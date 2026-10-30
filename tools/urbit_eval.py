"""Run Hoon through `urbit eval` for the dev tools, without a ship.

tools/golden and tools/hoon build one Hoon program out of segments (a
prefix, the library file, then a harness or an expression), run it with
`urbit eval`, and map the positions in eval's errors and crash traces
back to the segment, and the line in it, that they point at.

How `urbit eval` (vere 4.6) behaves, as found by trying it:

- It reads the program from stdin.  Boot noise ("loom: mapped ...",
  "lite: ...", "eval (run):") goes to stderr.
- Plain mode prints the result as Hoon prints a vase, with ANSI colours
  and \\r\\n line ends, to stdout.
- `-j` prints the jammed result as \\xNN escapes, but only every other
  byte of it, so it can't be decoded.  `-j -n` writes an exact newt
  frame instead: a 0 byte, the length as 4 little-endian bytes, then the
  jam.  This module uses `-j -n`.
- A failure prints its trace to stdout and "eval: bail: %exit" (or
  %meme, ...) to stderr, and still exits with status 0.
- Type errors carry no source positions unless the program turns on
  debug spots, so every program here starts with `!:`.  Spots print as
  /::[l c].[l c]> at compile time and /:<[l c].[l c]> at run time, and
  a syntax error as {l c}.  Lines and columns count from 1, columns in
  bytes.
- `~&` output is dropped.  mule catches crashes, but not the bails that
  end the whole eval, such as running out of memory (%meme) or asking
  for an atom bigger than the loom (%fail).
"""

import os
import re
import shutil
import subprocess
import tempfile

from noun import bytes_to_atom, cue

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_LIB = os.path.join(ROOT, 'jibb-dev', 'lib', 'jibb.hoon')

ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')
BOOT_NOISE = re.compile(
    r'^(loom: mapped \S+|lite: .*|eval \([a-z, ]+\):|newt meaningless .*)?$')
BAIL = re.compile(r'^(?:eval: )?bail: %?(\w+)')
# Numbers past 999 print with separators: 2,554 at compile time, 3.411
# in crash traces.
NUM = r'\d{1,3}(?:[.,]\d{3})*'
SPOT = re.compile(
    r'(?P<path>/[^\s:<\[]*)?:(?P<kind>[:<])'
    r'\[(?P<l1>%s) (?P<c1>%s)\]\.\[(?P<l2>%s) (?P<c2>%s)\]>' % ((NUM,) * 4))
SYNTAX = re.compile(r'^\{(?P<l>%s) (?P<c>%s)\}$' % (NUM, NUM))
BARE_PATH = re.compile(r'^/[^\s]*$')


class ToolError(Exception):
    """A failure that stops a tool: report it and exit with status 2."""


def display_path(path):
    """A path as the tools print it: from the repo root when inside it."""
    path = os.path.abspath(path)
    rel = os.path.relpath(path, ROOT)
    return path if rel.startswith('..') else rel


def strip_ansi(text):
    return ANSI.sub('', text).replace('\r', '')


def cord_literal(data):
    """A Hoon cord literal, '...', holding exactly these bytes.

    Printable ASCII stays as it is, quotes and backslashes are escaped,
    and every other byte, UTF-8 included, is written \\XX.

    >>> print(cord_literal("it's \\\\ \\"q\\" é\\n".encode()))
    'it\\'s \\\\ "q" \\c3\\a9\\0a'
    """
    out = ["'"]
    for b in data:
        if b == 0x5c:
            out.append('\\\\')
        elif b == 0x27:
            out.append("\\'")
        elif 0x20 <= b < 0x7f:
            out.append(chr(b))
        else:
            out.append('\\%02x' % b)
    out.append("'")
    return ''.join(out)


CORD_PIECE = 1024


def cord_pieces(data, size=CORD_PIECE):
    """data cut into pieces whose cord literals `rap 3` joins back into
    data: one piece per line, ending in its newline, and a line longer
    than size cut about every size bytes, since Hoon reads a cord
    literal in about quadratic time (a 72 KB one takes 11 s).  A piece
    is an atom, which loses NULs at its end, so a cut moves past NULs;
    only the NULs ending data are lost, as in Clay, where a file is one
    atom.

    >>> cord_pieces(b'ab\\ncd')
    [b'ab\\n', b'cd']
    >>> cord_pieces(b'abcdefg\\n', 3)
    [b'abc', b'def', b'g\\n']
    >>> cord_pieces(b'ab\\x00\\x00cdef', 3)
    [b'ab\\x00\\x00c', b'def']
    >>> cord_pieces(b'')
    [b'']
    """
    lines = data.split(b'\n')
    lines = [line + b'\n' for line in lines[:-1]] + lines[-1:]
    pieces = []
    for line in lines:
        start = 0
        while len(line) - start > size:
            cut = start + size
            while cut < len(line) and line[cut - 1] == 0:
                cut += 1
            pieces.append(line[start:cut])
            start = cut
        if start < len(line) or not pieces:
            pieces.append(line[start:])
    return pieces


def read_text(path):
    """A file's text, losslessly: bytes that aren't UTF-8 survive."""
    with open(path, 'rb') as f:
        return f.read().decode('utf-8', 'surrogateescape')


class Segment:
    """Consecutive lines of a program that came from one place."""

    def __init__(self, name, kind, start, lines):
        self.name = name      # what errors call it: a path, or (harness)
        self.kind = kind      # 'prefix', 'lib', 'harness' or 'expr'
        self.start = start    # its first line in the program, from 1
        self.lines = lines


class Program:
    """A Hoon program built from segments, each starting on a new line."""

    def __init__(self):
        self.parts = []
        self.segments = []
        self.next_line = 1

    def add(self, text, name, kind):
        if not text.endswith('\n'):
            text += '\n'
        lines = text.split('\n')[:-1]
        self.segments.append(Segment(name, kind, self.next_line, lines))
        self.parts.append(text)
        self.next_line += len(lines)

    def text(self):
        return ''.join(self.parts)

    def encode(self):
        return self.text().encode('utf-8', 'surrogateescape')

    def locate(self, line):
        """The segment holding a program line, and the line within it."""
        for seg in self.segments:
            if seg.start <= line < seg.start + len(seg.lines):
                return seg, line - seg.start + 1
        return None, line


def library_program(lib_path):
    """A program that starts `!:  =>  <library>`, for adding what follows.

    `!:` turns on debug spots, so errors and crash traces have positions;
    `=>` makes the library's core the subject of what's added next.
    """
    prog = Program()
    prog.add('!:\n=>', '(prefix)', 'prefix')
    prog.add(read_text(lib_path), display_path(lib_path), 'lib')
    return prog


def find_urbit():
    urbit = os.environ.get('URBIT') or shutil.which('urbit')
    if not urbit:
        raise ToolError('urbit is not on PATH; install vere, or set URBIT '
                        'to its path')
    return urbit


class EvalResult:
    def __init__(self):
        self.ok = False
        self.noun = None        # the result, in jam mode
        self.text = ''          # the printed result, in plain mode
        self.trace = []         # eval's error output, as clean lines
        self.notes = []         # stderr lines that aren't boot noise
        self.bail = None        # 'exit', 'meme', ... when eval bailed
        self.timed_out = False
        self.timeout = None     # the time limit it ran under, in seconds
        self.status = None      # the process's exit status

    def describe(self):
        """A few words on how eval failed."""
        if self.timed_out:
            return 'urbit eval timed out after %g s' % self.timeout
        if self.bail == 'meme':
            return 'urbit eval ran out of memory (bail: %meme)'
        if self.bail == 'over':
            return 'urbit eval overflowed its stack (bail: %over)'
        if self.bail:
            return 'urbit eval failed (bail: %%%s)' % self.bail
        if self.status:
            return 'urbit eval exited with status %s' % self.status
        return 'urbit eval failed'

    def is_compile_error(self):
        """Whether eval failed while compiling, before running anything.

        Compiling prints {l c} for a syntax error and /::[..]> spots for
        the rest, type errors and stack overflows alike; a crash at run
        time prints /:<[..]>.  A trace without spots, as under !., counts
        as compiling when it bailed %exit, since everything the harness
        runs is under mule."""
        if self.timed_out:
            return False
        if any(SYNTAX.match(line.strip()) for line in self.trace):
            return True
        kinds = {m.group('kind') for line in self.trace
                 for m in SPOT.finditer(line)}
        if '<' in kinds:
            return False
        return ':' in kinds or self.bail == 'exit'


def _newt_frame(out):
    """The jam bytes of the newt frame that ends stdout, or None."""
    start = 0
    while True:
        p = out.find(b'\x00', start)
        if p < 0:
            return None
        for width in (4, 8):
            body = p + 1 + width
            if body <= len(out) and \
                    int.from_bytes(out[p + 1:body], 'little') == len(out) - body:
                return out[body:]
        start = p + 1


def _clean_lines(raw):
    return strip_ansi(raw.decode('utf-8', 'replace')).split('\n')


def run_eval(program, jam, timeout=None):
    """Run a Program under urbit eval and return an EvalResult.

    jam=True runs `urbit eval -j -n` and decodes the result into .noun;
    jam=False keeps the printed result, colours stripped, in .text.
    """
    cmd = [find_urbit(), 'eval'] + (['-j', '-n'] if jam else [])
    res = EvalResult()
    res.timeout = timeout
    # stdout goes to a file, not a pipe: urbit eval exits before a pipe
    # drains, so piped output is cut off at 64 KB.
    with tempfile.TemporaryFile() as out:
        try:
            proc = subprocess.run(cmd, input=program.encode(),
                                  stdout=out, stderr=subprocess.PIPE,
                                  timeout=timeout)
        except subprocess.TimeoutExpired:
            res.timed_out = True
            out.seek(0)
            res.trace = [l for l in _clean_lines(out.read()) if l.strip()]
            return res
        out.seek(0)
        stdout = out.read()
    res.status = proc.returncode
    for line in _clean_lines(proc.stderr):
        m = BAIL.match(line.strip())
        if m:
            res.bail = m.group(1)
        elif not BOOT_NOISE.match(line.strip()):
            res.notes.append(line.rstrip())
    if not res.bail and proc.returncode == 0:
        if not jam:
            res.text = strip_ansi(stdout.decode('utf-8', 'replace'))
            res.ok = True
            return res
        frame = _newt_frame(stdout)
        if frame is not None:
            res.noun = cue(bytes_to_atom(frame))
            res.ok = True
            return res
    res.trace = [l.rstrip() for l in _clean_lines(stdout) if l.strip()]
    return res


class Spot:
    """A range of program text, placed in its segment."""

    def __init__(self, prog, l1, c1, l2=None, c2=None):
        self.seg, self.line = prog.locate(l1)
        self.col = c1
        end_seg, self.end_line = prog.locate(l1 if l2 is None else l2)
        self.end_col = c1 if c2 is None else c2
        if end_seg is not self.seg:
            self.end_line = None    # it runs past its segment

    @property
    def kind(self):
        return self.seg.kind if self.seg else 'prefix'

    def label(self):
        """name:line:col, then -col, -line:col or -(end) for a range."""
        if self.seg is None:
            return '(program)'
        out = '%s:%d:%d' % (self.seg.name, self.line, self.col)
        if self.end_line is None:
            return out + '-(end)'
        if (self.end_line, self.end_col) == (self.line, self.col):
            return out
        if self.end_line == self.line:
            return out + '-%d' % self.end_col
        return out + '-%d:%d' % (self.end_line, self.end_col)

    def excerpt(self, indent='  '):
        """The spot's first line with carets under it; '' if none."""
        if self.seg is None or not 1 <= self.line <= len(self.seg.lines):
            return ''
        text = self.seg.lines[self.line - 1]
        raw = text.encode('utf-8', 'surrogateescape')

        def chars(nbytes):  # columns count bytes; carets count characters
            return len(raw[:max(nbytes, 0)].decode('utf-8', 'replace'))

        lead = chars(self.col - 1)
        if self.end_line == self.line and self.end_col > self.col:
            width = chars(self.end_col - 1) - lead
        else:
            width = 1
        gutter = str(self.line)
        return '%s%s | %s\n%s%s | %s%s' % (
            indent, gutter, text.replace('\t', ' '),
            indent, ' ' * len(gutter), ' ' * lead, '^' * max(width, 1))


def num(text):
    """An integer from Hoon's printing of one, separators and all."""
    return int(text.replace('.', '').replace(',', ''))


def _map_line(prog, line, keep, spots):
    """Rewrite one line's spots; None when every spot on it is dropped."""
    dropped = []

    def sub(m):
        spot = Spot(prog, num(m.group('l1')), num(m.group('c1')),
                    num(m.group('l2')), num(m.group('c2')))
        if spot.kind not in keep:
            dropped.append(spot)
            return ''
        spots.append(spot)
        return spot.label()

    new = SPOT.sub(sub, line)
    if dropped and not new.strip():
        return None
    return new


def map_trace(prog, lines, keep=('lib', 'expr', 'harness')):
    """Rewrite the spots in eval's output as name:line:col, and drop
    frames in segments whose kind isn't kept.

    Returns the new lines and the kept spots, outermost first.
    """
    out, spots = [], []
    for i, line in enumerate(lines):
        bare = line.strip()
        m = SYNTAX.match(bare)
        if m:
            spot = Spot(prog, num(m.group('l')), num(m.group('c')))
            spots.append(spot)
            out.append(line.replace(bare, spot.label()))
            continue
        nxt = lines[i + 1].strip() if i + 1 < len(lines) else ''
        if BARE_PATH.match(bare) and SYNTAX.match(nxt):
            continue    # the program's path, printed before {l c}
        new = _map_line(prog, line, keep, spots)
        if new is not None:
            out.append(new)
    return out, spots


def fold_repeats(lines, min_reps=3, max_period=64):
    """Fold a block of lines that repeats back to back, as a recursion's
    frames do, into one copy and a note of how often it repeats.

    >>> fold_repeats(['a', 'b', 'c', 'b', 'c', 'b', 'c', 'd'])
    ['a', 'b', 'c', '(the 2 lines above repeat 2 more times)', 'd']
    """
    out, i, n = [], 0, len(lines)
    while i < n:
        best = None
        for k in range(1, min(max_period, (n - i) // min_reps) + 1):
            run = 0     # how far lines keep matching those k before them
            while i + k + run < n and lines[i + k + run] == lines[i + run]:
                run += 1
            reps = 1 + run // k
            if reps >= min_reps and (best is None or reps * k > best[0]):
                best = (reps * k, k, reps)
        if best is None:
            out.append(lines[i])
            i += 1
            continue
        covered, k, reps = best
        indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
        out += lines[i:i + k]
        out.append('%s(the %s above repeat%s %d more times)' % (
            indent, 'line' if k == 1 else '%d lines' % k,
            's' if k == 1 else '', reps - 1))
        i += covered
    return out


def focus(spots):
    """The spot to show an excerpt of: the innermost one in the library
    or the expression, else the innermost one."""
    for spot in reversed(spots):
        if spot.kind in ('lib', 'expr'):
            return spot
    return spots[-1] if spots else None


def failure_report(prog, res, headline, harness_headline=None):
    """eval's error output, mapped, with an excerpt of where it points.

    harness_headline replaces headline when the error is in the harness:
    the library compiled, but doesn't fit what the harness expects."""
    lines, spots = map_trace(prog, res.trace)
    lines = fold_repeats(lines)
    at = focus(spots)
    in_harness = at is not None and at.kind == 'harness'
    out = [harness_headline if in_harness and harness_headline else headline]
    out.append('')
    out += ['  ' + l for l in lines] or ['  (urbit eval printed no trace)']
    if at is not None:
        out += ['', 'at %s' % at.label()]
        ex = at.excerpt()
        if ex:
            out.append(ex)
        if in_harness:
            out += ['', 'That line is in the harness the tool writes after '
                    'the library; --save-program FILE writes it out.']
    notes = [n for n in res.notes if n.strip()]
    if notes:
        out += [''] + ['  ' + n for n in notes]
    return '\n'.join(out)


def lib_hint(lib_text):
    """A hint when the library starts with a Ford rune, which eval lacks,
    or with !., which turns off the spots that errors need."""
    for line in lib_text.split('\n'):
        s = line.strip()
        if not s or s.startswith('::'):
            continue
        if re.match(r'^/[-+=*~$%]', s):
            return ('hint: the library starts with the Ford rune %s, but '
                    'urbit eval has no Ford; the library must be one core '
                    'without /- /+ /= /* imports.' % s.split()[0])
        if s.startswith('!.'):
            return ('hint: the library starts with !., which turns off '
                    'source positions; take it out to see where errors are.')
        return None
    return None
