"""Blender probe for test_pipeline.py: pose the goblin the way its clips do and write where every bone's head and tail really are, as JSON, so the
flat skeleton the motion code is tested on (skeleton2d.py) can be checked against the real armature.

    Blender -b -P probe_pose.py -- OUT.json [variant [creature]]
"""
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import rigkit  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
out, variant = argv[0], (argv[1] if len(argv) > 1 and argv[1] != "-" else None)
creature = argv[2] if len(argv) > 2 else "goblin"
spec = importlib.util.spec_from_file_location("creature_" + creature, os.path.join(HERE, "creatures", creature + ".py"))
goblin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(goblin)

rigkit.reset()
rig = goblin.build(variant)
clips, _ = goblin.clips_of(rig, variant)
result = []
for name, clip in clips.items():
    for i in (0, len(clip.frames) // 2, len(clip.frames) - 1):
        rot, root = clip.frames[i]
        rig.pose(rot, root)
        bones = {}
        for bone in rig.rest:
            pb = rig.obj.pose.bones[bone]
            h, t = rig.obj.matrix_world @ pb.head, rig.obj.matrix_world @ pb.tail
            bones[bone] = [[h.x, h.z], [t.x, t.z]]
        result.append({"clip": name, "frame": i, "rot": rot, "root": list(root), "bones": bones})
with open(out, "w") as fh:
    json.dump(result, fh)
