use crate::{
    Diagnostic,
    ast::{
        DefinitionKind, Expr, ExprKind, Literal, Module, Mold, MoldDefinition, NumberAura, Pattern,
        PatternKind, Sample, SampleKind, Span, StringPart,
    },
    check::{self},
    types::{Aura, PathSegmentType, Type, TypeField, TypeVar},
    value::{GateValue, Noun, Scope, Slot, TypedValue, Value},
};
use num_bigint::BigUint;
use std::{collections::BTreeMap, rc::Rc};

pub fn evaluate(module: &Module, entry: &str) -> Result<Value, Diagnostic> {
    let _checked = check::check(module)?;
    let mut evaluator = Evaluator { module };
    let scope = evaluator.module_scope();
    let span = module
        .definitions
        .iter()
        .find(|definition| definition.name == entry)
        .map_or(module.span, |definition| definition.span);
    let value = evaluator.force(&scope, entry, span)?;
    match value.value {
        Value::Noun(_) | Value::Cell(_) => Ok(value.value),
        Value::Gate(_) | Value::Constructor(_) | Value::Native(_) => Err(Diagnostic::at(
            format!("entry point `{entry}` requires arguments"),
            span,
        )),
    }
}

struct Evaluator<'a> {
    module: &'a Module,
}

impl Evaluator<'_> {
    fn module_scope(&self) -> Rc<Scope> {
        let scope = Rc::new(Scope::new(None));
        for definition in &self.module.definitions {
            if let DefinitionKind::Value(expression) = &definition.kind {
                scope.slots.borrow_mut().insert(
                    definition.name.clone(),
                    Slot::Unevaluated(expression.clone()),
                );
            }
        }
        scope
    }

    fn force(
        &mut self,
        scope: &Rc<Scope>,
        name: &str,
        span: Span,
    ) -> Result<TypedValue, Diagnostic> {
        let previous = scope
            .slots
            .borrow_mut()
            .insert(name.to_string(), Slot::Evaluating);
        match previous {
            Some(Slot::Evaluated(value)) => {
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.to_string(), Slot::Evaluated(value.clone()));
                Ok(value)
            }
            Some(Slot::Eager(value)) => {
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.to_string(), Slot::Eager(value.clone()));
                Ok(value)
            }
            Some(Slot::Unevaluated(expression)) => {
                let result = self.eval(&expression, scope, None);
                match result {
                    Ok(value) => {
                        scope
                            .slots
                            .borrow_mut()
                            .insert(name.to_string(), Slot::Evaluated(value.clone()));
                        Ok(value)
                    }
                    Err(error) => {
                        scope
                            .slots
                            .borrow_mut()
                            .insert(name.to_string(), Slot::Unevaluated(expression));
                        Err(error)
                    }
                }
            }
            Some(Slot::Evaluating) => {
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.to_string(), Slot::Evaluating);
                Err(Diagnostic::at(
                    format!("value dependency cycle at `{name}`"),
                    span,
                ))
            }
            None => {
                if let Some(parent) = &scope.parent {
                    self.force(parent, name, span)
                } else {
                    Err(Diagnostic::at(format!("unknown value `{name}`"), span))
                }
            }
        }
    }

    fn eval(
        &mut self,
        expression: &Expr,
        scope: &Rc<Scope>,
        expected: Option<&Type>,
    ) -> Result<TypedValue, Diagnostic> {
        match &expression.kind {
            ExprKind::Literal(literal) => self.eval_literal(literal, expression.span),
            ExprKind::Reference(names) => {
                if names.len() == 2
                    && names.last().is_some_and(|name| name == "core")
                    && let Some(native) = crate::native::NativeFunction::from_field(&names[0])
                {
                    return Ok(TypedValue {
                        value: Value::Native(native),
                        typ: crate::native::scheme(native, self.module.span.source).typ,
                    });
                }
                let Some(base) = names.last() else {
                    return Err(Diagnostic::at("empty wing", expression.span));
                };
                let mut value = self.force(scope, base, expression.span)?;
                for field in &names[..names.len() - 1] {
                    value = self.record_field(&value, field, scope, expression.span)?;
                }
                Ok(value)
            }
            ExprKind::Gate { sample, body } => {
                let sample_type = expected
                    .and_then(|typ| match typ {
                        Type::Gate { sample, .. } => Some(sample.as_ref().clone()),
                        _ => None,
                    })
                    .unwrap_or_else(|| self.sample_type(sample, scope));
                let product = expected
                    .and_then(|typ| match typ {
                        Type::Gate { product, .. } => Some(product.as_ref().clone()),
                        _ => None,
                    })
                    .unwrap_or(Type::Noun);
                Ok(TypedValue {
                    value: Value::Gate(Rc::new(GateValue {
                        sample: sample.clone(),
                        body: body.as_ref().clone(),
                        environment: scope.clone(),
                    })),
                    typ: Type::Gate {
                        sample: Box::new(sample_type),
                        product: Box::new(product),
                    },
                })
            }
            ExprKind::Constructor(tag) => Ok(TypedValue {
                value: Value::Constructor(tag.clone()),
                typ: expected.cloned().unwrap_or(Type::Noun),
            }),
            ExprKind::Call { head, arguments } => {
                if let ExprKind::Reference(names) = &head.kind
                    && names.len() == 1
                    && matches!(names[0].as_str(), "proj" | "unface")
                {
                    return self.eval_type_directed(
                        &names[0],
                        &arguments[0],
                        scope,
                        expected,
                        expression.span,
                    );
                }
                let head_expected = if matches!(head.kind, ExprKind::Constructor(_)) {
                    expected.map(|product| Type::Gate {
                        sample: Box::new(Type::Noun),
                        product: Box::new(product.clone()),
                    })
                } else {
                    None
                };
                let head = self.eval(head, scope, head_expected.as_ref())?;
                let sample_type = self.gate_sample_type(&head, scope);
                let expected_fields = match &sample_type {
                    Type::Cell(fields) if fields.len() == arguments.len() => {
                        Some(fields.as_slice())
                    }
                    _ => None,
                };
                let mut values = Vec::new();
                for (index, argument) in arguments.iter().enumerate() {
                    let expected = expected_fields.map(|fields| &fields[index].typ);
                    values.push(self.eval(argument, scope, expected)?);
                }
                let sample = typed_sample(values);
                self.apply(head, sample, expression.span)
            }
            ExprKind::Cast { mold, value } => {
                let target = self.resolve_mold(mold, scope)?;
                let mut value = self.eval(value, scope, Some(&target))?;
                value.typ = target;
                Ok(value)
            }
            ExprKind::Tuple(items) => {
                let expected_fields = expected.and_then(|typ| match typ {
                    Type::Cell(fields) if fields.len() == items.len() => Some(fields.as_slice()),
                    _ => None,
                });
                let mut values = Vec::new();
                let mut fields = Vec::new();
                for (index, item) in items.iter().enumerate() {
                    let expected = expected_fields.map(|fields| &fields[index].typ);
                    let value = self.eval(&item.value, scope, expected)?;
                    values.push(value.value);
                    fields.push(TypeField {
                        face: item.face.clone(),
                        typ: value.typ,
                    });
                }
                if fields.len() == 1 && fields[0].face.is_none() {
                    return Ok(TypedValue {
                        value: values.remove(0),
                        typ: fields.remove(0).typ,
                    });
                }
                Ok(TypedValue {
                    value: make_cell(values),
                    typ: Type::Cell(fields),
                })
            }
            ExprKind::List(items) => {
                let element = expected.and_then(|typ| self.container_element(typ, "list", scope));
                let mut values = Vec::new();
                for item in items {
                    let value = self.eval(item, scope, element.as_ref())?;
                    values.push(value.value);
                }
                Ok(TypedValue {
                    value: make_list(values),
                    typ: expected.cloned().unwrap_or(Type::Noun),
                })
            }
            ExprKind::Unit(value) => {
                let payload = expected.and_then(|typ| self.container_element(typ, "unit", scope));
                let value = self.eval(value, scope, payload.as_ref())?;
                Ok(TypedValue {
                    value: make_cell(vec![Value::Noun(Noun::null()), value.value]),
                    typ: expected.cloned().unwrap_or(Type::Noun),
                })
            }
            ExprKind::Pair { tag, value } => {
                let tag_value = BigUint::from_bytes_le(tag.as_bytes());
                let tag = Noun::bytes(tag.as_bytes());
                let payload =
                    expected.and_then(|typ| self.pair_payload_type(&tag_value, typ, scope));
                let value = self.eval(value, scope, payload.as_ref())?;
                Ok(TypedValue {
                    value: make_cell(vec![Value::Noun(tag), value.value]),
                    typ: expected.cloned().unwrap_or(Type::Noun),
                })
            }
            ExprKind::Branch { subject, arms } => {
                let subject = self.eval(subject, scope, None)?;
                for arm in arms {
                    let child = Rc::new(Scope::new(Some(scope.clone())));
                    if self.match_pattern(&arm.pattern, &subject, &child)? {
                        return self.eval(&arm.body, &child, expected);
                    }
                }
                Err(Diagnostic::at("no branch pattern matched", expression.span))
            }
            ExprKind::Body {
                definitions,
                result,
            } => {
                let child = Rc::new(Scope::new(Some(scope.clone())));
                for definition in definitions {
                    match &definition.kind {
                        DefinitionKind::Value(value) => {
                            child
                                .slots
                                .borrow_mut()
                                .insert(definition.name.clone(), Slot::Unevaluated(value.clone()));
                        }
                        DefinitionKind::Mold(mold) => {
                            child
                                .molds
                                .borrow_mut()
                                .insert(definition.name.clone(), (*mold).clone());
                        }
                    }
                }
                self.eval(result, &child, expected)
            }
            ExprKind::Change { target, edits } => {
                let original = self.eval(
                    &Expr {
                        kind: ExprKind::Reference(target.clone()),
                        span: expression.span,
                    },
                    scope,
                    None,
                )?;
                let mut noun = match &original.value {
                    Value::Noun(noun) => noun.clone(),
                    _ => {
                        return Err(Diagnostic::at(
                            "change target is not a noun",
                            expression.span,
                        ));
                    }
                };
                for edit in edits {
                    let (_, steps) =
                        self.record_wing_location(&original.typ, &edit.field, scope, edit.span)?;
                    let expected =
                        self.record_wing_type(&original.typ, &edit.field, scope, edit.span)?;
                    let replacement = self.eval(&edit.value, scope, Some(&expected))?;
                    let Value::Noun(replacement) = replacement.value else {
                        return Err(Diagnostic::at("replacement is not a noun", edit.span));
                    };
                    noun = update_noun(&noun, &steps, replacement);
                }
                Ok(TypedValue {
                    value: Value::Noun(noun),
                    typ: original.typ,
                })
            }
            ExprKind::Trace { value, body } => {
                let value = self.eval(value, scope, None)?;
                eprintln!("{}", value.value);
                self.eval(body, scope, expected)
            }
            ExprKind::String(parts) => {
                let mut bytes = Vec::new();
                for part in parts {
                    match part {
                        StringPart::Text(text) => bytes.extend(text),
                        StringPart::Expr(value) => {
                            let span = value.span;
                            let value = self.eval(value, scope, None)?;
                            bytes.extend(self.print_atom(&value, scope, span)?);
                        }
                    }
                }
                Ok(TypedValue {
                    value: Value::Noun(Noun::bytes(&bytes)),
                    typ: Type::Atom(Aura::new("t")),
                })
            }
            ExprKind::Path(segments) => Ok(TypedValue {
                value: Value::Noun(Noun::list(
                    segments
                        .iter()
                        .map(|segment| Noun::bytes(segment.as_bytes()))
                        .collect(),
                )),
                typ: Type::Path(
                    segments
                        .iter()
                        .map(|segment| PathSegmentType::Knot(segment.clone()))
                        .collect(),
                ),
            }),
            ExprKind::Crash => Err(Diagnostic::at("Jibb crash", expression.span)),
            ExprKind::ApplicationPath(_) => Err(Diagnostic::at(
                "application paths are not available to the evaluator",
                expression.span,
            )),
        }
    }

    fn print_atom(
        &self,
        value: &TypedValue,
        scope: &Rc<Scope>,
        span: Span,
    ) -> Result<Vec<u8>, Diagnostic> {
        let Value::Noun(noun) = &value.value else {
            return Err(Diagnostic::at("interpolation expects an atom", span));
        };
        let Noun::Atom(atom) = noun.as_ref() else {
            return Err(Diagnostic::at("interpolation expects an atom", span));
        };
        match &value.typ {
            Type::Atom(aura) => format_aura_atom(atom, aura, span),
            Type::AnyAtom => Ok(format_radix(atom, 10, 3, "").into_bytes()),
            Type::Flag | Type::LoobeanConstant(_) => {
                if *atom == BigUint::default() {
                    Ok(b"%.y".to_vec())
                } else if *atom == BigUint::from(1u8) {
                    Ok(b"%.n".to_vec())
                } else {
                    Err(Diagnostic::at("invalid loobean atom", span))
                }
            }
            Type::Constant(_) => {
                if *atom == BigUint::default() {
                    Ok(b"%$".to_vec())
                } else if *atom == BigUint::from(1u8) {
                    Ok(b"%|".to_vec())
                } else {
                    let bytes = atom.to_bytes_le();
                    if bytes.first().is_some_and(u8::is_ascii_lowercase)
                        && bytes.iter().all(|byte| {
                            byte.is_ascii_lowercase() || byte.is_ascii_digit() || *byte == b'-'
                        })
                    {
                        Ok(format!("%{}", String::from_utf8_lossy(&bytes)).into_bytes())
                    } else {
                        Ok(format!("%{}", format_radix(atom, 10, 3, "")).into_bytes())
                    }
                }
            }
            Type::NumericTerm(_) => Ok(format!("%{}", format_radix(atom, 10, 3, "")).into_bytes()),
            Type::Named { .. } => {
                let cases = self.expand_named(&value.typ, scope)?;
                if cases.len() == 1 {
                    let mut value = value.clone();
                    value.typ = cases[0].clone();
                    self.print_atom(&value, scope, span)
                } else {
                    Err(Diagnostic::at("interpolation needs one atom type", span))
                }
            }
            _ => Err(Diagnostic::at(
                format!(
                    "interpolation has no printer for {}",
                    crate::types::TypeScheme::mono(value.typ.clone())
                ),
                span,
            )),
        }
    }

    fn eval_literal(&self, literal: &Literal, span: Span) -> Result<TypedValue, Diagnostic> {
        let (noun, typ) = match literal {
            Literal::Number(number) => (
                Noun::atom(number.value.clone()),
                Type::Atom(Aura::new(match number.aura {
                    NumberAura::Decimal => "ud",
                    NumberAura::Hexadecimal => "ux",
                    NumberAura::Base32 => "uv",
                })),
            ),
            Literal::String(bytes) => (Noun::bytes(bytes), Type::Atom(Aura::new("t"))),
            Literal::Knot(knot) => (Noun::bytes(knot.as_bytes()), Type::Atom(Aura::new("ta"))),
            Literal::Term(term) => (
                Noun::atom(term.value.clone()),
                match term.kind {
                    crate::ast::TermKind::Named => Type::Constant(term.value.clone()),
                    crate::ast::TermKind::Numeric => Type::NumericTerm(term.value.clone()),
                },
            ),
            Literal::Loobean(yes) => (
                Noun::loobean(*yes),
                Type::LoobeanConstant(BigUint::from(u8::from(!yes))),
            ),
            Literal::Null => (Noun::null(), Type::Constant(BigUint::default())),
            Literal::Ship(text) => {
                let value = crate::literal::ship(text)
                    .ok_or_else(|| Diagnostic::at("invalid ship literal", span))?;
                (Noun::atom(value), Type::Atom(Aura::new("p")))
            }
            Literal::Date(text) => {
                let value = crate::literal::date(text)
                    .ok_or_else(|| Diagnostic::at("invalid date literal", span))?;
                (Noun::atom(value), Type::Atom(Aura::new("da")))
            }
            Literal::Duration(text) => {
                let value = crate::literal::duration(text)
                    .ok_or_else(|| Diagnostic::at("invalid duration literal", span))?;
                (Noun::atom(value), Type::Atom(Aura::new("dr")))
            }
        };
        Ok(TypedValue {
            value: Value::Noun(noun),
            typ,
        })
    }

    fn apply(
        &mut self,
        head: TypedValue,
        sample: TypedValue,
        span: Span,
    ) -> Result<TypedValue, Diagnostic> {
        match head.value {
            Value::Gate(gate) => {
                let scope = Rc::new(Scope::new(Some(gate.environment.clone())));
                self.bind_sample(&gate.sample, &sample, &scope)?;
                let product = match &head.typ {
                    Type::Gate { product, .. } => Some(product.as_ref().clone()),
                    _ => None,
                };
                self.eval(&gate.body, &scope, product.as_ref())
            }
            Value::Constructor(tag) => {
                let product = match &head.typ {
                    Type::Gate { product, .. } => product.as_ref().clone(),
                    _ => Type::Noun,
                };
                Ok(TypedValue {
                    value: make_cell(vec![Value::Noun(Noun::atom(tag)), sample.value]),
                    typ: product,
                })
            }
            Value::Native(native) => crate::native::apply(native, &sample, span),
            Value::Noun(_) | Value::Cell(_) => {
                Err(Diagnostic::at("attempted to call a noun", span))
            }
        }
    }

    fn bind_sample(
        &mut self,
        sample: &Sample,
        value: &TypedValue,
        scope: &Rc<Scope>,
    ) -> Result<(), Diagnostic> {
        match &sample.kind {
            SampleKind::Binding(name) => {
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.clone(), Slot::Eager(value.clone()));
                Ok(())
            }
            SampleKind::Face { name, mold } => {
                let mut value = value.clone();
                value.typ = self.resolve_mold(mold, scope)?;
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.clone(), Slot::Eager(value));
                Ok(())
            }
            SampleKind::Pun(name) => {
                let mut value = value.clone();
                value.typ = self.resolve_mold(
                    &Mold {
                        kind: crate::ast::MoldKind::Reference(vec![name.clone()]),
                        span: sample.span,
                    },
                    scope,
                )?;
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.clone(), Slot::Eager(value));
                Ok(())
            }
            SampleKind::Mold(_) => Ok(()),
            SampleKind::Cell(samples) => {
                let components = sample_components(value, samples.len());
                for (sample, value) in samples.iter().zip(components) {
                    self.bind_sample(sample, &value, scope)?;
                }
                Ok(())
            }
        }
    }

    fn match_pattern(
        &mut self,
        pattern: &Pattern,
        value: &TypedValue,
        scope: &Rc<Scope>,
    ) -> Result<bool, Diagnostic> {
        match &pattern.kind {
            PatternKind::Wildcard => Ok(true),
            PatternKind::Binding(name) => {
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.clone(), Slot::Eager(value.clone()));
                Ok(true)
            }
            PatternKind::Literal(literal) => {
                let expected = self.eval_literal(literal, pattern.span)?;
                let Value::Noun(expected) = expected.value else {
                    unreachable!()
                };
                let Value::Noun(actual) = &value.value else {
                    return Ok(false);
                };
                Ok(noun_equal(actual, &expected))
            }
            PatternKind::Cell(patterns) => {
                let components = value_components(value, patterns.len());
                let Some(components) = components else {
                    return Ok(false);
                };
                for (pattern, value) in patterns.iter().zip(components) {
                    if !self.match_pattern(pattern, &value, scope)? {
                        return Ok(false);
                    }
                }
                Ok(true)
            }
        }
    }

    fn gate_sample_type(&self, head: &TypedValue, scope: &Rc<Scope>) -> Type {
        if let Type::Gate { sample, .. } = &head.typ {
            return sample.as_ref().clone();
        }
        match &head.value {
            Value::Gate(gate) => self.sample_type(&gate.sample, scope),
            _ => Type::Noun,
        }
    }

    fn sample_type(&self, sample: &Sample, scope: &Rc<Scope>) -> Type {
        match &sample.kind {
            SampleKind::Binding(_) => Type::Noun,
            SampleKind::Face { mold, .. } | SampleKind::Mold(mold) => {
                self.resolve_mold(mold, scope).unwrap_or(Type::Noun)
            }
            SampleKind::Pun(name) => self
                .resolve_mold(
                    &Mold {
                        kind: crate::ast::MoldKind::Reference(vec![name.clone()]),
                        span: sample.span,
                    },
                    scope,
                )
                .unwrap_or(Type::Noun),
            SampleKind::Cell(samples) => Type::Cell(
                samples
                    .iter()
                    .map(|sample| TypeField {
                        face: match &sample.kind {
                            SampleKind::Face { name, .. } | SampleKind::Pun(name) => {
                                Some(name.clone())
                            }
                            _ => None,
                        },
                        typ: self.sample_type(sample, scope),
                    })
                    .collect(),
            ),
        }
    }

    fn eval_type_directed(
        &mut self,
        operation: &str,
        argument: &Expr,
        scope: &Rc<Scope>,
        expected: Option<&Type>,
        span: Span,
    ) -> Result<TypedValue, Diagnostic> {
        let value = self.eval(argument, scope, None)?;
        if operation == "unface" {
            return Ok(TypedValue {
                value: value.value,
                typ: unface_type(&value.typ),
            });
        }
        let Some(Type::Cell(fields)) = expected else {
            return Err(Diagnostic::at("`proj` needs an expected record type", span));
        };
        let mut values = Vec::new();
        for field in fields {
            let Some(face) = &field.face else {
                return Err(Diagnostic::at("projection fields must be named", span));
            };
            let field_value = self.record_field(&value, face, scope, span)?;
            values.push(field_value.value);
        }
        Ok(TypedValue {
            value: make_cell(values),
            typ: expected.cloned().unwrap_or(Type::Noun),
        })
    }

    fn record_field(
        &mut self,
        value: &TypedValue,
        name: &str,
        scope: &Rc<Scope>,
        span: Span,
    ) -> Result<TypedValue, Diagnostic> {
        let (typ, steps) =
            self.record_wing_location(&value.typ, &[name.to_string()], scope, span)?;
        let value = apply_value_steps(&value.value, &steps)?;
        Ok(TypedValue { value, typ })
    }

    fn record_wing_type(
        &mut self,
        typ: &Type,
        names: &[String],
        scope: &Rc<Scope>,
        span: Span,
    ) -> Result<Type, Diagnostic> {
        Ok(self.record_wing_location(typ, names, scope, span)?.0)
    }

    fn record_wing_location(
        &mut self,
        typ: &Type,
        names: &[String],
        scope: &Rc<Scope>,
        span: Span,
    ) -> Result<(Type, Vec<Step>), Diagnostic> {
        let mut typ = typ.clone();
        let mut steps = Vec::new();
        for name in names {
            let (field, mut path) = self.field_location(&typ, name, scope, span)?;
            typ = field;
            steps.append(&mut path);
        }
        Ok((typ, steps))
    }

    fn field_location(
        &self,
        typ: &Type,
        name: &str,
        scope: &Rc<Scope>,
        span: Span,
    ) -> Result<(Type, Vec<Step>), Diagnostic> {
        match typ {
            Type::Cell(fields) if fields.len() == 1 => {
                if fields[0].face.as_deref() == Some(name) {
                    Ok((fields[0].typ.clone(), Vec::new()))
                } else {
                    Err(Diagnostic::at(
                        format!("record has no field `{name}`"),
                        span,
                    ))
                }
            }
            Type::Cell(fields) => {
                let index = fields
                    .iter()
                    .position(|field| field.face.as_deref() == Some(name))
                    .ok_or_else(|| Diagnostic::at(format!("record has no field `{name}`"), span))?;
                let mut steps = (0..index).map(|_| Step::Tail).collect::<Vec<_>>();
                if index + 1 != fields.len() {
                    steps.push(Step::Head);
                }
                Ok((fields[index].typ.clone(), steps))
            }
            Type::Named { .. } => {
                let cases = self.expand_named(typ, scope)?;
                if cases.len() != 1 {
                    return Err(Diagnostic::at("field access needs one record type", span));
                }
                self.field_location(&cases[0], name, scope, span)
            }
            _ => Err(Diagnostic::at("field access needs a record", span)),
        }
    }

    fn expand_named(&self, typ: &Type, scope: &Rc<Scope>) -> Result<Vec<Type>, Diagnostic> {
        let Type::Named {
            name, arguments, ..
        } = typ
        else {
            return Ok(vec![typ.clone()]);
        };
        let mold = check::resolved_mold_for_evaluation(self.module, name, &local_molds(scope))?;
        let substitutions = mold
            .parameters
            .iter()
            .zip(arguments)
            .map(|(parameter, argument)| (parameter.id, argument.clone()))
            .collect::<BTreeMap<TypeVar, Type>>();
        Ok(mold
            .cases
            .iter()
            .map(|case| substitute(&case.typ, &substitutions))
            .collect())
    }

    fn container_element(&self, typ: &Type, container: &str, scope: &Rc<Scope>) -> Option<Type> {
        match typ {
            Type::Named {
                name, arguments, ..
            } if name == container && arguments.len() == 1 => arguments.first().cloned(),
            Type::Named { .. } => {
                let cases = self.expand_named(typ, scope).ok()?;
                if cases.len() == 1 {
                    self.container_element(&cases[0], container, scope)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    fn pair_payload_type(&self, tag: &BigUint, typ: &Type, scope: &Rc<Scope>) -> Option<Type> {
        match typ {
            Type::Cell(fields) if fields.len() == 2 => {
                if constant_value(&fields[0].typ) == Some(tag) {
                    Some(fields[1].typ.clone())
                } else {
                    None
                }
            }
            Type::Named { .. } => self
                .expand_named(typ, scope)
                .ok()?
                .iter()
                .find_map(|case| self.pair_payload_type(tag, case, scope)),
            _ => None,
        }
    }

    fn resolve_mold(&self, mold: &Mold, scope: &Rc<Scope>) -> Result<Type, Diagnostic> {
        check::resolve_mold_for_evaluation(self.module, mold, &local_molds(scope))
    }
}

#[derive(Clone, Copy)]
enum Step {
    Head,
    Tail,
}

fn typed_sample(values: Vec<TypedValue>) -> TypedValue {
    if values.len() == 1 {
        return values.into_iter().next().expect("one sample");
    }
    let mut fields = Vec::new();
    let mut items = Vec::new();
    for value in values {
        fields.push(TypeField {
            face: None,
            typ: value.typ,
        });
        items.push(value.value);
    }
    TypedValue {
        value: make_cell(items),
        typ: Type::Cell(fields),
    }
}

fn make_cell(items: Vec<Value>) -> Value {
    if items.len() == 1 {
        return items.into_iter().next().expect("one cell item");
    }
    let mut nouns = Vec::new();
    for item in &items {
        match item {
            Value::Noun(noun) => nouns.push(noun.clone()),
            _ => return Value::Cell(items),
        }
    }
    Value::Noun(Noun::cells(nouns))
}

fn make_list(mut items: Vec<Value>) -> Value {
    items.push(Value::Noun(Noun::null()));
    make_cell(items)
}

fn sample_components(value: &TypedValue, count: usize) -> Vec<TypedValue> {
    value_components(value, count).expect("checked sample shape")
}

fn value_components(value: &TypedValue, count: usize) -> Option<Vec<TypedValue>> {
    if count == 1 {
        return Some(vec![value.clone()]);
    }
    let fields = match &value.typ {
        Type::Cell(fields) if fields.len() == count => Some(fields.as_slice()),
        _ => None,
    };
    match &value.value {
        Value::Noun(noun) => noun_components(noun, &value.typ, count),
        Value::Cell(items) if items.len() >= count => {
            let mut values = items
                .iter()
                .take(count - 1)
                .cloned()
                .enumerate()
                .map(|(index, value)| TypedValue {
                    value,
                    typ: fields.map_or(Type::Noun, |fields| fields[index].typ.clone()),
                })
                .collect::<Vec<_>>();
            let tail = if items.len() == count {
                items[count - 1].clone()
            } else {
                Value::Cell(items[count - 1..].to_vec())
            };
            values.push(TypedValue {
                value: tail,
                typ: fields.map_or(Type::Noun, |fields| fields[count - 1].typ.clone()),
            });
            Some(values)
        }
        _ => None,
    }
}

fn noun_components(noun: &Rc<Noun>, typ: &Type, count: usize) -> Option<Vec<TypedValue>> {
    if count == 1 {
        return Some(vec![TypedValue {
            value: Value::Noun(noun.clone()),
            typ: typ.clone(),
        }]);
    }
    let fields = match typ {
        Type::Cell(fields) if fields.len() == count => Some(fields.as_slice()),
        _ => None,
    };
    let mut values = Vec::new();
    let mut rest = noun.clone();
    for index in 0..count - 1 {
        let Noun::Cell(head, tail) = rest.as_ref() else {
            return None;
        };
        values.push(TypedValue {
            value: Value::Noun(head.clone()),
            typ: fields.map_or(Type::Noun, |fields| fields[index].typ.clone()),
        });
        rest = tail.clone();
    }
    values.push(TypedValue {
        value: Value::Noun(rest),
        typ: fields.map_or(Type::Noun, |fields| fields[count - 1].typ.clone()),
    });
    Some(values)
}

fn noun_equal(left: &Noun, right: &Noun) -> bool {
    match (left, right) {
        (Noun::Atom(left), Noun::Atom(right)) => left == right,
        (Noun::Cell(lh, lt), Noun::Cell(rh, rt)) => noun_equal(lh, rh) && noun_equal(lt, rt),
        _ => false,
    }
}

fn apply_value_steps(value: &Value, steps: &[Step]) -> Result<Value, Diagnostic> {
    let mut current = value.clone();
    for step in steps {
        current = match current {
            Value::Noun(noun) => Value::Noun(apply_steps(&noun, std::slice::from_ref(step))?),
            Value::Cell(items) => match step {
                Step::Head => items
                    .first()
                    .cloned()
                    .ok_or_else(|| Diagnostic::new("empty computational cell"))?,
                Step::Tail if items.len() == 2 => items[1].clone(),
                Step::Tail => Value::Cell(items[1..].to_vec()),
            },
            Value::Gate(_) | Value::Constructor(_) | Value::Native(_) => {
                return Err(Diagnostic::new("record field path is not a cell"));
            }
        };
    }
    Ok(current)
}

fn apply_steps(noun: &Rc<Noun>, steps: &[Step]) -> Result<Rc<Noun>, Diagnostic> {
    let mut current = noun.clone();
    for step in steps {
        let Noun::Cell(head, tail) = current.as_ref() else {
            return Err(Diagnostic::new("record field path does not match its noun"));
        };
        current = match step {
            Step::Head => head.clone(),
            Step::Tail => tail.clone(),
        };
    }
    Ok(current)
}

fn update_noun(noun: &Rc<Noun>, steps: &[Step], replacement: Rc<Noun>) -> Rc<Noun> {
    let Some((step, rest)) = steps.split_first() else {
        return replacement;
    };
    let Noun::Cell(head, tail) = noun.as_ref() else {
        panic!("checked record update shape")
    };
    match step {
        Step::Head => Noun::cell(update_noun(head, rest, replacement), tail.clone()),
        Step::Tail => Noun::cell(head.clone(), update_noun(tail, rest, replacement)),
    }
}

fn local_molds(scope: &Rc<Scope>) -> Vec<BTreeMap<String, MoldDefinition>> {
    let mut scopes = Vec::new();
    let mut current = Some(scope.clone());
    while let Some(scope) = current {
        if !scope.molds.borrow().is_empty() {
            scopes.push(scope.molds.borrow().clone());
        }
        current = scope.parent.clone();
    }
    scopes.reverse();
    scopes
}

fn substitute(typ: &Type, substitutions: &BTreeMap<TypeVar, Type>) -> Type {
    match typ {
        Type::Var(variable) => substitutions
            .get(variable)
            .cloned()
            .unwrap_or_else(|| typ.clone()),
        Type::Cell(fields) => Type::Cell(
            fields
                .iter()
                .map(|field| TypeField {
                    face: field.face.clone(),
                    typ: substitute(&field.typ, substitutions),
                })
                .collect(),
        ),
        Type::Gate { sample, product } => Type::Gate {
            sample: Box::new(substitute(sample, substitutions)),
            product: Box::new(substitute(product, substitutions)),
        },
        Type::Named {
            module,
            name,
            arguments,
        } => Type::Named {
            module: *module,
            name: name.clone(),
            arguments: arguments
                .iter()
                .map(|argument| substitute(argument, substitutions))
                .collect(),
        },
        _ => typ.clone(),
    }
}

fn unface_type(typ: &Type) -> Type {
    match typ {
        Type::Cell(fields) => Type::Cell(
            fields
                .iter()
                .map(|field| TypeField {
                    face: None,
                    typ: unface_type(&field.typ),
                })
                .collect(),
        ),
        Type::Gate { sample, product } => Type::Gate {
            sample: Box::new(unface_type(sample)),
            product: Box::new(unface_type(product)),
        },
        Type::Named {
            module,
            name,
            arguments,
        } => Type::Named {
            module: *module,
            name: name.clone(),
            arguments: arguments.iter().map(unface_type).collect(),
        },
        _ => typ.clone(),
    }
}

fn format_aura_atom(atom: &BigUint, aura: &Aura, span: Span) -> Result<Vec<u8>, Diagnostic> {
    match aura.0.as_str() {
        "t" | "ta" | "tas" | "tD" => Ok(atom.to_bytes_le()),
        "ud" => Ok(format_radix(atom, 10, 3, "").into_bytes()),
        "ux" => Ok(format_radix(atom, 16, 4, "0x").into_bytes()),
        "uv" => Ok(format_radix(atom, 32, 5, "0v").into_bytes()),
        "p" => crate::literal::format_ship(atom)
            .map(String::into_bytes)
            .ok_or_else(|| Diagnostic::at("invalid ship atom", span)),
        "da" => crate::literal::format_date(atom)
            .map(String::into_bytes)
            .ok_or_else(|| Diagnostic::at("invalid date atom", span)),
        "dr" => crate::literal::format_duration(atom)
            .map(String::into_bytes)
            .ok_or_else(|| Diagnostic::at("invalid duration atom", span)),
        "f" => {
            if *atom == BigUint::default() {
                Ok(b"%.y".to_vec())
            } else if *atom == BigUint::from(1u8) {
                Ok(b"%.n".to_vec())
            } else {
                Err(Diagnostic::at("invalid loobean atom", span))
            }
        }
        _ => Err(Diagnostic::at(
            format!("interpolation has no printer for @{}", aura.0),
            span,
        )),
    }
}

fn format_radix(value: &BigUint, radix: u32, group: usize, prefix: &str) -> String {
    let digits = value.to_str_radix(radix);
    let mut result = String::from(prefix);
    for (index, character) in digits.chars().enumerate() {
        if index != 0 && (digits.len() - index).is_multiple_of(group) {
            result.push('.');
        }
        result.push(character);
    }
    result
}

fn constant_value(typ: &Type) -> Option<&BigUint> {
    match typ {
        Type::Constant(value) | Type::NumericTerm(value) | Type::LoobeanConstant(value) => {
            Some(value)
        }
        _ => None,
    }
}
