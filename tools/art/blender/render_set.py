"""Blender entry point: render every animation of one creature to a colour pass and a normal pass per frame.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/art/blender/render_set.py -- --creature goblin --out DIR
        [--variant redcap] [--anims idle,walk] [--ss 4] [--save-blend FILE]

Writes DIR/<anim>_<n>_albedo.png, DIR/<anim>_<n>_normal.png and DIR/meta.json (canvas, pixels per unit, supersampling, frame counts).
tools/art/blender/spike.py runs this and then lights the passes with toon.py.
"""
import argparse
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import rigkit  # noqa: E402


def load(name):
    spec = importlib.util.spec_from_file_location("creature_" + name, os.path.join(HERE, "creatures", name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--creature", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--variant")
    ap.add_argument("--anims")
    ap.add_argument("--ss", type=int, default=4)
    ap.add_argument("--save-blend")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)

    scene = rigkit.reset()
    creature = load(a.creature)
    rig = creature.build(a.variant)
    if hasattr(creature, "setup"):  # a creature with many forms sizes its camera and animations per form
        cfg = creature.setup(rig, a.variant)
    else:
        cfg = {"canvas": creature.CANVAS, "ppu": creature.PPU, "margin": creature.MARGIN, "center_x": 0.0, "anims": creature.ANIMS}
    rigkit.setup_camera(scene, cfg["canvas"], cfg["ppu"], cfg["margin"], a.ss, cfg.get("center_x", 0.0))
    wanted = a.anims.split(",") if a.anims else list(cfg["anims"])
    materials = sorted({rigkit.shown_colour(rgb, far) for _, rgb, far in rig.parts})
    meta = {"creature": a.creature, "variant": a.variant or "", "canvas": cfg["canvas"], "ppu": cfg["ppu"], "margin": cfg["margin"], "ss": a.ss,
            "still": cfg.get("still", "idle_0"), "materials": materials, "anims": {}}
    for anim in wanted:
        count, fn, grounded = cfg["anims"][anim]
        for i in range(count):
            rot, root = fn(i, count)
            (rig.stand if grounded else rig.pose)(rot, root)
            rigkit.render_passes(scene, rig, os.path.join(a.out, "%s_%d" % (anim, i)))
        meta["anims"][anim] = count
    with open(os.path.join(a.out, "meta.json"), "w") as fh:
        json.dump(meta, fh)
    if a.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.save_blend)


main()
