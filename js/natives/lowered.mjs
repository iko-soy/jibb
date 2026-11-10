// The natives checked lowering emits, shared by the browser's modules.
// index.mjs registers these and the additional Node-facing identities.
import * as atom from './atom.mjs';
import { lent } from './list.mjs';
import { rawMapGet, rawMapPut } from './collections.mjs';
import { rawBitNot, rawDatePack, rawDateUnpack, rawParseAtom, rawSeal } from './legacy.mjs';

export const loweredNatives = Object.freeze(Object.assign(Object.create(null), {
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
}));
