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
        row = next(r for r in json.load(open(os.path.join(ROOT, "tools", "form_verbs.json"))) if r["spec"]["kind"] == "ring" and "anim" not in r)
        self.assertEqual(verbs.anim_of(row["form"]), "slam")
        self.assertIsNone(verbs.anim_of("goblin_nobody"), "no verb, no gesture")


class OverrideTest(unittest.TestCase):
    """A row can say its own gesture where the kind's is not what the verb does (a howl that is a `ring`, a thrown cap that is a `bolt`)."""

    def test_a_row_override_beats_its_kinds_gesture(self):
        self.assertEqual(verbs.anim_of("wolf_barghest"), "roar", "the fear howl is a ring that howls")
        self.assertEqual(verb_anims.archetype_of("ring"), "slam")
        self.assertEqual(verbs.anim_of("goblin_bloodcap"), "throw", "the cap-throw is a bolt that is thrown")
        self.assertEqual(verbs.anim_of("goblin_redcap"), "roar", "a rage with no override is the kind's")

    def test_every_override_is_a_gesture_that_differs_from_its_kinds(self):
        rows = json.load(open(os.path.join(ROOT, "tools", "form_verbs.json")))
        overridden = [r for r in rows if "anim" in r]
        self.assertGreater(len(overridden), 5)
        for r in overridden:
            self.assertIn(r["anim"], verb_anims.ARCHETYPES, r["form"])
            self.assertNotEqual(r["anim"], verb_anims.archetype_of(r["spec"]["kind"]), "%s says what its kind already says" % r["form"])


class PresetTest(unittest.TestCase):
    """The preset each rig family plays a gesture with (what its motion tables are called)."""

    def test_every_family_has_a_preset_for_every_gesture(self):
        for family, presets in verb_anims.PRESETS.items():
            self.assertEqual(sorted(presets), sorted(verb_anims.ARCHETYPES), family)

    def test_the_presets_exist_in_the_motion_tables(self):
        import biped_motion
        import quad_motion
        import slime_motion
        import spider_motion
        import undead_motion
        tables = {"biped": biped_motion.ATTACKS, "undead": undead_motion.KINDS, "quad": quad_motion.ATTACKS, "slime": slime_motion.STYLES}
        for family, table in tables.items():
            for gesture, preset in verb_anims.PRESETS[family].items():
                self.assertIn(preset, list(table), "%s %s" % (family, gesture))
        for gesture, preset in verb_anims.PRESETS["spider"].items():
            self.assertIn(preset, list(spider_motion.ATTACKS), gesture)
        for gesture, preset in verb_anims.PRESETS["drider"].items():
            self.assertIn(preset, list(spider_motion.GESTURES), gesture)

    def test_a_family_is_the_species_with_the_body_of_its_form(self):
        self.assertEqual(verb_anims.family_of("goblin", {}), "biped")
        self.assertEqual(verb_anims.family_of("undead", {}), "undead")
        self.assertEqual(verb_anims.family_of("wolf", {}), "quad")
        self.assertEqual(verb_anims.family_of("wolf", {"body": "biped"}), "biped", "the werewolves have the biped's")
        self.assertEqual(verb_anims.family_of("spider", {}), "spider")
        self.assertEqual(verb_anims.family_of("spider", {"drider": {"tall": 1.3}}), "drider")
        self.assertEqual(verb_anims.family_of("slime", {}), "slime")


if __name__ == "__main__":
    unittest.main()
