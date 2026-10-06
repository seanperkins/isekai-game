"""How a goblin moves: idle, walk, run, attack, hurt and die, as poses for the rig of goblin_skeleton.py. Pure Python (no Blender), so it is
tested in test_goblin_motion.py; creatures/goblin.py feeds it the measured feet and renders what it makes.

The goblin goes about in a crouch (docs/research/images/art-target/goblin-reference-sheet.png): the chest leans about 30 degrees forward, the head
is thrust ahead of it, the hips are low over bent knees and the feet are a wide step apart. Everything is placed in the world, not
relative to the parts above it, so a lean does not swing the arms back: a leg is solved by IK to where its foot goes (limbs.Leg), an arm and
what it holds are aimed at world angles (limbs.aim), and the rotations the rig needs fall out of that.

Angles are degrees from straight down, forward positive (see skeleton2d.py), except `lean` and `head_lean`, which are how far the chest and
the head are tipped forward from upright. Lengths that scale with the creature are fractions of the leg's length `L` (thigh plus shin).
"""
import math

import anim
import secondary
from limbs import Leg, aim, down

# ---- presets --------------------------------------------------------------------------------------------------------------------
# (near upper arm, near forearm, far upper arm, far forearm, how much it swings): turns from each bone's rest direction, the forearm's from the
# upper arm's, in the world (so the arms do not follow the chest's lean)
ARMS = {
    "free": (10, 34, 6, 20, 1.0),
    "guard": (24, 82, 24, 82, 0.15),          # both hands close to the chest
    "guard_n": (24, 82, 4, 24, 0.15),         # the near hand up, the other at the side
    "fists": (20, 70, 20, 70, 0.1),
    "offer": (48, 8, 40, 16, 0.2),            # arms out in front, giving
    "offer_up": (62, 30, 6, 24, 0.2),         # the near hand held up and out
    "carry": (38, 46, 12, 30, 0.3),
    "play": (76, 98, 76, 98, 0.0),            # both hands at the mouth
    "cradle": (36, 78, 44, 92, 0.0),          # an instrument held in the crook of an arm
    "raise_n": (150, 24, 8, 28, 0.2),         # the near arm high
    "raise_f": (22, 40, 150, 24, 0.2),        # the far arm high
    "lantern": (20, 30, 70, 30, 0.2),         # a lantern low, the other hand beckoning
    "shield": (40, 70, 36, 50, 0.15),
    "sword": (60, 50, 8, 24, 0.2),            # a blade over the shoulder
}
# how a form stands: "lean" and "head" are extra degrees on the chest and head, "pelvis" moves the hips (dx, dz, fractions of L), "feet" moves a
# foot's contact point (dx, dz, extra pitch): a raised foot has dz above 0
STANCES = {
    "hunch": {"lean": 12.0, "head": -4.0, "pelvis": (0.03, -0.06)},
    "wide": {"feet": {"n": (0.20, 0.0, 0.0), "f": (-0.20, 0.0, 0.0)}, "pelvis": (0.0, -0.04)},
    "stomp": {"feet": {"f": (0.20, 0.30, 20.0)}, "lean": -4.0},
    "hop": {"feet": {"f": (0.16, 0.26, 20.0)}, "lean": -8.0},
    "dance": {"feet": {"f": (0.18, 0.28, 20.0), "n": (-0.06, 0.0, 0.0)}, "lean": -10.0},
    "tiptoe": {"feet": {"n": (0.0, 0.0, -32.0), "f": (0.0, 0.0, -32.0)}},
    "listen": {"head": 10.0, "lean": -4.0},
}

CROUCH = 0.82          # hip height above the ankle, as a fraction of the leg's length, standing: a bend of about 58 degrees at the knee
STANCE_HALF = 0.31     # each foot this far (of L) either side of the hips in idle: a step 0.62 L wide
LEAN, HEAD_LEAN = 28.0, 12.0

GAITS = {
    "walk": dict(duty=0.6, crouch=0.82, bob=0.045, lift=0.19, lean=30.0, lean_amp=1.4, head=12.0, swing=18.0, wind=1.0),
    "run": dict(duty=0.4, crouch=0.74, bob=-0.085, lift=0.34, lean=42.0, lean_amp=2.5, head=18.0, swing=40.0, wind=1.5),
}
WALK_FRAMES, RUN_FRAMES, IDLE_FRAMES = 12, 10, 8
IDLE_SECONDS = 1.2

# hung things: the chain of bones above whose angle they ride, how much the body's bounce shakes them (degrees per unit of height), how far
# they trail in a walk (degrees) and the spring (Hz, damping ratio): visible displacement is the point, so ears give a pixel or two
SECONDARY = {
    "ear_n": dict(parents=["hips", "spine", "head"], bob=420.0, wind=-4.0, freq=4.5, zeta=0.45),
    "ear_f": dict(parents=["hips", "spine", "head"], bob=420.0, wind=-4.0, freq=4.5, zeta=0.45),
    "cap_tip": dict(parents=["hips", "spine", "head"], bob=320.0, wind=-7.0, freq=3.0, zeta=0.5),
    "hood_tip": dict(parents=["hips", "spine", "head"], bob=240.0, wind=-9.0, freq=3.0, zeta=0.5),
    "scarf_tail": dict(parents=["hips", "spine"], bob=160.0, wind=-22.0, freq=2.6, zeta=0.45),
    "cloak1": dict(parents=["hips", "spine"], bob=120.0, wind=-9.0, freq=2.4, zeta=0.5),
    "cloak2": dict(after="cloak1", bob=220.0, wind=-12.0, freq=2.1, zeta=0.45),
    "pack": dict(parents=["hips", "spine"], bob=520.0, wind=0.0, freq=3.0, zeta=0.5),
}

# what a form holds decides how it attacks (the gear on its near hand, see goblin_gear.py)
ATTACK_BY_GEAR = {
    "axe": "chop", "club": "chop", "hammer": "chop", "hammer_small": "chop", "pick": "chop", "wrench": "chop", "sword_big": "chop",
    "dagger": "stab", "spear": "thrust", "spiked_cap_held": "stab",
    "staff": "cast", "ring": "cast", "stone": "cast", "lantern": "cast", "spindle": "cast", "pipe": "cast", "lyre": "cast", "horn": "cast",
    "hawk": "cast",
}


def attack_kind(form):
    if form.get("attack"):
        return form["attack"]
    for name, opts in form["gear"]:
        if name in ATTACK_BY_GEAR and opts.get("side", "n") == "n":
            return ATTACK_BY_GEAR[name]
    return "swipe"


class Body:
    """What the motion needs to know about one goblin: its flat skeleton, the feet as measured from its meshes (ankle_h, heel, toe), its form and
    the bones its rig really has (gear adds some)."""
    def __init__(self, skel, feet, form, present=None):
        self.skel, self.form = skel, form
        self.present = set(present) if present is not None else set(skel.rest)
        self.legs = {s: Leg(skel, s, *feet[s]) for s in "nf"}
        self.L = self.legs["n"].reach
        self.hip = self.legs["n"].hip
        self.stance = STANCES.get(form.get("stance"), {})

    def hip_z(self, crouch):
        leg = self.legs["n"]
        return leg.ankle_h + crouch * self.L + self.stance.get("pelvis", (0.0, 0.0))[1] * self.L


# ---- pieces ---------------------------------------------------------------------------------------------------------------------
def _posture(body, rot, lean, head_lean):
    """Tip the chest forward `lean` degrees from upright and the head `head_lean`, both in the world."""
    aim(body.skel, rot, "spine", 180.0 - lean)
    aim(body.skel, rot, "head", 180.0 - head_lean)


def _arms(body, rot, t, swing, lag=0.07, offsets=None):
    """The arms from the form's preset: they swing against the legs (the near arm back as the near leg is forward), the elbow closes as the hand
    comes forward, and they trail the legs by `lag` of a cycle. `offsets` is {bone: degrees added to its world direction}."""
    a = ARMS[body.form.get("arms", "free")]
    c = math.cos(2.0 * math.pi * (t - lag))
    amp = swing * a[4]
    sk = body.skel
    for side, up_deg, fore_deg in (("n", a[0] - amp * c, a[1] + 0.6 * amp * (0.5 - 0.5 * c)), ("f", a[2] + amp * c, a[3] + 0.6 * amp * (0.5 + 0.5 * c))):
        upper = sk.rest_direction("arm_" + side) + up_deg
        fore = sk.rest_direction("fore_" + side) + up_deg + fore_deg
        off = offsets or {}
        aim(sk, rot, "arm_" + side, upper + off.get("arm_" + side, 0.0))
        aim(sk, rot, "fore_" + side, fore + off.get("fore_" + side, 0.0))


def direction_of(body, rot, bone):
    """The world direction (degrees) a bone points in a pose."""
    sk = body.skel
    return sk.rest_direction(bone) - sum(rot.get(b, (0.0, 0.0, 0.0))[1] for b in sk.chain(bone) + [bone])


def _hold_items(body, rot, gain=0.25):
    """What a goblin holds stays at the angle it was made at, whatever the arm does (it follows `gain` of the forearm's turn from its rest)."""
    sk = body.skel
    for s in "nf":
        bone = "item_" + s
        if bone not in sk.rest:
            continue
        tilt = body.form.get("item_angle", {}).get(s, 0.0) + gain * (direction_of(body, rot, "fore_" + s) - sk.rest_direction("fore_" + s))
        aim(sk, rot, bone, sk.rest_direction(bone) - tilt)


def _plant(body, rot, side, hip, contact_x, pitch=0.0, lift=0.0):
    leg = body.legs[side]
    ax, az = anim.plant(contact_x, pitch, leg.heel, leg.toe, leg.ankle_h)
    rot.update(leg.solve(hip, (ax, az + lift), pitch))


def _plant_heel(body, rot, side, hip, contact_x, pitch):
    """A foot planted flat at `contact_x` whose heel lifts (a negative `pitch`, toe down): it turns about the toe, which stays where it was."""
    leg = body.legs[side]
    flat_x, _ = anim.plant(contact_x, 0.0, leg.heel, leg.toe, leg.ankle_h)
    ax, az = anim.plant_toe(flat_x + leg.toe, min(0.0, pitch), leg.heel, leg.toe, leg.ankle_h)
    rot.update(leg.solve(hip, (ax, az), min(0.0, pitch)))


def _stand_feet(body, rot, hip, shift=0.0):
    """Both feet planted in the idle stance, a step apart (so both legs show from the side), each of them moved by the form's stance."""
    L = body.L
    for side, half in (("n", STANCE_HALF), ("f", -STANCE_HALF)):
        dx, dz, dpitch = body.stance.get("feet", {}).get(side, (0.0, 0.0, 0.0))
        _plant(body, rot, side, hip, body.hip[0] + (half + dx + shift) * L, dpitch, dz * L)


# ---- idle -----------------------------------------------------------------------------------------------------------------------
def idle_pose(body, t):
    """A guarded crouch, feet planted: the chest and head breathe and the weight shifts a little over the feet."""
    L = body.L
    st = body.stance
    breath = 0.5 - 0.5 * math.cos(2.0 * math.pi * t)
    px = st.get("pelvis", (0.0, 0.0))[0] * L + 0.012 * L * math.sin(2.0 * math.pi * t)
    hip = (body.hip[0] + px, body.hip_z(CROUCH) - 0.012 * L * breath)
    rot = {}
    _stand_feet(body, rot, hip)
    lean = LEAN + st.get("lean", 0.0) + 1.6 * math.sin(2.0 * math.pi * t - 0.6)
    head = HEAD_LEAN + st.get("head", 0.0) + 1.5 * math.sin(2.0 * math.pi * t + 0.9)
    _posture(body, rot, lean, head)
    _arms(body, rot, t, 3.0, lag=0.15)
    _hold_items(body, rot)
    return rot, (px, 0.0, hip[1] - body.hip[1])


# ---- walk and run ---------------------------------------------------------------------------------------------------------------
def gait_pose(body, gait, t, stride):
    """One pose of a walk or a run at cycle position t in [0, 1): `stride` is how far each planted foot travels while it is down (the body is
    still in the picture and the ground slides back under it)."""
    g = GAITS[gait]
    L = body.L
    st = body.stance
    pel_z = body.hip_z(g["crouch"]) + anim.pelvis_height(t, 0.0, g["bob"] * L, g["duty"])
    hip = (body.hip[0], pel_z)
    rot = {}
    for side, phase in (("n", 0.0), ("f", 0.5)):
        leg = body.legs[side]
        x, z, pitch, _ = anim.foot_pose(t + phase, stride, g["duty"], g["lift"] * L, leg.heel, leg.toe, leg.ankle_h)
        rot.update(leg.solve(hip, (hip[0] + x, z), pitch))
    lean = g["lean"] + st.get("lean", 0.0) + g["lean_amp"] * math.cos(4.0 * math.pi * (t - 0.3))
    head = g["head"] + st.get("head", 0.0) - 0.8 * g["lean_amp"] * math.cos(4.0 * math.pi * (t - 0.3)) + 1.2 * math.cos(4.0 * math.pi * (t - 0.08))
    _posture(body, rot, lean, head)
    _arms(body, rot, t, g["swing"])
    _hold_items(body, rot)
    return rot, (0.0, 0.0, pel_z - body.hip[1])


# ---- attack ---------------------------------------------------------------------------------------------------------------------
REST = "rest"   # in a key: the form's own resting value of that channel (its idle pose)

# Each attack is the frames it is drawn in, [(start second, how long)], and eased keys over time for every channel. Directions are world degrees
# (0 down, 90 forward, 180 up); lean and head are tipped-forward degrees; pelvis and feet are fractions of L from where they rest; `item` is how
# far forward the weapon (which points up in the hand) is tipped. The anticipation is held, the swing is fast, the impact is held, the recovery slow.
ATTACKS = {
    "chop": dict(
        frames=[(0.00, 0.06), (0.06, 0.06), (0.12, 0.12), (0.24, 0.03), (0.27, 0.03), (0.30, 0.09), (0.39, 0.07), (0.46, 0.07), (0.53, 0.09), (0.62, 0.11)],
        windup=3,
        keys={
            "lean": [(0.0, REST, "out"), (0.12, 12.0, "smooth"), (0.24, 12.0, "in"), (0.30, 44.0, "out"), (0.46, 48.0, "smooth"), (0.72, REST, "smooth")],
            "head": [(0.0, REST, "out"), (0.12, 4.0, "smooth"), (0.24, 4.0, "in"), (0.30, 26.0, "out"), (0.46, 28.0, "smooth"), (0.72, REST, "smooth")],
            "pelvis_x": [(0.0, 0.0, "out"), (0.12, -0.07, "smooth"), (0.24, -0.07, "in"), (0.30, 0.16, "out"), (0.46, 0.17, "smooth"), (0.72, 0.0, "smooth")],
            "pelvis_z": [(0.0, 0.0, "out"), (0.12, -0.07, "smooth"), (0.24, -0.07, "in"), (0.30, -0.08, "out"), (0.50, -0.05, "smooth"), (0.72, 0.0, "smooth")],
            "arm_n": [(0.0, REST, "out"), (0.12, 205.0, "smooth"), (0.24, 205.0, "in"), (0.27, 120.0, "linear"), (0.30, 48.0, "out"), (0.46, 28.0, "smooth"), (0.72, REST, "smooth")],
            "fore_n": [(0.0, REST, "out"), (0.12, 235.0, "smooth"), (0.24, 235.0, "in"), (0.27, 140.0, "linear"), (0.30, 58.0, "out"), (0.46, 34.0, "smooth"), (0.72, REST, "smooth")],
            "item_n": [(0.0, REST, "out"), (0.12, -62.0, "smooth"), (0.24, -62.0, "in"), (0.27, 10.0, "linear"), (0.30, 58.0, "out"), (0.46, 40.0, "smooth"), (0.72, REST, "smooth")],
            "arm_f": [(0.0, REST, "out"), (0.12, 60.0, "smooth"), (0.24, 60.0, "in"), (0.30, -20.0, "out"), (0.46, -10.0, "smooth"), (0.72, REST, "smooth")],
            "fore_f": [(0.0, REST, "out"), (0.12, 100.0, "smooth"), (0.24, 100.0, "in"), (0.30, 20.0, "out"), (0.72, REST, "smooth")],
            "step_n": [(0.0, 0.0, "smooth"), (0.24, 0.0, "in"), (0.30, 0.20, "out"), (0.55, 0.20, "smooth"), (0.72, 0.0, "smooth")],
            "lift_n": [(0.0, 0.0, "smooth"), (0.24, 0.0, "smooth"), (0.27, 0.10, "smooth"), (0.30, 0.0, "smooth")],
            "heel_f": [(0.0, 0.0, "smooth"), (0.30, 0.0, "out"), (0.36, -24.0, "smooth"), (0.60, -20.0, "smooth"), (0.72, 0.0, "smooth")],
        }),
}
ATTACKS["stab"] = dict(ATTACKS["chop"])
ATTACKS["thrust"] = dict(ATTACKS["chop"])
ATTACKS["cast"] = dict(ATTACKS["chop"])
ATTACKS["swipe"] = dict(ATTACKS["chop"])


def _rest_channels(body):
    """The values a form's idle pose has for the channels attacks key from REST."""
    rot, _ = idle_pose(body, 0.0)
    return {"lean": LEAN + body.stance.get("lean", 0.0), "head": HEAD_LEAN + body.stance.get("head", 0.0),
            "arm_n": direction_of(body, rot, "arm_n"), "fore_n": direction_of(body, rot, "fore_n"),
            "arm_f": direction_of(body, rot, "arm_f"), "fore_f": direction_of(body, rot, "fore_f"),
            "item_n": 180.0 - direction_of(body, rot, "item_n")}


def attack_frames(body):
    """[(start second, duration)] of the attack's frames and how many of them are the windup (the rest are the release and the recovery)."""
    spec = ATTACKS[attack_kind(body.form)]
    return spec["frames"], spec["windup"]


def attack_pose(body, time):
    spec = ATTACKS[attack_kind(body.form)]
    rest = _rest_channels(body)
    ch = {}
    for name, keys in spec["keys"].items():
        resolved = [(t, rest.get(name, 0.0) if v == REST else v, e) for t, v, e in keys]
        ch[name] = anim.sample(resolved, time)
    L = body.L
    hip = (body.hip[0] + ch["pelvis_x"] * L, body.hip_z(CROUCH) + ch["pelvis_z"] * L)
    rot = {}
    # the planted foot stays where it is; the near foot steps into the blow
    lift, pitch = ch["lift_n"] * L, 0.0
    _plant(body, rot, "n", hip, body.hip[0] + (STANCE_HALF + ch["step_n"]) * L, pitch, lift)
    _plant_heel(body, rot, "f", hip, body.hip[0] - STANCE_HALF * L, ch["heel_f"])
    _posture(body, rot, ch["lean"], ch["head"])
    sk = body.skel
    aim(sk, rot, "arm_n", ch["arm_n"])
    aim(sk, rot, "fore_n", ch["fore_n"])
    aim(sk, rot, "arm_f", ch["arm_f"])
    aim(sk, rot, "fore_f", ch["fore_f"])
    _hold_items(body, rot)
    aim(sk, rot, "item_n", 180.0 - ch["item_n"])
    return rot, (ch["pelvis_x"] * L, 0.0, hip[1] - body.hip[1])


# ---- hurt -----------------------------------------------------------------------------------------------------------------------
# A blow rocks the goblin back on its feet (the feet stay planted): the chest snaps up, the head throws back, the hips go back and down and the
# arms fling, then it settles. Keys named d_* are degrees added to the form's resting direction of that bone.
HURT = dict(
    frames=[(0.00, 0.04), (0.04, 0.07), (0.11, 0.07), (0.18, 0.08), (0.26, 0.10)],
    keys={
        "lean": [(0.0, REST, "out"), (0.04, 10.0, "out"), (0.11, 6.0, "smooth"), (0.18, 20.0, "smooth"), (0.32, REST, "smooth")],
        "head": [(0.0, REST, "out"), (0.04, -8.0, "out"), (0.11, -16.0, "smooth"), (0.18, 4.0, "smooth"), (0.32, REST, "smooth")],
        "pelvis_x": [(0.0, 0.0, "out"), (0.04, -0.05, "out"), (0.11, -0.09, "smooth"), (0.18, -0.04, "smooth"), (0.32, 0.0, "smooth")],
        "pelvis_z": [(0.0, 0.0, "out"), (0.04, -0.02, "out"), (0.11, -0.05, "smooth"), (0.18, -0.03, "smooth"), (0.32, 0.0, "smooth")],
        "d_arm_n": [(0.0, 0.0, "out"), (0.04, -40.0, "out"), (0.11, -62.0, "smooth"), (0.18, -20.0, "smooth"), (0.32, 0.0, "smooth")],
        "d_fore_n": [(0.0, 0.0, "out"), (0.04, -30.0, "out"), (0.11, -50.0, "smooth"), (0.18, -12.0, "smooth"), (0.32, 0.0, "smooth")],
        "d_arm_f": [(0.0, 0.0, "out"), (0.04, -34.0, "out"), (0.11, -56.0, "smooth"), (0.18, -16.0, "smooth"), (0.32, 0.0, "smooth")],
        "d_fore_f": [(0.0, 0.0, "out"), (0.04, -20.0, "out"), (0.11, -40.0, "smooth"), (0.18, -10.0, "smooth"), (0.32, 0.0, "smooth")],
        "d_item_n": [(0.0, 0.0, "out"), (0.04, -20.0, "out"), (0.11, -34.0, "smooth"), (0.18, -8.0, "smooth"), (0.32, 0.0, "smooth")],
    })


def hurt_frames():
    return HURT["frames"]


def hurt_pose(body, time):
    rest = _rest_channels(body)
    ch = {}
    for name, keys in HURT["keys"].items():
        ch[name] = anim.sample([(t, rest.get(name, 0.0) if v == REST else v, e) for t, v, e in keys], time)
    L = body.L
    hip = (body.hip[0] + ch["pelvis_x"] * L, body.hip_z(CROUCH) + ch["pelvis_z"] * L)
    rot = {}
    _stand_feet(body, rot, hip)
    _posture(body, rot, ch["lean"], ch["head"])
    sk = body.skel
    for bone in ("arm_n", "fore_n", "arm_f", "fore_f"):
        aim(sk, rot, bone, rest[bone] + ch["d_" + bone])
    _hold_items(body, rot)
    aim(sk, rot, "item_n", 180.0 - (rest["item_n"] + ch["d_item_n"]))
    return rot, (ch["pelvis_x"] * L, 0.0, hip[1] - body.hip[1])


# ---- die ------------------------------------------------------------------------------------------------------------------------
# The goblin is hit, its knees go, it folds forward, catches itself on its hands, hits the ground and lies prone with its legs trailing. After
# the first frame nothing is planted, so every bone has its own keys (world directions; REST is where the idle pose has it) and the rig is set
# on the ground afterwards. Lengths are fractions of L.
DIE = dict(
    frames=[(0.00, 0.06), (0.06, 0.08), (0.14, 0.08), (0.22, 0.10), (0.32, 0.12), (0.44, 0.16), (0.60, 0.30), (0.90, 0.30)],
    keys={
        "x": [(0.0, 0.0, "out"), (0.06, -0.08, "out"), (0.14, -0.10, "smooth"), (0.22, 0.05, "smooth"), (0.32, 0.30, "smooth"), (0.44, 0.55, "out"), (0.60, 0.58, "smooth"), (0.9, 0.58, "smooth")],
        "hips": [(0.0, 0.0, "out"), (0.14, 8.0, "smooth"), (0.22, 22.0, "smooth"), (0.32, 46.0, "smooth"), (0.44, 78.0, "out"), (0.9, 84.0, "smooth")],
        "lean": [(0.0, REST, "out"), (0.06, 8.0, "out"), (0.14, 22.0, "smooth"), (0.22, 52.0, "in"), (0.32, 76.0, "in"), (0.44, 92.0, "out"), (0.60, 96.0, "smooth"), (0.9, 96.0, "smooth")],
        "head": [(0.0, REST, "out"), (0.06, -4.0, "out"), (0.14, 18.0, "smooth"), (0.22, 40.0, "smooth"), (0.44, 100.0, "out"), (0.60, 104.0, "smooth"), (0.9, 104.0, "smooth")],
        "thigh_n": [(0.0, REST, "out"), (0.14, 62.0, "smooth"), (0.22, 40.0, "smooth"), (0.32, 0.0, "smooth"), (0.44, -70.0, "out"), (0.9, -80.0, "smooth")],
        "shin_n": [(0.0, REST, "out"), (0.14, -40.0, "smooth"), (0.22, -60.0, "smooth"), (0.32, -80.0, "smooth"), (0.44, -96.0, "out"), (0.9, -100.0, "smooth")],
        "foot_n": [(0.0, REST, "out"), (0.14, 100.0, "smooth"), (0.32, 60.0, "smooth"), (0.44, -70.0, "out"), (0.9, -76.0, "smooth")],
        "thigh_f": [(0.0, REST, "out"), (0.14, 50.0, "smooth"), (0.22, 20.0, "smooth"), (0.32, -20.0, "smooth"), (0.44, -86.0, "out"), (0.9, -96.0, "smooth")],
        "shin_f": [(0.0, REST, "out"), (0.14, -48.0, "smooth"), (0.22, -70.0, "smooth"), (0.32, -90.0, "smooth"), (0.44, -104.0, "out"), (0.9, -110.0, "smooth")],
        "foot_f": [(0.0, REST, "out"), (0.14, 96.0, "smooth"), (0.32, 40.0, "smooth"), (0.44, -84.0, "out"), (0.9, -90.0, "smooth")],
        "arm_n": [(0.0, REST, "out"), (0.06, 160.0, "out"), (0.14, 120.0, "smooth"), (0.22, 90.0, "smooth"), (0.32, 60.0, "smooth"), (0.44, 100.0, "out"), (0.9, 108.0, "smooth")],
        "fore_n": [(0.0, REST, "out"), (0.06, 190.0, "out"), (0.14, 140.0, "smooth"), (0.22, 100.0, "smooth"), (0.32, 40.0, "smooth"), (0.44, 96.0, "out"), (0.9, 104.0, "smooth")],
        "arm_f": [(0.0, REST, "out"), (0.06, 150.0, "out"), (0.14, 100.0, "smooth"), (0.22, 70.0, "smooth"), (0.32, 40.0, "smooth"), (0.44, 80.0, "out"), (0.9, 88.0, "smooth")],
        "fore_f": [(0.0, REST, "out"), (0.06, 170.0, "out"), (0.14, 120.0, "smooth"), (0.22, 80.0, "smooth"), (0.32, 20.0, "smooth"), (0.44, 80.0, "out"), (0.9, 86.0, "smooth")],
        "item_n": [(0.0, REST, "out"), (0.06, -30.0, "out"), (0.22, 20.0, "smooth"), (0.44, 90.0, "out"), (0.9, 90.0, "smooth")],
    })


def die_frames():
    return DIE["frames"]


def die_pose(body, time):
    sk = body.skel
    rot0, root0 = idle_pose(body, 0.0)
    rest = {b: direction_of(body, rot0, b) for b in ("thigh_n", "shin_n", "foot_n", "thigh_f", "shin_f", "foot_f", "arm_n", "fore_n", "arm_f", "fore_f")}
    rest["lean"], rest["head"] = LEAN + body.stance.get("lean", 0.0), HEAD_LEAN + body.stance.get("head", 0.0)
    rest["item_n"] = 180.0 - direction_of(body, rot0, "item_n")
    ch = {name: anim.sample([(t, rest.get(name, 0.0) if v == REST else v, e) for t, v, e in keys], time) for name, keys in DIE["keys"].items()}
    rot = {}
    aim(sk, rot, "hips", 180.0 - ch["hips"])
    _posture(body, rot, ch["lean"], ch["head"])
    for bone in ("thigh_n", "shin_n", "foot_n", "thigh_f", "shin_f", "foot_f", "arm_n", "fore_n", "arm_f", "fore_f"):
        aim(sk, rot, bone, ch[bone])
    aim(sk, rot, "item_f", 180.0 - 0.0)
    aim(sk, rot, "item_n", 180.0 - ch["item_n"])
    return rot, (root0[0] + ch["x"] * body.L, 0.0, 0.0)  # the render sets the whole body on the ground, so there is no height to give


# ---- clips ----------------------------------------------------------------------------------------------------------------------
class Clip:
    """The frames of one animation: [(rot, root)], how long each lasts in seconds, whether it loops and whether the rig is set on the ground
    afterwards (a fall has no feet to plant)."""
    def __init__(self, frames, durations, loop, grounded=False):
        self.frames, self.durations, self.loop, self.grounded = frames, durations, loop, grounded


def _with_secondary(body, frames, durations, wind, periodic):
    out = secondary.series(body.present, SECONDARY, frames, wind, durations, periodic=periodic)
    for i, (rot, root) in enumerate(frames):
        for bone, series in out.items():
            rot[bone] = down(series[i])
    return frames


def idle_clip(body):
    n = IDLE_FRAMES
    dur = [IDLE_SECONDS / n] * n
    return Clip(_with_secondary(body, [idle_pose(body, i / n) for i in range(n)], dur, 0.15, True), dur, True)


def gait_clip(body, gait, cycle, stride):
    n = WALK_FRAMES if gait == "walk" else RUN_FRAMES
    dur = [cycle / n] * n
    frames = [gait_pose(body, gait, i / n, stride) for i in range(n)]
    return Clip(_with_secondary(body, frames, dur, GAITS[gait]["wind"], True), dur, True)


def attack_clip(body):
    spec, _ = attack_frames(body)
    dur = [d for _, d in spec]
    frames = [attack_pose(body, t) for t, _ in spec]
    return Clip(_with_secondary(body, frames, dur, 0.5, False), dur, False)


def hurt_clip(body):
    spec = hurt_frames()
    dur = [d for _, d in spec]
    return Clip(_with_secondary(body, [hurt_pose(body, t) for t, _ in spec], dur, 0.5, False), dur, False)


def die_clip(body):
    spec = die_frames()
    dur = [d for _, d in spec]
    return Clip(_with_secondary(body, [die_pose(body, t) for t, _ in spec], dur, 0.3, False), dur, False, grounded=True)
