"""Urbit nouns for the dev tools: cue, jam, and atoms as bytes.

A noun is an int (an atom, never negative) or a Cell.  Nothing here
recurses, so lists of any length decode without hitting Python's
recursion limit.  /root/src/tools/pkg/pynoun is the reference this
follows; unlike it, this module needs nothing outside the standard
library.

Run `python3 tools/noun.py` to run the doctests.
"""


class Cell:
    """An ordered pair of nouns.

    >>> c = Cell(1, Cell(2, 3))
    >>> c.head, c.tail.head, c.tail.tail
    (1, 2, 3)
    >>> str(c)
    '[1 2 3]'
    """

    __slots__ = ('head', 'tail')

    def __init__(self, head, tail):
        self.head = head
        self.tail = tail

    def __eq__(self, other):
        # Iterative, so long lists compare without deep recursion.
        todo = [(self, other)]
        while todo:
            a, b = todo.pop()
            if a is b:
                continue
            if isinstance(a, Cell):
                if not isinstance(b, Cell):
                    return False
                todo.append((a.tail, b.tail))
                todo.append((a.head, b.head))
            elif isinstance(b, Cell) or a != b:
                return False
        return True

    def __ne__(self, other):
        return not self == other

    __hash__ = None

    def __repr__(self):
        return '<noun %s>' % show(self)

    def __str__(self):
        return show(self)


def is_cell(n):
    return isinstance(n, Cell)


def show(n):
    """Print a noun as Hoon prints raw nouns, tails flattened.

    >>> show(Cell(Cell(1, 2), Cell(3, 0)))
    '[[1 2] 3 0]'
    """
    out = []
    # Stack of pending work: nouns to print, or literal strings.
    todo = [(n, False)]
    while todo:
        item, tail_pos = todo.pop()
        if isinstance(item, str):
            out.append(item)
        elif isinstance(item, Cell):
            if not tail_pos:
                todo.append((']', False))
            todo.append((item.tail, True))
            todo.append((' ', False))
            todo.append((item.head, False))
            if not tail_pos:
                todo.append(('[', False))
        else:
            out.append(str(item))
    return ''.join(out)


def from_list(items, end=0):
    """Build a right-nested noun: a Hoon list when end is 0.

    >>> show(from_list([1, 2, 3]))
    '[1 2 3 0]'
    """
    n = end
    for item in reversed(items):
        n = Cell(item, n)
    return n


def to_list(n):
    """Read a null-terminated Hoon list; raise ValueError otherwise.

    >>> to_list(from_list([1, 2]))
    [1, 2]
    """
    items = []
    while isinstance(n, Cell):
        items.append(n.head)
        n = n.tail
    if n != 0:
        raise ValueError('not a list: ends in atom %d' % n)
    return items


def atom_to_bytes(a):
    """An atom's bytes, lowest first, as Hoon stores a cord.

    >>> atom_to_bytes(0x6362_61)
    b'abc'
    >>> atom_to_bytes(0)
    b''
    """
    if not isinstance(a, int) or a < 0:
        raise TypeError('not an atom: %r' % (a,))
    return a.to_bytes((a.bit_length() + 7) // 8, 'little')


def bytes_to_atom(b):
    """The atom whose bytes, lowest first, are b.  Trailing NULs are lost.

    >>> bytes_to_atom(b'abc') == 0x636261
    True
    """
    return int.from_bytes(b, 'little')


def cord(text):
    """The atom of a cord: UTF-8 text, first byte lowest.

    >>> atom_to_bytes(cord('héllo')).decode()
    'héllo'
    """
    return bytes_to_atom(text.encode('utf-8'))


class _Bits:
    """Read bits, lowest first, from an atom held as little-endian bytes."""

    def __init__(self, atom):
        self.data = atom_to_bytes(atom)
        self.size = len(self.data) * 8
        self.pos = 0

    def bit(self):
        p = self.pos
        self.pos = p + 1
        if p >= self.size:
            return 0
        return (self.data[p >> 3] >> (p & 7)) & 1

    def take(self, k):
        """The next k bits as an atom, in time linear in k."""
        if k == 0:
            return 0
        p = self.pos
        self.pos = p + k
        chunk = self.data[p >> 3:((p + k) >> 3) + 1]
        return (int.from_bytes(chunk, 'little') >> (p & 7)) & ((1 << k) - 1)

    def rub(self):
        """Read a length-prefixed atom, the inverse of jam's mat."""
        z = 0
        while not self.bit():
            z += 1
            if self.pos > self.size + 64:
                raise ValueError('cue: ran off the end of the input')
        if z == 0:
            return 0
        below = z - 1
        length = (1 << below) | self.take(below)
        return self.take(length)


def cue(atom):
    """Decode a jammed noun.

    >>> cue(2)
    0
    >>> show(cue(41))
    '[0 0]'
    >>> show(cue(22840095095806892874257389573))
    '[[1234567890987654321 1234567890987654321] 1234567890987654321 1234567890987654321]'
    """
    bits = _Bits(atom)
    refs = {}
    # Each frame is a cell under construction: [start, head, have_head].
    stack = []
    while True:
        start = bits.pos
        if not bits.bit():
            value = bits.rub()
            refs[start] = value
        elif bits.bit():
            ref = bits.rub()
            if ref not in refs:
                raise ValueError('cue: bad backreference %d' % ref)
            value = refs[ref]
        else:
            stack.append([start, None, False])
            continue
        # A whole noun is decoded: fill in the cells waiting for it.
        while stack:
            frame = stack[-1]
            if not frame[2]:
                frame[1] = value
                frame[2] = True
                break
            stack.pop()
            value = Cell(frame[1], value)
            refs[frame[0]] = value
        else:
            return value


class _BitWriter:
    def __init__(self):
        self.acc = 0
        self.pos = 0

    def put(self, value, k):
        if k:
            self.acc |= (value & ((1 << k) - 1)) << self.pos
            self.pos += k

    def mat(self, a):
        if a == 0:
            self.put(1, 1)
            return
        length = a.bit_length()
        b = length.bit_length()
        self.put(1 << b, b + 1)
        self.put(length & ((1 << (b - 1)) - 1), b - 1)
        self.put(a, length)


def jam(noun):
    """Encode a noun.  Repeated atoms become backreferences when shorter;
    cells are written out in full, which cue reads the same.

    >>> jam(0), jam(Cell(0, 0)), jam(4)
    (2, 41, 152)
    >>> all(cue(jam(n)) == n for n in [0, 1, 2, 255, 256, 2**64 + 7])
    True
    >>> n = from_list([cord('a'), cord('a'), Cell(5, 2**80), 0])
    >>> cue(jam(n)) == n
    True
    """
    out = _BitWriter()
    seen = {}
    todo = [noun]
    while todo:
        n = todo.pop()
        if isinstance(n, Cell):
            out.put(1, 1)
            out.put(0, 1)
            todo.append(n.tail)
            todo.append(n.head)
            continue
        if n < 0:
            raise TypeError('not an atom: %d' % n)
        ref = seen.get(n)
        if ref is not None and ref.bit_length() < n.bit_length():
            out.put(1, 1)
            out.put(1, 1)
            out.mat(ref)
        else:
            if ref is None:
                seen[n] = out.pos
            out.put(0, 1)
            out.mat(n)
    return out.acc


if __name__ == '__main__':
    import doctest
    import sys
    failures, tests = doctest.testmod()
    print('noun.py: %d doctests, %d failures' % (tests, failures))
    sys.exit(1 if failures else 0)
