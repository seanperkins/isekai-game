#!/usr/bin/env python3
"""Writes the throwaway project.godot the shot tools run in.

    python3 tools/shot_project.py SRC_PROJECT_GODOT DST_PROJECT_GODOT

The game starts fullscreen (display/window/size/mode=3), which takes over a Space on macOS and ignores --windowed and --position.
The copy has a 32x18 borderless window that cannot take focus instead; tools/shot_run.sh runs a shot tool in a project of symlinks
to the real one with this file as its project.godot, so the real file is never touched.
"""
import re
import sys

WINDOW = ("window/size/mode=0\nwindow/size/borderless=true\nwindow/size/no_focus=true")


def rewrite(text):
    """The project file with the tiny window. Raises ValueError when there is no window mode line to replace."""
    text, n = re.subn(r"^window/size/mode=\d+$", WINDOW, text, flags=re.M)
    if n != 1:
        raise ValueError("project.godot has %d window/size/mode lines, not 1" % n)
    text = re.sub(r"^window/size/window_width_override=.*$", "window/size/window_width_override=32", text, flags=re.M)
    text = re.sub(r"^window/size/window_height_override=.*$", "window/size/window_height_override=18", text, flags=re.M)
    return text


def main(argv):
    if len(argv) != 3:
        sys.exit("usage: shot_project.py SRC DST")
    with open(argv[1], encoding="utf-8") as fh:
        text = fh.read()
    try:
        out = rewrite(text)
    except ValueError as err:
        sys.exit(str(err))
    with open(argv[2], "w", encoding="utf-8") as fh:
        fh.write(out)


if __name__ == "__main__":
    main(sys.argv)
