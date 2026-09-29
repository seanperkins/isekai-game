"""Render every SFX recipe to Ogg Vorbis.

Recipes live in art_source/audio/recipes/*.json: {cue_name: {"dur", "variants", "loop", "layers",
"cue": {playback rules}}}. Each variant is rendered from a fixed seed, so a rebuild is byte-stable
in content. Output: assets/audio/sfx/<cue>_<n>.ogg. Run from the project root:
  TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/synth_sfx.py [cue ...]
"""
import glob
import json
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402
import dsp  # noqa: E402

RECIPES = "art_source/audio/recipes"
OUT = "assets/audio"
LOOP_XFADE = 0.15


def load_recipes(directory=RECIPES):
    recipes = {}
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        with open(path) as f:
            for name, recipe in json.load(f).items():
                if name in recipes:
                    raise audiolib.AudioToolError("duplicate cue %s (in %s)" % (name, path))
                recipes[name] = recipe
    return recipes


def variant_files(name, recipe):
    return ["sfx/%s_%d.ogg" % (name, k) for k in range(1, int(recipe.get("variants", 1)) + 1)]


def render_variant(name, recipe, k):
    seed = zlib.crc32(name.encode()) * 31 + k
    loop = bool(recipe.get("loop"))
    samples = dsp.render(recipe, recipe["dur"] + (LOOP_XFADE if loop else 0.0), seed, fade_edges=not loop)
    if loop:
        samples = dsp.make_loop(samples, LOOP_XFADE)
    return audiolib.normalize_peak(samples, audiolib.SFX_PEAK_DB)


def build_cue(name, recipe, out_root=OUT, write=audiolib.write_ogg):
    for k, rel in enumerate(variant_files(name, recipe), start=1):
        write(render_variant(name, recipe, k), os.path.join(out_root, rel))


def main(argv):
    try:
        recipes = load_recipes()
        wanted = argv or sorted(recipes)
        unknown = [n for n in wanted if n not in recipes]
        if unknown:
            print("unknown cue(s): %s" % ", ".join(unknown), file=sys.stderr)
            return 2
        for name in wanted:
            build_cue(name, recipes[name])
            print("built", name)
    except audiolib.AudioToolError as e:
        print("error:", e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
