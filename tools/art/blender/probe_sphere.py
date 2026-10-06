"""Run inside Blender by test_pipeline.py: render the normal pass of a sphere and save it, so a test can read its colours."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import rigkit as k  # noqa: E402

out = sys.argv[sys.argv.index("--") + 1]
scene = k.reset()
ob = k.ellipsoid("s", (0, 0, 0.5), (0.4, 0.4, 0.4), 24, 16)
k.setup_camera(scene, 32, 32.0, 0, 4)
ob.data.materials.append(k.normal_material())
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
