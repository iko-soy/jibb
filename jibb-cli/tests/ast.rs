use jibb::{
    Diagnostic,
    ast::{
        DefinitionKind, Expr, ExprKind, ImportKind, Literal, MoldKind, PatternKind, SampleKind,
        StringPart,
    },
    format_source, parse_ast,
};
use num_bigint::BigUint;
use std::{fs, path::Path};

fn module(source: &str) -> jibb::ast::Module {
    parse_ast(source).unwrap_or_else(|error| panic!("failed to lower:\n{source}\n{error}"))
}

fn value(source: &str) -> Expr {
    let module = module(source);
    match &module.definitions[0].kind {
        DefinitionKind::Value(value) => value.clone(),
        other => panic!("expected value definition, got {other:?}"),
    }
}

fn assert_same_surface(left: &str, right: &str) {
    assert_eq!(module(left).normalized(), module(right).normalized());
}

#[test]
fn numeric_literals_are_arbitrary_precision_and_strings_are_decoded() {
    let expression = value(
        "++ atoms [123.456.789.012.345.678.901.234.567.890 0xffff.ffff.ffff.ffff.ffff 0vvvv.vvvv \"a\\42\\7b\\5c\\22\\ff\" %.y %.n ~]\n",
    );
    let ExprKind::Tuple(items) = &expression.kind else {
        panic!("expected tuple: {expression:?}");
    };
    assert_eq!(
        items[0].value.kind,
        ExprKind::Literal(Literal::Number(
            BigUint::parse_bytes(b"123456789012345678901234567890", 10).unwrap()
        ))
    );
    assert_eq!(
        items[1].value.kind,
        ExprKind::Literal(Literal::Number(
            BigUint::parse_bytes(b"ffffffffffffffffffff", 16).unwrap()
        ))
    );
    assert_eq!(
        items[2].value.kind,
        ExprKind::Literal(Literal::Number(
            BigUint::parse_bytes(b"vvvvvvv", 32).unwrap()
        ))
    );
    assert_eq!(
        items[3].value.kind,
        ExprKind::Literal(Literal::String(b"aB{\\\"\xff".to_vec()))
    );
    assert_eq!(
        items[4].value.kind,
        ExprKind::Literal(Literal::Loobean(true))
    );
    assert_eq!(
        items[5].value.kind,
        ExprKind::Literal(Literal::Loobean(false))
    );
    assert_eq!(items[6].value.kind, ExprKind::Literal(Literal::Null));
}

#[test]
fn terms_constructors_and_knots_decode_to_runtime_values() {
    let expression = value("++ values [%add %1.000 %$ %& %| ~.some-knot |=%got]\n");
    let ExprKind::Tuple(items) = &expression.kind else {
        panic!("expected tuple: {expression:?}");
    };
    let terms = [
        BigUint::from_bytes_le(b"add"),
        BigUint::from(1_000u16),
        BigUint::default(),
        BigUint::default(),
        BigUint::from(1u8),
    ];
    for (item, expected) in items.iter().zip(terms) {
        assert_eq!(item.value.kind, ExprKind::Literal(Literal::Term(expected)));
    }
    assert_eq!(
        items[5].value.kind,
        ExprKind::Literal(Literal::Knot("some-knot".into()))
    );
    assert_eq!(
        items[6].value.kind,
        ExprKind::Constructor(BigUint::from_bytes_le(b"got"))
    );
}

#[test]
fn dotted_mold_faces_are_not_invented() {
    let error = parse_ast("+$ invalid [a.b=c]\n").unwrap_err();
    assert!(error.message.contains("unqualified"), "{error}");
}

#[test]
fn open_and_closed_containers_lower_identically() {
    assert_same_surface(
        "++ x ~[1 2 (f 3) [a=4 b=5] m(n=6)]\n",
        "++ x ~[\n  1\n  2\n  (f\n    3\n  [a=4 b=5]\n  m(\n    n=6\n",
    );
    assert_same_surface("++ x [1 2]\n", "++ x [\n  1\n  2\n");
    assert_same_surface("++ x m(a=1 b=2)\n", "++ x m(\n  a=1\n  b=2\n");
}

#[test]
fn redundant_groups_disappear_and_calls_have_head_and_arguments() {
    assert_same_surface("++ x (((f (g 1))))\n", "++ x f (g 1)\n");
    let expression = value("++ x f 1 2\n");
    let ExprKind::Call { head, arguments } = &expression.kind else {
        panic!("expected call: {expression:?}");
    };
    assert_eq!(head.kind, ExprKind::Reference(vec!["f".into()]));
    assert_eq!(arguments.len(), 2);
    assert!(matches!(value("++ x (1)\n").kind, ExprKind::Literal(_)));
}

#[test]
fn tall_wide_and_open_gates_share_one_representation() {
    assert_same_surface("++ id |=(x=@ud x)\n", "++ id |= x=@ud x\n");
    assert_same_surface("++ id |=(x=@ud ~[\n  x\n", "++ id |= x=@ud ~[x]\n");
    let expression = value("++ id |= x=@ud x\n");
    let ExprKind::Gate { sample, body } = &expression.kind else {
        panic!("expected gate: {expression:?}");
    };
    assert!(matches!(sample.kind, SampleKind::Face { .. }));
    assert_eq!(body.kind, ExprKind::Reference(vec!["x".into()]));
}

#[test]
fn bodies_and_rest_heads_are_normalized_into_nested_expressions() {
    let expression =
        value("++ outer |= x=@ud\n  ++ local |= y=@t y\n  ^- @ud ~& x\n  local \"done\"\n");
    let ExprKind::Gate { body, .. } = &expression.kind else {
        panic!("expected gate: {expression:?}");
    };
    let ExprKind::Body {
        definitions,
        result,
    } = &body.kind
    else {
        panic!("expected local body: {body:?}");
    };
    assert_eq!(definitions.len(), 1);
    let ExprKind::Cast { value, .. } = &result.kind else {
        panic!("expected cast: {result:?}");
    };
    let ExprKind::Trace { body, .. } = &value.kind else {
        panic!("expected trace: {value:?}");
    };
    assert!(matches!(body.kind, ExprKind::Call { .. }));
}

#[test]
fn interpolation_paths_imports_and_tight_expressions_are_semantic() {
    let module = module(
        "/- lib\n/% %mark\n/= card /ui/components/card\n++ x (f \"a{(g 1)}b\\7b\" %/blog/(slug) /todo/~zod tag+value `x |=%got)\n",
    );
    assert!(matches!(module.imports[0].kind, ImportKind::Library { .. }));
    assert!(matches!(module.imports[1].kind, ImportKind::Mark { .. }));
    assert!(matches!(module.imports[2].kind, ImportKind::Module { .. }));
    let DefinitionKind::Value(Expr {
        kind: ExprKind::Call { arguments, .. },
        ..
    }) = &module.definitions[0].kind
    else {
        panic!("expected call");
    };
    let ExprKind::String(parts) = &arguments[0].kind else {
        panic!("expected interpolation");
    };
    assert!(matches!(parts[0], StringPart::Text(_)));
    assert!(matches!(parts[1], StringPart::Expr(_)));
    assert!(matches!(arguments[1].kind, ExprKind::ApplicationPath(_)));
    assert!(matches!(arguments[2].kind, ExprKind::Path(_)));
    assert!(matches!(arguments[3].kind, ExprKind::Pair { .. }));
    assert!(matches!(arguments[4].kind, ExprKind::Unit(_)));
    assert!(matches!(arguments[5].kind, ExprKind::Constructor(_)));
}

#[test]
fn molds_samples_paths_and_patterns_have_dedicated_types() {
    let module = module(
        "+$ generic |$ [V E]\n  [%ok value=V]\n  [%err error=E]\n+$ route /todo/[id=@ud]/[slug=_]\n+$ function $-([A A] ?)\n+$ applied (map @t (list @ud))\n+$ puns [a=@ =msg]\n++ choose |= [a=@ud =msg m=model]\n  ?- a\n  [1 x] x\n  \"none\" ~\n  * !!\n",
    );
    let DefinitionKind::Mold(generic) = &module.definitions[0].kind else {
        panic!("expected mold");
    };
    assert_eq!(generic.generic.as_ref().unwrap().variables, ["V", "E"]);
    assert_eq!(generic.cases.len(), 2);
    let DefinitionKind::Mold(route) = &module.definitions[1].kind else {
        panic!("expected route mold");
    };
    assert!(matches!(route.cases[0].kind, MoldKind::Path(_)));
    let DefinitionKind::Mold(function) = &module.definitions[2].kind else {
        panic!("expected function mold");
    };
    assert!(matches!(function.cases[0].kind, MoldKind::Function { .. }));
    let DefinitionKind::Mold(applied) = &module.definitions[3].kind else {
        panic!("expected applied mold");
    };
    assert!(matches!(applied.cases[0].kind, MoldKind::Apply { .. }));
    let DefinitionKind::Value(Expr {
        kind: ExprKind::Gate { sample, body },
        ..
    }) = &module.definitions[5].kind
    else {
        panic!("expected gate");
    };
    let SampleKind::Cell(samples) = &sample.kind else {
        panic!("expected sample cell");
    };
    assert!(matches!(samples[1].kind, SampleKind::Pun(_)));
    let ExprKind::Branch { arms, .. } = &body.kind else {
        panic!("expected branch: {body:?}");
    };
    assert!(matches!(arms[0].pattern.kind, PatternKind::Cell(_)));
    assert!(matches!(
        arms[1].pattern.kind,
        PatternKind::Literal(Literal::String(_))
    ));
    assert!(matches!(arms[2].pattern.kind, PatternKind::Wildcard));
}

#[test]
fn spans_are_byte_ranges_and_normalization_erases_them() {
    let first = module("++ x (f 1)\n");
    let second = module("++  x  f 1\n");
    let definition = &first.definitions[0];
    assert_eq!(definition.span.start, 0);
    assert_eq!(definition.span.end, 10);
    assert_eq!(definition.span.source.0, 0);
    assert_ne!(first, second);
    assert_eq!(first.normalized(), second.normalized());
    assert_eq!(first.normalized().span, Default::default());
    assert_eq!(first.normalized().definitions[0].span, Default::default());
}

#[test]
fn invalid_syntax_returns_spanned_diagnostics() {
    for source in ["++ broken [a\n", "++ x \"\\q\"\n", "  ++ x 1\n"] {
        let error: Diagnostic = parse_ast(source).unwrap_err();
        assert!(error.span.is_some(), "{source:?}: {error}");
        assert!(error.to_string().contains("bytes"), "{error}");
    }
}

#[test]
fn formatting_preserves_normalized_ast_for_representative_programs() {
    let cases = [
        "++ x (((f (g 1))))\n",
        "++ id |=(x=@ud x)\n",
        "++ outer |= x=@ud\n  ++ local |= y=@t y\n  ^- @ud ~& x\n  local \"done\"\n",
        "+$ result |$ [V E]\n  [%ok value=V]\n  [%err error=E]\n",
        "++ x ~[1 2 [a=3 b=4] m(n=5)]\n",
        "++ text (f \"{(lent items)} items\" %/blog/((slug-for slug)))\n",
    ];
    for source in cases {
        let formatted = format_source(source).expect("representative source should format");
        assert_eq!(
            module(source).normalized(),
            module(&formatted).normalized(),
            "formatter changed semantics:\nSOURCE:\n{source}\nFORMATTED:\n{formatted}"
        );
    }
}

fn valid_case(about: &Path) -> bool {
    let Ok(metadata) = fs::read_to_string(about) else {
        return true;
    };
    metadata
        .lines()
        .find(|line| line.starts_with("expect:"))
        .is_none_or(|line| {
            line.starts_with("expect: parses") || line.starts_with("expect: unclear")
        })
}

#[test]
fn every_golden_case_lowers_and_valid_cases_survive_formatting() {
    let golden = Path::new(env!("CARGO_MANIFEST_DIR")).join("../tests/golden");
    if !golden.is_dir() {
        return;
    }
    let mut checked = 0;
    let mut valid_count = 0;
    let mut invalid_count = 0;
    let mut failures = Vec::new();
    for entry in fs::read_dir(&golden).expect("read golden corpus") {
        let source_path = entry
            .expect("golden directory entry")
            .path()
            .join("source.jibb");
        if !source_path.is_file() {
            continue;
        }
        checked += 1;
        let valid = valid_case(&source_path.with_file_name("about.txt"));
        let Ok(source) = fs::read_to_string(&source_path) else {
            if valid {
                failures.push(format!(
                    "{}: valid case is not UTF-8",
                    source_path.display()
                ));
            } else {
                invalid_count += 1;
            }
            continue;
        };
        let lowered = std::panic::catch_unwind(|| parse_ast(&source));
        match (valid, lowered) {
            (true, Ok(Ok(original))) => {
                valid_count += 1;
                match format_source(&source) {
                    Ok(formatted) => match parse_ast(&formatted) {
                        Ok(reparsed) if original.normalized() == reparsed.normalized() => {}
                        Ok(_) => failures.push(format!(
                            "{}: formatting changed the normalized AST",
                            source_path.display()
                        )),
                        Err(error) => failures.push(format!(
                            "{}: formatted source did not lower: {error}",
                            source_path.display()
                        )),
                    },
                    Err(error) => failures.push(format!(
                        "{}: valid source did not format: {error}",
                        source_path.display()
                    )),
                }
            }
            (true, Ok(Err(error))) => failures.push(format!(
                "{}: valid source did not lower: {error}",
                source_path.display()
            )),
            (true, Err(_)) => failures.push(format!(
                "{}: lowering panicked on valid source",
                source_path.display()
            )),
            (false, Ok(Err(_))) | (false, Err(_)) => invalid_count += 1,
            (false, Ok(Ok(module))) => failures.push(format!(
                "{}: invalid source was lowered: {module:?}",
                source_path.display()
            )),
        }
    }
    assert!(checked >= 750, "only {checked} golden cases were found");
    assert!(valid_count > 0 && invalid_count > 0);
    assert!(
        failures.is_empty(),
        "{} golden lowering failures (checked {checked}, valid {valid_count}, invalid {invalid_count}):\n{}",
        failures.len(),
        failures
            .iter()
            .take(30)
            .cloned()
            .collect::<Vec<_>>()
            .join("\n")
    );
}
