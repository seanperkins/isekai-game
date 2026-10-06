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
    clips = {"idle": bm.idle_clip(body), "walk": bm.gait_clip(body, "walk", walk_cycle, walk_stride), "run": bm.gait_clip(body, "run", run_cycle, run_stride)}
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


if __name__ == "__main__":
    unittest.main()
