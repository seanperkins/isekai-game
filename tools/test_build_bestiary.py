"""Checks for tools/build_bestiary.py. Run from anywhere:  python3 -m unittest tools/test_build_bestiary.py"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_bestiary as bb  # noqa: E402


class GroupTest(unittest.TestCase):
    def test_the_new_form_sheets_are_player_forms_not_enemies(self):
        for sid in ("forms_wolf", "forms_undead", "forms_slime", "forms_goblin", "forms_spider"):
            group, name, note = bb.classify(sid, "")
            self.assertEqual(group, "form", sid)
            self.assertIn("forms", name.lower(), sid)

    def test_the_older_form_sheets_stay_forms(self):
        self.assertEqual(bb.classify("form_weaver", "")[0], "form")

    def test_an_enemy_sheet_is_an_enemy(self):
        self.assertEqual(bb.classify("bat", "Bat")[0], "enemy")


if __name__ == "__main__":
    unittest.main()
