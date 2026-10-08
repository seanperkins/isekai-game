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


def read_accessor(path, index):
    """The values of accessor `index` of a .glb as a list of tuples (float components only)."""
    with open(path, "rb") as fh:
        data = fh.read()
    json_length, _ = struct.unpack("<II", data[12:20])
    gltf = json.loads(data[20:20 + json_length])
    start = 20 + json_length
    bin_length, _ = struct.unpack("<II", data[start:start + 8])
    blob = data[start + 8:start + 8 + bin_length]
    accessor = gltf["accessors"][index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return [struct.unpack_from("<%df" % width, blob, base + k * 4 * width) for k in range(accessor["count"])]


@unittest.skipUnless(os.path.exists(BLENDER), "needs Blender")
class HeldPoseTest(unittest.TestCase):
    def test_a_clip_that_holds_one_pose_is_that_pose_from_its_first_sample_to_its_last(self):
        """A landing, a fall, a wall cling are one pose held for a moment: the baked animation must not move the creature (it once bounced the hips 0.13 for a landing)."""
        with tempfile.TemporaryDirectory() as tmp:
            done = subprocess.run([sys.executable, os.path.join(HERE, "export_gltf.py"), "goblin", "goblin", "--out", tmp], capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
            path = os.path.join(tmp, "model.glb")
            gltf = read_glb(path)
            held = [a for a in gltf["animations"] if a["name"] in ("rise", "fall", "slide", "wall", "land")]
            self.assertEqual(len(held), 5)
            for animation in held:
                for channel in animation["channels"]:
                    values = read_accessor(path, animation["samplers"][channel["sampler"]]["output"])
                    spread = max(max(v[k] for v in values) - min(v[k] for v in values) for k in range(len(values[0])))
                    self.assertLess(spread, 1e-4, "%s: node %s %s moves by %.4f in a held pose" % (animation["name"], gltf["nodes"][channel["target"]["node"]].get("name"), channel["target"]["path"], spread))


@unittest.skipUnless(os.path.exists(BLENDER), "needs Blender")
class LoopTest(unittest.TestCase):
    def test_a_looping_clip_ends_where_it_begins_so_the_loop_closes_without_a_jump(self):
        """Every clip is baked from its own poses: a clip posed while the one before it was animating the rig began on that clip's pose instead (the walk began on the idle's)."""
        with tempfile.TemporaryDirectory() as tmp:
            done = subprocess.run([sys.executable, os.path.join(HERE, "export_gltf.py"), "goblin", "goblin", "--out", tmp], capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
            path = os.path.join(tmp, "model.glb")
            gltf = read_glb(path)
            looping = [a for a in gltf["animations"] if a["name"] in ("idle", "walk", "run")]
            self.assertEqual(len(looping), 3)
            for animation in looping:
                for channel in animation["channels"]:
                    values = read_accessor(path, animation["samplers"][channel["sampler"]]["output"])
                    jump = max(abs(a - b) for a, b in zip(values[0], values[-1]))
                    self.assertLess(jump, 1e-3, "%s: node %s %s starts and ends %.4f apart" % (animation["name"], gltf["nodes"][channel["target"]["node"]].get("name"), channel["target"]["path"], jump))


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
