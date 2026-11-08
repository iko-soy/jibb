use std::{
    fs,
    io::Write,
    process::{Command, Stdio},
};

fn jibb() -> Command {
    Command::new(env!("CARGO_BIN_EXE_jibb"))
}

#[test]
fn init_creates_a_formatted_agent_and_frontend_project() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let project = directory.path().join("counter-app");

    let result = jibb()
        .args(["init"])
        .arg(&project)
        .output()
        .expect("initialize project");
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert!(result.stderr.is_empty());
    assert_eq!(
        String::from_utf8(result.stdout).expect("output UTF-8"),
        format!("Initialized `counter-app` in {}\n", project.display())
    );

    for relative in [
        "app/counter-app.hoon",
        "desk.bill",
        "desk.docket-0",
        "mar/counter-app-action.hoon",
        "mar/counter-app-state.hoon",
        "README.md",
        "sur/counter-app.hoon",
        "sys.kelvin",
        "ui/api/counter-app.jibb",
        "ui/index.jibb",
    ] {
        assert!(project.join(relative).is_file(), "missing {relative}");
    }

    let agent = fs::read_to_string(project.join("app/counter-app.hoon")).expect("read agent");
    assert!(agent.contains("/+  default-agent, dbug"));
    assert!(agent.contains("%counter-app-action"));
    assert!(agent.contains("++  on-poke"));
    assert!(agent.contains("++  on-watch"));
    let frontend = fs::read_to_string(project.join("ui/index.jibb")).expect("read frontend");
    assert!(frontend.contains("++  main  program init update view subs"));
    assert!(frontend.contains("poke.counter %increment"));
    assert!(frontend.contains("state.counter |=%got"));
    assert!(frontend.contains("heading 1 \"Counter App\""));
    let docket = fs::read_to_string(project.join("desk.docket-0")).expect("read docket");
    assert!(docket.contains("title+'Counter App'"));
    assert!(docket.contains("site+/apps/counter-app"));

    let formatted = jibb()
        .args(["fmt", "--check"])
        .arg(project.join("ui/index.jibb"))
        .arg(project.join("ui/api/counter-app.jibb"))
        .output()
        .expect("check generated formatting");
    assert!(
        formatted.status.success(),
        "{}",
        String::from_utf8_lossy(&formatted.stdout)
    );
}

#[test]
fn init_refuses_to_overwrite_or_use_an_invalid_desk_name() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let project = directory.path().join("existing");
    fs::create_dir(&project).expect("create destination");
    let sentinel = project.join("keep.txt");
    fs::write(&sentinel, "keep me\n").expect("write existing file");

    let result = jibb()
        .args(["init"])
        .arg(&project)
        .output()
        .expect("reject nonempty destination");
    assert_eq!(result.status.code(), Some(2));
    assert!(result.stdout.is_empty());
    let error = String::from_utf8_lossy(&result.stderr);
    assert!(error.contains("already exists and is not empty"), "{error}");
    assert!(error.contains("no files were overwritten"), "{error}");
    assert_eq!(
        fs::read_to_string(&sentinel).expect("read sentinel"),
        "keep me\n"
    );
    assert_eq!(fs::read_dir(&project).expect("read destination").count(), 1);

    let invalid = directory.path().join("Invalid-name");
    let result = jibb()
        .args(["init"])
        .arg(&invalid)
        .output()
        .expect("reject invalid desk name");
    assert_eq!(result.status.code(), Some(2));
    assert!(String::from_utf8_lossy(&result.stderr).contains("invalid desk name"));
    assert!(!invalid.exists());
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

#[test]
fn run_evaluates_selected_entries_and_reports_errors() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let path = directory.path().join("program.jibb");
    fs::write(&path, "++ main 42\n++ other 7\n").expect("write program");

    let output = jibb().args(["run"]).arg(&path).output().expect("run main");
    assert!(output.status.success());
    assert_eq!(output.stdout, b"42\n");

    let output = jibb()
        .args(["run", "--entry", "other"])
        .arg(&path)
        .output()
        .expect("run other");
    assert!(output.status.success());
    assert_eq!(output.stdout, b"7\n");

    fs::write(directory.path().join("util.jibb"), "++ answer 42\n").unwrap();
    fs::write(&path, "/= util /util\n++ main answer.util\n").unwrap();
    let output = jibb()
        .args(["run", "--source-root"])
        .arg(directory.path())
        .arg(&path)
        .output()
        .expect("run imported module");
    assert!(output.status.success());
    assert_eq!(output.stdout, b"42\n");

    fs::write(&path, "++ main !!\n").expect("write crash");
    let output = jibb().args(["run"]).arg(&path).output().expect("run crash");
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&output.stderr).contains("crash"));

    fs::write(&path, "++ main [a\n").expect("write invalid source");
    let output = jibb()
        .args(["run"])
        .arg(&path)
        .output()
        .expect("run invalid");
    assert_eq!(output.status.code(), Some(1));

    let output = jibb()
        .args(["run"])
        .arg(directory.path().join("missing.jibb"))
        .output()
        .expect("run missing");
    assert_eq!(output.status.code(), Some(2));
}

#[test]
fn check_checks_multiple_files_without_evaluating() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let crash = directory.path().join("crash.jibb");
    let parse_error = directory.path().join("parse-error.jibb");
    let type_error = directory.path().join("type-error.jibb");
    fs::write(&crash, "++ main !!\n").expect("write crash");
    fs::write(&parse_error, "++ broken [a\n").expect("write parse error");
    fs::write(&type_error, "++ bad ^- @ud \"1\"\n").expect("write type error");

    let output = jibb()
        .args(["check"])
        .arg(&crash)
        .output()
        .expect("check crash");
    assert!(output.status.success());
    assert!(output.stdout.is_empty());
    assert!(output.stderr.is_empty());

    let output = jibb()
        .args(["check"])
        .arg(&crash)
        .arg(&parse_error)
        .arg(&type_error)
        .output()
        .expect("check multiple files");
    assert_eq!(output.status.code(), Some(1));
    assert!(output.stdout.is_empty());
    let errors = String::from_utf8_lossy(&output.stderr);
    assert!(errors.contains("parse-error.jibb"), "{errors}");
    assert!(errors.contains("type-error.jibb"), "{errors}");
    assert!(errors.contains("type mismatch"), "{errors}");

    let output = jibb()
        .args(["check"])
        .arg(directory.path().join("missing.jibb"))
        .output()
        .expect("check missing file");
    assert_eq!(output.status.code(), Some(2));
}

#[test]
fn check_loads_imports_and_preludes() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    let main = root.join("main.jibb");
    fs::write(root.join("util.jibb"), "++ answer 42\n").expect("write util");
    fs::write(&main, "/= util /util\n++ main !!\n++ copied answer.util\n")
        .expect("write importing module");

    let output = jibb()
        .args(["check", "--source-root"])
        .arg(root)
        .arg(&main)
        .output()
        .expect("check imported module");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );

    let prelude = root.join("prelude.jibb");
    fs::write(&prelude, "++ answer 42\n").expect("write prelude");
    fs::write(&main, "++ main !!\n++ copied answer\n").expect("write prelude user");
    let output = jibb()
        .args(["check", "--prelude"])
        .arg(&prelude)
        .arg(&main)
        .output()
        .expect("check with prelude");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn check_reads_standard_input() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::write(root.join("util.jibb"), "++ answer 42\n").expect("write util");

    let mut child = jibb()
        .args(["check", "--source-root"])
        .arg(root)
        .arg("-")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn jibb check");
    child
        .stdin
        .take()
        .expect("stdin")
        .write_all(b"/= util /util\n++ main !!\n++ copied answer.util\n")
        .expect("write stdin");
    let output = child.wait_with_output().expect("wait for jibb check");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(output.stdout.is_empty());

    let mut child = jibb()
        .args(["check", "-"])
        .stdin(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn jibb check");
    child
        .stdin
        .take()
        .expect("stdin")
        .write_all(b"++ bad ^- @ud \"1\"\n")
        .expect("write invalid stdin");
    let output = child.wait_with_output().expect("wait for jibb check");
    assert_eq!(output.status.code(), Some(1));
    let errors = String::from_utf8_lossy(&output.stderr);
    assert!(errors.contains("jibb check: -:"), "{errors}");
    assert!(errors.contains("type mismatch"), "{errors}");
}

#[test]
fn docs_generates_module_files_and_readme_index() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("lib")).expect("create library directory");
    let main = root.join("main.jibb");
    fs::write(
        &main,
        ":: Main module documentation.\n/= util /lib/util\n\n:: The answer.\n++ answer 42\n\n:: A color.\n+$ color ?\n\n:: Next value.\n++ next 43\n",
    )
    .expect("write main module");
    fs::write(
        root.join("lib/util.jibb"),
        "::  Utility module documentation.\n::\n::  Identity function.\n++ id |= x=@ud x\n",
    )
    .expect("write utility module");
    fs::write(root.join("empty.jibb"), ":: Empty module documentation.\n")
        .expect("write empty module");
    let output = root.join("generated");

    let result = jibb()
        .args(["docs", "--source-root"])
        .arg(root)
        .arg("--output")
        .arg(&output)
        .arg(root)
        .output()
        .expect("generate documentation");
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert!(result.stdout.is_empty());
    assert!(result.stderr.is_empty());

    let index = fs::read_to_string(output.join("readme.md")).expect("read index");
    assert_eq!(
        index,
        "# Jibb module documentation\n\n- [empty](<empty.md>)\n- [lib/util](<lib/util.md>)\n- [main](<main.md>)\n"
    );
    let empty_docs = fs::read_to_string(output.join("empty.md")).expect("read empty docs");
    assert_eq!(
        empty_docs,
        "# empty\n\nEmpty module documentation.\n\n## Table of contents\n\nThis module has no declarations.\n"
    );
    let main_docs = fs::read_to_string(output.join("main.md")).expect("read main docs");
    assert!(main_docs.starts_with("# main\n\nMain module documentation.\n"));
    assert!(main_docs.contains("## Table of contents\n"));
    assert!(main_docs.contains("- [Imports](#imports)\n"));
    assert!(main_docs.contains("- [`+$ color`](#mold-color)\n"));
    assert!(main_docs.contains("- [`++ answer`](#value-answer)\n"));
    assert!(main_docs.contains("### `++ answer`\n\nThe answer.\n"));
    assert!(main_docs.contains("**Type**\n\n```jibb\n@ud\n```"));
    assert!(main_docs.contains("### `+$ color`\n\nA color.\n\n```jibb\n+$ color ?\n```"));

    let util_docs = fs::read_to_string(output.join("lib/util.md")).expect("read utility docs");
    assert!(util_docs.starts_with("# lib/util\n\nUtility module documentation.\n"));
    assert!(util_docs.contains("### `++ id`\n\nIdentity function.\n"));
    assert!(util_docs.contains("$-(@ud @ud)"));

    let imported_output = root.join("imported-output");
    let result = jibb()
        .args(["docs", "--source-root"])
        .arg(root)
        .arg("--output")
        .arg(&imported_output)
        .arg(&main)
        .output()
        .expect("document imported modules");
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert!(imported_output.join("main.md").is_file());
    assert!(imported_output.join("lib/util.md").is_file());
}

#[test]
fn docs_reports_source_and_io_errors_without_writing_an_index() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    let invalid = root.join("invalid.jibb");
    let output = root.join("generated");
    fs::write(&invalid, "++ bad ^- @ud \"1\"\n").expect("write invalid module");

    let result = jibb()
        .args(["docs", "--output"])
        .arg(&output)
        .arg(&invalid)
        .output()
        .expect("reject invalid documentation input");
    assert_eq!(result.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&result.stderr).contains("type mismatch"));
    assert!(!output.join("readme.md").exists());

    let result = jibb()
        .args(["docs"])
        .arg(root.join("missing.jibb"))
        .output()
        .expect("report missing documentation input");
    assert_eq!(result.status.code(), Some(2));
    assert!(String::from_utf8_lossy(&result.stderr).contains("missing.jibb"));
}

#[test]
fn docs_handles_virtual_and_parent_relative_imports() {
    let directory = tempfile::tempdir().expect("temporary directory");
    let root = directory.path();
    fs::create_dir(root.join("a")).expect("create module directory");
    let main = root.join("a/main.jibb");
    fs::write(
        &main,
        "/= core /lib/jibb/primitives\n/= util /util\n++ answer 42\n",
    )
    .expect("write importing module");
    fs::write(root.join("a/util.jibb"), "++ answer 42\n").expect("write utility");
    let output = root.join("generated");

    let result = jibb()
        .args(["docs", "--source-root"])
        .arg(root)
        .arg("--output")
        .arg(&output)
        .arg(&main)
        .output()
        .expect("document virtual and relative imports");
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert!(output.join("a/main.md").is_file());
    assert!(output.join("a/util.md").is_file());
    let index = fs::read_to_string(output.join("readme.md")).expect("read index");
    assert_eq!(
        index,
        "# Jibb module documentation\n\n- [a/main](<a/main.md>)\n- [a/util](<a/util.md>)\n"
    );
}
