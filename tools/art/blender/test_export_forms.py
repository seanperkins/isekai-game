"""Turning a render's meta into the engine's clips (export_forms.py): pure Python."""
import json
import os
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import export_forms as ex  # noqa: E402
import goblin_forms  # noqa: E402
import held  # noqa: E402

META = {
    "anims": {"idle": 2, "walk": 3, "attack": 4, "hurt": 2, "die": 3},
    "durations": {"idle": [0.2, 0.2], "walk": [0.1, 0.1, 0.1], "attack": [0.06, 0.12, 0.04, 0.1], "hurt": [0.04, 0.08], "die": [0.06, 0.1, 0.3]},
    "loops": {"idle": True, "walk": True, "attack": False, "hurt": False, "die": False},
    "windup": 2,
}


class ClipsOfTest(unittest.TestCase):
    def setUp(self):
        self.c = ex.clips_of(META)

    def test_the_loops_and_the_one_shots_are_what_the_render_said(self):
        self.assertTrue(self.c["idle"]["loop"] and self.c["walk"]["loop"])
        self.assertFalse(self.c["hurt"]["loop"])

    def test_an_attack_is_split_at_the_windup_into_the_two_clips_the_verb_states_play(self):
        self.assertEqual(self.c["windup"]["frames"][0], "attack_0")
        self.assertEqual(set(self.c["windup"]["frames"]), {"attack_0", "attack_1"})
        self.assertEqual(set(self.c["recover"]["frames"]), {"attack_2", "attack_3"})
        self.assertFalse(self.c["windup"]["loop"] or self.c["recover"]["loop"])
        self.assertEqual(len(self.c["windup"]["frames"]) + len(self.c["recover"]["frames"]), len(self.c["attack"]["frames"]))

    def test_a_held_frame_is_repeated_so_the_uneven_timing_survives(self):
        frames = self.c["windup"]["frames"]
        self.assertGreater(frames.count("attack_1"), frames.count("attack_0"))

    def test_a_death_ends_on_its_last_frame_as_the_downed_pose(self):
        self.assertEqual(self.c["downed"]["frames"], ["die_2"])
        self.assertEqual(self.c["die"]["frames"][-1], "die_2")

    def test_an_animation_a_form_lacks_gets_no_clip(self):
        c = ex.clips_of({"anims": {"idle": 2}, "durations": {"idle": [0.2, 0.2]}, "loops": {"idle": True}})
        self.assertEqual(set(c), {"idle"})

    def test_the_spec_names_every_frame_native_and_shares_one_box(self):
        spec = ex.spec_of("anim_x", ["idle_0", "idle_1"])
        self.assertTrue(spec["common_box"])
        self.assertTrue(all(f["native"] for f in spec["frames"]))


class IdsTest(unittest.TestCase):
    def test_a_twins_form_id_is_its_species_and_form_except_for_the_slime_which_is_bare(self):
        self.assertEqual(ex.form_id("goblin", "redcap"), "goblin_redcap")
        self.assertEqual(ex.form_id("wolf", "warg"), "wolf_warg")
        self.assertEqual(ex.form_id("slime", "kraken"), "kraken")


class TimingTest(unittest.TestCase):
    CONSTANTS = {"windup": 0.35, "recover": 0.30, "hurt": 0.25, "run_speed": 1.9}

    def meta(self, attack, hurt=(0.25,)):
        return {"anims": {"attack": len(attack), "hurt": len(hurt)}, "durations": {"attack": list(attack), "hurt": list(hurt)}, "windup": 2}

    def test_it_reads_the_timings_from_the_enemy_so_the_art_cannot_drift(self):
        c = ex.engine_constants()
        self.assertEqual(set(c), {"windup", "recover", "hurt", "run_speed"})
        self.assertGreater(c["windup"], c["recover"])

    def test_the_art_the_biped_motion_makes_matches_the_engine(self):
        import biped_motion as gm
        c = ex.engine_constants()
        self.assertEqual((gm.ENGINE_WINDUP, gm.ENGINE_RECOVER, gm.ENGINE_HURT), (c["windup"], c["recover"], c["hurt"]))
        import quad_motion as qm
        self.assertEqual((qm.ENGINE_WINDUP, qm.ENGINE_RECOVER, qm.ENGINE_HURT), (c["windup"], c["recover"], c["hurt"]))

    def test_matching_timings_pass(self):
        ex.check_timing(self.meta([0.2, 0.15, 0.1, 0.2]), self.CONSTANTS)

    def test_a_windup_that_is_too_short_or_too_long_is_refused(self):
        for attack in ([0.2, 0.1, 0.1, 0.2], [0.2, 0.2, 0.1, 0.2]):
            with self.assertRaises(ValueError):
                ex.check_timing(self.meta(attack), self.CONSTANTS)

    def test_a_recovery_that_outlasts_the_engines_is_refused_one_that_is_shorter_is_fine(self):
        with self.assertRaises(ValueError):
            ex.check_timing(self.meta([0.2, 0.15, 0.2, 0.2]), self.CONSTANTS)
        ex.check_timing(self.meta([0.2, 0.15, 0.1, 0.1]), self.CONSTANTS)

    def test_a_flinch_of_the_wrong_length_is_refused(self):
        with self.assertRaises(ValueError):
            ex.check_timing(self.meta([0.2, 0.15, 0.1, 0.2], hurt=(0.4,)), self.CONSTANTS)


class SpeedsTest(unittest.TestCase):
    def test_a_form_id_is_split_back_into_its_species_and_form(self):
        self.assertEqual(ex.split_id("wolf_fenrir"), ("wolf", "fenrir"))
        self.assertEqual(ex.split_id("goblin_giant_killer"), ("goblin", "giant_killer"))
        self.assertEqual(ex.split_id("undead_bone_colossus"), ("undead", "bone_colossus"))
        self.assertEqual(ex.split_id("kraken"), ("slime", "kraken"), "the slime's forms are named bare")

    def test_the_clip_file_carries_each_forms_walk_speed_beside_its_clips(self):
        import json
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "data"))
            ex.write_clips({"wolf_fenrir": {"idle": {"frames": ["a"], "fps": 1.0, "loop": True}}}, tmp, {"wolf_fenrir": 41.5})
            with open(os.path.join(tmp, ex.CLIPS_PATH)) as fh:
                data = json.load(fh)
            self.assertEqual(data["_walk_speeds"], {"wolf_fenrir": 41.5})
            self.assertIn("idle", data["wolf_fenrir"])
            ex.write_clips({"wolf_warg": {"idle": {"frames": ["b"], "fps": 1.0, "loop": True}}}, tmp, {"wolf_warg": 50.0})
            with open(os.path.join(tmp, ex.CLIPS_PATH)) as fh:
                data = json.load(fh)
            self.assertEqual(data["_walk_speeds"], {"wolf_fenrir": 41.5, "wolf_warg": 50.0}, "a later export keeps the others' speeds")
            self.assertEqual(sorted(k for k in data if not k.startswith("_")), ["wolf_fenrir", "wolf_warg"])


class WearableTest(unittest.TestCase):
    def test_a_form_with_no_twin_to_wear_its_clips_is_left_out(self):
        have = {"twin_spider_norn.tres", "twin_kraken.tres"}
        exists = lambda path: os.path.basename(path) in have
        self.assertEqual(ex.wearable("spider", ["norn", "cave_matriarch"], exists), (["norn"], ["cave_matriarch"]))
        self.assertEqual(ex.wearable("slime", ["kraken", "cube"], exists), (["kraken"], ["cube"]), "the slime twins are named bare")


if __name__ == "__main__":
    unittest.main()


def fake_render(tmp, meta):
    """A render folder in `tmp`: raw/meta.json and one tiny frame with a normal map for every frame the meta names, and the folders an install writes into."""
    folder = os.path.join(tmp, "render")
    os.makedirs(os.path.join(folder, "raw"))
    os.makedirs(os.path.join(folder, "frames"))
    with open(os.path.join(folder, "raw", "meta.json"), "w") as fh:
        json.dump(meta, fh)
    for anim, count in meta["anims"].items():
        for i in range(count):
            for suffix in ("", "_n"):
                Image.new("RGBA", (4, 4), (10, 20, 30, 255)).save(os.path.join(folder, "frames", "%s_%d%s.png" % (anim, i, suffix)))
    os.makedirs(os.path.join(tmp, "tools", "art"))
    return folder


def hands_for(meta):
    return {"%s_%d" % (anim, i): {"n": [10.0 + i, 20.0, 5.0], "f": [8.0, 21.0, -3.0]} for anim, count in meta["anims"].items() for i in range(count)}


class HeldTest(unittest.TestCase):
    META = {"anims": {"idle": 2, "die": 2}, "durations": {"idle": [0.2, 0.2], "die": [0.1, 0.3]}, "loops": {"idle": True, "die": False}, "ppu": 40.0}

    def meta(self, creature, **more):
        return dict(self.META, creature=creature, **more)

    def test_spec_of_carries_each_frames_hands(self):
        spec = ex.spec_of("anim_x", ["idle_0", "idle_1"], hands={"idle_0": {"n": [1.0, 2.0, 3.0]}})
        self.assertEqual(spec["frames"][0]["hands"], {"n": [1.0, 2.0, 3.0]})
        self.assertNotIn("hands", spec["frames"][1])

    def test_install_writes_the_hands_into_the_spec_and_the_form_entry_into_the_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            meta = self.meta("goblin", hold=False)
            meta["hands"] = hands_for(meta)
            ex.install("goblin", "smith", fake_render(tmp, meta), root=tmp, assemble=False, check=False)
            with open(os.path.join(tmp, "tools", "art", "anim_goblin_smith_frames.json")) as fh:
                frames = {f["name"]: f for f in json.load(fh)["frames"]}
            with open(os.path.join(tmp, "data", "held_items.json")) as fh:
                table = json.load(fh)
        self.assertEqual(frames["idle_1"]["hands"], meta["hands"]["idle_1"])
        self.assertEqual(table["forms"]["goblin_smith"], {"scale": round(held.form_scale(goblin_forms.FORMS["smith"], 40.0), 4), "n": "hammer", "f": "tongs"})

    def test_install_refuses_an_armed_goblin_render_and_does_not_check_a_wolf(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError) as caught:
                ex.install("goblin", "smith", fake_render(tmp, self.meta("goblin")), root=tmp, assemble=False, check=False)
            self.assertIn("hold", str(caught.exception))
            self.assertFalse(os.path.exists(os.path.join(tmp, "art_source")), "nothing was written")
        with tempfile.TemporaryDirectory() as tmp:
            ex.install("wolf", "warg", fake_render(tmp, self.meta("wolf")), root=tmp, assemble=False, check=False)

    def test_a_wolf_install_leaves_held_items_json_alone(self):
        with tempfile.TemporaryDirectory() as tmp:
            ex.install("wolf", "warg", fake_render(tmp, self.meta("wolf")), root=tmp, assemble=False, check=False)
            self.assertFalse(os.path.exists(os.path.join(tmp, "data", "held_items.json")))
