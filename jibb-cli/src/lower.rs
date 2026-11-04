use crate::{
    Diagnostic,
    ast::{
        ApplicationSegment, Arm, Definition, DefinitionKind, Edit, Expr, ExprKind, Generic, Import,
        ImportKind, Item, Literal, Module, Mold, MoldDefinition, MoldField, MoldKind,
        MoldPathSegment, NumberAura, NumberLiteral, Pattern, PatternKind, Sample, SampleKind, Span,
        StringPart, TermKind, TermLiteral, TypedSegmentMold,
    },
    node_span,
};
use num_bigint::BigUint;
use tree_sitter::Node;

type LResult<T> = Result<T, Diagnostic>;

pub(crate) fn validate(node: Node<'_>) -> LResult<()> {
    if node.kind() == "ERROR" || node.is_missing() {
        return Err(Diagnostic::at(
            if node.is_missing() {
                format!("invalid Jibb syntax: missing {}", node.kind())
            } else {
                "invalid Jibb syntax".to_string()
            },
            node_span(node),
        ));
    }
    if node.is_named() && node.kind() != "source_file" && node.start_byte() == node.end_byte() {
        return Err(Diagnostic::at(
            format!("invalid Jibb syntax: empty {} node", node.kind()),
            node_span(node),
        ));
    }
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        validate(child)?;
    }
    Ok(())
}

pub(crate) fn lower_module(source: &str, root: Node<'_>) -> LResult<Module> {
    Lower { source }.module(root)
}

#[derive(Clone, Copy)]
enum RestHead<'tree> {
    Gate(Node<'tree>),
    Cast(Node<'tree>),
    Trace(Node<'tree>),
}

struct Lower<'a> {
    source: &'a str,
}

impl<'a> Lower<'a> {
    fn error<T>(&self, node: Node<'_>, message: impl Into<String>) -> LResult<T> {
        Err(Diagnostic::at(message, node_span(node)))
    }

    fn unsupported<T>(&self, context: &str, node: Node<'_>) -> LResult<T> {
        self.error(
            node,
            format!("unsupported {context} syntax node `{}`", node.kind()),
        )
    }

    fn text(&self, node: Node<'_>) -> LResult<String> {
        self.source
            .get(node.byte_range())
            .map(str::to_string)
            .ok_or_else(|| Diagnostic::at("CST byte range is outside the source", node_span(node)))
    }

    fn module(&self, root: Node<'a>) -> LResult<Module> {
        if root.kind() != "source_file" {
            return self.unsupported("module", root);
        }
        let mut imports = Vec::new();
        let mut definitions = Vec::new();
        for child in syntax_children(root) {
            match child.kind() {
                "import" => imports.push(self.import(child)?),
                "definition" => definitions.push(self.definition(child)?),
                kind => return self.error(child, format!("unsupported module node `{kind}`")),
            }
        }
        Ok(Module {
            imports,
            definitions,
            span: node_span(root),
        })
    }

    fn import(&self, node: Node<'a>) -> LResult<Import> {
        let kind = if let Some(name) = node.child_by_field_name("name") {
            let name = self.text(name)?;
            if let Some(path) = node.child_by_field_name("path") {
                ImportKind::Module {
                    name,
                    path: self.knots(path)?,
                }
            } else {
                ImportKind::Library { name }
            }
        } else if let Some(mark) = node.child_by_field_name("mark") {
            ImportKind::Mark {
                mark: self.text(mark)?,
            }
        } else {
            return self.error(node, "import has neither a name nor a mark");
        };
        Ok(Import {
            kind,
            span: node_span(node),
        })
    }

    fn definition(&self, node: Node<'a>) -> LResult<Definition> {
        let scope = if node.kind() == "definition" {
            only_syntax_child(node)?
        } else {
            node
        };
        let name = self.text(required_field(scope, "name")?)?;
        let kind = match scope.kind() {
            "value_definition" => DefinitionKind::Value(self.body(scope, "value")?),
            "mold_definition" => {
                let generic = scope
                    .child_by_field_name("generic")
                    .map(|node| self.generic(node))
                    .transpose()?;
                let mut cases = Vec::new();
                for child in syntax_children(scope) {
                    if matches!(child.kind(), "name" | "generic") {
                        continue;
                    }
                    cases.push(self.mold(child)?);
                }
                if cases.is_empty() {
                    return self.error(scope, "mold definition has no molds");
                }
                DefinitionKind::Mold(MoldDefinition { generic, cases })
            }
            _ => return self.unsupported("definition", scope),
        };
        Ok(Definition {
            name,
            kind,
            span: node_span(node),
        })
    }

    fn generic(&self, node: Node<'a>) -> LResult<Generic> {
        let mut variables = Vec::new();
        for child in syntax_children(node) {
            if child.kind() != "type_variable" {
                return self.unsupported("generic parameter", child);
            }
            variables.push(self.text(child)?);
        }
        if variables.is_empty() {
            return self.error(node, "generic parameter list is empty");
        }
        Ok(Generic {
            variables,
            span: node_span(node),
        })
    }

    fn body(&self, owner: Node<'a>, field: &str) -> LResult<Expr> {
        let last = fields(owner, field).into_iter().last().ok_or_else(|| {
            Diagnostic::at(
                format!("{} has no {field} body", owner.kind()),
                node_span(owner),
            )
        })?;
        let definitions = syntax_children(owner)
            .into_iter()
            .filter(|child| child.kind() == "definition")
            .map(|child| self.definition(child))
            .collect::<LResult<Vec<_>>>()?;
        let result = self.expr(last)?;
        Ok(self.make_body(owner, definitions, result))
    }

    fn make_body(&self, owner: Node<'_>, definitions: Vec<Definition>, result: Expr) -> Expr {
        if definitions.is_empty() {
            result
        } else {
            Expr {
                kind: ExprKind::Body {
                    definitions,
                    result: Box::new(result),
                },
                span: node_span(owner),
            }
        }
    }

    fn expr(&self, node: Node<'a>) -> LResult<Expr> {
        let span = node_span(node);
        let kind = match node.kind() {
            "call" => return self.call(node, syntax_children(node)),
            "group" | "open_rune_group" => {
                let mut expression = self.expr(only_syntax_child(node)?)?;
                expression.span = span;
                return Ok(expression);
            }
            "open_group" => {
                let children = syntax_children(node);
                if children.len() == 1 {
                    let mut expression = self.expr(children[0])?;
                    expression.span = span;
                    return Ok(expression);
                }
                return self.call(node, children);
            }
            "list" | "open_list" => ExprKind::List(
                syntax_children(node)
                    .into_iter()
                    .map(|child| self.expr(child))
                    .collect::<LResult<Vec<_>>>()?,
            ),
            "tuple" | "open_tuple" => ExprKind::Tuple(self.items(node)?),
            "change" | "open_change" => ExprKind::Change {
                target: self.wing(required_field(node, "target")?)?,
                edits: self.edits(node)?,
            },
            "pair" => ExprKind::Pair {
                tag: self.text(required_field(node, "tag")?)?,
                value: Box::new(self.expr(required_field(node, "value")?)?),
            },
            "unit" => ExprKind::Unit(Box::new(self.expr(required_field(node, "value")?)?)),
            "gate" | "open_rune_gate" | "wide_gate" => ExprKind::Gate {
                sample: self.sample(required_field(node, "sample")?)?,
                body: Box::new(if node.kind() == "wide_gate" {
                    self.expr(required_field(node, "body")?)?
                } else {
                    self.body(node, "body")?
                }),
            },
            "cast" | "open_rune_cast" => ExprKind::Cast {
                mold: self.mold(required_field(node, "mold")?)?,
                value: Box::new(self.body(node, "value")?),
            },
            "trace" => ExprKind::Trace {
                value: Box::new(self.expr(required_field(node, "value")?)?),
                body: Box::new(self.body(node, "body")?),
            },
            "branch" | "rest_branch" => {
                let arms = syntax_children(node)
                    .into_iter()
                    .filter(|child| child.kind() == "arm")
                    .map(|child| self.arm(child))
                    .collect::<LResult<Vec<_>>>()?;
                if arms.is_empty() {
                    return self.error(node, "branch has no arms");
                }
                ExprKind::Branch {
                    subject: Box::new(self.expr(required_field(node, "subject")?)?),
                    arms,
                }
            }
            "rest_head" => return self.rest_head(node),
            "string" => return self.string(node),
            "application_path" => ExprKind::ApplicationPath(self.application_segments(node)?),
            "path_literal" => ExprKind::Path(self.knots(node)?),
            "reference" => ExprKind::Reference(self.wing(only_syntax_child(node)?)?),
            "constructor" => {
                let term = syntax_children(node)
                    .into_iter()
                    .find(|child| child.kind() == "term")
                    .ok_or_else(|| Diagnostic::at("constructor has no term", span))?;
                ExprKind::Constructor(self.term(term)?)
            }
            "literal" => {
                let child = only_syntax_child(node)?;
                if child.kind() == "string" {
                    let mut expression = self.string(child)?;
                    expression.span = span;
                    return Ok(expression);
                }
                ExprKind::Literal(self.literal(child)?)
            }
            "crash" => ExprKind::Crash,
            _ => return self.unsupported("expression", node),
        };
        Ok(Expr { kind, span })
    }

    fn call(&self, node: Node<'a>, children: Vec<Node<'a>>) -> LResult<Expr> {
        let span = node_span(node);
        let mut expressions = children
            .into_iter()
            .map(|child| self.expr(child))
            .collect::<LResult<Vec<_>>>()?
            .into_iter();
        let head = expressions
            .next()
            .ok_or_else(|| Diagnostic::at("call has no head", span))?;
        let arguments: Vec<_> = expressions.collect();
        if arguments.is_empty() {
            Ok(Expr {
                kind: head.kind,
                span,
            })
        } else {
            Ok(Expr {
                kind: ExprKind::Call {
                    head: Box::new(head),
                    arguments,
                },
                span,
            })
        }
    }

    fn rest_head(&self, node: Node<'a>) -> LResult<Expr> {
        let mut heads = Vec::new();
        let mut definitions = Vec::new();
        let mut last = None;
        for child in syntax_children(node) {
            match field_for(node, child).as_deref() {
                Some("sample") => heads.push(RestHead::Gate(child)),
                Some("mold") => heads.push(RestHead::Cast(child)),
                Some("value") => heads.push(RestHead::Trace(child)),
                _ if child.kind() == "definition" => definitions.push(self.definition(child)?),
                _ => last = Some(self.expr(child)?),
            }
        }
        if heads.is_empty() {
            return self.error(node, "rest body has no head");
        }
        let mut result =
            last.ok_or_else(|| Diagnostic::at("rest head has no body", node_span(node)))?;
        result = self.make_body(node, definitions, result);
        for head in heads.into_iter().rev() {
            let kind = match head {
                RestHead::Gate(sample) => ExprKind::Gate {
                    sample: self.sample(sample)?,
                    body: Box::new(result),
                },
                RestHead::Cast(mold) => ExprKind::Cast {
                    mold: self.mold(mold)?,
                    value: Box::new(result),
                },
                RestHead::Trace(value) => ExprKind::Trace {
                    value: Box::new(self.expr(value)?),
                    body: Box::new(result),
                },
            };
            result = Expr {
                kind,
                span: node_span(node),
            };
        }
        Ok(result)
    }

    fn arm(&self, node: Node<'a>) -> LResult<Arm> {
        Ok(Arm {
            pattern: self.pattern(required_field(node, "pattern")?)?,
            body: self.body(node, "value")?,
            span: node_span(node),
        })
    }

    fn items(&self, node: Node<'a>) -> LResult<Vec<Item>> {
        let children = syntax_children(node);
        let mut items = Vec::new();
        let mut index = 0;
        while index < children.len() {
            let child = children[index];
            let (face, face_node, value) =
                if child.kind() == "name" && field_for(node, child).as_deref() == Some("face") {
                    let value = children.get(index + 1).copied().ok_or_else(|| {
                        Diagnostic::at("tuple face has no value", node_span(child))
                    })?;
                    (Some(self.text(child)?), Some(child), value)
                } else {
                    (None, None, child)
                };
            let start = face_node.unwrap_or(value).start_byte();
            items.push(Item {
                face,
                value: self.expr(value)?,
                span: Span::new(Default::default(), start, value.end_byte()),
            });
            index += if face_node.is_some() { 2 } else { 1 };
        }
        Ok(items)
    }

    fn edits(&self, node: Node<'a>) -> LResult<Vec<Edit>> {
        let target = required_field(node, "target")?;
        let children = syntax_children(node);
        let mut edits = Vec::new();
        let mut index = 0;
        while index < children.len() {
            let child = children[index];
            if child.id() == target.id() {
                index += 1;
                continue;
            }
            let (scope, field, value) = if child.kind() == "edit" {
                (
                    child,
                    required_field(child, "field")?,
                    required_field(child, "value")?,
                )
            } else if child.kind() == "wing" && field_for(node, child).as_deref() == Some("field") {
                let value = children
                    .get(index + 1)
                    .copied()
                    .ok_or_else(|| Diagnostic::at("change field has no value", node_span(child)))?;
                (child, child, value)
            } else {
                return self.unsupported("change edit", child);
            };
            edits.push(Edit {
                field: self.wing(field)?,
                value: self.expr(value)?,
                span: Span::new(Default::default(), scope.start_byte(), value.end_byte()),
            });
            index += if child.kind() == "edit" { 1 } else { 2 };
        }
        Ok(edits)
    }

    fn string(&self, node: Node<'a>) -> LResult<Expr> {
        let children = syntax_children(node);
        if children.len() == 1 && children[0].kind() == "string_literal" {
            return Ok(Expr {
                kind: ExprKind::Literal(Literal::String(self.decode_string(children[0])?)),
                span: node_span(node),
            });
        }
        let mut parts = Vec::new();
        for child in children {
            match child.kind() {
                "string_start" | "string_middle" | "string_end" => {
                    parts.push(StringPart::Text(self.decode_string(child)?));
                }
                _ => parts.push(StringPart::Expr(self.expr(child)?)),
            }
        }
        Ok(Expr {
            kind: ExprKind::String(parts),
            span: node_span(node),
        })
    }

    fn application_segments(&self, node: Node<'a>) -> LResult<Vec<ApplicationSegment>> {
        let mut segments = Vec::new();
        for child in syntax_children(node) {
            match child.kind() {
                "knot" => segments.push(ApplicationSegment::Knot(self.text(child)?)),
                "application_expression_segment" => {
                    segments.push(ApplicationSegment::Expr(
                        self.expr(only_syntax_child(child)?)?,
                    ));
                }
                _ => return self.unsupported("application path segment", child),
            }
        }
        Ok(segments)
    }

    fn knots(&self, node: Node<'_>) -> LResult<Vec<String>> {
        syntax_children(node)
            .into_iter()
            .map(|child| {
                if child.kind() == "knot" {
                    self.text(child)
                } else {
                    self.unsupported("path segment", child)
                }
            })
            .collect()
    }

    fn wing(&self, node: Node<'_>) -> LResult<Vec<String>> {
        match node.kind() {
            "reference" | "mold_reference" | "sample_mold_reference" => {
                self.wing(only_syntax_child(node)?)
            }
            "wing" => {
                let mut names = Vec::new();
                for child in syntax_children(node) {
                    match child.kind() {
                        "name" => names.push(self.text(child)?),
                        "wing" => names.extend(self.wing(child)?),
                        _ => return self.unsupported("wing segment", child),
                    }
                }
                if names.is_empty() {
                    return self.error(node, "wing has no names");
                }
                Ok(names)
            }
            _ => self.unsupported("wing", node),
        }
    }

    fn literal(&self, node: Node<'a>) -> LResult<Literal> {
        match node.kind() {
            "number" | "decimal" | "hexadecimal" | "base32" => {
                Ok(Literal::Number(self.number(node)?))
            }
            "string" => {
                let child = only_syntax_child(node)?;
                if child.kind() != "string_literal" {
                    return self.error(node, "interpolated string is not a literal");
                }
                Ok(Literal::String(self.decode_string(child)?))
            }
            "string_literal" => Ok(Literal::String(self.decode_string(node)?)),
            "ship" => Ok(Literal::Ship(self.text(node)?)),
            "date" => Ok(Literal::Date(self.text(node)?)),
            "duration" => Ok(Literal::Duration(self.text(node)?)),
            "knot_literal" => Ok(Literal::Knot(
                self.text(node)?
                    .get(2..)
                    .ok_or_else(|| Diagnostic::at("malformed knot literal", node_span(node)))?
                    .to_string(),
            )),
            "term" => Ok(Literal::Term(self.term_literal(node)?)),
            "loobean" => Ok(Literal::Loobean(self.loobean(node)?)),
            "null" => Ok(Literal::Null),
            _ => self.unsupported("literal", node),
        }
    }

    fn term_literal(&self, node: Node<'a>) -> LResult<TermLiteral> {
        let text = self.text(node)?;
        let kind = if text
            .get(1..)
            .is_some_and(|body| body.starts_with(|c: char| c.is_ascii_digit()))
        {
            TermKind::Numeric
        } else {
            TermKind::Named
        };
        Ok(TermLiteral {
            value: self.term(node)?,
            kind,
        })
    }

    fn term(&self, node: Node<'a>) -> LResult<BigUint> {
        let text = self.text(node)?;
        let body = text
            .get(1..)
            .ok_or_else(|| Diagnostic::at("malformed term literal", node_span(node)))?;
        match body {
            "" | "$" | "&" => Ok(BigUint::default()),
            "|" => Ok(BigUint::from(1u8)),
            _ if body.starts_with(|c: char| c.is_ascii_digit()) => {
                BigUint::parse_bytes(body.replace('.', "").as_bytes(), 10)
                    .ok_or_else(|| Diagnostic::at("invalid numeric term", node_span(node)))
            }
            _ => Ok(BigUint::from_bytes_le(body.as_bytes())),
        }
    }

    fn number(&self, node: Node<'a>) -> LResult<NumberLiteral> {
        let scope = if node.kind() == "number" {
            only_syntax_child(node)?
        } else {
            node
        };
        let text = self.text(scope)?;
        let (digits, radix, aura) = match scope.kind() {
            "decimal" => (text.replace('.', ""), 10, NumberAura::Decimal),
            "hexadecimal" => (
                text.get(2..)
                    .ok_or_else(|| Diagnostic::at("malformed hexadecimal atom", node_span(scope)))?
                    .replace('.', ""),
                16,
                NumberAura::Hexadecimal,
            ),
            "base32" => (
                text.get(2..)
                    .ok_or_else(|| Diagnostic::at("malformed base32 atom", node_span(scope)))?
                    .replace('.', ""),
                32,
                NumberAura::Base32,
            ),
            _ => return self.unsupported("number", scope),
        };
        let value = BigUint::parse_bytes(digits.as_bytes(), radix)
            .ok_or_else(|| Diagnostic::at("invalid numeric atom", node_span(scope)))?;
        Ok(NumberLiteral { value, aura })
    }

    fn loobean(&self, node: Node<'_>) -> LResult<bool> {
        match self.text(node)?.as_str() {
            "%.y" => Ok(true),
            "%.n" => Ok(false),
            _ => self.error(node, "invalid loobean literal"),
        }
    }

    fn decode_string(&self, node: Node<'_>) -> LResult<Vec<u8>> {
        let text = self.text(node)?;
        let bytes = text.as_bytes();
        let (start, end) = match node.kind() {
            "string_literal" => (1, bytes.len().saturating_sub(1)),
            "string_start" | "string_middle" => (1, bytes.len().saturating_sub(1)),
            "string_end" => (1, bytes.len().saturating_sub(1)),
            _ => return self.unsupported("string token", node),
        };
        if start > end || end > bytes.len() {
            return self.error(node, "malformed string token");
        }
        let inner = &bytes[start..end];
        let mut decoded = Vec::with_capacity(inner.len());
        let mut index = 0;
        while index < inner.len() {
            if inner[index] != b'\\' {
                decoded.push(inner[index]);
                index += 1;
                continue;
            }
            if index + 1 >= inner.len() {
                return self.error(node, "unterminated string escape");
            }
            match inner[index + 1] {
                b'"' | b'{' | b'\\' => {
                    decoded.push(inner[index + 1]);
                    index += 2;
                }
                first if first.is_ascii_hexdigit() => {
                    if index + 2 >= inner.len() || !inner[index + 2].is_ascii_hexdigit() {
                        return self.error(node, "invalid hexadecimal string escape");
                    }
                    let escape = std::str::from_utf8(&inner[index + 1..index + 3])
                        .map_err(|_| Diagnostic::at("invalid string escape", node_span(node)))?;
                    let byte = u8::from_str_radix(escape, 16)
                        .map_err(|_| Diagnostic::at("invalid string escape", node_span(node)))?;
                    decoded.push(byte);
                    index += 3;
                }
                _ => return self.error(node, "unsupported string escape"),
            }
        }
        Ok(decoded)
    }

    fn sample(&self, node: Node<'a>) -> LResult<Sample> {
        if node.kind() == "sample" {
            return self.sample(only_syntax_child(node)?);
        }
        let span = node_span(node);
        let kind = match node.kind() {
            "sample_binding" => SampleKind::Binding(self.text(only_syntax_child(node)?)?),
            "sample_face" => SampleKind::Face {
                name: self.text(required_field(node, "face")?)?,
                mold: self.mold(required_field(node, "mold")?)?,
            },
            "sample_pun" => SampleKind::Pun(self.text(pun_name(node)?)?),
            "sample_cell" => {
                let children = syntax_children(node);
                let mut samples = Vec::new();
                let mut index = 0;
                while index < children.len() {
                    if index + 1 < children.len()
                        && children[index].end_byte() == children[index + 1].start_byte()
                        && let Some(face) = sample_binding_name(children[index])
                        && let Some(pun) = sample_pun_name(children[index + 1])
                    {
                        let name = self.text(face)?;
                        let mold_name = self.text(pun)?;
                        let mold_span = node_span(children[index + 1]);
                        samples.push(Sample {
                            kind: SampleKind::Face {
                                name,
                                mold: Mold {
                                    kind: MoldKind::Reference(vec![mold_name]),
                                    span: mold_span,
                                },
                            },
                            span: Span::new(
                                Default::default(),
                                children[index].start_byte(),
                                children[index + 1].end_byte(),
                            ),
                        });
                        index += 2;
                        continue;
                    }
                    samples.push(self.sample(children[index])?);
                    index += 1;
                }
                SampleKind::Cell(samples)
            }
            "aura"
            | "hole"
            | "noun"
            | "void"
            | "flag"
            | "term"
            | "loobean"
            | "null"
            | "path_mold"
            | "mold_apply"
            | "open_mold_apply"
            | "mold_function"
            | "type_variable"
            | "sample_mold_reference" => SampleKind::Mold(self.mold(node)?),
            _ => return self.unsupported("sample", node),
        };
        Ok(Sample { kind, span })
    }

    fn mold(&self, node: Node<'a>) -> LResult<Mold> {
        let span = node_span(node);
        let kind = match node.kind() {
            "aura" => MoldKind::Aura(self.text(node)?),
            "hole" => MoldKind::Hole,
            "noun" => MoldKind::Noun,
            "void" => MoldKind::Void,
            "flag" => MoldKind::Flag,
            "null" => MoldKind::Null,
            "term" => MoldKind::Term(self.term_literal(node)?),
            "loobean" => MoldKind::Loobean(self.loobean(node)?),
            "mold_reference" | "sample_mold_reference" => MoldKind::Reference(self.wing(node)?),
            "type_variable" => MoldKind::TypeVariable(self.text(node)?),
            "path_mold" => MoldKind::Path(self.mold_path_segments(node)?),
            "mold_apply" | "open_mold_apply" => MoldKind::Apply {
                constructor: self.wing(required_field(node, "constructor")?)?,
                arguments: fields(node, "argument")
                    .into_iter()
                    .map(|child| self.mold(child))
                    .collect::<LResult<Vec<_>>>()?,
            },
            "mold_cell" | "open_mold_cell" => MoldKind::Cell(self.mold_fields(node)?),
            "mold_function" => MoldKind::Function {
                sample: Box::new(self.mold(required_field(node, "sample")?)?),
                product: Box::new(self.mold(required_field(node, "product")?)?),
            },
            _ => return self.unsupported("mold", node),
        };
        Ok(Mold { kind, span })
    }

    fn mold_path_segments(&self, node: Node<'a>) -> LResult<Vec<MoldPathSegment>> {
        let mut segments = Vec::new();
        for child in syntax_children(node) {
            match child.kind() {
                "knot" => segments.push(MoldPathSegment::Knot(self.text(child)?)),
                "typed_segment" => {
                    let mold_node = syntax_children(child)
                        .into_iter()
                        .find(|inner| matches!(inner.kind(), "aura" | "hole"))
                        .ok_or_else(|| {
                            Diagnostic::at("typed path segment has no mold", node_span(child))
                        })?;
                    let mold = match mold_node.kind() {
                        "aura" => TypedSegmentMold::Aura(self.text(mold_node)?),
                        "hole" => TypedSegmentMold::Hole,
                        _ => return self.unsupported("typed path mold", mold_node),
                    };
                    let name = syntax_children(child)
                        .into_iter()
                        .find(|inner| inner.kind() == "name")
                        .ok_or_else(|| {
                            Diagnostic::at("typed path segment has no name", node_span(child))
                        })?;
                    segments.push(MoldPathSegment::Typed {
                        name: self.text(name)?,
                        mold,
                    });
                }
                _ => return self.unsupported("mold path segment", child),
            }
        }
        Ok(segments)
    }

    fn mold_fields(&self, node: Node<'a>) -> LResult<Vec<MoldField>> {
        let children = syntax_children(node);
        let mut fields = Vec::new();
        let mut index = 0;
        while index < children.len() {
            let child = children[index];
            if index + 1 < children.len()
                && child.kind() == "field"
                && child.end_byte() == children[index + 1].start_byte()
                && let Some(reference) = field_mold_reference(child)
                && self.wing(reference)?.len() == 1
                && let Some(pun) = field_pun_name(children[index + 1])
            {
                let name = self.text(reference)?;
                let mold_name = self.text(pun)?;
                fields.push(MoldField {
                    face: Some(name),
                    mold: Mold {
                        kind: MoldKind::Reference(vec![mold_name]),
                        span: node_span(children[index + 1]),
                    },
                    span: Span::new(
                        Default::default(),
                        child.start_byte(),
                        children[index + 1].end_byte(),
                    ),
                });
                index += 2;
                continue;
            }
            if index + 1 < children.len()
                && child.end_byte() == children[index + 1].start_byte()
                && field_mold_reference(child).is_some()
                && field_pun_name(children[index + 1]).is_some()
            {
                return self.error(child, "a mold field face is one unqualified name");
            }
            if child.kind() == "name" && field_for(node, child).as_deref() == Some("face") {
                let mold = children
                    .get(index + 1)
                    .copied()
                    .ok_or_else(|| Diagnostic::at("mold face has no value", node_span(child)))?;
                fields.push(MoldField {
                    face: Some(self.text(child)?),
                    mold: self.mold(mold)?,
                    span: Span::new(Default::default(), child.start_byte(), mold.end_byte()),
                });
                index += 2;
                continue;
            }
            fields.push(self.mold_field(child)?);
            index += 1;
        }
        Ok(fields)
    }

    fn mold_field(&self, node: Node<'a>) -> LResult<MoldField> {
        if node.kind() == "pun" {
            let name = self.text(pun_name(node)?)?;
            return Ok(MoldField {
                face: Some(name.clone()),
                mold: Mold {
                    kind: MoldKind::Reference(vec![name]),
                    span: node_span(node),
                },
                span: node_span(node),
            });
        }
        if node.kind() == "field" {
            if let Some(face) = node.child_by_field_name("face") {
                return Ok(MoldField {
                    face: Some(self.text(face)?),
                    mold: self.mold(required_field(node, "mold")?)?,
                    span: node_span(node),
                });
            }
            return self.mold_field(only_syntax_child(node)?);
        }
        Ok(MoldField {
            face: None,
            mold: self.mold(node)?,
            span: node_span(node),
        })
    }

    fn pattern(&self, node: Node<'a>) -> LResult<Pattern> {
        if node.kind() == "pattern" {
            return self.pattern(only_syntax_child(node)?);
        }
        let span = node_span(node);
        let kind = match node.kind() {
            "pattern_cell" => PatternKind::Cell(
                syntax_children(node)
                    .into_iter()
                    .map(|child| self.pattern(child))
                    .collect::<LResult<Vec<_>>>()?,
            ),
            "pattern_binding" => PatternKind::Binding(self.text(only_syntax_child(node)?)?),
            "wildcard" => PatternKind::Wildcard,
            "term" | "number" | "string_literal" | "ship" | "loobean" | "null" => {
                PatternKind::Literal(self.literal(node)?)
            }
            _ => return self.unsupported("pattern", node),
        };
        Ok(Pattern { kind, span })
    }
}

fn named(node: Node<'_>) -> Vec<Node<'_>> {
    let mut cursor = node.walk();
    node.named_children(&mut cursor).collect()
}

fn syntax_children(node: Node<'_>) -> Vec<Node<'_>> {
    named(node)
        .into_iter()
        .filter(|child| !matches!(child.kind(), "comment" | "trailing_comment"))
        .collect()
}

fn only_syntax_child(node: Node<'_>) -> LResult<Node<'_>> {
    let children = syntax_children(node);
    if children.len() == 1 {
        Ok(children[0])
    } else {
        Err(Diagnostic::at(
            format!(
                "expected one syntax child in {}, found {}",
                node.kind(),
                children.len()
            ),
            node_span(node),
        ))
    }
}

fn required_field<'tree>(node: Node<'tree>, field: &str) -> LResult<Node<'tree>> {
    node.child_by_field_name(field).ok_or_else(|| {
        Diagnostic::at(
            format!("{} has no {field} field", node.kind()),
            node_span(node),
        )
    })
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

fn pun_name(node: Node<'_>) -> LResult<Node<'_>> {
    syntax_children(node)
        .into_iter()
        .find(|child| child.kind() == "name")
        .ok_or_else(|| Diagnostic::at("pun has no name", node_span(node)))
}

fn sample_binding_name(node: Node<'_>) -> Option<Node<'_>> {
    if node.kind() != "sample" {
        return None;
    }
    let inner = only_syntax_child(node).ok()?;
    if inner.kind() != "sample_binding" {
        return None;
    }
    only_syntax_child(inner).ok()
}

fn sample_pun_name(node: Node<'_>) -> Option<Node<'_>> {
    if node.kind() != "sample" {
        return None;
    }
    let inner = only_syntax_child(node).ok()?;
    if inner.kind() != "sample_pun" {
        return None;
    }
    pun_name(inner).ok()
}

fn field_mold_reference(node: Node<'_>) -> Option<Node<'_>> {
    if node.kind() != "field" {
        return None;
    }
    let inner = only_syntax_child(node).ok()?;
    if inner.kind() != "mold_reference" {
        return None;
    }
    Some(inner)
}

fn field_pun_name(node: Node<'_>) -> Option<Node<'_>> {
    if node.kind() != "field" {
        return None;
    }
    let inner = only_syntax_child(node).ok()?;
    if inner.kind() != "pun" {
        return None;
    }
    pun_name(inner).ok()
}
