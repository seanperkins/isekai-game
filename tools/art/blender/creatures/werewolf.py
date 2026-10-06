"""The upright wolf-men in Blender: moonbound, loup-garou, ulfhedinn, the beast of Gevaudan, lycaon and the wolfskin champion on one skeleton
(werewolf_skeleton.py), built by werewolf_kit.py, dressed from the wolf family's table (wolf_forms.py) with werewolf_gear.py, and moved by biped_motion.py with
the werewolf posture (hunched far forward over digitigrade legs, a long stride). Same contract as creatures/goblin.py.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import attack_kinds  # noqa: E402
import biped_motion as motion_  # noqa: E402
import rigkit as k  # noqa: E402
import sizing  # noqa: E402
import skeleton2d  # noqa: E402
import werewolf_gear as gear  # noqa: E402
import werewolf_kit as kit  # noqa: E402
import wolf_forms as forms  # noqa: E402

NAME = "werewolf"
MARGIN = 3
PAD = 4
RUN_SPEED = 1.9   # a run covers the ground this many times as fast as the walk (enemy.gd: RUN_SPEED)


def _form(variant):
    form = forms.FORMS[variant]
    return dict(form, attack=attack_kinds.resolve(form, "wolf_" + variant, motion_.attack_kind(form)))


def build(variant):
    form = _form(variant)
    rig = k.Rig("werewolf_" + variant)
    w = kit.Werewolf(rig, form)
    w.build()
    for name, kw in form.get("gear", []):
        gear.GEAR[name](w, **kw)
    rig.build()
    return rig


def measure_feet(rig):
    """{side: (ankle_h, heel, toe)} read off the toe pad of each foot in the rest pose (a wolf-man stands on its toes, so the sole is the pad, which lies ahead
    of the ankle: the heel is then a negative distance)."""
    rig.pose({}, (0.0, 0.0, 0.0))
    out = {}
    for side in "nf":
        bone = "foot_" + side
        ankle = rig.rest[bone][0]
        x0, x1, z0, _ = rig.bounds_of(bone, named=("pad_", "toe_claw_"))   # the toe claws are part of what stands on the ground
        out[side] = (ankle.z - z0, ankle.x - x0, x1 - ankle.x)
    return out


def body_of(rig, form):
    return motion_.Body(skeleton2d.Skeleton2D.from_rig(rig), measure_feet(rig), form, present=set(rig.rest), posture="werewolf")


def motion(variant):
    return sizing.speed_of("wolf", variant)


def today(variant):
    return sizing.today("wolf", variant, _form(variant)["width"])


def clips_of(rig, variant):
    form = _form(variant)
    body = body_of(rig, form)
    idle = motion_.idle_clip(body)
    rig.pose(*idle.frames[0])
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = math.sqrt(w * h / ((x1 - x0) * (z1 - z0))) if h else w / (x1 - x0)
    speed = motion(variant)
    walk_cycle, walk_stride = motion_.plan_gait(body, "walk", speed, ppu)
    run_cycle, run_stride = motion_.plan_gait(body, "run", speed * RUN_SPEED, ppu)
    return {
        "idle": idle,
        "walk": motion_.gait_clip(body, "walk", walk_cycle, walk_stride),
        "run": motion_.gait_clip(body, "run", run_cycle, run_stride),
        "attack": motion_.attack_clip(body),
        "hurt": motion_.hurt_clip(body),
        "die": motion_.die_clip(body),
    }, ppu


def setup(rig, variant):
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
            "fps": {n: len(c.frames) / sum(c.durations) for n, c in clips.items()}, "windup": motion_.ATTACK_WINDUP}
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": 0.0, "anims": anims, "still": "idle_0", "extra": info}
