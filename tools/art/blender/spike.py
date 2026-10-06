"""Run the Dead Cells style pipeline for one creature and see the result.

    python3 tools/art/blender/spike.py goblin [--variant redcap] [--out DIR] [--colours 24] [--anims idle,walk,attack]

1. Blender renders each frame as a colour pass and a normal pass (render_set.py, headless, no window).
2. toon.py lights them with a cel shade, shrinks to game size with crisp alpha, outlines, and snaps every frame to one shared palette.
3. Writes DIR/<creature>[_<variant>]/: frames/<anim>_<n>.png (the sprite), frames/<anim>_<n>_n.png (its normal map, for 2D lighting),
   <anim>.gif (a 4x loop) and board.png (the frames beside the game's current sprites for the same creature).

Needs Blender (BLENDER=/path overrides /Applications/Blender.app) and Pillow.
"""
import argparse
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import toon  # noqa: E402

BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
BACKDROP = (36, 36, 46, 255)
GROUND = (70, 70, 90, 255)
SHADOW = ((60, 50, 130), 0.55)  # the cool tint of the dark band
GLOW = ((255, 236, 190), 0.5)    # the warm tint of the lit band
ZOOM = 4
# what the game draws today for each creature, to put beside the render: (sheet, frames)
CURRENT = {
    "goblin": ("goblin", ["idle_1", "run_1", "run_2", "run_3", "run_4"]),
    "spider": ("spider", ["hang_1", "crawl_1", "crawl_2", "crawl_3", "crawl_4"]),
    "wolf": ("gloom_wolf", ["idle_1", "walk_1", "walk_2", "walk_3", "windup_1"]),
}


def render(creature, out, variant=None, anims=None, ss=4):
    cmd = [BLENDER, "-b", "-P", os.path.join(HERE, "render_set.py"), "--", "--creature", creature, "--out", out, "--ss", str(ss)]
    if variant:
        cmd += ["--variant", variant]
    if anims:
        cmd += ["--anims", anims]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0 or not os.path.exists(os.path.join(out, "meta.json")):
        raise RuntimeError("Blender failed:\n" + done.stdout[-2000:] + done.stderr[-2000:])


def _normal_small(normal, alpha_source, size):
    """The normal pass at game size: averaged, then masked by the sprite's own alpha so the two always agree."""
    rgb = normal.convert("RGB").resize(size, Image.BOX).convert("RGBA")
    mask = alpha_source.split()[3]
    rgb.putalpha(mask)
    return rgb


def process(raw, out, colours=24, outline=True):
    """Light, shrink, outline and palette-snap every frame in `raw` (what render() wrote); returns {anim: [frame names]}."""
    meta = json.load(open(os.path.join(raw, "meta.json")))
    canvas = meta["canvas"]
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    names, small, normals = [], {}, {}
    for anim, count in meta["anims"].items():
        for i in range(count):
            key = "%s_%d" % (anim, i)
            with Image.open(os.path.join(raw, key + "_albedo.png")) as a, Image.open(os.path.join(raw, key + "_normal.png")) as n:
                albedo, normal = a.convert("RGBA"), n.convert("RGBA")
            lit = toon.downscale(toon.shade(albedo, normal, shadow=SHADOW, glow=GLOW), (canvas, canvas))
            if outline:
                lit = toon.outline(lit)
            small[key] = lit
            normals[key] = _normal_small(normal, lit, (canvas, canvas))
            names.append(key)
    if meta.get("materials"):  # a palette made of the creature's own materials, so a small bright part is never merged away
        pal = toon.palette_of(toon.palette_colours([tuple(m) for m in meta["materials"]], shadow=SHADOW, glow=GLOW))
    else:
        pal = toon.palette(list(small.values()), colours)
    result = {}
    for anim, count in meta["anims"].items():
        result[anim] = []
        for i in range(count):
            key = "%s_%d" % (anim, i)
            toon.apply_palette(small[key], pal).save(os.path.join(out, "frames", key + ".png"))
            normals[key].save(os.path.join(out, "frames", key + "_n.png"))
            result[anim].append(key)
    return result


def _stage(frame, zoom, margin):
    """A frame on the backdrop with its ground line, magnified."""
    im = Image.new("RGBA", frame.size, BACKDROP)
    im.alpha_composite(frame)
    big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
    ImageDraw.Draw(big).line([(0, (im.height - margin) * zoom), (big.width, (im.height - margin) * zoom)], fill=GROUND, width=1)
    return big


def gifs(out, frames, margin, ms=110):
    for anim, keys in frames.items():
        imgs = [_stage(Image.open(os.path.join(out, "frames", k + ".png")).convert("RGBA"), ZOOM, margin).convert("P", palette=Image.ADAPTIVE) for k in keys]
        imgs[0].save(os.path.join(out, anim + ".gif"), save_all=True, append_images=imgs[1:], duration=ms, loop=0, disposal=2)


def _crop_all(images):
    """Crop every image to the union of their drawn pixels, so a row is as tight as the drawing."""
    boxes = [im.getbbox() for im in images if im.getbbox()]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    return [im.crop(box) for im in images]


def board(out, creature, frames, zoom=3):
    """Rows: the game's current sprites, then each animation of the render, all at the same scale on the same backdrop."""
    rows = []
    sheet, wanted = CURRENT[creature]
    meta = json.load(open(os.path.join(ROOT, "assets", "sheets", sheet + ".json")))
    atlas = Image.open(os.path.join(ROOT, "assets", "sheets", sheet + ".png")).convert("RGBA")
    current = []
    for name in wanted:
        x, y, w, h = meta["frames"][name]["rect"]
        current.append(atlas.crop((x, y, x + w, y + h)))
    rows.append(("today: " + ", ".join(wanted), current, False))
    for anim, keys in frames.items():
        rows.append((anim, _crop_all([Image.open(os.path.join(out, "frames", k + ".png")).convert("RGBA") for k in keys]), True))
    pad, label = 8, 16
    width = max(sum(im.width * zoom + pad for im in ims) for _, ims, _ in rows) + pad
    height = sum(max(im.height for im in ims) * zoom + label + pad for _, ims, _ in rows) + pad
    sheet_im = Image.new("RGBA", (width, height), BACKDROP)
    d = ImageDraw.Draw(sheet_im)
    y = pad
    for title, ims, _ in rows:
        d.text((pad, y), title, fill=(220, 220, 230, 255))
        top = y + label
        h = max(im.height for im in ims) * zoom
        x = pad
        for im in ims:
            big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
            sheet_im.alpha_composite(big, (x, top + h - big.height))
            x += big.width + pad
        y = top + h + pad
    sheet_im.save(os.path.join(out, "board.png"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("creature", choices=sorted(CURRENT))
    ap.add_argument("--variant")
    ap.add_argument("--out", default=os.path.join(ROOT, ".tmp", "blender-spike"))
    ap.add_argument("--colours", type=int, default=24)
    ap.add_argument("--anims")
    ap.add_argument("--no-outline", action="store_true")
    args = ap.parse_args(argv)
    name = args.creature + ("_" + args.variant if args.variant else "")
    out = os.path.join(args.out, name)
    raw = os.path.join(out, "raw")
    os.makedirs(raw, exist_ok=True)
    render(args.creature, raw, args.variant, args.anims)
    frames = process(raw, out, args.colours, not args.no_outline)
    meta = json.load(open(os.path.join(raw, "meta.json")))
    gifs(out, frames, meta["margin"])
    board(out, args.creature, frames)
    print("%s: %d frames in %s" % (name, sum(len(v) for v in frames.values()), out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
