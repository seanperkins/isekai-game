#!/usr/bin/env python3
"""Draws a 32x32 pixel icon for every form verb in tools/form_verbs.json into assets/sprites/icon_verb_<form>.png.

These are placeholders drawn by code, one glyph per verb kind in the form's own colour, so every verb has an icon in the HUD and the
Skills tab (a test requires one). Painted icons replace them later by overwriting the PNG and dropping the form from this run.
Needs Pillow. Run from the repo root:  uv run --with Pillow python tools/art/verb_icons.py
"""
import math
import os
import re
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import build_form_verbs as bfv  # noqa: E402

OUT = "assets/sprites"
SIZE = 32
BACK = (14, 22, 36, 255)


def ring_points(cx, cy, r, n):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def arrow(d, a, b, fg, w=2, head=4):
    d.line([a, b], fill=fg, width=w)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    left = (b[0] - head * math.cos(ang - 0.5), b[1] - head * math.sin(ang - 0.5))
    right = (b[0] - head * math.cos(ang + 0.5), b[1] - head * math.sin(ang + 0.5))
    d.polygon([b, left, right], fill=fg)


def g_bolt(d, fg):
    arrow(d, (7, 25), (25, 7), fg, 3, 6)


def g_burst(d, fg):
    for x, y in ring_points(16, 16, 10, 8):
        d.line([(16, 16), (x, y)], fill=fg, width=2)
    d.ellipse([12, 12, 20, 20], fill=fg)


def g_ring(d, fg):
    d.ellipse([6, 6, 26, 26], outline=fg, width=3)
    d.ellipse([14, 14, 18, 18], fill=fg)


def g_dash(d, fg):
    for dx in (0, 7, 14):
        d.line([(6 + dx, 8), (12 + dx, 16), (6 + dx, 24)], fill=fg, width=3)


def g_zone(d, fg):
    d.ellipse([5, 9, 27, 25], fill=fg[:3] + (90,), outline=fg)
    for x, y in ring_points(16, 17, 8, 6):
        d.point((x, y), fill=fg)


def g_mark(d, fg):
    d.ellipse([8, 8, 24, 24], outline=fg, width=2)
    for a, b in (((16, 3), (16, 11)), ((16, 21), (16, 29)), ((3, 16), (11, 16)), ((21, 16), (29, 16))):
        d.line([a, b], fill=fg, width=2)


def g_heal(d, fg):
    d.rectangle([13, 6, 18, 25], fill=fg)
    d.rectangle([6, 13, 25, 18], fill=fg)


def g_ward(d, fg):
    d.polygon([(16, 5), (26, 9), (25, 19), (16, 27), (7, 19), (6, 9)], outline=fg, fill=fg[:3] + (70,))
    d.line([(16, 9), (16, 22)], fill=fg, width=2)


def g_buff(d, fg):
    d.polygon([(16, 5), (26, 16), (19, 16), (19, 27), (13, 27), (13, 16), (6, 16)], fill=fg)


def g_pull(d, fg):
    for x, y in ring_points(16, 16, 12, 4):
        arrow(d, (x, y), (16 + (x - 16) * 0.35, 16 + (y - 16) * 0.35), fg, 2, 4)


def g_aura(d, fg):
    for r in (4, 8, 12):
        d.ellipse([16 - r, 16 - r, 16 + r, 16 + r], outline=fg)
    d.ellipse([14, 14, 18, 18], fill=fg)


def g_chain(d, fg):
    pts = [(7, 22), (16, 10), (25, 22)]
    d.line(pts, fill=fg, width=2)
    for x, y in pts:
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=fg, outline=BACK)


def g_engulf(d, fg):
    d.ellipse([5, 5, 27, 27], outline=fg, width=3)
    d.ellipse([12, 12, 20, 20], fill=fg)


def g_dissolve(d, fg):
    for x, y in ((9, 8), (17, 13), (24, 8)):
        d.polygon([(x, y), (x - 3, y + 6), (x + 3, y + 6)], fill=fg)
        d.ellipse([x - 3, y + 3, x + 3, y + 9], fill=fg)
    d.line([(5, 25), (27, 25)], fill=fg, width=2)


def g_glide(d, fg):
    d.arc([4, 4, 28, 28], 20, 160, fill=fg, width=3)
    d.line([(6, 22), (26, 22)], fill=fg, width=2)
    d.line([(10, 26), (22, 26)], fill=fg, width=2)


def g_anchor(d, fg):
    d.ellipse([11, 5, 21, 15], outline=fg, width=3)
    d.polygon([(16, 28), (10, 16), (22, 16)], fill=fg)


def g_decoy(d, fg):
    d.pieslice([8, 5, 24, 21], 180, 360, fill=fg)
    d.rectangle([8, 13, 24, 25], fill=fg)
    for x in (8, 14, 20):
        d.polygon([(x, 25), (x + 3, 29), (x + 6, 25)], fill=fg)
    d.ellipse([12, 11, 15, 14], fill=BACK)
    d.ellipse([18, 11, 21, 14], fill=BACK)


def g_summon(d, fg):
    for x, y in ((16, 8), (8, 22), (24, 22)):
        d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=fg)


def g_vine(d, fg):
    pts = [(16, 28), (11, 21), (21, 15), (11, 9), (16, 4)]
    d.line(pts, fill=fg, width=3)
    d.ellipse([19, 19, 25, 23], fill=fg)
    d.ellipse([7, 12, 13, 16], fill=fg)


def g_transmute(d, fg):
    arrow(d, (6, 11), (26, 11), fg, 3, 5)
    arrow(d, (26, 21), (6, 21), fg, 3, 5)


def g_copy(d, fg):
    d.rectangle([6, 6, 20, 20], outline=fg, width=2)
    d.rectangle([12, 12, 26, 26], fill=fg[:3] + (140,), outline=fg, width=2)


def g_reveal(d, fg):
    d.ellipse([4, 9, 28, 23], outline=fg, width=2)
    d.ellipse([12, 12, 20, 20], fill=fg)
    d.ellipse([15, 15, 17, 17], fill=BACK)


def g_bridge(d, fg):
    d.rectangle([3, 16, 29, 19], fill=fg)
    for x in (5, 12, 19, 26):
        d.line([(x, 19), (x, 25)], fill=fg, width=2)
    d.line([(3, 12), (29, 12)], fill=fg, width=1)


def g_trap(d, fg):
    d.line([(4, 22), (28, 22)], fill=fg, width=2)
    for x in (6, 12, 18, 24):
        d.polygon([(x, 22), (x + 3, 11), (x + 6, 22)], fill=fg)


def g_forge(d, fg):
    d.rectangle([6, 12, 26, 17], fill=fg)
    d.polygon([(10, 17), (22, 17), (20, 24), (12, 24)], fill=fg)
    d.rectangle([8, 24, 24, 27], fill=fg)
    d.line([(3, 14), (6, 14)], fill=fg, width=2)


def g_veil(d, fg):
    d.polygon([(16, 5), (26, 27), (6, 27)], outline=fg, width=3)
    d.line([(10, 20), (22, 20)], fill=fg, width=2)


def g_stalk(d, fg):
    d.ellipse([5, 11, 15, 21], outline=fg, width=2)
    arrow(d, (11, 16), (27, 16), fg, 3, 6)


def g_swap(d, fg):
    arrow(d, (6, 11), (26, 11), fg, 2, 5)
    arrow(d, (26, 21), (6, 21), fg, 2, 5)


def g_blink(d, fg):
    d.ellipse([4, 12, 10, 18], outline=fg, width=2)
    d.ellipse([22, 12, 28, 18], fill=fg)
    for x in (13, 17, 21):
        d.line([(x, 15), (x + 1, 17)], fill=fg, width=2)


def g_light(d, fg):
    d.ellipse([12, 12, 20, 20], fill=fg)
    for x, y in ring_points(16, 16, 11, 8):
        d.line([(16 + (x - 16) * 0.7, 16 + (y - 16) * 0.7), (x, y)], fill=fg, width=1)


def g_omen(d, fg):
    d.ellipse([7, 6, 25, 24], outline=fg, width=3)
    d.line([(10, 10), (22, 22)], fill=fg, width=3)
    d.line([(22, 10), (10, 22)], fill=fg, width=3)


def g_fate(d, fg):
    d.line([(5, 8), (12, 24), (20, 8), (27, 24)], fill=fg, width=2)
    d.ellipse([3, 6, 8, 11], fill=fg)
    d.ellipse([24, 21, 29, 26], fill=fg)


def g_sabotage(d, fg):
    d.polygon([(16, 4), (21, 12), (30, 13), (23, 19), (25, 28), (16, 23), (7, 28), (9, 19), (2, 13), (11, 12)], outline=fg, width=2)


def g_chase(d, fg):
    arrow(d, (4, 10), (20, 10), fg, 2, 5)
    arrow(d, (4, 22), (20, 22), fg, 2, 5)
    d.ellipse([22, 13, 30, 19], fill=fg)


def g_disperse(d, fg):
    for x, y in ((8, 9), (20, 7), (14, 15), (25, 17), (7, 22), (18, 25), (27, 26)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=fg)


GLYPHS = {"bolt": g_bolt, "burst": g_burst, "ring": g_ring, "dash": g_dash, "zone": g_zone, "mark": g_mark, "heal": g_heal,
          "ward": g_ward, "buff": g_buff, "pull": g_pull, "aura": g_aura, "chain": g_chain, "engulf": g_engulf,
          "dissolve": g_dissolve, "glide": g_glide, "anchor": g_anchor, "decoy": g_decoy, "summon": g_summon, "vine": g_vine,
          "transmute": g_transmute, "copy": g_copy, "reveal": g_reveal, "bridge": g_bridge, "trap": g_trap, "forge": g_forge,
          "veil": g_veil, "stalk": g_stalk, "swap": g_swap, "blink": g_blink, "light": g_light, "omen": g_omen, "fate": g_fate,
          "sabotage": g_sabotage, "chase": g_chase, "disperse": g_disperse}


BASE_TINTS = {"goblin": (112, 158, 74), "undead": (205, 196, 170)}   # a species' own verb has no form file: the colour of its body


def form_tint(form):
    """The (r, g, b) bytes of a form's tint, read from its data file (a species' own verb: its body's colour)."""
    if form in BASE_TINTS:
        return BASE_TINTS[form]
    with open("data/forms/%s.tres" % form, encoding="utf-8") as fh:
        m = re.search(r"^tint = Color\(([^)]*)\)", fh.read(), re.M)
    return tuple(int(round(float(c) * 255)) for c in m.group(1).split(",")[:3])


def icon(kind, tint):
    """A 32x32 icon: a dark rounded plate with a border in the tint and the kind's glyph, brightened."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=5, fill=BACK, outline=tuple(int(c * 0.6) for c in tint) + (255,))
    fg = tuple(min(255, int(c * 0.35 + 190)) for c in tint) + (255,)
    GLYPHS[kind](d, fg)
    return img


def build(rows=None, out_dir=OUT):
    rows = bfv.all_rows() if rows is None else rows
    os.makedirs(out_dir, exist_ok=True)
    names = []
    for r in rows:
        name = "icon_%s" % bfv.skill_id(r["form"])
        icon(r["spec"]["kind"], form_tint(r["form"])).save(os.path.join(out_dir, name + ".png"))
        names.append(name)
    return names


if __name__ == "__main__":
    print("drew %d verb icons into %s" % (len(build()), OUT))
