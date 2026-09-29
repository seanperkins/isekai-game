"""A contact sheet of the slime's frames at 4x, each with its traced hurt shape (red) and attack
shape (yellow), the floor line, and the frame name. Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/slime_contact_sheet.py
"""
import json
import os

from PIL import Image, ImageDraw

SCALE = 4
CELL_W, CELL_H = 68 * SCALE + 24, 60 * SCALE + 36
COLS = 5

sheet = Image.open("assets/sheets/slime.png").convert("RGBA")
data = json.load(open("assets/sheets/slime.json"))["frames"]
names = list(data)
rows = (len(names) + COLS - 1) // COLS
out = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H), (18, 18, 32, 255))
draw = ImageDraw.Draw(out)
for i, name in enumerate(names):
    f = data[name]
    x, y, w, h = f["rect"]
    ox = (i % COLS) * CELL_W + CELL_W // 2
    oy = (i // COLS) * CELL_H + CELL_H - 20  # the floor line
    frame = sheet.crop((x, y, x + w, y + h)).resize((w * SCALE, h * SCALE), Image.NEAREST)
    out.alpha_composite(frame, (ox - w * SCALE // 2, oy - h * SCALE))
    draw.line([(ox - CELL_W // 2 + 6, oy), (ox + CELL_W // 2 - 6, oy)], fill=(70, 70, 110, 255))
    for key, color in (("hurt", (255, 80, 80, 255)), ("attack", (255, 220, 60, 255))):
        pts = [(ox + px * SCALE, oy + py * SCALE) for px, py in f[key]]
        if len(pts) >= 3:
            draw.line(pts + [pts[0]], fill=color, width=1)
    draw.text((ox - CELL_W // 2 + 6, oy + 4), "%s  %dx%d" % (name, w, h), fill=(200, 210, 230, 255))
os.makedirs(".tmp/slime-frames", exist_ok=True)
out.convert("RGB").save(".tmp/slime-frames/contact_sheet.png")
print("wrote .tmp/slime-frames/contact_sheet.png", out.size)
