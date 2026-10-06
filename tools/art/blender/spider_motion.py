"""How a spider moves: idle, walk, run, attack, hurt and die, as poses for the rig of spider_skeleton.py. Pure Python (no Blender), tested in
test_spider_motion.py.

The body (the cephalothorax, which carries everything) is placed first, then every leg is solved by IK (limbs.Leg: femur and tibia) to where its claw is
to be in the world, with the tarsus held at a set world angle, so a planted claw stays put while the body moves over it. A spider's foot is a point (the
tarsal claw), so a planted tarsus keeps its angle and only curls while it swings.

The walk is the alternating tetrapod (docs/research/rig-weight-research.md): the near legs of pairs 0 and 2 and the far legs of pairs 1 and 3 step
together, then the other four, each group a little staggered from the back to the front (a metachronal wave); a leg lifts only while it swings forward,
four feet are always down and the body dips a little after each footfall. A form that holds a pair of legs up (the nightstalker's scythes, the
veil-spinner's veil) walks on six in three pairs a third of a cycle apart, so four are still always down. The run is the same tetrapod (or a tripod on
six legs), quicker, with less time on the ground.

Angles are degrees from straight down, forward positive (skeleton2d.py). Lengths in the keys are fractions of `U`, the height the body rides at.
"""
import math

import anim
import secondary
import spider_skeleton as ss
from limbs import Leg, aim, down

REST = "rest"
CURL = 0.55        # how far a swinging tarsus curls toward straight down (of its angle)

# the gaits: how long a foot is down, how high it lifts (of U), how far the body dips after a footfall (of U), how much it pitches (degrees), the
# stride a brisk step takes (of the longest the legs reach) and the bounds on a cycle (seconds)
GAITS = {
    "walk": dict(duty=0.64, duty6=0.72, lift=0.30, bob=0.035, pitch=1.2, sway=2.0, stride_frac=0.70, stride_u=1.0, cycle=(0.40, 1.3)),
    "run": dict(duty=0.50, duty6=0.55, lift=0.42, bob=0.06, pitch=2.2, sway=3.0, stride_frac=0.92, stride_u=1.5, cycle=(0.20, 0.60)),
}
STAGGER = 0.03     # each pair lands this much of a cycle after the pair behind it
IDLE_FRAMES, IDLE_SECONDS = 8, 1.6
GAIT_FRAMES = {"walk": 12, "run": 10}

SECONDARY = {
    "hair1": dict(parents=["body", "waist", "chest", "head"], bob=260.0, wind=-10.0, freq=3.0, zeta=0.45),
    "hair2": dict(after="hair1", bob=320.0, wind=-12.0, freq=2.4, zeta=0.4),
    "cloth1": dict(parents=["body", "waist"], bob=200.0, wind=-8.0, freq=2.6, zeta=0.45),
    "cloth2": dict(after="cloth1", bob=260.0, wind=-12.0, freq=2.1, zeta=0.4),
}
ABDOMEN = dict(parents=["body", "abd"], bob=-420.0, wind=1.5, freq=4.5, zeta=0.30)   # a heavy abdomen lags the body's dips
ENGINE_WINDUP, ENGINE_RECOVER, ENGINE_HURT = 0.35, 0.30, 0.25   # scripts/enemies/enemy.gd: VERB_WINDUP, VERB_RECOVER, HURT_SECONDS


def pair_of(key):
    return int(key[1])


class SpiderBody:
    """What the motion needs to know about one spider: its flat skeleton, how far below each claw's bone end its mesh reaches (`pads`), its form and
    the bones its rig really has."""
    def __init__(self, skel, pads, form, present=None):
        self.skel, self.form = skel, form
        self.present = set(present) if present is not None else set(skel.rest)
        self.legs, self.pad, self.tl, self.rest_tar, self.rest_tip = {}, {}, {}, {}, {}
        for key in ss.LEGS:
            self.legs[key] = Leg(skel, key, 0.0, 0.0, 0.0, thigh="fem_", shin="tib_", foot="tar_", bend=ss.BEND[pair_of(key)])
            self.pad[key] = pads[key]
            self.tl[key] = skel.length("tar_" + key)
            self.rest_tar[key] = skel.rest_direction("tar_" + key)
            self.rest_tip[key] = skel.rest["tar_" + key][1]
        self.raised = sorted(set(form.get("raised", ())))                 # pairs held up all the time
        self.walking = [k for k in ss.LEGS if pair_of(k) not in self.raised]
        self.U = skel.rest["body"][0][1]                                   # the height the body rides at
        self.z0 = sum(self.pad[k] - self.rest_tip[k][1] for k in ss.LEGS) / len(ss.LEGS)   # the root's height standing
        self.drider = "waist" in skel.rest
        self.swarm = sorted(b for b in skel.rest if b.startswith("swarm"))
        self.hull = form.get("_hull") or []
        self._max = {}

    def rest_dir(self, bone):
        return self.skel.rest_direction(bone)

    # ---- the stride the legs can take --------------------------------------------------------------------------------------------
    def max_stride(self, gait):
        """The longest stride (units) every walking leg can take in this gait without a claw falling short or the knee folding shut: found by trying
        strides on the gait's own poses."""
        if gait not in self._max:
            lo, hi = 0.0, 1.5 * self.U * 4.0
            for _ in range(22):
                mid = 0.5 * (lo + hi)
                if _gait_reaches(self, gait, mid):
                    lo = mid
                else:
                    hi = mid
            self._max[gait] = lo
        return self._max[gait]


# ---- placing the legs -------------------------------------------------------------------------------------------------------------
def ankle_for(body, key, tip, curl=0.0):
    """Where the ankle goes for a claw at `tip` (x, z) with its tarsus turned `curl` degrees from its rest angle."""
    d = math.radians(body.rest_tar[key] + curl)
    return (tip[0] - body.tl[key] * math.sin(d), tip[1] + body.tl[key] * math.cos(d))


def solve_legs(body, rot, root, tips):
    """Solve every leg in `tips` {leg: (claw x, claw z, tarsus curl)} by IK, the body already posed in `rot`. Returns {leg: ankle target}."""
    posed = body.skel.pose(rot, root)
    targets = {}
    for key, (x, z, curl) in tips.items():
        leg = body.legs[key]
        ankle = ankle_for(body, key, (x, z), curl)
        targets[key] = ankle
        rot.update(leg.solve(posed[leg.names[0]][0], ankle, curl, rot))
    lift_clear(body, rot, root)
    return targets


def planted(body, key, dx=0.0):
    """A claw standing on the ground where it stands at rest (moved `dx`)."""
    return (body.rest_tip[key][0] + dx, body.pad[key], 0.0)


def raised_tip(body, key, t=0.0, lift=1.0):
    """Where a raised leg's claw is held: up and forward of the body, a pair that is never put down (scythes, a veil) high, swaying a little."""
    i = pair_of(key)
    leg = body.legs[key]
    far = 1.0 if key[0] == "f" else 0.0
    # (direction from the hip, degrees from straight down; reach, of the leg's; the tarsus's world direction) for each way of holding a pair up
    angle, reach, tarsus = RAISED.get(body.form.get("raised_pose", "ready"), RAISED["ready"]) if i == 0 else (100.0, 0.7, 60.0)
    angle -= 9.0 * far                                   # the far one a little lower and behind, so the two do not sit on one line
    a = math.radians(angle + 3.0 * math.sin(2.0 * math.pi * t + 0.8 * far))
    d = reach * leg.reach * (0.6 + 0.4 * lift)
    hip = leg.hip
    x = hip[0] + d * math.sin(a)
    z = hip[1] + body.z0 - d * math.cos(a)
    curl = (tarsus + 4.0 * math.sin(2.0 * math.pi * t + 1.3)) * lift + body.rest_tar[key] * (1.0 - lift) - body.rest_tar[key]
    return (x, z, curl)


RAISED = {
    "ready": (112.0, 0.80, 70.0),      # forelegs up and out in front, ready to pounce
    "scythe": (150.0, 0.78, 10.0),     # scythes held high, their blades hanging down in front
    "veil": (140.0, 0.84, 150.0),      # held up high to carry a veil
    "hold": (98.0, 0.62, -20.0),       # held in close, clutching something
}


# ---- the body ---------------------------------------------------------------------------------------------------------------------
def _trunk(body, rot, pitch=0.0, abd=0.0, fang=0.0, palp=0.0, t=0.0):
    """Pitch the cephalothorax `pitch` degrees nose up (about the pedicel), carry the abdomen `abd` degrees higher than its rest, open the fangs `fang`
    degrees and work the palps."""
    sk = body.skel
    aim(sk, rot, "body", body.rest_dir("body") + pitch)
    rot["abd"] = down(-abd)                         # the abdomen's own deliberate turn, ridden by its spring (dropped in the clip)
    aim(sk, rot, "abdomen", body.rest_dir("abdomen") + pitch - abd)
    aim(sk, rot, "fang", body.rest_dir("fang") + pitch + fang)
    for s, ph in (("n", 0.0), ("f", 1.7)):
        aim(sk, rot, "palp_" + s, body.rest_dir("palp_" + s) + pitch + palp + 6.0 * math.sin(2.0 * math.pi * t + ph))


# the drider's arms: how a form holds them at rest, as world directions (upper arm, forearm) for the near and the far arm, and the item's tilt
ARMS = {
    "silk": dict(arm_n=18.0, fore_n=70.0, arm_f=12.0, fore_f=58.0),         # silk drawn out between the hands, in front
    "fan": dict(arm_n=24.0, fore_n=150.0, arm_f=10.0, fore_f=40.0),          # a fan held up by the face
    "shuttle": dict(arm_n=22.0, fore_n=66.0, arm_f=8.0, fore_f=40.0),
    "thread": dict(arm_n=46.0, fore_n=118.0, arm_f=16.0, fore_f=70.0),       # a thread held taut, one hand high, one low
    "fists": dict(arm_n=26.0, fore_n=62.0, arm_f=18.0, fore_f=50.0),
    "story": dict(arm_n=40.0, fore_n=110.0, arm_f=8.0, fore_f=26.0),         # one hand out holding a glowing thread
}


def _upper(body, rot, lean, head, arms, t=0.0, swing=0.0):
    """The drider's upper body: the waist and chest leaned `lean` degrees forward of upright, the head `head`, the arms at world directions (`arms`:
    arm_n, fore_n, arm_f, fore_f, item_n, item_f), swinging `swing` degrees."""
    if not body.drider:
        return
    sk = body.skel
    aim(sk, rot, "waist", 180.0 - lean * 0.6)
    aim(sk, rot, "chest", 180.0 - lean)
    aim(sk, rot, "head", 180.0 - head)
    c = math.sin(2.0 * math.pi * t)
    for s, sign in (("n", 1.0), ("f", -1.0)):
        aim(sk, rot, "arm_" + s, arms["arm_" + s] + sign * swing * c)
        aim(sk, rot, "fore_" + s, arms["fore_" + s] + sign * swing * 1.2 * c)
        aim(sk, rot, "item_" + s, arms.get("item_" + s, 180.0))


def _rest_arms(body):
    return dict(ARMS[body.form.get("arms", "silk")], item_n=body.form.get("item_n", 180.0), item_f=body.form.get("item_f", 180.0))


def _jitter(body, rot, t, amount=1.0, periodic=True):
    """The swarm's spiderlings scuttle: each bone they ride twitches on its own rhythm (whole numbers of beats a loop, so a loop closes)."""
    for j, bone in enumerate(body.swarm):
        a = 0.0
        for n, (k, ph) in enumerate(((5, 0.7 * j), (9, 1.9 * j + 0.4), (13, 2.3 * j + 1.1))):
            a += (9.0 / (n + 1)) * math.sin(2.0 * math.pi * k * t + ph)
        rot[bone] = down(amount * a)


# ---- idle -------------------------------------------------------------------------------------------------------------------------
def idle_pose(body, t):
    """Standing still on its eight (or six) feet: the abdomen swells and settles with its breath, the palps work, one foreleg lifts to taste the air and
    is set down where it was. A dancing form (`idle: "dance"`) rears on its hind legs and waves its front four; a form `ready` to pounce holds its
    forelegs up."""
    style = body.form.get("idle", "still")
    s = math.sin(2.0 * math.pi * t)
    U = body.U
    rot = {}
    if style == "dance":
        return _dance(body, t)
    pitch = 0.8 * s + body.form.get("pitch", 0.0)
    _trunk(body, rot, pitch, abd=2.0 * math.sin(2.0 * math.pi * t - 0.8), fang=2.0 + 2.0 * s, palp=4.0 * math.sin(4.0 * math.pi * t), t=t)
    _upper(body, rot, body.form.get("lean", 6.0) + 1.5 * s, body.form.get("head_lean", 4.0) + 2.0 * math.sin(2.0 * math.pi * t + 0.9), _rest_arms(body), t, 1.5)
    root = (0.0, 0.0, body.z0 + 0.012 * U * s)
    tips = {}
    for key in ss.LEGS:
        i = pair_of(key)
        if i in body.raised or (style == "ready" and i == 0):
            tips[key] = raised_tip(body, key, t)
        else:
            tips[key] = planted(body, key)
    if style != "ready" and 0 not in body.raised:
        # the near foreleg taps: up and down again on the same spot in the second half of the loop
        w = math.sin(math.pi * anim.clamp((t - 0.45) / 0.35)) ** 2
        x, z, c = tips["n0"]
        tips["n0"] = (x - 0.05 * U * w, z + 0.28 * U * w, 25.0 * w)
    solve_legs(body, rot, root, tips)
    _jitter(body, rot, t)
    return rot, root


def _dance(body, t):
    """The tarantella: up on the four hind legs with the body tipped up, the front four flung up and wide and waving, bouncing on the beat (twice a
    loop) and swaying."""
    U = body.U
    beat = 0.5 - 0.5 * math.cos(4.0 * math.pi * t)            # 0 down on the beat, 1 up between
    sway = math.sin(2.0 * math.pi * t)
    rot = {}
    _trunk(body, rot, 28.0 + 5.0 * sway, abd=-14.0 - 4.0 * beat, fang=10.0 + 8.0 * beat, palp=14.0 * sway, t=t)
    root = (0.0, 0.0, body.z0 + (0.10 + 0.08 * beat) * U)
    tips = {}
    for key in ss.LEGS:
        i = pair_of(key)
        far = key[0] == "f"
        if i >= 2:
            tips[key] = planted(body, key, (0.04 if i == 2 else 0.0) * U)
            continue
        ph = 2.0 * math.pi * t + (0.0 if i == 0 else 1.6) + (math.pi if far else 0.0)
        x0 = body.rest_tip[key][0]
        tips[key] = (x0 - (0.30 if i == 0 else 0.55) * U + 0.18 * U * math.sin(ph), (1.75 if i == 0 else 1.15) * U + 0.25 * U * math.cos(ph), 90.0 + 20.0 * math.sin(ph))
    solve_legs(body, rot, root, tips)
    _jitter(body, rot, t)
    return rot, root


# ---- gaits ------------------------------------------------------------------------------------------------------------------------
def phases(body, gait):
    """{leg: when in the cycle it lands} for the legs that walk."""
    out = {}
    if not body.raised:
        for key in ss.LEGS:
            i = pair_of(key)
            group = 0.0 if (key[0] == "n") == (i % 2 == 0) else 0.5
            out[key] = (group + STAGGER * (3 - i)) % 1.0
        return out
    if gait == "walk":
        # three pairs of legs a third of a cycle apart: one pair swings at a time
        order = {("n", 3): 0.0, ("f", 2): 0.0, ("n", 2): 1.0 / 3.0, ("f", 1): 1.0 / 3.0, ("n", 1): 2.0 / 3.0, ("f", 3): 2.0 / 3.0}
    else:
        order = {("n", 1): 0.0, ("f", 2): 0.0, ("n", 3): 0.0, ("f", 1): 0.5, ("n", 2): 0.5, ("f", 3): 0.5}
    for key in body.walking:
        out[key] = order[(key[0], pair_of(key))]
    return out


def duty_of(body, gait):
    g = GAITS[gait]
    return g["duty6"] if body.raised else g["duty"]


def tip_path(u, stride, duty, lift):
    """A claw over a cycle, u in [0, 1): (x from where it stands at rest, height, how far the tarsus is curled (0 to 1), whether it is down). Down, it
    moves back with the ground at one speed; it leaves and lands with the ground's speed (a cubic joins them) and rises `lift` on the way."""
    u %= 1.0
    if u < duty:
        return stride * (0.5 - u / duty), 0.0, 0.0, True
    s = (u - duty) / (1.0 - duty)
    m = -stride / duty * (1.0 - duty)                     # the ground's speed, per unit of the swing
    x = anim._hermite(-0.5 * stride, 0.5 * stride, m, m, s)
    w = math.sin(math.pi * s) ** 2
    return x, lift * w, w, False


def gait_tips(body, gait, t, stride):
    """{leg: (claw x, claw z, tarsus curl)} for a gait at cycle position t."""
    g = GAITS[gait]
    duty = duty_of(body, gait)
    out = {}
    for key, ph in phases(body, gait).items():
        x, z, w, _ = tip_path(t - ph, stride, duty, g["lift"] * body.U)
        rest = body.rest_tar[key]
        out[key] = (body.rest_tip[key][0] + x, body.pad[key] + z, -CURL * rest * w)
    for key in ss.LEGS:
        if key not in out:
            out[key] = raised_tip(body, key, t)
    return out


def _dip(body, gait, t):
    """The body's height over a cycle: it sinks just after each group of feet lands and rises as they take the weight."""
    g = GAITS[gait]
    beats = 3.0 if body.raised and gait == "walk" else 2.0
    return -g["bob"] * body.U * (0.5 + 0.5 * math.cos(2.0 * math.pi * beats * (t - 0.10)))


def gait_pose(body, gait, t, stride):
    g = GAITS[gait]
    beats = 3.0 if body.raised and gait == "walk" else 2.0
    turn = 2.0 * math.pi * t
    rot = {}
    pitch = body.form.get("pitch", 0.0) + g["pitch"] * math.sin(2.0 * math.pi * beats * (t - 0.18)) - (2.0 if gait == "run" else 0.0)
    _trunk(body, rot, pitch, abd=1.5 * math.sin(2.0 * math.pi * beats * (t - 0.3)), fang=1.0, palp=6.0 * math.sin(turn), t=t)
    lean = body.form.get("lean", 6.0) + (6.0 if gait == "run" else 2.0)
    _upper(body, rot, lean + 1.5 * math.sin(2.0 * math.pi * beats * (t - 0.2)), body.form.get("head_lean", 4.0), _rest_arms(body), t, g["sway"])
    root = (0.0, 0.0, body.z0 + _dip(body, gait, t) - (0.03 * body.U if gait == "run" else 0.0))
    solve_legs(body, rot, root, gait_tips(body, gait, t, stride))
    _jitter(body, rot, t, 1.4 if gait == "run" else 1.0)
    return rot, root


def gait_targets(body, gait, t, stride):
    """{leg: ankle (x, z)} the gait wants at cycle position t: what the IK has to reach."""
    return {k: ankle_for(body, k, (x, z), c) for k, (x, z, c) in gait_tips(body, gait, t, stride).items()}


def reach_error(body, rot, root, targets):
    posed = body.skel.pose(rot, root)
    return max(math.hypot(posed["tib_" + k][1][0] - a[0], posed["tib_" + k][1][1] - a[1]) for k, a in targets.items())


def _gait_reaches(body, gait, stride, samples=48, margin=0.96):
    """Whether every walking leg reaches its claw through a whole cycle of this stride, straight by no more than `margin` and folded by no more than
    its knee allows."""
    for n in range(samples):
        t = n / samples
        rot, root = gait_pose(body, gait, t, stride)
        posed = body.skel.pose(rot, root)
        targets = gait_targets(body, gait, t, stride)
        for key in body.walking:
            leg = body.legs[key]
            hip = posed[leg.names[0]][0]
            d = math.hypot(targets[key][0] - hip[0], targets[key][1] - hip[1])
            if d > margin * leg.reach or d < abs(leg.l1 - leg.l2) + 0.08 * min(leg.l1, leg.l2):
                return False
            # a leg reaching forward keeps its ankle ahead of its hip and one reaching back behind it, or the knee would flip over
            if leg.bend * (targets[key][0] - hip[0]) < 0.05 * leg.l1:
                return False
    return True


def plan_gait(body, gait, speed, ppu):
    """(cycle seconds, stride in units) for a gait covering the ground at `speed` game pixels per second with a sprite drawn at `ppu` pixels to the
    unit. A claw is down for `duty` of the cycle and the ground slides back under it at `speed`, so the stride is fixed by the cycle: the cycle is chosen
    for a brisk step of the usual length, kept within the usual bounds, then shortened if the stride it gives is longer than the legs reach."""
    g = GAITS[gait]
    duty = duty_of(body, gait)
    longest = body.max_stride(gait) * ppu
    target = min(g["stride_frac"] * longest, g["stride_u"] * body.U * ppu) / (speed * duty)
    cycle = min(g["cycle"][1], max(g["cycle"][0], target))
    stride_px = speed * duty * cycle
    if stride_px > longest:
        stride_px = longest
        cycle = stride_px / (speed * duty)
    return cycle, stride_px / ppu


# ---- attack -----------------------------------------------------------------------------------------------------------------------
# Every attack has the same frames as the wolf's and the goblin's, so the clips split the same way: the windup is the first five frames, which last
# the engine's windup (the impact frame comes up as the verb fires), the rest last its recover. Keys are over time; body channels are offsets from the
# carriage (the idle's first frame): root_x and root_z in U, pitch (nose up), abd (abdomen up), fang (open) in degrees; `f0x`, `f0z`, `f0c` move the
# front pair's claws (x and z in U, tarsus curl in degrees) and `f1x`, `f1z` the second pair's, from where the carriage has them. The drider's channels
# are world directions of its arms and how far it leans.
FRAMES = [(0.00, 0.06), (0.06, 0.06), (0.12, 0.15), (0.27, 0.04), (0.31, 0.04), (0.35, 0.08), (0.43, 0.05), (0.48, 0.05), (0.53, 0.06), (0.59, 0.06)]
WINDUP = 5
T_WIND, T_HOLD, T_MID, T_HIT, T_FOLLOW, T_END = 0.12, 0.27, 0.31, 0.35, 0.48, 0.59


def _swing(windup, mid, hit, follow, rest=0.0):
    return [(0.0, rest, "out"), (T_WIND, windup, "smooth"), (T_HOLD, windup, "in"), (T_MID, mid, "linear"), (T_HIT, hit, "out"), (T_FOLLOW, follow, "smooth"), (T_END, rest, "smooth")]


def _rest_swing(windup, mid, hit, follow):
    return _swing(windup, mid, hit, follow, REST)


BITE = {   # rear back with the forelegs up and the fangs wide, then lunge and drive the fangs down
    "root_x": _swing(-0.22, 0.25, 0.55, 0.40), "root_z": _swing(0.10, 0.05, -0.12, -0.06),
    "pitch": _swing(16.0, 4.0, -12.0, -6.0), "abd": _swing(-6.0, 4.0, 10.0, 5.0), "fang": _swing(34.0, 40.0, -2.0, 4.0),
    "f0x": _swing(-0.35, 0.40, 0.95, 0.70), "f0z": _swing(1.05, 0.80, 0.10, 0.0), "f0c": _swing(70.0, 50.0, 10.0, 0.0),
    "f1x": _swing(-0.10, 0.10, 0.30, 0.20), "f1z": _swing(0.35, 0.30, 0.0, 0.0),
}
POUNCE = {  # sink low and far back on the hind legs with the forelegs high, then spring the length of the body and slam them down
    "root_x": _swing(-0.40, 0.45, 1.05, 0.85), "root_z": _swing(-0.22, 0.25, -0.05, -0.10),
    "pitch": _swing(14.0, 8.0, -14.0, -8.0), "abd": _swing(-4.0, 8.0, 12.0, 6.0), "fang": _swing(26.0, 36.0, 0.0, 4.0),
    "f0x": _swing(-0.20, 1.00, 1.60, 1.30), "f0z": _swing(2.70, 1.90, 0.05, 0.0), "f0c": _swing(80.0, 60.0, 5.0, 0.0),
    "f1x": _swing(-0.15, 0.50, 0.75, 0.60), "f1z": _swing(0.20, 0.55, 0.0, 0.0),
}
SLASH = {   # the scythes go up and back over the body, then hew down in front
    "root_x": _swing(-0.25, 0.20, 0.45, 0.35), "root_z": _swing(-0.08, 0.04, -0.10, -0.06),
    "pitch": _swing(12.0, 6.0, -10.0, -5.0), "abd": _swing(-6.0, 2.0, 8.0, 4.0), "fang": _swing(20.0, 26.0, 8.0, 4.0),
    "f0x": _swing(-2.80, -0.60, 1.40, 1.10), "f0z": _swing(3.10, 3.00, 0.15, 0.30), "f0c": _swing(140.0, 90.0, 10.0, 20.0),
    "f1x": _swing(0.0, 0.0, 0.15, 0.10), "f1z": _swing(0.0, 0.0, 0.0, 0.0),
}
SPIT = {    # rear right up with the abdomen tucked under and the fangs wide, then snap the head down and forward: the venom flies
    "root_x": _swing(-0.15, 0.05, 0.22, 0.15), "root_z": _swing(0.18, 0.12, -0.06, -0.03),
    "pitch": _swing(26.0, 14.0, -10.0, -4.0), "abd": _swing(-16.0, -8.0, 10.0, 4.0), "fang": _swing(30.0, 44.0, 44.0, 16.0),
    "f0x": _swing(-0.25, 0.0, 0.35, 0.20), "f0z": _swing(0.95, 0.60, 0.15, 0.0), "f0c": _swing(60.0, 40.0, 10.0, 0.0),
    "f1x": _swing(-0.10, 0.0, 0.10, 0.05), "f1z": _swing(0.20, 0.15, 0.0, 0.0),
}
LOWER = {   # a drider's spider half under a gesture: it gathers back, then leans its whole weight into the blow
    "root_x": _swing(-0.18, 0.10, 0.30, 0.22), "root_z": _swing(-0.05, 0.0, -0.06, -0.04),
    "pitch": _swing(8.0, 2.0, -6.0, -3.0), "abd": _swing(-4.0, 2.0, 6.0, 3.0), "fang": _swing(0.0, 0.0, 0.0, 0.0),
    "f0x": _swing(-0.20, 0.20, 0.50, 0.35), "f0z": _swing(0.55, 0.40, 0.0, 0.0), "f0c": _swing(30.0, 20.0, 0.0, 0.0),
    "f1x": _swing(0.0, 0.0, 0.12, 0.08), "f1z": _swing(0.0, 0.0, 0.0, 0.0),
}
# the drider's gestures: (windup, mid, impact, follow) world directions of each arm bone and the item, and the lean and head (degrees forward)
GESTURES = {
    # a spell or a cast of silk: both hands drawn up and back, then flung forward
    "cast": dict(lean=(-12, 6, 20, 16), head=(-8, 6, 14, 12), arm_n=(150, 110, 82, 72), fore_n=(175, 120, 88, 78), arm_f=(132, 96, 84, 74), fore_f=(160, 110, 92, 82)),
    # a bow: the far hand pushes the bow out, the near hand draws the string to the cheek and lets it go
    "bow": dict(lean=(-6, -4, 8, 8), head=(-2, 0, 6, 6), arm_n=(-70, -80, -60, -20), fore_n=(70, 80, -30, 10), arm_f=(88, 90, 90, 80), fore_f=(90, 90, 92, 84),
                item_f=(180, 180, 180, 180)),
    # a fan whipped across: up behind the head, then down in front
    "fan": dict(lean=(-10, 4, 18, 14), head=(-6, 4, 12, 10), arm_n=(165, 120, 64, 46), fore_n=(205, 150, 76, 54), arm_f=(30, 20, 0, 6), fore_f=(70, 50, 20, 30),
                item_n=(220, 180, 120, 110)),
    # an overarm throw of the shuttle
    "throw": dict(lean=(-14, 2, 22, 18), head=(-6, 4, 14, 12), arm_n=(195, 160, 84, 58), fore_n=(235, 170, 80, 56), arm_f=(80, 50, 10, 10), fore_f=(110, 80, 40, 40),
                  item_n=(240, 200, 120, 100)),
    # both fists (or a club) brought up overhead and down
    "smash": dict(lean=(-16, 8, 30, 26), head=(-10, 6, 22, 20), arm_n=(172, 140, 62, 40), fore_n=(200, 150, 50, 30), arm_f=(166, 130, 56, 34), fore_f=(196, 140, 44, 26)),
}
ATTACKS = {"bite": BITE, "pounce": POUNCE, "slash": SLASH, "spit": SPIT}


def attack_kind(form):
    return form.get("attack", "bite")


def attack_frames(body):
    return FRAMES, WINDUP


def _carriage(body):
    """What an action starts from and returns to: the idle's first frame (its body pitch, its claws, the drider's arms)."""
    rot, root = idle_pose(body, 0.0)
    posed = body.skel.pose(rot, root)
    tips = {}
    for key in ss.LEGS:
        tip = posed["tar_" + key][1]
        tips[key] = (tip[0], tip[1], posed["tar_" + key][2] - body.rest_tar[key])
    return dict(rot=rot, root=root, posed=posed, tips=tips, pitch=posed["body"][2] - body.rest_dir("body"),
                abd=(body.rest_dir("abdomen") + posed["body"][2] - body.rest_dir("body")) - posed["abdomen"][2],
                fang=posed["fang"][2] - body.rest_dir("fang") - (posed["body"][2] - body.rest_dir("body")),
                dirs={b: posed[b][2] for b in posed})


FRONT = ("f0x", "f0z", "f0c")   # the front pair's claw in an attack: where it goes (from where it stands at rest, in U) and its curl, not offsets


def _offsets(keys, time, c=None, body=None):
    """The channels at `time`. With the carriage `c`, the front pair's channels are places the claw goes to from wherever the carriage holds it (on the
    ground, or already up for a form that holds its forelegs up) and back."""
    out = {}
    for name, k in keys.items():
        if c is not None and name in FRONT:
            x, z, curl = c["tips"]["n0"]
            rest = {"f0x": (x - body.rest_tip["n0"][0]) / body.U, "f0z": (z - body.pad["n0"]) / body.U, "f0c": curl}[name]
            k = [(k[0][0], rest, k[0][2])] + list(k[1:-1]) + [(k[-1][0], rest, k[-1][2])]
        out[name] = anim.sample(k, time)
    return out


def _pose_offsets(body, c, ch, t=0.0, gesture=None, time=0.0, front_placed=False):
    """A pose from the carriage `c` and channel offsets `ch`: the body moved and pitched, the front pairs' claws moved, every other claw planted where it
    stands."""
    U = body.U
    rot = {}
    _trunk(body, rot, c["pitch"] + ch.get("pitch", 0.0), abd=c["abd"] + ch.get("abd", 0.0), fang=c["fang"] + ch.get("fang", 0.0), palp=ch.get("palp", 0.0))
    if body.drider:
        sk = body.skel
        d = c["dirs"]
        lean0, head0 = 180.0 - d["chest"], 180.0 - d["head"]
        if gesture:
            lean = lean0 + ch.get("lean", 0.0) + (anim.sample(_swing(*gesture["lean"]), time) if "lean" in gesture else 0.0)
            head = head0 + ch.get("head", 0.0) + (anim.sample(_swing(*gesture["head"]), time) if "head" in gesture else 0.0)
            arms = {}
            for bone in ("arm_n", "fore_n", "arm_f", "fore_f", "item_n", "item_f"):
                rest = d[bone]
                arms[bone] = anim.sample([(tt, rest if v == REST else v, e) for tt, v, e in _rest_swing(*gesture[bone])], time) if bone in gesture else rest
        else:
            lean, head = lean0 + ch.get("lean", 0.0), head0 + ch.get("head", 0.0)
            arms = {b: d[b] + ch.get("d_" + b, 0.0) for b in ("arm_n", "fore_n", "arm_f", "fore_f", "item_n", "item_f")}
        aim(sk, rot, "waist", 180.0 - (180.0 - d["waist"]) - (lean - lean0) * 0.6)
        aim(sk, rot, "chest", 180.0 - lean)
        aim(sk, rot, "head", 180.0 - head)
        for bone in ("arm_n", "fore_n", "arm_f", "fore_f", "item_n", "item_f"):
            aim(sk, rot, bone, arms[bone])
    root = (c["root"][0] + ch.get("root_x", 0.0) * U, 0.0, c["root"][2] + ch.get("root_z", 0.0) * U)
    tips = {}
    for key in ss.LEGS:
        x, z, curl = c["tips"][key]
        i = pair_of(key)
        if i == 0 and front_placed:
            # both claws of the pair follow the near one's path, each keeping its own place against it from the carriage
            nx, nz, nc = c["tips"]["n0"]
            x, z, curl = x - nx + body.rest_tip["n0"][0] + ch["f0x"] * U, z - nz + body.pad["n0"] + ch["f0z"] * U, curl - nc + ch["f0c"]
        elif i == 0:
            x, z, curl = x + ch.get("f0x", 0.0) * U, z + ch.get("f0z", 0.0) * U, curl + ch.get("f0c", 0.0)
        elif i == 1 and z > body.pad[key] + 0.1 * U:
            # held up already (the dance): it rides with the body
            x, z = x + root[0] - c["root"][0], z + root[2] - c["root"][2]
        elif i == 1:
            x, z = x + ch.get("f1x", 0.0) * U, z + ch.get("f1z", 0.0) * U
        tips[key] = (x, max(body.pad[key], z), curl)
    solve_legs(body, rot, root, tips)
    return rot, root


def attack_pose(body, time):
    c = _carriage(body)
    kind = attack_kind(body.form)
    gesture = GESTURES.get(kind)
    keys = LOWER if gesture else ATTACKS[kind]
    ch = _offsets(keys, time, c, body)
    rot, root = _pose_offsets(body, c, ch, gesture=gesture, time=time, front_placed=True)
    _jitter_one_shot(body, rot, time, T_END)
    return rot, root


def _jitter_one_shot(body, rot, time, end, amount=1.6):
    """The swarm twitches through an action and is back where the idle starts by the last frame."""
    if not body.swarm:
        return
    base = {}
    _jitter(body, base, 0.0)
    for j, bone in enumerate(body.swarm):
        a = (8.0 + 2.0 * j) * math.sin(math.pi * 6 * anim.clamp(time / end) + 0.0) * amount
        rot[bone] = (0.0, base[bone][1] - a, 0.0)


# ---- hurt -------------------------------------------------------------------------------------------------------------------------
HURT_FRAMES = [(0.00, 0.04), (0.04, 0.06), (0.10, 0.06), (0.16, 0.05), (0.21, 0.04)]   # the engine's flinch; the last frame is the rest pose


def _hurt_keys(peak, mid):
    return [(0.0, 0.0, "out"), (0.04, mid, "out"), (0.10, peak, "smooth"), (0.16, peak * 0.3, "smooth"), (0.21, 0.0, "smooth")]


HURT = {
    "root_x": _hurt_keys(-0.16, -0.10), "root_z": _hurt_keys(0.06, 0.04), "pitch": _hurt_keys(14.0, 9.0), "abd": _hurt_keys(-10.0, -6.0),
    "fang": _hurt_keys(26.0, 18.0), "palp": _hurt_keys(30.0, 20.0), "f0x": _hurt_keys(-0.15, -0.10), "f0z": _hurt_keys(0.55, 0.35), "f0c": _hurt_keys(40.0, 25.0),
    "f1z": _hurt_keys(0.15, 0.10), "lean": _hurt_keys(-26.0, -16.0), "head": _hurt_keys(-30.0, -18.0),
    "d_arm_n": _hurt_keys(-50.0, -30.0), "d_fore_n": _hurt_keys(-40.0, -24.0), "d_arm_f": _hurt_keys(-44.0, -26.0), "d_fore_f": _hurt_keys(-30.0, -18.0),
}


def hurt_frames():
    return HURT_FRAMES


def hurt_pose(body, time):
    c = _carriage(body)
    ch = _offsets(HURT, time)
    if body.raised or body.form.get("idle") in ("dance", "ready"):
        ch["f0z"] *= 0.4          # legs already up are thrown a little further, not up again
    rot, root = _pose_offsets(body, c, ch)
    _jitter_one_shot(body, rot, time, HURT_FRAMES[-1][0], 2.0)
    return rot, root


# ---- die --------------------------------------------------------------------------------------------------------------------------
# The legs give, the body drops, and the legs curl in under it the way a dead spider's do, the abdomen settling. Nothing is planted after the first
# frame: every bone has its own keys (world directions, REST the idle's) and the render sets the body on the ground.
DIE_FRAMES = [(0.00, 0.06), (0.06, 0.08), (0.14, 0.08), (0.22, 0.10), (0.32, 0.12), (0.44, 0.16), (0.60, 0.30), (0.90, 0.30)]
#                    rest  jolt   buckle  drop   curl   curl   settle lie
DIE_BODY = [REST, 12.0, 4.0, -6.0, -8.0, -6.0, -5.0, -5.0]          # pitch, nose up
DIE_ABD = [REST, -10.0, -4.0, 6.0, 4.0, -2.0, -4.0, -4.0]           # abdomen raised
DIE_FANG = [REST, 40.0, 30.0, 16.0, 8.0, 4.0, 2.0, 2.0]
DIE_CURL = [0.0, 0.10, 0.35, 0.55, 0.78, 0.92, 1.0, 1.0]            # how far the legs have curled in
CURLED = {0: (150.0, -15.0, -95.0), 1: (165.0, -25.0, -100.0), 2: (-165.0, 25.0, 100.0), 3: (-150.0, 15.0, 95.0)}   # femur, tibia, tarsus when curled: knees up, the shins folded in over the body


def die_frames():
    return DIE_FRAMES


def _lerp_angle(a, b, w):
    d = (b - a + 180.0) % 360.0 - 180.0
    return a + d * w


def die_pose(body, time):
    times = [t for t, _ in DIE_FRAMES]
    c = _carriage(body)
    d = c["dirs"]
    key = lambda vals, base: anim.sample([(times[i], base if v == REST else v, "smooth") for i, v in enumerate(vals)], time)
    curl = anim.sample([(times[i], v, "smooth") for i, v in enumerate(DIE_CURL)], time)
    sk = body.skel
    rot = {}
    _trunk(body, rot, key(DIE_BODY, c["pitch"]), abd=key(DIE_ABD, c["abd"]), fang=key(DIE_FANG, 0.0))
    for k in ss.LEGS:
        i = pair_of(k)
        far = 0.08 if k[0] == "f" else 0.0                # the far legs a beat behind
        w = anim.clamp(curl - far)
        for bone, target in zip(("fem_", "tib_", "tar_"), CURLED[i]):
            aim(sk, rot, bone + k, _lerp_angle(d[bone + k], target, w))
    if body.drider:
        slump = anim.clamp(curl * 1.2)
        aim(sk, rot, "waist", _lerp_angle(d["waist"], 120.0, slump))
        aim(sk, rot, "chest", _lerp_angle(d["chest"], 96.0, slump))
        aim(sk, rot, "head", _lerp_angle(d["head"], 70.0, slump))
        for bone, target in (("arm_n", 40.0), ("fore_n", 20.0), ("arm_f", 30.0), ("fore_f", 10.0), ("item_n", 100.0), ("item_f", 120.0)):
            aim(sk, rot, bone, _lerp_angle(d[bone], target, slump))
    _jitter_one_shot(body, rot, min(time, 0.6), 0.6, 2.4)
    return rot, (c["root"][0] - 0.05 * body.U * anim.clamp(time / 0.3), 0.0, 0.0)


# ---- clips ------------------------------------------------------------------------------------------------------------------------
class Clip:
    def __init__(self, frames, durations, loop, grounded=False):
        self.frames, self.durations, self.loop, self.grounded = frames, durations, loop, grounded


def _with_secondary(body, frames, durations, wind, periodic, settle=None):
    """Add the follow-through: the abdomen lags the body on a spring (on top of its own deliberate turn, carried as a made-up bone "abd" that is dropped
    here), the hair and the cloth trail; then lift an abdomen that has swung into the floor. A one-shot that hands back to the idle (`settle`, the idle's
    first frame) eases its hung things into the idle's over its last stretch, so the next clip starts where this one ends."""
    present = body.present | {"abd"}
    table = dict(SECONDARY, abdomen=ABDOMEN)
    out = secondary.series(present, table, frames, wind, durations, periodic=periodic)
    starts = [sum(durations[:i]) for i in range(len(durations))]
    end = starts[-1]
    for i, (rot, root) in enumerate(frames):
        own = rot.pop("abd", (0.0, 0.0, 0.0))
        w = anim.smooth((starts[i] - 0.45 * end) / (0.55 * end)) if settle else 0.0
        for bone, series in out.items():
            if bone == "abdomen":
                value = own[1] - series[i]
            elif bone != "abd":
                value = -series[i]
            else:
                continue
            if w > 0.0:
                value += (settle[bone][1] - value) * w
            rot[bone] = (0.0, value, 0.0)
        lift_clear(body, rot, root)
    return frames


def hull_points(body, rot, root, posed=None):
    posed = posed or body.skel.pose(rot, root)
    return [(bone, body.skel.point(bone, p, posed=posed)) for bone, p in body.hull if bone in posed]


def lift_clear(body, rot, root, clearance=0.012):
    """Raise an abdomen (or a hem) that has swung down through the floor: the sprite sits on its lowest point, so nothing may go below the claws."""
    for bone in ("abdomen", "cloth1"):
        if bone not in rot or not any(b == bone for b, _ in body.hull):
            continue
        sign = 1.0 if bone == "abdomen" else -1.0
        for _ in range(60):
            low = min(p[1] for b, p in hull_points(body, rot, root) if b == bone)
            if low >= clearance:
                break
            rot[bone] = (0.0, rot[bone][1] + sign * 1.5, 0.0)
            if bone == "abdomen" and "abd" in rot:
                rot["abd"] = (0.0, rot["abd"][1] + sign * 1.5, 0.0)


def idle_clip(body):
    n = IDLE_FRAMES
    dur = [IDLE_SECONDS / n] * n
    return Clip(_with_secondary(body, [idle_pose(body, i / n) for i in range(n)], dur, 0.1, True), dur, True)


TICK = 0.02   # the engine plays clips on a 20 ms grid: a quicker cycle is drawn in fewer frames, never in frames shorter than a tick


def gait_frames(gait, cycle):
    return max(4, min(GAIT_FRAMES[gait], int(cycle / TICK + 1e-9)))


def gait_clip(body, gait, cycle, stride):
    n = gait_frames(gait, cycle)
    dur = [cycle / n] * n
    frames = [gait_pose(body, gait, i / n, stride) for i in range(n)]
    return Clip(_with_secondary(body, frames, dur, 0.8 if gait == "walk" else 1.4, True), dur, True)


def attack_clip(body):
    dur = [d for _, d in FRAMES]
    return Clip(_with_secondary(body, [attack_pose(body, t) for t, _ in FRAMES], dur, 0.5, False, idle_clip(body).frames[0][0]), dur, False)


def hurt_clip(body):
    dur = [d for _, d in HURT_FRAMES]
    return Clip(_with_secondary(body, [hurt_pose(body, t) for t, _ in HURT_FRAMES], dur, 0.5, False, idle_clip(body).frames[0][0]), dur, False)


def die_clip(body):
    dur = [d for _, d in DIE_FRAMES]
    return Clip(_with_secondary(body, [die_pose(body, t) for t, _ in DIE_FRAMES], dur, 0.3, False), dur, False, grounded=True)


def clips_for(body, speed, ppu, run_speed=1.9):
    """{name: Clip} for a spider whose everyday speed is `speed` game px/s, drawn at `ppu` pixels to the unit."""
    walk_cycle, walk_stride = plan_gait(body, "walk", speed, ppu)
    run_cycle, run_stride = plan_gait(body, "run", speed * run_speed, ppu)
    return {"idle": idle_clip(body), "walk": gait_clip(body, "walk", walk_cycle, walk_stride), "run": gait_clip(body, "run", run_cycle, run_stride),
            "attack": attack_clip(body), "hurt": hurt_clip(body), "die": die_clip(body)}
