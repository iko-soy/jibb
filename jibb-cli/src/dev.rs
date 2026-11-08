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
    let candidates = [
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../tools/ship"),
        installed.unwrap_or_default(),
        PathBuf::from("tools/ship"),
    ];
    for candidate in &candidates {
        if candidate.is_file() {
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
