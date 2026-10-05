"""Generate the opening's backdrop with Codex's built-in image tool, one image per piece.

Reads tools/art/opening_prompts.json. Raw images land in art_source/opening/<piece>_raw.png; an existing raw file is kept
unless --force. Codex needs network and its own state directory, so run this unsandboxed from the project root:
  python3 tools/art/opening_gen.py                # every missing piece
  python3 tools/art/opening_gen.py backdrop --force
"""
import json
import os
import re
import subprocess
import sys

CODEX = "/Users/sean/.local/bin/codex"  # the native binary; the cmux shim on PATH breaks
STYLE_REF = "art_source/sprites_tiles_d.png"
NAME = re.compile(r"^[a-z0-9_]+$")


def valid_name(name):
    """A piece name becomes part of file paths, so it is a plain identifier (no slashes or dots)."""
    return bool(NAME.match(name))


def valid_ref(ref):
    """A reference image is a path inside the project: relative, no parent steps."""
    return bool(ref) and not os.path.isabs(ref) and ".." not in ref.split("/")


def build_prompt(cfg, spec, out):
    return " ".join(["Use the built-in image generation tool. Make ONE image only.", spec["prompt"], cfg["style"], cfg["opaque"],
                     "Then copy the generated PNG to %s in the working directory and print that path." % out])


def generate(cfg, name, force):
    out = "art_source/opening/%s_raw.png" % name
    if os.path.exists(out) and not force:
        return "kept"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    os.makedirs(".tmp/opening-gen", exist_ok=True)
    spec = cfg["pieces"][name]
    bad = [r for r in spec.get("refs", []) if not valid_ref(r)]
    if bad:
        return "FAILED: reference outside the project: %s" % bad
    cmd = [CODEX, "-a", "never", "exec", "--sandbox", "workspace-write", "-C", os.getcwd(), "--json"]
    for ref in [STYLE_REF] + spec.get("refs", []):
        cmd += ["--image", ref]
    cmd += ["--", build_prompt(cfg, spec, out)]
    with open(".tmp/opening-gen/%s.jsonl" % name, "w") as log, open(".tmp/opening-gen/%s.err" % name, "w") as err:
        code = subprocess.run(cmd, stdout=log, stderr=err, stdin=subprocess.DEVNULL, timeout=900).returncode
    return "ok" if code == 0 and os.path.exists(out) else "FAILED exit=%d" % code


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    cfg = json.load(open("tools/art/opening_prompts.json"))
    names = args or list(cfg["pieces"])
    for name in names:
        if not valid_name(name) or name not in cfg["pieces"]:
            raise SystemExit("unknown piece: %r" % name)
    for name in names:
        print("%s: %s" % (name, generate(cfg, name, force)), flush=True)


if __name__ == "__main__":
    main()
