"""Checks for tools/build_species_forms.py against the design doc. Run from anywhere:
  python3 -m unittest tools/test_build_species_forms.py
"""
import os
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_species_forms as bsf  # noqa: E402


class SlugTest(unittest.TestCase):
    def test_slug_folds_accents_and_drops_apostrophes(self):
        self.assertEqual(bsf.slug("Úlfheðinn"), "ulfhedinn")
        self.assertEqual(bsf.slug("Beast of Gévaudan"), "beast_of_gevaudan")
        self.assertEqual(bsf.slug("Cŵn Annwn"), "cwn_annwn")
        self.assertEqual(bsf.slug("Heart-Weigher"), "heart_weigher")
        self.assertEqual(bsf.slug("Philosopher's Stone"), "philosophers_stone")


class FormsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.forms = bsf.species_forms()
        cls.by_id = {f["dataId"]: f for f in cls.forms}

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_every_non_slime_form_gets_a_unique_prefixed_id(self):
        self.assertEqual(len(self.forms), 99)
        self.assertEqual(len(self.by_id), 99)
        for f in self.forms:
            self.assertTrue(f["dataId"].startswith(f["species"] + "_"), f["dataId"])
            self.assertNotEqual(f["species"], "slime")

    def test_a_stage_two_form_grows_from_its_species_and_a_child_from_its_parents_id(self):
        moon = self.by_id["wolf_moonbound"]
        self.assertEqual(moon["parents"], ["wolf"])
        self.assertEqual(self.by_id["wolf_loup_garou"]["parents"], ["wolf_moonbound"])
        self.assertEqual(self.by_id["wolf_loup_garou"]["lineage"], "moonbound")
        self.assertEqual(self.by_id["wolf_beast_of_gevaudan"]["lineage"], "moonbound")

    def test_stats_follow_the_stage_base_and_the_reads_flavour(self):
        self.assertEqual(self.by_id["wolf_moonbound"]["stats"], {"atk": 1, "max_hp": 5, "max_mp": 3})
        self.assertEqual(self.by_id["wolf_loup_garou"]["stats"], {"atk": 3, "max_hp": 12, "max_mp": 6})
        self.assertEqual(self.by_id["wolf_dire_wolf"]["stats"], {"atk": 1, "def": 2, "max_hp": 12, "max_mp": 6})

    def test_size_and_tint_follow_the_stage(self):
        self.assertEqual(self.by_id["wolf_moonbound"]["size"], 1.12)
        self.assertEqual(self.by_id["wolf_fenrir"]["size"], 1.4)
        for f in self.forms:
            self.assertTrue(all(0.0 <= c <= 1.0 for c in f["tint"]), f["dataId"])

    def test_a_duplicate_id_is_an_error(self):
        dup = [dict(self.forms[0]), dict(self.forms[0])]
        with self.assertRaises(ValueError):
            bsf.check_unique(dup)

    def test_an_unknown_area_or_element_is_an_error(self):
        bad = dict(self.forms[0], host=["moon"])
        with self.assertRaises(ValueError):
            bsf.check_row(bad)
        bad = dict(self.forms[0], reads=["ether"])
        with self.assertRaises(ValueError):
            bsf.check_row(bad)

    def _doc_with(self, doc_id, index, value):
        lines = bsf.be.read(bsf.be.DOC).split("\n")
        for n, line in enumerate(lines):
            if line.startswith("| %s |" % doc_id):
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                if len(cells) == 9:
                    cells[index] = value
                    lines[n] = "| " + " | ".join(cells) + " |"
        return "\n".join(lines)

    def test_a_bad_element_in_the_doc_fails_even_beside_a_good_one(self):
        for reads in ("dark + ether", "ether"):
            with mock.patch.object(bsf.be, "read", return_value=self._doc_with("W2A", 3, reads)):
                with self.assertRaises(ValueError, msg=reads):
                    bsf.species_forms()

    def test_a_bad_area_in_the_doc_fails_even_beside_a_good_one(self):
        with mock.patch.object(bsf.be, "read", return_value=self._doc_with("W2A", 7, "forest, moon")):
            with self.assertRaises(ValueError):
                bsf.species_forms()

    def test_the_slime_has_eighteen_new_forms_with_their_parents_traits_and_grants(self):
        forms = bsf.slime_forms()
        by = {f["dataId"]: f for f in forms}
        self.assertEqual(len(forms), 18)
        g = by["gleipnir"]
        self.assertEqual((g["parents"], g["lineage"], g["traits"], g["grants"]), (["snare"], "weaver", ["spinner"], ["sticky_thread", "verb_gleipnir"]))
        self.assertEqual(by["ariadne"]["parents"], ["arachne"])
        self.assertEqual(by["ariadne"]["grants"], ["sticky_thread", "wall_cling", "verb_ariadne"])
        k = by["king_slime"]
        self.assertEqual((k["parents"], k["lineage"], k["traits"]), (["radiant"], "greater", ["adaptable"]))
        self.assertEqual(by["talos"]["parents"], ["golem"])
        self.assertEqual(by["selkie"]["parents"], ["brook"])

    def test_every_new_slime_form_is_stage_four_and_has_a_distinct_id(self):
        forms = bsf.slime_forms()
        self.assertEqual(len({f["dataId"] for f in forms}), 18)
        for f in forms:
            self.assertEqual((f["stage"], f["size"]), (4, 1.4))
            self.assertEqual(f["species"], "slime")
            self.assertFalse(os.path.exists("data/forms/%s.tres" % f["dataId"]) and f["dataId"] in ("weaver", "tide"), f["dataId"])

    def test_a_slime_tres_writes_its_traits_and_grants_and_the_others_do_not(self):
        text = bsf.tres(next(f for f in bsf.slime_forms() if f["dataId"] == "ariadne"))
        self.assertIn('traits = ["spinner"]', text)
        self.assertIn('grants = ["sticky_thread", "wall_cling", "verb_ariadne"]', text)
        self.assertNotIn("traits =", bsf.tres(self.by_id["wolf_moonbound"]))

    def test_the_tres_text_lists_the_new_fields(self):
        text = bsf.tres(self.by_id["wolf_moonbound"])
        for needle in ['id = "wolf_moonbound"', 'species = "wolf"', 'parents = ["wolf"]', 'reads = ["dark"]', 'host = ["forest"]',
                       'size = 1.12', "verb_text = ", "source = "]:
            self.assertIn(needle, text)
        self.assertTrue(text.startswith('[gd_resource type="Resource" script_class="FormDef" format=3]'))

    def test_build_writes_every_file(self):
        with tempfile.TemporaryDirectory() as out:
            ids = bsf.build(out)
            self.assertEqual(len(ids), 99)
            self.assertEqual(len(os.listdir(out)), 99)


if __name__ == "__main__":
    unittest.main()


class ArtTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_art_for_finds_the_frame_by_slug(self):
        by_id = {f["dataId"]: f for f in bsf.species_forms() + bsf.slime_forms()}
        self.assertEqual(bsf.art_for(by_id["wolf_warg"]), {"set": "forms_wolf", "frame": "warg"})
        self.assertEqual(bsf.art_for(by_id["gleipnir"]), {"set": "forms_slime", "frame": "gleipnir"})
        undead = next(f for f in by_id.values() if f["species"] == "undead")
        self.assertEqual(bsf.art_for(undead), {"set": "forms_undead", "frame": undead["dataId"][len("undead_"):]})

    def test_a_form_without_art_gets_none(self):
        self.assertEqual(bsf.art_for({"species": "wolf", "dataId": "wolf_no_such_form"}), {})
        self.assertEqual(bsf.art_for({"species": "newt", "dataId": "newt_thing"}), {})

    def test_every_generated_form_has_art(self):
        for f in bsf.species_forms() + bsf.slime_forms():
            self.assertTrue(bsf.art_for(f), f["dataId"])

    def test_the_tres_writes_the_set_and_the_frame(self):
        f = next(f for f in bsf.species_forms() if f["dataId"] == "wolf_warg")
        text = bsf.tres(f)
        self.assertIn('sprite_set = "forms_wolf"', text)
        self.assertIn('sprite_frame = "warg"', text)
