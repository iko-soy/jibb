"""Metadata shared by the eval and ship golden runners."""
import os
import re

KNOT = re.compile(r'^[a-z0-9.\-_~]+$')
TERM = re.compile(r'^[a-z][a-z0-9-]*$')


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
    return ui_path(path, filename)


def ui_path(path, filename):
    """Validate a logical Jibb path and render it as a Hoon path."""
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


def sur_imports(folder):
    """Selected /sur molds as (module, mold, fixture path), in file order.

    fixtures are plain text so the ship's -test does not build them as Hoon
    test files. Each module is compiled once per selected mold for now.
    """
    filename = os.path.join(folder, 'imports.txt')
    try:
        with open(filename, encoding='utf-8') as f:
            lines = list(f)
    except FileNotFoundError:
        return []
    except UnicodeError:
        raise ValueError('%s: imports must be UTF-8' % filename)
    out, seen = [], set()
    for number, line in enumerate(lines, 1):
        parts = line.split()
        if len(parts) != 2 or not all(TERM.fullmatch(p) for p in parts):
            raise ValueError('%s:%d: expected a module and mold name' %
                             (filename, number))
        module, mold = parts
        if (module, mold) in seen:
            raise ValueError('%s:%d: duplicate imported mold' % (filename, number))
        fixture = os.path.join(folder, 'sur', module + '.txt')
        if not os.path.isfile(fixture):
            raise ValueError('%s:%d: no fixture at %s' % (filename, number, fixture))
        seen.add((module, mold))
        out.append((module, mold, fixture))
    if out and not wants_types(folder):
        raise ValueError('%s: imported molds require a types output' % filename)
    return out


def mark_imports(folder):
    """Selected mark names and plain-text Hoon source fixtures, in file order."""
    filename = os.path.join(folder, 'marks.txt')
    try:
        with open(filename, encoding='utf-8') as f:
            lines = list(f)
    except FileNotFoundError:
        return []
    except UnicodeError:
        raise ValueError('%s: marks must be UTF-8' % filename)
    out, seen = [], set()
    for number, line in enumerate(lines, 1):
        parts = line.split()
        if len(parts) != 1 or not TERM.fullmatch(parts[0]):
            raise ValueError('%s:%d: expected a mark name' % (filename, number))
        mark = parts[0]
        if mark in seen:
            raise ValueError('%s:%d: duplicate imported mark' % (filename, number))
        fixture = os.path.join(folder, 'mar', mark + '.txt')
        if not os.path.isfile(fixture):
            raise ValueError('%s:%d: no fixture at %s' % (filename, number, fixture))
        seen.add(mark)
        out.append((mark, fixture))
    if out and not wants_types(folder):
        raise ValueError('%s: imported marks require a types output' % filename)
    return out


def module_fixtures(folder):
    """Logical Jibb paths, Hoon paths, and sources in a case's modules tree."""
    filename = os.path.join(folder, 'modules.txt')
    try:
        with open(filename, encoding='utf-8') as f:
            lines = list(f)
    except FileNotFoundError:
        return []
    except UnicodeError:
        raise ValueError('%s: module paths must be UTF-8' % filename)
    out, seen = [], set()
    for number, line in enumerate(lines, 1):
        logical = line[:-1] if line.endswith('\n') else line
        if not logical.strip() or logical.lstrip().startswith('#'):
            continue
        where = '%s:%d' % (filename, number)
        hoon_path = ui_path(logical, where)
        if logical in seen:
            raise ValueError('%s: duplicate module fixture' % where)
        fixture = os.path.join(folder, 'modules', *logical.split('/')[1:])
        if not os.path.isfile(fixture):
            raise ValueError('%s: no fixture at %s' % (where, fixture))
        seen.add(logical)
        out.append((logical, hoon_path, fixture))
    return out


def wants_modules(folder):
    """A manifest, even without sources, opts into module import checking."""
    return os.path.isfile(os.path.join(folder, 'modules.txt'))
