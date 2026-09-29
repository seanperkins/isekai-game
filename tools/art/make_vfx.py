"""Turn the generated effect frames (art_source/frames/vfx/*.png, magenta key) into the game's effect sprites in
assets/sprites/: the Water Blade slash and the two web covers (a few strands, a cocoon). Keys, crops where asked, scales
with a box filter and crisps the alpha, like make_icons.py. Run from the project root (the whole command):
  uv run --python 3.12 --with Pillow python tools/art/make_vfx.py
"""
import os

from PIL import Image

SRC = "art_source/frames/vfx"
OUT = "assets/sprites"

# name: (output name, crop to the drawn pixels, (width, height) with None = keep the aspect)
SPECS = {
    "water_slash": ("vfx_water_slash", True, (56, None)),
    "web_strands": ("vfx_web_strands", False, (64, 64)),
    "web_cocoon": ("vfx_web_cocoon", True, (None, 64)),
}


def key(im):
    """Magenta and its blend with the art: red and blue both well above green (silk and water never are)."""
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _ = px[x, y]
            if min(r, b) - g > 45:
                px[x, y] = (0, 0, 0, 0)
    return im


def crisp(im):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im


def fit(im, size):
    w, h = size
    if w is None:
        w = max(1, round(im.width * h / im.height))
    if h is None:
        h = max(1, round(im.height * w / im.width))
    return im.resize((w, h), Image.Resampling.BOX)


def main():
    for name, (out, crop, size) in SPECS.items():
        im = key(Image.open(os.path.join(SRC, name + ".png")))
        if crop:
            box = im.getbbox()
            if box is None:
                raise SystemExit(name + " is entirely key")
            im = im.crop(box)
        made = crisp(fit(im, size))
        made.save(os.path.join(OUT, out + ".png"))
        print("wrote", out, made.size)


if __name__ == "__main__":
    main()
