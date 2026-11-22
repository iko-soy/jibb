//! Regression tests for the 2026-11-16 audit of the native checker,
//! evaluator, literals, loader and formatter. Each test fails on the code
//! before the fix it covers.

use jibb::{
    Diagnostic, check, format_source, loader, parse_ast,
    value::{Noun, Value},
};
use num_bigint::BigUint;
use std::{
    fs,
    path::{Path, PathBuf},
};

fn dev() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../jibb-dev")
}

fn prelude() -> PathBuf {
    dev().join("lib/jibb/prelude.jibb")
}

/// Evaluates `main` of a module with no prelude.
fn run(source: &str) -> Result<Value, Diagnostic> {
    loader::evaluate_source(source, Path::new("audit.jibb"), "main", &[], None)
}

/// Evaluates `main` with the source prelude.
fn run_prelude(source: &str) -> Result<Value, Diagnostic> {
    let prelude = prelude();
    loader::evaluate_source(
        source,
        Path::new("audit.jibb"),
        "main",
        &[dev()],
        Some(&prelude),
    )
}

fn check_prelude(source: &str) -> Result<jibb::check::CheckedModule, Diagnostic> {
    let prelude = prelude();
    loader::check_source(source, Path::new("audit.jibb"), &[dev()], Some(&prelude))
}

fn ok(result: Result<Value, Diagnostic>) -> String {
    result
        .unwrap_or_else(|error| panic!("evaluation failed: {error}"))
        .to_string()
}

/// The text of a cord result.
fn cord(result: Result<Value, Diagnostic>) -> String {
    let value = result.unwrap_or_else(|error| panic!("evaluation failed: {error}"));
    let Value::Noun(noun) = value else {
        panic!("expected a cord, got {value}")
    };
    let Noun::Atom(atom) = noun.as_ref() else {
        panic!("expected a cord atom")
    };
    if atom.bits() == 0 {
        return String::new();
    }
    String::from_utf8(atom.to_bytes_le()).expect("UTF-8 cord")
}

/// Asserts an error's message and the source text its span covers.
fn assert_error(error: &Diagnostic, source: &str, message: &str, excerpt: &str) {
    assert_eq!(error.message, message, "{error}");
    let span = error.span.unwrap_or_else(|| panic!("{error} has no span"));
    assert_eq!(&source[span.start..span.end], excerpt, "{error}");
}

fn check_source(source: &str) -> Result<jibb::check::CheckedModule, Diagnostic> {
    check(&parse_ast(source)?)
}

#[test]
fn a_second_reference_to_an_outer_name_is_not_a_cycle() {
    assert_eq!(
        ok(run("++ k 5\n++ f |= n=@ud [k k]\n++ main (f 1)\n")),
        "[5 5]"
    );
    assert_eq!(
        ok(run(
            "++ g |= n=@ud n\n++ f |= n=@ud [(g n) (g n)]\n++ main (f 1)\n"
        )),
        "[1 1]"
    );
    assert_eq!(
        ok(run("++ g |= n=@ud n\n++ main\n  ++ a (g 1)\n  [a (g 2)]\n")),
        "[1 2]"
    );
    // A real cycle is still reported.
    let source = "++ main\n  ++ a b\n  ++ b a\n  a\n";
    let error = run(source).unwrap_err();
    assert_eq!(error.message, "non-gate value `a` depends on itself");
}

#[test]
fn prelude_arithmetic_and_list_gates_run() {
    assert_eq!(
        ok(run_prelude(
            "++ inc |= n=@ud (add n 1)\n++ main [(sub 5 2) (mul 3 4) (div 7 2) (mod 7 2) (snag 1 ~[10 20 30]) (turn ~[1 2 3] inc)]\n"
        )),
        // `[… 20 ~[2 3 4]]` is the noun `[… 20 2 3 4 ~]`.
        "[3 12 3 1 20 2 3 4]"
    );
    // A crash in the prelude stays a crash.
    let error = run_prelude("++ main (sub 1 2)\n").unwrap_err();
    assert_eq!(error.message, "decrement underflow");
}

#[test]
fn prelude_binders_do_not_clash_with_the_modules_own_names() {
    // The prelude's `turn` binds `f` and `item`; this module's own `f` and
    // `item` are not in the prelude's scope.
    assert_eq!(
        ok(run_prelude(
            "++ f |= n=@ud (add n 1)\n++ item 3\n++ main (turn ~[1 item] f)\n"
        )),
        "[2 4]"
    );
    // The module's own binders still may not shadow the prelude.
    let source = "++ main |= turn=@ud turn\n";
    let error = check_prelude(source).unwrap_err();
    assert_error(
        &error,
        source,
        "sample binder `turn` shadows a name",
        "turn=@ud",
    );
}

#[test]
fn wings_read_from_their_last_name_inward() {
    let records = "++ p [a=[b=1 a=2] b=[a=3 b=4]]\n";
    assert_eq!(ok(run(&format!("{records}++ main a.b.p\n"))), "3");
    assert_eq!(
        ok(run(&format!("{records}++ main p(a.b=9)\n"))),
        "[[1 2] 9 4]"
    );
    let checked = check_source(&format!("{records}++ x a.b.p\n++ y p(a.b=9)\n")).unwrap();
    assert_eq!(checked.values["x"].to_string(), "@ud");

    let source = "++ p [a=[b=1 c=2] d=3]\n++ main p(b.a=9 a=[b=1 c=2])\n";
    let error = check_source(source).unwrap_err();
    assert_error(
        &error,
        source,
        "change fields `b.a` and `a` overlap",
        "a=[b=1 c=2]",
    );
    assert_eq!(error.notes[0].message, "first field");
}

#[test]
fn wings_through_an_import_face_read_the_imported_definition() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::write(root.join("util.jibb"), "++ rec [a=[b=7 c=8] d=9]\n").unwrap();
    let main = root.join("main.jibb");
    fs::write(&main, "/= util /util\n++ main [b.a.rec.util d.rec.util]\n").unwrap();
    let value = loader::evaluate_path(&main, "main", &[root.to_path_buf()], None).unwrap();
    assert_eq!(value.to_string(), "[7 9]");
}

#[test]
fn atom_variables_bind_the_aura_that_fits_them() {
    for (source, message, excerpt) in [
        (
            "++ x (add ~s1 1)\n",
            "type mismatch: `1` is a @ud, not a @dr; write ~s1",
            "1",
        ),
        (
            "++ x (add 1 ~s1)\n",
            "type mismatch: `1` is a @ud, not a @dr; write ~s1",
            "1",
        ),
        (
            "++ x (add ~zod \"abc\")\n",
            "type mismatch: expected @p, found @t",
            "\"abc\"",
        ),
        (
            "++ x (gth \"a\" 1)\n",
            "type mismatch: `1` is a @ud, not a @t; write \"1\"",
            "1",
        ),
        (
            "++ x ^- @p (add ~zod \"abc\")\n",
            "type mismatch: expected @p, found @t",
            "\"abc\"",
        ),
    ] {
        let error = check_prelude(source).unwrap_err();
        assert_error(&error, source, message, excerpt);
    }
    // The sum in an interpolation takes the decimal's default, @ud.
    assert_eq!(cord(run_prelude("++ main \"{(add 1 2)}\"\n")), "3");
    let checked = check_prelude(
        "++ bump |= x=A (add x 1)\n++ later (bump ~s1)\n++ count (bump 2)\n++ sum (add 1 2)\n",
    )
    .unwrap();
    assert_eq!(
        checked.values["bump"].to_string(),
        "$-(A A) where A is an atom other than ?"
    );
    assert_eq!(checked.values["later"].to_string(), "@dr");
    assert_eq!(checked.values["count"].to_string(), "@ud");
    assert_eq!(checked.values["sum"].to_string(), "@ud");
}

#[test]
fn capitals_cannot_be_fixed_to_a_specific_type() {
    for (source, message, excerpt) in [
        (
            "++ f |= x=A ^- A ~s1\n",
            "capital `A` cannot be fixed to @dr",
            "~s1",
        ),
        (
            "++ f |= x=A ^- A 1\n",
            "capital `A` cannot be fixed to @ud",
            "1",
        ),
        (
            "++ f |= [x=A y=@ud] ^- A y\n",
            "capital `A` cannot be fixed to @ud",
            "y",
        ),
    ] {
        let error = check_source(source).unwrap_err();
        assert_error(&error, source, message, excerpt);
        assert_eq!(error.notes[0].message, "capital");
    }
    // A capital cast to `@` gains the atom constraint instead.
    let checked =
        check_source("++ keep |= x=A\n  ~& ^- @ x\n    x\n++ ship (keep ~zod)\n").unwrap();
    assert_eq!(
        checked.values["keep"].to_string(),
        "$-(A A) where A is an atom"
    );
    assert_eq!(checked.values["ship"].to_string(), "@p");
}

#[test]
fn local_definitions_do_not_generalize_the_enclosing_scopes_variables() {
    let source = "++ wrap-value |= y |=(z y)\n++ f |= x\n  ++ local (wrap-value x)\n  ^- [@ud @ud] (local 0)\n++ g |= p=[@ud @ud]\n  ?- p\n    [a b] a\n++ main (g (f 5))\n";
    // `local` keeps `x`'s variable, so the cast fixes `f` to take a pair and
    // the call with 5 is the error.
    let error = run(source).unwrap_err();
    assert_error(
        &error,
        source,
        "type mismatch: expected [@ud @ud], found @ud",
        "5",
    );
}

#[test]
fn syntax_with_missing_nodes_is_rejected_and_a_missing_final_newline_is_not() {
    for (source, excerpt) in [
        ("++  main  ~[1 2 3x]\n++  x  4\n", "~[1 2 3x]"),
        ("++  a  1++  main  [a 2]\n", "++"),
    ] {
        let error = parse_ast(source).unwrap_err();
        assert!(error.message.starts_with("invalid Jibb syntax"), "{error}");
        let span = error.span.expect("syntax errors are located");
        assert!(
            source[span.start..span.end].contains(excerpt)
                || excerpt.contains(&source[span.start..span.end]),
            "{error}: {:?}",
            &source[span.start..span.end]
        );
        assert!(run(source).is_err());
        assert!(format_source(source).is_err());
    }
    for (source, value) in [("++  main  42", "42"), ("++  main\n  ^-  @ud  5", "5")] {
        parse_ast(source).unwrap();
        assert_eq!(ok(run(source)), value);
        assert_eq!(format_source(source).unwrap(), format!("{source}\n"));
    }
}

#[test]
fn a_byte_order_mark_is_rejected_by_every_command() {
    let source = "\u{feff}++  main  42\n";
    let error = parse_ast(source).unwrap_err();
    assert_eq!(
        error.message,
        "invalid Jibb syntax: a byte order mark is not allowed"
    );
    let error = format_source(source).unwrap_err();
    assert!(
        error.contains("a byte order mark is not allowed"),
        "{error}"
    );
}

#[test]
fn calendar_literals_are_validated_when_checked() {
    for (source, message) in [
        (
            "++ d ~2026.14.1\n",
            "invalid date literal `~2026.14.1`: the month is not from 1 to 12",
        ),
        (
            "++ d ~2026.0.1\n",
            "invalid date literal `~2026.0.1`: the month is not from 1 to 12",
        ),
        (
            "++ d ~2026.1.0\n",
            "invalid date literal `~2026.1.0`: the day is 0",
        ),
        (
            "++ d ~0-.1.1\n",
            "invalid date literal `~0-.1.1`: there is no year 0 BC",
        ),
        ("++ d ~zzz\n", "`~zzz` is not a valid @p"),
    ] {
        let error = check_source(source).unwrap_err();
        let literal = source.trim_start_matches("++ d ").trim_end();
        assert_error(&error, source, message, literal);
    }
    let year = "~100000000000000000000000000000000000000.1.1";
    assert_eq!(cord(run(&format!("++ main \"{{{year}}}\"\n"))), year);
    assert_eq!(cord(run("++ main \"{~0.1.1}\"\n")), "~1-.1.1");
    assert_eq!(
        cord(run("++ main \"{~d99999999999999999999}\"\n")),
        "~d99999999999999999999"
    );
}

#[test]
fn sub_second_groups_are_the_top_bits_of_the_fraction() {
    let half = run("++ main ~s0..8000\n").unwrap();
    assert_eq!(half.to_string(), (BigUint::from(1u8) << 63u32).to_string());
    assert_eq!(cord(run("++ main \"{~s0..8000}\"\n")), "~s0..8000");
    assert_eq!(
        cord(run("++ main \"{~s1..0001.0002}\"\n")),
        "~s1..0001.0002"
    );
    assert_eq!(
        cord(run("++ main \"{~2026.1.1..00.00.00..0001.0002}\"\n")),
        "~2026.1.1..00.00.00..0001.0002"
    );
    assert_eq!(
        cord(run_prelude(
            "++ half ~s0..8000\n++ sum ^- @dr (add half half)\n++ main \"{sum}\"\n"
        )),
        "~s1"
    );
}

#[test]
fn the_empty_cord_has_no_bytes() {
    assert_eq!(ok(run_prelude("++ main (trip \"\")\n")), "0");
    assert_eq!(
        cord(run("++ empty ^- @t \"\"\n++ main \"a{empty}b\"\n")),
        "ab"
    );
}

#[test]
fn evaluation_follows_the_checked_types() {
    let identity = "++ id |= x=A x\n";
    assert_eq!(
        ok(run(&format!(
            "{identity}++ p (id [x=1 y=2])\n++ main y.p\n"
        ))),
        "2"
    );
    assert_eq!(
        ok(run(&format!(
            "{identity}++ p (id [x=1 y=2])\n++ main p(y=5)\n"
        ))),
        "[1 5]"
    );
    assert_eq!(
        ok(run(&format!(
            "{identity}++ main ^- [x=@ud] (proj (id [x=1 y=2]))\n"
        ))),
        "1"
    );
    assert_eq!(
        ok(run("++ r [f=|=(n=@ud n) n=1]\n++ s r(n=2)\n++ main n.s\n")),
        "2"
    );
    // A cell holding a gate is a cell like any other, so its gate-free rest
    // compares equal to the same noun.
    assert_eq!(
        ok(run_prelude(
            "++ g |= n=@ud n\n++ t [g 1 2]\n++ main\n  ?-  t\n    [f b]  (eq b [1 2])\n"
        )),
        "0"
    );
}

#[test]
fn traces_print_with_their_types_printer() {
    // Printing goes to standard error; the program still runs to its value.
    assert_eq!(
        ok(run("++ main\n  ~&  \"hi\"\n  ~&  ~zod\n  ~&  ~s1\n  5\n")),
        "5"
    );
    let source = "++ main\n  ~&  [1 2]\n  5\n";
    let error = run(source).unwrap_err();
    assert_error(
        &error,
        source,
        "a trace has no printer for [@ud @ud]; trace an atom or a tape",
        "[1 2]",
    );
}

#[test]
fn primitives_are_found_through_the_face_that_imports_them() {
    let source = "++ main (raw-add.core 40 2)\n";
    let error = run(source).unwrap_err();
    assert_error(&error, source, "unknown value `core`", "raw-add.core");
    assert_eq!(
        ok(run(
            "++ core [raw-add=|=([a=@ud b=@ud] a)]\n++ main (raw-add.core 40 2)\n"
        )),
        "40"
    );
    assert_eq!(
        ok(run(
            "/= prim /lib/jibb/primitives\n++ main (raw-add.prim 40 2)\n"
        )),
        "42"
    );
}

#[test]
fn an_empty_cell_is_an_error() {
    let source = "++ main []\n";
    let error = check_source(source).unwrap_err();
    assert_error(&error, source, "an empty `[]` is not a valid tuple", "]");
    let source = "+$ x []\n";
    let error = check_source(source).unwrap_err();
    assert_error(&error, source, "an empty `[]` is not a valid mold", "]");
}

#[test]
fn import_paths_stay_under_their_roots() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path().join("ui");
    fs::create_dir(&root).unwrap();
    fs::write(directory.path().join("secret.jibb"), "++ secret 42\n").unwrap();
    let main = root.join("main.jibb");
    let source = "/= s /../secret\n++ main secret.s\n";
    fs::write(&main, source).unwrap();
    let error = loader::check_path(&main, std::slice::from_ref(&root), None).unwrap_err();
    assert_error(
        &error,
        source,
        "import path segment `..` does not name a module",
        "/= s /../secret",
    );
}

#[test]
fn hoon_constant_terms_are_their_atoms() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("sur")).unwrap();
    fs::write(
        root.join("sur/fl.hoon"),
        "|%\n+$  flag  $%([%& p=@] [%| p=@])\n--\n",
    )
    .unwrap();
    fs::write(
        root.join("sur/mk.hoon"),
        "|%\n+$  marks  $?(%$ %.y %.n)\n--\n",
    )
    .unwrap();
    let main = root.join("main.jibb");
    fs::write(
        &main,
        "/- fl\n++ f |= x=flag.fl\n  ?- x\n    [%.y p] [%.y p]\n    [%.n p] [%.n p]\n++ main [(f [%.y 5]) (f [%.n 6]) (^- flag.fl [%.y 5])]\n",
    )
    .unwrap();
    let prelude = prelude();
    let value =
        loader::evaluate_path(&main, "main", &[root.to_path_buf(), dev()], Some(&prelude)).unwrap();
    assert_eq!(value.to_string(), "[[0 5] [1 6] 0 5]");
    // `%$` and `%.y` are both 0, so a union of them overlaps.
    fs::write(&main, "/- mk\n++ main ^- marks.mk %.n\n").unwrap();
    let error =
        loader::check_path(&main, &[root.to_path_buf(), dev()], Some(&prelude)).unwrap_err();
    assert_eq!(error.message, "union `marks.mk` has overlapping cases");
}

#[test]
fn a_marks_type_is_its_grab_cores_noun_arm() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("mar")).unwrap();
    fs::write(
        root.join("mar/pair.hoon"),
        "|_  noun=@\n++  grow  |%  ++  noun  @t  --\n++  grab  |%  ++  noun  [@ud @ud]  --\n--\n",
    )
    .unwrap();
    let main = root.join("main.jibb");
    fs::write(&main, "/% %pair\n++ main ^- pair [1 2]\n").unwrap();
    let value = loader::evaluate_path(&main, "main", &[root.to_path_buf()], None).unwrap();
    assert_eq!(value.to_string(), "[1 2]");
}

#[test]
fn comet_names_are_ships() {
    let comet = "~rolruc-midwyl-hathes-palsym--fotnul-pagpur-nopful-lomtem";
    let source = format!("++  main  \"{{{comet}}}\"\n");
    assert_eq!(format_source(&source).unwrap(), source);
    assert_eq!(cord(run(&source)), comet);
    let checked = check_source(&format!("++ c {comet}\n")).unwrap();
    assert_eq!(checked.values["c"].to_string(), "@p");
}

#[test]
fn a_cell_fits_the_same_cell_written_right_nested() {
    assert_eq!(
        ok(run("++ x ^- [@ud @ud @ud] [1 [2 3]]\n++ main x\n")),
        "[1 2 3]"
    );
    assert_eq!(
        ok(run(
            "++ f |= [a=@ud b=@ud c=@ud] c\n++ main [(f [1 [2 3]]) (f 1 [2 3])]\n"
        )),
        "[3 3]"
    );
    // A record does not fit a narrower one by regrouping its fields.
    let source = "++ sink |= x=[one=[a=@t b=B] other=@ud] \"ok\"\n++ bad (sink [one=[a=\"x\" b=~zod c=%.y] other=0])\n";
    assert!(check_source(source).is_err());
}

#[test]
fn deep_evaluation_ends_with_a_diagnostic() {
    let source = "/= core /lib/jibb/primitives\n++ count |= n=@ud\n  ?- n\n    0 0\n    * (raw-add.core 1 (count (raw-dec.core n)))\n++ main (count 1.000.000)\n";
    let error = run(source).unwrap_err();
    assert_eq!(
        error.message,
        "evaluation recursed too deeply for the evaluator's stack"
    );
}

#[test]
fn the_formatter_formats_commented_open_forms() {
    for (source, expected) in [
        (
            "++  g  |=(a ~[  ::  c\n  1\n  2\n",
            "++  g  |=  a\n  ~[  ::  c\n    1\n    2\n",
        ),
        ("++  x  (\n\n  f\n  a\n", "++  x  f a\n"),
        (
            "++  f  |=  n=@ud\n  +$  local\n    %a\n    %b\n::  c\n  n\n",
            "++  f  |=  n=@ud\n  +$  local\n    %a\n    %b\n  ::  c\n  n\n",
        ),
        (
            "+$  f  $-(@ [  ::  c\n  b=@\n",
            "+$  f\n  $-(@  [  ::  c\n    b=@\n",
        ),
        (
            "++  x  %/blog/(f ~[  ::  c\n  1\n",
            "++  x\n  %/blog/(f ~[  ::  c\n    1\n",
        ),
        // A blank line after a header renders as `::`, as one between items
        // does, so a second pass keeps the layout.
        ("++  x  |=  a\n\n  a\n", "++  x  |=  a\n  ::\n  a\n"),
        (
            "++  x\n  ~[\n\n    1\n    2\n",
            "++  x\n  ~[\n    ::\n    1\n    2\n",
        ),
        // A node ends where its code does, not at the next line's indent.
        (
            "++ f |= b=?\n  ?- b\n  %.y\n    1\n\n  %.n\n    ++ two 2\n    two\n",
            "++  f  |=  b=?\n  ?-  b\n  %.y  1\n  ::\n  %.n\n    ++  two  2\n    two\n",
        ),
        // A blank line after an opener renders even when the first item has
        // a face, and a redundant group around a gate goes.
        (
            "++ record\n  [\n\n    text=\"milk\"\n    done=%.n\n",
            "++  record\n  [\n    ::\n    text=\"milk\"\n    done=%.n\n",
        ),
        ("++ x (|= a  ::\n  b\n", "++  x  |=  a  ::\n  b\n"),
        // A faced mold field breaks as its mold does.
        (
            "+$ g [a=@ b=(list  ::\n  @t\n",
            "+$  g\n  [\n    a=@\n    b=(list  ::\n      @t\n",
        ),
    ] {
        let formatted = format_source(source).unwrap_or_else(|error| panic!("{error}"));
        assert_eq!(formatted, expected, "{source:?}");
        assert_eq!(format_source(&formatted).unwrap(), formatted);
    }
}

#[test]
fn the_formatter_scales_with_length_and_bounds_nesting() {
    let lines = (0..3_000)
        .map(|index| format!("++  a{index}  (f (g x{index}) [1 2])  ::  c{index}\n"))
        .collect::<String>();
    let formatted = format_source(&lines).unwrap();
    assert_eq!(formatted.lines().count(), 3_000);

    // Nesting that breaks across many lines stays within the scanner's
    // indentation limit and converges.
    let nested = format!("++  main  {}1 2{}\n", "[".repeat(600), "]".repeat(600));
    let formatted = format_source(&nested).unwrap();
    assert_eq!(format_source(&formatted).unwrap(), formatted);

    let calls = format!("++  main  {}9{}\n", "(f ".repeat(300), ")".repeat(300));
    format_source(&calls).unwrap();

    let deep = format!("++  main  {}9{}\n", "(f ".repeat(5_000), ")".repeat(5_000));
    let error = format_source(&deep).unwrap_err();
    assert!(
        error.contains("Jibb source nests more than 1000 brackets deep on one line"),
        "{error}"
    );
    let error = parse_ast(&deep).unwrap_err();
    assert_eq!(
        error.message,
        "Jibb source nests more than 1000 brackets deep on one line"
    );
}
