"""The flat copy of Rig.pose (skeleton2d.py): pure Python. test_pipeline.py checks it against the real Blender armature."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skeleton2d as sk  # noqa: E402

REST = {
    "hips": ((0.0, 0.8), (0.0, 0.95), None),
    "spine": ((0.0, 0.95), (0.05, 1.30), "hips"),
    "arm": ((0.06, 1.28), (0.10, 1.04), "spine"),
    "thigh": ((0.0, 0.8), (0.03, 0.48), "hips"),
}


class SkeletonTest(unittest.TestCase):
    def setUp(self):
        self.s = sk.Skeleton2D(REST)

    def assertPoint(self, got, want, places=6):
        self.assertAlmostEqual(got[0], want[0], places=places)
        self.assertAlmostEqual(got[1], want[1], places=places)

    def test_the_rest_pose_is_the_rest_pose(self):
        posed = self.s.pose()
        for name, (head, tail, _) in REST.items():
            self.assertPoint(posed[name][0], head)
            self.assertPoint(posed[name][1], tail)
            self.assertAlmostEqual(posed[name][2], sk.direction(head, tail))

    def test_directions_are_from_straight_down_forward_positive(self):
        self.assertAlmostEqual(sk.direction((0, 1), (0, 0)), 0.0)
        self.assertAlmostEqual(sk.direction((0, 0), (1, 0)), 90.0)
        self.assertAlmostEqual(abs(sk.direction((0, 0), (0, 1))), 180.0)
        self.assertAlmostEqual(sk.direction((0, 0), (-1, 0)), -90.0)

    def test_the_root_moves_everything(self):
        posed = self.s.pose({}, (0.5, 0.0, -0.1))
        self.assertPoint(posed["arm"][0], (0.56, 1.18))

    def test_a_positive_turn_leans_a_torso_forward_and_swings_a_hanging_leg_back(self):
        posed = self.s.pose({"spine": (0.0, 20.0, 0.0), "thigh": (0.0, 20.0, 0.0)})
        self.assertGreater(posed["spine"][1][0], REST["spine"][1][0] + 0.1)
        self.assertLess(posed["thigh"][1][0], REST["thigh"][1][0] - 0.1)
        self.assertAlmostEqual(posed["spine"][2], sk.direction(*REST["spine"][:2]) - 20.0)

    def test_a_child_turns_with_its_parent_about_the_parents_head_and_adds_its_own_turn(self):
        posed = self.s.pose({"spine": (0.0, 30.0, 0.0), "arm": (0.0, -10.0, 0.0)})
        self.assertAlmostEqual(posed["arm"][2], sk.direction(*REST["arm"][:2]) - 30.0 + 10.0)
        hx, hz = REST["spine"][0]
        ax, az = REST["arm"][0]
        want = sk.turn((ax - hx, az - hz), 30.0)
        self.assertPoint(posed["arm"][0], (hx + want[0], hz + want[1]))
        self.assertAlmostEqual(math.dist(posed["arm"][0], posed["arm"][1]), sk.Skeleton2D(REST).length("arm"))

    def test_a_point_fixed_to_a_bone_goes_where_the_bone_takes_it(self):
        rot = {"spine": (0.0, 30.0, 0.0), "arm": (0.0, -10.0, 0.0)}
        posed = self.s.pose(rot)
        self.assertPoint(self.s.point("arm", REST["arm"][1], posed=posed), posed["arm"][1])
        self.assertPoint(self.s.point("arm", REST["arm"][0], posed=posed), posed["arm"][0])

    def test_the_chain_lists_ancestors_root_first(self):
        self.assertEqual(self.s.chain("arm"), ["hips", "spine"])
        self.assertEqual(self.s.chain("hips"), [])


if __name__ == "__main__":
    unittest.main()
