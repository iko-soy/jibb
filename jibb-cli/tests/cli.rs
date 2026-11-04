use std::{
    fs,
    io::Write,
    process::{Command, Stdio},
};

fn jibb() -> Command {
    Command::new(env!("CARGO_BIN_EXE_jibb"))
}

#[test]
fn formats_standard_input() {
    let mut child = jibb()
        .args(["fmt"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("spawn jibb");
    child
        .stdin
        .take()
        .expect("stdin")
        .write_all(b"++ id |=(x x)\n")
        .expect("write stdin");
    let output = child.wait_with_output().expect("wait for jibb");
    assert!(output.status.success());
    assert_eq!(output.stdout, b"++  id  |=  x  x\n");
}

#[test]
fn check_write_and_diff_behave_consistently() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let path = directory.path().join("source.jibb");
    fs::write(&path, "++ x  1\n").expect("write source");

    let checked = jibb()
        .args(["fmt", "--check"])
        .arg(&path)
        .output()
        .expect("check source");
    assert_eq!(checked.status.code(), Some(1));
    assert_eq!(fs::read_to_string(&path).expect("read source"), "++ x  1\n");

    let diffed = jibb()
        .args(["fmt", "--diff"])
        .arg(&path)
        .output()
        .expect("diff source");
    assert!(diffed.status.success());
    let diff = String::from_utf8(diffed.stdout).expect("diff UTF-8");
    assert!(diff.contains("-++ x  1"), "{diff}");
    assert!(diff.contains("+++  x  1"), "{diff}");
    assert_eq!(fs::read_to_string(&path).expect("read source"), "++ x  1\n");

    assert!(
        jibb()
            .args(["fmt"])
            .arg(&path)
            .status()
            .expect("format source")
            .success()
    );
    assert_eq!(
        fs::read_to_string(&path).expect("read formatted source"),
        "++  x  1\n"
    );
    assert!(
        jibb()
            .args(["fmt", "--check"])
            .arg(&path)
            .status()
            .expect("check formatted source")
            .success()
    );
}

#[test]
fn invalid_input_is_not_written_and_io_errors_use_exit_two() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let path = directory.path().join("invalid.jibb");
    fs::write(&path, "++ broken [a\n").expect("write invalid source");
    let result = jibb()
        .args(["fmt"])
        .arg(&path)
        .output()
        .expect("format invalid source");
    assert_eq!(result.status.code(), Some(1));
    assert_eq!(
        fs::read_to_string(&path).expect("read invalid source"),
        "++ broken [a\n"
    );

    let missing = directory.path().join("missing.jibb");
    let result = jibb()
        .args(["fmt"])
        .arg(missing)
        .output()
        .expect("format missing source");
    assert_eq!(result.status.code(), Some(2));
}
