import test from 'node:test';
import assert from 'node:assert/strict';

import {
  abbreviateComet,
  fullShipName,
  identityElement,
  identityParts,
} from '../browser/identity.mjs';

const comet = 177292234920987225829036013324996224552n;
const planet = 1_624_961_343n;

test('comets are abbreviated in the middle without changing the full identity', () => {
  const full = '~rolruc-midwyl-hathes-palsym--fotnul-pagpur-nopful-lomtem';
  assert.equal(fullShipName(comet), full);
  assert.equal(abbreviateComet(comet), '~rolruc-midwyl-…-nopful-lomtem');
  assert.deepEqual(identityParts(comet), [
    { role: 'ship', text: '~rolruc-midwyl-…-nopful-lomtem' },
  ]);
});

test('galaxies, stars, planets, and unexpanded moons keep their full names', () => {
  assert.equal(abbreviateComet(0n), '~zod');
  assert.equal(abbreviateComet(256n), '~marzod');
  assert.equal(abbreviateComet(planet), '~sampel-palnet');
  assert.equal(
    abbreviateComet(14_598_768_375_314_968_895n),
    '~mastyr-midwyt-sampel-palnet',
  );
});

test('moon display places the issuing ship beside the actual identifier', () => {
  assert.deepEqual(identityParts(planet, '~sampel'), [
    { role: 'ship', text: '~sampel-palnet' },
    { role: 'moon', text: '~sampel' },
  ]);
});

test('identity element renders adjacent spans and retains the full identity in its title', () => {
  const makeElement = () => ({
    children: [],
    appendChild(child) {
      this.children.push(child);
      return child;
    },
  });
  const document = { createElement: makeElement };
  const moon = identityElement(document, planet, '~sampel');
  assert.equal(moon.title, '~sampel-palnet ~sampel');
  assert.deepEqual(
    moon.children.map(child => [child.className, child.textContent]),
    [
      ['identity-ship', '~sampel-palnet'],
      ['identity-moon', '~sampel'],
    ],
  );

  const shortened = identityElement(document, comet);
  assert.equal(shortened.title, fullShipName(comet));
  assert.equal(shortened.children[0].textContent, '~rolruc-midwyl-…-nopful-lomtem');
});

test('moon inputs reject invalid identifiers and parents that cannot issue the moon', () => {
  assert.throws(() => identityParts(comet, '~sampel'), /moon parent/);
  assert.throws(() => identityParts(14_598_768_375_314_968_895n, '~sampel'), /moon parent/);
  for (const identifier of ['', 'sampel', '~two words', null, 42]) {
    assert.throws(() => identityParts(planet, identifier), /moon identifier/);
  }
});
