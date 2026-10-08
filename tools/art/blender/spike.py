"""Run the Dead Cells style pipeline for one creature and see the result.

    python3 tools/art/blender/spike.py goblin [--variant redcap] [--out DIR] [--anims idle,walk,attack]

1. Blender renders each frame as a colour pass and a normal pass (render_set.py, headless, no window).
2. toon.py lights them with a cel shade, shrinks to game size with crisp alpha, outlines, and snaps every frame to one shared palette.
3. Writes DIR/<creature>[_<variant>]/: frames/<anim>_<n>.png (the sprite), frames/<anim>_<n>_n.png (its normal map, for 2D lighting),
   <anim>.gif (a 4x loop) and board.png (the frames beside the game's current sprites for the same creature).

Needs Blender (BLENDER=/path overrides /Applications/Blender.app) and Pillow.
"""
import argparse
import json
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import shade  # noqa: E402
import toon  # noqa: E402

BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
BACKDROP = (36, 36, 46, 255)
GROUND = (70, 70, 90, 255)
ZOOM = 4
# what the game draws today for each creature, to put beside the render: (sheet, frames)
CURRENT = {
    "goblin": ("goblin", ["idle_1", "run_1", "run_2", "run_3", "run_4"]),
    "spider": ("spider", ["hang_1", "crawl_1", "crawl_2", "crawl_3", "crawl_4"]),
    "wolf": ("gloom_wolf", ["idle_1", "walk_1", "walk_2", "walk_3", "windup_1"]),
}


def render(creature, out, variant=None, anims=None, ss=4, empty_hands=False):
    cmd = [BLENDER, "-b", "--factory-startup", "-P", os.path.join(HERE, "render_set.py"), "--", "--creature", creature, "--out", out, "--ss", str(ss)]
    if variant:
        cmd += ["--variant", variant]
    if anims:
        cmd += ["--anims", anims]
    if empty_hands:
        cmd.append("--empty-hands")   # the held pieces are left out; the game draws them (render_set.py)
    stale = os.path.join(out, "meta.json")
    if os.path.exists(stale):
        os.remove(stale)  # Blender exits cleanly on a Python error: only a fresh meta.json proves the run finished
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0 or "Traceback" in done.stdout + done.stderr or not os.path.exists(stale):
        raise RuntimeError("Blender failed:\n" + done.stdout[-2500:] + done.stderr[-2500:])


RIM, CREASES, LIT_OUTLINE = False, False, 0.62   # no automatic rim light or crease lines (form comes from the broad steps), and an outline that is lighter where it touches light
BAKE = 1.0   # how much of the lighting is painted into the sprite (1: a five-step ramp per material; 0.5: three steps, leaving more to the room's lights)


def _flat_outline_normals(lit, normals):
    """The normal map for a sprite that has an outline: the outline's pixels, which have no surface of their own, face the viewer."""
    out = normals.copy()
    lp, op = lit.load(), out.load()
    for y in range(lit.height):
        for x in range(lit.width):
            if lp[x, y][3] and not op[x, y][3]:
                op[x, y] = (128, 128, 255, 255)
    return out


def clear_stale(folder, keys):
    """Delete the frames (`<anim>_<n>.png` and its `_n.png`) in `folder` that are not one of `keys`: a re-render with fewer frames must not leave the old ones for the readers that count frames by file."""
    for name in os.listdir(folder):
        m = re.fullmatch(r"(.+_\d+)(_n)?\.png", name)
        if m and m.group(1) not in keys:
            os.remove(os.path.join(folder, name))


def process(raw, out, outline=True, bake=BAKE):
    """Shrink, light, outline and palette-snap every frame in `raw` (what render() wrote); returns {anim: [frame names]}. Writes each frame
    and its normal map to out/frames."""
    with open(os.path.join(raw, "meta.json")) as fh:
        meta = json.load(fh)
    canvas = meta["canvas"]
    materials = [tuple(m) for m in meta["materials"]]
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    clear_stale(os.path.join(out, "frames"), {"%s_%d" % (anim, i) for anim, count in meta["anims"].items() for i in range(count)})
    colours = shade.palette_colours(materials, bake)
    pal = toon.palette_of(colours)  # every colour a creature can show: its materials' ramps and their outline darks (refuses more than a palette can hold)
    result = {}
    for anim, count in meta["anims"].items():
        keys = ["%s_%d" % (anim, i) for i in range(count)]
        passes = []
        for key in keys:
            with Image.open(os.path.join(raw, key + "_albedo.png")) as a, Image.open(os.path.join(raw, key + "_normal.png")) as n:
                passes.append((a.convert("RGBA"), n.convert("RGBA")))
        prev_a, prev_steps, done = None, None, []
        for lap in range(2 if meta.get("loops", {}).get(anim, True) else 1):  # a loop's second lap starts from the last frame of the first, so its seam is as steady as the rest; an action starts cold
            done = []
            for a, n in passes:
                small_a, small_n = shade.reduce_passes(a, n, (canvas, canvas), materials, previous=prev_a)
                steps = {}
                lit = shade.shade(small_a, small_n, bake=bake, rim=RIM, creases=CREASES, previous=prev_steps, record=steps)
                prev_a, prev_steps = small_a, steps
                done.append((lit, small_n))
        result[anim] = keys
        for key, (lit, small_n) in zip(keys, done):
            if outline:
                lit = toon.outline(lit, shade.DARK, LIT_OUTLINE)
            lit = toon.apply_palette(lit, pal)
            if lit.getbbox() is None:
                raise RuntimeError("frame %s is empty: the creature is outside its canvas" % key)
            lit.save(os.path.join(out, "frames", key + ".png"))
            _flat_outline_normals(lit, small_n).save(os.path.join(out, "frames", key + "_n.png"))
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
    ap.add_argument("--anims")
    ap.add_argument("--empty-hands", action="store_true", help="leave out what the hands carry (goblin forms)")
    ap.add_argument("--no-outline", action="store_true")
    args = ap.parse_args(argv)
    name = args.creature + ("_" + args.variant if args.variant else "")
    out = os.path.join(args.out, name)
    raw = os.path.join(out, "raw")
    os.makedirs(raw, exist_ok=True)
    render(args.creature, raw, args.variant, args.anims, empty_hands=args.empty_hands)
    frames = process(raw, out, not args.no_outline)
    meta = json.load(open(os.path.join(raw, "meta.json")))
    gifs(out, frames, meta["margin"])
    board(out, args.creature, frames)
    print("%s: %d frames in %s" % (name, sum(len(v) for v in frames.values()), out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
