"""Blender probe for test_pipeline.py: the slime's soft body in the real rig, so the pure deformation the motion is tested on (slime_motion.py)
can be checked against what Blender draws.

    Blender -b -P probe_slime.py -- OUT.json FORM      pose each clip at its first, middle and last frame and write, per frame, the soft
                                                      parameters, the root, where the jelly's vertices really are (and its rest vertices),
                                                      and where every bone's head and tail really are
    Blender -b -P probe_slime.py -- OUT.json --hook    a bare rig with and without a post_pose hook: what the hook saw and did
"""
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import rigkit  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]


def evaluated(ob):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(deps)
    return [list(ev.matrix_world @ v.co) for v in ev.data.vertices]


def bones(rig):
    res = {}
    for name in rig.rest:
        pb = rig.obj.pose.bones[name]
        h, t = rig.obj.matrix_world @ pb.head, rig.obj.matrix_world @ pb.tail
        res[name] = [[h.x, h.z], [t.x, t.z]]
    return res


if argv[1] == "--hook":
    rigkit.reset()
    rig = rigkit.Rig("hooked")
    rig.bone("root", (0, 0, 0), (0, 0, 1))
    rig.bone("arm", (0, 0, 1), (1, 0, 1), "root")
    ob = rigkit.box("box", (0.5, 0, 1), (0.2, 0.2, 0.2))
    rig.part(ob, "arm", (200, 100, 50))
    rig.build()
    rig.pose({"arm": (0, -30, 0)}, (0.5, 0, 0))
    plain = {"bones": bones(rig), "verts": evaluated(ob)}
    seen = []

    def hook(r, rot, root):
        seen.append({"rot": {k: list(v) for k, v in rot.items()}, "root": list(root), "same_rig": r is rig})
        ob.data.vertices[0].co = ob.data.vertices[0].co + Vector((0.0, 0.0, 0.25))
        ob.data.update()
        bpy.context.view_layer.update()
    rig.post_pose = hook
    rig.pose({"arm": (0, -30, 0)}, (0.5, 0, 0))
    hooked = {"bones": bones(rig), "verts": evaluated(ob)}
    with open(out, "w") as fh:
        json.dump({"plain": plain, "hooked": hooked, "seen": seen}, fh)
    sys.exit(0)

form = argv[1]
spec = importlib.util.spec_from_file_location("creature_slime", os.path.join(HERE, "creatures", "slime.py"))
slime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(slime)
rigkit.reset()
variant = None if form == "slime" else form
rig = slime.build(variant)
clips, _ = slime.clips_of(rig, variant)
jelly = next(ob for ob, _, _ in rig.parts if ob.name == "jelly")
kit = rig.slime_kit
rest = next(p["rest"] for p in kit.soft_parts if p["ob"] is jelly)
result = {"rest": [list(v) for v in rest], "frames": []}
for name, clip in clips.items():
    for i in sorted({0, len(clip.frames) // 2, len(clip.frames) - 1}):
        rot, root = clip.frames[i]
        rig.pose(rot, root)
        result["frames"].append({"clip": name, "frame": i, "rot": rot, "root": list(root), "jelly": evaluated(jelly), "bones": bones(rig)})
with open(out, "w") as fh:
    json.dump(result, fh)
