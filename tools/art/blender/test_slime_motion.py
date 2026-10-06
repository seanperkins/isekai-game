"""How a slime moves (slime_motion.py), checked without Blender: the soft-body deformation keeps the base on the ground and the volume, a hop's
planted base does not skate and its flight is a parabola, the attack and the flinch keep the engine's timing and end on the rest pose, nothing
goes below the ground in any frame of any clip of any form. Pure Python."""
import math
import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import export_forms  # noqa: E402
import slime_forms as forms  # noqa: E402
import slime_motion as sm  # noqa: E402

PPU = 60.0


def body_of(name="slime"):
    return sm.SlimeBody(forms.FORMS[name])


def deformed(body, rot):
    verts, faces = body.shape.mesh()
    soft = sm.soft_of(rot)
    return [sm.deform(v, soft, body.shape) for v in verts], faces


_CLIPS = {}


def clips_of(name):
    if name not in _CLIPS:
        body = body_of(name)
        _CLIPS[name] = (body, sm.clips_for(body, forms.speed_of(name), PPU))
    return _CLIPS[name]


class ShapeTest(unittest.TestCase):
    def test_the_dome_is_a_closed_mesh_on_a_flat_base_as_tall_as_its_form_says(self):
        for name in forms.FORMS:
            body = body_of(name)
            verts, faces = body.shape.mesh()
            self.assertAlmostEqual(min(v[2] for v in verts), 0.0, places=9, msg=name)
            self.assertAlmostEqual(max(v[2] for v in verts), body.H, places=6, msg=name)
            edges = {}
            for f in faces:
                for a, b in zip(f, f[1:] + f[:1]):
                    edges[(a, b)] = edges.get((a, b), 0) + 1
            for (a, b), count in edges.items():
                self.assertEqual(count, 1, "%s: edge %s %s is used once each way" % (name, a, b))
                self.assertIn((b, a), edges, "%s: the mesh is closed" % name)

    def test_the_slime_mold_is_flat_and_wide_and_the_cube_is_boxy(self):
        mold, plain, cube = body_of("slime_mold").shape, body_of("slime").shape, body_of("cube").shape
        self.assertGreater(mold.R / mold.H, 1.4)
        self.assertLess(plain.R / plain.H, 1.0)
        # a box fills its bounding box; a dome does not
        for shape, lo, hi in ((cube, 0.80, 1.0), (plain, 0.3, 0.62)):
            verts, faces = shape.mesh()
            fill = sm.volume(verts, faces) / (2 * shape.R * 2 * shape.D * shape.H)
            self.assertTrue(lo < fill < hi, fill)

    def test_a_point_on_the_near_side_is_on_the_surface_in_front(self):
        shape = body_of().shape
        x, y, z = shape.near_point(0.2, 0.3, lift=0.0)
        self.assertAlmostEqual(x, 0.2, delta=0.01)
        self.assertAlmostEqual(z, 0.3, delta=0.01)
        self.assertLess(y, -0.2)


class DeformTest(unittest.TestCase):
    def random_soft(self, rng):
        return dict(sq=rng.uniform(0.6, 1.4), lean=rng.uniform(-0.15, 0.15), bulge=rng.uniform(-0.12, 0.12), bc=rng.uniform(0.1, 0.9),
                    wave=rng.uniform(-0.06, 0.06), phase=rng.uniform(0, 6.3))

    def test_the_base_stays_on_the_ground_and_nothing_goes_below_it(self):
        rng = random.Random(3)
        for name in ("slime", "cube", "shoggoth", "slime_mold"):
            body = body_of(name)
            verts, _ = body.shape.mesh()
            base = [v for v in verts if v[2] < 1e-9]
            for _ in range(40):
                soft = self.random_soft(rng)
                out = [sm.deform(v, soft, body.shape) for v in verts]
                self.assertGreaterEqual(min(p[2] for p in out), 0.0)
                for v in base:
                    p = sm.deform(v, soft, body.shape)
                    self.assertEqual(p[2], 0.0)
                    # the base does not shear: a base point moves only by the spread
                    self.assertAlmostEqual(p[0], v[0] * math.sqrt(1.0 / soft["sq"]) * (1 + soft["bulge"] * (sm._bell(0.0, soft["bc"]) - body.shape.gbar(soft["bc"]))), places=9)

    def test_the_volume_is_kept_a_squash_widens_and_a_stretch_narrows(self):
        rng = random.Random(5)
        body = body_of()
        verts, faces = body.shape.mesh()
        v0 = sm.volume(verts, faces)
        for _ in range(60):
            soft = self.random_soft(rng)
            out = [sm.deform(v, soft, body.shape) for v in verts]
            self.assertAlmostEqual(sm.volume(out, faces) / v0, 1.0, delta=0.03, msg=soft)
        width = lambda sq: max(p[0] for p in (sm.deform(v, dict(sq=sq), body.shape) for v in verts))
        self.assertGreater(width(0.7), width(1.0) * 1.15)
        self.assertLess(width(1.3), width(1.0) * 0.9)

    def test_a_pose_is_finite_and_a_small_change_moves_it_a_little(self):
        body = body_of()
        verts, _ = body.shape.mesh()
        rng = random.Random(9)
        for _ in range(30):
            a = self.random_soft(rng)
            b = {k: v + 1e-4 for k, v in a.items()}
            for v in verts[::7]:
                p, q = sm.deform(v, a, body.shape), sm.deform(v, b, body.shape)
                self.assertTrue(all(math.isfinite(c) for c in p))
                self.assertLess(math.dist(p, q), 1e-2)


class HopTest(unittest.TestCase):
    def test_a_planted_base_moves_back_at_the_speed_and_a_cycle_covers_speed_times_cycle(self):
        for name in ("slime", "kraken", "cube"):
            body = body_of(name)
            for gait, k in (("walk", 1.0), ("run", sm.RUN_SPEED)):
                speed = forms.speed_of(name) * k
                cycle, length = sm.plan_hop(body, gait, speed, PPU)
                v = speed / PPU
                self.assertAlmostEqual(length, v * cycle, places=9)
                c = sm.HOPS[gait]["contact"]
                ts = [c * i / 20.0 for i in range(20)]
                for t0, t1 in zip(ts, ts[1:]):
                    a, b = sm.hop_root(body, gait, t0, length), sm.hop_root(body, gait, t1, length)
                    self.assertAlmostEqual((b[0] - a[0]) / ((t1 - t0) * cycle), -v, places=6, msg="%s %s: planted" % (name, gait))
                    self.assertEqual(a[2], 0.0)
                    # in the world (the sprite's frame moves forward at v) the base stands still
                    self.assertAlmostEqual(b[0] + v * t1 * cycle, a[0] + v * t0 * cycle, places=9)
                # over the whole cycle the world displacement is the hop: speed times the cycle
                start = sm.hop_root(body, gait, 0.0, length)[0]
                end = sm.hop_root(body, gait, 1.0 - 1e-12, length)[0] + v * cycle
                self.assertAlmostEqual(end - start, v * cycle, places=6)

    def test_the_flight_is_a_parabola_moving_forward_at_one_speed(self):
        body = body_of()
        for gait in sm.HOPS:
            c = sm.HOPS[gait]["contact"]
            ts = [c + (1.0 - c) * i / 30.0 for i in range(31)][:-1]
            pts = [sm.hop_root(body, gait, t, 0.5) for t in ts]
            dz2 = [pts[i - 1][2] - 2 * pts[i][2] + pts[i + 1][2] for i in range(1, len(pts) - 1)]
            dx = [b[0] - a[0] for a, b in zip(pts, pts[1:])]
            self.assertLess(max(dz2) - min(dz2), 1e-9, "constant fall")
            self.assertLess(max(dz2), 0.0, "it falls")
            self.assertLess(max(dx) - min(dx), 1e-9, "constant forward speed")
            self.assertGreater(min(dx), 0.0)
            self.assertAlmostEqual(max(p[2] for p in pts), sm.HOPS[gait]["height"] * body.H, delta=0.01 * body.H)

    def test_every_hop_is_within_what_the_body_can_throw_itself(self):
        for name in forms.FORMS:
            body = body_of(name)
            if body.hover:
                continue
            for gait, k in (("walk", 1.0), ("run", sm.RUN_SPEED)):
                for speed in (forms.speed_of(name) * k, 15.0, 200.0):
                    cycle, length = sm.plan_hop(body, gait, speed, PPU)
                    self.assertLessEqual(length, sm.HOPS[gait]["longest"] * body.width + 1e-9, "%s %s" % (name, gait))
                    self.assertGreater(cycle, 0.0)
            self.assertLessEqual(sm.HOPS["run"]["height"], 0.5, "it leaps no higher than half its height")


class ClipTest(unittest.TestCase):
    def test_every_form_has_every_clip_finite_with_a_duration_per_frame(self):
        for name in forms.FORMS:
            body, clips = clips_of(name)
            self.assertEqual(set(clips), {"idle", "walk", "run", "attack", "hurt", "die"})
            for cname, clip in clips.items():
                self.assertEqual(len(clip.frames), len(clip.durations), cname)
                for rot, root in clip.frames:
                    self.assertTrue(all(math.isfinite(v) for v in root))
                    for bone, r in rot.items():
                        if bone != sm.SOFT:
                            self.assertTrue(all(math.isfinite(v) for v in r), "%s %s %s" % (name, cname, bone))
                    for v in sm.soft_of(rot).values():
                        if isinstance(v, float):
                            self.assertTrue(math.isfinite(v))
            self.assertTrue(clips["idle"].loop and clips["walk"].loop and not clips["attack"].loop and not clips["die"].loop)

    def test_nothing_is_ever_below_the_ground(self):
        for name in forms.FORMS:
            body, clips = clips_of(name)
            verts = body.shape.mesh()[0][::3]
            for cname, clip in clips.items():
                for i, (rot, root) in enumerate(clip.frames):
                    self.assertGreaterEqual(sm.lowest(body, rot, root, verts), -1e-6, "%s %s %d" % (name, cname, i))
                    posed = sm.pose_bones(body, rot, root)
                    for ch in body.chains:
                        low = min(posed[b][1][1] for b in ch["bones"])
                        self.assertGreaterEqual(low, ch.get("clear", sm.CLEAR) - 1e-6, "%s %s %d %s keeps its thickness off the ground" % (name, cname, i, ch["name"]))

    def test_a_hopper_stands_on_the_ground_at_rest_and_lands_and_a_hover_form_floats(self):
        for name in forms.FORMS:
            body, clips = clips_of(name)
            rot, root = clips["idle"].frames[0]
            low = min(sm.deform(v, sm.soft_of(rot), body.shape)[2] for v in body.shape.mesh()[0]) + root[2]
            if body.hover:
                self.assertGreater(low, 0.02, name)
                self.assertTrue(all(r[0] == 0.0 for _, r in clips["walk"].frames), "%s glides without hopping" % name)
            else:
                self.assertAlmostEqual(low, 0.0, places=9, msg=name)
                zs = [r[2] for _, r in clips["walk"].frames]
                self.assertEqual(min(zs), 0.0)
                self.assertGreater(max(zs), 0.15 * body.H, "%s hops" % name)

    def test_the_hop_squashes_on_landing_and_stretches_on_take_off(self):
        body, clips = clips_of("slime")
        sqs = [sm.soft_of(rot)["sq"] for rot, _ in clips["walk"].frames]
        self.assertLess(sqs[0], 0.8, "the first contact frame is the impact")
        self.assertGreater(max(sqs), 1.1)
        self.assertLess(min(sqs[1:6]), 0.85, "the anticipation sinks")

    def test_loops_close(self):
        """A cycle's pose one whole cycle on is its first frame (the hop's landing is the biggest step in it, by design: the first contact frame is
        the impact), the idle's seam is as smooth as its other steps, and the chains' springs end a lap where they began."""
        for name in ("slime", "kraken", "poltergeist", "cloud_rider"):
            body, clips = clips_of(name)
            for gait in ("walk", "run"):
                if body.hover:
                    pairs = [(sm.glide_soft(body, gait, 0.0), sm.glide_soft(body, gait, 1.0)), (sm.glide_root(body, gait, 0.0), sm.glide_root(body, gait, 1.0))]
                else:
                    pairs = [(sm.hop_soft(body, gait, 0.0), sm.hop_soft(body, gait, 1.0)), (sm.hop_root(body, gait, 0.0, 0.5), sm.hop_root(body, gait, 1.0, 0.5))]
                (s0, s1), (r0, r1) = pairs
                for k in ("sq", "lean", "wave", "bulge"):
                    self.assertAlmostEqual(s0[k], s1[k], places=9, msg="%s %s %s" % (name, gait, k))
                for a, b in zip(r0, r1):
                    self.assertAlmostEqual(a, b, places=9)
            clip = clips["idle"]
            tops = [sm.deform((0.0, 0.0, body.H), sm.soft_of(rot), body.shape)[2] + root[2] for rot, root in clip.frames + clip.frames[:1]]
            steps = [abs(b - a) for a, b in zip(tops, tops[1:])]
            self.assertLessEqual(steps[-1], max(steps[:-1]) + 1e-9, "%s idle seam" % name)
            for ch in body.chains:
                b = ch["bones"][-1]
                for cname in ("idle", "walk"):
                    dirs = [sm.pose_bones(body, rot, root)[b][2] for rot, root in clips[cname].frames]
                    seam = abs(dirs[0] - dirs[-1])
                    self.assertLessEqual(seam, 1.15 * max(abs(q - p) for p, q in zip(dirs, dirs[1:])) + 1e-6, "%s %s %s seam" % (name, cname, b))

    def test_the_idle_breathes_and_its_inner_thing_lags(self):
        body, clips = clips_of("philosophers_stone")
        tops = [sm.deform((0.0, 0.0, body.H), sm.soft_of(rot), body.shape)[2] for rot, _ in clips["idle"].frames]
        self.assertGreater(max(tops) - min(tops), 0.02 * body.H)
        self.assertLess(max(tops) - min(tops), 0.15 * body.H)
        lags = [sm.soft_of(rot)["off"]["inner"]["d"] for rot, _ in clips["idle"].frames]
        self.assertGreater(max(math.hypot(*d) for d in lags), 0.002)

    def test_a_chain_lags_its_driver_on_a_spring(self):
        """Swap the spring for no spring at all (the chain goes exactly where it is driven): the chains must move differently, by more than a
        little, or the follow-through is not there."""
        body = body_of("kraken")
        idle = sm.idle_clip(body)
        for gait in ("walk",):
            cycle, length = sm.plan_hop(body, gait, forms.speed_of("kraken"), PPU)
            n = sm.HOPS[gait]["frames"]
            times = [i / n for i in range(n)]
            dur = [cycle / n] * n
            make = lambda: [(sm._frame(sm.hop_soft(body, gait, t)), sm.hop_root(body, gait, t, length)) for t in times]
            fn, _ = sm._deliberate(body, gait, times)
            sprung = sm.chain_rots(body, make(), dur, True, fn)
            rigid = sm.chain_rots(body, make(), dur, True, fn, follow=lambda driver, durations, **kw: list(driver))
            worst = max(abs(a[0][b][1] - r[0][b][1]) for a, r in zip(sprung, rigid) for ch in body.chains for b in ch["bones"])
            self.assertGreater(worst, 8.0)

    def test_nothing_snaps_as_an_action_starts(self):
        for name in forms.FORMS:
            body, clips = clips_of(name)
            rest = sm.pose_bones(body, *clips["idle"].frames[0])
            for cname in ("attack", "hurt", "die"):
                first = sm.pose_bones(body, *clips[cname].frames[0])
                for ch in body.chains:
                    for b in ch["bones"]:
                        self.assertAlmostEqual(first[b][2], rest[b][2], delta=4.0, msg="%s %s %s" % (name, cname, b))

    def test_chains_follow_through(self):
        for name, chain in (("kraken", "t_back2"), ("beanstalk", "vine3"), ("gleipnir", "rib_a2"), ("shoggoth", "p_front1")):
            body, clips = clips_of(name)
            for cname in ("walk", "attack"):
                dirs = [sm.pose_bones(body, rot, root)[chain][2] for rot, root in clips[cname].frames]
                self.assertGreater(max(dirs) - min(dirs), 8.0, "%s %s %s" % (name, cname, chain))

    def test_a_chain_root_rides_the_deformed_surface(self):
        body, clips = clips_of("kraken")
        for rot, root in clips["walk"].frames:
            posed = sm.pose_bones(body, rot, root)
            for ch in body.chains:
                want = sm.deform(ch["anchor"], sm.soft_of(rot), body.shape)
                head = posed[ch["bones"][0]][0]
                self.assertAlmostEqual(head[0], want[0] + root[0], places=9)
                self.assertAlmostEqual(head[1], want[2] + root[2], places=9)

    def test_the_mimic_bites_with_its_lid_and_the_lasher_lashes(self):
        body, clips = clips_of("mimic")
        lid = [sm.pose_bones(body, rot, root)["lid1"][2] for rot, root in clips["attack"].frames]
        self.assertGreater(max(lid[:sm.WINDUP]) - lid[0], 30.0, "the lid opens wide on the coil")
        self.assertLess(lid[sm.WINDUP], lid[sm.WINDUP - 1] - 15.0, "and snaps shut on the impact")
        self.assertLessEqual(lid[sm.WINDUP], body.skel.rest_direction("lid1") + 0.5, "shut, not half open")
        body, clips = clips_of("kraken")
        tip = [sm.pose_bones(body, rot, root)["t_front3"][1][0] for rot, root in clips["attack"].frames]
        self.assertGreater(tip[sm.WINDUP] - tip[0], 0.1, "the front tentacle lashes forward")

    def test_a_poltergeist_throws_a_pebble_and_its_pebbles_drop_when_it_dies(self):
        body, clips = clips_of("poltergeist")
        dx = [sm.soft_of(rot)["off"]["pebble0"]["d"][0] for rot, _ in clips["attack"].frames]
        self.assertGreater(dx[sm.WINDUP], 0.8 * body.width)
        rot, root = clips["die"].frames[-1]
        for g, pivot in body.groups.items():
            dz = sm.soft_of(rot)["off"][g]["d"][1]
            self.assertAlmostEqual(pivot[2] + dz + root[2], forms.FORMS["poltergeist"]["pebble_r"], places=6)

    def test_it_dies_into_a_low_wide_puddle(self):
        for name in ("slime", "cube", "cloud_rider"):
            body, clips = clips_of(name)
            rot, root = clips["die"].frames[-1]
            out, _ = deformed(body, rot)
            self.assertLess(max(p[2] for p in out) + root[2], 0.62 * body.H, name)
            self.assertGreater(max(p[0] for p in out), body.R * 1.1, name)
            self.assertAlmostEqual(root[2], 0.0)


class TimingTest(unittest.TestCase):
    def test_the_windup_recover_and_flinch_last_what_the_engine_says(self):
        c = export_forms.engine_constants()
        self.assertAlmostEqual(sum(d for _, d in sm.FRAMES[:sm.WINDUP]), c["windup"], places=9)
        self.assertLessEqual(sum(d for _, d in sm.FRAMES[sm.WINDUP:]), c["recover"] + 1e-9)
        self.assertAlmostEqual(sum(d for _, d in sm.HURT_FRAMES), c["hurt"], places=9)
        self.assertAlmostEqual(sm.RUN_SPEED, c["run_speed"], places=9)

    def test_every_forms_meta_passes_the_exporters_timing_check(self):
        c = export_forms.engine_constants()
        for name in forms.FORMS:
            _, clips = clips_of(name)
            meta = {"durations": {n: k.durations for n, k in clips.items()}, "windup": sm.WINDUP}
            export_forms.check_timing(meta, c)

    def test_the_last_frames_of_the_attack_and_the_flinch_are_the_rest_pose(self):
        for name in forms.FORMS:
            body, clips = clips_of(name)
            rest_rot, rest_root = clips["idle"].frames[0]
            for cname in ("attack", "hurt"):
                rot, root = clips[cname].frames[-1]
                self.assertEqual(tuple(root), tuple(rest_root))
                a, b = sm.soft_of(rot), sm.soft_of(rest_rot)
                for k in sm.CHANNELS:
                    self.assertAlmostEqual(a[k], b[k], places=9, msg="%s %s %s" % (name, cname, k))
                self.assertEqual(a.get("off", {}), b.get("off", {}), "%s %s" % (name, cname))
                for bone in body.skel.rest:
                    self.assertAlmostEqual(rot.get(bone, (0, 0, 0))[1], rest_rot.get(bone, (0, 0, 0))[1], places=9, msg="%s %s %s" % (name, cname, bone))


class SpeedTest(unittest.TestCase):
    def test_a_twins_speed_is_read_from_its_own_file(self):
        self.assertAlmostEqual(forms.speed_of("kraken"), 60.0 * 0.8 / 1.4, places=6)
        self.assertEqual(forms.speed_of("slime"), 60.0)
        for name in forms.STAGE4:
            self.assertTrue(os.path.exists(forms.twin_path(name)), name)


if __name__ == "__main__":
    unittest.main()
