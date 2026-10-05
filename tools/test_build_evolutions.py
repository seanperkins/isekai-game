"""Checks for tools/build_evolutions.py against the real document and data. Run from anywhere:
  python3 -m unittest tools/test_build_evolutions.py
The counts are pins: when the document gains or loses a form, update the number here with it.
"""
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_evolutions as be  # noqa: E402


class BuildEvolutionsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old_cwd = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.tmp = tempfile.TemporaryDirectory()
        cls.old_out = be.OUT
        be.OUT = cls.tmp.name
        cls.data = be.build()
        cls.forms = {f["id"]: f for f in cls.data["forms"]}

    @classmethod
    def tearDownClass(cls):
        be.OUT = cls.old_out
        os.chdir(cls.old_cwd)
        cls.tmp.cleanup()

    def test_form_counts_per_species_are_pinned(self):
        counts = {s["id"]: sum(s["counts"].values()) for s in self.data["species"]}
        self.assertEqual(counts, {"slime": 42, "wolf": 21, "undead": 29, "spider": 21, "goblin": 28})
        self.assertEqual(len(self.data["forms"]), 141)

    def test_every_species_has_at_least_three_lines_and_two_children_each(self):
        for s in self.data["species"]:
            self.assertGreaterEqual(len(s["lines"]), 3, s["id"])
        for f in self.data["forms"]:
            if f["stage"] in (2, 3):
                self.assertGreaterEqual(len(f["children"]), 2, f["id"])

    def test_parents_exist_and_stages_step_by_one(self):
        bases = {b["id"] for b in self.data["bases"]}
        for f in self.data["forms"]:
            if f["stage"] == 2:
                self.assertIn(f["parent"], bases, f["id"])
            else:
                self.assertEqual(self.forms[f["parent"]]["stage"], f["stage"] - 1, f["id"])

    def test_ids_are_unique(self):
        ids = [f["id"] for f in self.data["forms"]] + [b["id"] for b in self.data["bases"]]
        self.assertEqual(len(ids), len(set(ids)))
        cids = [c["id"] for c in self.data["creatures"]]
        self.assertEqual(len(cids), len(set(cids)))

    def test_every_form_has_a_host_a_twin_and_known_elements(self):
        for f in self.data["forms"]:
            self.assertTrue(f["host"], f["id"])
            self.assertTrue(set(f["reads"]) <= set(be.ELEMENTS), f["id"])
            self.assertTrue(set(f["twin"]["essence"]) <= set(be.ELEMENTS), f["id"])

    def test_a_new_twin_carries_exactly_its_tiers_essence_and_xp(self):
        for f in self.data["forms"]:
            if f["twin"]["status"] == "new":
                tier = self.data["tiers"][str(f["stage"])]
                self.assertEqual(sum(f["twin"]["essence"].values()), tier["essence"], f["id"])
                self.assertEqual(f["twin"]["xp"], tier["xp"], f["id"])

    def test_the_taratect_is_the_one_existing_twin_among_the_forms(self):
        existing = [f["id"] for f in self.data["forms"] if f["twin"]["status"] == "existing"]
        self.assertEqual(existing, ["S3B2"])

    def test_support_monsters_use_known_areas_and_elements(self):
        support = [c for c in self.data["creatures"] if c["kind"] == "support"]
        self.assertEqual(len(support), 28)
        for c in support:
            self.assertTrue(c["areas"], c["id"])
            self.assertTrue(set(c["essence"]) <= set(be.ELEMENTS), c["id"])
        twins_of = {c["twinOf"] for c in support if c["twinOf"]}
        self.assertEqual(twins_of, {"J1", "U1", "G1"})

    def test_every_species_base_has_a_twin(self):
        for b in self.data["bases"]:
            self.assertIn(b["twin"]["status"], ("existing", "new"), b["id"])
            self.assertTrue(b["twin"]["essence"], b["id"])

    def test_shipped_supply_matches_the_calibration(self):
        by = {e["id"]: e["shippedSupply"] for e in self.data["essences"]}
        self.assertEqual(by, {"water": 48, "earth": 94, "air": 57, "light": 11, "dark": 31, "fire": 0, "mind": 0, "blood": 0})
        cave = next(a for a in self.data["areas"] if a["id"] == "cave")["shippedEssence"]
        self.assertEqual((cave["water"], cave["earth"], cave["air"], cave["dark"]), (19, 8, 12, 10))

    def test_a_later_element_only_appears_where_it_arrives(self):
        # fire, mind and blood have no shipped supply, so every carrier is a new creature in a planned area.
        for e in self.data["essences"]:
            if e["later"]:
                self.assertEqual(e["existing"], [], e["id"])

    def test_the_data_file_is_a_script_that_holds_the_same_json(self):
        path = os.path.join(be.OUT, "evolutions-data.js")
        text = be.read(path)
        self.assertTrue(text.startswith("window.EVOLUTIONS = "))
        loaded = json.loads(text[len("window.EVOLUTIONS = "):].rstrip().rstrip(";"))
        self.assertEqual(len(loaded["forms"]), 141)


if __name__ == "__main__":
    unittest.main()
