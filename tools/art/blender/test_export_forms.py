"""Turning a render's meta into the engine's clips (export_forms.py): pure Python."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import export_forms as ex  # noqa: E402

META = {
    "anims": {"idle": 2, "walk": 3, "attack": 4, "hurt": 2, "die": 3},
    "durations": {"idle": [0.2, 0.2], "walk": [0.1, 0.1, 0.1], "attack": [0.06, 0.12, 0.04, 0.1], "hurt": [0.04, 0.08], "die": [0.06, 0.1, 0.3]},
    "loops": {"idle": True, "walk": True, "attack": False, "hurt": False, "die": False},
    "windup": 2,
}


class ClipsOfTest(unittest.TestCase):
    def setUp(self):
        self.c = ex.clips_of(META)

    def test_the_loops_and_the_one_shots_are_what_the_render_said(self):
        self.assertTrue(self.c["idle"]["loop"] and self.c["walk"]["loop"])
        self.assertFalse(self.c["hurt"]["loop"])

    def test_an_attack_is_split_at_the_windup_into_the_two_clips_the_verb_states_play(self):
        self.assertEqual(self.c["windup"]["frames"][0], "attack_0")
        self.assertEqual(set(self.c["windup"]["frames"]), {"attack_0", "attack_1"})
        self.assertEqual(set(self.c["recover"]["frames"]), {"attack_2", "attack_3"})
        self.assertFalse(self.c["windup"]["loop"] or self.c["recover"]["loop"])
        self.assertEqual(len(self.c["windup"]["frames"]) + len(self.c["recover"]["frames"]), len(self.c["attack"]["frames"]))

    def test_a_held_frame_is_repeated_so_the_uneven_timing_survives(self):
        frames = self.c["windup"]["frames"]
        self.assertGreater(frames.count("attack_1"), frames.count("attack_0"))

    def test_a_death_ends_on_its_last_frame_as_the_downed_pose(self):
        self.assertEqual(self.c["downed"]["frames"], ["die_2"])
        self.assertEqual(self.c["die"]["frames"][-1], "die_2")

    def test_an_animation_a_form_lacks_gets_no_clip(self):
        c = ex.clips_of({"anims": {"idle": 2}, "durations": {"idle": [0.2, 0.2]}, "loops": {"idle": True}})
        self.assertEqual(set(c), {"idle"})

    def test_the_spec_names_every_frame_native_and_shares_one_box(self):
        spec = ex.spec_of("anim_x", ["idle_0", "idle_1"])
        self.assertTrue(spec["common_box"])
        self.assertTrue(all(f["native"] for f in spec["frames"]))


if __name__ == "__main__":
    unittest.main()
