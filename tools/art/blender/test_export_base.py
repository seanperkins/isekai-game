"""Cutting a render into a shipped creature's states (export_base.py): pure Python."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import export_base as eb  # noqa: E402
import goblin_forms  # noqa: E402
import held  # noqa: E402

META = {"anims": {"idle": 4, "run": 3, "attack": 10, "hurt": 5, "die": 8, "walk": 6},
        "durations": {"idle": [0.15] * 4, "run": [0.05] * 3, "attack": [0.06] * 10, "hurt": [0.05] * 5, "die": [0.1] * 8, "walk": [0.1] * 6}}


class PlanTest(unittest.TestCase):
    def setUp(self):
        self.frames, self.table = eb.plan(eb.SPECS["gloom_wolf"], dict(META, anims=dict(META["anims"], rise=1)))

    def test_every_state_the_game_asks_of_the_wolf_has_a_clip_with_frames_that_exist(self):
        for state in ("idle", "walk", "windup", "charge", "rest", "stunned", "hurt", "downed"):
            self.assertIn(state, self.table)
        names = {new for new, _, _ in self.frames}
        for clip in self.table.values():
            self.assertTrue(set(clip["frames"]) <= names)

    def test_the_states_are_taken_from_the_right_render_frames(self):
        by = {new: src for new, src, _ in self.frames}
        self.assertEqual(by["windup_1"], "attack_2")
        self.assertEqual(by["downed_1"], "die_7", "the last frame of the death")
        self.assertEqual([by["charge_%d" % i] for i in (1, 2, 3)], ["run_0", "run_1", "run_2"])

    def test_loops_loop_and_a_single_frame_is_one_frame_at_one_fps(self):
        self.assertTrue(self.table["idle"]["loop"] and self.table["walk"]["loop"] and self.table["charge"]["loop"])
        self.assertFalse(self.table["hurt"]["loop"])
        self.assertEqual(self.table["hurt"], {"frames": ["hurt_1"], "fps": 1.0, "loop": False})

    def test_the_charge_frames_carry_the_attack_shape_the_wolf_bites_with(self):
        opts = {new: o for new, _, o in self.frames}
        self.assertEqual(opts["charge_1"], {"attack_from": 0.55})
        self.assertEqual(opts["idle_1"], {})

    def test_the_goblin_has_the_follow_through_of_its_blow_for_when_the_player_casts(self):
        meta = dict(META, anims=dict(META["anims"], rise=1, fall=1, roll=4, slide=1, mantle=2, wall=1, land=1), windup=4,
                    durations=dict(META["durations"], rise=[0.1], fall=[0.1], roll=[0.1] * 4, slide=[0.1], mantle=[0.1, 0.1], wall=[0.1], land=[0.1]))
        frames, table = eb.plan(eb.SPECS["goblin"], meta)
        by = {new: src for new, src, _ in frames}
        self.assertEqual([by["recover_%d" % i] for i in range(1, 7)], ["attack_%d" % i for i in range(4, 10)], "the frames from the blow on, not the windup")
        self.assertFalse(table["recover"]["loop"])
        self.assertAlmostEqual(len(table["recover"]["frames"]) * 0.02, 6 * 0.06, delta=0.03)

    def test_the_skeleton_the_player_is_as_undead_has_the_same_states_as_the_goblin(self):
        self.assertEqual(eb.SPECS["undead_base"]["states"], eb.SPECS["goblin"]["states"], "a biped body of the player's: the same clips ask for the same frames")
        self.assertEqual(eb.SPECS["undead_base"]["render"], ("undead", "skeleton"))
        self.assertEqual(eb.SPECS["undead_base"]["key"], "undead_base", "its own sheet, not named for the skeleton creature whose size the rooms read")

    def test_the_goblins_states_are_the_ones_the_player_asks_for(self):
        _, table = eb.plan(eb.SPECS["goblin"], dict(META, windup=4, anims=dict(META["anims"], rise=1, fall=1, roll=4, slide=1, mantle=2, wall=1, land=1),
                                                   durations=dict(META["durations"], rise=[0.1], fall=[0.1], roll=[0.1] * 4, slide=[0.1], mantle=[0.1, 0.1], wall=[0.1], land=[0.1])))
        for state in ("idle", "run", "rise", "fall", "roll", "slide", "mantle", "wall"):
            self.assertIn(state, table)


class SpiderPlanTest(unittest.TestCase):
    META = {"anims": {"idle": 8, "walk": 12, "attack": 10, "hurt": 5, "die": 8},
            "durations": {"idle": [0.15] * 8, "walk": [0.1] * 12, "attack": [0.06] * 10, "hurt": [0.05] * 5, "die": [0.1] * 8}}

    def setUp(self):
        self.frames, self.table = eb.plan(eb.SPECS["spider"], self.META)

    def test_the_game_finds_every_frame_it_asks_the_sheet_for_by_name(self):
        names = {new for new, _, _ in self.frames}   # the sandbox draws crawl_1..4 and drop by frame name; the enemy plays the clips
        for name in ("hang_1", "hang_2", "drop", "crawl_1", "crawl_2", "crawl_3", "crawl_4", "stunned", "hurt", "downed"):
            self.assertIn(name, names)
        for state in ("hang", "drop", "crawl", "stunned", "hurt", "downed"):
            self.assertTrue(set(self.table[state]["frames"]) <= names)

    def test_crawl_is_four_even_frames_around_the_whole_walk_taking_as_long_as_it(self):
        by = {new: src for new, src, _ in self.frames}
        self.assertEqual([by["crawl_%d" % i] for i in (1, 2, 3, 4)], ["walk_0", "walk_3", "walk_6", "walk_9"])
        frames = self.table["crawl"]["frames"]
        self.assertAlmostEqual(len(frames) / self.table["crawl"]["fps"], 1.2, delta=0.04, msg="the walk's cycle")
        self.assertEqual({frames.count("crawl_%d" % i) for i in (1, 2, 3, 4)}, {len(frames) // 4})

    def test_what_names_a_frame_is_not_written_into_the_sheets_spec(self):
        for new, _, options in self.frames:
            self.assertNotIn("name", options, new)
            self.assertNotIn("even", options, new)


class SlimePlanTest(unittest.TestCase):
    META = {"anims": {"idle": 8, "walk": 12, "run": 10, "attack": 10, "hurt": 5, "die": 8},
            "durations": {"idle": [0.2] * 8, "walk": [0.05] * 12, "run": [0.04] * 10, "attack": [0.06] * 10, "hurt": [0.05] * 5, "die": [0.1] * 8}}

    def setUp(self):
        self.frames, self.table = eb.plan(eb.SPECS["slime"], self.META)
        self.names = {new for new, _, _ in self.frames}

    def test_the_sheet_has_the_frames_the_slimes_clips_and_the_cover_name(self):
        # data/slime_clips.json and EatCover name these; the weaver line's own sheets share them, so the clips stay as they are and the sheet fits them
        for name in ("idle_1", "idle_2", "run_1", "run_2", "run_3", "run_4", "rise", "fall", "land", "wall_1", "wall_2", "tackle", "spread_1", "spread_2",
                     "hurt", "rope", "cover_1", "cover_2", "cover_3", "cover_4", "cover_5"):
            self.assertIn(name, self.names)
        self.assertNotIn("idle_3", self.names, "the idle is two poses and the run four, as the clips have them")
        self.assertNotIn("run_5", self.names)

    def test_the_clips_file_is_left_as_it_is(self):
        self.assertIsNone(eb.SPECS["slime"].get("file"), "the slime's own clips stay")

    def test_a_flat_pose_is_taken_from_the_flat_frames_of_the_death_and_a_tall_one_from_a_tall_frame(self):
        by = {new: src for new, src, _ in self.frames}
        self.assertEqual([by["spread_1"], by["spread_2"]], ["die_3", "die_4"])
        self.assertEqual(by["rise"], "run_4")
        self.assertEqual({new: o for new, _, o in self.frames}["tackle"], {"attack_from": 0.62}, "the tackle's attack region is in front of it, as it was drawn")
        self.assertEqual([by["cover_3"], by["cover_4"]], ["die_3", "die_4"], "the engulfing is the flat spread, held")


class InstallTest(unittest.TestCase):
    def render(self, tmp, meta):
        """A fake render of a base creature in `tmp`/render: meta.json and one tiny frame (and normal map) for each frame the meta names."""
        from PIL import Image
        os.makedirs(os.path.join(tmp, "render", "raw"))
        os.makedirs(os.path.join(tmp, "render", "frames"))
        with open(os.path.join(tmp, "render", "raw", "meta.json"), "w") as fh:
            json.dump(meta, fh)
        for anim, count in meta["anims"].items():
            for i in range(count):
                for suffix in ("", "_n"):
                    Image.new("RGBA", (4, 4), (10, 20, 30, 255)).save(os.path.join(tmp, "render", "frames", "%s_%d%s.png" % (anim, i, suffix)))
        os.makedirs(os.path.join(tmp, "data"))
        os.makedirs(os.path.join(tmp, "tools", "art"))
        return os.path.join(tmp, "render")

    def test_a_slime_is_cut_to_its_own_pixels_and_a_walker_about_its_centre_and_each_writes_its_own_clip_file(self):
        meta = SlimePlanTest.META
        for name, centred, path, key in (("slime", False, None, None), ("spider", True, "data/enemy_clips.json", "spider")):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                folder = self.render(tmp, dict(meta, anims=dict(meta["anims"]), durations=meta["durations"]))
                if name == "spider":
                    with open(os.path.join(tmp, "data", "enemy_clips.json"), "w") as fh:
                        json.dump({"spider": {}, "wolf": {"keep": True}}, fh)
                eb.install(name, folder, root=tmp, assemble=False)
                with open(os.path.join(tmp, "tools", "art", name + "_frames.json")) as fh:
                    self.assertEqual(json.load(fh).get("centred_frames"), centred)
                if path is None:
                    self.assertEqual(os.listdir(os.path.join(tmp, "data")), [], "the clips file is not written")
                    continue
                with open(os.path.join(tmp, path)) as fh:
                    written = json.load(fh)
                self.assertIn("crawl", written[key])
                self.assertEqual(written["wolf"], {"keep": True}, "the others' clips are left alone")


class HeldTest(unittest.TestCase):
    render = InstallTest.render

    def goblin_meta(self, **more):
        anims = dict(META["anims"], rise=1, fall=1, roll=4, slide=1, mantle=2, wall=1, land=1)
        durations = dict(META["durations"], rise=[0.1], fall=[0.1], roll=[0.1] * 4, slide=[0.1], mantle=[0.1, 0.1], wall=[0.1], land=[0.1])
        return dict(META, anims=anims, durations=durations, windup=4, creature="goblin", ppu=40.0, **more)

    def test_the_base_export_keeps_hands_through_its_renamed_and_picked_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            meta = self.goblin_meta(hold=False)
            meta["hands"] = {"%s_%d" % (anim, i): {"n": [10.0 + i, 20.0, 5.0 + i], "f": [8.0, 21.0, -3.0]} for anim, count in meta["anims"].items() for i in range(count)}
            folder = self.render(tmp, meta)
            with open(os.path.join(tmp, "data", "enemy_clips.json"), "w") as fh:
                json.dump({}, fh)
            eb.install("goblin", folder, root=tmp, assemble=False)
            with open(os.path.join(tmp, "tools", "art", "goblin_frames.json")) as fh:
                frames = {f["name"]: f for f in json.load(fh)["frames"]}
            with open(os.path.join(tmp, "data", "held_items.json")) as fh:
                table = json.load(fh)
        by_source = {new: src for new, src, _ in eb.plan(eb.SPECS["goblin"], meta)[0]}
        self.assertEqual(by_source["run_2"], "run_1", "the plan renames run_1 to run_2")
        self.assertEqual(frames["run_2"]["hands"], meta["hands"]["run_1"])
        self.assertTrue(all("hands" in f for f in frames.values()))
        self.assertEqual(table["forms"]["goblin"], {"scale": round(held.form_scale(goblin_forms.FORMS["goblin"], 40.0), 4)})

    def test_an_armed_goblin_render_is_refused_and_a_wolf_is_not_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = self.render(tmp, self.goblin_meta())
            with self.assertRaises(ValueError):
                eb.install("goblin", folder, root=tmp, assemble=False)
        with tempfile.TemporaryDirectory() as tmp:
            folder = self.render(tmp, dict(META, creature="wolf", windup=4))
            with open(os.path.join(tmp, "data", "enemy_clips.json"), "w") as fh:
                json.dump({"gloom_wolf": {}}, fh)
            eb.install("gloom_wolf", folder, root=tmp, assemble=False)
            self.assertFalse(os.path.exists(os.path.join(tmp, "data", "held_items.json")))


class WidthsTest(unittest.TestCase):
    def test_a_manifest_names_the_width_each_frame_came_out_at(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest, sheet = os.path.join(tmp, "m.json"), os.path.join(tmp, "s.json")
            with open(manifest, "w") as fh:
                json.dump({"set": "x", "frames": [{"name": "a", "width": 0, "native": True}, {"name": "b", "width": 0, "native": True, "attack_from": 0.5}]}, fh)
            with open(sheet, "w") as fh:
                json.dump({"frames": {"a": {"rect": [0, 0, 31, 20]}, "b": {"rect": [32, 0, 47, 20]}}}, fh)
            eb.write_widths(manifest, sheet)
            with open(manifest) as fh:
                frames = json.load(fh)["frames"]
            self.assertEqual([f["width"] for f in frames], [31, 47])
            self.assertEqual(frames[1]["attack_from"], 0.5, "the rest of an entry stays")


class SizingTest(unittest.TestCase):
    def test_a_base_creature_walks_at_the_speed_of_its_own_stat_not_the_default(self):
        import sizing
        self.assertAlmostEqual(sizing.speed_of("spider", None), 66.0, msg="spd 110 (data/creatures/spider.tres)")
        self.assertAlmostEqual(sizing.speed_of("wolf", None), 60.0, msg="spd 100 (data/creatures/gloom_wolf.tres)")
        self.assertAlmostEqual(sizing.speed_of("goblin", None), 60.0, msg="the base goblin is the player's: the glue gives it its own")

    def test_a_base_creature_is_matched_by_the_dimension_the_game_reads_and_a_form_by_area(self):
        import sizing
        old = (54.0, 37.0)
        extent = (2.0, 1.0)
        self.assertAlmostEqual(extent[0] * sizing.pixels_per_unit(extent, old, "width"), 54.0)
        self.assertAlmostEqual(extent[1] * sizing.pixels_per_unit(extent, old, "height"), 37.0)
        ppu = sizing.pixels_per_unit(extent, old)
        self.assertAlmostEqual(extent[0] * ppu * extent[1] * ppu, 54.0 * 37.0)
        self.assertAlmostEqual(extent[0] * sizing.pixels_per_unit(extent, (50.0, None), "height"), 50.0, msg="with no still to match it is the width")


if __name__ == "__main__":
    unittest.main()
