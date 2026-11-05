use crate::{
    ast::{Expr, MoldDefinition, Sample},
    types::Type,
};
use num_bigint::BigUint;
use std::{cell::RefCell, collections::BTreeMap, fmt, rc::Rc};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Noun {
    Atom(BigUint),
    Cell(Rc<Noun>, Rc<Noun>),
}

#[derive(Clone, Debug)]
pub enum Value {
    Noun(Rc<Noun>),
    Cell(Vec<Value>),
    Gate(Rc<GateValue>),
    Constructor(BigUint),
}

#[derive(Clone, Debug)]
pub struct GateValue {
    pub(crate) sample: Sample,
    pub(crate) body: Expr,
    pub(crate) environment: Rc<Scope>,
}

#[derive(Clone, Debug)]
pub(crate) struct TypedValue {
    pub value: Value,
    pub typ: Type,
}

#[derive(Clone, Debug)]
pub(crate) enum Slot {
    Unevaluated(Expr),
    Evaluating,
    Evaluated(TypedValue),
    Eager(TypedValue),
}

#[derive(Debug)]
pub(crate) struct Scope {
    pub parent: Option<Rc<Scope>>,
    pub slots: RefCell<BTreeMap<String, Slot>>,
    pub molds: RefCell<BTreeMap<String, MoldDefinition>>,
}

impl Scope {
    pub fn new(parent: Option<Rc<Scope>>) -> Self {
        Self {
            parent,
            slots: RefCell::new(BTreeMap::new()),
            molds: RefCell::new(BTreeMap::new()),
        }
    }
}

impl Noun {
    pub(crate) fn atom(value: impl Into<BigUint>) -> Rc<Self> {
        Rc::new(Self::Atom(value.into()))
    }

    pub(crate) fn bytes(bytes: &[u8]) -> Rc<Self> {
        Self::atom(BigUint::from_bytes_le(bytes))
    }

    pub(crate) fn null() -> Rc<Self> {
        Self::atom(BigUint::default())
    }

    pub(crate) fn loobean(yes: bool) -> Rc<Self> {
        Self::atom(u8::from(!yes))
    }

    pub(crate) fn cell(head: Rc<Self>, tail: Rc<Self>) -> Rc<Self> {
        Rc::new(Self::Cell(head, tail))
    }

    pub(crate) fn cells(items: Vec<Rc<Self>>) -> Rc<Self> {
        let mut items = items.into_iter().rev();
        let mut result = items.next().unwrap_or_else(Self::null);
        for item in items {
            result = Self::cell(item, result);
        }
        result
    }

    pub(crate) fn list(items: Vec<Rc<Self>>) -> Rc<Self> {
        let mut result = Self::null();
        for item in items.into_iter().rev() {
            result = Self::cell(item, result);
        }
        result
    }
}

impl fmt::Display for Noun {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Atom(value) => write!(formatter, "{value}"),
            Self::Cell(head, tail) => {
                write!(formatter, "[{head}")?;
                let mut rest = tail;
                loop {
                    match rest.as_ref() {
                        Self::Cell(head, tail) => {
                            write!(formatter, " {head}")?;
                            rest = tail;
                        }
                        Self::Atom(value) if *value == BigUint::default() => {
                            return formatter.write_str("]");
                        }
                        _ => return write!(formatter, " {rest}]"),
                    }
                }
            }
        }
    }
}

impl fmt::Display for Value {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Noun(noun) => write!(formatter, "{noun}"),
            Self::Cell(items) => {
                formatter.write_str("[")?;
                for (index, item) in items.iter().enumerate() {
                    if index != 0 {
                        formatter.write_str(" ")?;
                    }
                    write!(formatter, "{item}")?;
                }
                formatter.write_str("]")
            }
            Self::Gate(_) => formatter.write_str("<gate>"),
            Self::Constructor(tag) => write!(formatter, "<constructor %{tag}>"),
        }
    }
}
