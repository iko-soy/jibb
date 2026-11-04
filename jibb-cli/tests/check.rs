use jibb::{check, parse_ast};

fn check_source(source: &str) -> Result<jibb::check::CheckedModule, jibb::Diagnostic> {
    check(&parse_ast(source).expect("source should lower"))
}

#[test]
fn checks_literal_auras_and_directional_widening() {
    let checked = check_source(
        "++ decimal 1\n++ hex 0x1\n++ base32 0v1\n++ text \"x\"\n++ yes %.y\n++ unsigned ^- @u 1\n++ atom ^- @ 0x1\n++ noun ^- * 1\n++ empty !!\n",
    )
    .unwrap();
    let expected = [
        ("decimal", "@ud"),
        ("hex", "@ux"),
        ("base32", "@uv"),
        ("text", "@t"),
        ("yes", "?"),
        ("unsigned", "@u"),
        ("atom", "@"),
        ("noun", "*"),
        ("empty", "!!"),
    ];
    for (name, typ) in expected {
        assert_eq!(checked.values[name].to_string(), typ, "{name}");
    }
}

#[test]
fn distinguishes_loobean_and_term_literal_fitting() {
    let checked = check_source(
        "+$ yes %.y\n++ yes-flag ^- yes %.y\n++ yes-term ^- yes %$\n++ normal-flag ^- ? %.y\n++ normal-any ^- @ %.y\n++ literal-f ^- @f %.y\n++ numeric ^- @tas %1\n++ bit ^- @ta %&\n++ zero ^- ? %$\n++ one ^- ? %1\n",
    )
    .unwrap();
    assert_eq!(checked.values["yes-flag"].to_string(), "yes");
    assert_eq!(checked.values["yes-term"].to_string(), "yes");
    assert_eq!(checked.values["normal-flag"].to_string(), "?");
    assert_eq!(checked.values["normal-any"].to_string(), "@");
    assert_eq!(checked.values["literal-f"].to_string(), "@f");
    assert_eq!(checked.values["numeric"].to_string(), "@tas");
    assert_eq!(checked.values["bit"].to_string(), "@ta");
    assert_eq!(checked.values["zero"].to_string(), "?");
    assert_eq!(checked.values["one"].to_string(), "?");

    for source in [
        "+$ yes %.y\n++ wrong ^- yes %.n\n",
        "++ wrong ^- @tas %.y\n",
        "++ wrong ^- @ta %.y\n",
        "++ wrong ^- @ud %.y\n",
        "++ wrong ^- ? %2\n",
    ] {
        assert!(check_source(source).is_err(), "{source}");
    }
}

#[test]
fn rejects_incompatible_literal_auras() {
    for source in [
        "++ x ^- @dr 30\n",
        "++ x ^- @p 0\n",
        "++ x ^- @t 0x1\n",
        "++ x ^- @ud \"1\"\n",
    ] {
        let error = check_source(source).unwrap_err();
        assert!(error.message.contains("type mismatch"), "{error}");
        assert!(error.span.is_some());
    }
}

#[test]
fn resolves_tags_and_records_from_cast_context() {
    let checked = check_source(
        "+$ msg\n  %add\n  %stop\n++ message ^- msg %add\n++ point ^- [x=@t y=@ud] [\"origin\" 0]\n",
    )
    .unwrap();
    assert_eq!(checked.values["message"].to_string(), "msg");
    assert_eq!(checked.values["point"].to_string(), "[x=@t y=@ud]");

    let error = check_source("++ message %add\n").unwrap_err();
    assert!(error.message.contains("needs an expected type"));

    let error = check_source("+$ msg %add\n++ message ^- msg %stop\n").unwrap_err();
    assert!(error.message.contains("type mismatch"));
}

#[test]
fn checks_generic_molds_and_arity() {
    let checked = check_source(
        "+$ result |$ [V E]\n  [%ok value=V]\n  [%err error=E]\n+$ text-result (result @t @ud)\n",
    )
    .unwrap();
    assert_eq!(checked.molds["result"].parameters.len(), 2);
    assert_eq!(checked.molds["text-result"].cases.len(), 1);

    let error = check_source("+$ result |$ [V E] [V E]\n+$ bad (result @t)\n").unwrap_err();
    assert!(error.message.contains("expects 2 arguments"));

    let error = check_source("+$ bad [value=A]\n").unwrap_err();
    assert!(error.message.contains("not declared"));
}

#[test]
fn rejects_overlapping_union_cases_by_runtime_noun() {
    for source in [
        "+$ overlap\n  @t\n  @ud\n",
        "+$ overlap\n  %$\n  %.y\n",
        "+$ overlap\n  [%add @ud]\n  [%add @t]\n",
    ] {
        let error = check_source(source).unwrap_err();
        assert!(error.message.contains("overlapping cases"), "{error}");
        assert_eq!(error.notes.len(), 1);
    }

    check_source("+$ distinct\n  @t\n  [@ud @ud]\n").unwrap();
    check_source("+$ distinct\n  [%add @ud]\n  [%stop @t]\n").unwrap();
    check_source("+$ distinct\n  !!\n  @t\n").unwrap();
}

#[test]
fn rejects_duplicate_names_and_fields_with_related_spans() {
    let error = check_source("++ value 1\n++ value 2\n").unwrap_err();
    assert!(error.message.contains("duplicate definition"));
    assert_eq!(error.notes.len(), 1);
    assert!(error.to_string().contains("first definition"));

    let error = check_source("+$ bad [x=@t x=@ud]\n").unwrap_err();
    assert!(error.message.contains("duplicate record field"));
    assert_eq!(error.notes.len(), 1);

    let error = check_source("++ bad [x=1 x=2]\n").unwrap_err();
    assert!(error.message.contains("duplicate record field"));
}

#[test]
fn unresolved_and_unsupported_features_fail_closed() {
    let error = check_source("+$ box [item=_]\n").unwrap_err();
    assert!(error.message.contains("unconstrained type hole"));

    let error = check_source("++ identity |=(x x)\n").unwrap_err();
    assert!(error.message.contains("not available"));

    let error = check_source("++ first 1\n++ second first\n").unwrap_err();
    assert!(error.message.contains("not implemented"));
}
