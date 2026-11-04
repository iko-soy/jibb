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
fn infers_and_instantiates_principal_gate_types() {
    let checked = check_source(
        "++ id |=(x x)\n++ named |= x=Msg x\n++ swap |= [a=Key b=Value] [b a]\n++ apply |= [f=$-(A B) x=A] (f x)\n++ text (id \"x\")\n++ number (id 1)\n",
    )
    .unwrap();
    assert_eq!(checked.values["id"].to_string(), "$-(A A)");
    assert_eq!(checked.values["named"].to_string(), "$-(Msg Msg)");
    assert_eq!(
        checked.values["swap"].to_string(),
        "$-([a=Key b=Value] [Value Key])"
    );
    assert_eq!(checked.values["apply"].to_string(), "$-([f=$-(A B) x=A] B)");
    assert_eq!(checked.values["text"].to_string(), "@t");
    assert_eq!(checked.values["number"].to_string(), "@ud");
}

#[test]
fn checks_forward_references_and_recursive_gate_groups() {
    let checked = check_source(
        "++ second first\n++ first 1\n++ even |= n=@ud (odd n)\n++ odd |= n=@ud (even n)\n",
    )
    .unwrap();
    assert_eq!(checked.values["first"].to_string(), "@ud");
    assert_eq!(checked.values["second"].to_string(), "@ud");
    assert_eq!(checked.values["even"].to_string(), "$-(@ud A)");
    assert_eq!(checked.values["odd"].to_string(), "$-(@ud A)");
}

#[test]
fn rejects_value_cycles_and_non_gate_recursion() {
    for source in [
        "++ value value\n",
        "++ value [|=(x=@ud value)]\n",
        "++ left right\n++ right left\n",
    ] {
        let error = check_source(source).unwrap_err();
        assert!(error.message.contains("non-gate value"), "{error}");
    }
}

#[test]
fn enforces_distinct_capitals_and_call_samples() {
    let error = check_source("++ bad |= [a=A b=B] ^- [A B] [b a]\n").unwrap_err();
    assert!(error.message.contains("distinct type variables"));
    assert_eq!(error.notes.len(), 2);

    let error = check_source("++ id |= x=@ud x\n++ bad (id \"x\")\n").unwrap_err();
    assert!(error.message.contains("type mismatch"), "{error}");

    let error = check_source("++ bad |=(x (x x))\n").unwrap_err();
    assert!(error.span.is_some());

    let error = check_source("++ unknown missing\n").unwrap_err();
    assert!(error.message.contains("unknown value"));
}

#[test]
fn resolves_definition_holes_without_later_use_constraints() {
    let checked = check_source("++ id |= x=A ^- _ x\n++ number ^- _ 1\n").unwrap();
    assert_eq!(checked.values["id"].to_string(), "$-(A A)");
    assert_eq!(checked.values["number"].to_string(), "@ud");

    let error = check_source("++ id |= x=_ x\n++ use (id \"x\")\n").unwrap_err();
    assert!(error.message.contains("unconstrained type hole"));
}

#[test]
fn checks_record_samples_and_calls() {
    let checked =
        check_source("++ first |= [x=@t y=@ud] x\n++ result (first [\"origin\" 0])\n").unwrap();
    assert_eq!(checked.values["first"].to_string(), "$-([x=@t y=@ud] @t)");
    assert_eq!(checked.values["result"].to_string(), "@t");
}

#[test]
fn checks_local_polymorphism_recursion_and_capital_scopes() {
    let checked = check_source(
        "++ use\n  ++ id |=(x x)\n  [(id 1) (id \"x\")]\n++ outer |= x=A\n  ++ inner |= y=A y\n  (inner x)\n++ independent |= x=@ud\n  ++ inner |= y=A y\n  inner\n",
    )
    .unwrap();
    assert_eq!(checked.values["use"].to_string(), "[@ud @t]");
    assert_eq!(checked.values["outer"].to_string(), "$-(A A)");
    assert_eq!(checked.values["independent"].to_string(), "$-(@ud $-(A A))");

    let checked = check_source("++ use\n  ++ recurse |= n=@ud (recurse n)\n  recurse\n").unwrap();
    assert_eq!(checked.values["use"].to_string(), "$-(@ud A)");

    let error = check_source("++ bad\n  ++ value value\n  value\n").unwrap_err();
    assert!(error.message.contains("non-gate value"));

    let error = check_source("++ bad\n  ++ f |= g=@ud g\n  ++ g 1\n  f\n").unwrap_err();
    assert!(error.message.contains("shadows a name"));
}

#[test]
fn unresolved_and_unsupported_features_fail_closed() {
    let error = check_source("+$ box [item=_]\n").unwrap_err();
    assert!(error.message.contains("unconstrained type hole"));

    let error = check_source("++ identity ~[1]\n").unwrap_err();
    assert!(error.message.contains("not available"));

    let error = check_source("++ branch ?- %.y\n  %.y 1\n  %.n 0\n").unwrap_err();
    assert!(error.message.contains("not available"));
}
