"""The verb gesture vocabulary: every kind of verb the game can cast says which gesture it plays (tools/verb_anims.json), and the vocabulary is the one the rig families author."""
import json
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verb_anims  # noqa: E402
import verbs  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))


def game_kinds():
    with open(os.path.join(ROOT, "scripts", "abilities", "verb_kinds.gd")) as fh:
        src = fh.read()
    return re.findall(r'"(\w+)"', re.search(r"const KINDS := \[(.*?)\]", src, re.S).group(1))


class TableTests(unittest.TestCase):
    def test_every_kind_the_game_can_cast_has_a_gesture(self):
        kinds = game_kinds()
        self.assertGreater(len(kinds), 50)
        self.assertEqual([k for k in kinds if k not in verb_anims.table()], [], "a kind added to verb_kinds.gd needs a row in tools/verb_anims.json")

    def test_the_table_has_no_kind_the_game_does_not_know(self):
        self.assertEqual(sorted(set(verb_anims.table()) - set(game_kinds())), [])

    def test_every_gesture_it_names_is_in_the_vocabulary_and_every_one_in_it_is_used(self):
        used = set(verb_anims.table().values())
        self.assertEqual(sorted(used - set(verb_anims.ARCHETYPES)), [])
        self.assertEqual(sorted(set(verb_anims.ARCHETYPES) - used), [], "a gesture nothing uses")

    def test_the_vocabulary_has_no_repeats(self):
        self.assertEqual(len(verb_anims.ARCHETYPES), len(set(verb_anims.ARCHETYPES)))

    def test_the_existing_attacks_keep_their_names(self):
        for name in ("slam", "roar", "lunge", "claw", "guard", "cast"):
            self.assertIn(name, verb_anims.ARCHETYPES)

    def test_archetype_of_a_kind_the_game_does_not_have_is_an_error(self):
        with self.assertRaises(KeyError):
            verb_anims.archetype_of("teleport_to_mars")
        self.assertEqual(verb_anims.archetype_of("burst"), "slam")


class RowTests(unittest.TestCase):
    def rows(self):
        out = []
        for name in ("form_verbs.json", "monster_verbs.json"):
            with open(os.path.join(ROOT, "tools", name)) as fh:
                out += json.load(fh)
        return out

    def test_every_verb_row_has_a_gesture(self):
        for row in self.rows():
            self.assertIn(row["spec"]["kind"], verb_anims.table(), row.get("form") or row.get("creature"))

    def test_a_form_says_the_gesture_of_its_verb(self):
        row = next(r for r in json.load(open(os.path.join(ROOT, "tools", "form_verbs.json"))) if r["spec"]["kind"] == "ring")
        self.assertEqual(verbs.anim_of(row["form"]), "slam")
        self.assertIsNone(verbs.anim_of("goblin_nobody"), "no verb, no gesture")


if __name__ == "__main__":
    unittest.main()
