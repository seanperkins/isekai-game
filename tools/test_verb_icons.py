"""Checks for tools/art/verb_icons.py. Run from anywhere:  python3 -m unittest tools/test_verb_icons.py (needs Pillow)"""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "art"))
import build_form_verbs as bfv  # noqa: E402
import verb_icons as vi  # noqa: E402


class IconsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_every_kind_in_the_table_has_a_glyph(self):
        for r in bfv.load_rows():
            self.assertIn(r["spec"]["kind"], vi.GLYPHS, r["form"])

    def test_an_icon_is_32_square_and_drawn(self):
        for kind in vi.GLYPHS:
            img = vi.icon(kind, (200, 120, 255))
            self.assertEqual(img.size, (32, 32))
            lit = [p for p in img.getdata() if p[3] and p[:3] != vi.BACK[:3]]
            self.assertGreater(len(lit), 30, kind)

    def test_build_writes_one_png_per_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            names = vi.build(out_dir=tmp)
            self.assertEqual(sorted(f[:-4] for f in os.listdir(tmp)), sorted(names))



class KindsTest(unittest.TestCase):
    def test_every_kind_the_framework_has_a_glyph(self):
        import re
        text = open(os.path.join(os.path.dirname(HERE), "scripts/abilities/verb_kinds.gd"), encoding="utf-8").read()
        kinds = re.search(r"const KINDS := \[(.*?)\]", text, re.S).group(1)
        for kind in re.findall(r'"(\w+)"', kinds):
            self.assertIn(kind, vi.GLYPHS, kind)


if __name__ == "__main__":
    unittest.main()
