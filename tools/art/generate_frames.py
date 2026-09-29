"""Generate frames one at a time with Codex ($imagegen). Every frame is its own image, never a sheet.

Each frame is given the canonical slime as a style reference, plus the earlier frames it lists in
`refs`, so the character stays the same. Output goes to art_source/frames/<set>/<name>.png on a
magenta key. Run unsandboxed from the project root:
  uv run --python 3.12 python tools/art/generate_frames.py slime [frame ...]
"""
import json
import os
import re
import subprocess
import sys

NAME = re.compile(r"^[a-z0-9_]+$")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CANONICAL = "assets/sprites/slime_idle.png"


def valid_name(name):
    return bool(NAME.match(name))


def build_prompt(style, frame):
    return ("$imagegen Generate one image (square): %s Style: %s Fill the whole background with flat "
            "solid magenta #FF00FF, nothing else: no shadow, no text, no border. Save the PNG into the "
            "current working directory as %s.png. Reply with the absolute path of the saved file only."
            % (frame["prompt"], style, frame["name"]))


def refs_for(frame, out_dir, root=ROOT):
    refs = [os.path.join(root, CANONICAL)]
    for r in frame.get("refs", []):
        refs.append(os.path.join(out_dir, r + ".png"))
    return refs


def command(out_dir, refs):
    cmd = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", out_dir,
           "-o", os.path.join(out_dir, ".last.txt")]
    for r in refs:
        cmd += ["-i", r]
    return cmd + ["-"]


def main():
    if len(sys.argv) < 2 or not valid_name(sys.argv[1]):
        raise SystemExit("usage: generate_frames.py <set> [frame ...]")
    rig_set = sys.argv[1]
    data = json.load(open(os.path.join(ROOT, "tools/art/%s_frames.json" % rig_set)))
    wanted = sys.argv[2:] or [f["name"] for f in data["frames"]]
    out_dir = os.path.join(ROOT, "art_source/frames", rig_set)
    os.makedirs(out_dir, exist_ok=True)
    by_name = {f["name"]: f for f in data["frames"]}
    for name in wanted:
        if name not in by_name or not valid_name(name):
            raise SystemExit("unknown frame: %r" % name)
        frame = by_name[name]
        refs = refs_for(frame, out_dir)
        missing = [r for r in refs if not os.path.exists(r)]
        if missing:
            raise SystemExit("%s needs %s generated first" % (name, missing))
        print("generating", name, flush=True)
        subprocess.run(command(out_dir, refs), input=build_prompt(data["style"], frame).encode(),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if not os.path.exists(os.path.join(out_dir, name + ".png")):
            raise SystemExit("codex did not produce %s.png" % name)
        print("wrote", os.path.join(out_dir, name + ".png"), flush=True)


if __name__ == "__main__":
    main()
