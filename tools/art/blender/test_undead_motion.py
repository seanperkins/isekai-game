"""How the undead move (undead_motion.py on biped_motion.py), checked on flat copies of their skeletons: pure Python. Feet are measured where they
touch the ground, so these fail when a foot skates, floats or sinks, whatever the angles say; a floater is measured by its lowest point."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim  # noqa: E402
import biped_motion as bm  # noqa: E402
import export_forms  # noqa: E402
import undead_forms as forms  # noqa: E402
import undead_motion as um  # noqa: E402
import undead_skeleton as us  # noqa: E402

PAD = 0.04           # how far a floater's meshes reach below its lowest bone, in these tests (creatures/undead.py measures it)
PX = 0.04            # about a game pixel in model units


def body_of(name="skeleton", **overrides):
    form = dict(forms.FORMS[name], **overrides)
    skel = us.skeleton(form)
    if form["body"] in ("candle", "ghost", "skull"):
        low = min(min(h[1], t[1]) for h, t, _ in skel.rest.values()) - PAD
        return um.FloatBody(skel, form, low)
    return um.biped_body(skel, us.feet(form), form)


def sole(body, side, rot, root):
    return body.legs[side].sole(body.skel.pose(rot, root))


def lowest(body, rot, root):
    return min(min(h[1], t[1]) for h, t, _ in body.skel.pose(rot, root).values())


def clips(body):
    return um.clips(body, 40.0, 26.0)


class PostureTest(unittest.TestCase):
    def lean(self, name):
        body = body_of(name)
        return 180.0 - body.skel.pose(*bm.idle_pose(body, 0.0))["spine"][2]

    def test_a_skeleton_stands_nearly_upright_on_long_legs_and_a_zombie_and_a_ghoul_hunch(self):
        self.assertLess(self.lean("skeleton"), 14.0)
        self.assertGreater(self.lean("zombie"), self.lean("skeleton") + 8.0)
        self.assertGreater(self.lean("ghoul"), self.lean("zombie") + 6.0)

    def test_the_hips_of_an_upright_undead_stand_higher_over_their_feet_than_a_goblins(self):
        body = body_of("skeleton")
        posed = body.skel.pose(*bm.idle_pose(body, 0.0))
        self.assertGreater((posed["hips"][0][1] - posed["shin_n"][1][1]) / body.L, 0.86)

    def test_every_form_has_a_posture_and_an_attack_that_exist(self):
        for name, form in forms.FORMS.items():
            self.assertIn(form["posture"], dict(um.POSTURES, float=None), name)
            kind = um.attack_kind(form)
            self.assertTrue(kind in um.KINDS or kind == "shoot" or kind in um.FLOAT_ATTACKS, "%s: %s" % (name, kind))
            if form.get("arms"):
                self.assertIn(form["arms"], bm.ARMS, name)

    def test_the_tree_is_the_game_tree(self):
        self.assertEqual(len(forms.FORMS), 30)
        for name, form in forms.FORMS.items():
            if form["parent"]:
                self.assertIn(form["parent"], forms.FORMS, name)
                self.assertEqual(form["stage"], forms.FORMS[form["parent"]]["stage"] + 1 if form["parent"] != "skeleton" else 2, name)


class IdleTest(unittest.TestCase):
    def test_both_feet_stay_planted_through_every_biped_idle(self):
        for name in forms.BIPEDS:
            body = body_of(name)
            first = {s: sole(body, s, *bm.idle_pose(body, 0.0)) for s in "nf"}
            for i in range(bm.IDLE_FRAMES):
                for s in "nf":
                    heel, toe = sole(body, s, *bm.idle_pose(body, i / bm.IDLE_FRAMES))
                    self.assertAlmostEqual(toe[0], first[s][1][0], places=6, msg=name)
                    if body.stance.get("feet", {}).get(s, (0, 0, 0))[1] == 0.0:
                        self.assertAlmostEqual(min(heel[1], toe[1]), 0.0, places=6, msg=name)


class GaitTest(unittest.TestCase):
    SAMPLES = 120

    def test_a_planted_foot_moves_back_at_one_speed_in_every_upright_and_heavy_gait(self):
        a, b = anim.ROLL
        for name in ("skeleton", "zombie", "ghoul", "bone_colossus", "lich"):
            body = body_of(name)
            for gait in ("walk", "run"):
                duty, stride = body.gaits[gait]["duty"], 0.5 * body.L
                xs = []
                for k in range(self.SAMPLES):
                    t = k / self.SAMPLES
                    if (a + 0.04) * duty < t < (b - 0.04) * duty:
                        heel, toe = sole(body, "n", *bm.gait_pose(body, gait, t, stride))
                        self.assertAlmostEqual(heel[1], 0.0, places=6, msg="%s %s" % (name, gait))
                        xs.append((t, heel[0]))
                slopes = [(q[1] - p[1]) / (q[0] - p[0]) for p, q in zip(xs, xs[1:])]
                for s in slopes:
                    self.assertAlmostEqual(s, -stride / duty, delta=0.02 * stride / duty, msg="%s %s" % (name, gait))

    def test_the_zombie_walks_slower_lower_and_pitching_more_than_the_skeleton(self):
        sk, zo = body_of("skeleton"), body_of("zombie")
        self.assertGreater(zo.gaits["walk"]["lean_amp"], sk.gaits["walk"]["lean_amp"] * 2)
        self.assertGreater(zo.gaits["walk"]["bob"], sk.gaits["walk"]["bob"])
        self.assertLess(zo.gaits["walk"]["lift"], sk.gaits["walk"]["lift"])


class ReachTest(unittest.TestCase):
    def test_every_foot_reaches_where_its_gait_puts_it_at_every_speed_and_scale_a_form_can_have(self):
        worst, where = 0.0, None
        for name in forms.BIPEDS:
            body = body_of(name)
            for gait in ("walk", "run"):
                g = body.gaits[um.gait_name(body, gait)]
                for speed in (12.0, 30.0, 54.0, 80.0, 130.0):
                    for ppu in (16.0, 24.0, 34.0):
                        s = speed * (um.RUN_SPEED if gait == "run" else 1.0)
                        cycle, stride = um.plan_gait(body, gait, s, ppu)
                        self.assertLessEqual(stride, g["max_stride"] * body.L + 1e-9)
                        for k in range(20):
                            t = k / 20.0
                            if body.form["body"] == "hop":
                                rot, root = um.hop_pose(body, gait, t, stride)
                                posed = body.skel.pose(rot, root)
                                for side in "nf":
                                    x, z = um.hop_feet_x(body, gait, t, stride, side)
                                    ankle = body.legs[side].ankle_of(posed)
                                    err = math.hypot(ankle[0] - (body.hip[0] + x), ankle[1] - z)
                                    if err > worst:
                                        worst, where = err, (name, gait, speed, ppu, t)
                                continue
                            rot, root = bm.gait_pose(body, gait, t, stride)
                            posed = body.skel.pose(rot, root)
                            for side, phase in (("n", 0.0), ("f", 0.5)):
                                leg = body.legs[side]
                                x, z, _, _ = anim.foot_pose(t + phase, stride, g["duty"], g["lift"] * body.L, leg.heel, leg.toe, leg.ankle_h)
                                ankle = leg.ankle_of(posed)
                                err = math.hypot(ankle[0] - (body.hip[0] + x), ankle[1] - z)
                                if err > worst:
                                    worst, where = err, (name, gait, speed, ppu, t)
        self.assertLess(worst, 0.004, "a foot falls %.4f short at %s" % (worst, where))


class HopTest(unittest.TestCase):
    STRIDE, SAMPLES = 0.4, 200

    def poses(self, body, gait):
        stride = self.STRIDE * body.L
        return stride, [(k / self.SAMPLES, um.hop_pose(body, gait, k / self.SAMPLES, stride)) for k in range(self.SAMPLES)]

    def test_a_jiangshi_hops_with_both_feet_together_and_spends_part_of_every_cycle_in_the_air(self):
        body = body_of("jiangshi")
        for gait in ("walk", "run"):
            _, poses = self.poses(body, gait)
            air = [t for t, p in poses if min(min(sole(body, s, *p)[0][1], sole(body, s, *p)[1][1]) for s in "nf") > 0.01]
            self.assertGreater(len(air) / self.SAMPLES, 0.2, "%s: airtime" % gait)
            for t, p in poses:
                self.assertLess(abs(sole(body, "n", *p)[1][0] - sole(body, "f", *p)[1][0]), 0.06 * body.L, "the feet stay together")
            down = [t for t, p in poses if max(sole(body, "n", *p)[0][1], sole(body, "n", *p)[1][1]) < 1e-6]
            self.assertTrue(down, "and part of it with both feet flat on the ground")

    def test_a_landed_hop_does_not_slide_the_soles_move_back_with_the_ground(self):
        body = body_of("jiangshi")
        a, b = anim.ROLL
        for gait in ("walk", "run"):
            stride, poses = self.poses(body, gait)
            duty = um.HOPS[gait]["duty"]
            heels = [(t, sole(body, "n", *p)[0]) for t, p in poses if 0.02 * duty < t < a * duty]
            flats = [(t, sole(body, "f", *p)[0]) for t, p in poses if (a + 0.04) * duty < t < (b - 0.04) * duty]
            for pts in (heels, flats):
                for (t0, p0), (t1, p1) in zip(pts, pts[1:]):
                    self.assertAlmostEqual((p1[0] - p0[0]) / (t1 - t0), -stride / duty, delta=0.02 * stride / duty, msg=gait)
                    self.assertAlmostEqual(p1[1], 0.0, places=6)

    def test_the_body_rises_through_the_air_and_the_hop_loops(self):
        body = body_of("jiangshi")
        stride, poses = self.poses(body, "walk")
        zs = [p[1][2] for _, p in poses]
        self.assertGreater(max(zs) - min(zs), 0.12 * body.L)
        a, b = um.hop_pose(body, "walk", 0.0, stride), um.hop_pose(body, "walk", 1.0 - 1e-9, stride)
        for bone in a[0]:
            self.assertAlmostEqual(a[0][bone][1], b[0][bone][1], delta=0.05, msg=bone)


class FloatTest(unittest.TestCase):
    def test_a_floater_never_touches_the_ground_and_bobs(self):
        for name in forms.FLOATERS:
            body = body_of(name)
            for clip_name, clip in clips(body).items():
                if clip_name == "die":
                    continue
                for rot, root in clip.frames:
                    self.assertGreater(lowest(body, rot, root) - PAD, 0.4 * body.hover, "%s %s floats" % (name, clip_name))
            zs = [root[2] for _, root in um.idle_clip(body).frames]
            self.assertGreater(max(zs) - min(zs), 0.03 * body.size, name)

    def test_a_floater_drifting_leans_into_it_and_its_hangings_trail(self):
        body = body_of("banshee")
        walk = um.gait_clip(body, "walk", *um.plan_gait(body, "walk", 40.0, 26.0))
        idle = um.idle_clip(body)
        tilt = lambda clip: sum(180.0 - body.skel.pose(*f)["spine"][2] for f in clip.frames) / len(clip.frames)
        self.assertGreater(tilt(walk), tilt(idle) + 6.0)
        strip = lambda clip: sum(body.skel.pose(*f)["strip1b"][2] for f in clip.frames) / len(clip.frames)
        self.assertLess(strip(walk), strip(idle) - 4.0, "the shroud trails back")

    def test_a_floater_dies_on_the_ground(self):
        for name in forms.FLOATERS:
            body = body_of(name)
            clip = um.die_clip(body)
            self.assertTrue(clip.grounded)
            self.assertAlmostEqual(clip.frames[-1][1][2], 0.0, places=6)
            self.assertAlmostEqual(clip.frames[0][1][2], body.hover, delta=0.02 * body.size)


class AttackTest(unittest.TestCase):
    def test_the_windup_lasts_the_engines_windup_ending_with_the_release_and_the_recovery_no_longer_than_its_recover(self):
        for name in forms.FORMS:
            body = body_of(name)
            clip = um.attack_clip(body)
            w = um.windup_of(body)
            self.assertAlmostEqual(sum(clip.durations[:w]), um.ENGINE_WINDUP, places=9, msg=name)
            self.assertLessEqual(sum(clip.durations[w:]), um.ENGINE_RECOVER + 1e-9, name)
            self.assertAlmostEqual(sum(um.hurt_clip(body).durations), um.ENGINE_HURT, places=9, msg=name)

    def test_a_heavy_blow_holds_its_apex_longer_and_swings_quicker(self):
        heavy, normal = um.TIMINGS["heavy"]["frames"], um.TIMINGS["normal"]["frames"]
        self.assertGreater(max(d for _, d in heavy[:5]), max(d for _, d in normal[:5]))
        self.assertLess(min(d for _, d in heavy[:5]), min(d for _, d in normal[:5]))

    def test_the_last_frame_of_an_attack_and_of_a_flinch_is_the_rest_pose(self):
        for name in forms.FORMS:
            body = body_of(name)
            idle = um.idle_clip(body).frames[0]
            for clip in (um.attack_clip(body), um.hurt_clip(body)):
                rot, root = clip.frames[-1]
                a, b = body.skel.pose(*idle), body.skel.pose(rot, root)
                for bone in a:
                    if bone in um.SECONDARY:
                        continue
                    for p, q in zip(a[bone][:2], b[bone][:2]):
                        self.assertLess(math.dist(p, q), 0.6 * PX, "%s %s ends where the idle starts" % (name, bone))

    def test_nothing_goes_below_the_ground_in_any_clip_that_stands(self):
        for name in forms.FORMS:
            body = body_of(name)
            for clip_name, clip in clips(body).items():
                if clip.grounded:
                    continue
                for i, (rot, root) in enumerate(clip.frames):
                    self.assertGreaterEqual(lowest(body, rot, root), -1e-6, "%s %s %d" % (name, clip_name, i))

    def test_the_planted_far_foot_does_not_slide_in_an_attack(self):
        for name in forms.BIPEDS:
            body = body_of(name)
            if um.KINDS.get(um.attack_kind(body.form), {}).get("both_feet"):
                continue
            frames, _ = um.attack_frames(body)
            toes = [sole(body, "f", *um.attack_pose(body, t)[:2])[1] for t, _ in frames]
            for toe in toes:
                self.assertAlmostEqual(toe[0], toes[0][0], delta=0.25 * PX, msg=name)

    def tip(self, body, rot, root, bone, length):
        sk = body.skel
        h, t, _ = sk.rest[bone]
        n = math.hypot(t[0] - h[0], t[1] - h[1])
        return sk.point(bone, (h[0] + (t[0] - h[0]) / n * length, h[1] + (t[1] - h[1]) / n * length), rot, root)

    def test_a_blade_is_raised_behind_the_head_then_ends_well_ahead_of_the_chest(self):
        for name, length in (("bone_warrior", 0.4), ("draugr", 0.8), ("revenant_knight", 0.8)):
            body = body_of(name)
            frames, w = um.attack_frames(body)
            apex = um.attack_pose(body, frames[2][0])[:2]
            hit = um.attack_pose(body, frames[w][0])[:2]
            head = body.skel.pose(*apex)["head"][0]
            tip = self.tip(body, *apex, "item_n", length)
            self.assertGreater(tip[1], head[1], name)
            self.assertLess(tip[0], head[0] + 0.1 * body.L, name)
            chest = body.skel.pose(*hit)["spine"][1]
            self.assertGreater(self.tip(body, *hit, "item_n", length)[0] - chest[0], 0.6 * body.L, name)

    def test_a_skeleton_brings_its_point_down_blade_over_the_top(self):
        body = body_of("skeleton")
        frames, w = um.attack_frames(body)
        sk = body.skel
        dirs = [sk.pose(*um.attack_pose(body, t)[:2])["item_n"][2] % 360.0 for t, _ in frames]
        self.assertTrue(150.0 < dirs[2] < 260.0, "raised: %.0f" % dirs[2])
        self.assertTrue(40.0 < dirs[w] < 120.0, "cutting forward: %.0f" % dirs[w])
        self.assertTrue(dirs[-1] < 25.0 or dirs[-1] > 335.0, "and point down again")

    def test_an_archer_draws_to_its_cheek_with_the_bow_arm_straight_and_looses(self):
        for name in ("skeletal_archer", "deadeye", "arash", "wild_huntsman"):
            body = body_of(name)
            frames, w = um.attack_frames(body)
            sk = body.skel
            full = um.attack_pose(body, frames[3][0])[:2]
            posed = sk.pose(*full)
            cheek = um._cheek(body, posed)
            self.assertLess(math.dist(posed["fore_n"][1], cheek), 0.08 * body.L, name)
            shoulder, grip = posed["arm_f"][0], posed["fore_f"][1]
            self.assertAlmostEqual(math.dist(shoulder, grip), sk.length("arm_f") + sk.length("fore_f"), delta=0.01, msg="the bow arm is straight")
            aim_dir = 90.0 + forms.FORMS[name].get("aim", 0.0)
            self.assertAlmostEqual(posed["arrow"][2], aim_dir, delta=8.0, msg="%s: the arrow points at the target" % name)
            for bone in ("string_u", "string_l"):
                h, t, _ = posed[bone]
                along = ((t[0] - h[0]) * (posed["fore_n"][1][0] - h[0]) + (t[1] - h[1]) * (posed["fore_n"][1][1] - h[1])) / (sk.length(bone) * math.dist(h, posed["fore_n"][1]))
                self.assertGreater(along, 0.99, "%s: the string runs to the hand" % name)
            loosed = sk.pose(*um.attack_pose(body, frames[w][0])[:2])
            self.assertAlmostEqual(loosed["arrow"][2] % 360.0, loosed["item_f"][2] % 360.0, delta=1.0, msg="the arrow is gone: it lies along the bow again")
            self.assertLess(loosed["fore_n"][1][0], posed["fore_n"][1][0], "the drawing hand flies back")

    def test_a_whip_cracks_out_level_ahead_of_the_hand(self):
        body = body_of("dullahan")
        frames, w = um.attack_frames(body)
        hit = um.attack_clip(body).frames[w]
        posed = body.skel.pose(*hit)
        hand = posed["fore_n"][1]
        tip = posed["whip5"][1]
        self.assertGreater(tip[0], hand[0] + 0.3 * body.L)
        rest = body.skel.pose(*um.idle_clip(body).frames[0])
        self.assertLess(rest["whip5"][1][1], rest["fore_n"][1][1] - 0.1 * body.L, "at rest it hangs in a coil below the hand")
        self.assertLess(abs(rest["whip5"][1][0] - rest["fore_n"][1][0]), 0.3 * body.L)

    def test_a_jiangshi_lunges_with_both_feet_and_both_arms(self):
        body = body_of("jiangshi")
        frames, w = um.attack_frames(body)
        hit = um.attack_pose(body, frames[w][0])[:2]
        rest = bm.idle_pose(body, 0.0)
        for s in "nf":
            self.assertGreater(sole(body, s, *hit)[1][0], sole(body, s, *rest)[1][0] + 0.2 * body.L)
        lifted = um.attack_pose(body, frames[4][0])[:2]
        self.assertGreater(min(sole(body, "n", *lifted)[0][1], sole(body, "f", *lifted)[0][1]), 0.02, "both feet leave the ground together")

    def test_a_slam_reaches_down_in_front_and_never_into_the_ground(self):
        body = body_of("barrow_king")
        frames, w = um.attack_frames(body)
        posed = body.skel.pose(*um.attack_pose(body, frames[w][0])[:2])
        self.assertLess(posed["fore_n"][1][1], posed["hips"][0][1] - 0.2 * body.L, "the fists go down below the hips")
        self.assertGreater(posed["fore_n"][1][0], posed["hips"][0][0] + 0.3 * body.L)


class SecondaryTest(unittest.TestCase):
    def test_a_skeletons_jaw_rattles_and_its_rag_swings_as_it_walks(self):
        body = body_of("skeleton")
        clip = um.gait_clip(body, "walk", 0.8, 0.5 * body.L)
        for bone, least in (("jaw", 2.0), ("rag", 3.0)):
            angles = [rot[bone][1] for rot, _ in clip.frames]
            self.assertGreater(max(angles) - min(angles), least, bone)

    def test_a_mummys_bandage_ends_trail_behind_it_when_it_walks(self):
        body = body_of("mummy_priest")
        idle, walk = um.idle_clip(body), um.gait_clip(body, "walk", 0.8, 0.5 * body.L)
        mean = lambda c: sum(body.skel.pose(*f)["band2"][2] for f in c.frames) / len(c.frames)
        self.assertLess(mean(walk), mean(idle) - 5.0)

    def test_a_jaw_opens_in_a_bite(self):
        body = body_of("heart_weigher")
        clip = um.attack_clip(body)
        opened = [rot["jaw"][1] for rot, _ in clip.frames]
        self.assertGreater(max(opened) - opened[0], 25.0)


class TimingTest(unittest.TestCase):
    def test_every_forms_clips_pass_the_engines_timing_check(self):
        constants = export_forms.engine_constants()
        for name in forms.FORMS:
            body = body_of(name)
            c = clips(body)
            meta = {"durations": {k: v.durations for k, v in c.items()}, "windup": um.windup_of(body), "anims": {k: len(v.frames) for k, v in c.items()},
                    "loops": {k: v.loop for k, v in c.items()}}
            export_forms.check_timing(meta, constants)
            export_forms.clips_of(meta)
            self.assertEqual(set(c), {"idle", "walk", "run", "attack", "hurt", "die"})
            for k, v in c.items():
                self.assertEqual(len(v.frames), len(v.durations), "%s %s" % (name, k))
                for rot, root in v.frames:
                    self.assertTrue(all(math.isfinite(x) for r in rot.values() for x in r) and all(math.isfinite(x) for x in root), name)


if __name__ == "__main__":
    unittest.main()
