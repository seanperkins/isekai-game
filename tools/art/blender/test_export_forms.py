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


class TimingTest(unittest.TestCase):
    CONSTANTS = {"windup": 0.35, "recover": 0.30, "hurt": 0.25, "run_speed": 1.9}

    def meta(self, attack, hurt=(0.25,)):
        return {"anims": {"attack": len(attack), "hurt": len(hurt)}, "durations": {"attack": list(attack), "hurt": list(hurt)}, "windup": 2}

    def test_it_reads_the_timings_from_the_enemy_so_the_art_cannot_drift(self):
        c = ex.engine_constants()
        self.assertEqual(set(c), {"windup", "recover", "hurt", "run_speed"})
        self.assertGreater(c["windup"], c["recover"])

    def test_the_art_the_biped_motion_makes_matches_the_engine(self):
        import biped_motion as gm
        c = ex.engine_constants()
        self.assertEqual((gm.ENGINE_WINDUP, gm.ENGINE_RECOVER, gm.ENGINE_HURT), (c["windup"], c["recover"], c["hurt"]))
        import quad_motion as qm
        self.assertEqual((qm.ENGINE_WINDUP, qm.ENGINE_RECOVER, qm.ENGINE_HURT), (c["windup"], c["recover"], c["hurt"]))

    def test_matching_timings_pass(self):
        ex.check_timing(self.meta([0.2, 0.15, 0.1, 0.2]), self.CONSTANTS)

    def test_a_windup_that_is_too_short_or_too_long_is_refused(self):
        for attack in ([0.2, 0.1, 0.1, 0.2], [0.2, 0.2, 0.1, 0.2]):
            with self.assertRaises(ValueError):
                ex.check_timing(self.meta(attack), self.CONSTANTS)

    def test_a_recovery_that_outlasts_the_engines_is_refused_one_that_is_shorter_is_fine(self):
        with self.assertRaises(ValueError):
            ex.check_timing(self.meta([0.2, 0.15, 0.2, 0.2]), self.CONSTANTS)
        ex.check_timing(self.meta([0.2, 0.15, 0.1, 0.1]), self.CONSTANTS)

    def test_a_flinch_of_the_wrong_length_is_refused(self):
        with self.assertRaises(ValueError):
            ex.check_timing(self.meta([0.2, 0.15, 0.1, 0.2], hurt=(0.4,)), self.CONSTANTS)


if __name__ == "__main__":
    unittest.main()
