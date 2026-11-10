// Hoon +muk (MurmurHash3 x86_32). The ship-name permutation hashes two
// bytes; collection hashes use the atom's full little-endian byte string.
// imul and bitwise operations retain the low 32 bits without BigInt work.
export function murmur32(seed, bytes) {
  const mix = value => {
    let key = Math.imul(value, 0xcc9e2d51);
    key = (key << 15) | (key >>> 17);
    return Math.imul(key, 0x1b873593);
  };
  let hash = seed | 0;
  let offset = 0;
  while (offset + 4 <= bytes.length) {
    hash ^= mix(bytes[offset] | (bytes[offset + 1] << 8)
      | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24));
    hash = (hash << 13) | (hash >>> 19);
    hash = (Math.imul(hash, 5) + 0xe6546b64) | 0;
    offset += 4;
  }
  let tail = 0;
  for (let index = bytes.length - 1; index >= offset; index -= 1) {
    tail = (tail << 8) | bytes[index];
  }
  if (offset !== bytes.length) hash ^= mix(tail);
  hash ^= bytes.length;
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x85ebca6b);
  hash ^= hash >>> 13;
  hash = Math.imul(hash, 0xc2b2ae35);
  hash ^= hash >>> 16;
  return hash >>> 0;
}
