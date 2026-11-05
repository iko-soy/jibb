use jibb::{
    loader::evaluate_path,
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
    if !root.join("sur/import-fixture.hoon").is_file() {
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
    if !root.join("sur/blog.hoon").is_file() {
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
