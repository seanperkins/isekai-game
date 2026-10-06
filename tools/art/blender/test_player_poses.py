"""The poses a player body needs (player_poses.py), checked on the flat skeleton: pure Python."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import biped_motion as gm  # noqa: E402
import player_poses as pp  # noqa: E402
import test_biped_motion as T  # noqa: E402


def extent(body, rot, root):
    posed = body.skel.pose(rot, root)
    pts = [p for name, (h, t, _) in posed.items() if not name.startswith(("ear", "item")) for p in (h, t)]
    return min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts)


class PoseTest(unittest.TestCase):
    def setUp(self):
        self.body = T.body_of("goblin")
        rot, root = gm.idle_pose(self.body, 0.0)
        x0, x1, z0, z1 = extent(self.body, rot, root)
        self.stand_h, self.stand_w = z1 - z0, x1 - x0

    def test_every_pose_exists_is_finite_and_a_clip_has_the_frames_it_says(self):
        for name, n in pp.FRAMES.items():
            clip = pp.clip(self.body, name)
            self.assertEqual(len(clip.frames), n, name)
            for rot, root in clip.frames:
                for v in list(root) + [a for r in rot.values() for a in r]:
                    self.assertTrue(math.isfinite(v), name)
            self.assertEqual(clip.grounded, pp.GROUNDED[name], name)

    def test_a_roll_is_a_compact_ball_that_turns_a_quarter_each_frame(self):
        frames = [pp.pose(self.body, "roll", k) for k in range(4)]
        for rot, root in frames:
            x0, x1, z0, z1 = extent(self.body, rot, root)
            self.assertLess(z1 - z0, 0.8 * self.stand_h, "curled up")
            self.assertLess(x1 - x0, 1.2 * self.stand_h)
        a, b = self.body.skel.pose(*frames[0])["head"][2], self.body.skel.pose(*frames[1])["head"][2]
        self.assertAlmostEqual((a - b) % 360.0, 90.0, delta=0.5)
        c = self.body.skel.pose(*frames[2])["head"][2]
        self.assertAlmostEqual((a - c) % 360.0, 180.0, delta=0.5)

    def test_a_rise_drives_the_near_knee_above_the_far_foot_and_flings_the_arms_up(self):
        posed = self.body.skel.pose(*pp.pose(self.body, "rise"))
        self.assertGreater(posed["shin_n"][0][1], posed["shin_f"][0][1] + 0.1, "the near knee is up")
        self.assertGreater(posed["fore_n"][1][1], posed["head"][0][1], "the hand is above the head")

    def test_a_fall_hangs_the_legs_and_raises_the_arms(self):
        posed = self.body.skel.pose(*pp.pose(self.body, "fall"))
        self.assertGreater(posed["fore_n"][1][1], posed["spine"][1][1] - 0.2)
        self.assertLess(posed["foot_n"][0][1], posed["hips"][0][1], "the feet hang below the hips")

    def test_a_slide_is_low_with_the_body_leaning_back_and_a_leg_out_in_front(self):
        rot, root = pp.pose(self.body, "slide")
        x0, x1, z0, z1 = extent(self.body, rot, root)
        posed = self.body.skel.pose(rot, root)
        self.assertLess(180.0 - posed["spine"][2], 0.0, "leaning back")
        self.assertGreater(posed["foot_n"][0][0], posed["hips"][0][0] + 0.3 * self.body.L, "a foot well ahead")

    def test_a_mantle_goes_from_hanging_by_the_hands_to_the_chest_over_the_edge(self):
        hang = self.body.skel.pose(*pp.pose(self.body, "mantle", 0))
        up = self.body.skel.pose(*pp.pose(self.body, "mantle", 1))
        self.assertGreater(hang["fore_n"][1][1], hang["head"][1][1], "the hands are over the head")
        self.assertGreater(180.0 - up["spine"][2], 30.0, "then the body leans over its hands")
        self.assertGreater(up["thigh_n"][1][0], up["hips"][0][0] + 0.2 * self.body.L, "a knee comes forward onto the ledge")

    def test_a_wall_cling_reaches_up_the_wall_with_a_foot_braced_forward(self):
        posed = self.body.skel.pose(*pp.pose(self.body, "wall"))
        self.assertGreater(posed["fore_n"][1][1], posed["head"][1][1] - 0.05)
        self.assertGreater(posed["shin_n"][0][0], posed["hips"][0][0] + 0.1 * self.body.L, "the near knee is up against the wall")

    def test_a_landing_is_a_crouch_with_both_feet_down(self):
        rot, root = pp.pose(self.body, "land")
        posed = self.body.skel.pose(rot, root)
        for s in "nf":
            heel, toe = self.body.legs[s].sole(posed)
            self.assertAlmostEqual(min(heel[1], toe[1]), 0.0, places=6)
        x0, x1, z0, z1 = extent(self.body, rot, root)
        self.assertLess(z1 - z0, 0.85 * self.stand_h)

    def test_an_unknown_pose_is_an_error(self):
        with self.assertRaises(KeyError):
            pp.pose(self.body, "dance")


if __name__ == "__main__":
    unittest.main()
