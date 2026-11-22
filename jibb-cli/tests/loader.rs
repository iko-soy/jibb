mod common;

use jibb::{
    loader::{check_path, check_source, evaluate_path},
    value::{Noun, Value},
};
use num_bigint::BigUint;
use std::{fs, path::Path, rc::Rc};

fn run(file: &Path, roots: &[std::path::PathBuf]) -> Value {
    evaluate_path(file, "main", roots, None).unwrap_or_else(|error| panic!("{error}"))
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
fn loads_values_molds_and_native_primitive_modules() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::write(root.join("util.jibb"), "++ answer 42\n").unwrap();
    fs::write(root.join("types.jibb"), "+$ point [x=@ud y=@ud]\n").unwrap();
    fs::write(
        root.join("main.jibb"),
        "/= util /util\n/= types /types\n/= core /lib/jibb/primitives\n++ main [(answer.util) x.p (raw-add.core 1 2)]\n++ p ^- point.types [1 2]\n",
    )
    .unwrap();
    let value = run(&root.join("main.jibb"), &[root.to_path_buf()]);
    let Value::Noun(noun) = value else {
        panic!("expected noun")
    };
    let expected = Rc::new(Noun::Cell(
        Rc::new(Noun::Atom(BigUint::from(42u32))),
        Rc::new(Noun::Cell(
            Rc::new(Noun::Atom(BigUint::from(1u32))),
            Rc::new(Noun::Atom(BigUint::from(3u32))),
        )),
    ));
    assert_eq!(noun, expected);
}

#[test]
fn evaluates_with_the_source_prelude() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../jibb-dev");
    let prelude = root.join("lib/jibb/prelude.jibb");
    if !common::corpus(&prelude) {
        return;
    }
    let directory = tempfile::tempdir().expect("temporary directory");
    let main = directory.path().join("main.jibb");
    fs::write(&main, "++ main (add 40 2)\n").unwrap();
    let value =
        evaluate_path(&main, "main", &[root], Some(&prelude)).expect("source prelude evaluates");
    assert_eq!(atom(&value), &BigUint::from(42u32));
}

#[test]
fn evaluates_internal_prelude_constructor() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../jibb-dev");
    if !common::corpus(&root.join("lib/jibb/internal.jibb")) {
        return;
    }
    let directory = tempfile::tempdir().expect("temporary directory");
    let main = directory.path().join("main.jibb");
    fs::write(
        &main,
        "/= internal /lib/jibb/internal\n++ main ^- (ask.internal @ud) [%pure 42]\n",
    )
    .unwrap();
    let value = evaluate_path(&main, "main", &[root], None).expect("internal prelude constructor");
    let Value::Noun(noun) = value else {
        panic!("expected noun")
    };
    let tag = Rc::new(Noun::Atom(BigUint::from_bytes_le(b"pure")));
    assert_eq!(
        noun,
        Rc::new(Noun::Cell(tag, Rc::new(Noun::Atom(BigUint::from(42u32)))))
    );
}

#[test]
fn checks_files_and_source_without_evaluating() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::write(root.join("util.jibb"), "++ answer 42\n").unwrap();
    let source = "/= util /util\n++ main !!\n++ copied answer.util\n";
    let main = root.join("main.jibb");
    fs::write(&main, source).unwrap();

    check_path(&main, &[root.to_path_buf()], None).expect("check file without evaluating");
    check_source(
        source,
        &root.join("stdin.jibb"),
        &[root.to_path_buf()],
        None,
    )
    .expect("check source without evaluating");
}

#[test]
fn imports_standard_each_through_temporary_sur_files() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("sur")).unwrap();
    fs::write(
        root.join("sur/fixture.hoon"),
        "|%\n+$  either  (each @ud @t)\n--\n",
    )
    .unwrap();
    let main = root.join("main.jibb");
    fs::write(
        &main,
        "/- fixture\n++ left ^- either.fixture [%& 42]\n++ right ^- either.fixture [%| \"hello\"]\n++ main [left right]\n",
    )
    .unwrap();
    check_path(&main, &[root.to_path_buf()], None).expect("both standard each branches");

    fs::write(
        root.join("sur/shadow.hoon"),
        "|%\n+$  each  [left=@ud right=@t]\n+$  local  each\n--\n",
    )
    .unwrap();
    fs::write(&main, "/- shadow\n++ main ^- local.shadow [1 \"local\"]\n").unwrap();
    check_path(&main, &[root.to_path_buf()], None).expect("local each shadows the standard mold");
}

#[test]
fn imports_recursive_standard_json_through_temporary_sur_files() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("sur")).unwrap();
    for name in ["fixture", "other"] {
        fs::write(
            root.join(format!("sur/{name}.hoon")),
            "|%\n+$  entry  json\n--\n",
        )
        .unwrap();
    }
    let main = root.join("main.jibb");
    fs::write(
        &main,
        concat!(
            "/- fixture\n/- other\n",
            "++ copy |= value=entry.fixture ^- entry.other value\n",
            "++ main ^- entry.fixture\n",
            "  [%a [[%b %.y] [[%n ~.42] [[%s \"hello\"] [[%o [[p=\"key\" q=~] ~ ~]] ~]]]]]\n",
        ),
    )
    .unwrap();
    check_path(&main, &[root.to_path_buf()], None)
        .expect("recursive json values and cross-import identity");

    fs::write(
        &main,
        "/- fixture\n++ main ^- entry.fixture [%a [[%s 42] ~]]\n",
    )
    .unwrap();
    let error = check_path(&main, &[root.to_path_buf()], None).unwrap_err();
    assert!(error.message.contains("type mismatch"), "{error}");

    fs::write(
        root.join("sur/shadow.hoon"),
        "|%\n+$  json  @ud\n+$  local  json\n--\n",
    )
    .unwrap();
    fs::write(&main, "/- shadow\n++ main ^- local.shadow 42\n").unwrap();
    check_path(&main, &[root.to_path_buf()], None).expect("local json shadows the standard mold");
}

#[test]
fn imports_numeric_hoon_tags_and_rejects_loobean_noun_overlap() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("sur")).unwrap();
    let main = root.join("main.jibb");
    fs::write(
        root.join("sur/tags.hoon"),
        "|%\n+$  versioned\n  $%  [%0 @ud]\n      [%1 @t]\n  ==\n--\n",
    )
    .unwrap();
    fs::write(&main, "/- tags\n++ main ^- versioned.tags [%0 42]\n").unwrap();
    check_path(&main, &[root.to_path_buf()], None).expect("numeric %0 union tag");

    fs::write(
        root.join("sur/tags.hoon"),
        "|%\n+$  overlap\n  $%  [%& @ud]\n      [%0 @t]\n  ==\n--\n",
    )
    .unwrap();
    let error = check_path(&main, &[root.to_path_buf()], None).unwrap_err();
    assert!(error.message.contains("overlapping cases"), "{error}");
}

#[test]
fn rejects_import_cycles() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::write(root.join("a.jibb"), "/= b /b\n++ a 1\n").unwrap();
    fs::write(root.join("b.jibb"), "/= a /a\n++ b 2\n").unwrap();
    let error = evaluate_path(&root.join("a.jibb"), "a", &[root.to_path_buf()], None).unwrap_err();
    assert!(error.message.contains("cycle"));
}
