import { atomToBytes } from '../core/runtime.mjs';
import { formatP } from '../natives/atom.mjs';

const MAX_PLANET = 0xffff_ffffn;
const MAX_MOON = 0xffff_ffff_ffff_ffffn;
const decoder = new TextDecoder();

export function fullShipName(value) {
  return decoder.decode(atomToBytes(formatP(value)));
}

export function abbreviateComet(value) {
  const full = fullShipName(value);
  if (value <= MAX_MOON) return full;
  const words = full.split('-').filter(Boolean);
  if (words.length <= 4) return full;
  return [...words.slice(0, 2), '…', ...words.slice(-2)].join('-');
}

export function identityParts(ship, moonIdentifier) {
  const full = fullShipName(ship);
  if (moonIdentifier === undefined) {
    return [{ role: 'ship', text: abbreviateComet(ship) }];
  }
  if (ship > MAX_PLANET) {
    throw new RangeError('a moon parent must be a galaxy, star, or planet');
  }
  if (typeof moonIdentifier !== 'string' || !/^~[^\s]+$/.test(moonIdentifier)) {
    throw new TypeError('moon identifier must be a nonempty ~-prefixed string');
  }
  return [
    { role: 'ship', text: full },
    { role: 'moon', text: moonIdentifier },
  ];
}

export function identityElement(document, ship, moonIdentifier) {
  const root = document.createElement('span');
  root.className = 'identity';
  root.title = moonIdentifier === undefined
    ? fullShipName(ship)
    : `${fullShipName(ship)} ${moonIdentifier}`;
  for (const part of identityParts(ship, moonIdentifier)) {
    const element = document.createElement('span');
    element.className = `identity-${part.role}`;
    element.textContent = part.text;
    root.appendChild(element);
  }
  return root;
}
