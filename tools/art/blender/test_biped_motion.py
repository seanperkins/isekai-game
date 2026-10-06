"""How a goblin moves (biped_motion.py), checked on a flat copy of its skeleton: pure Python. Feet are measured where they touch the ground,
so these fail when a foot skates, floats or sinks, whatever the angles say."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim  # noqa: E402
import goblin_forms as forms  # noqa: E402
import biped_motion as gm  # noqa: E402
import goblin_skeleton as gs  # noqa: E402

FEET = {"n": (0.11, 0.06, 0.24), "f": (0.11, 0.06, 0.24)}
PX = 0.04     # about a game pixel in the units of the model (a goblin is drawn at about 26 pixels to the unit)


def body_of(name="goblin", **overrides):
    form = dict(forms.FORMS[name], **overrides)
    skel = gs.skeleton(gs.BASE_BX * form.get("bx", 1.0), gs.BASE_TALL * form.get("tall", 1.0), extra=gs.ears(form.get("ears", 1.0)))
    return gm.Body(skel, FEET, form)


def sole(body, side, rot, root):
    return body.legs[side].sole(body.skel.pose(rot, root))


class PostureTest(unittest.TestCase):
    def test_a_goblin_crouches_with_its_chest_well_forward_and_its_head_ahead_of_its_hips(self):
        body = body_of()
        rot, root = gm.idle_pose(body, 0.0)
        posed = body.skel.pose(rot, root)
        lean = 180.0 - posed["spine"][2]
        self.assertTrue(24.0 < lean < 34.0, lean)
        self.assertGreater(posed["head"][1][0] - posed["hips"][0][0], 0.22 * body.L, "the head is thrust ahead of the hips")

    def test_the_hips_are_low_over_bent_knees(self):
        body = body_of()
        rot, root = gm.idle_pose(body, 0.0)
        posed = body.skel.pose(rot, root)
        hip_over_ankle = (posed["hips"][0][1] - posed["shin_n"][1][1]) / body.L
        self.assertAlmostEqual(hip_over_ankle, 0.82, delta=0.04)

    def test_the_arms_hold_their_place_in_the_world_whatever_the_chest_does(self):
        body = body_of()
        a = gm.ARMS["free"]
        for lean in (0.0, 30.0, 60.0):
            rot = {}
            gm._posture(body, rot, lean, 10.0)
            gm._arms(body, rot, 0.25, 0.0)
            self.assertAlmostEqual(gm.direction_of(body, rot, "arm_n"), body.skel.rest_direction("arm_n") + a[0], places=6)

    def test_what_a_goblin_holds_keeps_its_tilt_while_the_forearm_swings(self):
        body = body_of()
        tilts = []
        for t in (0.0, 0.25, 0.5, 0.75):
            rot, _ = gm.gait_pose(body, "walk", t, 0.5)
            tilts.append(180.0 - gm.direction_of(body, rot, "item_n"))
        self.assertLess(max(tilts) - min(tilts), 12.0)


class IdleTest(unittest.TestCase):
    def test_both_feet_stay_exactly_where_they_are_planted_through_the_loop_and_both_legs_show(self):
        body = body_of()
        first = {s: sole(body, s, *gm.idle_pose(body, 0.0)) for s in "nf"}
        for i in range(gm.IDLE_FRAMES):
            for s in "nf":
                heel, toe = sole(body, s, *gm.idle_pose(body, i / gm.IDLE_FRAMES))
                self.assertAlmostEqual(heel[0], first[s][0][0], places=6)
                self.assertAlmostEqual(toe[0], first[s][1][0], places=6)
                self.assertAlmostEqual(heel[1], 0.0, places=6)
                self.assertAlmostEqual(toe[1], 0.0, places=6)
        apart = first["n"][1][0] - first["f"][1][0]
        self.assertGreater(apart, 0.5 * body.L, "a step apart, so the camera sees two legs")

    def test_it_breathes_but_does_not_drift(self):
        body = body_of()
        zs = [gm.idle_pose(body, i / 16.0)[1][2] for i in range(16)]
        self.assertGreater(max(zs) - min(zs), 0.004)
        self.assertLess(max(zs) - min(zs), 0.03)

    def test_a_form_that_stands_wide_has_its_feet_further_apart_and_a_hunch_lowers_the_hips(self):
        plain, wide, hunch = body_of("hob"), body_of("hob", stance="wide"), body_of("hob", stance="hunch")
        gap = lambda b: (lambda r: sole(b, "n", *r)[1][0] - sole(b, "f", *r)[1][0])(gm.idle_pose(b, 0.0))
        self.assertGreater(gap(wide), gap(plain) + 0.1 * plain.L)
        self.assertLess(gm.idle_pose(hunch, 0.0)[1][2], gm.idle_pose(plain, 0.0)[1][2] - 0.02)

    def test_a_raised_foot_is_off_the_ground_and_a_tiptoe_stands_on_its_toes(self):
        body = body_of("hob", stance="stomp")
        heel, toe = sole(body, "f", *gm.idle_pose(body, 0.0))
        self.assertGreater(heel[1], 0.05 * body.L)
        body = body_of("hob", stance="tiptoe")
        heel, toe = sole(body, "n", *gm.idle_pose(body, 0.0))
        self.assertGreater(heel[1], 0.04)
        self.assertAlmostEqual(toe[1], 0.0, places=6)


class GaitTest(unittest.TestCase):
    STRIDE, SAMPLES = 0.5, 240

    def poses(self, body, gait):
        return [(k / self.SAMPLES, gm.gait_pose(body, gait, k / self.SAMPLES, self.STRIDE)) for k in range(self.SAMPLES)]

    def test_a_planted_foot_lies_flat_on_the_ground_and_moves_back_at_one_speed_through_the_middle_of_its_stance_in_both_gaits(self):
        a, b = anim.ROLL
        for gait in ("walk", "run"):
            body = body_of()
            duty = gm.GAITS[gait]["duty"]
            xs = []
            for t, (rot, root) in self.poses(body, gait):
                if (a + 0.04) * duty < t < (b - 0.04) * duty:
                    heel, toe = sole(body, "n", rot, root)
                    self.assertAlmostEqual(heel[1], 0.0, places=6, msg="%s t=%.3f: the heel is on the ground" % (gait, t))
                    self.assertAlmostEqual(toe[1], 0.0, places=6, msg="%s t=%.3f: and the toe" % (gait, t))
                    xs.append((t, heel[0], toe[0]))
            for index in (1, 2):
                slopes = [(q[index] - p[index]) / (q[0] - p[0]) for p, q in zip(xs, xs[1:])]
                self.assertAlmostEqual(sum(slopes) / len(slopes), -self.STRIDE / duty, delta=0.02, msg=gait)
                self.assertLess(max(slopes) - min(slopes), 0.06 * self.STRIDE / duty, "%s: the speed does not change through the stance" % gait)

    def test_the_heel_stays_put_on_landing_and_the_toe_at_toe_off_whatever_the_gait(self):
        a, b = anim.ROLL
        for gait in ("walk", "run"):
            body = body_of()
            duty = gm.GAITS[gait]["duty"]
            heel_x, toe_x = [], []
            for t, (rot, root) in self.poses(body, gait):
                heel, toe = sole(body, "n", rot, root)
                if 0.02 * duty < t < a * duty:
                    heel_x.append((t, heel[0], heel[1]))
                if (b + 0.05) * duty < t < 0.98 * duty:
                    toe_x.append((t, toe[0], toe[1]))
            for points in (heel_x, toe_x):
                slopes = [(q[1] - p[1]) / (q[0] - p[0]) for p, q in zip(points, points[1:])]
                for slope in slopes:
                    self.assertAlmostEqual(slope, -self.STRIDE / duty, delta=0.02, msg=gait)
                for _, _, z in points:
                    self.assertAlmostEqual(z, 0.0, places=6)

    def test_the_swinging_foot_clears_the_ground_and_never_goes_through_it(self):
        for gait in ("walk", "run"):
            body = body_of()
            clearances, lows = [], []
            for t, (rot, root) in self.poses(body, gait):
                heel, toe = sole(body, "n", rot, root)
                lows.append(min(heel[1], toe[1]))
                if t > gm.GAITS[gait]["duty"] + 0.1:
                    clearances.append(min(heel[1], toe[1]))
            self.assertGreaterEqual(min(lows), -1e-6, gait)
            self.assertGreater(max(clearances), 0.04, gait)

    def test_a_walk_always_has_a_foot_down_and_a_run_leaves_the_ground_twice_a_cycle(self):
        for gait, flights in (("walk", 0), ("run", 2)):
            body = body_of()
            down = []
            for t, (rot, root) in self.poses(body, gait):
                grounded = [min(sole(body, s, rot, root)[0][1], sole(body, s, rot, root)[1][1]) < 0.003 for s in "nf"]
                down.append(any(grounded))
            airborne = sum(1 for a, b in zip(down, down[1:] + down[:1]) if a and not b)
            self.assertEqual(airborne, flights, gait)

    def test_the_pelvis_is_highest_over_a_planted_leg_in_a_walk_and_lowest_there_in_a_run(self):
        body = body_of()
        z = lambda gait, t, stride: gm.gait_pose(body, gait, t, stride)[1][2]
        duty = gm.GAITS["walk"]["duty"]
        self.assertGreater(z("walk", duty / 2.0, 0.5), z("walk", 0.05, 0.5) + 0.01, "up over the leg, down after the heel strike")
        duty = gm.GAITS["run"]["duty"]
        self.assertLess(z("run", duty / 2.0, 0.8), z("run", duty + 0.05, 0.8) - 0.02, "down in the push, up in the air")

    def test_the_run_leans_further_forward_than_the_walk(self):
        body = body_of()
        lean = lambda gait: 180.0 - body.skel.pose(*gm.gait_pose(body, gait, 0.1, 0.5))["spine"][2]
        self.assertGreater(lean("run"), lean("walk") + 8.0)

    def test_the_loop_closes_every_bone_ends_a_cycle_where_it_began(self):
        body = body_of()
        a, b = gm.gait_pose(body, "walk", 0.0, 0.5), gm.gait_pose(body, "walk", 1.0 - 1e-9, 0.5)
        for bone in a[0]:
            self.assertAlmostEqual(a[0][bone][1], b[0][bone][1], delta=0.01, msg=bone)

    def test_the_arms_swing_against_the_legs(self):
        body = body_of()
        arm = lambda t: gm.direction_of(body, gm.gait_pose(body, "walk", t, 0.5)[0], "arm_n")
        near_forward = body.skel.pose(*gm.gait_pose(body, "walk", 0.0, 0.5))["foot_n"][0][0]
        far_forward = body.skel.pose(*gm.gait_pose(body, "walk", 0.5, 0.5))["foot_n"][0][0]
        self.assertGreater(near_forward, far_forward)
        self.assertLess(arm(0.0 + 0.07), arm(0.5 + 0.07), "the near arm is back as the near leg is forward")


class ReachTest(unittest.TestCase):
    def test_every_foot_reaches_where_the_gait_puts_it_at_every_speed_and_scale_a_form_can_have(self):
        worst = 0.0
        for name in ("goblin", "hob", "ironboot", "gremlin", "mastersmith", "knocker"):
            body = body_of(name)
            for gait in ("walk", "run"):
                g = gm.GAITS[gait]
                for speed in (12.0, 30.0, 54.0, 80.0, 130.0, 200.0):
                    for ppu in (18.0, 26.0, 36.0):
                        s = speed * (1.9 if gait == "run" else 1.0)
                        cycle, stride = gm.plan_gait(body, gait, s, ppu)
                        self.assertLessEqual(stride, g["max_stride"] * body.L + 1e-9, "%s %s %s %s" % (name, gait, speed, ppu))
                        self.assertAlmostEqual(stride * ppu, min(s * g["duty"] * cycle, g["max_stride"] * body.L * ppu), places=6)
                        for k in range(24):
                            t = k / 24.0
                            rot, root = gm.gait_pose(body, gait, t, stride)
                            posed = body.skel.pose(rot, root)
                            for side, phase in (("n", 0.0), ("f", 0.5)):
                                leg = body.legs[side]
                                x, z, _, _ = anim.foot_pose(t + phase, stride, g["duty"], g["lift"] * body.L, leg.heel, leg.toe, leg.ankle_h)
                                ankle = leg.ankle_of(posed)
                                worst = max(worst, math.hypot(ankle[0] - (body.hip[0] + x), ankle[1] - z))
        self.assertLess(worst, 0.004, "no foot falls short of its target by more than a tenth of a pixel")

    def test_a_cycle_is_never_longer_than_a_slow_walk_nor_shorter_than_the_stride_allows(self):
        body = body_of()
        slow = gm.plan_gait(body, "walk", 6.0, 26.0)
        self.assertLessEqual(slow[0], gm.GAITS["walk"]["cycle"][1] + 1e-9)
        fast = gm.plan_gait(body, "run", 400.0, 26.0)
        self.assertLess(fast[0], gm.GAITS["run"]["cycle"][0], "faster than the usual limit: it quickens its step rather than overreach")


class AttackTest(unittest.TestCase):
    def tip(self, body, rot, root, length=0.5):
        """Where the end of something `length` long held in the near hand (it points up from the hand at rest) is."""
        sk = body.skel
        hand = sk.rest["item_n"][0]
        return sk.point("item_n", (hand[0], hand[1] + length), rot, root)

    def frames(self, body):
        return [gm.attack_pose(body, t) for t, _ in gm.attack_frames(body)[0]]

    def test_the_far_foot_stays_planted_through_the_attack_and_its_heel_comes_up_about_the_toe(self):
        body = body_of("redcap")
        toes = [sole(body, "f", *p)[1] for p in self.frames(body)]
        for toe in toes:
            self.assertAlmostEqual(toe[0], toes[0][0], delta=0.25 * PX, msg="the toe does not slide")
            self.assertAlmostEqual(toe[1], 0.0, places=6)
        heels = [sole(body, "f", *p)[0][1] for p in self.frames(body)]
        self.assertGreater(max(heels), 0.03, "the heel lifts as the body goes into the blow")

    def test_the_near_foot_steps_into_the_blow_and_plants_where_it_lands(self):
        body = body_of("redcap")
        frames = self.frames(body)
        toes = [sole(body, "n", *p)[1] for p in frames]
        self.assertGreater(max(t[0] for t in toes), toes[0][0] + 0.1 * body.L)
        held = [i for i, (t, _) in enumerate(gm.attack_frames(body)[0]) if gm.T_HIT <= t <= 0.43]
        for i in held:
            self.assertAlmostEqual(toes[i][1], 0.0, places=6, msg="frame %d" % i)
            self.assertAlmostEqual(toes[i][0], toes[held[0]][0], delta=0.01)

    def test_the_weapon_is_raised_behind_the_head_then_ends_well_ahead_of_the_chest(self):
        body = body_of("redcap")
        frames = self.frames(body)
        spec = gm.attack_frames(body)[0]
        windup = frames[2]   # the apex of the windup, held
        tip = self.tip(body, *windup)
        head = body.skel.pose(*windup)["head"][0]
        self.assertGreater(tip[1], head[1], "raised above the head")
        self.assertLess(tip[0], head[0], "and behind it")
        impact = frames[gm.attack_frames(body)[1]]   # the first frame after the windup: the one the engine shows as the verb fires
        posed = body.skel.pose(*impact)
        chest = posed["spine"][1]
        reach = self.tip(body, *impact)[0] - chest[0]
        self.assertTrue(0.8 * body.L < reach < 1.5 * body.L, "the damaging end is %.2f L ahead of the chest" % (reach / body.L))
        self.assertLess(abs(self.tip(body, *impact)[1] - chest[1]), 0.9 * body.L)

    def test_the_hands_never_leave_the_arms(self):
        body = body_of("redcap")
        for rot, root in self.frames(body):
            posed = body.skel.pose(rot, root)
            self.assertLess(math.dist(posed["fore_n"][1], posed["item_n"][0]), 0.35 * body.L)

    def test_the_timing_holds_the_anticipation_and_the_impact_and_is_fastest_in_the_swing(self):
        body = body_of("redcap")
        frames, windup = gm.attack_frames(body)
        durations = [d for _, d in frames]
        self.assertEqual(frames[0][0], 0.0)
        for (t, d), (nt, _) in zip(frames, frames[1:]):
            self.assertAlmostEqual(t + d, nt, places=9, msg="frames follow each other")
        self.assertGreaterEqual(max(durations[:windup]), 0.1, "the anticipation is held")
        self.assertLessEqual(max(durations[windup - 2:windup]), 0.04, "the swing is the fastest part")
        self.assertGreaterEqual(durations[windup], 0.08, "the impact is held")

    def test_the_windup_frames_last_exactly_as_long_as_the_engines_windup_and_the_recovery_no_longer_than_its_recover(self):
        for kind in gm.ATTACKS:
            body = body_of("redcap", attack=kind)
            frames, windup = gm.attack_frames(body)
            self.assertAlmostEqual(sum(d for _, d in frames[:windup]), gm.ENGINE_WINDUP, places=9, msg=kind)
            self.assertAlmostEqual(sum(d for _, d in frames[windup:]), gm.ENGINE_RECOVER, places=9, msg=kind)

    def test_the_last_frame_of_an_attack_and_of_a_flinch_is_the_rest_pose_the_next_clip_starts_from(self):
        body = body_of("redcap")
        idle, _ = gm.idle_pose(body, 0.0)
        for rot in (gm.attack_pose(body, gm.attack_frames(body)[0][-1][0])[0], gm.hurt_pose(body, gm.hurt_frames()[-1][0])[0]):
            for bone in ("spine", "head", "arm_n", "fore_n", "thigh_n", "shin_n"):
                self.assertAlmostEqual(rot[bone][1], idle[bone][1], delta=0.6, msg=bone)

    def test_the_flinch_lasts_the_engines_flinch(self):
        self.assertAlmostEqual(sum(d for _, d in gm.hurt_frames()), gm.ENGINE_HURT, places=9)

    def test_every_form_attacks_in_a_way_that_exists(self):
        for name, form in forms.FORMS.items():
            self.assertIn(gm.attack_kind(form), gm.ATTACKS, name)

    def test_what_a_form_holds_decides_how_it_attacks(self):
        self.assertEqual(gm.attack_kind(forms.FORMS["redcap"]), "chop")
        self.assertEqual(gm.attack_kind(forms.FORMS["skulker"]), "stab")
        self.assertEqual(gm.attack_kind(forms.FORMS["goblin"]), "swipe")


class HurtAndDieTest(unittest.TestCase):
    def test_a_blow_rocks_the_goblin_back_with_its_feet_planted_and_it_recovers(self):
        body = body_of("redcap")
        spec = gm.hurt_frames()
        poses = [gm.hurt_pose(body, t) for t, _ in spec]
        idle = gm.idle_pose(body, 0.0)
        peak = poses[2]
        self.assertLess(180.0 - body.skel.pose(*peak)["spine"][2], 12.0, "the chest comes up")
        self.assertLess(peak[1][0], idle[1][0] - 0.05 * body.L, "the hips go back")
        for p in poses:
            for s in "nf":
                heel, toe = sole(body, s, *p)
                self.assertAlmostEqual(heel[1], 0.0, places=6)
                self.assertAlmostEqual(heel[0], sole(body, s, *idle)[0][0], places=6)
        end = gm.hurt_pose(body, spec[-1][0] + spec[-1][1])
        self.assertAlmostEqual(end[1][2], idle[1][2], places=3)

    def test_it_falls_forward_and_ends_lying_prone_with_its_legs_trailing_behind(self):
        body = body_of("redcap")
        spec = gm.die_frames()
        last = gm.die_pose(body, spec[-1][0])
        posed = body.skel.pose(*last)
        spine = posed["spine"]
        self.assertAlmostEqual(spine[2], 90.0 - 4.0, delta=12.0, msg="the back is level")
        self.assertAlmostEqual(posed["hips"][2], 90.0, delta=15.0, msg="so is the pelvis")
        self.assertLess(posed["foot_n"][0][0], posed["hips"][0][0], "the feet are behind the hips")
        self.assertGreater(posed["head"][1][0], posed["hips"][0][0] + 0.3 * body.L, "the head is ahead of them")
        core = [p for name, p in posed.items() if not name.startswith("ear")]
        low = min(p[1][1] for p in core)
        high = max(max(p[0][1], p[1][1]) for p in core)
        self.assertLess(high - low, 0.6 * body.L, "a low shape")

    def test_the_fall_goes_through_a_crouch_on_the_way_down(self):
        body = body_of("redcap")
        heights = [body.skel.pose(*gm.die_pose(body, t))["head"][1][1] - min(p[1][1] for p in body.skel.pose(*gm.die_pose(body, t)).values()) for t, _ in gm.die_frames()]
        self.assertTrue(all(b <= a + 0.08 for a, b in zip(heights[1:], heights[2:])), "the head only goes down once it is going")
        self.assertLess(heights[-1], 0.4 * heights[0])


class ClipTest(unittest.TestCase):
    def test_every_clip_is_finite_and_has_a_duration_for_every_frame(self):
        body = body_of("redcap")
        for clip in (gm.idle_clip(body), gm.gait_clip(body, "walk", 0.6, 0.5), gm.gait_clip(body, "run", 0.4, 0.8), gm.attack_clip(body), gm.hurt_clip(body), gm.die_clip(body)):
            self.assertEqual(len(clip.frames), len(clip.durations))
            for rot, root in clip.frames:
                for v in list(root) + [a for r in rot.values() for a in r]:
                    self.assertTrue(math.isfinite(v))

    def test_a_form_with_ears_and_a_cap_tip_has_them_swing_and_one_without_does_not(self):
        body = body_of("redcap")
        clip = gm.gait_clip(body, "walk", 0.6, 0.5)
        ears = [rot["ear_n"][1] for rot, _ in clip.frames]
        self.assertGreater(max(ears) - min(ears), 3.0, "an ear moves a pixel or two")

    def test_the_loops_are_loops_and_the_actions_are_not(self):
        body = body_of("redcap")
        self.assertTrue(gm.idle_clip(body).loop)
        self.assertTrue(gm.gait_clip(body, "run", 0.4, 0.8).loop)
        self.assertFalse(gm.attack_clip(body).loop)
        self.assertTrue(gm.die_clip(body).grounded)
        self.assertFalse(gm.attack_clip(body).grounded)


if __name__ == "__main__":
    unittest.main()


# ---- the wolf-men: the same motion with another skeleton, a digitigrade foot (its sole is a toe pad ahead of the ankle) and the werewolf posture ----
def werewolf(**overrides):
    import werewolf_skeleton as ws
    form = dict(forms.FORMS["goblin"], **overrides)
    skel = ws.skeleton()
    return gm.Body(skel, {"n": (0.27, -0.18, 0.17), "f": (0.27, -0.18, 0.17)}, form, present=set(skel.rest), posture="werewolf")


class WerewolfTest(unittest.TestCase):
    def test_it_hunches_far_forward_and_stands_on_its_toes(self):
        body = werewolf()
        rot, root = gm.idle_pose(body, 0.0)
        posed = body.skel.pose(rot, root)
        self.assertTrue(30.0 < 180.0 - posed["spine"][2] < 46.0)
        for s in "nf":
            heel, toe = body.legs[s].sole(posed)
            self.assertAlmostEqual(heel[1], 0.0, places=6)
            self.assertAlmostEqual(toe[1], 0.0, places=6)
            self.assertGreater(body.legs[s].ankle_of(posed)[1], 0.2, "the ankle is high above the ground")

    def test_its_planted_foot_does_not_slide_in_a_walk_and_a_run_and_it_reaches_at_every_speed(self):
        body = werewolf()
        a, b = anim.ROLL
        worst = 0.0
        for gait in ("walk", "run"):
            g = body.gaits[gait]
            for speed in (15.0, 54.0, 110.0, 220.0):
                s = speed * (1.9 if gait == "run" else 1.0)
                cycle, stride = gm.plan_gait(body, gait, s, 26.0)
                heels = []
                for k in range(120):
                    t = k / 120.0
                    rot, root = gm.gait_pose(body, gait, t, stride)
                    posed = body.skel.pose(rot, root)
                    leg = body.legs["n"]
                    x, z, _, _ = anim.foot_pose(t, stride, g["duty"], g["lift"] * body.L, leg.heel, leg.toe, leg.ankle_h)
                    ankle = leg.ankle_of(posed)
                    worst = max(worst, math.hypot(ankle[0] - (body.hip[0] + x), ankle[1] - z))
                    if (a + 0.05) * g["duty"] < t < (b - 0.05) * g["duty"]:
                        heels.append((t, leg.sole(posed)[0][0]))
                slopes = [(q[1] - p[1]) / (q[0] - p[0]) for p, q in zip(heels, heels[1:])]
                self.assertAlmostEqual(sum(slopes) / len(slopes), -stride / g["duty"], delta=0.03 * stride / g["duty"], msg="%s %s" % (gait, speed))
        self.assertLess(worst, 0.004)

    def test_its_jaw_opens_for_a_blow_and_a_death_and_its_tail_follows_the_body(self):
        body = werewolf()
        self.assertGreater(max(gm.attack_pose(body, t)[0]["jaw"][1] for t, _ in gm.attack_frames(body)[0]), 15.0)
        self.assertEqual(gm.attack_pose(body, gm.attack_frames(body)[0][-1][0])[0]["jaw"][1], 0.0, "closed again")
        self.assertGreater(gm.hurt_pose(body, 0.10)[0]["jaw"][1], 15.0)
        self.assertGreater(gm.die_pose(body, 0.3)[0]["jaw"][1], 10.0)
        clip = gm.gait_clip(body, "walk", 0.8, 0.7)
        tail = [rot["tail2"][1] for rot, _ in clip.frames]
        self.assertGreater(max(tail) - min(tail), 1.5)

    def test_a_goblin_has_no_jaw_to_open(self):
        body = body_of("redcap")
        self.assertNotIn("jaw", gm.attack_pose(body, 0.35)[0])
