//! Evaluation of checked modules.
//!
//! The evaluator is untyped, as Core is: values are atoms, cells and
//! functions, and a cell holds a function as it holds any other value. What the
//! types decide, the axes of wings, changes and projections and the printers
//! of interpolations and traces, comes from the checker's elaboration of this
//! same module.

use crate::{
    Diagnostic,
    ast::{
        DefinitionKind, Expr, ExprKind, Literal, Module, Pattern, PatternKind, Sample, SampleKind,
        Span, StringPart,
    },
    check::{self, Elaboration, Printer, Step, expression_key},
    native::NativeFunction,
    value::{
        Closure, GateValue, Noun, Runtime, Scope, Slot, Val, Value, atom, atom_bytes, cell, list,
        loobean,
    },
};
use num_bigint::BigUint;
use std::{collections::HashMap, rc::Rc};

/// Stack the evaluator may use before it stops with a diagnostic, well inside
/// the large stack it runs on: its recursion follows the program's, and a
/// frame's size depends on the build.
const STACK_BUDGET: usize = crate::STACK_SIZE - (64 << 20);

/// The address of a local, which moves down the stack as calls nest.
fn stack_position() -> usize {
    let marker = 0u8;
    std::hint::black_box(&marker) as *const u8 as usize
}

pub fn evaluate(module: &Module, entry: &str) -> Result<Value, Diagnostic> {
    let plain = crate::on_large_stack(|| -> Result<Plain, Diagnostic> {
        let (_checked, elaboration) = check::check_for_evaluation(module)?;
        let mut evaluator = Evaluator {
            elaboration: &elaboration,
            stack_base: stack_position(),
        };
        let scope = module_scope(module);
        let span = module
            .definitions
            .iter()
            .find(|definition| definition.name == entry)
            .map_or(module.span, |definition| definition.span);
        let value = evaluator.lookup(&scope, entry, span)?;
        if matches!(
            value.as_ref(),
            Runtime::Gate(_) | Runtime::Constructor(_) | Runtime::Native(_)
        ) {
            return Err(Diagnostic::at(
                format!("entry point `{entry}` requires arguments"),
                span,
            ));
        }
        Ok(Plain::new(&value))
    })?;
    Ok(plain.into_value())
}

fn module_scope(module: &Module) -> Rc<Scope<'_>> {
    let scope = Rc::new(Scope::new(None));
    for definition in &module.definitions {
        if let DefinitionKind::Value(expression) = &definition.kind {
            scope
                .slots
                .borrow_mut()
                .insert(definition.name.as_str(), Slot::Lazy(expression));
        }
    }
    scope
}

struct Evaluator<'e> {
    elaboration: &'e Elaboration,
    stack_base: usize,
}

impl<'a> Evaluator<'_> {
    /// Finds a name in the innermost scope that binds it and forces it there.
    fn lookup(
        &mut self,
        scope: &Rc<Scope<'a>>,
        name: &str,
        span: Span,
    ) -> Result<Val<'a>, Diagnostic> {
        let mut current = scope.clone();
        loop {
            let found = current
                .slots
                .borrow()
                .get_key_value(name)
                .map(|(key, slot)| (*key, slot.clone()));
            match found {
                Some((_, Slot::Done(value))) => return Ok(value),
                Some((_, Slot::Evaluating)) => {
                    return Err(Diagnostic::at(
                        format!("value dependency cycle at `{name}`"),
                        span,
                    ));
                }
                Some((key, Slot::Lazy(expression))) => {
                    current.slots.borrow_mut().insert(key, Slot::Evaluating);
                    let result = self.eval(expression, &current);
                    let slot = match &result {
                        Ok(value) => Slot::Done(value.clone()),
                        Err(_) => Slot::Lazy(expression),
                    };
                    current.slots.borrow_mut().insert(key, slot);
                    return result;
                }
                None => {
                    let Some(parent) = current.parent.clone() else {
                        return Err(Diagnostic::at(format!("unknown value `{name}`"), span));
                    };
                    current = parent;
                }
            }
        }
    }

    fn eval(&mut self, expression: &'a Expr, scope: &Rc<Scope<'a>>) -> Result<Val<'a>, Diagnostic> {
        if stack_position().abs_diff(self.stack_base) > STACK_BUDGET {
            return Err(Diagnostic::at(
                "evaluation recursed too deeply for the evaluator's stack",
                expression.span,
            ));
        }
        self.eval_inner(expression, scope)
    }

    fn checked<'m, T>(
        &self,
        table: &'m HashMap<usize, T>,
        expression: &Expr,
    ) -> Result<&'m T, Diagnostic> {
        table.get(&expression_key(expression)).ok_or_else(|| {
            Diagnostic::at(
                "internal error: the checker left this expression unelaborated",
                expression.span,
            )
        })
    }

    fn eval_inner(
        &mut self,
        expression: &'a Expr,
        scope: &Rc<Scope<'a>>,
    ) -> Result<Val<'a>, Diagnostic> {
        let span = expression.span;
        match &expression.kind {
            ExprKind::Literal(literal) => literal_value(literal, span),
            ExprKind::Native(native) => Ok(Rc::new(Runtime::Native(*native))),
            ExprKind::Constructor(tag) => Ok(Rc::new(Runtime::Constructor(tag.clone()))),
            ExprKind::Reference(names) => {
                let Some(base) = names.last() else {
                    return Err(Diagnostic::at("empty wing", span));
                };
                let value = self.lookup(scope, base, span)?;
                if names.len() == 1 {
                    return Ok(value);
                }
                walk(
                    &value,
                    self.checked(&self.elaboration.wings, expression)?,
                    span,
                )
            }
            ExprKind::Gate { sample, body } => Ok(Rc::new(Runtime::Gate(Closure {
                sample,
                body,
                environment: scope.clone(),
            }))),
            ExprKind::Call { head, arguments } => {
                if let ExprKind::Reference(names) = &head.kind
                    && names.len() == 1
                    && matches!(names[0].as_str(), "proj" | "unface")
                {
                    let source = self.eval(&arguments[0], scope)?;
                    if names[0] == "unface" {
                        return Ok(source);
                    }
                    let fields = self.checked(&self.elaboration.projections, expression)?;
                    let values = fields
                        .iter()
                        .map(|steps| walk(&source, steps, span))
                        .collect::<Result<Vec<_>, _>>()?;
                    return right_nested(values, span);
                }
                let head = self.eval(head, scope)?;
                let mut values = Vec::with_capacity(arguments.len());
                for argument in arguments {
                    values.push(self.eval(argument, scope)?);
                }
                let sample = right_nested(values, span)?;
                self.apply(&head, sample, span)
            }
            ExprKind::Cast { value, .. } => self.eval(value, scope),
            ExprKind::Tuple(items) => {
                let mut values = Vec::with_capacity(items.len());
                for item in items {
                    values.push(self.eval(&item.value, scope)?);
                }
                right_nested(values, span)
            }
            ExprKind::List(items) => {
                let mut values = Vec::with_capacity(items.len());
                for item in items {
                    values.push(self.eval(item, scope)?);
                }
                Ok(list(values.into_iter()))
            }
            ExprKind::Unit(value) => Ok(cell(atom(0u8), self.eval(value, scope)?)),
            ExprKind::Pair { tag, value } => Ok(cell(
                atom(BigUint::from_bytes_le(tag.as_bytes())),
                self.eval(value, scope)?,
            )),
            ExprKind::Branch { subject, arms } => {
                let subject = self.eval(subject, scope)?;
                for arm in arms {
                    let child = Rc::new(Scope::new(Some(scope.clone())));
                    if self.match_pattern(&arm.pattern, &subject, &child)? {
                        return self.eval(&arm.body, &child);
                    }
                }
                Err(Diagnostic::at("no branch pattern matched", span))
            }
            ExprKind::Body {
                definitions,
                result,
            } => {
                let child = Rc::new(Scope::new(Some(scope.clone())));
                for definition in definitions {
                    if let DefinitionKind::Value(value) = &definition.kind {
                        child
                            .slots
                            .borrow_mut()
                            .insert(definition.name.as_str(), Slot::Lazy(value));
                    }
                }
                self.eval(result, &child)
            }
            ExprKind::Change { target, edits } => {
                let (target_steps, edit_steps) =
                    self.checked(&self.elaboration.changes, expression)?;
                let Some(base) = target.last() else {
                    return Err(Diagnostic::at("empty wing", span));
                };
                let base = self.lookup(scope, base, span)?;
                let original = walk(&base, target_steps, span)?;
                // Every value is computed before any field changes, from the
                // original record.
                let mut values = Vec::with_capacity(edits.len());
                for edit in edits {
                    values.push(self.eval(&edit.value, scope)?);
                }
                let mut result = original;
                for (steps, value) in edit_steps.iter().zip(values) {
                    result = replace(&result, steps, value, span)?;
                }
                Ok(result)
            }
            ExprKind::Trace { value, body } => {
                let traced = self.eval(value, scope)?;
                let printer = self.checked(&self.elaboration.printers, value)?;
                let text = print(&traced, printer, value.span)?;
                eprintln!("{}", String::from_utf8_lossy(&text));
                self.eval(body, scope)
            }
            ExprKind::String(parts) => {
                let mut bytes = Vec::new();
                for part in parts {
                    match part {
                        StringPart::Text(text) => bytes.extend(text),
                        StringPart::Expr(value) => {
                            let printed = self.eval(value, scope)?;
                            let printer = self.checked(&self.elaboration.printers, value)?;
                            bytes.extend(print(&printed, printer, value.span)?);
                        }
                    }
                }
                Ok(atom(BigUint::from_bytes_le(&bytes)))
            }
            ExprKind::Path(segments) => Ok(list(
                segments
                    .iter()
                    .map(|segment| atom(BigUint::from_bytes_le(segment.as_bytes())))
                    .collect::<Vec<_>>()
                    .into_iter(),
            )),
            ExprKind::Crash => Err(Diagnostic::at("Jibb crash", span)),
            ExprKind::ApplicationPath(_) => Err(Diagnostic::at(
                "application paths are not available to the evaluator",
                span,
            )),
        }
    }

    fn apply(
        &mut self,
        head: &Val<'a>,
        sample: Val<'a>,
        span: Span,
    ) -> Result<Val<'a>, Diagnostic> {
        match head.as_ref() {
            Runtime::Gate(closure) => {
                let scope = Rc::new(Scope::new(Some(closure.environment.clone())));
                bind_sample(closure.sample, &sample, &scope, span)?;
                self.eval(closure.body, &scope)
            }
            Runtime::Constructor(tag) => Ok(cell(atom(tag.clone()), sample)),
            Runtime::Native(native) => crate::native::apply(*native, &sample, span),
            Runtime::Atom(_) | Runtime::Cell(..) => {
                Err(Diagnostic::at("attempted to call a noun", span))
            }
        }
    }

    fn match_pattern(
        &mut self,
        pattern: &'a Pattern,
        value: &Val<'a>,
        scope: &Rc<Scope<'a>>,
    ) -> Result<bool, Diagnostic> {
        match &pattern.kind {
            PatternKind::Wildcard => Ok(true),
            PatternKind::Binding(name) => {
                scope
                    .slots
                    .borrow_mut()
                    .insert(name.as_str(), Slot::Done(value.clone()));
                Ok(true)
            }
            PatternKind::Literal(literal) => {
                let expected = literal_value(literal, pattern.span)?;
                match (value.as_ref(), expected.as_ref()) {
                    (Runtime::Atom(actual), Runtime::Atom(expected)) => Ok(actual == expected),
                    (Runtime::Cell(..), _) => Ok(false),
                    _ => Err(Diagnostic::at(
                        "a pattern cannot test a function",
                        pattern.span,
                    )),
                }
            }
            PatternKind::Cell(patterns) => {
                let mut current = value.clone();
                for (index, pattern) in patterns.iter().enumerate() {
                    if index + 1 == patterns.len() {
                        return self.match_pattern(pattern, &current, scope);
                    }
                    let (head, tail) = match current.as_ref() {
                        Runtime::Cell(head, tail) => (head.clone(), tail.clone()),
                        Runtime::Atom(_) => return Ok(false),
                        _ => {
                            return Err(Diagnostic::at(
                                "a pattern cannot test a function",
                                pattern.span,
                            ));
                        }
                    };
                    if !self.match_pattern(pattern, &head, scope)? {
                        return Ok(false);
                    }
                    current = tail;
                }
                Ok(true)
            }
        }
    }
}

fn bind_sample<'a>(
    sample: &'a Sample,
    value: &Val<'a>,
    scope: &Rc<Scope<'a>>,
    span: Span,
) -> Result<(), Diagnostic> {
    match &sample.kind {
        SampleKind::Binding(name) | SampleKind::Face { name, .. } | SampleKind::Pun(name) => {
            scope
                .slots
                .borrow_mut()
                .insert(name.as_str(), Slot::Done(value.clone()));
            Ok(())
        }
        SampleKind::Mold(_) => Ok(()),
        SampleKind::Cell(samples) => {
            let mut current = value.clone();
            for (index, sample) in samples.iter().enumerate() {
                if index + 1 == samples.len() {
                    return bind_sample(sample, &current, scope, span);
                }
                let Runtime::Cell(head, tail) = current.as_ref() else {
                    return Err(Diagnostic::at(
                        "a gate's sample is not the cell it names",
                        span,
                    ));
                };
                let (head, tail) = (head.clone(), tail.clone());
                bind_sample(sample, &head, scope, span)?;
                current = tail;
            }
            Ok(())
        }
    }
}

fn literal_value<'a>(literal: &Literal, span: Span) -> Result<Val<'a>, Diagnostic> {
    let checked =
        |value: Result<BigUint, String>| value.map_err(|message| Diagnostic::at(message, span));
    Ok(match literal {
        Literal::Number(number) => atom(number.value.clone()),
        Literal::String(bytes) => atom(BigUint::from_bytes_le(bytes)),
        Literal::Knot(knot) => atom(BigUint::from_bytes_le(knot.as_bytes())),
        Literal::Term(term) => atom(term.value.clone()),
        Literal::Loobean(yes) => loobean(*yes),
        Literal::Null => atom(0u8),
        Literal::Ship(text) => atom(checked(crate::literal::ship(text))?),
        Literal::Date(text) => atom(checked(crate::literal::date(text))?),
        Literal::Duration(text) => atom(checked(crate::literal::duration(text))?),
    })
}

/// `[a b c]` is `[a [b c]]`, and a one-item cell is its item.
fn right_nested<'a>(values: Vec<Val<'a>>, span: Span) -> Result<Val<'a>, Diagnostic> {
    let mut values = values.into_iter().rev();
    let Some(mut result) = values.next() else {
        return Err(Diagnostic::at("an empty `[]` is not a valid tuple", span));
    };
    for value in values {
        result = cell(value, result);
    }
    Ok(result)
}

fn walk<'a>(value: &Val<'a>, steps: &[Step], span: Span) -> Result<Val<'a>, Diagnostic> {
    let mut current = value.clone();
    for step in steps {
        let next = match (current.as_ref(), step) {
            (Runtime::Cell(head, _), Step::Head) => head.clone(),
            (Runtime::Cell(_, tail), Step::Tail) => tail.clone(),
            _ => {
                return Err(Diagnostic::at(
                    "a record field is missing from its value",
                    span,
                ));
            }
        };
        current = next;
    }
    Ok(current)
}

fn replace<'a>(
    value: &Val<'a>,
    steps: &[Step],
    replacement: Val<'a>,
    span: Span,
) -> Result<Val<'a>, Diagnostic> {
    let Some((step, rest)) = steps.split_first() else {
        return Ok(replacement);
    };
    let Runtime::Cell(head, tail) = value.as_ref() else {
        return Err(Diagnostic::at(
            "a changed field is missing from its record",
            span,
        ));
    };
    Ok(match step {
        Step::Head => cell(replace(head, rest, replacement, span)?, tail.clone()),
        Step::Tail => cell(head.clone(), replace(tail, rest, replacement, span)?),
    })
}

fn print(value: &Val<'_>, printer: &Printer, span: Span) -> Result<Vec<u8>, Diagnostic> {
    if let Printer::Unavailable(typ) = printer {
        return Err(Diagnostic::at(
            format!("a trace has no printer for {typ}; trace an atom or a tape"),
            span,
        ));
    }
    if let Printer::Tape = printer {
        let mut bytes = Vec::new();
        let mut current = value.clone();
        loop {
            let next = match current.as_ref() {
                Runtime::Atom(end) if end.bits() == 0 => return Ok(bytes),
                Runtime::Cell(head, tail) => {
                    let Runtime::Atom(byte) = head.as_ref() else {
                        return Err(Diagnostic::at("a tape holds a cell", span));
                    };
                    bytes.extend(atom_bytes(byte));
                    tail.clone()
                }
                _ => return Err(Diagnostic::at("a tape is not a list", span)),
            };
            current = next;
        }
    }
    let Runtime::Atom(value) = value.as_ref() else {
        return Err(Diagnostic::at("a printed value is not an atom", span));
    };
    match printer {
        Printer::Text => Ok(atom_bytes(value)),
        Printer::Aura(aura) => format_aura_atom(value, aura, span),
        Printer::Tape | Printer::Unavailable(_) => unreachable!("handled above"),
    }
}

/// An atom as `(scot aura atom)` prints it.
fn format_aura_atom(value: &BigUint, aura: &str, span: Span) -> Result<Vec<u8>, Diagnostic> {
    let text = match aura {
        "ud" | "u" => Some(format_radix(value, 10, 3, "")),
        "ux" => Some(format_radix(value, 16, 4, "0x")),
        "uv" => Some(format_radix(value, 32, 5, "0v")),
        "ub" => Some(format_radix(value, 2, 4, "0b")),
        "p" => crate::literal::format_ship(value),
        "da" => crate::literal::format_date(value),
        "dr" => crate::literal::format_duration(value),
        "f" if value.bits() == 0 => Some("%.y".to_string()),
        "f" if *value == BigUint::from(1u8) => Some("%.n".to_string()),
        "f" => None,
        _ => {
            return Err(Diagnostic::at(
                format!("interpolation has no printer for @{aura}"),
                span,
            ));
        }
    };
    text.map(String::into_bytes)
        .ok_or_else(|| Diagnostic::at(format!("the atom is not a valid @{aura}"), span))
}

fn format_radix(value: &BigUint, radix: u32, group: usize, prefix: &str) -> String {
    let digits = value.to_str_radix(radix);
    let mut result = String::from(prefix);
    for (index, character) in digits.chars().enumerate() {
        if index != 0 && (digits.len() - index).is_multiple_of(group) {
            result.push('.');
        }
        result.push(character);
    }
    result
}

/// An evaluated result that can leave the evaluation thread: its nodes in
/// post-order, sharing as the value shared, so a child comes before its cell.
struct Plain {
    nodes: Vec<PlainNode>,
    root: usize,
}

enum PlainNode {
    Atom(BigUint),
    Cell(usize, usize),
    Gate,
    Constructor(BigUint),
    Native(NativeFunction),
}

impl Plain {
    fn new(root: &Val<'_>) -> Self {
        let mut nodes = Vec::new();
        let mut indices = HashMap::<*const Runtime<'_>, usize>::new();
        let mut stack = vec![(root.clone(), false)];
        while let Some((value, expanded)) = stack.pop() {
            let key = Rc::as_ptr(&value);
            if indices.contains_key(&key) {
                continue;
            }
            let node = match value.as_ref() {
                Runtime::Cell(head, tail) if !expanded => {
                    stack.push((value.clone(), true));
                    stack.push((tail.clone(), false));
                    stack.push((head.clone(), false));
                    continue;
                }
                Runtime::Cell(head, tail) => {
                    PlainNode::Cell(indices[&Rc::as_ptr(head)], indices[&Rc::as_ptr(tail)])
                }
                Runtime::Atom(value) => PlainNode::Atom(value.clone()),
                Runtime::Gate(_) => PlainNode::Gate,
                Runtime::Constructor(tag) => PlainNode::Constructor(tag.clone()),
                Runtime::Native(native) => PlainNode::Native(*native),
            };
            indices.insert(key, nodes.len());
            nodes.push(node);
        }
        let root = indices[&Rc::as_ptr(root)];
        Self { nodes, root }
    }

    fn into_value(self) -> Value {
        let mut functions = Vec::with_capacity(self.nodes.len());
        let mut nouns: Vec<Option<Rc<Noun>>> = Vec::with_capacity(self.nodes.len());
        for node in &self.nodes {
            let (function, noun) = match node {
                PlainNode::Atom(value) => (false, Some(Noun::atom(value.clone()))),
                PlainNode::Cell(head, tail) => {
                    let function = functions[*head] || functions[*tail];
                    let noun = match (&nouns[*head], &nouns[*tail]) {
                        (Some(head), Some(tail)) => Some(Noun::cell(head.clone(), tail.clone())),
                        _ => None,
                    };
                    (function, noun)
                }
                PlainNode::Gate | PlainNode::Constructor(_) | PlainNode::Native(_) => (true, None),
            };
            functions.push(function);
            nouns.push(noun);
        }
        self.value(self.root, &nouns)
    }

    fn value(&self, index: usize, nouns: &[Option<Rc<Noun>>]) -> Value {
        if let Some(noun) = &nouns[index] {
            return Value::Noun(noun.clone());
        }
        match &self.nodes[index] {
            PlainNode::Gate => Value::Gate(Rc::new(GateValue::new())),
            PlainNode::Constructor(tag) => Value::Constructor(tag.clone()),
            PlainNode::Native(native) => Value::Native(*native),
            PlainNode::Atom(_) => unreachable!("atoms are nouns"),
            PlainNode::Cell(..) => {
                let mut items = Vec::new();
                let mut current = index;
                while let PlainNode::Cell(head, tail) = &self.nodes[current] {
                    items.push(self.value(*head, nouns));
                    current = *tail;
                }
                items.push(self.value(current, nouns));
                Value::Cell(items)
            }
        }
    }
}
