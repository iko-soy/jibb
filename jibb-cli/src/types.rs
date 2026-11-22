use crate::ast::SourceId;
use num_bigint::BigUint;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

pub type TypeVar = u32;

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Aura(pub String);

impl Aura {
    pub fn new(name: impl Into<String>) -> Self {
        Self(name.into())
    }

    pub fn fits(&self, expected: &Self) -> bool {
        self == expected || self.0.starts_with(&expected.0)
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum Type {
    Var(TypeVar),
    Atom(Aura),
    AnyAtom,
    Noun,
    Void,
    Flag,
    Constant(BigUint),
    NumericTerm(BigUint),
    LoobeanConstant(BigUint),
    Cell(Vec<TypeField>),
    Gate {
        sample: Box<Type>,
        product: Box<Type>,
    },
    Named {
        module: SourceId,
        name: String,
        arguments: Vec<Type>,
    },
    Path(Vec<PathSegmentType>),
    Union(Vec<Type>),
}

pub(crate) fn display_mold_name(name: &str) -> String {
    if let Some(name) = name.strip_prefix("hoon__") {
        return name.to_string();
    }
    if let Some((face, name)) = name.split_once("__") {
        return format!("{name}.{face}");
    }
    name.to_string()
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct TypeField {
    pub face: Option<String>,
    pub typ: Type,
}

/// A cell's fields spread to `count` positions: `[a [b c]]` is `[a b c]`, so
/// an unfaced cell in the last position supplies the remaining fields. Faced
/// fields are never grouped, since a record does not fit a narrower one.
pub(crate) fn spread_cell_fields(fields: &[TypeField], count: usize) -> Option<Vec<TypeField>> {
    if fields.len() == count {
        return Some(fields.to_vec());
    }
    if fields.len() > count {
        return None;
    }
    let last = fields.last()?;
    let Type::Cell(inner) = &last.typ else {
        return None;
    };
    if last.face.is_some() || inner.len() < 2 {
        return None;
    }
    let mut spread = fields[..fields.len() - 1].to_vec();
    spread.extend(inner.iter().cloned());
    spread_cell_fields(&spread, count)
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum PathSegmentType {
    Knot(String),
    Typed { name: String, aura: Aura },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum ConstraintKind {
    Atom,
    ArithmeticAtom,
    GateFree,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Constraint {
    pub variable: TypeVar,
    pub kind: ConstraintKind,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct QuantifiedVariable {
    pub id: TypeVar,
    pub name: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TypeScheme {
    pub variables: Vec<QuantifiedVariable>,
    pub constraints: Vec<Constraint>,
    pub typ: Type,
}

impl TypeScheme {
    pub fn mono(typ: Type) -> Self {
        Self {
            variables: Vec::new(),
            constraints: Vec::new(),
            typ,
        }
    }
}

impl fmt::Display for TypeScheme {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut printer = TypePrinter::new(self);
        formatter.write_str(&printer.typ(&self.typ))?;
        if !self.constraints.is_empty() {
            let mut constraints = self.constraints.clone();
            constraints.sort_by(|left, right| {
                printer
                    .variable_name(left.variable)
                    .cmp(&printer.variable_name(right.variable))
                    .then(left.kind.cmp(&right.kind))
            });
            constraints.dedup();
            formatter.write_str(" where ")?;
            for (index, constraint) in constraints.into_iter().enumerate() {
                if index != 0 {
                    formatter.write_str(", ")?;
                }
                let name = printer.variable_name(constraint.variable);
                let description = match constraint.kind {
                    ConstraintKind::Atom => "is an atom",
                    ConstraintKind::ArithmeticAtom => "is an atom other than ?",
                    ConstraintKind::GateFree => "contains no gates",
                };
                write!(formatter, "{name} {description}")?;
            }
        }
        Ok(())
    }
}

struct TypePrinter {
    names: BTreeMap<TypeVar, String>,
    used: BTreeSet<String>,
    next: usize,
}

impl TypePrinter {
    fn new(scheme: &TypeScheme) -> Self {
        let mut printer = Self {
            names: BTreeMap::new(),
            used: BTreeSet::new(),
            next: 0,
        };
        for variable in &scheme.variables {
            if let Some(name) = &variable.name
                && printer.used.insert(name.clone())
            {
                printer.names.insert(variable.id, name.clone());
            }
        }
        printer
    }

    fn typ(&mut self, typ: &Type) -> String {
        match typ {
            Type::Var(variable) => self.variable_name(*variable),
            Type::Atom(aura) => format!("@{}", aura.0),
            Type::AnyAtom => "@".to_string(),
            Type::Noun => "*".to_string(),
            Type::Void => "!!".to_string(),
            Type::Flag => "?".to_string(),
            Type::Constant(value) | Type::LoobeanConstant(value) => constant_text(value),
            Type::NumericTerm(value) => format!("%{}", decimal_text(value)),
            Type::Cell(fields) => {
                let mut items = Vec::new();
                self.cell_items(fields, &mut items);
                format!("[{}]", items.join(" "))
            }
            Type::Gate { sample, product } => {
                format!("$-({} {})", self.typ(sample), self.typ(product))
            }
            Type::Named {
                name, arguments, ..
            } => {
                let name = display_mold_name(name);
                if arguments.is_empty() {
                    name.clone()
                } else {
                    let arguments = arguments
                        .iter()
                        .map(|argument| self.typ(argument))
                        .collect::<Vec<_>>()
                        .join(" ");
                    format!("({name} {arguments})")
                }
            }
            Type::Union(cases) => format!(
                "({})",
                cases
                    .iter()
                    .map(|case| self.typ(case))
                    .collect::<Vec<_>>()
                    .join(" ")
            ),
            Type::Path(segments) => {
                let segments = segments
                    .iter()
                    .map(|segment| match segment {
                        PathSegmentType::Knot(knot) => knot.clone(),
                        PathSegmentType::Typed { name, aura } => {
                            format!("[{name}=@{}]", aura.0)
                        }
                    })
                    .collect::<Vec<_>>()
                    .join("/");
                format!("/{segments}")
            }
        }
    }

    fn cell_items(&mut self, fields: &[TypeField], items: &mut Vec<String>) {
        for (index, field) in fields.iter().enumerate() {
            if index + 1 == fields.len()
                && field.face.is_none()
                && let Type::Cell(nested) = &field.typ
            {
                self.cell_items(nested, items);
                continue;
            }
            let typ = self.typ(&field.typ);
            items.push(match &field.face {
                Some(face) => format!("{face}={typ}"),
                None => typ,
            });
        }
    }

    fn variable_name(&mut self, variable: TypeVar) -> String {
        if let Some(name) = self.names.get(&variable) {
            return name.clone();
        }
        loop {
            let name = anonymous_name(self.next);
            self.next += 1;
            if self.used.insert(name.clone()) {
                self.names.insert(variable, name.clone());
                return name;
            }
        }
    }
}

fn anonymous_name(mut index: usize) -> String {
    let suffix = index / 26;
    index %= 26;
    let letter = char::from(b'A' + index as u8);
    if suffix == 0 {
        letter.to_string()
    } else {
        format!("{letter}{suffix}")
    }
}

fn constant_text(value: &BigUint) -> String {
    if *value == BigUint::default() {
        return "%.y".to_string();
    }
    if *value == BigUint::from(1u8) {
        return "%.n".to_string();
    }
    let bytes = value.to_bytes_le();
    if bytes.first().is_some_and(u8::is_ascii_lowercase)
        && bytes
            .iter()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || *byte == b'-')
    {
        return format!("%{}", String::from_utf8_lossy(&bytes));
    }
    format!("%{}", decimal_text(value))
}

fn decimal_text(value: &BigUint) -> String {
    let decimal = value.to_str_radix(10);
    let mut grouped = String::new();
    for (index, character) in decimal.chars().enumerate() {
        if index != 0 && (decimal.len() - index).is_multiple_of(3) {
            grouped.push('.');
        }
        grouped.push(character);
    }
    grouped
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn aura_fitting_is_directional() {
        let decimal = Aura::new("ud");
        let unsigned = Aura::new("u");
        let text = Aura::new("t");
        assert!(decimal.fits(&unsigned));
        assert!(!unsigned.fits(&decimal));
        assert!(!decimal.fits(&text));
    }

    #[test]
    fn prints_principal_types_and_constraints() {
        let scheme = TypeScheme {
            variables: vec![QuantifiedVariable {
                id: 7,
                name: Some("Num".to_string()),
            }],
            constraints: vec![Constraint {
                variable: 7,
                kind: ConstraintKind::ArithmeticAtom,
            }],
            typ: Type::Gate {
                sample: Box::new(Type::Cell(vec![TypeField {
                    face: Some("n".to_string()),
                    typ: Type::Var(7),
                }])),
                product: Box::new(Type::Var(7)),
            },
        };
        assert_eq!(
            scheme.to_string(),
            "$-([n=Num] Num) where Num is an atom other than ?"
        );
    }

    #[test]
    fn flattens_only_unfaced_tail_cells_and_displays_mold_names() {
        let field = |typ| TypeField { face: None, typ };
        let flat = Type::Cell(vec![
            field(Type::Atom(Aura::new("ud"))),
            field(Type::Cell(vec![
                field(Type::Atom(Aura::new("t"))),
                field(Type::Cell(vec![
                    field(Type::Flag),
                    field(Type::Atom(Aura::new("p"))),
                ])),
            ])),
        ]);
        assert_eq!(TypeScheme::mono(flat).to_string(), "[@ud @t ? @p]");

        let faced = Type::Cell(vec![TypeField {
            face: Some("rest".to_string()),
            typ: Type::Cell(vec![field(Type::Atom(Aura::new("t"))), field(Type::Flag)]),
        }]);
        assert_eq!(TypeScheme::mono(faced).to_string(), "[rest=[@t ?]]");
        let non_tail = Type::Cell(vec![
            field(Type::Cell(vec![
                field(Type::Atom(Aura::new("ud"))),
                field(Type::Atom(Aura::new("t"))),
            ])),
            field(Type::Flag),
        ]);
        assert_eq!(TypeScheme::mono(non_tail).to_string(), "[[@ud @t] ?]");

        for (name, expected) in [
            ("todo__item", "item.todo"),
            ("theme", "theme"),
            ("hoon__list", "list"),
        ] {
            let named = Type::Named {
                module: SourceId(0),
                name: name.to_string(),
                arguments: Vec::new(),
            };
            assert_eq!(TypeScheme::mono(named).to_string(), expected);
        }
    }
}
