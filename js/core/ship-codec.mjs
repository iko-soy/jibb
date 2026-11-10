import { murmur32 } from './hash.mjs';

// The round shared by the two directions of Hoon's ship-name permutation.
const RAKU = [0xb76d5eed, 0xee281300, 0x85bcae01, 0x4b387af7];

export function shipRound(round, value) {
  return murmur32(RAKU[round], [value & 0xff, (value >>> 8) & 0xff]);
}
