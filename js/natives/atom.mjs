import {
  CoreCrash,
  atomToBytes,
  bytesToAtom,
  requireLoobean,
  same,
} from '../core/runtime.mjs';
import {
  arrayToList,
  atom,
  cord,
  listToArray,
  loob,
  pair,
  text,
} from './helpers.mjs';

const MAX_CODEPOINT = 0x10ffffn;
const DATE_OFFSET = 292_277_024_400n;
const MAX_U32 = 0xffff_ffffn;
const MAX_U64 = 0xffff_ffff_ffff_ffffn;
const SHIP_DOMAIN = 0xffff * 0x1_0000;

const PREFIXES = [
  'doz', 'mar', 'bin', 'wan', 'sam', 'lit', 'sig', 'hid', 'fid', 'lis', 'sog', 'dir', 'wac',
  'sab', 'wis', 'sib', 'rig', 'sol', 'dop', 'mod', 'fog', 'lid', 'hop', 'dar', 'dor', 'lor',
  'hod', 'fol', 'rin', 'tog', 'sil', 'mir', 'hol', 'pas', 'lac', 'rov', 'liv', 'dal', 'sat',
  'lib', 'tab', 'han', 'tic', 'pid', 'tor', 'bol', 'fos', 'dot', 'los', 'dil', 'for', 'pil',
  'ram', 'tir', 'win', 'tad', 'bic', 'dif', 'roc', 'wid', 'bis', 'das', 'mid', 'lop', 'ril',
  'nar', 'dap', 'mol', 'san', 'loc', 'nov', 'sit', 'nid', 'tip', 'sic', 'rop', 'wit', 'nat',
  'pan', 'min', 'rit', 'pod', 'mot', 'tam', 'tol', 'sav', 'pos', 'nap', 'nop', 'som', 'fin',
  'fon', 'ban', 'mor', 'wor', 'sip', 'ron', 'nor', 'bot', 'wic', 'soc', 'wat', 'dol', 'mag',
  'pic', 'dav', 'bid', 'bal', 'tim', 'tas', 'mal', 'lig', 'siv', 'tag', 'pad', 'sal', 'div',
  'dac', 'tan', 'sid', 'fab', 'tar', 'mon', 'ran', 'nis', 'wol', 'mis', 'pal', 'las', 'dis',
  'map', 'rab', 'tob', 'rol', 'lat', 'lon', 'nod', 'nav', 'fig', 'nom', 'nib', 'pag', 'sop',
  'ral', 'bil', 'had', 'doc', 'rid', 'moc', 'pac', 'rav', 'rip', 'fal', 'tod', 'til', 'tin',
  'hap', 'mic', 'fan', 'pat', 'tac', 'lab', 'mog', 'sim', 'son', 'pin', 'lom', 'ric', 'tap',
  'fir', 'has', 'bos', 'bat', 'poc', 'hac', 'tid', 'hav', 'sap', 'lin', 'dib', 'hos', 'dab',
  'bit', 'bar', 'rac', 'par', 'lod', 'dos', 'bor', 'toc', 'hil', 'mac', 'tom', 'dig', 'fil',
  'fas', 'mit', 'hob', 'har', 'mig', 'hin', 'rad', 'mas', 'hal', 'rag', 'lag', 'fad', 'top',
  'mop', 'hab', 'nil', 'nos', 'mil', 'fop', 'fam', 'dat', 'nol', 'din', 'hat', 'nac', 'ris',
  'fot', 'rib', 'hoc', 'nim', 'lar', 'fit', 'wal', 'rap', 'sar', 'nal', 'mos', 'lan', 'don',
  'dan', 'lad', 'dov', 'riv', 'bac', 'pol', 'lap', 'tal', 'pit', 'nam', 'bon', 'ros', 'ton',
  'fod', 'pon', 'sov', 'noc', 'sor', 'lav', 'mat', 'mip', 'fip',
];

const SUFFIXES = [
  'zod', 'nec', 'bud', 'wes', 'sev', 'per', 'sut', 'let', 'ful', 'pen', 'syt', 'dur', 'wep',
  'ser', 'wyl', 'sun', 'ryp', 'syx', 'dyr', 'nup', 'heb', 'peg', 'lup', 'dep', 'dys', 'put',
  'lug', 'hec', 'ryt', 'tyv', 'syd', 'nex', 'lun', 'mep', 'lut', 'sep', 'pes', 'del', 'sul',
  'ped', 'tem', 'led', 'tul', 'met', 'wen', 'byn', 'hex', 'feb', 'pyl', 'dul', 'het', 'mev',
  'rut', 'tyl', 'wyd', 'tep', 'bes', 'dex', 'sef', 'wyc', 'bur', 'der', 'nep', 'pur', 'rys',
  'reb', 'den', 'nut', 'sub', 'pet', 'rul', 'syn', 'reg', 'tyd', 'sup', 'sem', 'wyn', 'rec',
  'meg', 'net', 'sec', 'mul', 'nym', 'tev', 'web', 'sum', 'mut', 'nyx', 'rex', 'teb', 'fus',
  'hep', 'ben', 'mus', 'wyx', 'sym', 'sel', 'ruc', 'dec', 'wex', 'syr', 'wet', 'dyl', 'myn',
  'mes', 'det', 'bet', 'bel', 'tux', 'tug', 'myr', 'pel', 'syp', 'ter', 'meb', 'set', 'dut',
  'deg', 'tex', 'sur', 'fel', 'tud', 'nux', 'rux', 'ren', 'wyt', 'nub', 'med', 'lyt', 'dus',
  'neb', 'rum', 'tyn', 'seg', 'lyx', 'pun', 'res', 'red', 'fun', 'rev', 'ref', 'mec', 'ted',
  'rus', 'bex', 'leb', 'dux', 'ryn', 'num', 'pyx', 'ryg', 'ryx', 'fep', 'tyr', 'tus', 'tyc',
  'leg', 'nem', 'fer', 'mer', 'ten', 'lus', 'nus', 'syl', 'tec', 'mex', 'pub', 'rym', 'tuc',
  'fyl', 'lep', 'deb', 'ber', 'mug', 'hut', 'tun', 'byl', 'sud', 'pem', 'dev', 'lur', 'def',
  'bus', 'bep', 'run', 'mel', 'pex', 'dyt', 'byt', 'typ', 'lev', 'myl', 'wed', 'duc', 'fur',
  'fex', 'nul', 'luc', 'len', 'ner', 'lex', 'rup', 'ned', 'lec', 'ryd', 'lyd', 'fen', 'wel',
  'nyd', 'hus', 'rel', 'rud', 'nes', 'hes', 'fet', 'des', 'ret', 'dun', 'ler', 'nyr', 'seb',
  'hul', 'ryl', 'lud', 'rem', 'lys', 'fyn', 'wer', 'ryc', 'sug', 'nys', 'nyl', 'lyn', 'dyn',
  'dem', 'lux', 'fed', 'sed', 'bec', 'mun', 'lyr', 'tes', 'mud', 'nyt', 'byr', 'sen', 'weg',
  'fyr', 'mur', 'tel', 'rep', 'teg', 'pec', 'nel', 'nev', 'fes',
];

const RAKU = [0xb76d5eed, 0xee281300, 0x85bcae01, 0x4b387af7];

function crash(operation, message) {
  throw new CoreCrash(`${operation}: ${message}`);
}

function atomPair(sample, operation) {
  const [left, right] = pair(sample, operation);
  return [atom(left, operation), atom(right, operation)];
}

function decodeUtf8(value, operation) {
  const bytes = atomToBytes(atom(value, operation));
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    crash(operation, 'invalid UTF-8 cord');
  }
}

function encodeCodepoints(codepoints) {
  let result = '';
  for (let offset = 0; offset < codepoints.length; offset += 1024) {
    result += String.fromCodePoint(...codepoints.slice(offset, offset + 1024));
  }
  return result;
}

function grouped(value, radix, width, prefix, operation) {
  const digits = atom(value, operation).toString(radix);
  const groups = [];
  for (let end = digits.length; end > 0; end -= width) {
    groups.unshift(digits.slice(Math.max(0, end - width), end));
  }
  return cord(`${prefix}${groups.join('.')}`);
}

function prefixedAtom(prefix, value, operation) {
  const first = new TextEncoder().encode(prefix);
  const rest = atomToBytes(atom(value, operation));
  const bytes = new Uint8Array(first.length + rest.length);
  bytes.set(first);
  bytes.set(rest, first.length);
  return bytesToAtom(bytes);
}

function murmur32(seed, value) {
  let key = value & 0xffff;
  key = Math.imul(key, 0xcc9e2d51);
  key = (key << 15) | (key >>> 17);
  key = Math.imul(key, 0x1b873593);

  let hash = (seed | 0) ^ key;
  hash ^= 2;
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x85ebca6b);
  hash ^= hash >>> 13;
  hash = Math.imul(hash, 0xc2b2ae35);
  hash ^= hash >>> 16;
  return hash >>> 0;
}

function shipRound(round, value) {
  return murmur32(RAKU[round], value);
}

// Hoon's generalized four-round Feistel permutation, including its legacy
// even-round representation and the cycle-walking wrapper used by +feis.
function shipPermutation(input) {
  const a = 65_535;
  const b = 65_536;
  let ell = input % a;
  let arr = Math.floor(input / a);

  for (let round = 1; round <= 4; round += 1) {
    const effective = shipRound(round - 1, arr);
    const temporary = (effective + ell) % (round % 2 === 1 ? a : b);
    ell = arr;
    arr = temporary;
  }

  return arr === a ? arr * a + ell : ell * a + arr;
}

function feis(value) {
  const first = shipPermutation(value);
  return first < SHIP_DOMAIN ? first : shipPermutation(first);
}

function fein(value) {
  if (value >= 0x1_0000n && value <= MAX_U32) {
    return 0x1_0000n + BigInt(feis(Number(value - 0x1_0000n)));
  }
  if (value >= 0x1_0000_0000n && value <= MAX_U64) {
    return (value & ~MAX_U32) | fein(value & MAX_U32);
  }
  return value;
}

function isLeap(year) {
  return year % 4n === 0n && (year % 100n !== 0n || year % 400n === 0n);
}

function civilFromDays(totalDays) {
  const era = totalDays / 146_097n;
  let days = totalDays % 146_097n;
  let year = era * 400n;

  while (days >= (isLeap(year) ? 366n : 365n)) {
    days -= isLeap(year) ? 366n : 365n;
    year += 1n;
  }

  const lengths = [
    31n, isLeap(year) ? 29n : 28n, 31n, 30n, 31n, 30n,
    31n, 31n, 30n, 31n, 30n, 31n,
  ];
  let month = 1n;
  for (const length of lengths) {
    if (days < length) break;
    days -= length;
    month += 1n;
  }
  return [year, month, days + 1n];
}

function pad2(value) {
  return String(value).padStart(2, '0');
}

function formatFraction(value) {
  if (value === 0n) return '';
  const groups = [];
  for (let shift = 48n; shift >= 0n; shift -= 16n) {
    groups.push(((value >> shift) & 0xffffn).toString(16).padStart(4, '0'));
  }
  while (groups.at(-1) === '0000') groups.pop();
  return `..${groups.join('.')}`;
}

function wood(value) {
  const decoded = decodeUtf8(value, 'formatT');
  let result = '';
  for (const character of decoded) {
    const codepoint = character.codePointAt(0);
    if ((codepoint >= 97 && codepoint <= 122)
      || (codepoint >= 48 && codepoint <= 57)
      || codepoint === 45) {
      result += character;
    } else if (codepoint === 32) {
      result += '.';
    } else if (codepoint === 46) {
      result += '~.';
    } else if (codepoint === 126) {
      result += '~~';
    } else {
      result += `~${codepoint === 0 ? '' : codepoint.toString(16)}.`;
    }
  }
  return result;
}

export function add(sample) {
  const [left, right] = atomPair(sample, 'add');
  return left + right;
}

export function sub(sample) {
  const [left, right] = atomPair(sample, 'sub');
  if (left < right) crash('sub', 'subtract underflow');
  return left - right;
}

export function mul(sample) {
  const [left, right] = atomPair(sample, 'mul');
  return left * right;
}

export function inc(value) {
  return atom(value, 'inc') + 1n;
}

export function dec(value) {
  const current = atom(value, 'dec');
  if (current === 0n) crash('dec', 'decrement underflow');
  return current - 1n;
}

export function gth(sample) {
  const [left, right] = atomPair(sample, 'gth');
  return loob(left > right);
}

export function gte(sample) {
  const [left, right] = atomPair(sample, 'gte');
  return loob(left >= right);
}

export function lth(sample) {
  const [left, right] = atomPair(sample, 'lth');
  return loob(left < right);
}

export function lte(sample) {
  const [left, right] = atomPair(sample, 'lte');
  return loob(left <= right);
}

export function eq(sample) {
  const [left, right] = pair(sample, 'eq');
  return same(left, right);
}

export function not(value) {
  return requireLoobean(value) ? 1n : 0n;
}

export function max(sample) {
  const [left, right] = atomPair(sample, 'max');
  return left > right ? left : right;
}

export function min(sample) {
  const [left, right] = atomPair(sample, 'min');
  return left < right ? left : right;
}

// This is the composed Unicode codec: Hoon's tuba(trip value), rather than
// the prelude's separate byte-tape-to-codepoint-list arm named tuba.
export function trip(value) {
  const decoded = decodeUtf8(value, 'trip');
  return arrayToList(Array.from(decoded, character => BigInt(character.codePointAt(0))));
}

export function tuba(values) {
  const items = listToArray(values, 'tuba');
  const codepoints = items.map(item => {
    const codepoint = atom(item, 'tuba');
    if (codepoint > MAX_CODEPOINT || (codepoint >= 0xd800n && codepoint <= 0xdfffn)) {
      crash('tuba', `invalid Unicode scalar value ${codepoint}`);
    }
    return Number(codepoint);
  });
  return cord(encodeCodepoints(codepoints));
}

export function tripBytes(value) {
  return arrayToList([...atomToBytes(atom(value, 'trip'))].map(BigInt));
}

export function cripBytes(values) {
  const bytes = listToArray(values, 'crip').map((value) => {
    const byte = atom(value, 'crip');
    if (byte > 0xffn) crash('crip', `invalid byte ${byte}`);
    return Number(byte);
  });
  return bytesToAtom(new Uint8Array(bytes));
}

export function tubaBytes(values) {
  const packed = cripBytes(values);
  const decoded = decodeUtf8(packed, 'tuba');
  return arrayToList(Array.from(decoded, character => BigInt(character.codePointAt(0))));
}

export function tufaCodepoints(values) {
  const codepoints = listToArray(values, 'tufa').map((value) => {
    const codepoint = atom(value, 'tufa');
    if (codepoint > MAX_CODEPOINT || (codepoint >= 0xd800n && codepoint <= 0xdfffn)) {
      crash('tufa', `invalid Unicode scalar value ${codepoint}`);
    }
    return Number(codepoint);
  });
  return arrayToList([...new TextEncoder().encode(encodeCodepoints(codepoints))].map(BigInt));
}

export function join(sample) {
  const [separator, values] = pair(sample, 'join');
  const parts = [atomToBytes(atom(separator, 'join'))];
  const items = listToArray(values, 'join').map(value => atomToBytes(atom(value, 'join')));
  const length = items.reduce((total, item) => total + item.length, 0)
    + Math.max(0, items.length - 1) * parts[0].length;
  const output = new Uint8Array(length);
  let offset = 0;

  for (let index = 0; index < items.length; index += 1) {
    if (index !== 0) {
      output.set(parts[0], offset);
      offset += parts[0].length;
    }
    output.set(items[index], offset);
    offset += items[index].length;
  }
  return bytesToAtom(output);
}

export function formatUd(value) {
  return grouped(value, 10, 3, '', 'formatUd');
}

export function formatUx(value) {
  return grouped(value, 16, 4, '0x', 'formatUx');
}

export function formatUv(value) {
  return grouped(value, 32, 5, '0v', 'formatUv');
}

export function formatTas(value) {
  return atom(value, 'formatTas');
}

export function formatT(value) {
  return cord(`~~${wood(value)}`);
}

export function formatTa(value) {
  return prefixedAtom('~.', value, 'formatTa');
}

export function formatP(value) {
  const encoded = fein(atom(value, 'formatP'));
  if (encoded <= 0xffn) return cord(`~${SUFFIXES[Number(encoded)]}`);

  const hexadecimal = encoded.toString(16);
  const byteLength = Math.ceil(hexadecimal.length / 2);
  const blockCount = Math.ceil(byteLength / 2);
  const words = [];
  for (let index = 0; index < blockCount; index += 1) {
    const shift = 16n * BigInt(blockCount - index - 1);
    const word = (encoded >> shift) & 0xffffn;
    words.push(`${PREFIXES[Number(word >> 8n)]}${SUFFIXES[Number(word & 0xffn)]}`);
  }

  let rendered = '';
  for (let index = 0; index < words.length; index += 1) {
    if (index !== 0) rendered += index % 4 === 0 ? '--' : '-';
    rendered += words[index];
  }
  return cord(`~${rendered}`);
}

export function formatDa(value) {
  const current = atom(value, 'formatDa');
  const fraction = current & MAX_U64;
  let seconds = current >> 64n;
  const days = seconds / 86_400n;
  seconds %= 86_400n;
  const [year, month, day] = civilFromDays(days);
  const bc = year <= DATE_OFFSET;
  const displayYear = bc ? DATE_OFFSET + 1n - year : year - DATE_OFFSET;
  let rendered = `~${displayYear}${bc ? '-' : ''}.${pad2(month)}.${pad2(day)}`;

  if (seconds !== 0n || fraction !== 0n) {
    const hours = seconds / 3_600n;
    const minutes = seconds % 3_600n / 60n;
    const remainder = seconds % 60n;
    rendered += `..${pad2(hours)}.${pad2(minutes)}.${pad2(remainder)}${formatFraction(fraction)}`;
  }
  return cord(rendered);
}

export function formatDr(value) {
  const current = atom(value, 'formatDr');
  const fraction = current & MAX_U64;
  let seconds = current >> 64n;
  const days = seconds / 86_400n;
  seconds %= 86_400n;
  const hours = seconds / 3_600n;
  seconds %= 3_600n;
  const minutes = seconds / 60n;
  seconds %= 60n;

  const parts = [];
  if (days !== 0n) parts.push(`d${days}`);
  if (hours !== 0n) parts.push(`h${hours}`);
  if (minutes !== 0n) parts.push(`m${minutes}`);
  if (seconds !== 0n || parts.length === 0) parts.push(`s${seconds}`);
  return cord(`~${parts.join('.')}${formatFraction(fraction)}`);
}

export function scot(sample) {
  const [aura, value] = pair(sample, 'scot');
  switch (text(aura)) {
    case 'ud': return formatUd(value);
    case 'ux': return formatUx(value);
    case 'uv': return formatUv(value);
    case 'tas': return formatTas(value);
    case 't': return formatT(value);
    case 'ta': return formatTa(value);
    case 'p': return formatP(value);
    case 'da': return formatDa(value);
    case 'dr': return formatDr(value);
    default: return crash('scot', `unsupported aura @${text(aura)}`);
  }
}

export function scow(sample) {
  return arrayToList([...atomToBytes(scot(sample))].map(BigInt));
}
