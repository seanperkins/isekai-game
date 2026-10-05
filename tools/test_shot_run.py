"""Checks for tools/shot_run.sh that need no display: its command line (a dry run) and what the script must never do. Run from anywhere:
  python3 -m unittest tools/test_shot_run.py
"""
import os
import subprocess
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCRIPT = os.path.join(HERE, "shot_run.sh")


def dry_run(*args, **env):
    full = dict(os.environ, SHOT_DRY_RUN="1", **env)
    return subprocess.run(["bash", SCRIPT, *args], capture_output=True, text=True, env=full, cwd=ROOT)


class CommandLineTest(unittest.TestCase):
    def test_the_run_is_muted_by_default(self):
        out = dry_run("tools/evolution_shots.gd")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("--audio-driver Dummy", out.stdout)

    def test_the_sound_can_be_asked_for(self):
        out = dry_run("tools/evolution_shots.gd", SHOT_AUDIO="1")
        self.assertNotIn("--audio-driver", out.stdout)

    def test_the_window_is_put_far_off_screen_and_the_tool_gets_its_arguments(self):
        out = dry_run("tools/room_shots.gd", "--", "C1", "300,180")
        self.assertIn("--position 30000,30000", out.stdout)
        self.assertIn("-s res://tools/room_shots.gd -- C1 300,180", out.stdout)

    def test_extra_godot_flags_are_passed_on(self):
        out = dry_run("tools/moveset_gifs.gd", SHOT_GODOT_ARGS="--fixed-fps 60")
        self.assertIn("--fixed-fps 60", out.stdout)

    def test_it_runs_in_a_copy_of_the_project_not_the_real_one(self):
        out = dry_run("tools/evolution_shots.gd")
        self.assertRegex(out.stdout, r"--path \S+\.proj ")

    def test_no_tool_or_a_missing_tool_is_a_usage_error(self):
        none = dry_run()
        self.assertEqual(none.returncode, 2)
        self.assertIn("usage", none.stderr)
        self.assertEqual(dry_run("tools/nothing_here.gd").returncode, 2)


class NeverDoTest(unittest.TestCase):
    def test_focus_is_never_given_back_by_app_name(self):
        """`tell application "<name>" to activate` launches whatever app has that name; two builds of a terminal shared one, and it
        opened a new terminal window each run. The hand-back is by process id through System Events."""
        for path in (SCRIPT, os.path.join(HERE, "menagerie_shots.sh")):
            text = open(path, encoding="utf-8").read()
            code = "\n".join(line for line in text.split("\n") if not line.lstrip().startswith("#"))
            self.assertNotIn("to activate", code, path)
            self.assertNotIn("open -a", code, path)
        self.assertIn("unix id", open(SCRIPT, encoding="utf-8").read())


if __name__ == "__main__":
    unittest.main()
