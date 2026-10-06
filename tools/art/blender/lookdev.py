"""Look at several goblin forms side by side in one pose: render each (idle by default) and lay the chosen frame of each in a row.

    python3 tools/art/blender/lookdev.py redcap paladin tinker [--anim idle] [--frame 0] [--zoom 4] [--out DIR]
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import spike  # noqa: E402


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("forms", nargs="+")
    ap.add_argument("--anim", default="idle")
    ap.add_argument("--frame", type=int, default=0)
    ap.add_argument("--zoom", type=int, default=4)
    ap.add_argument("--out", default=os.path.join(ROOT, ".tmp", "lookdev"))
    ap.add_argument("--creature", default="goblin")
    a = ap.parse_args(argv)
    shots = []
    for name in a.forms:
        raw = os.path.join(a.out, name, "raw")
        os.makedirs(raw, exist_ok=True)
        variant = None if name in ("goblin", "base") else name
        spike.render(a.creature, raw, variant, a.anim, 4)
        spike.process(raw, os.path.join(a.out, name), colours=24, outline=True)
        im = Image.open(os.path.join(a.out, name, "frames", "%s_%d.png" % (a.anim, a.frame))).convert("RGBA")
        shots.append((name, im.crop(im.getbbox())))
    pad, head = 8, 14
    h = max(im.height for _, im in shots) * a.zoom
    w = sum(im.width * a.zoom + pad for _, im in shots) + pad
    sheet = Image.new("RGBA", (w, h + head + 2 * pad), spike.BACKDROP)
    d = ImageDraw.Draw(sheet)
    x = pad
    for name, im in shots:
        big = im.resize((im.width * a.zoom, im.height * a.zoom), Image.NEAREST)
        sheet.alpha_composite(big, (x, head + pad + h - big.height))
        d.text((x, 2), name, fill=(220, 220, 230, 255))
        x += big.width + pad
    path = os.path.join(a.out, "lookdev.png")
    sheet.save(path)
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
