"""Gear for the slime kit (slime_kit.py): what each form adds to the jelly dome. A form lists its gear by name in slime_forms.py. Each function
places its parts on the body's surface (plan angle, placement elevation: kit.S, heights spread evenly) or on the form's chains of bones, and says
how the soft body moves them (skin, carry, free; see slime_kit). Glowing parts are lit whatever their shape. At about 62 px wide a part needs to be
3 px or more across to read, so parts are drawn bold.
"""
import math
import random

import bmesh
from mathutils import Vector

import rigkit as k
from slime_kit import darker, lighter, oriented_ellipsoid


def _overlap(h, t, k):
    """The (x, z) ends of a bone stretched by `k` of its length at each end, so the pieces of a chain overlap into one strip."""
    dx, dz = t[0] - h[0], t[2] - h[2]
    return (h[0] - k * dx, h[2] - k * dz), (t[0] + k * dx, t[2] + k * dz)


# ---- bound and threaded ----
def bands(g, colour, at=(22, 52, -8), tilt=12.0, vertical=None, width=8.0, **_):
    """Ribbon or brass bands round the body: loops at elevations `at` (tilted), or upright straps at plan angles `vertical`."""
    if vertical:
        for i, phi in enumerate(vertical):
            g.stripe("strap%d" % i, [(phi, a) for a in range(-88, 89, 4)], width, colour, lift=0.025)
        return
    for i, a0 in enumerate(at):
        pts = [(phi, a0 + tilt * math.sin(math.radians(phi + 50 * i))) for phi in range(-180, 181, 8)]
        g.stripe("band%d" % i, pts, width, colour, lift=0.022)
        g.stripe("bandshine%d" % i, [(p, a + width * 0.25) for p, a in pts if -170 < p < -60], width * 0.3, lighter(colour, 0.6), glow=True, lift=0.03)


def bow(g, colour, **_):
    """A bow-knot on top of the back: two loops and a knot, carried; the two loose ends flutter on their chains."""
    knot = g.S(170, 70, 0.05)
    g.blob("knot", knot, (0.045, 0.04, 0.04), colour, "carry", anchor=knot)
    for i, (dx, dz) in enumerate(((-0.15, 0.08), (0.11, 0.10))):
        g.add(oriented_ellipsoid("loop%d" % i, (knot[0], knot[2]), (knot[0] + dx, knot[2] + dz), 0.03, 0.05, knot[1] - 0.02), colour, "carry", knot)
        g.add(oriented_ellipsoid("loophole%d" % i, (knot[0] + dx * 0.35, knot[2] + dz * 0.35), (knot[0] + dx * 0.8, knot[2] + dz * 0.8), 0.03, 0.018, knot[1] - 0.05),
              darker(g.jelly, 0.3), "carry", knot)
    for b, h, t in g.chain_bones("rib_a") + g.chain_bones("rib_b"):
        a, z = _overlap(h, t, 0.2)
        g.on_bone(oriented_ellipsoid("ribbon_" + b, a, z, 0.02, 0.05, -0.12, 8, 5), b, colour)


def glints(g, colour, **_):
    for i, (phi, a) in enumerate(((-120, 30), (-60, 62), (-150, -10), (-90, 75))):
        c = g.S(phi, a, 0.04)
        g.blob("glint%d" % i, c, (0.016, 0.012, 0.016), colour, "carry", glow=True, seg=6, rings=4)


def spiral(g, colour, **_):
    """A glowing thread spiralling inside the body like a tiny labyrinth (drawn on the near surface), its end running back to the spool."""
    pts = []
    for i in range(80):
        t = i / 79.0
        ang = 2.0 * math.pi * 2.4 * t
        r = 3.0 + 34.0 * t
        pts.append((-98.0 + r * math.cos(ang) * 1.25, 18.0 + r * math.sin(ang) * 0.95))
    pts += [(-150.0, 4.0), (-168.0, 2.0), (-179.0, 2.0)]
    g.stripe("spiral", pts, 5.0, colour, glow=True, lift=0.014, group="inner")
    for b, h, t in g.chain_bones("thread"):
        g.on_bone(k.limb("thread_" + b, h, t, 0.016, 0.016, 5), b, colour, glow=True)


def spool(g, colour, **_):
    c = g.S(182, 4, -0.02)
    g.blob("spool", c, (0.07, 0.09, 0.09), colour, "carry", anchor=c)
    g.blob("spool_hub", (c[0] - 0.06, c[1] - 0.03, c[2]), (0.025, 0.06, 0.06), darker(colour, 0.3), "carry", anchor=c)


def blush(g, colour=(250, 150, 180), **_):
    g.patch("blush", (-50.0, 0.0), (9.0, 6.0), colour, lift=0.02, steps=(6, 4))


def leaves(g, colour, **_):
    """A leafy beanstalk vine curling up from the back: a thick stem on the vine's bones, two broad leaves and a little tendril."""
    dark = darker(colour, 0.22)
    root = g.S(150, 70, -0.1)
    bones = g.chain_bones("vine")
    g.blob("vine_root", root, (0.06, 0.05, 0.06), colour, "carry", anchor=root)
    y = -0.06
    for i, (b, h, t) in enumerate(bones):
        r0, r1 = 0.06 - 0.01 * i, 0.05 - 0.01 * i
        h, t = (h[0], y, h[2]), (t[0], y, t[2])
        g.on_bone(k.limb("stem_" + b, h, t, r0, r1, 7, smooth=True), b, colour)
        g.on_bone(k.ellipsoid("knuckle_" + b, t, (r1 * 1.05,) * 3, 7, 5), b, colour)
        if i in (1, 3):
            side = -1 if i == 1 else 1
            mx, mz = (h[0] + t[0]) / 2.0, (h[2] + t[2]) / 2.0
            tip = (mx + side * 0.30, mz + 0.10)
            g.on_bone(oriented_ellipsoid("leaf_" + b, (mx, mz), tip, 0.03, 0.09, y - 0.03, 10, 6), b, colour)
            g.on_bone(oriented_ellipsoid("leafvein_" + b, (mx + side * 0.03, mz + 0.01), (tip[0] - side * 0.03, tip[1] - 0.005), 0.03, 0.01, y - 0.06, 6, 4), b, dark)
    b, h, t = bones[-1]
    g.on_bone(k.limb("tendril", (t[0], y, t[2]), (t[0] + 0.06, y, t[2] + 0.05), 0.012, 0.007, 4), b, colour)
    g.on_bone(k.limb("tendril2", (t[0] + 0.06, y, t[2] + 0.05), (t[0] + 0.09, y, t[2] + 0.0), 0.008, 0.004, 4), b, colour)


def beans(g, colour, **_):
    for i, (x, z, ang) in enumerate(((-0.20, 0.34, 25), (0.10, 0.20, -30))):
        c = g.near(x, z, 0.10)
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        g.add(oriented_ellipsoid("bean%d" % i, (c[0] - 0.13 * ca, c[2] - 0.13 * sa), (c[0] + 0.13 * ca, c[2] + 0.13 * sa), 0.04, 0.085, c[1]),
              colour, "carry", c, group="inner")
        g.blob("beaneye%d" % i, (c[0] + 0.03, c[1] - 0.045, c[2] + 0.01), (0.03, 0.01, 0.014), darker(colour, 0.35), "carry", group="inner", seg=6, rings=4, anchor=c)


def lumps(g, colour, **_):
    rng = random.Random(4)
    for i, phi in enumerate((-170, -135, -100, -65, -30, 10, 160)):
        p = g.S(phi, -82, 0.05)
        r = 0.045 + 0.02 * rng.random()
        g.blob("lump%d" % i, (p[0], p[1], r * 0.8), (r * 1.3, r, r * 0.8), colour if i % 2 else darker(colour, 0.15), "skin", seg=8, rings=5, smooth=False)


def pelt(g, colour, spots=(108, 100, 92), **_):
    """A seal pelt half shed over the rear of the back like a loose cloak: a draped patch over the rear quarter, dappled, its loose end hanging
    behind on the pelt's chain."""
    g.patch("pelt_cap", (-150.0, 52.0), (42.0, 34.0), colour, lift=0.05, steps=(14, 10))
    g.patch("pelt_cap_back", (165.0, 45.0), (30.0, 40.0), darker(colour, 0.1), lift=0.05, steps=(8, 10))
    for j, (phi, a) in enumerate(((-160, 60), (-135, 40), (-170, 30), (-125, 66))):
        g.patch("pelt_spot%d" % j, (phi, a), (6.0, 6.0), spots, lift=0.06, steps=(4, 4))
    for i, (b, h, t) in enumerate(g.chain_bones("pelt")):
        g.on_bone(oriented_ellipsoid("pelt_" + b, (h[0], h[2]), (t[0], t[2]), g.shape.D * 0.9, 0.06 - 0.015 * i, -0.02, 12, 6), b, colour if i == 0 else darker(colour, 0.1))
        g.on_bone(k.blade("pelt_rag" + b, (t[0] + 0.02, -0.1, t[2] + 0.02), (t[0] - 0.05, -0.1, t[2] - 0.06), 0.06, 0.04), b, darker(colour, 0.1))


def whiskers(g, colour, **_):
    c = g.S(-2, 4, 0.10)
    g.blob("nose", c, (0.03, 0.035, 0.024), (40, 44, 60), "carry", anchor=c)
    for i, dz in enumerate((0.035, -0.015)):
        g.cblade("whisker%d" % i, (c[0], c[1] - 0.03, c[2] + dz * 0.3), (c[0] + 0.09, c[1] - 0.04, c[2] + dz), 0.012, 0.008, colour, anchor=c, glow=True)


def droplets(g, colour, groups=False, **_):
    if groups:
        for gname, pivot in g.form.get("groups", {}).items():
            r = 0.045 if gname.endswith("0") else 0.032
            g.blob("drop_" + gname, (pivot[0], pivot[1], r * 0.8), (r * 1.3, r, r * 0.8), colour, "free", group=gname, seg=10, rings=6)
            g.blob("dropshine_" + gname, (pivot[0] - r * 0.3, pivot[1] - r, r * 1.2), (r * 0.35,) * 3, (255, 255, 255), "free", group=gname, glow=True, seg=5, rings=4)
        return
    for i, (phi, a) in enumerate(((-150, 36), (-60, 66), (-165, -20))):
        c = g.S(phi, a, 0.05)
        g.blob("droplet%d" % i, c, (0.02, 0.018, 0.028), colour, "carry", glow=True, seg=6, rings=5)


# ---- the deep ----
def swirl(g, colour, **_):
    """A whirlpool spiral inside the body, and the tentacles: thick jelly limbs on the chains, the far ones darker."""
    pts = []
    for i in range(60):
        t = i / 59.0
        ang = -2.0 * math.pi * 1.8 * t
        r = 4.0 + 32.0 * t
        pts.append((-100.0 + r * math.cos(ang) * 1.2, 10.0 + r * math.sin(ang) * 0.9))
    g.stripe("swirl", pts, 7.0, colour, lift=0.012)
    g.stripe("swirl_light", pts[::2][:18], 3.0, lighter(colour, 0.4), glow=True, lift=0.018)
    _tentacles(g, ("t_back", "t_far", "t_near", "t_front"), 0.085)


def _tentacles(g, names, r0, colour=None, taper=0.6):
    colour = colour or g.jelly
    for name in names:
        bones = g.chain_bones(name)
        far = bones[0][1][1] > 0.05
        c = darker(colour, 0.15) if far else colour
        n = len(bones)
        for i, (b, h, t) in enumerate(bones):
            a, z = r0 * (1.0 - taper * i / n), r0 * (1.0 - taper * (i + 1) / n)
            g.on_bone(k.limb("tent_" + b, h, t, a, z, 8, smooth=True), b, c, far)
            g.on_bone(k.ellipsoid("tentj_" + b, h, (a,) * 3, 8, 6), b, c, far)
            if i == n - 1:
                g.on_bone(k.ellipsoid("tenttip_" + b, t, (z,) * 3, 6, 4), b, c, far)


def suckers(g, colour, **_):
    for name in ("t_back", "t_far", "t_near", "t_front"):
        bones = g.chain_bones(name)
        n = len(bones)
        for i, (b, h, t) in enumerate(bones):
            dx, dz = t[0] - h[0], t[2] - h[2]
            L = math.hypot(dx, dz)
            nx, nz = dz / L, -dx / L
            for j in (0.25, 0.75):
                r = 0.075 * (1.0 - 0.6 * (i + j) / n)
                c = (h[0] + dx * j + nx * r * 0.7, h[1] - r * 0.7, h[2] + dz * j + nz * r * 0.7)
                g.on_bone(k.ellipsoid("sucker_%s_%d" % (b, int(j * 10)), c, (0.016,) * 3, 6, 4), b, colour)


def crest(g, colour, deep, **_):
    """A rolling crest of foaming wave along the back: tall blades of deep water topped with foam curling forward."""
    spots = [(180, 10), (180, 28), (180, 44), (180, 58), (180, 70), (180, 82), (0, 88), (0, 78)]
    for i, (phi, a) in enumerate(spots):
        root = g.S(phi, a, -0.06)
        h = 0.12 + 0.12 * math.sin(math.pi * (i + 1) / (len(spots) + 1))
        tip = (root[0] + 0.07, root[1] - 0.06, root[2] + h)
        g.add(k.blade("wave%d" % i, root, tip, 0.17, 0.12), deep, "skin")
        g.add(oriented_ellipsoid("foam%d" % i, (tip[0] - 0.07, tip[2] - 0.01), (tip[0] + 0.08, tip[2] - 0.06), 0.07, 0.045, root[1] - 0.08, 8, 5), colour, "skin")


def horns(g, colour, **_):
    for i, phi in enumerate((-40, 20)):
        base = g.S(40 + phi, 78, -0.03)
        y = base[1]
        mid = (base[0] - 0.02, y, base[2] + 0.15)
        tip = (mid[0] - 0.12, y, mid[2] + 0.08)
        c = colour if phi < 0 else darker(colour, 0.25)
        g.add(k.limb("horn%d" % i, base, mid, 0.05, 0.035, 7), c, "carry", base, far=phi > 0)
        g.add(k.limb("horntip%d" % i, mid, tip, 0.035, 0.0, 7), c, "carry", base, far=phi > 0)


def serpents(g, colour, **_):
    """Small sea-serpent shapes coiling inside: S-curves in a lighter teal, each with a head."""
    for j, (p0, a0) in enumerate(((-160.0, 30.0), (-120.0, -20.0), (-95.0, 50.0))):
        pts = [(p0 + 36.0 * t, a0 + 12.0 * math.sin(2.0 * math.pi * 1.1 * t)) for t in (i / 17.0 for i in range(18))]
        g.stripe("serpent%d" % j, pts, 5.0, colour, lift=0.014)
        c = g.S(pts[-1][0] + 2, pts[-1][1], 0.03)
        g.blob("serpenthead%d" % j, c, (0.02, 0.012, 0.016), colour, "skin", seg=6, rings=4)


# ---- acid and blight ----
def bubbles(g, colour, **_):
    for gname, pivot in sorted(g.form.get("groups", {}).items()):
        if gname.startswith("bubble"):
            c = g.near(pivot[0], pivot[2], 0.04)
            r = 0.03 if gname[-1] != "2" else 0.022
            g.blob(gname, c, (r, r * 0.8, r), colour, "carry", group=gname, glow=True, seg=8, rings=6, anchor=c)
    for i, (x, z, r) in enumerate(((-0.25, 0.16, 0.022), (0.24, 0.44, 0.018), (-0.05, 0.50, 0.02), (0.30, 0.14, 0.016))):
        c = g.near(x, z, 0.04)
        g.blob("fizz%d" % i, c, (r, r * 0.8, r), colour, "skin", glow=True, seg=6, rings=4)


def flecks(g, colour, **_):
    rng = random.Random(7)
    for i in range(9):
        p = g.S(-165 + 150 * rng.random(), -40 + 90 * rng.random(), 0.02)
        g.blob("fleck%d" % i, p, (0.024, 0.014, 0.02), colour if i % 2 else darker(colour, 0.2), "skin", seg=5, rings=4, smooth=False)


def drips(g, colour, **_):
    for name in ("drip_a", "drip_b", "drip_c"):
        bones = g.chain_bones(name)
        for i, (b, h, t) in enumerate(bones):
            g.on_bone(k.limb("drip_" + b, (h[0], -0.2, h[2]), (t[0], -0.2, t[2]), 0.05 - 0.012 * i, 0.034 - 0.01 * i, 7, smooth=True), b, colour)
        b, h, t = bones[-1]
        g.on_bone(k.ellipsoid("drop_" + b, (t[0], -0.2, t[2]), (0.04, 0.035, 0.05), 8, 6), b, lighter(colour, 0.2))
    for i, phi in enumerate((-150, -110, -60, -20)):
        p = g.S(phi, -78, 0.04)
        g.blob("hang%d" % i, (p[0], p[1], 0.03), (0.03, 0.03, 0.03), colour, "skin", seg=6, rings=5)


def blotches(g, colour, **_):
    """Mottled patches of toxic glow inside the murky jelly."""
    for i, (phi, a, rp, ra) in enumerate(((-120, -10, 20, 16), (-80, 20, 12, 10), (-150, 30, 10, 12), (-60, -30, 14, 9), (-100, 50, 8, 6))):
        g.patch("blotch%d" % i, (phi, a), (rp, ra), colour if i % 2 == 0 else darker(colour, 0.25), lift=0.012, steps=(8, 6))


def boils(g, colour, **_):
    for i, (phi, a, r) in enumerate(((-110, 50, 0.06), (-55, 10, 0.045), (-150, 5, 0.055), (165, 60, 0.05), (-85, 75, 0.04), (-30, -40, 0.04))):
        c = g.S(phi, a, -0.02)
        g.blob("boil%d" % i, c, (r, r, r), colour, "skin", seg=8, rings=6)
        hl = g.S(phi - 5, a + 8, r * 1.1)
        g.blob("boilhl%d" % i, hl, (r * 0.3,) * 3, lighter(colour, 0.5), "skin", glow=True, seg=5, rings=4)


def miasma(g, colour, dark, **_):
    for name in ("mia_a", "mia_b"):
        bones = g.chain_bones(name)
        for i, (b, h, t) in enumerate(bones):
            c = colour if (i + (name == "mia_b")) % 2 == 0 else dark
            a, z = _overlap(h, t, 0.3)
            g.on_bone(oriented_ellipsoid("mia_" + b, a, z, 0.04, 0.065 - 0.012 * i, -0.1, 8, 5), b, c)


def tatters(g, colour=None, **_):
    colour = darker(g.jelly, 0.25)
    for i, a in enumerate((-50, -20, 10, 35)):
        root = g.S(180, a, -0.06)
        g.add(k.blade("tatter%d" % i, root, (root[0] - 0.11, root[1] - 0.05, root[2] - 0.06), 0.08, 0.06), colour, "skin")


def veins(g, colour, **_):
    """A branching network of glowing veins through the body like a maze solved: trunks rise from the base and branch twice."""
    rng = random.Random(11)
    g.vein_nodes = []

    def grow(name, p, a, heading, length, depth):
        pts = [(p, a)]
        for _ in range(int(length)):
            heading += rng.uniform(-30, 30)
            heading = max(20.0, min(160.0, heading))
            p += 7.0 * math.cos(math.radians(heading))
            a += 9.0 * math.sin(math.radians(heading))
            a = min(82.0, a)
            pts.append((p, a))
        g.stripe(name, pts, 5.0 - 1.0 * depth, colour, lift=0.014)
        g.vein_nodes.append(pts[-1])
        if depth < 2:
            for j, turn in enumerate((-50, 50)):
                grow(name + str(j), p, a, heading + turn, max(3, length * 0.6), depth + 1)
    for i, p0 in enumerate((-160.0, -120.0, -80.0, -40.0)):
        grow("vein%d" % i, p0, -80.0, 90.0 + rng.uniform(-30, 30), 11, 0)


def nodes(g, colour, **_):
    for i, (p, a) in enumerate(getattr(g, "vein_nodes", [])[::2]):
        c = g.S(p, a, 0.03)
        g.blob("node%d" % i, c, (0.024, 0.014, 0.024), colour, "skin", glow=True, seg=6, rings=4)


def tendrils(g, colour, **_):
    for i, (phi, length) in enumerate(((-15, 0.20), (-50, 0.14), (12, 0.15), (-80, 0.10))):
        p = g.S(phi, -86, 0.0)
        dx = math.cos(math.radians(phi)) * length
        g.add(k.loft("tendril%d" % i, [((p[0] - 0.02, p[1] - 0.02, 0.018), (0.018, 0.03)), ((p[0] + dx * 0.6, p[1] - 0.04, 0.014), (0.012, 0.02)),
                                       ((p[0] + dx, p[1] - 0.05, 0.008), (0.004, 0.006))], "x", 6, True), colour, "skin", glow=True)


# ---- metal and stone ----
def plates(g, colour, rivet, **_):
    """Riveted bronze plates over the back and sides, each a curved patch of the surface (with a dark edge) that comes away when it dies."""
    edge = darker(colour, 0.4)
    for gname, (phi, a, rp, ra) in zip(("plate0", "plate1", "plate2", "plate3"), ((-158, 22, 26, 44), (-112, 52, 26, 30), (-62, 50, 20, 26), (-120, 86, 70, 8))):
        g.patch(gname + "_edge", (phi, a), (rp + 3.0, ra + 3.0), edge, lift=0.03, group=gname, steps=(10, 8))
        g.patch(gname, (phi, a), (rp, ra), colour, lift=0.045, group=gname, steps=(10, 8))
        for j, (dp, da) in enumerate(((-0.65, 0.55), (0.65, 0.55), (-0.65, -0.55), (0.65, -0.55))):
            c = g.S(phi + dp * rp, a + da * ra, 0.06)
            g.blob("%s_rivet%d" % (gname, j), c, (0.018,) * 3, rivet, "skin", group=gname, seg=6, rings=4)
    g.patch("plate_back_edge", (172, 40), (32, 40), edge, lift=0.03)
    g.patch("plate_back", (172, 40), (28, 36), darker(colour, 0.1), lift=0.045)


def nail(g, colour, ichor, **_):
    c = g.S(-35, -45, 0.06)
    g.blob("nail", c, (0.04, 0.03, 0.04), colour, "carry", seg=8, rings=5, smooth=False)
    g.blob("nailhead", (c[0] + 0.01, c[1] - 0.02, c[2] + 0.01), (0.018, 0.012, 0.018), lighter(colour, 0.4), "carry", seg=6, rings=4, anchor=c)
    g.stripe("ichor", [(-38, -42), (-50, -34), (-62, -26), (-76, -24), (-90, -18)], 4.0, ichor, glow=True)
    for i, pts in enumerate((((-100, -5), (-115, 10), (-112, 25)), ((-95, -20), (-125, -18), (-140, -30)))):
        g.stripe("molten%d" % i, list(pts), 4.0, ichor, glow=True, lift=0.016)


def stone(g, colour, ring, **_):
    """A faceted stone glowing at the heart of the jelly with a ring of light about it, lagging the jelly as it moves."""
    c = g.near(0.0, 0.32, 0.14)
    g.blob("stone", c, (0.15, 0.05, 0.19), colour, "carry", group="inner", glow=False, seg=6, rings=4, smooth=False, anchor=c)
    g.blob("stone_face", (c[0] - 0.03, c[1] - 0.045, c[2] + 0.035), (0.065, 0.02, 0.085), lighter(colour, 0.5), "carry", group="inner", glow=True, seg=4, rings=3,
           smooth=False, anchor=c)
    pts = [(-92.0 + 40.0 * math.cos(2 * math.pi * i / 40.0), 18.0 + 36.0 * math.sin(2 * math.pi * i / 40.0)) for i in range(41)]
    g.stripe("stone_ring", pts, 5.5, ring, glow=True, lift=0.02, group="inner", mode="skin")


def sparks(g, colour, **_):
    for gname, pivot in sorted(g.form.get("groups", {}).items()):
        if gname.startswith("spark"):
            free = g.form.get("attack") == "pulse"
            c = pivot if free else g.near(pivot[0], pivot[2], 0.05)
            mode = "free" if free else "carry"
            s = 1.3 if free else 1.0
            g.cblade(gname + "_v", (c[0], c[1], c[2] - 0.04 * s), (c[0], c[1], c[2] + 0.04 * s), 0.022, 0.012, colour, mode, gname, True, anchor=c)
            g.cblade(gname + "_h", (c[0] - 0.035 * s, c[1], c[2]), (c[0] + 0.035 * s, c[1], c[2]), 0.022, 0.012, colour, mode, gname, True, anchor=c)


def coin(g, colour, **_):
    c = g.near(-0.12, 0.46, 0.10)
    g.blob("coin", c, (0.11, 0.025, 0.11), colour, "carry", group="inner", seg=12, rings=4, anchor=c)
    g.blob("coin_mark", (c[0], c[1] - 0.025, c[2]), (0.035, 0.01, 0.065), darker(colour, 0.3), "carry", group="inner", seg=6, rings=4, anchor=c)


def bone(g, colour, **_):
    c = g.near(0.02, 0.18, 0.10)
    a, b = (c[0] - 0.14, c[2] - 0.03), (c[0] + 0.14, c[2] + 0.05)
    g.add(oriented_ellipsoid("bone_shaft", a, b, 0.025, 0.032, c[1]), colour, "carry", c, group="inner")
    for i, (x, z) in enumerate((a, b)):
        for j, dz in enumerate((-0.02, 0.02)):
            g.blob("bone_knob%d%d" % (i, j), (x, c[1], z + dz * 1.4), (0.036,) * 3, colour, "carry", group="inner", seg=6, rings=4, anchor=c)


def cracks(g, colour, **_):
    g.stripe("crack0", [(-70, 85), (-80, 62), (-70, 45), (-86, 28), (-78, 8), (-88, -12)], 4.0, colour, lift=0.02, group="crack")
    g.stripe("crack1", [(-130, 70), (-120, 48), (-136, 26), (-124, 4)], 4.0, colour, lift=0.02, group="crack")
    g.stripe("crack2", [(-80, 28), (-100, 22), (-112, 30)], 3.0, colour, lift=0.02, group="crack")


def edges(g, colour, **_):
    g.stripe("edge_top", [(phi, 80) for phi in range(-180, 1, 8)], 5.0, colour, glow=True, lift=0.014)
    g.stripe("edge_front", [(-35, a) for a in range(-85, 82, 6)], 5.0, colour, glow=True, lift=0.014)
    for i, (x, z, r) in enumerate(((0.2, 0.55, 0.02), (-0.28, 0.2, 0.016), (0.25, 0.25, 0.014))):
        c = g.near(x, z, 0.04)
        g.blob("cubebub%d" % i, c, (r, r * 0.8, r), (250, 255, 240), "skin", glow=True, seg=6, rings=4)


def _arch(name, cx, cz, rx, ry, rz, segments=20, rings=10):
    """The upper half of an ellipsoid (flat underneath): a chest lid seen from its end shows this arc."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((cx + v.co.x * rx, v.co.y * ry, cz + max(0.0, v.co.z) * rz))
    return k._object(name, bm, True)


def lid(g, colour, band, **_):
    """A chest lid on a hinge at the back of the top, arched from back to front (as a chest's end shows it), with brass straps over it and a brass
    lip; the creature's eyes look out from its front, and a row of teeth hangs from the lip."""
    (b, h, t), = g.chain_bones("lid")
    D = g.shape.D * 1.02
    x0, x1, z = h[0] - 0.03, t[0] + 0.02, h[2]
    cx, rx, rz = (x0 + x1) / 2.0, (x1 - x0) / 2.0, 0.26
    g.on_bone(_arch("lid", cx, z, rx, D, rz), b, colour)
    for i, u in enumerate((-0.62, 0.62)):
        x = cx + u * rx
        top = z + rz * math.sqrt(max(0.0, 1.0 - u * u))
        g.on_bone(k.limb("lidstrap%d" % i, (x, -D - 0.01, z), (x, -D - 0.01, top + 0.01), 0.03, 0.03, 6), b, band)
        g.on_bone(k.limb("lidstrapb%d" % i, (x, -D - 0.01, top), (x, 0.0, top + 0.02), 0.03, 0.03, 6), b, darker(band, 0.15))
    g.on_bone(k.box("lidlip", (cx, 0.0, z + 0.02), (x1 - x0 + 0.04, D * 2.1, 0.05)), b, band)
    g.on_bone(k.box("lock", (x1 + 0.01, -D * 0.5, z + 0.05), (0.04, 0.08, 0.09)), b, lighter(band, 0.25))
    for i, (dx, dz, s) in enumerate(((-0.24, 0.13, 1.0), (-0.10, 0.12, 0.92))):
        c = (x1 + dx, -D * 0.93, z + dz)
        g.on_bone(k.ellipsoid("eye%d" % i, c, (0.042 * s, 0.03, 0.072 * s), 10, 7), b, g.eye)
        g.on_bone(k.ellipsoid("eyeglint%d" % i, (c[0] - 0.012, c[1] - 0.03, c[2] + 0.03), (0.014,) * 3, 6, 4), b, (250, 252, 255), glow=True)
    for i in range(7):
        x = x1 - 0.07 - 0.12 * i
        g.on_bone(k.blade("tooth_u%d" % i, (x, -D * 0.98, z - 0.0), (x + 0.008, -D * 0.98, z - 0.08), 0.055, 0.03), b, (250, 250, 244))


def teeth(g, colour, **_):
    H = g.shape.H
    D = g.shape.D
    for i in range(6):
        x = 0.40 - 0.12 * i
        g.cblade("tooth_l%d" % i, (x - 0.06, -D * 1.0, H - 0.01), (x - 0.055, -D * 1.0, H + 0.06), 0.045, 0.03, colour, "carry", anchor=(x, -D, H))
    g.add(k.box("lip", (0.0, 0.0, H - 0.02), (2 * g.shape.R + 0.04, D * 2.08, 0.035)), (206, 170, 96), "skin")


def tongue(g, colour, **_):
    H = g.shape.H
    D = g.shape.D
    p = (0.42, -D * 0.6, H + 0.01)
    g.add(oriented_ellipsoid("tongue", (p[0] - 0.06, p[2] + 0.01), (p[0] + 0.12, p[2] - 0.07), 0.07, 0.03, p[1]), colour, "carry", p)


def wisp(g, colour, **_):
    """The rear dissolving into a short wispy tail: the body drawn out behind, then ragged wisps on the tail's chain."""
    g.add(oriented_ellipsoid("wisp_root", (-0.30, 0.22), (-0.62, 0.30), 0.26, 0.14, 0.0, 12, 8), g.jelly, "skin")
    bones = g.chain_bones("tail")
    for i, (b, h, t) in enumerate(bones):
        g.on_bone(oriented_ellipsoid("wisp_" + b, (h[0], h[2]), (t[0], t[2]), 0.16 * (1 - 0.3 * i), 0.07 * (1 - 0.25 * i), 0.0, 10, 6), b, g.jelly if i == 0 else colour)
        g.on_bone(k.blade("wisprag_" + b, (t[0] + 0.03, -0.1, t[2]), (t[0] - 0.06, -0.1, t[2] + 0.05 * (1 if i % 2 else -1)), 0.06, 0.04), b, colour)


def pebbles(g, colour, brick, **_):
    rng = random.Random(2)
    for gname, pivot in sorted(g.form.get("groups", {}).items()):
        if not gname.startswith("pebble"):
            continue
        r = g.form.get("pebble_r", 0.03)
        c = brick if gname == "pebble2" else (colour if gname != "pebble3" else darker(colour, 0.15))
        sx = 1.4 if gname == "pebble2" else 1.0 + 0.3 * rng.random()
        g.blob(gname, pivot, (r * sx, r, r * (0.8 + 0.3 * rng.random())), c, "free", group=gname, seg=6, rings=4, smooth=False, anchor=pivot)


def cloud(g, colour, shade, **_):
    """A small fluffy cloud the rider sits on: a cluster of round puffs (each a group that churns and, when it dies, drifts apart), and a swirl of a
    tail curling at the rear."""
    for gname, pivot in sorted(g.form.get("groups", {}).items()):
        if not gname.startswith("puff"):
            continue
        x, y, z = pivot
        back = y > 0.0
        k_ = int(gname[4:])
        r = 0.13 if not back else 0.12
        h = g.form["puff_h"]
        if k_ >= 6:      # the tail curling up at the rear: smaller puffs, the last curled over
            r, h = 0.085 - 0.015 * (k_ - 6), 0.07 - 0.012 * (k_ - 6)
        g.blob(gname, (x, y - 0.03, z), (r * 1.1, r, h), shade if back or k_ == 7 else colour, "free", group=gname, seg=12, rings=8, anchor=pivot, far=back)
        if not back and k_ < 6:
            g.blob(gname + "_top", (x - 0.02, y - 0.09, z + 0.03), (r * 0.6, r * 0.5, g.form["puff_h"] * 0.6), (255, 255, 255), "free", group=gname, seg=10, rings=6,
                   anchor=pivot, glow=True)


def air(g, colour, **_):
    for i, (phi, a) in enumerate(((150, 40), (-170, 75), (165, 0))):
        c = g.S(phi, a, 0.14)
        g.cblade("air%d" % i, (c[0], c[1] - 0.05, c[2]), (c[0] - 0.14, c[1] - 0.05, c[2] + 0.02), 0.03, 0.012, colour, "carry", glow=True, anchor=c)


# ---- the vast and the radiant ----
def many_eyes(g, colour=None, **_):
    """Many small glossy eyes of different sizes over the whole mass, each in a pale rim so it reads on the dark jelly, and short thick pseudopods."""
    rng = random.Random(13)
    for i, (phi, a, s) in enumerate(((-150, 50, 0.85), (-120, 15, 0.7), (-95, 58, 0.9), (-145, -25, 0.65), (-88, -20, 0.75), (-118, 80, 0.6),
                                     (-170, 15, 0.6), (-50, 62, 0.65), (-12, -30, 0.6))):
        c = g.S(phi, a, 0.0)
        r = (0.06 * s, 0.035 * s, 0.075 * s * (0.8 + 0.4 * rng.random()))
        g.blob("meyerim%d" % i, (c[0], c[1] + 0.01, c[2]), (r[0] * 1.45, r[1], r[2] * 1.3), (150, 110, 200), "carry", "eyes", seg=8, rings=6, anchor=c)
        g.blob("meye%d" % i, c, r, (14, 10, 22), "carry", "eyes", seg=8, rings=6, anchor=c)
        g.blob("meyeglint%d" % i, (c[0] - 0.01 * s, c[1] - 0.025, c[2] + 0.022 * s), (0.018 * s + 0.004,) * 3, (240, 230, 255), "carry", "eyes", glow=True, seg=5,
               rings=4, anchor=c)
    _tentacles(g, ("p_front", "p_back", "p_top", "p_up", "p_front2", "p_low"), 0.10, taper=0.45)


def sheen(g, colour, **_):
    g.stripe("sheen0", [(-160 + 12 * i, 55 - 3 * i + 5 * math.sin(i)) for i in range(10)], 6.0, colour, lift=0.012, glow=True)
    g.stripe("sheen1", [(-150 + 12 * i, -5 + 7 * math.sin(i * 0.8)) for i in range(9)], 5.0, (150, 90, 200), lift=0.012)


def crown(g, colour, gem, **_):
    """A small gold crown on top of the head with a ruby, carried by the top of the jelly."""
    pivot = g.form["groups"]["crown"]
    x, y, z = pivot
    H = g.shape.H
    g.add(k.loft("crown_band", [((x, 0.0, H - 0.05), (0.17, 0.15)), ((x, 0.0, H + 0.07), (0.19, 0.17))], "z", 14, False), colour, "carry", pivot, "crown")
    for i, phi in enumerate(range(-150, 180, 60)):
        px, py = x + 0.18 * math.cos(math.radians(phi)), 0.16 * math.sin(math.radians(phi))
        g.add(k.blade("crown_pt%d" % i, (px, py, H + 0.05), (px, py, H + 0.20), 0.09, 0.03), colour if py <= 0.0 else darker(colour, 0.2), "carry", pivot, "crown",
              far=py > 0.0)
        g.add(k.ellipsoid("crown_ball%d" % i, (px, py, H + 0.205), (0.024,) * 3, 6, 4), (255, 240, 170), "carry", pivot, "crown", glow=True)
    g.add(k.ellipsoid("ruby", (x + 0.03, -0.165, H + 0.01), (0.045, 0.025, 0.05), 8, 5, smooth=False), gem, "carry", pivot, "crown", glow=True)


def pulse(g, colour, **_):
    """A ring of golden light the king calls with: it swells out from the body when it attacks (hidden otherwise)."""
    x, y, z = g.form["groups"]["pulse"]
    pts = []
    for i in range(41):
        t = 2.0 * math.pi * i / 40.0
        pts.append((x + 0.62 * math.cos(t), 0.6, z + 0.52 * math.sin(t)))     # behind the body: it shows round it
    for i in range(40):
        a, b = pts[i], pts[i + 1]
        g.add(k.limb("pulse%d" % i, a, b, 0.02, 0.02, 4, caps=False), colour, "free", (x, y, z), "pulse", glow=True)


def mirror(g, colour, dark, **_):
    """Liquid mercury: a dark reflected horizon across the middle, bold white highlights and a long rippling reflection."""
    g.stripe("horizon", [(phi, 0 + 8 * math.sin(math.radians(phi * 3))) for phi in range(-178, -2, 6)], 16.0, dark, lift=0.01)
    g.stripe("horizon2", [(phi, -40 + 5 * math.sin(math.radians(phi * 2))) for phi in range(-172, -8, 8)], 7.0, darker(dark, 0.25), lift=0.01)
    g.patch("shine", (-122.0, 48.0), (26.0, 13.0), colour, glow=True, lift=0.02)
    g.stripe("streak", [(phi, 66 + 5 * math.sin(math.radians(phi * 2))) for phi in range(-160, -40, 8)], 5.0, colour, glow=True, lift=0.02)
    g.stripe("streak2", [(phi, -18 + 4 * math.sin(math.radians(phi * 3))) for phi in range(-150, -60, 8)], 3.5, colour, glow=True, lift=0.02)


GEAR = {name: fn for name, fn in globals().items() if callable(fn) and not name.startswith("_") and fn.__module__ == __name__}
