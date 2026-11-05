use jibb::{
    evaluate, parse_ast,
    value::{Noun, Value},
};
use num_bigint::BigUint;
use std::rc::Rc;

fn run(source: &str) -> Value {
    let module = parse_ast(source).expect("source should lower");
    evaluate(&module, "main").unwrap_or_else(|error| panic!("evaluation failed: {error}"))
}

fn noun(source: &str) -> Rc<Noun> {
    match run(source) {
        Value::Noun(noun) => noun,
        other => panic!("expected noun, got {other}"),
    }
}

fn atom(value: u64) -> Rc<Noun> {
    Rc::new(Noun::Atom(BigUint::from(value)))
}

fn cell(head: Rc<Noun>, tail: Rc<Noun>) -> Rc<Noun> {
    Rc::new(Noun::Cell(head, tail))
}

#[test]
fn evaluates_literals_and_forward_definitions() {
    assert_eq!(noun("++ main [1 2]\n"), cell(atom(1), atom(2)));
    assert_eq!(noun("++ main second\n++ second 42\n"), atom(42));
}

#[test]
fn evaluates_gates_and_local_polymorphism() {
    assert_eq!(noun("++ id |=(x x)\n++ main (id 42)\n"), atom(42));
    assert_eq!(noun("++ main\n  ++ id |=(x x)\n  (id 42)\n"), atom(42));
}

#[test]
fn evaluates_recursive_gates_and_branches() {
    assert_eq!(
        noun(
            "+$ nat\n  ~\n  [~ tail=nat]\n++ count |= n=nat ?- n\n  ~ 0\n  [~ rest] (count rest)\n++ main (count [~ [~ ~]])\n",
        ),
        atom(0)
    );

    assert_eq!(
        noun(
            "+$ msg\n  [%add n=@ud]\n  %stop\n++ describe |= m=msg ?- m\n  [%add n] n\n  %stop 0\n++ main (describe [%add 42])\n",
        ),
        atom(42)
    );
}

#[test]
fn evaluates_record_wings_changes_and_projection() {
    assert_eq!(noun("++ main x.p\n++ p [x=42 y=2]\n"), atom(42));
    assert_eq!(
        noun("++ main p(x=42)\n++ p [x=1 y=2]\n"),
        cell(atom(42), atom(2))
    );
    assert_eq!(
        noun("++ main ^- [x=@ud] (proj p)\n++ p [x=42 y=2]\n"),
        atom(42)
    );
}

#[test]
fn evaluates_constructors_units_and_lists() {
    let source = "+$ list |$ [A]\n  ~\n  [head=A tail=(list A)]\n+$ unit |$ [A]\n  ~\n  [~ value=A]\n+$ msg [%add n=@ud]\n++ main ^- msg (|=%add 42)\n";
    let tag = Rc::new(Noun::Atom(BigUint::from_bytes_le(b"add")));
    assert_eq!(noun(source), cell(tag, atom(42)));

    let source = "+$ list |$ [A]\n  ~\n  [head=A tail=(list A)]\n+$ unit |$ [A]\n  ~\n  [~ value=A]\n++ maybe ^- (unit @ud) `42\n++ main [maybe ~[1 2]]\n";
    let unit = cell(atom(0), atom(42));
    let list = cell(atom(1), cell(atom(2), atom(0)));
    assert_eq!(noun(source), cell(unit, list));
}

#[test]
fn evaluates_higher_order_gates() {
    assert_eq!(
        noun("++ apply |= [f=$-(@ud @ud) x=@ud] (f x)\n++ id |= x=@ud x\n++ main (apply id 42)\n",),
        atom(42)
    );
}

#[test]
fn rejects_runtime_crash_without_panicking() {
    let module = parse_ast("++ main !!\n").unwrap();
    let error = evaluate(&module, "main").unwrap_err();
    assert!(error.message.contains("crash"));
}
