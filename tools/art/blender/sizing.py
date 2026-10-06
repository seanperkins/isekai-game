"""How big a rendered form is drawn and how fast it moves in the game, read from the game's own data. Pure Python.

A form is sized so its still covers the same area (width times height) as the still its sheet frame has today (before/forms_<species>.json, saved before
the 3D pass), which keeps the game's size ladder, and its gaits are timed to the speed its twin walks at, so a planted foot does not skate.
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BASE_SPEED = 60.0      # px/s at spd 100, as in scripts/enemies/enemy.gd


def twin_path(species, variant):
    """The twin's resource. The slime forms are named bare (twin_kraken); the other species' by species (twin_wolf_fenrir)."""
    name = "twin_%s" % variant if species == "slime" else "twin_%s_%s" % (species, variant)
    return os.path.join(ROOT, "data", "creatures", name + ".tres")


def speed_of(species, variant):
    """How fast this form crosses the ground in the game, in the sprite's own pixels per second: the enemy's speed (60 px/s times its spd stat
    over 100) divided by the size its sprite is drawn at. A form with no twin walks at 60."""
    speed, size = BASE_SPEED, 1.0
    if variant:
        try:
            with open(twin_path(species, variant)) as fh:
                text = fh.read()
            spd = re.search(r'"spd":\s*(\d+)', text)
            sz = re.search(r"^sprite_size = ([0-9.]+)", text, re.M)
            speed = BASE_SPEED * (float(spd.group(1)) if spd else 100.0) / 100.0
            size = float(sz.group(1)) if sz else 1.0
        except OSError:
            pass
    return speed / size


def today(species, variant, width, base=None):
    """(width, height) in game pixels of the still the game had for this form before the 3D pass, so a re-render sizes the same whatever the live
    sheet holds. `base` is (sheet json path, frame) for a form with no twin (the base creature); without a still: (width, None)."""
    path, name = os.path.join(HERE, "before", "forms_%s.json" % species), variant
    if base is not None:
        path, name = base
    try:
        with open(path) as fh:
            rect = json.load(fh)["frames"][name]["rect"]
        return float(rect[2]), float(rect[3])
    except (OSError, KeyError):
        return float(width), None
