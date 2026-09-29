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


def refs_for(frame, out_dir, root=ROOT, canonical=CANONICAL):
    refs = [os.path.join(root, canonical)]
    for r in frame.get("refs", []):
        refs.append(os.path.join(out_dir, r + ".png"))
    return refs


def command(out_dir, refs):
    cmd = ["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", out_dir,
           "-o", os.path.join(out_dir, ".last.txt")]
    for r in refs:
        cmd += ["-i", r]
    return cmd + ["-"]


def todo(wanted, existing, explicit):
    """Frames to generate. With no explicit list, resume: skip frames that already have a PNG."""
    return list(wanted) if explicit else [n for n in wanted if n not in existing]


def main():
    if len(sys.argv) < 2 or not valid_name(sys.argv[1]):
        raise SystemExit("usage: generate_frames.py <set> [frame ...]")
    rig_set = sys.argv[1]
    data = json.load(open(os.path.join(ROOT, "tools/art/%s_frames.json" % rig_set)))
    out_dir = os.path.join(ROOT, "art_source/frames", rig_set)
    os.makedirs(out_dir, exist_ok=True)
    by_name = {f["name"]: f for f in data["frames"]}
    explicit = len(sys.argv) > 2
    wanted = sys.argv[2:] or [f["name"] for f in data["frames"]]
    for name in wanted:
        if name not in by_name or not valid_name(name):
            raise SystemExit("unknown frame: %r" % name)
    existing = {n for n in by_name if os.path.exists(os.path.join(out_dir, n + ".png"))}
    failed = []
    for name in todo(wanted, existing, explicit):
        frame = by_name[name]
        refs = refs_for(frame, out_dir, ROOT, data.get("canonical", CANONICAL))
        missing = [r for r in refs if not os.path.exists(r)]
        if missing:
            print("skipping %s: needs %s first" % (name, missing), flush=True)
            failed.append(name)
            continue
        target = os.path.join(out_dir, name + ".png")
        for attempt in (1, 2):
            if os.path.exists(target):
                os.remove(target)  # a stale file must not pass for a fresh one
            print("generating", name, "(attempt %d)" % attempt, flush=True)
            subprocess.run(command(out_dir, refs), input=build_prompt(data["style"], frame).encode(),
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            if os.path.exists(target):
                print("wrote", target, flush=True)
                break
        else:
            print("FAILED", name, flush=True)
            failed.append(name)
    if failed:
        raise SystemExit("failed: " + " ".join(failed))


if __name__ == "__main__":
    main()
