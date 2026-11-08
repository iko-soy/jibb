import { cases } from './cases.mjs';
import { measureSync } from './timing.mjs';
import { compileCore } from '../core/compiler.mjs';
import { readCore } from '../core/reader.mjs';
import * as runtime from '../core/runtime.mjs';
import { emitCore } from '../nock/emitter.mjs';
import { applyNock, runNock } from '../nock/interpreter.mjs';

function argumentsFor(name) {
  let warmup = 3;
  let iterations = 20;
  let json = false;
  for (let index = 2; index < process.argv.length; index += 1) {
    const argument = process.argv[index];
    if (argument === '--json') {
      json = true;
    } else if (argument === '--case') {
      name = process.argv[++index];
    } else if (argument === '--warmups') {
      warmup = positive(process.argv[++index], argument);
    } else if (argument === '--iterations') {
      iterations = positive(process.argv[++index], argument);
    } else {
      throw new Error(`unknown argument ${argument}`);
    }
  }
  return { name, warmup, iterations, json };
}

function positive(value, option) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1) {
    throw new Error(`${option} expects a positive integer`);
  }
  return parsed;
}

function applyArguments(value, args, apply) {
  let current = value;
  for (const argument of args) current = apply(current, argument);
  return current;
}

async function generatedProgram(test) {
  const source = compileCore(test.source, { nativeNames: Object.keys(test.natives) });
  const module = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
  return () => applyArguments(
    module.evaluate(runtime, test.natives),
    test.arguments,
    runtime.apply,
  );
}

function nockProgram(test) {
  const ast = readCore(test.source, { nativeNames: Object.keys(test.natives) });
  const formula = emitCore(ast, { nativeNames: Object.keys(test.natives) });
  return () => applyArguments(
    runNock(0n, formula, test.natives),
    test.arguments,
    (gate, argument) => applyNock(gate, argument, test.natives),
  );
}

function verify(test, generated, nock) {
  const jsOutcome = generated();
  const nockOutcome = nock();
  if (runtime.same(jsOutcome, test.expected) !== 0n) {
    throw new Error(`${test.name}: generated JavaScript returned the wrong noun`);
  }
  if (runtime.same(nockOutcome, test.expected) !== 0n) {
    throw new Error(`${test.name}: Nock returned the wrong noun`);
  }
  if (runtime.same(jsOutcome, nockOutcome) !== 0n) {
    throw new Error(`${test.name}: backends disagree`);
  }
}

async function benchmark(test, options) {
  const generated = await generatedProgram(test);
  const nock = nockProgram(test);
  verify(test, generated, nock);
  for (let index = 0; index < options.warmup; index += 1) {
    generated();
    nock();
  }
  const names = Object.keys(test.natives);
  return {
    name: test.name,
    emission: {
      javascript: measureSync(options.iterations, () => compileCore(test.source, { nativeNames: names })),
      nock: measureSync(options.iterations, () => emitCore(readCore(test.source, { nativeNames: names }), { nativeNames: names })),
    },
    execution: {
      javascript: measureSync(options.iterations, generated),
      nock: measureSync(options.iterations, nock),
    },
  };
}

function milliseconds(value) {
  return `${value.toFixed(3)} ms`;
}

const options = argumentsFor();
const selected = cases.filter((test) => !options.name || test.name.includes(options.name));
if (selected.length === 0) throw new Error(`no benchmark matches ${options.name}`);
const results = [];
for (const test of selected) results.push(await benchmark(test, options));

if (options.json) {
  console.log(JSON.stringify({ warmup: options.warmup, cases: results }, null, 2));
} else {
  for (const result of results) {
    const { emission, execution } = result;
    const ratio = execution.nock.medianMs / execution.javascript.medianMs;
    console.log(result.name);
    console.log(`  emission:  JavaScript ${milliseconds(emission.javascript.medianMs)}, Nock ${milliseconds(emission.nock.medianMs)}`);
    console.log(`  execution: JavaScript ${milliseconds(execution.javascript.medianMs)}, Nock ${milliseconds(execution.nock.medianMs)} (${ratio.toFixed(2)}x)`);
    console.log(`  means:     JavaScript ${milliseconds(execution.javascript.meanMs)}, Nock ${milliseconds(execution.nock.meanMs)}`);
  }
}
