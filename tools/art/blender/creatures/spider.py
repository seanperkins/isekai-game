"""The spider family in Blender: the plain spider and its twenty-one forms on one skeleton (spider_skeleton.py), built by spider_kit.py, dressed from a
table (spider_forms.py) with gear (spider_gear.py) and moved by spider_motion.py (pure Python, tested without Blender). Every form gets idle, walk (the
alternating tetrapod), run, attack (a bite, a pounce, a scythe slash, a spit, or a drider's gesture), hurt and die.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import attack_kinds  # noqa: E402
import rigkit as k  # noqa: E402
from mathutils import Vector  # noqa: E402
import sizing  # noqa: E402
import skeleton2d  # noqa: E402
import spider_forms as forms  # noqa: E402
import spider_gear as gear  # noqa: E402
import spider_kit as kit  # noqa: E402
import spider_motion as motion_  # noqa: E402
import spider_skeleton as skeleton  # noqa: E402
import verb_anims  # noqa: E402

NAME = "spider"
BASE = "spider"
MARGIN = 3
PAD = 4
RUN_SPEED = 1.9   # a run covers the ground this many times as fast as the walk (enemy.gd: RUN_SPEED)


def _name(variant):
    return variant or BASE


def _form(variant):
    """The form's table entry with the attack it uses: the one it names itself, else the gesture of the verb it casts (attack_kinds.resolve), else a bite."""
    form = forms.FORMS[_name(variant)]
    if form.get("attack"):
        return form
    return dict(form, attack=attack_kinds.resolve(form, "spider_" + _name(variant), "bite", family=verb_anims.family_of("spider", form)))


def build(variant=None):
    form = _form(variant)
    rig = k.Rig("spider_" + _name(variant))
    s = kit.Spider(rig, form)
    s.build()
    for name, kw in form.get("gear", []):
        gear.GEAR[name](s, **kw)
    rig.build()
    return rig


def flat_skeleton(rig):
    return skeleton2d.Skeleton2D.from_rig(rig)


def measure_pads(rig):
    """{leg: how far below the claw's bone end its mesh reaches}, read off each tarsus's own mesh in the rest pose (not the gear bound to it)."""
    rig.pose({}, (0.0, 0.0, 0.0))
    meshes = {ob.name: ob for ob, _, _ in rig.parts}
    out = {}
    for key in skeleton.LEGS:
        ob = meshes["tar_" + key]
        z0 = min((ob.matrix_world @ Vector(c)).z for c in ob.bound_box)
        out[key] = rig.rest["tar_" + key][1].z - z0
    return out


def body_of(rig, form):
    return motion_.SpiderBody(flat_skeleton(rig), measure_pads(rig), dict(form, _hull=skeleton.hull_for(form)), present=set(rig.rest))


def motion(variant):
    return sizing.speed_of("spider", None if _name(variant) == BASE else variant)


def today(variant):
    """The plain spider is sized by the sheet it replaced (before/spider_base.json, saved before the render took its place); a form by the still it replaces."""
    base = (os.path.join(HERE, "before", "spider_base.json"), "hang_1") if _name(variant) == BASE else None
    return sizing.today("spider", variant, _form(variant)["width"], base)


def clips_of(rig, variant):
    """({name: Clip}, pixels per unit) for this form: the unit is sized so the still covers the area of the still it replaces."""
    form = _form(variant)
    body = body_of(rig, form)
    idle = motion_.idle_clip(body)
    rig.pose(*idle.frames[0])
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = sizing.pixels_per_unit((x1 - x0, z1 - z0), (w, h), "width" if _name(variant) == BASE else "area")
    return motion_.clips_for(body, motion(variant), ppu, RUN_SPEED), ppu


def setup(rig, variant):
    """Size the camera for this form and time its gaits to its speed (so planted claws do not skate); the canvas holds every frame."""
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
            "fps": {n: len(c.frames) / sum(c.durations) for n, c in clips.items()}, "windup": motion_.WINDUP}
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": 0.0, "anims": anims, "still": "idle_0", "extra": info}


# ---- gestures ---------------------------------------------------------------------------------------------------------------------
# the preset of spider_motion.ATTACKS that plays each gesture on a plain spider (verb_anims.ARCHETYPES): its blows for the cast (a spit), the lunge (a pounce) and the claw (a slash), its own
# for the rest; a drider plays the arms of spider_motion.GESTURES (its own cast, throw and smash, the biped's for the rest) instead
GESTURES = verb_anims.PRESETS["spider"]
DRIDER_GESTURES = verb_anims.PRESETS["drider"]


def gesture_clip(rig, variant, archetype):
    """The attack clip of this form playing the gesture `archetype`; a KeyError when it has no preset for it."""
    form = _form(variant)
    preset = (DRIDER_GESTURES if form.get("drider") else GESTURES)[archetype]
    return motion_.attack_clip(body_of(rig, dict(form, attack=preset)))
