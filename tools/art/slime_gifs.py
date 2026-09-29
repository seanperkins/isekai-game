"""GIFs of the slime's clips from data/slime_clips.json (run, idle, spread with its exit, cover,
wall), on a floor line at 4x. Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/slime_gifs.py
"""
import json
import os

from PIL import Image, ImageDraw

SCALE = 4
W, H = 76 * SCALE, 64 * SCALE
sheet = Image.open("assets/sheets/slime.png").convert("RGBA")
frames = json.load(open("assets/sheets/slime.json"))["frames"]
clips = json.load(open("data/slime_clips.json"))
os.makedirs(".tmp/slime-frames", exist_ok=True)


def draw_frame(name):
    x, y, w, h = frames[name]["rect"]
    bg = Image.new("RGBA", (W, H), (18, 18, 32, 255))
    floor = H - 16
    ImageDraw.Draw(bg).line([(0, floor), (W, floor)], fill=(70, 70, 110, 255))
    frame = sheet.crop((x, y, x + w, y + h)).resize((w * SCALE, h * SCALE), Image.NEAREST)
    bg.alpha_composite(frame, ((W - w * SCALE) // 2, floor - h * SCALE))
    return bg.convert("P", palette=Image.ADAPTIVE)


def make(name, sequence, fps):
    imgs = [draw_frame(n) for n in sequence]
    imgs[0].save(".tmp/slime-frames/%s.gif" % name, save_all=True, append_images=imgs[1:],
                 duration=int(1000 / fps), loop=0)
    print("wrote", name + ".gif", len(imgs), "frames")


def cycle(clip, repeats):
    return clips[clip]["frames"] * repeats


make("run", cycle("run", 3), clips["run"]["fps"])
make("idle", cycle("idle", 4), clips["idle"]["fps"])
make("wall", cycle("wall", 4), clips["wall"]["fps"])
make("cover", ["cover_1"] * 3 + ["cover_2"] * 3 + ["cover_3", "cover_3", "cover_4", "cover_4"] * 3 + ["cover_5"] * 4, 8)
make("spread", ["idle_1"] * 4 + clips["spread"]["frames"] + ["spread_2"] * 8 + clips["spread"]["exit"] + ["idle_1"] * 4, 10)
