"""How a four-legged canine moves (quad_motion.py), checked on a flat copy of its skeleton: pure Python. Paws are measured where they touch the
ground, so these fail when a paw skates, floats or sinks, whatever the angles say."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import quad_motion as qm  # noqa: E402
import quad_skeleton as qs  # noqa: E402

FEET = {"fn": (0.16, 0.0, 0.12), "ff": (0.16, 0.0, 0.12), "hn": (0.20, 0.0, 0.10), "hf": (0.20, 0.0, 0.10)}
STRIDES = {"walk": 0.5, "trot": 0.6, "gallop": 0.5}


def body_of(**proportions):
    return qm.QuadBody(qs.skeleton(**proportions), FEET, {}, present=set(qs.skeleton(**proportions).rest))


def low(body, key, rot, root):
    return min(p[1] for p in body.legs[key].sole(body.skel.pose(rot, root)))


def down_paws(body, rot, root, tol=0.001):
    return {k for k in body.legs if low(body, k, rot, root) < tol}


def anim_roll():
    return qm.anim.ROLL


class SkeletonTest(unittest.TestCase):
    def test_it_has_the_trunk_the_head_a_jaw_ears_a_tail_and_four_three_bone_legs(self):
        s = qs.skeleton()
        for b in ("hips", "spine", "neck", "head", "jaw", "tail1", "tail2", "tail3", "ear_n", "ear_f"):
            self.assertIn(b, s.rest)
        for side in "nf":
            for b in ("sho_", "fore_", "paw_", "thigh_", "shin_", "meta_"):
                self.assertIn(b + side, s.rest)

    def test_a_longer_legged_hound_stands_taller_and_a_stocky_wolf_lower(self):
        tall, plain, stocky = (qs.skeleton(leg=k).rest["hips"][0][1] for k in (1.3, 1.0, 0.85))
        self.assertGreater(tall, plain + 0.1)
        self.assertLess(stocky, plain - 0.05)

    def test_every_paw_stands_on_the_ground_at_rest(self):
        for leg in (0.85, 1.0, 1.3):
            s = qs.skeleton(leg=leg)
            for side in "nf":
                self.assertAlmostEqual(s.rest["paw_" + side][1][1], 0.03 * leg, places=6)
                self.assertAlmostEqual(s.rest["meta_" + side][1][1], 0.03 * leg, places=6)


class IdleTest(unittest.TestCase):
    def test_all_four_paws_stay_where_they_stand_through_the_loop(self):
        body = body_of()
        first = {k: body.legs[k].contact(body.skel.pose(*qm.idle_pose(body, 0.0))) for k in body.legs}
        for i in range(qm.IDLE_FRAMES):
            rot, root = qm.idle_pose(body, i / qm.IDLE_FRAMES)
            posed = body.skel.pose(rot, root)
            for k in body.legs:
                self.assertAlmostEqual(low(body, k, rot, root), 0.0, places=6, msg=k)
                self.assertAlmostEqual(body.legs[k].contact(posed), first[k], places=6, msg=k)

    def test_it_breathes_a_little(self):
        body = body_of()
        ys = [body.skel.pose(*qm.idle_pose(body, i / 16.0))["spine"][1][1] for i in range(16)]
        self.assertGreater(max(ys) - min(ys), 0.004)
        self.assertLess(max(ys) - min(ys), 0.04)


class JointsTest(unittest.TestCase):
    def side(self, joint, a, b):
        """Negative when `joint` is in front of (the +x side of) a line that runs downwards from a to b, positive when it is behind."""
        return (b[1] - a[1]) * (joint[0] - a[0]) - (b[0] - a[0]) * (joint[1] - a[1])

    def test_the_elbows_point_back_and_the_stifles_point_forward_in_every_gait(self):
        body = body_of()
        for gait in qm.GAITS:
            for k in range(0, 40):
                rot, root = qm.gait_pose(body, gait, k / 40.0, STRIDES[gait])
                posed = body.skel.pose(rot, root)
                for s in "nf":
                    elbow, hip, wrist = posed["fore_" + s][0], posed["sho_" + s][0], posed["paw_" + s][0]
                    stifle, thigh, hock = posed["shin_" + s][0], posed["thigh_" + s][0], posed["meta_" + s][0]
                    self.assertGreaterEqual(self.side(elbow, hip, wrist), -1e-9, "%s elbow %s t=%d" % (gait, s, k))
                    self.assertLessEqual(self.side(stifle, thigh, hock), 1e-9, "%s stifle %s t=%d" % (gait, s, k))


class GaitTest(unittest.TestCase):
    SAMPLES = 240

    def poses(self, body, gait):
        return [(k / self.SAMPLES, qm.gait_pose(body, gait, k / self.SAMPLES, STRIDES[gait])) for k in range(self.SAMPLES)]

    def test_no_paw_goes_through_the_ground_and_a_swinging_paw_clears_it(self):
        for gait in qm.GAITS:
            body = body_of()
            clear = {k: 0.0 for k in body.legs}
            for t, (rot, root) in self.poses(body, gait):
                for k in body.legs:
                    z = low(body, k, rot, root)
                    self.assertGreaterEqual(z, -1e-6, "%s %s t=%.2f" % (gait, k, t))
                    clear[k] = max(clear[k], z)
            for k, c in clear.items():
                self.assertGreater(c, 0.03, "%s %s lifts" % (gait, k))

    def test_a_planted_paw_lies_flat_and_moves_back_at_one_speed_through_the_middle_of_its_stance(self):
        a, b = anim_roll()
        for gait in qm.GAITS:
            body = body_of()
            duty = qm.GAITS[gait]["duty"]
            for k, leg in body.legs.items():
                lag = qm.GAITS[gait]["phase"][k]
                xs = []
                for t, (rot, root) in self.poses(body, gait):
                    u = (t - lag) % 1.0
                    if (a + 0.04) * duty < u < (b - 0.04) * duty:
                        heel, toe = leg.sole(body.skel.pose(rot, root))
                        self.assertAlmostEqual(heel[1], 0.0, places=6, msg="%s %s flat" % (gait, k))
                        self.assertAlmostEqual(toe[1], 0.0, places=6, msg="%s %s flat" % (gait, k))
                        xs.append((u, heel[0]))
                slopes = [(q[1] - p[1]) / (q[0] - p[0]) for p, q in zip(xs, xs[1:])]
                self.assertAlmostEqual(sum(slopes) / len(slopes), -STRIDES[gait] / duty, delta=0.03, msg="%s %s" % (gait, k))
                self.assertLess(max(slopes) - min(slopes), 0.1 * STRIDES[gait] / duty, "%s %s: constant speed" % (gait, k))

    def test_a_walk_is_four_beats_a_quarter_cycle_apart_with_two_or_more_paws_always_down(self):
        body = body_of()
        landings = {}
        before = (1.0 - 1.0 / self.SAMPLES, qm.gait_pose(body, "walk", 1.0 - 1.0 / self.SAMPLES, STRIDES["walk"]))
        previous = down_paws(body, *before[1])
        counts = []
        for t, (rot, root) in self.poses(body, "walk"):
            now = down_paws(body, rot, root)
            counts.append(len(now))
            for k in now - previous:
                landings.setdefault(k, t)
            previous = now
        start = landings["hn"]
        order = sorted(landings, key=lambda k: (landings[k] - start) % 1.0)
        self.assertEqual(order, ["hn", "fn", "hf", "ff"], "hind near, fore near, hind far, fore far")
        self.assertGreaterEqual(min(counts), 2)

    def test_a_trot_puts_diagonal_pairs_down_together_and_a_gallop_hangs_in_the_air(self):
        body = body_of()
        for t, (rot, root) in self.poses(body, "trot"):
            down = down_paws(body, rot, root)
            self.assertEqual(("fn" in down) == ("hf" in down) or abs(t % 0.5) < 0.1 or abs(t % 0.5 - 0.5) < 0.1, True)
        flights = [t for t, (rot, root) in self.poses(body, "gallop") if not down_paws(body, rot, root)]
        self.assertGreater(len(flights), 0.04 * self.SAMPLES, "all four paws are off the ground for a while")

    def test_the_trunk_rises_and_falls_as_the_legs_close_and_spread(self):
        body = body_of()
        zs = [root[2] for _, (_, root) in self.poses(body, "walk")]
        self.assertGreater(max(zs) - min(zs), 0.02)
        self.assertLess(max(zs) - min(zs), 0.18)

    def test_the_loop_closes(self):
        body = body_of()
        a, b = qm.gait_pose(body, "trot", 0.0, 0.6), qm.gait_pose(body, "trot", 1.0 - 1e-9, 0.6)
        for bone in a[0]:
            self.assertAlmostEqual(a[0][bone][1], b[0][bone][1], delta=0.01, msg=bone)


class ActionTest(unittest.TestCase):
    def test_the_lunge_springs_forward_off_planted_hind_paws_with_its_jaws_opening_then_snapping_shut(self):
        body = body_of()
        frames = [qm.attack_pose(body, t) for t, _ in qm.FRAMES]
        for rot, root in frames:
            for k in ("hn", "hf"):
                self.assertAlmostEqual(low(body, k, rot, root), 0.0, places=6)
        contacts = [body.legs["hn"].contact(body.skel.pose(*f)) for f in frames]
        self.assertLess(max(contacts) - min(contacts), 0.02, "the hind paws do not slide")
        heads = [body.skel.pose(*f)["head"][1][0] for f in frames]
        self.assertGreater(max(heads) - heads[0], 0.4 * body.L["f"], "the head goes well ahead")
        jaws = [qm.anim.sample(qm.ATTACKS["bite"]["jaw"], t) for t, _ in qm.FRAMES]
        self.assertGreater(max(jaws), 20.0)
        self.assertLess(jaws[qm.WINDUP], 8.0, "snapped shut on the impact frame")

    def test_the_windup_sinks_back_with_the_head_low_before_the_spring(self):
        body = body_of()
        rest = body.skel.pose(*qm.idle_pose(body, 0.0))
        wound = body.skel.pose(*qm.attack_pose(body, qm.T_HOLD - 0.01))
        self.assertLess(wound["head"][1][1], rest["head"][1][1] - 0.06)
        self.assertLess(wound["head"][1][0], rest["head"][1][0] + 0.01)

    def test_a_blow_throws_the_head_up_and_back_with_the_paws_planted(self):
        body = body_of()
        rest = body.skel.pose(*qm.idle_pose(body, 0.0))
        for t, _ in qm.HURT_FRAMES:
            rot, root = qm.hurt_pose(body, t)
            for k in body.legs:
                self.assertAlmostEqual(low(body, k, rot, root), 0.0, places=6)
        peak = body.skel.pose(*qm.hurt_pose(body, 0.10))
        self.assertGreater(peak["head"][1][1], rest["head"][1][1] + 0.05)

    def test_it_falls_and_ends_lying_flat_with_its_legs_stretched_out(self):
        body = body_of()
        posed = body.skel.pose(*qm.die_pose(body, qm.DIE_FRAMES[-1][0]))
        self.assertAlmostEqual(posed["spine"][2], 90.0, delta=6.0)
        core = [p for n, p in posed.items() if not n.startswith(("ear", "tail"))]
        self.assertLess(max(max(p[0][1], p[1][1]) for p in core) - min(min(p[0][1], p[1][1]) for p in core), 0.35)
        self.assertLess(posed["meta_n"][1][0], posed["hips"][0][0], "the hind legs are stretched behind")
        self.assertGreater(posed["paw_n"][1][0], posed["spine"][1][0] - 0.05, "the forelegs are stretched ahead")


class AttackKindsTest(unittest.TestCase):
    def test_every_kind_keeps_its_hind_paws_down_through_the_blow_ends_at_rest_and_comes_up_with_the_engines_timing(self):
        for kind in qm.ATTACKS:
            body = qm.QuadBody(qs.skeleton(), FEET, {"attack": kind})
            idle, _ = qm.idle_pose(body, 0.0)
            frames = [qm.attack_pose(body, t) for t, _ in qm.FRAMES]
            for rot, root in frames:
                for k in ("hn", "hf"):
                    self.assertGreaterEqual(low(body, k, rot, root), -1e-6, kind)
                for r in (rot,):
                    for bone in ("spine", "neck", "head"):
                        self.assertTrue(math.isfinite(r[bone][1]))
            for bone in ("spine", "neck", "head", "thigh_n", "sho_n"):
                self.assertAlmostEqual(frames[-1][0][bone][1], idle[bone][1], delta=1.5, msg="%s %s" % (kind, bone))
            self.assertAlmostEqual(sum(d for _, d in qm.FRAMES[:qm.WINDUP]), qm.ENGINE_WINDUP, places=9)

    def test_a_roar_throws_the_head_up_a_slam_rears_the_forepaws_and_a_guard_drops_the_body(self):
        def at(kind, t):
            body = qm.QuadBody(qs.skeleton(), FEET, {"attack": kind})
            return body, body.skel.pose(*qm.attack_pose(body, t))
        body, rest = at("bite", 0.0)
        _, roar = at("roar", qm.T_HIT)
        self.assertGreater(roar["head"][1][1], rest["head"][1][1] + 0.08)
        _, rear = at("slam", qm.T_HOLD - 0.01)
        self.assertGreater(rear["paw_n"][1][1], 0.2, "the forepaws are well off the ground")
        _, slammed = at("slam", qm.T_HIT)
        self.assertLess(slammed["paw_n"][1][1], 0.06, "and come down")
        _, crouch = at("guard", qm.T_HIT)
        self.assertLess(crouch["spine"][1][1], rest["spine"][1][1] - 0.04)

    def test_an_unknown_kind_is_a_bite(self):
        self.assertEqual(qm.attack_kind({"attack": "nonsense"}), "bite")
        self.assertEqual(qm.attack_kind({}), "bite")


class TimingTest(unittest.TestCase):
    def test_the_windup_and_recovery_frames_last_what_the_engines_verb_states_do_and_the_flinch_its_flinch(self):
        self.assertAlmostEqual(sum(d for _, d in qm.FRAMES[:qm.WINDUP]), qm.ENGINE_WINDUP, places=9)
        self.assertAlmostEqual(sum(d for _, d in qm.FRAMES[qm.WINDUP:]), qm.ENGINE_RECOVER, places=9)
        self.assertAlmostEqual(sum(d for _, d in qm.HURT_FRAMES), qm.ENGINE_HURT, places=9)

    def test_the_last_frames_are_the_rest_pose_the_next_clip_starts_from(self):
        body = body_of()
        idle, _ = qm.idle_pose(body, 0.0)
        for rot in (qm.attack_pose(body, qm.FRAMES[-1][0])[0], qm.hurt_pose(body, qm.HURT_FRAMES[-1][0])[0]):
            for bone in ("spine", "neck", "head", "thigh_n", "sho_n"):
                self.assertAlmostEqual(rot[bone][1], idle[bone][1], delta=1.5, msg=bone)


class GallopTest(unittest.TestCase):
    def poses(self, body, n=160):
        return [(k / float(n), qm.gait_pose(body, "gallop", k / float(n), 0.5)) for k in range(n)]

    def test_the_body_rises_in_the_suspension_and_a_paw_that_is_down_is_never_lifted_with_it(self):
        body = body_of()
        g = qm.GAITS["gallop"]
        standing = qm.idle_pose(body, 0.0)[1][2]
        airborne = 0
        for t, (rot, root) in self.poses(body):
            down = [k for k in body.legs if low(body, k, rot, root) < 1e-6]
            planted = [k for k in body.legs if ((t - g["phase"][k]) % 1.0) < g["duty"] - 0.04]   # well inside its stance
            for k in planted:
                self.assertAlmostEqual(low(body, k, rot, root), 0.0, places=6, msg="%s is planted at t=%.3f" % (k, t))
            if not down:
                airborne += 1
                self.assertGreater(root[2], standing - 0.02, "the body is not sunk while it flies")
        self.assertGreater(airborne, 8, "there is a real suspension")
        flying = [root[2] for t, (rot, root) in self.poses(body) if not [k for k in body.legs if low(body, k, rot, root) < 1e-6]]
        grounded = [root[2] for t, (rot, root) in self.poses(body) if [k for k in body.legs if low(body, k, rot, root) < 1e-6]]
        self.assertGreater(max(flying), max(grounded) + 0.01, "it is higher in the air than with a paw down")


class GlideTest(unittest.TestCase):
    def test_a_flier_is_off_the_ground_in_every_frame_with_its_forelegs_ahead_and_its_hind_legs_and_tail_trailing(self):
        body = body_of()
        rest = body.skel.pose(*qm.idle_pose(body, 0.0))
        for kind in qm.GLIDE:
            clip = qm.glide_clip(body, kind)
            self.assertTrue(clip.loop and not clip.grounded)
            self.assertEqual(len(clip.frames), qm.GLIDE[kind]["frames"])
            for rot, root in clip.frames:
                posed = body.skel.pose(rot, root)
                self.assertGreater(min(low(body, k, rot, root) for k in body.legs), 0.03 * body.H, "%s: every paw is off the ground" % kind)
                self.assertGreater(posed["paw_n"][1][0], posed["sho_n"][0][0], "the forepaw is ahead of the shoulder")
                self.assertLess(posed["meta_n"][1][0], posed["thigh_n"][0][0], "the hind paw trails behind the hip")

    def test_flying_is_higher_than_hovering_and_the_loop_closes(self):
        body = body_of()
        height = lambda kind: sum(qm.glide_pose(body, kind, k / 10.0)[1][2] for k in range(10)) / 10.0
        self.assertGreater(height("fly"), height("hover") + 0.03)
        a, b = qm.glide_pose(body, "fly", 0.0), qm.glide_pose(body, "fly", 1.0 - 1e-9)
        for bone in a[0]:
            self.assertAlmostEqual(a[0][bone][1], b[0][bone][1], delta=0.01, msg=bone)


class JawTest(unittest.TestCase):
    def test_an_open_jaw_points_further_down_than_a_closed_one_in_the_bite_the_flinch_and_the_death(self):
        body = body_of()
        closed = body.skel.pose(*qm.idle_pose(body, 0.0))
        gap = lambda posed: posed["head"][2] - posed["jaw"][2]
        self.assertAlmostEqual(gap(closed), 12.0, delta=0.5)
        self.assertGreater(gap(body.skel.pose(*qm.attack_pose(body, qm.T_MID))), 12.0 + 15.0, "wide open as it springs")
        self.assertLess(gap(body.skel.pose(*qm.attack_pose(body, qm.T_HIT))), 12.0 + 10.0, "snapped shut on the impact")
        self.assertGreater(gap(body.skel.pose(*qm.hurt_pose(body, 0.10))), 12.0 + 15.0, "a yelp")
        self.assertAlmostEqual(gap(body.skel.pose(*qm.die_pose(body, 0.0))), 12.0, delta=1.0, msg="the death starts closed")


class KeysTest(unittest.TestCase):
    def test_every_key_table_is_in_time_order_and_never_jumps_between_neighbouring_keys(self):
        tables = [("bite " + k, v) for kind in qm.ATTACKS for k, v in qm.ATTACKS[kind].items()] + [("hurt " + k, v) for k, v in qm.HURT.items()]
        for name, keys in tables:
            times = [t for t, _, _ in keys]
            self.assertEqual(times, sorted(times), name)
            self.assertEqual(len(set(times)), len(times), name)
        times = [t for t, _ in qm.DIE_FRAMES]
        for channel, values in qm.DIE_KEYS.items():
            self.assertEqual(len(values), len(times), channel)


class TailTest(unittest.TestCase):
    def test_the_tail_never_hangs_below_the_floor_in_any_frame_of_any_clip(self):
        body = body_of()
        clips = [qm.idle_clip(body), qm.gait_clip(body, "walk", 0.8, 0.5), qm.gait_clip(body, "trot", 0.5, 0.6), qm.gait_clip(body, "gallop", 0.4, 0.5),
                 qm.attack_clip(body), qm.hurt_clip(body)]
        for clip in clips:
            for rot, root in clip.frames:
                posed = body.skel.pose(rot, root)
                for b in ("tail1", "tail2", "tail3"):
                    self.assertGreaterEqual(posed[b][1][1], 0.0, b)


class PlanTest(unittest.TestCase):
    def test_a_slow_creature_walks_a_quick_one_trots_and_the_stride_is_never_longer_than_the_legs_reach(self):
        body = body_of()
        self.assertEqual(qm.walking_gait(body, 20.0, 26.0), "walk")
        self.assertEqual(qm.walking_gait(body, 90.0, 26.0), "trot")
        for gait in qm.GAITS:
            g = qm.GAITS[gait]
            for speed in (15.0, 40.0, 70.0, 110.0, 200.0):
                cycle, stride = qm.plan_gait(body, gait, speed, 26.0)
                self.assertLessEqual(stride, g["max_stride"] * body.H + 1e-9, "%s %s" % (gait, speed))
                self.assertGreater(cycle, 0.0)

    def test_every_planned_paw_reaches_its_target(self):
        worst = 0.0
        body = body_of()
        for gait in qm.GAITS:
            g = qm.GAITS[gait]
            for speed in (15.0, 60.0, 130.0, 260.0):
                cycle, stride = qm.plan_gait(body, gait, speed, 26.0)
                for k in range(24):
                    t = k / 24.0
                    rot, root = qm.gait_pose(body, gait, t, stride)
                    posed = body.skel.pose(rot, root)
                    targets, _ = qm.gait_targets(body, gait, t, stride)
                    for key, leg in body.legs.items():
                        ankle = leg.ankle_of(posed)
                        worst = max(worst, ((ankle[0] - targets[key][0]) ** 2 + (ankle[1] - targets[key][1]) ** 2) ** 0.5)
        self.assertLess(worst, 0.004)


class ClipTest(unittest.TestCase):
    def test_every_clip_is_finite_and_has_a_duration_per_frame_and_the_tail_and_ears_move(self):
        body = body_of()
        clips = [qm.idle_clip(body), qm.gait_clip(body, "walk", 0.8, 0.5), qm.gait_clip(body, "trot", 0.5, 0.6), qm.gait_clip(body, "gallop", 0.4, 0.5),
                 qm.attack_clip(body), qm.hurt_clip(body), qm.die_clip(body)]
        for clip in clips:
            self.assertEqual(len(clip.frames), len(clip.durations))
            for rot, root in clip.frames:
                for v in list(root) + [a for r in rot.values() for a in r]:
                    self.assertTrue(math.isfinite(v))
        for bone, least in (("tail1", 4.0), ("tail3", 2.0)):
            swing = [rot[bone][1] for rot, _ in clips[2].frames]
            self.assertGreater(max(swing) - min(swing), least, bone)
        self.assertTrue(clips[1].loop and not clips[4].loop and clips[6].grounded)


if __name__ == "__main__":
    unittest.main()
