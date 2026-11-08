const JNAME = /^[a-z][a-z0-9-]*$/;
const GENERATED_NAME = /^_[0-9]+$/;
const PATH = /^[a-z][a-z0-9-]*(?:\/[a-z][a-z0-9-]*)*$/;

/** A syntax error with a one-based source position. */
export class CoreSyntaxError extends SyntaxError {
  constructor(message, line, column) {
    super(`${message} at ${line}:${column}`);
    this.name = 'CoreSyntaxError';
    this.line = line;
    this.column = column;
  }
}

function errorAt(token, message) {
  throw new CoreSyntaxError(message, token.line, token.column);
}

class Lexer {
  constructor(source) {
    this.source = source;
    this.index = 0;
    this.line = 1;
    this.column = 1;
  }

  location() {
    return { line: this.line, column: this.column };
  }

  token(kind, text, location) {
    return { kind, text, ...location };
  }

  advance() {
    const character = this.source[this.index++];
    if (character === '\r') {
      if (this.source[this.index] === '\n') this.index++;
      this.line++;
      this.column = 1;
    } else if (character === '\n') {
      this.line++;
      this.column = 1;
    } else {
      this.column++;
    }
  }

  string() {
    const start = this.location();
    const startIndex = this.index;
    this.advance();

    while (this.index < this.source.length) {
      const character = this.source[this.index];
      if (character === '"') {
        this.advance();
        return this.token('string', this.source.slice(startIndex, this.index), start);
      }
      if (character === '\n' || character === '\r') {
        errorAt(this.location(), 'A Core string cannot span lines');
      }
      if (character === '{') {
        errorAt(this.location(), 'Interpolated strings are not Core atom literals');
      }
      if (character !== '\\') {
        this.advance();
        continue;
      }

      const slash = this.location();
      this.advance();
      const escape = this.source[this.index];
      if (escape === '\\' || escape === '"' || escape === '{') {
        this.advance();
      } else if (
        escape !== undefined
        && /^[0-9a-f]$/.test(escape)
        && /^[0-9a-f]$/.test(this.source[this.index + 1] ?? '')
      ) {
        this.advance();
        this.advance();
      } else {
        errorAt(slash, 'Invalid Jibb string escape');
      }
    }

    errorAt(start, 'Unterminated string literal');
  }

  tokenize() {
    const tokens = [];
    while (this.index < this.source.length) {
      const character = this.source[this.index];
      if (/\s/u.test(character)) {
        this.advance();
        continue;
      }
      if (this.source.startsWith('::', this.index)) {
        while (
          this.index < this.source.length
          && this.source[this.index] !== '\n'
          && this.source[this.index] !== '\r'
        ) {
          this.advance();
        }
        continue;
      }

      const start = this.location();
      if (character === '(' || character === ')') {
        this.advance();
        tokens.push(this.token(character, character, start));
        continue;
      }
      if (character === '"') {
        tokens.push(this.string());
        continue;
      }

      const startIndex = this.index;
      while (this.index < this.source.length) {
        const current = this.source[this.index];
        if (
          /\s/u.test(current)
          || current === '('
          || current === ')'
          || this.source.startsWith('::', this.index)
        ) {
          break;
        }
        this.advance();
      }
      tokens.push(this.token('word', this.source.slice(startIndex, this.index), start));
    }

    tokens.push(this.token('eof', '', this.location()));
    return tokens;
  }
}

function parseRaw(source) {
  const tokens = new Lexer(source).tokenize();
  let offset = 0;

  function item() {
    const token = tokens[offset++];
    if (token.kind === 'word' || token.kind === 'string') return token;
    if (token.kind === ')') errorAt(token, "Unexpected ')'");
    if (token.kind === 'eof') errorAt(token, 'Expected an expression');
    if (token.kind !== '(') errorAt(token, 'Expected an expression');

    const items = [];
    while (tokens[offset].kind !== ')') {
      if (tokens[offset].kind === 'eof') {
        errorAt(token, "Unterminated '('");
      }
      items.push(item());
    }
    offset++;
    return { kind: 'list', items, line: token.line, column: token.column };
  }

  if (tokens[offset].kind === 'eof') errorAt(tokens[offset], 'Expected a Core expression or module');
  const result = item();
  if (tokens[offset].kind !== 'eof') {
    errorAt(tokens[offset], 'Unexpected input after the top-level form');
  }
  return result;
}

function validName(text) {
  if (JNAME.test(text) || GENERATED_NAME.test(text)) return true;
  const parts = text.split(':');
  return parts.length === 2 && PATH.test(parts[0]) && JNAME.test(parts[1]);
}

function formHead(raw) {
  if (raw.kind !== 'list' || raw.items.length === 0) {
    errorAt(raw, 'Expected a nonempty Core form');
  }
  const head = raw.items[0];
  if (head.kind !== 'word') errorAt(head, 'Expected a Core form name');
  return head;
}

function isLiteralWord(text) {
  return text.startsWith('~') || text.startsWith('%') || /^[0-9]/.test(text);
}

class Builder {
  constructor(nativeNames) {
    this.nativeNames = nativeNames;
    this.scopes = [];
  }

  name(raw, description = 'name') {
    if (raw.kind !== 'word' || !validName(raw.text)) {
      errorAt(raw, `Expected a valid Core ${description}`);
    }
    return raw.text;
  }

  path(raw) {
    if (raw.kind !== 'word' || !PATH.test(raw.text)) {
      errorAt(raw, 'Expected a module path of slash-separated Jibb names');
    }
    return raw.text.split('/');
  }

  axis(raw) {
    if (raw.kind !== 'word' || !/^[0-9]+$/.test(raw.text)) {
      errorAt(raw, 'Expected an axis containing only decimal digits');
    }
    const axis = BigInt(raw.text);
    if (axis < 1n) errorAt(raw, 'A Core axis must be at least 1');
    return axis;
  }

  arity(raw, count) {
    const actual = raw.items.length - 1;
    if (actual !== count) {
      errorAt(formHead(raw), `${raw.items[0].text} expects ${count} argument${count === 1 ? '' : 's'}, got ${actual}`);
    }
  }

  visible(name) {
    return this.scopes.some((scope) => scope.has(name));
  }

  checkBindings(bindings) {
    const names = new Set();
    for (const binding of bindings) {
      if (names.has(binding.name)) {
        errorAt(binding.raw, `Duplicate binding '${binding.name}'`);
      }
      if (this.visible(binding.name)) {
        errorAt(binding.raw, `Binding '${binding.name}' shadows an enclosing binding`);
      }
      names.add(binding.name);
    }
    return names;
  }

  inScope(names, build) {
    this.scopes.push(names);
    try {
      return build();
    } finally {
      this.scopes.pop();
    }
  }

  expression(raw) {
    if (raw.kind === 'string') return { type: 'literal', text: raw.text };
    if (raw.kind === 'word') {
      if (validName(raw.text)) return { type: 'name', name: raw.text };
      if (isLiteralWord(raw.text)) return { type: 'literal', text: raw.text };
      errorAt(raw, `Invalid Core name or atom literal '${raw.text}'`);
    }

    const head = formHead(raw).text;
    const items = raw.items;
    switch (head) {
      case 'cons':
        this.arity(raw, 2);
        return { type: 'cons', head: this.expression(items[1]), tail: this.expression(items[2]) };
      case 'slot':
        this.arity(raw, 2);
        return { type: 'slot', axis: this.axis(items[1]), value: this.expression(items[2]) };
      case 'edit':
        this.arity(raw, 3);
        return {
          type: 'edit',
          axis: this.axis(items[1]),
          target: this.expression(items[2]),
          value: this.expression(items[3]),
        };
      case 'cell?':
        this.arity(raw, 1);
        return { type: 'cell', value: this.expression(items[1]) };
      case 'eq':
        this.arity(raw, 2);
        return { type: 'eq', left: this.expression(items[1]), right: this.expression(items[2]) };
      case 'if':
        this.arity(raw, 3);
        return {
          type: 'if',
          condition: this.expression(items[1]),
          then: this.expression(items[2]),
          else: this.expression(items[3]),
        };
      case 'let': {
        this.arity(raw, 3);
        const binding = { name: this.name(items[1], 'binding name'), raw: items[1] };
        const names = this.checkBindings([binding]);
        const value = this.expression(items[2]);
        const body = this.inScope(names, () => this.expression(items[3]));
        return { type: 'let', name: binding.name, value, body };
      }
      case 'rec':
        return this.rec(raw);
      case 'lam': {
        this.arity(raw, 2);
        const binding = { name: this.name(items[1], 'parameter name'), raw: items[1] };
        const names = this.checkBindings([binding]);
        return {
          type: 'lam',
          parameter: binding.name,
          body: this.inScope(names, () => this.expression(items[2])),
        };
      }
      case 'app':
        this.arity(raw, 2);
        return { type: 'app', fn: this.expression(items[1]), argument: this.expression(items[2]) };
      case 'native': {
        this.arity(raw, 1);
        const name = this.name(items[1], 'native name');
        if (this.nativeNames !== null && !this.nativeNames.has(name)) {
          errorAt(items[1], `Unknown native '${name}'`);
        }
        return { type: 'native', name };
      }
      case 'crash':
        this.arity(raw, 0);
        return { type: 'crash' };
      case 'trace':
        this.arity(raw, 2);
        return { type: 'trace', message: this.expression(items[1]), body: this.expression(items[2]) };
      case 'module':
        errorAt(raw, 'A module is only valid as the top-level form');
        break;
      default:
        errorAt(items[0], `Unknown Core form '${head}'`);
    }
  }

  rec(raw) {
    this.arity(raw, 2);
    const list = raw.items[1];
    if (list.kind !== 'list') errorAt(list, 'Expected a rec binding list');

    const bindings = list.items.map((binding) => {
      if (binding.kind !== 'list') errorAt(binding, 'Expected a rec binding (name lambda)');
      const head = binding.items[0];
      if (binding.items.length !== 2) {
        errorAt(head ?? binding, 'A rec binding expects a name and a lambda');
      }
      return {
        name: this.name(head, 'rec binding name'),
        raw: head,
        lambda: binding.items[1],
      };
    });
    const names = this.checkBindings(bindings);

    return this.inScope(names, () => {
      const built = bindings.map((binding) => {
        const lambda = this.expression(binding.lambda);
        if (lambda.type !== 'lam') errorAt(binding.lambda, 'A rec right-hand side must be a lam');
        return { name: binding.name, lambda };
      });
      return { type: 'rec', bindings: built, body: this.expression(raw.items[2]) };
    });
  }

  module(raw) {
    const items = raw.items;
    if (items.length < 2) errorAt(formHead(raw), 'module expects a path and zero or more definitions');
    const path = this.path(items[1]);
    const definitions = items.slice(2).map((definition) => {
      if (definition.kind !== 'list' || definition.items[0]?.kind !== 'word' || definition.items[0].text !== 'def') {
        errorAt(definition, 'Expected a module definition (def name expression)');
      }
      if (definition.items.length !== 3) {
        errorAt(definition.items[0], 'def expects a name and an expression');
      }
      return {
        name: this.name(definition.items[1], 'definition name'),
        raw: definition.items[1],
        expression: definition.items[2],
      };
    });
    const names = this.checkBindings(definitions);

    return this.inScope(names, () => ({
      type: 'module',
      path,
      definitions: definitions.map((definition) => ({
        name: definition.name,
        expression: this.expression(definition.expression),
      })),
    }));
  }
}

/**
 * Read one Core expression or module. Atom literals retain their exact spelling.
 * Supplying nativeNames as a Set or array enables closed-world native checking.
 */
export function readCore(source, { nativeNames } = {}) {
  if (typeof source !== 'string') throw new TypeError('Core source must be a string');
  let natives = null;
  if (nativeNames !== undefined) {
    if (!Array.isArray(nativeNames) && !(nativeNames instanceof Set)) {
      throw new TypeError('nativeNames must be a Set or an array');
    }
    natives = new Set(nativeNames);
  }

  const raw = parseRaw(source);
  const builder = new Builder(natives);
  if (raw.kind === 'list' && raw.items[0]?.kind === 'word' && raw.items[0].text === 'module') {
    return builder.module(raw);
  }
  return builder.expression(raw);
}
