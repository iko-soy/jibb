import { performance } from 'node:perf_hooks';

export function measureSync(iterations, operation) {
  if (!Number.isSafeInteger(iterations) || iterations < 1) {
    throw new Error('iterations must be a positive integer');
  }
  const samples = [];
  for (let index = 0; index < iterations; index += 1) {
    const start = performance.now();
    operation();
    samples.push(performance.now() - start);
  }
  samples.sort((left, right) => left - right);
  const median = samples.length % 2 === 1
    ? samples[(samples.length - 1) / 2]
    : (samples[samples.length / 2 - 1] + samples[samples.length / 2]) / 2;
  return {
    iterations,
    medianMs: median,
    meanMs: samples.reduce((sum, value) => sum + value, 0) / samples.length,
    minMs: samples[0],
    maxMs: samples.at(-1),
  };
}
