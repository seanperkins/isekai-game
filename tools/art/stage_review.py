"""Review a species' movement on the 3D photo stage before anything is baked to 2D:

    python3 tools/art/stage_review.py goblin --script jump_ledges [--variant redcap] [--every 3] [--out DIR] [--record]

1. The game records the run (tools/record_movement.gd: the sandbox's own movement over its own course) to .tmp/stage/<species>_<script>.json, unless that file is already there.
2. Blender poses the creature along it on the course, with the game's playback rules (tools/art/blender/stage_review.py).
3. The frames are put together as DIR/review.gif (DIR defaults to .tmp/stage/<creature>_<script>/) with review_sheet.png, a few frames side by side to read at a glance.

Needs Godot (GODOT=/path overrides `godot`), Blender (BLENDER=/path overrides /Applications/Blender.app) and Pillow.
"""
import argparse
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
GODOT = os.environ.get("GODOT", "godot")
STAGE = os.path.join(ROOT, ".tmp", "stage")
SHEET_FRAMES = 8


def species_of(creature):
    """The movement profile's species for a creature module: the werewolves move as the wolf does."""
    return {"werewolf": "wolf"}.get(creature, creature)


def record(species, script, path):
    env = dict(os.environ, HOME=os.path.join(ROOT, ".tmp", "gdhome"))
    os.makedirs(env["HOME"], exist_ok=True)
    cmd = [GODOT, "--headless", "-s", "tools/record_movement.gd", "--", species, script]
    done = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True)
    if done.returncode != 0 or not os.path.exists(path):
        sys.exit("recording failed:\n" + (done.stdout + done.stderr)[-2000:])


def render(creature, variant, recording, out, every):
    cmd = [BLENDER, "-b", "-P", os.path.join(HERE, "blender", "stage_review.py"), "--", "--creature", creature, "--recording", recording, "--out", out, "--every", str(every)]
    if variant:
        cmd += ["--variant", variant]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0:
        sys.exit("render failed:\n" + (done.stdout + done.stderr)[-3000:])
    return done.stdout


def assemble(out):
    meta = json.load(open(os.path.join(out, "review.json")))
    frames = [Image.open(os.path.join(out, "frame_%04d.png" % f["frame"])).convert("RGB") for f in meta["frames"]]
    ms = int(round(1000.0 / meta["fps"]))
    frames[0].save(os.path.join(out, "review.gif"), save_all=True, append_images=frames[1:], duration=ms, loop=0, optimize=False)
    pick = [frames[int(i * (len(frames) - 1) / (SHEET_FRAMES - 1))] for i in range(SHEET_FRAMES)]
    w, h = pick[0].size
    sheet = Image.new("RGB", (w * 2, h * (SHEET_FRAMES // 2)))
    for i, im in enumerate(pick):
        sheet.paste(im, ((i % 2) * w, (i // 2) * h))
    sheet.save(os.path.join(out, "review_sheet.png"))
    states = []
    for f in meta["frames"]:
        if not states or states[-1][0] != f["state"]:
            states.append([f["state"], 0])
        states[-1][1] += 1
    return "  ".join("%s x%d" % (s, n) for s, n in states)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("creature")
    ap.add_argument("--script", required=True)
    ap.add_argument("--variant")
    ap.add_argument("--out")
    ap.add_argument("--every", type=int, default=3)
    ap.add_argument("--record", action="store_true", help="record the run again even if there is one")
    a = ap.parse_args()
    species = species_of(a.creature)
    recording = os.path.join(STAGE, "%s_%s.json" % (species, a.script))
    if a.record or not os.path.exists(recording):
        record(species, a.script, recording)
    out = a.out or os.path.join(STAGE, "%s%s_%s" % (a.creature, "_" + a.variant if a.variant else "", a.script))
    print(render(a.creature, a.variant, recording, out, a.every).strip())
    print("states: " + assemble(out))
    print("wrote %s" % os.path.join(out, "review.gif"))


if __name__ == "__main__":
    main()
