"""Turn the generated skill icons (art_source/frames/skill_icons_grotto/*.png and skill_icons_flooded/*.png, magenta key) into the
32x32 game icons in assets/sprites/. Keys, crops to the drawn pixels, scales with a box filter and crisps the alpha.
Run from the project root (the whole command):
  uv run --python 3.12 --with Pillow python tools/art/make_icons.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_sheets import crisp_alpha, keyed  # noqa: E402

SRC_DIRS = ["art_source/frames/skill_icons_grotto", "art_source/frames/skill_icons_flooded"]
OUT = "assets/sprites"


def make_icon(im):
    im = keyed(im)
    box = im.getbbox()
    if box is None:
        raise SystemExit("icon is entirely key")
    im = im.crop(box)
    side = max(im.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return crisp_alpha(square.resize((32, 32), Image.Resampling.BOX))


def main():
    for src in SRC_DIRS:
        if not os.path.isdir(src):
            continue
        for name in sorted(f[:-4] for f in os.listdir(src) if f.endswith(".png")):
            icon = make_icon(Image.open(os.path.join(src, name + ".png")))
            icon.save(os.path.join(OUT, name + ".png"))
            print("wrote", name)


if __name__ == "__main__":
    main()
