//! Command-line regression tests for the 2026-11-16 audit.

use std::{fs, process::Command};

fn jibb() -> Command {
    Command::new(env!("CARGO_BIN_EXE_jibb"))
}

#[test]
fn traces_print_text_by_its_printer() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let file = directory.path().join("trace.jibb");
    fs::write(
        &file,
        "++  main\n  ~&  \"hi\"\n  ~&  ~zod\n  ~&  ~s1\n  ~&  1.000\n  5\n",
    )
    .unwrap();
    let output = jibb().arg("run").arg(&file).output().expect("run");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "5\n");
    assert_eq!(
        String::from_utf8(output.stderr).unwrap(),
        "hi\n~zod\n~s1\n1.000\n"
    );
}

#[test]
fn projection_evaluates_its_source_once() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let file = directory.path().join("projection.jibb");
    fs::write(
        &file,
        "++ source\n  ~&  \"once\"\n  [x=1 y=2]\n++ main ^- [y=@ud x=@ud] (proj source)\n",
    )
    .unwrap();
    let output = jibb().arg("run").arg(&file).output().expect("run");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "[2 1]\n");
    assert_eq!(String::from_utf8(output.stderr).unwrap(), "once\n");
}

#[test]
fn a_file_without_a_final_newline_checks_runs_and_formats() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let file = directory.path().join("main.jibb");
    fs::write(&file, "++  main  42").unwrap();
    let output = jibb().arg("check").arg(&file).output().expect("check");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let output = jibb().arg("run").arg(&file).output().expect("run");
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "42\n");
    let output = jibb().arg("fmt").arg(&file).output().expect("format");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(fs::read_to_string(&file).unwrap(), "++  main  42\n");
}

#[cfg(unix)]
#[test]
fn formatting_through_a_link_formats_its_target_and_keeps_the_link() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let target = directory.path().join("target.jibb");
    let link = directory.path().join("link.jibb");
    fs::write(&target, "++ main  42\n").unwrap();
    std::os::unix::fs::symlink(&target, &link).unwrap();
    let output = jibb().arg("fmt").arg(&link).output().expect("format");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(
        fs::symlink_metadata(&link)
            .unwrap()
            .file_type()
            .is_symlink()
    );
    assert_eq!(fs::read_to_string(&target).unwrap(), "++  main  42\n");
}

#[cfg(unix)]
#[test]
fn check_and_run_take_the_language_from_the_name_given() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let plain = directory.path().join("plain.txt");
    fs::write(&plain, "++  main  42\n").unwrap();
    let jibb_link = directory.path().join("x.jibb");
    std::os::unix::fs::symlink(&plain, &jibb_link).unwrap();
    let output = jibb().arg("run").arg(&jibb_link).output().expect("run");
    assert_eq!(String::from_utf8(output.stdout).unwrap(), "42\n");

    let source = directory.path().join("target.jibb");
    fs::write(&source, "++  main  42\n").unwrap();
    let text_link = directory.path().join("y.txt");
    std::os::unix::fs::symlink(&source, &text_link).unwrap();
    let output = jibb().arg("check").arg(&text_link).output().expect("check");
    assert_eq!(output.status.code(), Some(1));
    assert!(
        String::from_utf8(output.stderr)
            .unwrap()
            .contains("unsupported source extension `.txt`; expected `.jibb`")
    );
}

#[test]
fn docs_do_not_follow_imports_out_of_the_source_root() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path().join("project/ui");
    fs::create_dir_all(&root).unwrap();
    fs::create_dir_all(directory.path().join("outside")).unwrap();
    fs::write(
        directory.path().join("outside/secret.jibb"),
        "++  secret  42\n",
    )
    .unwrap();
    fs::write(
        root.join("main.jibb"),
        "/=  s  /../../outside/secret\n++  main  secret.s\n",
    )
    .unwrap();
    let output_directory = directory.path().join("project/docs");
    let output = jibb()
        .args(["docs", "--source-root"])
        .arg(&root)
        .arg("-o")
        .arg(&output_directory)
        .arg(&root)
        .output()
        .expect("generate documentation");
    assert_eq!(output.status.code(), Some(1));
    assert!(
        String::from_utf8(output.stderr)
            .unwrap()
            .contains("import path segment `..` does not name a module")
    );
    assert!(!output_directory.exists());
    assert!(!directory.path().join("outside/secret.md").exists());
}
