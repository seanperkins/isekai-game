"""The glTF export for the review page's 3D view. Gated: it needs Blender (BLENDER, default /Applications/Blender.app)."""
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
SHOWN = {"idle", "walk", "run", "attack", "hurt", "die"}


def read_json(path):
    with open(path) as fh:
        return json.load(fh)


def read_glb(path):
    with open(path, "rb") as fh:
        data = fh.read()
    magic, version, length = struct.unpack("<4sII", data[:12])
    chunk_length, chunk_type = struct.unpack("<II", data[12:20])
    assert magic == b"glTF" and version == 2 and length == len(data), (magic, version, length, len(data))
    assert chunk_type == 0x4E4F534A   # "JSON"
    return json.loads(data[20:20 + chunk_length])


@unittest.skipUnless(os.path.exists(BLENDER), "needs Blender")
class ExportTest(unittest.TestCase):
    def test_the_base_goblin_exports_a_glb_with_every_clip(self):
        with tempfile.TemporaryDirectory() as tmp:
            done = subprocess.run([sys.executable, os.path.join(HERE, "export_gltf.py"), "goblin", "goblin", "--out", tmp], capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
            gltf = read_glb(os.path.join(tmp, "model.glb"))
            model = read_json(os.path.join(tmp, "model.json"))
            names = [a["name"] for a in gltf["animations"]]
            self.assertTrue(SHOWN <= set(names), names)
            self.assertEqual(sorted(names), sorted(model["clips"]))
            self.assertGreaterEqual(len(gltf["skins"]), 1)
            self.assertTrue(gltf["materials"])
            for material in gltf["materials"]:
                self.assertIn("baseColorFactor", material["pbrMetallicRoughness"])
            accessors = gltf["accessors"]
            engine = read_json(os.path.join(ROOT, "data", "enemy_clips.json"))["goblin"]   # what the game plays for the base goblin
            for animation in gltf["animations"]:
                end = max(accessors[s["input"]]["max"][0] for s in animation["samplers"])
                start = min(accessors[s["input"]]["min"][0] for s in animation["samplers"])
                self.assertAlmostEqual(start, 0.0, delta=0.001, msg=animation["name"] + " starts at 0")
                self.assertAlmostEqual(end, model["clips"][animation["name"]], delta=0.015, msg=animation["name"])
                if animation["name"] in engine and len(engine[animation["name"]]["frames"]) > 1:   # a one-frame clip is a held pose: it has no length of its own
                    self.assertAlmostEqual(end, len(engine[animation["name"]]["frames"]) / engine[animation["name"]]["fps"], delta=0.015, msg=animation["name"] + " against the game's clip")


@unittest.skipUnless(os.path.exists(BLENDER), "needs Blender")
class RefusalTest(unittest.TestCase):
    def test_a_rig_that_deforms_its_meshes_per_pose_is_refused_not_exported_without_its_animation(self):
        with tempfile.TemporaryDirectory() as tmp:
            done = subprocess.run([sys.executable, os.path.join(HERE, "export_gltf.py"), "slime", "slime", "--out", tmp], capture_output=True, text=True)
            self.assertNotEqual(done.returncode, 0, "a slime's jelly moves its vertices, which a glTF of bone animation cannot carry")
            self.assertIn("deforms its meshes", done.stdout + done.stderr)
            self.assertFalse(os.path.exists(os.path.join(tmp, "model.glb")))


class FrameTimesTest(unittest.TestCase):
    def test_frame_times_are_the_running_sum_with_a_one_tick_floor(self):
        sys.path.insert(0, HERE)
        import export_gltf
        starts, total = export_gltf.frame_times([0.1, 0.0, 0.25], True)
        self.assertEqual([round(s, 4) for s in starts], [0.0, 0.1, 0.12])
        self.assertAlmostEqual(total, 0.37, places=6)

    def test_srgb_to_linear_matches_the_standard_curve(self):
        sys.path.insert(0, HERE)
        import export_gltf
        self.assertAlmostEqual(export_gltf.srgb_to_linear(0.0), 0.0)
        self.assertAlmostEqual(export_gltf.srgb_to_linear(1.0), 1.0)
        self.assertAlmostEqual(export_gltf.srgb_to_linear(0.5), 0.21404, places=4)


if __name__ == "__main__":
    unittest.main()
