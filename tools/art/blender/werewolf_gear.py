"""Gear for the werewolf kit (werewolf_kit.py): one function per piece, a registry GEAR. Written against the bones of the form's skeleton."""
import math

from wolf_gear import BONE_C, CRIMSON, GOLD, IRON, LEATHER, TAN

PELT = (150, 150, 158)


def pelt(g, color=PELT, **_):
    """A cloak of grey wolf pelt over the shoulders, its empty head resting on one shoulder."""
    n = g.at("spine", 0.96)
    cols = []
    for i in range(7):
        a = math.radians(-100 + 200 * i / 6)
        cols.append(((n[0] - 0.02 - 0.12 * math.cos(a), 0.17 * math.sin(a), n[2] - 0.02), (n[0] - 0.16 - 0.14 * math.cos(a), 0.22 * math.sin(a), n[2] - 0.55 + 0.07 * (i % 3))))
    g.sheet("pelt", cols, lambda z: {"spine": 1.0}, color)
    g.e("pelt_head", (n[0] + 0.02, -0.19, n[2] + 0.02), (0.11, 0.07, 0.09), "spine", color)
    g.blade("pelt_ear", (n[0] + 0.0, -0.19, n[2] + 0.08), (n[0] - 0.04, -0.19, n[2] + 0.17), 0.05, 0.02, "spine", color)


def straps(g, color=LEATHER, studs=IRON, **_):
    """Leather straps across the chest, studded."""
    for k, (a, b) in enumerate((((0.02, 1.46), (0.20, 1.06)), ((0.18, 1.46), (-0.02, 1.06)))):
        g.l("strap%d" % k, (a[0], -0.2, a[1] * g.tall), (b[0], -0.2, b[1] * g.tall), 0.03, 0.03, "spine", color)
    for i in range(3):
        g.e("stud%d" % i, (0.10, -0.215, (1.38 - 0.1 * i) * g.tall), (0.016, 0.01, 0.016), "spine", studs, seg=6, rings=4)


def bracers(g, color=IRON, trim=BONE_C, **_):
    for s, y in (("n", -0.24), ("f", 0.24)):
        h, t, _ = g.bones["fore_" + s]
        p, q = g.at("fore_" + s, 0.45), g.at("fore_" + s, 0.85)
        g.l("bracer_" + s, p, q, 0.058, 0.05, "fore_" + s, color, far=s == "f")


def breeches(g, color=(70, 52, 52), **_):
    """Ragged dark breeches hanging from the waist."""
    top = 0.96 * g.tall
    cols = [((0.0 + 0.06 * math.cos(math.radians(a)), 0.17 * math.sin(math.radians(a)), top), (0.0 + 0.10 * math.cos(math.radians(a)), 0.22 * math.sin(math.radians(a)), top - 0.42 - 0.10 * (i % 2)))
            for i, a in enumerate(range(-100, 101, 25))]
    g.sheet("breeches", cols, lambda z: {"hips": 1.0}, color)


def blood(g, color=CRIMSON, **_):
    """Blood on the muzzle, the claws and the chest."""
    g.e("blood_muzzle", (0.50, -0.065, 1.66 * g.tall), (0.05, 0.012, 0.025), "head", color, seg=6, rings=4)
    g.e("blood_chest", (0.14, -0.2, 1.30 * g.tall), (0.05, 0.01, 0.08), "spine", color, seg=6, rings=4)
    for s in "nf":
        h = g.at("fore_" + s, 1.0)
        g.e("blood_claw_" + s, (h[0] + 0.07, h[1], h[2] - 0.11), (0.02, 0.012, 0.05), "fore_" + s, color, far=s == "f", seg=6, rings=4)


def cloak(g, color=(70, 50, 100), **_):
    """A ragged royal cloak hanging from the shoulders."""
    n = g.at("spine", 0.97)
    hem = [0.0, -0.08, 0.04, -0.12, 0.0, -0.06, 0.03]
    cols = []
    for i in range(7):
        a = math.radians(-105 + 210 * i / 6)
        cols.append(((n[0] - 0.10 * math.cos(a), 0.2 * math.sin(a), n[2]), (n[0] - 0.22 * math.cos(a) - 0.1, 0.27 * math.sin(a), n[2] - 0.78 + hem[i])))
    g.sheet("cloak", cols, lambda z: {"spine": 1.0}, color)


def crown(g, color=(120, 120, 130), **_):
    h = g.at("head", 0.55)
    for i in range(3):
        a = math.radians(-50 + 50 * i)
        g.blade("crown%d" % i, (h[0] + 0.03 * math.cos(a), 0.10 * math.sin(a), h[2] + 0.09), (h[0] + 0.03 * math.cos(a), 0.10 * math.sin(a), h[2] + 0.22 - 0.03 * (i % 2)), 0.07, 0.025, "head", color)


def mane(g, color=None, size=1.0, **_):
    color = color or g.dark
    for i in range(6):
        t = i / 5.0
        p = g.at("spine", 0.5 + 0.5 * t)
        g.blade("mane%d" % i, (p[0] - 0.05, 0, p[2] + 0.04), (p[0] - 0.14 * size, 0, p[2] + 0.14 * size - 0.02 * i), 0.09 * size, 0.04, "spine", color)


def stripe(g, color=(30, 26, 38), **_):
    """A dark stripe down the spine."""
    for i in range(5):
        p = g.at("spine", 0.1 + 0.2 * i)
        g.e("stripe%d" % i, (p[0] - 0.08, 0, p[2] + 0.015), (0.06, 0.045, 0.03), "spine", color, seg=6, rings=4)


def paint(g, color=TAN, **_):
    """War paint: stripes across the muzzle and the chest."""
    for i in range(3):
        g.e("paint%d" % i, (0.42 + 0.03 * i, -0.075, 1.67 * g.tall - 0.01 * i), (0.012, 0.012, 0.03), "head", color, seg=6, rings=4)
        g.e("chest_paint%d" % i, (0.10 + 0.02 * i, -0.21, (1.40 - 0.07 * i) * g.tall), (0.012, 0.01, 0.045), "spine", color, seg=6, rings=4)


def shield(g, color=(160, 124, 82), rim=IRON, **_):
    """A round wooden shield held out in front in both hands."""
    c = (0.50, 0.0, 1.0 * g.tall)
    g.e("shield", c, (0.07, 0.22, 0.25), "item_n", color)
    g.e("shield_boss", (c[0] + 0.065, c[1], c[2]), (0.04, 0.07, 0.07), "item_n", rim)
    g.loft("shield_rim", [((c[0], 0.0, c[2] - 0.24), (0.045, 0.2), 0.0), ((c[0], 0.0, c[2] + 0.24), (0.045, 0.2), 0.0)], "item_n", rim, axis="z", sides=8)


def trophies(g, color=BONE_C, **_):
    for i in range(3):
        g.blade("trophy%d" % i, (0.16 - 0.04 * i, -0.21, (1.12 - 0.07 * i) * g.tall), (0.16 - 0.04 * i, -0.21, (1.02 - 0.07 * i) * g.tall), 0.04, 0.02, "spine", color)


GEAR = {name: fn for name, fn in globals().items() if callable(fn) and not name.startswith("_") and fn.__module__ == __name__}
