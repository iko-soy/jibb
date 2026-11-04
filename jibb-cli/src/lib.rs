mod formatter;

pub use formatter::format_source;

use tree_sitter::{Language, Parser};

unsafe extern "C" {
    fn tree_sitter_jibb() -> Language;
}

pub fn language() -> Language {
    unsafe { tree_sitter_jibb() }
}

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
