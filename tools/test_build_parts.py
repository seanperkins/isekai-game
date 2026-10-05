"""Checks for tools/build_parts.py. Run from anywhere:
  python3 -m unittest tools/test_build_parts.py
"""
import glob
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_parts as bp  # noqa: E402


class PartsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = os.getcwd()
        os.chdir(os.path.dirname(HERE))
        cls.rows = bp.load_rows()

    @classmethod
    def tearDownClass(cls):
        os.chdir(cls.old)

    def test_there_are_ten_parts_eight_grafts_a_held_one_and_a_key(self):
        self.assertEqual(len(self.rows), 10)
        kinds = [r["kind"] for r in self.rows]
        self.assertEqual((kinds.count("graft"), kinds.count("held"), kinds.count("key")), (8, 1, 1))

    def test_the_rows_pass_their_own_checks(self):
        bp.check_rows(self.rows)

    def test_a_bad_row_is_refused(self):
        good = dict(self.rows[0])
        for bad in (dict(good, kind="trinket"), dict(good, slot=""), dict(self.rows[8], slot="ribs"), dict(good, color=[1, 2])):
            with self.assertRaises(ValueError, msg=str(bad)):
                bp.check_rows([bad])
        with self.assertRaises(ValueError):
            bp.check_rows([good, good])

    def test_the_tres_has_each_field_and_is_stable(self):
        row = next(r for r in self.rows if r["id"] == "claw")
        text = bp.tres(row)
        for part in ('script_class="PartDef"', 'id = "claw"', 'kind = "graft"', 'slot = "claw"', "worn_max = 2", 'stats = {"atk": 1}'):
            self.assertIn(part, text)
        self.assertEqual(text, bp.tres(row))
        self.assertNotIn("slot =", bp.tres(next(r for r in self.rows if r["id"] == "moonstone")))

    def test_build_writes_one_file_per_row(self):
        with tempfile.TemporaryDirectory() as out:
            bp.build(out)
            self.assertEqual(len(glob.glob(os.path.join(out, "*.tres"))), 10)

    def test_the_checked_in_files_are_what_the_generator_writes(self):
        for r in self.rows:
            with open("data/parts/%s.tres" % r["id"], encoding="utf-8") as fh:
                self.assertEqual(fh.read(), bp.tres(r), r["id"])


if __name__ == "__main__":
    unittest.main()
