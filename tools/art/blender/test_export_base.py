"""Cutting a render into a shipped creature's states (export_base.py): pure Python."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import export_base as eb  # noqa: E402

META = {"anims": {"idle": 4, "run": 3, "attack": 10, "hurt": 5, "die": 8, "walk": 6},
        "durations": {"idle": [0.15] * 4, "run": [0.05] * 3, "attack": [0.06] * 10, "hurt": [0.05] * 5, "die": [0.1] * 8, "walk": [0.1] * 6}}


class PlanTest(unittest.TestCase):
    def setUp(self):
        self.frames, self.table = eb.plan(eb.SPECS["gloom_wolf"], dict(META, anims=dict(META["anims"], rise=1)))

    def test_every_state_the_game_asks_of_the_wolf_has_a_clip_with_frames_that_exist(self):
        for state in ("idle", "walk", "windup", "charge", "rest", "stunned", "hurt", "downed"):
            self.assertIn(state, self.table)
        names = {new for new, _, _ in self.frames}
        for clip in self.table.values():
            self.assertTrue(set(clip["frames"]) <= names)

    def test_the_states_are_taken_from_the_right_render_frames(self):
        by = {new: src for new, src, _ in self.frames}
        self.assertEqual(by["windup_1"], "attack_2")
        self.assertEqual(by["downed_1"], "die_7", "the last frame of the death")
        self.assertEqual([by["charge_%d" % i] for i in (1, 2, 3)], ["run_0", "run_1", "run_2"])

    def test_loops_loop_and_a_single_frame_is_one_frame_at_one_fps(self):
        self.assertTrue(self.table["idle"]["loop"] and self.table["walk"]["loop"] and self.table["charge"]["loop"])
        self.assertFalse(self.table["hurt"]["loop"])
        self.assertEqual(self.table["hurt"], {"frames": ["hurt_1"], "fps": 1.0, "loop": False})

    def test_the_charge_frames_carry_the_attack_shape_the_wolf_bites_with(self):
        opts = {new: o for new, _, o in self.frames}
        self.assertEqual(opts["charge_1"], {"attack_from": 0.55})
        self.assertEqual(opts["idle_1"], {})

    def test_the_goblins_states_are_the_ones_the_player_asks_for(self):
        _, table = eb.plan(eb.SPECS["goblin"], dict(META, anims=dict(META["anims"], rise=1, fall=1, roll=4, slide=1, mantle=2, wall=1, land=1),
                                                   durations=dict(META["durations"], rise=[0.1], fall=[0.1], roll=[0.1] * 4, slide=[0.1], mantle=[0.1, 0.1], wall=[0.1], land=[0.1])))
        for state in ("idle", "run", "rise", "fall", "roll", "slide", "mantle", "wall"):
            self.assertIn(state, table)


class SpiderPlanTest(unittest.TestCase):
    META = {"anims": {"idle": 8, "walk": 12, "attack": 10, "hurt": 5, "die": 8},
            "durations": {"idle": [0.15] * 8, "walk": [0.1] * 12, "attack": [0.06] * 10, "hurt": [0.05] * 5, "die": [0.1] * 8}}

    def setUp(self):
        self.frames, self.table = eb.plan(eb.SPECS["spider"], self.META)

    def test_the_game_finds_every_frame_it_asks_the_sheet_for_by_name(self):
        names = {new for new, _, _ in self.frames}   # the sandbox draws crawl_1..4 and drop by frame name; the enemy plays the clips
        for name in ("hang_1", "hang_2", "drop", "crawl_1", "crawl_2", "crawl_3", "crawl_4", "stunned", "hurt", "downed"):
            self.assertIn(name, names)
        for state in ("hang", "drop", "crawl", "stunned", "hurt", "downed"):
            self.assertTrue(set(self.table[state]["frames"]) <= names)

    def test_crawl_is_four_even_frames_around_the_whole_walk_taking_as_long_as_it(self):
        by = {new: src for new, src, _ in self.frames}
        self.assertEqual([by["crawl_%d" % i] for i in (1, 2, 3, 4)], ["walk_0", "walk_3", "walk_6", "walk_9"])
        frames = self.table["crawl"]["frames"]
        self.assertAlmostEqual(len(frames) / self.table["crawl"]["fps"], 1.2, delta=0.04, msg="the walk's cycle")
        self.assertEqual({frames.count("crawl_%d" % i) for i in (1, 2, 3, 4)}, {len(frames) // 4})

    def test_what_names_a_frame_is_not_written_into_the_sheets_spec(self):
        for new, _, options in self.frames:
            self.assertNotIn("name", options, new)
            self.assertNotIn("even", options, new)


class SizingTest(unittest.TestCase):
    def test_a_base_creature_is_matched_by_the_dimension_the_game_reads_and_a_form_by_area(self):
        import sizing
        old = (54.0, 37.0)
        extent = (2.0, 1.0)
        self.assertAlmostEqual(extent[0] * sizing.pixels_per_unit(extent, old, "width"), 54.0)
        self.assertAlmostEqual(extent[1] * sizing.pixels_per_unit(extent, old, "height"), 37.0)
        ppu = sizing.pixels_per_unit(extent, old)
        self.assertAlmostEqual(extent[0] * ppu * extent[1] * ppu, 54.0 * 37.0)
        self.assertAlmostEqual(extent[0] * sizing.pixels_per_unit(extent, (50.0, None), "height"), 50.0, msg="with no still to match it is the width")


if __name__ == "__main__":
    unittest.main()
