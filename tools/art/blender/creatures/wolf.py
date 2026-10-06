"""The wolf family in Blender: the gloom wolf and its four-legged forms on one skeleton (quad_skeleton.py), built by wolf_kit.py, dressed from a table
(wolf_forms.py) with gear (wolf_gear.py) and moved by quad_motion.py (pure Python, tested without Blender). The same kit is the goblin riders' mount
(build_into, and body_of with a prefix). Every form gets idle, walk (a walk, or a trot when its speed is too quick for a walk), run (a gallop),
attack (a lunge and a bite), hurt and die.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import attack_kinds  # noqa: E402
import quad_motion as motion_  # noqa: E402
import quad_skeleton as skeleton  # noqa: E402
import rigkit as k  # noqa: E402
import sizing  # noqa: E402
import skeleton2d  # noqa: E402
import wolf_forms as forms  # noqa: E402
import wolf_gear as gear  # noqa: E402
import wolf_kit as kit  # noqa: E402

NAME = "wolf"
MARGIN = 3
PAD = 4
RUN_SPEED = 1.9   # a gallop covers the ground this many times as fast as the walk (enemy.gd: RUN_SPEED)
BONES = {name for name, _, _, _ in skeleton.core()}


def _form(variant):
    """The form's table entry with the attack it uses, chosen by the verb it casts (attack_kinds.resolve)."""
    form = forms.FORMS[variant or "gloom_wolf"]
    return dict(form, attack=attack_kinds.resolve(form, "wolf_" + variant if variant else "wolf", "bite", quad=True))


def mount_form(fur, belly, barding=None):
    """The form of a wolf a goblin rides: the gloom wolf in its colours, with armour plates when it has barding."""
    return dict(forms.FORMS["gloom_wolf"], fur=fur, belly=belly, gear=[("plates", {"color": barding})] if barding else [])


def _dress(w, form):
    for name, kw in form.get("gear", []):
        gear.GEAR[name](w, **kw)


def build(variant=None):
    form = _form(variant)
    rig = k.Rig("wolf_" + (variant or "gloom_wolf"))
    w = kit.Wolf(rig, form)
    w.build()
    _dress(w, form)
    rig.build()
    return rig


def build_into(rig, p, s, origin, fur, belly, barding=None):
    """Add a wolf to `rig`: bone names get the prefix `p`, every coordinate is scaled by `s` and moved by `origin` (so a wolf can carry a rider). The
    caller builds the rig afterwards."""
    form = mount_form(fur, belly, barding)
    w = kit.Wolf(rig, form, p, s, origin)
    w.build()
    _dress(w, form)


def flat_skeleton(rig, prefix=""):
    """The wolf's bones in the rig (those that start with `prefix`), as a flat skeleton named without it."""
    rest = {}
    for name, (head, tail, parent) in rig.rest.items():
        bare = name[len(prefix):]
        if name.startswith(prefix) and bare in BONES:
            rest[bare] = ((head.x, head.z), (tail.x, tail.z), parent[len(prefix):] if parent and parent.startswith(prefix) else None)
    return skeleton2d.Skeleton2D(rest)


def measure_feet(rig, prefix=""):
    """{leg: (ankle_h, heel, toe)} read off the meshes bound to each paw (a foreleg's paw, a hind leg's metatarsus) in the rest pose."""
    rig.pose({}, (0.0, 0.0, 0.0))
    out = {}
    for key in ("fn", "ff", "hn", "hf"):
        bone = prefix + ("paw_" if key[0] == "f" else "meta_") + key[1]
        ankle = rig.rest[bone][0]
        x0, x1, z0, _ = rig.bounds_of(bone)
        out[key] = (ankle.z - z0, ankle.x - x0, x1 - ankle.x)
    return out


def body_of(rig, form, prefix=""):
    present = {n[len(prefix):] for n in rig.rest if n.startswith(prefix)} & BONES
    return motion_.QuadBody(flat_skeleton(rig, prefix), measure_feet(rig, prefix), form, present=present)


def named(clip, prefix):
    """The clip with its bones renamed with `prefix` (for a wolf that is part of a bigger rig)."""
    frames = [({prefix + b: v for b, v in rot.items()}, root) for rot, root in clip.frames]
    return motion_.Clip(frames, clip.durations, clip.loop, clip.grounded)


def motion(variant):
    return sizing.speed_of("wolf", None if variant in (None, "gloom_wolf") else variant)


def today(variant):
    base = (os.path.join(HERE, "..", "..", "..", "assets", "sheets", "gloom_wolf.json"), "idle_1") if variant in (None, "gloom_wolf") else None
    return sizing.today("wolf", variant, _form(variant)["width"], base)


def clips_for(body, speed, ppu):
    """{name: Clip} for a canine body whose everyday speed is `speed` game px/s with a sprite drawn at `ppu` pixels to the unit."""
    walk = motion_.walking_gait(body, speed, ppu)
    walk_cycle, walk_stride = motion_.plan_gait(body, walk, speed, ppu)
    run_cycle, run_stride = motion_.plan_gait(body, "gallop", speed * RUN_SPEED, ppu)
    return {
        "idle": motion_.idle_clip(body),
        "walk": motion_.gait_clip(body, walk, walk_cycle, walk_stride),
        "run": motion_.gait_clip(body, "gallop", run_cycle, run_stride),
        "attack": motion_.attack_clip(body),
        "hurt": motion_.hurt_clip(body),
        "die": motion_.die_clip(body),
    }


def clips_of(rig, variant):
    """({name: Clip}, pixels per unit) for this form: the unit is sized so the still covers the area of the still it replaces."""
    form = _form(variant)
    body = body_of(rig, form)
    idle = motion_.idle_clip(body)
    rig.pose(*idle.frames[0])
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = math.sqrt(w * h / ((x1 - x0) * (z1 - z0))) if h else w / (x1 - x0)
    return clips_for(body, motion(variant), ppu), ppu


def setup(rig, variant):
    """Size the camera for this form and time its gaits to its speed (so planted paws do not skate); the canvas holds every frame."""
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
