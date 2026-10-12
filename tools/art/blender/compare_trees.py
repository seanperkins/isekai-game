"""Which forms of a goblin_tree.py output differ from another render of them.

    python3 tools/art/blender/compare_trees.py BASE NEW

A tree is a folder with one folder per form: frames/<clip>_<n>.png and raw/meta.json. A form differs when `new` lacks it, when its frame files differ in name, size or pixels, or when
its meta.json says another `hands`, `ppu`, `canvas` or `hold`. Forms only `new` has are ignored. Prints the differing forms and exits 1 if there are any: the gate that says a change to
how the goblins are built left every picture it was not meant to touch exactly as it was.
"""
import json
import os
import sys

from PIL import Image

COMPARED_META = ("hands", "ppu", "canvas", "hold")


def _frames(folder):
    path = os.path.join(folder, "frames")
    return sorted(n for n in os.listdir(path) if n.endswith(".png")) if os.path.isdir(path) else []


def _meta(folder):
    with open(os.path.join(folder, "raw", "meta.json")) as fh:
        return json.load(fh)


def _same_picture(a, b):
    with Image.open(a) as x, Image.open(b) as y:
        x, y = x.convert("RGBA"), y.convert("RGBA")
        return x.size == y.size and x.tobytes() == y.tobytes()


def _differs(base, new):
    if _frames(base) != _frames(new):
        return True
    if any(not _same_picture(os.path.join(base, "frames", n), os.path.join(new, "frames", n)) for n in _frames(base)):
        return True
    a, b = _meta(base), _meta(new)
    return any(a.get(k) != b.get(k) for k in COMPARED_META)


def different_forms(base, new):
    """The sorted names of the forms of `base` that `new` does not reproduce exactly."""
    out = []
    for form in sorted(os.listdir(base)):
        if not os.path.isdir(os.path.join(base, form, "raw")):
            continue   # not a form folder (the tree's contact sheets)
        other = os.path.join(new, form)
        if not os.path.isdir(os.path.join(other, "raw")) or _differs(os.path.join(base, form), other):
            out.append(form)
    return out


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 2:
        raise SystemExit("usage: compare_trees.py BASE NEW")
    forms = different_forms(*argv)
    for form in forms:
        print(form)
    return 1 if forms else 0


if __name__ == "__main__":
    sys.exit(main())
