"""Render a species' whole tree of forms and look at it.

    python3 tools/art/blender/species_tree.py wolf [form ...] [--out DIR] [--skip-render]

For each form (all of them by default) this runs Blender (render_set.py) and lights the frames (spike.process), then writes into DIR
(default .tmp/<species>-tree):
  <form>/frames/      every frame of every clip, and its normal map
  stills/<form>.png   the form's still, trimmed, named as its frame in the game's sheet
  tree.png            the whole tree, the forms in tree order
  compare.png         the same, each form beside the still the game has today (tools/art/blender/before/)
  walk.gif            the tree walking
tools/art/blender/export_forms.py then installs a tree in the game. The goblin tree has its own layout (goblin_tree.py).
"""
import argparse
import importlib
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import spike  # noqa: E402

# species -> (creature module in creatures/, forms module, the base creature's name in the forms table, the name of the kit's base form)
SPECIES = {
    "goblin": ("goblin", "goblin_forms", "goblin"),
    "wolf": ("wolf", "wolf_forms", "gloom_wolf"),
    "spider": ("spider", "spider_forms", "weavermaid_base"),
    "undead": ("undead", "undead_forms", "skeleton"),
    "slime": ("slime", "slime_forms", "slime"),
}
BACKDROP, INK, FAINT = (36, 36, 46, 255), (226, 226, 236, 255), (110, 110, 130, 255)


def forms_of(species):
    return importlib.import_module(SPECIES[species][1]).FORMS


def rows_of(forms, base):
    """The forms in tree order, a row per branch of the base: the branch's own form first, then everything that grows from it, depth first."""
    def descendants(name):
        out = []
        for child in [n for n, f in forms.items() if f.get("parent") == name]:
            out += [child] + descendants(child)
        return out
    return [[base]] + [[c] + descendants(c) for c in [n for n, f in forms.items() if f.get("parent") == base]]


def render_form(species, name, out, ss=4):
    creature, _, base = SPECIES[species]
    raw = os.path.join(out, name, "raw")
    os.makedirs(raw, exist_ok=True)
    spike.render(creature, raw, None if name == base else name, None, ss)
    return spike.process(raw, os.path.join(out, name), outline=True)


def frame(out, name, key):
    with Image.open(os.path.join(out, name, "frames", key + ".png")) as im:
        return im.convert("RGBA")


def still(out, name):
    meta = json.load(open(os.path.join(out, name, "raw", "meta.json")))
    im = frame(out, name, meta["still"])
    return im.crop(im.getbbox())


def union_box(images):
    boxes = [im.getbbox() for im in images if im.getbbox()]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def current_still(species, name):
    """The still the game had for this form before the 3D pass (tools/art/blender/before/), or None."""
    path = os.path.join(HERE, "before", "forms_%s.json" % species)
    if not os.path.exists(path):
        return None
    sheet = json.load(open(path))["frames"]
    if name not in sheet:
        return None
    x, y, w, h = sheet[name]["rect"]
    with Image.open(os.path.join(HERE, "before", "forms_%s.png" % species)) as im:
        return im.convert("RGBA").crop((x, y, x + w, y + h))


def board(rows, picture, cell_w, zoom, label_of, title=None):
    """A grid of cells; `picture(name)` is a list of images drawn side by side, bottom aligned, with the form's label under them. Each row is as
    tall as its tallest sprite."""
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
            d.text((pad + c * cell_w, y + h + 2), label_of(name), fill=FAINT)
        y += h + foot + pad
    return im


def make_boards(species, rows, names, out, zoom=3):
    forms = forms_of(species)
    label = lambda n: "%s (%s)" % (n.replace("_", " "), forms[n].get("stage", 1))
    stills = {n: still(out, n) for n in names}
    cell_w = max(im.width for im in stills.values()) * zoom + 10
    board(rows, lambda n: [stills[n]], cell_w, zoom, label, "the %s tree, rendered" % species).save(os.path.join(out, "tree.png"))
    both = {n: [current_still(species, n), stills[n]] for n in names}
    cw = max(sum((p.width if p else 0) for p in v) for v in both.values()) * 2 + 24
    board(rows, lambda n: both[n], cw, 2, label, "today (left) and rendered (right)").save(os.path.join(out, "compare.png"))
    metas = {n: json.load(open(os.path.join(out, n, "raw", "meta.json"))) for n in names}
    walks = {n: [frame(out, n, "walk_%d" % i) for i in range(metas[n]["anims"]["walk"])] for n in names if "walk" in metas[n]["anims"]}
    crops = {n: union_box(v) for n, v in walks.items()}
    cell_w = max((c[2] - c[0]) for c in crops.values()) * zoom + 10
    count = max(len(v) for v in walks.values())
    fps = sum(metas[n]["fps"].get("walk", 12.0) for n in walks) / len(walks)
    frames = []
    for i in range(count):
        pic = board(rows, lambda n, i=i: [walks[n][i % len(walks[n])].crop(crops[n])] if n in walks else [], cell_w, zoom, label, "the %s tree, walking" % species)
        frames.append(pic.convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(out, "walk.gif"), save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, disposal=2)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("species", choices=sorted(SPECIES))
    ap.add_argument("forms", nargs="*")
    ap.add_argument("--out")
    ap.add_argument("--skip-render", action="store_true", help="reuse the frames already in --out")
    ap.add_argument("--only-quads", action="store_true", help="skip the forms a species builds with a different kit (wolf: the werewolves)")
    args = ap.parse_args(argv)
    forms = forms_of(args.species)
    base = SPECIES[args.species][2]
    out = args.out or os.path.join(ROOT, ".tmp", "%s-tree" % args.species)
    names = args.forms or [n for n in forms if not (args.only_quads and forms[n].get("body", "quad") != "quad")]
    os.makedirs(os.path.join(out, "stills"), exist_ok=True)
    for n in names:
        if not args.skip_render:
            render_form(args.species, n, out)
            print("rendered", n, flush=True)
        still(out, n).save(os.path.join(out, "stills", n + ".png"))
    rows = [[n for n in row if n in names] for row in rows_of(forms, base)]
    make_boards(args.species, [r for r in rows if r], names, out)
    print("wrote", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
