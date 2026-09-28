"""Assemble individually generated frames into a sprite sheet and trace hit shapes from them.

Each frame is a Codex image on a magenta key (art_source/frames/<set>/<name>.png). This keys the
magenta out, crops to the drawn pixels, scales to the frame's width in tools/art/<set>_frames.json
(keeping the aspect), thresholds the alpha so edges stay crisp, traces a hurt shape (the convex hull
of the drawn outline) and, where the frame has `attack_from`, an attack shape (the hull of the part
of the outline at or right of that fraction of the width), and packs everything into
assets/sheets/<set>.png + assets/sheets/<set>.json.

Shapes are frame-local pixels with the origin at the bottom centre (x right, y down: the floor
line is y = 0). Run from the project root (the whole command, no cd or pipes):
  uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py slime
"""
import json
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_sheets import crisp_alpha, keyed  # noqa: E402

SRC = "art_source/frames"
OUT = "assets/sheets"
NAME = re.compile(r"^[a-z0-9_]+$")
SHEET_WIDTH = 512
PAD = 1


def fit_frame(im, width):
    """Key out magenta, crop to the drawn pixels, scale to `width` keeping the aspect, crisp the alpha."""
    im = keyed(im.convert("RGBA"))
    box = im.split()[3].getbbox()
    if box is None:
        raise ValueError("frame is empty after keying")
    im = im.crop(box)
    height = max(1, round(im.height * width / im.width))
    return crisp_alpha(im.resize((width, height), Image.BOX))


def boundary_corners(im):
    """Corners of every opaque pixel that touches transparency or the frame edge."""
    w, h = im.size
    px = im.load()

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y][3] >= 128

    pts = set()
    for y in range(h):
        for x in range(w):
            if not opaque(x, y):
                continue
            if all(opaque(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                continue
            pts.update({(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)})
    return pts


def convex_hull(points):
    """Andrew's monotone chain; the hull without a repeated last point."""
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def cross(o, p, q):
        return (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0])

    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def to_local(points, w, h):
    return [[x - w / 2.0, y - float(h)] for x, y in points]


def trace(im, attack_from):
    """(hurt, attack) shapes, frame-local. `attack` is empty unless `attack_from` is given."""
    w, h = im.size
    pts = boundary_corners(im)
    hurt = to_local(convex_hull(pts), w, h)
    attack = []
    if attack_from is not None:
        front = {p for p in pts if p[0] >= attack_from * w}
        if len(front) >= 3:
            attack = to_local(convex_hull(front), w, h)
    return hurt, attack


def pack(frames):
    """Shelf-pack the frames in order. Returns (sheet, {name: (x, y, w, h)})."""
    x = y = row_h = 0
    rects = {}
    for name, im in frames.items():
        if x + im.width + PAD > SHEET_WIDTH and x > 0:
            x = 0
            y += row_h + PAD
            row_h = 0
        rects[name] = (x, y, im.width, im.height)
        x += im.width + PAD
        row_h = max(row_h, im.height)
    sheet = Image.new("RGBA", (SHEET_WIDTH, y + row_h), (0, 0, 0, 0))
    for name, im in frames.items():
        sheet.paste(im, rects[name][:2])
    return sheet, rects


def main():
    if len(sys.argv) != 2 or not NAME.match(sys.argv[1]):
        raise SystemExit("usage: assemble_frames.py <set>")
    rig_set = sys.argv[1]
    data = json.load(open("tools/art/%s_frames.json" % rig_set))
    fitted, shapes = {}, {}
    for f in data["frames"]:
        src = os.path.join(SRC, rig_set, f["name"] + ".png")
        if not os.path.exists(src):
            raise SystemExit("missing %s (generate it first)" % src)
        fitted[f["name"]] = fit_frame(Image.open(src), f["width"])
        shapes[f["name"]] = trace(fitted[f["name"]], f.get("attack_from"))
    sheet, rects = pack(fitted)
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, rig_set + ".png"))
    frames = {n: {"rect": list(rects[n]), "hurt": shapes[n][0], "attack": shapes[n][1]} for n in fitted}
    with open(os.path.join(OUT, rig_set + ".json"), "w") as out:
        json.dump({"set": rig_set, "image": rig_set + ".png", "frames": frames}, out)
    for n, im in fitted.items():
        print("frame", n, im.size)
    print("wrote", os.path.join(OUT, rig_set + ".png"), sheet.size)


if __name__ == "__main__":
    main()
