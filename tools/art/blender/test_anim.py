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


class FootTest(unittest.TestCase):
    STRIDE, DUTY, LIFT = 0.4, 0.6, 0.12
    HEEL, TOE, ANKLE = 0.08, 0.22, 0.11

    def foot(self, u, stride=None, lift=None, dims=None):
        heel, toe, ankle = dims or (self.HEEL, self.TOE, self.ANKLE)
        return anim.foot_pose(u, self.STRIDE if stride is None else stride, self.DUTY, self.LIFT if lift is None else lift, heel, toe, ankle)

    def sole(self, u, dims=None):
        heel, toe, ankle = dims or (self.HEEL, self.TOE, self.ANKLE)
        x, z, pitch, _ = self.foot(u, dims=dims)
        return anim.sole_points(x, z, pitch, heel, toe, ankle)

    def test_the_ankle_path_and_its_velocity_have_no_jumps_across_the_whole_cycle_including_lift_off_landing_and_the_wrap(self):
        n = 6000
        pts = [self.foot(k / float(n)) for k in range(n + 1)]
        vel = [((b[0] - a[0]) * n, (b[1] - a[1]) * n, (b[2] - a[2]) * n) for a, b in zip(pts, pts[1:])]
        for (ax, az, ap), (bx, bz, bp) in zip(vel, vel[1:]):
            self.assertLess(abs(bx - ax), 0.6, "x velocity does not jump (per cycle)")
            self.assertLess(abs(bz - az), 0.6, "z velocity does not jump")
            self.assertLess(abs(bp - ap), 600.0, "pitch velocity does not jump")
        wrap = self.foot(0.0), self.foot(0.9999999)
        for a, b in zip(wrap[0][:3], wrap[1][:3]):
            self.assertAlmostEqual(a, b, delta=0.002)
        lo, hi = vel[int(self.DUTY * n) - 2], vel[int(self.DUTY * n) + 2]
        self.assertAlmostEqual(lo[0], hi[0], delta=0.1 * abs(lo[0]) + 0.05, msg="the foot leaves the ground at the speed it was moving back")

    def test_the_heel_does_not_move_over_the_ground_from_landing_until_the_foot_is_flat_and_nor_does_the_toe_from_the_heel_lifting_until_it_leaves(self):
        speed = -self.STRIDE / self.DUTY   # the ground's speed under the foot, units per cycle
        a, b = anim.ROLL
        # (the part of the stance, the points of the sole that must be on the ground and moving with it)
        for name, (lo, hi), pivots in (("heel", (0.0, a), (0,)), ("flat", (a, b), (0, 1)), ("toe", (b, 1.0), (1,))):
            samples = []
            for k in range(1, 200):
                u = (lo + (hi - lo) * k / 200.0) * self.DUTY
                samples.append((u, self.sole(u)))
            for pivot in pivots:
                for (u0, s0), (u1, s1) in zip(samples, samples[1:]):
                    self.assertAlmostEqual((s1[pivot][0] - s0[pivot][0]) / (u1 - u0), speed, delta=0.002 * abs(speed), msg="%s phase, point %d" % (name, pivot))
                    self.assertAlmostEqual(s1[pivot][1], 0.0, places=7, msg="%s phase, point %d is on the ground" % (name, pivot))

    def test_a_planted_foot_never_has_a_point_below_the_ground(self):
        for dims in ((self.HEEL, self.TOE, self.ANKLE), (0.03, 0.09, 0.2), (0.12, 0.30, 0.08)):
            for k in range(0, 600):
                heel, toe = self.sole(k / 1000.0, dims)
                self.assertGreaterEqual(min(heel[1], toe[1]), -1e-9)

    def test_the_sole_never_goes_below_the_ground_in_swing_and_the_foot_comes_up_to_the_lift(self):
        peak = 0.0
        for k in range(601, 1000):
            heel, toe = self.sole(k / 1000.0)
            self.assertGreaterEqual(min(heel[1], toe[1]), -1e-9)
            self.assertFalse(self.foot(k / 1000.0)[3])
            peak = max(peak, min(heel[1], toe[1]))
        self.assertGreater(peak, self.LIFT * 0.6)

    def test_the_heel_strikes_toe_up_rolls_flat_and_the_heel_lifts_before_the_toe_leaves(self):
        self.assertGreater(self.foot(0.0)[2], 10.0)
        self.assertAlmostEqual(self.foot(0.3)[2], 0.0, delta=0.5)
        self.assertLess(self.foot(self.DUTY - 0.001)[2], -30.0)

    def test_the_other_leg_is_half_a_cycle_behind_so_a_foot_is_always_down_and_both_are_down_a_fifth_of_the_time(self):
        both = 0
        for k in range(1000):
            u = k / 1000.0
            a, b = self.foot(u)[3], self.foot((u + 0.5) % 1.0)[3]
            self.assertTrue(a or b)
            both += a and b
        self.assertAlmostEqual(both / 1000.0, 2 * (self.DUTY - 0.5), delta=0.01)

    def test_the_heel_is_behind_the_ankle_and_the_toe_ahead_and_both_are_below_it(self):
        heel, toe = anim.sole_points(0.5, 0.3, 0.0, self.HEEL, self.TOE, self.ANKLE)
        self.assertAlmostEqual(heel[0], 0.5 - self.HEEL, places=9)
        self.assertAlmostEqual(toe[0], 0.5 + self.TOE, places=9)
        self.assertAlmostEqual(heel[1], 0.3 - self.ANKLE, places=9)

    def test_the_middle_of_the_flat_part_is_under_the_hip(self):
        a, b = anim.ROLL
        x, z, p, _ = self.foot((a + b) / 2.0 * self.DUTY)
        self.assertAlmostEqual(x, 0.0, places=9)
        self.assertAlmostEqual(z, self.ANKLE, places=9)

    def test_a_foot_swung_with_no_lift_still_does_not_go_through_the_floor(self):
        for k in range(601, 1000):
            heel, toe = self.sole(k / 1000.0) if False else anim.sole_points(*self.foot(k / 1000.0, lift=0.0)[:3], self.HEEL, self.TOE, self.ANKLE)
            self.assertGreaterEqual(min(heel[1], toe[1]), -1e-9)

    def test_a_short_stubby_foot_swung_low_is_lifted_clear_of_the_floor(self):
        heel, toe, ankle = 0.05, 0.1, 0.2  # a foot on which the swing's roll would otherwise dip the sole through the floor
        for k in range(601, 1000):
            x, z, p, _ = anim.foot_pose(k / 1000.0, 0.1, self.DUTY, 0.0, heel, toe, ankle)
            self.assertGreaterEqual(min(pt[1] for pt in anim.sole_points(x, z, p, heel, toe, ankle)), -1e-9)

    def test_a_tilted_foot_rests_on_its_heel_or_its_toe_and_the_lowest_point_is_what_decides(self):
        flat = anim.sole_points(0.0, 0.11, 0.0, self.HEEL, self.TOE, self.ANKLE)
        self.assertAlmostEqual(min(p[1] for p in flat), 0.0, places=9)
        toe_up = anim.sole_points(0.0, 0.2, 30.0, self.HEEL, self.TOE, self.ANKLE)
        self.assertLess(toe_up[0][1], toe_up[1][1], "toe up: the heel is the low point")
        heel_up = anim.sole_points(0.0, 0.2, -30.0, self.HEEL, self.TOE, self.ANKLE)
        self.assertLess(heel_up[1][1], heel_up[0][1], "heel up: the toe is the low point")


class PelvisTest(unittest.TestCase):
    def test_a_planted_foot_puts_its_contact_point_where_it_is_told_and_its_sole_on_the_floor(self):
        heel, toe, ankle = 0.08, 0.22, 0.11
        for pitch in (-34.0, -10.0, 0.0, 7.0, 14.0):
            x, z = anim.plant(0.3, pitch, heel, toe, ankle)
            cx, low = anim.sole_contact(x, z, pitch, heel, toe, ankle)
            self.assertAlmostEqual(cx, 0.3, places=9)
            self.assertAlmostEqual(low, 0.0, places=9)

    def test_a_heel_lifting_turns_about_the_toe_which_stays_put(self):
        heel, toe, ankle = 0.08, 0.22, 0.11
        flat_x, _ = anim.plant(0.3, 0.0, heel, toe, ankle)
        flat_toe = flat_x + toe
        for pitch in (-5.0, -20.0, -34.0):
            x, z = anim.plant_toe(flat_toe, pitch, heel, toe, ankle)
            _, tip = anim.sole_points(x, z, pitch, heel, toe, ankle)
            self.assertAlmostEqual(tip[0], flat_toe, places=9)
            self.assertAlmostEqual(tip[1], 0.0, places=9)

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
    N, DT = 12, 1.0 / 24.0

    def sine(self, amp=10.0):
        return [amp * math.sin(2 * math.pi * i / self.N) for i in range(self.N)]

    def test_a_constant_driver_settles_to_it(self):
        for v in anim.follow([7.0] * 8, self.DT, freq=3.0, zeta=0.4):
            self.assertAlmostEqual(v, 7.0, places=3)

    def test_the_follower_lags_the_driver_and_does_not_fly_off(self):
        driver = self.sine()
        out = anim.follow(driver, self.DT, freq=3.0, zeta=0.4)
        self.assertGreater((out.index(max(out)) - driver.index(max(driver))) % self.N, 0, "it arrives late")
        self.assertLess(max(out), max(driver) * 1.6)

    def test_a_loop_is_seamless_the_spring_ends_where_it_began_in_position_and_speed(self):
        series, start, end = anim.follow(self.sine(), self.DT, freq=3.0, zeta=0.2, state=True)
        self.assertAlmostEqual(start[0], end[0], places=3)
        self.assertAlmostEqual(start[1], end[1], places=2)
        again = anim.follow(self.sine(), self.DT, freq=3.0, zeta=0.2)
        for a, b in zip(series, again):
            self.assertAlmostEqual(a, b, places=6)

    def test_a_lightly_damped_spring_still_converges_whatever_the_number_of_cycles_it_takes(self):
        series, start, end = anim.follow(self.sine(), self.DT, freq=6.0, zeta=0.03, state=True)
        self.assertAlmostEqual(start[0], end[0], places=2)

    def test_a_stiffer_follower_stays_closer_to_the_driver(self):
        driver = self.sine()
        err = lambda out: sum(abs(a - b) for a, b in zip(out, driver))
        self.assertLess(err(anim.follow(driver, self.DT, freq=8.0, zeta=0.5)), err(anim.follow(driver, self.DT, freq=1.5, zeta=0.5)))

    def test_slower_frames_give_the_spring_more_time_so_it_trails_by_fewer_frames(self):
        driver = self.sine()
        lag = lambda dt: (lambda out: (out.index(max(out)) - driver.index(max(driver))) % self.N)(anim.follow(driver, dt, freq=2.0, zeta=0.4))
        self.assertGreaterEqual(lag(1.0 / 60.0), lag(0.25))

    def test_a_one_shot_starts_at_rest_on_the_first_frame_and_only_catches_up_from_there(self):
        step = [0.0] * 3 + [10.0] * 9
        out = anim.follow(step, self.DT, freq=3.0, zeta=0.5, periodic=False)
        self.assertEqual(out[0], 0.0)
        self.assertLess(out[3], 10.0, "the frame the driver jumps it has not yet arrived")
        self.assertGreater(out[-1], 5.0)

    def test_frames_of_different_lengths_are_integrated_over_their_own_time(self):
        driver = [0.0, 10.0, 10.0, 10.0]
        short = anim.follow(driver, [0.02, 0.02, 0.02, 0.02], freq=3.0, zeta=0.5, periodic=False)
        long = anim.follow(driver, [0.02, 0.5, 0.02, 0.02], freq=3.0, zeta=0.5, periodic=False)
        self.assertGreater(long[2], short[2], "a held frame gives it time to arrive")


class KeysTest(unittest.TestCase):
    KEYS = [(0, 0.0, "out"), (3, 10.0, "in"), (5, 4.0, "smooth"), (9, 0.0, "linear")]

    def test_it_hits_every_key_exactly(self):
        for t, v, _ in self.KEYS:
            self.assertAlmostEqual(anim.sample(self.KEYS, t), v, places=9)

    def test_a_loop_whose_first_key_is_late_still_wraps_smoothly_from_the_previous_cycle(self):
        keys = [(2, 0.0, "linear"), (6, 8.0, "linear")]
        self.assertAlmostEqual(anim.sample_loop(keys, 0, 8), 4.0, places=6, msg="halfway down from 8 (at 6) to 0 (at 2 + 8)")
        self.assertAlmostEqual(anim.sample_loop(keys, 7.999999, 8), anim.sample_loop(keys, 0, 8), places=3)

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
