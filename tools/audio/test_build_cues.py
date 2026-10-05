import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import build_cues  # noqa: E402
import synth_sfx  # noqa: E402

RECIPES = {
    "tone": {"dur": 0.2, "variants": 2, "cue": {"bus": "UI", "volume_db": -8},
             "layers": [{"osc": "sine", "f0": 440, "amp": 1.0, "env": [0.005, 0.1]}]},
    "hum": {"dur": 0.8, "loop": True, "cue": {"bus": "SFX_Player"},
            "layers": [{"noise": "pink", "lp": 500, "amp": 1.0, "env": [0.02, 600]}]},
}
AUTHORED = {"events": {"jumped": "tone", "mana_spent": None, "_why:mana_spent": "one per MP point"},
            "biomes": {"cave": {"reverb_wet": 0.15}}}


def write_catalog(path):
    with open(path, "w") as f:
        json.dump(dict(AUTHORED, cues={}), f)


class BuildCuesTest(unittest.TestCase):
    def test_cues_list_their_variant_files_and_mark_loops(self):
        cues = build_cues.cues_from_recipes(RECIPES)
        self.assertEqual(cues["tone"]["files"], ["sfx/tone_1.ogg", "sfx/tone_2.ogg"])
        self.assertEqual(cues["tone"]["bus"], "UI")
        self.assertNotIn("loop", cues["tone"])
        self.assertTrue(cues["hum"]["loop"])

    def test_build_keeps_the_authored_sections_and_fills_cues(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            path = os.path.join(d, "cues.json")
            write_catalog(path)
            build_cues.build(path, RECIPES, d)
            with open(path) as f:
                got = json.load(f)
            self.assertEqual(got["events"], AUTHORED["events"])
            self.assertEqual(got["biomes"], AUTHORED["biomes"])
            self.assertEqual(sorted(got["cues"]), ["hum", "tone"])

    def test_a_hand_authored_cue_with_no_recipe_survives_a_rebuild(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            path = os.path.join(d, "cues.json")
            hand = {"files": ["sfx/tone_1.ogg"], "bus": "UI", "volume_db": -4}
            with open(path, "w") as f:
                json.dump(dict(AUTHORED, cues={"stand_in": hand}), f)
            build_cues.build(path, RECIPES, d)
            with open(path) as f:
                got = json.load(f)
            self.assertEqual(got["cues"]["stand_in"], hand)
            self.assertEqual(sorted(got["cues"]), ["hum", "stand_in", "tone"])

    def test_the_themes_section_is_kept_as_authored(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            path = os.path.join(d, "cues.json")
            themes = {"battle": {"music": "music/battle.ogg", "fade_in": 0.5, "fade_out": 1.5}}
            with open(path, "w") as f:
                json.dump(dict(AUTHORED, cues={}, themes=themes), f)
            build_cues.build(path, RECIPES, d)
            with open(path) as f:
                got = json.load(f)
            self.assertEqual(got["themes"], themes)

    def test_a_stale_cue_whose_files_are_gone_is_dropped(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            path = os.path.join(d, "cues.json")
            with open(path, "w") as f:
                json.dump(dict(AUTHORED, cues={"old": {"files": ["sfx/old_1.ogg"], "bus": "UI"}}), f)
            build_cues.build(path, RECIPES, d)
            with open(path) as f:
                got = json.load(f)
            self.assertNotIn("old", got["cues"])

    def test_a_recipe_wins_over_a_hand_authored_cue_of_the_same_name(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            path = os.path.join(d, "cues.json")
            with open(path, "w") as f:
                json.dump(dict(AUTHORED, cues={"tone": {"files": ["sfx/tone_1.ogg"], "bus": "Music", "volume_db": -30}}), f)
            build_cues.build(path, RECIPES, d)
            with open(path) as f:
                got = json.load(f)
            self.assertEqual(got["cues"]["tone"]["bus"], "UI")

    def test_a_missing_file_fails_and_leaves_the_catalog_unchanged(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "cues.json")
            write_catalog(path)
            before = open(path, "rb").read()
            with self.assertRaises(a.AudioToolError):
                build_cues.build(path, RECIPES, d)
            self.assertEqual(open(path, "rb").read(), before)

    def test_a_corrupt_file_fails(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            with open(os.path.join(d, "sfx", "tone_2.ogg"), "wb") as f:
                f.write(b"junk")
            path = os.path.join(d, "cues.json")
            write_catalog(path)
            with self.assertRaises(a.AudioToolError):
                build_cues.build(path, RECIPES, d)


if __name__ == "__main__":
    unittest.main()
