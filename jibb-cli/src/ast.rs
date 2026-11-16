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

    /// Marks every span as belonging to `source`, the file this module was
    /// read from.
    pub fn set_source(&mut self, source: SourceId) {
        self.visit_spans(&mut |span| span.source = source);
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
    /// A private primitive from `/lib/jibb/primitives`. Only the module loader
    /// creates this node, when it links that module under an import face, so
    /// a primitive is found through the scope that imported it.
    Native(crate::native::NativeFunction),
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
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span));

    fn erase_spans(&mut self) {
        self.visit_spans(&mut |span| *span = Span::default());
    }
}

impl<T: EraseSpans + ?Sized> EraseSpans for Box<T> {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        (**self).visit_spans(visit);
    }
}

impl<T: EraseSpans> EraseSpans for Vec<T> {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        for value in self {
            value.visit_spans(visit);
        }
    }
}

impl<T: EraseSpans> EraseSpans for Option<T> {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        if let Some(value) = self {
            value.visit_spans(visit);
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
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        visit(self);
    }
}

impl EraseSpans for Module {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        self.imports.visit_spans(visit);
        self.definitions.visit_spans(visit);
    }
}

impl EraseSpans for Import {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
    }
}

impl EraseSpans for Definition {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        match &mut self.kind {
            DefinitionKind::Value(value) => value.visit_spans(visit),
            DefinitionKind::Mold(definition) => {
                definition.generic.visit_spans(visit);
                definition.cases.visit_spans(visit);
            }
        }
    }
}

impl EraseSpans for Generic {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
    }
}

impl EraseSpans for Expr {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        match &mut self.kind {
            ExprKind::Literal(_)
            | ExprKind::Path(_)
            | ExprKind::Reference(_)
            | ExprKind::Constructor(_)
            | ExprKind::Crash
            | ExprKind::Native(_) => {}
            ExprKind::String(parts) => parts.visit_spans(visit),
            ExprKind::ApplicationPath(parts) => parts.visit_spans(visit),
            ExprKind::Call { head, arguments } => {
                head.visit_spans(visit);
                arguments.visit_spans(visit);
            }
            ExprKind::Gate { sample, body } => {
                sample.visit_spans(visit);
                body.visit_spans(visit);
            }
            ExprKind::Cast { mold, value } => {
                mold.visit_spans(visit);
                value.visit_spans(visit);
            }
            ExprKind::Trace { value, body } => {
                value.visit_spans(visit);
                body.visit_spans(visit);
            }
            ExprKind::Branch { subject, arms } => {
                subject.visit_spans(visit);
                arms.visit_spans(visit);
            }
            ExprKind::Body {
                definitions,
                result,
            } => {
                definitions.visit_spans(visit);
                result.visit_spans(visit);
            }
            ExprKind::List(items) => items.visit_spans(visit),
            ExprKind::Tuple(items) => items.visit_spans(visit),
            ExprKind::Change { target: _, edits } => edits.visit_spans(visit),
            ExprKind::Pair { tag: _, value } | ExprKind::Unit(value) => value.visit_spans(visit),
        }
    }
}

impl EraseSpans for StringPart {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        if let Self::Expr(expr) = self {
            expr.visit_spans(visit);
        }
    }
}

impl EraseSpans for ApplicationSegment {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        if let Self::Expr(expr) = self {
            expr.visit_spans(visit);
        }
    }
}

impl EraseSpans for Item {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        self.value.visit_spans(visit);
    }
}

impl EraseSpans for Edit {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        self.value.visit_spans(visit);
    }
}

impl EraseSpans for Arm {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        self.pattern.visit_spans(visit);
        self.body.visit_spans(visit);
    }
}

impl EraseSpans for Sample {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        match &mut self.kind {
            SampleKind::Binding(_) | SampleKind::Pun(_) => {}
            SampleKind::Face { name: _, mold } | SampleKind::Mold(mold) => mold.visit_spans(visit),
            SampleKind::Cell(samples) => samples.visit_spans(visit),
        }
    }
}

impl EraseSpans for Mold {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
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
                arguments.visit_spans(visit);
            }
            MoldKind::Cell(fields) => fields.visit_spans(visit),
            MoldKind::Function { sample, product } => {
                sample.visit_spans(visit);
                product.visit_spans(visit);
            }
            MoldKind::Union(cases) => cases.visit_spans(visit),
        }
    }
}

impl EraseSpans for MoldField {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        self.mold.visit_spans(visit);
    }
}

impl EraseSpans for Pattern {
    fn visit_spans(&mut self, visit: &mut dyn FnMut(&mut Span)) {
        self.span.visit_spans(visit);
        if let PatternKind::Cell(patterns) = &mut self.kind {
            patterns.visit_spans(visit);
        }
    }
}
