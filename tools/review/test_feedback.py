"""The review app's feedback file: what the page posts and the agent reads. Pure Python, a temp folder per test."""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import feedback  # noqa: E402


class FeedbackTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.content = Path(self._tmp.name)

    def test_append_returns_an_id_and_timestamp_and_lists_it(self):
        first = feedback.append(self.content, {"creature": "goblin_hob", "clip": "walk", "flag": "wrong", "note": "upper body"})
        second = feedback.append(self.content, {"creature": "goblin_hob", "flag": "ok", "note": ""})
        self.assertEqual((first["id"], second["id"]), (1, 2))
        self.assertRegex(first["ts"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
        self.assertEqual([e["id"] for e in feedback.entries(self.content)], [1, 2])
        self.assertEqual(feedback.entries(self.content)[0]["clip"], "walk")

    def test_a_flag_outside_the_three_is_refused(self):
        self.assertEqual(feedback.FLAGS, ("ok", "wrong", "change"))
        with self.assertRaises(ValueError):
            feedback.append(self.content, {"creature": "goblin_hob", "flag": "meh", "note": ""})
        self.assertEqual(feedback.entries(self.content), [])

    def test_an_id_with_a_slash_capital_or_dots_is_refused(self):
        for bad in ("../x", "Hob", "a b", "", "a/b"):
            with self.subTest(creature=bad), self.assertRaises(ValueError):
                feedback.append(self.content, {"creature": bad, "flag": "ok", "note": ""})
        with self.assertRaises(ValueError):
            feedback.append(self.content, {"creature": "goblin_hob", "clip": "../walk", "flag": "ok", "note": ""})

    def test_a_note_over_2000_characters_is_refused(self):
        feedback.append(self.content, {"creature": "goblin_hob", "flag": "ok", "note": "x" * 2000})
        with self.assertRaises(ValueError):
            feedback.append(self.content, {"creature": "goblin_hob", "flag": "ok", "note": "x" * 2001})

    def test_unread_returns_each_entry_once_and_peek_does_not_mark(self):
        feedback.append(self.content, {"creature": "a", "flag": "ok", "note": "one"})
        feedback.append(self.content, {"creature": "b", "flag": "wrong", "note": "two"})
        self.assertEqual(len(feedback.unread(self.content, mark=False)), 2)
        self.assertEqual(len(feedback.unread(self.content, mark=False)), 2)
        self.assertEqual([e["note"] for e in feedback.unread(self.content)], ["one", "two"])
        self.assertEqual(feedback.unread(self.content), [])
        feedback.append(self.content, {"creature": "a", "flag": "change", "note": "three"})
        self.assertEqual([e["note"] for e in feedback.unread(self.content)], ["three"])
        self.assertEqual(json.loads((self.content / "feedback.state").read_text()), {"read_through": 3})

    def test_latest_flags_is_the_newest_flag_per_creature(self):
        for creature, flag in (("a", "wrong"), ("b", "ok"), ("a", "change")):
            feedback.append(self.content, {"creature": creature, "flag": flag, "note": ""})
        self.assertEqual(feedback.latest_flags(self.content), {"a": "change", "b": "ok"})

    def test_a_corrupt_line_in_the_file_is_skipped_not_fatal(self):
        feedback.append(self.content, {"creature": "a", "flag": "ok", "note": "kept"})
        with open(self.content / "feedback.jsonl", "a") as fh:
            fh.write('{"id": 2, "creature"\n')
        entry = feedback.append(self.content, {"creature": "a", "flag": "wrong", "note": "after"})
        self.assertEqual(entry["id"], 2)   # ids count the valid lines
        self.assertEqual([e["note"] for e in feedback.entries(self.content)], ["kept", "after"])

    def test_a_json_line_missing_its_fields_or_with_a_bad_flag_is_skipped_not_fatal(self):
        with open(self.content / "feedback.jsonl", "a") as fh:
            fh.write('{"id": 3}\n')
            fh.write('{"id": 4, "creature": "a", "flag": "bogus", "note": ""}\n')
            fh.write('{"id": 5, "creature": "a", "flag": "ok", "note": "kept"}\n')
        self.assertEqual([e["id"] for e in feedback.entries(self.content)], [5])
        self.assertEqual(feedback.latest_flags(self.content), {"a": "ok"})
        self.assertEqual([e["note"] for e in feedback.unread(self.content)], ["kept"])

    def test_the_cli_prints_unread_entries_once_and_says_when_there_are_none(self):
        import contextlib
        import io
        feedback.append(self.content, {"creature": "goblin_hob", "clip": "walk", "flag": "wrong", "note": "upper body"})
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            feedback.main(["--content", str(self.content)])
        self.assertRegex(out.getvalue(), r"#1 goblin_hob/walk WRONG \S+: upper body")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            feedback.main(["--content", str(self.content)])
        self.assertEqual(out.getvalue().strip(), "no new feedback")


if __name__ == "__main__":
    unittest.main()
