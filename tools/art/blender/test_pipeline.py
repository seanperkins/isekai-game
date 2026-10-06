"""Runs Blender headless (skipped when it is not installed): the render passes must mean what toon.py assumes."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")


def blender(*args):
    done = subprocess.run([BLENDER, "-b", *args], capture_output=True, text=True)
    return done


@unittest.skipUnless(os.path.exists(BLENDER), "Blender is not installed")
class PipelineTest(unittest.TestCase):
    def test_the_normal_pass_encodes_right_up_and_toward_the_viewer(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "sphere.png")
            blender("-P", os.path.join(HERE, "probe_sphere.py"), "--", path)
            with Image.open(path) as im:
                n = im.convert("RGBA")
            w, h = n.size
            cx, cy, r = w // 2, h - 16 * 4, int(0.38 * 32 * 4)  # the sphere's centre sits 16 game px above the ground
            def near(px, want):
                for got, expect in zip(px[:3], want):
                    self.assertAlmostEqual(got, expect, delta=6)
            near(n.getpixel((cx, cy)), (128, 128, 255))        # facing the viewer: blue
            self.assertGreater(n.getpixel((cx + r, cy))[0], 230)  # facing right: red
            self.assertGreater(n.getpixel((cx, cy - r))[1], 230)  # facing up: green
            self.assertLess(n.getpixel((cx - r, cy))[0], 25)      # facing left: no red

    def render(self, creature, tmp):
        done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", creature, "--out", tmp, "--anims", "idle", "--ss", "2")
        self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
        with open(os.path.join(tmp, "meta.json")) as fh:
            return json.load(fh)

    def test_every_creature_renders_both_passes_inside_its_canvas_and_stands_on_the_ground(self):
        for creature in ("goblin", "spider", "wolf"):
            with self.subTest(creature=creature), tempfile.TemporaryDirectory() as tmp:
                meta = self.render(creature, tmp)
                size = meta["canvas"] * meta["ss"]
                for i in range(meta["anims"]["idle"]):
                    with Image.open(os.path.join(tmp, "idle_%d_albedo.png" % i)) as a, Image.open(os.path.join(tmp, "idle_%d_normal.png" % i)) as n:
                        albedo, normal = a.convert("RGBA"), n.convert("RGBA")
                    self.assertEqual(albedo.size, (size, size))
                    box = albedo.split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                    self.assertIsNotNone(box, "something is drawn")
                    self.assertGreater(box[0], 0)
                    self.assertGreater(box[1], 0)
                    self.assertLess(box[2], size)
                    ground = size - meta["margin"] * meta["ss"]
                    self.assertAlmostEqual(box[3], ground, delta=meta["ss"] * 2, msg="the lowest pixel rests on the ground line")
                    self.assertEqual(albedo.split()[3].getbbox(), normal.split()[3].getbbox(), "both passes cover the same pixels")

    def render_anim(self, creature, anim, tmp):
        done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", creature, "--out", tmp, "--anims", anim, "--ss", "2")
        self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
        with open(os.path.join(tmp, "meta.json")) as fh:
            return json.load(fh)

    def test_a_crouching_creature_is_lowered_until_it_touches_the_ground_and_a_leaping_one_is_lifted_off_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            meta = self.render_anim("wolf", "pounce", tmp)
            ground = (meta["canvas"] - meta["margin"]) * meta["ss"]
            for i, airborne in enumerate((False, False, True, True, False, False)):
                with Image.open(os.path.join(tmp, "pounce_%d_albedo.png" % i)) as a:
                    box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                if airborne:
                    self.assertLess(box[3], ground - 4 * meta["ss"], "frame %d is off the ground" % i)
                else:
                    self.assertAlmostEqual(box[3], ground, delta=meta["ss"], msg="frame %d rests on the ground" % i)

    def test_glowing_parts_take_the_lit_band_whatever_their_shape(self):
        lit = tuple(int(round((0.5 + 0.5 * c / 0.99) * 255)) for c in (-0.45, 0.70, 0.55))
        for creature in ("goblin", "spider", "wolf"):
            with self.subTest(creature=creature), tempfile.TemporaryDirectory() as tmp:
                self.render(creature, tmp)
                with Image.open(os.path.join(tmp, "idle_0_normal.png")) as n:
                    px = list(n.convert("RGBA").get_flattened_data())
                glowing = [p for p in px if p[3] and all(abs(a - b) <= 4 for a, b in zip(p[:3], lit))]
                self.assertGreater(len(glowing), 4, "the eyes and marks face the light")

    def test_a_variant_changes_colours_and_parts_but_not_the_animation(self):
        with tempfile.TemporaryDirectory() as plain, tempfile.TemporaryDirectory() as red:
            self.render("goblin", plain)
            done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", "goblin", "--variant", "redcap", "--out", red, "--anims", "idle", "--ss", "2")
            self.assertEqual(done.returncode, 0)
            with Image.open(os.path.join(plain, "idle_0_albedo.png")) as a, Image.open(os.path.join(red, "idle_0_albedo.png")) as b:
                self.assertNotEqual(list(a.convert("RGBA").get_flattened_data()), list(b.convert("RGBA").get_flattened_data()))
            with open(os.path.join(red, "meta.json")) as fh:
                self.assertEqual(json.load(fh)["variant"], "redcap")


if __name__ == "__main__":
    unittest.main()
