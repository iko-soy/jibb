use crate::{
    ast::{Expr, Sample},
    native::NativeFunction,
};
use num_bigint::BigUint;
use std::{cell::RefCell, collections::HashMap, fmt, rc::Rc};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Noun {
    Atom(BigUint),
    Cell(Rc<Noun>, Rc<Noun>),
}

/// An evaluated entry point. Data without functions is a [`Noun`]; a cell that
/// holds a function lists its right-nested items, as `[a b c]` is `[a [b c]]`.
#[derive(Clone, Debug)]
pub enum Value {
    Noun(Rc<Noun>),
    Cell(Vec<Value>),
    Gate(Rc<GateValue>),
    Constructor(BigUint),
    Native(NativeFunction),
}

/// A gate in an evaluated result. Functions are not data: a result shows
/// only that one is there.
#[derive(Debug)]
pub struct GateValue {
    _private: (),
}

impl GateValue {
    pub(crate) fn new() -> Self {
        Self { _private: () }
    }
}

/// A runtime value: Core's values are nouns and functions, and a function may
/// sit inside a cell, so cells are built the same way whatever they hold.
pub(crate) type Val<'a> = Rc<Runtime<'a>>;

pub(crate) enum Runtime<'a> {
    Atom(BigUint),
    Cell(Val<'a>, Val<'a>),
    Gate(Closure<'a>),
    Constructor(BigUint),
    Native(NativeFunction),
}

pub(crate) struct Closure<'a> {
    pub sample: &'a Sample,
    pub body: &'a Expr,
    pub environment: Rc<Scope<'a>>,
}

#[derive(Clone)]
pub(crate) enum Slot<'a> {
    Lazy(&'a Expr),
    Evaluating,
    Done(Val<'a>),
}

pub(crate) struct Scope<'a> {
    pub parent: Option<Rc<Scope<'a>>>,
    pub slots: RefCell<HashMap<&'a str, Slot<'a>>>,
}

impl<'a> Scope<'a> {
    pub fn new(parent: Option<Rc<Scope<'a>>>) -> Self {
        Self {
            parent,
            slots: RefCell::new(HashMap::new()),
        }
    }
}

pub(crate) fn atom<'a>(value: impl Into<BigUint>) -> Val<'a> {
    Rc::new(Runtime::Atom(value.into()))
}

pub(crate) fn cell<'a>(head: Val<'a>, tail: Val<'a>) -> Val<'a> {
    Rc::new(Runtime::Cell(head, tail))
}

pub(crate) fn loobean<'a>(yes: bool) -> Val<'a> {
    atom(u8::from(!yes))
}

/// The bytes of an atom, least significant first, without the zero byte
/// `BigUint::to_bytes_le` gives for 0: the empty cord has no bytes.
pub(crate) fn atom_bytes(value: &BigUint) -> Vec<u8> {
    if value.bits() == 0 {
        Vec::new()
    } else {
        value.to_bytes_le()
    }
}

/// A right-nested list of items, ending in `~`.
pub(crate) fn list<'a>(items: impl DoubleEndedIterator<Item = Val<'a>>) -> Val<'a> {
    let mut result = atom(0u8);
    for item in items.rev() {
        result = cell(item, result);
    }
    result
}

impl Noun {
    pub(crate) fn atom(value: impl Into<BigUint>) -> Rc<Self> {
        Rc::new(Self::Atom(value.into()))
    }

    pub(crate) fn cell(head: Rc<Self>, tail: Rc<Self>) -> Rc<Self> {
        Rc::new(Self::Cell(head, tail))
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
            Self::Native(native) => write!(formatter, "<native {}>", native.field()),
        }
    }
}
