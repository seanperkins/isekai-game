"""The undead tree in Blender: the plain skeleton and its 29 forms, each built on its own bones (undead_skeleton.py) by undead_kit.py, dressed
from a table (undead_forms.py) with gear (undead_gear.py) and moved by undead_motion.py on biped_motion.py (pure Python, tested without Blender).
Every form gets idle, walk, run, attack, hurt and die: a two-legged form walks and runs as a biped of its own posture, a jiangshi hops, a corpse
candle, a banshee and a demilich float.

Each form is sized so the still covers the same area as the still its sheet frame has today (before/forms_undead.json), and its gaits are timed
to the speed its twin walks at in the game, so a planted foot does not skate.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import player_poses  # noqa: E402
import rigkit as k  # noqa: E402
import sizing  # noqa: E402
import skeleton2d  # noqa: E402
import undead_forms as forms  # noqa: E402
import undead_gear as gear  # noqa: E402
import undead_kit as kit  # noqa: E402
import undead_motion as motion_  # noqa: E402
import verb_anims  # noqa: E402

NAME = "undead"
BASE = "skeleton"
MARGIN = 3
PAD = 4


def _name(variant):
    return variant or BASE


def _form(variant):
    return forms.FORMS[_name(variant)]


def build(variant=None):
    form = _form(variant)
    rig = k.Rig("undead_" + _name(variant))
    u = kit.Undead(rig, form)
    u.build()
    for name, kw in form.get("gear", []):
        gear.GEAR[name](u, **kw)
    rig.build()
    return rig


def measure_feet(rig):
    """{side: (ankle_h, heel, toe)} read off the meshes bound to each foot in the rest pose (as creatures/goblin.py)."""
    rig.pose({}, (0.0, 0.0, 0.0))
    out = {}
    for side in "nf":
        bone = "foot_" + side
        ankle = rig.rest[bone][0]
        x0, x1, z0, _ = rig.bounds_of(bone)
        out[side] = (ankle.z - z0, ankle.x - x0, x1 - ankle.x)
    return out


def body_of(rig, form):
    """The motion code's view of a rig: a biped (with its measured feet) or a floater (with how far below its root its meshes reach)."""
    skel = skeleton2d.Skeleton2D.from_rig(rig)
    if form["body"] in ("candle", "ghost", "skull"):
        rig.pose({}, (0.0, 0.0, 0.0))
        return motion_.FloatBody(skel, form, rig.lowest(), present=set(rig.rest))
    return motion_.biped_body(skel, measure_feet(rig), form, present=set(rig.rest))


def motion(variant):
    return sizing.speed_of("undead", None if _name(variant) == BASE else _name(variant))


BASE_GROWTH = 1.05   # the player's skeleton is drawn about as tall as the player's goblin (47 px), a little more than the still it replaces (45)


def today(variant):
    w, h = sizing.today("undead", _name(variant), _form(variant)["width"])
    return (w * BASE_GROWTH, h * BASE_GROWTH if h else h) if _name(variant) == BASE else (w, h)


def clips_of(rig, variant):
    """({name: Clip}, pixels per unit) for this form: the unit is sized so the still covers the area of the still the form replaces."""
    form = _form(variant)
    body = body_of(rig, form)
    idle = motion_.idle_clip(body)
    rig.pose(*idle.frames[0])
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    base = _name(variant) == BASE   # the plain skeleton is also the player's undead body: sized by its height, and it leaps, falls, rolls, slides, mantles and clings as well
    ppu = sizing.pixels_per_unit((x1 - x0, z1 - z0), (w, h), "height" if base else "area")
    clips = motion_.clips(body, motion(variant), ppu)
    if base:
        clips.update({name: player_poses.clip(body, name) for name in player_poses.FRAMES})
    return clips, ppu


def windup(rig, variant):
    form = _form(variant)
    return motion_.TIMINGS["normal" if form["body"] in ("candle", "ghost", "skull") else form.get("weight", "normal")]["windup"]


def setup(rig, variant):
    """Size the camera for this form and time its gaits to its speed; the canvas holds every frame."""
    form = _form(variant)
    clips, ppu = clips_of(rig, variant)
    anims = {name: (len(c.frames), (lambda i, n, c=c: c.frames[i]), c.grounded) for name, c in clips.items()}
    lo_x, hi_x, hi_z = 1e9, -1e9, 0.0
    for c in clips.values():
        for rot, root in c.frames:
            (rig.stand if c.grounded else rig.pose)(rot, root)
            a, b, _, top = rig.extent()
            lo_x, hi_x, hi_z = min(lo_x, a), max(hi_x, b), max(hi_z, top)
    need = max(2.0 * max(abs(lo_x), abs(hi_x)) * ppu + 2 * PAD, hi_z * ppu + MARGIN + PAD)
    canvas = int(math.ceil(need / 8.0) * 8)
    info = {"durations": {n: c.durations for n, c in clips.items()}, "loops": {n: c.loop for n, c in clips.items()},
            "fps": {n: len(c.frames) / sum(c.durations) for n, c in clips.items()}, "windup": windup(rig, variant)}
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": 0.0, "anims": anims, "still": form.get("still", "idle_0"), "extra": info}


# ---- gestures ---------------------------------------------------------------------------------------------------------------------
# the preset of undead_motion.KINDS that plays each gesture (verb_anims.ARCHETYPES); a gesture not listed is one the undead cannot play yet
GESTURES = {name: name for name in verb_anims.ARCHETYPES}   # undead_motion.KINDS has a preset for each (the biped's, through attack_kinds.register_undead)


def gesture_clip(rig, variant, archetype):
    """The attack clip of this form playing the gesture `archetype`; a KeyError when it has no preset for it (a floating body has its own attacks)."""
    form = dict(_form(variant), attack=GESTURES[archetype])
    if form["body"] in ("candle", "ghost", "skull"):
        raise KeyError(archetype)
    return motion_.attack_clip(body_of(rig, form))
