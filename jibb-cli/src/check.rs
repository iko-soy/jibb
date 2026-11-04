use crate::{
    Diagnostic,
    ast::{
        Definition, DefinitionKind, Expr, ExprKind, Literal, Module, Mold, MoldDefinition,
        MoldKind, MoldPathSegment, NumberAura, Pattern, PatternKind, Sample, SampleKind, SourceId,
        Span, TermKind, TypedSegmentMold,
    },
    infer::Unifier,
    types::{
        Aura, ConstraintKind, PathSegmentType, QuantifiedVariable, Type, TypeField, TypeScheme,
        TypeVar,
    },
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

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PatternMatch {
    Full,
    Partial,
    None,
}

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
            self.validate_constraints()?;
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
            self.validate_constraints()?;
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
            self.validate_constraints()?;
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
            self.validate_constraints()?;
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

    fn validate_constraints(&mut self) -> Result<(), Diagnostic> {
        for (variable, kind, span) in self.unifier.constraint_sites() {
            let typ = self.unifier.resolve(&Type::Var(variable));
            if typ == Type::Var(variable) {
                continue;
            }
            self.require_constraint(&typ, kind, span)?;
        }
        Ok(())
    }

    fn require_constraint(
        &mut self,
        typ: &Type,
        kind: ConstraintKind,
        span: Span,
    ) -> Result<(), Diagnostic> {
        let mut visiting = HashSet::new();
        self.require_constraint_inner(typ, kind, span, &mut visiting)
    }

    fn require_constraint_inner(
        &mut self,
        typ: &Type,
        kind: ConstraintKind,
        span: Span,
        visiting: &mut HashSet<Type>,
    ) -> Result<(), Diagnostic> {
        let typ = self.unifier.normalize(typ);
        match &typ {
            Type::Var(variable) => {
                self.unifier.constrain_variable(*variable, kind, span);
                Ok(())
            }
            Type::Named { .. } => {
                if !visiting.insert(typ.clone()) {
                    return Ok(());
                }
                let cases = self.expanded_cases(&typ).ok_or_else(|| {
                    Diagnostic::at("constraint requires a known named mold", span)
                })?;
                for case in cases {
                    self.require_constraint_inner(&case, kind, span, visiting)?;
                }
                visiting.remove(&typ);
                Ok(())
            }
            Type::Cell(fields) if kind == ConstraintKind::GateFree => {
                for field in fields {
                    self.require_constraint_inner(&field.typ, kind, span, visiting)?;
                }
                Ok(())
            }
            Type::Void => Ok(()),
            Type::Path(_) if kind == ConstraintKind::GateFree => Ok(()),
            Type::Atom(aura) => {
                if kind == ConstraintKind::ArithmeticAtom && aura.0 == "f" {
                    Err(constraint_mismatch(kind, &typ, span))
                } else {
                    Ok(())
                }
            }
            Type::AnyAtom => {
                if kind == ConstraintKind::ArithmeticAtom {
                    Err(constraint_mismatch(kind, &typ, span))
                } else {
                    Ok(())
                }
            }
            Type::Flag | Type::LoobeanConstant(_) => {
                if kind == ConstraintKind::ArithmeticAtom {
                    Err(constraint_mismatch(kind, &typ, span))
                } else {
                    Ok(())
                }
            }
            Type::Constant(_) | Type::NumericTerm(_) => Ok(()),
            Type::Noun | Type::Gate { .. } | Type::Cell(_) | Type::Path(_) => {
                Err(constraint_mismatch(kind, &typ, span))
            }
        }
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
            ExprKind::Reference(names) => {
                let typ = self.lookup_wing(names, expression.span, environment)?;
                self.fit_or_error(typ, expected, expression.span)
            }
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
            ExprKind::Constructor(tag) => {
                let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                let Some(Type::Gate { sample, product }) = resolved_expected else {
                    return Err(Diagnostic::at(
                        "constructor needs an expected gate type",
                        expression.span,
                    ));
                };
                let payload = self.pair_payload_type(tag, &product).ok_or_else(|| {
                    Diagnostic::at(
                        "constructor tag has no matching union case",
                        expression.span,
                    )
                })?;
                self.fit_or_error(*sample, Some(&payload), expression.span)?;
                self.fit_or_error(
                    Type::Gate {
                        sample: Box::new(payload),
                        product,
                    },
                    expected,
                    expression.span,
                )
            }
            ExprKind::Call { head, arguments } => {
                if let ExprKind::Reference(names) = &head.kind
                    && names.len() == 1
                    && matches!(names[0].as_str(), "proj" | "unface")
                {
                    if arguments.len() != 1 {
                        return Err(Diagnostic::at(
                            format!("`{}` takes one argument", names[0]),
                            expression.span,
                        ));
                    }
                    if names[0] == "unface" {
                        let typ =
                            self.infer_expression(&arguments[0], None, variables, environment)?;
                        let typ = unface_type(&typ);
                        return self.fit_or_error(typ, expected, expression.span);
                    }
                    let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                    let Some(expected_type) = resolved_expected else {
                        return Err(Diagnostic::at(
                            "`proj` needs an expected record type",
                            expression.span,
                        ));
                    };
                    let fields = self.projection_fields(&expected_type).ok_or_else(|| {
                        Diagnostic::at("`proj` needs an expected record type", expression.span)
                    })?;
                    let source =
                        self.infer_expression(&arguments[0], None, variables, environment)?;
                    for field in fields {
                        let Some(face) = &field.face else {
                            return Err(Diagnostic::at(
                                "`proj` result fields must be named",
                                expression.span,
                            ));
                        };
                        let source_type = self.record_field(&source, face, expression.span)?;
                        self.fit_or_error(source_type, Some(&field.typ), expression.span)?;
                    }
                    return Ok(expected_type);
                }
                let head_expected = if matches!(head.kind, ExprKind::Constructor(_)) {
                    expected.map(|product| Type::Gate {
                        sample: Box::new(Type::Var(self.fresh_variable())),
                        product: Box::new(product.clone()),
                    })
                } else {
                    None
                };
                let head_type =
                    self.infer_expression(head, head_expected.as_ref(), variables, environment)?;
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
            ExprKind::List(items) => {
                let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                let element = resolved_expected
                    .as_ref()
                    .and_then(|typ| self.container_element(typ, "list"));
                if resolved_expected.is_some() && element.is_none() {
                    return Err(Diagnostic::at(
                        "list literal needs an expected list type",
                        expression.span,
                    ));
                }
                let element = element.unwrap_or_else(|| Type::Var(self.fresh_variable()));
                let target = match resolved_expected {
                    Some(typ) => typ,
                    None => self
                        .local_generic_type("list", element.clone())
                        .ok_or_else(|| {
                            Diagnostic::at(
                                "list literal needs the standard list mold or an expected type",
                                expression.span,
                            )
                        })?,
                };
                for item in items {
                    self.infer_expression(item, Some(&element), variables, environment)?;
                }
                self.fit_or_error(target, expected, expression.span)
            }
            ExprKind::Unit(value) => {
                let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                let payload = resolved_expected
                    .as_ref()
                    .and_then(|typ| self.container_element(typ, "unit"));
                let value =
                    self.infer_expression(value, payload.as_ref(), variables, environment)?;
                let actual = Type::Cell(vec![
                    TypeField {
                        face: None,
                        typ: Type::Constant(BigUint::default()),
                    },
                    TypeField {
                        face: None,
                        typ: value.clone(),
                    },
                ]);
                if expected.is_some() {
                    return self.fit_or_error(actual, expected, expression.span);
                }
                let target = self.local_generic_type("unit", value).ok_or_else(|| {
                    Diagnostic::at(
                        "unit literal needs the standard unit mold or an expected type",
                        expression.span,
                    )
                })?;
                Ok(target)
            }
            ExprKind::Pair { tag, value } => {
                let tag = BigUint::from_bytes_le(tag.as_bytes());
                let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                let Some(expected_type) = resolved_expected else {
                    return Err(Diagnostic::at(
                        "tagged pair needs an expected union type",
                        expression.span,
                    ));
                };
                let payload = self
                    .pair_payload_type(&tag, &expected_type)
                    .ok_or_else(|| {
                        Diagnostic::at("pair tag has no matching union case", expression.span)
                    })?;
                let value = self.infer_expression(value, Some(&payload), variables, environment)?;
                self.fit_or_error(
                    Type::Cell(vec![
                        TypeField {
                            face: None,
                            typ: Type::Constant(tag),
                        },
                        TypeField {
                            face: None,
                            typ: value,
                        },
                    ]),
                    expected,
                    expression.span,
                )
            }
            ExprKind::Change { target, edits } => {
                let target_type = self.lookup_wing(target, expression.span, environment)?;
                if edits.is_empty() {
                    return Err(Diagnostic::at(
                        "a record change needs an edit",
                        expression.span,
                    ));
                }
                let mut previous = Vec::<Vec<String>>::new();
                for edit in edits {
                    if previous.iter().any(|field| {
                        field == &edit.field
                            || field.starts_with(&edit.field)
                            || edit.field.starts_with(field)
                    }) {
                        return Err(Diagnostic::at(
                            "record change has duplicate or overlapping edits",
                            edit.span,
                        ));
                    }
                    let field_type = self.record_wing(&target_type, &edit.field, edit.span)?;
                    self.infer_expression(&edit.value, Some(&field_type), variables, environment)?;
                    previous.push(edit.field.clone());
                }
                self.fit_or_error(target_type, expected, expression.span)
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
                for part in parts {
                    if let crate::ast::StringPart::Expr(value) = part {
                        let typ = self.infer_expression(value, None, variables, environment)?;
                        self.require_printable(&typ, value.span)?;
                    }
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
            ExprKind::Branch { subject, arms } => self.infer_branch(
                subject,
                arms,
                expected,
                variables,
                environment,
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

    fn infer_branch(
        &mut self,
        subject: &Expr,
        arms: &[crate::ast::Arm],
        expected: Option<&Type>,
        variables: &mut BTreeMap<String, TypeVar>,
        environment: &mut Environment,
        span: Span,
    ) -> Result<Type, Diagnostic> {
        let subject_type = self.infer_expression(subject, None, variables, environment)?;
        let subject_type = self.unifier.normalize(&subject_type);
        if matches!(subject_type, Type::Var(_)) {
            return Err(Diagnostic::at(
                "branch subject needs a known type",
                subject.span,
            ));
        }
        if arms.is_empty() {
            return Err(Diagnostic::at("branch has no arms", span));
        }
        let original_cases = self
            .pattern_cases(&subject_type)
            .ok_or_else(|| Diagnostic::at("branch subject needs a known type", subject.span))?;
        let mut remaining = original_cases.clone();
        let mut previous_patterns: Vec<&Pattern> = Vec::new();
        let result = expected
            .cloned()
            .unwrap_or_else(|| Type::Var(self.fresh_variable()));

        for arm in arms {
            let matching = original_cases
                .iter()
                .filter(|case| self.pattern_match(&arm.pattern, case) != PatternMatch::None)
                .cloned()
                .collect::<Vec<_>>();
            if matching.is_empty() {
                return Err(Diagnostic::at(
                    "pattern does not match the branch subject",
                    arm.pattern.span,
                ));
            }
            if previous_patterns
                .iter()
                .any(|previous| self.pattern_covers(previous, &arm.pattern))
            {
                return Err(Diagnostic::at(
                    "branch arm is covered by earlier arms",
                    arm.pattern.span,
                ));
            }
            if !remaining
                .iter()
                .any(|case| self.pattern_match(&arm.pattern, case) != PatternMatch::None)
            {
                return Err(Diagnostic::at(
                    "branch arm is covered by earlier arms",
                    arm.pattern.span,
                ));
            }
            let mut arm_environment = environment.clone();
            self.bind_pattern(
                &arm.pattern,
                &matching,
                &subject_type,
                true,
                &mut arm_environment,
            )?;
            self.infer_expression(&arm.body, Some(&result), variables, &mut arm_environment)?;
            remaining.retain(|case| self.pattern_match(&arm.pattern, case) != PatternMatch::Full);
            previous_patterns.push(&arm.pattern);
        }

        if let Some(missing) = remaining.first() {
            return Err(Diagnostic::at(
                format!(
                    "nonexhaustive branch: missing case {}",
                    TypeScheme::mono(missing.clone())
                ),
                span,
            )
            .with_note("branch subject", subject.span));
        }
        let result = self.unifier.normalize(&result);
        self.fit_or_error(result, expected, span)
    }

    fn pattern_cases(&self, typ: &Type) -> Option<Vec<Type>> {
        self.finite_product_cases(typ, 0)
    }

    fn finite_product_cases(&self, typ: &Type, depth: usize) -> Option<Vec<Type>> {
        let cases = match typ {
            Type::Named { .. } if depth < 8 => {
                let mut cases = Vec::new();
                for case in self.expanded_cases(typ)? {
                    cases.extend(self.finite_product_cases(&case, depth + 1)?);
                }
                cases
            }
            Type::Named { .. } => vec![typ.clone()],
            Type::Flag => vec![
                Type::LoobeanConstant(BigUint::default()),
                Type::LoobeanConstant(BigUint::from(1u8)),
            ],
            Type::Void => Vec::new(),
            Type::Var(_) => return None,
            Type::Cell(fields) if fields.len() == 1 => {
                return self.finite_product_cases(&fields[0].typ, depth);
            }
            Type::Cell(fields) => {
                let mut rows = vec![Vec::new()];
                for field in fields {
                    let variants = self.finite_product_cases(&field.typ, depth)?;
                    let mut next = Vec::new();
                    for row in &rows {
                        for typ in &variants {
                            let mut row = row.clone();
                            row.push(TypeField {
                                face: field.face.clone(),
                                typ: typ.clone(),
                            });
                            next.push(row);
                            if next.len() > 256 {
                                return None;
                            }
                        }
                    }
                    rows = next;
                }
                rows.into_iter().map(Type::Cell).collect()
            }
            _ => vec![typ.clone()],
        };
        if cases.len() > 256 { None } else { Some(cases) }
    }

    fn pattern_covers(&self, earlier: &Pattern, later: &Pattern) -> bool {
        match (&earlier.kind, &later.kind) {
            (PatternKind::Binding(_) | PatternKind::Wildcard, _) => true,
            (_, PatternKind::Binding(_) | PatternKind::Wildcard) => false,
            (PatternKind::Literal(earlier), PatternKind::Literal(later)) => {
                let earlier = literal_pattern_type(earlier);
                let later = literal_pattern_type(later);
                if let (Some(earlier), Some(later)) =
                    (constant_value(&earlier), constant_value(&later))
                {
                    earlier == later
                } else {
                    earlier == later
                }
            }
            (PatternKind::Cell(earlier), PatternKind::Cell(later)) => {
                earlier.len() == later.len()
                    && earlier
                        .iter()
                        .zip(later)
                        .all(|(earlier, later)| self.pattern_covers(earlier, later))
            }
            _ => false,
        }
    }

    fn pattern_match(&self, pattern: &Pattern, case: &Type) -> PatternMatch {
        match &pattern.kind {
            PatternKind::Binding(_) | PatternKind::Wildcard => PatternMatch::Full,
            PatternKind::Literal(literal) => {
                let actual = literal_pattern_type(literal);
                self.literal_pattern_match(&actual, case)
            }
            PatternKind::Cell(patterns) => {
                if let Some(projections) = self.project_cell_pattern(case, patterns.len()) {
                    let mut partial = false;
                    for (pattern, case) in patterns.iter().zip(projections) {
                        match self.pattern_match(pattern, &case) {
                            PatternMatch::Full => {}
                            PatternMatch::Partial => partial = true,
                            PatternMatch::None => return PatternMatch::None,
                        }
                    }
                    if partial {
                        PatternMatch::Partial
                    } else {
                        PatternMatch::Full
                    }
                } else {
                    match case {
                        Type::Noun | Type::Var(_) => PatternMatch::Partial,
                        Type::Named { .. } => {
                            let Some(cases) = self.expanded_cases(case) else {
                                return PatternMatch::None;
                            };
                            self.combine_pattern_matches(
                                &cases
                                    .iter()
                                    .map(|case| self.pattern_match(pattern, case))
                                    .collect::<Vec<_>>(),
                            )
                        }
                        _ => PatternMatch::None,
                    }
                }
            }
        }
    }

    fn literal_pattern_match(&self, actual: &Type, case: &Type) -> PatternMatch {
        if let (Some(actual), Some(case)) = (constant_value(actual), constant_value(case)) {
            return if actual == case {
                PatternMatch::Full
            } else {
                PatternMatch::None
            };
        }
        if let Type::Named { .. } = case {
            let Some(cases) = self.expanded_cases(case) else {
                return PatternMatch::None;
            };
            return self.combine_pattern_matches(
                &cases
                    .iter()
                    .map(|case| self.literal_pattern_match(actual, case))
                    .collect::<Vec<_>>(),
            );
        }
        if self.types_fit(actual, case) {
            PatternMatch::Partial
        } else {
            PatternMatch::None
        }
    }

    fn combine_pattern_matches(&self, matches: &[PatternMatch]) -> PatternMatch {
        if !matches.is_empty() && matches.iter().all(|result| *result == PatternMatch::Full) {
            PatternMatch::Full
        } else if matches.iter().any(|result| *result != PatternMatch::None) {
            PatternMatch::Partial
        } else {
            PatternMatch::None
        }
    }

    fn project_cell_pattern(&self, case: &Type, count: usize) -> Option<Vec<Type>> {
        match case {
            Type::Cell(fields) if fields.len() == 1 => {
                self.project_cell_pattern(&fields[0].typ, count)
            }
            Type::Cell(fields) if fields.len() >= count => {
                let mut projections = fields
                    .iter()
                    .take(count - 1)
                    .map(|field| field.typ.clone())
                    .collect::<Vec<_>>();
                if fields.len() == count {
                    projections.push(fields[count - 1].typ.clone());
                } else {
                    projections.push(Type::Cell(fields[count - 1..].to_vec()));
                }
                Some(projections)
            }
            Type::Noun => Some((0..count).map(|_| Type::Noun).collect()),
            Type::Named { .. } => {
                let cases = self.expanded_cases(case)?;
                if cases.len() == 1 {
                    self.project_cell_pattern(&cases[0], count)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    fn bind_pattern(
        &mut self,
        pattern: &Pattern,
        cases: &[Type],
        subject_type: &Type,
        top: bool,
        environment: &mut Environment,
    ) -> Result<(), Diagnostic> {
        match &pattern.kind {
            PatternKind::Wildcard | PatternKind::Literal(_) => Ok(()),
            PatternKind::Binding(name) => {
                self.reject_tag_binder(name, cases, pattern.span)?;
                let typ = if top {
                    subject_type.clone()
                } else {
                    let typ = Type::Var(self.fresh_variable());
                    for case in cases {
                        self.fit_or_error(case.clone(), Some(&typ), pattern.span)?;
                    }
                    typ
                };
                self.bind_pattern_name(name, &typ, pattern.span, environment)
            }
            PatternKind::Cell(patterns) => {
                let mut projections = Vec::new();
                for case in cases {
                    let projected =
                        self.project_cell_pattern(case, patterns.len())
                            .ok_or_else(|| {
                                Diagnostic::at(
                                    "cell pattern subject is not known to be a cell",
                                    pattern.span,
                                )
                            })?;
                    projections.push(projected);
                }
                for (index, pattern) in patterns.iter().enumerate() {
                    let cases = projections
                        .iter()
                        .map(|projection| projection[index].clone())
                        .collect::<Vec<_>>();
                    self.bind_pattern(pattern, &cases, subject_type, false, environment)?;
                }
                Ok(())
            }
        }
    }

    fn reject_tag_binder(&self, name: &str, cases: &[Type], span: Span) -> Result<(), Diagnostic> {
        let value = BigUint::from_bytes_le(name.as_bytes());
        if cases.iter().any(|case| self.case_has_tag(case, &value)) {
            return Err(Diagnostic::at(
                format!("pattern binder `{name}` spells a tag at this position"),
                span,
            ));
        }
        Ok(())
    }

    fn case_has_tag(&self, case: &Type, value: &BigUint) -> bool {
        match case {
            Type::Constant(constant) => constant == value,
            Type::Named { .. } => self
                .expanded_cases(case)
                .is_some_and(|cases| cases.iter().any(|case| self.case_has_tag(case, value))),
            _ => false,
        }
    }

    fn bind_pattern_name(
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
                format!("pattern binder `{name}` shadows a name"),
                span,
            ));
        }
        environment.insert(name.to_string(), Binding::Monomorphic(typ.clone()));
        Ok(())
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

    fn container_element(&self, typ: &Type, container: &str) -> Option<Type> {
        match typ {
            Type::Named {
                name, arguments, ..
            } if name == container && arguments.len() == 1 => arguments.first().cloned(),
            Type::Named { .. } => {
                let cases = self.expanded_cases(typ)?;
                if cases.len() == 1 {
                    self.container_element(&cases[0], container)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    fn local_generic_type(&self, name: &str, element: Type) -> Option<Type> {
        let (definition, _) = self.mold_definitions.get(name)?;
        if definition
            .generic
            .as_ref()
            .is_none_or(|generic| generic.variables.len() != 1)
        {
            return None;
        }
        Some(Type::Named {
            module: self.module.span.source,
            name: name.to_string(),
            arguments: vec![element],
        })
    }

    fn pair_payload_type(&self, tag: &BigUint, typ: &Type) -> Option<Type> {
        match typ {
            Type::Cell(fields) if fields.len() == 2 => {
                if constant_value(&fields[0].typ) == Some(tag) {
                    Some(fields[1].typ.clone())
                } else {
                    None
                }
            }
            Type::Named { .. } => self
                .expanded_cases(typ)?
                .iter()
                .find_map(|case| self.pair_payload_type(tag, case)),
            _ => None,
        }
    }

    fn lookup_wing(
        &mut self,
        names: &[String],
        span: Span,
        environment: &Environment,
    ) -> Result<Type, Diagnostic> {
        let Some(name) = names.first() else {
            return Err(Diagnostic::at("empty wing", span));
        };
        let mut typ = self.lookup_reference(name, span, environment)?;
        for name in &names[1..] {
            typ = self.record_field(&typ, name, span)?;
        }
        Ok(typ)
    }

    fn record_wing(
        &mut self,
        typ: &Type,
        names: &[String],
        span: Span,
    ) -> Result<Type, Diagnostic> {
        let mut typ = typ.clone();
        for name in names {
            typ = self.record_field(&typ, name, span)?;
        }
        Ok(typ)
    }

    fn projection_fields(&self, typ: &Type) -> Option<Vec<TypeField>> {
        match typ {
            Type::Cell(fields) => Some(fields.clone()),
            Type::Named { .. } => {
                let cases = self.expanded_cases(typ)?;
                if cases.len() == 1 {
                    self.projection_fields(&cases[0])
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    fn record_field(&mut self, typ: &Type, name: &str, span: Span) -> Result<Type, Diagnostic> {
        let typ = self.unifier.normalize(typ);
        match &typ {
            Type::Cell(fields) => fields
                .iter()
                .find(|field| field.face.as_deref() == Some(name))
                .map(|field| field.typ.clone())
                .ok_or_else(|| Diagnostic::at(format!("record has no field `{name}`"), span)),
            Type::Named { .. } => {
                let cases = self
                    .expanded_cases(&typ)
                    .ok_or_else(|| Diagnostic::at("field access needs a known record", span))?;
                if cases.len() != 1 {
                    return Err(Diagnostic::at(
                        "field access needs a single record type",
                        span,
                    ));
                }
                self.record_field(&cases[0], name, span)
            }
            _ => Err(Diagnostic::at(
                format!(
                    "field access needs a record, found {}",
                    TypeScheme::mono(typ)
                ),
                span,
            )),
        }
    }

    fn lookup_reference(
        &mut self,
        name: &str,
        span: Span,
        environment: &Environment,
    ) -> Result<Type, Diagnostic> {
        if matches!(name, "proj" | "unface") {
            return Err(Diagnostic::at(
                format!("`{name}` is reserved and must be called with one argument"),
                span,
            ));
        }
        if let Some(binding) = environment.get(name).cloned() {
            return Ok(match binding {
                Binding::Monomorphic(typ) => self.unifier.normalize(&typ),
                Binding::Polymorphic(scheme) => self.unifier.instantiate(&scheme, span),
            });
        }
        if let Some(scheme) = self.values.get(name).cloned() {
            return Ok(self.unifier.instantiate(&scheme, span));
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

    fn require_printable(&mut self, typ: &Type, span: Span) -> Result<(), Diagnostic> {
        let typ = self.unifier.normalize(typ);
        match &typ {
            Type::Atom(_) | Type::AnyAtom | Type::Flag | Type::Void => Ok(()),
            Type::Named { .. } => {
                let cases = self
                    .expanded_cases(&typ)
                    .ok_or_else(|| Diagnostic::at("interpolation needs a known printer", span))?;
                if cases.len() == 1 {
                    self.require_printable(&cases[0], span)
                } else {
                    Err(Diagnostic::at(
                        "interpolation needs a single atom printer",
                        span,
                    ))
                }
            }
            _ if constant_value(&typ).is_some() => Ok(()),
            _ => Err(Diagnostic::at(
                format!(
                    "interpolation needs a printable atom, found {}",
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
            (Type::Var(variable), Type::AnyAtom) if self.unifier.has_atom_constraint(*variable) => {
                true
            }
            (Type::Atom(aura), Type::Var(variable))
                if self.unifier.has_atom_constraint(*variable)
                    && (aura.0 != "f"
                        || !self
                            .unifier
                            .has_constraint(*variable, ConstraintKind::ArithmeticAtom)) =>
            {
                true
            }
            (Type::Flag, Type::Var(variable))
                if self.unifier.has_constraint(*variable, ConstraintKind::Atom) =>
            {
                true
            }
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

fn constraint_mismatch(kind: ConstraintKind, typ: &Type, span: Span) -> Diagnostic {
    let requirement = match kind {
        ConstraintKind::Atom => "an atom",
        ConstraintKind::ArithmeticAtom => "an atom other than ?",
        ConstraintKind::GateFree => "a type containing no gates",
    };
    Diagnostic::at(
        format!(
            "type constraint requires {requirement}, found {}",
            TypeScheme::mono(typ.clone())
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

fn literal_pattern_type(literal: &Literal) -> Type {
    match literal {
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
        Literal::Term(term) => match term.kind {
            TermKind::Named => Type::Constant(term.value.clone()),
            TermKind::Numeric => Type::NumericTerm(term.value.clone()),
        },
        Literal::Loobean(yes) => Type::LoobeanConstant(BigUint::from(u8::from(!yes))),
        Literal::Null => Type::Constant(BigUint::default()),
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

#[cfg(test)]
mod tests {
    use super::*;

    fn prepare_molds<'a>(checker: &mut Checker<'a>) {
        checker.collect_scope().unwrap();
        let names = checker
            .mold_definitions
            .keys()
            .map(|name| (*name).to_string())
            .collect::<Vec<_>>();
        for name in names {
            let definition = checker.mold_definitions[name.as_str()].0.clone();
            let span = checker.mold_definitions[name.as_str()].1;
            let resolved = checker
                .resolve_mold_definition(&name, &definition, span)
                .unwrap();
            checker.resolved_molds.insert(name, resolved);
        }
    }

    #[test]
    fn checks_gate_free_constraints_through_named_generics() {
        let module = crate::parse_ast("+$ box |$ [A] [value=A]\n+$ gated $-(@ud @ud)\n").unwrap();
        let mut checker = Checker::new(&module);
        prepare_molds(&mut checker);
        let element = checker.unifier.fresh_rigid("A", Span::default());
        checker
            .require_constraint(
                &Type::Named {
                    module: SourceId::default(),
                    name: "box".to_string(),
                    arguments: vec![Type::Var(element)],
                },
                ConstraintKind::GateFree,
                Span::default(),
            )
            .unwrap();
        assert!(
            checker
                .unifier
                .constraint_sites()
                .iter()
                .any(|(variable, kind, _)| {
                    *variable == element && *kind == ConstraintKind::GateFree
                })
        );

        let error = checker
            .require_constraint(
                &Type::Named {
                    module: SourceId::default(),
                    name: "gated".to_string(),
                    arguments: Vec::new(),
                },
                ConstraintKind::GateFree,
                Span::default(),
            )
            .unwrap_err();
        assert!(error.message.contains("containing no gates"));
    }

    #[test]
    fn arithmetic_constraints_reject_loobeans_and_unrestricted_atoms() {
        let module = Module {
            imports: Vec::new(),
            definitions: Vec::new(),
            span: Span::default(),
        };
        let mut checker = Checker::new(&module);
        for typ in [Type::Flag, Type::AnyAtom, Type::Atom(Aura::new("f"))] {
            assert!(
                checker
                    .require_constraint(&typ, ConstraintKind::ArithmeticAtom, Span::default())
                    .is_err(),
                "{typ:?}"
            );
        }
        checker
            .require_constraint(
                &Type::Atom(Aura::new("ud")),
                ConstraintKind::ArithmeticAtom,
                Span::default(),
            )
            .unwrap();
        checker
            .require_constraint(&Type::Flag, ConstraintKind::Atom, Span::default())
            .unwrap();
    }

    #[test]
    fn constrained_variables_fit_without_monomorphizing() {
        let module = Module {
            imports: Vec::new(),
            definitions: Vec::new(),
            span: Span::default(),
        };
        let mut checker = Checker::new(&module);
        let arithmetic = checker.unifier.fresh_rigid("A", Span::default());
        checker.unifier.constrain_variable(
            arithmetic,
            ConstraintKind::ArithmeticAtom,
            Span::default(),
        );
        assert_eq!(
            checker
                .fit_or_error(
                    Type::Atom(Aura::new("ud")),
                    Some(&Type::Var(arithmetic)),
                    Span::default(),
                )
                .unwrap(),
            Type::Var(arithmetic)
        );
        assert_eq!(
            checker
                .fit_or_error(Type::Var(arithmetic), Some(&Type::AnyAtom), Span::default(),)
                .unwrap(),
            Type::AnyAtom
        );
        assert!(
            checker
                .fit_or_error(Type::Flag, Some(&Type::Var(arithmetic)), Span::default(),)
                .is_err()
        );

        let comparable = checker.unifier.fresh_rigid("B", Span::default());
        checker
            .unifier
            .constrain_variable(comparable, ConstraintKind::Atom, Span::default());
        assert_eq!(
            checker
                .fit_or_error(Type::Flag, Some(&Type::Var(comparable)), Span::default(),)
                .unwrap(),
            Type::Var(comparable)
        );
    }
}
