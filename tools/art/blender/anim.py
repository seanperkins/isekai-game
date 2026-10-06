"""Animation maths for the creature rigs: pure Python (no Blender), so it is tested in test_anim.py and used inside Blender.

The ideas come from how walks are actually built (docs/research/rig-weight-research.md): a leg is two bones solved by IK so a planted foot
stays planted; a gait has a stance (foot on the ground, moving back at the speed of the body) and a swing (foot lifted and brought forward),
with the heel striking and the toe leaving; the pelvis, the centre of mass, rises as a leg passes under it and sinks after each heel strike;
things hung on the body (ears, cloaks, packs) lag it as springs; and actions are eased keyframes with uneven timing.

Angles. A limb hanging straight down is angle 0. A positive angle swings its tip forward (+x), counter-clockwise on screen, the same way as
`down(d)` in goblin_kit.py. Positions are (x, z) with z up.
"""
import math


# ---- easing and keys ----
def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def smooth(t):
    t = clamp(t)
    return t * t * (3.0 - 2.0 * t)


def ease(kind, t):
    t = clamp(t)
    if kind == "out":
        return 1.0 - (1.0 - t) ** 3
    if kind == "in":
        return t ** 3
    if kind == "smooth":
        return smooth(t)
    return t


def sample(keys, t):
    """The value at time t of [(time, value, ease)...]: eased from each key to the next (the ease is the one on the key it leaves), held
    before the first and after the last."""
    if t <= keys[0][0]:
        return keys[0][1]
    if t >= keys[-1][0]:
        return keys[-1][1]
    for (t0, v0, kind), (t1, v1, _) in zip(keys, keys[1:]):
        if t0 <= t < t1:
            return v0 + (v1 - v0) * ease(kind, (t - t0) / (t1 - t0))
    return keys[-1][1]


def sample_loop(keys, t, period):
    """Like sample, but the last key leads back to the first one `period` later."""
    t = t % period
    first_t, first_v, _ = keys[0]
    last_t, last_v, last_kind = keys[-1]
    if t >= last_t:
        return last_v + (first_v - last_v) * ease(last_kind, (t - last_t) / (first_t + period - last_t))
    return sample(keys, t)


# ---- legs ----
def fk2d(l1, l2, hip, a1, a2):
    """(knee, end) of a two-bone limb whose bones point at absolute angles a1 and a2."""
    knee = (hip[0] + l1 * math.sin(a1), hip[1] - l1 * math.cos(a1))
    return knee, (knee[0] + l2 * math.sin(a2), knee[1] - l2 * math.cos(a2))


def ik2d(l1, l2, hip, target, bend=1):
    """Absolute angles (a1, a2), in radians, that put the end of a two-bone limb on `target`. bend=1 puts the knee forward (a person's), -1
    back (a wolf's hock). A target out of reach gets a straight limb pointing at it; one closer than the fold gets the nearest fold."""
    dx, dz = target[0] - hip[0], target[1] - hip[1]
    d = math.hypot(dx, dz)
    d = clamp(d, abs(l1 - l2) + 1e-9, l1 + l2 - 1e-9)
    heading = math.atan2(dx, -dz)
    cos_a = clamp((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
    a1 = heading + bend * math.acos(cos_a)
    end = (hip[0] + d * math.sin(heading), hip[1] - d * math.cos(heading))
    knee = (hip[0] + l1 * math.sin(a1), hip[1] - l1 * math.cos(a1))
    return a1, math.atan2(end[0] - knee[0], -(end[1] - knee[1]))


# ---- gait ----
def stride_foot(u, stride, duty=0.6, lift=0.12):
    """One foot over a cycle, u in [0, 1): (x, z, pitch in degrees, grounded). x is relative to the hip: the foot is planted for `duty` of
    the cycle, moving back at a constant speed (the body moving forward over it), then lifts, swings forward on an arc `lift` high and lands
    where the next stance begins. The heel strikes toe-up, the foot rolls flat, the heel lifts before the toe leaves."""
    u = u % 1.0
    if u < duty:
        s = u / duty
        x, z, grounded = stride / 2.0 - stride * s, 0.0, True
    else:
        s = (u - duty) / (1.0 - duty)
        x, z, grounded = -stride / 2.0 + stride * smooth(s), lift * math.sin(math.pi * s ** 0.85), False
    swing = 1.0 - duty
    pitch = sample([(0.0, 14.0, "smooth"), (0.18 * duty, 0.0, "linear"), (0.70 * duty, 0.0, "smooth"), (duty, -34.0, "smooth"),
                    (duty + 0.25 * swing, -20.0, "smooth"), (duty + 0.80 * swing, 8.0, "smooth"), (1.0, 14.0, "linear")], u)
    return x, z, pitch, grounded


def contact_lift(pitch, heel, toe):
    """How high the ankle sits when a foot tilted by `pitch` degrees rests on its heel (toe up, pitch > 0) or its toe (heel up, pitch < 0)."""
    if pitch >= 0.0:
        return heel * math.sin(math.radians(pitch))
    return toe * math.sin(math.radians(-pitch))


def pelvis_height(t, base, amp, duty=0.6):
    """The pelvis over a cycle t in [0, 1): highest as each leg passes under it (mid-stance), lowest shortly after each heel strike, so it
    bobs twice a cycle."""
    return base + amp * math.cos(4.0 * math.pi * (t - duty / 2.0))


# ---- follow-through ----
def follow(driver, stiffness=0.12, damping=0.35, cycles=6, substeps=4):
    """How something hung on a moving part lags it. `driver` is the part's absolute angle on each frame of a loop; the result is the hung
    thing's absolute angle on each frame, from a damped spring chasing the driver, run for several cycles so the loop is seamless."""
    n = len(driver)
    pos, vel = driver[0], 0.0
    dt = 1.0 / substeps
    out = []
    for c in range(cycles):
        out = []
        for i in range(n):
            out.append(pos)
            a, b = driver[i], driver[(i + 1) % n]
            for k in range(substeps):
                target = a + (b - a) * (k / float(substeps))
                vel += (stiffness * (target - pos) - damping * vel) * dt
                pos += vel * dt
    return out
