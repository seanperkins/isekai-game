"""Rendering a goblin empty-handed (render_set.py --empty-hands): the same fit as the armed render, no weapon in the picture, and where each hand is.
Needs Blender; a skipped run proves nothing."""
import json
import os
import shutil
import subprocess
import sys
import unittest

from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
SKIN = (104, 124, 66)   # goblin_kit.SKIN: the near hand is a skin-coloured mesh at the item bone's head
SS = 2


@unittest.skipUnless(os.path.exists(BLENDER), "Blender is not installed")
class EmptyHandsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base = os.path.join(ROOT, ".tmp", "held-render-tests")
        os.makedirs(base, exist_ok=True)
        cls.dir = os.path.join(base, "run-%d" % os.getpid())
        os.makedirs(cls.dir)
        cls.cache = {}

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir, ignore_errors=True)

    def render(self, creature, variant, anims, empty, extra=()):
        """The render folder (render_set.py's output) and the process, rendered once per request."""
        key = (creature, variant, anims, empty)
        if key not in self.cache:
            out = os.path.join(self.dir, "%s_%s_%s_%s" % (creature, variant or "base", anims, "empty" if empty else "armed"))
            cmd = [BLENDER, "-b", "--factory-startup", "-P", os.path.join(HERE, "render_set.py"), "--", "--creature", creature, "--out", out, "--anims", anims, "--ss", str(SS)]
            if variant:
                cmd += ["--variant", variant]
            if empty:
                cmd.append("--empty-hands")
            done = subprocess.run(cmd + list(extra), capture_output=True, text=True)
            self.cache[key] = (out, done)
        return self.cache[key]

    def meta(self, *args):
        out, done = self.render(*args)
        self.assertTrue(os.path.exists(os.path.join(out, "meta.json")), (done.stdout + done.stderr)[-1500:])
        self.assertNotIn("Traceback", done.stdout + done.stderr)
        with open(os.path.join(out, "meta.json")) as fh:
            return json.load(fh)

    def alpha(self, args, frame):
        out, _ = self.render(*args)
        with Image.open(os.path.join(out, frame + "_albedo.png")) as im:
            return im.convert("RGBA").split()[3]

    def test_an_empty_render_has_the_armed_renders_canvas_and_ppu_and_says_hold_false(self):
        armed, empty = self.meta("goblin", "smith", "idle", False), self.meta("goblin", "smith", "idle", True)
        for key in ("canvas", "ppu", "margin", "ss", "anims"):
            self.assertEqual(armed[key], empty[key], key)
        self.assertIs(empty["hold"], False)
        self.assertNotIn("hold", armed)
        self.assertNotIn("hands", armed)

    def test_the_empty_alpha_is_a_strict_subset_of_the_armed_alpha_for_the_smith_and_the_giant_killer(self):
        for form in ("smith", "giant_killer"):
            self.meta("goblin", form, "idle", False), self.meta("goblin", form, "idle", True)
            armed, empty = self.alpha(("goblin", form, "idle", False), "idle_0"), self.alpha(("goblin", form, "idle", True), "idle_0")
            self.assertIsNone(ImageChops.subtract(empty, armed).getbbox(), "%s: the empty body draws only what the armed one does" % form)
            self.assertIsNotNone(ImageChops.subtract(armed, empty).getbbox(), "%s: the weapon is gone (a leftover armed rig would leave none missing)" % form)

    def test_hands_land_on_the_skin_of_the_hand(self):
        for form, anim, frame in ((None, "idle", "idle_0"), ("smith", "attack", "attack_2")):
            meta = self.meta("goblin", form, anim, True)
            out, _ = self.render("goblin", form, anim, True)
            with Image.open(os.path.join(out, frame + "_albedo.png")) as im:
                albedo = im.convert("RGBA")
            px, py, _ = meta["hands"][frame]["n"]
            cx, cy = int(round(px * SS)), int(round(py * SS))
            near = [albedo.getpixel((x, y)) for x in range(cx - 1, cx + 2) for y in range(cy - 1, cy + 2)]
            self.assertTrue(any(p[3] == 255 and all(abs(p[i] - SKIN[i]) <= 6 for i in range(3)) for p in near), "%s %s: no skin at the near hand (%.1f, %.1f): %s" % (form, frame, px, py, near))

    def test_a_rider_form_has_hands_for_every_frame(self):
        meta = self.meta("goblin", "wolf_lord", "idle", True)
        self.assertEqual(sorted(meta["hands"]), ["idle_%d" % i for i in range(meta["anims"]["idle"])])
        for frame, hands in meta["hands"].items():
            for side in "nf":
                px, py, a = hands[side]
                self.assertTrue(0 < px < meta["canvas"] and 0 < py < meta["canvas"], (frame, side, px, py))
                self.assertTrue(-180 < a <= 180, (frame, side, a))

    def test_empty_hands_on_a_creature_without_hold_is_an_error(self):
        out, done = self.render("wolf", "warg", "idle", True)
        self.assertFalse(os.path.exists(os.path.join(out, "meta.json")))
        self.assertIn("hold", done.stdout + done.stderr)

    def test_the_paladins_mace_is_on_the_far_arm_and_his_shield_on_the_near(self):
        done = subprocess.run([BLENDER, "-b", "--factory-startup", "-P", os.path.join(HERE, "probe_hands.py"), "--", "paladin"], capture_output=True, text=True)
        lines = [line for line in done.stdout.splitlines() if line.startswith("HANDS ")]
        self.assertTrue(lines, (done.stdout + done.stderr)[-1500:])
        owners = json.loads(lines[-1][6:])
        self.assertEqual({owners[n] for n in ("handle", "knob")}, {"item_f"}, "the mace")
        self.assertEqual({owners[n] for n in ("shield", "sunburst")}, {"item_n"}, "the shield")

    def test_an_empty_dying_frame_is_inside_the_canvas_and_never_below_the_ground(self):
        for form in ("giant_killer", "smith"):
            meta = self.meta("goblin", form, "die", True)
            size = meta["canvas"] * SS
            ground = (meta["canvas"] - meta["margin"]) * SS
            for i in range(meta["anims"]["die"]):
                box = self.alpha(("goblin", form, "die", True), "die_%d" % i).getbbox()
                self.assertIsNotNone(box)
                self.assertLessEqual(box[3], ground + SS, "%s die_%d dips below the ground" % (form, i))
                self.assertTrue(box[0] > 0 and box[1] > 0 and box[2] < size and box[3] < size, "%s die_%d touches the canvas edge: %s" % (form, i, box))


if __name__ == "__main__":
    unittest.main()
