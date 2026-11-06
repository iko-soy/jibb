use std::collections::HashSet;

use tree_sitter::Node;

use crate::parse;

const WIDTH: usize = 80;
const INDENT: usize = 2;

type FResult<T> = Result<T, String>;

#[derive(Clone, Debug)]
struct Doc {
    lines: Vec<String>,
}

impl Doc {
    fn line(column: usize, text: impl Into<String>) -> Self {
        Self {
            lines: vec![format!("{}{}", " ".repeat(column), text.into())],
        }
    }

    fn empty() -> Self {
        Self { lines: Vec::new() }
    }

    fn append(&mut self, mut other: Self) {
        self.lines.append(&mut other.lines);
    }
}

struct Module<'tree> {
    node: Node<'tree>,
    entries: Vec<Entry<'tree>>,
}

enum Entry<'tree> {
    Import(Import<'tree>),
    Definition(Definition<'tree>),
}

impl<'tree> Entry<'tree> {
    fn node(&self) -> Node<'tree> {
        match self {
            Self::Import(import) => import.node,
            Self::Definition(definition) => definition.node,
        }
    }
}

struct Import<'tree> {
    node: Node<'tree>,
}

struct Definition<'tree> {
    node: Node<'tree>,
    scope: Node<'tree>,
    kind: DefinitionKind<'tree>,
}

enum DefinitionKind<'tree> {
    Value {
        name: String,
        body: Body<'tree>,
    },
    Mold {
        name: String,
        generic: Option<Mold<'tree>>,
        molds: Vec<Mold<'tree>>,
    },
}

struct Body<'tree> {
    owner: Node<'tree>,
    definitions: Vec<Definition<'tree>>,
    last: Box<Expr<'tree>>,
}

struct Arm<'tree> {
    node: Node<'tree>,
    pattern: Pattern<'tree>,
    body: Body<'tree>,
}

struct Expr<'tree> {
    node: Node<'tree>,
    kind: ExprKind<'tree>,
}

enum ExprKind<'tree> {
    Atom(String),
    Call(Vec<Expr<'tree>>),
    Group(Box<Expr<'tree>>),
    List(Vec<Expr<'tree>>),
    Tuple(Vec<ValueItem<'tree>>),
    Change {
        target: String,
        edits: Vec<ValueItem<'tree>>,
    },
    Pair {
        tag: String,
        value: Box<Expr<'tree>>,
    },
    Unit(Box<Expr<'tree>>),
    Gate {
        sample: Mold<'tree>,
        body: Box<Body<'tree>>,
    },
    WideGate {
        sample: Mold<'tree>,
        body: Box<Expr<'tree>>,
    },
    Cast {
        mold: Mold<'tree>,
        body: Box<Body<'tree>>,
    },
    Trace {
        value: Box<Expr<'tree>>,
        body: Box<Body<'tree>>,
    },
    Branch {
        subject: Box<Expr<'tree>>,
        arms: Vec<Arm<'tree>>,
        rest: bool,
    },
    RestHead {
        heads: Vec<Head<'tree>>,
        body: Box<Body<'tree>>,
    },
    String(Vec<StringPart<'tree>>),
    ApplicationPath(Vec<PathPart<'tree>>),
}

enum Head<'tree> {
    Gate(Mold<'tree>),
    Cast(Mold<'tree>),
    Trace(Expr<'tree>),
}

enum StringPart<'tree> {
    Text(String),
    Expr(Expr<'tree>),
}

enum PathPart<'tree> {
    Text(String),
    Expr(Expr<'tree>),
}

struct ValueItem<'tree> {
    node: Node<'tree>,
    face: Option<String>,
    value: Expr<'tree>,
}

struct Mold<'tree> {
    node: Node<'tree>,
    kind: MoldKind<'tree>,
}

enum MoldKind<'tree> {
    Atom(String),
    Face {
        name: String,
        mold: Box<Mold<'tree>>,
    },
    Pun(String),
    Cell {
        fields: Vec<Mold<'tree>>,
        breakable: bool,
    },
    Apply {
        constructor: String,
        arguments: Vec<Mold<'tree>>,
    },
    Function {
        sample: Box<Mold<'tree>>,
        product: Box<Mold<'tree>>,
    },
    Generic(Vec<String>),
}

struct Pattern<'tree> {
    node: Node<'tree>,
    kind: PatternKind<'tree>,
}

enum PatternKind<'tree> {
    Atom(String),
    Cell(Vec<Pattern<'tree>>),
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Position {
    Body,
    Operand,
}

struct Builder<'a> {
    source: &'a str,
}

impl<'a> Builder<'a> {
    fn text(&self, node: Node<'_>) -> String {
        self.source[node.byte_range()].to_string()
    }

    fn module(&self, root: Node<'a>) -> FResult<Module<'a>> {
        let mut entries = Vec::new();
        for child in named(root) {
            match child.kind() {
                "import" => entries.push(Entry::Import(Import { node: child })),
                "definition" => entries.push(Entry::Definition(self.definition(child)?)),
                "comment" | "trailing_comment" => {}
                kind => return Err(format!("formatter: unsupported module node {kind}")),
            }
        }
        Ok(Module {
            node: root,
            entries,
        })
    }

    fn definition(&self, node: Node<'a>) -> FResult<Definition<'a>> {
        let scope = if node.kind() == "definition" {
            named(node)
                .into_iter()
                .find(|child| !is_comment(*child))
                .ok_or_else(|| "formatter: empty definition".to_string())?
        } else {
            node
        };
        match scope.kind() {
            "value_definition" => {
                let name = required_field(scope, "name")?;
                Ok(Definition {
                    node,
                    scope,
                    kind: DefinitionKind::Value {
                        name: self.text(name),
                        body: self.body(scope, "value")?,
                    },
                })
            }
            "mold_definition" => {
                let name = self.text(required_field(scope, "name")?);
                let generic = scope
                    .child_by_field_name("generic")
                    .map(|node| self.mold(node))
                    .transpose()?;
                let mut molds = Vec::new();
                for child in named(scope) {
                    if is_comment(child) || child.kind() == "name" || child.kind() == "generic" {
                        continue;
                    }
                    molds.push(self.mold(child)?);
                }
                if molds.is_empty() {
                    return Err("formatter: mold definition without a mold".to_string());
                }
                Ok(Definition {
                    node,
                    scope,
                    kind: DefinitionKind::Mold {
                        name,
                        generic,
                        molds,
                    },
                })
            }
            kind => Err(format!("formatter: unsupported definition {kind}")),
        }
    }

    fn body(&self, owner: Node<'a>, field: &str) -> FResult<Body<'a>> {
        let last = fields(owner, field)
            .into_iter()
            .last()
            .ok_or_else(|| format!("formatter: {} has no {field} body", owner.kind()))?;
        let mut definitions = Vec::new();
        for child in named(owner) {
            if child.kind() == "definition" {
                definitions.push(self.definition(child)?);
            }
        }
        Ok(Body {
            owner,
            definitions,
            last: Box::new(self.expr(last)?),
        })
    }

    fn expr(&self, node: Node<'a>) -> FResult<Expr<'a>> {
        let kind = match node.kind() {
            "call" => ExprKind::Call(
                named(node)
                    .into_iter()
                    .filter(|child| !is_comment(*child))
                    .map(|child| self.expr(child))
                    .collect::<FResult<Vec<_>>>()?,
            ),
            "group" | "open_rune_group" => {
                ExprKind::Group(Box::new(self.expr(only_syntax_child(node)?)?))
            }
            "open_group" => {
                let children = syntax_children(node);
                if children.len() == 1 {
                    ExprKind::Group(Box::new(self.expr(children[0])?))
                } else {
                    ExprKind::Call(
                        children
                            .into_iter()
                            .map(|child| self.expr(child))
                            .collect::<FResult<Vec<_>>>()?,
                    )
                }
            }
            "list" | "open_list" => ExprKind::List(
                syntax_children(node)
                    .into_iter()
                    .map(|child| self.expr(child))
                    .collect::<FResult<Vec<_>>>()?,
            ),
            "tuple" | "open_tuple" => ExprKind::Tuple(self.value_items(node, false)?),
            "change" | "open_change" => {
                let target = self.text(required_field(node, "target")?);
                ExprKind::Change {
                    target,
                    edits: self.value_items(node, true)?,
                }
            }
            "pair" => ExprKind::Pair {
                tag: self.text(required_field(node, "tag")?),
                value: Box::new(self.expr(required_field(node, "value")?)?),
            },
            "unit" => ExprKind::Unit(Box::new(self.expr(required_field(node, "value")?)?)),
            "gate" | "open_rune_gate" => ExprKind::Gate {
                sample: self.mold(required_field(node, "sample")?)?,
                body: Box::new(self.body(node, "body")?),
            },
            "wide_gate" => ExprKind::WideGate {
                sample: self.mold(required_field(node, "sample")?)?,
                body: Box::new(self.expr(required_field(node, "body")?)?),
            },
            "cast" | "open_rune_cast" => ExprKind::Cast {
                mold: self.mold(required_field(node, "mold")?)?,
                body: Box::new(self.body(node, "value")?),
            },
            "trace" => ExprKind::Trace {
                value: Box::new(self.expr(required_field(node, "value")?)?),
                body: Box::new(self.body(node, "body")?),
            },
            "branch" | "rest_branch" => {
                let mut arms = Vec::new();
                for child in named(node) {
                    if child.kind() == "arm" {
                        arms.push(self.arm(child)?);
                    }
                }
                ExprKind::Branch {
                    subject: Box::new(self.expr(required_field(node, "subject")?)?),
                    arms,
                    rest: node.kind() == "rest_branch",
                }
            }
            "rest_head" => return self.rest_head(node),
            "string" => {
                let children = syntax_children(node);
                if children.len() == 1 && children[0].kind() == "string_literal" {
                    ExprKind::Atom(self.text(children[0]))
                } else {
                    let mut parts = Vec::new();
                    for child in children {
                        match child.kind() {
                            "string_start" | "string_middle" | "string_end" => {
                                parts.push(StringPart::Text(self.text(child)))
                            }
                            _ => parts.push(StringPart::Expr(self.expr(child)?)),
                        }
                    }
                    ExprKind::String(parts)
                }
            }
            "application_path" => {
                let mut parts = Vec::new();
                let mut cursor = node.walk();
                for child in node.children(&mut cursor) {
                    match child.kind() {
                        "%/" | "/" => parts.push(PathPart::Text(self.text(child))),
                        "knot" => parts.push(PathPart::Text(self.text(child))),
                        "application_expression_segment" => {
                            parts.push(PathPart::Text("(".to_string()));
                            parts.push(PathPart::Expr(self.expr(only_syntax_child(child)?)?));
                            parts.push(PathPart::Text(")".to_string()));
                        }
                        _ => {}
                    }
                }
                ExprKind::ApplicationPath(parts)
            }
            "literal" => {
                let child = only_syntax_child(node)?;
                if child.kind() == "string" {
                    return self.expr(child);
                }
                ExprKind::Atom(self.canonical_atom(node))
            }
            "reference" | "constructor" | "path_literal" | "crash" => {
                ExprKind::Atom(self.canonical_atom(node))
            }
            kind => {
                return Err(format!(
                    "formatter: unsupported expression node {kind}: {:?}",
                    self.text(node)
                ));
            }
        };
        Ok(Expr { node, kind })
    }

    fn rest_head(&self, node: Node<'a>) -> FResult<Expr<'a>> {
        let header_row = node.start_position().row;
        let mut heads = Vec::new();
        let mut body_children = Vec::new();
        for child in syntax_children(node) {
            if child.start_position().row == header_row {
                continue;
            }
            body_children.push(child);
        }

        let mut cursor = node.walk();
        let children: Vec<_> = node.children(&mut cursor).collect();
        for (index, child) in children.iter().enumerate() {
            match child.kind() {
                "|=" | "^-" | "~&" => {
                    let field = match child.kind() {
                        "|=" => "sample",
                        "^-" => "mold",
                        _ => "value",
                    };
                    let value = children[index + 1..]
                        .iter()
                        .copied()
                        .find(|candidate| {
                            candidate.is_named()
                                && candidate.start_position().row == header_row
                                && field_for(node, *candidate).as_deref() == Some(field)
                        })
                        .or_else(|| {
                            syntax_children(node).into_iter().find(|candidate| {
                                candidate.start_position().row == header_row
                                    && matches!(
                                        (child.kind(), candidate.kind()),
                                        ("|=", "sample")
                                            | (
                                                "^-",
                                                "aura"
                                                    | "hole"
                                                    | "noun"
                                                    | "void"
                                                    | "flag"
                                                    | "null"
                                                    | "term"
                                                    | "loobean"
                                                    | "mold_reference"
                                                    | "type_variable"
                                                    | "path_mold"
                                                    | "mold_apply"
                                                    | "open_mold_apply"
                                                    | "mold_cell"
                                                    | "open_mold_cell"
                                                    | "mold_function",
                                            )
                                            | ("~&", "call" | "gate" | "cast" | "trace" | "branch")
                                    )
                            })
                        })
                        .ok_or_else(|| "formatter: incomplete rest header".to_string())?;
                    match child.kind() {
                        "|=" => heads.push(Head::Gate(self.mold(value)?)),
                        "^-" => heads.push(Head::Cast(self.mold(value)?)),
                        _ => heads.push(Head::Trace(self.expr(value)?)),
                    }
                }
                _ => {}
            }
        }
        if heads.is_empty() {
            return Err("formatter: empty rest header".to_string());
        }

        let mut definitions = Vec::new();
        let mut last = None;
        for child in body_children {
            if child.kind() == "definition" {
                definitions.push(self.definition(child)?);
            } else {
                last = Some(self.expr(child)?);
            }
        }
        let last = last.ok_or_else(|| "formatter: rest header without a body".to_string())?;
        Ok(Expr {
            node,
            kind: ExprKind::RestHead {
                heads,
                body: Box::new(Body {
                    owner: node,
                    definitions,
                    last: Box::new(last),
                }),
            },
        })
    }

    fn arm(&self, node: Node<'a>) -> FResult<Arm<'a>> {
        Ok(Arm {
            node,
            pattern: self.pattern(required_field(node, "pattern")?)?,
            body: self.body(node, "value")?,
        })
    }

    fn value_items(&self, node: Node<'a>, change: bool) -> FResult<Vec<ValueItem<'a>>> {
        let target = if change {
            Some(required_field(node, "target")?.id())
        } else {
            None
        };
        let children = syntax_children(node);
        let mut items = Vec::new();
        let mut index = 0;
        while index < children.len() {
            let child = children[index];
            if Some(child.id()) == target {
                index += 1;
                continue;
            }
            if child.kind() == "edit" {
                items.push(ValueItem {
                    node: child,
                    face: Some(self.text(required_field(child, "field")?)),
                    value: self.expr(required_field(child, "value")?)?,
                });
                index += 1;
                continue;
            }
            if (change && child.kind() == "wing")
                || (!change && child.kind() == "name" && index + 1 < children.len())
            {
                items.push(ValueItem {
                    node: children[index + 1],
                    face: Some(self.text(child)),
                    value: self.expr(children[index + 1])?,
                });
                index += 2;
                continue;
            }
            items.push(ValueItem {
                node: child,
                face: None,
                value: self.expr(child)?,
            });
            index += 1;
        }
        Ok(items)
    }

    fn mold(&self, node: Node<'a>) -> FResult<Mold<'a>> {
        if node.kind() == "sample" {
            return self.mold(only_syntax_child(node)?);
        }
        let kind = match node.kind() {
            "sample_face" | "field" => {
                if let Some(face) = node.child_by_field_name("face") {
                    MoldKind::Face {
                        name: self.text(face),
                        mold: Box::new(self.mold(required_field(node, "mold")?)?),
                    }
                } else {
                    return self.mold(only_syntax_child(node)?);
                }
            }
            "sample_pun" | "pun" => {
                let name = syntax_children(node)
                    .into_iter()
                    .find(|child| child.kind() == "name")
                    .ok_or_else(|| "formatter: malformed pun".to_string())?;
                MoldKind::Pun(self.text(name))
            }
            "sample_cell" | "mold_cell" | "open_mold_cell" => {
                let breakable = node.kind() != "sample_cell";
                let children = syntax_children(node);
                let mut fields = Vec::new();
                let mut index = 0;
                while index < children.len() {
                    let child = children[index];
                    if index + 1 < children.len()
                        && child.kind() == "field"
                        && only_syntax_child(child)
                            .map(|inner| inner.kind() == "mold_reference")
                            .unwrap_or(false)
                        && child.end_byte() == children[index + 1].start_byte()
                        && field_pun_name(children[index + 1]).is_some()
                    {
                        let name = self.text(child);
                        let mold_name = self.text(field_pun_name(children[index + 1]).unwrap());
                        fields.push(Mold {
                            node: child,
                            kind: MoldKind::Face {
                                name,
                                mold: Box::new(Mold {
                                    node: children[index + 1],
                                    kind: MoldKind::Atom(mold_name),
                                }),
                            },
                        });
                        index += 2;
                    } else if index + 1 < children.len()
                        && child.kind() == "sample"
                        && only_syntax_child(child)
                            .map(|inner| inner.kind() == "sample_binding")
                            .unwrap_or(false)
                        && child.end_byte() == children[index + 1].start_byte()
                        && sample_pun_name(children[index + 1]).is_some()
                    {
                        let name = self.text(child);
                        let mold_name = self.text(sample_pun_name(children[index + 1]).unwrap());
                        fields.push(Mold {
                            node: child,
                            kind: MoldKind::Face {
                                name,
                                mold: Box::new(Mold {
                                    node: children[index + 1],
                                    kind: MoldKind::Atom(mold_name),
                                }),
                            },
                        });
                        index += 2;
                    } else if child.kind() == "name" && index + 1 < children.len() {
                        fields.push(Mold {
                            node: children[index + 1],
                            kind: MoldKind::Face {
                                name: self.text(child),
                                mold: Box::new(self.mold(children[index + 1])?),
                            },
                        });
                        index += 2;
                    } else {
                        fields.push(self.mold(child)?);
                        index += 1;
                    }
                }
                MoldKind::Cell { fields, breakable }
            }
            "mold_apply" | "open_mold_apply" => MoldKind::Apply {
                constructor: self.text(required_field(node, "constructor")?),
                arguments: fields(node, "argument")
                    .into_iter()
                    .map(|child| self.mold(child))
                    .collect::<FResult<Vec<_>>>()?,
            },
            "mold_function" => MoldKind::Function {
                sample: Box::new(self.mold(required_field(node, "sample")?)?),
                product: Box::new(self.mold(required_field(node, "product")?)?),
            },
            "generic" => {
                let variables = syntax_children(node)
                    .into_iter()
                    .filter(|child| child.kind() == "type_variable")
                    .map(|child| self.text(child))
                    .collect();
                MoldKind::Generic(variables)
            }
            "aura"
            | "hole"
            | "noun"
            | "void"
            | "flag"
            | "null"
            | "term"
            | "loobean"
            | "mold_reference"
            | "sample_mold_reference"
            | "type_variable"
            | "path_mold"
            | "sample_binding"
            | "string_literal"
            | "wildcard" => MoldKind::Atom(self.text(node)),
            kind => return Err(format!("formatter: unsupported mold node {kind}")),
        };
        Ok(Mold { node, kind })
    }

    fn pattern(&self, node: Node<'a>) -> FResult<Pattern<'a>> {
        if node.kind() == "pattern" {
            return self.pattern(only_syntax_child(node)?);
        }
        let kind = match node.kind() {
            "pattern_cell" => PatternKind::Cell(
                syntax_children(node)
                    .into_iter()
                    .map(|child| self.pattern(child))
                    .collect::<FResult<Vec<_>>>()?,
            ),
            "term" | "number" | "decimal" | "hexadecimal" | "base32" | "string_literal"
            | "ship" | "loobean" | "null" | "wildcard" | "pattern_binding" | "name" => {
                PatternKind::Atom(self.text(node))
            }
            kind => return Err(format!("formatter: unsupported pattern node {kind}")),
        };
        Ok(Pattern { node, kind })
    }

    fn canonical_atom(&self, node: Node<'_>) -> String {
        if node.kind() == "constructor" {
            let term = syntax_children(node)
                .into_iter()
                .find(|child| child.kind() == "term")
                .map(|child| self.text(child))
                .unwrap_or_default();
            format!("|={term}")
        } else {
            self.text(node)
        }
    }
}

#[derive(Clone)]
struct Comment {
    id: usize,
    anchor: usize,
    row: usize,
    column: usize,
    text: String,
    standalone: bool,
}

struct SequenceItem<'tree> {
    node: Node<'tree>,
    doc: Doc,
}

struct Renderer<'a> {
    source: &'a str,
    lines: Vec<&'a str>,
    handled_comments: HashSet<usize>,
}

impl<'a> Renderer<'a> {
    fn new(source: &'a str) -> Self {
        Self {
            source,
            lines: source.split('\n').collect(),
            handled_comments: HashSet::new(),
        }
    }

    fn module(&mut self, module: &Module<'a>) -> FResult<Doc> {
        let comments = self.all_comments(module.node);
        let mut items = Vec::new();
        for entry in &module.entries {
            let node = entry.node();
            let doc = match entry {
                Entry::Import(import) => self.import(import)?,
                Entry::Definition(definition) => self.definition(definition, 0)?,
            };
            items.push(SequenceItem { node, doc });
        }
        let doc = self.sequence(module.node, None, items, 0, 0, self.source.len())?;
        if let Some(comment) = comments.iter().find(|comment| !self.handled(comment)) {
            return Err(format!(
                "formatter: comment at line {} was not rendered",
                comment.row + 1
            ));
        }
        Ok(doc)
    }

    fn import(&mut self, import: &Import<'a>) -> FResult<Doc> {
        let node = import.node;
        let text = match node.kind() {
            "import" => {
                let rune = node
                    .child(0)
                    .ok_or_else(|| "formatter: malformed import".to_string())?;
                match &self.source[rune.byte_range()] {
                    "/-" => format!("/-  {}", self.text(required_field(node, "name")?)),
                    "/%" => format!("/%  {}", self.text(required_field(node, "mark")?)),
                    "/=" => format!(
                        "/=  {}  {}",
                        self.text(required_field(node, "name")?),
                        self.text(required_field(node, "path")?)
                    ),
                    _ => return Err("formatter: unknown import".to_string()),
                }
            }
            _ => return Err("formatter: malformed import".to_string()),
        };
        let doc = Doc::line(0, text);
        self.attach_unhandled(node, doc, 0)
    }

    fn definition(&mut self, definition: &Definition<'a>, indent: usize) -> FResult<Doc> {
        let doc = match &definition.kind {
            DefinitionKind::Value { name, body } => {
                let prefix = format!("++  {name}");
                self.owner_body(definition.scope, prefix, body, indent, indent)?
            }
            DefinitionKind::Mold {
                name,
                generic,
                molds,
            } => {
                let mut prefix = format!("+$  {name}");
                if let Some(generic) = generic {
                    prefix.push_str("  ");
                    prefix.push_str(&self.flat_mold(generic).ok_or_else(|| {
                        "formatter: comments inside a generic are unsupported".to_string()
                    })?);
                }
                if molds.len() == 1 {
                    let mold = &molds[0];
                    if let Some(flat) = self.flat_mold(mold) {
                        let candidate = format!("{prefix}  {flat}");
                        if indent + width(&candidate) <= WIDTH {
                            Doc::line(indent, candidate)
                        } else {
                            let header = Doc::line(indent, prefix);
                            let items = vec![SequenceItem {
                                node: mold.node,
                                doc: self.mold_doc(mold, indent + INDENT, indent + INDENT)?,
                            }];
                            self.sequence(
                                definition.scope,
                                Some(header),
                                items,
                                indent + INDENT,
                                0,
                                self.source.len(),
                            )?
                        }
                    } else {
                        let header = Doc::line(indent, prefix);
                        let items = vec![SequenceItem {
                            node: mold.node,
                            doc: self.mold_doc(mold, indent + INDENT, indent + INDENT)?,
                        }];
                        self.sequence(
                            definition.scope,
                            Some(header),
                            items,
                            indent + INDENT,
                            0,
                            self.source.len(),
                        )?
                    }
                } else {
                    let header = Doc::line(indent, prefix);
                    let mut items = Vec::new();
                    for mold in molds {
                        items.push(SequenceItem {
                            node: mold.node,
                            doc: self.mold_doc(mold, indent + INDENT, indent + INDENT)?,
                        });
                    }
                    self.sequence(
                        definition.scope,
                        Some(header),
                        items,
                        indent + INDENT,
                        0,
                        self.source.len(),
                    )?
                }
            }
        };
        let doc = self.attach_trailing_definition_comments(definition.scope, doc, indent)?;
        self.attach_unhandled(definition.scope, doc, indent)
    }

    fn owner_body(
        &mut self,
        owner: Node<'a>,
        prefix: String,
        body: &Body<'a>,
        indent: usize,
        start: usize,
    ) -> FResult<Doc> {
        let simple = body.definitions.is_empty();
        let can_inline =
            simple && !matches!(body.last.kind, ExprKind::Cast { .. }) && !self.has_trivia(owner);
        if can_inline && let Some(flat) = self.flat_expr(&body.last, Position::Body) {
            let candidate = format!("{prefix}  {flat}");
            if start + width(&candidate) <= WIDTH {
                return Ok(Doc::line(start, candidate));
            }
        }

        if simple {
            match &body.last.kind {
                ExprKind::Gate {
                    sample,
                    body: gate_body,
                } => {
                    if let Some(sample) = self.flat_mold(sample) {
                        let header = Doc::line(start, format!("{prefix}  |=  {sample}"));
                        return self.body_doc(gate_body, indent + INDENT, Some(header));
                    }
                }
                ExprKind::Cast {
                    mold,
                    body: cast_body,
                } => {
                    if let Some(mold_text) = self.flat_mold(mold) {
                        if let Some(flat_cast) = self.flat_expr(&body.last, Position::Body)
                            && indent + INDENT + width(&flat_cast) <= WIDTH
                        {
                            let header = Doc::line(start, prefix);
                            return self.body_doc(body, indent + INDENT, Some(header));
                        }
                        let header = Doc::line(start, format!("{prefix}  ^-  {mold_text}"));
                        return self.body_doc(cast_body, indent + INDENT, Some(header));
                    }
                }
                _ => {}
            }
        }

        let header = Doc::line(start, prefix);
        self.body_doc(body, indent + INDENT, Some(header))
    }

    fn body_doc(&mut self, body: &Body<'a>, indent: usize, header: Option<Doc>) -> FResult<Doc> {
        let mut items = Vec::new();
        for definition in &body.definitions {
            items.push(SequenceItem {
                node: definition.node,
                doc: self.definition(definition, indent)?,
            });
        }
        items.push(SequenceItem {
            node: body.last.node,
            doc: self.expr_doc(&body.last, indent, indent, Position::Body)?,
        });
        self.sequence(body.owner, header, items, indent, 0, self.source.len())
    }

    fn expr_doc(
        &mut self,
        expr: &Expr<'a>,
        indent: usize,
        start: usize,
        position: Position,
    ) -> FResult<Doc> {
        let flat = self.flat_expr(expr, position);
        let mut doc = if let Some(flat) = flat.as_ref() {
            if start + width(flat) <= WIDTH {
                Doc::line(start, flat)
            } else {
                self.break_expr(expr, indent, start, position)?
            }
        } else {
            self.break_expr(expr, indent, start, position)?
        };
        if doc.lines.is_empty() {
            doc = Doc::line(start, flat.unwrap_or_default());
        }
        self.attach_unhandled(expr.node, doc, indent)
    }

    fn break_expr(
        &mut self,
        expr: &Expr<'a>,
        indent: usize,
        start: usize,
        position: Position,
    ) -> FResult<Doc> {
        match &expr.kind {
            ExprKind::Atom(_)
            | ExprKind::String(_)
            | ExprKind::ApplicationPath(_)
            | ExprKind::Pair { .. }
            | ExprKind::Unit(_) => {
                let flat = self
                    .flat_expr(expr, position)
                    .ok_or_else(|| format!("formatter: cannot break {}", expr.node.kind()))?;
                Ok(Doc::line(start, flat))
            }
            ExprKind::Group(value) => {
                if position == Position::Operand
                    && matches!(
                        value.kind,
                        ExprKind::Cast { .. } | ExprKind::Trace { .. } | ExprKind::Branch { .. }
                    )
                {
                    let mut doc = self.expr_doc(value, indent, start + 1, Position::Body)?;
                    doc.lines[0] = format!("{}({}", " ".repeat(start), &doc.lines[0][start + 1..]);
                    Ok(doc)
                } else {
                    self.expr_doc(value, indent, start, position)
                }
            }
            ExprKind::Call(values) => {
                if values.len() == 1 {
                    return self.expr_doc(&values[0], indent, start, position);
                }
                if values.is_empty() {
                    return Err("formatter: empty call".to_string());
                }
                let mut head =
                    self.expr_doc(&values[0], indent + INDENT, start + 1, Position::Operand)?;
                head.lines[0] = format!("{}({}", " ".repeat(start), &head.lines[0][start + 1..]);
                let mut items = Vec::new();
                for value in &values[1..] {
                    items.push(SequenceItem {
                        node: value.node,
                        doc: self.expr_doc(
                            value,
                            indent + INDENT,
                            indent + INDENT,
                            Position::Body,
                        )?,
                    });
                }
                self.sequence(
                    expr.node,
                    Some(head),
                    items,
                    indent + INDENT,
                    0,
                    self.source.len(),
                )
            }
            ExprKind::List(values) => {
                let header = Doc::line(start, "~[");
                let mut items = Vec::new();
                for value in values {
                    items.push(SequenceItem {
                        node: value.node,
                        doc: self.expr_doc(
                            value,
                            indent + INDENT,
                            indent + INDENT,
                            Position::Body,
                        )?,
                    });
                }
                self.sequence(
                    expr.node,
                    Some(header),
                    items,
                    indent + INDENT,
                    0,
                    self.source.len(),
                )
            }
            ExprKind::Tuple(values) => {
                let header = Doc::line(start, "[");
                let items = self.value_item_docs(values, indent + INDENT)?;
                self.sequence(
                    expr.node,
                    Some(header),
                    items,
                    indent + INDENT,
                    0,
                    self.source.len(),
                )
            }
            ExprKind::Change { target, edits } => {
                let header = Doc::line(start, format!("{target}("));
                let items = self.value_item_docs(edits, indent + INDENT)?;
                self.sequence(
                    expr.node,
                    Some(header),
                    items,
                    indent + INDENT,
                    0,
                    self.source.len(),
                )
            }
            ExprKind::WideGate { sample, body } => {
                if position == Position::Operand {
                    let flat = self
                        .flat_expr(expr, position)
                        .ok_or_else(|| "formatter: cannot format this wide gate".to_string())?;
                    return Ok(Doc::line(start, flat));
                }
                let sample = self.flat_mold(sample).ok_or_else(|| {
                    "formatter: comments inside a gate sample are unsupported".to_string()
                })?;
                let mut doc = Doc::line(start, format!("|=  {sample}"));
                let value =
                    self.expr_doc(body, indent + INDENT, indent + INDENT, Position::Body)?;
                doc.append(value);
                Ok(doc)
            }
            ExprKind::Gate { sample, body } => {
                if position == Position::Operand {
                    let flat = self.flat_expr(expr, position).ok_or_else(|| {
                        "formatter: a multiline gate cannot be a wide operand".to_string()
                    })?;
                    return Ok(Doc::line(start, flat));
                }
                let sample = self.flat_mold(sample).ok_or_else(|| {
                    "formatter: comments inside a gate sample are unsupported".to_string()
                })?;
                let header = Doc::line(start, format!("|=  {sample}"));
                self.body_doc(body, indent + INDENT, Some(header))
            }
            ExprKind::Cast { mold, body } => {
                if position == Position::Operand {
                    return Err("formatter: a cast cannot be an operand".to_string());
                }
                let mold = self.flat_mold(mold).ok_or_else(|| {
                    "formatter: comments inside a cast mold are unsupported".to_string()
                })?;
                let header = Doc::line(start, format!("^-  {mold}"));
                self.body_doc(body, indent + INDENT, Some(header))
            }
            ExprKind::Trace { value, body } => {
                let value = self.flat_expr(value, Position::Body).ok_or_else(|| {
                    "formatter: a multiline trace value is unsupported".to_string()
                })?;
                let header = Doc::line(start, format!("~&  {value}"));
                self.body_doc(body, indent + INDENT, Some(header))
            }
            ExprKind::Branch {
                subject,
                arms,
                rest,
            } => {
                let subject = self.flat_expr(subject, Position::Body).ok_or_else(|| {
                    "formatter: a multiline branch subject is unsupported".to_string()
                })?;
                let header = Doc::line(start, format!("?-  {subject}"));
                let arm_indent = if *rest { indent } else { indent + INDENT };
                let mut items = Vec::new();
                for arm in arms {
                    items.push(SequenceItem {
                        node: arm.node,
                        doc: self.arm_doc(arm, arm_indent)?,
                    });
                }
                self.sequence(
                    expr.node,
                    Some(header),
                    items,
                    arm_indent,
                    0,
                    self.source.len(),
                )
            }
            ExprKind::RestHead { heads, body } => {
                let mut text = String::new();
                for (index, head) in heads.iter().enumerate() {
                    if index > 0 {
                        text.push_str("  ");
                    }
                    match head {
                        Head::Gate(sample) => {
                            text.push_str("|=  ");
                            text.push_str(&self.flat_mold(sample).ok_or_else(|| {
                                "formatter: invalid sample in rest header".to_string()
                            })?);
                        }
                        Head::Cast(mold) => {
                            text.push_str("^-  ");
                            text.push_str(&self.flat_mold(mold).ok_or_else(|| {
                                "formatter: invalid mold in rest header".to_string()
                            })?);
                        }
                        Head::Trace(value) => {
                            text.push_str("~&  ");
                            text.push_str(&self.flat_expr(value, Position::Body).ok_or_else(
                                || "formatter: invalid trace in rest header".to_string(),
                            )?);
                        }
                    }
                }
                let header = Doc::line(start, text);
                self.body_doc(body, indent, Some(header))
            }
        }
    }

    fn value_item_docs(
        &mut self,
        values: &[ValueItem<'a>],
        indent: usize,
    ) -> FResult<Vec<SequenceItem<'a>>> {
        let mut items = Vec::new();
        for item in values {
            let doc = if let Some(face) = &item.face {
                let prefix = format!("{face}=");
                if let Some(flat) = self.flat_expr(&item.value, Position::Body) {
                    if indent + width(&prefix) + width(&flat) <= WIDTH {
                        Doc::line(indent, format!("{prefix}{flat}"))
                    } else {
                        let mut value = self.expr_doc(
                            &item.value,
                            indent,
                            indent + width(&prefix),
                            Position::Body,
                        )?;
                        value.lines[0] = format!(
                            "{}{}{}",
                            " ".repeat(indent),
                            prefix,
                            &value.lines[0][indent + width(&prefix)..]
                        );
                        value
                    }
                } else {
                    let mut value = self.expr_doc(
                        &item.value,
                        indent,
                        indent + width(&prefix),
                        Position::Body,
                    )?;
                    value.lines[0] = format!(
                        "{}{}{}",
                        " ".repeat(indent),
                        prefix,
                        &value.lines[0][indent + width(&prefix)..]
                    );
                    value
                }
            } else {
                self.expr_doc(&item.value, indent, indent, Position::Body)?
            };
            items.push(SequenceItem {
                node: item.node,
                doc,
            });
        }
        Ok(items)
    }

    fn arm_doc(&mut self, arm: &Arm<'a>, indent: usize) -> FResult<Doc> {
        let pattern = self.flat_pattern(&arm.pattern).ok_or_else(|| {
            "formatter: comments inside an arm pattern are unsupported".to_string()
        })?;
        self.owner_body(arm.node, pattern, &arm.body, indent, indent)
    }

    fn mold_doc(&mut self, mold: &Mold<'a>, indent: usize, start: usize) -> FResult<Doc> {
        let flat = self.flat_mold(mold);
        let doc = if let Some(flat) = flat.as_ref() {
            if start + width(flat) <= WIDTH {
                Doc::line(start, flat)
            } else {
                self.break_mold(mold, indent, start)?
            }
        } else {
            self.break_mold(mold, indent, start)?
        };
        self.attach_unhandled(mold.node, doc, indent)
    }

    fn break_mold(&mut self, mold: &Mold<'a>, indent: usize, start: usize) -> FResult<Doc> {
        match &mold.kind {
            MoldKind::Cell { fields, breakable } if *breakable => {
                let header = Doc::line(start, "[");
                let mut items = Vec::new();
                for field in fields {
                    items.push(SequenceItem {
                        node: field.node,
                        doc: self.mold_doc(field, indent + INDENT, indent + INDENT)?,
                    });
                }
                self.sequence(
                    mold.node,
                    Some(header),
                    items,
                    indent + INDENT,
                    0,
                    self.source.len(),
                )
            }
            MoldKind::Apply {
                constructor,
                arguments,
            } => {
                let header = Doc::line(start, format!("({constructor}"));
                let mut items = Vec::new();
                for argument in arguments {
                    items.push(SequenceItem {
                        node: argument.node,
                        doc: self.mold_doc(argument, indent + INDENT, indent + INDENT)?,
                    });
                }
                self.sequence(
                    mold.node,
                    Some(header),
                    items,
                    indent + INDENT,
                    0,
                    self.source.len(),
                )
            }
            _ => {
                let flat = self
                    .flat_mold(mold)
                    .ok_or_else(|| format!("formatter: cannot break mold {}", mold.node.kind()))?;
                Ok(Doc::line(start, flat))
            }
        }
    }

    fn flat_expr(&self, expr: &Expr<'a>, position: Position) -> Option<String> {
        if self.has_trivia(expr.node) {
            return None;
        }
        match &expr.kind {
            ExprKind::Atom(text) => Some(text.clone()),
            ExprKind::Call(values) => {
                if values.is_empty() {
                    return None;
                }
                if values.len() == 1 {
                    return self.flat_expr(&values[0], position);
                }
                let mut text = String::new();
                for (index, value) in values.iter().enumerate() {
                    if index > 0 {
                        text.push(' ');
                    }
                    text.push_str(&self.flat_expr(value, Position::Operand)?);
                }
                if position == Position::Operand {
                    Some(format!("({text})"))
                } else {
                    Some(text)
                }
            }
            ExprKind::Group(value) => {
                if position == Position::Operand && matches!(value.kind, ExprKind::Cast { .. }) {
                    Some(format!("({})", self.flat_expr(value, Position::Body)?))
                } else {
                    self.flat_expr(value, position)
                }
            }
            ExprKind::List(values) => {
                let mut text = "~[".to_string();
                for (index, value) in values.iter().enumerate() {
                    if index > 0 {
                        text.push(' ');
                    }
                    text.push_str(&self.flat_expr(value, Position::Operand)?);
                }
                text.push(']');
                Some(text)
            }
            ExprKind::Tuple(values) => {
                let mut text = "[".to_string();
                for (index, item) in values.iter().enumerate() {
                    if index > 0 {
                        text.push(' ');
                    }
                    if let Some(face) = &item.face {
                        text.push_str(face);
                        text.push('=');
                        text.push_str(&self.flat_expr(&item.value, Position::Operand)?);
                    } else {
                        text.push_str(&self.flat_expr(&item.value, Position::Operand)?);
                    }
                }
                text.push(']');
                Some(text)
            }
            ExprKind::Change { target, edits } => {
                let mut text = format!("{target}(");
                for (index, item) in edits.iter().enumerate() {
                    if index > 0 {
                        text.push(' ');
                    }
                    text.push_str(item.face.as_ref()?);
                    text.push('=');
                    text.push_str(&self.flat_expr(&item.value, Position::Operand)?);
                }
                text.push(')');
                Some(text)
            }
            ExprKind::Pair { tag, value } => Some(format!(
                "{tag}+{}",
                self.flat_expr(value, Position::Operand)?
            )),
            ExprKind::Unit(value) => {
                Some(format!("`{}", self.flat_expr(value, Position::Operand)?))
            }
            ExprKind::Gate { sample, body } => {
                if !body.definitions.is_empty()
                    || matches!(body.last.kind, ExprKind::Cast { .. })
                    || (position == Position::Body
                        && matches!(
                            &sample.kind,
                            MoldKind::Atom(text) if text.starts_with('%')
                        ))
                {
                    return None;
                }
                let sample = self.flat_mold(sample)?;
                if position == Position::Operand {
                    Some(format!(
                        "|=({sample}  {})",
                        self.flat_expr(&body.last, Position::Operand)?
                    ))
                } else {
                    Some(format!(
                        "|=  {sample}  {}",
                        self.flat_expr(&body.last, Position::Body)?
                    ))
                }
            }
            ExprKind::WideGate { sample, body } => {
                if position == Position::Operand {
                    Some(format!(
                        "|=({}  {})",
                        self.flat_mold(sample)?,
                        self.flat_expr(body, Position::Operand)?
                    ))
                } else {
                    Some(format!(
                        "|=  {}  {}",
                        self.flat_mold(sample)?,
                        self.flat_expr(body, Position::Body)?
                    ))
                }
            }
            ExprKind::Cast { mold, body } => {
                if position == Position::Operand || !body.definitions.is_empty() {
                    return None;
                }
                Some(format!(
                    "^-  {}  {}",
                    self.flat_mold(mold)?,
                    self.flat_expr(&body.last, Position::Body)?
                ))
            }
            ExprKind::Trace { .. } | ExprKind::Branch { .. } | ExprKind::RestHead { .. } => None,
            ExprKind::String(parts) => {
                let mut text = String::new();
                for part in parts {
                    match part {
                        StringPart::Text(piece) => text.push_str(piece),
                        StringPart::Expr(value) => {
                            text.push_str(&self.flat_expr(value, Position::Body)?)
                        }
                    }
                }
                Some(text)
            }
            ExprKind::ApplicationPath(parts) => {
                let mut text = String::new();
                for part in parts {
                    match part {
                        PathPart::Text(piece) => text.push_str(piece),
                        PathPart::Expr(value) => {
                            text.push_str(&self.flat_expr(value, Position::Body)?)
                        }
                    }
                }
                Some(text)
            }
        }
    }

    fn flat_mold(&self, mold: &Mold<'a>) -> Option<String> {
        if self.has_trivia(mold.node) {
            return None;
        }
        match &mold.kind {
            MoldKind::Atom(text) => Some(text.clone()),
            MoldKind::Face { name, mold } => Some(format!("{name}={}", self.flat_mold(mold)?)),
            MoldKind::Pun(name) => Some(format!("={name}")),
            MoldKind::Cell { fields, .. } => {
                let mut text = "[".to_string();
                for (index, field) in fields.iter().enumerate() {
                    if index > 0 {
                        text.push(' ');
                    }
                    text.push_str(&self.flat_mold(field)?);
                }
                text.push(']');
                Some(text)
            }
            MoldKind::Apply {
                constructor,
                arguments,
            } => {
                let mut text = format!("({constructor}");
                for argument in arguments {
                    text.push(' ');
                    text.push_str(&self.flat_mold(argument)?);
                }
                text.push(')');
                Some(text)
            }
            MoldKind::Function { sample, product } => Some(format!(
                "$-({}  {})",
                self.flat_mold(sample)?,
                self.flat_mold(product)?
            )),
            MoldKind::Generic(variables) => Some(format!("|$  [{}]", variables.join(" "))),
        }
    }

    fn flat_pattern(&self, pattern: &Pattern<'a>) -> Option<String> {
        if self.has_trivia(pattern.node) {
            return None;
        }
        match &pattern.kind {
            PatternKind::Atom(text) => Some(text.clone()),
            PatternKind::Cell(patterns) => {
                let mut text = "[".to_string();
                for (index, pattern) in patterns.iter().enumerate() {
                    if index > 0 {
                        text.push(' ');
                    }
                    text.push_str(&self.flat_pattern(pattern)?);
                }
                text.push(']');
                Some(text)
            }
        }
    }

    fn sequence(
        &mut self,
        scope: Node<'a>,
        header: Option<Doc>,
        items: Vec<SequenceItem<'a>>,
        indent: usize,
        lower: usize,
        upper: usize,
    ) -> FResult<Doc> {
        #[derive(Clone)]
        enum EventKind {
            Item(usize),
            Comment(Comment),
        }
        #[derive(Clone)]
        struct Event {
            anchor: usize,
            row: usize,
            end_row: usize,
            kind: EventKind,
        }

        let mut events = Vec::new();
        for (index, item) in items.iter().enumerate() {
            events.push(Event {
                anchor: item.node.start_byte(),
                row: item.node.start_position().row,
                end_row: self.last_code_row(item.node),
                kind: EventKind::Item(index),
            });
        }
        for comment in self.direct_comments(scope) {
            if comment.anchor < lower || comment.anchor > upper || self.handled(&comment) {
                continue;
            }
            if comment.standalone
                && comment.anchor >= last_syntax_end(scope)
                && comment.column < indent
            {
                continue;
            }
            if items.iter().any(|item| {
                comment.anchor >= item.node.start_byte() && comment.anchor < item.node.end_byte()
            }) {
                continue;
            }
            events.push(Event {
                anchor: comment.anchor,
                row: comment.row,
                end_row: comment.row,
                kind: EventKind::Comment(comment),
            });
        }
        events.sort_by_key(|event| event.anchor);

        let mut output = Doc::empty();
        let header_row = scope.start_position().row;
        if let Some(header) = header {
            output.append(header);
        }
        let had_header = !output.lines.is_empty();
        let mut previous: Option<(usize, usize)> = None;

        for event in events {
            if let Some((_, previous_row)) = previous
                && self.blank_between(previous_row, event.row)
            {
                output.lines.push(format!("{}::", " ".repeat(indent)));
            }
            match event.kind {
                EventKind::Item(index) => {
                    output.append(items[index].doc.clone());
                    previous = Some((event.row, event.end_row));
                }
                EventKind::Comment(comment) => {
                    let trailing = !comment.standalone
                        && (previous.map(|(_, row)| row == comment.row).unwrap_or(false)
                            || (previous.is_none() && had_header && header_row == comment.row));
                    if trailing && !output.lines.is_empty() {
                        let index = if previous.is_none() {
                            0
                        } else {
                            output.lines.len() - 1
                        };
                        append_trailing(&mut output.lines[index], &comment.text);
                    } else {
                        output
                            .lines
                            .push(format!("{}{}", " ".repeat(indent), comment.text));
                    }
                    self.handled_comments.insert(comment.id);
                    previous = Some((comment.row, comment.row));
                }
            }
        }
        Ok(output)
    }

    fn attach_unhandled(&mut self, node: Node<'a>, mut doc: Doc, indent: usize) -> FResult<Doc> {
        for comment in self.direct_comments(node) {
            if self.handled(&comment) {
                continue;
            }
            if comment.standalone
                && comment.anchor >= last_syntax_end(node)
                && comment.column < indent
            {
                continue;
            }
            if comment.standalone {
                let index = if comment.row <= node.start_position().row || doc.lines.is_empty() {
                    0
                } else if doc.lines.len() > 1 && comment.row < last_row(node) {
                    1
                } else {
                    doc.lines.len()
                };
                doc.lines
                    .insert(index, format!("{}{}", " ".repeat(indent), comment.text));
            } else if !doc.lines.is_empty() {
                let index = if comment.row == node.start_position().row {
                    0
                } else {
                    doc.lines.len() - 1
                };
                append_trailing(&mut doc.lines[index], &comment.text);
            }
            self.handled_comments.insert(comment.id);
        }
        Ok(doc)
    }

    fn attach_trailing_definition_comments(
        &mut self,
        node: Node<'a>,
        mut doc: Doc,
        indent: usize,
    ) -> FResult<Doc> {
        let last_syntax = last_syntax_end(node);
        let mut previous_row = self.source[..last_syntax]
            .bytes()
            .filter(|byte| *byte == b'\n')
            .count();
        for comment in self.all_comments(node) {
            if self.handled(&comment) || comment.anchor < last_syntax || comment.column < indent {
                continue;
            }
            if comment.standalone {
                if self.blank_between(previous_row, comment.row) {
                    doc.lines.push(format!("{}::", " ".repeat(indent)));
                }
                doc.lines
                    .push(format!("{}{}", " ".repeat(indent), comment.text));
            } else if !doc.lines.is_empty() {
                append_trailing(doc.lines.last_mut().unwrap(), &comment.text);
            }
            previous_row = comment.row;
            self.handled_comments.insert(comment.id);
        }
        Ok(doc)
    }

    fn all_comments(&self, node: Node<'a>) -> Vec<Comment> {
        let mut comments = self.direct_comments(node);
        for child in named(node) {
            if !is_comment(child) {
                comments.extend(self.all_comments(child));
            }
        }
        comments.sort_by_key(|comment| comment.anchor);
        comments
    }

    fn direct_comments(&self, node: Node<'a>) -> Vec<Comment> {
        let mut comments = Vec::new();
        for child in named(node) {
            if !is_comment(child) {
                continue;
            }
            let text = &self.source[child.byte_range()];
            let Some(relative) = text.find("::") else {
                continue;
            };
            let anchor = child.start_byte() + relative;
            let row = child.end_position().row;
            let line = self.lines.get(row).copied().unwrap_or("");
            let column = anchor
                - self.source[..anchor]
                    .rfind('\n')
                    .map(|i| i + 1)
                    .unwrap_or(0);
            let standalone = line[..column.min(line.len())].trim().is_empty();
            comments.push(Comment {
                id: child.id(),
                anchor,
                row,
                column,
                text: self.source[anchor..child.end_byte()].trim_end().to_string(),
                standalone,
            });
        }
        comments
    }

    fn handled(&self, comment: &Comment) -> bool {
        self.handled_comments.contains(&comment.id)
    }

    fn last_code_row(&self, node: Node<'a>) -> usize {
        let mut row = last_row(node);
        while row > node.start_position().row
            && self
                .lines
                .get(row)
                .map(|line| line.trim().is_empty())
                .unwrap_or(false)
        {
            row -= 1;
        }
        row
    }

    fn blank_between(&self, previous: usize, next: usize) -> bool {
        if next <= previous + 1 {
            return false;
        }
        (previous + 1..next).any(|row| {
            self.lines
                .get(row)
                .map(|line| line.trim().is_empty())
                .unwrap_or(false)
        })
    }

    fn has_trivia(&self, node: Node<'a>) -> bool {
        if has_comment(node) {
            return true;
        }
        let start = node.start_position().row;
        let end = last_row(node);
        (start..=end).any(|row| {
            row > start
                && row < end
                && self
                    .lines
                    .get(row)
                    .map(|line| line.trim().is_empty())
                    .unwrap_or(false)
        })
    }

    fn text(&self, node: Node<'_>) -> String {
        self.source[node.byte_range()].to_string()
    }
}

fn named(node: Node<'_>) -> Vec<Node<'_>> {
    let mut cursor = node.walk();
    node.named_children(&mut cursor).collect()
}

fn syntax_children(node: Node<'_>) -> Vec<Node<'_>> {
    named(node)
        .into_iter()
        .filter(|child| !is_comment(*child))
        .collect()
}

fn only_syntax_child(node: Node<'_>) -> FResult<Node<'_>> {
    let children = syntax_children(node);
    if children.len() == 1 {
        Ok(children[0])
    } else {
        Err(format!(
            "formatter: expected one syntax child in {}, got {}",
            node.kind(),
            children.len()
        ))
    }
}

fn field_pun_name<'tree>(node: Node<'tree>) -> Option<Node<'tree>> {
    if node.kind() != "field" {
        return None;
    }
    let inner = only_syntax_child(node).ok()?;
    if inner.kind() != "pun" {
        return None;
    }
    syntax_children(inner)
        .into_iter()
        .find(|child| child.kind() == "name")
}

fn sample_pun_name<'tree>(node: Node<'tree>) -> Option<Node<'tree>> {
    if node.kind() != "sample" {
        return None;
    }
    let inner = only_syntax_child(node).ok()?;
    if inner.kind() != "sample_pun" {
        return None;
    }
    syntax_children(inner)
        .into_iter()
        .find(|child| child.kind() == "name")
}

fn required_field<'tree>(node: Node<'tree>, field: &str) -> FResult<Node<'tree>> {
    node.child_by_field_name(field)
        .ok_or_else(|| format!("formatter: {} has no {field} field", node.kind()))
}

fn fields<'tree>(node: Node<'tree>, field: &str) -> Vec<Node<'tree>> {
    let mut cursor = node.walk();
    node.children_by_field_name(field, &mut cursor).collect()
}

fn field_for(node: Node<'_>, sought: Node<'_>) -> Option<String> {
    let mut cursor = node.walk();
    if !cursor.goto_first_child() {
        return None;
    }
    loop {
        if cursor.node().id() == sought.id() {
            return cursor.field_name().map(str::to_string);
        }
        if !cursor.goto_next_sibling() {
            return None;
        }
    }
}

fn is_comment(node: Node<'_>) -> bool {
    matches!(node.kind(), "comment" | "trailing_comment")
}

fn has_comment(node: Node<'_>) -> bool {
    if is_comment(node) {
        return true;
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        if has_comment(child) {
            return true;
        }
    }
    false
}

fn last_syntax_end(node: Node<'_>) -> usize {
    let mut end = node.start_byte();
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        if is_comment(child) || matches!(child.kind(), "_indent" | "_dedent" | "_newline") {
            continue;
        }
        let child_end = if child.is_named() {
            last_syntax_end(child)
        } else {
            child.end_byte()
        };
        end = end.max(child_end);
    }
    if end == node.start_byte() {
        node.end_byte()
    } else {
        end
    }
}

fn last_row(node: Node<'_>) -> usize {
    let end = node.end_position();
    if end.column == 0 && end.row > node.start_position().row {
        end.row - 1
    } else {
        end.row
    }
}

fn width(text: &str) -> usize {
    text.chars().count()
}

fn append_trailing(line: &mut String, comment: &str) {
    while line.ends_with(' ') {
        line.pop();
    }
    line.push_str("  ");
    line.push_str(comment);
}

fn format_once(source: &str) -> FResult<String> {
    let tree = parse(source)?;
    let root = tree.root_node();
    let module = Builder { source }.module(root)?;
    let doc = Renderer::new(source).module(&module)?;
    let mut output = doc.lines.join("\n");
    for line in output.lines() {
        debug_assert_eq!(line, line.trim_end());
    }
    if !output.is_empty() {
        output.push('\n');
    }
    Ok(output)
}

pub fn format_source(source: &str) -> Result<String, String> {
    let formatted = format_once(source)?;
    let reparsed = parse(&formatted).map_err(|error| {
        format!("formatter: generated invalid Jibb syntax:\n{formatted}\n{error}")
    })?;
    drop(reparsed);
    let second = format_once(&formatted)?;
    if second != formatted {
        return Err(format!(
            "formatter: formatting did not converge:\nFIRST:\n{formatted}\nSECOND:\n{second}"
        ));
    }
    Ok(formatted)
}
