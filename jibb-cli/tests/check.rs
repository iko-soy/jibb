use jibb::{check, parse_ast};

fn check_source(source: &str) -> Result<jibb::check::CheckedModule, jibb::Diagnostic> {
    check(&parse_ast(source).expect("source should lower"))
}

fn assert_check_error(source: &str, message: &str, excerpt: &str) {
    let error = check_source(source).unwrap_err();
    assert_eq!(error.message, message, "{error}");
    let span = error.span.unwrap_or_else(|| panic!("{error} has no span"));
    assert_eq!(&source[span.start..span.end], excerpt, "{error}");
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
        "+$ yes %.y\n++ yes-flag ^- yes %.y\n++ yes-term ^- yes %$\n++ normal-flag ^- ? %.y\n++ normal-any ^- @ %.y\n++ literal-f ^- @f %.y\n++ numeric ^- @ud %1.000\n++ inferred-numeric %1.000\n++ singleton ^- %1.000 %1.000\n++ bit ^- ? %&\n++ inferred-boolean %&\n++ zero ^- ? %$\n++ one ^- ? %1\n++ name ^- @t %hello\n++ knot ^- @ta %hello\n++ term ^- @tas %hello\n",
    )
    .unwrap();
    assert_eq!(checked.values["yes-flag"].to_string(), "yes");
    assert_eq!(checked.values["yes-term"].to_string(), "yes");
    assert_eq!(checked.values["normal-flag"].to_string(), "?");
    assert_eq!(checked.values["normal-any"].to_string(), "@");
    assert_eq!(checked.values["literal-f"].to_string(), "@f");
    assert_eq!(checked.values["numeric"].to_string(), "@ud");
    assert_eq!(checked.values["inferred-numeric"].to_string(), "@ud");
    assert_eq!(checked.values["singleton"].to_string(), "%1.000");
    assert_eq!(checked.values["bit"].to_string(), "?");
    assert_eq!(checked.values["inferred-boolean"].to_string(), "?");
    assert_eq!(checked.values["zero"].to_string(), "?");
    assert_eq!(checked.values["one"].to_string(), "?");
    assert_eq!(checked.values["name"].to_string(), "@t");
    assert_eq!(checked.values["knot"].to_string(), "@ta");
    assert_eq!(checked.values["term"].to_string(), "@tas");

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
fn rejects_terms_outside_their_hoon_auras_with_literal_diagnostics() {
    for (source, message, excerpt) in [
        (
            "++ wrong ^- @tas %1\n",
            "type mismatch: expected @tas, found %1",
            "%1",
        ),
        (
            "++ wrong ^- @ud %name\n",
            "type mismatch: expected @ud, found %name",
            "%name",
        ),
        (
            "++ wrong ^- @t %1.000\n",
            "type mismatch: expected @t, found %1.000",
            "%1.000",
        ),
        (
            "++ wrong ^- @t %&\n",
            "type mismatch: expected @t, found ?",
            "%&",
        ),
    ] {
        assert_check_error(source, message, excerpt);
    }
}

#[test]
fn checks_boolean_terms_in_branches() {
    let checked =
        check_source("++ choose |= b=? ?- b\n  %& 1\n  %| 0\n++ answer (choose %&)\n").unwrap();
    assert_eq!(checked.values["choose"].to_string(), "$-(? @ud)");
    assert_eq!(checked.values["answer"].to_string(), "@ud");

    assert_check_error(
        "++ bad |= b=? ?- b\n  %2 1\n  * 0\n",
        "pattern does not match the branch subject",
        "%2",
    );
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
    assert_eq!(error.message, "nothing fixes the union of %add; add a `^-`");
    assert_eq!(
        error.span.map(|span| (span.start, span.end)),
        Some((11, 15))
    );

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
fn checks_loobean_and_union_branches() {
    let checked = check_source(
        "++ choose |= b=? ?- b\n  %.y 1\n  %.n 0\n+$ msg\n  [%add n=@ud]\n  %stop\n++ describe |= m=msg ?- m\n  [%add n] n\n  %stop 0\n++ answer (choose %.y)\n",
    )
    .unwrap();
    assert_eq!(checked.values["choose"].to_string(), "$-(? @ud)");
    assert_eq!(checked.values["describe"].to_string(), "$-(msg @ud)");
    assert_eq!(checked.values["answer"].to_string(), "@ud");

    let error = check_source("++ bad |= b=? ?- b\n  %.y 1\n").unwrap_err();
    assert!(error.message.contains("nonexhaustive"));

    let error = check_source("+$ msg %stop\n++ bad |= m=msg ?- m\n  stop 0\n").unwrap_err();
    assert!(error.message.contains("spells a tag"));
}

#[test]
fn checks_nested_pattern_coverage_and_covered_arms() {
    let checked =
        check_source("++ both |= [a=? b=?] ?- [a b]\n  [%.y *] 1\n  [%.n *] 0\n").unwrap();
    assert_eq!(checked.values["both"].to_string(), "$-([a=? b=?] @ud)");

    for source in [
        "++ bad |= b=? ?- b\n  * 1\n  %.y 0\n",
        "++ bad |= n=@ud ?- n\n  0 1\n  0 2\n  * 3\n",
        "++ bad |= b=? ?- b\n  %.y 1\n  %.y 0\n  %.n 1\n",
    ] {
        let error = check_source(source).unwrap_err();
        assert!(error.message.contains("covered by earlier"), "{error}");
    }

    let error = check_source("++ bad |= n=@ud ?- n\n  0 1\n").unwrap_err();
    assert!(error.message.contains("nonexhaustive"));
}

#[test]
fn rejects_incompatible_patterns_and_branch_results() {
    let error = check_source("++ bad |= b=? ?- b\n  \"yes\" 1\n  * 0\n").unwrap_err();
    assert!(error.message.contains("does not match"));

    let error = check_source("++ bad |= b=? ?- b\n  %.y 1\n  %.n \"no\"\n").unwrap_err();
    assert!(error.message.contains("type mismatch"));
}

#[test]
fn checks_record_wings_and_changes() {
    let checked = check_source(
        "++ city |= p=[name=@t address=[city=@t zip=@ud]] city.address.p\n++ relocate |= p=[name=@t address=[city=@t zip=@ud]] p(city.address=\"new\")\n++ renamed |= p=[name=@t age=@ud] p(name=\"new\" age=2)\n++ result (city [name=\"n\" address=[city=\"x\" zip=1]])\n",
    )
    .unwrap();
    assert_eq!(
        checked.values["city"].to_string(),
        "$-([name=@t address=[city=@t zip=@ud]] @t)"
    );
    assert_eq!(
        checked.values["relocate"].to_string(),
        "$-([name=@t address=[city=@t zip=@ud]] [name=@t address=[city=@t zip=@ud]])"
    );
    assert_eq!(checked.values["result"].to_string(), "@t");

    for source in [
        "++ bad |= p=[x=@ud y=@ud] p(x=1 x=2)\n",
        "++ bad |= p=[name=@t age=@ud] p(name=1)\n",
        "++ bad |= p=[name=@t age=@ud] missing.p\n",
        "++ bad |= p=[address=[city=@t zip=@ud]] p(address=[city=\"x\" zip=1] city.address=\"y\")\n",
    ] {
        assert!(check_source(source).is_err(), "{source}");
    }

    let error = check_source(
        "++ bad |= p=[address=[city=@t zip=@ud]] p(address=[city=\"x\" zip=1] city.address=\"y\")\n",
    )
    .unwrap_err();
    assert_eq!(
        error.message,
        "change fields `address` and `city.address` overlap"
    );
    assert_eq!(error.notes[0].message, "first field");
}

#[test]
fn checks_lists_units_pairs_and_constructors_from_molds() {
    let checked = check_source(
        "+$ list |$ [A]\n  ~\n  [head=A tail=(list A)]\n+$ unit |$ [A]\n  ~\n  [~ value=A]\n+$ attr\n  [%fill n=@ud]\n  [%gap size=@ud]\n+$ msg\n  [%add n=@ud]\n  %stop\n++ attrs ^- (list attr) ~[fill+1 gap+2]\n++ maybe ^- (unit @t) `\"x\"\n++ empty ~[]\n++ add ^- $-(@ud msg) |=%add\n++ made ^- msg (|=%add 1)\n",
    )
    .unwrap();
    assert_eq!(checked.values["attrs"].to_string(), "(list attr)");
    assert_eq!(checked.values["maybe"].to_string(), "(unit @t)");
    assert_eq!(checked.values["empty"].to_string(), "(list A)");
    assert_eq!(checked.values["add"].to_string(), "$-(@ud msg)");
    assert_eq!(checked.values["made"].to_string(), "msg");

    let error = check_source("++ bad ~[1]\n").unwrap_err();
    assert!(error.message.contains("standard list mold"));
}

#[test]
fn checks_projection_unface_and_interpolation() {
    let checked = check_source(
        "++ project |= p=[x=@ud y=@t] ^- [x=@ud] (proj p)\n++ erase |= p=[x=@ud y=@t] (unface p)\n++ render |= [day=@da n=@ud] \"Updated {day}: {n}\"\n",
    )
    .unwrap();
    assert_eq!(
        checked.values["project"].to_string(),
        "$-([x=@ud y=@t] [x=@ud])"
    );
    assert_eq!(
        checked.values["erase"].to_string(),
        "$-([x=@ud y=@t] [@ud @t])"
    );
    assert_eq!(
        checked.values["render"].to_string(),
        "$-([day=@da n=@ud] @t)"
    );

    assert!(check_source("++ bad |= n=A \"{n}\"\n").is_err());
    assert!(check_source("++ bad |= p=[x=@ud] (proj p)\n").is_err());
    check_source("++ main ^- [x=@ud] (proj p)\n++ p [x=42 y=2]\n").unwrap();
}

#[test]
fn checks_local_molds_and_restores_lexical_scopes() {
    let checked = check_source(
        "++ use\n  +$ point [x=@ud y=@ud]\n  ++ make |= p=point x.p\n  (make [1 2])\n++ recursive\n  +$ list |$ [A]\n    ~\n    [head=A tail=(list A)]\n  ++ xs ^- (list @ud) ~[1]\n  ^- * xs\n++ first\n  +$ local @ud\n  ++ x ^- local 1\n  ^- @ud x\n++ second\n  +$ local @t\n  ++ x ^- local \"x\"\n  ^- @t x\n",
    )
    .unwrap();
    assert_eq!(checked.values["use"].to_string(), "@ud");
    assert_eq!(checked.values["recursive"].to_string(), "*");
    assert_eq!(checked.values["first"].to_string(), "@ud");
    assert_eq!(checked.values["second"].to_string(), "@t");

    // A local mold is written out where the body's type leaves its scope; a
    // recursive one cannot be.
    let checked = check_source("++ bad\n  +$ local @ud\n  ++ x ^- local 1\n  x\n").unwrap();
    assert_eq!(checked.values["bad"].to_string(), "@ud");
    let error =
        check_source("++ bad\n  +$ chain\n    ~\n    [@ud chain]\n  ++ x ^- chain ~\n  x\n")
            .unwrap_err();
    assert_eq!(
        error.message,
        "a recursive local mold cannot escape its lexical scope in an inferred type"
    );

    let error = check_source("++ bad\n  +$ overlap\n    @t\n    @ud\n  1\n").unwrap_err();
    assert!(error.message.contains("overlapping cases"));
}

#[test]
fn fits_tagged_cells_against_named_unions() {
    let checked = check_source(
        "+$ element |$ [M]\n  [%row payload=@t]\n  [%button label=@t message=M]\n++ button |= [label=@t message=M] ^- (element M) [%button label message]\n",
    )
    .unwrap();
    assert_eq!(
        checked.values["button"].to_string(),
        "$-([label=@t message=M] (element M))"
    );
}

#[test]
fn selects_generic_union_cases_by_leading_tag() {
    let checked = check_source("+$ list |$ [A]\n  ~\n  [i=A t=(list A)]\n+$ unit |$ [A]\n  ~\n  [~ u=A]\n+$ agent-path (list @ta)\n+$ ask |$ [M]\n  [%pure value=M]\n  [%agent api=@t case=@tas agent=@tas path=agent-path scry=(unit agent-path) receive=$-([mark=@tas state=(unit *) fact=*] [state=* message=M])]\n  [%store module=@t name=@tas receive=$-([state=(unit *) fact=*] [state=* message=M])]\n++ pure |= x=M ^- (ask M) [%pure x]\n")
        .unwrap();
    assert_eq!(checked.values["pure"].to_string(), "$-(M (ask M))");
}

fn check_with_primitives(source: &str) -> Result<jibb::check::CheckedModule, jibb::Diagnostic> {
    let source = format!("/= core /lib/jibb/primitives\n{source}");
    jibb::loader::check_source(&source, std::path::Path::new("primitives.jibb"), &[], None)
}

#[test]
fn native_primitives_carry_static_constraints() {
    let checked = check_with_primitives(
        "++ inc |= n=A (raw-add.core n 1)\n++ compare |= [a=A b=A] (raw-gth.core a b)\n++ same-atom |= [a=A b=A] (raw-eq.core a b)\n",
    )
    .unwrap();
    assert_eq!(
        checked.values["inc"].to_string(),
        "$-(A A) where A is an atom other than ?"
    );
    assert_eq!(
        checked.values["compare"].to_string(),
        "$-([a=A b=A] ?) where A is an atom"
    );
    assert_eq!(
        checked.values["same-atom"].to_string(),
        "$-([a=A b=A] ?) where A contains no gates"
    );

    let error = check_with_primitives("++ bad |= x=? (raw-add.core x 1)\n").unwrap_err();
    assert!(error.message.contains("type mismatch"), "{error}");
    let error = check_with_primitives("++ bad (raw-eq.core |=(x x) |=(y y))\n").unwrap_err();
    assert!(error.message.contains("containing no gates"), "{error}");
}

#[test]
fn numeric_terms_are_arithmetic_atoms_but_boolean_terms_are_not() {
    let checked = check_with_primitives(
        "++ sum (raw-add.core %1.000 2)\n++ increment |= n=A (raw-add.core n %1.000)\n",
    )
    .unwrap();
    assert_eq!(checked.values["sum"].to_string(), "@ud");
    assert_eq!(
        checked.values["increment"].to_string(),
        "$-(A A) where A is an atom other than ?"
    );

    let source = "/= core /lib/jibb/primitives\n++ bad (raw-add.core %& %1)\n";
    let error =
        jibb::loader::check_source(source, std::path::Path::new("primitives.jibb"), &[], None)
            .unwrap_err();
    assert_eq!(
        error.message,
        "type constraint requires an atom other than ?, found ?"
    );
    let span = error.span.unwrap_or_else(|| panic!("{error} has no span"));
    assert_eq!(&source[span.start..span.end], "raw-add.core", "{error}");
}

#[test]
fn unresolved_and_unsupported_features_fail_closed() {
    let error = check_source("+$ box [item=_]\n").unwrap_err();
    assert!(error.message.contains("unconstrained type hole"));

    let error = check_source("++ identity ~[1]\n").unwrap_err();
    assert!(error.message.contains("standard list mold"));

    let error = check_source("++ path %/blog\n").unwrap_err();
    assert!(error.message.contains("not available"));
}
