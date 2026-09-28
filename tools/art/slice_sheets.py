"""Cut sprites out of the magenta-keyed Style D sheets into res://assets/sprites/<name>.png.

Keying: magenta and magenta-tinted edge pixels become transparent. Downscale uses a box
filter, then alpha is thresholded so edges stay crisp (pixel-art look, no halos).
Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/slice_sheets.py
"""
import json
import os
from PIL import Image

OUT = "assets/sprites"


def keyed(im):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # Magenta and anti-aliased magenta fringe: red and blue both well above green.
            if r > 150 and b > 150 and g < 120 and min(r, b) - g > 60:
                px[x, y] = (0, 0, 0, 0)
    return im


def crisp_alpha(im):
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im


def main():
    manifest = json.load(open("tools/art/manifest.json"))
    os.makedirs(OUT, exist_ok=True)
    for sheet, sprites in manifest["sheets"].items():
        src = Image.open(sheet)
        for name, spec in sprites.items():
            x0, y0, x1, y1 = spec["box"]
            crop = keyed(src.crop((x0, y0, x1 + 1, y1 + 1)))
            if "size" in spec:
                size = tuple(spec["size"])
            else:
                size = (max(1, round(crop.width * spec["scale"])), max(1, round(crop.height * spec["scale"])))
            out = crisp_alpha(crop.resize(size, Image.Resampling.BOX))
            path = os.path.join(OUT, name + ".png")
            out.save(path)
            print("wrote", path, out.size)


if __name__ == "__main__":
    main()
