"""Render the goblin tree and look at it.

    python3 tools/art/blender/goblin_tree.py [form ...] [--out DIR]

For each form (all 29 by default) this runs Blender (render_set.py) and lights the frames (spike.process), then writes into DIR
(default .tmp/goblin-tree):
  <form>/frames/      every frame of idle, walk and attack, and its normal map
  stills/<form>.png   the form's still, trimmed, named as its frame in the game's sheet (for tools/art/handdraw.py import --native)
  tree.png            the whole tree, the forms in tree order, one row per line
  compare.png         the same, each form beside the still the game has today
  walk.gif            the tree walking
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import goblin_forms as forms  # noqa: E402
import spike  # noqa: E402

LINES = ["beast", "tinker", "skulker", "hob"]
BACKDROP, INK, FAINT = (36, 36, 46, 255), (226, 226, 236, 255), (110, 110, 130, 255)


def tree_order():
    """[[goblin], line by line: root, stage-3 a, its two children, stage-3 b, its two children] by the forms' parents."""
    rows = [["goblin"]]
    for line in LINES:
        members = [n for n, f in forms.FORMS.items() if f["line"] == line]
        root = [n for n in members if forms.FORMS[n]["stage"] == 2][0]
        row = [root]
        for mid in [n for n in members if forms.FORMS[n]["parent"] == root]:
            row.append(mid)
            row += [n for n in members if forms.FORMS[n]["parent"] == mid]
        rows.append(row)
    return rows


def render_form(name, out):
    raw = os.path.join(out, name, "raw")
    os.makedirs(raw, exist_ok=True)
    spike.render("goblin", raw, None if name == "goblin" else name, None, 4)
    return spike.process(raw, os.path.join(out, name), colours=24, outline=True)


def frame(out, name, key):
    with Image.open(os.path.join(out, name, "frames", key + ".png")) as im:
        return im.convert("RGBA")


def still(out, name):
    meta = json.load(open(os.path.join(out, name, "raw", "meta.json")))
    return frame(out, name, meta["still"]).crop(frame(out, name, meta["still"]).getbbox())


def union_box(images):
    boxes = [im.getbbox() for im in images if im.getbbox()]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def current_still(name):
    """The still the game had for this form before the 3D pass (tools/art/blender/before/)."""
    sheet = json.load(open(os.path.join(HERE, "before", "forms_goblin.json")))["frames"]
    if name not in sheet:
        return None
    x, y, w, h = sheet[name]["rect"]
    with Image.open(os.path.join(HERE, "before", "forms_goblin.png")) as im:
        return im.convert("RGBA").crop((x, y, x + w, y + h))


def board(rows, picture, cell_w, zoom, title=None, label=True):
    """A grid of cells; `picture(name)` is a list of images drawn side by side, bottom aligned, with the form's name under them.
    Each row is as tall as its tallest sprite."""
    pad, foot = 6, 16
    magnified = {n: [None if p is None else p.resize((p.width * zoom, p.height * zoom), Image.NEAREST) for p in picture(n)] for r in rows for n in r}
    heights = [max([p.height for n in r for p in magnified[n] if p is not None] or [8]) for r in rows]
    width = max(len(r) for r in rows) * cell_w + pad
    height = sum(h + foot + pad for h in heights) + pad + (18 if title else 0)
    im = Image.new("RGBA", (width, height), BACKDROP)
    d = ImageDraw.Draw(im)
    if title:
        d.text((pad, 3), title, fill=INK)
    y = pad + (18 if title else 0)
    for row, h in zip(rows, heights):
        for c, name in enumerate(row):
            x = pad + c * cell_w
            for pic in magnified[name]:
                if pic is None:
                    continue
                im.alpha_composite(pic, (x, y + h - pic.height))
                x += pic.width + 6
            if label:
                d.text((pad + c * cell_w, y + h + 2), name.replace("_", " ") + " (%d)" % forms.FORMS[name]["stage"], fill=FAINT)
        y += h + foot + pad
    return im


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("forms", nargs="*")
    ap.add_argument("--out", default=os.path.join(ROOT, ".tmp", "goblin-tree"))
    ap.add_argument("--skip-render", action="store_true", help="reuse the frames already in --out")
    args = ap.parse_args(argv)
    names = args.forms or list(forms.FORMS)
    os.makedirs(os.path.join(args.out, "stills"), exist_ok=True)
    for n in names:
        if not args.skip_render:
            render_form(n, args.out)
            print("rendered", n, flush=True)
        still(args.out, n).save(os.path.join(args.out, "stills", n + ".png"))
    rows = [[n for n in row if n in names] for row in tree_order()]
    rows = [r for r in rows if r]
    zoom = 3
    stills = {n: still(args.out, n) for n in names}
    cell_w = max(im.width for im in stills.values()) * zoom + 10
    board(rows, lambda n: [stills[n]], cell_w, zoom, "the goblin tree, rendered").save(os.path.join(args.out, "tree.png"))
    both = {n: [current_still(n), stills[n]] for n in names}
    cw = max(sum((p.width if p else 0) for p in v) for v in both.values()) * 2 + 24
    board(rows, lambda n: both[n], cw, 2, "today (left) and rendered (right)").save(os.path.join(args.out, "compare.png"))
    # the tree walking: each form cropped once to the union of its walk so it does not jump, at the speed its own walk cycle was built for
    metas = {n: json.load(open(os.path.join(args.out, n, "raw", "meta.json"))) for n in names}
    walks = {n: [frame(args.out, n, "walk_%d" % i) for i in range(metas[n]["anims"]["walk"])] for n in names if "walk" in metas[n]["anims"]}
    crops = {n: union_box(v) for n, v in walks.items()}
    cell_w = max((c[2] - c[0]) for c in crops.values()) * zoom + 10
    count = max(len(v) for v in walks.values())
    fps = sum(metas[n]["fps"].get("walk", 12.0) for n in walks) / len(walks)
    frames = []
    for i in range(count):
        pic = board(rows, lambda n, i=i: [walks[n][i % len(walks[n])].crop(crops[n])] if n in walks else [], cell_w, zoom, "the goblin tree, walking")
        frames.append(pic.convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(args.out, "walk.gif"), save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, disposal=2)
    print("wrote", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
