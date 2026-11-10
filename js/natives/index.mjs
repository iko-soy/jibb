import * as atom from './atom.mjs';
import * as list from './list.mjs';
import { cue, jam, validateNoun } from './codec.mjs';
import { rawMapGet, rawMapPut } from './collections.mjs';
import { rawBitNot, rawDatePack, rawDateUnpack, rawParseAtom, rawSeal } from './legacy.mjs';
import { defineNative } from './registry.mjs';
import { loweredNatives } from './lowered.mjs';

const implementations = {
  ...loweredNatives,
  sub: atom.sub,
  mul: atom.mul,
  inc: atom.inc,
  gte: atom.gte,
  lth: atom.lth,
  lte: atom.lte,
  not: atom.not,
  max: atom.max,
  min: atom.min,
  'raw-add.core': atom.add,
  'raw-dec.core': atom.dec,
  'raw-gth.core': atom.gth,
  'raw-eq.core': atom.eq,
  'raw-trip.core': atom.tripBytes,
  'raw-tuba.core': atom.tubaBytes,
  'raw-crip.core': atom.cripBytes,
  'raw-tufa.core': atom.tufaCodepoints,
  'raw-format-knot.core': atom.scot,
  'raw-format-tape.core': atom.scow,
  'raw-map-get.core': rawMapGet,
  'raw-map-put.core': rawMapPut,
  'raw-date-pack.core': rawDatePack,
  'raw-date-unpack.core': rawDateUnpack,
  'raw-parse-atom.core': rawParseAtom,
  'raw-bit-not.core': rawBitNot,
  'raw-seal.core': rawSeal,
  jam,
  cue,
  'validate-noun': validateNoun,
};
for (const [name, implementation] of Object.entries(implementations)) {
  defineNative(name, implementation);
}
// lent is already in the lowered-native table.
for (const [name, implementation] of Object.entries(list)) {
  if (name !== 'lent') defineNative(name, implementation);
}

export { createNativeRegistry, defineNative, nativeNames } from './registry.mjs';
export { cue, decodeUw, deUw, encodeUw, enUw, jam, validateNoun } from './codec.mjs';
export * from './atom.mjs';
export * from './list.mjs';
export * from './collections.mjs';
export * from './legacy.mjs';
