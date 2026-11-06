use crate::{
    Diagnostic,
    ast::{SourceId, Span},
    types::{Aura, Constraint, ConstraintKind, QuantifiedVariable, Type, TypeField, TypeScheme},
    value::{Noun, TypedValue, Value},
};
use num_bigint::BigUint;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NativeFunction {
    Gth,
    Eq,
    Add,
    Dec,
    Trip,
    Tuba,
}

impl NativeFunction {
    pub fn from_field(name: &str) -> Option<Self> {
        match name {
            "raw-gth" => Some(Self::Gth),
            "raw-eq" => Some(Self::Eq),
            "raw-add" => Some(Self::Add),
            "raw-dec" => Some(Self::Dec),
            "raw-trip" => Some(Self::Trip),
            "raw-tuba" => Some(Self::Tuba),
            _ => None,
        }
    }

    pub fn field(self) -> &'static str {
        match self {
            Self::Gth => "raw-gth",
            Self::Eq => "raw-eq",
            Self::Add => "raw-add",
            Self::Dec => "raw-dec",
            Self::Trip => "raw-trip",
            Self::Tuba => "raw-tuba",
        }
    }
}

pub(crate) fn scheme(native: NativeFunction, source: SourceId) -> TypeScheme {
    let variable = 0;
    let generic = QuantifiedVariable {
        id: variable,
        name: Some("A".to_string()),
    };
    let (typ, constraint) = match native {
        NativeFunction::Gth => (
            Type::Gate {
                sample: Box::new(Type::Cell(vec![
                    TypeField {
                        face: None,
                        typ: Type::Var(variable),
                    },
                    TypeField {
                        face: None,
                        typ: Type::Var(variable),
                    },
                ])),
                product: Box::new(Type::Flag),
            },
            ConstraintKind::Atom,
        ),
        NativeFunction::Eq => (
            Type::Gate {
                sample: Box::new(Type::Cell(vec![
                    TypeField {
                        face: None,
                        typ: Type::Var(variable),
                    },
                    TypeField {
                        face: None,
                        typ: Type::Var(variable),
                    },
                ])),
                product: Box::new(Type::Flag),
            },
            ConstraintKind::GateFree,
        ),
        NativeFunction::Add => (
            Type::Gate {
                sample: Box::new(Type::Cell(vec![
                    TypeField {
                        face: None,
                        typ: Type::Var(variable),
                    },
                    TypeField {
                        face: None,
                        typ: Type::Var(variable),
                    },
                ])),
                product: Box::new(Type::Var(variable)),
            },
            ConstraintKind::ArithmeticAtom,
        ),
        NativeFunction::Dec => (
            Type::Gate {
                sample: Box::new(Type::Var(variable)),
                product: Box::new(Type::Var(variable)),
            },
            ConstraintKind::ArithmeticAtom,
        ),
        NativeFunction::Trip => (
            Type::Gate {
                sample: Box::new(Type::Atom(Aura::new("t"))),
                product: Box::new(Type::Named {
                    module: source,
                    name: "list".to_string(),
                    arguments: vec![Type::Atom(Aura::new("tD"))],
                }),
            },
            ConstraintKind::Atom,
        ),
        NativeFunction::Tuba => (
            Type::Gate {
                sample: Box::new(Type::Named {
                    module: source,
                    name: "list".to_string(),
                    arguments: vec![Type::Atom(Aura::new("tD"))],
                }),
                product: Box::new(Type::Atom(Aura::new("ud"))),
            },
            ConstraintKind::Atom,
        ),
    };
    let constraints = if matches!(native, NativeFunction::Trip | NativeFunction::Tuba) {
        Vec::new()
    } else {
        vec![Constraint {
            variable,
            kind: constraint,
        }]
    };
    TypeScheme {
        variables: if matches!(native, NativeFunction::Trip | NativeFunction::Tuba) {
            Vec::new()
        } else {
            vec![generic]
        },
        constraints,
        typ,
    }
}

pub(crate) fn apply(
    native: NativeFunction,
    sample: &TypedValue,
    span: Span,
) -> Result<TypedValue, Diagnostic> {
    match native {
        NativeFunction::Gth => {
            let (left, right) = atom_pair(sample, span)?;
            Ok(TypedValue {
                value: Value::Noun(Noun::loobean(left > right)),
                typ: Type::Flag,
            })
        }
        NativeFunction::Eq => {
            let (left, right) = value_pair(sample, span)?;
            Ok(TypedValue {
                value: Value::Noun(Noun::loobean(value_equal(&left, &right)?)),
                typ: Type::Flag,
            })
        }
        NativeFunction::Add => {
            let (left, right) = atom_pair(sample, span)?;
            Ok(TypedValue {
                value: Value::Noun(Noun::atom(left + right)),
                typ: sample_field_type(sample, 0),
            })
        }
        NativeFunction::Dec => {
            let atom = single_atom(sample, span)?;
            if atom == BigUint::default() {
                return Err(Diagnostic::at("decrement underflow", span));
            }
            let value = atom - BigUint::from(1u8);
            Ok(TypedValue {
                value: Value::Noun(Noun::atom(value)),
                typ: sample.typ.clone(),
            })
        }
        NativeFunction::Trip => {
            let atom = single_atom(sample, span)?;
            let bytes = atom.to_bytes_le();
            Ok(TypedValue {
                value: Value::Noun(Noun::list(
                    bytes
                        .into_iter()
                        .map(|byte| Noun::atom(BigUint::from(byte)))
                        .collect(),
                )),
                typ: Type::Noun,
            })
        }
        NativeFunction::Tuba => {
            let Value::Noun(noun) = &sample.value else {
                return Err(Diagnostic::at("tuba expects a text list", span));
            };
            let mut length = 0u64;
            let mut current = noun.clone();
            loop {
                match current.as_ref() {
                    Noun::Atom(value) if *value == BigUint::default() => break,
                    Noun::Cell(_, tail) => {
                        length += 1;
                        current = tail.clone();
                    }
                    _ => return Err(Diagnostic::at("tuba expects a proper text list", span)),
                }
            }
            Ok(TypedValue {
                value: Value::Noun(Noun::atom(BigUint::from(length))),
                typ: Type::Atom(Aura::new("ud")),
            })
        }
    }
}

fn atom_pair(sample: &TypedValue, span: Span) -> Result<(BigUint, BigUint), Diagnostic> {
    let (left, right) = value_pair(sample, span)?;
    let (Value::Noun(left), Value::Noun(right)) = (left, right) else {
        return Err(Diagnostic::at("native expects two atoms", span));
    };
    let (Noun::Atom(left), Noun::Atom(right)) = (left.as_ref(), right.as_ref()) else {
        return Err(Diagnostic::at("native expects two atoms", span));
    };
    Ok((left.clone(), right.clone()))
}

fn value_pair(sample: &TypedValue, span: Span) -> Result<(Value, Value), Diagnostic> {
    match &sample.value {
        Value::Noun(noun) => match noun.as_ref() {
            Noun::Cell(left, right) => Ok((Value::Noun(left.clone()), Value::Noun(right.clone()))),
            _ => Err(Diagnostic::at("native expects a two-item sample", span)),
        },
        Value::Cell(items) if items.len() == 2 => Ok((items[0].clone(), items[1].clone())),
        _ => Err(Diagnostic::at("native expects a two-item sample", span)),
    }
}

fn single_atom(sample: &TypedValue, span: Span) -> Result<BigUint, Diagnostic> {
    let Value::Noun(noun) = &sample.value else {
        return Err(Diagnostic::at("native expects an atom", span));
    };
    let Noun::Atom(value) = noun.as_ref() else {
        return Err(Diagnostic::at("native expects an atom", span));
    };
    Ok(value.clone())
}

fn sample_field_type(sample: &TypedValue, index: usize) -> Type {
    match &sample.typ {
        Type::Cell(fields) => fields
            .get(index)
            .map_or(Type::Noun, |field| field.typ.clone()),
        _ => sample.typ.clone(),
    }
}

fn value_equal(left: &Value, right: &Value) -> Result<bool, Diagnostic> {
    match (left, right) {
        (Value::Noun(left), Value::Noun(right)) => Ok(noun_equal(left, right)),
        (Value::Cell(left), Value::Cell(right)) => {
            if left.len() != right.len() {
                return Ok(false);
            }
            for (left, right) in left.iter().zip(right) {
                if !value_equal(left, right)? {
                    return Ok(false);
                }
            }
            Ok(true)
        }
        (Value::Noun(_), Value::Cell(_)) | (Value::Cell(_), Value::Noun(_)) => Ok(false),
        (Value::Gate(_), _) | (Value::Constructor(_), _) | (Value::Native(_), _) => {
            Err(Diagnostic::new("equality cannot inspect gates"))
        }
        (_, Value::Gate(_)) | (_, Value::Constructor(_)) | (_, Value::Native(_)) => {
            Err(Diagnostic::new("equality cannot inspect gates"))
        }
    }
}

fn noun_equal(left: &Noun, right: &Noun) -> bool {
    match (left, right) {
        (Noun::Atom(left), Noun::Atom(right)) => left == right,
        (Noun::Cell(lh, lt), Noun::Cell(rh, rt)) => noun_equal(lh, rh) && noun_equal(lt, rt),
        _ => false,
    }
}
