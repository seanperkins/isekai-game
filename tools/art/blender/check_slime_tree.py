"""Check a rendered slime tree before it goes into the game: every form's meta.json keeps the engine's timing (export_forms.check_timing) and every
frame of every clip is drawn inside its canvas and never below the ground line.

    python3 tools/art/blender/check_slime_tree.py [.tmp/slime-tree]
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import export_forms  # noqa: E402
import slime_forms  # noqa: E402


def check(tree):
    constants = export_forms.engine_constants()
    problems, checked = [], 0
    for form in slime_forms.FORMS:
        raw = os.path.join(tree, form, "raw")
        if not os.path.exists(os.path.join(raw, "meta.json")):
            problems.append("%s: not rendered" % form)
            continue
        with open(os.path.join(raw, "meta.json")) as fh:
            meta = json.load(fh)
        try:
            export_forms.check_timing(meta, constants)
        except ValueError as e:
            problems.append("%s: %s" % (form, e))
        ss = meta["ss"]
        size, ground = meta["canvas"] * ss, (meta["canvas"] - meta["margin"]) * ss
        for anim, count in meta["anims"].items():
            for i in range(count):
                with Image.open(os.path.join(raw, "%s_%d_albedo.png" % (anim, i))) as a:
                    box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                checked += 1
                if box is None:
                    problems.append("%s %s %d: nothing drawn" % (form, anim, i))
                elif not (box[0] > 0 and box[1] > 0 and box[2] < size):
                    problems.append("%s %s %d: outside the canvas %s" % (form, anim, i, box))
                elif box[3] > ground + ss:
                    problems.append("%s %s %d: %d px below the ground" % (form, anim, i, (box[3] - ground) // ss))
    return problems, checked


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    tree = argv[0] if argv else os.path.join(ROOT, ".tmp", "slime-tree")
    problems, checked = check(tree)
    for p in problems:
        print(p)
    print("%d forms, %d frames checked, %d problems" % (len(slime_forms.FORMS), checked, len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
