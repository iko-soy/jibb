use crate::{
    Diagnostic,
    ast::{Definition, DefinitionKind, ImportKind, Module},
    loader::{check_path, is_primitive_module_path, resolve_module_path},
    parse_ast,
};
use std::{
    collections::{BTreeMap, VecDeque},
    fmt, fs, io,
    path::{Path, PathBuf},
};

#[derive(Debug)]
pub enum Error {
    Io { path: PathBuf, error: io::Error },
    Diagnostic { path: PathBuf, error: Diagnostic },
    Invalid(String),
}

impl Error {
    pub fn is_io(&self) -> bool {
        matches!(self, Self::Io { .. })
    }
}

impl fmt::Display for Error {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io { path, error } => write!(formatter, "{}: {error}", path.display()),
            Self::Diagnostic { path, error } => write!(formatter, "{}: {error}", path.display()),
            Self::Invalid(message) => formatter.write_str(message),
        }
    }
}

impl std::error::Error for Error {}

struct SourceModule {
    file: PathBuf,
    logical_path: PathBuf,
    source: String,
    syntax: Module,
}

#[derive(Clone)]
struct Candidate {
    file: PathBuf,
    logical_path: PathBuf,
}

pub fn generate(
    inputs: &[PathBuf],
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> Result<BTreeMap<PathBuf, String>, Error> {
    let mut pending = VecDeque::new();
    for input in inputs {
        discover_input(input, source_roots, &mut pending)?;
    }

    let mut modules = BTreeMap::new();
    while let Some(candidate) = pending.pop_front() {
        if modules.contains_key(&candidate.file) {
            continue;
        }
        let source = fs::read_to_string(&candidate.file).map_err(|error| Error::Io {
            path: candidate.file.clone(),
            error,
        })?;
        let syntax = parse_ast(&source).map_err(|error| Error::Diagnostic {
            path: candidate.file.clone(),
            error,
        })?;
        for import in &syntax.imports {
            if let ImportKind::Module { path, .. } = &import.kind
                && !is_primitive_module_path(path)
            {
                let file =
                    resolve_module_path(path, &candidate.file, source_roots).map_err(|error| {
                        Error::Diagnostic {
                            path: candidate.file.clone(),
                            error,
                        }
                    })?;
                let file = fs::canonicalize(&file).map_err(|error| Error::Io {
                    path: file.clone(),
                    error,
                })?;
                let logical_path = source_root_relative(&file, source_roots).unwrap_or_else(|| {
                    candidate
                        .logical_path
                        .parent()
                        .unwrap_or_else(|| Path::new(""))
                        .join(import_logical_path(path))
                });
                pending.push_back(Candidate { file, logical_path });
            }
        }
        modules.insert(
            candidate.file.clone(),
            SourceModule {
                file: candidate.file,
                logical_path: candidate.logical_path,
                source,
                syntax,
            },
        );
    }
    if modules.is_empty() {
        return Err(Error::Invalid("no Jibb modules found".to_string()));
    }

    let mut owners = BTreeMap::new();
    for module in modules.values() {
        let output_path = markdown_path(&module.logical_path);
        let normalized = output_path
            .to_string_lossy()
            .replace('\\', "/")
            .to_ascii_lowercase();
        if normalized == "readme.md" {
            return Err(Error::Invalid(format!(
                "{}: module output `readme.md` is reserved for the index",
                module.file.display()
            )));
        }
        if let Some(previous) = owners.insert(normalized, &module.file) {
            return Err(Error::Invalid(format!(
                "modules {} and {} have the same documentation path `{}`",
                previous.display(),
                module.file.display(),
                module.logical_path.display()
            )));
        }
    }

    let mut output = BTreeMap::new();
    for module in modules.values() {
        let checked =
            check_path(&module.file, source_roots, prelude).map_err(|error| Error::Diagnostic {
                path: module.file.clone(),
                error,
            })?;
        let markdown = render_module(module, &checked)?;
        output.insert(markdown_path(&module.logical_path), markdown);
    }

    let mut index = String::from("# Jibb module documentation\n\n");
    let mut indexed_modules = modules.values().collect::<Vec<_>>();
    indexed_modules.sort_by(|left, right| left.logical_path.cmp(&right.logical_path));
    for module in indexed_modules {
        let name = module_name(&module.logical_path);
        index.push_str(&format!(
            "- [{}](<{}>)\n",
            markdown_label(&name),
            markdown_destination(&markdown_path(&module.logical_path))
        ));
    }
    output.insert(PathBuf::from("readme.md"), index);
    Ok(output)
}

fn discover_input(
    input: &Path,
    source_roots: &[PathBuf],
    pending: &mut VecDeque<Candidate>,
) -> Result<(), Error> {
    let metadata = fs::metadata(input).map_err(|error| Error::Io {
        path: input.to_path_buf(),
        error,
    })?;
    if metadata.is_dir() {
        let root = fs::canonicalize(input).map_err(|error| Error::Io {
            path: input.to_path_buf(),
            error,
        })?;
        discover_directory(&root, &root, pending)
    } else if metadata.is_file() {
        if input
            .extension()
            .is_none_or(|extension| extension != "jibb")
        {
            return Err(Error::Invalid(format!(
                "{}: input file does not have a `.jibb` extension",
                input.display()
            )));
        }
        let file = fs::canonicalize(input).map_err(|error| Error::Io {
            path: input.to_path_buf(),
            error,
        })?;
        let logical_path = file_logical_path(&file, source_roots);
        pending.push_back(Candidate { file, logical_path });
        Ok(())
    } else {
        Err(Error::Invalid(format!(
            "{}: input is neither a file nor a directory",
            input.display()
        )))
    }
}

fn discover_directory(
    root: &Path,
    directory: &Path,
    pending: &mut VecDeque<Candidate>,
) -> Result<(), Error> {
    let entries = fs::read_dir(directory)
        .map_err(|error| Error::Io {
            path: directory.to_path_buf(),
            error,
        })?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| Error::Io {
            path: directory.to_path_buf(),
            error,
        })?;
    let mut entries = entries;
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        let file_type = entry.file_type().map_err(|error| Error::Io {
            path: entry.path(),
            error,
        })?;
        if file_type.is_dir() {
            discover_directory(root, &entry.path(), pending)?;
        } else if (file_type.is_file() || file_type.is_symlink())
            && entry
                .path()
                .extension()
                .is_some_and(|extension| extension == "jibb")
            && entry.path().is_file()
        {
            let file = fs::canonicalize(entry.path()).map_err(|error| Error::Io {
                path: entry.path(),
                error,
            })?;
            let logical_path = entry
                .path()
                .strip_prefix(root)
                .expect("discovered path remains under its input directory")
                .to_path_buf();
            pending.push_back(Candidate { file, logical_path });
        }
    }
    Ok(())
}

fn file_logical_path(file: &Path, source_roots: &[PathBuf]) -> PathBuf {
    source_root_relative(file, source_roots).unwrap_or_else(|| {
        file.file_name()
            .expect("source file has a file name")
            .into()
    })
}

fn source_root_relative(file: &Path, source_roots: &[PathBuf]) -> Option<PathBuf> {
    source_roots
        .iter()
        .filter_map(|root| {
            let root = fs::canonicalize(root).unwrap_or_else(|_| root.clone());
            file.strip_prefix(&root)
                .ok()
                .map(|relative| (root.components().count(), relative.to_path_buf()))
        })
        .max_by_key(|(depth, _)| *depth)
        .map(|(_, relative)| relative)
}

fn import_logical_path(segments: &[String]) -> PathBuf {
    let mut path = segments.iter().collect::<PathBuf>();
    path.set_extension("jibb");
    path
}

fn markdown_path(logical_path: &Path) -> PathBuf {
    let mut path = logical_path.to_path_buf();
    path.set_extension("md");
    path
}

fn module_name(logical_path: &Path) -> String {
    logical_path
        .with_extension("")
        .to_string_lossy()
        .replace('\\', "/")
}

fn markdown_label(text: &str) -> String {
    text.chars()
        .flat_map(|character| match character {
            '\\' | '[' | ']' => vec!['\\', character],
            _ => vec![character],
        })
        .collect()
}

fn markdown_destination(path: &Path) -> String {
    path.iter()
        .map(|component| {
            component
                .to_string_lossy()
                .bytes()
                .flat_map(|byte| match byte {
                    b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                        vec![(byte as char).to_string()]
                    }
                    _ => vec![format!("%{byte:02X}")],
                })
                .collect::<String>()
        })
        .collect::<Vec<_>>()
        .join("/")
}

fn render_module(
    module: &SourceModule,
    checked: &crate::check::CheckedModule,
) -> Result<String, Error> {
    let name = module_name(&module.logical_path);
    let comments = Comments::new(&module.source, &module.syntax);
    let molds = module
        .syntax
        .definitions
        .iter()
        .filter(|definition| matches!(definition.kind, DefinitionKind::Mold(_)))
        .collect::<Vec<_>>();
    let values = module
        .syntax
        .definitions
        .iter()
        .filter(|definition| matches!(definition.kind, DefinitionKind::Value(_)))
        .collect::<Vec<_>>();

    let mut markdown = format!("# {name}\n\n");
    if let Some(documentation) = &comments.module {
        markdown.push_str(documentation);
        markdown.push_str("\n\n");
    }
    markdown.push_str("## Table of contents\n\n");
    if !module.syntax.imports.is_empty() {
        markdown.push_str("- [Imports](#imports)\n");
    }
    if !molds.is_empty() {
        markdown.push_str("- [Molds](#molds)\n");
        for definition in &molds {
            markdown.push_str(&format!(
                "  - [`+$ {}`](#mold-{})\n",
                definition.name, definition.name
            ));
        }
    }
    if !values.is_empty() {
        markdown.push_str("- [Values](#values)\n");
        for definition in &values {
            markdown.push_str(&format!(
                "  - [`++ {}`](#value-{})\n",
                definition.name, definition.name
            ));
        }
    }
    if module.syntax.imports.is_empty() && molds.is_empty() && values.is_empty() {
        markdown.push_str("This module has no declarations.\n");
    }

    if !module.syntax.imports.is_empty() {
        markdown.push_str("\n## Imports\n\n");
        for import in &module.syntax.imports {
            markdown.push_str(&format!(
                "- `{}`\n",
                module.source[import.span.start..import.span.end].trim()
            ));
        }
    }
    if !molds.is_empty() {
        markdown.push_str("\n## Molds\n\n");
        for definition in molds {
            render_declaration_header(&mut markdown, "mold", definition, &comments);
            markdown.push_str("```jibb\n");
            markdown.push_str(&mold_source(&module.source, definition));
            markdown.push_str("\n```\n\n");
        }
    }
    if !values.is_empty() {
        markdown.push_str("\n## Values\n\n");
        for definition in values {
            render_declaration_header(&mut markdown, "value", definition, &comments);
            let scheme = checked.values.get(&definition.name).ok_or_else(|| {
                Error::Invalid(format!(
                    "{}: checked type for `{}` is missing",
                    module.file.display(),
                    definition.name
                ))
            })?;
            markdown.push_str("**Type**\n\n```jibb\n");
            markdown.push_str(&scheme.to_string());
            markdown.push_str("\n```\n\n");
        }
    }
    while markdown.ends_with("\n\n") {
        markdown.pop();
    }
    Ok(markdown)
}

fn mold_source(source: &str, definition: &Definition) -> String {
    let mut lines = source[definition.span.start..definition.span.end]
        .lines()
        .collect::<Vec<_>>();
    while lines.last().is_some_and(|line| {
        line.trim().is_empty() || line.strip_suffix('\r').unwrap_or(line).starts_with("::")
    }) {
        lines.pop();
    }
    lines.join("\n")
}

fn render_declaration_header(
    markdown: &mut String,
    kind: &str,
    definition: &Definition,
    comments: &Comments,
) {
    let rune = if kind == "mold" { "+$" } else { "++" };
    markdown.push_str(&format!(
        "<a id=\"{kind}-{}\"></a>\n### `{rune} {}`\n\n",
        definition.name, definition.name
    ));
    if let Some(documentation) = comments.declarations.get(&definition.span.start) {
        markdown.push_str(documentation);
        markdown.push_str("\n\n");
    }
}

struct CommentBlock {
    end_row: usize,
    text: String,
}

struct Comments {
    module: Option<String>,
    declarations: BTreeMap<usize, String>,
}

impl Comments {
    fn new(source: &str, module: &Module) -> Self {
        let line_starts = line_starts(source);
        let blocks = comment_blocks(source);
        let mut declarations = BTreeMap::new();
        let mut declaration_blocks = BTreeMap::new();
        for definition in &module.definitions {
            let row = line_at(&line_starts, definition.span.start);
            if let Some((index, block)) = blocks
                .iter()
                .enumerate()
                .find(|(_, block)| block.end_row + 1 == row)
            {
                declarations.insert(definition.span.start, block.text.clone());
                declaration_blocks.insert(index, definition.span.start);
            }
        }

        let first_syntax = module
            .imports
            .iter()
            .map(|import| import.span.start)
            .chain(
                module
                    .definitions
                    .iter()
                    .map(|definition| definition.span.start),
            )
            .min()
            .map(|byte| line_at(&line_starts, byte));
        let documentation = blocks
            .iter()
            .enumerate()
            .filter(|(index, block)| {
                first_syntax.is_none_or(|first_row| block.end_row < first_row)
                    && !declaration_blocks.contains_key(index)
            })
            .map(|(_, block)| block.text.as_str())
            .collect::<Vec<_>>()
            .join("\n\n");
        let module = (!documentation.is_empty()).then_some(documentation);
        Self {
            module,
            declarations,
        }
    }
}

fn line_starts(source: &str) -> Vec<usize> {
    let mut starts = vec![0];
    starts.extend(
        source
            .bytes()
            .enumerate()
            .filter(|(_, byte)| *byte == b'\n')
            .map(|(index, _)| index + 1),
    );
    starts
}

fn line_at(starts: &[usize], byte: usize) -> usize {
    starts.partition_point(|start| *start <= byte) - 1
}

fn comment_blocks(source: &str) -> Vec<CommentBlock> {
    let mut blocks = Vec::new();
    let mut current: Option<CommentBlock> = None;
    for (row, line) in source.lines().enumerate() {
        let line = line.strip_suffix('\r').unwrap_or(line);
        if let Some(comment) = line.strip_prefix("::") {
            let text = comment
                .strip_prefix("  ")
                .or_else(|| comment.strip_prefix(' '))
                .unwrap_or(comment);
            if text.is_empty() {
                if let Some(block) = current.take() {
                    blocks.push(block);
                }
            } else if let Some(block) = &mut current {
                block.end_row = row;
                block.text.push('\n');
                block.text.push_str(text);
            } else {
                current = Some(CommentBlock {
                    end_row: row,
                    text: text.to_string(),
                });
            }
        } else if let Some(block) = current.take() {
            blocks.push(block);
        }
    }
    if let Some(block) = current {
        blocks.push(block);
    }
    blocks
}
