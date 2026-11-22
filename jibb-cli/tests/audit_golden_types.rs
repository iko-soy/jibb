//! Compares the native checker with the Hoon checker's golden type reports.
//!
//! `types.txt` records the full Hoon checker's verdict for a golden case. A case
//! whose report names no error site and no partial-inference limitation is valid;
//! the native checker must accept it and print the same principal types for its
//! value definitions. Cases that need module fixtures, Hoon imports or a logical
//! path are outside this comparison.

use jibb::{check, loader, parse_ast};
use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
};

struct Case {
    name: String,
    source: String,
    types: String,
    prelude: bool,
}

fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..")
}

fn cases() -> Vec<Case> {
    let golden = root().join("tests/golden");
    let mut cases = Vec::new();
    let mut entries = fs::read_dir(&golden)
        .expect("read the golden corpus")
        .map(|entry| entry.expect("golden entry").path())
        .collect::<Vec<_>>();
    entries.sort();
    for directory in entries {
        let read = |name: &str| fs::read_to_string(directory.join(name)).ok();
        let (Some(about), Some(types), Some(source)) =
            (read("about.txt"), read("types.txt"), read("source.jibb"))
        else {
            continue;
        };
        if !about.contains("expect-types") {
            continue;
        }
        if [
            "imports.txt",
            "marks.txt",
            "path.txt",
            "type-source.jibb",
            "type-path.txt",
        ]
        .iter()
        .any(|name| directory.join(name).exists())
        {
            continue;
        }
        let prelude = match read("modules.txt") {
            None => false,
            Some(modules) if modules.trim() == "# no module fixtures" => true,
            Some(_) => continue,
        };
        cases.push(Case {
            name: directory
                .file_name()
                .expect("case name")
                .to_string_lossy()
                .into_owned(),
            source,
            types,
            prelude,
        });
    }
    cases
}

fn expected_valid(types: &str) -> bool {
    !types.lines().any(|line| line.starts_with("/tests/golden/"))
        && !types.contains("partial inference")
}

fn expected_values(types: &str) -> BTreeMap<String, String> {
    types
        .lines()
        .filter_map(|line| line.strip_prefix("++ "))
        .filter_map(|line| line.split_once(": "))
        .map(|(name, typ)| (name.to_string(), typ.to_string()))
        .collect()
}

fn check_case(case: &Case) -> Result<jibb::check::CheckedModule, jibb::Diagnostic> {
    if case.prelude {
        let dev = root().join("jibb-dev");
        let prelude = dev.join("lib/jibb/prelude.jibb");
        loader::check_source(
            &case.source,
            Path::new("source.jibb"),
            &[dev],
            Some(&prelude),
        )
    } else {
        check(&parse_ast(&case.source)?)
    }
}

/// Reports every divergence; run with `--ignored --nocapture`.
#[test]
#[ignore]
fn golden_types_report() {
    let mut accepted = 0;
    let mut rejected = 0;
    for case in cases() {
        let valid = expected_valid(&case.types);
        let result = std::panic::catch_unwind(|| check_case(&case));
        let result = match result {
            Ok(result) => result,
            Err(_) => {
                println!("PANIC {}", case.name);
                continue;
            }
        };
        match (&result, valid) {
            (Ok(checked), true) => {
                accepted += 1;
                for (name, expected) in expected_values(&case.types) {
                    let actual = checked
                        .values
                        .get(&name)
                        .map(ToString::to_string)
                        .unwrap_or_else(|| "<missing>".to_string());
                    if actual != expected {
                        println!(
                            "TYPE {} {name}: expected {expected} | actual {actual}",
                            case.name
                        );
                    }
                }
            }
            (Err(error), true) => {
                println!(
                    "REJECT {}{}: {}",
                    case.name,
                    if case.prelude { " (prelude)" } else { "" },
                    error.to_string().lines().next().unwrap_or_default()
                );
            }
            (Ok(_), false) => {
                println!(
                    "ACCEPT {}: {}",
                    case.name,
                    case.types.lines().next().unwrap_or_default()
                );
            }
            (Err(_), false) => rejected += 1,
        }
    }
    println!("agreeing: {accepted} valid, {rejected} invalid");
}

fn case(name: &str) -> Case {
    cases()
        .into_iter()
        .find(|case| case.name == name)
        .unwrap_or_else(|| panic!("golden case {name} is missing"))
}

/// The excerpt a diagnostic or note covers.
fn excerpt(case: &Case, span: jibb::ast::Span) -> &str {
    &case.source[span.start..span.end]
}

#[test]
fn audited_golden_cases_match_the_full_checker() {
    for name in [
        "split-types-constructor-context-later-use",
        "split-types-constructor-context-positive",
        "split-types-loobean-singleton-source-positive",
        "split-types-partial-atom-alias-positive",
        "split-types-partial-atom-constraint-positive",
        "split-types-partial-many-atom-constraints-positive",
        "split-types-recursive-gate-positive",
        "types-generic-local-parameter",
        "types-generic-local-scope",
        "types-record-nested",
        "types-union-print-escape",
        "types-recursion-scc-groups",
        "split-types-union-finite-positive",
        "split-types-deferred-call-context-positive",
        "split-types-local-error-cast-positive",
        "inline-decimal-generic",
        "split-types-prelude-arithmetic-positive",
    ] {
        let case = case(name);
        assert!(expected_valid(&case.types), "{name} is a valid case");
        let checked = check_case(&case).unwrap_or_else(|error| panic!("{name}: {error}"));
        for (value, expected) in expected_values(&case.types) {
            assert_eq!(
                checked.values[&value].to_string(),
                expected,
                "{name}: ++ {value}"
            );
        }
    }

    // Invalid programs the native checker accepted, with the full checker's
    // message and sites.
    for (name, message, site, note) in [
        (
            "split-types-recursive-gate-mixed",
            "capital `A` cannot be fixed to @t",
            "\"hi\"",
            Some("A"),
        ),
        (
            "split-types-recursive-sample-alias-use",
            "capital `A` cannot be fixed to @t",
            "\"hi\"",
            Some("A"),
        ),
        (
            "split-types-partial-locals-through-global",
            "type mismatch: expected @p, found @t",
            "(local \"hi\")",
            None,
        ),
        (
            "split-inline-decimal-sites-later",
            "type mismatch: `1` is a @ud, not a @dr; write ~s1",
            "1",
            None,
        ),
        (
            "split-types-recursive-gate-poly",
            "capital `A` cannot be fixed to [A A]",
            "[x x]",
            Some("A"),
        ),
    ] {
        let case = case(name);
        assert!(!expected_valid(&case.types), "{name} is an invalid case");
        let error = check_case(&case).expect_err(name);
        assert_eq!(error.message, message, "{name}");
        assert_eq!(
            excerpt(&case, error.span.expect("located")),
            site,
            "{name}: {error}"
        );
        if let Some(note) = note {
            assert_eq!(excerpt(&case, error.notes[0].span), note, "{name}");
        }
    }
}
