"""Render every held piece as a sprite of its own, lit like a creature, with a normal map and a grip, for the held-item layer to draw on a hand.

    python3 tools/art/blender/held_items.py [--out DIR] [--install] [item ...]

Each item (held.all_items(): what the forms hold, and every held piece at its default options) is rendered alone on the standard goblin's item bone at
held.ITEM_PPU, cut to the pixels it draws, and written as an ordinary sprite set: held_<id>.png, held_<id>_n.png and held_<id>.json (the frame `item`, with
no hit shapes). The grip, the item bone's head in the picture's bottom-centre pixels, goes into data/held_items.json["items"]. Without --install the files go
under --out; with it, into assets/sheets and data/held_items.json.
"""
import argparse
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import held  # noqa: E402
import spike  # noqa: E402


def write_item(item, folder, dest):
    """Cut an item's lit frame and its normal map to the drawn pixels, write its sheet set into `dest`, and return its entry for the items table."""
    with open(os.path.join(folder, "raw", "meta.json")) as fh:
        meta = json.load(fh)
    with Image.open(os.path.join(folder, "frames", "item_0.png")) as im:
        lit = im.convert("RGBA")
    box = lit.split()[3].getbbox()
    if box is None:
        raise RuntimeError("held item %s drew nothing" % item)
    with Image.open(os.path.join(folder, "frames", "item_0_n.png")) as im:
        normal = im.convert("RGBA").crop(box)
    lit = lit.crop(box)
    normal.putalpha(lit.split()[3])
    os.makedirs(dest, exist_ok=True)
    name = "held_" + item
    lit.save(os.path.join(dest, name + ".png"))
    normal.save(os.path.join(dest, name + "_n.png"))
    with open(os.path.join(dest, name + ".json"), "w") as fh:
        json.dump({"set": name, "image": name + ".png", "normal": name + "_n.png", "frames": {"item": {"rect": [0, 0, lit.width, lit.height], "hurt": [], "attack": []}}}, fh)
    gx, gy = held.local_of(meta["grip"][0], meta["grip"][1], box)
    return {"set": name, "frame": "item", "grip": [round(gx, 2), round(gy, 2)], "ppu": held.ITEM_PPU}


def build_items(ids, out, dest):
    """Render and write the items `ids` (renders under out/<id>/); returns {id: entry}."""
    entries = {}
    for item in ids:
        raw = os.path.join(out, item, "raw")
        os.makedirs(raw, exist_ok=True)
        spike.render("held_item", raw, variant=item, ss=4)
        spike.process(raw, os.path.join(out, item), outline=True)
        entries[item] = write_item(item, os.path.join(out, item), dest)
        print("rendered", item, flush=True)
    return entries


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("items", nargs="*", help="item ids (default: all)")
    ap.add_argument("--out", default=os.path.join(ROOT, ".tmp", "held-items"))
    ap.add_argument("--install", action="store_true", help="write into assets/sheets and data/held_items.json")
    a = ap.parse_args(argv)
    ids = a.items or sorted(held.all_items())
    unknown = [i for i in ids if i not in held.all_items()]
    if unknown:
        raise SystemExit("not held items: %s" % ", ".join(unknown))
    dest = os.path.join(ROOT, "assets", "sheets") if a.install else os.path.join(a.out, "sheets")
    table = os.path.join(ROOT, "data", "held_items.json") if a.install else os.path.join(a.out, "held_items.json")
    held.update_table(table, items=build_items(ids, a.out, dest))
    print("wrote", table)
    return 0


if __name__ == "__main__":
    sys.exit(main())
