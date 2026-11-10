// The natives checked lowering emits, which the browser registers: a page's
// islands need no others. index.mjs registers these and the rest.
import * as atom from './atom.mjs';
import { lent } from './list.mjs';
import { rawMapGet, rawMapPut } from './collections.mjs';
import { rawBitNot, rawDatePack, rawDateUnpack, rawParseAtom, rawSeal } from './legacy.mjs';
import { defineNative } from './registry.mjs';

export const loweredNatives = {
  add: atom.add,
  dec: atom.dec,
  gth: atom.gth,
  eq: atom.eq,
  lent,
  trip: atom.tripBytes,
  tuba: atom.tubaBytes,
  crip: atom.cripBytes,
  tufa: atom.tufaCodepoints,
  join: atom.join,
  scot: atom.scot,
  scow: atom.scow,
  year: rawDatePack,
  yore: rawDateUnpack,
  'parse-atom': rawParseAtom,
  'bit-not': rawBitNot,
  'map-get': rawMapGet,
  'map-put': rawMapPut,
  'raw-seal': rawSeal,
};
for (const [name, implementation] of Object.entries(loweredNatives)) {
  defineNative(name, implementation);
}
