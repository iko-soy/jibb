const DECIMAL = /^(?:0|[1-9][0-9]{0,2}(?:\.[0-9]{3})*)$/;
const HEXADECIMAL = /^0x[0-9a-fA-F]+(?:\.[0-9a-fA-F]+)*$/;
const BASE32 = /^0v[0-9a-v]+(?:\.[0-9a-v]+)*$/;
const TERM = /^%(?:[a-z][a-z0-9-]*|[&|$])$/;
const KNOT = /^~\.[a-z0-9._~-]*$/;
const DATE = /^~([0-9]+)(-?)\.([0-9]{1,2})\.([0-9]{1,2})(?:\.\.([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{1,2})(?:\.\.([0-9a-f]{4}(?:\.[0-9a-f]{4}){0,3}))?)?$/;
const DURATION = /^~([dhms][0-9]+(?:\.[dhms][0-9]+)*)(?:\.\.([0-9a-f]{4}(?:\.[0-9a-f]{4}){0,3}))?$/;
const DATE_OFFSET = 292_277_024_400n;
const MAX_U32 = 0xffff_ffffn;
const MAX_U64 = 0xffff_ffff_ffff_ffffn;

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

const PREFIX_VALUES = new Map(PREFIXES.map((name, value) => [name, value]));
const SUFFIX_VALUES = new Map(SUFFIXES.map((name, value) => [name, value]));
const RAKU = [0xb76d5eed, 0xee281300, 0x85bcae01, 0x4b387af7];

function fail(text, reason = 'invalid literal') {
  throw new SyntaxError(`${reason}: ${JSON.stringify(text)}`);
}

function result(text, value, aura) {
  return { value, aura, text };
}

function cord(bytes) {
  let value = 0n;
  for (let index = bytes.length - 1; index >= 0; index -= 1) {
    value = (value << 8n) | BigInt(bytes[index]);
  }
  return value;
}

function asciiCord(text) {
  return cord(Array.from(text, character => character.charCodeAt(0)));
}

function base32Value(text) {
  let value = 0n;
  for (const character of text.slice(2).replaceAll('.', '')) {
    const code = character.charCodeAt(0);
    const digit = code <= 57 ? code - 48 : code - 87;
    value = value * 32n + BigInt(digit);
  }
  return value;
}

function wellFormed(text) {
  for (let index = 0; index < text.length; index += 1) {
    const code = text.charCodeAt(index);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = text.charCodeAt(index + 1);
      if (!(next >= 0xdc00 && next <= 0xdfff)) return false;
      index += 1;
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      return false;
    }
  }
  return true;
}

function readString(text) {
  if (text.length < 2 || !text.startsWith('"') || !text.endsWith('"') || !wellFormed(text)) {
    fail(text, 'invalid string literal');
  }

  const inner = text.slice(1, -1);
  const bytes = [];
  let raw = '';
  const flush = () => {
    if (raw !== '') {
      for (const byte of new TextEncoder().encode(raw)) bytes.push(byte);
    }
    raw = '';
  };

  for (let index = 0; index < inner.length;) {
    const character = inner[index];
    const code = inner.charCodeAt(index);
    if (character === '{') fail(text, 'interpolated strings are not literals');
    if (character === '"') fail(text, 'unescaped quote in string literal');
    if (code <= 31 || code === 127) fail(text, 'unescaped control character in string literal');

    if (character !== '\\') {
      raw += character;
      index += 1;
      continue;
    }

    flush();
    const escaped = inner[index + 1];
    if (escaped === '"' || escaped === '{' || escaped === '\\') {
      bytes.push(escaped.charCodeAt(0));
      index += 2;
      continue;
    }
    const hexadecimal = inner.slice(index + 1, index + 3);
    if (!/^[0-9a-f]{2}$/.test(hexadecimal)) {
      fail(text, 'invalid string escape (expected \", \\{, \\\\, or two lowercase hex digits)');
    }
    bytes.push(Number.parseInt(hexadecimal, 16));
    index += 3;
  }
  flush();
  return result(text, cord(bytes), '@t');
}

function readTerm(text) {
  if (text === '%.y' || text === '%.n') {
    return result(text, text === '%.y' ? 0n : 1n, '?');
  }
  if (text === '%&' || text === '%$') return result(text, 0n, '@tas');
  if (text === '%|') return result(text, 1n, '@tas');

  const body = text.slice(1);
  if (DECIMAL.test(body)) return result(text, BigInt(body.replaceAll('.', '')), '@tas');
  if (!TERM.test(text)) fail(text, 'invalid term literal');
  return result(text, asciiCord(body), '@tas');
}

function readFractions(groups) {
  if (groups === undefined) return 0n;
  let value = 0n;
  for (const group of groups.split('.')) value = (value << 16n) | BigInt(`0x${group}`);
  return value;
}

function daysFromCivil(year, month, day) {
  let days = year === 0n
    ? 0n
    : year * 365n + (year - 1n) / 4n + 1n - ((year - 1n) / 100n + 1n)
      + ((year - 1n) / 400n + 1n);
  const leap = year % 4n === 0n && (year % 100n !== 0n || year % 400n === 0n);
  const lengths = [31n, leap ? 29n : 28n, 31n, 30n, 31n, 30n, 31n, 31n, 30n, 31n, 30n, 31n];
  for (let index = 0; index < month - 1; index += 1) {
    if (index >= lengths.length) return null;
    days += lengths[index];
  }
  return days + BigInt(day) - 1n;
}

function readDate(text, match) {
  const [, yearText, bc, monthText, dayText, hours = '0', minutes = '0', seconds = '0', groups] = match;
  const displayYear = BigInt(yearText);
  const year = bc === '-' ? DATE_OFFSET - (displayYear - 1n) : DATE_OFFSET + displayYear;
  const days = daysFromCivil(year, Number(monthText), Number(dayText));
  if (days === null || days < 0n) fail(text, 'invalid date literal');
  const wholeSeconds = days * 86_400n + BigInt(hours) * 3_600n + BigInt(minutes) * 60n + BigInt(seconds);
  return result(text, (wholeSeconds << 64n) | readFractions(groups), '@da');
}

function readDuration(text, match) {
  const ranks = { d: 4, h: 3, m: 2, s: 1 };
  const units = { d: 86_400n, h: 3_600n, m: 60n, s: 1n };
  let seconds = 0n;
  let previous = 0;
  for (const segment of match[1].split('.')) {
    const unit = segment[0];
    const rank = ranks[unit];
    if (previous !== 0 && rank >= previous) fail(text, 'duration units must be in d, h, m, s order');
    previous = rank;
    seconds += BigInt(segment.slice(1)) * units[unit];
  }
  return result(text, (seconds << 64n) | readFractions(match[2]), '@dr');
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

function inverseFeistel(value) {
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

function tail(value) {
  const decoded = inverseFeistel(value);
  return BigInt(decoded < 0xffff_ffff ? decoded : inverseFeistel(decoded));
}

function fynd(value) {
  if (value >= 0x1_0000n && value <= MAX_U32) {
    return 0x1_0000n + tail(Number(value - 0x1_0000n));
  }
  if (value >= 0x1_0000_0000n && value <= MAX_U64) {
    return (value & ~MAX_U32) | fynd(value & MAX_U32);
  }
  return value;
}

function readShip(text) {
  const words = text.slice(1).split('-');
  const bytes = [];

  if (words.length === 1 && words[0].length === 3) {
    const suffix = SUFFIX_VALUES.get(words[0]);
    if (suffix === undefined) fail(text, 'invalid ship suffix');
    bytes.push(suffix);
  } else {
    for (let index = 0; index < words.length; index += 1) {
      const word = words[words.length - index - 1];
      if (index % 5 === 4) {
        if (word !== '') fail(text, 'invalid ship separator (expected a double hyphen)');
      } else if (word === '') {
        fail(text, 'invalid ship separator');
      }
    }

    for (const word of words) {
      if (word === '') continue;
      if (word.length !== 6) fail(text, 'ship words after a galaxy must contain six letters');
      const prefix = PREFIX_VALUES.get(word.slice(0, 3));
      const suffix = SUFFIX_VALUES.get(word.slice(3));
      if (prefix === undefined) fail(text, 'invalid ship prefix');
      if (suffix === undefined) fail(text, 'invalid ship suffix');
      bytes.push(prefix, suffix);
    }
  }

  let encoded = 0n;
  for (const byte of bytes) encoded = (encoded << 8n) | BigInt(byte);
  return result(text, fynd(encoded), '@p');
}

export function readLiteral(text) {
  if (typeof text !== 'string') throw new SyntaxError(`literal must be a string, received ${typeof text}`);
  if (text === '~') return result(text, 0n, 'null');
  if (text.startsWith('"')) return readString(text);
  if (text.startsWith('%')) return readTerm(text);
  if (DECIMAL.test(text)) return result(text, BigInt(text.replaceAll('.', '')), '@ud');
  if (HEXADECIMAL.test(text)) return result(text, BigInt(text.replaceAll('.', '')), '@ux');
  if (BASE32.test(text)) return result(text, base32Value(text), '@uv');
  if (KNOT.test(text)) return result(text, asciiCord(text.slice(2)), 'knot');

  if (text.startsWith('~')) {
    if (/^~[0-9]/.test(text)) {
      const match = DATE.exec(text);
      if (match) return readDate(text, match);
      fail(text, 'invalid date literal');
    }
    if (/^~[dhms][0-9]/.test(text)) {
      const match = DURATION.exec(text);
      if (match) return readDuration(text, match);
      fail(text, 'invalid duration literal');
    }
    return readShip(text);
  }

  return fail(text);
}
