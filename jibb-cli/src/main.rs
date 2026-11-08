use clap::{Parser, Subcommand};
use std::{
    ffi::OsString,
    fs::{self, OpenOptions},
    io::{self, Read, Write},
    path::{Path, PathBuf},
    process::ExitCode,
    sync::atomic::{AtomicU64, Ordering},
};

const EXIT_SUCCESS: u8 = 0;
const EXIT_FORMATTING: u8 = 1;
const EXIT_TOOL: u8 = 2;
const DIFF_CONTEXT: usize = 3;

#[derive(Parser)]
#[command(name = "jibb", version, about = "Earth-side Jibb utilities")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    #[command(about = "Format Jibb source")]
    Fmt {
        #[arg(long, help = "Check whether files are already formatted")]
        check: bool,
        #[arg(long, help = "Print formatting diffs without writing files")]
        diff: bool,
        #[arg(value_name = "FILE", help = "Files to format, or standard input")]
        files: Vec<PathBuf>,
    },
    #[command(about = "Create a Hoon agent and Jibb frontend project")]
    Init {
        #[arg(value_name = "DIRECTORY", help = "New or empty project directory")]
        directory: PathBuf,
    },
    #[command(about = "Statically check Jibb source without evaluating it")]
    Check {
        #[arg(
            value_name = "FILE",
            required = true,
            help = "Files to check, or `-` for standard input"
        )]
        files: Vec<PathBuf>,
        #[arg(long = "source-root", help = "Root for `/=` module imports")]
        source_roots: Vec<PathBuf>,
        #[arg(long, help = "Source prelude module to include")]
        prelude: Option<PathBuf>,
    },
    #[command(about = "Generate Markdown documentation for Jibb modules")]
    Docs {
        #[arg(
            value_name = "PATH",
            required = true,
            help = "Jibb files or directories to document"
        )]
        paths: Vec<PathBuf>,
        #[arg(
            short,
            long,
            default_value = "docs/api",
            help = "Directory for generated Markdown files"
        )]
        output: PathBuf,
        #[arg(long = "source-root", help = "Root for `/=` module imports")]
        source_roots: Vec<PathBuf>,
        #[arg(long, help = "Source prelude module to include")]
        prelude: Option<PathBuf>,
    },
    #[command(about = "Statically check and evaluate a Jibb entry point")]
    Run {
        #[arg(value_name = "FILE", help = "Jibb source file")]
        file: PathBuf,
        #[arg(long, default_value = "main", help = "Entry definition to evaluate")]
        entry: String,
        #[arg(long = "source-root", help = "Root for `/=` module imports")]
        source_roots: Vec<PathBuf>,
        #[arg(long, help = "Source prelude module to include")]
        prelude: Option<PathBuf>,
    },
}

#[derive(Default)]
struct RunStatus {
    needs_formatting: bool,
    invalid_source: bool,
    tool_error: bool,
}

impl RunStatus {
    fn exit_code(&self) -> ExitCode {
        if self.tool_error {
            ExitCode::from(EXIT_TOOL)
        } else if self.invalid_source || self.needs_formatting {
            ExitCode::from(EXIT_FORMATTING)
        } else {
            ExitCode::from(EXIT_SUCCESS)
        }
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match cli.command {
        Command::Fmt { check, diff, files } => run_fmt(&files, check, diff),
        Command::Init { directory } => run_init(&directory),
        Command::Check {
            files,
            source_roots,
            prelude,
        } => run_check(&files, &source_roots, prelude.as_deref()),
        Command::Docs {
            paths,
            output,
            source_roots,
            prelude,
        } => run_docs(&paths, &output, &source_roots, prelude.as_deref()),
        Command::Run {
            file,
            entry,
            source_roots,
            prelude,
        } => run_program(&file, &entry, &source_roots, prelude.as_deref()),
    }
}

fn run_init(directory: &Path) -> ExitCode {
    match jibb::init::create(directory) {
        Ok(name) => {
            println!("Initialized `{name}` in {}", directory.display());
            ExitCode::from(EXIT_SUCCESS)
        }
        Err(error) => {
            eprintln!("jibb init: {error}");
            ExitCode::from(EXIT_TOOL)
        }
    }
}

fn run_docs(
    paths: &[PathBuf],
    output: &Path,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> ExitCode {
    let files = match jibb::docs::generate(paths, source_roots, prelude) {
        Ok(files) => files,
        Err(error) => {
            eprintln!("jibb docs: {error}");
            return ExitCode::from(if error.is_io() {
                EXIT_TOOL
            } else {
                EXIT_FORMATTING
            });
        }
    };
    for (relative, contents) in files
        .iter()
        .filter(|(path, _)| *path != Path::new("readme.md"))
    {
        if let Err(error) = write_documentation_file(output, relative, contents) {
            eprintln!("jibb docs: {}: {error}", output.join(relative).display());
            return ExitCode::from(EXIT_TOOL);
        }
    }
    if let Some(index) = files.get(Path::new("readme.md"))
        && let Err(error) = write_documentation_file(output, Path::new("readme.md"), index)
    {
        eprintln!("jibb docs: {}: {error}", output.join("readme.md").display());
        return ExitCode::from(EXIT_TOOL);
    }
    ExitCode::from(EXIT_SUCCESS)
}

fn write_documentation_file(output: &Path, relative: &Path, contents: &str) -> io::Result<()> {
    let path = output.join(relative);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    atomic_write(&path, contents.as_bytes())
}

fn run_program(
    file: &Path,
    entry: &str,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> ExitCode {
    let label = file.to_string_lossy();
    let _source = match fs::read_to_string(file) {
        Ok(source) => source,
        Err(error) => {
            eprintln!("jibb run: {label}: failed to read: {error}");
            return ExitCode::from(EXIT_TOOL);
        }
    };
    match jibb::loader::evaluate_path(file, entry, source_roots, prelude) {
        Ok(value) => {
            if let Err(error) = write_stdout(format!("{value}\n").as_bytes()) {
                eprintln!("jibb run: failed to write standard output: {error}");
                ExitCode::from(EXIT_TOOL)
            } else {
                ExitCode::from(EXIT_SUCCESS)
            }
        }
        Err(error) => {
            eprintln!("jibb run: {label}: {error}");
            ExitCode::from(EXIT_FORMATTING)
        }
    }
}

fn run_check(files: &[PathBuf], source_roots: &[PathBuf], prelude: Option<&Path>) -> ExitCode {
    let stdin_requested = files.iter().any(|path| path == Path::new("-"));
    if stdin_requested && files.len() != 1 {
        eprintln!("jibb check: '-' must be the only input file");
        return ExitCode::from(EXIT_TOOL);
    }

    let mut status = RunStatus::default();
    if stdin_requested {
        let mut source = String::new();
        match io::stdin().read_to_string(&mut source) {
            Ok(_) => {
                if let Err(error) = jibb::loader::check_source(
                    &source,
                    Path::new("stdin.jibb"),
                    source_roots,
                    prelude,
                ) {
                    eprintln!("jibb check: -: {error}");
                    status.invalid_source = true;
                }
            }
            Err(error) => {
                eprintln!("jibb check: failed to read standard input: {error}");
                status.tool_error = true;
            }
        }
        return status.exit_code();
    }

    for file in files {
        let label = file.to_string_lossy();
        if let Err(error) = fs::read_to_string(file) {
            eprintln!("jibb check: {label}: failed to read: {error}");
            status.tool_error = true;
            continue;
        }
        if let Err(error) = jibb::loader::check_path(file, source_roots, prelude) {
            eprintln!("jibb check: {label}: {error}");
            status.invalid_source = true;
        }
    }
    status.exit_code()
}

fn run_fmt(files: &[PathBuf], check: bool, diff: bool) -> ExitCode {
    let stdin_requested = files.iter().any(|path| path == Path::new("-"));
    if stdin_requested && files.len() != 1 {
        eprintln!("jibb fmt: '-' must be the only input file");
        return ExitCode::from(EXIT_TOOL);
    }

    let mut status = RunStatus::default();
    let mut output = String::new();

    if files.is_empty() || stdin_requested {
        let mut bytes = Vec::new();
        match io::stdin().read_to_end(&mut bytes) {
            Ok(_) => process_input("-", bytes, None, check, diff, &mut output, &mut status),
            Err(error) => {
                eprintln!("jibb fmt: failed to read standard input: {error}");
                status.tool_error = true;
            }
        }
    } else {
        for path in files {
            let label = path.to_string_lossy();
            match fs::read(path) {
                Ok(bytes) => process_input(
                    &label,
                    bytes,
                    Some(path),
                    check,
                    diff,
                    &mut output,
                    &mut status,
                ),
                Err(error) => {
                    eprintln!("jibb fmt: {label}: failed to read: {error}");
                    status.tool_error = true;
                }
            }
        }
    }

    if let Err(error) = write_stdout(output.as_bytes()) {
        eprintln!("jibb fmt: failed to write standard output: {error}");
        status.tool_error = true;
    }
    status.exit_code()
}

fn process_input(
    label: &str,
    bytes: Vec<u8>,
    path: Option<&Path>,
    check: bool,
    diff: bool,
    output: &mut String,
    status: &mut RunStatus,
) {
    let source = match String::from_utf8(bytes) {
        Ok(source) => source,
        Err(error) => {
            let offset = error.utf8_error().valid_up_to();
            eprintln!("jibb fmt: {label}: input is not valid UTF-8 at byte {offset}");
            status.invalid_source = true;
            return;
        }
    };

    let formatted = match jibb::format_source(&source) {
        Ok(formatted) => formatted,
        Err(error) => {
            eprintln!("jibb fmt: {label}: invalid source: {error}");
            status.invalid_source = true;
            return;
        }
    };
    let changed = formatted != source;

    if changed && diff {
        output.push_str(&unified_diff(label, &source, &formatted));
    }
    if changed && check {
        status.needs_formatting = true;
        if !diff {
            output.push_str(label);
            output.push('\n');
        }
    }

    if !check && !diff {
        match path {
            None => output.push_str(&formatted),
            Some(path) if changed => {
                if let Err(error) = atomic_write(path, formatted.as_bytes()) {
                    eprintln!("jibb fmt: {label}: failed to write: {error}");
                    status.tool_error = true;
                }
            }
            Some(_) => {}
        }
    }
}

fn write_stdout(bytes: &[u8]) -> io::Result<()> {
    let stdout = io::stdout();
    let mut stdout = stdout.lock();
    stdout.write_all(bytes)?;
    stdout.flush()
}

fn atomic_write(path: &Path, contents: &[u8]) -> io::Result<()> {
    static NEXT_TEMP_FILE: AtomicU64 = AtomicU64::new(0);

    let permissions = match fs::metadata(path) {
        Ok(metadata) => Some(metadata.permissions()),
        Err(error) if error.kind() == io::ErrorKind::NotFound => None,
        Err(error) => return Err(error),
    };
    let parent = path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let file_name = path
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "path has no file name"))?;

    for _ in 0..100 {
        let mut temp_name = OsString::from(".");
        temp_name.push(file_name);
        temp_name.push(format!(
            ".jibb-{}-{}.tmp",
            std::process::id(),
            NEXT_TEMP_FILE.fetch_add(1, Ordering::Relaxed)
        ));
        let temp_path = parent.join(temp_name);

        let mut temp_file = match OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temp_path)
        {
            Ok(file) => file,
            Err(error) if error.kind() == io::ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(error),
        };

        let write_result = temp_file
            .write_all(contents)
            .and_then(|()| match &permissions {
                Some(permissions) => temp_file.set_permissions(permissions.clone()),
                None => Ok(()),
            })
            .and_then(|()| temp_file.sync_all());
        drop(temp_file);

        if let Err(error) = write_result {
            let _ = fs::remove_file(&temp_path);
            return Err(error);
        }
        if let Err(error) = fs::rename(&temp_path, path) {
            let _ = fs::remove_file(&temp_path);
            return Err(error);
        }
        return Ok(());
    }

    Err(io::Error::new(
        io::ErrorKind::AlreadyExists,
        "could not allocate a unique temporary file",
    ))
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum DiffTag {
    Equal,
    Delete,
    Insert,
}

#[derive(Clone, Copy)]
struct DiffOp<'a> {
    tag: DiffTag,
    line: &'a str,
}

fn unified_diff(label: &str, old: &str, new: &str) -> String {
    let operations = line_operations(old, new);
    let Some(first_change) = operations
        .iter()
        .position(|operation| operation.tag != DiffTag::Equal)
    else {
        return String::new();
    };

    let mut old_positions = Vec::with_capacity(operations.len() + 1);
    let mut new_positions = Vec::with_capacity(operations.len() + 1);
    old_positions.push(0usize);
    new_positions.push(0usize);
    for operation in &operations {
        let old_position = old_positions.last().copied().unwrap();
        let new_position = new_positions.last().copied().unwrap();
        old_positions.push(old_position + usize::from(operation.tag != DiffTag::Insert));
        new_positions.push(new_position + usize::from(operation.tag != DiffTag::Delete));
    }

    let mut result = format!("--- {label}\n+++ {label}\n");
    let mut change = first_change;
    loop {
        let start = context_before(&operations, change);
        let mut last_change = change;
        let mut scan = change + 1;
        while scan < operations.len() {
            if operations[scan].tag == DiffTag::Equal {
                scan += 1;
                continue;
            }
            let gap = operations[last_change + 1..scan]
                .iter()
                .filter(|operation| operation.tag == DiffTag::Equal)
                .count();
            if gap > DIFF_CONTEXT * 2 {
                break;
            }
            last_change = scan;
            scan += 1;
        }
        let end = context_after(&operations, last_change + 1);

        let old_before = old_positions[start];
        let new_before = new_positions[start];
        let old_count = old_positions[end] - old_before;
        let new_count = new_positions[end] - new_before;
        let old_start = if old_count == 0 {
            old_before
        } else {
            old_before + 1
        };
        let new_start = if new_count == 0 {
            new_before
        } else {
            new_before + 1
        };
        result.push_str(&format!(
            "@@ -{} +{} @@\n",
            diff_range(old_start, old_count),
            diff_range(new_start, new_count)
        ));

        for operation in &operations[start..end] {
            result.push(match operation.tag {
                DiffTag::Equal => ' ',
                DiffTag::Delete => '-',
                DiffTag::Insert => '+',
            });
            result.push_str(operation.line);
            if !operation.line.ends_with('\n') {
                result.push('\n');
                result.push_str("\\ No newline at end of file\n");
            }
        }

        change = end;
        while change < operations.len() && operations[change].tag == DiffTag::Equal {
            change += 1;
        }
        if change == operations.len() {
            break;
        }
    }
    result
}

fn context_before(operations: &[DiffOp<'_>], change: usize) -> usize {
    let mut start = change;
    let mut context = 0;
    while start > 0 && context < DIFF_CONTEXT {
        start -= 1;
        if operations[start].tag == DiffTag::Equal {
            context += 1;
        }
    }
    start
}

fn context_after(operations: &[DiffOp<'_>], after_change: usize) -> usize {
    let mut end = after_change;
    let mut context = 0;
    while end < operations.len() && context < DIFF_CONTEXT {
        if operations[end].tag == DiffTag::Equal {
            context += 1;
        }
        end += 1;
    }
    end
}

fn diff_range(start: usize, count: usize) -> String {
    if count == 1 {
        start.to_string()
    } else {
        format!("{start},{count}")
    }
}

fn line_operations<'a>(old: &'a str, new: &'a str) -> Vec<DiffOp<'a>> {
    let old_lines: Vec<&str> = old.split_inclusive('\n').collect();
    let new_lines: Vec<&str> = new.split_inclusive('\n').collect();
    let rows = old_lines.len() + 1;
    let columns = new_lines.len() + 1;

    if rows
        .checked_mul(columns)
        .is_none_or(|cells| cells > 4_000_000)
    {
        return replacement_operations(&old_lines, &new_lines);
    }

    let mut lcs = vec![0u32; rows * columns];
    for old_index in (0..old_lines.len()).rev() {
        for new_index in (0..new_lines.len()).rev() {
            let index = old_index * columns + new_index;
            lcs[index] = if old_lines[old_index] == new_lines[new_index] {
                1 + lcs[(old_index + 1) * columns + new_index + 1]
            } else {
                lcs[(old_index + 1) * columns + new_index]
                    .max(lcs[old_index * columns + new_index + 1])
            };
        }
    }

    let mut operations = Vec::with_capacity(old_lines.len() + new_lines.len());
    let (mut old_index, mut new_index) = (0, 0);
    while old_index < old_lines.len() && new_index < new_lines.len() {
        if old_lines[old_index] == new_lines[new_index] {
            operations.push(DiffOp {
                tag: DiffTag::Equal,
                line: old_lines[old_index],
            });
            old_index += 1;
            new_index += 1;
        } else if lcs[(old_index + 1) * columns + new_index]
            >= lcs[old_index * columns + new_index + 1]
        {
            operations.push(DiffOp {
                tag: DiffTag::Delete,
                line: old_lines[old_index],
            });
            old_index += 1;
        } else {
            operations.push(DiffOp {
                tag: DiffTag::Insert,
                line: new_lines[new_index],
            });
            new_index += 1;
        }
    }
    operations.extend(old_lines[old_index..].iter().map(|line| DiffOp {
        tag: DiffTag::Delete,
        line,
    }));
    operations.extend(new_lines[new_index..].iter().map(|line| DiffOp {
        tag: DiffTag::Insert,
        line,
    }));
    operations
}

fn replacement_operations<'a>(old_lines: &[&'a str], new_lines: &[&'a str]) -> Vec<DiffOp<'a>> {
    let prefix = old_lines
        .iter()
        .zip(new_lines)
        .take_while(|(old, new)| old == new)
        .count();
    let suffix = old_lines[prefix..]
        .iter()
        .rev()
        .zip(new_lines[prefix..].iter().rev())
        .take_while(|(old, new)| old == new)
        .count();

    let mut operations = Vec::with_capacity(old_lines.len() + new_lines.len());
    operations.extend(old_lines[..prefix].iter().map(|line| DiffOp {
        tag: DiffTag::Equal,
        line,
    }));
    operations.extend(
        old_lines[prefix..old_lines.len() - suffix]
            .iter()
            .map(|line| DiffOp {
                tag: DiffTag::Delete,
                line,
            }),
    );
    operations.extend(
        new_lines[prefix..new_lines.len() - suffix]
            .iter()
            .map(|line| DiffOp {
                tag: DiffTag::Insert,
                line,
            }),
    );
    operations.extend(
        old_lines[old_lines.len() - suffix..]
            .iter()
            .map(|line| DiffOp {
                tag: DiffTag::Equal,
                line,
            }),
    );
    operations
}

#[cfg(test)]
mod tests {
    use super::unified_diff;

    #[test]
    fn unchanged_diff_is_empty() {
        assert_eq!(unified_diff("input.jibb", "same\n", "same\n"), "");
    }

    #[test]
    fn renders_a_unified_hunk() {
        assert_eq!(
            unified_diff("input.jibb", "old\n", "new\n"),
            "--- input.jibb\n+++ input.jibb\n@@ -1 +1 @@\n-old\n+new\n"
        );
    }

    #[test]
    fn marks_missing_final_newlines() {
        let diff = unified_diff("-", "old", "new");
        assert!(diff.contains("-old\n\\ No newline at end of file\n"));
        assert!(diff.contains("+new\n\\ No newline at end of file\n"));
    }

    #[test]
    fn separates_distant_changes_into_hunks() {
        let old = "one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\n";
        let new = "ONE\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nNINE\n";
        let diff = unified_diff("input.jibb", old, new);
        assert_eq!(diff.matches("@@ -").count(), 2);
        assert!(diff.contains("@@ -1,4 +1,4 @@\n"));
        assert!(diff.contains("@@ -6,4 +6,4 @@\n"));
    }
}
