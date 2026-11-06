use jibb::{language, parse};
use tree_sitter::Parser;

fn assert_parses(source: &str) {
    if let Err(error) = parse(source) {
        panic!("source failed to parse:\n{source}\n{error}");
    }
}

#[test]
fn comments_are_named_extras_and_blank_lines_do_not_change_layout() {
    let source = "::  leading comment\n\n++ main view  :: trailing comment\n  :: comment-only line\n\n++ other ~\n";
    let tree = parse(source).expect("comments and blank lines should parse");
    let sexp = tree.root_node().to_sexp();
    assert_eq!(sexp.matches("comment").count(), 3, "{sexp}");
}

#[test]
fn parses_imports_literals_paths_and_tight_forms() {
    assert_parses(
        r#"/-  todo
/%  %todo-action
/=  card  /ui/components/card
+$ result |$ [V E]
  [%ok value=V]
  [%err error=E]
+$ route /todo/[id=@ud]/[slug=_]
++ literals [1.000 0x1f 0v5.fdf99 ~zod ~2026.10.23..14.30.00 ~h1.m30 ~.my-post %1.000 %$ %.y ~]
++ forms [gap+%s2 `x m(note=text open.cart=(not open.cart.m)) |=%got |=(p=post.blog title.p)]
++ paths [/posts/~zod %/blog/(slug) %/static/img/logo.png]
"#,
    );
}

#[test]
fn parses_store_with_patterns_changes_and_open_lists() {
    assert_parses(
        r#"+$ state [items=(list @t) open=?]
+$ poke
  [%add item=@t]
  %toggle

++ main (store init update)
++ init ^- state [items=~ open=%.n]
++ update |= [a=poke s=state]
  ?- a
  [%add item]  s(items=[item items.s])
  %toggle      s(open=(not open.s))
"#,
    );
}

#[test]
fn parses_interpolation_nested_open_brackets_and_application_paths() {
    assert_parses(
        r#"++ view |= [day=@da n=@ud m=model]
  column ~[gap+%s1] ~[
    (text "Updated {day}; {(lent items.cart.m)} items; :: text")
    (column ~ ~[
      (text "{n} items")
      (go %/blog/(slug) /todo/~zod)
"#,
    );
}

#[test]
fn parses_bodies_local_definitions_and_same_depth_rest() {
    assert_parses(
        r#"++ outer |= x=@ud
  ++ local |= y=A
    ^- _ ~& y
    ++ inner |= z=@t z
    inner "done"
  ^- @ud ~& x
  ?- (eq x 1.000)
  %.y  local x
  %.n  !!
"#,
    );
}

#[test]
fn parses_open_molds_samples_and_function_molds() {
    assert_parses(
        r#"+$ record [
  text=@t
  done=?
+$ applied (map
  @t
  (list @ud)
+$ generic $-([A A] ?)
++ id |= [a=@ b]
  b
++ pun |= [=msg m=model]
  msg
"#,
    );
}

#[test]
fn scanner_state_survives_incremental_reuse() {
    let mut parser = Parser::new();
    parser.set_language(&language()).unwrap();
    let first = "++ a |= x=@ud\n  ^- @ud ~& x\n  x\n";
    let tree = parser.parse(first, None).unwrap();
    assert!(
        !tree.root_node().has_error(),
        "{}",
        tree.root_node().to_sexp()
    );

    let second = "++ b\n  ++ c ~\n  [c ~]\n++ d ~\n";
    let tree = parser.parse(second, Some(&tree)).unwrap();
    assert!(
        !tree.root_node().has_error(),
        "{}",
        tree.root_node().to_sexp()
    );
}

#[test]
fn parses_date_subseconds_and_implicitly_closed_rune_groups() {
    assert_parses("++ d ~2026.10.23..14.30.00..ffff\n++ empty |= s=state s()\n");
    assert_parses(
        r#"++ scalar |= flag=?
  ^- [x=@t y=@p]
    [
      x=(?- flag
        %.y (proj [x="a" extra=~zod])
        %.n (proj [x="b" extra=~zod])
      y=~zod
"#,
    );
}

fn assert_rejects(source: &str) {
    if let Ok(tree) = parse(source) {
        panic!(
            "source should have been rejected:\n{source}\n{}",
            tree.root_node().to_sexp()
        );
    }
}

#[test]
fn parses_standalone_puns_trailing_spaces_and_implicit_bracket_closures() {
    assert_parses("++ g |= =msg msg\n++ x 5   \n++ y 6\n");
    assert_parses(
        r#"+$ v (map @ud [
  a=@
  b=@
+$ f $-(@ [
  b=@
+$ g [a=@ b=(list
  @t
"#,
    );
    assert_parses(
        r#"++ g |=(a ~[
  1
  2
++ h (f |=(a ~[
  1
"#,
    );
    assert_parses(
        r#"++ x (|= a
  b
++ y [a (|= x
  ~
++ z (~& a b
  c
"#,
    );
    assert_parses(
        r#"++ x %/blog/(f ~[
  1
++ y 2
"#,
    );
}

#[test]
fn rejects_literal_prefixes_and_unspaced_items() {
    for literal in [
        "0v5.fdfz9",
        "1000",
        "1.0000",
        "0xg1",
        "~0v0000d",
        "~h1m30",
        "~x",
        "~sampelpalnet",
    ] {
        assert_rejects(&format!("++ x {literal}\n"));
    }
    for term in [
        "%9a", "%1000", "%007", "%01", "%0x1f", "%0v5", "%0b1", "%0xg", "%0x",
    ] {
        assert_rejects(&format!("++ x {term}\n"));
    }
    assert_rejects(r#"++ x ~[(text "a")(text "b")]"#);
}

#[test]
fn rejects_tightness_layout_and_control_character_violations() {
    assert_rejects("++ x (state.cart |= %got)\n");
    assert_rejects("++ x ` x\n");
    assert_rejects("+$ path /[id= _]\n");
    assert_rejects("  ++ x 5\n");
    assert_rejects("++ x \"a\u{1}b\"\n");
    assert_rejects("++ x \"é\tb\"\n");
    assert_rejects("++ x 1  :: é\tz\n");
}

#[test]
fn rejects_rest_after_an_open_subject_or_value() {
    assert_rejects(
        r#"++ f |= x=?
  ?- (eq x
    %.y
  %.y 1
  %.n 2
"#,
    );
    assert_rejects(
        r#"++ f |= x=@ud
  ~& ~[
    x
  x
"#,
    );
}

#[test]
fn rejects_non_pattern_literals_and_invalid_mold_or_import_forms() {
    assert_rejects("++ f\n  ?-  a\n    ~s30  1\n");
    assert_rejects("++ f |= s=(list @)\n  ?- s\n    ~[a]  1\n    *     2\n");
    assert_rejects("++ f ^- ?(%a %b) %a\n");
    assert_rejects("/%  %$\n");
}
