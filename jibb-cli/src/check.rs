use crate::{
    Diagnostic,
    ast::{
        DefinitionKind, Expr, ExprKind, Literal, Module, Mold, MoldDefinition, MoldKind,
        MoldPathSegment, NumberAura, SourceId, Span, TermKind, TypedSegmentMold,
    },
    types::{Aura, PathSegmentType, QuantifiedVariable, Type, TypeField, TypeScheme, TypeVar},
};
use num_bigint::BigUint;
use std::collections::{BTreeMap, BTreeSet, HashSet};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CheckedModule {
    pub source: SourceId,
    pub values: BTreeMap<String, TypeScheme>,
    pub molds: BTreeMap<String, ResolvedMold>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResolvedMold {
    pub module: SourceId,
    pub name: String,
    pub parameters: Vec<QuantifiedVariable>,
    pub cases: Vec<ResolvedCase>,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResolvedCase {
    pub typ: Type,
    pub span: Span,
}

pub fn check(module: &Module) -> Result<CheckedModule, Diagnostic> {
    Checker::new(module).check()
}

struct Checker<'a> {
    module: &'a Module,
    mold_definitions: BTreeMap<&'a str, (&'a MoldDefinition, Span)>,
    value_definitions: BTreeMap<&'a str, Span>,
    resolved_molds: BTreeMap<String, ResolvedMold>,
    next_variable: TypeVar,
}

impl<'a> Checker<'a> {
    fn new(module: &'a Module) -> Self {
        Self {
            module,
            mold_definitions: BTreeMap::new(),
            value_definitions: BTreeMap::new(),
            resolved_molds: BTreeMap::new(),
            next_variable: 0,
        }
    }

    fn check(mut self) -> Result<CheckedModule, Diagnostic> {
        if let Some(import) = self.module.imports.first() {
            return Err(Diagnostic::at(
                "module imports are not available to the static checker yet",
                import.span,
            ));
        }
        self.collect_scope()?;
        let mold_names = self
            .mold_definitions
            .keys()
            .map(|name| (*name).to_string())
            .collect::<Vec<_>>();
        for name in mold_names {
            let definition = self.mold_definitions[name.as_str()].0.clone();
            let span = self.mold_definitions[name.as_str()].1;
            let resolved = self.resolve_mold_definition(&name, &definition, span)?;
            self.resolved_molds.insert(name, resolved);
        }
        self.validate_unions()?;

        let mut values = BTreeMap::new();
        for definition in &self.module.definitions {
            let DefinitionKind::Value(expression) = &definition.kind else {
                continue;
            };
            let mut variables = BTreeMap::new();
            let typ = self.infer_expression(expression, None, &mut variables)?;
            values.insert(definition.name.clone(), TypeScheme::mono(typ));
        }

        Ok(CheckedModule {
            source: self.module.span.source,
            values,
            molds: self.resolved_molds,
        })
    }

    fn collect_scope(&mut self) -> Result<(), Diagnostic> {
        for definition in &self.module.definitions {
            if matches!(definition.name.as_str(), "proj" | "unface") {
                return Err(Diagnostic::at(
                    format!("`{}` is reserved", definition.name),
                    definition.span,
                ));
            }
            match &definition.kind {
                DefinitionKind::Value(_) => {
                    if let Some(previous) = self
                        .value_definitions
                        .insert(&definition.name, definition.span)
                    {
                        return Err(duplicate_name(&definition.name, definition.span, previous));
                    }
                }
                DefinitionKind::Mold(mold) => {
                    if let Some((_, previous)) = self
                        .mold_definitions
                        .insert(&definition.name, (mold, definition.span))
                    {
                        return Err(duplicate_name(&definition.name, definition.span, previous));
                    }
                }
            }
        }
        Ok(())
    }

    fn resolve_mold_definition(
        &mut self,
        name: &str,
        definition: &MoldDefinition,
        span: Span,
    ) -> Result<ResolvedMold, Diagnostic> {
        let mut variables = BTreeMap::new();
        let mut parameters = Vec::new();
        if let Some(generic) = &definition.generic {
            for variable in &generic.variables {
                if variables.contains_key(variable) {
                    return Err(Diagnostic::at(
                        format!("duplicate generic variable `{variable}`"),
                        generic.span,
                    ));
                }
                let id = self.fresh_variable();
                variables.insert(variable.clone(), id);
                parameters.push(QuantifiedVariable {
                    id,
                    name: Some(variable.clone()),
                });
            }
        }
        let mut cases = Vec::new();
        for mold in &definition.cases {
            let typ = self.resolve_mold(mold, &mut variables, false, false)?;
            cases.push(ResolvedCase {
                typ,
                span: mold.span,
            });
        }
        Ok(ResolvedMold {
            module: self.module.span.source,
            name: name.to_string(),
            parameters,
            cases,
            span,
        })
    }

    fn resolve_mold(
        &mut self,
        mold: &Mold,
        variables: &mut BTreeMap<String, TypeVar>,
        allow_holes: bool,
        allow_new_variables: bool,
    ) -> Result<Type, Diagnostic> {
        match &mold.kind {
            MoldKind::Aura(aura) => {
                let aura = aura.strip_prefix('@').unwrap_or(aura);
                if aura.is_empty() {
                    Ok(Type::AnyAtom)
                } else {
                    Ok(Type::Atom(Aura::new(aura)))
                }
            }
            MoldKind::Hole if allow_holes => Ok(Type::Var(self.fresh_variable())),
            MoldKind::Hole => Err(Diagnostic::at("unconstrained type hole", mold.span)),
            MoldKind::Noun => Ok(Type::Noun),
            MoldKind::Void => Ok(Type::Void),
            MoldKind::Flag => Ok(Type::Flag),
            MoldKind::Null => Ok(Type::Constant(BigUint::default())),
            MoldKind::Term(term) => Ok(match term.kind {
                TermKind::Named => Type::Constant(term.value.clone()),
                TermKind::Numeric => Type::NumericTerm(term.value.clone()),
            }),
            MoldKind::Loobean(yes) => Ok(Type::LoobeanConstant(BigUint::from(u8::from(!yes)))),
            MoldKind::TypeVariable(name) => {
                if let Some(variable) = variables.get(name) {
                    return Ok(Type::Var(*variable));
                }
                if !allow_new_variables {
                    return Err(Diagnostic::at(
                        format!("type variable `{name}` is not declared by `|$`"),
                        mold.span,
                    ));
                }
                let variable = self.fresh_variable();
                variables.insert(name.clone(), variable);
                Ok(Type::Var(variable))
            }
            MoldKind::Reference(names) => {
                let name = self.local_mold_name(names, mold.span)?;
                let Some((definition, _)) = self.mold_definitions.get(name) else {
                    return Err(Diagnostic::at(format!("unknown mold `{name}`"), mold.span));
                };
                let arity = definition
                    .generic
                    .as_ref()
                    .map_or(0, |generic| generic.variables.len());
                if arity != 0 {
                    return Err(Diagnostic::at(
                        format!("generic mold `{name}` expects {arity} arguments"),
                        mold.span,
                    ));
                }
                Ok(Type::Named {
                    module: self.module.span.source,
                    name: name.to_string(),
                    arguments: Vec::new(),
                })
            }
            MoldKind::Apply {
                constructor,
                arguments,
            } => {
                let name = self.local_mold_name(constructor, mold.span)?;
                let Some((definition, _)) = self.mold_definitions.get(name) else {
                    return Err(Diagnostic::at(format!("unknown mold `{name}`"), mold.span));
                };
                let expected = definition
                    .generic
                    .as_ref()
                    .map_or(0, |generic| generic.variables.len());
                if arguments.len() != expected {
                    return Err(Diagnostic::at(
                        format!(
                            "mold `{name}` expects {expected} arguments, found {}",
                            arguments.len()
                        ),
                        mold.span,
                    ));
                }
                let arguments = arguments
                    .iter()
                    .map(|argument| {
                        self.resolve_mold(argument, variables, allow_holes, allow_new_variables)
                    })
                    .collect::<Result<Vec<_>, _>>()?;
                Ok(Type::Named {
                    module: self.module.span.source,
                    name: name.to_string(),
                    arguments,
                })
            }
            MoldKind::Cell(fields) => {
                let mut faces = BTreeMap::new();
                let mut resolved = Vec::new();
                for field in fields {
                    if let Some(face) = &field.face
                        && let Some(previous) = faces.insert(face, field.span)
                    {
                        return Err(Diagnostic::at(
                            format!("duplicate record field `{face}`"),
                            field.span,
                        )
                        .with_note("first field", previous));
                    }
                    resolved.push(TypeField {
                        face: field.face.clone(),
                        typ: self.resolve_mold(
                            &field.mold,
                            variables,
                            allow_holes,
                            allow_new_variables,
                        )?,
                    });
                }
                if resolved.len() == 1 && resolved[0].face.is_none() {
                    Ok(resolved.remove(0).typ)
                } else {
                    Ok(Type::Cell(resolved))
                }
            }
            MoldKind::Function { sample, product } => Ok(Type::Gate {
                sample: Box::new(self.resolve_mold(
                    sample,
                    variables,
                    allow_holes,
                    allow_new_variables,
                )?),
                product: Box::new(self.resolve_mold(
                    product,
                    variables,
                    allow_holes,
                    allow_new_variables,
                )?),
            }),
            MoldKind::Path(segments) => Ok(Type::Path(
                segments
                    .iter()
                    .map(|segment| match segment {
                        MoldPathSegment::Knot(knot) => Ok(PathSegmentType::Knot(knot.clone())),
                        MoldPathSegment::Typed {
                            name,
                            mold: segment_mold,
                        } => match segment_mold {
                            TypedSegmentMold::Aura(aura)
                                if aura.strip_prefix('@').is_some_and(|aura| !aura.is_empty()) =>
                            {
                                Ok(PathSegmentType::Typed {
                                    name: name.clone(),
                                    aura: Aura::new(aura.strip_prefix('@').unwrap_or(aura)),
                                })
                            }
                            TypedSegmentMold::Aura(_) => Err(Diagnostic::at(
                                "a typed path segment needs a specific aura",
                                mold.span,
                            )),
                            TypedSegmentMold::Hole => Err(Diagnostic::at(
                                "unconstrained typed path segment",
                                mold.span,
                            )),
                        },
                    })
                    .collect::<Result<Vec<_>, _>>()?,
            )),
        }
    }

    fn local_mold_name<'b>(&self, names: &'b [String], span: Span) -> Result<&'b str, Diagnostic> {
        if names.len() != 1 {
            return Err(Diagnostic::at(
                "qualified mold references require module interfaces",
                span,
            ));
        }
        Ok(&names[0])
    }

    fn validate_unions(&self) -> Result<(), Diagnostic> {
        for mold in self.resolved_molds.values() {
            for left in 0..mold.cases.len() {
                for right in left + 1..mold.cases.len() {
                    let a = &mold.cases[left];
                    let b = &mold.cases[right];
                    let mut visiting = HashSet::new();
                    if self.may_overlap(&a.typ, &b.typ, &mut visiting) {
                        return Err(Diagnostic::at(
                            format!("union `{}` has overlapping cases", mold.name),
                            b.span,
                        )
                        .with_note("earlier overlapping case", a.span));
                    }
                }
            }
        }
        Ok(())
    }

    fn may_overlap(&self, left: &Type, right: &Type, visiting: &mut HashSet<(Type, Type)>) -> bool {
        if matches!(left, Type::Void) || matches!(right, Type::Void) {
            return false;
        }
        if let Type::Cell(fields) = left
            && fields.len() == 1
        {
            return self.may_overlap(&fields[0].typ, right, visiting);
        }
        if let Type::Cell(fields) = right
            && fields.len() == 1
        {
            return self.may_overlap(left, &fields[0].typ, visiting);
        }
        if let (Some(left), Some(right)) = (constant_value(left), constant_value(right)) {
            return left == right;
        }
        if !visiting.insert((left.clone(), right.clone())) {
            return true;
        }
        let result = match (left, right) {
            (Type::Named { .. }, _) => self.expanded_cases(left).is_none_or(|cases| {
                cases
                    .iter()
                    .any(|case| self.may_overlap(case, right, visiting))
            }),
            (_, Type::Named { .. }) => self.expanded_cases(right).is_none_or(|cases| {
                cases
                    .iter()
                    .any(|case| self.may_overlap(left, case, visiting))
            }),
            (Type::Noun, _) | (_, Type::Noun) => true,
            (Type::Var(_), _) | (_, Type::Var(_)) => true,
            (Type::Flag, other) | (other, Type::Flag)
                if constant_value(other).is_some_and(|value| {
                    *value == BigUint::default() || *value == BigUint::from(1u8)
                }) =>
            {
                true
            }
            (Type::Flag, other) | (other, Type::Flag) if constant_value(other).is_some() => false,
            (Type::Flag, Type::Cell(_)) | (Type::Cell(_), Type::Flag) => false,
            (Type::Atom(_), Type::Cell(_))
            | (Type::Cell(_), Type::Atom(_))
            | (Type::AnyAtom, Type::Cell(_))
            | (Type::Cell(_), Type::AnyAtom)
            | (Type::Constant(_), Type::Cell(_))
            | (Type::Cell(_), Type::Constant(_))
            | (Type::NumericTerm(_), Type::Cell(_))
            | (Type::Cell(_), Type::NumericTerm(_))
            | (Type::LoobeanConstant(_), Type::Cell(_))
            | (Type::Cell(_), Type::LoobeanConstant(_)) => false,
            (Type::Cell(a), Type::Cell(b)) => self.cells_may_overlap(a, b, visiting),
            _ => true,
        };
        visiting.remove(&(left.clone(), right.clone()));
        result
    }

    fn cells_may_overlap(
        &self,
        left: &[TypeField],
        right: &[TypeField],
        visiting: &mut HashSet<(Type, Type)>,
    ) -> bool {
        if left.is_empty() || right.is_empty() {
            return false;
        }
        if left.len() == 1 || right.len() == 1 {
            let left = if left.len() == 1 {
                left[0].typ.clone()
            } else {
                Type::Cell(left.to_vec())
            };
            let right = if right.len() == 1 {
                right[0].typ.clone()
            } else {
                Type::Cell(right.to_vec())
            };
            return self.may_overlap(&left, &right, visiting);
        }
        self.may_overlap(&left[0].typ, &right[0].typ, visiting)
            && self.cells_may_overlap(&left[1..], &right[1..], visiting)
    }

    fn expanded_cases(&self, typ: &Type) -> Option<Vec<Type>> {
        let Type::Named {
            module,
            name,
            arguments,
        } = typ
        else {
            return None;
        };
        if *module != self.module.span.source {
            return None;
        }
        let mold = self.resolved_molds.get(name)?;
        let substitutions = mold
            .parameters
            .iter()
            .zip(arguments)
            .map(|(parameter, argument)| (parameter.id, argument.clone()))
            .collect::<BTreeMap<_, _>>();
        Some(
            mold.cases
                .iter()
                .map(|case| substitute(&case.typ, &substitutions))
                .collect(),
        )
    }

    fn infer_expression(
        &mut self,
        expression: &Expr,
        expected: Option<&Type>,
        variables: &mut BTreeMap<String, TypeVar>,
    ) -> Result<Type, Diagnostic> {
        match &expression.kind {
            ExprKind::Literal(literal) => self.infer_literal(literal, expected, expression.span),
            ExprKind::Crash => self.fit_or_error(Type::Void, expected, expression.span),
            ExprKind::Cast { mold, value } => {
                let target = self.resolve_mold(mold, variables, true, true)?;
                self.infer_expression(value, Some(&target), variables)?;
                if contains_unbound_variable(&target, &variables.values().copied().collect()) {
                    return Err(Diagnostic::at("unconstrained type hole", mold.span));
                }
                Ok(target)
            }
            ExprKind::Tuple(items) => {
                let expected_fields = match expected {
                    Some(Type::Cell(fields)) => Some(fields.as_slice()),
                    _ => None,
                };
                let mut faces = BTreeMap::new();
                let mut fields = Vec::new();
                for (index, item) in items.iter().enumerate() {
                    if let Some(face) = &item.face
                        && let Some(previous) = faces.insert(face, item.span)
                    {
                        return Err(Diagnostic::at(
                            format!("duplicate record field `{face}`"),
                            item.span,
                        )
                        .with_note("first field", previous));
                    }
                    let expected_item = expected_fields.and_then(|fields| fields.get(index));
                    if expected_fields.is_some_and(|fields| fields.len() != items.len()) {
                        return Err(type_mismatch(
                            Type::Cell(Vec::new()),
                            expected.cloned().unwrap_or(Type::Noun),
                            expression.span,
                        ));
                    }
                    let typ = self.infer_expression(
                        &item.value,
                        expected_item.map(|field| &field.typ),
                        variables,
                    )?;
                    fields.push(TypeField {
                        face: item.face.clone(),
                        typ,
                    });
                }
                let actual = if fields.len() == 1 && fields[0].face.is_none() {
                    fields.remove(0).typ
                } else {
                    Type::Cell(fields)
                };
                self.fit_or_error(actual, expected, expression.span)
            }
            ExprKind::Reference(names) if names.len() == 1 => Err(Diagnostic::at(
                "value reference inference is not implemented yet",
                expression.span,
            )),
            _ => Err(Diagnostic::at(
                "this expression is not available to the static checker yet",
                expression.span,
            )),
        }
    }

    fn infer_literal(
        &self,
        literal: &Literal,
        expected: Option<&Type>,
        span: Span,
    ) -> Result<Type, Diagnostic> {
        let actual = match literal {
            Literal::Number(number) => Type::Atom(Aura::new(match number.aura {
                NumberAura::Decimal => "ud",
                NumberAura::Hexadecimal => "ux",
                NumberAura::Base32 => "uv",
            })),
            Literal::String(_) => Type::Atom(Aura::new("t")),
            Literal::Ship(_) => Type::Atom(Aura::new("p")),
            Literal::Date(_) => Type::Atom(Aura::new("da")),
            Literal::Duration(_) => Type::Atom(Aura::new("dr")),
            Literal::Knot(_) => Type::Atom(Aura::new("ta")),
            Literal::Loobean(yes) => {
                if let Some(expected) = expected {
                    let value = BigUint::from(u8::from(!yes));
                    if self.loobean_fits_singleton(&value, expected) {
                        return Ok(expected.clone());
                    }
                }
                Type::Flag
            }
            Literal::Term(term) => {
                let actual = match term.kind {
                    TermKind::Named => Type::Constant(term.value.clone()),
                    TermKind::Numeric => Type::NumericTerm(term.value.clone()),
                };
                let Some(expected) = expected else {
                    return Err(Diagnostic::at(
                        "tag literal needs an expected type; add a `^-` cast",
                        span,
                    ));
                };
                if self.types_fit(&actual, expected) {
                    return Ok(expected.clone());
                }
                return Err(type_mismatch(actual, expected.clone(), span));
            }
            Literal::Null => {
                let actual = Type::Constant(BigUint::default());
                let Some(expected) = expected else {
                    return Err(Diagnostic::at(
                        "`~` needs an expected type; add a `^-` cast",
                        span,
                    ));
                };
                if self.types_fit(&actual, expected) {
                    return Ok(expected.clone());
                }
                return Err(type_mismatch(actual, expected.clone(), span));
            }
        };
        self.fit_or_error(actual, expected, span)
    }

    fn loobean_fits_singleton(&self, value: &BigUint, expected: &Type) -> bool {
        match expected {
            Type::Flag => true,
            Type::Constant(_) | Type::NumericTerm(_) | Type::LoobeanConstant(_) => {
                constant_value(expected) == Some(value)
            }
            Type::Named { .. } => self.expanded_cases(expected).is_some_and(|cases| {
                cases
                    .iter()
                    .any(|case| self.loobean_fits_singleton(value, case))
            }),
            _ => false,
        }
    }

    fn fit_or_error(
        &self,
        actual: Type,
        expected: Option<&Type>,
        span: Span,
    ) -> Result<Type, Diagnostic> {
        if let Some(expected) = expected
            && !self.types_fit(&actual, expected)
        {
            return Err(type_mismatch(actual, expected.clone(), span));
        }
        Ok(actual)
    }

    fn types_fit(&self, actual: &Type, expected: &Type) -> bool {
        if actual == expected || matches!(actual, Type::Void) || matches!(expected, Type::Noun) {
            return true;
        }
        if let (Some(actual), Some(expected)) = (constant_value(actual), constant_value(expected)) {
            return actual == expected;
        }
        match (actual, expected) {
            (_, Type::AnyAtom) => matches!(
                actual,
                Type::Atom(_)
                    | Type::AnyAtom
                    | Type::Constant(_)
                    | Type::NumericTerm(_)
                    | Type::LoobeanConstant(_)
                    | Type::Flag
            ),
            (Type::Atom(actual), Type::Atom(expected)) => actual.fits(expected),
            (Type::Flag, Type::Atom(aura)) => aura.0 == "f",
            (Type::LoobeanConstant(_), Type::Atom(aura)) => aura.0 == "f",
            (Type::Constant(_), Type::Atom(aura)) => aura.0 == "tas" || aura.0 == "ta",
            (Type::NumericTerm(_), Type::Atom(aura)) => {
                matches!(aura.0.as_str(), "tas" | "ta" | "ud" | "u")
            }
            (actual, Type::Flag) if constant_value(actual).is_some() => constant_value(actual)
                .is_some_and(|value| *value == BigUint::default() || *value == BigUint::from(1u8)),
            (Type::Cell(actual), Type::Cell(expected)) => {
                actual.len() == expected.len()
                    && actual.iter().zip(expected).all(|(actual, expected)| {
                        (actual.face == expected.face
                            || actual.face.is_none()
                            || expected.face.is_none())
                            && self.types_fit(&actual.typ, &expected.typ)
                    })
            }
            (
                Type::Gate {
                    sample: actual_sample,
                    product: actual_product,
                },
                Type::Gate {
                    sample: expected_sample,
                    product: expected_product,
                },
            ) => {
                self.types_fit(actual_sample, expected_sample)
                    && self.types_fit(actual_product, expected_product)
            }
            (Type::Named { .. }, _) => self
                .expanded_cases(actual)
                .is_some_and(|cases| cases.iter().all(|case| self.types_fit(case, expected))),
            (_, Type::Named { .. }) => self
                .expanded_cases(expected)
                .is_some_and(|cases| cases.iter().any(|case| self.types_fit(actual, case))),
            _ => false,
        }
    }

    fn fresh_variable(&mut self) -> TypeVar {
        let variable = self.next_variable;
        self.next_variable += 1;
        variable
    }
}

fn duplicate_name(name: &str, span: Span, previous: Span) -> Diagnostic {
    Diagnostic::at(format!("duplicate definition `{name}`"), span)
        .with_note("first definition", previous)
}

fn type_mismatch(actual: Type, expected: Type, span: Span) -> Diagnostic {
    Diagnostic::at(
        format!(
            "type mismatch: expected {}, found {}",
            TypeScheme::mono(expected),
            TypeScheme::mono(actual)
        ),
        span,
    )
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

fn constant_value(typ: &Type) -> Option<&BigUint> {
    match typ {
        Type::Constant(value) | Type::NumericTerm(value) | Type::LoobeanConstant(value) => {
            Some(value)
        }
        _ => None,
    }
}

fn contains_unbound_variable(typ: &Type, declared: &BTreeSet<TypeVar>) -> bool {
    match typ {
        Type::Var(variable) => !declared.contains(variable),
        Type::Cell(fields) => fields
            .iter()
            .any(|field| contains_unbound_variable(&field.typ, declared)),
        Type::Gate { sample, product } => {
            contains_unbound_variable(sample, declared)
                || contains_unbound_variable(product, declared)
        }
        Type::Named { arguments, .. } => arguments
            .iter()
            .any(|argument| contains_unbound_variable(argument, declared)),
        _ => false,
    }
}
