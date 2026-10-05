"""Checks for tools/build_form_gates.py and the gates it writes. Run from anywhere:
  python3 -m unittest tools/test_build_form_gates.py
"""
import math
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_form_gates as bfg  # noqa: E402
import build_parts as bp  # noqa: E402
import build_species_forms as bsf  # noqa: E402


class RowsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.forms = bsf.species_forms()
        cls.rows = bfg.load_rows()
        cls.by_form = {r["form"]: r for r in cls.rows}

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_there_is_one_row_for_each_of_the_99_non_slime_forms_and_no_other(self):
        self.assertEqual(len(self.forms), 99)
        self.assertEqual(sorted(self.by_form), sorted(f["dataId"] for f in self.forms))
        self.assertEqual(len(self.rows), 99)

    def test_every_atom_is_well_shaped(self):
        bfg.check_rows(self.rows, [f["dataId"] for f in self.forms])

    def test_a_form_with_an_unknown_row_or_a_missing_row_is_refused(self):
        ids = [f["dataId"] for f in self.forms]
        with self.assertRaises(ValueError):
            bfg.check_rows(self.rows + [{"form": "wolf_nothing", "atoms": []}], ids)
        with self.assertRaises(ValueError):
            bfg.check_rows(self.rows[1:], ids)
        with self.assertRaises(ValueError):
            bfg.check_rows(self.rows + [self.rows[0]], ids)

    def test_a_bad_atom_is_refused(self):
        for atom in ({"kind": "feeling", "text": "x", "n": 1}, {"kind": "counter", "event": "defeated", "n": 0, "text": "x"},
                     {"kind": "counter", "event": "defeated", "n": 1}, {"kind": "reset_counter", "event": "defeated", "reset_on": "damaged", "n": 1, "text": "x"},
                     {"kind": "streak", "n": 1, "text": "x"},
                     {"kind": "any", "text": "x", "of": []}):
            with self.assertRaises(ValueError, msg=str(atom)):
                bfg.check_atom(atom, "t")

    def test_the_essence_atoms_split_the_stages_total_over_the_reads(self):
        for f in self.forms:
            atoms = bfg.essence_atoms(f["reads"], f["stage"])
            self.assertEqual([a["tags"]["essence"] for a in atoms], f["reads"], f["dataId"])
            want = math.ceil({2: 26, 3: 34, 4: 44}[f["stage"]] / len(f["reads"]))
            self.assertTrue(all(a["n"] == want and a["event"] == "absorbed" and a["kind"] == "counter" for a in atoms), f["dataId"])

    def test_later_elements_are_essence_atoms_like_the_rest(self):
        blood = bsf.species_forms()
        form = next(f for f in blood if f["dataId"] == "undead_vampire")
        self.assertIn("blood", [a["tags"]["essence"] for a in form["gate"]])

    def test_a_forms_gate_is_its_essence_then_its_deeds(self):
        form = next(f for f in self.forms if f["dataId"] == "wolf_amarok")
        self.assertEqual([a["event"] for a in form["gate"]], ["absorbed", "absorbed", "room_cleared"])
        self.assertEqual(form["gate"][-1]["tags"], {"alone": True})

    def test_every_form_has_a_gate_and_every_atom_has_text(self):
        for f in self.forms:
            self.assertTrue(f["gate"], f["dataId"])
            for a in f["gate"]:
                self.assertTrue(a["text"], f["dataId"])

    def test_a_gate_that_asks_for_a_part_names_a_part_that_exists(self):
        parts = {r["id"] for r in bp.load_rows()}
        for r in self.rows:
            for atom in r["atoms"]:
                if atom.get("event") in ("part_harvested", "graft_attached", "graft_shed") and "part" in atom.get("tags", {}):
                    self.assertIn(atom["tags"]["part"], parts, r["form"])

    def test_a_no_damage_streak_names_what_resets_it(self):
        form = next(f for f in self.forms if f["dataId"] == "wolf_beast_of_gevaudan")
        streak = [a for a in form["gate"] if a["kind"] == "streak"][0]
        self.assertEqual((streak["event"], streak["reset_on"]), ("defeated", "damaged"))

    def test_the_streak_gates_are_the_five_the_design_text_names(self):
        streaks = sorted(f["dataId"] for f in self.forms if any(a["kind"] == "streak" for a in f["gate"]))
        self.assertEqual(streaks, ["goblin_redcap", "spider_nightstalker", "spider_plaguemother", "undead_deadeye", "wolf_beast_of_gevaudan"])
        self.assertFalse(any(a["kind"] == "reset_counter" for f in self.forms for a in f["gate"]), "a gate wants the best run, not the current one")


class WriteTest(unittest.TestCase):
    def test_variant_writes_godots_text_form(self):
        self.assertEqual(bfg.variant({"kind": "counter", "tags": {"behind": True}, "n": 5, "text": 'a "q"'}),
                         '{"kind": "counter", "tags": {"behind": true}, "n": 5, "text": "a \\"q\\""}')
        self.assertEqual(bfg.variant([1, "a", False, []]), '[1, "a", false, []]')

    def test_the_checked_in_forms_are_what_the_generator_writes(self):
        old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        try:
            for f in bsf.species_forms():
                with open("data/forms/%s.tres" % f["dataId"], encoding="utf-8") as fh:
                    self.assertEqual(fh.read(), bsf.tres(f), f["dataId"])
        finally:
            os.chdir(old)


if __name__ == "__main__":
    unittest.main()
