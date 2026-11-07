use crate::{
    Diagnostic,
    ast::{
        Definition, DefinitionKind, Expr, ExprKind, ImportKind, Module, Mold, MoldKind, Sample,
        SampleKind, Span,
    },
    check::{self, CheckedModule},
    evaluate, parse_ast,
    value::Value,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::{Path, PathBuf},
};

pub fn check_path(
    file: &Path,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> Result<CheckedModule, Diagnostic> {
    let module = load_path(file, source_roots, prelude)?;
    check::check(&module)
}

pub fn check_source(
    source: &str,
    file: &Path,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> Result<CheckedModule, Diagnostic> {
    let mut loader = Loader::new(source_roots, prelude);
    let module = loader.load_source_with_prelude(source, file)?;
    check::check(&module)
}

pub fn evaluate_path(
    file: &Path,
    entry: &str,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> Result<Value, Diagnostic> {
    let module = load_path(file, source_roots, prelude)?;
    evaluate(&module, entry)
}

fn load_path(
    file: &Path,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> Result<Module, Diagnostic> {
    Loader::new(source_roots, prelude).load_with_prelude(file)
}

pub fn is_primitive_module_path(segments: &[String]) -> bool {
    segments == ["lib", "jibb", "primitives"]
}

pub fn resolve_module_path(
    segments: &[String],
    importing: &Path,
    source_roots: &[PathBuf],
) -> Result<PathBuf, Diagnostic> {
    if segments.is_empty() {
        return Err(Diagnostic::new("empty module import path"));
    }
    let relative = format!("{}.jibb", segments.join("/"));
    for root in source_roots {
        let candidate = root.join(&relative);
        if candidate.is_file() {
            return Ok(candidate);
        }
    }
    let parent = importing.parent().unwrap_or_else(|| Path::new("."));
    let candidate = parent.join(relative);
    if candidate.is_file() {
        return Ok(candidate);
    }
    Err(Diagnostic::new(format!(
        "cannot resolve module import /{} from {} (roots: {:?})",
        segments.join("/"),
        importing.display(),
        source_roots
    )))
}

struct Loader<'a> {
    source_roots: &'a [PathBuf],
    prelude: Option<&'a Path>,
    loading: Vec<PathBuf>,
    cache: BTreeMap<PathBuf, Module>,
    hoon_cache: BTreeMap<PathBuf, Vec<Definition>>,
}

impl<'a> Loader<'a> {
    fn new(source_roots: &'a [PathBuf], prelude: Option<&'a Path>) -> Self {
        Self {
            source_roots,
            prelude,
            loading: Vec::new(),
            cache: BTreeMap::new(),
            hoon_cache: BTreeMap::new(),
        }
    }

    fn load_with_prelude(&mut self, file: &Path) -> Result<Module, Diagnostic> {
        let module = self.load(file)?;
        self.with_prelude(module)
    }

    fn load_source_with_prelude(
        &mut self,
        source: &str,
        file: &Path,
    ) -> Result<Module, Diagnostic> {
        let module = self.load_source(source, file)?;
        self.with_prelude(module)
    }

    fn with_prelude(&mut self, mut module: Module) -> Result<Module, Diagnostic> {
        if let Some(prelude) = self.prelude {
            let prelude = self.load(prelude)?;
            module.definitions = [prelude.definitions, module.definitions].concat();
        }
        Ok(module)
    }

    fn load(&mut self, file: &Path) -> Result<Module, Diagnostic> {
        let key = fs::canonicalize(file).unwrap_or_else(|_| file.to_path_buf());
        if let Some(module) = self.cache.get(&key) {
            return Ok(module.clone());
        }
        let source = fs::read_to_string(&key).map_err(|error| {
            Diagnostic::new(format!("{}: failed to read: {error}", key.display()))
        })?;
        let module = parse_ast(&source)?;
        self.link(module, key)
    }

    fn load_source(&mut self, source: &str, file: &Path) -> Result<Module, Diagnostic> {
        let key = fs::canonicalize(file).unwrap_or_else(|_| file.to_path_buf());
        let module = parse_ast(source)?;
        self.link(module, key)
    }

    fn link(&mut self, mut module: Module, key: PathBuf) -> Result<Module, Diagnostic> {
        if let Some(module) = self.cache.get(&key) {
            return Ok(module.clone());
        }
        if self.loading.contains(&key) {
            return Err(Diagnostic::new(format!(
                "module import cycle at {}",
                key.display()
            )));
        }
        self.loading.push(key.clone());
        let result = (|| {
            let mut linked = Vec::new();
            let mut faces = BTreeSet::new();
            let own_names = module
                .definitions
                .iter()
                .map(|definition| definition.name.clone())
                .collect::<BTreeSet<_>>();
            for import in &module.imports {
                match &import.kind {
                    ImportKind::Library { name } => {
                        if own_names.contains(name) || !faces.insert(name.clone()) {
                            return Err(Diagnostic::at(
                                format!("import face `{name}` shadows a name"),
                                import.span,
                            ));
                        }
                        let definitions = self.load_hoon_library(name, &key)?;
                        linked.extend(definitions);
                        for definition in &mut module.definitions {
                            rewrite_definition(definition, name, &BTreeMap::new());
                        }
                    }
                    ImportKind::Mark { mark } => {
                        if own_names.contains(mark) {
                            return Err(Diagnostic::at(
                                format!("mark type `{mark}` shadows a name"),
                                import.span,
                            ));
                        }
                        linked.extend(self.load_hoon_mark(mark, &key)?);
                    }
                    ImportKind::Module { name, path } => {
                        if own_names.contains(name) || !faces.insert(name.clone()) {
                            return Err(Diagnostic::at(
                                format!("import face `{name}` shadows a name"),
                                import.span,
                            ));
                        }
                        if is_primitive_module_path(path) {
                            linked.extend(native_molds());
                            for definition in &mut module.definitions {
                                rewrite_definition(definition, name, &BTreeMap::new());
                            }
                            continue;
                        }
                        let imported_path = self.resolve(path, &key)?;
                        let imported = self.load(&imported_path)?;
                        linked.extend(prefix_definitions(&imported.definitions, name));
                        for definition in &mut module.definitions {
                            rewrite_definition(definition, name, &BTreeMap::new());
                        }
                    }
                }
            }
            for definition in &mut module.definitions {
                rewrite_definition(definition, "", &BTreeMap::new());
            }
            let definitions = std::mem::take(&mut module.definitions);
            module.definitions = [linked, definitions].concat();
            module.imports.clear();
            Ok(())
        })();
        self.loading.pop();
        if result.is_ok() {
            self.cache.insert(key, module.clone());
        }
        result?;
        Ok(module)
    }

    fn resolve(&self, segments: &[String], importing: &Path) -> Result<PathBuf, Diagnostic> {
        resolve_module_path(segments, importing, self.source_roots)
    }
    fn resolve_hoon(&self, segments: &[String], importing: &Path) -> Result<PathBuf, Diagnostic> {
        if segments.is_empty() {
            return Err(Diagnostic::new("empty Hoon import path"));
        }
        let relative = format!("{}.hoon", segments.join("/"));
        for root in self.source_roots {
            let candidate = root.join(&relative);
            if candidate.is_file() {
                return Ok(candidate);
            }
        }
        let parent = importing.parent().unwrap_or_else(|| Path::new("."));
        let candidate = parent.join(relative);
        if candidate.is_file() {
            return Ok(candidate);
        }
        Err(Diagnostic::new(format!(
            "cannot resolve Hoon import /{} from {}",
            segments.join("/"),
            importing.display()
        )))
    }

    fn load_hoon_library(
        &mut self,
        name: &str,
        importing: &Path,
    ) -> Result<Vec<Definition>, Diagnostic> {
        let path = self.resolve_hoon(&["sur".to_string(), name.to_string()], importing)?;
        if let Some(definitions) = self.hoon_cache.get(&path) {
            return Ok(definitions.clone());
        }
        if self.loading.contains(&path) {
            return Err(Diagnostic::new(format!(
                "Hoon import cycle at {}",
                path.display()
            )));
        }
        let source = fs::read_to_string(&path).map_err(|error| {
            Diagnostic::new(format!("{}: failed to read: {error}", path.display()))
        })?;
        self.loading.push(path.clone());
        let result = (|| {
            let module = crate::hoon::read_sur(&source, name, Span::default())?;
            let mut definitions = Vec::new();
            for import in &module.imports {
                definitions.extend(self.load_hoon_library(import, &path)?);
            }
            definitions.extend(module.definitions);
            Ok(definitions)
        })();
        self.loading.pop();
        if let Ok(ref definitions) = result {
            self.hoon_cache.insert(path, definitions.clone());
        }
        result
    }

    fn load_hoon_mark(
        &mut self,
        mark: &str,
        importing: &Path,
    ) -> Result<Vec<Definition>, Diagnostic> {
        let mark_name = mark.strip_prefix('%').unwrap_or(mark);
        let path = self.resolve_hoon(&["mar".to_string(), mark_name.to_string()], importing)?;
        if self.loading.contains(&path) {
            return Err(Diagnostic::new(format!(
                "Hoon mark import cycle at {}",
                path.display()
            )));
        }
        let source = fs::read_to_string(&path).map_err(|error| {
            Diagnostic::new(format!("{}: failed to read: {error}", path.display()))
        })?;
        self.loading.push(path.clone());
        let result = (|| {
            let module = crate::hoon::read_mark(&source, mark_name, Span::default())?;
            let mut definitions = Vec::new();
            for import in &module.imports {
                definitions.extend(self.load_hoon_library(import, &path)?);
            }
            definitions.extend(module.definitions);
            Ok(definitions)
        })();
        self.loading.pop();
        result
    }
}

fn native_molds() -> Vec<Definition> {
    let source = "+$ list |$ [A]\n  ~\n  [i=A t=(list A)]\n+$ unit |$ [A]\n  ~\n  [~ u=A]\n";
    let definitions = parse_ast(source)
        .expect("native mold source parses")
        .definitions;
    prefix_definitions(&definitions, "core")
}

fn prefix_definitions(definitions: &[Definition], face: &str) -> Vec<Definition> {
    let renames = definitions
        .iter()
        .map(|definition| {
            (
                definition.name.clone(),
                format!("{face}__{}", definition.name),
            )
        })
        .collect::<BTreeMap<_, _>>();
    definitions
        .iter()
        .cloned()
        .map(|mut definition| {
            definition.name = renames[&definition.name].clone();
            rewrite_definition(&mut definition, face, &renames);
            definition
        })
        .collect()
}

pub(crate) fn rewrite_definition_for_hoon(
    definition: &mut Definition,
    renames: &BTreeMap<String, String>,
) {
    rewrite_definition(definition, "", renames);
}

fn rewrite_definition(definition: &mut Definition, face: &str, renames: &BTreeMap<String, String>) {
    match &mut definition.kind {
        DefinitionKind::Value(expression) => rewrite_expr(expression, face, renames),
        DefinitionKind::Mold(mold) => {
            for case in &mut mold.cases {
                rewrite_mold(case, face, renames);
            }
        }
    }
}

fn rewrite_expr(expression: &mut Expr, face: &str, renames: &BTreeMap<String, String>) {
    match &mut expression.kind {
        ExprKind::Reference(names) => rewrite_wing(names, face, renames),
        ExprKind::String(parts) => {
            for part in parts {
                if let crate::ast::StringPart::Expr(expression) = part {
                    rewrite_expr(expression, face, renames);
                }
            }
        }
        ExprKind::ApplicationPath(segments) => {
            for segment in segments {
                if let crate::ast::ApplicationSegment::Expr(expression) = segment {
                    rewrite_expr(expression, face, renames);
                }
            }
        }
        ExprKind::Call { head, arguments } => {
            rewrite_expr(head, face, renames);
            for argument in arguments {
                rewrite_expr(argument, face, renames);
            }
        }
        ExprKind::Gate { sample, body } => {
            rewrite_sample(sample, face, renames);
            rewrite_expr(body, face, renames);
        }
        ExprKind::Cast { mold, value } => {
            rewrite_mold(mold, face, renames);
            rewrite_expr(value, face, renames);
        }
        ExprKind::Trace { value, body } => {
            rewrite_expr(value, face, renames);
            rewrite_expr(body, face, renames);
        }
        ExprKind::Branch { subject, arms } => {
            rewrite_expr(subject, face, renames);
            for arm in arms {
                rewrite_expr(&mut arm.body, face, renames);
            }
        }
        ExprKind::Body {
            definitions,
            result,
        } => {
            for definition in definitions {
                rewrite_definition(definition, face, renames);
            }
            rewrite_expr(result, face, renames);
        }
        ExprKind::List(items) => {
            for item in items {
                rewrite_expr(item, face, renames);
            }
        }
        ExprKind::Tuple(items) => {
            for item in items {
                rewrite_expr(&mut item.value, face, renames);
            }
        }
        ExprKind::Change { target, edits } => {
            rewrite_wing(target, face, renames);
            for edit in edits {
                rewrite_expr(&mut edit.value, face, renames);
            }
        }
        ExprKind::Pair { value, .. } | ExprKind::Unit(value) => {
            rewrite_expr(value, face, renames);
        }
        ExprKind::Literal(_) | ExprKind::Path(_) | ExprKind::Constructor(_) | ExprKind::Crash => {}
    }
}

fn rewrite_sample(sample: &mut Sample, face: &str, renames: &BTreeMap<String, String>) {
    match &mut sample.kind {
        SampleKind::Binding(_) | SampleKind::Pun(_) => {}
        SampleKind::Face { mold, .. } | SampleKind::Mold(mold) => {
            rewrite_mold(mold, face, renames);
        }
        SampleKind::Cell(samples) => {
            for sample in samples {
                rewrite_sample(sample, face, renames);
            }
        }
    }
}

fn rewrite_mold(mold: &mut Mold, face: &str, renames: &BTreeMap<String, String>) {
    match &mut mold.kind {
        MoldKind::Reference(names) => rewrite_wing(names, face, renames),
        MoldKind::Apply {
            constructor,
            arguments,
        } => {
            rewrite_wing(constructor, face, renames);
            for argument in arguments {
                rewrite_mold(argument, face, renames);
            }
        }
        MoldKind::Cell(fields) => {
            for field in fields {
                rewrite_mold(&mut field.mold, face, renames);
            }
        }
        MoldKind::Union(cases) => {
            for case in cases {
                rewrite_mold(case, face, renames);
            }
        }
        MoldKind::Function { sample, product } => {
            rewrite_mold(sample, face, renames);
            rewrite_mold(product, face, renames);
        }
        MoldKind::Aura(_)
        | MoldKind::Hole
        | MoldKind::Noun
        | MoldKind::Void
        | MoldKind::Flag
        | MoldKind::Null
        | MoldKind::Term(_)
        | MoldKind::Loobean(_)
        | MoldKind::TypeVariable(_)
        | MoldKind::Path(_) => {}
    }
}

fn rewrite_wing(names: &mut Vec<String>, face: &str, renames: &BTreeMap<String, String>) {
    if names.len() == 2
        && names
            .last()
            .is_some_and(|name| name == "core" && names[0].starts_with("raw-"))
    {
        return;
    }
    if names.len() == 2 && names.last().is_some_and(|name| name == face) {
        *names = vec![format!("{face}__{}", names[0])];
    } else if names.len() == 1
        && let Some(rename) = renames.get(&names[0])
    {
        *names = vec![rename.clone()];
    }
}
