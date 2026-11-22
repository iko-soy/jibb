use crate::{
    Diagnostic, SourceLanguage,
    ast::{
        Definition, DefinitionKind, Expr, ExprKind, ImportKind, Module, Mold, MoldKind, Sample,
        SampleKind, SourceId, Span,
    },
    check::{self, CheckedModule},
    evaluate,
    native::NativeFunction,
    parse_ast,
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

pub fn evaluate_source(
    source: &str,
    file: &Path,
    entry: &str,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> Result<Value, Diagnostic> {
    let mut loader = Loader::new(source_roots, prelude);
    let module = loader.load_source_with_prelude(source, file)?;
    evaluate(&module, entry)
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

/// The mold the private `raw-seal` primitive produces. It is not reachable
/// from source, so it keeps one name whatever face imports the primitives.
pub(crate) const PRIMITIVE_OPAQUE: &str = "primitives__opaque";

/// The source id of the molds the loader itself supplies.
const NATIVE_SOURCE: SourceId = SourceId(u64::MAX);

/// Checks that each segment of an import path names a file or directory under
/// a source root: `.` and `..` would leave it.
fn check_segments(segments: &[String], span: Span) -> Result<(), Diagnostic> {
    if segments.is_empty() {
        return Err(Diagnostic::at("empty module import path", span));
    }
    for segment in segments {
        if segment.is_empty() || segment == "." || segment == ".." || segment.contains(['/', '\\'])
        {
            return Err(Diagnostic::at(
                format!("import path segment `{segment}` does not name a module"),
                span,
            ));
        }
    }
    Ok(())
}

pub fn resolve_module_path(
    segments: &[String],
    importing: &Path,
    source_roots: &[PathBuf],
) -> Result<PathBuf, Diagnostic> {
    check_segments(segments, Span::default())?;
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
    /// The next source id; each loaded file gets its own, so the checker can
    /// tell which file a definition came from.
    next_source: u64,
}

impl<'a> Loader<'a> {
    fn new(source_roots: &'a [PathBuf], prelude: Option<&'a Path>) -> Self {
        Self {
            source_roots,
            prelude,
            loading: Vec::new(),
            cache: BTreeMap::new(),
            hoon_cache: BTreeMap::new(),
            next_source: 0,
        }
    }

    fn parse(&mut self, source: &str, key: &Path) -> Result<Module, Diagnostic> {
        let mut module = SourceLanguage::from_path(key)?.parse_ast(source)?;
        module.set_source(SourceId(self.next_source));
        self.next_source += 1;
        Ok(module)
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
            let mut prelude = self.load(prelude)?;
            for definition in &mut prelude.definitions {
                rewrite_definition(definition, "hoon", &BTreeMap::new());
            }
            let existing_molds = module
                .definitions
                .iter()
                .chain(&prelude.definitions)
                .filter(|definition| matches!(&definition.kind, DefinitionKind::Mold(_)))
                .map(|definition| definition.name.as_str())
                .collect::<BTreeSet<_>>();
            let native = [native_hoon_molds(), primitive_opaque()]
                .concat()
                .into_iter()
                .filter(|definition| !existing_molds.contains(definition.name.as_str()))
                .collect::<Vec<_>>();
            module.definitions = [native, prelude.definitions, module.definitions].concat();
        }
        Ok(module)
    }

    /// Loads a file. Its language comes from the name it was given, so a
    /// link is read as the file it names, not as its target's extension.
    fn load(&mut self, file: &Path) -> Result<Module, Diagnostic> {
        SourceLanguage::from_path(file)?;
        let key = fs::canonicalize(file).unwrap_or_else(|_| file.to_path_buf());
        if let Some(module) = self.cache.get(&key) {
            return Ok(module.clone());
        }
        let source = fs::read_to_string(&key).map_err(|error| {
            Diagnostic::new(format!("{}: failed to read: {error}", key.display()))
        })?;
        let module = self.parse(&source, file)?;
        self.link(module, key)
    }

    fn load_source(&mut self, source: &str, file: &Path) -> Result<Module, Diagnostic> {
        let key = fs::canonicalize(file).unwrap_or_else(|_| file.to_path_buf());
        let module = self.parse(source, file)?;
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
            let mut primitives_linked = false;
            let mut hoon_linked = false;
            let mut faces = BTreeSet::new();
            let own_names = module
                .definitions
                .iter()
                .map(|definition| definition.name.clone())
                .collect::<BTreeSet<_>>();
            let own_molds = module
                .definitions
                .iter()
                .filter(|definition| matches!(&definition.kind, DefinitionKind::Mold(_)))
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
                        hoon_linked = true;
                        linked.extend(definitions);
                        for definition in &mut module.definitions {
                            rewrite_definition(definition, name, &BTreeMap::new());
                        }
                    }
                    ImportKind::Mark { mark } => {
                        if own_molds.contains(mark.strip_prefix('%').unwrap_or(mark)) {
                            return Err(Diagnostic::at(
                                format!("mark type `{mark}` shadows a name"),
                                import.span,
                            ));
                        }
                        hoon_linked = true;
                        linked.extend(self.load_hoon_mark(mark, &key)?);
                    }
                    ImportKind::Module { name, path } => {
                        if own_names.contains(name) || !faces.insert(name.clone()) {
                            return Err(Diagnostic::at(
                                format!("import face `{name}` shadows a name"),
                                import.span,
                            ));
                        }
                        check_segments(path, import.span)?;
                        if is_primitive_module_path(path) {
                            linked.extend(primitive_definitions(name));
                            if !primitives_linked {
                                linked.extend(native_hoon_molds());
                                linked.extend(primitive_opaque());
                                primitives_linked = true;
                            }
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
            if hoon_linked {
                linked.extend(native_hoon_molds());
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
        check_segments(segments, Span::default())?;
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
            let mut module = crate::hoon::read_sur(&source, name, Span::default())?;
            resolve_standard_mold_references(&mut module.definitions);
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
            let mut module = crate::hoon::read_mark(&source, mark_name, Span::default())?;
            resolve_standard_mold_references(&mut module.definitions);
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

/// The private primitive interface, linked under the face that imports it:
/// each primitive is a value of that face, as `raw-add.core`, and the
/// interface's molds are `list.core`, `unit.core` and `opaque.core`.
fn primitive_definitions(face: &str) -> Vec<Definition> {
    let mut definitions = native_molds(face);
    definitions.extend(NativeFunction::ALL.iter().map(|native| {
        let span = Span::new(NATIVE_SOURCE, 0, 0);
        Definition {
            name: format!("{face}__{}", native.field()),
            kind: DefinitionKind::Value(Expr {
                kind: ExprKind::Native(*native),
                span,
            }),
            span,
        }
    }));
    definitions
}

fn native_molds(face: &str) -> Vec<Definition> {
    let mut module = parse_ast(
        "+$ list |$ [A]\n  ~\n  [i=A t=(list A)]\n+$ unit |$ [A]\n  ~\n  [~ u=A]\n+$ opaque |$ [A] (opaque.primitives A)\n",
    )
    .expect("native mold source parses");
    module.set_source(NATIVE_SOURCE);
    for definition in &mut module.definitions {
        rewrite_definition(definition, "primitives", &BTreeMap::new());
    }
    prefix_definitions(&module.definitions, face)
}

fn primitive_opaque() -> Vec<Definition> {
    let mut module = parse_ast("+$ opaque |$ [A] A\n").expect("native mold source parses");
    module.set_source(NATIVE_SOURCE);
    prefix_definitions(&module.definitions, "primitives")
}

fn native_hoon_molds() -> Vec<Definition> {
    native_source(
        concat!(
            "+$ map |$ [K V] (tree [p=K q=V])\n",
            "+$ tree |$ [A]\n  ~\n  [n=A l=(tree A) r=(tree A)]\n",
            "+$ step @ud\n",
            "+$ list |$ [A]\n  ~\n  [i=A t=(list A)]\n",
            "+$ each |$ [A B]\n  [%& p=A]\n  [%| p=B]\n",
            "+$ json\n",
            "  ~\n",
            "  [%a p=(list json)]\n",
            "  [%b p=?]\n",
            "  [%n p=@ta]\n",
            "  [%o p=(map @t json)]\n",
            "  [%s p=@t]\n",
        ),
        "hoon",
    )
}

/// Resolves unqualified Hoon references against the same native standard
/// catalog that is linked with the import. `read_sur` has already rewritten
/// local references, so a local mold shadows its standard namesake here.
fn resolve_standard_mold_references(definitions: &mut [Definition]) {
    let renames = native_hoon_molds()
        .into_iter()
        .filter_map(|definition| {
            let name = definition.name.strip_prefix("hoon__")?.to_string();
            Some((name, definition.name))
        })
        .collect();
    for definition in definitions {
        rewrite_definition_for_hoon(definition, &renames);
    }
}

fn native_source(source: &str, face: &str) -> Vec<Definition> {
    let mut module = parse_ast(source).expect("native mold source parses");
    module.set_source(NATIVE_SOURCE);
    prefix_definitions(&module.definitions, face)
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
        ExprKind::Literal(_)
        | ExprKind::Path(_)
        | ExprKind::Constructor(_)
        | ExprKind::Crash
        | ExprKind::Native(_) => {}
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

/// Rewrites a wing through an import face: `x.face` and the wing `a.b.x.face`
/// read definition `x` of the imported module, then its fields.
fn rewrite_wing(names: &mut Vec<String>, face: &str, renames: &BTreeMap<String, String>) {
    if names.len() >= 2 && names.last().is_some_and(|name| name == face) {
        names.pop();
        let definition = names
            .pop()
            .expect("a wing through a face names a definition");
        names.push(format!("{face}__{definition}"));
    } else if let Some(last) = names.last_mut()
        && let Some(rename) = renames.get(last)
    {
        *last = rename.clone();
    }
}
