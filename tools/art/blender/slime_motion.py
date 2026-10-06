"""How a slime moves: a jelly dome that squashes, stretches, leans and wobbles, hops instead of walking, and carries whatever its form has (eyes, a
stone, a crown, tentacles, a vine) along with it. Pure Python (no Blender), tested in test_slime_motion.py.

The body is one dome mesh (`Shape.mesh`) deformed per frame from a handful of numbers (`deform`), the frame's "soft" parameters, which ride in the
frame's rotation table under the key SOFT (Rig.pose and skeleton2d only read bone names, so they pass through). The kit's `post_pose` hook
(rigkit.Rig.post_pose) writes the same deformation into the real mesh. Every term keeps the base on the ground: z' = z * sq, and the sideways terms
(lean, wave) grow from zero at the base, so the base neither leaves the ground nor shears. Width scales as sqrt(vol / sq), so a squash widens and a
stretch narrows with the volume kept (vol = 1); only the death lets some of it seep away.

Soft parameters (all optional, see REST):
  sq      height scale (below 1 a squash, above 1 a stretch)
  vol     volume kept (1 but in the death)
  lean    how far the top is sheared forward, in body heights (the base stays put)
  bulge   a ring of extra width at height `bc` (0 base, 1 top), volume-neutral to first order
  wave    a sideways S through the body (a wobble), with `phase`
  off     {group: dict(d=(dx, dz), s=scale, a=degrees, sz=height scale)}: a group of parts moved on top of the body (a blink, a thrown pebble,
          a dropped crown, the inner stone lagging)

Appendages (tentacles, a vine, ribbon ends, a pelt) are chains of bones rooted on the body surface: the root follows the deformed surface
(`anchor_offset`, which post_pose adds to the chain's first bone) and each link chases its own direction on a spring, so it lags the body and
overshoots (follow-through). Angles are degrees from straight down, forward positive (skeleton2d.py).

Movement. A slime hops: the planted base does not slide (in the sprite's frame it moves back at the speed while it is down), and in the air the body
moves forward on a parabola, so a cycle covers exactly speed * cycle. A hover form (the cloud rider, the poltergeist) bobs and glides instead.
"""
import math

import anim
import skeleton2d
from limbs import aim

SOFT = "_soft"
REST = dict(sq=1.0, vol=1.0, lean=0.0, bulge=0.0, bc=0.5, wave=0.0, phase=0.0)
CHANNELS = ("sq", "vol", "lean", "bulge", "bc", "wave", "phase")

# the engine's timings (scripts/enemies/enemy.gd: VERB_WINDUP, VERB_RECOVER, HURT_SECONDS; test_export_forms checks the constants) and the
# attack's frames, the same as the wolf's and the goblin's so the windup is the first five
ENGINE_WINDUP, ENGINE_RECOVER, ENGINE_HURT = 0.35, 0.30, 0.25
FRAMES = [(0.00, 0.06), (0.06, 0.06), (0.12, 0.15), (0.27, 0.04), (0.31, 0.04), (0.35, 0.08), (0.43, 0.05), (0.48, 0.05), (0.53, 0.06), (0.59, 0.06)]
WINDUP = 5
T_WIND, T_HOLD, T_MID, T_HIT, T_FOLLOW, T_SETTLE, T_END = 0.12, 0.27, 0.31, 0.35, 0.43, 0.53, 0.59
HURT_FRAMES = [(0.00, 0.04), (0.04, 0.06), (0.10, 0.06), (0.16, 0.05), (0.21, 0.04)]
DIE_FRAMES = [(0.00, 0.06), (0.06, 0.08), (0.14, 0.08), (0.22, 0.10), (0.32, 0.12), (0.44, 0.16), (0.60, 0.30), (0.90, 0.30)]
IDLE_FRAMES, IDLE_SECONDS = 8, 1.6
RUN_SPEED = 1.9
CLEAR = 0.05      # how far above the ground a chain's bones stay, by default (its flesh is drawn round them)

# hops: `contact` the share of the cycle the base is down, `height` the top of the flight in body heights, `length` the hop a cycle aims for and
# `longest` the most the body can throw itself, both in body widths, `cycle` the bounds on the cycle in seconds
HOPS = {
    "walk": dict(frames=12, contact=0.5, height=0.24, length=0.75, longest=1.05, cycle=(0.55, 1.1)),
    "run": dict(frames=10, contact=0.36, height=0.42, length=1.2, longest=1.6, cycle=(0.4, 0.8)),
}
GLIDES = {"walk": dict(frames=10, cycle=1.0, bob=0.05, lean=0.05), "run": dict(frames=10, cycle=0.6, bob=0.04, lean=0.10)}


# ---- the dome ------------------------------------------------------------------------------------------------------------------------
class Shape:
    """The rest body: a dome on a flat base, `R` half as wide as it is (x), `D` half as deep (y), `H` tall, its widest at `zc` (of H). `n_top` and
    `n_bot` are superellipse exponents of the side profile (2 round, larger boxier), `plan` that of the plan (2 an ellipse, larger a rounded
    square). `lumps` [(amplitude, k_phi, k_a, phase)] roughen it; `snout` (amplitude, elevation) pushes a bump out at the front."""
    LAT, AROUND = 18, 32

    def __init__(self, R=0.5, D=0.42, H=0.72, zc=0.38, n_top=2.4, n_bot=4.0, plan=2.0, lumps=(), snout=None):
        self.R, self.D, self.H, self.zc = R, D, H, zc
        self.n_top, self.n_bot, self.plan = n_top, n_bot, plan
        self.lumps, self.snout = tuple(lumps), snout
        self._gbar = {}

    @classmethod
    def of(cls, form):
        return cls(**form.get("shape", {}))

    def profile(self, a):
        """(radius fraction, z) of the side profile at elevation `a` degrees (-90 the base's centre, 90 the top)."""
        r = math.radians(a)
        c, s = abs(math.cos(r)), math.sin(r)
        zc = self.zc * self.H
        if s >= 0:
            return c ** (2.0 / self.n_top), zc + (self.H - zc) * s ** (2.0 / self.n_top)
        return c ** (2.0 / self.n_bot), zc - zc * (-s) ** (2.0 / self.n_bot)

    def surface(self, phi, a, lift=0.0):
        """The point on the surface at plan angle `phi` (0 the front, -90 the near side, 180 the back) and elevation `a`, pushed out by `lift`
        (a fraction of its distance from the axis)."""
        rho, z = self.profile(a)
        p = math.radians(phi)
        c, s = math.cos(p), math.sin(p)
        e = 2.0 / self.plan
        cx = math.copysign(abs(c) ** e, c)
        sy = math.copysign(abs(s) ** e, s)
        k = 1.0
        for amp, kp, ka, ph in self.lumps:
            k += amp * math.sin(kp * p + ka * math.radians(a) + ph) * (abs(math.cos(math.radians(a))) ** 0.5)
        if self.snout:
            amp, at = self.snout
            k += amp * math.exp(-(p * p) / 0.25 - ((a - at) / 22.0) ** 2)
        k *= 1.0 + lift
        return (self.R * rho * cx * k, self.D * rho * sy * k, z)

    def elev_for(self, a):
        """The profile elevation whose height is where a placement elevation `a` asks for: heights spread evenly with the sine of `a` (0 the widest
        point, 90 the top, -90 the base), whatever the shape's exponents, so a placement means the same on a round dome, a cube or a flat mould."""
        s = math.sin(math.radians(a))
        zc = self.zc * self.H
        want = zc + (self.H - zc) * s if s >= 0 else zc * (1.0 + s)
        lo, hi = -90.0, 90.0
        for _ in range(40):
            mid = (lo + hi) / 2.0
            if self.profile(mid)[1] < want:
                lo = mid
            else:
                hi = mid
        return (lo + hi) / 2.0

    def point(self, phi, a, lift=0.0):
        """The surface point for a placement: plan angle `phi`, height by `a` (elev_for), pushed out by `lift`."""
        return self.surface(phi, self.elev_for(a), lift)

    def mesh(self):
        """(vertices, faces) of the dome: rings of `AROUND` points from just above the base's centre to just below the top, and the two poles.
        Faces wind the same way everywhere (outward)."""
        verts = [(0.0, 0.0, 0.0)]
        lat = self.LAT
        for j in range(1, lat):
            a = -90.0 + 180.0 * j / lat
            for i in range(self.AROUND):
                verts.append(self.surface(360.0 * i / self.AROUND, a))
        verts.append((0.0, 0.0, self.H))
        top = len(verts) - 1
        n = self.AROUND

        def at(j, i):
            return 1 + (j - 1) * n + (i % n)
        faces = []
        for i in range(n):
            faces.append((0, at(1, i + 1), at(1, i)))
        for j in range(1, lat - 1):
            for i in range(n):
                faces.append((at(j, i), at(j, i + 1), at(j + 1, i + 1), at(j + 1, i)))
        for i in range(n):
            faces.append((top, at(lat - 1, i), at(lat - 1, i + 1)))
        return verts, faces

    def near_point(self, x, z, lift=0.02):
        """The point on the near (camera) side of the surface seen at (x, z) from the side, pushed out by `lift`: where to put a thing that is to
        show on the body (or through the jelly)."""
        lo, hi = -90.0, 90.0
        for _ in range(50):
            mid = (lo + hi) / 2.0
            if self.profile(mid)[1] < z:
                lo = mid
            else:
                hi = mid
        a = (lo + hi) / 2.0
        rho = self.profile(a)[0]
        cx = max(-0.999, min(0.999, x / max(1e-6, self.R * rho)))
        return self.surface(-math.degrees(math.acos(cx)), a, lift)

    def gbar(self, bc):
        """The volume-weighted mean of the bulge's bell at `bc`, so subtracting it makes a bulge add (to first order) no volume."""
        key = round(bc, 4)
        if key not in self._gbar:
            num = den = 0.0
            steps = 120
            prev = self.profile(-90.0)
            for k in range(1, steps + 1):
                cur = self.profile(-90.0 + 180.0 * k / steps)
                dz = cur[1] - prev[1]
                area = ((cur[0] + prev[0]) / 2.0) ** 2
                u = (cur[1] + prev[1]) / 2.0 / self.H
                num += area * _bell(u, bc) * dz
                den += area * dz
                prev = cur
            self._gbar[key] = num / den
        return self._gbar[key]


def _bell(u, bc):
    return math.exp(-((u - bc) / 0.22) ** 2)


def soft_of(rot):
    s = dict(REST)
    s.update((rot or {}).get(SOFT, {}))
    return s


def deform(p, soft, shape):
    """Where the rest point `p` (x, y, z) of the body goes under the soft parameters (the root is added afterwards, by the rig)."""
    s = dict(REST)
    s.update(soft)
    x, y, z = p
    H = shape.H
    u = z / H
    w = math.sqrt(s["vol"] / s["sq"])
    if s["bulge"]:
        w *= 1.0 + s["bulge"] * (_bell(u, s["bc"]) - shape.gbar(s["bc"]))
    dx = s["lean"] * H * u * u + s["wave"] * H * u * math.sin(math.pi * 1.4 * u - s["phase"])
    return (x * w + dx, y * w, z * s["sq"])


def anchor_offset(soft, shape, p):
    """How far the deformation moves a point fixed to the body: what a chain rooted there, or a part carried there, is moved by."""
    q = deform(p, soft, shape)
    return (q[0] - p[0], q[1] - p[1], q[2] - p[2])


def group_transform(v, pivot, off):
    """A part of `group` moved by its offset {d, s, a, sz}: scaled (and squashed in height) and turned about its pivot, then moved."""
    dx, dz = off.get("d", (0.0, 0.0))
    s, sz, a = off.get("s", 1.0), off.get("sz", 1.0), math.radians(off.get("a", 0.0))
    x, y, z = v[0] - pivot[0], v[1] - pivot[1], v[2] - pivot[2]
    x, y, z = x * s, y * s, z * s * sz
    c, n = math.cos(a), math.sin(a)
    x, z = x * c + z * n, -x * n + z * c
    return (pivot[0] + x + dx, pivot[1] + y, pivot[2] + z + dz)


def volume(verts, faces):
    """The volume a closed mesh encloses (the divergence theorem over its faces, fanned into triangles)."""
    total = 0.0
    for f in faces:
        a = verts[f[0]]
        for i in range(1, len(f) - 1):
            b, c = verts[f[i]], verts[f[i + 1]]
            total += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
    return abs(total)


# ---- the body: the shape, the bones, the form ---------------------------------------------------------------------------------------------
class SlimeBody:
    """What the motion needs to know about one slime: its rest shape, its bones (a root `body` and the chains of the form's appendages), the
    form's flags (hover, stiff, the specials) and its groups of loose parts."""
    def __init__(self, form):
        self.form = form
        self.shape = Shape.of(form)
        self.H, self.R = self.shape.H, self.shape.R
        self.width = 2.0 * self.R
        self.hover = form.get("hover", 0.0)          # how high a hovering form floats at rest, in units (0: it hops on the ground)
        self.stiff = form.get("stiff", 1.0)          # how far it gives (1 jelly; the cube and the talos much less)
        self.chains = []
        rest = {"body": ((0.0, 0.0), (0.0, self.H), None)}
        for ch in form.get("chains", []):
            anchor = self.shape.point(ch["at"][0], ch["at"][1], ch.get("lift", -0.08))
            head, names = (anchor[0], anchor[2]), []
            for i, (direction, length) in enumerate(ch["links"]):
                d = math.radians(direction)
                tail = (head[0] + length * math.sin(d), head[1] - length * math.cos(d))
                name = "%s%d" % (ch["name"], i + 1)
                rest[name] = (head, tail, names[-1] if names else "body")
                names.append(name)
                head = tail
            self.chains.append(dict(ch, anchor=anchor, bones=names))
        self.skel = skeleton2d.Skeleton2D(rest)
        self.groups = form.get("groups", {})          # {group: pivot (x, y, z)} of the loose parts the motion moves

    def chain(self, name):
        return next(c for c in self.chains if c["name"] == name)


def pose_bones(body, rot, root):
    """{bone: (head, tail, direction)} as the real armature has them after the kit's post_pose: the skeleton posed, and each chain carried by
    where the deformed surface has moved its root."""
    posed = body.skel.pose(rot, root)
    soft = soft_of(rot)
    for ch in body.chains:
        dx, _, dz = anchor_offset(soft, body.shape, ch["anchor"])
        for b in ch["bones"]:
            h, t, d = posed[b]
            posed[b] = ((h[0] + dx, h[1] + dz), (t[0] + dx, t[1] + dz), d)
    return posed


def lowest(body, rot, root, verts=None):
    """The lowest z of the deformed body and of every chain's bones in a pose."""
    soft = soft_of(rot)
    verts = verts or body.shape.mesh()[0]
    low = min(deform(v, soft, body.shape)[2] for v in verts) + root[2]
    posed = pose_bones(body, rot, root)
    for ch in body.chains:
        for b in ch["bones"]:
            h, t, _ = posed[b]
            low = min(low, h[1], t[1])
    return low


# ---- chains: follow-through -------------------------------------------------------------------------------------------------------------
def _velocities(points, durations, periodic):
    n = len(points)
    out = []
    for i in range(n):
        if periodic:
            a, b = points[i - 1], points[(i + 1) % n]
            dt = durations[i - 1] + durations[i]
        else:
            a, b = points[max(0, i - 1)], points[min(n - 1, i + 1)]
            dt = sum(durations[max(0, i - 1):min(n - 1, i + 1)]) or durations[i]
        out.append(((b[0] - a[0]) / dt, (b[1] - a[1]) / dt))
    return out


def chain_rots(body, frames, durations, periodic, deliberate=None, rest_frame=None):
    """Fill each frame's rotations for the chains: a link chases its rest direction plus what the clip does on purpose (`deliberate(chain,
    link, i)`, degrees) plus a lag against how its root moves (a thing hung on a body trails it), on a spring, so it overshoots and settles.
    A one-shot clip starts from, and ends on, `rest_frame`'s rotations (the idle's first frame), so the next clip starts where it left off."""
    n = len(frames)
    for ch in body.chains:
        anchors = []
        for rot, root in frames:
            dx, _, dz = anchor_offset(soft_of(rot), body.shape, ch["anchor"])
            anchors.append((ch["anchor"][0] + dx + root[0], ch["anchor"][2] + dz + root[2]))
        vel = _velocities(anchors, durations, periodic)
        k = ch.get("drag", 30.0)
        prev = None
        for li, b in enumerate(ch["bones"]):
            rest = body.skel.rest_direction(b)
            driver = []
            for i in range(n):
                base = rest if prev is None else prev[i] + rest - body.skel.rest_direction(ch["bones"][li - 1])
                d = math.radians(base)
                lag = -k * (vel[i][0] * math.cos(d) + vel[i][1] * math.sin(d)) * (0.6 if prev is not None else 1.0)
                lag = max(-50.0, min(50.0, lag))
                extra = deliberate(ch, li, i) if deliberate else 0.0
                driver.append(base + lag + extra)
            chased = anim.follow(driver, durations, freq=ch.get("freq", 2.6) * (0.85 ** li), zeta=ch.get("zeta", 0.4), periodic=periodic)
            prev = chased
            for i in range(n):
                frames[i][0].setdefault("_dirs", {})[b] = chased[i]
    for rot, _ in frames:
        dirs = rot.pop("_dirs", {})
        for ch in body.chains:
            for b in ch["bones"]:
                aim(body.skel, rot, b, dirs[b])
    if rest_frame is not None and not periodic and frames:
        for ch in body.chains:
            for b in ch["bones"]:
                frames[-1][0][b] = rest_frame[0][b]
    return frames


def _lagged(body, frames, durations, periodic, pivot, freq=2.2, zeta=0.35, gain=1.0, limit=0.06):
    """The (dx, dz) a thing inside the jelly lags by, per frame: it is pulled along by the jelly around it on a spring (an inner stone, a coin in
    the cube, the crown riding on top)."""
    xs, zs = [], []
    for rot, root in frames:
        dx, _, dz = anchor_offset(soft_of(rot), body.shape, pivot)
        xs.append(pivot[0] + dx + root[0])
        zs.append(pivot[2] + dz + root[2])
    fx = anim.follow(xs, durations, freq=freq, zeta=zeta, periodic=periodic)
    fz = anim.follow(zs, durations, freq=freq, zeta=zeta, periodic=periodic)
    lim = limit * body.H
    return [(max(-lim, min(lim, gain * (a - b))), max(-lim, min(lim, gain * (c - d)))) for a, b, c, d in zip(fx, xs, fz, zs)]


# ---- clips -----------------------------------------------------------------------------------------------------------------------------
class Clip:
    def __init__(self, frames, durations, loop, grounded=False):
        self.frames, self.durations, self.loop, self.grounded = frames, durations, loop, grounded


def _soft(body, **kw):
    """Soft parameters with the form's stiffness applied: a stiff body gives a fraction of what a jelly does."""
    k = body.stiff
    s = dict(REST)
    for name, v in kw.items():
        if name in ("sq", "vol"):
            s[name] = 1.0 + (v - 1.0) * (k if name == "sq" else 1.0)
        elif name in ("lean", "bulge", "wave"):
            s[name] = v * k
        else:
            s[name] = v
    return s


def _frame(soft, off=None):
    soft = dict(soft)
    if off:
        soft["off"] = off
    return {SOFT: soft}


def _rest_root(body):
    return (0.0, 0.0, body.hover)


def idle_soft(body, t):
    """Breathing and a slow wobble: the body swells and settles, leans a little one way and the other, and a ring of fullness travels up it."""
    turn = 2.0 * math.pi * t
    return _soft(body, sq=1.0 + 0.035 * math.sin(turn), lean=0.025 * math.sin(turn - 1.1), wave=0.018 * math.sin(turn + 0.6), phase=turn,
                 bulge=0.07 * math.sin(math.pi * t) ** 2, bc=0.15 + 0.7 * t)


def idle_root(body, t):
    if body.hover:
        return (0.0, 0.0, body.hover + 0.04 * body.H * math.sin(2.0 * math.pi * t))
    return (0.0, 0.0, 0.0)


def _rest(body):
    """The pose every action starts from and returns to: the idle's first frame."""
    return idle_soft(body, 0.0), idle_root(body, 0.0)


# -- hopping
def plan_hop(body, gait, speed, ppu):
    """(cycle seconds, hop length in units) for a hop covering the ground at `speed` game pixels per second with a sprite drawn at `ppu` pixels
    to the unit: the hop aims for `length` body widths in a cycle within the usual bounds, never longer than the body can throw itself
    (`longest`), so the cycle is shortened instead."""
    g = HOPS[gait]
    v = speed / ppu
    cycle = min(g["cycle"][1], max(g["cycle"][0], g["length"] * body.width / v))
    if v * cycle > g["longest"] * body.width:
        cycle = g["longest"] * body.width / v
    return cycle, v * cycle


def hop_root(body, gait, t, length):
    """Where the body's base centre is at cycle position t in [0, 1), in the sprite's frame (which moves forward at length per cycle): while the
    base is down it moves back at the speed (it is planted on the ground going by), then the body flies forward on a parabola."""
    g = HOPS[gait]
    c = g["contact"]
    t = t % 1.0
    if t < c:
        x = length * (c / 2.0 - t)
        z = 0.0
    else:
        s = (t - c) / (1.0 - c)
        x = length * (-c / 2.0 + c * s)
        z = 4.0 * g["height"] * body.H * s * (1.0 - s)
    return (x, 0.0, z)


def hop_soft(body, gait, t):
    """The squash and stretch of a hop: it lands and squashes, jiggles back, sinks into the anticipation, stretches up as it leaves, rounds out
    in the air and reaches down before it lands again."""
    g = HOPS[gait]
    c = g["contact"]
    t = t % 1.0
    run = gait == "run"
    if t < c:
        u = t / c
        # keyed where the frames fall (a walk's contact frames are at sixths of it, a run's at about quarters), so the landing squash, the
        # rebound and the coil are each drawn: the first contact frame is the impact
        if run:
            sq = anim.sample([(0.0, 0.66, "smooth"), (0.28, 1.03, "smooth"), (0.56, 0.74, "smooth"), (0.83, 0.92, "smooth"), (1.0, 1.20, "linear")], u)
            lean = anim.sample([(0.0, 0.06, "smooth"), (0.28, -0.04, "smooth"), (0.56, -0.08, "smooth"), (0.83, 0.02, "smooth"), (1.0, 0.11, "linear")], u)
            wave = anim.sample([(0.0, 0.05, "smooth"), (0.28, -0.03, "smooth"), (0.56, 0.0, "smooth"), (1.0, 0.0, "linear")], u)
        else:
            sq = anim.sample([(0.0, 0.74, "smooth"), (0.17, 1.06, "smooth"), (0.34, 0.96, "smooth"), (0.5, 1.0, "smooth"), (0.67, 0.80, "smooth"),
                              (0.84, 0.79, "smooth"), (1.0, 1.16, "linear")], u)
            lean = anim.sample([(0.0, 0.05, "smooth"), (0.17, -0.05, "smooth"), (0.34, 0.02, "smooth"), (0.5, 0.0, "smooth"), (0.67, -0.07, "smooth"),
                                (0.84, -0.04, "smooth"), (1.0, 0.08, "linear")], u)
            wave = anim.sample([(0.0, 0.05, "smooth"), (0.17, -0.04, "smooth"), (0.34, 0.02, "smooth"), (0.5, 0.0, "smooth"), (1.0, 0.0, "linear")], u)
        bulge = anim.sample([(0.0, 0.12, "smooth"), (0.2, 0.0, "smooth"), (0.67, 0.08, "smooth"), (0.84, 0.06, "smooth"), (1.0, 0.0, "linear")], u)
        bc = 0.25
    else:
        s = (t - c) / (1.0 - c)
        sq = anim.sample([(0.0, 1.20 if run else 1.16, "out"), (0.45, 1.0, "smooth"), (0.8, 1.02, "in"), (1.0, 1.10 if run else 1.07, "linear")], s)
        lean = anim.sample([(0.0, 0.10 if run else 0.07, "out"), (0.5, 0.02, "smooth"), (1.0, 0.07 if run else 0.06, "linear")], s)
        wave = 0.02 * math.sin(math.pi * s)
        bulge = anim.sample([(0.0, 0.0, "smooth"), (0.5, -0.04, "smooth"), (1.0, 0.0, "linear")], s)
        bc = 0.6
    return _soft(body, sq=sq, lean=lean, wave=wave, phase=2.0 * math.pi * t, bulge=bulge, bc=bc)


# -- gliding (a hover form)
def glide_root(body, gait, t):
    g = GLIDES[gait]
    return (0.0, 0.0, body.hover + g["bob"] * body.H * math.sin(2.0 * math.pi * t))


def glide_soft(body, gait, t):
    g = GLIDES[gait]
    turn = 2.0 * math.pi * t
    return _soft(body, sq=1.0 + 0.03 * math.sin(turn + 1.0), lean=g["lean"] + 0.02 * math.sin(turn), wave=0.03 * math.sin(turn + 0.4), phase=turn,
                 bulge=0.05 * math.sin(math.pi * t) ** 2, bc=0.2 + 0.6 * t)


# -- the attack: the coil (held), the lunge, the impact squash
def _swing(windup, mid, hit, follow, settle=None, rest=0.0):
    settle = follow * -0.4 if settle is None else settle
    return [(0.0, rest, "out"), (T_WIND, windup, "smooth"), (T_HOLD, windup, "in"), (T_MID, mid, "linear"), (T_HIT, hit, "out"),
            (T_FOLLOW, follow, "smooth"), (T_SETTLE, settle, "smooth"), (T_END, rest, "smooth")]


LUNGE = {   # offsets from the rest, the root's in body widths and heights
    "sq": _swing(-0.30, 0.30, -0.24, 0.10, -0.04), "lean": _swing(-0.12, 0.16, 0.12, -0.05, 0.02),
    "bulge": _swing(0.10, -0.04, 0.12, 0.0, 0.0), "wave": _swing(0.03, -0.05, 0.05, -0.03, 0.01),
    "x": _swing(-0.06, 0.26, 0.34, 0.24, 0.08), "z": _swing(0.0, 0.16, 0.0, 0.0, 0.0),
}
SLAM = {    # the stiff ones: a short heavy rock back, a hop up, a slam down
    "sq": _swing(-0.10, 0.06, -0.10, 0.03, -0.01), "lean": _swing(-0.10, 0.10, 0.03, -0.02, 0.0),
    "bulge": _swing(0.0, 0.0, 0.04, 0.0, 0.0), "wave": _swing(0.0, 0.0, 0.0, 0.0, 0.0),
    "x": _swing(-0.04, 0.18, 0.26, 0.20, 0.06), "z": _swing(0.0, 0.30, 0.0, 0.03, 0.0),
}
REACH = {   # a form that strikes with an appendage stays mostly put: the body coils and pushes, the chain does the hitting
    "sq": _swing(-0.22, 0.16, -0.14, 0.06, -0.02), "lean": _swing(-0.10, 0.12, 0.10, -0.03, 0.01),
    "bulge": _swing(0.06, 0.0, 0.08, 0.0, 0.0), "wave": _swing(0.02, -0.04, 0.03, -0.02, 0.0),
    "x": _swing(-0.04, 0.06, 0.10, 0.06, 0.02), "z": _swing(0.0, 0.0, 0.0, 0.0, 0.0),
}
LASH = _swing(-55.0, 40.0, 75.0, 30.0, -10.0)     # degrees a striking chain swings forward (+) from its rest: back on the coil, whipping through


def attack_style(body):
    return body.form.get("attack", "slam" if body.stiff < 0.6 else "lunge")


def attack_soft_root(body, t):
    style = attack_style(body)
    keys = SLAM if style == "slam" else (REACH if style in ("lash", "throw", "pulse") else LUNGE)
    s0, r0 = _rest(body)
    ch = {name: anim.sample(k, t) for name, k in keys.items()}
    soft = dict(s0)
    soft["sq"] = s0["sq"] + ch["sq"] * (body.stiff if style != "slam" else 1.0)
    soft["lean"] = s0["lean"] + ch["lean"] * (body.stiff if style != "slam" else 1.0)
    soft["bulge"] = s0["bulge"] + ch["bulge"]
    soft["bc"] = 0.35
    soft["wave"] = s0["wave"] + ch["wave"] * body.stiff
    root = (r0[0] + ch["x"] * body.width, 0.0, r0[2] + ch["z"] * body.H)
    if t >= T_END:
        soft, root = dict(s0), r0
    return soft, root


# -- the flinch: a squash, a jiggle
HURT = {
    "sq": [(0.0, 0.0, "out"), (0.04, -0.26, "out"), (0.10, 0.14, "smooth"), (0.16, -0.06, "smooth"), (0.21, 0.0, "smooth")],
    "lean": [(0.0, 0.0, "out"), (0.04, -0.10, "out"), (0.10, 0.05, "smooth"), (0.16, -0.02, "smooth"), (0.21, 0.0, "smooth")],
    "wave": [(0.0, 0.0, "out"), (0.04, 0.05, "out"), (0.10, -0.04, "smooth"), (0.16, 0.02, "smooth"), (0.21, 0.0, "smooth")],
    "x": [(0.0, 0.0, "out"), (0.04, -0.06, "out"), (0.10, -0.09, "smooth"), (0.16, -0.03, "smooth"), (0.21, 0.0, "smooth")],
    "blink": [(0.0, 1.0, "out"), (0.04, 0.25, "out"), (0.10, 0.3, "smooth"), (0.16, 0.8, "smooth"), (0.21, 1.0, "smooth")],
}


def hurt_soft_root(body, t):
    s0, r0 = _rest(body)
    ch = {name: anim.sample(k, t) for name, k in HURT.items()}
    soft = dict(s0)
    soft["sq"] = s0["sq"] + ch["sq"] * body.stiff ** 0.5
    soft["lean"] = s0["lean"] + ch["lean"] * body.stiff
    soft["wave"] = s0["wave"] + ch["wave"] * body.stiff
    return soft, (r0[0] + ch["x"] * body.width, 0.0, r0[2]), ch["blink"]


# -- the death: a collapse into a puddle that settles
DIE = {   # per DIE_FRAMES: shudder up, give, sag, spread, puddle, settle, still
    "sq":   [1.0, 1.14, 0.74, 0.48, 0.32, 0.25, 0.22, 0.22],
    "vol":  [1.0, 1.0, 0.96, 0.86, 0.72, 0.62, 0.56, 0.56],
    "lean": [0.0, -0.06, 0.05, -0.03, 0.02, -0.01, 0.0, 0.0],
    "wave": [0.0, 0.03, -0.04, 0.03, -0.015, 0.006, 0.0, 0.0],
    "drop": [0.0, -0.1, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0],     # how far a hovering form has fallen to the ground
    "eyes": [1.0, 1.0, 0.5, 0.25, 0.15, 0.12, 0.12, 0.12],
}
STIFF_DIE = {   # the cube and the talos crack and slump rather than melt
    "sq":   [1.0, 1.04, 0.96, 0.80, 0.66, 0.58, 0.56, 0.56],
    "vol":  [1.0, 1.0, 1.0, 0.96, 0.9, 0.86, 0.85, 0.85],
    "lean": [0.0, -0.03, 0.03, 0.08, 0.10, 0.11, 0.11, 0.11],
    "wave": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "drop": [0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0],
    "eyes": [1.0, 1.0, 0.6, 0.3, 0.2, 0.15, 0.15, 0.15],
}


def die_channels(body, i):
    table = STIFF_DIE if body.stiff < 0.6 else DIE
    return {k: v[i] for k, v in table.items()}


# ---- the loose parts: groups moved per frame ---------------------------------------------------------------------------------------------
def _eyes(off, blink):
    if blink != 1.0:
        off["eyes"] = dict(sz=blink)


def specials(body, clip, i, t, n, soft, root):
    """{group: offset} for the form's loose parts on frame i (time t, of n frames) of a clip: pebbles orbiting and thrown, a cloud churning and
    dispersing, a crown, a pulse, plates clattering, cracks, bubbles rising, a lid biting."""
    f = body.form
    off = {}
    H, W = body.H, body.width
    turn = 2.0 * math.pi * (t if clip in ("idle", "walk", "run") else 0.0)
    for g, pivot in body.groups.items():
        if g.startswith("pebble"):
            k = int(g[6:] or 0)
            dz = 0.05 * H * math.sin(turn + 1.7 * k)
            dx = 0.02 * W * math.cos(turn + 1.7 * k)
            if clip == "attack" and k == 0:
                fly = anim.sample([(0.0, 0.0, "out"), (T_WIND, -0.08, "smooth"), (T_HOLD, -0.10, "in"), (T_MID, 0.5, "linear"), (T_HIT, 1.0, "linear"), (T_FOLLOW, 1.3, "linear")], t)
                dx += fly * W
                dz += anim.sample([(0.0, 0.0, "smooth"), (T_HOLD, 0.25, "in"), (T_HIT, 0.05, "linear")], t) * H
                if t >= T_FOLLOW - 1e-9 and t < T_END:
                    off[g] = dict(d=(dx, dz), s=0.0)
                    continue
                if t >= T_END:
                    dx, dz = 0.0, 0.0
            if clip == "die":
                fall = anim.sample([(DIE_FRAMES[1][0], 0.0, "in"), (DIE_FRAMES[3][0], 1.0, "out"), (DIE_FRAMES[4][0], 0.92, "out"), (DIE_FRAMES[5][0], 1.0, "linear")], t)
                ground = -(pivot[2] + root[2]) + f.get("pebble_r", 0.03)
                dz = fall * ground
                dx = 0.04 * W * (k - 1) * fall
            off[g] = dict(d=(dx, dz))
        elif g.startswith("puff"):
            k = int(g[4:] or 0)
            churn = 0.012 * W
            dx, dz, s = churn * math.cos(turn * 2 + 1.3 * k), churn * math.sin(turn * 2 + 1.3 * k), 1.0 + 0.05 * math.sin(turn + k)
            if clip == "die":
                spread = anim.sample([(DIE_FRAMES[1][0], 0.0, "in"), (DIE_FRAMES[5][0], 1.0, "out")], t)
                dx += spread * (pivot[0] * 1.6 + 0.1 * W * (k % 3 - 1))
                dz += spread * 0.15 * H * (1 + k % 2) + (body.hover - root[2])     # the cloud stays up as the rider drops out of it
                s = max(0.0, 1.0 - 1.05 * spread)
            elif clip == "walk" or clip == "run":
                dx -= 0.03 * W * (k % 2)
            off[g] = dict(d=(dx, dz), s=s)
        elif g == "crown":
            if clip == "die":
                fall = anim.sample([(DIE_FRAMES[1][0], 0.0, "in"), (DIE_FRAMES[4][0], 1.0, "out")], t)
                carried = pivot[2] + anchor_offset(soft, body.shape, pivot)[2] + root[2]     # where the collapsing body has let it down to
                off[g] = dict(d=(-0.35 * W * fall, fall * (0.05 - carried)), a=-75.0 * fall)
        elif g == "pulse":
            if clip == "attack":
                grow = anim.sample([(T_HOLD, 0.0, "linear"), (T_HIT, 0.55, "linear"), (T_FOLLOW, 1.15, "out"), (T_SETTLE, 1.5, "linear")], t)
                off[g] = dict(s=grow if T_HOLD < t < T_SETTLE else 0.0)
            else:
                off[g] = dict(s=0.0)
        elif g.startswith("plate"):
            k = int(g[5:] or 0)
            if clip == "die":
                fall = anim.sample([(DIE_FRAMES[2][0], 0.0, "in"), (DIE_FRAMES[4][0], 1.0, "out"), (DIE_FRAMES[5][0], 0.9, "out"), (DIE_FRAMES[6][0], 1.0, "linear")], t)
                side = 1.0 if pivot[0] >= 0 else -1.0
                off[g] = dict(d=(side * 0.18 * W * fall, -fall * 0.25 * H * (pivot[2] / H)), a=side * 40.0 * fall * (1 + 0.3 * k))
        elif g == "crack":
            if clip == "die":
                off[g] = dict(s=anim.sample([(DIE_FRAMES[0][0], 0.0, "linear"), (DIE_FRAMES[1][0], 0.6, "out"), (DIE_FRAMES[3][0], 1.0, "linear")], t))
            else:
                off[g] = dict(s=0.0)
        elif g.startswith("bubble"):
            k = int(g[6:] or 0)
            rise = ((t if clip in ("idle", "walk", "run") else 0.0) + 0.33 * k) % 1.0
            span = f.get("bubble_rise", 0.3) * H
            off[g] = dict(d=(0.0, span * (rise - 0.5)), s=math.sin(math.pi * rise) ** 0.5)
        elif g.startswith("spark"):
            k = int(g[5:] or 0)
            tw = 0.5 + 0.5 * math.sin(2.0 * math.pi * (t * 2 if clip in ("idle", "walk", "run") else 0.0) + 2.1 * k)
            off[g] = dict(s=0.4 + 0.6 * tw, d=(0.0, 0.03 * H * math.sin(turn + k)))
            if clip == "die":
                off[g] = dict(s=max(0.0, 1.0 - 2.0 * t / DIE_FRAMES[-1][0]))
    return off


def lid_angle(body, clip, t):
    """How far a mimic's lid is open, degrees: a little in its breathing, wide on the coil, snapped shut on the bite."""
    if clip == "attack":
        return anim.sample([(0.0, 4.0, "out"), (T_WIND, 48.0, "smooth"), (T_HOLD, 52.0, "in"), (T_MID, 30.0, "linear"), (T_HIT, -2.0, "out"),
                            (T_FOLLOW, 8.0, "smooth"), (T_SETTLE, 2.0, "smooth"), (T_END, 4.0, "smooth")], t)
    if clip == "idle":
        return 4.0 + 4.0 * math.sin(2.0 * math.pi * t) ** 2
    if clip in ("walk", "run"):
        return 6.0 + 10.0 * max(0.0, math.sin(2.0 * math.pi * t))
    if clip == "hurt":
        return anim.sample([(0.0, 4.0, "out"), (0.04, 22.0, "out"), (0.10, 10.0, "smooth"), (0.21, 4.0, "smooth")], t)
    if clip == "die":
        return anim.sample([(0.0, 4.0, "out"), (DIE_FRAMES[2][0], 30.0, "smooth"), (DIE_FRAMES[5][0], 12.0, "smooth")], t)
    return 4.0


def _deliberate(body, clip, times):
    """What each chain does on purpose in a clip, degrees: the idle's slow sway rolling along it, the attack's lash, the death's droop."""
    lasher = body.form.get("lash")
    period = {"idle": IDLE_SECONDS}.get(clip, None)

    def fn(ch, li, i):
        t = times[i]
        sway = ch.get("sway", 6.0)
        out = 0.0
        if clip in ("idle", "walk", "run"):
            out += sway * math.sin(2.0 * math.pi * t + 0.9 * li + ch.get("phase", 0.0))
        if ch["name"] == "lid":
            return lid_angle(body, clip, t) * (1 if li == 0 else 0)
        if clip == "attack" and ch["name"] == lasher:
            out += anim.sample(LASH, t) * (1.0 if li == 0 else 0.6) * ch.get("lash_sign", 1.0)
        if clip == "attack" and ch["name"] != lasher:
            out += anim.sample(_swing(-8.0, 6.0, 10.0, 3.0, -1.0), t) * ch.get("lash_sign", 1.0)
        if clip == "die":
            droop = anim.sample([(0.0, 0.0, "in"), (DIE_FRAMES[2][0], 0.3, "smooth"), (DIE_FRAMES[5][0], 1.0, "smooth")], t)
            out += droop * ch.get("droop", 0.0) * (1.0 if li == 0 else 0.5)
        return out
    return fn, period


def _assemble(body, clip, times, softs, roots, durations, periodic, blinks=None, rest_frame=None):
    frames = []
    n = len(times)
    for i, (t, s, r) in enumerate(zip(times, softs, roots)):
        off = specials(body, clip, i, t, n, s, r)
        if blinks is not None:
            _eyes(off, blinks[i])
        frames.append((_frame(s, off), r))
    inner = body.form.get("inner")
    if inner is not None:
        lag = _lagged(body, frames, durations, periodic, inner, gain=body.form.get("inner_gain", 1.4))
        for (rot, _), d in zip(frames, lag):
            rot[SOFT].setdefault("off", {})["inner"] = dict(d=d)
    if rest_frame is not None:
        rest_off = rest_frame[0][SOFT].get("off", {})
        if "inner" in rest_off:
            frames[-1][0][SOFT].setdefault("off", {})["inner"] = dict(rest_off["inner"])
    fn, _ = _deliberate(body, clip, times)
    chain_rots(body, frames, durations, periodic, fn, rest_frame)
    if rest_frame is not None:     # the last frame is exactly the pose the idle starts from
        frames[-1] = ({k: (dict(v) if isinstance(v, dict) else v) for k, v in rest_frame[0].items()}, tuple(rest_frame[1]))
    _clear_floor(body, frames)
    return frames


def _clear_floor(body, frames):
    """Raise any chain that has swung down through the floor (a drip, a tentacle in a deep squash): nothing may be below the ground, and a chain
    keeps its bones `clear` above it (its own thickness, so the flesh drawn round the bone stays above the ground too)."""
    for rot, root in frames:
        for ch in body.chains:
            clearance = ch.get("clear", CLEAR)
            first = ch["bones"][0]
            base = rot[first][1]

            def low(theta):
                rot[first] = (0.0, base + theta, 0.0)
                posed = pose_bones(body, rot, root)
                return min(posed[b][1][1] for b in ch["bones"])     # the tails: the root is on the body, however low it is squashed
            # the smallest turn of the whole chain about its root, either way, that lifts it clear; failing that, the turn that lifts it most
            best, best_low = 0.0, low(0.0)
            if best_low < clearance:
                for step in range(1, 91):
                    for theta in (2.0 * step, -2.0 * step):
                        z = low(theta)
                        if z > best_low:
                            best, best_low = theta, z
                    if best_low >= clearance:
                        break
            rot[first] = (0.0, base + best, 0.0)


def idle_clip(body):
    n = IDLE_FRAMES
    dur = [IDLE_SECONDS / n] * n
    times = [i / n for i in range(n)]
    blinks = [1.0] * n
    blinks[5] = 0.2      # a blink, once a loop
    frames = _assemble(body, "idle", times, [idle_soft(body, t) for t in times], [idle_root(body, t) for t in times], dur, True, blinks)
    return Clip(frames, dur, True)


def hop_clip(body, gait, cycle, length):
    g = HOPS[gait]
    n = g["frames"]
    dur = [cycle / n] * n
    times = [i / n for i in range(n)]
    softs = [hop_soft(body, gait, t) for t in times]
    roots = [hop_root(body, gait, t, length) for t in times]
    return Clip(_assemble(body, gait, times, softs, roots, dur, True), dur, True)


def glide_clip(body, gait):
    g = GLIDES[gait]
    n = g["frames"]
    dur = [g["cycle"] / n] * n
    times = [i / n for i in range(n)]
    return Clip(_assemble(body, gait, times, [glide_soft(body, gait, t) for t in times], [glide_root(body, gait, t) for t in times], dur, True), dur, True)


def attack_clip(body, rest_frame):
    dur = [d for _, d in FRAMES]
    times = [t for t, _ in FRAMES]
    pairs = [attack_soft_root(body, t) for t in times]
    return Clip(_assemble(body, "attack", times, [p[0] for p in pairs], [p[1] for p in pairs], dur, False, rest_frame=rest_frame), dur, False)


def hurt_clip(body, rest_frame):
    dur = [d for _, d in HURT_FRAMES]
    times = [t for t, _ in HURT_FRAMES]
    trip = [hurt_soft_root(body, t) for t in times]
    return Clip(_assemble(body, "hurt", times, [p[0] for p in trip], [p[1] for p in trip], dur, False, [p[2] for p in trip], rest_frame), dur, False)


def die_clip(body):
    dur = [d for _, d in DIE_FRAMES]
    times = [t for t, _ in DIE_FRAMES]
    softs, roots, blinks = [], [], []
    s0, r0 = _rest(body)
    for i in range(len(times)):
        ch = die_channels(body, i)
        softs.append(dict(s0, sq=ch["sq"], vol=ch["vol"], lean=ch["lean"], wave=ch["wave"], phase=1.0 + i, bulge=0.0))
        roots.append((0.0, 0.0, r0[2] * (1.0 - max(0.0, min(1.0, ch["drop"]))) if body.hover else 0.0))
        blinks.append(ch["eyes"])
    return Clip(_assemble(body, "die", times, softs, roots, dur, False, blinks), dur, False)


def clips_for(body, speed, ppu):
    """{name: Clip} for a slime whose everyday speed is `speed` game px/s, drawn at `ppu` pixels to the unit."""
    idle = idle_clip(body)
    rest_frame = idle.frames[0]
    if body.hover:
        walk, run = glide_clip(body, "walk"), glide_clip(body, "run")
    else:
        walk = hop_clip(body, "walk", *plan_hop(body, "walk", speed, ppu))
        run = hop_clip(body, "run", *plan_hop(body, "run", speed * RUN_SPEED, ppu))
    return {"idle": idle, "walk": walk, "run": run, "attack": attack_clip(body, rest_frame), "hurt": hurt_clip(body, rest_frame), "die": die_clip(body)}
