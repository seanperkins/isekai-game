"""The held pieces rendered as sprites of their own (held_items.py): the sheet set the game loads, the grip, and the art. Needs Blender."""
import json
import os
import shutil
import sys
import unittest

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import goblin_forms as forms  # noqa: E402
import held  # noqa: E402

BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
LANTERN_BODY, LANTERN_BODY_FAR = (255, 214, 110), (204, 171, 88)   # the lantern's flat colour, and what a far-hand piece would be shaded to


@unittest.skipUnless(os.path.exists(BLENDER), "Blender is not installed")
class ItemSheetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import held_items
        base = os.path.join(ROOT, ".tmp", "held-items-tests")
        os.makedirs(base, exist_ok=True)
        cls.dir = os.path.join(base, "run-%d" % os.getpid())
        cls.cyan = held.held_of(forms.FORMS["puck"]["gear"])["n"]
        cls.sword = "sword_big"   # no form holds it with default options: a catalogue-only item
        cls.ids = ["axe", "lantern", cls.cyan, "club", cls.sword]
        cls.entries = held_items.build_items(cls.ids, cls.dir, os.path.join(cls.dir, "sheets"))
        cls.sheets = os.path.join(cls.dir, "sheets")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir, ignore_errors=True)

    def sheet(self, item):
        with open(os.path.join(self.sheets, "held_%s.json" % item)) as fh:
            return json.load(fh)

    def image(self, item, normal=False):
        with Image.open(os.path.join(self.sheets, "held_%s%s.png" % (item, "_n" if normal else ""))) as im:
            return im.convert("RGBA")

    def test_a_catalogue_only_default_renders(self):
        for item in ("club", self.sword):
            self.assertIn(item, held.all_items())
            self.assertTrue(os.path.exists(os.path.join(self.sheets, "held_%s.png" % item)), item)
            self.assertEqual(self.entries[item]["set"], "held_" + item)
            self.assertIsNotNone(self.image(item).split()[3].getbbox(), "%s drew nothing" % item)

    def test_an_item_sheet_has_the_json_SpriteSheet_loads(self):
        for item in self.ids:
            data = self.sheet(item)
            self.assertEqual(data["image"], "held_%s.png" % item)
            self.assertEqual(data["normal"], "held_%s_n.png" % item)
            frame = data["frames"]["item"]
            w, h = self.image(item).size
            self.assertEqual(frame["rect"], [0, 0, w, h])
            self.assertEqual((frame["hurt"], frame["attack"]), ([], []))
            self.assertEqual(self.image(item, normal=True).size, (w, h))

    def test_the_grip_is_beside_the_item_and_a_hand_does_not_change_the_item(self):
        self.assertEqual(held.item_id("lantern", {"side": "f"}), held.item_id("lantern", {"side": "n"}))
        for item in self.ids:
            w, h = self.image(item).size
            gx, gy = self.entries[item]["grip"]
            self.assertTrue(-w / 2 - 8 <= gx <= w / 2 + 8 and -h - 8 <= gy <= 8, "%s: grip %s is nowhere near its %dx%d picture" % (item, (gx, gy), w, h))
            self.assertEqual(self.entries[item]["ppu"], held.ITEM_PPU)
        # a piece made for the far hand is rendered as the near hand's: its flat colour is not dimmed (the layer dims it, once)
        with Image.open(os.path.join(self.dir, "lantern", "raw", "item_0_albedo.png")) as raw:
            colours = {px[:3] for _, px in raw.convert("RGBA").getcolors(maxcolors=1 << 20) if px[3] == 255}
        self.assertTrue(any(all(abs(c[i] - LANTERN_BODY[i]) <= 4 for i in range(3)) for c in colours))
        self.assertFalse(any(all(abs(c[i] - LANTERN_BODY_FAR[i]) <= 4 for i in range(3)) for c in colours))

    def test_the_puck_s_cyan_lantern_is_another_item_with_other_pixels(self):
        self.assertNotEqual(self.cyan, "lantern")
        self.assertNotEqual(self.image("lantern").tobytes(), self.image(self.cyan).tobytes())

    def test_the_axe_has_pixels_above_and_beside_the_grip(self):
        w, h = self.image("axe").size
        gx, gy = self.entries["axe"]["grip"]
        col, row = w / 2 + gx, h + gy   # the grip in the picture's own pixels
        solid = [(x, y) for x in range(w) for y in range(h) if self.image("axe").getpixel((x, y))[3] == 255]
        self.assertTrue(any(y < row - 10 for _, y in solid), "the haft goes up from the hand")
        self.assertTrue(any(x > col + 5 for x, _ in solid), "the head is in front of the hand")


if __name__ == "__main__":
    unittest.main()
