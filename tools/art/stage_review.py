"""Review a species' movement on the 3D photo stage before anything is baked to 2D:

    python3 tools/art/stage_review.py goblin --script jump_ledges [--variant redcap] [--every 3] [--out DIR] [--reuse]
    python3 tools/art/stage_review.py wolf --script walk_run --view-px 110 --size 960x540 --out .tmp/x   (a close look: the view is 110 game pixels wide)
    python3 tools/art/stage_review.py goblin            (every script the species can run)      python3 tools/art/stage_review.py all     (every species)
    python3 tools/art/stage_review.py goblin --gesture slam   (or `all`: every gesture of tools/verb_anims.json, cast in place; no recording)

1. The game records the run (tools/record_movement.gd: the sandbox's own movement over its own course) to .tmp/stage/<species>_<script>.json; it is recorded again every time, so a
   review is never of an older game, unless --reuse says to take the file that is there.
2. Blender poses the creature along it on the course, with the game's playback rules (tools/art/blender/stage_review.py).
3. The frames are put together as DIR/review.gif (DIR defaults to .tmp/stage/<creature>/<script>/) with review_sheet.png, a few frames side by side to read at a glance, and the report
   lines name the states the creature has no pose for and how far a foot is dragged.

Needs Godot (GODOT=/path overrides `godot`), Blender (BLENDER=/path overrides /Applications/Blender.app) and Pillow.
"""
import argparse
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "blender"))
from stage_review import KNOWN_ARCHETYPES, KNOWN_MISSING, RUNS, SPECIES, gif_durations, positive_int  # noqa: E402
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
GODOT = os.environ.get("GODOT", "godot")
STAGE = os.path.join(ROOT, ".tmp", "stage")
SHEET_FRAMES = 8
GESTURE_VIEW_PX = 150   # a gesture is judged close up


def species_of(creature):
    """The movement profile's species for a creature module: the werewolves move as the wolf does."""
    return {"werewolf": "wolf"}.get(creature, creature)


def record(species, script, path):
    env = dict(os.environ, HOME=os.path.join(ROOT, ".tmp", "gdhome"))
    os.makedirs(env["HOME"], exist_ok=True)
    done = subprocess.run([GODOT, "--headless", "-s", "tools/record_movement.gd", "--", species, script], cwd=ROOT, env=env, capture_output=True, text=True)
    if done.returncode != 0 or not os.path.exists(path):
        sys.exit("recording failed:\n" + (done.stdout + done.stderr)[-2000:])


def render(creature, variant, recordings, out, every, view_px=None, size=None):
    cmd = [BLENDER, "-b", "--factory-startup", "-P", os.path.join(HERE, "blender", "stage_review.py"), "--", "--creature", creature, "--recording", *recordings, "--out", out, "--every", str(every)]
    if view_px:
        cmd += ["--view-px", str(view_px)]
    if size:
        cmd += ["--size", size]
    if variant:
        cmd += ["--variant", variant]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0:
        sys.exit("render failed:\n" + (done.stdout + done.stderr)[-3000:])
    return done.stdout


def assemble(out):
    """The GIF and the contact sheet of a rendered folder; returns its review.json."""
    with open(os.path.join(out, "review.json")) as fh:
        meta = json.load(fh)
    frames = [Image.open(os.path.join(out, "frame_%04d.png" % f["frame"])).convert("RGB") for f in meta["frames"]]
    frames[0].save(os.path.join(out, "review.gif"), save_all=True, append_images=frames[1:], duration=gif_durations(len(frames), meta["fps"]), loop=0, optimize=False)
    cast = [i for i, f in enumerate(meta["frames"]) if f["state"] == "cast"]  # a gesture's sheet is its own frames: the windup, the impact and the recovery
    span = cast or list(range(len(frames)))
    pick = [frames[span[int(i * (len(span) - 1) / (SHEET_FRAMES - 1))]] for i in range(SHEET_FRAMES)]
    w, h = pick[0].size
    sheet = Image.new("RGB", (w * 2, h * (SHEET_FRAMES // 2)))
    for i, im in enumerate(pick):
        sheet.paste(im, ((i % 2) * w, (i // 2) * h))
    sheet.save(os.path.join(out, "review_sheet.png"))
    return meta


def states(meta):
    runs = []
    for f in meta["frames"]:
        if not runs or runs[-1][0] != f["state"]:
            runs.append([f["state"], 0])
        runs[-1][1] += 1
    return "  ".join("%s x%d" % (s, n) for s, n in runs)


def review(creature, variant, scripts, every, out=None, reuse=False, view_px=None, size=None):
    """Render every script of one creature in one Blender run and put each together; the report lines name the states it has no pose for (and flag one KNOWN_MISSING does not list)."""
    species = species_of(creature)
    recordings = []
    for script in scripts:
        path = os.path.join(STAGE, "%s_%s.json" % (species, script))
        if not (reuse and os.path.exists(path)):
            record(species, script, path)
        recordings.append(path)
    base = out or os.path.join(STAGE, creature + ("_" + variant if variant else ""))
    if len(scripts) == 1 and not out:
        base = os.path.join(base, scripts[0])  # one script has its own folder, so two reviews of one creature do not overwrite each other
    render(creature, variant, recordings, base, every, view_px, size)
    lines = []
    for script in scripts:
        folder = base if len(recordings) == 1 else os.path.join(base, script)
        meta = assemble(folder)
        known = KNOWN_MISSING.get(species, {}).get(script, [])
        gap = ", ".join(meta["missing"]) or "none"
        new = [m for m in meta["missing"] if m not in known]
        feet = "" if meta.get("foot_slide_px") is None else "  foot slide %.2f px" % meta["foot_slide_px"]
        lines.append("%-8s %-12s no pose for: %-22s%s%s   %s" % (creature, script, gap, "  NEW: " + ", ".join(new) if new else "", feet, os.path.join(folder, "review.gif")))
        lines.append("           " + states(meta))
    return lines


def gesture_review(creature, variant, name, every, out=None):
    """Cast `name` (or every gesture) on the stage for one creature, and put each together; the lines name the gestures the creature has no preset for (and flag one KNOWN_ARCHETYPES does not list)."""
    base = out or os.path.join(STAGE, creature + ("_" + variant if variant else ""), "gestures")
    cmd = [BLENDER, "-b", "--factory-startup", "-P", os.path.join(HERE, "blender", "stage_review.py"), "--", "--creature", creature, "--gesture", name, "--out", base, "--every", str(every),
           "--view-px", str(GESTURE_VIEW_PX)]
    if variant:
        cmd += ["--variant", variant]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0:
        sys.exit("render failed:\n" + (done.stdout + done.stderr)[-3000:])
    with open(os.path.join(base, "gesture_manifest.json")) as fh:
        manifest = json.load(fh)
    missing = manifest["missing"]
    lines = []
    for name in manifest["rendered"]:   # this run's gestures only, not the folders an earlier run left beside them
        folder = "gesture_" + name
        assemble(os.path.join(base, folder))
        lines.append("%-8s %-8s %s" % (creature, name, os.path.join(base, folder, "review.gif")))
    known = KNOWN_ARCHETYPES.get(creature, [])
    new = [m for m in missing if m not in known]
    lines.append("%-8s no preset for: %s%s" % (creature, ", ".join(missing) or "none", "   NEW: " + ", ".join(new) if new else ""))
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("creature", help="goblin, undead, wolf, spider or slime, or `all`")
    ap.add_argument("--script", help="walk_run, jump_ledges, wall_shaft, crawl, pounce, or `all` (every one the species can run; the default)")
    ap.add_argument("--gesture", help="a gesture of tools/verb_anims.json, or `all`: cast in place instead of a recorded run")
    ap.add_argument("--variant")
    ap.add_argument("--out")
    ap.add_argument("--every", type=positive_int, default=3, help="pose every Nth recorded tick (60 ticks a second)")
    ap.add_argument("--reuse", action="store_true", help="take a recording that is already there instead of recording the run again")
    ap.add_argument("--view-px", type=float, help="how many game pixels wide the view is (default 360: the whole course; 100 to 150 is a close look at the creature)")
    ap.add_argument("--size", help="the render's WxH (default 640x360; 960x540 with a close view)")
    a = ap.parse_args()
    everything = a.creature == "all"
    if a.gesture:
        for creature in SPECIES if everything else [a.creature]:
            for line in gesture_review(creature, a.variant, a.gesture, 2 if a.every == 3 else a.every, None if everything else a.out):
                print(line)
        return
    for creature in SPECIES if everything else [a.creature]:
        scripts = [a.script] if a.script and a.script != "all" and not everything else RUNS[species_of(creature)]
        for line in review(creature, a.variant, scripts, a.every, None if everything else a.out, a.reuse, a.view_px, a.size):
            print(line)


if __name__ == "__main__":
    main()
