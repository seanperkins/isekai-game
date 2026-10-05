"""Checks for tools/build_form_verbs.py and the verb columns of tools/build_species_forms.py. Run from anywhere:
  python3 -m unittest tools/test_build_form_verbs.py
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_form_verbs as bfv  # noqa: E402
import build_species_forms as bsf  # noqa: E402


class RowsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.rows = bfv.load_rows()
        cls.slime = {f["dataId"]: f for f in bsf.slime_forms()}
        cls.others = {f["dataId"]: f for f in bsf.species_forms()}

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_rows_name_known_forms_and_fidelity(self):
        self.assertGreater(len(self.rows), 0)
        for r in self.rows:
            self.assertTrue(r["form"] in self.slime or r["form"] in self.others, r["form"])
            self.assertIn(r["fidelity"], ("full", "approx", "needs"))
            self.assertTrue(r["name"] and r["spec"].get("kind"))

    def test_a_form_has_one_row_at_most(self):
        ids = [r["form"] for r in self.rows]
        self.assertEqual(len(ids), len(set(ids)))

    def test_skill_tres_is_a_form_verb_with_the_spec(self):
        row = next(r for r in self.rows if r["form"] == "gleipnir")
        text = bfv.skill_tres(row)
        self.assertIn('id = "verb_gleipnir"', text)
        self.assertIn('source = "form_verb"', text)
        self.assertIn('"scene": "res://scenes/abilities/verb.tscn"', text)
        self.assertIn('"kind": "bolt"', text)
        self.assertIn("mp_cost = %d" % row["mp"], text)
        self.assertNotIn("unlock", text)

    def test_a_form_gets_its_verb_and_grant(self):
        f = self.slime["gleipnir"]
        self.assertEqual(f["verbId"], "verb_gleipnir")
        self.assertIn("verb_gleipnir", f["grants"])
        text = bsf.tres(f)
        self.assertIn('verb = "verb_gleipnir"', text)

    def test_a_form_without_a_row_has_no_verb(self):
        f = self.slime["quicksilver_slime"]
        self.assertNotIn("verbId", f)
        self.assertNotIn("verb =", bsf.tres(f).replace("verb_text =", ""))

    def test_an_unknown_form_in_the_table_is_refused(self):
        with self.assertRaises(ValueError):
            bsf.check_verb_rows([{"form": "no_such_form", "name": "x", "mp": 1, "value": 0, "spec": {"kind": "bolt"}, "fidelity": "full", "text": "t", "note": ""}],
                                list(self.slime) + list(self.others))


if __name__ == "__main__":
    unittest.main()


class SpeciesRowsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.rows = {r["form"]: r for r in bfv.load_rows()}
        cls.forms = bsf.species_forms()

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_every_wolf_and_undead_form_has_a_row(self):
        for f in self.forms:
            if f["species"] in ("wolf", "undead"):
                self.assertIn(f["dataId"], self.rows)

    def test_full_means_no_note_and_the_rest_say_what_is_missing(self):
        for r in self.rows.values():
            self.assertEqual(r["note"] == "", r["fidelity"] == "full", r["form"])

    def test_a_form_is_named_once_and_its_skill_id_follows_it(self):
        self.assertEqual(len(self.rows), len(bfv.load_rows()))
        for f in self.forms:
            if f["dataId"] in self.rows:
                self.assertEqual(f["verbId"], bfv.skill_id(f["dataId"]))
