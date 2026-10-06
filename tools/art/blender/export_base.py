"""Replace a shipped base creature's art with a render: the goblin (also the player's two-legged body), the gloom wolf (also the player's wolf body), later the spider.

    python3 tools/art/blender/export_base.py goblin|gloom_wolf [--from DIR]

DIR holds the render of the base form (species_tree.py wrote it; default .tmp/<species>-tree). A shipped creature's sheet has the frames its clips name
(data/enemy_clips.json), and the game (Enemy, SpeciesLook, Player) asks for those clips by state, so the render is cut into exactly those states: each state is
taken from a render clip (all its frames, or the ones listed), keeps its durations, and the frames are renamed `<state>_<n>`. Every frame is cut about the creature's centre (so it
does not drift sideways) and to its own height (a shipped creature's states are different sizes: the game and its rooms read them), the normal map is written beside the sheet, and the creature's entry of enemy_clips.json is rewritten.
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

# set -> where its render is and which state comes from which render clip: (state, render clip, frames or None for all, loops, options)
SPECS = {
    "goblin": dict(render=("goblin", "goblin"), key="goblin", states=[
        ("idle", "idle", None, True, {}), ("run", "run", None, True, {}), ("rise", "rise", [0], False, {}), ("fall", "fall", [0], False, {}),
        ("roll", "roll", None, True, {}), ("slide", "slide", [0], False, {}), ("mantle", "mantle", None, False, {}), ("wall", "wall", [0], True, {}),
        ("land", "land", [0], False, {})]),
    "gloom_wolf": dict(render=("wolf", "gloom_wolf"), key="gloom_wolf", states=[
        ("idle", "idle", None, True, {}), ("walk", "walk", None, True, {}), ("windup", "attack", [2], False, {}),
        ("charge", "run", None, True, {"attack_from": 0.55}), ("rest", "attack", [9], True, {}), ("stunned", "hurt", [2], False, {}),
        ("hurt", "hurt", [2], False, {}), ("downed", "die", [-1], False, {})]),
}


def plan(spec, meta):
    """([(new frame name, source frame name, options)], {state: clip}) for a spec and a render's meta.json."""
    frames, table = [], {}
    for state, source, picks, loop, options in spec["states"]:
        count = meta["anims"][source]
        indices = list(range(count)) if picks is None else [i % count for i in picks]
        names = []
        for n, i in enumerate(indices, 1):
            new = "%s_%d" % (state, n)
            frames.append((new, "%s_%d" % (source, i), options))
            names.append(new)
        durations = [meta["durations"][source][i] for i in indices]
        table[state] = clips.on_grid(names, durations, loop) if len(names) > 1 else {"frames": names, "fps": 1.0, "loop": bool(loop)}
    return frames, table


def install(name, folder, root=ROOT, assemble=True):
    spec = SPECS[name]
    with open(os.path.join(folder, "raw", "meta.json")) as fh:
        meta = json.load(fh)
    frames, table = plan(spec, meta)
    dest = os.path.join(root, "art_source", "frames", name)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for new, source, _ in frames:
        shutil.copy(os.path.join(folder, "frames", source + ".png"), os.path.join(dest, new + ".png"))
        shutil.copy(os.path.join(folder, "frames", source + "_n.png"), os.path.join(dest, new + "_n.png"))
    entries = []
    for new, _, options in frames:
        entry = {"name": new, "width": 0, "native": True}
        entry.update(options)
        entries.append(entry)
    with open(os.path.join(root, "tools", "art", name + "_frames.json"), "w") as fh:
        json.dump({"set": name, "centred_frames": True, "anchor": frames[0][0], "frames": entries}, fh, indent=1)
    if assemble:
        done = subprocess.run([sys.executable, os.path.join("tools", "art", "assemble_frames.py"), name], cwd=root, capture_output=True, text=True)
        if done.returncode != 0:
            raise RuntimeError("assemble_frames failed for %s:\n%s%s" % (name, done.stdout[-1500:], done.stderr[-1500:]))
    path = os.path.join(root, "data", "enemy_clips.json")
    with open(path) as fh:
        current = json.load(fh)
    current[spec["key"]] = table
    with open(path, "w") as fh:
        json.dump(current, fh, indent=1)
        fh.write("\n")
    return table


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("name", choices=sorted(SPECS))
    ap.add_argument("--from", dest="source")
    a = ap.parse_args(argv)
    species, form = SPECS[a.name]["render"]
    source = a.source or os.path.join(ROOT, ".tmp", "%s-tree" % species)
    table = install(a.name, os.path.join(source, form))
    print("installed %s: %s" % (a.name, ", ".join("%s (%d)" % (s, len(c["frames"])) for s, c in table.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
