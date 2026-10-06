"""The goblin tree in Blender: the base goblin and its 28 forms on one skeleton (goblin_kit.py), dressed from a table (goblin_forms.py) with gear
(goblin_gear.py) and moved by biped_motion.py (pure Python, tested without Blender). A rider's mount is the wolf kit. Every form gets idle,
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
import attack_kinds  # noqa: E402
import goblin_forms as forms  # noqa: E402
import goblin_gear as gear  # noqa: E402
import goblin_kit as kit  # noqa: E402
import biped_motion as motion_  # noqa: E402
import player_poses  # noqa: E402
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
SLUMP_SPINE, SLUMP_HEAD, SLUMP_ARMS = 48.0, 28.0, 0.85   # a rider whose mount dies: how far (degrees) its spine and head fold forward, and how much of its arms' lift goes
RIDE = {"thigh_n": down(84), "thigh_f": down(84), "shin_n": down(-88), "shin_f": down(-88), "foot_n": down(6), "foot_f": down(6), "spine": up(2)}
WALK_SPEED_RUN = 1.9   # a run covers the ground this many times as fast as the walk does


def _form(variant):
    """The form's table entry with the attack it uses: what it holds and the verb it casts decide it (attack_kinds.resolve)."""
    form = forms.FORMS[variant or "goblin"]
    return dict(form, attack=attack_kinds.resolve(form, "goblin_" + variant if variant else "goblin", motion_.attack_kind(form)))


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
def _rider_arms(rot, form, t, swing_deg, lag=0.2, slump=0.0):
    """A seated rider's arms from the preset, relative to its body (which moves with the mount): they swing a little against the wolf's stride, and a slumping
    rider's go slack and hang (`slump` 0 to 1)."""
    a = ARMS[form.get("arms", "free")]
    c = math.cos(2.0 * math.pi * (t - lag))
    amp = swing_deg * a[4]
    slack = 1.0 - SLUMP_ARMS * slump
    rot["arm_n"], rot["fore_n"] = down(slack * (a[0] - amp * c)), down(slack * (a[1] + 0.6 * amp * (0.5 - 0.5 * c)))
    rot["arm_f"], rot["fore_f"] = down(slack * (a[2] + amp * c)), down(slack * (a[3] + 0.6 * amp * (0.5 + 0.5 * c)))


def _rider_frame(form, mount_rot, root, t, slump=0.0):
    """One frame of a rider: the mount's pose (its bones prefixed), the rider seated on it with its arms from the preset, and what it holds kept
    at the angle it was made at whatever the arm does. A rider whose mount is dying (`slump` 0 to 1) folds forward over its neck, its head and arms
    drop, and what it holds is no longer kept upright: it goes with the body."""
    out = {"w_" + b: v for b, v in mount_rot.items()}
    out.update(RIDE)
    _rider_arms(out, form, t, 6.0, slump=slump)
    out["spine"] = up(2.0 + 1.5 * math.sin(4.0 * math.pi * t) + SLUMP_SPINE * slump)
    out["head"] = up(SLUMP_HEAD * slump)
    for s in "nf":
        chain = ["w_hips", "w_spine", "hips", "spine", "arm_" + s, "fore_" + s]
        above = sum(out.get(b, (0.0, 0.0, 0.0))[1] for b in chain)
        arm = out.get("arm_" + s, (0, 0, 0))[1] + out.get("fore_" + s, (0, 0, 0))[1]
        out["item_" + s] = (0.0, form.get("item_angle", {}).get(s, 0.0) + 0.25 * arm - above * (1.0 - slump), 0.0)
    return out, root


def _slump(clip, i, n):
    """How far a rider has folded over by frame `i` of `n` of `clip`: nothing but in the death, where it eases in over the mount's fall and then holds."""
    if clip != "die" or n < 2:
        return 0.0
    p = min(1.0, i / (0.7 * (n - 1)))
    return p * p * (3.0 - 2.0 * p)


def rider_clips(rig, form, variant):
    """({name: Clip}, ppu) for a goblin on a wolf: the wolf moves as a wolf does (the quadruped motion on the mount's own flat skeleton, its bones
    prefixed) and the rider sits on it."""
    mount = form["mount"]
    mform = dict(wolf.mount_form(mount["fur"], mount["belly"], mount.get("barding")), attack=attack_kinds.resolve({}, "goblin_" + (variant or ""), "bite", quad=True))
    body = wolf.body_of(rig, mform, "w_")
    rig.pose(*_rider_frame(form, wolf.motion_.idle_clip(body).frames[0][0], wolf.motion_.idle_clip(body).frames[0][1], 0.0))
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = math.sqrt(w * h / ((x1 - x0) * (z1 - z0))) if h else w / (x1 - x0)
    clips = {}
    for name, c in wolf.clips_for(body, motion(variant), ppu).items():
        n = len(c.frames)
        frames = [_rider_frame(form, rot, root, i / n if c.loop else 0.0, _slump(name, i, n)) for i, (rot, root) in enumerate(c.frames)]
        out = secondary.series(set(rig.rest), motion_.SECONDARY, frames, {"idle": 0.15, "attack": 0.5, "hurt": 0.5, "die": 0.3}.get(name, 1.0), c.durations,
                               extra_chain=("w_hips", "w_spine"), periodic=c.loop)
        for i, (rot, _) in enumerate(frames):
            for bone, series in out.items():
                rot[bone] = down(series[i])
        clips[name] = motion_.Clip(frames, c.durations, c.loop, c.grounded)
    return clips, ppu


# ---- sizing -----------------------------------------------------------------------------------------------------------------------
PLAYER_SPEED = 105.0   # px/s: the base goblin is the player's two-legged body, whose run is about twice this (data/movement/biped.tres)


def motion(variant):
    if not variant or variant == "goblin":
        return PLAYER_SPEED
    return sizing.speed_of("goblin", variant)


BASE_GROWTH = 1.15   # the player's goblin is drawn this much bigger than the drawing it replaced (Sean, 2026-10-06: a bit taller)


def today(variant):
    """The base goblin is sized by the sheet it replaced (before/goblin_base.json, saved before the render took its place), grown by BASE_GROWTH."""
    base = (os.path.join(HERE, "before", "goblin_base.json"), "idle_1") if not variant or variant == "goblin" else None
    w, h = sizing.today("goblin", variant, _form(variant)["width"], base)
    return (w * BASE_GROWTH, h * BASE_GROWTH if h else h) if base is not None else (w, h)


def clips_of(rig, variant):
    """({name: motion.Clip}, pixels per unit) for this form: the unit is sized so the still covers the area of the still the form replaces."""
    form = _form(variant)
    if form.get("ride"):
        return rider_clips(rig, form, variant)
    body = body_of(rig, form)
    idle = motion_.idle_clip(body)
    rig.pose(*idle.frames[0])
    x0, x1, z0, z1 = rig.extent()
    ppu = sizing.pixels_per_unit((x1 - x0, z1 - z0), today(variant), "height" if not variant or variant == "goblin" else "area")
    speed = motion(variant)
    walk_cycle, walk_stride = motion_.plan_gait(body, "walk", speed, ppu)
    run_cycle, run_stride = motion_.plan_gait(body, "run", speed * WALK_SPEED_RUN, ppu)
    clips = {
        "idle": idle,
        "walk": motion_.gait_clip(body, "walk", walk_cycle, walk_stride),
        "run": motion_.gait_clip(body, "run", run_cycle, run_stride),
        "attack": motion_.attack_clip(body),
        "hurt": motion_.hurt_clip(body),
        "die": motion_.die_clip(body),
    }
    if not variant or variant == "goblin":   # the base goblin is also the player's biped body: it leaps, falls, rolls, slides, mantles and clings as well
        clips.update({name: player_poses.clip(body, name) for name in player_poses.FRAMES})
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
    info["windup"] = wolf.motion_.WINDUP if form.get("ride") else motion_.ATTACK_WINDUP
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": 0.0, "anims": anims,
            "still": form.get("still", "idle_0"), "extra": info}


# ---- gestures ---------------------------------------------------------------------------------------------------------------------
# the preset of biped_motion.ATTACKS that plays each gesture (verb_anims.ARCHETYPES); a gesture not listed is one the two-legged bodies cannot play yet
GESTURES = {"cast": "cast", "slam": "slam", "roar": "roar", "lunge": "lunge", "guard": "guard", "claw": "claw"}


def gesture_clip(rig, variant, archetype):
    """The attack clip of this form playing the gesture `archetype`; a KeyError when it has no preset for it (a rider's attack is its mount's, so it has none)."""
    form = dict(_form(variant), attack=GESTURES[archetype])
    if form.get("ride"):
        raise KeyError(archetype)
    return motion_.attack_clip(body_of(rig, form))
