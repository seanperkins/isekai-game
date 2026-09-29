"""Assemble individually generated set-dressing pieces into single images plus a manifest.

Each piece is a Codex image on a magenta key (art_source/frames/<set>/<name>.png, from
generate_frames.py). This keys the magenta out, crops to the drawn pixels, scales to the piece's
width in tools/art/<set>_frames.json (keeping the aspect), crisps the alpha and writes
assets/dressing/<biome>/<name>.png, plus pieces.json recording each piece's final size and anchor
("top": it hangs from its position, "bottom": it stands on it, "center": centred on it).
The set name is dressing_<biome>. Run from the project root (the whole command, no cd or pipes):
  uv run --python 3.12 --with Pillow python tools/art/assemble_pieces.py dressing_cave
"""
import json
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from assemble_frames import fit_frame  # noqa: E402

NAME = re.compile(r"^[a-z0-9_]+$")
ANCHORS = ("top", "bottom", "center")
SRC = "art_source/frames"
OUT = "assets/dressing"


def build_piece(im, width):
    """Key, crop and scale one piece to `width` px wide (aspect kept, alpha crisp)."""
    return fit_frame(im, width)


def assemble(frames, src_dir, out_dir):
    """Write every piece and pieces.json; returns the manifest."""
    for f in frames:
        if not NAME.match(f["name"]):
            raise ValueError("bad piece name %r" % f["name"])
        if f.get("anchor") not in ANCHORS:
            raise ValueError("%s: anchor must be one of %s" % (f["name"], ANCHORS))
    os.makedirs(out_dir, exist_ok=True)
    manifest = {"pieces": {}}
    for f in frames:
        path = os.path.join(src_dir, f["name"] + ".png")
        if not os.path.exists(path):
            raise SystemExit("missing %s (generate it first)" % path)
        im = build_piece(Image.open(path), f["width"])
        im.save(os.path.join(out_dir, f["name"] + ".png"))
        manifest["pieces"][f["name"]] = {"size": [im.width, im.height], "anchor": f["anchor"]}
    with open(os.path.join(out_dir, "pieces.json"), "w") as out:
        json.dump(manifest, out, indent=1)
    return manifest


def main():
    if len(sys.argv) != 2 or not re.match(r"^dressing_[a-z0-9]+$", sys.argv[1]):
        raise SystemExit("usage: assemble_pieces.py dressing_<biome>")
    name = sys.argv[1]
    biome = name[len("dressing_"):]
    data = json.load(open("tools/art/%s_frames.json" % name))
    manifest = assemble(data["frames"], os.path.join(SRC, name), os.path.join(OUT, biome))
    for n, p in manifest["pieces"].items():
        print("piece", n, p["size"], p["anchor"])


if __name__ == "__main__":
    main()
