use crate::{
    Diagnostic,
    ast::{SourceId, Span},
    types::{Aura, Constraint, ConstraintKind, QuantifiedVariable, Type, TypeField, TypeScheme},
    value::{Runtime, Val, atom, atom_bytes, list, loobean},
};
use num_bigint::BigUint;
use std::rc::Rc;

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
    pub(crate) const ALL: [Self; 17] = [
        Self::Gth,
        Self::Eq,
        Self::Add,
        Self::Dec,
        Self::Trip,
        Self::Tuba,
        Self::Crip,
        Self::Tufa,
        Self::DatePack,
        Self::DateUnpack,
        Self::FormatKnot,
        Self::FormatTape,
        Self::ParseAtom,
        Self::MapGet,
        Self::MapPut,
        Self::Seal,
        Self::BitNot,
    ];

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
    let opaque = named(source, crate::loader::PRIMITIVE_OPAQUE, vec![a.clone()]);
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

pub(crate) fn apply<'a>(
    native: NativeFunction,
    sample: &Val<'a>,
    span: Span,
) -> Result<Val<'a>, Diagnostic> {
    match native {
        NativeFunction::Gth => {
            let (left, right) = atom_pair(sample, span)?;
            Ok(loobean(left > right))
        }
        NativeFunction::Eq => {
            let (left, right) = pair(sample, span)?;
            Ok(loobean(equal(left, right, span)?))
        }
        NativeFunction::Add => {
            let (left, right) = atom_pair(sample, span)?;
            Ok(atom(left + right))
        }
        NativeFunction::Dec => {
            let value = single_atom(sample, span)?;
            if value.bits() == 0 {
                return Err(Diagnostic::at("decrement underflow", span));
            }
            Ok(atom(value - 1u8))
        }
        NativeFunction::Trip => {
            let bytes = atom_bytes(single_atom(sample, span)?);
            Ok(list(bytes.into_iter().map(atom)))
        }
        NativeFunction::Tuba => {
            let bytes = byte_list(sample, "tuba", span)?;
            let text = String::from_utf8(bytes)
                .map_err(|_| Diagnostic::at("tuba expects valid UTF-8", span))?;
            Ok(list(
                text.chars()
                    .map(|character| atom(u32::from(character)))
                    .collect::<Vec<_>>()
                    .into_iter(),
            ))
        }
        NativeFunction::Crip => Ok(atom(BigUint::from_bytes_le(&byte_list(
            sample, "crip", span,
        )?))),
        NativeFunction::Tufa => {
            let mut bytes = Vec::new();
            for codepoint in atom_list(sample, "tufa", span)? {
                let codepoint = u32::try_from(&codepoint)
                    .ok()
                    .and_then(char::from_u32)
                    .ok_or_else(|| Diagnostic::at("tufa expects valid codepoints", span))?;
                let mut encoded = [0; 4];
                bytes.extend_from_slice(codepoint.encode_utf8(&mut encoded).as_bytes());
            }
            Ok(list(bytes.into_iter().map(atom)))
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

fn atom_list(value: &Val<'_>, operation: &str, span: Span) -> Result<Vec<BigUint>, Diagnostic> {
    let mut atoms = Vec::new();
    let mut current = value.clone();
    loop {
        let next = match current.as_ref() {
            Runtime::Atom(value) if value.bits() == 0 => return Ok(atoms),
            Runtime::Cell(head, tail) => {
                let Runtime::Atom(value) = head.as_ref() else {
                    return Err(Diagnostic::at(
                        format!("{operation} expects an atom list"),
                        span,
                    ));
                };
                atoms.push(value.clone());
                tail.clone()
            }
            _ => {
                return Err(Diagnostic::at(
                    format!("{operation} expects a proper atom list"),
                    span,
                ));
            }
        };
        current = next;
    }
}

fn byte_list(value: &Val<'_>, operation: &str, span: Span) -> Result<Vec<u8>, Diagnostic> {
    atom_list(value, operation, span)?
        .into_iter()
        .map(|atom| {
            u8::try_from(&atom)
                .map_err(|_| Diagnostic::at(format!("{operation} expects bytes"), span))
        })
        .collect()
}

fn pair<'v, 'a>(sample: &'v Val<'a>, span: Span) -> Result<(&'v Val<'a>, &'v Val<'a>), Diagnostic> {
    match sample.as_ref() {
        Runtime::Cell(left, right) => Ok((left, right)),
        _ => Err(Diagnostic::at("native expects a two-item sample", span)),
    }
}

fn atom_pair<'v>(
    sample: &'v Val<'_>,
    span: Span,
) -> Result<(&'v BigUint, &'v BigUint), Diagnostic> {
    let (left, right) = pair(sample, span)?;
    match (left.as_ref(), right.as_ref()) {
        (Runtime::Atom(left), Runtime::Atom(right)) => Ok((left, right)),
        _ => Err(Diagnostic::at("native expects two atoms", span)),
    }
}

fn single_atom<'v>(sample: &'v Val<'_>, span: Span) -> Result<&'v BigUint, Diagnostic> {
    match sample.as_ref() {
        Runtime::Atom(value) => Ok(value),
        _ => Err(Diagnostic::at("native expects an atom", span)),
    }
}

/// Noun equality, as Nock 5. The checker keeps gates out of `eq`'s
/// arguments, so meeting one is an internal error rather than an answer.
pub(crate) fn equal<'a>(left: &Val<'a>, right: &Val<'a>, span: Span) -> Result<bool, Diagnostic> {
    let mut pending = vec![(left.clone(), right.clone())];
    while let Some((left, right)) = pending.pop() {
        if Rc::ptr_eq(&left, &right) {
            continue;
        }
        match (left.as_ref(), right.as_ref()) {
            (Runtime::Atom(left), Runtime::Atom(right)) => {
                if left != right {
                    return Ok(false);
                }
            }
            (Runtime::Cell(left_head, left_tail), Runtime::Cell(right_head, right_tail)) => {
                pending.push((left_tail.clone(), right_tail.clone()));
                pending.push((left_head.clone(), right_head.clone()));
            }
            (Runtime::Atom(_), Runtime::Cell(..)) | (Runtime::Cell(..), Runtime::Atom(_)) => {
                return Ok(false);
            }
            _ => return Err(Diagnostic::at("equality cannot inspect gates", span)),
        }
    }
    Ok(true)
}
