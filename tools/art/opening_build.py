"""Turn the opening's raw backdrop into the 640x360 game image: assets/opening/backdrop.png.

Box-filter resize, like tools/art/terrain_build.py. Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/opening_build.py
"""
import os

from PIL import Image

RAW = "art_source/opening/backdrop_raw.png"
OUT = "assets/opening/backdrop.png"
SIZE = (640, 360)


def build(raw=RAW, out=OUT, size=SIZE):
    im = Image.open(raw).convert("RGB").resize(size, Image.Resampling.BOX)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)
    return out


if __name__ == "__main__":
    print("wrote", build())
