use std::{
    env, io,
    path::{Path, PathBuf},
    process::{Command, ExitStatus},
};

#[derive(Debug)]
pub struct DevOptions {
    pub directory: PathBuf,
    pub desk: Option<String>,
    pub pier: Option<PathBuf>,
    pub pill: Option<PathBuf>,
    pub urbit: Option<PathBuf>,
    pub click: Option<PathBuf>,
    pub ship_tool: Option<PathBuf>,
    pub timeout: u64,
}

pub fn run(options: &DevOptions) -> io::Result<ExitStatus> {
    let tool = ship_tool(options.ship_tool.as_deref())?;
    let pier = options
        .pier
        .clone()
        .unwrap_or_else(|| options.directory.join(".jibb/zod"));
    let mut command = Command::new(tool);
    command.arg("--pier").arg(pier);
    if let Some(click) = &options.click {
        command.arg("--click").arg(click);
    }
    command
        .arg("dev")
        .arg("--timeout")
        .arg(options.timeout.to_string());
    if let Some(desk) = &options.desk {
        command.arg("--desk").arg(desk);
    }
    if let Some(pill) = &options.pill {
        command.arg("--pill").arg(pill);
    }
    if let Some(urbit) = &options.urbit {
        command.arg("--urbit").arg(urbit);
    }
    command.arg(&options.directory).status()
}

fn ship_tool(explicit: Option<&Path>) -> io::Result<PathBuf> {
    if let Some(path) = explicit {
        return require_tool(path);
    }
    if let Some(path) = env::var_os("JIBB_SHIP_TOOL") {
        return require_tool(Path::new(&path));
    }
    let installed = env::current_exe()
        .ok()
        .and_then(|exe| exe.parent().map(Path::to_path_buf))
        .map(|bin| bin.join("../share/jibb/tools/ship"));
    find_tool(&[
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../tools/ship"),
        installed.unwrap_or_default(),
    ])
}

/// The first candidate that is a file at an absolute path. Only locations tied
/// to this executable are candidates: a `tools/ship` relative to the working
/// directory would run whatever the current checkout provides.
fn find_tool(candidates: &[PathBuf]) -> io::Result<PathBuf> {
    for candidate in candidates {
        if candidate.is_absolute() && candidate.is_file() {
            return Ok(candidate.clone());
        }
    }
    Err(io::Error::new(
        io::ErrorKind::NotFound,
        "cannot find tools/ship; pass --ship-tool FILE or set JIBB_SHIP_TOOL",
    ))
}

fn require_tool(path: &Path) -> io::Result<PathBuf> {
    if path.is_file() {
        Ok(path.to_path_buf())
    } else {
        Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("no ship tool at {}", path.display()),
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_tool_relative_to_the_working_directory_is_not_found() {
        // The test runs in the package directory, where `src/dev.rs` exists.
        let relative = PathBuf::from("src/dev.rs");
        assert!(relative.is_file());
        let error = find_tool(std::slice::from_ref(&relative)).unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::NotFound);
        let absolute = env::current_dir().unwrap().join("src/dev.rs");
        assert_eq!(find_tool(&[relative, absolute.clone()]).unwrap(), absolute);
    }
}
