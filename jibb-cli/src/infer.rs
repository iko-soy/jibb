use crate::{
    Diagnostic,
    ast::Span,
    types::{QuantifiedVariable, Type, TypeField, TypeScheme, TypeVar},
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
        let variables = free
            .difference(occupied)
            .copied()
            .map(|id| QuantifiedVariable {
                id,
                name: self.rigid.get(&id).map(|rigid| rigid.name.clone()),
            })
            .collect::<Vec<_>>();
        TypeScheme {
            variables,
            constraints: Vec::new(),
            typ,
        }
    }

    pub(crate) fn instantiate(&mut self, scheme: &TypeScheme) -> Type {
        let substitutions = scheme
            .variables
            .iter()
            .map(|variable| (variable.id, Type::Var(self.fresh())))
            .collect::<BTreeMap<_, _>>();
        let typ = substitute(&scheme.typ, &substitutions);
        self.normalize(&typ)
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
        self.bindings.insert(variable, typ);
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
