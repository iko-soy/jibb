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
    Crip,
    Tufa,
    DatePack,
    DateUnpack,
    FormatKnot,
    FormatTape,
    ParseAtom,
    MapGet,
    MapPut,
    Seal,
    BitNot,
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
            "raw-crip" => Some(Self::Crip),
            "raw-tufa" => Some(Self::Tufa),
            "raw-date-pack" => Some(Self::DatePack),
            "raw-date-unpack" => Some(Self::DateUnpack),
            "raw-format-knot" => Some(Self::FormatKnot),
            "raw-format-tape" => Some(Self::FormatTape),
            "raw-parse-atom" => Some(Self::ParseAtom),
            "raw-map-get" => Some(Self::MapGet),
            "raw-map-put" => Some(Self::MapPut),
            "raw-seal" => Some(Self::Seal),
            "raw-bit-not" => Some(Self::BitNot),
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
            Self::Crip => "raw-crip",
            Self::Tufa => "raw-tufa",
            Self::DatePack => "raw-date-pack",
            Self::DateUnpack => "raw-date-unpack",
            Self::FormatKnot => "raw-format-knot",
            Self::FormatTape => "raw-format-tape",
            Self::ParseAtom => "raw-parse-atom",
            Self::MapGet => "raw-map-get",
            Self::MapPut => "raw-map-put",
            Self::Seal => "raw-seal",
            Self::BitNot => "raw-bit-not",
        }
    }
}

pub(crate) fn scheme(native: NativeFunction, source: SourceId) -> TypeScheme {
    let a = Type::Var(0);
    let b = Type::Var(1);
    let atom = |aura| Type::Atom(Aura::new(aura));
    let list = |element| named(source, "list", vec![element]);
    let tape = list(atom("tD"));
    let number = atom("ud");
    let span = faced_cell(vec![
        ("d", number.clone()),
        ("h", number.clone()),
        ("m", number.clone()),
        ("s", number.clone()),
        ("f", list(atom("ux"))),
    ]);
    let date = Type::Cell(vec![
        TypeField {
            face: None,
            typ: faced_cell(vec![("a", Type::Flag), ("y", number.clone())]),
        },
        TypeField {
            face: Some("m".to_string()),
            typ: number,
        },
        TypeField {
            face: Some("t".to_string()),
            typ: span,
        },
    ]);
    let dime = faced_cell(vec![("p", atom("ta")), ("q", Type::AnyAtom)]);
    let map = named(source, "map", vec![a.clone(), b.clone()]);
    let unit = named(source, "unit", vec![b.clone()]);
    let opaque = named(source, "core__opaque", vec![a.clone()]);
    let (typ, variables, constraints) = match native {
        NativeFunction::Gth => (
            gate(cell(vec![a.clone(), a]), Type::Flag),
            vec![(0, "A")],
            vec![Constraint {
                variable: 0,
                kind: ConstraintKind::Atom,
            }],
        ),
        NativeFunction::Eq => (
            gate(cell(vec![a.clone(), a]), Type::Flag),
            vec![(0, "A")],
            vec![Constraint {
                variable: 0,
                kind: ConstraintKind::GateFree,
            }],
        ),
        NativeFunction::Add => (
            gate(cell(vec![a.clone(), a.clone()]), a),
            vec![(0, "A")],
            vec![Constraint {
                variable: 0,
                kind: ConstraintKind::ArithmeticAtom,
            }],
        ),
        NativeFunction::Dec => (
            gate(a.clone(), a),
            vec![(0, "A")],
            vec![Constraint {
                variable: 0,
                kind: ConstraintKind::ArithmeticAtom,
            }],
        ),
        NativeFunction::Trip => (gate(atom("t"), tape), Vec::new(), Vec::new()),
        NativeFunction::Tuba => (gate(tape, list(atom("c"))), Vec::new(), Vec::new()),
        NativeFunction::Crip => (gate(tape, atom("t")), Vec::new(), Vec::new()),
        NativeFunction::Tufa => (gate(list(atom("c")), tape), Vec::new(), Vec::new()),
        NativeFunction::DatePack => (gate(date.clone(), atom("da")), Vec::new(), Vec::new()),
        NativeFunction::DateUnpack => (gate(atom("da"), date), Vec::new(), Vec::new()),
        NativeFunction::FormatKnot => (gate(dime.clone(), atom("ta")), Vec::new(), Vec::new()),
        NativeFunction::FormatTape => (gate(dime, tape), Vec::new(), Vec::new()),
        NativeFunction::ParseAtom => (
            gate(
                cell(vec![atom("tas"), atom("ta")]),
                faced_cell(vec![("valid", Type::Flag), ("value", Type::AnyAtom)]),
            ),
            Vec::new(),
            Vec::new(),
        ),
        NativeFunction::MapGet => (
            gate(cell(vec![map.clone(), a.clone()]), unit),
            vec![(0, "K"), (1, "V")],
            vec![Constraint {
                variable: 0,
                kind: ConstraintKind::GateFree,
            }],
        ),
        NativeFunction::MapPut => (
            gate(cell(vec![map.clone(), a.clone(), b]), map),
            vec![(0, "K"), (1, "V")],
            vec![Constraint {
                variable: 0,
                kind: ConstraintKind::GateFree,
            }],
        ),
        NativeFunction::Seal => (gate(a, opaque), vec![(0, "A")], Vec::new()),
        NativeFunction::BitNot => (
            gate(
                cell(vec![Type::AnyAtom, Type::AnyAtom, Type::AnyAtom]),
                Type::AnyAtom,
            ),
            Vec::new(),
            Vec::new(),
        ),
    };
    TypeScheme {
        variables: variables
            .into_iter()
            .map(|(id, name)| QuantifiedVariable {
                id,
                name: Some(name.to_string()),
            })
            .collect(),
        constraints,
        typ,
    }
}

fn named(source: SourceId, name: &str, arguments: Vec<Type>) -> Type {
    Type::Named {
        module: source,
        name: name.to_string(),
        arguments,
    }
}

fn gate(sample: Type, product: Type) -> Type {
    Type::Gate {
        sample: Box::new(sample),
        product: Box::new(product),
    }
}

fn cell(types: Vec<Type>) -> Type {
    Type::Cell(
        types
            .into_iter()
            .map(|typ| TypeField { face: None, typ })
            .collect(),
    )
}

fn faced_cell(fields: Vec<(&str, Type)>) -> Type {
    Type::Cell(
        fields
            .into_iter()
            .map(|(face, typ)| TypeField {
                face: Some(face.to_string()),
                typ,
            })
            .collect(),
    )
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
            let bytes = byte_list(&sample.value, "tuba", span)?;
            let text = String::from_utf8(bytes)
                .map_err(|_| Diagnostic::at("tuba expects valid UTF-8", span))?;
            Ok(TypedValue {
                value: Value::Noun(Noun::list(
                    text.chars()
                        .map(|character| Noun::atom(BigUint::from(character as u32)))
                        .collect(),
                )),
                typ: Type::Noun,
            })
        }
        NativeFunction::Crip => Ok(TypedValue {
            value: Value::Noun(Noun::atom(BigUint::from_bytes_le(&byte_list(
                &sample.value,
                "crip",
                span,
            )?))),
            typ: Type::Atom(Aura::new("t")),
        }),
        NativeFunction::Tufa => {
            let mut bytes = Vec::new();
            for codepoint in atom_list(&sample.value, "tufa", span)? {
                let codepoint = u32::try_from(codepoint)
                    .ok()
                    .and_then(char::from_u32)
                    .ok_or_else(|| Diagnostic::at("tufa expects valid codepoints", span))?;
                let mut encoded = [0; 4];
                bytes.extend_from_slice(codepoint.encode_utf8(&mut encoded).as_bytes());
            }
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
        NativeFunction::Seal => Ok(sample.clone()),
        NativeFunction::DatePack
        | NativeFunction::DateUnpack
        | NativeFunction::FormatKnot
        | NativeFunction::FormatTape
        | NativeFunction::ParseAtom
        | NativeFunction::MapGet
        | NativeFunction::MapPut
        | NativeFunction::BitNot => Err(Diagnostic::at(
            format!("{} execution is not implemented", native.field()),
            span,
        )),
    }
}

fn atom_list(value: &Value, operation: &str, span: Span) -> Result<Vec<BigUint>, Diagnostic> {
    let Value::Noun(noun) = value else {
        return Err(Diagnostic::at(format!("{operation} expects a list"), span));
    };
    let mut atoms = Vec::new();
    let mut current = noun.clone();
    loop {
        match current.as_ref() {
            Noun::Atom(value) if *value == BigUint::default() => return Ok(atoms),
            Noun::Cell(head, tail) => {
                let Noun::Atom(value) = head.as_ref() else {
                    return Err(Diagnostic::at(
                        format!("{operation} expects an atom list"),
                        span,
                    ));
                };
                atoms.push(value.clone());
                current = tail.clone();
            }
            _ => {
                return Err(Diagnostic::at(
                    format!("{operation} expects a proper atom list"),
                    span,
                ));
            }
        }
    }
}

fn byte_list(value: &Value, operation: &str, span: Span) -> Result<Vec<u8>, Diagnostic> {
    atom_list(value, operation, span)?
        .into_iter()
        .map(|atom| {
            u8::try_from(atom)
                .map_err(|_| Diagnostic::at(format!("{operation} expects bytes"), span))
        })
        .collect()
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
