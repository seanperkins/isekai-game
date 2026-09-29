"""Generate terrain art pieces one image at a time with Codex's built-in image tool.

Reads tools/art/terrain_prompts.json. Raw images land in art_source/terrain/<biome>/<piece>_raw.png.
Existing raw files are kept unless --force. Runs a few Codex processes in parallel.
Run from the project root:
  python3 tools/art/terrain_gen.py cave                 # every missing piece
  python3 tools/art/terrain_gen.py cave cap_top ledge   # just these
Codex needs network and its own state directory, so this cannot run inside the Claude sandbox.
"""
import concurrent.futures
import json
import os
import subprocess
import sys

CODEX = "/Users/sean/.local/bin/codex"  # the native binary; the cmux shim on PATH breaks
STYLE_REF = "art_source/sprites_tiles_d.png"
WORKERS = 4


def build_prompt(cfg, biome, spec, out):
    parts = ["Use the built-in image generation tool. Make ONE image only.", spec["prompt"], cfg["style"],
             cfg["biomes"][biome]["palette"], cfg["rules"], cfg[spec["bg"]],
             f"Then copy the generated PNG to {out} in the working directory and print that path."]
    return " ".join(parts)


def generate(cfg, biome, name, force):
    spec = cfg["biomes"][biome]["pieces"][name]
    out = f"art_source/terrain/{biome}/{name}_raw.png"
    if os.path.exists(out) and not force:
        return name, "kept"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    os.makedirs(".tmp/terrain-gen", exist_ok=True)
    cmd = [CODEX, "-a", "never", "exec", "--sandbox", "workspace-write", "-C", os.getcwd(), "--json"]
    for ref in [STYLE_REF] + spec.get("refs", []):
        cmd += ["--image", ref]
    cmd += ["--", build_prompt(cfg, biome, spec, out)]
    with open(f".tmp/terrain-gen/{biome}_{name}.jsonl", "w") as log, \
            open(f".tmp/terrain-gen/{biome}_{name}.err", "w") as err:
        code = subprocess.run(cmd, stdout=log, stderr=err, stdin=subprocess.DEVNULL, timeout=900).returncode
    return name, ("ok" if code == 0 and os.path.exists(out) else f"FAILED exit={code}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    cfg = json.load(open("tools/art/terrain_prompts.json"))
    biome = args[0]
    names = args[1:] or list(cfg["biomes"][biome]["pieces"])
    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        for name, status in pool.map(lambda n: generate(cfg, biome, n, force), names):
            print(f"{biome}/{name}: {status}", flush=True)


if __name__ == "__main__":
    main()
