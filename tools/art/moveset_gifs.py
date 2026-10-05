"""Assembles the moveset GIFs and docs/evolutions/movesets/movesets.json from the frames tools/moveset_gifs.gd captured from the
real engine (the movement sandbox, scripted input). Run from the project root:

  mkdir -p .tmp/moveset-gifs && D=$(mktemp -d .tmp/moveset-gifs/run.XXXXXX)
  env HOME="$PWD/.tmp/gdhome" TMPDIR="$PWD/$D" gtimeout -k 5 600 godot --path . --windowed --resolution 640x360 --fixed-fps 60 \\
      -s res://tools/moveset_gifs.gd -- --out="$PWD/$D"          # windowed, so unsandboxed
  uv run --python 3.12 --with Pillow python tools/art/moveset_gifs.py "$D"

With no argument it takes the newest .tmp/moveset-gifs/run.* directory. The GIFs play at the speed the game ran (a frame every
2nd physics tick, 30 fps), except the clips marked slow, which are captured every tick and play at half speed.
"""
import glob
import json
import os
import sys

from PIL import Image, ImageChops

OUT = "docs/evolutions/movesets"
MAX_BYTES = 1_500_000
TICK_MS = 1000.0 / 60.0
COLORS = 128
LEAD = 8  # frames of rest kept before the first change, and
TAIL = 14  # after the last one
SAMPLES = 24  # frames mixed into the clip's palette

SPECIES = [
    ("slime", "Slime"),
    ("biped", "Biped (goblin and undead body)"),
    ("wolf", "Wolf"),
    ("spider", "Spider"),
]

# species -> [(clip id, title, caption)]; the captions say which input does what (Space jump, J the signature button, the arrows
# steer and aim, down is the down arrow). Keep them true to scripts/movement and docs/ledgers/species-movesets-*.
CLIPS = {
    "slime": [
        ("run", "Run", "Left and right run at 140 px/s: 0.05 s to get up to speed, 0.06 s to stop and a slow 0.08 s turn round."),
        ("jump", "Jump to a ledge", "Space jumps and the height follows how long it is held: a tap is a small hop (letting go early makes gravity 2.5 times heavier on the way up), a full hold rises about 63 px. That clears the 40 px ledge, then the 60 px one with 3 px to spare."),
        ("bounce", "Hold-jump bounce", "Keep Space held through a fall and the slime rebounds on landing as a ball with its eyes rolling, each bounce at 85% of the last launch speed, until the impact drops under 250 px/s. Let go of Space and it settles."),
        ("tackle", "Tackle", "J is a short dash along the facing: 340 px/s for 0.18 s, in the tackle pose. Shown at half speed."),
        ("puddle", "Puddle", "Run, then hold down: the slime flattens into a 0.5 s puddle slide and keeps crawling at half speed while down is held, flat enough for the 12 px tunnel. It stands up again once down is released and there is room."),
        ("wall", "Wall cling and wall jump", "Pressing into a wall in the air makes the slime stick for 0.2 s, then slide down at 90 px/s. Space kicks off the wall at 180 px/s with a full jump; kicking from wall to wall climbs the shaft."),
    ],
    "biped": [
        ("run", "Run", "Left and right run at 140 px/s, with a fast start (0.04 s), a fast stop (0.03 s) and a quick turn."),
        ("jump", "Jump", "Space jumps about 60 px when held; a tap cuts the rise to a small hop. Here a tap, then a held run-up jump that goes up through the thin one-way ledge and lands on it."),
        ("roll", "Roll", "J from a standstill, or under 100 px/s, rolls at 220 px/s for 0.35 s with a low flat body. The body is drawn translucent for the first 0.2 s, which are invulnerable."),
        ("slide", "Slide", "J while running (100 px/s or more) slides instead: the run speed bleeds off over 0.4 s in the same low body, again invulnerable for the first 0.2 s."),
        ("mantle", "Mantle", "Jump at a ledge with a wall ahead so the feet end up within 32 px under its lip (this 60 px one, which a 60 px jump only just reaches) and the hands catch the lip: no button, the biped is pulled up and over in 0.25 s. Shown at half speed."),
        ("walljump", "Wall slide and wall jump", "Pressing into a wall in the air slides down it at 90 px/s (the biped does not stick, unlike the slime). Space kicks off at 180 px/s with a full jump; kicking from wall to wall climbs the shaft."),
        ("dropthrough", "Drop through a thin ledge", "Down while standing on a one-way ledge drops through it for 0.2 s, and a jump from below passes up through it and lands on top. Every species can; shown with the biped."),
    ],
    "wolf": [
        ("gallop", "Gallop", "The wolf is slow to start: 0.4 s from rest to its 230 px/s top speed, walking at first and galloping from 150 px/s. Released, it stops in 0.1 s."),
        ("skid", "Skid turn", "Reversing at a gallop (150 px/s or more) is a skid: it brakes in 0.1 s, leans back and kicks up dust, then sets off the other way. Shown at half speed."),
        ("pounce", "Pounce", "J leaps along the aim at 300 px/s (plus half the speed it already had) for 0.35 s, then gravity takes over; one pounce per jump and 0.8 s before the next. Up and right here, then up and left. The sandbox only records contact with the red dummy: the flash is added by the capture. Shown at half speed."),
        ("vault", "Vault a step", "Running at 150 px/s or more into a hard step up to 24 px high makes the wolf hop it by itself, with no jump press, keeping its speed. The step here is an extra 16 px one in the open: the sandbox's own sits 20 px from the wall, too close to land past."),
    ],
    "spider": [
        ("crawl", "Crawl walls and ceilings", "The arrows crawl along any hard surface. One held direction takes the spider up the pillar's wall, over its corner onto the slab, round to the underside and down the far side to the floor."),
        ("zip", "Web zip", "J fires a thread along the aim at the first solid within 160 px and pulls the spider to it at 400 px/s, gripping what it reaches. Up to the slab's underside, then down and left to the pillar's wall. Shown at half speed."),
        ("drop", "Silk drop", "Down, hanging from a ceiling or in the air, spins a thread from the solid above and slides down it at 90 px/s. Down reels out, up climbs back at 60 px/s, Space lets go, and the floor grips it again."),
        ("slick", "Slick block", "The pale block is slick: the spider cannot hold a thread to it, crawl up it or hang from it. A zip at it from 100 px away, well in range, fizzles with no thread; crawling up to it stops at the face, and a hop at it slides off."),
    ],
}


def newest_run():
    runs = sorted(glob.glob(".tmp/moveset-gifs/run.*"), key=os.path.getmtime)
    return runs[-1] if runs else None


def differs(a, b, tolerance=24):
    """Whether two frames differ by more than `tolerance` pixels (a breathing idle frame does not count as a change)."""
    bbox = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox is None:
        return False
    region = ImageChops.difference(a.crop(bbox), b.crop(bbox)).convert("L").point(lambda v: 255 if v > 24 else 0)
    return sum(1 for v in region.getdata() if v) > tolerance


def trim(frames):
    """Drops dead frames at the ends, keeping LEAD frames of rest before the first change and TAIL after the last one."""
    n = len(frames)
    first = next((i for i in range(1, n) if differs(frames[i - 1], frames[i])), 0)
    last = next((i for i in range(n - 1, 0, -1) if differs(frames[i - 1], frames[i])), n - 1)
    start = max(0, first - LEAD)
    end = min(n, last + 1 + TAIL)
    return frames[start:end]


def palette_for(frames):
    """One palette for the whole clip (so every frame indexes the same colours and the GIF can store only what changed)."""
    step = max(1, len(frames) // SAMPLES)
    picks = frames[::step][:SAMPLES]
    w, h = picks[0].size
    sheet = Image.new("RGB", (w, h * len(picks)))
    for i, f in enumerate(picks):
        sheet.paste(f, (0, i * h))
    return sheet.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def durations(count, per_frame_ms):
    """Per-frame delays in whole centiseconds that add up to the real time (3,3,4,3,3,4 for 33.3 ms)."""
    out, emitted, total = [], 0, 0.0
    for _ in range(count):
        total += per_frame_ms
        cs = max(2, round(total / 10.0) - emitted)
        emitted += cs
        out.append(cs * 10)
    return out


def assemble(run, entry):
    paths = sorted(glob.glob(os.path.join(run, entry["dir"], "*.png")))
    paths = paths[: int(entry["frames"])]  # the frames this capture wrote, not strays left by an earlier one
    frames = [Image.open(p).convert("RGB") for p in paths]
    frames = trim(frames)
    pal = palette_for(frames)
    quant = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    per_frame = int(entry["stride"]) * int(entry["slow"]) * TICK_MS
    name = "%s-%s.gif" % (entry["species"], entry["id"])
    path = os.path.join(OUT, name)
    quant[0].save(path, save_all=True, append_images=quant[1:], duration=durations(len(quant), per_frame), loop=0, optimize=True)
    size = os.path.getsize(path)
    return name, len(quant), size, frames[0].size, per_frame


def main():
    run = sys.argv[1] if len(sys.argv) > 1 else newest_run()
    if not run:
        sys.exit("no frames: pass the capture directory")
    manifest = {(c["species"], c["id"]): c for c in json.load(open(os.path.join(run, "manifest.json")))["clips"]}
    os.makedirs(OUT, exist_ok=True)
    species_out = []
    total = 0
    for sid, sname in SPECIES:
        clips = []
        for cid, title, caption in CLIPS[sid]:
            entry = manifest.get((sid, cid))
            if entry is None:
                print("MISSING", sid, cid)
                continue
            name, count, size, (w, h), per_frame = assemble(run, entry)
            total += size
            print("%-22s %3d frames %5.2f s %7.0f KB  %dx%d" % (name, count, count * per_frame / 1000.0, size / 1024.0, w, h))
            if size > MAX_BYTES:
                print("  TOO BIG: over %d bytes" % MAX_BYTES)
            clip = {"id": cid, "title": title, "caption": caption, "file": name, "fps": round(1000.0 / per_frame),
                    "width": w, "height": h, "frames": count}
            if int(entry["slow"]) > 1:
                clip["slow"] = int(entry["slow"])
            clips.append(clip)
        species_out.append({"id": sid, "name": sname, "clips": clips})
    with open(os.path.join(OUT, "movesets.json"), "w") as f:
        json.dump({"species": species_out}, f, indent=2)
        f.write("\n")
    print("total %.2f MB" % (total / 1048576.0))


if __name__ == "__main__":
    main()
