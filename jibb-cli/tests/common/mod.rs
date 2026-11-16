use std::{env, path::Path};

/// Whether the repository file or folder a corpus test reads beside the
/// crate is there. A checkout and Nix's `jibb-cli-tests` have it; a copy of
/// the crate alone doesn't, and the test then fails rather than pass without
/// reading it, unless `JIBB_CLI_SKIP_CORPUS=1` asks to skip it.
pub fn corpus(path: &Path) -> bool {
    if path.is_dir() || path.is_file() {
        return true;
    }
    assert!(
        env::var_os("JIBB_CLI_SKIP_CORPUS").is_some_and(|value| value == "1"),
        "{} is missing: run the tests in a checkout of the repository, or set \
         JIBB_CLI_SKIP_CORPUS=1 to skip the tests that read it",
        path.display()
    );
    false
}
