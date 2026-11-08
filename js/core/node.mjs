import { compileCore } from './compiler.mjs';
import * as runtime from './runtime.mjs';

export async function evaluateCore(input, { natives = {}, logger } = {}) {
  const source = compileCore(input, { nativeNames: Object.keys(natives) });
  const module = await import(
    `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`
  );
  const selectedRuntime = logger === undefined
    ? runtime
    : {
        ...runtime,
        trace: (message, body) => runtime.trace(message, body, logger),
        traceLazy: (message, body) => runtime.traceLazy(message, body, logger),
      };
  return module.evaluate(selectedRuntime, natives);
}
