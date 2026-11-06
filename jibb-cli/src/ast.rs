use num_bigint::BigUint;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct SourceId(pub u64);

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Span {
    pub source: SourceId,
    pub start: usize,
    pub end: usize,
}

impl Span {
    pub const fn new(source: SourceId, start: usize, end: usize) -> Self {
        Self { source, start, end }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Module {
    pub imports: Vec<Import>,
    pub definitions: Vec<Definition>,
    pub span: Span,
}

impl Module {
    pub fn normalized(&self) -> Self {
        Normalize::normalized(self)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Import {
    pub kind: ImportKind,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ImportKind {
    Library { name: String },
    Mark { mark: String },
    Module { name: String, path: Vec<String> },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Definition {
    pub name: String,
    pub kind: DefinitionKind,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DefinitionKind {
    Value(Expr),
    Mold(MoldDefinition),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MoldDefinition {
    pub generic: Option<Generic>,
    pub cases: Vec<Mold>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Generic {
    pub variables: Vec<String>,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Expr {
    pub kind: ExprKind,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExprKind {
    Literal(Literal),
    String(Vec<StringPart>),
    Path(Vec<String>),
    ApplicationPath(Vec<ApplicationSegment>),
    Reference(Vec<String>),
    Constructor(BigUint),
    Call {
        head: Box<Expr>,
        arguments: Vec<Expr>,
    },
    Gate {
        sample: Sample,
        body: Box<Expr>,
    },
    Cast {
        mold: Mold,
        value: Box<Expr>,
    },
    Trace {
        value: Box<Expr>,
        body: Box<Expr>,
    },
    Branch {
        subject: Box<Expr>,
        arms: Vec<Arm>,
    },
    Body {
        definitions: Vec<Definition>,
        result: Box<Expr>,
    },
    List(Vec<Expr>),
    Tuple(Vec<Item>),
    Change {
        target: Vec<String>,
        edits: Vec<Edit>,
    },
    Pair {
        tag: String,
        value: Box<Expr>,
    },
    Unit(Box<Expr>),
    Crash,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Literal {
    Number(NumberLiteral),
    String(Vec<u8>),
    Ship(String),
    Date(String),
    Duration(String),
    Knot(String),
    Term(TermLiteral),
    Loobean(bool),
    Null,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NumberLiteral {
    pub value: BigUint,
    pub aura: NumberAura,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NumberAura {
    Decimal,
    Hexadecimal,
    Base32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TermLiteral {
    pub value: BigUint,
    pub kind: TermKind,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TermKind {
    Named,
    Numeric,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum StringPart {
    Text(Vec<u8>),
    Expr(Expr),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ApplicationSegment {
    Knot(String),
    Expr(Expr),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Item {
    pub face: Option<String>,
    pub value: Expr,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Edit {
    pub field: Vec<String>,
    pub value: Expr,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Arm {
    pub pattern: Pattern,
    pub body: Expr,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Sample {
    pub kind: SampleKind,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SampleKind {
    Binding(String),
    Face { name: String, mold: Mold },
    Pun(String),
    Cell(Vec<Sample>),
    Mold(Mold),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Mold {
    pub kind: MoldKind,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MoldKind {
    Aura(String),
    Hole,
    Noun,
    Void,
    Flag,
    Null,
    Term(TermLiteral),
    Loobean(bool),
    Reference(Vec<String>),
    TypeVariable(String),
    Path(Vec<MoldPathSegment>),
    Apply {
        constructor: Vec<String>,
        arguments: Vec<Mold>,
    },
    Union(Vec<Mold>),
    Cell(Vec<MoldField>),
    Function {
        sample: Box<Mold>,
        product: Box<Mold>,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MoldPathSegment {
    Knot(String),
    Typed {
        name: String,
        mold: TypedSegmentMold,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TypedSegmentMold {
    Aura(String),
    Hole,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MoldField {
    pub face: Option<String>,
    pub mold: Mold,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Pattern {
    pub kind: PatternKind,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PatternKind {
    Literal(Literal),
    Binding(String),
    Wildcard,
    Cell(Vec<Pattern>),
}

pub trait Normalize: Sized {
    fn normalized(&self) -> Self;
}

trait EraseSpans {
    fn erase_spans(&mut self);
}

impl<T: EraseSpans + ?Sized> EraseSpans for Box<T> {
    fn erase_spans(&mut self) {
        (**self).erase_spans();
    }
}

impl<T: EraseSpans> EraseSpans for Vec<T> {
    fn erase_spans(&mut self) {
        for value in self {
            value.erase_spans();
        }
    }
}

impl<T: EraseSpans> EraseSpans for Option<T> {
    fn erase_spans(&mut self) {
        if let Some(value) = self {
            value.erase_spans();
        }
    }
}

macro_rules! normalized {
    ($($type:ty),+ $(,)?) => {
        $(
            impl Normalize for $type {
                fn normalized(&self) -> Self {
                    let mut value = self.clone();
                    value.erase_spans();
                    value
                }
            }
        )+
    };
}

normalized!(
    Module, Import, Definition, Generic, Expr, Item, Edit, Arm, Sample, Mold, MoldField, Pattern
);

impl EraseSpans for Span {
    fn erase_spans(&mut self) {
        *self = Self::default();
    }
}

impl EraseSpans for Module {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        self.imports.erase_spans();
        self.definitions.erase_spans();
    }
}

impl EraseSpans for Import {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
    }
}

impl EraseSpans for Definition {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        match &mut self.kind {
            DefinitionKind::Value(value) => value.erase_spans(),
            DefinitionKind::Mold(definition) => {
                definition.generic.erase_spans();
                definition.cases.erase_spans();
            }
        }
    }
}

impl EraseSpans for Generic {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
    }
}

impl EraseSpans for Expr {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        match &mut self.kind {
            ExprKind::Literal(_)
            | ExprKind::Path(_)
            | ExprKind::Reference(_)
            | ExprKind::Constructor(_)
            | ExprKind::Crash => {}
            ExprKind::String(parts) => parts.erase_spans(),
            ExprKind::ApplicationPath(parts) => parts.erase_spans(),
            ExprKind::Call { head, arguments } => {
                head.erase_spans();
                arguments.erase_spans();
            }
            ExprKind::Gate { sample, body } => {
                sample.erase_spans();
                body.erase_spans();
            }
            ExprKind::Cast { mold, value } => {
                mold.erase_spans();
                value.erase_spans();
            }
            ExprKind::Trace { value, body } => {
                value.erase_spans();
                body.erase_spans();
            }
            ExprKind::Branch { subject, arms } => {
                subject.erase_spans();
                arms.erase_spans();
            }
            ExprKind::Body {
                definitions,
                result,
            } => {
                definitions.erase_spans();
                result.erase_spans();
            }
            ExprKind::List(items) => items.erase_spans(),
            ExprKind::Tuple(items) => items.erase_spans(),
            ExprKind::Change { target: _, edits } => edits.erase_spans(),
            ExprKind::Pair { tag: _, value } | ExprKind::Unit(value) => value.erase_spans(),
        }
    }
}

impl EraseSpans for StringPart {
    fn erase_spans(&mut self) {
        if let Self::Expr(expr) = self {
            expr.erase_spans();
        }
    }
}

impl EraseSpans for ApplicationSegment {
    fn erase_spans(&mut self) {
        if let Self::Expr(expr) = self {
            expr.erase_spans();
        }
    }
}

impl EraseSpans for Item {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        self.value.erase_spans();
    }
}

impl EraseSpans for Edit {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        self.value.erase_spans();
    }
}

impl EraseSpans for Arm {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        self.pattern.erase_spans();
        self.body.erase_spans();
    }
}

impl EraseSpans for Sample {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        match &mut self.kind {
            SampleKind::Binding(_) | SampleKind::Pun(_) => {}
            SampleKind::Face { name: _, mold } | SampleKind::Mold(mold) => mold.erase_spans(),
            SampleKind::Cell(samples) => samples.erase_spans(),
        }
    }
}

impl EraseSpans for Mold {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        match &mut self.kind {
            MoldKind::Aura(_)
            | MoldKind::Hole
            | MoldKind::Noun
            | MoldKind::Void
            | MoldKind::Flag
            | MoldKind::Null
            | MoldKind::Term(_)
            | MoldKind::Loobean(_)
            | MoldKind::Reference(_)
            | MoldKind::TypeVariable(_)
            | MoldKind::Path(_) => {}
            MoldKind::Apply {
                constructor: _,
                arguments,
            } => {
                arguments.erase_spans();
            }
            MoldKind::Cell(fields) => fields.erase_spans(),
            MoldKind::Function { sample, product } => {
                sample.erase_spans();
                product.erase_spans();
            }
            MoldKind::Union(cases) => cases.erase_spans(),
        }
    }
}

impl EraseSpans for MoldField {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        self.mold.erase_spans();
    }
}

impl EraseSpans for Pattern {
    fn erase_spans(&mut self) {
        self.span.erase_spans();
        if let PatternKind::Cell(patterns) = &mut self.kind {
            patterns.erase_spans();
        }
    }
}
