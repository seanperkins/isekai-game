"""The goblin tree in Blender: the base goblin and its 28 forms on one skeleton (goblin_kit.py), dressed from a table (goblin_forms.py) with gear
(goblin_gear.py) and moved by goblin_motion.py (pure Python, tested without Blender). A rider's mount is the wolf kit. Every form gets idle,
walk, run, attack, hurt and die; the pose of its arms, its stance and what it holds come from small presets, so a new form is a few lines of
data, not new animation.

Each form is sized so the still covers the same area (width times height) as the still its sheet frame has today (before/forms_goblin.json), so
the game's size ladder is kept while the proportions are the form's own.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import anim  # noqa: E402
import goblin_forms as forms  # noqa: E402
import goblin_gear as gear  # noqa: E402
import goblin_kit as kit  # noqa: E402
import goblin_motion as motion_  # noqa: E402
import goblin_skeleton as skeleton  # noqa: E402
import rigkit as k  # noqa: E402
import secondary  # noqa: E402
import sizing  # noqa: E402
import skeleton2d  # noqa: E402
from creatures import wolf  # noqa: E402
from goblin_kit import down, up  # noqa: E402

NAME = "goblin"
MARGIN = 3
PAD = 4
RIDER_SCALE = 1.0
ARMS, STANCES = motion_.ARMS, motion_.STANCES
RIDE = {"thigh_n": down(84), "thigh_f": down(84), "shin_n": down(-88), "shin_f": down(-88), "foot_n": down(6), "foot_f": down(6), "spine": up(2)}
RIDER_COUNTS = {"idle": 12, "walk": 12, "attack": 12}
RIDER_SECONDS = {"idle": 1.4, "walk": 0.6, "attack": 0.84}
WALK_SPEED_RUN = 1.9   # a run covers the ground this many times as fast as the walk does


def _form(variant):
    return forms.FORMS[variant or "goblin"]


def build(variant=None):
    form = _form(variant)
    rig = k.Rig("goblin_" + (variant or "goblin"))
    scale, origin, mount = 1.0, (0.0, 0.0, 0.0), form.get("ride") and form["mount"]
    if mount:
        ws = mount["scale"]
        wolf.build_into(rig, "w_", ws, (0, 0, 0), fur=mount["fur"], belly=mount["belly"], barding=mount.get("barding"))
        scale = RIDER_SCALE
        seat = 0.78 * ws - 0.06
        origin = (0.02 * ws, 0.0, seat - 0.80 * form.get("tall", 1.0) * scale)
    g = kit.Goblin(rig, form, "", scale, origin)
    if mount:
        g.root_parent = "w_spine"
    g.build()
    for name, kw in form["gear"]:
        gear.GEAR[name](g, **kw)
    rig.build()
    return rig


def measure_feet(rig):
    """{side: (ankle_h, heel, toe)} read off the meshes bound to each foot in the rest pose: how far the sole is below the ankle and how far it
    reaches behind and in front of it, boots and all."""
    rig.pose({}, (0.0, 0.0, 0.0))
    out = {}
    for side in "nf":
        bone = "foot_" + side
        ankle = rig.rest[bone][0]
        x0, x1, z0, _ = rig.bounds_of(bone)
        out[side] = (ankle.z - z0, ankle.x - x0, x1 - ankle.x)
    return out


def body_of(rig, form):
    """The motion code's view of a rig: its flat skeleton, its measured feet and the bones it really has."""
    return motion_.Body(skeleton2d.Skeleton2D.from_rig(rig), measure_feet(rig), form, present=set(rig.rest))


# ---- a rider ----------------------------------------------------------------------------------------------------------------------
def _rider_arms(rot, form, t, swing_deg, lag=0.2):
    """A seated rider's arms from the preset, relative to its body (which moves with the mount): they swing a little against the wolf's stride."""
    a = ARMS[form.get("arms", "free")]
    c = math.cos(2.0 * math.pi * (t - lag))
    amp = swing_deg * a[4]
    rot["arm_n"], rot["fore_n"] = down(a[0] - amp * c), down(a[1] + 0.6 * amp * (0.5 - 0.5 * c))
    rot["arm_f"], rot["fore_f"] = down(a[2] + amp * c), down(a[3] + 0.6 * amp * (0.5 + 0.5 * c))


def _rider_frame(form, anim_name, i, n):
    t = i / n
    rot = dict(RIDE)
    _rider_arms(rot, form, t, 6.0)
    rot["spine"] = up(2.0 + 1.5 * math.sin(4.0 * math.pi * t))
    wolf_fn = {"idle": wolf.idle, "walk": wolf.walk, "attack": wolf.pounce}[anim_name]
    wrot, root = wolf_fn(min(5, i * 6 // n), 6, "w_") if anim_name == "attack" else wolf_fn(i, n, "w_")
    out = dict(wrot)
    out.update(rot)
    for s in "nf":  # what it holds keeps its angle whatever the arm does
        chain = ["w_hips", "w_spine", "hips", "spine", "arm_" + s, "fore_" + s]
        above = sum(out.get(b, (0.0, 0.0, 0.0))[1] for b in chain)
        arm = out.get("arm_" + s, (0, 0, 0))[1] + out.get("fore_" + s, (0, 0, 0))[1]
        out["item_" + s] = (0.0, form.get("item_angle", {}).get(s, 0.0) + 0.25 * arm - above, 0.0)
    return out, (root[0], root[1], root[2] * form["mount"]["scale"])


def _rider_clip(rig, form, anim_name):
    n = RIDER_COUNTS[anim_name]
    frames = [_rider_frame(form, anim_name, i, n) for i in range(n)]
    dur = [RIDER_SECONDS[anim_name] / n] * n
    out = secondary.series(set(rig.rest), motion_.SECONDARY, frames, {"walk": 1.0, "idle": 0.15, "attack": 0.5}[anim_name], dur,
                           extra_chain=("w_hips", "w_spine"), periodic=anim_name != "attack")
    for i, (rot, _) in enumerate(frames):
        for bone, series in out.items():
            rot[bone] = down(series[i])
    return motion_.Clip(frames, dur, anim_name != "attack", grounded=True)


# ---- sizing -----------------------------------------------------------------------------------------------------------------------
def motion(variant):
    return sizing.speed_of("goblin", None if variant == "goblin" else variant)


def today(variant):
    base = (os.path.join(HERE, "..", "..", "..", "assets", "sheets", "goblin.json"), "idle_1") if not variant or variant == "goblin" else None
    return sizing.today("goblin", variant, _form(variant)["width"], base)


def _cycle(body_reach_px, speed, duty, lo, hi, stride_legs):
    """(cycle seconds, stride in px) for a gait that covers the ground at `speed` px/s with feet that stay down for `duty` of the cycle: a
    brisk step is `stride_legs` leg lengths."""
    cycle = min(hi, max(lo, stride_legs * body_reach_px / (speed * duty)))
    return cycle, speed * duty * cycle


def clips_of(rig, variant):
    """{name: motion.Clip} for this form, plus the camera sizing: the pixels per unit, from the area of the still the form replaces."""
    form = _form(variant)
    riding = bool(form.get("ride"))
    if riding:
        clips = {name: _rider_clip(rig, form, name) for name in RIDER_COUNTS}
        first = clips["idle"]
        rig.stand(*first.frames[0])
        reach = None
    else:
        body = body_of(rig, form)
        idle = motion_.idle_clip(body)
        rig.pose(*idle.frames[0])
        reach = body.L
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = math.sqrt(w * h / ((x1 - x0) * (z1 - z0))) if h else w / (x1 - x0)
    if riding:
        return clips, ppu
    speed = motion(variant)
    walk_cycle, walk_stride = _cycle(reach * ppu, speed, motion_.GAITS["walk"]["duty"], 0.35, 0.9, 0.9)
    run_cycle, run_stride = _cycle(reach * ppu, speed * WALK_SPEED_RUN, motion_.GAITS["run"]["duty"], 0.28, 0.6, 1.5)
    clips = {
        "idle": idle,
        "walk": motion_.gait_clip(body, "walk", walk_cycle, walk_stride / ppu),
        "run": motion_.gait_clip(body, "run", run_cycle, run_stride / ppu),
        "attack": motion_.attack_clip(body),
        "hurt": motion_.hurt_clip(body),
        "die": motion_.die_clip(body),
    }
    return clips, ppu


def setup(rig, variant):
    """Size the camera for this form and time its gaits to its speed: the still covers the area of today's still, a walk's stride is what the
    form's speed demands (so planted feet do not skate), and the canvas holds every frame."""
    form = _form(variant)
    clips, ppu = clips_of(rig, variant)
    anims = {name: (len(c.frames), (lambda i, n, c=c: c.frames[i]), c.grounded) for name, c in clips.items()}
    lo_x, hi_x, hi_z = 1e9, -1e9, 0.0
    for name, c in clips.items():
        for rot, root in c.frames:
            (rig.stand if c.grounded else rig.pose)(rot, root)
            a, b, _, top = rig.extent()
            lo_x, hi_x, hi_z = min(lo_x, a), max(hi_x, b), max(hi_z, top)
    need = max(2.0 * max(abs(lo_x), abs(hi_x)) * ppu + 2 * PAD, hi_z * ppu + MARGIN + PAD)  # about the creature's own centre, so a frame mirrors in place
    canvas = int(math.ceil(need / 8.0) * 8)
    info = {"durations": {name: c.durations for name, c in clips.items()}, "loops": {name: c.loop for name, c in clips.items()},
            "fps": {name: len(c.frames) / sum(c.durations) for name, c in clips.items()}}
    if not form.get("ride"):
        spec, windup = motion_.attack_frames(motion_.Body(skeleton2d.Skeleton2D.from_rig(rig), measure_feet(rig), form, present=set(rig.rest)))
        info["windup"] = windup
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": 0.0, "anims": anims,
            "still": form.get("still", "idle_0"), "extra": info}
