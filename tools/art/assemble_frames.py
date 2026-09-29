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
import math
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


def cropped(im):
    """Key out magenta and crop to the drawn pixels."""
    im = keyed(im.convert("RGBA"))
    box = im.split()[3].getbbox()
    if box is None:
        raise ValueError("frame is empty after keying")
    return im.crop(box)


def anchor_scale(im, width):
    """The scale that draws the anchor frame `width` px wide; every frame of the set shares it."""
    return width / cropped(im).width


def apply_look(im, look):
    """Blend the RGB of the opaque pixels toward white (`lighten`, 0..1) and then toward a colour (`tint` [r,g,b]
    by `tint_amount`). Runs on the KEYED, cropped image so the magenta key is already gone and never drifts."""
    if not look:
        return im
    im = im.copy()
    px = im.load()
    lighten = float(look.get("lighten", 0.0))
    tint = look.get("tint")
    amount = float(look.get("tint_amount", 0.0))
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, al = px[x, y]
            if al == 0:
                continue
            rgb = [r, g, b]
            if lighten:
                rgb = [v + (255 - v) * lighten for v in rgb]
            if tint and amount:
                rgb = [v + (t - v) * amount for v, t in zip(rgb, tint)]
            px[x, y] = tuple(int(round(v)) for v in rgb) + (al,)
    return im


def fit_scaled(im, scale, look=None):
    """Key, crop, apply a `look` (see apply_look), and scale by a shared factor (BOX), then crisp the alpha."""
    c = apply_look(cropped(im), look)
    size = (max(1, round(c.width * scale)), max(1, round(c.height * scale)))
    return crisp_alpha(c.resize(size, Image.BOX))


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


def _simplify(chain, eps):
    """Douglas-Peucker on an open chain of (x, y) points."""
    if len(chain) < 3:
        return list(chain)
    (x1, y1), (x2, y2) = chain[0], chain[-1]
    dx, dy = x2 - x1, y2 - y1
    norm = (dx * dx + dy * dy) ** 0.5
    worst, at = 0.0, 0
    for i in range(1, len(chain) - 1):
        px, py = chain[i]
        d = abs(dy * (px - x1) - dx * (py - y1)) / norm if norm else ((px - x1) ** 2 + (py - y1) ** 2) ** 0.5
        if d > worst:
            worst, at = d, i
    if worst <= eps:
        return [chain[0], chain[-1]]
    return _simplify(chain[:at + 1], eps)[:-1] + _simplify(chain[at:], eps)


def outline(im, x_from=0, eps=0.35):
    """A polygon that follows the drawn pixels: each column's top and bottom edge, simplified. Unlike the
    convex hull it does not fill the empty space under a raised tail or between wings. `x_from` keeps only
    the columns at or right of it. Points are (x, y) pixel-corner coordinates."""
    w, h = im.size
    px = im.load()
    top, bottom = [], []
    for x in range(int(x_from), w):
        ys = [y for y in range(h) if px[x, y][3] >= 128]
        if not ys:
            continue
        top += [(x, min(ys)), (x + 1, min(ys))]
        bottom += [(x, max(ys) + 1), (x + 1, max(ys) + 1)]
    if not top:
        return []
    # drop repeated points, then simplify the two edges separately so the corners survive
    def dedupe(chain):
        out = []
        for p in chain:
            if not out or out[-1] != p:
                out.append(p)
        return out
    upper = _simplify(dedupe(top), eps)
    lower = _simplify(dedupe(list(reversed(bottom))), eps)
    poly = upper + lower
    result = []
    for p in poly:
        if not result or result[-1] != p:
            result.append(p)
    if len(result) > 1 and result[0] == result[-1]:
        result.pop()
    return result


def to_local(points, w, h):
    return [[x - w / 2.0, y - float(h)] for x, y in points]


def trace(im, attack_from, eps=0.35):
    """(hurt, attack) shapes, frame-local. `attack` is empty unless `attack_from` is given. Both follow the
    drawn outline (see `outline`), not the convex hull."""
    w, h = im.size
    hurt = to_local(outline(im, eps=eps), w, h)
    attack = []
    if attack_from is not None:
        front = outline(im, x_from=math.ceil(attack_from * w))
        if len(front) >= 3:
            attack = to_local(front, w, h)
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
    scale = None
    # a derived set (e.g. the Pale Moth) reads another set's source frames and lightens/tints the keyed crop
    src_set = data.get("derive_from", rig_set)
    look = {k: data[k] for k in ("lighten", "tint", "tint_amount") if k in data}
    if "anchor" in data:  # one shared scale, so a stretched or wing-raised frame is not blown up to a fixed width
        by_name = {f["name"]: f for f in data["frames"]}
        scale = anchor_scale(Image.open(os.path.join(SRC, src_set, data["anchor"] + ".png")), by_name[data["anchor"]]["width"])
    for f in data["frames"]:
        src = os.path.join(SRC, src_set, f["name"] + ".png")
        if not os.path.exists(src):
            raise SystemExit("missing %s (generate it first)" % src)
        fitted[f["name"]] = fit_scaled(Image.open(src), scale, look) if scale else fit_frame(Image.open(src), f["width"])
        shapes[f["name"]] = trace(fitted[f["name"]], f.get("attack_from"), f.get("outline_eps", 0.35))
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
