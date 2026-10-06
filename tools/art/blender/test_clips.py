"""Turning timed frames into the engine's clips (clips.py): pure Python. The engine's SlimeAnimator plays {"frames": [...], "fps": f, "loop": b}
at one fps, so a held frame is a repeated name and the base fps is the length of the shortest frame."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clips  # noqa: E402


class ClipTest(unittest.TestCase):
    def test_a_walk_of_equal_frames_plays_each_once_at_one_over_the_frame_length(self):
        c = clips.clip(["w0", "w1", "w2", "w3"], [0.05] * 4, loop=True)
        self.assertEqual(c["frames"], ["w0", "w1", "w2", "w3"])
        self.assertAlmostEqual(c["fps"], 20.0, places=6)
        self.assertTrue(c["loop"])

    def test_a_held_frame_is_a_repeated_name(self):
        c = clips.clip(["a0", "a1", "a2", "a3"], [0.07, 0.14, 0.21, 0.07], loop=False)
        self.assertEqual(c["frames"], ["a0", "a1", "a1", "a2", "a2", "a2", "a3"])
        self.assertAlmostEqual(c["fps"], 1 / 0.07, places=6)
        self.assertFalse(c["loop"])

    def test_the_total_time_is_preserved(self):
        durations = [0.07, 0.14, 0.21, 0.07]
        c = clips.clip(["a0", "a1", "a2", "a3"], durations, loop=False)
        self.assertAlmostEqual(len(c["frames"]) / c["fps"], sum(durations), places=6)

    def test_timing_that_cannot_be_played_at_one_rate_is_refused(self):
        with self.assertRaises(ValueError):
            clips.clip(["a", "b", "c"], [0.05, 0.073, 0.05], loop=False)

    def test_a_single_still_frame_is_a_clip_of_one(self):
        c = clips.clip(["hurt"], [0.2], loop=False)
        self.assertEqual(c["frames"], ["hurt"])

    def test_names_and_durations_must_agree(self):
        with self.assertRaises(ValueError):
            clips.clip(["a", "b"], [0.05], loop=True)


class TableTest(unittest.TestCase):
    def test_a_table_orders_the_clips_and_keys_them_by_creature(self):
        table = clips.table("twin_goblin_hob", {"walk": clips.clip(["w0", "w1"], [0.05, 0.05], True), "idle": clips.clip(["i0"], [0.2], True)})
        self.assertEqual(list(table), ["twin_goblin_hob"])
        self.assertEqual(sorted(table["twin_goblin_hob"]), ["idle", "walk"])


class OnGridTest(unittest.TestCase):
    def test_each_frame_is_held_for_its_duration_rounded_to_the_tick(self):
        c = clips.on_grid(["a", "b", "c"], [0.06, 0.03, 0.12], False, 0.03)
        self.assertEqual(c["frames"], ["a", "a", "b", "c", "c", "c", "c"])
        self.assertAlmostEqual(c["fps"], 1.0 / 0.03, places=3)
        self.assertFalse(c["loop"])

    def test_a_frame_shorter_than_a_tick_still_shows_for_one(self):
        self.assertEqual(clips.on_grid(["a", "b"], [0.001, 0.06], True, 0.02)["frames"], ["a", "b", "b"], "a one-tick minimum for a, and b makes up the rest of the three ticks the clip should have")

    def test_the_errors_do_not_add_up_a_clip_is_as_long_as_asked_to_within_half_a_tick_however_many_frames(self):
        durations = [0.07, 0.13, 0.05, 0.09] * 5
        c = clips.on_grid(list("abcd") * 5, durations, True, 0.02)
        self.assertAlmostEqual(len(c["frames"]) / c["fps"], sum(durations), delta=0.5 * 0.02 + 1e-9)

    def test_eight_frames_of_a_hundred_and_fifty_milliseconds_make_exactly_one_point_two_seconds(self):
        c = clips.on_grid(list("abcdefgh"), [0.15] * 8, True, 0.02)
        self.assertEqual(len(c["frames"]), 60)

    def test_lengths_must_match(self):
        with self.assertRaises(ValueError):
            clips.on_grid(["a"], [0.1, 0.1], True)


if __name__ == "__main__":
    unittest.main()
