use crate::{
    Diagnostic,
    ast::{
        Definition, DefinitionKind, Expr, ExprKind, Literal, Module, Mold, MoldDefinition,
        MoldKind, MoldPathSegment, NumberAura, Sample, SampleKind, SourceId, Span, TermKind,
        TypedSegmentMold,
    },
    infer::Unifier,
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

#[derive(Clone, Debug)]
enum Binding {
    Monomorphic(Type),
    Polymorphic(TypeScheme),
}

type Environment = BTreeMap<String, Binding>;

struct Checker<'a> {
    module: &'a Module,
    mold_definitions: BTreeMap<&'a str, (&'a MoldDefinition, Span)>,
    value_definitions: BTreeMap<&'a str, Span>,
    resolved_molds: BTreeMap<String, ResolvedMold>,
    values: BTreeMap<String, TypeScheme>,
    unifier: Unifier,
    holes: BTreeMap<TypeVar, Span>,
    local_scopes: Vec<BTreeSet<String>>,
}

impl<'a> Checker<'a> {
    fn new(module: &'a Module) -> Self {
        Self {
            module,
            mold_definitions: BTreeMap::new(),
            value_definitions: BTreeMap::new(),
            resolved_molds: BTreeMap::new(),
            values: BTreeMap::new(),
            unifier: Unifier::default(),
            holes: BTreeMap::new(),
            local_scopes: Vec::new(),
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
        self.check_values()?;

        Ok(CheckedModule {
            source: self.module.span.source,
            values: self.values,
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
                let id = self.unifier.fresh_rigid(variable, generic.span);
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
            MoldKind::Hole if allow_holes => {
                let variable = self.fresh_variable();
                self.holes.insert(variable, mold.span);
                Ok(Type::Var(variable))
            }
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
                let variable = self.unifier.fresh_rigid(name, mold.span);
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

    fn check_values(&mut self) -> Result<(), Diagnostic> {
        let definitions = self
            .module
            .definitions
            .iter()
            .filter(|definition| matches!(definition.kind, DefinitionKind::Value(_)))
            .cloned()
            .collect::<Vec<_>>();
        let dependencies = value_dependencies(&definitions);
        for group in strongly_connected(&dependencies) {
            self.check_value_group(&group, &definitions, &dependencies)?;
        }
        Ok(())
    }

    fn check_value_group(
        &mut self,
        group: &[String],
        definitions: &[Definition],
        dependencies: &BTreeMap<String, BTreeSet<String>>,
    ) -> Result<(), Diagnostic> {
        let recursive = group.len() > 1
            || group.first().is_some_and(|name| {
                dependencies
                    .get(name)
                    .is_some_and(|dependencies| dependencies.contains(name))
            });
        if !recursive {
            let name = &group[0];
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(expression) = &definition.kind else {
                unreachable!()
            };
            let mut variables = BTreeMap::new();
            let mut environment = Environment::new();
            let typ = self.infer_expression(expression, None, &mut variables, &mut environment)?;
            let typ = self.unifier.normalize(&typ);
            self.ensure_holes_resolved(&typ)?;
            let scheme = self.unifier.generalize(&typ, &BTreeSet::new());
            self.values.insert(name.clone(), scheme);
            return Ok(());
        }

        let mut environment = Environment::new();
        let mut seeds = Vec::new();
        for name in group {
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(Expr {
                kind: ExprKind::Gate { sample, .. },
                ..
            }) = &definition.kind
            else {
                return Err(Diagnostic::at(
                    format!("non-gate value `{name}` depends on itself"),
                    definition.span,
                ));
            };
            let mut variables = BTreeMap::new();
            let mut sample_environment = Environment::new();
            let sample =
                self.infer_sample(sample, None, &mut variables, &mut sample_environment)?;
            let product = Type::Var(self.fresh_variable());
            let gate = Type::Gate {
                sample: Box::new(sample),
                product: Box::new(product.clone()),
            };
            environment.insert(name.clone(), Binding::Monomorphic(gate));
            seeds.push((name.clone(), product, variables, sample_environment));
        }

        for (name, product, variables, sample_environment) in &seeds {
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(Expr {
                kind: ExprKind::Gate { body, .. },
                ..
            }) = &definition.kind
            else {
                unreachable!()
            };
            let mut environment = environment.clone();
            environment.extend(sample_environment.clone());
            let mut variables = variables.clone();
            self.infer_expression(body, Some(product), &mut variables, &mut environment)?;
        }

        for (name, _, _, _) in seeds {
            let Some(Binding::Monomorphic(typ)) = environment.get(&name).cloned() else {
                unreachable!()
            };
            let typ = self.unifier.normalize(&typ);
            self.ensure_holes_resolved(&typ)?;
            let scheme = self.unifier.generalize(&typ, &BTreeSet::new());
            self.values.insert(name, scheme);
        }
        Ok(())
    }

    fn infer_local_definitions(
        &mut self,
        definitions: &[Definition],
        variables: &BTreeMap<String, TypeVar>,
        environment: &mut Environment,
    ) -> Result<(), Diagnostic> {
        let mut names = BTreeSet::new();
        for definition in definitions {
            if matches!(definition.name.as_str(), "proj" | "unface") {
                return Err(Diagnostic::at(
                    format!("`{}` is reserved", definition.name),
                    definition.span,
                ));
            }
            if matches!(definition.kind, DefinitionKind::Mold(_)) {
                return Err(Diagnostic::at(
                    "local mold definitions are not available to the static checker yet",
                    definition.span,
                ));
            }
            if self
                .value_definitions
                .contains_key(definition.name.as_str())
                || environment.contains_key(&definition.name)
                || !names.insert(definition.name.clone())
            {
                return Err(Diagnostic::at(
                    format!("local definition `{}` shadows a name", definition.name),
                    definition.span,
                ));
            }
        }
        let dependencies = value_dependencies(definitions);
        self.local_scopes.push(names);
        let result = (|| {
            for group in strongly_connected(&dependencies) {
                self.check_local_group(&group, definitions, &dependencies, variables, environment)?;
            }
            Ok(())
        })();
        self.local_scopes.pop();
        result
    }

    fn check_local_group(
        &mut self,
        group: &[String],
        definitions: &[Definition],
        dependencies: &BTreeMap<String, BTreeSet<String>>,
        outer_variables: &BTreeMap<String, TypeVar>,
        environment: &mut Environment,
    ) -> Result<(), Diagnostic> {
        let recursive = group.len() > 1
            || group.first().is_some_and(|name| {
                dependencies
                    .get(name)
                    .is_some_and(|dependencies| dependencies.contains(name))
            });
        let occupied = self.occupied_variables(environment, outer_variables);
        if !recursive {
            let name = &group[0];
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(expression) = &definition.kind else {
                unreachable!()
            };
            let mut variables = outer_variables.clone();
            let typ = self.infer_expression(expression, None, &mut variables, environment)?;
            let typ = self.unifier.normalize(&typ);
            self.ensure_holes_resolved(&typ)?;
            let scheme = self.unifier.generalize(&typ, &occupied);
            environment.insert(name.clone(), Binding::Polymorphic(scheme));
            return Ok(());
        }

        let mut group_environment = environment.clone();
        let mut seeds = Vec::new();
        for name in group {
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(Expr {
                kind: ExprKind::Gate { sample, .. },
                ..
            }) = &definition.kind
            else {
                return Err(Diagnostic::at(
                    format!("non-gate value `{name}` depends on itself"),
                    definition.span,
                ));
            };
            let mut variables = outer_variables.clone();
            let mut sample_environment = environment.clone();
            let sample =
                self.infer_sample(sample, None, &mut variables, &mut sample_environment)?;
            let product = Type::Var(self.fresh_variable());
            let gate = Type::Gate {
                sample: Box::new(sample),
                product: Box::new(product.clone()),
            };
            group_environment.insert(name.clone(), Binding::Monomorphic(gate));
            seeds.push((name.clone(), product, variables, sample_environment));
        }

        for (name, product, variables, sample_environment) in &seeds {
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(Expr {
                kind: ExprKind::Gate { body, .. },
                ..
            }) = &definition.kind
            else {
                unreachable!()
            };
            let mut body_environment = group_environment.clone();
            body_environment.extend(sample_environment.clone());
            let mut variables = variables.clone();
            self.infer_expression(body, Some(product), &mut variables, &mut body_environment)?;
        }

        for (name, _, _, _) in seeds {
            let Some(Binding::Monomorphic(typ)) = group_environment.get(&name).cloned() else {
                unreachable!()
            };
            let typ = self.unifier.normalize(&typ);
            self.ensure_holes_resolved(&typ)?;
            let scheme = self.unifier.generalize(&typ, &occupied);
            environment.insert(name, Binding::Polymorphic(scheme));
        }
        Ok(())
    }

    fn occupied_variables(
        &mut self,
        environment: &Environment,
        variables: &BTreeMap<String, TypeVar>,
    ) -> BTreeSet<TypeVar> {
        let mut occupied = variables.values().copied().collect::<BTreeSet<_>>();
        for binding in environment.values() {
            if let Binding::Monomorphic(typ) = binding {
                occupied.extend(self.unifier.free_variables_of(typ));
            }
        }
        occupied
    }

    fn ensure_holes_resolved(&mut self, typ: &Type) -> Result<(), Diagnostic> {
        let typ = self.unifier.normalize(typ);
        if let Some(variable) = find_hole(&typ, &self.holes) {
            return Err(Diagnostic::at(
                "unconstrained type hole",
                self.holes[&variable],
            ));
        }
        Ok(())
    }

    fn infer_expression(
        &mut self,
        expression: &Expr,
        expected: Option<&Type>,
        variables: &mut BTreeMap<String, TypeVar>,
        environment: &mut Environment,
    ) -> Result<Type, Diagnostic> {
        match &expression.kind {
            ExprKind::Literal(literal) => self.infer_literal(literal, expected, expression.span),
            ExprKind::Crash => self.fit_or_error(Type::Void, expected, expression.span),
            ExprKind::Cast { mold, value } => {
                let target = self.resolve_mold(mold, variables, true, true)?;
                self.infer_expression(value, Some(&target), variables, environment)?;
                let target = self.unifier.normalize(&target);
                self.ensure_holes_resolved(&target)?;
                Ok(target)
            }
            ExprKind::Reference(names) if names.len() == 1 => {
                let typ = self.lookup_reference(&names[0], expression.span, environment)?;
                self.fit_or_error(typ, expected, expression.span)
            }
            ExprKind::Reference(_) => Err(Diagnostic::at(
                "record and module wings are not available to the static checker yet",
                expression.span,
            )),
            ExprKind::Gate { sample, body } => {
                let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                let (expected_sample, expected_product) = match &resolved_expected {
                    Some(Type::Gate { sample, product }) => {
                        (Some(sample.as_ref()), Some(product.as_ref()))
                    }
                    _ => (None, None),
                };
                let sample = self.infer_sample(sample, expected_sample, variables, environment)?;
                let body = self.infer_expression(body, expected_product, variables, environment)?;
                self.fit_or_error(
                    Type::Gate {
                        sample: Box::new(sample),
                        product: Box::new(body),
                    },
                    expected,
                    expression.span,
                )
            }
            ExprKind::Call { head, arguments } => {
                let head_type = self.infer_expression(head, None, variables, environment)?;
                let (sample, product) = self.gate_parts(&head_type, head.span)?;
                let resolved_sample = self.unifier.normalize(&sample);
                let expected_arguments = match &resolved_sample {
                    Type::Cell(fields) if fields.len() == arguments.len() => {
                        Some(fields.as_slice())
                    }
                    _ => None,
                };
                let mut argument_types = Vec::new();
                for (index, argument) in arguments.iter().enumerate() {
                    let expected = expected_arguments.map(|fields| &fields[index].typ);
                    argument_types.push(self.infer_expression(
                        argument,
                        expected,
                        variables,
                        environment,
                    )?);
                }
                let argument = if argument_types.len() == 1 {
                    argument_types.remove(0)
                } else {
                    Type::Cell(
                        argument_types
                            .into_iter()
                            .map(|typ| TypeField { face: None, typ })
                            .collect(),
                    )
                };
                self.fit_or_error(argument, Some(&sample), expression.span)?;
                let product = self.unifier.normalize(&product);
                self.fit_or_error(product, expected, expression.span)
            }
            ExprKind::Tuple(items) => {
                let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                let expected_fields = match &resolved_expected {
                    Some(Type::Cell(fields)) if fields.len() == items.len() => {
                        Some(fields.as_slice())
                    }
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
                    let expected_item = expected_fields.map(|fields| &fields[index].typ);
                    let typ =
                        self.infer_expression(&item.value, expected_item, variables, environment)?;
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
            ExprKind::String(parts) => {
                if parts
                    .iter()
                    .any(|part| matches!(part, crate::ast::StringPart::Expr(_)))
                {
                    return Err(Diagnostic::at(
                        "string interpolation is not available to the static checker yet",
                        expression.span,
                    ));
                }
                self.fit_or_error(Type::Atom(Aura::new("t")), expected, expression.span)
            }
            ExprKind::Path(segments) => self.fit_or_error(
                Type::Path(
                    segments
                        .iter()
                        .map(|segment| PathSegmentType::Knot(segment.clone()))
                        .collect(),
                ),
                expected,
                expression.span,
            ),
            ExprKind::Trace { value, body } => {
                self.infer_expression(value, None, variables, environment)?;
                self.infer_expression(body, expected, variables, environment)
            }
            ExprKind::Body {
                definitions,
                result,
            } => {
                self.infer_local_definitions(definitions, variables, environment)?;
                self.infer_expression(result, expected, variables, environment)
            }
            _ => Err(Diagnostic::at(
                "this expression is not available to the static checker yet",
                expression.span,
            )),
        }
    }

    fn infer_sample(
        &mut self,
        sample: &Sample,
        expected: Option<&Type>,
        variables: &mut BTreeMap<String, TypeVar>,
        environment: &mut Environment,
    ) -> Result<Type, Diagnostic> {
        if let SampleKind::Cell(samples) = &sample.kind {
            let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
            let expected_fields = match &resolved_expected {
                Some(Type::Cell(fields)) if fields.len() == samples.len() => {
                    Some(fields.as_slice())
                }
                _ => None,
            };
            let mut fields = Vec::new();
            for (index, sample) in samples.iter().enumerate() {
                let expected = expected_fields.map(|fields| &fields[index].typ);
                fields.push(self.infer_sample_field(sample, expected, variables, environment)?);
            }
            let typ = if fields.len() == 1 && fields[0].face.is_none() {
                fields.remove(0).typ
            } else {
                Type::Cell(fields)
            };
            return self.fit_or_error(typ, expected, sample.span);
        }
        let field = self.infer_sample_field(sample, expected, variables, environment)?;
        Ok(field.typ)
    }

    fn infer_sample_field(
        &mut self,
        sample: &Sample,
        expected: Option<&Type>,
        variables: &mut BTreeMap<String, TypeVar>,
        environment: &mut Environment,
    ) -> Result<TypeField, Diagnostic> {
        match &sample.kind {
            SampleKind::Binding(name) => {
                let typ = expected
                    .map(|typ| self.unifier.resolve(typ))
                    .unwrap_or_else(|| Type::Var(self.fresh_variable()));
                self.bind_sample(name, &typ, sample.span, environment)?;
                Ok(TypeField { face: None, typ })
            }
            SampleKind::Face { name, mold } => {
                let typ = self.resolve_mold(mold, variables, true, true)?;
                let typ = self.fit_or_error(typ, expected, sample.span)?;
                self.bind_sample(name, &typ, sample.span, environment)?;
                Ok(TypeField {
                    face: Some(name.clone()),
                    typ,
                })
            }
            SampleKind::Pun(name) => {
                let mold = Mold {
                    kind: MoldKind::Reference(vec![name.clone()]),
                    span: sample.span,
                };
                let typ = self.resolve_mold(&mold, variables, true, true)?;
                let typ = self.fit_or_error(typ, expected, sample.span)?;
                self.bind_sample(name, &typ, sample.span, environment)?;
                Ok(TypeField {
                    face: Some(name.clone()),
                    typ,
                })
            }
            SampleKind::Mold(mold) => {
                let typ = self.resolve_mold(mold, variables, true, true)?;
                let typ = self.fit_or_error(typ, expected, sample.span)?;
                Ok(TypeField { face: None, typ })
            }
            SampleKind::Cell(_) => {
                let typ = self.infer_sample(sample, expected, variables, environment)?;
                Ok(TypeField { face: None, typ })
            }
        }
    }

    fn bind_sample(
        &self,
        name: &str,
        typ: &Type,
        span: Span,
        environment: &mut Environment,
    ) -> Result<(), Diagnostic> {
        if matches!(name, "proj" | "unface") {
            return Err(Diagnostic::at(format!("`{name}` is reserved"), span));
        }
        if self.value_definitions.contains_key(name)
            || environment.contains_key(name)
            || self.local_scopes.iter().any(|scope| scope.contains(name))
        {
            return Err(Diagnostic::at(
                format!("sample binder `{name}` shadows a name"),
                span,
            ));
        }
        environment.insert(name.to_string(), Binding::Monomorphic(typ.clone()));
        Ok(())
    }

    fn lookup_reference(
        &mut self,
        name: &str,
        span: Span,
        environment: &Environment,
    ) -> Result<Type, Diagnostic> {
        if let Some(binding) = environment.get(name).cloned() {
            return Ok(match binding {
                Binding::Monomorphic(typ) => self.unifier.normalize(&typ),
                Binding::Polymorphic(scheme) => self.unifier.instantiate(&scheme),
            });
        }
        if let Some(scheme) = self.values.get(name).cloned() {
            return Ok(self.unifier.instantiate(&scheme));
        }
        Err(Diagnostic::at(format!("unknown value `{name}`"), span))
    }

    fn gate_parts(&mut self, typ: &Type, span: Span) -> Result<(Type, Type), Diagnostic> {
        let typ = self.unifier.normalize(typ);
        match typ {
            Type::Gate { sample, product } => Ok((*sample, *product)),
            Type::Var(_) => {
                let sample = Type::Var(self.fresh_variable());
                let product = Type::Var(self.fresh_variable());
                let gate = Type::Gate {
                    sample: Box::new(sample.clone()),
                    product: Box::new(product.clone()),
                };
                self.unifier.unify(&typ, &gate, span)?;
                Ok((sample, product))
            }
            Type::Named { .. } => {
                let cases = self.expanded_cases(&typ).ok_or_else(|| {
                    Diagnostic::at("called value does not have a known gate type", span)
                })?;
                if cases.len() != 1 {
                    return Err(Diagnostic::at("called mold is not a single gate", span));
                }
                self.gate_parts(&cases[0], span)
            }
            _ => Err(Diagnostic::at(
                format!(
                    "called value has type {}, not a gate",
                    TypeScheme::mono(typ)
                ),
                span,
            )),
        }
    }

    fn infer_literal(
        &mut self,
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
                    let resolved = self.unifier.resolve(expected);
                    let value = BigUint::from(u8::from(!yes));
                    if self.loobean_fits_singleton(&value, &resolved) {
                        return Ok(resolved);
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
                if matches!(self.unifier.resolve(expected), Type::Var(_)) {
                    return Err(Diagnostic::at(
                        "tag literal needs a known union or atom type; add a `^-` cast",
                        span,
                    ));
                }
                return self.fit_or_error(actual, Some(expected), span);
            }
            Literal::Null => {
                let actual = Type::Constant(BigUint::default());
                let Some(expected) = expected else {
                    return Err(Diagnostic::at(
                        "`~` needs an expected type; add a `^-` cast",
                        span,
                    ));
                };
                if matches!(self.unifier.resolve(expected), Type::Var(_)) {
                    return Err(Diagnostic::at(
                        "`~` needs a known union or atom type; add a `^-` cast",
                        span,
                    ));
                }
                return self.fit_or_error(actual, Some(expected), span);
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
        &mut self,
        actual: Type,
        expected: Option<&Type>,
        span: Span,
    ) -> Result<Type, Diagnostic> {
        let actual = self.unifier.normalize(&actual);
        let Some(expected) = expected else {
            return Ok(actual);
        };
        let expected = self.unifier.normalize(expected);
        if self.types_fit(&actual, &expected) {
            return Ok(expected);
        }
        if matches!(actual, Type::Var(_)) || matches!(expected, Type::Var(_)) {
            let typ = self.unifier.unify(&actual, &expected, span)?;
            return Ok(self.unifier.normalize(&typ));
        }
        Err(type_mismatch(actual, expected, span))
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
        self.unifier.fresh()
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

fn find_hole(typ: &Type, holes: &BTreeMap<TypeVar, Span>) -> Option<TypeVar> {
    match typ {
        Type::Var(variable) if holes.contains_key(variable) => Some(*variable),
        Type::Var(_) => None,
        Type::Cell(fields) => fields.iter().find_map(|field| find_hole(&field.typ, holes)),
        Type::Gate { sample, product } => {
            find_hole(sample, holes).or_else(|| find_hole(product, holes))
        }
        Type::Named { arguments, .. } => arguments
            .iter()
            .find_map(|argument| find_hole(argument, holes)),
        _ => None,
    }
}

fn value_definition<'a>(definitions: &'a [Definition], name: &str) -> &'a Definition {
    definitions
        .iter()
        .find(|definition| definition.name == name)
        .expect("dependency groups contain only value definitions")
}

fn value_dependencies(definitions: &[Definition]) -> BTreeMap<String, BTreeSet<String>> {
    let names = definitions
        .iter()
        .map(|definition| definition.name.clone())
        .collect::<BTreeSet<_>>();
    definitions
        .iter()
        .map(|definition| {
            let mut dependencies = BTreeSet::new();
            let DefinitionKind::Value(expression) = &definition.kind else {
                unreachable!()
            };
            collect_dependencies(expression, &names, &mut dependencies);
            (definition.name.clone(), dependencies)
        })
        .collect()
}

fn collect_dependencies(
    expression: &Expr,
    names: &BTreeSet<String>,
    dependencies: &mut BTreeSet<String>,
) {
    match &expression.kind {
        ExprKind::Reference(path) => {
            if let Some(name) = path.first()
                && names.contains(name)
            {
                dependencies.insert(name.clone());
            }
        }
        ExprKind::String(parts) => {
            for part in parts {
                if let crate::ast::StringPart::Expr(expression) = part {
                    collect_dependencies(expression, names, dependencies);
                }
            }
        }
        ExprKind::ApplicationPath(segments) => {
            for segment in segments {
                if let crate::ast::ApplicationSegment::Expr(expression) = segment {
                    collect_dependencies(expression, names, dependencies);
                }
            }
        }
        ExprKind::Call { head, arguments } => {
            collect_dependencies(head, names, dependencies);
            for argument in arguments {
                collect_dependencies(argument, names, dependencies);
            }
        }
        ExprKind::Gate { body, .. } | ExprKind::Cast { value: body, .. } => {
            collect_dependencies(body, names, dependencies);
        }
        ExprKind::Trace { value, body } => {
            collect_dependencies(value, names, dependencies);
            collect_dependencies(body, names, dependencies);
        }
        ExprKind::Branch { subject, arms } => {
            collect_dependencies(subject, names, dependencies);
            for arm in arms {
                collect_dependencies(&arm.body, names, dependencies);
            }
        }
        ExprKind::Body {
            definitions: local,
            result,
        } => {
            for definition in local {
                if let DefinitionKind::Value(expression) = &definition.kind {
                    collect_dependencies(expression, names, dependencies);
                }
            }
            collect_dependencies(result, names, dependencies);
        }
        ExprKind::List(expressions) => {
            for expression in expressions {
                collect_dependencies(expression, names, dependencies);
            }
        }
        ExprKind::Tuple(items) => {
            for item in items {
                collect_dependencies(&item.value, names, dependencies);
            }
        }
        ExprKind::Change { edits, .. } => {
            for edit in edits {
                collect_dependencies(&edit.value, names, dependencies);
            }
        }
        ExprKind::Pair { value, .. } | ExprKind::Unit(value) => {
            collect_dependencies(value, names, dependencies);
        }
        ExprKind::Literal(_) | ExprKind::Path(_) | ExprKind::Constructor(_) | ExprKind::Crash => {}
    }
}

fn strongly_connected(dependencies: &BTreeMap<String, BTreeSet<String>>) -> Vec<Vec<String>> {
    let mut tarjan = Tarjan {
        dependencies,
        next: 0,
        indices: BTreeMap::new(),
        low: BTreeMap::new(),
        stack: Vec::new(),
        on_stack: BTreeSet::new(),
        groups: Vec::new(),
    };
    for name in dependencies.keys() {
        if !tarjan.indices.contains_key(name) {
            tarjan.visit(name);
        }
    }
    tarjan.groups
}

struct Tarjan<'a> {
    dependencies: &'a BTreeMap<String, BTreeSet<String>>,
    next: usize,
    indices: BTreeMap<String, usize>,
    low: BTreeMap<String, usize>,
    stack: Vec<String>,
    on_stack: BTreeSet<String>,
    groups: Vec<Vec<String>>,
}

impl Tarjan<'_> {
    fn visit(&mut self, name: &str) {
        let index = self.next;
        self.next += 1;
        self.indices.insert(name.to_string(), index);
        self.low.insert(name.to_string(), index);
        self.stack.push(name.to_string());
        self.on_stack.insert(name.to_string());

        if let Some(dependencies) = self.dependencies.get(name) {
            for dependency in dependencies {
                if !self.indices.contains_key(dependency) {
                    self.visit(dependency);
                    let dependency_low = self.low[dependency];
                    let low = self.low[name].min(dependency_low);
                    self.low.insert(name.to_string(), low);
                } else if self.on_stack.contains(dependency) {
                    let dependency_index = self.indices[dependency];
                    let low = self.low[name].min(dependency_index);
                    self.low.insert(name.to_string(), low);
                }
            }
        }

        if self.low[name] == self.indices[name] {
            let mut group = Vec::new();
            loop {
                let member = self.stack.pop().expect("Tarjan stack is not empty");
                self.on_stack.remove(&member);
                group.push(member.clone());
                if member == name {
                    break;
                }
            }
            group.sort();
            self.groups.push(group);
        }
    }
}
