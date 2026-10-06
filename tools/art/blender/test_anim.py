"""The animation maths shared by every creature (anim.py): pure Python, so it is tested here and used inside Blender."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim  # noqa: E402


class IkTest(unittest.TestCase):
    def reaches(self, l1, l2, hip, target, bend):
        a1, a2 = anim.ik2d(l1, l2, hip, target, bend)
        _, end = anim.fk2d(l1, l2, hip, a1, a2)
        self.assertAlmostEqual(end[0], target[0], places=7)
        self.assertAlmostEqual(end[1], target[1], places=7)
        return a1, a2

    def test_a_target_in_reach_is_reached_with_the_knee_forward_or_back(self):
        for target in ((0.0, 0.0), (0.2, 0.1), (-0.3, 0.05), (0.1, 0.4)):
            for bend in (1, -1):
                self.reaches(0.6, 0.55, (0.0, 1.0), target, bend)

    def test_the_knee_goes_the_way_it_is_told(self):
        a1, _ = self.reaches(0.6, 0.6, (0.0, 1.0), (0.0, 0.0), 1)
        knee, _ = anim.fk2d(0.6, 0.6, (0.0, 1.0), *anim.ik2d(0.6, 0.6, (0.0, 1.0), (0.0, 0.0), 1))
        self.assertGreater(knee[0], 0.0)
        knee_back, _ = anim.fk2d(0.6, 0.6, (0.0, 1.0), *anim.ik2d(0.6, 0.6, (0.0, 1.0), (0.0, 0.0), -1))
        self.assertLess(knee_back[0], 0.0)
        self.assertGreater(a1, 0.0, "a forward knee means the thigh is turned forward")

    def test_a_target_out_of_reach_gets_a_straight_limb_pointing_at_it(self):
        a1, a2 = anim.ik2d(0.5, 0.5, (0.0, 1.0), (0.6, -2.0), 1)
        knee, end = anim.fk2d(0.5, 0.5, (0.0, 1.0), a1, a2)
        self.assertAlmostEqual(math.hypot(end[0], end[1] - 1.0), 1.0, places=5)
        want = math.atan2(0.6, 3.0)
        self.assertAlmostEqual(a1, want, places=4)
        self.assertAlmostEqual(a2, want, places=4)

    def test_a_target_closer_than_the_fold_does_not_blow_up(self):
        for target in ((0.0, 0.95), (0.0, 1.0)):  # the second is the hip itself
            a1, a2 = anim.ik2d(0.8, 0.3, (0.0, 1.0), target, 1)
            self.assertTrue(all(math.isfinite(v) for v in (a1, a2)))


class GaitTest(unittest.TestCase):
    STRIDE, DUTY, LIFT = 0.4, 0.6, 0.12

    def foot(self, u):
        return anim.stride_foot(u, self.STRIDE, self.DUTY, self.LIFT)

    def test_a_planted_foot_stays_on_the_ground_and_moves_back_at_one_speed(self):
        xs = []
        for k in range(0, 60):
            u = k / 100.0
            x, z, _, grounded = self.foot(u)
            self.assertTrue(grounded)
            self.assertEqual(z, 0.0)
            xs.append(x)
        steps = [a - b for a, b in zip(xs, xs[1:])]
        self.assertTrue(all(abs(s - steps[0]) < 1e-9 for s in steps), "constant speed: it does not slide")
        self.assertAlmostEqual(self.foot(0.0)[0] - self.foot(self.DUTY)[0], self.STRIDE, places=6)

    def test_a_swinging_foot_lifts_and_comes_forward_and_lands_where_the_next_stance_begins(self):
        self.assertAlmostEqual(self.foot(self.DUTY)[0], -self.STRIDE / 2, places=6)
        self.assertAlmostEqual(self.foot(0.999999)[0], self.STRIDE / 2, places=3)
        last = -1e9
        peak = 0.0
        for k in range(61, 100):
            x, z, _, grounded = self.foot(k / 100.0)
            self.assertFalse(grounded)
            self.assertGreaterEqual(x, last, "it only moves forward")
            last = x
            peak = max(peak, z)
        self.assertAlmostEqual(peak, self.LIFT, delta=0.01)
        self.assertEqual(self.foot(0.9999999)[1] < 0.001, True)

    def test_the_foot_is_continuous_across_the_whole_cycle(self):
        prev = self.foot(0.0)
        for k in range(1, 400):
            cur = self.foot(k / 400.0)
            self.assertLess(abs(cur[0] - prev[0]), 0.05)
            self.assertLess(abs(cur[1] - prev[1]), 0.05)
            prev = cur
        self.assertAlmostEqual(self.foot(0.0)[0], self.foot(1.0)[0], places=6)

    def test_the_other_leg_is_half_a_cycle_behind_so_a_foot_is_always_down_and_both_are_down_a_fifth_of_the_time(self):
        both = 0
        for k in range(1000):
            u = k / 1000.0
            a, b = self.foot(u)[3], self.foot((u + 0.5) % 1.0)[3]
            self.assertTrue(a or b)
            both += a and b
        self.assertAlmostEqual(both / 1000.0, 2 * (self.DUTY - 0.5), delta=0.01)

    def test_the_heel_strikes_toe_up_rolls_flat_and_the_heel_lifts_before_the_toe_leaves(self):
        self.assertGreater(self.foot(0.0)[2], 5.0)
        self.assertAlmostEqual(self.foot(0.3)[2], 0.0, delta=2.0)
        self.assertLess(self.foot(self.DUTY - 0.01)[2], -15.0)

    def test_a_tilted_foot_rests_on_its_heel_or_its_toe(self):
        self.assertEqual(anim.contact_lift(0.0, 0.1, 0.2), 0.0)
        self.assertAlmostEqual(anim.contact_lift(30.0, 0.1, 0.2), 0.1 * 0.5, places=6)
        self.assertAlmostEqual(anim.contact_lift(-30.0, 0.1, 0.2), 0.2 * 0.5, places=6)


class PelvisTest(unittest.TestCase):
    def test_the_pelvis_is_highest_as_each_leg_passes_and_lowest_just_after_each_heel_strike(self):
        duty, amp = 0.6, 0.03
        samples = [(k / 200.0, anim.pelvis_height(k / 200.0, 1.0, amp, duty)) for k in range(200)]
        top = max(samples, key=lambda s: s[1])
        low = min(samples, key=lambda s: s[1])
        self.assertAlmostEqual(top[1], 1.0 + amp, places=4)
        self.assertAlmostEqual(low[1], 1.0 - amp, places=4)
        self.assertTrue(abs(top[0] - duty / 2) < 0.02 or abs(top[0] - (duty / 2 + 0.5)) < 0.02)
        self.assertTrue(0.0 < low[0] % 0.5 < 0.15, "lowest shortly after a contact")

    def test_it_bobs_twice_a_cycle(self):
        self.assertAlmostEqual(anim.pelvis_height(0.1, 1.0, 0.03, 0.6), anim.pelvis_height(0.6, 1.0, 0.03, 0.6), places=9)


class FollowTest(unittest.TestCase):
    def sine(self, n=12, amp=10.0):
        return [amp * math.sin(2 * math.pi * i / n) for i in range(n)]

    def test_a_constant_driver_settles_to_it(self):
        out = anim.follow([7.0] * 8)
        for v in out:
            self.assertAlmostEqual(v, 7.0, places=3)

    def test_the_follower_lags_the_driver_and_the_loop_is_seamless(self):
        driver = self.sine()
        out = anim.follow(driver)
        peak_driver = driver.index(max(driver))
        peak_out = out.index(max(out))
        self.assertGreater((peak_out - peak_driver) % len(driver), 0, "it arrives late")
        self.assertLess(max(out), max(driver) * 1.6, "and does not fly off")
        again = anim.follow(driver, cycles=12)
        for a, b in zip(out, again):
            self.assertAlmostEqual(a, b, places=2)

    def test_a_stiffer_follower_stays_closer_to_the_driver(self):
        driver = self.sine()
        soft = anim.follow(driver, stiffness=0.05)
        stiff = anim.follow(driver, stiffness=0.5)
        err = lambda out: sum(abs(a - b) for a, b in zip(out, driver))
        self.assertLess(err(stiff), err(soft))


class KeysTest(unittest.TestCase):
    KEYS = [(0, 0.0, "out"), (3, 10.0, "in"), (5, 4.0, "smooth"), (9, 0.0, "linear")]

    def test_it_hits_every_key_exactly(self):
        for t, v, _ in self.KEYS:
            self.assertAlmostEqual(anim.sample(self.KEYS, t), v, places=9)

    def test_it_holds_before_the_first_and_after_the_last(self):
        self.assertEqual(anim.sample(self.KEYS, -4), 0.0)
        self.assertEqual(anim.sample(self.KEYS, 20), 0.0)

    def test_an_ease_out_arrives_fast_and_an_ease_in_leaves_slowly(self):
        out_half = anim.sample([(0, 0.0, "out"), (4, 1.0, "linear")], 1)
        in_half = anim.sample([(0, 0.0, "in"), (4, 1.0, "linear")], 1)
        self.assertGreater(out_half, 0.25)
        self.assertLess(in_half, 0.25)

    def test_a_loop_wraps_from_the_last_key_to_the_first(self):
        keys = [(0, 0.0, "smooth"), (4, 8.0, "smooth")]
        self.assertAlmostEqual(anim.sample_loop(keys, 6, 8), 4.0, places=6)
        self.assertAlmostEqual(anim.sample_loop(keys, 8, 8), 0.0, places=9)


if __name__ == "__main__":
    unittest.main()
