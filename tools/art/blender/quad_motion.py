"""How a four-legged canine moves: idle, walk (a four-beat lateral walk, or a trot when the game's speed is too quick for a walk), run (a gallop),
bite, hurt and die, as poses for the rig of quad_skeleton.py. Pure Python (no Blender), tested in test_quad_motion.py.

The trunk is posed first (hips, chest, neck, head, jaw, tail), then each leg is solved by IK to a foot that is placed in the world, so a planted
paw stays put while the body moves over it. A walk is four beats, each foot landing a quarter of a cycle after the last (hind near, fore near,
hind far, fore far) with two or three feet down at once; a trot lands diagonal pairs together; a gallop brings the hind pair down, then the fore
pair, then hangs in the air. Angles are degrees from straight down, forward positive (skeleton2d.py).
"""
import math

import anim
import secondary
from limbs import Leg, aim, down

REST = "rest"

# the gaits: how long a foot is down, when each lands in the cycle (the near feet are the ones the camera sees), how high a foot is lifted
# (of the leg's length), and how the trunk moves: `bob` the height of the hips, `pitch` the nodding of the trunk, `nod` of the head, `flex` of the back
# `stride_legs`: the stride a brisk step takes and `max_stride` the longest the legs can reach, both in leg heights (the shoulder's height above the ground); `cycle`
# the usual bounds on how long a cycle lasts, in seconds
GAITS = {
    "walk": dict(duty=0.72, phase=dict(hn=0.00, fn=0.25, hf=0.50, ff=0.75), lift=0.20, bob=0.020, pitch=1.5, nod=5.0, flex=2.0, stride_legs=0.8, max_stride=0.9, cycle=(0.55, 1.2)),
    "trot": dict(duty=0.52, phase=dict(hn=0.00, ff=0.00, hf=0.50, fn=0.50), lift=0.26, bob=0.045, pitch=2.5, nod=3.0, flex=2.0, stride_legs=1.0, max_stride=1.1, cycle=(0.3, 0.7)),
    "gallop": dict(duty=0.30, phase=dict(hn=0.00, hf=0.10, fn=0.52, ff=0.62), lift=0.40, bob=0.10, pitch=7.0, nod=8.0, flex=9.0, air=0.30, stride_legs=0.9, max_stride=1.0, cycle=(0.22, 0.5)),
}
IDLE_FRAMES, IDLE_SECONDS = 8, 1.6
GAIT_FRAMES = {"walk": 12, "trot": 10, "gallop": 10}
SLACK = 0.04      # the trunk stands this much (of the foreleg) lower than the rest pose, so the straight foreleg can reach as the paw swings

SECONDARY = {
    "ear_n": dict(parents=["hips", "spine", "neck", "head"], bob=500.0, wind=-5.0, freq=4.5, zeta=0.45),
    "ear_f": dict(parents=["hips", "spine", "neck", "head"], bob=500.0, wind=-5.0, freq=4.5, zeta=0.45),
    "tail1": dict(parents=["hips", "wag"], bob=700.0, wind=-6.0, freq=3.2, zeta=0.5),
    "tail2": dict(after="tail1", bob=700.0, wind=-9.0, freq=2.0, zeta=0.4),
    "tail3": dict(after="tail2", bob=700.0, wind=-12.0, freq=1.3, zeta=0.35),
}


class QuadBody:
    """What the motion needs to know about one canine: its flat skeleton, the measured paws (ankle_h, heel, toe) of each leg, its form."""
    def __init__(self, skel, feet, form, present=None):
        self.skel, self.form = skel, form
        self.present = set(present) if present is not None else set(skel.rest)
        self.legs = {}
        for key, upper, lower, foot, bend in (("fn", "sho_", "fore_", "paw_", -1), ("ff", "sho_", "fore_", "paw_", -1),
                                              ("hn", "thigh_", "shin_", "meta_", 1), ("hf", "thigh_", "shin_", "meta_", 1)):
            self.legs[key] = Leg(skel, key[1], *feet[key], thigh=upper, shin=lower, foot=foot, bend=bend)
        self.L = {"f": self.legs["fn"].reach, "h": self.legs["hn"].reach}
        self.H = self.legs["fn"].hip[1]   # how high the shoulder is above the ground at rest
        self.anchor = {k: leg.hip[0] for k, leg in self.legs.items()}      # where each leg hangs from, at rest
        self.rest_contact, self.rest_ankle = {}, {}
        rest = skel.pose()
        for key, leg in self.legs.items():
            self.rest_contact[key] = leg.contact(rest) - self.anchor[key]  # where the paw touches, from its leg's hip, at rest
            self.rest_ankle[key] = leg.ankle_of(rest)[0] - self.anchor[key]  # and where its ankle is

    def rest_dirs(self):
        rest = self.skel.pose()
        return {b: rest[b][2] for b in rest}


# ---- the trunk ------------------------------------------------------------------------------------------------------------------
def _trunk(body, rot, hips, spine, neck, head, jaw=0.0):
    """Aim the trunk in the world: the hips, chest, neck and head `directions` (0 down, 90 forward, 180 up), the jaw `jaw` degrees open."""
    sk = body.skel
    aim(sk, rot, "hips", hips)
    aim(sk, rot, "spine", spine)
    aim(sk, rot, "neck", neck)
    aim(sk, rot, "head", head)
    aim(sk, rot, "jaw", head - 12.0 + jaw)


def _legs(body, rot, root, targets):
    """Solve every leg to its world target {leg: (contact x, lift above the ground, pitch)}: the leg's joint is where the trunk has put it, and the
    trunk sinks as far as the legs need to reach (_sag). Returns the root it ended on."""
    planted = {}
    for key, (cx, lift, pitch) in targets.items():
        leg = body.legs[key]
        ax, az = anim.plant(cx, pitch, leg.heel, leg.toe, leg.ankle_h)
        planted[key] = (ax, az + lift, pitch)
    root = (root[0], root[1], root[2] - _sag(body, rot, root, planted))
    posed = body.skel.pose(rot, root)
    for key, (ax, az, pitch) in planted.items():
        leg = body.legs[key]
        rot.update(leg.solve(posed[leg.names[0]][0], (ax, az), pitch, rot))
    return root


def _stand_targets(body, shift=0.0):
    return {k: (body.anchor[k] + body.rest_contact[k] + shift, 0.0, 0.0) for k in body.legs}


def _dirs(body):
    return body.rest_dirs()


def _carriage(body):
    """(directions of the bones, root height) of the idle pose's first frame: how the animal carries itself standing, which an action starts from and
    returns to."""
    rot, root = idle_pose(body, 0.0)
    posed = body.skel.pose(rot, root)
    return {b: posed[b][2] for b in posed}, root[2]


# ---- idle -----------------------------------------------------------------------------------------------------------------------
def idle_pose(body, t):
    """Standing, breathing: the chest rises and falls, the head moves a little, the weight moves between the front and the back."""
    d = _dirs(body)
    s = math.sin(2.0 * math.pi * t)
    c = math.cos(2.0 * math.pi * t)
    rot = {"wag": down(6.0 * math.sin(2.0 * math.pi * t + 0.5))}
    _trunk(body, rot, d["hips"] + 0.5 * c, d["spine"] + 0.8 * s, d["neck"] - 1.2 * s - 3.0, d["head"] + 2.0 * math.sin(2.0 * math.pi * t - 0.9) - 4.0)
    root = (0.0, 0.0, -SLACK * body.L["f"] - 0.004 * (0.5 - 0.5 * c))
    root = _legs(body, rot, root, _stand_targets(body))
    return rot, root


# ---- gaits ----------------------------------------------------------------------------------------------------------------------
def gait_pose(body, gait, t, stride):
    """One pose of a walk, a trot or a gallop at cycle position t in [0, 1); `stride` is how far each planted paw travels while it is down."""
    g = GAITS[gait]
    d = _dirs(body)
    L = body.L["f"]
    turn = 2.0 * math.pi * t
    # the trunk: it rises and falls twice a cycle in a walk and a trot, nods and flexes; a gallop gathers and stretches once
    if gait == "gallop":
        extend = 0.5 + 0.5 * math.cos(turn - 0.5)           # 1 when the body is stretched out, 0 when it is gathered
        bob = g["bob"] * L * (extend - 0.5)
        pitch = g["pitch"] * math.cos(turn - 0.5)
        flex = g["flex"] * (extend - 0.5) * 2.0
    else:
        wave = math.cos(4.0 * math.pi * (t - 0.12))
        bob = g["bob"] * L * wave
        pitch = g["pitch"] * math.sin(4.0 * math.pi * (t - 0.12))
        flex = g["flex"] * math.sin(4.0 * math.pi * (t - 0.25))
    nod = g["nod"] * math.sin(turn - 0.6)
    rot = {"wag": down({"walk": 9.0, "trot": 8.0, "gallop": 12.0}[gait] * math.sin(turn + 0.8))}
    _trunk(body, rot, d["hips"] + pitch - flex * 0.5, d["spine"] + pitch + flex * 0.5, d["neck"] - 2.0 + 0.5 * nod, d["head"] - 4.0 + nod + 2.0 * math.sin(2.0 * turn))
    targets, air = gait_targets(body, gait, t, stride)
    root = (0.0, 0.0, -SLACK * L + bob + air)
    root = (0.0, 0.0, root[2] - _sag(body, rot, root, targets))
    posed = body.skel.pose(rot, root)
    for key, (ax, z, pitch_f) in targets.items():
        leg = body.legs[key]
        rot.update(leg.solve(posed[leg.names[0]][0], (ax, z), pitch_f, rot))
    return rot, root


def gait_targets(body, gait, t, stride):
    """({paw: (ankle x, ankle z, pitch)}, how far the body is lifted in the air) for a gait at cycle position t: where each ankle is to be, in the world."""
    g = GAITS[gait]
    L = body.L["f"]
    targets, support = {}, 0.0
    for key, leg in body.legs.items():
        u = (t - g["phase"][key]) % 1.0
        x, z, pitch_f, _ = anim.foot_pose(u, stride, g["duty"], g["lift"] * L, leg.heel, leg.toe, leg.ankle_h)
        # x is the ankle's from a hip that stays put, the middle of the flat part of the stance under it: put that where the paw stands at rest
        targets[key] = (body.anchor[key] + body.rest_ankle[key] + x, z, pitch_f)
        support += _load(u, g["duty"])
    air = g.get("air", 0.0) * body.H * anim.clamp(1.0 - support)        # a gallop leaves the ground: the body rises, the legs gather under it
    if air:
        targets = {k: (cx, z + air * 0.7 if z > 1e-9 else z, p) for k, (cx, z, p) in targets.items()}
    return targets, air


def _load(u, duty, ramp=0.04):
    """How much of the animal's weight a paw carries at cycle position u: nothing in the swing, eased in just after it lands and out just before it
    leaves, all of it between."""
    if u >= duty:
        return 0.0
    if u < ramp:
        return anim.smooth(u / ramp)
    if u > duty - ramp:
        return anim.smooth((duty - u) / ramp)
    return 1.0


def _sag(body, rot, root, targets, extension=0.985):
    """How far the trunk has to drop for every paw to reach its target: a leg reaching far ahead or behind is straightened and cannot also hold the
    trunk at its usual height, so the animal sinks as its legs spread (and rises as they come under it), the bob of a real gait."""
    posed = body.skel.pose(rot, root)
    sag = 0.0
    for key, (ax, z, _) in targets.items():
        leg = body.legs[key]
        joint = posed[leg.names[0]][0]
        reach = extension * leg.reach
        need = z + math.sqrt(max(0.0, reach * reach - (ax - joint[0]) ** 2))
        sag = max(sag, joint[1] - need)
    return sag


# ---- bite ----------------------------------------------------------------------------------------------------------------------
# The attack is a lunge: the animal sinks back on its haunches with its head low (the windup, held), springs forward off planted hind paws with its
# jaws opening and the forepaws reaching, snaps shut at the impact, and settles. Keys are over time in seconds, like the goblin's attack; every
# channel is an offset from the rest, in degrees for directions and fractions of the leg for lengths. The frames are the goblin's, so the clips split
# the same way (the windup is the first three).
ENGINE_WINDUP, ENGINE_RECOVER, ENGINE_HURT = 0.35, 0.30, 0.25   # scripts/enemies/enemy.gd: VERB_WINDUP, VERB_RECOVER, HURT_SECONDS (test_export_forms checks)
FRAMES = [(0.00, 0.06), (0.06, 0.06), (0.12, 0.15), (0.27, 0.04), (0.31, 0.04), (0.35, 0.08), (0.43, 0.05), (0.48, 0.05), (0.53, 0.06), (0.59, 0.06)]
WINDUP = 5   # the windup frames last the engine's windup, so the impact frame comes up as the verb fires; the rest last its recover
T_WIND, T_HOLD, T_MID, T_HIT, T_FOLLOW, T_END = 0.12, 0.27, 0.31, 0.35, 0.48, 0.59


def _swing(windup, mid, hit, follow):
    return [(0.0, 0.0, "out"), (T_WIND, windup, "smooth"), (T_HOLD, windup, "in"), (T_MID, mid, "linear"), (T_HIT, hit, "out"), (T_FOLLOW, follow, "smooth"), (T_END, 0.0, "smooth")]


BITES = {
    "root_x": _swing(-0.10, 0.28, 0.55, 0.42), "root_z": _swing(-0.14, -0.04, 0.0, -0.02),
    "hips": _swing(4.0, -3.0, -6.0, -4.0), "spine": _swing(-9.0, 2.0, 5.0, 3.0),
    "neck": _swing(-22.0, -8.0, -4.0, -6.0), "head": _swing(-4.0, 8.0, 12.0, 6.0), "jaw": _swing(0.0, 32.0, 4.0, 0.0),
    "fn_x": _swing(0.0, 0.10, 0.34, 0.20), "fn_lift": _swing(0.0, 0.10, 0.12, 0.06),
    "ff_x": _swing(0.0, 0.0, 0.18, 0.10), "ff_lift": _swing(0.0, 0.0, 0.04, 0.0),
}


def attack_frames(body):
    return FRAMES, WINDUP


def attack_pose(body, time):
    d, z0 = _carriage(body)
    L = body.L["f"]
    ch = {name: anim.sample(keys, time) for name, keys in BITES.items()}
    rot = {}
    _trunk(body, rot, d["hips"] + ch["hips"], d["spine"] + ch["spine"], d["neck"] + ch["neck"], d["head"] + ch["head"], ch["jaw"])
    root = (ch["root_x"] * L, 0.0, z0 + ch["root_z"] * L)
    targets = _stand_targets(body)
    for key in ("fn", "ff"):
        cx, _, pitch = targets[key]
        targets[key] = (cx + ch[key + "_x"] * L, ch[key + "_lift"] * L, pitch)
    root = _legs(body, rot, root, targets)
    return rot, root


# ---- hurt -----------------------------------------------------------------------------------------------------------------------
HURT_FRAMES = [(0.00, 0.04), (0.04, 0.06), (0.10, 0.06), (0.16, 0.05), (0.21, 0.04)]   # a quarter of a second, the engine's flinch; the last frame is the rest pose
HURT = {
    "root_x": [(0.0, 0.0, "out"), (0.04, -0.06, "out"), (0.10, -0.10, "smooth"), (0.16, -0.04, "smooth"), (0.21, 0.0, "smooth")],
    "root_z": [(0.0, 0.0, "out"), (0.04, -0.03, "out"), (0.10, -0.06, "smooth"), (0.16, -0.02, "smooth"), (0.21, 0.0, "smooth")],
    "hips": [(0.0, 0.0, "out"), (0.04, 6.0, "out"), (0.10, 8.0, "smooth"), (0.16, 3.0, "smooth"), (0.21, 0.0, "smooth")],
    "spine": [(0.0, 0.0, "out"), (0.04, 8.0, "out"), (0.10, 12.0, "smooth"), (0.16, 4.0, "smooth"), (0.21, 0.0, "smooth")],
    "neck": [(0.0, 0.0, "out"), (0.04, 20.0, "out"), (0.10, 30.0, "smooth"), (0.16, 10.0, "smooth"), (0.21, 0.0, "smooth")],
    "head": [(0.0, 0.0, "out"), (0.04, 14.0, "out"), (0.10, 22.0, "smooth"), (0.16, 8.0, "smooth"), (0.21, 0.0, "smooth")],
    "jaw": [(0.0, 0.0, "out"), (0.04, 22.0, "out"), (0.10, 26.0, "smooth"), (0.16, 8.0, "smooth"), (0.21, 0.0, "smooth")],
}


def hurt_frames():
    return HURT_FRAMES


def hurt_pose(body, time):
    d, z0 = _carriage(body)
    L = body.L["f"]
    ch = {name: anim.sample(keys, time) for name, keys in HURT.items()}
    rot = {}
    _trunk(body, rot, d["hips"] + ch["hips"], d["spine"] + ch["spine"], d["neck"] + ch["neck"], d["head"] + ch["head"], ch["jaw"])
    root = (ch["root_x"] * L, 0.0, z0 + ch["root_z"] * L)
    root = _legs(body, rot, root, _stand_targets(body))
    return rot, root


# ---- die ------------------------------------------------------------------------------------------------------------------------
# The legs go, the animal drops on its chest, rolls onto its side and lies stretched out, its head down and its legs straight. After the first
# frames nothing is planted, so each bone has its own keys (world directions) and the render sets the body on the ground afterwards.
DIE_FRAMES = [(0.00, 0.06), (0.06, 0.08), (0.14, 0.08), (0.22, 0.10), (0.32, 0.12), (0.44, 0.16), (0.60, 0.30), (0.90, 0.30)]
DIE_KEYS = {
    #            rest      yelp     buckle    drop      roll      flop      settle   lie
    "hips":    [REST, 104.0, 100.0, 96.0, 92.0, 90.0, 90.0, 90.0],
    "spine":   [REST, 100.0, 96.0, 92.0, 90.0, 90.0, 90.0, 90.0],
    "neck":    [REST, 150.0, 130.0, 108.0, 92.0, 84.0, 82.0, 82.0],
    "head":    [REST, 120.0, 100.0, 84.0, 76.0, 70.0, 70.0, 70.0],
    "jaw":     [REST, 26.0, 20.0, 12.0, 8.0, 6.0, 6.0, 6.0],
    "sho_n":   [REST, 20.0, 40.0, 60.0, 74.0, 84.0, 88.0, 88.0],
    "fore_n":  [REST, 10.0, 56.0, 76.0, 86.0, 92.0, 94.0, 94.0],
    "paw_n":   [REST, 30.0, 70.0, 84.0, 90.0, 92.0, 92.0, 92.0],
    "sho_f":   [REST, 24.0, 30.0, 40.0, 56.0, 70.0, 74.0, 74.0],
    "fore_f":  [REST, 14.0, 40.0, 60.0, 74.0, 82.0, 86.0, 86.0],
    "paw_f":   [REST, 34.0, 60.0, 76.0, 84.0, 88.0, 88.0, 88.0],
    "thigh_n": [REST, 36.0, 60.0, 40.0, 0.0, -44.0, -62.0, -64.0],
    "shin_n":  [REST, -40.0, -64.0, -76.0, -84.0, -88.0, -90.0, -90.0],
    "meta_n":  [REST, 34.0, 20.0, 0.0, -44.0, -78.0, -88.0, -90.0],
    "thigh_f": [REST, 38.0, 56.0, 30.0, -10.0, -34.0, -50.0, -52.0],
    "shin_f":  [REST, -38.0, -60.0, -72.0, -80.0, -84.0, -86.0, -86.0],
    "meta_f":  [REST, 32.0, 16.0, -6.0, -50.0, -70.0, -80.0, -84.0],
    "root_x":  [0.0, -0.05, -0.06, 0.0, 0.10, 0.18, 0.20, 0.20],
}


def die_frames():
    return DIE_FRAMES


def die_pose(body, time):
    rest = body.rest_dirs()
    times = [t for t, _ in DIE_FRAMES]
    ch = {}
    for name, values in DIE_KEYS.items():
        base = rest.get(name, 0.0)
        keys = [(times[i], (base if v == REST else v), "smooth") for i, v in enumerate(values)]
        ch[name] = anim.sample(keys, time)
    sk = body.skel
    rot = {}
    for bone in ("hips", "spine", "neck", "head"):
        aim(sk, rot, bone, ch[bone])
    aim(sk, rot, "jaw", ch["head"] - 12.0 + ch["jaw"])
    for side in "nf":
        for bone in ("sho_", "fore_", "paw_", "thigh_", "shin_", "meta_"):
            aim(sk, rot, bone + side, ch[bone + side])
    return rot, (ch["root_x"] * body.L["f"], 0.0, 0.0)


# ---- clips ----------------------------------------------------------------------------------------------------------------------
class Clip:
    def __init__(self, frames, durations, loop, grounded=False):
        self.frames, self.durations, self.loop, self.grounded = frames, durations, loop, grounded


def _with_secondary(body, frames, durations, wind, periodic):
    """Add the hung things' follow-through. A frame may carry a made-up bone "wag": degrees the tail is deliberately swung, which the tail chain
    rides like the hips' own turn; it is not a bone of the rig and is dropped here."""
    present = body.present | {"wag"}
    out = secondary.series(present, SECONDARY, frames, wind, durations, periodic=periodic)
    for i, (rot, root) in enumerate(frames):
        rot.pop("wag", None)
        for bone, series in out.items():
            if bone != "wag":
                rot[bone] = down(series[i])
        _lift_tail(body, rot, root)
    return frames


def _lift_tail(body, rot, root, clearance=0.02):
    """Raise a tail that has swung down through the floor (when the body drops or pitches): a tail is not allowed below the paws, since the sprite sits
    on its lowest point."""
    if "tail1" not in body.skel.rest:
        return
    for _ in range(60):
        posed = body.skel.pose(rot, root)
        if min(min(posed[b][0][1], posed[b][1][1]) for b in ("tail1", "tail2", "tail3")) >= clearance:
            return
        for b in ("tail1", "tail2", "tail3"):
            rot[b] = (0.0, rot[b][1] + 2.0, 0.0)


def idle_clip(body):
    n = IDLE_FRAMES
    dur = [IDLE_SECONDS / n] * n
    return Clip(_with_secondary(body, [idle_pose(body, i / n) for i in range(n)], dur, 0.1, True), dur, True)


def plan_gait(body, gait, speed, ppu):
    """(cycle seconds, stride in units) for a gait covering the ground at `speed` game pixels per second with a sprite drawn at `ppu` pixels to the unit:
    the stride is fixed by the cycle (the ground slides back under a paw at `speed` while it is down), so the cycle is chosen for a brisk step of the usual
    length, kept within the usual bounds, and shortened if the stride it gives is longer than the legs can reach."""
    g = GAITS[gait]
    reach_px = body.H * ppu
    target = g["stride_legs"] * reach_px / (speed * g["duty"])
    cycle = min(g["cycle"][1], max(g["cycle"][0], target))
    stride_px = speed * g["duty"] * cycle
    longest = g["max_stride"] * reach_px
    if stride_px > longest:
        stride_px = longest
        cycle = stride_px / (speed * g["duty"])
    return cycle, stride_px / ppu


def walking_gait(body, speed, ppu):
    """The gait a creature uses for its everyday movement at this speed: a walk when a brisk walking step would take at least a walk's shortest cycle,
    else a trot (a quick walk is a trot)."""
    g = GAITS["walk"]
    natural = g["stride_legs"] * body.H * ppu / (speed * g["duty"])
    return "walk" if natural >= g["cycle"][0] else "trot"


def gait_clip(body, gait, cycle, stride):
    n = GAIT_FRAMES[gait]
    dur = [cycle / n] * n
    frames = [gait_pose(body, gait, i / n, stride) for i in range(n)]
    return Clip(_with_secondary(body, frames, dur, {"walk": 0.8, "trot": 1.0, "gallop": 1.6}[gait], True), dur, True)


def attack_clip(body):
    dur = [d for _, d in FRAMES]
    return Clip(_with_secondary(body, [attack_pose(body, t) for t, _ in FRAMES], dur, 0.5, False), dur, False)


def hurt_clip(body):
    dur = [d for _, d in HURT_FRAMES]
    return Clip(_with_secondary(body, [hurt_pose(body, t) for t, _ in HURT_FRAMES], dur, 0.5, False), dur, False)


def die_clip(body):
    dur = [d for _, d in DIE_FRAMES]
    return Clip(_with_secondary(body, [die_pose(body, t) for t, _ in DIE_FRAMES], dur, 0.3, False), dur, False, grounded=True)
