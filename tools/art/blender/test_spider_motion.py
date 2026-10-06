"""How a spider moves (spider_motion.py), checked on a flat copy of its skeleton for every form of the family: pure Python. Claws are measured where
the posed skeleton puts them (the tarsus's end), so these fail when a claw skates, floats or sinks, whatever the angles say."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spider_forms as sf  # noqa: E402
import spider_motion as sm  # noqa: E402
import spider_skeleton as ss  # noqa: E402

PAD = 0.008
TOL = 1e-6
SPEEDS = (15.0, 40.0, 70.0, 110.0, 160.0, 260.0)
PPUS = (18.0, 26.0, 36.0)


def body_of(name):
    form = sf.FORMS[name]
    return sm.SpiderBody(ss.skeleton_for(form), {k: PAD for k in ss.LEGS}, dict(form, _hull=ss.hull_for(form)))


BODIES = {}


def body(name):
    if name not in BODIES:
        BODIES[name] = body_of(name)
    return BODIES[name]


def tip(b, key, posed):
    return posed["tar_" + key][1]


def lowest_part(b, rot, root):
    """The lowest point of the skeleton and of the meshes' hull (the abdomen's belly, the hem) in a pose, the claws' tips taken at their meshes'
    lowest point."""
    posed = b.skel.pose(rot, root)
    low = min(min(h[1], t[1]) for n, (h, t, _) in posed.items() if not n.startswith("tar_"))
    low = min([low] + [tip(b, k, posed)[1] - b.pad[k] for k in ss.LEGS])
    return min([low] + [p[1] for _, p in sm.hull_points(b, rot, root, posed)])


def clips(b, speed=50.0, ppu=28.0):
    return sm.clips_for(b, speed, ppu)


class SkeletonTest(unittest.TestCase):
    def test_every_form_has_a_body_an_abdomen_fangs_and_eight_three_bone_legs_whose_claws_stand_on_the_ground(self):
        for name, form in sf.FORMS.items():
            s = ss.skeleton_for(form)
            for b in ("body", "abdomen", "fang", "palp_n", "palp_f"):
                self.assertIn(b, s.rest, name)
            for key in ss.LEGS:
                for b in ("fem_", "tib_", "tar_"):
                    self.assertIn(b + key, s.rest, name)
                self.assertAlmostEqual(s.rest["tar_" + key][1][1], ss.TIP_Z, places=9)
                # the knee rises well above the hip: a spider's legs arc up and over
                self.assertGreater(s.rest["tib_" + key][0][1], s.rest["fem_" + key][0][1] + 0.12, "%s %s" % (name, key))

    def test_a_drider_has_a_torso_a_head_hair_cloth_and_two_arms_holding_things(self):
        for name, form in sf.FORMS.items():
            s = ss.skeleton_for(form)
            upper = ("waist", "chest", "head", "arm_n", "fore_n", "item_n", "arm_f", "fore_f", "item_f", "hair1", "hair2", "cloth1", "cloth2")
            self.assertEqual(all(b in s.rest for b in upper), form.get("drider") is not None, name)
        self.assertEqual(sum(1 for f in sf.FORMS.values() if f.get("drider")), 7)

    def test_the_body_plans_differ(self):
        h = lambda n: ss.skeleton_for(sf.FORMS[n]).rest["body"][0][1]
        def width(n):
            sh = ss.shape(**ss.proportions_of(sf.FORMS[n]))
            return sh["ax"] * sh["ay"] * sh["az"]
        self.assertLess(h("stalker"), h("spider") - 0.05, "a stalker rides low")
        self.assertGreater(h("chasm_weaver"), h("spider") + 0.08, "a chasm-weaver rides high on long legs")
        self.assertGreater(width("plaguemother"), 2.5 * width("spider"), "a plaguemother is bloated")
        self.assertLess(width("stalker"), width("spider"))
        top = lambda n: max(max(hh[1], t[1]) for hh, t, _ in ss.skeleton_for(sf.FORMS[n]).rest.values())
        self.assertGreater(top("norn"), 2.0 * h("norn"), "a drider stands tall")

    def test_the_tree_matches_the_game(self):
        self.assertEqual(len(sf.FORMS), 22)
        for name, form in sf.FORMS.items():
            if name == "spider":
                continue
            self.assertIn(form["parent"], sf.FORMS, name)
            self.assertEqual(form["stage"], sf.FORMS[form["parent"]]["stage"] + 1, name)


class IdleTest(unittest.TestCase):
    def test_planted_claws_stay_where_they_stand_and_a_lifted_one_comes_back_to_the_same_spot(self):
        for name in sf.FORMS:
            b = body(name)
            spots = {}
            for i in range(32):
                rot, root = sm.idle_pose(b, i / 32.0)
                posed = b.skel.pose(rot, root)
                for k in ss.LEGS:
                    x, z = tip(b, k, posed)
                    self.assertGreaterEqual(z, PAD - TOL, "%s %s" % (name, k))
                    if z < PAD + TOL:
                        spots.setdefault(k, set()).add(round(x, 6))
            for k, xs in spots.items():
                self.assertEqual(len(xs), 1, "%s %s does not slide: %s" % (name, k, xs))
            down = [k for k in spots]
            self.assertGreaterEqual(len(down), 4, name)

    def test_it_breathes_a_little(self):
        b = body("spider")
        zs = [b.skel.pose(*sm.idle_pose(b, i / 16.0))["body"][0][1] for i in range(16)]
        self.assertGreater(max(zs) - min(zs), 0.002)
        self.assertLess(max(zs) - min(zs), 0.03)

    def test_the_tarantella_dances_on_its_hind_legs_with_its_front_four_up(self):
        b = body("tarantella")
        for i in range(8):
            posed = b.skel.pose(*sm.idle_pose(b, i / 8.0))
            for k in ss.LEGS:
                z = tip(b, k, posed)[1]
                if sm.pair_of(k) >= 2:
                    self.assertAlmostEqual(z, PAD, places=6)
                else:
                    self.assertGreater(z, 0.8 * b.U, k)
        bounce = [sm.idle_pose(b, i / 16.0)[1][2] for i in range(16)]
        self.assertGreater(max(bounce) - min(bounce), 0.05 * b.U)


class GaitTest(unittest.TestCase):
    SAMPLES = 240

    def test_a_planted_claw_does_not_slide_it_moves_back_with_the_ground_at_one_speed(self):
        for name in sf.FORMS:
            b = body(name)
            for gait in sm.GAITS:
                stride = 0.8 * b.max_stride(gait)
                duty = sm.duty_of(b, gait)
                speed = stride / duty          # units per cycle the ground moves back
                prev = None
                for n in range(self.SAMPLES + 1):
                    t = n / self.SAMPLES
                    posed = b.skel.pose(*sm.gait_pose(b, gait, t, stride))
                    now = {k: tip(b, k, posed) for k in b.walking}
                    if prev:
                        for k in b.walking:
                            if now[k][1] < PAD + TOL and prev[k][1] < PAD + TOL:
                                self.assertAlmostEqual((now[k][0] - prev[k][0]) * self.SAMPLES, -speed, delta=1e-4 * speed + 1e-6,
                                                       msg="%s %s %s t=%.3f" % (name, gait, k, t))
                    prev = now

    def test_no_claw_goes_through_the_ground_and_a_swinging_one_clears_it(self):
        for name in sf.FORMS:
            b = body(name)
            for gait in sm.GAITS:
                stride = b.max_stride(gait)
                clear = {k: 0.0 for k in b.walking}
                for n in range(self.SAMPLES):
                    rot, root = sm.gait_pose(b, gait, n / self.SAMPLES, stride)
                    posed = b.skel.pose(rot, root)
                    for k in b.walking:
                        z = tip(b, k, posed)[1]
                        self.assertGreaterEqual(z, PAD - TOL, "%s %s %s" % (name, gait, k))
                        clear[k] = max(clear[k], z - PAD)
                    self.assertGreaterEqual(lowest_part(b, rot, root), -TOL, "%s %s" % (name, gait))
                for k, c in clear.items():
                    self.assertGreater(c, 0.15 * b.U, "%s %s %s lifts" % (name, gait, k))

    def test_the_walk_is_the_alternating_tetrapod_with_four_feet_always_down(self):
        for name in sf.FORMS:
            b = body(name)
            stride = b.max_stride("walk")
            counts = []
            swinging_together = set()
            for n in range(self.SAMPLES):
                posed = b.skel.pose(*sm.gait_pose(b, "walk", n / self.SAMPLES, stride))
                down = {k for k in b.walking if tip(b, k, posed)[1] < PAD + TOL}
                counts.append(len(down))
                up = frozenset(set(b.walking) - down)
                if len(up) == 4:
                    swinging_together.add(up)
            self.assertGreaterEqual(min(counts), 4, name)
            if not b.raised:
                self.assertIn(frozenset({"n0", "f1", "n2", "f3"}), swinging_together, name)
                self.assertIn(frozenset({"f0", "n1", "f2", "n3"}), swinging_together, name)

    def test_four_feet_are_down_in_every_rendered_walk_frame_at_every_speed(self):
        for name in sf.FORMS:
            b = body(name)
            for speed in SPEEDS:
                cycle, stride = sm.plan_gait(b, "walk", speed, 28.0)
                clip = sm.gait_clip(b, "walk", cycle, stride)
                for rot, root in clip.frames:
                    posed = b.skel.pose(rot, root)
                    self.assertGreaterEqual(sum(1 for k in b.walking if tip(b, k, posed)[1] < PAD + TOL), 4, "%s %s" % (name, speed))

    def test_a_raised_pair_is_never_walked_on(self):
        for name in ("nightstalker", "veil_spinner", "cocoon_mother"):
            b = body(name)
            self.assertEqual(b.raised, [0])
            for gait in sm.GAITS:
                for n in range(48):
                    posed = b.skel.pose(*sm.gait_pose(b, gait, n / 48.0, b.max_stride(gait)))
                    for k in ("n0", "f0"):
                        self.assertGreater(tip(b, k, posed)[1], 0.5 * b.U, "%s %s" % (name, k))

    def test_the_body_dips_after_each_footfall(self):
        b = body("spider")
        zs = [sm.gait_pose(b, "walk", n / 48.0, 0.2)[1][2] for n in range(48)]
        self.assertGreater(max(zs) - min(zs), 0.02 * b.U)
        self.assertLess(max(zs) - min(zs), 0.1 * b.U)
        lows = [n for n in range(48) if zs[n] < zs[n - 1] and zs[n] <= zs[(n + 1) % 48]]
        self.assertEqual(len(lows), 2, "twice a cycle")

    def test_the_knees_stay_above_the_line_from_hip_to_claw(self):
        for name in sf.FORMS:
            b = body(name)
            for gait in sm.GAITS:
                for n in range(48):
                    posed = b.skel.pose(*sm.gait_pose(b, gait, n / 48.0, b.max_stride(gait)))
                    for k in b.walking:
                        hip, knee, ankle = posed["fem_" + k][0], posed["tib_" + k][0], posed["tar_" + k][0]
                        t = (knee[0] - hip[0]) / (ankle[0] - hip[0]) if abs(ankle[0] - hip[0]) > 1e-6 else 0.5
                        line_z = hip[1] + (ankle[1] - hip[1]) * t
                        self.assertGreater(knee[1], min(hip[1], line_z), "%s %s %s" % (name, gait, k))

    def test_the_loop_closes(self):
        for name in ("spider", "nightstalker", "swarm_sovereign", "jorogumo"):
            b = body(name)
            for gait in sm.GAITS:
                a, z = sm.gait_pose(b, gait, 0.0, 0.2), sm.gait_pose(b, gait, 1.0 - 1e-9, 0.2)
                for bone in a[0]:
                    self.assertAlmostEqual(a[0][bone][1], z[0][bone][1], delta=0.01, msg="%s %s %s" % (name, gait, bone))
                self.assertAlmostEqual(a[1][2], z[1][2], places=6)


class PlanTest(unittest.TestCase):
    def test_every_planned_claw_reaches_its_target_at_every_speed_and_scale(self):
        for name in sf.FORMS:
            b = body(name)
            worst = 0.0
            for gait in sm.GAITS:
                for speed in SPEEDS:
                    for ppu in PPUS:
                        cycle, stride = sm.plan_gait(b, gait, speed, ppu)
                        self.assertLessEqual(stride, b.max_stride(gait) + 1e-9)
                        self.assertGreater(cycle, 0.0)
                        for n in range(24):
                            t = n / 24.0
                            rot, root = sm.gait_pose(b, gait, t, stride)
                            targets = sm.gait_targets(b, gait, t, stride)
                            worst = max(worst, sm.reach_error(b, rot, root, {k: targets[k] for k in b.walking}))
            self.assertLess(worst, 1e-6, name)

    def test_a_quick_cycle_is_drawn_in_fewer_frames_never_shorter_than_the_engines_tick(self):
        for cycle in (0.09, 0.15, 0.3, 1.2):
            for gait in sm.GAITS:
                n = sm.gait_frames(gait, cycle)
                self.assertGreaterEqual(cycle / n, sm.TICK - 1e-9 if n > 4 else 0.0)
                self.assertLessEqual(n, sm.GAIT_FRAMES[gait])

    def test_the_stride_grows_with_the_speed_until_the_legs_cannot_reach_further(self):
        b = body("spider")
        strides = [sm.plan_gait(b, "walk", s, 28.0)[1] for s in (15.0, 40.0, 200.0)]
        self.assertLess(strides[0], strides[1] + 1e-9)
        self.assertAlmostEqual(strides[2], b.max_stride("walk"), places=9)


class ActionTest(unittest.TestCase):
    def planted_keys(self, b):
        return [k for k in ss.LEGS if sm.pair_of(k) >= 2]

    def test_the_attacks_keep_the_hind_claws_planted_and_reaching(self):
        for name in sf.FORMS:
            b = body(name)
            spots = {}
            for t, _ in sm.FRAMES:
                rot, root = sm.attack_pose(b, t)
                posed = b.skel.pose(rot, root)
                for k in self.planted_keys(b):
                    x, z = tip(b, k, posed)
                    self.assertAlmostEqual(z, PAD, places=6, msg="%s %s" % (name, k))
                    spots.setdefault(k, []).append(x)
                c = sm._carriage(b)
                targets = {k: sm.ankle_for(b, k, c["tips"][k][:2], c["tips"][k][2]) for k in self.planted_keys(b)}
                self.assertLess(sm.reach_error(b, rot, root, targets), 1e-6, name)
                self.assertGreaterEqual(lowest_part(b, rot, root), -TOL, "%s t=%.2f" % (name, t))
            for k, xs in spots.items():
                self.assertLess(max(xs) - min(xs), 1e-6, "%s %s slides" % (name, k))

    def test_a_bite_rears_back_then_lunges_and_a_pounce_goes_further(self):
        def reach(name):
            b = body(name)
            heads = [b.skel.pose(*sm.attack_pose(b, t))["body"][1][0] for t, _ in sm.FRAMES]
            return b, heads
        b, heads = reach("spider")
        self.assertLess(min(heads[:WINDUP_END()]), heads[0] - 0.03, "it draws back in the windup")
        self.assertGreater(heads[sm.WINDUP], heads[0] + 0.1 * b.U, "and strikes forward on the impact frame")
        pb, pheads = reach("stalker")
        self.assertGreater((max(pheads) - pheads[0]) / pb.U, (max(heads) - heads[0]) / b.U + 0.2)

    def test_the_forelegs_go_up_in_the_windup(self):
        for name in ("spider", "stalker", "venomspinner", "nightstalker"):
            b = body(name)
            rest = tip(b, "n0", b.skel.pose(*sm.idle_pose(b, 0.0)))
            wound = tip(b, "n0", b.skel.pose(*sm.attack_pose(b, sm.T_HOLD - 0.01)))
            # up, or (scythes already held high) drawn back over the body
            self.assertTrue(wound[1] > rest[1] + 0.1 * b.U or wound[0] < rest[0] - 0.3 * b.U, "%s: %s from %s" % (name, wound, rest))

    def test_a_drider_gestures_with_its_arms(self):
        for name in ("weavermaid", "jorogumo", "loom_weaver", "seven_spider_spirits", "tsuchigumo", "norn", "anansi"):
            b = body(name)
            dirs = []
            for t, _ in sm.FRAMES:
                posed = b.skel.pose(*sm.attack_pose(b, t))
                dirs.append((posed["arm_n"][2], posed["fore_n"][2]))
            swing = max(abs(d[0] - dirs[0][0]) + abs(d[1] - dirs[0][1]) for d in dirs)
            self.assertGreater(swing, 60.0, name)

    def test_a_blow_throws_the_front_up_and_back_with_the_hind_claws_planted(self):
        for name in sf.FORMS:
            b = body(name)
            rest = b.skel.pose(*sm.idle_pose(b, 0.0))
            for t, _ in sm.HURT_FRAMES:
                rot, root = sm.hurt_pose(b, t)
                posed = b.skel.pose(rot, root)
                for k in self.planted_keys(b):
                    self.assertAlmostEqual(tip(b, k, posed)[1], PAD, places=6)
                self.assertGreaterEqual(lowest_part(b, rot, root), -TOL, name)
            peak = b.skel.pose(*sm.hurt_pose(b, 0.10))
            self.assertLess(peak["body"][0][0], rest["body"][0][0] - 0.05 * b.U, name)

    def test_it_dies_curled_up_low(self):
        for name in sf.FORMS:
            b = body(name)
            posed = b.skel.pose(*sm.die_pose(b, sm.DIE_FRAMES[-1][0]))
            for k in ss.LEGS:
                # every claw is drawn in toward the body, nearer the hip than it was standing
                hip, claw = posed["fem_" + k][0], posed["tar_" + k][1]
                rest = b.skel.rest
                self.assertLess(math.dist(hip, claw), math.dist(rest["fem_" + k][0], rest["tar_" + k][1]) * 0.8, "%s %s" % (name, k))


def WINDUP_END():
    return sm.WINDUP


class TimingTest(unittest.TestCase):
    def test_the_windup_and_recovery_frames_last_what_the_engines_verb_states_do_and_the_flinch_its_flinch(self):
        self.assertAlmostEqual(sum(d for _, d in sm.FRAMES[:sm.WINDUP]), sm.ENGINE_WINDUP, places=9)
        self.assertLessEqual(sum(d for _, d in sm.FRAMES[sm.WINDUP:]), sm.ENGINE_RECOVER + 1e-9)
        self.assertAlmostEqual(sum(d for _, d in sm.HURT_FRAMES), sm.ENGINE_HURT, places=9)
        for i, (t, d) in enumerate(sm.FRAMES[:-1]):
            self.assertAlmostEqual(t + d, sm.FRAMES[i + 1][0], places=9)

    def test_the_engine_constants_are_the_games(self):
        import export_forms
        c = export_forms.engine_constants()
        self.assertEqual((c["windup"], c["recover"], c["hurt"]), (sm.ENGINE_WINDUP, sm.ENGINE_RECOVER, sm.ENGINE_HURT))

    def test_the_last_frames_of_the_attack_and_the_flinch_are_the_idles_first(self):
        for name in sf.FORMS:
            b = body(name)
            c = clips(b)
            idle = c["idle"].frames[0]
            for clip in ("attack", "hurt"):
                rot, root = c[clip].frames[-1]
                for bone, value in idle[0].items():
                    self.assertAlmostEqual(rot[bone][1], value[1], delta=0.5, msg="%s %s %s" % (name, clip, bone))
                for a, z in zip(root, idle[1]):
                    self.assertAlmostEqual(a, z, places=6)

    def test_a_meta_from_these_clips_passes_the_engines_timing_check(self):
        import export_forms
        b = body("spider")
        c = clips(b)
        meta = {"durations": {n: cl.durations for n, cl in c.items()}, "windup": sm.WINDUP}
        export_forms.check_timing(meta, export_forms.engine_constants())


class ClipTest(unittest.TestCase):
    def test_nothing_goes_below_the_ground_in_any_frame_of_any_standing_clip(self):
        for name in sf.FORMS:
            b = body(name)
            for clip_name, clip in clips(b).items():
                if clip.grounded:
                    continue
                for i, (rot, root) in enumerate(clip.frames):
                    self.assertGreaterEqual(lowest_part(b, rot, root), -TOL, "%s %s %d" % (name, clip_name, i))

    def test_every_clip_is_finite_with_a_duration_per_frame_and_the_abdomen_and_hair_follow_through(self):
        for name in ("spider", "jorogumo", "swarm_sovereign"):
            b = body(name)
            c = clips(b)
            for clip in c.values():
                self.assertEqual(len(clip.frames), len(clip.durations))
                for rot, root in clip.frames:
                    self.assertNotIn("abd", rot)
                    for v in list(root) + [a for r in rot.values() for a in r]:
                        self.assertTrue(math.isfinite(v))
            self.assertTrue(c["walk"].loop and not c["attack"].loop and c["die"].grounded)
            swing = [rot["abdomen"][1] for rot, _ in c["walk"].frames]
            self.assertGreater(max(swing) - min(swing), 1.0, name)
            if b.drider:
                hair = [rot["hair2"][1] for rot, _ in c["attack"].frames]
                self.assertGreater(max(hair) - min(hair), 4.0)

    def test_the_swarm_scuttles_and_its_loop_closes(self):
        b = body("swarm_sovereign")
        self.assertEqual(len(b.swarm), 4)
        frames = clips(b)["idle"].frames
        for bone in b.swarm:
            vals = [rot[bone][1] for rot, _ in frames]
            self.assertGreater(max(vals) - min(vals), 4.0, bone)
        a, z = sm.idle_pose(b, 0.0)[0], sm.idle_pose(b, 1.0)[0]
        for bone in b.swarm:
            self.assertAlmostEqual(a[bone][1], z[bone][1], places=6)


if __name__ == "__main__":
    unittest.main()
