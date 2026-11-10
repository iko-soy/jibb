use jibb::format_source;
use std::{fs, path::Path};

fn valid_case(about: &Path) -> bool {
    let Ok(metadata) = fs::read_to_string(about) else {
        return true;
    };
    metadata
        .lines()
        .find(|line| line.starts_with("expect:"))
        .is_none_or(|line| line.starts_with("expect: parse") || line.starts_with("expect: unclear"))
}

#[test]
fn golden_syntax_and_formatting_corpus() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let golden = root.join("tests/golden");
    if !golden.is_dir() {
        return;
    }

    let mut checked = 0;
    for entry in fs::read_dir(golden).expect("read golden corpus") {
        let source = entry
            .expect("golden directory entry")
            .path()
            .join("source.jibb");
        if !source.is_file() {
            continue;
        }
        checked += 1;
        let valid = valid_case(&source.with_file_name("about.txt"));
        let bytes = fs::read(&source).expect("read golden source");
        match String::from_utf8(bytes) {
            Ok(text) => {
                let result = format_source(&text);
                if valid {
                    assert!(
                        result.is_ok(),
                        "{} should format: {result:?}",
                        source.display()
                    );
                } else {
                    assert!(result.is_err(), "{} should be rejected", source.display());
                }
            }
            Err(_) => assert!(!valid, "{} is not valid UTF-8", source.display()),
        }
    }
    assert!(checked >= 750, "only {checked} golden cases were found");
}

// Milestone 7: the formatter leaves every example in the doc unchanged.
// tools/doc-blocks keeps each Jibb block of docs/spec as a doc-* case.
#[test]
fn doc_examples_are_canonical() {
    let golden = Path::new(env!("CARGO_MANIFEST_DIR")).join("../tests/golden");
    if !golden.is_dir() {
        return;
    }
    let mut checked = 0;
    for entry in fs::read_dir(golden).expect("read golden corpus") {
        let directory = entry.expect("golden directory entry").path();
        let is_doc = directory
            .file_name()
            .is_some_and(|name| name.to_string_lossy().starts_with("doc-"));
        if !is_doc {
            continue;
        }
        let source = directory.join("source.jibb");
        let text = fs::read_to_string(&source).expect("read a doc example");
        let formatted = format_source(&text)
            .unwrap_or_else(|error| panic!("{} should format: {error}", source.display()));
        assert_eq!(formatted, text, "the formatter changes {}", source.display());
        checked += 1;
    }
    assert!(checked >= 14, "only {checked} doc examples were found");
}

#[test]
fn app_and_prelude_sources_format_and_converge() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let mut files = Vec::new();
    for directory in ["my-app", "jibb-dev"] {
        let directory = root.join(directory);
        if !directory.is_dir() {
            return;
        }
        collect_jibb(&directory, &mut files);
    }
    assert!(!files.is_empty());
    for source in files {
        let text = fs::read_to_string(&source).expect("read application source");
        assert!(
            format_source(&text).is_ok(),
            "{} should format and converge",
            source.display()
        );
    }
}

fn collect_jibb(directory: &Path, files: &mut Vec<std::path::PathBuf>) {
    for entry in fs::read_dir(directory).expect("read source directory") {
        let path = entry.expect("source directory entry").path();
        if path.is_dir() {
            collect_jibb(&path, files);
        } else if path
            .extension()
            .is_some_and(|extension| extension == "jibb")
        {
            files.push(path);
        }
    }
}
