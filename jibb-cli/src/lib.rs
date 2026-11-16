pub mod ast;
pub mod check;
pub mod dev;
pub mod docs;
mod eval;
mod formatter;
mod hoon;
mod infer;
pub mod init;
mod literal;
pub mod loader;
mod lower;
mod native;
pub mod types;
pub mod value;

pub use check::check;
pub use eval::evaluate;
pub use formatter::format_source;

use ast::{SourceId, Span};
use std::{fmt, path::Path};
use tree_sitter::{Language, Node, Parser};

unsafe extern "C" {
    fn tree_sitter_jibb() -> Language;
}

pub fn language() -> Language {
    unsafe { tree_sitter_jibb() }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SourceLanguage {
    Jibb,
}

impl SourceLanguage {
    pub fn from_path(path: &Path) -> Result<Self, Diagnostic> {
        match path.extension() {
            Some(extension) if extension == "jibb" => Ok(Self::Jibb),
            Some(extension) => Err(Diagnostic::new(format!(
                "unsupported source extension `.{}`; expected `.jibb`",
                extension.to_string_lossy()
            ))),
            None => Err(Diagnostic::new(
                "source file has no extension; expected `.jibb`",
            )),
        }
    }

    pub fn parse_ast(self, source: &str) -> Result<ast::Module, Diagnostic> {
        match self {
            Self::Jibb => parse_ast(source),
        }
    }

    pub fn format(self, source: &str) -> Result<String, String> {
        match self {
            Self::Jibb => format_source(source),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiagnosticNote {
    pub message: String,
    pub span: Span,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Diagnostic {
    pub message: String,
    pub span: Option<Span>,
    pub notes: Vec<DiagnosticNote>,
}

impl Diagnostic {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            span: None,
            notes: Vec::new(),
        }
    }

    pub fn at(message: impl Into<String>, span: Span) -> Self {
        Self {
            message: message.into(),
            span: Some(span),
            notes: Vec::new(),
        }
    }

    pub fn with_note(mut self, message: impl Into<String>, span: Span) -> Self {
        self.notes.push(DiagnosticNote {
            message: message.into(),
            span,
        });
        self
    }
}

impl fmt::Display for Diagnostic {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        if let Some(span) = self.span {
            write!(
                formatter,
                "{} at bytes {}..{} (source {})",
                self.message, span.start, span.end, span.source.0
            )?;
        } else {
            formatter.write_str(&self.message)?;
        }
        for note in &self.notes {
            write!(
                formatter,
                "\n{} at bytes {}..{} (source {})",
                note.message, note.span.start, note.span.end, note.span.source.0
            )?;
        }
        Ok(())
    }
}

impl std::error::Error for Diagnostic {}

/// The deepest syntax tree the tools accept. Formatting, lowering and
/// checking recurse along the tree, so deeper input is an error rather than a
/// stack overflow.
pub const MAX_SYNTAX_DEPTH: usize = 2_000;

/// Stack size for work whose recursion follows the source's nesting or
/// evaluation's.
pub(crate) const STACK_SIZE: usize = 512 << 20;

/// Runs `work` on a thread with a stack large enough for the deepest accepted
/// syntax tree and for evaluation's depth limit.
pub(crate) fn on_large_stack<T: Send>(work: impl FnOnce() -> T + Send) -> T {
    std::thread::scope(|scope| {
        std::thread::Builder::new()
            .stack_size(STACK_SIZE)
            .spawn_scoped(scope, work)
            .expect("spawn a thread for Jibb work")
            .join()
            .unwrap_or_else(|panic| std::panic::resume_unwind(panic))
    })
}

/// The deepest bracket nesting accepted on one line. Tree-sitter's parse
/// slows sharply with nesting, so deeper input is rejected before parsing.
const MAX_LINE_NESTING: usize = MAX_SYNTAX_DEPTH / 2;

/// The byte where one line's brackets first nest deeper than `limit`. Each
/// line counts from zero: nesting across lines goes through indentation,
/// which the layout scanner bounds. String text is skipped, but an
/// interpolation's `{…}` counts with what it holds.
fn line_nesting_beyond(source: &str, limit: usize) -> Option<usize> {
    let bytes = source.as_bytes();
    let mut depth = 0usize;
    let mut strings = 0usize;
    let mut interpolations = Vec::new();
    let mut index = 0;
    while index < bytes.len() {
        let byte = bytes[index];
        let in_string = interpolations.last().copied().unwrap_or(0) < strings;
        match byte {
            b'\n' => {
                depth = 0;
                strings = 0;
                interpolations.clear();
            }
            b'\\' if in_string => index += 1,
            b'"' if in_string => strings -= 1,
            b'"' => strings += 1,
            b'{' if in_string => {
                interpolations.push(strings);
                depth += 1;
            }
            b'}' if !in_string && interpolations.last() == Some(&strings) => {
                interpolations.pop();
                depth = depth.saturating_sub(1);
            }
            b':' if !in_string && bytes.get(index + 1) == Some(&b':') => {
                while index < bytes.len() && bytes[index] != b'\n' {
                    index += 1;
                }
                continue;
            }
            b'(' | b'[' if !in_string => depth += 1,
            b')' | b']' if !in_string => depth = depth.saturating_sub(1),
            _ => {}
        }
        if depth > limit {
            return Some(index);
        }
        index += 1;
    }
    None
}

fn parse_tree(source: &str) -> Result<tree_sitter::Tree, Diagnostic> {
    if let Some(at) = line_nesting_beyond(source, MAX_LINE_NESTING) {
        return Err(Diagnostic::at(
            format!("Jibb source nests more than {MAX_LINE_NESTING} brackets deep on one line"),
            Span::new(SourceId::default(), at, at + 1),
        ));
    }
    if source.starts_with('\u{feff}') {
        return Err(Diagnostic::at(
            "invalid Jibb syntax: a byte order mark is not allowed",
            Span::new(SourceId::default(), 0, '\u{feff}'.len_utf8()),
        ));
    }
    let mut parser = Parser::new();
    parser
        .set_language(&language())
        .map_err(|error| Diagnostic::new(error.to_string()))?;
    let tree = parser
        .parse(source, None)
        .ok_or_else(|| Diagnostic::new("parser cancelled"))?;
    if let Some(span) = deeper_than(tree.root_node(), MAX_SYNTAX_DEPTH) {
        return Err(Diagnostic::at(
            format!("Jibb source nests more than {MAX_SYNTAX_DEPTH} syntax levels deep"),
            span,
        ));
    }
    lower::validate(tree.root_node())?;
    Ok(tree)
}

/// The span of the first node deeper than `limit`, found without recursion.
fn deeper_than(root: Node<'_>, limit: usize) -> Option<Span> {
    let mut cursor = root.walk();
    let mut depth = 0;
    loop {
        if cursor.goto_first_child() {
            depth += 1;
            if depth > limit {
                return Some(node_span(cursor.node()));
            }
            continue;
        }
        loop {
            if cursor.goto_next_sibling() {
                break;
            }
            if !cursor.goto_parent() {
                return None;
            }
            depth -= 1;
        }
    }
}

pub fn parse(source: &str) -> Result<tree_sitter::Tree, String> {
    parse_tree(source).map_err(|error| error.to_string())
}

pub fn parse_ast(source: &str) -> Result<ast::Module, Diagnostic> {
    on_large_stack(|| {
        let tree = parse_tree(source)?;
        lower::lower_module(source, tree.root_node())
    })
}

pub(crate) fn node_span(node: Node<'_>) -> Span {
    Span::new(SourceId::default(), node.start_byte(), node.end_byte())
}
