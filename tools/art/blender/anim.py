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
    """Like sample, but the last key leads back to the first one `period` later (and, before the first key, from the previous cycle's last)."""
    t = t % period
    first_t, first_v, _ = keys[0]
    last_t, last_v, last_kind = keys[-1]
    if t < first_t:
        t0 = last_t - period
        return last_v + (first_v - last_v) * ease(last_kind, (t - t0) / (first_t - t0))
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
def pitch_at(u, duty):
    """A foot's pitch in degrees over a cycle: the heel strikes toe-up, the foot rolls flat, the heel lifts before the toe leaves (toe-off at
    `duty`), then in swing the toe trails and comes up to meet the ground."""
    swing = 1.0 - duty
    return sample([(0.0, 14.0, "smooth"), (0.18 * duty, 0.0, "linear"), (0.70 * duty, 0.0, "smooth"), (duty, -34.0, "smooth"),
                   (duty + 0.25 * swing, -20.0, "smooth"), (duty + 0.80 * swing, 8.0, "smooth"), (1.0, 14.0, "linear")], u % 1.0)


def sole_points(ax, az, pitch, heel, toe, ankle_h):
    """The heel and the toe of a foot whose ankle is at (ax, az) and which is tilted `pitch` degrees (positive: toe up) about the ankle; the
    sole is `ankle_h` below the ankle, the heel `heel` behind it and the toe `toe` ahead."""
    c, s = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))

    def point(x, z):
        return (ax + x * c - z * s, az + x * s + z * c)
    return [point(-heel, -ankle_h), point(toe, -ankle_h)]


def sole_contact(ax, az, pitch, heel, toe, ankle_h):
    """Where the foot touches: the heel when it is the lower point, the toe when that is, the middle between them when the sole is flat.
    Returns (x, lowest z)."""
    h, t = sole_points(ax, az, pitch, heel, toe, ankle_h)
    w = smooth(0.5 + (t[1] - h[1]) / (0.08 * (heel + toe)))
    return w * h[0] + (1.0 - w) * t[0], min(h[1], t[1])


def plant(contact_x, pitch, heel, toe, ankle_h):
    """The ankle (x, z) that puts a foot tilted `pitch` degrees on the ground with its contact point (the heel, the toe, or between them when it
    is flat) at `contact_x`."""
    cx, low = sole_contact(0.0, 0.0, pitch, heel, toe, ankle_h)
    return contact_x - cx, -low


def plant_toe(toe_x, pitch, heel, toe, ankle_h):
    """The ankle (x, z) that stands a foot tilted `pitch` degrees (toe down, so negative) on the tip of its toe at `toe_x`: a heel lifting off the
    ground turns about the toe, which stays where it was."""
    tip = sole_points(0.0, 0.0, pitch, heel, toe, ankle_h)[1]
    return toe_x - tip[0], -tip[1]


def foot_pose(u, stride, duty, lift, heel, toe, ankle_h):
    """One foot over a cycle, u in [0, 1): the ankle (x, z), the pitch in degrees and whether it is planted. x is relative to the hip. In stance
    the contact point moves back at a constant speed (the body moving forward over it) and the ankle is wherever that puts the sole on the
    ground, rolling heel, flat, toe; swing joins the toe-off pose to the next heel strike on an arc `lift` high, so the path never jumps."""
    u = u % 1.0

    def stance(s):
        p = pitch_at(s * duty, duty)
        cx, low = sole_contact(0.0, 0.0, p, heel, toe, ankle_h)
        return stride / 2.0 - stride * s - cx, -low, p

    if u < duty:
        x, z, p = stance(u / duty)
        return x, z, p, True
    x0, z0, _ = stance(1.0)
    x1, z1, _ = stance(0.0)
    s = (u - duty) / (1.0 - duty)
    k = smooth(s)
    x = x0 + (x1 - x0) * k
    z = z0 + (z1 - z0) * k + lift * math.sin(math.pi * s ** 0.85)
    p = pitch_at(u, duty)
    z += max(0.0, -min(pt[1] for pt in sole_points(x, z, p, heel, toe, ankle_h)))  # never through the floor
    return x, z, p, False


def pelvis_height(t, base, amp, duty=0.6):
    """The pelvis over a cycle t in [0, 1): highest as each leg passes under it (mid-stance), lowest shortly after each heel strike, so it
    bobs twice a cycle."""
    return base + amp * math.cos(4.0 * math.pi * (t - duty / 2.0))


# ---- follow-through ----
def follow(driver, durations, freq=3.0, zeta=0.4, periodic=True, state=False, max_cycles=400):
    """How something hung on a moving part lags it, in real seconds. `driver` is the part's angle on each frame; `durations` is how long
    each frame lasts (one number, or a list); the follower is a damped spring (natural frequency `freq` in Hz, damping ratio `zeta`) chasing
    the driver, which is moved in a straight line between frames. Returns the follower's angle at the start of each frame.

    A loop (`periodic`) is run until the spring ends a lap where it began, in position and in speed, so the seam is as smooth as the rest;
    a one-shot starts on the first frame at rest. With `state=True` also returns the (position, speed) at the start and at the end."""
    n = len(driver)
    times = [float(durations)] * n if isinstance(durations, (int, float)) else [float(d) for d in durations]
    w = 2.0 * math.pi * freq
    pos, vel = float(driver[0]), 0.0
    out, first, last = [], (pos, vel), (pos, vel)
    for lap in range(max_cycles if periodic else 1):
        out, lap_start = [], (pos, vel)
        for i in range(n):
            out.append(pos)
            a, b = driver[i], driver[(i + 1) % n] if periodic else driver[min(i + 1, n - 1)]
            steps = max(1, int(math.ceil(times[i] * 240.0)))
            dt = times[i] / steps
            for k in range(steps):
                target = a + (b - a) * ((k + 0.5) / steps)
                vel += (w * w * (target - pos) - 2.0 * zeta * w * vel) * dt
                pos += vel * dt
        if lap == 0:
            first = lap_start
        last = (pos, vel)
        if periodic and abs(pos - lap_start[0]) < 1e-5 and abs(vel - lap_start[1]) < 1e-4:
            break
    return (out, lap_start if periodic else first, last) if state else out
