import test from 'node:test';
import assert from 'node:assert/strict';

import { CoreSyntaxError, readCore } from '../core/reader.mjs';

const name = (value) => ({ type: 'name', name: value });
const literal = (text) => ({ type: 'literal', text });

function syntaxError(source, pattern, options) {
  assert.throws(
    () => readCore(source, options),
    (error) => {
      assert.ok(error instanceof CoreSyntaxError);
      assert.ok(error instanceof SyntaxError);
      assert.equal(error.name, 'CoreSyntaxError');
      assert.equal(typeof error.line, 'number');
      assert.equal(typeof error.column, 'number');
      if (pattern) assert.match(error.message, pattern);
      return true;
    },
  );
}

test('reads opaque atom literals without changing their spelling', () => {
  const atoms = [
    '0',
    '42',
    '1.000',
    '12345678901234567890123456789012345678901234567890',
    '0xdead.beef.0123.4567.89ab.cdef',
    '0v0a.bcd2e',
    '~',
    '~zod',
    '~2026.11.8..01.02.03',
    '~s30',
    '~h1.m30',
    '~.my-post',
    '%add',
    '%1.000',
    '%$',
    '%.y',
    '%.n',
    '%1000',
    '1000',
    '0xOPAQUE',
  ];
  for (const atom of atoms) assert.deepEqual(readCore(atom), literal(atom));
});

test('reads Jibb strings with valid escapes and preserves their source text', () => {
  const strings = [
    '""',
    '"milk"',
    '"Unicode: 😀 λ"',
    String.raw`":: is text"`,
    String.raw`"line\0afeed"`,
    String.raw`"backslash\\ quote\" brace\{"`,
  ];
  for (const string of strings) assert.deepEqual(readCore(string), literal(string));
});

test('reads own, qualified, and generated names', () => {
  for (const value of ['x', 'todo-action', 'a1', 'api/todo:todo-action', '_0', '_12345678901234567890']) {
    assert.deepEqual(readCore(value), name(value));
  }
});

test('reads noun constructors and operations', () => {
  assert.deepEqual(readCore('(cons %head tail)'), {
    type: 'cons',
    head: literal('%head'),
    tail: name('tail'),
  });
  assert.deepEqual(readCore('(slot 123456789012345678901234567890 subject)'), {
    type: 'slot',
    axis: 123456789012345678901234567890n,
    value: name('subject'),
  });
  assert.deepEqual(readCore('(edit 7 target new-value)'), {
    type: 'edit',
    axis: 7n,
    target: name('target'),
    value: name('new-value'),
  });
  assert.deepEqual(readCore('(cell? value)'), { type: 'cell', value: name('value') });
  assert.deepEqual(readCore('(eq left right)'), {
    type: 'eq',
    left: name('left'),
    right: name('right'),
  });
});

test('reads control, binding, lambda, application, and effect nodes', () => {
  assert.deepEqual(readCore('(if condition yes no)'), {
    type: 'if',
    condition: name('condition'),
    then: name('yes'),
    else: name('no'),
  });
  assert.deepEqual(readCore('(let x (cons 1 2) (slot 2 x))'), {
    type: 'let',
    name: 'x',
    value: { type: 'cons', head: literal('1'), tail: literal('2') },
    body: { type: 'slot', axis: 2n, value: name('x') },
  });
  assert.deepEqual(readCore('(lam _1 (slot 2 _1))'), {
    type: 'lam',
    parameter: '_1',
    body: { type: 'slot', axis: 2n, value: name('_1') },
  });
  assert.deepEqual(readCore('(app function argument)'), {
    type: 'app',
    fn: name('function'),
    argument: name('argument'),
  });
  assert.deepEqual(readCore('(native join)'), { type: 'native', name: 'join' });
  assert.deepEqual(readCore('(crash)'), { type: 'crash' });
  assert.deepEqual(readCore('(trace "message" (crash))'), {
    type: 'trace',
    message: literal('"message"'),
    body: { type: 'crash' },
  });
});

test('reads ordered recursive lambda bindings and their body', () => {
  assert.deepEqual(readCore('(rec ((even (lam n (app odd n))) (odd (lam n (app even n)))) (app even 10))'), {
    type: 'rec',
    bindings: [
      {
        name: 'even',
        lambda: {
          type: 'lam',
          parameter: 'n',
          body: { type: 'app', fn: name('odd'), argument: name('n') },
        },
      },
      {
        name: 'odd',
        lambda: {
          type: 'lam',
          parameter: 'n',
          body: { type: 'app', fn: name('even'), argument: name('n') },
        },
      },
    ],
    body: { type: 'app', fn: name('even'), argument: literal('10') },
  });
  assert.deepEqual(readCore('(rec () ~)'), {
    type: 'rec',
    bindings: [],
    body: literal('~'),
  });
});

test('reads modules with path segments and definitions in source order', () => {
  assert.deepEqual(readCore('(module api/todo-list (def id (lam x x)) (def answer 42))'), {
    type: 'module',
    path: ['api', 'todo-list'],
    definitions: [
      { name: 'id', expression: { type: 'lam', parameter: 'x', body: name('x') } },
      { name: 'answer', expression: literal('42') },
    ],
  });
  assert.deepEqual(readCore('(module empty)'), { type: 'module', path: ['empty'], definitions: [] });
  assert.equal(readCore('(cons 1 2)').type, 'cons', 'a lone expression is accepted');
});

test('ignores comments outside strings and tracks CRLF positions', () => {
  assert.deepEqual(
    readCore(':: heading\r\n(cons :: between head and tail\r\n  1 2) :: tail'),
    { type: 'cons', head: literal('1'), tail: literal('2') },
  );
  assert.deepEqual(readCore('(trace "keep :: this" value)'), {
    type: 'trace',
    message: literal('"keep :: this"'),
    body: name('value'),
  });
});

test('rejects wrong arities for every fixed-arity form', () => {
  const invalid = [
    '(cons 1)', '(cons 1 2 3)',
    '(slot 1)', '(slot 1 x y)',
    '(edit 1 x)', '(edit 1 x y z)',
    '(cell?)', '(cell? x y)',
    '(eq x)', '(eq x y z)',
    '(if c t)', '(if c t f extra)',
    '(let x value)', '(let x value body extra)',
    '(rec ())', '(rec () body extra)',
    '(lam x)', '(lam x body extra)',
    '(app f)', '(app f x extra)',
    '(native)', '(native add extra)',
    '(crash extra)',
    '(trace message)', '(trace message body extra)',
  ];
  for (const source of invalid) syntaxError(source, /expects|argument/);
});

test('rejects invalid axes, including zero and arbitrarily large zero spellings', () => {
  for (const axis of ['0', '000', '-1', '+1', '1.0', '0x10', 'axis', '"1"']) {
    syntaxError(`(slot ${axis} value)`, /axis/i);
    syntaxError(`(edit ${axis} target value)`, /axis/i);
  }
  assert.equal(readCore('(slot 000001 value)').axis, 1n);
});

test('rejects malformed names in references and binding positions', () => {
  const invalid = ['Name', '_name', '_', 'a_b', 'a:b:c', 'api/:name', 'api/todo:', ':name', 'api//todo:name', '/api:name'];
  for (const value of invalid) {
    syntaxError(value, /name|literal/i);
    syntaxError(`(let ${value} 1 2)`, /name/i);
    syntaxError(`(lam ${value} body)`, /name/i);
    syntaxError(`(native ${value})`, /name/i);
  }
});

test('rejects duplicate and shadowing bindings in their lexical scopes', () => {
  const invalid = [
    '(let x 1 (let x 2 x))',
    '(lam x (let x 1 x))',
    '(let x 1 (lam x x))',
    '(rec ((f (lam x x)) (f (lam y y))) f)',
    '(let f 1 (rec ((f (lam x x))) f))',
    '(rec ((f (lam g g)) (g (lam x x))) f)',
    '(rec ((f (lam x x))) (lam f f))',
    '(module m (def x 1) (def x 2))',
    '(module m (def x 1) (def f (lam x x)))',
  ];
  for (const source of invalid) syntaxError(source, /Duplicate|shadows/);

  assert.equal(readCore('(cons (let x 1 x) (let x 2 x))').type, 'cons', 'sibling scopes do not shadow');
  assert.equal(readCore('(let x (lam x x) x)').type, 'let', 'a let is not in scope in its value');
});

test('rejects malformed rec forms and non-lambda right-hand sides', () => {
  const invalid = [
    '(rec bindings body)',
    '(rec (binding) body)',
    '(rec ((f)) body)',
    '(rec ((f (lam x x) extra)) body)',
    '(rec ((f 1)) body)',
    '(rec ((f (app (lam x x) 1))) body)',
    '(rec ((1 (lam x x))) body)',
  ];
  for (const source of invalid) syntaxError(source, /rec|lam|name/i);
});

test('rejects malformed modules and misplaced module forms', () => {
  const invalid = [
    '(module)',
    '(module "api/todo")',
    '(module api//todo)',
    '(module /api/todo)',
    '(module api/todo value)',
    '(module m (define x 1))',
    '(module m (def x))',
    '(module m (def x 1 2))',
    '(module m (def "x" 1))',
    '(let m 1 (module inner))',
    '()',
    '(unknown x)',
    '(module m) trailing',
    '(cons 1 2',
    ')',
    '',
    ':: only a comment',
  ];
  for (const source of invalid) syntaxError(source);
});

test('validates native names only when a registry is supplied', () => {
  assert.deepEqual(readCore('(native anything)'), { type: 'native', name: 'anything' });
  assert.deepEqual(readCore('(native add)', { nativeNames: ['add', 'join'] }), { type: 'native', name: 'add' });
  assert.deepEqual(readCore('(native api/todo:join)', { nativeNames: new Set(['api/todo:join']) }), {
    type: 'native',
    name: 'api/todo:join',
  });
  syntaxError('(native add)', /Unknown native 'add'/, { nativeNames: [] });
  syntaxError('(native adds)', /Unknown native 'adds'/, { nativeNames: new Set(['add']) });
  assert.throws(() => readCore('(native add)', { nativeNames: 'add' }), TypeError);
});

test('rejects interpolation and malformed strings', () => {
  syntaxError('"Since {day}"', /Interpolated strings/);
  syntaxError('(trace "{message}" body)', /Interpolated strings/);
  syntaxError('"unterminated', /Unterminated string/);
  syntaxError('"two\nlines"', /cannot span lines/);
  syntaxError(String.raw`"bad\q"`, /Invalid Jibb string escape/);
  syntaxError(String.raw`"bad\0A"`, /Invalid Jibb string escape/);
  syntaxError(String.raw`"bad\0"`, /Invalid Jibb string escape/);
  assert.deepEqual(readCore(String.raw`"\{"`), literal(String.raw`"\{"`));
});

test('CoreSyntaxError reports a useful one-based line and column', () => {
  const source = '(app\r\n  (native nope)\r\n  value)';
  assert.throws(
    () => readCore(source, { nativeNames: ['add'] }),
    (error) => {
      assert.ok(error instanceof CoreSyntaxError);
      assert.equal(error.line, 2);
      assert.equal(error.column, 11);
      assert.match(error.message, /Unknown native 'nope' at 2:11/);
      return true;
    },
  );
});
