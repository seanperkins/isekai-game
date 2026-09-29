"""Regenerate the `cues` section of data/audio/cues.json from the SFX recipes.

The `events` and `biomes` sections are authored by hand and kept as they are. Every file a cue
lists must already exist and read as Ogg Vorbis, or nothing is written and the exit code is 1.
Run from the project root:
  python3 tools/audio/build_cues.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402
import synth_sfx  # noqa: E402

CATALOG = "data/audio/cues.json"


def cues_from_recipes(recipes):
    cues = {}
    for name in sorted(recipes):
        recipe = recipes[name]
        rule = dict(recipe["cue"])
        rule["files"] = synth_sfx.variant_files(name, recipe)
        if recipe.get("loop"):
            rule["loop"] = True
        cues[name] = rule
    return cues


def build(catalog_path=CATALOG, recipes=None, root=synth_sfx.OUT):
    recipes = recipes if recipes is not None else synth_sfx.load_recipes()
    with open(catalog_path) as f:
        catalog = json.load(f)
    cues = cues_from_recipes(recipes)
    for rule in cues.values():
        for rel in rule["files"]:
            audiolib.validate_ogg(os.path.join(root, rel))
    body = {"cues": cues, "events": catalog.get("events", {}), "biomes": catalog.get("biomes", {})}
    tmp = catalog_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(body, f, indent=2)
        f.write("\n")
    os.replace(tmp, catalog_path)


def main(argv):
    try:
        build()
    except (audiolib.AudioToolError, OSError, ValueError) as e:
        print("error:", e, file=sys.stderr)
        return 1
    print("wrote", CATALOG)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
