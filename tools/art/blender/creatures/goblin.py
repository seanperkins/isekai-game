"""The goblin tree: the base goblin and its 28 forms on one skeleton (goblin_kit.py), dressed from a table (goblin_forms.py) with gear
(goblin_gear.py). A rider's mount is the wolf kit. Every form gets idle, walk and attack; the pose of its arms, its stance and the angle of
whatever it holds come from small presets, so a new form is a few lines of data, not new animation.

Each form is sized so the still covers the same area (width times height) as the still its sheet frame has today (assets/sheets/forms_goblin.json), so
the game's size ladder is kept while the proportions are the form's own.
"""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import goblin_forms as forms  # noqa: E402
import goblin_gear as gear  # noqa: E402
import goblin_kit as kit  # noqa: E402
import rigkit as k  # noqa: E402
import anim  # noqa: E402
from creatures import wolf  # noqa: E402
from goblin_kit import down, up  # noqa: E402

NAME = "goblin"
MARGIN = 3
PAD = 4
RIDER_SCALE = 1.0

# (near upper arm, near forearm, far upper arm, far forearm, how much it still swings), degrees; see goblin_kit.down
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
# the way a form stands: "bones" are extra degrees on the spine and head, "pelvis" moves the hips (a fraction of leg length), "feet" move a foot's
# target (dx, dz as fractions of leg length, extra pitch in degrees). Only the riders still pose their legs by hand (RIDE).
STANCES = {
    "hunch": {"bones": {"spine": up(16), "head": up(-8)}, "pelvis": (0.03, -0.07)},
    "wide": {"feet": {"n": (0.22, 0.0, 0.0), "f": (-0.22, 0.0, 0.0)}, "pelvis": (0.0, -0.03)},
    "stomp": {"feet": {"f": (0.2, 0.3, 20.0)}, "bones": {"spine": up(6)}},
    "hop": {"feet": {"f": (0.16, 0.26, 20.0)}, "bones": {"spine": up(-4)}},
    "dance": {"feet": {"f": (0.18, 0.28, 20.0), "n": (-0.06, 0.0, 0.0)}, "bones": {"spine": up(-6)}},
    "tiptoe": {"feet": {"n": (0.0, 0.0, -32.0), "f": (0.0, 0.0, -32.0)}},
    "listen": {"bones": {"head": (0.0, 14.0, 0.0), "spine": up(-3)}},
}
RIDE = {"thigh_n": down(84), "thigh_f": down(84), "shin_n": down(-88), "shin_f": down(-88), "foot_n": down(6), "foot_f": down(6), "spine": up(2)}
COUNTS = {"idle": 12, "walk": 12, "attack": 12}
DUTY = 0.6          # the share of a walk cycle a foot is on the ground
# the attack, as eased keys over its 12 poses (anim.sample): anticipation (frames 1-2), the swing (3-4), the impact (5), follow-through and
# recovery (6-11). Lengths are fractions of leg length, angles degrees. The clip holds the anticipation and the impact longer (HOLDS).
ATTACK = {
    "pelvis_x": [(0, 0.0, "smooth"), (2, -0.07, "in"), (3, -0.02, "in"), (5, 0.18, "out"), (7, 0.2, "smooth"), (11, 0.0, "smooth")],
    "pelvis_z": [(0, 0.0, "smooth"), (2, -0.09, "in"), (3, -0.04, "in"), (5, -0.06, "out"), (8, -0.03, "smooth"), (11, 0.0, "smooth")],
    "spine": [(0, 4.0, "smooth"), (2, -12.0, "in"), (3, 0.0, "in"), (5, 18.0, "out"), (7, 21.0, "smooth"), (11, 4.0, "smooth")],
    "head": [(0, -2.0, "smooth"), (2, 8.0, "in"), (5, -12.0, "out"), (7, -14.0, "smooth"), (11, -2.0, "smooth")],
    "arm_n": [(0, 10.0, "smooth"), (2, -150.0, "in"), (3, -60.0, "in"), (4, 10.0, "in"), (5, 58.0, "out"), (7, 74.0, "smooth"), (11, 10.0, "smooth")],
    "fore_n": [(0, 34.0, "smooth"), (2, 18.0, "in"), (5, 8.0, "out"), (7, 4.0, "smooth"), (11, 34.0, "smooth")],
    "arm_f": [(0, 6.0, "smooth"), (2, 44.0, "in"), (5, -22.0, "out"), (7, -12.0, "smooth"), (11, 6.0, "smooth")],
    "fore_f": [(0, 20.0, "smooth"), (2, 52.0, "in"), (5, 8.0, "out"), (11, 20.0, "smooth")],
    "item_n": [(0, 0.0, "smooth"), (2, 74.0, "in"), (3, 62.0, "in"), (4, 0.0, "in"), (5, -62.0, "out"), (7, -84.0, "smooth"), (11, 0.0, "smooth")],
    "foot_n_x": [(0, 0.0, "smooth"), (2, -0.03, "in"), (3, 0.0, "in"), (5, 0.26, "out"), (8, 0.26, "smooth"), (10, 0.0, "smooth")],
    "foot_n_z": [(0, 0.0, "smooth"), (3, 0.0, "smooth"), (4, 0.16, "smooth"), (5, 0.0, "smooth"), (8, 0.0, "smooth"), (9, 0.1, "smooth"), (10, 0.0, "smooth")],
    "foot_n_pitch": [(0, 0.0, "smooth"), (4, -8.0, "smooth"), (5, 12.0, "out"), (6, 0.0, "smooth")],
    "foot_f_pitch": [(0, 0.0, "smooth"), (4, 0.0, "in"), (5, -26.0, "out"), (8, -26.0, "smooth"), (10, 0.0, "smooth")],
}
# how many frames of the clip each attack pose stays up: a held anticipation, a fast swing, a held impact (see docs/research/rig-weight-research.md)
HOLDS = [1, 2, 3, 1, 1, 3, 2, 1, 1, 1, 2, 1]
# the things hung on the body that lag it on a spring (anim.follow): the chain of bones above whose angle they ride, how much the body's bounce
# shakes them (degrees per unit of height), how far they trail in a walk (degrees), and the spring. Only those a form's gear made are used.
SECONDARY = {
    "ear_n": dict(parents=["hips", "spine", "head"], bob=420.0, wind=-4.0, k=0.22, c=0.40),
    "ear_f": dict(parents=["hips", "spine", "head"], bob=420.0, wind=-4.0, k=0.22, c=0.40),
    "cap_tip": dict(parents=["hips", "spine", "head"], bob=320.0, wind=-7.0, k=0.16, c=0.34),
    "hood_tip": dict(parents=["hips", "spine", "head"], bob=240.0, wind=-9.0, k=0.16, c=0.34),
    "scarf_tail": dict(parents=["hips", "spine"], bob=160.0, wind=-22.0, k=0.14, c=0.30),
    "cloak1": dict(parents=["hips", "spine"], bob=120.0, wind=-7.0, k=0.15, c=0.35),
    "cloak2": dict(after="cloak1", bob=220.0, wind=-9.0, k=0.14, c=0.30),
    "pack": dict(parents=["hips", "spine"], bob=520.0, wind=0.0, k=0.20, c=0.40),
}
WIND = {"walk": 1.0, "idle": 0.15, "attack": 0.5}


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


# ---- the legs ----
def _length(bone):
    head, tail = bone[0], bone[1]
    return math.hypot(tail.x - head.x, tail.z - head.z)


def _angle(bone):
    """A bone's rest direction, as an angle from straight down, positive when it points forward."""
    head, tail = bone[0], bone[1]
    return math.atan2(tail.x - head.x, -(tail.z - head.z))


class Leg:
    """One leg's lengths and rest angles, read from the rig, so the IK can say how far to turn each bone from where it was built."""
    def __init__(self, rig, side):
        thigh, shin, foot = (rig.rest[name + side] for name in ("thigh_", "shin_", "foot_"))
        self.l1, self.l2 = _length(thigh), _length(shin)
        self.rest1, self.rest2 = _angle(thigh), _angle(shin)
        self.hip = (thigh[0].x, thigh[0].z)
        self.ankle_z = foot[0].z
        self.toe = foot[1].x - foot[0].x
        self.heel = 0.4 * self.toe
        self.reach = self.l1 + self.l2

    def ankle(self, x, lift, pitch, grounded):
        """Where the ankle goes for a foot at x (world), `lift` off the ground and tilted by `pitch`: a planted foot rests on its heel or toe."""
        return x, self.ankle_z + lift + (anim.contact_lift(pitch, self.heel, self.toe) if grounded else 0.0)

    def solve(self, hip_z, ankle, pitch, side):
        """The thigh, shin and foot rotations that put the ankle on `ankle` (hip at `hip_z`) and the foot at `pitch` degrees."""
        a1, a2 = anim.ik2d(self.l1, self.l2, (self.hip[0], hip_z), ankle, 1)
        d1, d2 = math.degrees(a1 - self.rest1), math.degrees(a2 - self.rest2)
        return {"thigh_" + side: down(d1), "shin_" + side: down(d2 - d1), "foot_" + side: down(pitch - d2)}


# ---- poses ----
def _add(rot, bone, delta):
    cur = rot.get(bone, (0.0, 0.0, 0.0))
    rot[bone] = (cur[0] + delta[0], cur[1] + delta[1], cur[2] + delta[2])


def _stance(form):
    return STANCES.get(form.get("stance"), {})


def _arms(rot, form, t, swing_deg, lag=0.07):
    """Arms from the form's preset: they swing against the legs (the near arm back as the near leg is forward), the elbow closes as the hand
    comes forward, and they trail the legs by `lag` of a cycle."""
    a = ARMS[form.get("arms", "free")]
    c = math.cos(2.0 * math.pi * (t - lag))
    amp = swing_deg * a[4]
    rot["arm_n"], rot["fore_n"] = down(a[0] - amp * c), down(a[1] + 0.6 * amp * (0.5 - 0.5 * c))
    rot["arm_f"], rot["fore_f"] = down(a[2] + amp * c), down(a[3] + 0.6 * amp * (0.5 + 0.5 * c))


def _lagged(series, i):
    """A spring-follow of a per-frame series, so the spine trails the hips and the head trails the spine."""
    return anim.follow(series, stiffness=0.25, damping=0.5)[i]


def walk_pose(form, legs, i, n, stride):
    leg = legs["n"]
    t = i / n
    L = leg.reach
    lift = 0.2 * L
    base = leg.hip[1] - 0.05 * L
    pel_z = anim.pelvis_height(t, base, 0.05 * L, DUTY)
    st = _stance(form)
    pel_z += st.get("pelvis", (0.0, 0.0))[1] * L
    rot = {}
    for side, phase in (("n", 0.0), ("f", 0.5)):
        x, z, pitch, grounded = anim.stride_foot(t + phase, stride, DUTY, lift)
        ankle = legs[side].ankle(legs[side].hip[0] + x, z, pitch, grounded)
        rot.update(legs[side].solve(pel_z, ankle, pitch, side))
    lean = [3.5 - 1.2 * math.cos(4.0 * math.pi * (k / n - 0.3)) for k in range(n)]
    spine = _lagged(lean, i)
    rot["spine"] = up(spine)
    rot["head"] = up(-0.85 * spine + 1.8 * math.cos(4.0 * math.pi * (t - 0.08)))
    _arms(rot, form, t, 18.0)
    for bone, delta in st.get("bones", {}).items():
        _add(rot, bone, delta)
    return rot, (0.0, 0.0, pel_z - leg.hip[1])


def idle_pose(form, legs, i, n):
    leg = legs["n"]
    t = i / n
    L = leg.reach
    st = _stance(form)
    px, pz = st.get("pelvis", (0.0, 0.0))
    breath = 0.5 - 0.5 * math.cos(2.0 * math.pi * t)
    pel_z = leg.hip[1] - 0.04 * L + pz * L - 0.012 * L * breath
    rot = {}
    for side, stand in (("n", 0.20), ("f", -0.17)):  # planted a step apart so both legs show from the side; the pelvis sways over them
        dx, dz, dpitch = st.get("feet", {}).get(side, (0.0, 0.0, 0.0))
        ankle = legs[side].ankle(legs[side].hip[0] + (stand + dx) * L, dz * L, dpitch, dz == 0.0)
        rot.update(legs[side].solve(pel_z, ankle, dpitch, side))
    breathing = [1.3 * math.sin(2.0 * math.pi * k / n - 0.6) for k in range(n)]
    spine = 3.0 + _lagged(breathing, i)
    rot["spine"] = up(spine)
    rot["head"] = up(-0.8 * spine + 1.6 * math.sin(2.0 * math.pi * t + 1.3))
    _arms(rot, form, t, 3.0, lag=0.15)
    for bone, delta in st.get("bones", {}).items():
        _add(rot, bone, delta)
    return rot, (px * L + 0.008 * L * math.sin(2.0 * math.pi * t), 0.0, pel_z - leg.hip[1])


def attack_pose(form, legs, i, n):
    leg = legs["n"]
    L = leg.reach
    key = lambda name: anim.sample(ATTACK[name], float(i))
    pel_z = leg.hip[1] - 0.04 * L + key("pelvis_z") * L
    rot = {}
    lift = key("foot_n_z") * L
    pitch_n = key("foot_n_pitch")
    ankle_n = legs["n"].ankle(legs["n"].hip[0] + (0.03 + key("foot_n_x")) * L, lift, pitch_n, lift < 1e-6)
    rot.update(legs["n"].solve(pel_z, ankle_n, pitch_n, "n"))
    pitch_f = key("foot_f_pitch")
    rot.update(legs["f"].solve(pel_z, legs["f"].ankle(legs["f"].hip[0] - 0.03 * L, 0.0, pitch_f, True), pitch_f, "f"))
    rot["spine"], rot["head"] = up(key("spine")), up(key("head"))
    rot["arm_n"], rot["fore_n"] = down(key("arm_n")), down(key("fore_n"))
    rot["arm_f"], rot["fore_f"] = down(key("arm_f")), down(key("fore_f"))
    for bone, delta in _stance(form).get("bones", {}).items():
        _add(rot, bone, delta)
    return rot, (key("pelvis_x") * L, 0.0, pel_z - leg.hip[1])


def rider_pose(form, anim_name, i, n):
    """A rider's own bones: seated (the legs are not walked), the arms from the preset, the body riding the wolf's motion."""
    t = i / n
    rot = dict(RIDE)
    _arms(rot, form, t, 6.0, lag=0.2)
    rot["spine"] = up(2.0 + 1.5 * math.sin(4.0 * math.pi * t))
    return rot


def _hold_items(form, rot, anim_name, i, gain=0.25):
    """Keep whatever the goblin holds at the angle it was made at, whatever the arms do (it follows `gain` of the arm), or swinging in an
    attack: the item bone cancels the rotation of the bones above it."""
    for s in "nf":
        chain = ["hips", "spine", "arm_" + s, "fore_" + s]
        if form.get("ride"):
            chain = ["w_hips", "w_spine"] + chain
        above = sum(rot.get(b, (0.0, 0.0, 0.0))[1] for b in chain)
        arm = rot.get("arm_" + s, (0.0, 0.0, 0.0))[1] + rot.get("fore_" + s, (0.0, 0.0, 0.0))[1]
        if anim_name == "attack" and s == "n":
            want = anim.sample(ATTACK["item_n"], float(i))
            rot["item_n"] = (0.0, want - above, 0.0)
        else:
            rot["item_" + s] = (0.0, form.get("item_angle", {}).get(s, 0.0) + gain * arm - above, 0.0)


def _abs_deg(rot, chain):
    """The absolute angle (degrees, forward positive) a chain of bones adds up to."""
    return -sum(rot.get(b, (0.0, 0.0, 0.0))[1] for b in chain)


def _secondary(rig, frames, anim_name, riding):
    """Per frame, the angle each hung thing the form has (ears, cap tip, cloak, scarf, pack) makes with the bone it hangs from. Each chases the
    angle it would have if it were rigid, shaken by the body's bounce and blown back in a walk, on a spring (anim.follow), so it trails the
    body and the loop stays seamless."""
    n = len(frames)
    mean_z = sum(root[2] for _, root in frames) / n
    followed, out = {}, {}
    for bone, cfg in SECONDARY.items():
        if bone not in rig.rest:
            continue
        if "after" in cfg:
            parent = followed[cfg["after"]]
        else:
            chain = [b for b in cfg["parents"] if b in rig.rest]
            if riding:
                chain = ["w_hips", "w_spine"] + chain
            parent = [_abs_deg(rot, chain) for rot, _ in frames]
        driver = [pa + cfg["bob"] * (root[2] - mean_z) + WIND[anim_name] * cfg["wind"] for pa, (_, root) in zip(parent, frames)]
        chased = anim.follow(driver, stiffness=cfg["k"], damping=cfg["c"])
        followed[bone] = chased
        out[bone] = [c - pa for c, pa in zip(chased, parent)]
    return out


def make(form, anim_name, rig, stride=0.3):
    riding = bool(form.get("ride"))
    legs = None if riding else {"n": Leg(rig, "n"), "f": Leg(rig, "f")}
    pose = {"walk": lambda f, l, i, n: walk_pose(f, l, i, n, stride), "idle": idle_pose, "attack": attack_pose}[anim_name]
    count = COUNTS[anim_name]

    def base(i, n):
        if riding:
            wolf_fn = {"idle": wolf.idle, "walk": wolf.walk, "attack": wolf.pounce}[anim_name]
            if anim_name == "attack":  # the wolf's pounce has its own six poses: stretch them over this clip
                rot, root = wolf_fn(min(5, i * 6 // n), 6, "w_")
            else:
                rot, root = wolf_fn(i, n, "w_")
            rot = dict(rot)
            rot.update(rider_pose(form, anim_name, i, n))
            return rot, (root[0], root[1], root[2] * form["mount"]["scale"])
        return pose(form, legs, i, n)

    secondary = _secondary(rig, [base(k, count) for k in range(count)], anim_name, riding)

    def fn(i, n):
        rot, root = base(i, n)
        rot = dict(rot)
        for bone, series in secondary.items():
            rot[bone] = down(series[i])
        _hold_items(form, rot, anim_name, i)
        return rot, root
    return count, fn, riding


def motion(variant):
    """How fast this form crosses the ground in the game, in the sprite's own pixels per second: the enemy's speed (60 px/s times its spd
    stat over 100) divided by the size its sprite is drawn at. The walk is built so a planted foot moves back at exactly this speed."""
    speed, size = 60.0, 1.0
    if variant and variant != "goblin":
        path = os.path.join(HERE, "..", "..", "..", "data", "creatures", "twin_goblin_%s.tres" % variant)
        try:
            text = open(path).read()
            spd = re.search(r'"spd":\s*(\d+)', text)
            sz = re.search(r"^sprite_size = ([0-9.]+)", text, re.M)
            speed = 60.0 * (float(spd.group(1)) if spd else 100.0) / 100.0
            size = float(sz.group(1)) if sz else 1.0
        except OSError:
            pass
    return speed / size


def today(variant):
    """(width, height) in game pixels of the still the game had for this form before the 3D pass (tools/art/blender/before/), so a re-render
    sizes the same whatever the live sheet holds; the base goblin uses its idle frame."""
    if variant and variant != "goblin":
        path, name = os.path.join(HERE, "before", "forms_goblin.json"), variant
    else:
        path, name = os.path.join(HERE, "..", "..", "..", "assets", "sheets", "goblin.json"), "idle_1"
    try:
        with open(path) as fh:
            rect = json.load(fh)["frames"][name]["rect"]
        return float(rect[2]), float(rect[3])
    except (OSError, KeyError):  # nothing to match: fall back to the width in the table
        return float(_form(variant)["width"]), None


def setup(rig, variant):
    """Size the camera for this form and time its walk to its speed: the still covers the area of today's still, the walk's stride is what the
    form's speed demands (so planted feet do not skate), and the canvas holds every frame."""
    form = _form(variant)
    anims = {"idle": make(form, "idle", rig)}
    count, fn, grounded = anims["idle"]
    (rig.stand if grounded else rig.pose)(*fn(0, count))
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = math.sqrt(w * h / ((x1 - x0) * (z1 - z0))) if h else w / (x1 - x0)
    reach = None if form.get("ride") else Leg(rig, "n").reach
    speed = motion(variant)
    if reach:
        cycle = min(0.9, max(0.35, 0.9 * reach * ppu / (speed * DUTY)))  # seconds: a brisk step is about one leg long
        stride = speed * DUTY * cycle / ppu
    else:
        cycle, stride = 0.6, 0.3
    anims["walk"] = make(form, "walk", rig, stride)
    anims["attack"] = make(form, "attack", rig)
    fps = {"idle": 6.0, "walk": COUNTS["walk"] / cycle, "attack": 1.0 / 0.07}
    lo_x, hi_x, hi_z = 1e9, -1e9, 0.0
    for name, (count, fn, grounded) in anims.items():
        for i in range(count):
            (rig.stand if grounded else rig.pose)(*fn(i, count))
            a, b, _, top = rig.extent()
            lo_x, hi_x, hi_z = min(lo_x, a), max(hi_x, b), max(hi_z, top)
    need = max((hi_x - lo_x) * ppu + 2 * PAD, hi_z * ppu + MARGIN + PAD)
    canvas = int(math.ceil(need / 8.0) * 8)
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": (lo_x + hi_x) / 2.0, "anims": anims,
            "still": form.get("still", "idle_0"), "fps": fps, "holds": {"attack": HOLDS}}
