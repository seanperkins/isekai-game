"""Review images for one creature set: a contact sheet of its frames at 4x with the traced hurt
shape (red) and attack shape (yellow) over the floor line, and one GIF per clip from
data/enemy_clips.json. Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/enemy_review.py bat
Writes .tmp/enemy-frames/<set>_contact.png and .tmp/enemy-frames/<set>_<clip>.gif.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

SCALE = 4
COLS = 4
OUT = ".tmp/enemy-frames"

name = sys.argv[1]
sheet = Image.open("assets/sheets/%s.png" % name).convert("RGBA")
frames = json.load(open("assets/sheets/%s.json" % name))["frames"]
clips = json.load(open("data/enemy_clips.json"))[name]
os.makedirs(OUT, exist_ok=True)
max_w = max(f["rect"][2] for f in frames.values())
max_h = max(f["rect"][3] for f in frames.values())
CELL_W, CELL_H = max_w * SCALE + 24, max_h * SCALE + 36


def crop(n):
    x, y, w, h = frames[n]["rect"]
    return sheet.crop((x, y, x + w, y + h)).resize((w * SCALE, h * SCALE), Image.NEAREST), w, h


names = list(frames)
rows = (len(names) + COLS - 1) // COLS
out = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H), (18, 18, 32, 255))
d = ImageDraw.Draw(out)
for i, n in enumerate(names):
    im, w, h = crop(n)
    ox = (i % COLS) * CELL_W + CELL_W // 2
    oy = (i // COLS) * CELL_H + CELL_H - 20
    out.alpha_composite(im, (ox - w * SCALE // 2, oy - h * SCALE))
    d.line([(ox - CELL_W // 2 + 6, oy), (ox + CELL_W // 2 - 6, oy)], fill=(70, 70, 110, 255))
    for key, color in (("hurt", (255, 80, 80, 255)), ("attack", (255, 220, 60, 255))):
        pts = [(ox + px * SCALE, oy + py * SCALE) for px, py in frames[n][key]]
        if len(pts) >= 3:
            d.line(pts + [pts[0]], fill=color, width=1)
    d.text((ox - CELL_W // 2 + 6, oy + 4), "%s  %dx%d" % (n, w, h), fill=(200, 210, 230, 255))
out.convert("RGB").save("%s/%s_contact.png" % (OUT, name))
print("wrote", "%s/%s_contact.png" % (OUT, name), out.size)

W, H = max_w * SCALE + 40, max_h * SCALE + 40
for clip, c in clips.items():
    seq = c["frames"] * (3 if c["loop"] else 1) if len(c["frames"]) > 1 else c["frames"] * 3
    imgs = []
    for n in seq:
        im, w, h = crop(n)
        bg = Image.new("RGBA", (W, H), (18, 18, 32, 255))
        floor = H - 16
        ImageDraw.Draw(bg).line([(0, floor), (W, floor)], fill=(70, 70, 110, 255))
        bg.alpha_composite(im, ((W - w * SCALE) // 2, floor - h * SCALE))
        imgs.append(bg.convert("P", palette=Image.ADAPTIVE))
    imgs[0].save("%s/%s_%s.gif" % (OUT, name, clip), save_all=True, append_images=imgs[1:],
                 duration=int(1000 / max(c["fps"], 2.0)), loop=0)
print("wrote", len(clips), "gifs")
