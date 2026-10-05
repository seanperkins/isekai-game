"""Checks for tools/build_creatures.py: the twins and support monsters as creature data. Run from anywhere:
  python3 -m unittest tools/test_build_creatures.py
"""
import glob
import os
import re
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_creatures as bc  # noqa: E402

STAGE_STATS = {2: {"max_hp": 6, "atk": 3, "def": 1, "spd": 90}, 3: {"max_hp": 14, "atk": 5, "def": 2, "spd": 90},
               4: {"max_hp": 26, "atk": 8, "def": 3, "spd": 100}}
SPEED = {"wolf": 20, "spider": 10, "undead": -20, "slime": -20, "goblin": 0}
SHIPPED = {"bat", "toad", "lizard", "spider", "water_pool", "serpent", "spore_moth", "mushroom_crab", "vine_snake", "pale_moth", "glass_eel",
           "cave_crayfish", "drift_jelly", "bog_lizardman", "storm_eel", "gloom_wolf", "armed_ant", "stone_drake", "taratect"}


def form_text(form_id):
    with open("data/forms/%s.tres" % form_id, encoding="utf-8") as fh:
        return fh.read()


class RowsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.rows = bc.creature_rows()
        cls.twins = [r for r in cls.rows if r["origin"] == "twin"]
        cls.support = [r for r in cls.rows if r["origin"] == "support"]

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_there_are_140_twins_and_29_support_monsters(self):
        self.assertEqual(len(self.twins), 140)
        self.assertEqual(len(self.support), 29)
        self.assertEqual(len({r["id"] for r in self.rows}), 169, "every id is unique")
        self.assertFalse({r["id"] for r in self.rows} & SHIPPED)

    def test_the_junk_heap_is_an_earth_support_monster_in_the_village(self):
        junk = next(r for r in self.support if r["id"] == "junk")
        self.assertEqual(junk["essences"], {"earth": 1})
        self.assertEqual(junk["role"], "common")
        self.assertIn("village", [a.lower() for a in junk["areas"]])

    def test_a_twin_is_twin_plus_its_form_id_and_the_form_exists(self):
        for r in self.twins:
            self.assertEqual(r["id"], "twin_" + r["form"])
            self.assertTrue(os.path.exists("data/forms/%s.tres" % r["form"]), r["id"])

    def test_the_stats_follow_the_stage_and_the_species(self):
        for r in self.twins:
            want = dict(STAGE_STATS[r["stage"]])
            want["spd"] += SPEED[r["species"]]
            self.assertEqual(r["stats"], want, r["id"])
        by_stage = {s: next(r for r in self.twins if r["stage"] == s and r["species"] == "goblin") for s in (2, 3, 4)}
        self.assertLess(by_stage[2]["stats"]["max_hp"], by_stage[3]["stats"]["max_hp"])
        self.assertLess(by_stage[3]["stats"]["max_hp"], by_stage[4]["stats"]["max_hp"])

    def test_the_tier_sets_the_essence_and_the_xp(self):
        for r in self.twins:
            self.assertEqual(sum(r["essences"].values()), {2: 3, 3: 8, 4: 12}[r["stage"]], r["id"])
            self.assertEqual(r["xp"], {2: 4, 3: 10, 4: 20}[r["stage"]], r["id"])

    def test_the_essence_goes_to_the_forms_reads(self):
        for r in self.twins:
            reads = re.search(r"^reads = \[(.*)\]", form_text(r["form"]), re.M)
            if reads:  # the slime's built forms carry no reads line
                self.assertEqual(set(r["essences"]), set(re.findall(r'"(\w+)"', reads.group(1))), r["id"])

    def test_species_set_the_flags(self):
        for r in self.twins:
            self.assertEqual(bool(r["flags"].get("pack")), r["species"] in ("wolf", "goblin"), r["id"])
            self.assertEqual(bool(r["flags"].get("charges")), r["species"] == "wolf", r["id"])

    def test_a_twin_has_its_forms_verb_and_art(self):
        for r in self.twins:
            text = form_text(r["form"])
            verb = re.search(r'^verb = "(\w+)"', text, re.M)
            self.assertEqual(r["verb"], verb.group(1) if verb else "", r["id"])
            sheet = re.search(r'^sprite_set = "(\w+)"', text, re.M)
            frame = re.search(r'^sprite_frame = "(\w+)"', text, re.M)
            # a form with a still wears it; one without (a built slime form) is the slime sheet tinted, as the player draws it
            # (a sheet with no frame named shows its idle_1, as FormEffects.look does)
            self.assertEqual((r["sprite_set"], r["sprite_frame"]), (sheet.group(1), frame.group(1) if frame else "idle_1") if sheet else ("slime", "idle_1"), r["id"])
            if not sheet:
                tint = [float(x) for x in re.search(r"^tint = Color\(([^)]*)\)", text, re.M).group(1).split(",")][:3]
                self.assertEqual(r["sprite_tint"], tint, r["id"])
            size = re.search(r"^size = ([\d.]+)", text, re.M)
            self.assertAlmostEqual(r["sprite_size"], float(size.group(1)) if size else 1.0, places=3, msg=r["id"])

    def test_every_creature_has_a_look(self):
        for r in self.rows:
            self.assertTrue(r["sprite_set"] or r["wears"], r["id"])
            if r["wears"]:
                self.assertIn(r["wears"], SHIPPED, r["id"])

    def test_support_monsters_keep_the_design_tables_numbers(self):
        by_id = {r["id"]: r for r in self.support}
        self.assertEqual(by_id["skeleton"]["essences"], {"dark": 2})
        self.assertEqual(by_id["skeleton"]["xp"], 3)
        self.assertEqual(by_id["chapel_priest"]["essences"], {"light": 4, "mind": 4})
        self.assertEqual(by_id["chapel_priest"]["role"], "elite")
        self.assertTrue(by_id["shield_guard"]["flags"].get("armored_charger"))
        self.assertTrue(by_id["ghost"]["flags"].get("drifter"))
        self.assertEqual((by_id["wild_slime"]["sprite_set"], by_id["wild_slime"]["sprite_frame"]), ("slime", "idle_1"))

    def test_the_drops_are_the_design_tables(self):
        drops = {r["id"]: sorted(p for p, _ in r["drops"]) for r in self.rows if r["drops"]}
        self.assertEqual(drops["skeleton"], ["ribs", "skull"])
        self.assertEqual(drops["twin_undead_ghoul"], ["claw", "flesh", "ribs"])
        self.assertEqual(drops["moon_hare"], ["moonstone"])
        self.assertEqual(len(drops), 13)
        self.assertEqual([c for p, c in next(r for r in self.rows if r["id"] == "twin_undead_lich")["drops"]], [0.1])

    def test_the_tres_writes_the_drops(self):
        text = bc.tres(next(r for r in self.rows if r["id"] == "moon_hare"))
        self.assertIn('drops = [{"part": "moonstone", "chance": 0.15}]', text)

    def test_the_three_species_bases_say_their_species_and_no_other_support_monster_does(self):
        species = {r["id"]: r["species"] for r in self.support if r["species"]}
        self.assertEqual(species, {"wild_slime": "slime", "skeleton": "undead", "village_goblin": "goblin"})

    def test_a_support_monster_with_no_art_of_its_own_wears_a_shipped_creature_tinted(self):
        rat = next(r for r in self.support if r["id"] == "cave_rat")
        self.assertIn(rat["wears"], SHIPPED)
        self.assertNotEqual(rat["sprite_tint"], [1.0, 1.0, 1.0])


class WriteTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.rows = bc.creature_rows()

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_the_tres_writes_every_field_a_creature_needs(self):
        row = next(r for r in self.rows if r["id"] == "twin_wolf_fenrir")
        text = bc.tres(row)
        for part in ('script_class="CreatureDef"', 'id = "twin_wolf_fenrir"', 'origin = "twin"', 'form = "wolf_fenrir"', 'species = "wolf"',
                     'stage = 4', 'verb = "verb_wolf_fenrir"', 'sprite_set = "forms_wolf"', 'sprite_frame = "fenrir"', "pack = true", "charges = true", "xp = 20"):
            self.assertIn(part, text)
        self.assertEqual(text, bc.tres(row), "the same row writes the same text")

    def test_build_writes_one_file_per_row_and_the_id_list(self):
        with tempfile.TemporaryDirectory() as out:
            ids_path = os.path.join(out, "menagerie_ids.gd")
            bc.build(out, ids_path)
            self.assertEqual(len(glob.glob(os.path.join(out, "*.tres"))), 169)
            text = open(ids_path, encoding="utf-8").read()
            self.assertIn("class_name MenagerieIds", text)
            self.assertIn('"twin_wolf_fenrir"', text)
            self.assertIn('"wild_slime"', text)
            self.assertIn("const ALL := TWINS + SUPPORT", text)

    def test_the_checked_in_data_is_what_the_generator_writes(self):
        for r in self.rows:
            with open("data/creatures/%s.tres" % r["id"], encoding="utf-8") as fh:
                self.assertEqual(fh.read(), bc.tres(r), r["id"])


if __name__ == "__main__":
    unittest.main()
