import assert from 'node:assert/strict';
import test from 'node:test';

import { safeUrl } from '../browser/safe-url.mjs';

test('safe URLs follow the server rule exactly', () => {
  for (const url of [
    '/', '/about', '/static/a.png?x=1#y', '/a//b', '/%2F%2Fx',
    'https://example.com', 'https:', 'mailto:a@b.c', 'tel:+1555', '/café',
  ]) {
    assert.equal(safeUrl(url), true, url);
  }
  for (const url of [
    '', '//evil.example', '/\\evil.example', 'http://example.com', 'HTTPS://example.com',
    'javascript:alert(1)', 'JavaScript:x', 'data:text/html,x', 'about:blank', 'blob:x',
    ' /about', '/a b', '/a\tb', '/a\nb', '/a\rb', '/\x7f', '\0/', 'relative/path', '?q', '#f',
    'mailto', 'tel', 'https', '\u0001https://example.com',
  ]) {
    assert.equal(safeUrl(url), false, JSON.stringify(url));
  }
});
