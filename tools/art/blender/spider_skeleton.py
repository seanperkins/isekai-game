"""The skeleton of a spider (the spider family), as data, in standard coordinates: about 1.3 units from the fangs to the end of the abdomen, facing
+x, ground at z 0. The kit builds the armature and the meshes from it, the motion code and its tests read the same numbers. Pure Python.

A spider is a cephalothorax (`body`, the root: its head is the pedicel, where the abdomen hangs), an `abdomen` behind it, chelicerae (`fang`) and two
palps in front, and eight legs, four pairs numbered from the front (0) to the back (3), on the near side (n, y < 0, the side the camera sees) and the far
side (f). A leg is a femur rising to a high knee (`fem_`), a tibia down to the ankle (`tib_`) and a tarsus to the claw (`tar_`), whose tip is the foot.
A drider (`drider=dict(...)`) has a person's upper body rising from the front of the cephalothorax: `waist`, `chest`, `head`, two arms (`arm_`,
`fore_`, `item_`), hair (`hair1`, `hair2`) and a hanging cloth (`cloth1`, `cloth2`). A swarm (`swarm=True`) has four bones the spiderlings of its
crumbling rear ride on.

Proportions (all 1.0 by default): `span` the legs' length, `ride` how high the body is carried, `thorax` the cephalothorax's size, `abdomen` the
abdomen's size, `abd_len` its length against its height, `abd_lift` how far (degrees) it is carried up behind, `tars` the tarsus's length.
`shape(...)` gives the meshes' sizes and the hull: points of the meshes, each on its bone, that must never go below the ground.
"""
import math

import skeleton2d

PAIRS = 4
SIDES = (("n", -1.0), ("f", 1.0))
TIP_Z = 0.012     # the claw's bone end stands this high at rest; the mesh's own tip is the foot
# per pair, front to back: where the hip sits along the cephalothorax (of its half length), where the foot stands (from the thorax's middle, of
# `span`), the tarsus's direction (degrees from straight down, forward positive), how high the knee rises above the hip (of `span`)
HIP_AT = (0.80, 0.30, -0.15, -0.55)
FOOT_AT = (0.60, 0.36, -0.42, -0.80)
FEMUR = 0.86      # the femur's length against the tibia's, in side view
TARSUS_DIR = (34.0, 16.0, -14.0, -30.0)
KNEE_UP = (0.32, 0.35, 0.37, 0.34)
BEND = (1, 1, -1, -1)  # the knee is above the hip-to-ankle line: the IK bends a forward leg one way and a backward one the other
LEGS = ["%s%d" % (s, i) for i in range(PAIRS) for s, _ in SIDES]

DEFAULTS = dict(span=1.0, ride=1.0, thorax=1.0, abdomen=1.0, abd_len=1.0, abd_lift=20.0, tars=1.0, drider=None, swarm=False, abd_h=1.0)
DRIDER = dict(tall=1.0, lean=4.0, hair=1.0, cloth=1.0, broad=1.0)


def proportions_of(form):
    """The skeleton's proportions as a form (spider_forms.FORMS) names them: everything else in a form is colour, gear or motion."""
    out = {k: form.get(k, v) for k, v in DEFAULTS.items()}
    if out["drider"] is not None:
        out["drider"] = dict(DRIDER, **out["drider"])
    return out


def _dir(angle):
    """A unit vector (x, z) pointing `angle` degrees from straight down, forward positive."""
    a = math.radians(angle)
    return math.sin(a), -math.cos(a)


def shape(span=1.0, ride=1.0, thorax=1.0, abdomen=1.0, abd_len=1.0, abd_lift=20.0, tars=1.0, drider=None, swarm=False, abd_h=1.0):
    """The sizes the meshes are built to, in standard coordinates: the thorax's centre and half sizes, the pedicel, the abdomen's axis (from the pedicel,
    its direction), its half length, half width and half height, and the height the body rides at (raised when a big abdomen would drag)."""
    th = thorax
    xc, T = 0.10, 0.165 * th
    ax, ay, az = 0.30 * abdomen * abd_len, 0.245 * abdomen, 0.265 * abdomen * abd_h
    a_dir = -(90.0 + abd_lift)
    # the abdomen's lowest point is to clear the ground by a margin when the body rides at its usual height
    hc = 0.30 * ride
    ux, uz = _dir(a_dir)
    low = hc + 0.02 + 0.95 * ax * uz - az * math.cos(math.radians(abd_lift)) * 1.02
    hc += max(0.0, 0.14 * ride - low)
    pedicel = (xc - 0.95 * T, hc + 0.02)
    centre = (pedicel[0] + 0.95 * ax * ux, pedicel[1] + 0.95 * ax * uz)
    return dict(xc=xc, T=T, th_h=0.12 * th, th_w=0.14 * th, hc=hc, pedicel=pedicel, a_dir=a_dir, a_centre=centre, ax=ax, ay=ay, az=az)


LEG_SCALE = 1.14   # a spider's legs are long: the span a form names is of a body this much leggier


def leg_points(i, s, span, tars, sh):
    """(hip, knee, ankle, tip) of leg pair `i` on side sign `s`, as (x, y, z)."""
    span = span * LEG_SCALE
    xc, T, hc = sh["xc"], sh["T"], sh["hc"]
    hip = (xc + HIP_AT[i] * T * 1.1, s * 0.09 * sh["th_w"] / 0.12, hc - 0.03)
    spread = (0.07 if i < 2 else -0.07) * span if s > 0 else 0.0       # the far legs splay a little wider, so eight legs do not draw as four
    tip = (xc + FOOT_AT[i] * span + spread, s * 0.52 * span, TIP_Z)
    tl = 0.15 * span * tars
    dx, dz = _dir(TARSUS_DIR[i])
    ankle = (tip[0] - tl * dx, s * 0.48 * span, tip[2] - tl * dz)
    # the knee: high above the hip, most of the way out toward the ankle, so the leg arcs up and over
    kz = hip[2] + KNEE_UP[i] * span + 1.1 * max(0.0, hc - 0.30 * span) + (0.03 * span if s > 0 else 0.0)   # a body carried high arches its knees higher still
    # its x: where the femur is FEMUR times as long as the tibia in side view, so the leg can fold well up before the knee shuts
    lo, hi = hip[0], ankle[0] + 0.6 * (ankle[0] - hip[0])
    for _ in range(50):
        mid = 0.5 * (lo + hi)
        f = math.hypot(mid - hip[0], kz - hip[2]) - FEMUR * math.hypot(mid - ankle[0], kz - ankle[2])
        lo, hi = (lo, mid) if f > 0 else (mid, hi)
    knee = (0.5 * (lo + hi), s * 0.38 * span, kz)
    return hip, knee, ankle, tip


def drider_points(sh, tall=1.0, lean=4.0, hair=1.0, cloth=1.0, broad=1.0):
    """The upper body's joints (x, z) rising from the front of the cephalothorax."""
    xc, T, hc = sh["xc"], sh["T"], sh["hc"]
    k = tall
    waist = (xc + 0.35 * T, hc + 0.07)
    ux, uz = _dir(180.0 - lean)
    belly = (waist[0] + 0.15 * k * ux, waist[1] + 0.15 * k * uz)
    neck = (belly[0] + 0.22 * k * ux, belly[1] + 0.22 * k * uz)
    crown = (neck[0] + 0.03 * k, neck[1] + 0.17 * k)
    shoulder = (neck[0] - 0.01 * k, neck[1] - 0.03 * k)
    elbow = (shoulder[0] + 0.01 * k, shoulder[1] - 0.15 * k)
    hand = (elbow[0] + 0.04 * k, elbow[1] - 0.13 * k)
    return dict(waist=waist, belly=belly, neck=neck, crown=crown, shoulder=shoulder, elbow=elbow, hand=hand)


def core(span=1.0, ride=1.0, thorax=1.0, abdomen=1.0, abd_len=1.0, abd_lift=20.0, tars=1.0, drider=None, swarm=False, abd_h=1.0):
    """[(name, head, tail, parent)] in standard coordinates (x, y, z), parents first."""
    sh = shape(span, ride, thorax, abdomen, abd_len, abd_lift, tars, drider, swarm, abd_h)
    xc, T, hc = sh["xc"], sh["T"], sh["hc"]
    p = sh["pedicel"]
    ux, uz = _dir(sh["a_dir"])
    tail = (p[0] + 1.9 * sh["ax"] * ux, p[1] + 1.9 * sh["ax"] * uz)
    front = (xc + T, hc)
    bones = [
        ("body", (p[0], 0.0, hc), (front[0], 0.0, front[1]), None),
        ("abdomen", (p[0], 0.0, p[1]), (tail[0], 0.0, tail[1]), "body"),
        ("fang", (front[0] - 0.01, 0.0, hc - 0.01), (front[0] + 0.03 * thorax, 0.0, hc - 0.10 * thorax), "body"),
    ]
    for s, sign in SIDES:
        bones.append(("palp_" + s, (front[0] - 0.01, sign * 0.05 * thorax, hc + 0.0), (front[0] + 0.07 * thorax, sign * 0.07 * thorax, hc - 0.07 * thorax), "body"))
    for i in range(PAIRS):
        for s, sign in SIDES:
            hip, knee, ankle, tip = leg_points(i, sign, span, tars, sh)
            k = "%s%d" % (s, i)
            bones += [("fem_" + k, hip, knee, "body"), ("tib_" + k, knee, ankle, "fem_" + k), ("tar_" + k, ankle, tip, "tib_" + k)]
    if swarm:
        # four bones the spiderlings of a crumbling rear ride on, spread over the back half of the abdomen
        c = sh["a_centre"]
        for j, (u, v) in enumerate(((-0.55, 0.95), (-1.1, 0.55), (-1.3, -0.05), (-1.05, -0.6)), 1):     # at the rear, out past the surface
            at = (c[0] + u * sh["ax"], c[1] + v * sh["az"])
            bones.append(("swarm%d" % j, (at[0] + 0.03, 0.0, at[1]), (at[0] - 0.05, 0.0, at[1] + 0.02), "abdomen"))
    if drider is not None:
        d = drider_points(sh, **drider)
        k = drider["tall"]
        bones += [
            ("waist", (d["waist"][0], 0.0, d["waist"][1]), (d["belly"][0], 0.0, d["belly"][1]), "body"),
            ("chest", (d["belly"][0], 0.0, d["belly"][1]), (d["neck"][0], 0.0, d["neck"][1]), "waist"),
            ("head", (d["neck"][0], 0.0, d["neck"][1]), (d["crown"][0], 0.0, d["crown"][1]), "chest"),
        ]
        for s, sign in SIDES:
            y = sign * 0.09 * k
            bones += [("arm_" + s, (d["shoulder"][0], y, d["shoulder"][1]), (d["elbow"][0], y, d["elbow"][1]), "chest"),
                      ("fore_" + s, (d["elbow"][0], y, d["elbow"][1]), (d["hand"][0], y, d["hand"][1]), "arm_" + s),
                      ("item_" + s, (d["hand"][0], y, d["hand"][1]), (d["hand"][0], y, d["hand"][1] + 0.08 * k), "fore_" + s)]
        hb = (d["neck"][0] - 0.02 * k, d["neck"][1] + 0.13 * k)
        h1 = (hb[0] - 0.07 * k, hb[1] - 0.10 * k * drider["hair"])
        h2 = (h1[0] - 0.04 * k, h1[1] - 0.12 * k * drider["hair"])
        bones += [("hair1", (hb[0], 0.0, hb[1]), (h1[0], 0.0, h1[1]), "head"), ("hair2", (h1[0], 0.0, h1[1]), (h2[0], 0.0, h2[1]), "hair1")]
        c0 = (d["belly"][0] - 0.05 * k, d["belly"][1])
        c1 = (c0[0] - 0.05 * k, c0[1] - 0.10 * k * drider["cloth"])
        c2 = (c1[0] - 0.03 * k, c1[1] - 0.09 * k * drider["cloth"])
        bones += [("cloth1", (c0[0], 0.0, c0[1]), (c1[0], 0.0, c1[1]), "waist"), ("cloth2", (c1[0], 0.0, c1[1]), (c2[0], 0.0, c2[1]), "cloth1")]
    return bones


def hull(span=1.0, ride=1.0, thorax=1.0, abdomen=1.0, abd_len=1.0, abd_lift=20.0, tars=1.0, drider=None, swarm=False, abd_h=1.0):
    """[(bone, (x, z))]: points on the meshes' undersides, each riding its bone, that must stay above the ground in a standing pose: the abdomen's
    belly and end, the cephalothorax's underside, the fangs' tips, the cloth's hem."""
    sh = shape(span, ride, thorax, abdomen, abd_len, abd_lift, tars, drider, swarm, abd_h)
    c, ax, az = sh["a_centre"], sh["ax"], sh["az"]
    lift = math.radians(-sh["a_dir"] - 90.0)
    pts = []
    for k in range(13):
        a = math.pi + math.pi * k / 12.0          # the lower half of the abdomen's outline, in its own axes
        u, v = ax * math.cos(a) * 1.03, az * math.sin(a) * 1.03
        # turn by the abdomen's lift: its axis points back and up
        x = c[0] + u * math.cos(lift) + v * math.sin(lift)
        z = c[1] - u * math.sin(lift) + v * math.cos(lift)
        pts.append(("abdomen", (x, z)))
    for k in range(5):
        a = math.pi + math.pi * k / 4.0
        pts.append(("body", (sh["xc"] + sh["T"] * 1.05 * math.cos(a), sh["hc"] + sh["th_h"] * 1.05 * math.sin(a))))
    pts.append(("fang", None))      # the fangs' tips: the end of the fang bone (filled in by hull_for)
    if drider is not None:
        d = drider_points(sh, **drider)
        pts.append(("waist", (d["waist"][0] + 0.06 * drider["tall"], d["waist"][1] - 0.10)))
    return pts


def placed(point, scale=1.0, origin=(0.0, 0.0, 0.0)):
    x, y, z = point
    return (x * scale + origin[0], y * scale + origin[1], z * scale + origin[2])


def skeleton(scale=1.0, origin=(0.0, 0.0, 0.0), **proportions):
    """The flat skeleton (skeleton2d.Skeleton2D) of a spider of these proportions."""
    rest = {}
    for name, head, tail, parent in core(**proportions):
        h, t = placed(head, scale, origin), placed(tail, scale, origin)
        rest[name] = ((h[0], h[2]), (t[0], t[2]), parent)
    return skeleton2d.Skeleton2D(rest)


def skeleton_for(form):
    return skeleton(**proportions_of(form))


SCYTHE = 2.8   # a scythe blade reaches this many tarsus lengths past the ankle (spider_gear.scythes)


def hull_for(form):
    """The hull of a form: its body's, and the points of gear that reach out past the bones (the tips of a pair of scythes)."""
    pts = hull(**proportions_of(form))
    bones = {n: (h, t) for n, h, t, _ in core(**proportions_of(form))}
    pts = [(b, p) if p is not None else (b, (bones[b][1][0], bones[b][1][2])) for b, p in pts]
    if any(name == "hair" for name, _ in form.get("gear", [])):
        # a tarantula's tufts stand out a quarter past the abdomen's outline (spider_gear.hair)
        c = shape(**proportions_of(form))["a_centre"]
        pts += [(b, (c[0] + 1.25 / 1.03 * (p[0] - c[0]), c[1] + 1.25 / 1.03 * (p[1] - c[1]))) for b, p in list(pts) if b == "abdomen"]
    if any(name == "held_cocoon" for name, _ in form.get("gear", [])):
        import spider_motion
        x, z = spider_motion.held_cocoon_at(form)
        pts.append(("tar_n0", (x, z - spider_motion.HELD_COCOON[2])))     # the bottom of the cocoon the claws clutch
    if "cloth2" in bones:
        pts.append(("cloth2", (bones["cloth2"][1][0], bones["cloth2"][1][2])))   # the hem
    if any(name == "scythes" for name, _ in form.get("gear", [])):
        for s in "nf":
            h, t = bones["tar_%s0" % s]
            pts.append(("tar_%s0" % s, (h[0] + SCYTHE * (t[0] - h[0]), h[2] + SCYTHE * (t[2] - h[2]))))
    return pts
