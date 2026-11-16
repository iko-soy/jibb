// Hoon's atom syntax, as the pinned ship's Hoon (%135) parses it, in
// hoon.hoon's ++so, ++ag and ++ab: +nuck for a whole literal, and +slaw for
// one aura. Each rule is Hoon's, ordered choice and greedy repetition
// included, so a text reads here exactly as it does on the ship. Also the
// codecs its printer shares: ship names, @uc's base58check and IEEE floats.
import { CoreCrash } from './runtime.mjs';
import { shipRound } from './ship-codec.mjs';
import { PREFIXES, SUFFIXES } from './syllables.mjs';

const MAX_U32 = 0xffff_ffffn;
const MAX_U64 = 0xffff_ffff_ffff_ffffn;
export const DATE_OFFSET = 292_277_024_400n;
// @uw's and @uc's digits, by value.
export const UW = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-~';
export const BASE58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

const PREFIX = new Map(PREFIXES.map((name, value) => [name, BigInt(value)]));
const SUFFIX = new Map(SUFFIXES.map((name, value) => [name, BigInt(value)]));

// Where Hoon's reading crashes, as +year does on a BC year 0, this does
// too; a reader under mule, as parse-atom's, takes it as no value.
const crash = (message) => { throw new CoreCrash(message); };

// Text at i that a sticky pattern matches, and where it ends.
function at(pattern, s, i) {
  pattern.lastIndex = i;
  const match = pattern.exec(s);
  return match && [match, pattern.lastIndex];
}

// The value of digits in base radix, ignoring dots and the gaps after
// them, in time linear in their number but for base 58's: BigInt reads
// decimal and binary itself.
function digits(text, radix, alphabet) {
  const plain = text.replace(DOTS, '');
  if (radix === 10) return BigInt(plain);
  if (radix !== 58) {
    const width = Math.log2(radix);
    return BigInt(`0b0${[...plain].map(digit => alphabet.indexOf(digit).toString(2).padStart(width, '0')).join('')}`);
  }
  let value = 0n;
  for (const digit of plain) value = value * 58n + BigInt(alphabet.indexOf(digit));
  return value;
}

const DECIMAL = '0123456789';
const HEX = '0123456789abcdef';
// ++gap: a line's end, two spaces, or a :: comment, then any more of them.
// ++dog, a number's dot, ++dof, @q's hyphen, and ++doh, a ship's --, may
// each be followed by one, so a number can go on on the next line.
const COMMENT = '::[^\\x00-\\x1f\\x7f]*(?:\\n|$)';
const GAP = `(?:\\n|[ \\n](?:[ \\n]|${COMMENT})|${COMMENT})(?:${COMMENT}|[ \\n])*`;
const DOG = `\\.(?:${GAP})?`;
const DOTS = new RegExp(DOG, 'g');
// Each rule's text, as ++ag reads it: ape takes a lone 0 first.
const grouped = (first, later) => new RegExp(`0|${first}(?:${DOG}${later})*`, 'y');
const DEM = grouped('[1-9][0-9]{0,2}', '[0-9]{3}');
// slaw's %ud is a jet, which takes no gap after a dot.
const DEM_JET = /0|[1-9][0-9]{0,2}(?:\.[0-9]{3})*/y;
const DIM = /0|[1-9][0-9]*/y;
const HEXAG = grouped('[1-9a-f][0-9a-fA-F]{0,3}', '[0-9a-f]{4}');
const VIZ = grouped('[1-9a-v][0-9a-v]{0,4}', '[0-9a-v]{5}');
const WIZ = grouped('[1-9a-zA-Z~-][0-9a-zA-Z~-]{0,4}', '[0-9a-zA-Z~-]{5}');
const BAY = grouped('1[01]{0,3}', '[01]{4}');
const FIM = /[1-9A-HJ-NP-Za-km-z]+/y;
const SYM = /[a-z][a-z0-9-]*/y;
const URS = /[0-9a-z.~_-]*/y;

// A rule for a number: its value and where it ends, or null. Hex digits
// past the first may be capitals.
function number(pattern, radix, alphabet, fold = text => text) {
  return (s, i) => {
    const found = at(pattern, s, i);
    return found && [digits(fold(found[0][0]), radix, alphabet), found[1]];
  };
}
const dem = number(DEM, 10, DECIMAL);
const demJet = number(DEM_JET, 10, DECIMAL);
const dim = number(DIM, 10, DECIMAL);
const hex = number(HEXAG, 16, HEX, text => text.toLowerCase());
const viz = number(VIZ, 32, UW);
const wiz = number(WIZ, 64, UW);
const bay = number(BAY, 2, DECIMAL);
const sym = (s, i) => {
  const found = at(SYM, s, i);
  return found && [cordOf(found[0][0]), found[1]];
};
const urs = (s, i) => {
  const found = at(URS, s, i);
  return [cordOf(found[0][0]), found[1]];
};

// ++fa: Bitcoin's base58check, whose four check bytes are of a double
// SHA-256 of the value's big-endian bytes, padded to 21.
function bytesOf(value) {
  const bytes = [];
  for (let rest = value; rest > 0n; rest >>= 8n) bytes.push(Number(rest & 0xffn));
  return bytes;
}
export const checkPad = value => Math.max(0, 21 - bytesOf(value).length);
export function check58(value) {
  const message = [...new Array(checkPad(value)).fill(0), ...bytesOf(value).reverse()];
  const [a, b, c, d] = sha256(sha256(message));
  return BigInt(((a << 24) | (b << 16) | (c << 8) | d) >>> 0);
}
const fim = (s, i) => {
  const found = at(FIM, s, i);
  if (!found) return null;
  const whole = digits(found[0][0], 58, BASE58);
  const value = whole >> 32n;
  return check58(value) === (whole & MAX_U32) ? [value, found[1]] : null;
};

// SHA-256 of a byte list.
const K = [];
for (let n = 2, found = 0; found < 64; n += 1) {
  let prime = true;
  for (let d = 2; d * d <= n; d += 1) if (n % d === 0) prime = false;
  if (prime) K[found++] = Math.floor((Math.cbrt(n) % 1) * 2 ** 32) | 0;
}
function sha256(bytes) {
  const words = [];
  const length = bytes.length;
  const padded = [...bytes, 0x80];
  while (padded.length % 64 !== 56) padded.push(0);
  for (let shift = 56; shift >= 0; shift -= 8) padded.push(Math.floor((length * 8) / 2 ** shift) & 0xff);
  for (let index = 0; index < padded.length; index += 4) {
    words.push((padded[index] << 24) | (padded[index + 1] << 16) | (padded[index + 2] << 8) | padded[index + 3]);
  }
  const hash = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  const rotate = (value, count) => (value >>> count) | (value << (32 - count));
  for (let block = 0; block < words.length; block += 16) {
    const w = words.slice(block, block + 16);
    for (let t = 16; t < 64; t += 1) {
      const s0 = rotate(w[t - 15], 7) ^ rotate(w[t - 15], 18) ^ (w[t - 15] >>> 3);
      const s1 = rotate(w[t - 2], 17) ^ rotate(w[t - 2], 19) ^ (w[t - 2] >>> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0;
    }
    let [a, b, c, d, e, f, g, h] = hash;
    for (let t = 0; t < 64; t += 1) {
      const t1 = (h + (rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25)) + ((e & f) ^ (~e & g)) + K[t] + w[t]) | 0;
      const t2 = ((rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
      [h, g, f, e, d, c, b, a] = [g, f, e, (d + t1) | 0, c, b, a, (t1 + t2) | 0];
    }
    [a, b, c, d, e, f, g, h].forEach((value, index) => { hash[index] = (hash[index] + value) | 0; });
  }
  return hash.flatMap(value => [value >>> 24, (value >>> 16) & 0xff, (value >>> 8) & 0xff, value & 0xff]);
}

// ++ob: the Feistel cipher that scrambles planets and moons, +fein, and
// its inverse, +fynd.
function feistel(input) {
  const a = 65_535;
  const b = 65_536;
  let ell = input % a;
  let arr = Math.floor(input / a);
  for (let round = 1; round <= 4; round += 1) {
    const temporary = (shipRound(round - 1, arr) + ell) % (round % 2 === 1 ? a : b);
    ell = arr;
    arr = temporary;
  }
  return arr === a ? arr * a + ell : ell * a + arr;
}

function unfeistel(value) {
  const a = 65_535;
  const b = 65_536;
  const ahh = value % a;
  const ale = Math.floor(value / a);
  let ell = ale === a ? ahh : ale;
  let arr = ale === a ? ale : ahh;
  for (let round = 4; round >= 1; round -= 1) {
    const effective = shipRound(round - 1, ell);
    const temporary = round % 2 === 1
      ? (arr + a - effective % a) % a
      : (arr + b - effective % b) % b;
    arr = ell;
    ell = temporary;
  }
  return a * arr + ell;
}

function scramble(value, cipher, bound) {
  if (value >= 0x1_0000n && value <= MAX_U32) {
    const once = cipher(Number(value - 0x1_0000n));
    return 0x1_0000n + BigInt(once < bound ? once : cipher(once));
  }
  if (value > MAX_U32 && value <= MAX_U64) return (value & ~MAX_U32) | scramble(value & MAX_U32, cipher, bound);
  return value;
}
export const fein = value => scramble(value, feistel, 0xffff * 0x1_0000);
export const fynd = value => scramble(value, unfeistel, 0xffff_ffff);

// ++fed:ag, a ship's name, read whole: a galaxy's suffix, a star's prefix
// (not doz) and suffix, two to four words, or longer names in --groups of
// four words; a name of words has a nonzero first. slaw's %p is a jet,
// which reads the usual lengths of name, a galaxy's to a planet's, a
// moon's or a comet's, letting a leading zero word or a doz star through,
// and leaves the rest to ++fed.
const DOH = `--(?:${GAP})?`;
const SHIP = new RegExp(`^(?:[a-z]{3}|[a-z]{6}(?:-[a-z]{6}){0,3}(?:${DOH}[a-z]{6}(?:-[a-z]{6}){3})*)$`);
const HYPHENS = new RegExp(`${DOH}|-`);
const JET_SHIP = /^(?:[a-z]{3}|[a-z]{6}(?:-[a-z]{6}){0,3}|(?:[a-z]{6}-){3}[a-z]{6}--(?:[a-z]{6}-){3}[a-z]{6})$/;
function ship(name, jet) {
  if (!SHIP.test(name)) return undefined;
  if (name.length === 3) return SUFFIX.get(name);
  const words = name.split(HYPHENS);
  let value = 0n;
  for (const word of words) {
    const prefix = PREFIX.get(word.slice(0, 3));
    const suffix = SUFFIX.get(word.slice(3));
    if (prefix === undefined || suffix === undefined) return undefined;
    value = (value << 16n) | (prefix << 8n) | suffix;
  }
  const lenient = jet && JET_SHIP.test(name);
  if (!lenient && (words[1] ? value >> BigInt(16 * words.length - 16) === 0n : name.startsWith('doz'))) return undefined;
  return fynd(value);
}
const fed = (s, i) => {
  const value = ship(s.slice(i));
  return value === undefined ? null : [value, s.length];
};

// ++when: a date, and +year of it. A month or day may have a leading
// zero, as ++mot and ++dap take it, and +rend prints them so.
const DATE = /(0|[1-9][0-9]*)(-?)\.(1[0-2]|0?[1-9])\.(0[1-9]|[1-9][0-9]*)/y;
const TIME = /\.\.([0-9]+)\.([0-9]+)\.([0-9]+)/y;
const FRACTION = /\.\.([0-9a-f]{4}(?:\.[0-9a-f]{4})*)/y;
function when(s, i) {
  const found = at(DATE, s, i);
  if (!found) return null;
  const [[, yearText, bc, month, day], end] = found;
  let hours = 0n;
  let minutes = 0n;
  let seconds = 0n;
  let fraction = [];
  let next = end;
  const time = at(TIME, s, end);
  if (time) {
    [hours, minutes, seconds] = time[0].slice(1).map(BigInt);
    next = time[1];
    const groups = at(FRACTION, s, next);
    if (groups) {
      fraction = groups[0][1].split('.').map(group => BigInt(`0x${group}`));
      next = groups[1];
    }
  }
  return [year(bc !== '-', BigInt(yearText), BigInt(month), BigInt(day), hours, minutes, seconds, fraction), next];
}

// +yawn: days to a month and day of an absolute year, a day past the
// month's end carrying into the next months, and month 13 into the next
// year, as Hoon's does; month 0 or day 0, or month 14 on, crash there.
function lengths(year) {
  const leap = year % 4n === 0n && (year % 100n !== 0n || year % 400n === 0n);
  return [31n, leap ? 29n : 28n, 31n, 30n, 31n, 30n, 31n, 31n, 30n, 31n, 30n, 31n];
}
export function yawn(year, month, day) {
  if (month === 0n || day === 0n || month > 13n) crash(`year: no month ${month} day ${day}`);
  let days = year === 0n
    ? 0n
    : year * 365n + (year - 1n) / 4n + 1n - ((year - 1n) / 100n + 1n) + ((year - 1n) / 400n + 1n);
  const months = lengths(year);
  for (let index = 0n; index < month - 1n; index += 1n) days += months[Number(index)];
  return days + day - 1n;
}

// +year: a date's atom. A BC year 0, or before the atom epoch, and a fifth
// sub-second group crash, as Hoon's +year and +yule do.
export function year(ad, display, month, day, hours, minutes, seconds, fraction) {
  if (!ad && (display === 0n || display > DATE_OFFSET + 1n)) crash(`year: no year ${display} BC`);
  const absolute = ad ? DATE_OFFSET + display : DATE_OFFSET + 1n - display;
  const whole = yawn(absolute, month, day) * 86_400n + hours * 3_600n + minutes * 60n + seconds;
  return (whole << 64n) | yule(fraction);
}

// +yule's sub-second words, most significant first, each added in place.
export function yule(fraction) {
  if (fraction.length > 4) crash('yule: more than four sub-second groups');
  return fraction.reduce((sum, group, index) => sum + (group << BigInt(48 - 16 * index)), 0n);
}

// A duration: units in any order, summed, then sub-second groups.
const UNIT = /([dhms])(0|[1-9][0-9]*)/y;
const SECONDS = { d: 86_400n, h: 3_600n, m: 60n, s: 1n };
function duration(s, i) {
  let found = at(UNIT, s, i);
  if (!found) return null;
  let total = 0n;
  let end;
  for (;;) {
    total += SECONDS[found[0][1]] * BigInt(found[0][2]);
    end = found[1];
    found = s[end] === '.' && at(UNIT, s, end + 1);
    if (!found) break;
  }
  const groups = at(FRACTION, s, end);
  const fraction = groups ? groups[0][1].split('.').map(group => BigInt(`0x${group}`)) : [];
  return [(total << 64n) | yule(fraction), groups ? groups[1] : end];
}

// ++urx: a cord's escapes. An escape's hex is the plain ++hex, digits of
// either case, as many as there are, broken by \\, a gap and / (++gon) if
// it is long; each piece is UTF-8 by +tuft, and a NUL from ~0. vanishes as
// +rap drops it.
const GON = new RegExp(`\\\\(?:${GAP})?/`, 'g');
const PLAIN_HEX = number(new RegExp(`[0-9a-fA-F](?:(?:\\\\(?:${GAP})?/)?[0-9a-fA-F])*`, 'y'), 16, HEX,
  text => text.replace(GON, '').toLowerCase());
function urx(s, i) {
  const bytes = [];
  for (;;) {
    const c = s[i];
    if (c !== undefined && /[0-9a-z_-]/.test(c)) {
      bytes.push(c.charCodeAt(0));
      i += 1;
    } else if (c === '.') {
      bytes.push(32);
      i += 1;
    } else if (c === '~') {
      const escape = PLAIN_HEX(s, i + 1);
      if (escape && s[escape[1]] === '.') {
        bytes.push(...tuft(escape[0]));
        i = escape[1] + 1;
      } else if (s[i + 1] === '~' || s[i + 1] === '.') {
        bytes.push(s.charCodeAt(i + 1));
        i += 2;
      } else {
        break;
      }
    } else {
      break;
    }
  }
  return [bytes, i];
}

// +tuft: the UTF-8 of each 32-bit word of a @c, as Hoon encodes any word.
export function tuft(value) {
  const bytes = [];
  for (let rest = value; rest !== 0n; rest >>= 32n) {
    const b = Number(rest & MAX_U32);
    if (b <= 0x7f) bytes.push(b);
    else if (b <= 0x7ff) bytes.push(0xc0 | (b >>> 6), 0x80 | (b & 63));
    else if (b <= 0xffff) bytes.push(0xe0 | (b >>> 12), 0x80 | ((b >>> 6) & 63), 0x80 | (b & 63));
    else bytes.push(0xf0 | ((b >>> 18) & 7), 0x80 | ((b >>> 12) & 63), 0x80 | ((b >>> 6) & 63), 0x80 | (b & 63));
  }
  return bytes.filter(byte => byte !== 0);
}

// +taft: the code points of UTF-8 bytes, as Hoon decodes them: each lead
// byte, a control other than a line feed crashing (+teff), and a sequence
// that doesn't encode its value back the same way crashing too.
export function taft(bytes) {
  const points = [];
  for (let index = 0; index < bytes.length;) {
    const lead = bytes[index];
    if (lead < 32 && lead !== 10) crash(`taft: control character ${lead}`);
    const width = lead <= 127 ? 1 : lead <= 223 ? 2 : lead <= 239 ? 3 : 4;
    const piece = bytes.slice(index, index + width);
    let point = width === 1 ? lead : lead & (0x7f >> width);
    for (const byte of piece.slice(1)) point = (point << 6) | (byte & 63);
    // Bytes past the end read as zero.
    point <<= 6 * (width - piece.length);
    if (tuft(BigInt(point)).join() !== piece.join()) crash('taft: invalid UTF-8');
    points.push(point);
    index += width;
  }
  return points;
}

// ++royl: a float's decimal, as [sign mantissa exponent] for mantissa
// times ten to the exponent, or infinity or NaN.
const DECIMALS = /(-?)(0|[1-9][0-9]*)(?:\.([0-9]+))?(?:e(-?)(0|[1-9][0-9]*))?/y;
const SPECIAL = /(-?)inf|nan/y;
function royl(s, i) {
  const special = at(SPECIAL, s, i);
  if (special) return [special[0][0] === 'nan' ? { nan: true } : { sign: !special[0][1], infinite: true }, special[1]];
  const found = at(DECIMALS, s, i);
  if (!found) return null;
  const [[, minus, whole, fraction = '', negative, exponent = '0'], end] = found;
  return [{
    sign: !minus,
    mantissa: BigInt(whole + fraction),
    exponent: (negative ? -1 : 1) * Number(exponent) - fraction.length,
  }, end];
}

// IEEE formats, as ++ff takes them: [exponent bits, fraction bits, bias].
export const FLOATS = { h: [5, 10, 15], s: [8, 23, 127], d: [11, 52, 1023], q: [15, 112, 16383] };

// The float nearest a decimal, ties to even, as ++grd:ff rounds it.
export function toFloat([w, p, b], number) {
  const sign = number.sign || number.nan ? 0n : 1n << BigInt(w + p);
  const top = (1n << BigInt(w)) - 1n;
  if (number.nan) return ((top << 1n) | 1n) << BigInt(p - 1);
  if (number.infinite || number.mantissa === 0n) return sign | (number.infinite ? top << BigInt(p) : 0n);
  let numerator = number.mantissa * 10n ** BigInt(Math.max(number.exponent, 0));
  const denominator = 10n ** BigInt(Math.max(-number.exponent, 0));
  const precision = BigInt(p + 1);
  const least = BigInt(1 - b - p);
  // The exponent of the result's last bit: none below the format's least.
  let e = BigInt(numerator.toString(2).length - denominator.toString(2).length) - precision;
  const scale = exponent => (exponent >= 0n ? [numerator, denominator << exponent] : [numerator << -exponent, denominator]);
  let [n, d] = scale(e);
  while (n >= d << precision) [n, d] = scale(e += 1n);
  while (n < d << (precision - 1n) && e > least) [n, d] = scale(e -= 1n);
  while (e < least) [n, d] = scale(e += 1n);
  let q = n / d;
  const twice = 2n * (n % d);
  if (twice > d || (twice === d && (q & 1n))) q += 1n;
  if (q === 1n << precision) {
    q >>= 1n;
    e += 1n;
  }
  if (q === 0n) return sign;
  if (e > least + 2n ** BigInt(w) - 3n) return sign | (top << BigInt(p));
  return sign | (q < 1n << BigInt(p) ? q : ((e - least + 1n) << BigInt(p)) | (q & ((1n << BigInt(p)) - 1n)));
}

// A float's shortest decimal, as ++drg:ff makes it (Steele and White's
// dragon4): [sign digits exponent] for digits times ten to the exponent,
// or infinity or NaN.
export function fromFloat([w, p, b], bits) {
  const fraction = bits & ((1n << BigInt(p)) - 1n);
  const biased = (bits >> BigInt(p)) & ((1n << BigInt(w)) - 1n);
  const sign = ((bits >> BigInt(w + p)) & 1n) === 0n;
  const least = BigInt(1 - b - p);
  if (biased === (1n << BigInt(w)) - 1n) return fraction === 0n ? { sign, infinite: true } : { nan: true };
  if (biased === 0n && fraction === 0n) return { sign, digits: 0n, exponent: 0 };
  const a = biased === 0n ? fraction : fraction + (1n << BigInt(p));
  const e = biased === 0n ? least : biased + least - 1n;
  let r = e >= 0n ? a << e : a;
  let s = e >= 0n ? 1n : 1n << -e;
  let mn = e >= 0n ? 1n << e : 1n;
  let mp = mn;
  if (a === 1n << BigInt(p) && e !== least) {
    mp <<= 1n;
    r <<= 1n;
    s <<= 1n;
  }
  // Hoon scales r up by tens while it is under s/10, then s while 2r+m+
  // reaches 2s; each power of ten is the least that does, found here from
  // the values' sizes rather than one ten at a time.
  const tens = (low, high) => {
    let count = Math.max(0, Math.floor((high.toString(2).length - low.toString(2).length) * 0.30103) - 1);
    while (low * 10n ** BigInt(count) < high) count += 1;
    return count;
  };
  const down = tens(r, (s + 9n) / 10n);
  const scale = 10n ** BigInt(down);
  r *= scale;
  mn *= scale;
  mp *= scale;
  const over = tens(2n * s, 2n * r + mp + 1n);
  s *= 10n ** BigInt(over);
  let k = over - down;
  let o = 0n;
  for (;;) {
    const u = (r * 10n) / s;
    r = (r * 10n) % s;
    k -= 1;
    mn *= 10n;
    mp *= 10n;
    const low = 2n * r < mn;
    const high = 2n * s < mp || 2n * r > 2n * s - mp;
    if (low || high) {
      const up = high && (!low || 2n * r > s);
      return { sign, digits: o * 10n + (up ? u + 1n : u), exponent: k };
    }
    o = o * 10n + u;
  }
}

// ++feq:ag, read whole: @q's syllables, a byte at the top or two bytes a
// word.
const DOF = new RegExp(`-(?:${GAP})?`);
function feq(s, i) {
  const words = s.slice(i).split(DOF);
  let value = 0n;
  for (const [index, word] of words.entries()) {
    const prefix = PREFIX.get(word.slice(0, 3));
    const suffix = SUFFIX.get(word.slice(-3));
    if (word.length === 6 && prefix !== undefined && suffix !== undefined) {
      value = (value << 16n) | (prefix << 8n) | suffix;
    } else if (index === 0 && word.length === 3 && SUFFIX.has(word)) {
      value = SUFFIX.get(word);
    } else {
      return null;
    }
  }
  return [value, s.length];
}

// ++lip:ag and ++bip:ag: an IPv4 and an IPv6 address's groups.
const DOG_AT = new RegExp(DOG, 'y');
function groups(s, i, count, pattern, radix, base) {
  let value = 0n;
  for (let group = 0; group < count; group += 1) {
    if (group) {
      const dot = at(DOG_AT, s, i);
      if (!dot) return null;
      i = dot[1];
    }
    const found = at(pattern, s, i);
    if (!found) return null;
    value = value * base + digits(found[0][0].toLowerCase(), radix, HEX);
    i = found[1];
  }
  return [value, i];
}
const TED = /0|[1-9][0-9]{0,2}/y;
const QEX = /0|[1-9a-f][0-9a-fA-F]{0,3}/y;

// ++bisk: a number by its prefix.
function bisk(s, i) {
  if (s[i] === '0') {
    const kind = s[i + 1];
    const reader = { b: bay, c: fim, i: dim, x: hex, v: viz, w: wiz }[kind];
    const parsed = reader?.(s, i + 2);
    if (parsed) return [`u${kind}`, ...parsed];
  }
  const parsed = dem(s, i);
  return parsed && ['ud', ...parsed];
}

// ++nuck: a whole literal's aura and value, or undefined. A literal Hoon
// reads only by crashing crashes here too.
// Like Hoon's parsers, each choice that parses is taken, whether or not
// the rest of the text then reads.
export function nuck(s) {
  const read = (aura, parsed) => (parsed && parsed[1] === s.length ? { aura, value: parsed[0] } : undefined);
  const first = s[0] ?? '';
  if (/[a-z]/.test(first)) return read('tas', sym(s, 0));
  if (/[0-9]/.test(first)) {
    const parsed = bisk(s, 0);
    return parsed && read(parsed[0], parsed.slice(1));
  }
  if (first === '-') {
    // ++tash: -n is negative, --n positive, in @s's zigzag order.
    const positive = s[1] === '-';
    const parsed = bisk(s, positive ? 2 : 1);
    if (!parsed) return undefined;
    const [aura, value, end] = parsed;
    return read(`s${aura.slice(1)}`, [positive ? 2n * value : value === 0n ? 0n : 2n * value - 1n, end]);
  }
  if (first === '.') {
    for (const [aura, count, pattern, radix, base] of [['is', 8, QEX, 16, 0x1_0000n], ['if', 4, TED, 10, 256n]]) {
      const parsed = groups(s, 1, count, pattern, radix, base);
      if (parsed) return read(aura, parsed);
    }
    const tildes = /~{0,3}/y.exec(s.slice(1))[0].length;
    for (const [aura, prefix] of [['rh', 2], ['rq', 3], ['rd', 1], ['rs', 0]]) {
      if (tildes < prefix) continue;
      const parsed = royl(s, 1 + prefix);
      if (parsed) return read(aura, [toFloat(FLOATS[aura[1]], parsed[0]), parsed[1]]);
    }
    if (s[1] === 'y' || s[1] === 'n') return read('f', [s[1] === 'y' ? 0n : 1n, 2]);
    if (s[1] === '~') return read('q', feq(s, 2));
    return undefined;
  }
  if (first !== '~') return undefined;
  // A ~0 and base-32 digits is a jammed blob, which no aura reads.
  if (s[1] === '0' && /[0-9a-v]/.test(s[2] ?? '')) return undefined;
  // ++crub, or ~ alone.
  for (const [aura, rule] of [['da', when], ['dr', duration], ['p', fed]]) {
    const parsed = rule(s, 1);
    if (parsed) return read(aura, parsed);
  }
  if (s[1] === '.') return read('ta', urs(s, 2));
  if (s[1] === '~') return read('t', textOf(urx(s, 2)));
  if (s[1] === '-') return read('c', codesOf(urx(s, 2)));
  return read('n', [0n, 1]);
}

function cordOf(text) {
  return bytesAtom([...text].map(character => character.charCodeAt(0)));
}
function bytesAtom(bytes) {
  let value = 0n;
  for (let index = bytes.length - 1; index >= 0; index -= 1) value = (value << 8n) | BigInt(bytes[index]);
  return value;
}
const textOf = ([bytes, end]) => [bytesAtom(bytes), end];
const codesOf = ([bytes, end]) => [taft(bytes).reduceRight((value, point) => (value << 32n) | BigInt(point), 0n), end];

// +slaw: an aura's value of a text, or undefined. Hoon's fast paths read
// their aura's syntax alone; other auras are a whole literal of exactly
// that aura. A text Hoon crashes on crashes here too.
export function slaw(aura, s) {
  const whole = parsed => (parsed && parsed[1] === s.length ? parsed[0] : undefined);
  switch (aura) {
    case 'da': return s[0] === '~' ? whole(when(s, 1)) : undefined;
    case 'p': return s[0] === '~' ? ship(s.slice(1), true) : undefined;
    case 'ud': return whole(demJet(s, 0));
    case 'ux': return s.startsWith('0x') ? whole(hex(s, 2)) : undefined;
    case 'uv': return s.startsWith('0v') ? whole(viz(s, 2)) : undefined;
    case 'ta': return s.startsWith('~.') ? whole(urs(s, 2)) : undefined;
    case 'tas': return whole(sym(s, 0));
    default: {
      const read = nuck(s);
      return read?.aura === aura ? read.value : undefined;
    }
  }
}
