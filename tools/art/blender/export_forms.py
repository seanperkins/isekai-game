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
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import clips  # noqa: E402
import held  # noqa: E402
import sizing  # noqa: E402

BASES = {"goblin": "goblin", "wolf": "gloom_wolf", "spider": "spider", "undead": "skeleton", "slime": "slime"}   # a family's base creature is not a twin: it has its own sheet
ANIM_ORDER = ("idle", "walk", "run", "attack", "hurt", "die")
ENEMY_GD = os.path.join(ROOT, "scripts", "enemies", "enemy.gd")


def engine_constants(path=ENEMY_GD):
    """The timings the game's enemy runs on, read from its source so the art cannot drift from it: {"windup", "recover", "hurt", "run_speed"}."""
    with open(path) as fh:
        text = fh.read()
    names = {"windup": "VERB_WINDUP", "recover": "VERB_RECOVER", "hurt": "HURT_SECONDS", "run_speed": "RUN_SPEED"}
    return {key: float(re.search(r"^const %s := ([0-9.]+)" % const, text, re.M).group(1)) for key, const in names.items()}


def check_timing(meta, constants, slack=0.011):
    """Raise ValueError unless the attack's windup frames last as long as the engine's windup (so the impact frame comes up as the verb fires), its
    recovery frames no longer than the engine's recover (so nothing slides under the animation once the creature is free to move), and the flinch
    as long as the engine's."""
    d = meta["durations"]
    if "attack" in d:
        split = meta["windup"]
        windup, recover = sum(d["attack"][:split]), sum(d["attack"][split:])
        if abs(windup - constants["windup"]) > slack:
            raise ValueError("the windup frames last %.3f s, the engine's windup %.3f s" % (windup, constants["windup"]))
        if recover > constants["recover"] + slack:
            raise ValueError("the recovery frames last %.3f s, longer than the engine's recover %.3f s" % (recover, constants["recover"]))
    if "hurt" in d and abs(sum(d["hurt"]) - constants["hurt"]) > slack:
        raise ValueError("the flinch lasts %.3f s, the engine's %.3f s" % (sum(d["hurt"]), constants["hurt"]))
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


def form_id(creature, form):
    """The id a twin's `form` field holds: the species and the form (goblin_redcap), except the slime forms, which are named bare (kraken)."""
    return form if creature == "slime" else "%s_%s" % (creature, form)


def spec_of(set_name, names, hands=None):
    """The assembler's spec for a set: every frame native and cut to one box. `hands` ({frame: {side: [px, py, degrees]}}) are placed with each frame."""
    frames = [{"name": n, "width": 0, "native": True} for n in names]
    for entry in frames:
        if hands and entry["name"] in hands:
            entry["hands"] = hands[entry["name"]]
    return {"set": set_name, "common_box": True, "frames": frames}


def install(creature, form, folder, root=ROOT, assemble=True, check=True):
    """Put one rendered form in the game. Returns (form id, its clips)."""
    set_name = "anim_" + form_id(creature, form)
    with open(os.path.join(folder, "raw", "meta.json")) as fh:
        meta = json.load(fh)
    held.check_empty_handed(meta)   # an armed goblin render would draw every weapon twice beside the held-item layer
    if check:
        check_timing(meta, engine_constants())
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
        json.dump(spec_of(set_name, names, meta.get("hands")), fh, indent=1)
    if assemble:
        done = subprocess.run([sys.executable, os.path.join("tools", "art", "assemble_frames.py"), set_name], cwd=root, capture_output=True, text=True)
        if done.returncode != 0:
            raise RuntimeError("assemble_frames failed for %s:\n%s%s" % (set_name, done.stdout[-1500:], done.stderr[-1500:]))
    if creature == "goblin":
        held.update_table(os.path.join(root, "data", "held_items.json"), forms={form_id(creature, form): held.form_entry(form, meta["ppu"])})
    return form_id(creature, form), clips_of(meta)


SPECIES = ("goblin", "wolf", "undead", "spider")   # the families whose forms are named <species>_<form>; the slime's are bare


def split_id(fid):
    """(species, form) of an id `form_id` made: wolf_fenrir is ("wolf", "fenrir"), kraken ("slime", "kraken")."""
    head, _, rest = fid.partition("_")
    return (head, rest) if head in SPECIES and rest else ("slime", fid)


def write_clips(table, root=ROOT, speeds=None):
    """Merge {form id: clips} into data/form_clips.json, in form-id order. `speeds` ({form id: px/s}) are the walking speeds the clips were built
    for, kept under "_walk_speeds": a body that is not the enemy (the player as that form) plays a walk at the speed it really goes against it."""
    path = os.path.join(root, CLIPS_PATH)
    current = {}
    if os.path.exists(path):
        with open(path) as fh:
            current = json.load(fh)
    current.update(table)
    if speeds:
        current["_walk_speeds"] = dict(sorted(dict(current.get("_walk_speeds", {}), **speeds).items()))
    with open(path, "w") as fh:
        json.dump({k: current[k] for k in sorted(current)}, fh, indent=1)
        fh.write("\n")


def wearable(creature, forms, exists=os.path.exists):
    """(forms a twin wears, forms no twin wears): an evolution with no enemy twin has no one to play its clips."""
    kept = [f for f in forms if exists(sizing.twin_path(creature, f))]
    return kept, [f for f in forms if f not in kept]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("creature")
    ap.add_argument("forms", nargs="*")
    ap.add_argument("--from", dest="source")
    a = ap.parse_args(argv)
    source = a.source or os.path.join(ROOT, ".tmp", "%s-tree" % a.creature)
    forms = a.forms or sorted(d for d in os.listdir(source) if os.path.isdir(os.path.join(source, d, "raw")) and d != BASES.get(a.creature))
    if not a.forms:
        forms, left_out = wearable(a.creature, forms)
        for form in left_out:
            print("left out %s: no twin wears it" % form, flush=True)
    table, speeds = {}, {}
    for form in forms:
        fid, c = install(a.creature, form, os.path.join(source, form))
        table[fid] = c
        speeds[fid] = round(sizing.speed_of(a.creature, form), 3)
        print("installed", fid, flush=True)
    write_clips(table, ROOT, speeds)
    print("wrote", CLIPS_PATH)
    return 0


if __name__ == "__main__":
    sys.exit(main())
