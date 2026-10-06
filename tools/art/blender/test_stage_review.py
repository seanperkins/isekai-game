"""The movement review on the photo stage (stage_review.py): turning a recorded run into poses, checked without Blender. A walk's phase advances by the speed over the
stride so a planted foot does not skate; a state a creature has no pose for says so instead of showing its idle."""
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import biped_motion as bm  # noqa: E402
import player_poses  # noqa: E402
import stage  # noqa: E402
import stage_review as sr  # noqa: E402
from test_biped_motion import body_of  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
WALK_SPEED = 105.0
PPU = 26.0


def goblin_clips():
    """The goblin's clips as the base goblin builds them (creatures/goblin.py clips_of), on the flat test skeleton."""
    body = body_of()
    walk_cycle, walk_stride = bm.plan_gait(body, "walk", WALK_SPEED, PPU)
    run_cycle, run_stride = bm.plan_gait(body, "run", WALK_SPEED * sr.RUN_SPEED, PPU)
    clips = {"idle": bm.idle_clip(body), "walk": bm.gait_clip(body, "walk", walk_cycle, walk_stride), "run": bm.gait_clip(body, "run", run_cycle, run_stride),
             "attack": bm.attack_clip(body)}
    clips.update({name: player_poses.clip(body, name) for name in player_poses.FRAMES})
    return clips


def tick(i, x=100.0, y=0.0, vx=0.0, vy=0.0, surface="floor", verb="", facing=1, on_floor=True):
    return {"t": i / 60.0, "x": x, "y": y, "vx": vx, "vy": vy, "facing": facing, "verb": verb, "on_floor": on_floor, "surface": surface, "normal": [0.0, -1.0]}


class RuleTests(unittest.TestCase):
    def test_the_rate_rules_are_the_games(self):
        with open(os.path.join(ROOT, "scripts", "forms", "form_pose.gd")) as fh:
            src = fh.read()
        const = lambda name: float(re.search(r"const %s := ([0-9.]+)" % name, src).group(1))
        self.assertEqual(sr.RUN_RATIO, const("RUN_RATIO"))
        self.assertEqual(sr.RUN_SPEED, const("RUN_SPEED"))
        rng = re.search(r"const RATE_RANGE := Vector2\(([0-9.]+), ([0-9.]+)\)", src)
        self.assertEqual(sr.RATE_RANGE, (float(rng.group(1)), float(rng.group(2))))

    def test_a_phase_advances_by_the_speed_over_the_stride(self):
        self.assertEqual(sr.phase_rate(60.0, 120.0), 0.5)
        self.assertEqual(sr.phase_rate(0.0, 120.0), 0.0)

    def test_a_stride_is_what_the_clip_covers_in_one_cycle(self):
        clips = goblin_clips()
        cycle = sum(clips["walk"].durations)
        self.assertAlmostEqual(sr.stride_of(clips["walk"], "walk", WALK_SPEED), WALK_SPEED * cycle)
        self.assertAlmostEqual(sr.stride_of(clips["run"], "run", WALK_SPEED), WALK_SPEED * sr.RUN_SPEED * sum(clips["run"].durations))


class StateTests(unittest.TestCase):
    def test_standing_walking_and_running_split_where_the_game_splits_them(self):
        self.assertEqual(sr.state_of(tick(0, vx=0.5), WALK_SPEED), "idle")
        self.assertEqual(sr.state_of(tick(0, vx=WALK_SPEED * sr.RUN_RATIO), WALK_SPEED), "walk")
        self.assertEqual(sr.state_of(tick(0, vx=WALK_SPEED * sr.RUN_RATIO + 1.0), WALK_SPEED), "run")
        self.assertEqual(sr.state_of(tick(0, vx=-200.0), WALK_SPEED), "run", "speed has no sign")

    def test_the_air_is_a_rise_or_a_fall(self):
        self.assertEqual(sr.state_of(tick(0, y=-30.0, vy=-200.0, surface="air", on_floor=False), WALK_SPEED), "rise")
        self.assertEqual(sr.state_of(tick(0, y=-30.0, vy=120.0, surface="air", on_floor=False), WALK_SPEED), "fall")

    def test_a_wall_a_mantle_and_a_verb_are_their_own_states(self):
        self.assertEqual(sr.state_of(tick(0, surface="wall", on_floor=False), WALK_SPEED), "wall")
        self.assertEqual(sr.state_of(tick(0, surface="mantle", on_floor=False), WALK_SPEED), "mantle")
        self.assertEqual(sr.state_of(tick(0, vx=300.0, verb="pounce"), WALK_SPEED), "pounce")

    def test_a_hard_landing_is_a_landing_for_a_few_ticks(self):
        ticks = [tick(0, surface="air", on_floor=False, vy=300.0), tick(1), tick(2), tick(3)]
        ticks += [tick(i) for i in range(4, 4 + sr.LAND_TICKS + 2)]
        states = sr.states_of(ticks, WALK_SPEED)
        self.assertEqual(states[0], "fall")
        self.assertEqual(states[1:1 + sr.LAND_TICKS], ["land"] * sr.LAND_TICKS)
        self.assertEqual(states[1 + sr.LAND_TICKS], "idle")

    def test_a_soft_step_down_is_not_a_landing(self):
        ticks = [tick(0, surface="air", on_floor=False, vy=40.0), tick(1), tick(2)]
        self.assertEqual(sr.states_of(ticks, WALK_SPEED), ["fall", "idle", "idle"])


class PoseTests(unittest.TestCase):
    def test_a_walk_at_a_phase_is_the_walk_frame_there(self):
        clips = goblin_clips()
        p = sr.pose_for(clips, "walk", 0.25)
        n = len(clips["walk"].frames)
        self.assertEqual((p.clip, p.frame), ("walk", int(0.25 * n)))
        self.assertEqual((p.rot, p.root), clips["walk"].frames[int(0.25 * n)])
        self.assertEqual(sr.pose_for(clips, "walk", 1.25).frame, int(0.25 * n), "a phase wraps")

    def test_a_wall_has_the_players_clinging_pose(self):
        p = sr.pose_for(goblin_clips(), "wall", 0.0)
        self.assertEqual(p.clip, "wall")

    def test_a_state_a_creature_has_no_pose_for_says_so(self):
        clips = goblin_clips()
        del clips["wall"]
        with self.assertRaises(sr.NoPose) as caught:
            sr.pose_for(clips, "wall", 0.0)
        self.assertEqual(caught.exception.state, "wall")
        with self.assertRaises(sr.NoPose):
            sr.pose_for(goblin_clips(), "dance", 0.0)
        with self.assertRaises(sr.NoPose):
            sr.pose_for(goblin_clips(), "pounce", 0.0)

    def test_a_pose_is_grounded_as_its_clip_is(self):
        clips = goblin_clips()
        self.assertTrue(sr.pose_for(clips, "rise", 0.0).grounded, "a leap is set on the ground by its lowest point")
        self.assertFalse(sr.pose_for(clips, "idle", 0.0).grounded, "a stance has its own root")
        self.assertFalse(sr.pose_for(clips, "land", 0.0).grounded)


class PlaybackTests(unittest.TestCase):
    def walking(self, ticks=120, vx=WALK_SPEED):
        return {"species": "goblin", "script": "walk", "fps": 60, "start": [0.0, 0.0],
                "ticks": [tick(i, x=vx * i / 60.0, vx=vx) for i in range(ticks)]}

    def test_a_planted_foot_does_not_skate_a_walk_advances_by_speed_over_stride(self):
        clips = goblin_clips()
        frames = sr.playback(self.walking(), clips, WALK_SPEED, every=1)
        stride = sr.stride_of(clips["walk"], "walk", WALK_SPEED)
        a, b = frames[10], frames[70]
        self.assertAlmostEqual(b.travel - a.travel, 60 * (WALK_SPEED / 60.0), places=3)
        advanced = (b.phase - a.phase) * stride
        self.assertAlmostEqual(advanced, b.travel - a.travel, delta=0.01 * stride, msg="phase times stride is the distance the body went")

    def test_a_walk_at_half_speed_plays_at_half_rate(self):
        clips = goblin_clips()
        slow = sr.playback(self.walking(vx=WALK_SPEED / 2), clips, WALK_SPEED, every=1)
        fast = sr.playback(self.walking(), clips, WALK_SPEED, every=1)
        self.assertAlmostEqual((slow[-1].phase - slow[0].phase) * 2.0, fast[-1].phase - fast[0].phase, places=6)

    def test_only_every_nth_tick_is_posed(self):
        frames = sr.playback(self.walking(120), goblin_clips(), WALK_SPEED, every=3)
        self.assertEqual(len(frames), 40)
        self.assertEqual([f.tick for f in frames[:3]], [0, 3, 6])

    def test_a_mantle_goes_from_the_hang_to_the_pull(self):
        ticks = [tick(i, surface="mantle", on_floor=False, y=-60.0 - i) for i in range(20)]
        frames = sr.playback({"species": "goblin", "script": "m", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}, goblin_clips(), WALK_SPEED, every=1)
        self.assertEqual({f.clip for f in frames}, {"mantle"})
        self.assertEqual((frames[0].frame, frames[-1].frame), (0, 1))

    def test_a_creature_without_the_pose_stops_the_playback_with_the_state_named(self):
        clips = goblin_clips()
        del clips["mantle"]
        ticks = [tick(i, surface="mantle", on_floor=False) for i in range(4)]
        with self.assertRaises(sr.NoPose) as caught:
            sr.playback({"species": "goblin", "script": "m", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}, clips, WALK_SPEED, every=1)
        self.assertEqual(caught.exception.state, "mantle")

    def test_a_facing_is_carried_to_the_frame(self):
        ticks = [tick(0, facing=-1), tick(1, facing=-1)]
        frames = sr.playback({"species": "goblin", "script": "w", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}, goblin_clips(), WALK_SPEED, every=1)
        self.assertEqual(frames[0].facing, -1)


class RecordingTests(unittest.TestCase):
    COURSE = {"floor": [0, 0, 1400, 40], "walls": [[-40, -400, 40, 440], [1400, -400, 40, 440]]}

    def rec(self, ticks):
        return {"species": "goblin", "script": "s", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}

    def test_a_run_that_ends_standing_in_the_course_is_good(self):
        sr.check_recording(self.rec([tick(0), tick(1, x=110.0)]), self.COURSE)

    def test_a_run_that_never_lands_is_reported(self):
        ticks = [tick(0), tick(1, surface="air", on_floor=False, y=-30.0)]
        with self.assertRaises(sr.BadRecording) as caught:
            sr.check_recording(self.rec(ticks), self.COURSE)
        self.assertIn("never lands", str(caught.exception))

    def test_a_body_that_leaves_the_course_is_reported(self):
        for x, y in ((1500.0, 0.0), (-80.0, 0.0), (100.0, 80.0), (100.0, -500.0)):
            with self.assertRaises(sr.BadRecording, msg=str((x, y))) as caught:
                sr.check_recording(self.rec([tick(0), tick(1, x=x, y=y), tick(2)]), self.COURSE)
            self.assertIn("leaves the course", str(caught.exception))

    def test_an_empty_recording_is_reported(self):
        with self.assertRaises(sr.BadRecording):
            sr.check_recording(self.rec([]), self.COURSE)


class StageTests(unittest.TestCase):
    COURSE = {"floor": [0, 0, 1400, 40], "walls": [[-40, -400, 40, 440]], "ledges": [[400, -40, 80, 40]], "dummy": [120, -50, 20, 40], "start": [100, 0], "y_axis": "down"}

    def test_a_course_rect_becomes_a_box_in_stage_units(self):
        boxes = {b.name: b for b in sr.course_boxes(self.COURSE, 40.0) if b.name.startswith("ledges")}
        b = boxes["ledges_0"]
        self.assertEqual((b.x0, b.x1, b.z0, b.z1), (10.0, 12.0, 0.0, 1.0))
        self.assertEqual(b.kind, "solid")

    def test_the_floor_is_cut_into_alternating_stripes_so_a_slide_shows(self):
        stripes = [b for b in sr.course_boxes(self.COURSE, 40.0) if b.kind in ("floor_a", "floor_b")]
        self.assertEqual(len(stripes), -(-1400 // sr.STRIPE_PX))
        self.assertEqual({b.kind for b in stripes}, {"floor_a", "floor_b"})
        self.assertEqual(stripes[0].x0, 0.0)
        self.assertAlmostEqual(stripes[-1].x1, 1400 / 40.0)

    def test_the_dummy_is_not_solid(self):
        d = [b for b in sr.course_boxes(self.COURSE, 40.0) if b.name == "dummy"][0]
        self.assertEqual(d.kind, "hostile")

    def test_the_camera_follows_the_body_and_keeps_the_ground_in_view(self):
        frames = sr.playback({"species": "goblin", "script": "w", "fps": 60, "start": [0.0, 0.0], "ticks": [tick(i, x=2.0 * i, vx=120.0) for i in range(90)]},
                             goblin_clips(), WALK_SPEED, every=1)
        path = sr.camera_path(frames, 40.0, 360.0, 202.5)
        self.assertEqual(len(path), len(frames))
        self.assertGreater(path[-1][0], path[0][0], "it follows to the right")
        view_h = 202.5 / 40.0
        for cx, cz in path:
            self.assertLessEqual(cz - view_h / 2.0, -sr.GROUND_MARGIN_PX / 40.0 + 1e-6, "the ground is in the frame")


class CrawlTests(unittest.TestCase):
    """The spider moves by shifting its body over a surface: its velocity is zero and its speed is read from where it was."""

    def crawl(self, i, x, y, normal, speed=70.0, surface="wall"):
        t = tick(i, x=x, y=y, vx=0.0, surface=surface)
        t.update({"crawl": True, "speed": speed, "normal": normal})
        return t

    def test_a_crawl_is_a_gait_by_its_speed_not_a_wall_or_a_ceiling(self):
        for surface, normal in (("wall", [-1.0, 0.0]), ("ceiling", [0.0, 1.0]), ("floor", [0.0, -1.0])):
            self.assertEqual(sr.state_of(self.crawl(0, 0.0, 0.0, normal, 40.0, surface), 66.0), "walk", surface)
            self.assertEqual(sr.state_of(self.crawl(0, 0.0, 0.0, normal, 100.0, surface), 66.0), "run", surface)
            self.assertEqual(sr.state_of(self.crawl(0, 0.0, 0.0, normal, 0.0, surface), 66.0), "idle", surface)

    def test_a_tick_with_no_speed_goes_by_its_velocity(self):
        self.assertEqual(sr.state_of(tick(0, vx=-200.0), 105.0), "run")

    def test_the_body_is_turned_to_lie_on_its_surface(self):
        self.assertAlmostEqual(sr.surface_angle([0.0, -1.0]), 0.0)
        self.assertAlmostEqual(sr.surface_angle([-1.0, 0.0]), -90.0)
        self.assertAlmostEqual(sr.surface_angle([1.0, 0.0]), 90.0)
        self.assertAlmostEqual(abs(sr.surface_angle([0.0, 1.0])), 180.0)

    def test_a_crawler_faces_the_way_it_goes_along_its_surface(self):
        clips = goblin_clips()
        up = [self.crawl(i, 760.0, -2.0 * i, [-1.0, 0.0]) for i in range(6)]  # up a wall that is on its right
        down = [self.crawl(i, 760.0, 2.0 * i, [-1.0, 0.0]) for i in range(6)]
        rec = lambda ticks: {"species": "spider", "script": "c", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}
        self.assertEqual(sr.playback(rec(up), clips, 66.0, every=1)[-1].facing, 1)
        self.assertEqual(sr.playback(rec(down), clips, 66.0, every=1)[-1].facing, -1)
        over = [self.crawl(i, 2.0 * i, -180.0, [0.0, 1.0], surface="ceiling") for i in range(6)]  # hanging, going right: upside down, so its right is the screen's left
        f = sr.playback(rec(over), clips, 66.0, every=1)[-1]
        self.assertEqual((f.facing, round(abs(f.angle))), (-1, 180))

    def test_a_walker_keeps_the_facing_the_game_gave_it(self):
        f = sr.playback({"species": "goblin", "script": "w", "fps": 60, "start": [0.0, 0.0], "ticks": [tick(0, facing=-1)]}, goblin_clips(), WALK_SPEED, every=1)[0]
        self.assertEqual((f.facing, f.angle), (-1, 0.0))


class GapTests(unittest.TestCase):
    def rec(self, ticks):
        return {"species": "wolf", "script": "s", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}

    def test_the_missing_states_are_the_ones_the_run_needs_and_the_clips_lack(self):
        ticks = [tick(0), tick(1, surface="air", on_floor=False, vy=-100.0), tick(2, surface="air", on_floor=False, vy=100.0), tick(3, vx=300.0)]
        self.assertEqual(sr.missing_states(self.rec(ticks), {"idle", "walk", "run"}, WALK_SPEED), ["fall", "rise"])
        self.assertEqual(sr.missing_states(self.rec(ticks), {"idle", "walk", "run", "rise", "fall"}, WALK_SPEED), [])

    def test_a_verb_with_no_clip_is_missing_by_its_name(self):
        self.assertEqual(sr.missing_states(self.rec([tick(0, verb="pounce")]), {"idle"}, WALK_SPEED), ["pounce"])

    def test_playback_can_hold_a_missing_pose_and_say_so_instead_of_stopping(self):
        clips = goblin_clips()
        del clips["wall"]
        ticks = [tick(0), tick(1, surface="wall", on_floor=False), tick(2, surface="wall", on_floor=False), tick(3)]
        frames = sr.playback(self.rec(ticks), clips, WALK_SPEED, every=1, hold_missing=True)
        self.assertEqual([f.missing for f in frames], [None, "wall", "wall", None])
        self.assertEqual(frames[1].clip, frames[0].clip, "the last pose is held")

    def test_the_known_gaps_name_real_states_of_known_species(self):
        for species, scripts in sr.KNOWN_MISSING.items():
            self.assertIn(species, ("goblin", "undead", "slime", "wolf", "spider"))
            for script, states in scripts.items():
                self.assertTrue(states and states == sorted(states), (species, script))
                for state in states:
                    self.assertNotIn(state, ("idle", "walk", "run"), "every body has these")


class SlideTests(unittest.TestCase):
    def walking(self, vx):
        return {"species": "goblin", "script": "w", "fps": 60, "start": [0.0, 0.0], "ticks": [tick(i, x=vx * i / 60.0, vx=vx, ) for i in range(180)]}

    def test_a_steady_walk_does_not_slide(self):
        clips = goblin_clips()
        frames = sr.playback(self.walking(100.0), clips, WALK_SPEED, every=1)
        self.assertLess(sr.slide_px(frames, clips, WALK_SPEED), 0.01)

    def test_a_body_too_slow_for_the_games_playback_range_slides_and_is_measured(self):
        clips = goblin_clips()
        frames = sr.playback(self.walking(5.0), clips, WALK_SPEED, every=1)  # the rate is held at 0.2, so the planted foot is dragged
        self.assertGreater(sr.slide_px(frames, clips, WALK_SPEED), 0.01)

    def test_standing_and_flying_have_no_planted_foot_to_slide(self):
        clips = goblin_clips()
        ticks = [tick(i, surface="air", on_floor=False, vy=-50.0, x=i * 2.0) for i in range(30)]
        frames = sr.playback({"species": "goblin", "script": "j", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}, clips, WALK_SPEED, every=1)
        self.assertEqual(sr.slide_px(frames, clips, WALK_SPEED), 0.0)


class ContactTests(unittest.TestCase):
    """Where the rig's mesh rests on the ground, bone by bone: the foot-slide check measures these, not the numbers the playback was made from."""

    def test_each_bone_that_touches_has_the_span_of_its_resting_vertices(self):
        pts = {"foot_n": [(0.0, 0.0), (0.2, 0.0), (0.1, 0.0)], "foot_f": [(1.0, 0.0)], "shin_n": []}
        self.assertEqual(sr.contact_spans(pts), {"foot_n": (0.0, 0.2), "foot_f": (1.0, 1.0)})
        self.assertEqual(sr.contact_spans({}), {})

    def test_a_foot_that_stays_planted_while_it_rolls_does_not_slide(self):
        self.assertEqual(sr.contact_slide({"foot_n": (1.0, 1.0)}, {"foot_n": (1.0, 1.3)}), 0.0, "the heel stays where it came down")
        self.assertEqual(sr.contact_slide({"foot_n": (1.0, 1.3)}, {"foot_n": (1.3, 1.3)}), 0.0, "the toe stays where it is as the heel lifts")

    def test_a_foot_dragged_along_the_ground_slides_by_how_far(self):
        self.assertAlmostEqual(sr.contact_slide({"foot_n": (1.0, 1.3)}, {"foot_n": (1.05, 1.35)}), 0.05)

    def test_a_foot_that_has_just_come_down_or_gone_up_is_not_a_slide(self):
        self.assertEqual(sr.contact_slide({}, {"foot_n": (5.0, 5.3)}), 0.0)
        self.assertEqual(sr.contact_slide({"foot_n": (1.0, 1.3)}, {}), 0.0)

    def test_the_other_foot_taking_the_step_is_not_the_first_one_sliding(self):
        self.assertEqual(sr.contact_slide({"foot_n": (0.0, 0.2)}, {"foot_f": (0.3, 0.5)}), 0.0)
        self.assertEqual(sr.contact_slide({"foot_n": (0.0, 0.2), "foot_f": (1.0, 1.2)}, {"foot_n": (0.0, 0.2), "foot_f": (1.0, 1.2)}), 0.0)

    def test_the_worst_foot_is_the_one_reported(self):
        self.assertAlmostEqual(sr.contact_slide({"a": (0.0, 0.2), "b": (1.0, 1.2)}, {"a": (0.0, 0.2), "b": (1.1, 1.3)}), 0.1)

    def test_a_body_walking_on_frozen_feet_slides_by_how_far_it_goes(self):
        # the feet rest on the same spot in the pose but the body moves 2.33 px a tick: a planted foot is carried along
        before = sr.contact_spans({"foot_n": [(1.0, 0.0), (1.2, 0.0)]})
        after = sr.contact_spans({"foot_n": [(1.0 + 0.0583, 0.0), (1.2 + 0.0583, 0.0)]})
        self.assertAlmostEqual(sr.contact_slide(before, after) * 40.0, 2.33, places=2)


class PoseChangeTests(unittest.TestCase):
    """The instants a gait changes pose, found between the ticks: a planted foot is judged where the continuous gait would be, not where the 60 hertz ticks happen to fall."""

    def walking(self, vx, ticks=240):
        return {"species": "goblin", "script": "w", "fps": 60, "start": [0.0, 0.0], "ticks": [tick(i, x=vx * i / 60.0, vx=vx) for i in range(ticks)]}

    def test_consecutive_changes_are_a_frames_worth_of_stride_apart(self):
        clips = goblin_clips()
        for vx in (60.0, 105.0, 140.0):
            changes = sr.pose_changes(sr.playback(self.walking(vx), clips, WALK_SPEED, every=1), clips, WALK_SPEED)
            self.assertGreater(len(changes), 20)
            n = len(clips["walk"].frames)
            step = sr.stride_of(clips["walk"], "walk", WALK_SPEED) / n
            for a, b in zip(changes, changes[1:]):
                skipped = (b.frame - a.frame) % n  # a body faster than the clip's own pace passes over a frame now and then, as the game's does
                self.assertGreaterEqual(skipped, 1)
                self.assertAlmostEqual(b.x - a.x, step * skipped, places=6, msg="speed %s" % vx)

    def test_a_change_carries_the_pose_it_changes_to_and_where_the_body_is_then(self):
        clips = goblin_clips()
        frames = sr.playback(self.walking(105.0), clips, WALK_SPEED, every=1)
        c = sr.pose_changes(frames, clips, WALK_SPEED)[3]
        self.assertEqual((c.rot, c.root), clips["walk"].frames[c.frame])
        self.assertEqual(c.state, "walk")
        self.assertTrue(any(f.x <= c.x <= f.x + 105.0 / 60.0 + 1e-9 for f in frames), "between two ticks")

    def test_standing_and_flying_change_no_gait_pose(self):
        clips = goblin_clips()
        ticks = [tick(i, surface="air", on_floor=False, vy=-50.0, x=i * 2.0) for i in range(30)]
        frames = sr.playback({"species": "goblin", "script": "j", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}, clips, WALK_SPEED, every=1)
        self.assertEqual(sr.pose_changes(frames, clips, WALK_SPEED), [])


class StrideRunTests(unittest.TestCase):
    """Which pose changes are steps of one stride: the check compares those, however slow the walk, and none across a stop or a change of gait."""

    def rec(self, ticks):
        return {"species": "goblin", "script": "w", "fps": 60, "start": [0.0, 0.0], "ticks": ticks}

    def test_a_very_slow_walk_is_still_one_stride_with_many_ticks_between_steps(self):
        clips = goblin_clips()
        frames = sr.playback(self.rec([tick(i, x=11.5 * i / 60.0, vx=11.5) for i in range(300)]), clips, WALK_SPEED, every=1)
        changes = sr.pose_changes(frames, clips, WALK_SPEED)
        gaps = [b.pose_frame.tick - a.pose_frame.tick for a, b in zip(changes, changes[1:])]
        self.assertGreater(min(gaps), 5, "a pose lasts six ticks or more: the rate is held at the game's lowest")
        self.assertEqual({c.run for c in changes}, {changes[0].run}, "one stride")

    def test_a_stop_and_a_change_of_gait_start_a_new_stride(self):
        clips = goblin_clips()
        walk = [tick(i, x=100.0 * i / 60.0, vx=100.0) for i in range(60)]
        stop = [tick(60 + i, x=100.0) for i in range(30)]
        run = [tick(90 + i, x=100.0 + 200.0 * i / 60.0, vx=200.0) for i in range(60)]
        again = [tick(150 + i, x=300.0 + 100.0 * i / 60.0, vx=100.0) for i in range(60)]
        frames = sr.playback(self.rec(walk + stop + run + again), clips, WALK_SPEED, every=1)
        runs = []
        for c in sr.pose_changes(frames, clips, WALK_SPEED):
            if not runs or runs[-1][0] != c.run:
                runs.append((c.run, c.state))
        self.assertEqual([state for _, state in runs], ["walk", "run", "walk"])
        self.assertEqual(len({r for r, _ in runs}), 3)


class CastTests(unittest.TestCase):
    """A gesture judged in place: the body stands where the course starts and casts, for the time the engine gives a verb (windup 0.35 s, then recovery 0.30 s)."""

    def test_a_cast_recording_stands_for_the_windup_and_the_recovery(self):
        rec = sr.cast_recording("slam")
        ticks = rec["ticks"]
        cast = [t for t in ticks if t["cast"] == "slam"]
        self.assertEqual(len(cast), 21 + 18, "0.35 s of windup and 0.30 s of recovery at 60 ticks a second")
        self.assertEqual([t["cast"] for t in ticks[:3]], ["", "", ""], "it stands before it casts")
        self.assertEqual(ticks[-1]["cast"], "", "and after")
        self.assertEqual({(t["x"], t["y"]) for t in ticks}, {(100.0, 0.0)}, "the gesture does not move the body")
        self.assertEqual([t["cast_t"] for t in cast][:2], [0.0, round(1.0 / 60.0, 4)])
        self.assertTrue(all(t["on_floor"] and t["surface"] == "floor" and t["speed"] == 0.0 for t in ticks))

    def test_a_cast_tick_is_in_the_cast_state(self):
        ticks = sr.cast_recording("slam")["ticks"]
        self.assertEqual(sr.state_of(ticks[0], WALK_SPEED), "idle")
        self.assertEqual(sr.state_of([t for t in ticks if t["cast"]][0], WALK_SPEED), "cast")

    def test_the_cast_plays_the_attack_clip_from_its_start_to_its_end(self):
        clips = goblin_clips()
        frames = sr.playback(sr.cast_recording("slam"), clips, WALK_SPEED, every=1)
        cast = [f for f in frames if f.state == "cast"]
        self.assertEqual({f.clip for f in cast}, {"attack"})
        self.assertEqual(cast[0].frame, 0)
        windup = bm.ATTACK_WINDUP
        impact = [f for f in cast if f.t >= cast[0].t + 0.35 - 1e-9][0]
        self.assertEqual(impact.frame, windup, "the first frame after the windup is showing when the verb fires")
        self.assertEqual(cast[-1].frame, len(clips["attack"].frames) - 1, "the last frame is the rest pose it came from")

    def test_a_creature_with_no_attack_clip_has_no_pose_for_a_cast(self):
        clips = goblin_clips()
        del clips["attack"]
        with self.assertRaises(sr.NoPose) as caught:
            sr.playback(sr.cast_recording("slam"), clips, WALK_SPEED, every=1)
        self.assertEqual(caught.exception.state, "cast")

    def test_every_gesture_can_be_cast(self):
        import verb_anims
        for name in verb_anims.ARCHETYPES:
            self.assertEqual(sr.cast_recording(name)["script"], "gesture_" + name)


class GifTests(unittest.TestCase):
    def test_a_gif_times_frames_in_hundredths_so_the_durations_share_out_the_rounding(self):
        d = sr.gif_durations(60, 60.0)  # a sixtieth of a second is not a whole hundredth
        self.assertEqual(sum(d), 1000)
        self.assertTrue(set(d) <= {10, 20})
        d = sr.gif_durations(40, 20.0)
        self.assertEqual(set(d), {50})

    def test_the_total_is_what_the_frames_take_to_play(self):
        for n, fps in ((61, 60.0), (37, 30.0), (13, 24.0)):
            self.assertAlmostEqual(sum(sr.gif_durations(n, fps)), 1000.0 * n / fps, delta=10)


class ArgumentTests(unittest.TestCase):
    def test_a_decimation_below_one_is_refused(self):
        import argparse
        for bad in ("0", "-2", "x"):
            with self.assertRaises(argparse.ArgumentTypeError):
                sr.positive_int(bad)
        self.assertEqual(sr.positive_int("3"), 3)


class RunFactorTests(unittest.TestCase):
    def test_a_creatures_own_run_factor_sets_the_stride_of_its_run(self):
        clips = goblin_clips()
        self.assertAlmostEqual(sr.stride_of(clips["run"], "run", WALK_SPEED, 3.0), WALK_SPEED * 3.0 * sum(clips["run"].durations))
        self.assertAlmostEqual(sr.stride_of(clips["walk"], "walk", WALK_SPEED, 3.0), WALK_SPEED * sum(clips["walk"].durations), msg="a walk is the walk's")

    def test_playback_turns_a_run_by_its_own_factor(self):
        clips = goblin_clips()
        rec = {"species": "wolf", "script": "r", "fps": 60, "start": [0.0, 0.0], "ticks": [tick(i, x=300.0 * i / 60.0, vx=300.0) for i in range(60)]}
        a = sr.playback(rec, clips, WALK_SPEED, every=1, run_factor=1.9)
        b = sr.playback(rec, clips, WALK_SPEED, every=1, run_factor=3.0)
        self.assertAlmostEqual(a[-1].phase * 1.9, b[-1].phase * 3.0, places=6, msg="a faster-built run turns slower for the same speed")


if __name__ == "__main__":
    unittest.main()
