pub mod ast;
pub mod check;
mod formatter;
mod lower;
pub mod types;

pub use check::check;
pub use formatter::format_source;

use ast::{SourceId, Span};
use std::fmt;
use tree_sitter::{Language, Node, Parser};

unsafe extern "C" {
    fn tree_sitter_jibb() -> Language;
}

pub fn language() -> Language {
    unsafe { tree_sitter_jibb() }
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

pub fn parse(source: &str) -> Result<tree_sitter::Tree, String> {
    let mut parser = Parser::new();
    parser
        .set_language(&language())
        .map_err(|error| error.to_string())?;
    let tree = parser
        .parse(source, None)
        .ok_or_else(|| "parser cancelled".to_string())?;
    if tree.root_node().has_error() {
        return Err(format!(
            "invalid Jibb syntax:\n{}",
            tree.root_node().to_sexp()
        ));
    }
    Ok(tree)
}

pub fn parse_ast(source: &str) -> Result<ast::Module, Diagnostic> {
    let mut parser = Parser::new();
    parser
        .set_language(&language())
        .map_err(|error| Diagnostic::new(error.to_string()))?;
    let tree = parser
        .parse(source, None)
        .ok_or_else(|| Diagnostic::new("parser cancelled"))?;
    let root = tree.root_node();
    lower::validate(root)?;
    lower::lower_module(source, root)
}

pub(crate) fn node_span(node: Node<'_>) -> Span {
    Span::new(SourceId::default(), node.start_byte(), node.end_byte())
}
