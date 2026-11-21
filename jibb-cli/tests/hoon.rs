mod common;

use jibb::{
    loader::{check_path, evaluate_path},
    value::{Noun, Value},
};
use num_bigint::BigUint;
use std::{fs, path::Path, rc::Rc};

fn run(file: &Path, root: &Path) -> Value {
    evaluate_path(file, "main", &[root.to_path_buf()], None)
        .unwrap_or_else(|error| panic!("{error}"))
}

fn atom(value: &Value) -> &BigUint {
    let Value::Noun(noun) = value else {
        panic!("expected atom")
    };
    let Noun::Atom(value) = noun.as_ref() else {
        panic!("expected atom")
    };
    value
}

#[test]
fn imports_nested_hoon_unions_and_recursive_molds() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../tests/clay-fixtures/desk");
    if !common::corpus(&root.join("sur/import-fixture.hoon")) {
        return;
    }
    let directory = tempfile::tempdir().expect("temporary directory");
    let main = directory.path().join("main.jibb");
    fs::write(
        &main,
        "/- import-fixture\n++ main id.record\n++ record ^- nested.import-fixture [id=1 value=[a=2 b=\"x\"]]\n",
    )
    .unwrap();
    let value = evaluate_path(
        &main,
        "main",
        &[
            root.clone(),
            Path::new(env!("CARGO_MANIFEST_DIR")).join("../my-app"),
            Path::new(env!("CARGO_MANIFEST_DIR")).join("../jibb-dev"),
        ],
        Some(&Path::new(env!("CARGO_MANIFEST_DIR")).join("../jibb-dev/lib/jibb/prelude.jibb")),
    )
    .expect("nested Hoon import");
    assert_eq!(atom(&value), &BigUint::from(1u32));
}

#[test]
fn imports_hoon_records_unions_and_marks() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../my-app");
    if !common::corpus(&root.join("sur/blog.hoon")) {
        return;
    }
    let directory = tempfile::tempdir().expect("temporary directory");
    let main = directory.path().join("main.jibb");
    fs::write(
        &main,
        "/- blog\n++ main title.p\n++ p ^- post.blog [title=\"hello\" slug=~.world]\n",
    )
    .unwrap();
    assert_eq!(atom(&run(&main, &root)), &BigUint::from_bytes_le(b"hello"));

    fs::write(&main, "/- todo\n++ main ^- action.todo [%add \"hello\"]\n").unwrap();
    let Value::Noun(noun) = run(&main, &root) else {
        panic!("expected noun")
    };
    let tag = Rc::new(Noun::Atom(BigUint::from_bytes_le(b"add")));
    let text = Rc::new(Noun::Atom(BigUint::from_bytes_le(b"hello")));
    assert_eq!(noun, Rc::new(Noun::Cell(tag, text)));

    fs::write(
        &main,
        "/% %todo-action\n++ main ^- todo-action [%add \"hello\"]\n",
    )
    .unwrap();
    let Value::Noun(noun) = run(&main, &root) else {
        panic!("expected noun")
    };
    let tag = Rc::new(Noun::Atom(BigUint::from_bytes_le(b"add")));
    let text = Rc::new(Noun::Atom(BigUint::from_bytes_le(b"hello")));
    assert_eq!(noun, Rc::new(Noun::Cell(tag, text)));
}

#[test]
fn mark_molds_and_values_can_share_a_name() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("mar")).unwrap();
    fs::write(
        root.join("mar/foo.hoon"),
        "|_  noun=@\n++  grow  |%  ++  noun  @ud  --\n++  grab  |%  ++  noun  @ud  --\n--\n",
    )
    .unwrap();
    let main = root.join("main.jibb");
    let source = "/% %foo\n++ foo 1\n++ marked ^- foo 42\n++ main [foo marked]\n";
    fs::write(&main, source).unwrap();

    let checked = check_path(&main, &[root.to_path_buf()], None).expect("mark and value coexist");
    assert_eq!(checked.values["foo"].to_string(), "@ud");
    assert!(checked.molds.contains_key("foo"));
    let value = run(&main, root);
    assert_eq!(value.to_string(), "[1 42]");

    let source = "/% %foo\n+$ foo @ud\n++ main 0\n";
    fs::write(&main, source).unwrap();
    let error = check_path(&main, &[root.to_path_buf()], None).unwrap_err();
    assert_eq!(error.message, "mark type `%foo` shadows a name");
    let span = error.span.expect("mark conflict has a span");
    assert_eq!(&source[span.start..span.end], "/% %foo");
}
