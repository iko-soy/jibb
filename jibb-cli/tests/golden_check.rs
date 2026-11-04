use jibb::{check, parse_ast};
use std::{fs, path::Path};

fn check_golden(name: &str) -> Result<jibb::check::CheckedModule, jibb::Diagnostic> {
    let source = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("tests/golden")
        .join(name)
        .join("source.jibb");
    let source = fs::read_to_string(source).expect("read type golden source");
    check(&parse_ast(&source).expect("golden source should lower"))
}

fn check_golden_lines(
    name: &str,
    last: usize,
) -> Result<jibb::check::CheckedModule, jibb::Diagnostic> {
    let source = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("tests/golden")
        .join(name)
        .join("source.jibb");
    let source = fs::read_to_string(source).expect("read type golden source");
    let source = format!(
        "{}\n",
        source.lines().take(last).collect::<Vec<_>>().join("\n")
    );
    check(&parse_ast(&source).expect("golden fragment should lower"))
}

#[test]
fn supported_type_golden_cases_follow_the_spec() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../tests/golden");
    if !root.is_dir() {
        return;
    }

    check_golden("types-typevar-print").expect("principal type schemes should check");
    let error = check_golden_lines("types-union-patterns", 13).expect_err("missing union case");
    assert!(error.message.contains("nonexhaustive branch"), "{error}");
    let error = check_golden_lines("types-single-case-pattern", 10).expect_err("invalid pattern");
    assert!(error.message.contains("pattern does not match"), "{error}");

    for (name, expected) in [
        ("types-record-faces", "type mismatch"),
        ("types-loobean-singleton-source", "type mismatch"),
        ("types-union-tag-atoms", "type mismatch"),
        ("types-union-overlap", "overlapping cases"),
        ("types-value-cycles", "non-gate value"),
    ] {
        let error = check_golden(name).expect_err(name);
        assert!(
            error.message.contains(expected),
            "{name}: expected {expected:?}, got {error}"
        );
    }
}
