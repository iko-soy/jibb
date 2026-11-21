use crate::{
    Diagnostic,
    ast::{
        Definition, DefinitionKind, Expr, ExprKind, Item, Literal, Module, Mold, MoldDefinition,
        MoldField, MoldKind, MoldPathSegment, NumberAura, Pattern, PatternKind, Sample, SampleKind,
        SourceId, Span, TermKind, TypedSegmentMold,
    },
    infer::Unifier,
    types::{
        Aura, ConstraintKind, PathSegmentType, QuantifiedVariable, Type, TypeField, TypeScheme,
        TypeVar, spread_cell_fields,
    },
};
use num_bigint::BigUint;
use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};

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

/// One step into a cell: its head or its tail.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Step {
    Head,
    Tail,
}

/// How a checked value prints, in `{…}` or a trace, as the lowering's printer
/// natives print it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum Printer {
    /// An atom whose aura starts with `t`, spliced as its bytes.
    Text,
    /// A list of text atoms, spliced as their bytes.
    Tape,
    /// An atom printed by `scot` with this aura.
    Aura(String),
    /// A traced value of this type has no printer.
    Unavailable(String),
}

/// What the evaluator needs from the checked types, keyed by the address of
/// the expression it belongs to, so evaluation never rebuilds types.
#[derive(Clone, Debug, Default)]
pub(crate) struct Elaboration {
    /// The steps from a wing's base value to its field.
    pub(crate) wings: HashMap<usize, Vec<Step>>,
    /// A change's target steps, then the steps of each edited field.
    pub(crate) changes: HashMap<usize, (Vec<Step>, Vec<Vec<Step>>)>,
    /// The steps of each field `proj` selects, in the expected record's order.
    pub(crate) projections: HashMap<usize, Vec<Vec<Step>>>,
    /// The printer of an interpolated or traced expression.
    pub(crate) printers: HashMap<usize, Printer>,
}

pub(crate) fn expression_key(expression: &Expr) -> usize {
    std::ptr::from_ref(expression) as usize
}

pub fn check(module: &Module) -> Result<CheckedModule, Diagnostic> {
    crate::on_large_stack(|| Checker::new(module).check().map(|(checked, _)| checked))
}

/// Checks a module and returns what evaluation needs from its types. The
/// elaboration is keyed by the module's own expressions, so the caller must
/// evaluate this same module.
pub(crate) fn check_for_evaluation(
    module: &Module,
) -> Result<(CheckedModule, Elaboration), Diagnostic> {
    Checker::new(module).check()
}

#[derive(Clone, Debug)]
enum Binding {
    Monomorphic(Type),
    Polymorphic(TypeScheme),
    /// A gate of the recursive group being inferred: monomorphic, except that
    /// the capitals it introduces are instantiated at each reference.
    Group {
        typ: Type,
        capitals: Vec<TypeVar>,
    },
}

/// An interpolated or traced expression whose printer is chosen once its
/// definition's types are known.
#[derive(Clone)]
struct PendingPrinter {
    key: usize,
    typ: Type,
    span: Span,
    trace: bool,
}

/// A decimal literal waiting for its aura: it is a `@ud` unless its context
/// fixes another aura it fits, or its `++` is generic over it.
#[derive(Clone)]
struct PendingNumber {
    variable: TypeVar,
    value: BigUint,
    span: Span,
}

/// A tag, `~` or constructor waiting for the union its variable becomes.
#[derive(Clone)]
struct PendingTag {
    variable: TypeVar,
    kind: PendingTagKind,
    span: Span,
}

#[derive(Clone)]
enum PendingTagKind {
    Literal(Literal),
    Constructor { tag: BigUint, sample: Type },
}

/// Where a definition's pending items begin.
#[derive(Clone, Copy)]
struct Marks {
    numbers: usize,
    printers: usize,
    holes: usize,
}

type Environment = BTreeMap<String, Binding>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PatternMatch {
    Full,
    Partial,
    None,
}

#[derive(Clone)]
struct Checker<'a> {
    module: &'a Module,
    mold_definitions: BTreeMap<&'a str, (&'a MoldDefinition, Span)>,
    value_definitions: BTreeMap<&'a str, Span>,
    resolved_molds: BTreeMap<String, ResolvedMold>,
    values: BTreeMap<String, TypeScheme>,
    unifier: Unifier,
    holes: Vec<(TypeVar, Span)>,
    local_scopes: Vec<BTreeSet<String>>,
    local_mold_definitions: Vec<BTreeMap<String, (MoldDefinition, Span)>>,
    local_resolved_molds: Vec<BTreeMap<String, ResolvedMold>>,
    elaboration: Elaboration,
    pending_printers: Vec<PendingPrinter>,
    pending_numbers: Vec<PendingNumber>,
    pending_tags: Vec<PendingTag>,
    capital_instances: Vec<(TypeVar, TypeVar, Span)>,
    /// The file the definition being checked came from.
    origin: SourceId,
    /// Result variables of branches whose arms join their types.
    join_variables: HashSet<TypeVar>,
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
            holes: Vec::new(),
            local_scopes: Vec::new(),
            local_mold_definitions: Vec::new(),
            local_resolved_molds: Vec::new(),
            elaboration: Elaboration::default(),
            pending_printers: Vec::new(),
            pending_numbers: Vec::new(),
            pending_tags: Vec::new(),
            capital_instances: Vec::new(),
            origin: module.span.source,
            join_variables: HashSet::new(),
        }
    }

    /// Whether a top-level name defined at `span` is in scope where the
    /// current definition was written. Every file sees its own names and the
    /// prelude's; the prelude and imported modules do not see the names of
    /// the module that imports them.
    fn global_visible(&self, span: Span) -> bool {
        span.source != self.module.span.source || self.origin == self.module.span.source
    }

    fn global_value_visible(&self, name: &str) -> bool {
        self.value_definitions
            .get(name)
            .is_some_and(|span| self.global_visible(*span))
    }

    fn check(mut self) -> Result<(CheckedModule, Elaboration), Diagnostic> {
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
        self.resolve_pending_tags()?;
        if let Some(pending) = self.pending_tags.first() {
            return Err(Diagnostic::at(
                format!(
                    "nothing fixes the union of {}; add a `^-`",
                    pending_tag_text(&pending.kind)
                ),
                pending.span,
            ));
        }
        let values = self
            .values
            .iter()
            .map(|(name, scheme)| (name.clone(), self.unifier.normalize_scheme(scheme)))
            .collect();
        Ok((
            CheckedModule {
                source: self.module.span.source,
                values,
                molds: self.resolved_molds,
            },
            self.elaboration,
        ))
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
        self.resolve_scoped_mold_definition(name, definition, span, &BTreeMap::new())
    }

    /// Resolves a mold definition whose body may also name the capitals of
    /// the definition it is local to; its own `|$` parameters come first.
    fn resolve_scoped_mold_definition(
        &mut self,
        name: &str,
        definition: &MoldDefinition,
        span: Span,
        enclosing: &BTreeMap<String, TypeVar>,
    ) -> Result<ResolvedMold, Diagnostic> {
        let mut own = BTreeSet::new();
        let mut variables = enclosing.clone();
        let mut parameters = Vec::new();
        if let Some(generic) = &definition.generic {
            for variable in &generic.variables {
                if !own.insert(variable.clone()) {
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
                self.holes.push((variable, mold.span));
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
                TermKind::Boolean => Type::LoobeanConstant(term.value.clone()),
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
                let Some((definition, _)) = self.mold_definition(name) else {
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
                let Some((definition, _)) = self.mold_definition(name) else {
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
                if fields.is_empty() {
                    return Err(Diagnostic::at(
                        "an empty `[]` is not a valid mold",
                        mold.span,
                    ));
                }
                validate_record_mold_scope(fields)?;
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
            MoldKind::Union(cases) => Ok(Type::Union(
                cases
                    .iter()
                    .map(|case| {
                        self.resolve_mold(case, variables, allow_holes, allow_new_variables)
                    })
                    .collect::<Result<Vec<_>, _>>()?,
            )),
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

    fn mold_definition(&self, name: &str) -> Option<(MoldDefinition, Span)> {
        for scope in self.local_mold_definitions.iter().rev() {
            if let Some((definition, span)) = scope.get(name) {
                return Some((definition.clone(), *span));
            }
        }
        self.mold_definitions
            .get(name)
            .map(|(definition, span)| ((*definition).clone(), *span))
    }

    fn resolved_mold(&self, name: &str) -> Option<&ResolvedMold> {
        for scope in self.local_resolved_molds.iter().rev() {
            if let Some(mold) = scope.get(name) {
                return Some(mold);
            }
        }
        self.resolved_molds.get(name)
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
            self.validate_union(mold)?;
        }
        Ok(())
    }

    fn validate_union(&self, mold: &ResolvedMold) -> Result<(), Diagnostic> {
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
            (Type::Union(cases), _) => cases
                .iter()
                .any(|case| self.may_overlap(case, right, visiting)),
            (_, Type::Union(cases)) => cases
                .iter()
                .any(|case| self.may_overlap(left, case, visiting)),
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
        if let Type::Union(cases) = typ {
            return Some(cases.clone());
        }
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
        let mold = self.resolved_mold(name)?;
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

    fn transparent_case(&self, typ: &Type) -> Option<Type> {
        if !matches!(typ, Type::Named { .. }) {
            return None;
        }
        let cases = self.expanded_cases(typ)?;
        if cases.len() == 1 {
            cases.first().cloned()
        } else {
            None
        }
    }

    fn check_values(&mut self) -> Result<(), Diagnostic> {
        let module = self.module;
        let definitions = module
            .definitions
            .iter()
            .filter(|definition| matches!(definition.kind, DefinitionKind::Value(_)))
            .collect::<Vec<_>>();
        let dependencies = value_dependencies(&definitions);
        for group in strongly_connected(&dependencies) {
            self.origin = value_definition(&definitions, &group[0]).span.source;
            let schemes = self.check_group(
                &group,
                &definitions,
                &dependencies,
                &BTreeMap::new(),
                &Environment::new(),
                true,
            )?;
            self.values.extend(schemes);
        }
        Ok(())
    }

    fn recursive_product(
        &mut self,
        body: &Expr,
        variables: &mut BTreeMap<String, TypeVar>,
    ) -> Result<Type, Diagnostic> {
        if let ExprKind::Cast { mold, .. } = &body.kind {
            self.resolve_mold(mold, variables, true, true)
        } else {
            Ok(Type::Var(self.fresh_variable()))
        }
    }

    fn marks(&self) -> Marks {
        Marks {
            numbers: self.pending_numbers.len(),
            printers: self.pending_printers.len(),
            holes: self.holes.len(),
        }
    }

    /// Infers one dependency group of definitions in `environment`, the scope
    /// they are defined in, and generalizes them together. A recursive group
    /// is inferred with monomorphic references, except that each gate's own
    /// capitals are instantiated where another gate of the group uses it.
    fn check_group(
        &mut self,
        group: &[String],
        definitions: &[&Definition],
        dependencies: &BTreeMap<String, BTreeSet<String>>,
        outer_variables: &BTreeMap<String, TypeVar>,
        environment: &Environment,
        top: bool,
    ) -> Result<Vec<(String, TypeScheme)>, Diagnostic> {
        let marks = self.marks();
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
            let mut variables = outer_variables.clone();
            let mut local_environment = environment.clone();
            let typ =
                self.infer_expression(expression, None, &mut variables, &mut local_environment)?;
            let mut schemes =
                self.finish_definitions(&[typ], environment, outer_variables, marks, top)?;
            return Ok(vec![(name.clone(), schemes.remove(0))]);
        }

        let mut group_environment = environment.clone();
        let mut seeds = Vec::new();
        for name in group {
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(Expr {
                kind: ExprKind::Gate { sample, body },
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
            let product = self.recursive_product(body, &mut variables)?;
            let capitals = variables
                .iter()
                .filter(|(name, _)| !outer_variables.contains_key(*name))
                .map(|(_, variable)| *variable)
                .collect();
            let gate = Type::Gate {
                sample: Box::new(sample),
                product: Box::new(product.clone()),
            };
            group_environment.insert(
                name.clone(),
                Binding::Group {
                    typ: gate.clone(),
                    capitals,
                },
            );
            seeds.push((name.clone(), gate, product, variables, sample_environment));
        }

        let instances = self.capital_instances.len();
        for (name, gate, product, variables, sample_environment) in &seeds {
            let definition = value_definition(definitions, name);
            let DefinitionKind::Value(Expr {
                kind: ExprKind::Gate { body, .. },
                ..
            }) = &definition.kind
            else {
                unreachable!()
            };
            // In its own body a gate's capitals are rigid, so it calls itself
            // at one type; the other gates of its group are instantiated.
            let mut body_environment = group_environment.clone();
            body_environment.insert(name.clone(), Binding::Monomorphic(gate.clone()));
            body_environment.extend(sample_environment.clone());
            let mut variables = variables.clone();
            self.infer_expression(body, Some(product), &mut variables, &mut body_environment)?;
        }
        self.validate_capital_instances(instances)?;

        let types = seeds
            .iter()
            .map(|(_, gate, ..)| gate.clone())
            .collect::<Vec<_>>();
        let schemes = self.finish_definitions(&types, environment, outer_variables, marks, top)?;
        Ok(seeds
            .into_iter()
            .map(|(name, ..)| name)
            .zip(schemes)
            .collect())
    }

    /// A definition boundary: decimals take their default, tags and printers
    /// are resolved where their types are now known, and the types are
    /// generalized over the variables the enclosing scope does not share.
    fn finish_definitions(
        &mut self,
        types: &[Type],
        environment: &Environment,
        outer_variables: &BTreeMap<String, TypeVar>,
        marks: Marks,
        top: bool,
    ) -> Result<Vec<TypeScheme>, Diagnostic> {
        let mut occupied = self.occupied_variables(environment, outer_variables);
        let mut samples = BTreeSet::new();
        for typ in types {
            if let Type::Gate { sample, .. } = self.unifier.resolve(typ) {
                samples.extend(self.unifier.free_variables_of(&sample));
            }
        }
        self.resolve_pending_numbers(marks.numbers, &occupied, &samples, top)?;
        self.resolve_pending_tags()?;
        occupied.extend(self.pending_tag_variables());
        self.resolve_pending_printers(marks.printers, &occupied, top)?;
        self.resolve_holes(marks.holes, &occupied, top)?;
        self.validate_constraints()?;
        let mut schemes = Vec::new();
        for typ in types {
            let typ = self.unifier.normalize(typ);
            schemes.push(self.unifier.generalize(&typ, &occupied));
        }
        Ok(schemes)
    }

    /// A definition determines its own holes: each must have become a type,
    /// or a capital, once the definition is inferred. A hole the enclosing
    /// scope shares waits for that scope's boundary.
    fn resolve_holes(
        &mut self,
        mark: usize,
        occupied: &BTreeSet<TypeVar>,
        top: bool,
    ) -> Result<(), Diagnostic> {
        let holes = self.holes.split_off(mark);
        for (variable, span) in holes {
            if let Type::Var(variable) = self.unifier.resolve(&Type::Var(variable))
                && !self.unifier.is_rigid(variable)
            {
                if !top && occupied.contains(&variable) {
                    self.holes.push((variable, span));
                    continue;
                }
                return Err(Diagnostic::at("unconstrained type hole", span));
            }
        }
        Ok(())
    }

    fn resolve_pending_numbers(
        &mut self,
        mark: usize,
        occupied: &BTreeSet<TypeVar>,
        samples: &BTreeSet<TypeVar>,
        top: bool,
    ) -> Result<(), Diagnostic> {
        let pending = self.pending_numbers.split_off(mark);
        for number in pending {
            match self.unifier.resolve(&Type::Var(number.variable)) {
                Type::Var(variable) if self.unifier.is_rigid(variable) => {
                    if !top {
                        self.pending_numbers.push(number);
                    } else if !self.unifier.has_atom_constraint(variable) {
                        return Err(Diagnostic::at(
                            format!(
                                "capital `{}` cannot be fixed to @ud",
                                self.unifier.rigid_name(variable)
                            ),
                            number.span,
                        )
                        .with_note("capital", self.unifier.rigid_span(variable)));
                    }
                }
                Type::Var(variable) => {
                    if occupied.contains(&variable) && !top {
                        self.pending_numbers.push(number);
                    } else if !samples.contains(&variable) {
                        self.unifier.unify(
                            &Type::Var(variable),
                            &Type::Atom(Aura::new("ud")),
                            number.span,
                        )?;
                    }
                }
                typ => self.check_number_fits(&number, &typ)?,
            }
        }
        Ok(())
    }

    fn check_number_fits(&mut self, number: &PendingNumber, typ: &Type) -> Result<(), Diagnostic> {
        let typ = self.unifier.normalize(typ);
        if self.types_fit(&Type::Atom(Aura::new("ud")), &typ) {
            return Ok(());
        }
        Err(number_mismatch(&number.value, &typ, number.span))
    }

    fn pending_tag_variables(&mut self) -> Vec<TypeVar> {
        let variables = self
            .pending_tags
            .iter()
            .map(|tag| tag.variable)
            .collect::<Vec<_>>();
        variables
            .into_iter()
            .filter_map(
                |variable| match self.unifier.resolve(&Type::Var(variable)) {
                    Type::Var(variable) => Some(variable),
                    _ => None,
                },
            )
            .collect()
    }

    /// Checks each waiting tag whose union is now known.
    fn resolve_pending_tags(&mut self) -> Result<(), Diagnostic> {
        let pending = std::mem::take(&mut self.pending_tags);
        for tag in pending {
            let typ = self.unifier.resolve(&Type::Var(tag.variable));
            if matches!(typ, Type::Var(_)) {
                self.pending_tags.push(tag);
                continue;
            }
            match tag.kind {
                PendingTagKind::Literal(literal) => {
                    self.infer_literal(&literal, Some(&typ), tag.span)?;
                }
                PendingTagKind::Constructor { tag: value, sample } => {
                    let payload = self.pair_payload_type(&value, &typ).ok_or_else(|| {
                        Diagnostic::at("constructor tag has no matching union case", tag.span)
                    })?;
                    self.fit_or_error(sample, Some(&payload), tag.span)?;
                }
            }
        }
        Ok(())
    }

    fn resolve_pending_printers(
        &mut self,
        mark: usize,
        occupied: &BTreeSet<TypeVar>,
        top: bool,
    ) -> Result<(), Diagnostic> {
        let pending = self.pending_printers.split_off(mark);
        for printer in pending {
            let typ = self.unifier.normalize(&printer.typ);
            if !top
                && self
                    .unifier
                    .free_variables_of(&typ)
                    .iter()
                    .any(|variable| occupied.contains(variable))
            {
                self.pending_printers.push(printer);
                continue;
            }
            let selected = match self.printer_for(&typ, &mut BTreeSet::new()) {
                Some(selected) => selected,
                None if printer.trace => Printer::Unavailable(TypeScheme::mono(typ).to_string()),
                None => return Err(interpolation_error(&typ, printer.span)),
            };
            self.elaboration.printers.insert(printer.key, selected);
        }
        Ok(())
    }

    /// The printer the lowering would pick for a value of this type.
    fn printer_for(&self, typ: &Type, visiting: &mut BTreeSet<String>) -> Option<Printer> {
        match typ {
            Type::Atom(aura) if aura.0.starts_with('t') => Some(Printer::Text),
            Type::Atom(aura) => Some(Printer::Aura(aura.0.clone())),
            Type::AnyAtom | Type::NumericTerm(_) => Some(Printer::Aura("ud".to_string())),
            Type::Flag | Type::LoobeanConstant(_) => Some(Printer::Aura("f".to_string())),
            Type::Constant(_) | Type::Void => Some(Printer::Text),
            Type::Named { name, .. } => {
                if self.is_text_list(typ) {
                    return Some(Printer::Tape);
                }
                if !visiting.insert(name.clone()) {
                    return None;
                }
                let cases = self.expanded_cases(typ)?;
                let printer = match cases.as_slice() {
                    [case] => self.printer_for(case, visiting),
                    _ => None,
                };
                visiting.remove(name);
                printer
            }
            _ => None,
        }
    }

    /// A tape, by shape: a union of `~` and a cell of a `@tD` and the same
    /// list.
    fn is_text_list(&self, typ: &Type) -> bool {
        let Some(cases) = self.expanded_cases(typ) else {
            return false;
        };
        let [first, second] = cases.as_slice() else {
            return false;
        };
        let (nil, cell) = if constant_value(first).is_some() {
            (first, second)
        } else {
            (second, first)
        };
        if constant_value(nil) != Some(&BigUint::default()) {
            return false;
        }
        let Type::Cell(fields) = cell else {
            return false;
        };
        let [head, tail] = fields.as_slice() else {
            return false;
        };
        matches!(&head.typ, Type::Atom(aura) if aura.0 == "tD") && tail.typ == *typ
    }

    fn validate_capital_instances(&mut self, start: usize) -> Result<(), Diagnostic> {
        let instances = self.capital_instances.split_off(start);
        for (capital, instance, span) in instances {
            for kind in [
                ConstraintKind::Atom,
                ConstraintKind::ArithmeticAtom,
                ConstraintKind::GateFree,
            ] {
                if self.unifier.has_constraint(capital, kind) {
                    let typ = self.unifier.resolve(&Type::Var(instance));
                    self.require_constraint(&typ, kind, span)?;
                }
            }
        }
        Ok(())
    }

    fn infer_local_definitions(
        &mut self,
        definitions: &[Definition],
        variables: &BTreeMap<String, TypeVar>,
        environment: &mut Environment,
    ) -> Result<(), Diagnostic> {
        let mut value_names = BTreeSet::new();
        let mut mold_definitions = BTreeMap::new();
        for definition in definitions {
            if matches!(definition.name.as_str(), "proj" | "unface") {
                return Err(Diagnostic::at(
                    format!("`{}` is reserved", definition.name),
                    definition.span,
                ));
            }
            match &definition.kind {
                DefinitionKind::Value(_) => {
                    if self.global_value_visible(&definition.name)
                        || environment.contains_key(&definition.name)
                        || !value_names.insert(definition.name.clone())
                    {
                        return Err(Diagnostic::at(
                            format!("local definition `{}` shadows a name", definition.name),
                            definition.span,
                        ));
                    }
                }
                DefinitionKind::Mold(mold) => {
                    if self
                        .mold_definition(&definition.name)
                        .is_some_and(|(_, span)| self.global_visible(span))
                        || mold_definitions
                            .insert(definition.name.clone(), ((*mold).clone(), definition.span))
                            .is_some()
                    {
                        return Err(Diagnostic::at(
                            format!("local mold `{}` shadows a name", definition.name),
                            definition.span,
                        ));
                    }
                }
            }
        }

        self.local_scopes.push(value_names);
        self.local_mold_definitions.push(mold_definitions);
        self.local_resolved_molds.push(BTreeMap::new());
        let value_definitions = definitions
            .iter()
            .filter(|definition| matches!(definition.kind, DefinitionKind::Value(_)))
            .collect::<Vec<_>>();
        let result = (|| {
            let mold_names = self
                .local_mold_definitions
                .last()
                .into_iter()
                .flat_map(|scope| scope.keys())
                .cloned()
                .collect::<Vec<_>>();
            for name in mold_names {
                let (definition, span) = self.mold_definition(&name).expect("local mold exists");
                let resolved =
                    self.resolve_scoped_mold_definition(&name, &definition, span, variables)?;
                self.local_resolved_molds
                    .last_mut()
                    .expect("local mold scope exists")
                    .insert(name, resolved);
            }
            for mold in self
                .local_resolved_molds
                .last()
                .into_iter()
                .flat_map(|scope| scope.values())
            {
                self.validate_union(mold)?;
            }
            let dependencies = value_dependencies(&value_definitions);
            let mut pending = strongly_connected_in_source_order(&dependencies, &value_definitions);
            while !pending.is_empty() {
                let mut waiting = Vec::new();
                let mut progressed = false;
                for group in pending {
                    let mut attempt = self.clone();
                    match attempt.check_group(
                        &group,
                        &value_definitions,
                        &dependencies,
                        variables,
                        environment,
                        false,
                    ) {
                        Ok(schemes) => {
                            *self = attempt;
                            for (name, scheme) in schemes {
                                environment.insert(name, Binding::Polymorphic(scheme));
                            }
                            progressed = true;
                        }
                        Err(error) => waiting.push((group, error)),
                    }
                }
                if waiting.is_empty() {
                    return Ok(());
                }
                if !progressed {
                    let (_, error) = waiting.remove(0);
                    return Err(error);
                }
                pending = waiting.into_iter().map(|(group, _)| group).collect();
            }
            Ok(())
        })();
        if result.is_err() {
            self.finish_local_definitions();
        }
        result
    }

    fn finish_local_definitions(&mut self) {
        self.local_scopes.pop();
        self.local_mold_definitions.pop();
        self.local_resolved_molds.pop();
    }

    /// A body's result may mention its own local molds; outside the body they
    /// are written out, as the full checker reports them, since their names
    /// are out of scope there. A recursive local mold cannot be written out.
    fn expand_escaping_local_molds(&mut self, typ: &Type, span: Span) -> Result<Type, Diagnostic> {
        let typ = self.unifier.normalize(typ);
        let Some(scope) = self.local_resolved_molds.last() else {
            return Ok(typ);
        };
        if !type_mentions_molds(&typ, &scope.keys().cloned().collect::<BTreeSet<_>>()) {
            return Ok(typ);
        }
        let scope = scope.clone();
        expand_molds(&typ, &scope, &mut Vec::new()).ok_or_else(|| {
            Diagnostic::at(
                "a recursive local mold cannot escape its lexical scope in an inferred type",
                span,
            )
        })
    }

    fn occupied_variables(
        &mut self,
        environment: &Environment,
        variables: &BTreeMap<String, TypeVar>,
    ) -> BTreeSet<TypeVar> {
        let mut occupied = variables.values().copied().collect::<BTreeSet<_>>();
        for binding in environment.values() {
            match binding {
                Binding::Monomorphic(typ) | Binding::Group { typ, .. } => {
                    occupied.extend(self.unifier.free_variables_of(typ));
                }
                Binding::Polymorphic(scheme) => {
                    let quantified = scheme
                        .variables
                        .iter()
                        .map(|variable| variable.id)
                        .collect::<BTreeSet<_>>();
                    occupied.extend(
                        self.unifier
                            .free_variables_of(&scheme.typ)
                            .into_iter()
                            .filter(|variable| !quantified.contains(variable)),
                    );
                }
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
            Type::Union(cases) => {
                for case in cases {
                    self.require_constraint_inner(case, kind, span, visiting)?;
                }
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
            Type::Constant(_) if kind == ConstraintKind::ArithmeticAtom => {
                Err(constraint_mismatch(kind, &typ, span))
            }
            Type::Constant(_) | Type::NumericTerm(_) => Ok(()),
            Type::Noun | Type::Gate { .. } | Type::Cell(_) | Type::Path(_) => {
                Err(constraint_mismatch(kind, &typ, span))
            }
        }
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
            ExprKind::Native(native) => {
                let scheme = crate::native::scheme(*native, self.module.span.source);
                let typ = self.unifier.instantiate(&scheme, expression.span);
                self.fit_or_error(typ, expected, expression.span)
            }
            ExprKind::Cast { mold, value } => {
                let target = self.resolve_mold(mold, variables, true, true)?;
                self.infer_expression(value, Some(&target), variables, environment)?;
                let target = self.unifier.normalize(&target);
                self.fit_or_error(target, expected, expression.span)
            }
            ExprKind::Reference(names) => {
                let (typ, steps) = self.lookup_wing(names, expression.span, environment)?;
                if names.len() > 1 {
                    self.elaboration
                        .wings
                        .insert(expression_key(expression), steps);
                }
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
                let resolved_expected = expected.map(|typ| {
                    let typ = self.unifier.resolve(typ);
                    self.transparent_case(&typ).unwrap_or(typ)
                });
                let (sample, product) = match resolved_expected {
                    Some(Type::Gate { sample, product }) => (*sample, *product),
                    Some(Type::Var(variable)) if !self.unifier.is_rigid(variable) => (
                        Type::Var(self.fresh_variable()),
                        Type::Var(self.fresh_variable()),
                    ),
                    None => (
                        Type::Var(self.fresh_variable()),
                        Type::Var(self.fresh_variable()),
                    ),
                    Some(_) => {
                        return Err(Diagnostic::at(
                            "constructor needs an expected gate type",
                            expression.span,
                        ));
                    }
                };
                let resolved_product = self.unifier.resolve(&product);
                if let Type::Var(variable) = resolved_product
                    && !self.unifier.is_rigid(variable)
                {
                    self.pending_tags.push(PendingTag {
                        variable,
                        kind: PendingTagKind::Constructor {
                            tag: tag.clone(),
                            sample: sample.clone(),
                        },
                        span: expression.span,
                    });
                    return self.fit_or_error(
                        Type::Gate {
                            sample: Box::new(sample),
                            product: Box::new(product),
                        },
                        expected,
                        expression.span,
                    );
                }
                let payload = self
                    .pair_payload_type(tag, &resolved_product)
                    .ok_or_else(|| {
                        Diagnostic::at(
                            "constructor tag has no matching union case",
                            expression.span,
                        )
                    })?;
                self.fit_or_error(sample, Some(&payload), expression.span)?;
                self.fit_or_error(
                    Type::Gate {
                        sample: Box::new(payload),
                        product: Box::new(product),
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
                    let mut selected = Vec::new();
                    for field in fields {
                        let Some(face) = &field.face else {
                            return Err(Diagnostic::at(
                                "`proj` result fields must be named",
                                expression.span,
                            ));
                        };
                        let (source_type, steps) =
                            self.record_field(&source, face, expression.span)?;
                        self.fit_or_error(source_type, Some(&field.typ), expression.span)?;
                        selected.push(steps);
                    }
                    self.elaboration
                        .projections
                        .insert(expression_key(expression), selected);
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
                    Type::Cell(fields) if arguments.len() > 1 => {
                        align_cell_fields(fields, arguments.len())
                    }
                    _ => None,
                };
                let mut argument_types = Vec::new();
                for (index, argument) in arguments.iter().enumerate() {
                    let expected = if arguments.len() == 1 {
                        Some(&resolved_sample)
                    } else {
                        expected_arguments.as_ref().map(|fields| &fields[index].typ)
                    };
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
                let resolved_expected = expected
                    .map(|typ| self.unifier.resolve(typ))
                    .filter(|typ| !self.is_flexible(typ));
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
                let resolved_expected = expected
                    .map(|typ| self.unifier.resolve(typ))
                    .filter(|typ| !self.is_flexible(typ));
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
                if resolved_expected.is_some() {
                    return self.fit_or_error(actual, expected, expression.span);
                }
                let target = self.local_generic_type("unit", value).ok_or_else(|| {
                    Diagnostic::at(
                        "unit literal needs the standard unit mold or an expected type",
                        expression.span,
                    )
                })?;
                self.fit_or_error(target, expected, expression.span)
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
                let (target_type, target_steps) =
                    self.lookup_wing(target, expression.span, environment)?;
                if edits.is_empty() {
                    return Err(Diagnostic::at(
                        "a change takes at least one field",
                        expression.span,
                    ));
                }
                let mut previous = Vec::<&crate::ast::Edit>::new();
                let mut edit_steps = Vec::new();
                for edit in edits {
                    for earlier in &previous {
                        // A wing reads from its last name inward, so `open.cart` is
                        // inside `cart`: one field contains the other when its
                        // wing ends with the other's.
                        if earlier.field.ends_with(&edit.field)
                            || edit.field.ends_with(&earlier.field)
                        {
                            return Err(Diagnostic::at(
                                format!(
                                    "change fields `{}` and `{}` overlap",
                                    earlier.field.join("."),
                                    edit.field.join(".")
                                ),
                                edit.span,
                            )
                            .with_note("first field", earlier.span));
                        }
                    }
                    let (field_type, steps) =
                        self.record_wing(&target_type, &edit.field, edit.span)?;
                    self.infer_expression(&edit.value, Some(&field_type), variables, environment)?;
                    edit_steps.push(steps);
                    previous.push(edit);
                }
                self.elaboration
                    .changes
                    .insert(expression_key(expression), (target_steps, edit_steps));
                self.fit_or_error(target_type, expected, expression.span)
            }
            ExprKind::Tuple(items) => {
                if items.is_empty() {
                    return Err(Diagnostic::at(
                        "an empty `[]` is not a valid tuple",
                        expression.span,
                    ));
                }
                validate_record_item_scope(items)?;
                let resolved_expected = expected.map(|typ| self.unifier.resolve(typ));
                let expected_fields = resolved_expected
                    .as_ref()
                    .and_then(|typ| self.expected_cell_fields(typ, items));
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
                    let expected_item = expected_fields.as_ref().map(|fields| &fields[index].typ);
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
                        self.pending_printers.push(PendingPrinter {
                            key: expression_key(value),
                            typ,
                            span: value.span,
                            trace: false,
                        });
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
                let typ = self.infer_expression(value, None, variables, environment)?;
                self.pending_printers.push(PendingPrinter {
                    key: expression_key(value),
                    typ,
                    span: value.span,
                    trace: true,
                });
                self.infer_expression(body, expected, variables, environment)
            }
            ExprKind::Body {
                definitions,
                result,
            } => {
                let outer_environment = environment.clone();
                let scope_depth = self.local_resolved_molds.len();
                let checked = (|| {
                    self.infer_local_definitions(definitions, variables, environment)?;
                    let typ = self.infer_expression(result, expected, variables, environment)?;
                    self.expand_escaping_local_molds(&typ, result.span)
                })();
                if self.local_resolved_molds.len() > scope_depth {
                    self.finish_local_definitions();
                }
                *environment = outer_environment;
                checked
            }
            ExprKind::ApplicationPath(_) => Err(Diagnostic::at(
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
        let original_cases = self.pattern_cases(&subject_type).ok_or_else(|| {
            Diagnostic::at(
                format!(
                    "branch subject needs a known type, found {}",
                    crate::types::TypeScheme::mono(subject_type.clone())
                ),
                subject.span,
            )
        })?;
        let binding_cases = match &subject_type {
            Type::Named { .. } => self
                .expanded_cases(&subject_type)
                .unwrap_or_else(|| original_cases.clone()),
            _ => vec![subject_type.clone()],
        };
        let mut remaining = original_cases.clone();
        let mut previous_patterns: Vec<&Pattern> = Vec::new();
        // Without a known result type the arms join: each is checked against
        // the type so far, and an ancestor aura widens it.
        let result = match expected {
            Some(typ) if !self.is_flexible(typ) => typ.clone(),
            _ => {
                let join = self.fresh_variable();
                self.join_variables.insert(join);
                Type::Var(join)
            }
        };

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
            let binding_matching = binding_cases
                .iter()
                .filter(|case| self.pattern_match(&arm.pattern, case) != PatternMatch::None)
                .cloned()
                .collect::<Vec<_>>();
            self.bind_pattern(
                &arm.pattern,
                &binding_matching,
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
        self.finite_product_cases(typ, 0, &mut BTreeSet::new())
    }

    fn finite_product_cases(
        &self,
        typ: &Type,
        depth: usize,
        seen: &mut BTreeSet<(SourceId, String)>,
    ) -> Option<Vec<Type>> {
        let cases = match typ {
            Type::Union(cases) => {
                let mut result = Vec::new();
                for case in cases {
                    result.extend(self.finite_product_cases(case, depth, seen)?);
                }
                result
            }
            Type::Named { module, name, .. } if depth < 8 => {
                let key = (*module, name.clone());
                if !seen.insert(key.clone()) {
                    return Some(vec![typ.clone()]);
                }
                let mut cases = Vec::new();
                for case in self.expanded_cases(typ)? {
                    cases.extend(self.finite_product_cases(&case, depth + 1, seen)?);
                }
                seen.remove(&key);
                cases
            }
            Type::Named { .. } => vec![typ.clone()],
            Type::Flag => vec![
                Type::LoobeanConstant(BigUint::default()),
                Type::LoobeanConstant(BigUint::from(1u8)),
            ],
            Type::Void => Vec::new(),
            Type::Var(_) => vec![typ.clone()],
            Type::Cell(fields) if fields.len() == 1 => {
                return self.finite_product_cases(&fields[0].typ, depth, seen);
            }
            Type::Cell(fields) => {
                let mut rows = vec![Vec::new()];
                for field in fields {
                    let variants = self.finite_product_cases(&field.typ, depth, seen)?;
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
                    self.binder_type(cases, pattern.span)?
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

    /// The type a nested binder takes from the cases its arm can match: their
    /// common type, or the union of the distinct case types at that position.
    fn binder_type(&mut self, cases: &[Type], span: Span) -> Result<Type, Diagnostic> {
        let mut distinct = Vec::<Type>::new();
        for case in cases {
            let case = self.unifier.normalize(case);
            if !distinct.contains(&case) {
                distinct.push(case);
            }
        }
        let concrete = distinct
            .iter()
            .all(|case| self.unifier.free_variables_of(case).is_empty());
        if distinct.len() > 1
            && concrete
            && !distinct.iter().all(|case| {
                self.types_fit(case, &distinct[0]) && self.types_fit(&distinct[0], case)
            })
        {
            return Ok(Type::Union(distinct));
        }
        let typ = Type::Var(self.fresh_variable());
        for case in distinct {
            self.fit_or_error(case, Some(&typ), span)?;
        }
        Ok(typ)
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
        if self.global_value_visible(name)
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
        if self.global_value_visible(name)
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
        let (definition, _) = self.mold_definition(name)?;
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

    fn expected_cell_fields(
        &self,
        typ: &Type,
        items: &[crate::ast::Item],
    ) -> Option<Vec<TypeField>> {
        let count = items.len();
        let tag = items.first().and_then(|item| {
            if item.face.is_some() {
                return None;
            }
            match &item.value.kind {
                ExprKind::Literal(Literal::Term(term)) => Some(term.value.clone()),
                ExprKind::Literal(Literal::Null) => Some(BigUint::default()),
                ExprKind::Literal(Literal::Loobean(yes)) => Some(BigUint::from(u8::from(!yes))),
                _ => None,
            }
        });
        let matches_tag = |fields: &[TypeField]| {
            tag.as_ref()
                .is_none_or(|tag| constant_value(&fields[0].typ) == Some(tag))
        };
        match typ {
            Type::Cell(fields) => {
                align_cell_fields(fields, count).filter(|fields| matches_tag(fields))
            }
            Type::Named { .. } => self.expanded_cases(typ)?.iter().find_map(|case| {
                if let Type::Cell(fields) = case
                    && let Some(fields) = align_cell_fields(fields, count)
                    && matches_tag(&fields)
                {
                    Some(fields)
                } else {
                    self.expected_cell_fields(case, items)
                }
            }),
            _ => None,
        }
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
    ) -> Result<(Type, Vec<Step>), Diagnostic> {
        let Some(name) = names.last() else {
            return Err(Diagnostic::at("empty wing", span));
        };
        let typ = self.lookup_reference(name, span, environment)?;
        self.record_wing(&typ, &names[..names.len() - 1], span)
    }

    /// Reads a wing of record fields from a value of this type. A wing reads
    /// from its last name inward, as Hoon's: `a.b.p` is field `a` of field `b`
    /// of `p`.
    fn record_wing(
        &mut self,
        typ: &Type,
        names: &[String],
        span: Span,
    ) -> Result<(Type, Vec<Step>), Diagnostic> {
        let mut typ = typ.clone();
        let mut steps = Vec::new();
        for name in names.iter().rev() {
            let (field, mut path) = self.record_field(&typ, name, span)?;
            typ = field;
            steps.append(&mut path);
        }
        Ok((typ, steps))
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

    /// A field's type and the steps from its record to it: the record is
    /// right-nested, so field `i` of `n` is `i` tails and then, unless it is
    /// the last, a head.
    fn record_field(
        &mut self,
        typ: &Type,
        name: &str,
        span: Span,
    ) -> Result<(Type, Vec<Step>), Diagnostic> {
        let typ = self.unifier.normalize(typ);
        match &typ {
            Type::Cell(fields) => {
                let index = fields
                    .iter()
                    .position(|field| field.face.as_deref() == Some(name))
                    .ok_or_else(|| Diagnostic::at(format!("record has no field `{name}`"), span))?;
                let mut steps = vec![Step::Tail; index];
                if index + 1 != fields.len() {
                    steps.push(Step::Head);
                }
                Ok((fields[index].typ.clone(), steps))
            }
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
                Binding::Group { typ, capitals } => {
                    let mut substitutions = BTreeMap::new();
                    for capital in capitals {
                        let instance = self.fresh_variable();
                        self.capital_instances.push((capital, instance, span));
                        substitutions.insert(capital, Type::Var(instance));
                    }
                    let typ = self.unifier.normalize(&typ);
                    substitute(&typ, &substitutions)
                }
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

    fn infer_literal(
        &mut self,
        literal: &Literal,
        expected: Option<&Type>,
        span: Span,
    ) -> Result<Type, Diagnostic> {
        let invalid = match literal {
            Literal::Ship(text) => crate::literal::ship(text).err(),
            Literal::Date(text) => crate::literal::date(text).err(),
            Literal::Duration(text) => crate::literal::duration(text).err(),
            _ => None,
        };
        if let Some(message) = invalid {
            return Err(Diagnostic::at(message, span));
        }
        let resolved = expected.map(|typ| self.unifier.resolve(typ));
        let actual = match literal {
            Literal::Number(number) => {
                let aura = match number.aura {
                    NumberAura::Decimal => "ud",
                    NumberAura::Hexadecimal => "ux",
                    NumberAura::Base32 => "uv",
                };
                if number.aura == NumberAura::Decimal {
                    // A decimal waits for its context: it is a `@ud` unless the
                    // context fixes an aura it fits, or its `++` is generic
                    // over its aura.
                    if let Some(Type::Var(variable)) = resolved {
                        return Ok(self.defer_unsigned_literal(variable, &number.value, span));
                    }
                    if let Some(expected) = &resolved {
                        let expected = self.unifier.normalize(expected);
                        if let Type::Atom(_) = expected
                            && !self.types_fit(&Type::Atom(Aura::new("ud")), &expected)
                        {
                            return Err(number_mismatch(&number.value, &expected, span));
                        }
                    }
                }
                Type::Atom(Aura::new(aura))
            }
            Literal::String(_) => Type::Atom(Aura::new("t")),
            Literal::Ship(_) => Type::Atom(Aura::new("p")),
            Literal::Date(_) => Type::Atom(Aura::new("da")),
            Literal::Duration(_) => Type::Atom(Aura::new("dr")),
            Literal::Knot(_) => Type::Atom(Aura::new("ta")),
            Literal::Loobean(yes) => {
                if let Some(resolved) = &resolved {
                    let value = BigUint::from(u8::from(!yes));
                    if self.loobean_fits_singleton(&value, resolved) {
                        return Ok(resolved.clone());
                    }
                }
                Type::Flag
            }
            Literal::Term(term) if term.kind == TermKind::Numeric => {
                return match resolved {
                    Some(Type::Var(variable)) => {
                        Ok(self.defer_unsigned_literal(variable, &term.value, span))
                    }
                    // Unlike a name, a numeric term has Hoon's @ud type even
                    // without a cast or a union to select.
                    None => Ok(Type::Atom(Aura::new("ud"))),
                    // Preserve a numeric singleton mold when one is expected.
                    Some(_) => {
                        self.fit_or_error(Type::NumericTerm(term.value.clone()), expected, span)
                    }
                };
            }
            Literal::Term(term) if term.kind == TermKind::Boolean => {
                if let Some(resolved) = &resolved
                    && self.loobean_fits_singleton(&term.value, resolved)
                {
                    return Ok(resolved.clone());
                }
                return self.fit_or_error(Type::Flag, expected, span);
            }
            Literal::Term(_) | Literal::Null => {
                let actual = match literal {
                    Literal::Term(term) => Type::Constant(term.value.clone()),
                    _ => Type::Constant(BigUint::default()),
                };
                // A tag waits for its union: its variable must become a union
                // with a matching case, or an atom type the term fits.
                let variable = match resolved {
                    None => Some(self.fresh_variable()),
                    Some(Type::Var(variable)) if !self.unifier.is_rigid(variable) => Some(variable),
                    Some(_) => None,
                };
                if let Some(variable) = variable {
                    self.pending_tags.push(PendingTag {
                        variable,
                        kind: PendingTagKind::Literal(literal.clone()),
                        span,
                    });
                    return Ok(Type::Var(variable));
                }
                return self.fit_or_error(actual, expected, span);
            }
        };
        self.fit_or_error(actual, expected, span)
    }

    fn defer_unsigned_literal(&mut self, variable: TypeVar, value: &BigUint, span: Span) -> Type {
        if !self.unifier.is_rigid(variable) && !self.unifier.has_atom_constraint(variable) {
            self.unifier
                .constrain_variable(variable, ConstraintKind::Atom, span);
        }
        self.pending_numbers.push(PendingNumber {
            variable,
            value: value.clone(),
            span,
        });
        Type::Var(variable)
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
        // A branch's arms join at an ancestor aura: an arm whose atom type is
        // an ancestor of the type so far widens the branch to it.
        if let Type::Var(join) = expected
            && self.join_variables.contains(join)
        {
            let current = self.unifier.normalize(expected);
            if !matches!(current, Type::Var(_))
                && is_atom_type(&current)
                && is_atom_type(&actual)
                && !self.types_fit(&actual, &current)
                && self.types_fit(&current, &actual)
            {
                self.unifier.rebind(*join, actual.clone());
                return Ok(actual);
            }
        }
        let expected = self.unifier.normalize(expected);
        // A type variable used where an atom is required gains an atom
        // constraint; it becomes nothing more specific.
        if let (Type::Var(variable), Type::AnyAtom) = (&actual, &expected) {
            if !self.unifier.has_atom_constraint(*variable) {
                self.unifier
                    .constrain_variable(*variable, ConstraintKind::Atom, span);
            }
            return Ok(expected);
        }
        if self.types_fit(&actual, &expected) {
            return Ok(expected);
        }
        // A cell still holding unknown parts, such as a waiting tag, takes the
        // one case of a union its shape and tags can match.
        if matches!(actual, Type::Cell(_))
            && let Some(cases) = self.expanded_cases(&expected)
            && cases.len() > 1
            && !self.unifier.free_variables_of(&actual).is_empty()
        {
            let candidates = cases
                .iter()
                .filter(|case| self.may_match_case(&actual, case))
                .cloned()
                .collect::<Vec<_>>();
            if let [case] = candidates.as_slice() {
                self.fit_or_error(actual, Some(case), span)?;
                return Ok(expected);
            }
        }
        // A variable takes the named type itself, not its expansion.
        let variable = matches!(actual, Type::Var(_)) || matches!(expected, Type::Var(_));
        let actual_case = self.transparent_case(&actual);
        let expected_case = self.transparent_case(&expected);
        if !variable && (actual_case.is_some() || expected_case.is_some()) {
            let expanded_actual = actual_case.unwrap_or_else(|| actual.clone());
            let expanded_expected = expected_case.unwrap_or_else(|| expected.clone());
            if self
                .unifier
                .unify(&expanded_actual, &expanded_expected, span)
                .is_err()
            {
                return Err(Diagnostic::at(
                    format!(
                        "type mismatch: expected {}, found {}",
                        TypeScheme::mono(expected),
                        TypeScheme::mono(actual)
                    ),
                    span,
                ));
            }
            return Ok(self.unifier.normalize(&expected));
        }
        let typ = self.unifier.unify(&actual, &expected, span)?;
        Ok(self.unifier.normalize(&typ))
    }

    fn types_fit(&self, actual: &Type, expected: &Type) -> bool {
        self.types_fit_with_visited(actual, expected, &mut HashSet::new())
    }

    fn types_fit_with_visited(
        &self,
        actual: &Type,
        expected: &Type,
        visiting: &mut HashSet<(Type, Type)>,
    ) -> bool {
        if actual == expected || matches!(actual, Type::Void) || matches!(expected, Type::Noun) {
            return true;
        }
        if let (Some(actual), Some(expected)) = (constant_value(actual), constant_value(expected)) {
            return actual == expected;
        }
        let pair = (matches!(actual, Type::Named { .. }) || matches!(expected, Type::Named { .. }))
            .then(|| (actual.clone(), expected.clone()));
        if let Some(pair) = &pair
            && !visiting.insert(pair.clone())
        {
            return true;
        }
        let result = match (actual, expected) {
            (Type::Var(variable), Type::AnyAtom) if self.unifier.has_atom_constraint(*variable) => {
                true
            }
            (Type::Named { .. }, Type::AnyAtom) => {
                self.expanded_cases(actual).is_some_and(|cases| {
                    cases
                        .iter()
                        .all(|case| self.types_fit_with_visited(case, expected, visiting))
                })
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
            (Type::Constant(_), Type::Atom(aura)) => Aura::new("tas").fits(aura),
            (Type::NumericTerm(_), Type::Atom(aura)) => Aura::new("ud").fits(aura),
            (actual, Type::Flag) if constant_value(actual).is_some() => constant_value(actual)
                .is_some_and(|value| *value == BigUint::default() || *value == BigUint::from(1u8)),
            (Type::Cell(actual), Type::Cell(expected)) => {
                let count = actual.len().max(expected.len());
                match (
                    spread_cell_fields(actual, count),
                    spread_cell_fields(expected, count),
                ) {
                    (Some(actual), Some(expected)) => {
                        actual.iter().zip(&expected).all(|(actual, expected)| {
                            (actual.face == expected.face
                                || actual.face.is_none()
                                || expected.face.is_none())
                                && self.types_fit_with_visited(&actual.typ, &expected.typ, visiting)
                        })
                    }
                    _ => false,
                }
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
                self.types_fit_with_visited(actual_sample, expected_sample, visiting)
                    && self.types_fit_with_visited(actual_product, expected_product, visiting)
            }
            (Type::Union(cases), _) => cases
                .iter()
                .all(|case| self.types_fit_with_visited(case, expected, visiting)),
            (_, Type::Union(cases)) => cases
                .iter()
                .any(|case| self.types_fit_with_visited(actual, case, visiting)),
            (Type::Named { .. }, _) => self.expanded_cases(actual).is_some_and(|cases| {
                cases
                    .iter()
                    .all(|case| self.types_fit_with_visited(case, expected, visiting))
            }),
            (_, Type::Named { .. }) => self.expanded_cases(expected).is_some_and(|cases| {
                cases
                    .iter()
                    .any(|case| self.types_fit_with_visited(actual, case, visiting))
            }),
            _ => false,
        };
        if let Some(pair) = pair {
            visiting.remove(&pair);
        }
        result
    }

    fn fresh_variable(&mut self) -> TypeVar {
        self.unifier.fresh()
    }

    /// Whether a type with unknown parts can still become this union case: an
    /// unknown part matches anything, except that a waiting tag matches only
    /// its own constant.
    fn may_match_case(&mut self, actual: &Type, case: &Type) -> bool {
        let actual = self.unifier.resolve(actual);
        match (&actual, case) {
            (Type::Var(variable), _) if !self.unifier.is_rigid(*variable) => {
                let tags = self
                    .pending_tags
                    .iter()
                    .filter_map(|pending| match &pending.kind {
                        PendingTagKind::Literal(Literal::Term(term)) => {
                            Some((pending.variable, term.value.clone()))
                        }
                        PendingTagKind::Literal(Literal::Null) => {
                            Some((pending.variable, BigUint::default()))
                        }
                        _ => None,
                    })
                    .collect::<Vec<_>>();
                let mut constant = None;
                for (pending, value) in tags {
                    if self.unifier.resolve(&Type::Var(pending)) == actual {
                        constant = Some(value);
                    }
                }
                match constant {
                    Some(value) => constant_value(case).is_none_or(|case| *case == value),
                    None => true,
                }
            }
            (Type::Cell(actual), Type::Cell(case)) => {
                let count = actual.len().max(case.len());
                match (
                    spread_cell_fields(actual, count),
                    spread_cell_fields(case, count),
                ) {
                    (Some(actual), Some(case)) => actual
                        .iter()
                        .zip(&case)
                        .all(|(actual, case)| self.may_match_case(&actual.typ, &case.typ)),
                    _ => false,
                }
            }
            (_, Type::Named { .. }) => self
                .expanded_cases(case)
                .is_some_and(|cases| cases.iter().any(|case| self.may_match_case(&actual, case))),
            _ => self.types_fit(&actual, case),
        }
    }

    /// An unbound variable that is not a capital: a type still to be found.
    fn is_flexible(&mut self, typ: &Type) -> bool {
        matches!(self.unifier.resolve(typ), Type::Var(variable) if !self.unifier.is_rigid(variable))
    }
}

/// The expected types of `count` items written against a cell type, as
/// `[a b c]` is `[a [b c]]`: with fewer items than fields the last item is
/// expected to be the rest of the cell; with more, an unfaced cell in the last
/// position supplies them.
fn align_cell_fields(fields: &[TypeField], count: usize) -> Option<Vec<TypeField>> {
    if count < 2 || fields.is_empty() {
        return None;
    }
    if fields.len() > count {
        let mut aligned = fields[..count - 1].to_vec();
        aligned.push(TypeField {
            face: None,
            typ: Type::Cell(fields[count - 1..].to_vec()),
        });
        return Some(aligned);
    }
    spread_cell_fields(fields, count)
}

/// Writes out the local molds a type mentions; `None` for a recursive one.
fn expand_molds(
    typ: &Type,
    scope: &BTreeMap<String, ResolvedMold>,
    visiting: &mut Vec<String>,
) -> Option<Type> {
    Some(match typ {
        Type::Named {
            module,
            name,
            arguments,
        } => {
            let arguments = arguments
                .iter()
                .map(|argument| expand_molds(argument, scope, visiting))
                .collect::<Option<Vec<_>>>()?;
            let Some(mold) = scope.get(name) else {
                return Some(Type::Named {
                    module: *module,
                    name: name.clone(),
                    arguments,
                });
            };
            if visiting.contains(name) {
                return None;
            }
            visiting.push(name.clone());
            let substitutions = mold
                .parameters
                .iter()
                .zip(arguments)
                .map(|(parameter, argument)| (parameter.id, argument))
                .collect::<BTreeMap<_, _>>();
            let cases = mold
                .cases
                .iter()
                .map(|case| expand_molds(&substitute(&case.typ, &substitutions), scope, visiting))
                .collect::<Option<Vec<_>>>()?;
            visiting.pop();
            if cases.len() == 1 {
                cases.into_iter().next().expect("one case")
            } else {
                Type::Union(cases)
            }
        }
        Type::Cell(fields) => Type::Cell(
            fields
                .iter()
                .map(|field| {
                    Some(TypeField {
                        face: field.face.clone(),
                        typ: expand_molds(&field.typ, scope, visiting)?,
                    })
                })
                .collect::<Option<Vec<_>>>()?,
        ),
        Type::Gate { sample, product } => Type::Gate {
            sample: Box::new(expand_molds(sample, scope, visiting)?),
            product: Box::new(expand_molds(product, scope, visiting)?),
        },
        Type::Union(cases) => Type::Union(
            cases
                .iter()
                .map(|case| expand_molds(case, scope, visiting))
                .collect::<Option<Vec<_>>>()?,
        ),
        _ => typ.clone(),
    })
}

/// Hoon's decimal spelling, with dots between groups of three digits.
fn decimal_text(value: &BigUint) -> String {
    let digits = value.to_str_radix(10);
    let mut text = String::new();
    for (index, digit) in digits.chars().enumerate() {
        if index != 0 && (digits.len() - index).is_multiple_of(3) {
            text.push('.');
        }
        text.push(digit);
    }
    text
}

fn number_mismatch(value: &BigUint, expected: &Type, span: Span) -> Diagnostic {
    let number = decimal_text(value);
    let Type::Atom(aura) = expected else {
        return Diagnostic::at(
            format!(
                "type mismatch: expected {}, found @ud",
                TypeScheme::mono(expected.clone())
            ),
            span,
        );
    };
    let hint = match aura.0.as_str() {
        "dr" => format!("; write ~s{number}"),
        "ux" => format!("; write 0x{}", value.to_str_radix(16)),
        "t" | "ta" | "tas" => format!("; write \"{number}\""),
        _ => String::new(),
    };
    Diagnostic::at(
        format!(
            "type mismatch: `{number}` is a @ud, not a @{}{hint}",
            aura.0
        ),
        span,
    )
}

fn interpolation_error(typ: &Type, span: Span) -> Diagnostic {
    match typ {
        Type::Var(_) => Diagnostic::at(
            "interpolation needs an aura to print this atom; its `++` is generic over it, so add a `^-` naming the aura",
            span,
        ),
        _ => Diagnostic::at(
            format!(
                "interpolation needs a printable atom, found {}",
                TypeScheme::mono(typ.clone())
            ),
            span,
        ),
    }
}

fn pending_tag_text(kind: &PendingTagKind) -> String {
    let constant = |value: &BigUint| TypeScheme::mono(Type::Constant(value.clone())).to_string();
    match kind {
        PendingTagKind::Literal(Literal::Term(term)) => match term.kind {
            TermKind::Named | TermKind::Boolean => constant(&term.value),
            TermKind::Numeric => format!("%{}", decimal_text(&term.value)),
        },
        PendingTagKind::Literal(_) => "~".to_string(),
        PendingTagKind::Constructor { tag, .. } => format!("|={}", constant(tag)),
    }
}

fn is_atom_type(typ: &Type) -> bool {
    matches!(typ, Type::Atom(_) | Type::AnyAtom | Type::Noun)
}

/// An unnamed nested tuple is the surrounding record's tail, not a new record
/// value. A faced tuple is a field's value and therefore starts its own scope.
fn validate_record_item_scope(items: &[Item]) -> Result<(), Diagnostic> {
    let mut faces = BTreeMap::new();
    validate_record_items(items, &mut faces)
}

fn validate_record_items<'a>(
    items: &'a [Item],
    faces: &mut BTreeMap<&'a str, Span>,
) -> Result<(), Diagnostic> {
    for item in items {
        if let Some(face) = &item.face
            && let Some(previous) = faces.insert(face, item.span)
        {
            return Err(
                Diagnostic::at(format!("duplicate record field `{face}`"), item.span)
                    .with_note("first field", previous),
            );
        }
        if item.face.is_none()
            && let ExprKind::Tuple(nested) = &item.value.kind
        {
            validate_record_items(nested, faces)?;
        }
    }
    Ok(())
}

/// The same record-scope rule applies to written cell molds.
fn validate_record_mold_scope(fields: &[MoldField]) -> Result<(), Diagnostic> {
    let mut faces = BTreeMap::new();
    validate_record_molds(fields, &mut faces)
}

fn validate_record_molds<'a>(
    fields: &'a [MoldField],
    faces: &mut BTreeMap<&'a str, Span>,
) -> Result<(), Diagnostic> {
    for field in fields {
        if let Some(face) = &field.face
            && let Some(previous) = faces.insert(face, field.span)
        {
            return Err(
                Diagnostic::at(format!("duplicate record field `{face}`"), field.span)
                    .with_note("first field", previous),
            );
        }
        if field.face.is_none()
            && let MoldKind::Cell(nested) = &field.mold.kind
        {
            validate_record_molds(nested, faces)?;
        }
    }
    Ok(())
}

fn duplicate_name(name: &str, span: Span, previous: Span) -> Diagnostic {
    Diagnostic::at(format!("duplicate definition `{name}`"), span)
        .with_note("first definition", previous)
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
        Type::Union(cases) => Type::Union(
            cases
                .iter()
                .map(|case| substitute(case, substitutions))
                .collect(),
        ),
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
            TermKind::Boolean => Type::LoobeanConstant(term.value.clone()),
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

fn type_mentions_molds(typ: &Type, names: &BTreeSet<String>) -> bool {
    match typ {
        Type::Named {
            name, arguments, ..
        } => {
            names.contains(name)
                || arguments
                    .iter()
                    .any(|argument| type_mentions_molds(argument, names))
        }
        Type::Cell(fields) => fields
            .iter()
            .any(|field| type_mentions_molds(&field.typ, names)),
        Type::Gate { sample, product } => {
            type_mentions_molds(sample, names) || type_mentions_molds(product, names)
        }
        _ => false,
    }
}

fn value_definition<'a>(definitions: &[&'a Definition], name: &str) -> &'a Definition {
    definitions
        .iter()
        .copied()
        .find(|definition| definition.name == name)
        .expect("dependency groups contain only value definitions")
}

fn value_dependencies(definitions: &[&Definition]) -> BTreeMap<String, BTreeSet<String>> {
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
            if let Some(name) = path.last()
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
        ExprKind::Change { target, edits } => {
            if let Some(name) = target.last()
                && names.contains(name)
            {
                dependencies.insert(name.clone());
            }
            for edit in edits {
                collect_dependencies(&edit.value, names, dependencies);
            }
        }
        ExprKind::Pair { value, .. } | ExprKind::Unit(value) => {
            collect_dependencies(value, names, dependencies);
        }
        ExprKind::Literal(_)
        | ExprKind::Path(_)
        | ExprKind::Constructor(_)
        | ExprKind::Crash
        | ExprKind::Native(_) => {}
    }
}

fn strongly_connected(dependencies: &BTreeMap<String, BTreeSet<String>>) -> Vec<Vec<String>> {
    strongly_connected_in_order(dependencies, dependencies.keys().map(String::as_str))
}

fn strongly_connected_in_source_order(
    dependencies: &BTreeMap<String, BTreeSet<String>>,
    definitions: &[&Definition],
) -> Vec<Vec<String>> {
    strongly_connected_in_order(
        dependencies,
        definitions
            .iter()
            .map(|definition| definition.name.as_str()),
    )
}

fn strongly_connected_in_order<'b>(
    dependencies: &BTreeMap<String, BTreeSet<String>>,
    names: impl IntoIterator<Item = &'b str>,
) -> Vec<Vec<String>> {
    let mut tarjan = Tarjan {
        dependencies,
        next: 0,
        indices: BTreeMap::new(),
        low: BTreeMap::new(),
        stack: Vec::new(),
        on_stack: BTreeSet::new(),
        groups: Vec::new(),
    };
    for name in names {
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
    fn capitals_take_no_specific_type_while_variables_bind_atoms() {
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
        // A typed `@ud` cannot make a capital more specific; only a decimal
        // literal takes a generic aura.
        let error = checker
            .fit_or_error(
                Type::Atom(Aura::new("ud")),
                Some(&Type::Var(arithmetic)),
                Span::default(),
            )
            .unwrap_err();
        assert_eq!(error.message, "capital `A` cannot be fixed to @ud");
        assert_eq!(
            checker
                .fit_or_error(Type::Var(arithmetic), Some(&Type::AnyAtom), Span::default())
                .unwrap(),
            Type::AnyAtom
        );
        let error = checker
            .fit_or_error(Type::Flag, Some(&Type::Var(arithmetic)), Span::default())
            .unwrap_err();
        assert_eq!(error.message, "capital `A` cannot be fixed to ?");

        // A capital used where an atom is expected gains the atom constraint.
        let plain = checker.unifier.fresh_rigid("B", Span::default());
        checker
            .fit_or_error(Type::Var(plain), Some(&Type::AnyAtom), Span::default())
            .unwrap();
        assert!(checker.unifier.has_constraint(plain, ConstraintKind::Atom));

        // A flexible atom variable binds to the aura that fits it.
        let flexible = checker.unifier.fresh();
        checker.unifier.constrain_variable(
            flexible,
            ConstraintKind::ArithmeticAtom,
            Span::default(),
        );
        checker
            .fit_or_error(
                Type::Atom(Aura::new("dr")),
                Some(&Type::Var(flexible)),
                Span::default(),
            )
            .unwrap();
        assert_eq!(
            checker.unifier.resolve(&Type::Var(flexible)),
            Type::Atom(Aura::new("dr"))
        );
    }
}
