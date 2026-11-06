"""Load the host-supplied checked prelude group source bundle.

The manifest names logical Jibb module paths without their final /jibb mark.
`group FACE /path` exposes a qualified group; `source /path` supplies a
private dependency without adding a source-level face. A `reader MODULE /sur/MODULE ARM` entry supplies the exact Hoon source
for a reader-certified generator arm.
"""

import os
import re

FACE = re.compile(r"^[a-z][a-z0-9-]*$")
PART = re.compile(r"^[a-z0-9.\-_~]+$")


def load_all(root):
    desk = os.path.realpath(os.path.join(root, "jibb-dev"))
    manifest = os.path.join(desk, "lib", "jibb", "prelude-groups.txt")
    try:
        with open(manifest, encoding="utf-8") as stream:
            lines = list(stream)
    except OSError as error:
        raise ValueError("cannot read prelude group manifest: %s" % error) from error
    groups, modules, readers = [], [], []
    faces, paths, reader_names = set(), {}, set()
    for number, line in enumerate(lines, 1):
        words = line.partition("#")[0].split()
        if not words:
            continue
        if words[0] == "reader" and len(words) == 4:
            _, module, logical, name = words
            if (not FACE.fullmatch(module) or not FACE.fullmatch(name) or
                    logical != "/sur/" + module or (module, name) in reader_names):
                raise ValueError("invalid or duplicate prelude reader at line %d" % number)
            reader_names.add((module, name))
            filename = os.path.realpath(os.path.join(desk, "sur", module + ".hoon"))
            if os.path.commonpath((desk, filename)) != desk:
                raise ValueError("prelude reader source escapes its desk at line %d" % number)
            try:
                with open(filename, "rb") as stream:
                    source = stream.read()
            except OSError as error:
                raise ValueError("cannot read prelude reader source %s: %s" % (filename, error)) from error
            readers.append((module, name, logical, filename, source))
            continue
        if words[0] == "group" and len(words) == 3:
            _, face, logical = words
            if not FACE.fullmatch(face) or face in faces:
                raise ValueError("invalid or duplicate group face at line %d" % number)
            faces.add(face)
        elif words[0] == "source" and len(words) == 2:
            _, logical = words
            face = None
        else:
            raise ValueError("invalid prelude group entry at line %d" % number)
        parts = logical.split("/")
        if (not logical.startswith("/") or len(parts) < 2 or
                any(not PART.fullmatch(part) or part in (".", "..") for part in parts[1:])):
            raise ValueError("invalid prelude group module path at line %d" % number)
        filename = os.path.realpath(os.path.join(desk, *parts[1:]) + ".jibb")
        if os.path.commonpath((desk, filename)) != desk:
            raise ValueError("prelude group source escapes its desk at line %d" % number)
        try:
            with open(filename, "rb") as stream:
                source = stream.read()
        except OSError as error:
            raise ValueError("cannot read prelude group source %s: %s" % (filename, error)) from error
        previous = paths.setdefault(logical, source)
        if previous != source:
            raise ValueError("conflicting prelude group source at line %d" % number)
        entry = (face, logical, filename, source)
        (groups if face is not None else modules).append(entry)
    return groups, modules, readers


def load(root):
    groups, modules, _ = load_all(root)
    return groups, modules


def hoon_path(logical):
    return "~[" + " ".join("~." + part for part in logical.split("/")[1:] + ["jibb"]) + "]"


def sur_path(logical):
    return "~[" + " ".join("~." + part for part in logical.split("/")[1:] + ["hoon"]) + "]"
