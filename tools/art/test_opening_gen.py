import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import opening_gen as g  # noqa: E402

CFG = {"style": "STYLE TEXT", "opaque": "FILLS THE FRAME", "pieces": {"backdrop": {"refs": [], "prompt": "A sunny street."}}}


class OpeningGenTest(unittest.TestCase):
    def test_a_piece_name_is_a_plain_identifier(self):
        for good in ("backdrop", "street_2"):
            self.assertTrue(g.valid_name(good), good)
        for bad in ("", "../../outside/target", "a/b", "a.b", "A", "x y"):
            self.assertFalse(g.valid_name(bad), bad)

    def test_a_reference_stays_inside_the_project(self):
        self.assertTrue(g.valid_ref("art_source/opening/other_raw.png"))
        for bad in ("", "/etc/passwd", "../outside.png", "art_source/../../outside.png"):
            self.assertFalse(g.valid_ref(bad), bad)

    def test_the_prompt_carries_the_piece_the_style_the_fill_rule_and_the_output(self):
        p = g.build_prompt(CFG, CFG["pieces"]["backdrop"], "art_source/opening/backdrop_raw.png")
        for part in ("A sunny street.", "STYLE TEXT", "FILLS THE FRAME", "art_source/opening/backdrop_raw.png"):
            self.assertIn(part, p)

    def test_a_piece_with_an_outside_reference_is_refused_before_codex_runs(self):
        cfg = {"style": "s", "opaque": "o", "pieces": {"backdrop": {"refs": ["../outside.png"], "prompt": "p"}}}
        old = os.getcwd()
        os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
        try:
            self.assertTrue(g.generate(cfg, "backdrop", True).startswith("FAILED: reference outside the project"))
        finally:
            os.chdir(old)


if __name__ == "__main__":
    unittest.main()
