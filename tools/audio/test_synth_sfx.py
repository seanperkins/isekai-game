import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import synth_sfx as s  # noqa: E402

RECIPE = {"dur": 0.2, "variants": 3, "cue": {"bus": "SFX_Player"},
          "layers": [{"osc": "sine", "f0": 300, "f1": 200, "amp": 1.0, "env": [0.005, 0.1]}]}


class SynthSfxTest(unittest.TestCase):
    def test_variant_file_names_are_numbered_from_one(self):
        self.assertEqual(s.variant_files("x", RECIPE), ["sfx/x_1.ogg", "sfx/x_2.ogg", "sfx/x_3.ogg"])

    def test_variants_differ_and_each_repeats_exactly(self):
        one = s.render_variant("x", RECIPE, 1)
        self.assertEqual(one, s.render_variant("x", RECIPE, 1))
        self.assertNotEqual(one, s.render_variant("x", RECIPE, 2))

    def test_peak_is_normalised(self):
        out = s.render_variant("x", RECIPE, 1)
        self.assertAlmostEqual(a.lin_to_db(a.peak(out)), a.SFX_PEAK_DB, places=2)

    def test_a_loop_cue_wraps_without_a_click_and_keeps_its_length(self):
        rec = {"dur": 0.8, "loop": True, "cue": {"bus": "SFX_Player"},
               "layers": [{"noise": "pink", "lp": 500, "amp": 1.0, "env": [0.02, 600]}]}
        out = s.render_variant("l", rec, 1)
        self.assertLess(a.seam_ratio(out), 3.0)
        self.assertAlmostEqual(len(out) / a.RATE, 0.8, delta=0.01)

    def test_a_failed_write_leaves_no_files(self):
        def boom(samples, path):
            raise a.AudioToolError("boom")
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(a.AudioToolError):
                s.build_cue("x", RECIPE, d, boom)
            found = [f for _, _, fs in os.walk(d) for f in fs]
            self.assertEqual(found, [])

    def test_build_cue_writes_every_variant(self):
        with tempfile.TemporaryDirectory() as d:
            s.build_cue("x", RECIPE, d)
            for rel in s.variant_files("x", RECIPE):
                a.validate_ogg(os.path.join(d, rel))

    def test_the_real_recipes_are_well_formed(self):
        recipes = s.load_recipes()
        self.assertGreater(len(recipes), 45)
        for name, r in recipes.items():
            self.assertIn("bus", r.get("cue", {}), name)
            self.assertGreater(r["dur"], 0.0, name)
            self.assertTrue(r["layers"], name)
            for layer in r["layers"]:
                self.assertTrue("osc" in layer or "noise" in layer, name)
                self.assertEqual(len(layer["env"]), 2, name)
            if r.get("loop"):
                self.assertGreaterEqual(r["dur"], 0.5, name)


if __name__ == "__main__":
    unittest.main()
