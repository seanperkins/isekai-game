import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_frames as g  # noqa: E402

FRAME = {"name": "run_2", "width": 42, "refs": ["idle_1", "run_1"], "prompt": "The same slime, running."}


class GenerateFramesTest(unittest.TestCase):
    def test_prompt_carries_the_style_the_frame_the_key_and_the_filename(self):
        p = g.build_prompt("STYLE TEXT", FRAME)
        self.assertTrue(p.startswith("$imagegen"))
        for part in ("STYLE TEXT", "The same slime, running.", "magenta", "as run_2.png"):
            self.assertIn(part, p)

    def test_references_start_with_the_canonical_slime_then_the_frames_own(self):
        refs = g.refs_for(FRAME, "/out", "/repo")
        self.assertEqual(refs, ["/repo/assets/sprites/slime_idle.png", "/out/idle_1.png", "/out/run_1.png"])

    def test_a_set_can_name_its_own_reference(self):
        refs = g.refs_for({"name": "fly_1", "refs": []}, "/out", "/repo", "assets/sprites/bat_1.png")
        self.assertEqual(refs, ["/repo/assets/sprites/bat_1.png"])

    def test_resuming_skips_finished_frames_but_an_explicit_list_regenerates(self):
        self.assertEqual(g.todo(["a", "b", "c"], {"a", "b"}, False), ["c"])
        self.assertEqual(g.todo(["a", "b"], {"a", "b"}, True), ["a", "b"])

    def test_a_reference_with_a_slash_points_into_another_set(self):
        refs = g.refs_for({"name": "run_1", "refs": ["form_weaver/idle_1", "slime/run_1"]}, "/out", "/repo", "art_source/frames/slime/idle_1.png")
        self.assertEqual(refs, ["/repo/art_source/frames/slime/idle_1.png",
                                "/repo/art_source/frames/form_weaver/idle_1.png",
                                "/repo/art_source/frames/slime/run_1.png"])

    def test_the_command_passes_one_reference_flag_each_and_reads_stdin(self):
        cmd = g.command("/out", ["/a.png", "/b.png"])
        self.assertEqual(cmd[:2], ["codex", "exec"])
        self.assertEqual(cmd.count("-i"), 2)
        self.assertEqual(cmd[-1], "-")
        self.assertEqual(cmd[cmd.index("-C") + 1], "/out")

    def test_names_are_validated(self):
        self.assertTrue(g.valid_name("run_2"))
        for bad in ("../x", "Run", "a b", "", "a.png"):
            self.assertFalse(g.valid_name(bad), bad)

    def test_every_frame_in_the_list_is_well_formed(self):
        import json
        data = json.load(open(os.path.join(os.path.dirname(__file__), "slime_frames.json")))
        names = [f["name"] for f in data["frames"]]
        self.assertEqual(len(names), 21)
        self.assertEqual(len(set(names)), 21)
        for f in data["frames"]:
            self.assertTrue(g.valid_name(f["name"]), f["name"])
            self.assertGreater(f["width"], 20)
            for r in f["refs"]:
                self.assertIn(r, names)
                self.assertLess(names.index(r), names.index(f["name"]), "a reference must come earlier")
        self.assertEqual([f["name"] for f in data["frames"] if "attack_from" in f], ["tackle"])


if __name__ == "__main__":
    unittest.main()
