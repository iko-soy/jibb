use crate::{
    Diagnostic,
    ast::{Mold, MoldDefinition, MoldField, MoldKind, Span},
};
use num_bigint::BigUint;

pub struct HoonModule {
    pub definitions: Vec<crate::ast::Definition>,
    pub imports: Vec<String>,
}

pub fn read_sur(source: &str, face: &str, span: Span) -> Result<HoonModule, Diagnostic> {
    let tokens = lex(source)?;
    let mut parser = Parser {
        tokens,
        position: 0,
        face,
        span,
    };
    parser.module()
}

pub fn read_mark(source: &str, mark: &str, span: Span) -> Result<HoonModule, Diagnostic> {
    let tokens = lex(source)?;
    let mut parser = Parser {
        tokens,
        position: 0,
        face: mark,
        span,
    };
    let imports = parser.imports()?;
    let mut definition = parser.mark_mold()?;
    definition.name = mark.to_string();
    Ok(HoonModule {
        definitions: vec![definition],
        imports,
    })
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum Token {
    Word(String),
    Aura(String),
    Term(BigUint),
    Null,
    Void,
    Flag,
    Noun,
    LeftParen,
    RightParen,
    LeftBracket,
    RightBracket,
    Face,
    EndUnion,
}

fn lex(source: &str) -> Result<Vec<Token>, Diagnostic> {
    let mut tokens = Vec::new();
    let mut chars = source.char_indices().peekable();
    while let Some((index, character)) = chars.next() {
        match character {
            ':' if chars.peek().is_some_and(|(_, next)| *next == ':') => {
                for (_, next) in chars.by_ref() {
                    if next == '\n' {
                        break;
                    }
                }
            }
            character if character.is_whitespace() => {}
            '(' => tokens.push(Token::LeftParen),
            ')' => tokens.push(Token::RightParen),
            '[' => tokens.push(Token::LeftBracket),
            ']' => tokens.push(Token::RightBracket),
            '?' => tokens.push(Token::Flag),
            '*' => tokens.push(Token::Noun),
            '~' => tokens.push(Token::Null),
            '!' => {
                if chars.next().is_some_and(|(_, next)| next == '!') {
                    tokens.push(Token::Void);
                } else {
                    return Err(Diagnostic::at(
                        "unsupported Hoon `!` form",
                        index_span(index),
                    ));
                }
            }
            '=' => {
                if chars.peek().is_some_and(|(_, next)| *next == '=') {
                    chars.next();
                    tokens.push(Token::EndUnion);
                } else {
                    tokens.push(Token::Face);
                }
            }
            '@' => {
                let mut aura = String::from("@");
                while let Some((_, next)) = chars.peek() {
                    if next.is_ascii_alphabetic() {
                        aura.push(*next);
                        chars.next();
                    } else {
                        break;
                    }
                }
                tokens.push(Token::Aura(aura));
            }
            '%' => {
                if let Some(Token::Word(previous)) = tokens.last_mut()
                    && (previous == "$" || previous == "|" || previous == "/")
                {
                    previous.push('%');
                    continue;
                }
                let mut term = String::new();
                while let Some((_, next)) = chars.peek() {
                    if next.is_ascii_alphanumeric() || matches!(next, '.' | '-' | '$' | '&' | '|') {
                        term.push(*next);
                        chars.next();
                    } else {
                        break;
                    }
                }
                let value = if term.starts_with(|character: char| character.is_ascii_digit()) {
                    BigUint::parse_bytes(term.replace('.', "").as_bytes(), 10).ok_or_else(|| {
                        Diagnostic::at("invalid Hoon numeric term", index_span(index))
                    })?
                } else {
                    BigUint::from_bytes_le(term.as_bytes())
                };
                tokens.push(Token::Term(value));
            }
            _ => {
                let mut word = String::from(character);
                while let Some((_, next)) = chars.peek() {
                    if next.is_ascii_alphanumeric()
                        || matches!(next, '-' | '_' | '$' | '+' | '/' | '|' | ':' | '@' | '^')
                    {
                        word.push(*next);
                        chars.next();
                    } else {
                        break;
                    }
                }
                tokens.push(Token::Word(word));
            }
        }
    }
    Ok(tokens)
}

fn index_span(index: usize) -> Span {
    Span::new(Default::default(), index, index + 1)
}

struct Parser<'a> {
    tokens: Vec<Token>,
    position: usize,
    face: &'a str,
    span: Span,
}

impl Parser<'_> {
    fn module(&mut self) -> Result<HoonModule, Diagnostic> {
        let imports = self.imports()?;
        let mut definitions = Vec::new();
        while self.position < self.tokens.len() {
            match self.take_word()? {
                "--" => {}
                "|%" => {}
                "$~" => {
                    self.mold()?;
                }
                "+$" => definitions.push(self.definition()?),
                other => {
                    return Err(Diagnostic::at(
                        format!("unsupported Hoon construct `{other}`"),
                        self.span,
                    ));
                }
            }
        }
        let renames = definitions
            .iter()
            .map(|definition| {
                (
                    definition.name.clone(),
                    format!("{}__{}", self.face, definition.name),
                )
            })
            .collect::<std::collections::BTreeMap<_, _>>();
        for definition in &mut definitions {
            definition.name = renames[&definition.name].clone();
            crate::loader::rewrite_definition_for_hoon(definition, &renames);
        }
        Ok(HoonModule {
            definitions,
            imports,
        })
    }

    fn imports(&mut self) -> Result<Vec<String>, Diagnostic> {
        let mut imports = Vec::new();
        while self.peek_word() == Some("/-") {
            self.position += 1;
            imports.push(self.take_word()?.to_string());
        }
        Ok(imports)
    }

    fn definition(&mut self) -> Result<crate::ast::Definition, Diagnostic> {
        let name = self.take_word()?.to_string();
        let mold = self.mold()?;
        let cases = match mold.kind {
            MoldKind::Union(cases) => cases,
            _ => vec![mold],
        };
        Ok(crate::ast::Definition {
            name,
            kind: crate::ast::DefinitionKind::Mold(MoldDefinition {
                generic: None,
                cases,
            }),
            span: self.span,
        })
    }

    fn mark_mold(&mut self) -> Result<crate::ast::Definition, Diagnostic> {
        while self.position < self.tokens.len() {
            if self.peek_word() == Some("noun") {
                self.position += 1;
                return self.definition_named("noun".to_string());
            }
            self.position += 1;
        }
        Err(Diagnostic::at("Hoon mark has no `++ noun` mold", self.span))
    }

    fn definition_named(&mut self, name: String) -> Result<crate::ast::Definition, Diagnostic> {
        let mold = self.mold()?;
        let cases = match mold.kind {
            MoldKind::Union(cases) => cases,
            _ => vec![mold],
        };
        Ok(crate::ast::Definition {
            name,
            kind: crate::ast::DefinitionKind::Mold(MoldDefinition {
                generic: None,
                cases,
            }),
            span: self.span,
        })
    }

    fn mold(&mut self) -> Result<Mold, Diagnostic> {
        let span = self.span;
        let token = self.tokens.get(self.position).cloned();
        self.position += 1;
        let kind = match token {
            Some(Token::Void) => MoldKind::Void,
            Some(Token::Noun) => MoldKind::Noun,
            Some(Token::Flag) => MoldKind::Flag,
            Some(Token::Null) => MoldKind::Null,
            Some(Token::Aura(aura)) => {
                if aura == "@" {
                    MoldKind::Aura(String::new())
                } else {
                    MoldKind::Aura(aura)
                }
            }
            Some(Token::Term(value)) => MoldKind::Term(crate::ast::TermLiteral {
                value,
                kind: crate::ast::TermKind::Named,
            }),
            Some(Token::Word(word))
                if word == "$%" || word == "$?" || word == "$^" || word == "$@" =>
            {
                return self.union();
            }
            Some(Token::Word(word)) if word == "$|" => return self.mold(),
            Some(Token::LeftParen) => {
                let constructor = self.take_word()?.to_string();
                let mut arguments = Vec::new();
                while !matches!(self.tokens.get(self.position), Some(Token::RightParen)) {
                    arguments.push(self.mold()?);
                }
                self.position += 1;
                MoldKind::Apply {
                    constructor: vec![constructor],
                    arguments,
                }
            }
            Some(Token::LeftBracket) => {
                let mut fields = Vec::new();
                while !matches!(self.tokens.get(self.position), Some(Token::RightBracket)) {
                    let mut face = None;
                    if matches!(self.tokens.get(self.position), Some(Token::Word(_)))
                        && matches!(self.tokens.get(self.position + 1), Some(Token::Face))
                    {
                        face = Some(self.take_word()?.to_string());
                        self.position += 1;
                    }
                    fields.push(MoldField {
                        face,
                        mold: self.mold()?,
                        span,
                    });
                }
                self.position += 1;
                MoldKind::Cell(fields)
            }
            Some(Token::Word(name)) => MoldKind::Reference(vec![self.reference(&name)]),
            _ => {
                return Err(Diagnostic::at(
                    format!(
                        "unsupported Hoon mold at token {}: {:?}",
                        self.position, token
                    ),
                    span,
                ));
            }
        };
        Ok(Mold { kind, span })
    }

    fn union(&mut self) -> Result<Mold, Diagnostic> {
        let grouped = matches!(self.tokens.get(self.position), Some(Token::LeftParen));
        if grouped {
            self.position += 1;
        }
        let mut cases = Vec::new();
        while self.position < self.tokens.len() {
            if matches!(self.tokens.get(self.position), Some(Token::EndUnion)) {
                self.position += 1;
                break;
            }
            if grouped && matches!(self.tokens.get(self.position), Some(Token::RightParen)) {
                self.position += 1;
                break;
            }
            if matches!(self.tokens.get(self.position), Some(Token::Word(word)) if word == "+$" || word == "--")
            {
                break;
            }
            cases.push(self.mold()?);
        }
        if cases.is_empty() {
            return Err(Diagnostic::at("empty Hoon union", self.span));
        }
        Ok(Mold {
            kind: MoldKind::Union(cases),
            span: self.span,
        })
    }

    fn reference(&self, name: &str) -> String {
        if let Some((module, name)) = name.split_once(':') {
            format!("{name}__{module}")
        } else {
            name.to_string()
        }
    }

    fn peek_word(&self) -> Option<&str> {
        match self.tokens.get(self.position) {
            Some(Token::Word(word)) => Some(word),
            _ => None,
        }
    }

    fn take_word(&mut self) -> Result<&str, Diagnostic> {
        let position = self.position;
        self.position += 1;
        match self.tokens.get(position) {
            Some(Token::Word(word)) => Ok(word),
            _ => Err(Diagnostic::at(
                format!(
                    "expected a Hoon word at token {}: {:?}",
                    position,
                    self.tokens.get(position)
                ),
                self.span,
            )),
        }
    }
}
