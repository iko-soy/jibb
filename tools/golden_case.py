"""Metadata shared by the eval and ship golden runners."""
import os
import re

KNOT = re.compile(r'^[a-z0-9.\-_~]+$')


def source_path(folder):
    """The optional logical /ui path as a Hoon path expression."""
    filename = os.path.join(folder, 'path.txt')
    try:
        with open(filename, encoding='utf-8') as f:
            raw = f.read()
    except FileNotFoundError:
        return None
    except UnicodeError:
        raise ValueError('%s: path must be UTF-8' % filename)
    path = raw[:-1] if raw.endswith('\n') else raw
    parts = path.split('/')
    if len(parts) < 3 or parts[:2] != ['', 'ui'] or not parts[-1].endswith('.jibb'):
        raise ValueError('%s: expected an absolute /ui/.../*.jibb path' % filename)
    parts[-1] = parts[-1][:-5]
    if any(not KNOT.fullmatch(p) or p in ('.', '..') for p in parts[1:]):
        raise ValueError('%s: path components must be nonempty knots' % filename)
    return '~[' + ' '.join('~.' + p for p in parts[1:] + ['jibb']) + ']'


def wants_types(folder):
    """An expect-types line keeps a deleted expected file from disabling a test."""
    try:
        with open(os.path.join(folder, 'about.txt'), encoding='utf-8') as f:
            marked = any(line.startswith('expect-types:') for line in f)
    except FileNotFoundError:
        marked = False
    return marked or os.path.isfile(os.path.join(folder, 'types.txt'))
