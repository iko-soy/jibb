use crate::{
    Diagnostic,
    ast::{
        Definition, DefinitionKind, Expr, ExprKind, ImportKind, Module, Mold, MoldKind, Sample,
        SampleKind,
    },
    evaluate, parse_ast,
    value::Value,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::{Path, PathBuf},
};

pub fn evaluate_path(
    file: &Path,
    entry: &str,
    source_roots: &[PathBuf],
    prelude: Option<&Path>,
) -> Result<Value, Diagnostic> {
    let mut loader = Loader {
        source_roots,
        prelude,
        loading: Vec::new(),
        cache: BTreeMap::new(),
    };
    let module = loader.load_with_prelude(file)?;
    evaluate(&module, entry)
}

struct Loader<'a> {
    source_roots: &'a [PathBuf],
    prelude: Option<&'a Path>,
    loading: Vec<PathBuf>,
    cache: BTreeMap<PathBuf, Module>,
}

impl Loader<'_> {
    fn load_with_prelude(&mut self, file: &Path) -> Result<Module, Diagnostic> {
        let mut module = self.load(file)?;
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
        if self.loading.contains(&key) {
            return Err(Diagnostic::new(format!(
                "module import cycle at {}",
                key.display()
            )));
        }
        let source = fs::read_to_string(&key).map_err(|error| {
            Diagnostic::new(format!("{}: failed to read: {error}", key.display()))
        })?;
        let mut module = parse_ast(&source)?;
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
                let ImportKind::Module { name, path } = &import.kind else {
                    return Err(Diagnostic::at(
                        "only `/=` module imports are supported",
                        import.span,
                    ));
                };
                if own_names.contains(name) || !faces.insert(name.clone()) {
                    return Err(Diagnostic::at(
                        format!("import face `{name}` shadows a name"),
                        import.span,
                    ));
                }
                if path
                    == &[
                        "lib".to_string(),
                        "jibb".to_string(),
                        "primitives".to_string(),
                    ]
                {
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
        if segments.is_empty() {
            return Err(Diagnostic::new("empty module import path"));
        }
        let relative = segments.join("/");
        let relative = format!("{relative}.jibb");
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
            "cannot resolve module import /{} from {}",
            segments.join("/"),
            importing.display()
        )))
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
