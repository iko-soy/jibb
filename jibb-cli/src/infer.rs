use crate::{
    Diagnostic,
    ast::Span,
    types::{Constraint, ConstraintKind, QuantifiedVariable, Type, TypeField, TypeScheme, TypeVar},
};
use num_bigint::BigUint;
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug)]
struct RigidVariable {
    name: String,
    span: Span,
}

#[derive(Clone, Debug, Default)]
pub(crate) struct Unifier {
    next: TypeVar,
    bindings: BTreeMap<TypeVar, Type>,
    rigid: BTreeMap<TypeVar, RigidVariable>,
    constraints: BTreeMap<TypeVar, BTreeMap<ConstraintKind, Span>>,
}

impl Unifier {
    pub(crate) fn fresh(&mut self) -> TypeVar {
        let variable = self.next;
        self.next += 1;
        variable
    }

    pub(crate) fn fresh_rigid(&mut self, name: &str, span: Span) -> TypeVar {
        let variable = self.fresh();
        self.rigid.insert(
            variable,
            RigidVariable {
                name: name.to_string(),
                span,
            },
        );
        variable
    }

    pub(crate) fn resolve(&mut self, typ: &Type) -> Type {
        match typ {
            Type::Var(variable) => {
                let Some(binding) = self.bindings.get(variable).cloned() else {
                    return typ.clone();
                };

                let resolved = self.resolve(&binding);
                self.bindings.insert(*variable, resolved.clone());
                resolved
            }
            _ => typ.clone(),
        }
    }

    pub(crate) fn normalize(&mut self, typ: &Type) -> Type {
        match self.resolve(typ) {
            Type::Cell(fields) => Type::Cell(
                fields
                    .into_iter()
                    .map(|field| TypeField {
                        face: field.face,
                        typ: self.normalize(&field.typ),
                    })
                    .collect(),
            ),
            Type::Gate { sample, product } => Type::Gate {
                sample: Box::new(self.normalize(&sample)),
                product: Box::new(self.normalize(&product)),
            },
            Type::Named {
                module,
                name,
                arguments,
            } => Type::Named {
                module,
                name,
                arguments: arguments
                    .iter()
                    .map(|argument| self.normalize(argument))
                    .collect(),
            },
            typ => typ,
        }
    }

    pub(crate) fn unify(
        &mut self,
        left: &Type,
        right: &Type,
        span: Span,
    ) -> Result<Type, Diagnostic> {
        let left = self.resolve(left);
        let right = self.resolve(right);
        if left == right {
            return Ok(left);
        }
        if let (Some(left_value), Some(right_value)) =
            (constant_value(&left), constant_value(&right))
            && left_value == right_value
        {
            return Ok(right);
        }
        match (&left, &right) {
            (Type::Var(left), Type::Var(right)) => {
                match (
                    self.rigid.get(left).cloned(),
                    self.rigid.get(right).cloned(),
                ) {
                    (Some(left_rigid), Some(right_rigid)) => {
                        Err(rigid_mismatch(&left_rigid, &right_rigid, span))
                    }
                    (Some(_), None) => {
                        self.bind(*right, Type::Var(*left), span)?;
                        Ok(Type::Var(*left))
                    }
                    (None, Some(_)) => {
                        self.bind(*left, Type::Var(*right), span)?;
                        Ok(Type::Var(*right))
                    }
                    (None, None) => {
                        self.bind(*left, Type::Var(*right), span)?;
                        Ok(Type::Var(*right))
                    }
                }
            }
            (Type::Var(variable), _) if self.rigid.contains_key(variable) => {
                let rigid = self.rigid[variable].clone();
                Err(Diagnostic::at(
                    format!(
                        "explicit type variable `{}` cannot become {}",
                        rigid.name,
                        TypeScheme::mono(right.clone())
                    ),
                    span,
                )
                .with_note("explicit type variable", rigid.span))
            }
            (_, Type::Var(variable)) if self.rigid.contains_key(variable) => {
                let loobean = matches!(left, Type::Flag | Type::LoobeanConstant(_));
                if matches!(
                    left,
                    Type::Atom(_)
                        | Type::AnyAtom
                        | Type::Constant(_)
                        | Type::NumericTerm(_)
                        | Type::LoobeanConstant(_)
                        | Type::Flag
                ) && (!loobean
                    || !self.has_constraint(*variable, ConstraintKind::ArithmeticAtom))
                {
                    if !self.has_atom_constraint(*variable) {
                        self.constrain_variable(*variable, ConstraintKind::Atom, span);
                    }
                    return Ok(Type::Var(*variable));
                }
                let rigid = self.rigid[variable].clone();
                Err(Diagnostic::at(
                    format!(
                        "explicit type variable `{}` cannot become {}",
                        rigid.name,
                        TypeScheme::mono(left.clone())
                    ),
                    span,
                )
                .with_note("explicit type variable", rigid.span))
            }
            (Type::Var(variable), _) => {
                self.bind(*variable, right.clone(), span)?;
                Ok(right)
            }
            (_, Type::Var(variable)) => {
                self.bind(*variable, left.clone(), span)?;
                Ok(left)
            }
            (Type::Atom(left), Type::Atom(right)) if left == right => Ok(Type::Atom(left.clone())),
            (Type::AnyAtom, Type::AnyAtom) => Ok(Type::AnyAtom),
            (Type::Noun, Type::Noun) => Ok(Type::Noun),
            (Type::Void, Type::Void) => Ok(Type::Void),
            (Type::Flag, Type::Flag) => Ok(Type::Flag),
            (Type::Cell(left), Type::Cell(right)) if left.len() == right.len() => {
                let mut fields = Vec::new();
                for (left, right) in left.iter().zip(right) {
                    let face = match (&left.face, &right.face) {
                        (Some(left), Some(right)) if left != right => {
                            return Err(Diagnostic::at(
                                format!("record field `{left}` does not match `{right}`"),
                                span,
                            ));
                        }
                        (Some(face), _) | (_, Some(face)) => Some(face.clone()),
                        (None, None) => None,
                    };
                    fields.push(TypeField {
                        face,
                        typ: self.unify(&left.typ, &right.typ, span)?,
                    });
                }
                Ok(Type::Cell(fields))
            }
            (
                Type::Gate {
                    sample: left_sample,
                    product: left_product,
                },
                Type::Gate {
                    sample: right_sample,
                    product: right_product,
                },
            ) => Ok(Type::Gate {
                sample: Box::new(self.unify(left_sample, right_sample, span)?),
                product: Box::new(self.unify(left_product, right_product, span)?),
            }),
            (
                Type::Named {
                    module: left_module,
                    name: left_name,
                    arguments: left_arguments,
                },
                Type::Named {
                    module: right_module,
                    name: right_name,
                    arguments: right_arguments,
                },
            ) if left_module == right_module
                && left_name == right_name
                && left_arguments.len() == right_arguments.len() =>
            {
                let mut arguments = Vec::new();
                for (left, right) in left_arguments.iter().zip(right_arguments) {
                    arguments.push(self.unify(left, right, span)?);
                }
                Ok(Type::Named {
                    module: *left_module,
                    name: left_name.clone(),
                    arguments,
                })
            }
            (Type::Path(left), Type::Path(right)) if left == right => Ok(Type::Path(left.clone())),
            _ => Err(type_mismatch(left, right, span)),
        }
    }

    pub(crate) fn generalize(&mut self, typ: &Type, occupied: &BTreeSet<TypeVar>) -> TypeScheme {
        let typ = self.normalize(typ);
        let mut free = BTreeSet::new();
        self.free_variables(&typ, &mut free);
        let quantified = free.difference(occupied).copied().collect::<BTreeSet<_>>();
        let variables = quantified
            .iter()
            .copied()
            .map(|id| QuantifiedVariable {
                id,
                name: self.rigid.get(&id).map(|rigid| rigid.name.clone()),
            })
            .collect::<Vec<_>>();
        let sites = self.constraint_sites();
        let mut constraints = BTreeMap::new();
        for (variable, kind, _) in sites {
            self.map_generalized_constraint(&Type::Var(variable), kind, &mut constraints);
        }
        let constraints = constraints
            .into_iter()
            .filter(|(variable, _)| quantified.contains(variable))
            .flat_map(|(variable, kinds)| {
                kinds
                    .into_iter()
                    .map(move |kind| Constraint { variable, kind })
            })
            .collect();
        TypeScheme {
            variables,
            constraints,
            typ,
        }
    }

    pub(crate) fn instantiate(&mut self, scheme: &TypeScheme, span: Span) -> Type {
        let substitutions = scheme
            .variables
            .iter()
            .map(|variable| (variable.id, Type::Var(self.fresh())))
            .collect::<BTreeMap<_, _>>();
        for constraint in &scheme.constraints {
            if let Some(Type::Var(variable)) = substitutions.get(&constraint.variable) {
                self.constrain_variable(*variable, constraint.kind, span);
            }
        }
        let typ = substitute(&scheme.typ, &substitutions);
        self.normalize(&typ)
    }

    pub(crate) fn constrain_variable(
        &mut self,
        variable: TypeVar,
        kind: ConstraintKind,
        span: Span,
    ) {
        self.constraints
            .entry(variable)
            .or_default()
            .entry(kind)
            .or_insert(span);
    }

    pub(crate) fn constraint_sites(&self) -> Vec<(TypeVar, ConstraintKind, Span)> {
        self.constraints
            .iter()
            .flat_map(|(variable, constraints)| {
                constraints
                    .iter()
                    .map(|(kind, span)| (*variable, *kind, *span))
                    .collect::<Vec<_>>()
            })
            .collect()
    }

    pub(crate) fn has_constraint(&self, variable: TypeVar, kind: ConstraintKind) -> bool {
        self.constraints
            .get(&variable)
            .is_some_and(|constraints| constraints.contains_key(&kind))
    }

    pub(crate) fn has_atom_constraint(&self, variable: TypeVar) -> bool {
        self.has_constraint(variable, ConstraintKind::Atom)
            || self.has_constraint(variable, ConstraintKind::ArithmeticAtom)
    }

    fn map_generalized_constraint(
        &mut self,
        typ: &Type,
        kind: ConstraintKind,
        constraints: &mut BTreeMap<TypeVar, BTreeSet<ConstraintKind>>,
    ) {
        match self.resolve(typ) {
            Type::Var(variable) => {
                constraints.entry(variable).or_default().insert(kind);
            }
            Type::Cell(fields) if kind == ConstraintKind::GateFree => {
                for field in fields {
                    self.map_generalized_constraint(&field.typ, kind, constraints);
                }
            }
            Type::Named { arguments, .. } if kind == ConstraintKind::GateFree => {
                for argument in arguments {
                    self.map_generalized_constraint(&argument, kind, constraints);
                }
            }
            _ => {}
        }
    }

    pub(crate) fn free_variables_of(&mut self, typ: &Type) -> BTreeSet<TypeVar> {
        let mut variables = BTreeSet::new();
        self.free_variables(typ, &mut variables);
        variables
    }

    fn bind(&mut self, variable: TypeVar, typ: Type, span: Span) -> Result<(), Diagnostic> {
        if typ == Type::Var(variable) {
            return Ok(());
        }
        if self.occurs(variable, &typ) {
            return Err(Diagnostic::at("infinite type", span));
        }
        match typ {
            Type::Var(target) => {
                if let Some(constraints) = self.constraints.get(&variable).cloned() {
                    for (kind, span) in constraints {
                        self.constrain_variable(target, kind, span);
                    }
                }
                self.bindings.insert(variable, Type::Var(target));
            }
            typ => {
                self.bindings.insert(variable, typ);
            }
        }
        Ok(())
    }

    fn occurs(&mut self, variable: TypeVar, typ: &Type) -> bool {
        match self.resolve(typ) {
            Type::Var(other) => variable == other,
            Type::Cell(fields) => fields
                .into_iter()
                .any(|field| self.occurs(variable, &field.typ)),
            Type::Gate { sample, product } => {
                self.occurs(variable, &sample) || self.occurs(variable, &product)
            }
            Type::Named { arguments, .. } => arguments
                .into_iter()
                .any(|argument| self.occurs(variable, &argument)),
            _ => false,
        }
    }

    fn free_variables(&mut self, typ: &Type, variables: &mut BTreeSet<TypeVar>) {
        match self.resolve(typ) {
            Type::Var(variable) => {
                variables.insert(variable);
            }
            Type::Cell(fields) => {
                for field in fields {
                    self.free_variables(&field.typ, variables);
                }
            }
            Type::Gate { sample, product } => {
                self.free_variables(&sample, variables);
                self.free_variables(&product, variables);
            }
            Type::Named { arguments, .. } => {
                for argument in arguments {
                    self.free_variables(&argument, variables);
                }
            }
            _ => {}
        }
    }
}

fn rigid_mismatch(left: &RigidVariable, right: &RigidVariable, span: Span) -> Diagnostic {
    Diagnostic::at(
        format!(
            "distinct type variables `{}` and `{}` must not be forced equal; use the same capital for a shared type",
            left.name, right.name
        ),
        span,
    )
    .with_note("first type variable", left.span)
    .with_note("second type variable", right.span)
}

fn type_mismatch(left: Type, right: Type, span: Span) -> Diagnostic {
    Diagnostic::at(
        format!(
            "type mismatch: expected {}, found {}",
            TypeScheme::mono(right),
            TypeScheme::mono(left)
        ),
        span,
    )
}

fn constant_value(typ: &Type) -> Option<&BigUint> {
    match typ {
        Type::Constant(value) | Type::NumericTerm(value) | Type::LoobeanConstant(value) => {
            Some(value)
        }
        _ => None,
    }
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Aura;

    #[test]
    fn constraints_survive_generalization_and_instantiation() {
        let mut unifier = Unifier::default();
        let variable = unifier.fresh_rigid("A", Span::default());
        unifier.constrain_variable(variable, ConstraintKind::ArithmeticAtom, Span::default());
        let typ = Type::Gate {
            sample: Box::new(Type::Var(variable)),
            product: Box::new(Type::Var(variable)),
        };
        let scheme = unifier.generalize(&typ, &BTreeSet::new());
        assert_eq!(
            scheme.to_string(),
            "$-(A A) where A is an atom other than ?"
        );

        let instance = unifier.instantiate(&scheme, Span::default());
        let Type::Gate { sample, .. } = &instance else {
            panic!("expected gate")
        };
        let Type::Var(instance_variable) = unifier.resolve(sample) else {
            panic!("expected fresh variable")
        };
        assert!(
            unifier
                .constraint_sites()
                .iter()
                .any(|(variable, kind, _)| {
                    *variable == instance_variable && *kind == ConstraintKind::ArithmeticAtom
                })
        );
        unifier
            .unify(sample, &Type::Atom(Aura::new("ud")), Span::default())
            .unwrap();
    }

    #[test]
    fn gate_free_constraints_propagate_through_bound_cells() {
        let mut unifier = Unifier::default();
        let outer = unifier.fresh();
        let element = unifier.fresh_rigid("Key", Span::default());
        unifier.constrain_variable(outer, ConstraintKind::GateFree, Span::default());
        unifier
            .unify(
                &Type::Var(outer),
                &Type::Cell(vec![
                    TypeField {
                        face: None,
                        typ: Type::Var(element),
                    },
                    TypeField {
                        face: None,
                        typ: Type::Var(element),
                    },
                ]),
                Span::default(),
            )
            .unwrap();
        let scheme = unifier.generalize(&Type::Var(outer), &BTreeSet::new());
        assert_eq!(scheme.to_string(), "[Key Key] where Key contains no gates");
    }
}
