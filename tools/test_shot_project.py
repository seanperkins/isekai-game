"""Checks for tools/shot_project.py. Run from anywhere:
  python3 -m unittest tools/test_shot_project.py
"""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import shot_project as sp  # noqa: E402

PROJECT = """[application]

config/name="Game"

[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/size/mode=3
window/stretch/mode="canvas_items"
"""


class RewriteTest(unittest.TestCase):
    def test_fullscreen_becomes_a_tiny_borderless_window_that_cannot_take_focus(self):
        out = sp.rewrite(PROJECT)
        self.assertIn("window/size/mode=0\n", out)
        self.assertNotIn("window/size/mode=3", out)
        self.assertIn("window/size/borderless=true", out)
        self.assertIn("window/size/no_focus=true", out)
        self.assertIn("window/size/window_width_override=32", out)
        self.assertIn("window/size/window_height_override=18", out)

    def test_everything_else_is_kept(self):
        out = sp.rewrite(PROJECT)
        for line in ('config/name="Game"', "window/size/viewport_width=640", "window/size/viewport_height=360", 'window/stretch/mode="canvas_items"'):
            self.assertIn(line, out)

    def test_the_stretch_mode_line_is_not_mistaken_for_the_window_mode(self):
        self.assertEqual(sp.rewrite(PROJECT).count("window/size/mode="), 1)

    def test_a_project_with_no_window_mode_line_is_refused(self):
        with self.assertRaises(ValueError):
            sp.rewrite(PROJECT.replace("window/size/mode=3\n", ""))

    def test_two_mode_lines_are_refused(self):
        with self.assertRaises(ValueError):
            sp.rewrite(PROJECT + "window/size/mode=0\n")

    def test_the_real_project_rewrites(self):
        with open(os.path.join(HERE, "..", "project.godot"), encoding="utf-8") as fh:
            out = sp.rewrite(fh.read())
        self.assertIn("window/size/window_width_override=32", out)


class CommandLineTest(unittest.TestCase):
    def test_it_writes_the_destination_and_leaves_the_source(self):
        with tempfile.TemporaryDirectory() as d:
            src, dst = os.path.join(d, "project.godot"), os.path.join(d, "out.godot")
            with open(src, "w", encoding="utf-8") as fh:
                fh.write(PROJECT)
            done = subprocess.run([sys.executable, os.path.join(HERE, "shot_project.py"), src, dst], capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, done.stderr)
            self.assertEqual(open(src, encoding="utf-8").read(), PROJECT)
            self.assertIn("window/size/mode=0", open(dst, encoding="utf-8").read())

    def test_a_bad_project_is_an_error_not_a_half_written_file(self):
        with tempfile.TemporaryDirectory() as d:
            src, dst = os.path.join(d, "project.godot"), os.path.join(d, "out.godot")
            with open(src, "w", encoding="utf-8") as fh:
                fh.write("[display]\n")
            done = subprocess.run([sys.executable, os.path.join(HERE, "shot_project.py"), src, dst], capture_output=True, text=True)
            self.assertNotEqual(done.returncode, 0)
            self.assertFalse(os.path.exists(dst))


if __name__ == "__main__":
    unittest.main()
