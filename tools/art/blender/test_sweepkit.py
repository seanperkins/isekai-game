"""The geometry of a swept tube (sweepkit.py), pure Python: a smooth path through points, rings perpendicular to it, and the weights that let one tube bend at a joint."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sweepkit as sk  # noqa: E402

LEG = [(0.0, 0.0, 0.58), (0.02, 0.0, 0.37), (-0.03, 0.0, 0.16)]
SECTIONS = [(0.08, 0.07), (0.06, 0.055), (0.036, 0.036)]


def dist(a, b):
    return math.sqrt(sum((p - q) ** 2 for p, q in zip(a, b)))


class PathTest(unittest.TestCase):
    def test_the_smooth_path_passes_through_every_control_point_in_order(self):
        pts, secs, at = sk.resample(LEG, SECTIONS, per=4)
        self.assertEqual(len(pts), len(secs))
        for i, ci in enumerate(at):
            self.assertLess(dist(pts[ci], LEG[i]), 1e-9)
        self.assertEqual(at, sorted(at))
        self.assertEqual(at[0], 0)
        self.assertEqual(at[-1], len(pts) - 1)

    def test_it_has_per_samples_between_each_pair_of_control_points(self):
        pts, _, at = sk.resample(LEG, SECTIONS, per=4)
        self.assertEqual(len(pts), 4 * (len(LEG) - 1) + 1)

    def test_the_sections_run_from_one_control_size_to_the_next_without_leaving_them(self):
        _, secs, at = sk.resample(LEG, SECTIONS, per=4)
        for s in secs:
            self.assertGreaterEqual(s[0], 0.036 - 1e-9)
            self.assertLessEqual(s[0], 0.08 + 1e-9)
        self.assertEqual(secs[at[1]], SECTIONS[1])

    def test_the_smooth_path_stays_close_to_the_bones_it_follows(self):
        pts, _, _ = sk.resample(LEG, SECTIONS, per=4)
        for p in pts:
            self.assertLess(sk.distance_to_polyline(p, LEG), 0.03)


class RingTest(unittest.TestCase):
    def test_every_ring_is_perpendicular_to_the_path_and_as_wide_as_its_section(self):
        pts, secs, _ = sk.resample(LEG, SECTIONS, per=4)
        rings = sk.rings(pts, secs, sides=12)
        self.assertEqual(len(rings), len(pts))
        for i, ring in enumerate(rings):
            self.assertEqual(len(ring), 12)
            centre = pts[i]
            ys = [v[1] - centre[1] for v in ring]
            self.assertAlmostEqual(max(ys), secs[i][1], places=6, msg="the ring is b wide across the leg")
            tangent = sk.tangent_at(pts, i)
            for v in ring:
                off = [v[k] - centre[k] for k in range(3)]
                self.assertAlmostEqual(sum(o * t for o, t in zip(off, tangent)), 0.0, places=6, msg="the ring lies in the plane across the path")

    def test_a_bend_keeps_the_leg_as_thick_at_the_joint_as_on_either_side(self):
        bent = [(0.0, 0.0, 0.5), (0.0, 0.0, 0.3), (0.2, 0.0, 0.15)]
        pts, secs, at = sk.resample(bent, [(0.05, 0.05)] * 3, per=3)
        rings = sk.rings(pts, secs, sides=12)
        joint = at[1]
        # the ring at the bend is at least as wide as the section: mitered, not pinched
        ring = rings[joint]
        widest = max(dist(a, b) for a in ring for b in ring)
        self.assertGreaterEqual(widest, 2 * 0.05 - 1e-9)


class FrameTest(unittest.TestCase):
    def ring_for(self, yaw):
        a = math.radians(yaw)
        straight = [(0.0, 0.0, 0.0), (0.0, 0.0, 0.2)]
        return sk.rings(straight, [(0.05, 0.01), (0.05, 0.01)], sides=12, up=(math.sin(a), math.cos(a), 0.0))[0]

    def test_with_no_turn_the_width_runs_along_x_and_the_thickness_along_y(self):
        ring = self.ring_for(0.0)
        self.assertAlmostEqual(max(abs(v[0]) for v in ring), 0.05, places=6)
        self.assertAlmostEqual(max(abs(v[1]) for v in ring), 0.01, places=6)

    def test_turned_a_quarter_the_width_runs_along_y(self):
        ring = self.ring_for(90.0)
        self.assertAlmostEqual(max(abs(v[0]) for v in ring), 0.01, places=6)
        self.assertAlmostEqual(max(abs(v[1]) for v in ring), 0.05, places=6)

    def test_turned_part_way_the_plate_shows_a_good_width_from_the_side_and_from_the_front(self):
        ring = self.ring_for(40.0)
        self.assertGreater(max(abs(v[0]) for v in ring), 0.035, "seen from the side")
        self.assertGreater(max(abs(v[1]) for v in ring), 0.028, "seen from the front")


class WeightTest(unittest.TestCase):
    def test_a_vertex_on_a_bone_is_that_bones_alone_and_one_at_a_joint_is_shared_evenly(self):
        bounds = [0.0, 0.2, 0.4]       # the arclengths where bone 0, bone 1 and the end begin
        self.assertEqual(sk.joint_weights(0.05, bounds[1:-1], 0.04), [1.0, 0.0])
        self.assertEqual(sk.joint_weights(0.35, bounds[1:-1], 0.04), [0.0, 1.0])
        w = sk.joint_weights(0.2, bounds[1:-1], 0.04)
        self.assertAlmostEqual(w[0], 0.5)
        self.assertAlmostEqual(w[1], 0.5)

    def test_the_weights_always_sum_to_one_and_change_smoothly_across_a_joint(self):
        last = None
        for i in range(0, 41):
            s = i * 0.01
            w = sk.joint_weights(s, [0.1, 0.25], 0.05)
            self.assertEqual(len(w), 3)
            self.assertAlmostEqual(sum(w), 1.0)
            if last is not None:
                self.assertLess(max(abs(a - b) for a, b in zip(w, last)), 0.35)
            last = w

    def test_the_arclength_of_a_point_is_how_far_along_the_bones_it_projects(self):
        total = sum(dist(LEG[i], LEG[i + 1]) for i in range(2))
        self.assertAlmostEqual(sk.arclength_of(LEG[0], LEG), 0.0)
        self.assertAlmostEqual(sk.arclength_of(LEG[1], LEG), dist(LEG[0], LEG[1]))
        self.assertAlmostEqual(sk.arclength_of(LEG[2], LEG), total)
        mid = tuple((LEG[0][k] + LEG[1][k]) / 2 + (0.0 if k != 1 else 0.05) for k in range(3))
        self.assertAlmostEqual(sk.arclength_of(mid, LEG), dist(LEG[0], LEG[1]) / 2, places=3)


if __name__ == "__main__":
    unittest.main()
