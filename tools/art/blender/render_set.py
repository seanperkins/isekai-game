"""Blender entry point: render every animation of one creature to a colour pass and a normal pass per frame.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/art/blender/render_set.py -- --creature goblin --out DIR
        [--variant redcap] [--anims idle,walk] [--ss 4] [--save-blend FILE] [--empty-hands]

Writes DIR/<anim>_<n>_albedo.png, DIR/<anim>_<n>_normal.png and DIR/meta.json (canvas, pixels per unit, supersampling, frame counts).
tools/art/blender/spike.py runs this and then lights the passes with toon.py.

--empty-hands (a creature whose build takes `hold`: the goblins) sets the camera, the canvas and the clips from the armed rig, as always, and then renders
the frames from a second rig that leaves out what the hands carry. The game draws those things in a layer (scripts/ui/held_item_layer.gd), so meta.json
says "hold": false and gives, for each frame, where each hand is and how far it has turned: {"idle_0": {"n": [px, py, degrees], "f": [...]}}, in canvas
pixels (held.py has the maths).
"""
import argparse
import importlib.util
import inspect
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import held  # noqa: E402
import rigkit  # noqa: E402


def load(name):
    spec = importlib.util.spec_from_file_location("creature_" + name, os.path.join(HERE, "creatures", name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def hands_of(rig, cfg):
    """{"n": [px, py, degrees], "f": [...]}: where each item bone's head is in the render's canvas, and how far the bone has turned from its rest direction, in the current pose."""
    out = {}
    for side in "nf":
        bone = "item_" + side
        head, tail = rig.bone_world(bone)
        rest_head, rest_tail, _ = rig.rest[bone]
        px, py = held.project(cfg["canvas"], cfg["ppu"], cfg["margin"], cfg.get("center_x", 0.0), head.x, head.z)
        turn = held.bone_turn((rest_head.x, rest_head.z), (rest_tail.x, rest_tail.z), (head.x, head.z), (tail.x, tail.z))
        out[side] = [round(px, 2), round(py, 2), round(turn, 2)]
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--creature", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--variant")
    ap.add_argument("--anims")
    ap.add_argument("--ss", type=int, default=4)
    ap.add_argument("--save-blend")
    ap.add_argument("--empty-hands", action="store_true", help="render the frames without what the hands carry (the creature's build must take `hold`)")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)

    scene = rigkit.reset()
    creature = load(a.creature)
    if a.empty_hands and "hold" not in inspect.signature(creature.build).parameters:
        raise SystemExit("--empty-hands: %s holds nothing in a layer (its build takes no `hold`)" % a.creature)
    rig = creature.build(a.variant)
    if hasattr(creature, "setup"):  # a creature with many forms sizes its camera and animations per form
        cfg = creature.setup(rig, a.variant)
    else:
        cfg = {"canvas": creature.CANVAS, "ppu": creature.PPU, "margin": creature.MARGIN, "center_x": 0.0, "anims": creature.ANIMS}
    rigkit.setup_camera(scene, cfg["canvas"], cfg["ppu"], cfg["margin"], a.ss, cfg.get("center_x", 0.0))
    if a.empty_hands:   # the fit above is the armed form's; what is drawn is the body without what its hands carry, and nothing of the armed rig is left to be rendered
        rig.discard()
        rig = creature.build(a.variant, hold=False)
    wanted = a.anims.split(",") if a.anims else list(cfg["anims"])
    materials = sorted({rigkit.shown_colour(rgb, far) for _, rgb, far in rig.parts})
    meta = {"creature": a.creature, "variant": a.variant or "", "canvas": cfg["canvas"], "ppu": cfg["ppu"], "margin": cfg["margin"], "ss": a.ss,
            "still": cfg.get("still", "idle_0"), "fps": cfg.get("fps", {}), "holds": cfg.get("holds", {}), "materials": materials, "anims": {}}
    meta.update(cfg.get("extra", {}))  # what a creature says about its clips: each frame's duration, which loop, where the windup ends
    hands = {}
    if a.empty_hands:
        meta["hold"] = False
        meta["hands"] = hands
    for anim in wanted:
        count, fn, grounded = cfg["anims"][anim]
        for i in range(count):
            rot, root = fn(i, count)
            (rig.stand if grounded else rig.pose)(rot, root)
            if a.empty_hands:
                hands["%s_%d" % (anim, i)] = hands_of(rig, cfg)
            rigkit.render_passes(scene, rig, os.path.join(a.out, "%s_%d" % (anim, i)))
        meta["anims"][anim] = count
    with open(os.path.join(a.out, "meta.json"), "w") as fh:
        json.dump(meta, fh)
    if a.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.save_blend)


main()
