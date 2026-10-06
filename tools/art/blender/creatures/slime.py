"""The slime family in Blender: the plain blue jelly slime and its eighteen forms on one soft-body dome (slime_motion.Shape), built by slime_kit.py,
dressed from a table (slime_forms.py) with gear (slime_gear.py) and moved by slime_motion.py (pure Python, tested without Blender). Every form gets
idle (breathing, a wobble, a blink), walk (a hop, or a glide for a hovering form), run (a longer, faster hop), attack (a held coil, a lunge, an
impact squash; a lash, a bite, a throw, a pulse or a slam for the forms that strike so), hurt (a squash and a jiggle) and die (a collapse into a
puddle that settles).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import rigkit as k  # noqa: E402
import sizing  # noqa: E402
import slime_forms as forms  # noqa: E402
import slime_gear as gear  # noqa: E402
import slime_kit as kit  # noqa: E402
import slime_motion as motion_  # noqa: E402
import verb_anims  # noqa: E402

NAME = "slime"
MARGIN = 3
PAD = 4


def _form(variant):
    return forms.FORMS[variant or "slime"]


def build(variant=None):
    form = _form(variant)
    rig = k.Rig("slime_" + (variant or "slime"))
    s = kit.SlimeKit(rig, form)
    s.build()
    for name, kw in form.get("gear", []):
        gear.GEAR[name](s, **kw)
    rig.build()
    s.finish()
    return rig


def motion(variant):
    return forms.speed_of(variant)


BASE_SHRINK = 0.88   # the player's slime is drawn this much smaller than the drawing it replaced (Sean, 2026-10-06: a little smaller)


def today(variant):
    base = (os.path.join(HERE, "before", "slime_base.json"), "idle_1") if variant in (None, "slime") else None   # the sheet it replaced, saved before the render took its place
    w, h = sizing.today("slime", variant, _form(variant)["width"], base)
    return (w * BASE_SHRINK, h * BASE_SHRINK if h else h) if base is not None else (w, h)


def clips_of(rig, variant):
    """({name: Clip}, pixels per unit) for this form: the unit is sized so the still covers the area of the still it replaces."""
    body = rig.slime_kit.body
    idle = motion_.idle_clip(body)
    rig.pose(*idle.frames[0])
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = math.sqrt(w * h / ((x1 - x0) * (z1 - z0))) if h else w / (x1 - x0)
    return motion_.clips_for(body, motion(variant), ppu), ppu


def setup(rig, variant):
    """Size the camera for this form and time its hops to its speed (so the planted base does not skate); the canvas holds every frame."""
    clips, ppu = clips_of(rig, variant)
    anims = {name: (len(c.frames), (lambda i, n, c=c: c.frames[i]), c.grounded) for name, c in clips.items()}
    lo_x, hi_x, hi_z = 1e9, -1e9, 0.0
    for c in clips.values():
        for rot, root in c.frames:
            rig.pose(rot, root)
            a, b, _, top = rig.extent()
            lo_x, hi_x, hi_z = min(lo_x, a), max(hi_x, b), max(hi_z, top)
    need = max(2.0 * max(abs(lo_x), abs(hi_x)) * ppu + 2 * PAD, hi_z * ppu + MARGIN + PAD)
    canvas = int(math.ceil(need / 8.0) * 8)
    info = {"durations": {n: c.durations for n, c in clips.items()}, "loops": {n: c.loop for n, c in clips.items()},
            "fps": {n: len(c.frames) / sum(c.durations) for n, c in clips.items()}, "windup": motion_.WINDUP}
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": 0.0, "anims": anims, "still": "idle_0", "extra": info}


# ---- gestures ---------------------------------------------------------------------------------------------------------------------
# the attack style of slime_motion that plays each gesture (verb_anims.ARCHETYPES); a gesture not listed is one the slimes cannot play yet
GESTURES = {name: name for name in verb_anims.ARCHETYPES}
GESTURES.update({"cast": "lash", "claw": "bite", "throw": "toss", "pulse": "throb"})   # the styles forms name (lash, bite, throw, pulse) are not changed: the gestures have their own


def gesture_clip(rig, variant, archetype):
    """The attack clip of this form playing the gesture `archetype`; a KeyError when it has no style for it."""
    import copy
    body = copy.copy(rig.slime_kit.body)
    body.form = dict(body.form, attack=GESTURES[archetype])
    return motion_.attack_clip(body, motion_.idle_clip(body).frames[0])
