use jibb::{format_source, parse};

fn check(source: &str, expected: &str) {
    let actual = format_source(source)
        .unwrap_or_else(|error| panic!("formatting failed:\nSOURCE:\n{source}\nERROR:\n{error}"));
    assert_eq!(actual, expected, "formatted output differed");
    parse(&actual).expect("formatted output must reparse");
    assert_eq!(
        format_source(&actual).as_deref(),
        Ok(expected),
        "formatting must be idempotent"
    );
}

#[test]
fn empty_and_whitespace_only_files_have_no_output() {
    check("", "");
    check(" \n\n  \n", "");
}

#[test]
fn invalid_syntax_is_rejected_without_output() {
    let error = format_source("++ broken [a\n").unwrap_err();
    assert!(error.contains("invalid Jibb syntax"), "{error}");
}

#[test]
fn imports_definitions_and_literals_use_canonical_spacing() {
    check(
        r#"/-   todo
/%   %todo-action
/=   card    /ui/components/card
++   literals   [ 1.000  0x1f 0v5.fdf99 ~zod ~2026.10.23 ~h1.m30 ~.my-post %1.000 %$ %.y ~ ]
++ tight [ gap+%s2 `x m(note=text open.cart=(not open.cart.m)) |=%got ]
"#,
        r#"/-  todo
/%  %todo-action
/=  card  /ui/components/card
++  literals
  [1.000 0x1f 0v5.fdf99 ~zod ~2026.10.23 ~h1.m30 ~.my-post %1.000 %$ %.y ~]
++  tight  [gap+%s2 `x m(note=text open.cart=(not open.cart.m)) |=%got]
"#,
    );
}

#[test]
fn redundant_groups_disappear_but_operand_call_groups_remain() {
    check(
        "++ a (((f x)))\n++ b ~[(a) ((f x))]\n++ c (f (g x))\n",
        "++  a  f x\n++  b  ~[a (f x)]\n++  c  f (g x)\n",
    );
}

#[test]
fn wide_gates_become_tall_except_in_operands() {
    check(
        "++ id |=(x=@ud x)\n++ apply (f |=(x=@ud (g x)))\n+$ function $-([A A] ?)\n",
        "++  id  |=  x=@ud  x\n++  apply  f |=(x=@ud  (g x))\n+$  function  $-([A A]  ?)\n",
    );
}

#[test]
fn short_and_multiline_casts_follow_the_owner_exception() {
    check(
        "++ init ^-  state [items=~ open=%.n]\n++ through |=  x=@ud ^-  @ud x\n",
        "++  init\n  ^-  state  [items=~ open=%.n]\n++  through  |=  x=@ud\n  ^-  @ud  x\n",
    );

    check(
        "++ wide ^-  (list @ud) ~[alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron]\n",
        "++  wide  ^-  (list @ud)\n  ~[\n    alpha\n    beta\n    gamma\n    delta\n    epsilon\n    zeta\n    eta\n    theta\n    iota\n    kappa\n    lambda\n    mu\n    nu\n    xi\n    omicron\n",
    );
}

#[test]
fn multiline_gate_bodies_start_below_the_gate_header() {
    check(
        "++ update |=  [a=poke s=state]\n  ?-  a\n  [%add item]      s(items=[item items.s])\n  %toggle          s(open=(not open.s))\n",
        "++  update  |=  [a=poke s=state]\n  ?-  a\n  [%add item]  s(items=[item items.s])\n  %toggle  s(open=(not open.s))\n",
    );
}

#[test]
fn branch_is_on_its_own_line_and_arm_bodies_use_two_spaces() {
    check(
        "++ choose ?-  (eq x 1.000)\n  %.y       (f x)\n  %.n       !!\n",
        "++  choose\n  ?-  eq x 1.000\n    %.y  f x\n    %.n  !!\n",
    );
}

#[test]
fn same_depth_rest_heads_and_branches_are_preserved() {
    check(
        r#"++ outer |=  x=@ud
  ++ local |=  y=A
    ^-  _ ~&  y
    ++ inner |=  z=@t z
    inner "done"
  ^-  @ud ~&  x
  ?-  (eq x 1.000)
  %.y  local x
  %.n  !!
"#,
        r#"++  outer  |=  x=@ud
  ++  local  |=  y=A
    ^-  _  ~&  y
    ++  inner  |=  z=@t  z
    inner "done"
  ^-  @ud  ~&  x
  ?-  eq x 1.000
  %.y  local x
  %.n  !!
"#,
    );
}

#[test]
fn single_molds_stay_inline_and_union_cases_go_below() {
    check(
        "+$ result |$  [V E]\n  [%ok value=V]\n  [%err error=E]\n+$ record [\n  text=@t\n  done=?\n+$ one\n  %only\n",
        "+$  result  |$  [V E]\n  [%ok value=V]\n  [%err error=E]\n+$  record  [text=@t done=?]\n+$  one  %only\n",
    );
}

#[test]
fn a_long_single_mold_moves_below_the_definition_line() {
    check(
        "+$ record [alpha=@ud beta=@ud gamma=@ud delta=@ud epsilon=@ud zeta=@ud eta=@ud theta=@ud]\n",
        "+$  record\n  [\n    alpha=@ud\n    beta=@ud\n    gamma=@ud\n    delta=@ud\n    epsilon=@ud\n    zeta=@ud\n    eta=@ud\n    theta=@ud\n",
    );
}

#[test]
fn exactly_eighty_columns_stays_inline_and_eighty_one_breaks_the_owner() {
    let fits_value = "a".repeat(66);
    let fits = format!("++ boundary {fits_value}\n");
    let fits_expected = format!("++  boundary  {fits_value}\n");
    assert_eq!(fits_expected.trim_end().chars().count(), 80);
    check(&fits, &fits_expected);

    let overflows_value = "a".repeat(67);
    let overflows = format!("++ boundary {overflows_value}\n");
    let overflows_expected = format!("++  boundary\n  {overflows_value}\n");
    check(&overflows, &overflows_expected);
}

#[test]
fn a_multiline_call_has_parenthesized_head_and_one_argument_per_line() {
    check(
        "++ apply (very-long-function-name first-argument second-argument third-argument fourth-argument fifth-argument)\n",
        "++  apply\n  (very-long-function-name\n    first-argument\n    second-argument\n    third-argument\n    fourth-argument\n    fifth-argument\n",
    );
}

#[test]
fn long_lists_tuples_and_changes_use_open_forms_without_closers() {
    check(
        "++ items ~[alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron]\n",
        "++  items\n  ~[\n    alpha\n    beta\n    gamma\n    delta\n    epsilon\n    zeta\n    eta\n    theta\n    iota\n    kappa\n    lambda\n    mu\n    nu\n    xi\n    omicron\n",
    );
    check(
        "++ tuple [alpha=alpha beta=beta gamma=gamma delta=delta epsilon=epsilon zeta=zeta eta=eta theta=theta iota=iota]\n",
        "++  tuple\n  [\n    alpha=alpha\n    beta=beta\n    gamma=gamma\n    delta=delta\n    epsilon=epsilon\n    zeta=zeta\n    eta=eta\n    theta=theta\n    iota=iota\n",
    );
    check(
        "++ edit model(alpha=alpha beta=beta gamma=gamma delta=delta epsilon=epsilon zeta=zeta eta=eta theta=theta)\n",
        "++  edit\n  model(\n    alpha=alpha\n    beta=beta\n    gamma=gamma\n    delta=delta\n    epsilon=epsilon\n    zeta=zeta\n    eta=eta\n    theta=theta\n",
    );
}

#[test]
fn nested_open_forms_reparse_and_converge() {
    let source = "++ nested ~[\n  [alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron]\n  (very-long-function-name first-argument second-argument third-argument fourth-argument fifth-argument)\n  m(alpha=alpha beta=beta gamma=gamma delta=delta epsilon=epsilon zeta=zeta eta=eta theta=theta)\n";
    let output = format_source(source).expect("nested open forms should format");
    assert!(output.contains("  ~[\n"), "{output}");
    assert!(output.contains("    [\n"), "{output}");
    assert!(
        output.contains("    (very-long-function-name\n"),
        "{output}"
    );
    assert!(output.contains("    m(\n"), "{output}");
    assert!(
        !output.lines().any(|line| line.trim_end() == "]"),
        "{output}"
    );
    parse(&output).expect("nested output should parse");
    assert_eq!(format_source(&output).as_deref(), Ok(output.as_str()));
}

#[test]
fn interpolation_and_application_paths_format_inner_expressions_only() {
    check(
        r#"++ text [(f "{(lent items.cart.m)} items :: text") (go %/blog/((slug-for slug)) /todo/~zod)]
"#,
        r#"++  text
  [
    f "{lent items.cart.m} items :: text"
    go %/blog/(slug-for slug) /todo/~zod
"#,
    );
}

#[test]
fn blank_runs_become_bare_comments_and_edge_runs_disappear() {
    check(
        "\n\n++ a ~\n\n\n++ b ~\n\n::\n\n++ c ~\n\n",
        "++  a  ~\n::\n++  b  ~\n::\n::\n::\n++  c  ~\n",
    );
}

#[test]
fn comment_text_is_preserved_and_blank_runs_around_it_still_convert() {
    check(
        "::  lead\n\n++ a ~\n\n::   middle text\n\n++ b ~\n",
        "::  lead\n::\n++  a  ~\n::\n::   middle text\n::\n++  b  ~\n",
    );
}

#[test]
fn comments_force_open_layout_and_keep_their_text_and_order() {
    check(
        "++ items ~[\n  alpha\n\n  ::  note\n  beta   ::   tail\n++ next ~\n",
        "++  items\n  ~[\n    alpha\n    ::\n    ::  note\n    beta  ::   tail\n++  next  ~\n",
    );
}

#[test]
fn trailing_comment_spacing_is_exactly_two_spaces() {
    check(
        "/- todo       ::  import\n++ f |=  x=@ud\n  ?-  x\n  *       x       :: arm\n",
        "/-  todo  ::  import\n++  f  |=  x=@ud\n  ?-  x\n  *  x  :: arm\n",
    );
}

#[test]
fn no_forced_separators_are_inserted_between_definitions() {
    check("++ a ~\n++ b ~\n", "++  a  ~\n++  b  ~\n");
}

#[test]
fn complete_store_example_formats_as_one_idempotent_module() {
    check(
        r#"/-  todo
/%  %todo-action
/=  card    /ui/components/card

+$ state [items=(list @t) open=?]
+$ poke
  [%add item=@t]
  %toggle

++ main (store init update)
++ init ^-  state [items=~ open=%.n]
++ update |=  [a=poke s=state]
  ?-  a
  [%add item]      s(items=[item items.s])
  %toggle          s(open=(not open.s))
"#,
        r#"/-  todo
/%  %todo-action
/=  card  /ui/components/card
::
+$  state  [items=(list @t) open=?]
+$  poke
  [%add item=@t]
  %toggle
::
++  main  store init update
++  init
  ^-  state  [items=~ open=%.n]
++  update  |=  [a=poke s=state]
  ?-  a
  [%add item]  s(items=[item items.s])
  %toggle  s(open=(not open.s))
"#,
    );
}

#[test]
fn adjacent_name_mold_faces_are_not_split_into_puns() {
    check(
        "+$ model [cart=cart note=@t]\n++ update |=  [a=poke s=state] s\n",
        "+$  model  [cart=cart note=@t]\n++  update  |=  [a=poke s=state]  s\n",
    );
}

#[test]
fn grouped_casts_remain_grouped_when_used_as_operands() {
    check(
        "++ value ((lead (^-  (unit @t) ~)) \"tail\")\n",
        "++  value  (lead (^-  (unit @t)  ~)) \"tail\"\n",
    );
}

#[test]
fn trailing_declarations_after_multiline_definitions_keep_root_indent() {
    check(
        "++ head |=  p=[A B]\n  ?-  p\n    [a b] a\n\n:: root declaration\n++ next ^-  @t \"x\"\n:: another declaration\n",
        "++  head  |=  p=[A B]\n  ?-  p\n    [a b]  a\n::\n:: root declaration\n++  next\n  ^-  @t  \"x\"\n:: another declaration\n",
    );
}

#[test]
fn term_sample_gates_do_not_reparse_as_constructors() {
    check("++ x |=  %got\n  ~\n", "++  x  |=  %got\n  ~\n");
}

#[test]
fn date_subseconds_and_rune_groups_survive_formatting() {
    check(
        "++ d ~2026.10.23..14.30.00..ffff\n",
        "++  d  ~2026.10.23..14.30.00..ffff\n",
    );

    let source = r#"++ scalar |= flag=?
  ^- [x=@t y=@p]
    [
      x=(?- flag
        %.y (proj [x="a" extra=~zod])
        %.n (proj [x="b" extra=~zod])
      y=~zod
"#;
    let output = format_source(source).expect("rune group should format");
    assert!(output.contains("x=?-  flag"), "{output}");
}
