"""Install rendered forms in the game: each form becomes an animated sheet of its own and a set of clips.

    python3 tools/art/blender/export_forms.py goblin [--from DIR] [form ...]

DIR is what goblin_tree.py wrote (default .tmp/<creature>-tree): one folder per form with frames/ (every frame and its normal map) and raw/meta.json
(how many frames each animation has, how long each lasts, which loop, where the windup ends). For each form this

  1. copies the frames into art_source/frames/anim_<creature>_<form>/ and writes tools/art/anim_<creature>_<form>_frames.json (every frame cut to
     one shared box, so the creature does not jump about between frames),
  2. runs tools/art/assemble_frames.py, which writes assets/sheets/anim_<creature>_<form>.png/.json and the normal map <set>_n.png,
  3. adds the form's clips to data/form_clips.json, which Enemy plays for a twin whose `form` is <creature>_<form>.

An attack becomes two clips that the engine's verb states play: `windup` (the anticipation, held on its last frame until the verb fires) and
`recover` (release, strike, follow-through and recovery). A death becomes `die` and `downed` (its last frame).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import clips  # noqa: E402

ANIM_ORDER = ("idle", "walk", "run", "attack", "hurt", "die")
CLIPS_PATH = os.path.join("data", "form_clips.json")


def frame_names(anim, count):
    return ["%s_%d" % (anim, i) for i in range(count)]


def clips_of(meta, tick=0.02):
    """{state: clip} for the engine from a render's meta.json: its frame counts, durations, loops and where the attack's windup ends."""
    counts, durations, loops = meta["anims"], meta["durations"], meta["loops"]
    out = {}
    for anim in ("idle", "walk", "run", "hurt"):
        if anim in counts:
            out[anim] = clips.on_grid(frame_names(anim, counts[anim]), durations[anim], loops[anim], tick)
    if "attack" in counts:
        names, dur, split = frame_names("attack", counts["attack"]), durations["attack"], meta.get("windup", 0)
        out["attack"] = clips.on_grid(names, dur, False, tick)
        if 0 < split < len(names):
            out["windup"] = clips.on_grid(names[:split], dur[:split], False, tick)
            out["recover"] = clips.on_grid(names[split:], dur[split:], False, tick)
    if "die" in counts:
        names = frame_names("die", counts["die"])
        out["die"] = clips.on_grid(names, durations["die"], False, tick)
        out["downed"] = {"frames": [names[-1]], "fps": 1.0, "loop": False}
    return out


def spec_of(set_name, names):
    return {"set": set_name, "common_box": True, "frames": [{"name": n, "width": 0, "native": True} for n in names]}


def install(creature, form, folder, root=ROOT, assemble=True):
    """Put one rendered form in the game. Returns (form id, its clips)."""
    set_name = "anim_%s_%s" % (creature, form)
    with open(os.path.join(folder, "raw", "meta.json")) as fh:
        meta = json.load(fh)
    dest = os.path.join(root, "art_source", "frames", set_name)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    names = []
    for anim in ANIM_ORDER:
        for n in frame_names(anim, meta["anims"].get(anim, 0)):
            shutil.copy(os.path.join(folder, "frames", n + ".png"), os.path.join(dest, n + ".png"))
            shutil.copy(os.path.join(folder, "frames", n + "_n.png"), os.path.join(dest, n + "_n.png"))
            names.append(n)
    with open(os.path.join(root, "tools", "art", set_name + "_frames.json"), "w") as fh:
        json.dump(spec_of(set_name, names), fh, indent=1)
    if assemble:
        done = subprocess.run([sys.executable, os.path.join("tools", "art", "assemble_frames.py"), set_name], cwd=root, capture_output=True, text=True)
        if done.returncode != 0:
            raise RuntimeError("assemble_frames failed for %s:\n%s%s" % (set_name, done.stdout[-1500:], done.stderr[-1500:]))
    return "%s_%s" % (creature, form), clips_of(meta)


def write_clips(table, root=ROOT):
    """Merge {form id: clips} into data/form_clips.json, in form-id order."""
    path = os.path.join(root, CLIPS_PATH)
    current = {}
    if os.path.exists(path):
        with open(path) as fh:
            current = json.load(fh)
    current.update(table)
    with open(path, "w") as fh:
        json.dump({k: current[k] for k in sorted(current)}, fh, indent=1)
        fh.write("\n")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("creature")
    ap.add_argument("forms", nargs="*")
    ap.add_argument("--from", dest="source")
    a = ap.parse_args(argv)
    source = a.source or os.path.join(ROOT, ".tmp", "%s-tree" % a.creature)
    forms = a.forms or sorted(d for d in os.listdir(source) if os.path.isdir(os.path.join(source, d, "raw")) and d != "goblin")
    table = {}
    for form in forms:
        fid, c = install(a.creature, form, os.path.join(source, form))
        table[fid] = c
        print("installed", fid, flush=True)
    write_clips(table)
    print("wrote", CLIPS_PATH)
    return 0


if __name__ == "__main__":
    sys.exit(main())
