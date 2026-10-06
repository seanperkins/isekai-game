"""Gear for the wolf kit (wolf_kit.py): each piece is written against the bones of the form's own skeleton, so it sits right on a hound or a war wolf.
A form lists its gear by name in wolf_forms.py. Glowing parts (embers, wisps, eyes) are lit whatever their shape.
"""
import math

TAN, LEATHER, IRON, BONE_C, GOLD, CYAN, EMBER, CRIMSON = (150, 118, 80), (118, 84, 56), (110, 116, 128), (214, 206, 182), (222, 176, 66), (130, 214, 226), (255, 120, 40), (172, 36, 52)


def harness(g, color=LEATHER, studs=IRON, fang=BONE_C, **_):
    """A leather strap round the chest and a diagonal across it, studded, with a fang hung from it."""
    b = g.bulk
    c = g.at("spine", 0.78)
    g.loft("harness", [((c[0] - 0.035, 0, c[2] - 0.02), (0.188 * b, 0.128 * b)), ((c[0] + 0.035, 0, c[2] - 0.02), (0.188 * b, 0.128 * b))], "spine", color, sides=8)
    for i in range(3):
        t = 0.2 + 0.3 * i
        p = g.at("spine", t)
        g.e("stud%d" % i, (p[0], -0.128 * b, p[2] - 0.045), (0.02, 0.012, 0.02), "spine", studs, seg=6, rings=4)
    g.blade("fang", (c[0], -0.13 * b, c[2] - 0.10), (c[0], -0.13 * b, c[2] - 0.20), 0.03, 0.02, "spine", fang)


def collar(g, color=IRON, spikes=False, chain=False, stone=None, **_):
    n = g.at("neck", 0.18)
    b = g.bulk
    g.loft("collar", [((n[0] - 0.03, 0, n[2]), (0.155 * b, 0.118 * b)), ((n[0] + 0.03, 0, n[2]), (0.155 * b, 0.118 * b))], "neck", color, sides=8)
    if spikes:
        for i in range(5):
            a = math.radians(-60 + 30 * i)
            g.blade("cspike%d" % i, (n[0] + 0.15 * b * math.sin(a) * 0.3, -0.12 * b * math.cos(a), n[2] + 0.15 * b * math.cos(a)),
                    (n[0] + 0.19 * b * math.sin(a) * 0.3, -0.18 * b * math.cos(a), n[2] + 0.21 * b * math.cos(a)), 0.03, 0.03, "neck", color)
    if stone:
        g.e("tag", (n[0] + 0.01, -0.125 * b, n[2] - 0.14), (0.09, 0.025, 0.11), "neck", stone, seg=6, rings=4)
    if chain:
        for i in range(4):
            g.e("link%d" % i, (n[0] + 0.02 + 0.015 * i, -0.13 * b, n[2] - 0.16 - 0.055 * i), (0.022, 0.014, 0.03), "neck", chain, seg=6, rings=4)


def plates(g, color=TAN, **_):
    """Hard plates over the shoulders and the back like natural armour."""
    b = g.bulk
    for i, t in enumerate((0.15, 0.45, 0.78)):
        p = g.at("spine", t)
        g.blade("plate%d" % i, (p[0] - 0.05, 0, p[2] + 0.12 * b), (p[0] + 0.10, 0, p[2] + 0.19 * b), 0.12, 0.05 * b, "spine", color)
    h = g.at("hips", 0.4)
    g.blade("plate_h", (h[0] - 0.05, 0, h[2] + 0.12 * b), (h[0] + 0.06, 0, h[2] + 0.19 * b), 0.12, 0.05 * b, "hips", color)


def ruff(g, color=None, size=1.0, **_):
    """A mane: blades along the top of the neck and over the chest."""
    color = color or g.fur
    for i in range(6):
        t = i / 5.0
        p = g.at("neck", t)
        g.blade("mane%d" % i, (p[0], 0, p[2] + 0.08), (p[0] - 0.12 * size, 0, p[2] + 0.18 * size - 0.03 * i), 0.08 * size, 0.04, "neck", color)
    c = g.at("spine", 0.9)
    for i in range(3):
        g.blade("ruff%d" % i, (c[0] + 0.02 * i, 0, c[2] - 0.08), (c[0] - 0.03 + 0.03 * i, 0, c[2] - 0.20 * size), 0.08, 0.04, "spine", color)


def wisps(g, color=CYAN, where=("tail3", "paw_n", "paw_f", "meta_n", "meta_f"), **_):
    """Thin glowing wisps trailing from the paws and tail, as mist or wind."""
    for bone in where:
        if bone not in g.bones:
            continue
        h, t, _ = g.bones[bone]
        for j in range(2):
            g.blade("wisp_%s%d" % (bone, j), (t[0] - 0.01 * j, h[1], t[2] + 0.03 + 0.04 * j), (t[0] - 0.16 - 0.06 * j, h[1], t[2] + 0.10 + 0.05 * j), 0.05, 0.02, bone, color, far=h[1] > 0, glow=True)


def flames(g, color=EMBER, **_):
    """Flames licking from the mane, the back and the tail: glowing blades."""
    for i in range(7):
        t = i / 6.0
        p = g.at("neck", t) if i < 4 else g.at("spine", (i - 3) / 3.0)
        bone = "neck" if i < 4 else "spine"
        g.blade("flame%d" % i, (p[0], 0, p[2] + 0.10), (p[0] - 0.05, 0, p[2] + 0.26 + 0.03 * (i % 2)), 0.07, 0.04, bone, color, glow=True)
    for j in (1, 2, 3):
        h, t, _ = g.bones["tail%d" % j]
        g.blade("tflame%d" % j, (h[0], 0, h[2] + 0.04), (h[0] - 0.04, 0, h[2] + 0.18), 0.06, 0.04, "tail%d" % j, color, glow=True)


def cracks(g, color=EMBER, **_):
    """Glowing cracks through the fur: thin ember patches on the flanks and the haunches."""
    for i, (bone, t, dz) in enumerate((("spine", 0.3, 0.0), ("spine", 0.7, 0.04), ("hips", 0.5, 0.0), ("thigh_n", 0.3, 0.0))):
        p = g.at(bone, t)
        g.e("crack%d" % i, (p[0], -0.125 * g.bulk, p[2] + dz), (0.05, 0.012, 0.012), bone, color, glow=True, seg=6, rings=4)


def chains(g, color=IRON, **_):
    """Snapped chains hanging from the neck, the forelegs and the tail: heavy links, and one broken length swinging clear of the chest so it shows in outline."""
    for bone, count in (("neck", 4), ("sho_n", 3), ("tail1", 3)):
        h, t, _ = g.bones[bone]
        for i in range(count):
            g.e("%s_link%d" % (bone, i), (t[0] + 0.01 * i, h[1] - 0.12 * g.bulk if bone != "tail1" else -0.03, t[2] - 0.05 * i), (0.045, 0.025, 0.055), bone, color, seg=6, rings=4)
    h, t, _ = g.bones["neck"]
    for i in range(4):
        g.e("free_link%d" % i, (t[0] + 0.12 + 0.05 * i, -0.13 * g.bulk, t[2] - 0.22 - 0.07 * i), (0.04, 0.022, 0.05), "neck", color, seg=6, rings=4)


def frost(g, color=(150, 190, 220), ice=(190, 226, 240), **_):
    """Frost on the back and icicles from the chin and belly."""
    for i, t in enumerate((0.2, 0.5, 0.8)):
        p = g.at("spine", t)
        g.e("frost%d" % i, (p[0], 0, p[2] + 0.13 * g.bulk), (0.09, 0.07 * g.bulk, 0.03), "spine", color, seg=6, rings=4)
    for i, t in enumerate((0.3, 0.6)):
        p = g.at("spine", t)
        g.blade("icicle%d" % i, (p[0], 0, p[2] - 0.15 * g.bulk), (p[0] - 0.01, 0, p[2] - 0.25 * g.bulk), 0.025, 0.02, "spine", ice)
    g.blade("icicle_c", g.head_point(0.7, -0.05), g.head_point(0.7, -0.15), 0.02, 0.02, "jaw", ice)


def gold_collar(g, color=GOLD, **_):
    """A broad collar and armbands."""
    n = g.at("neck", 0.2)
    b = g.bulk
    g.loft("gcollar", [((n[0] - 0.05, 0, n[2] - 0.02), (0.165 * b, 0.124 * b)), ((n[0] + 0.05, 0, n[2] - 0.03), (0.165 * b, 0.124 * b)), ((n[0] + 0.10, 0, n[2] - 0.05), (0.135 * b, 0.104 * b))], "neck", color, sides=8)
    for s in "nf":
        h, t, _ = g.bones["fore_" + s]
        g.loft("band_" + s, [((h[0] - 0.02, h[1], h[2] - 0.06), (0.055 * b, 0.055 * b)), ((h[0] + 0.0, h[1], h[2] - 0.10), (0.055 * b, 0.055 * b))], "fore_" + s, color, sides=6, axis="z", far=s == "f")


def sash(g, color=CYAN, **_):
    """A thin sash from the neck, streaming back."""
    n = g.at("neck", 0.1)
    cols = [((n[0] - 0.02 * i, 0.02 * (i % 2) - 0.02, n[2] + 0.04), (n[0] - 0.22 - 0.16 * i, 0.02 * (i % 2) - 0.02, n[2] - 0.02 - 0.05 * i + 0.04 * (i % 3))) for i in range(5)]
    g.sheet("sash", cols, lambda z: {"spine": 1.0}, color)


def belly_panel(g, color=(150, 112, 88), **_):
    """A broad warm panel along the belly and the chest, so a warm underside reads from the side."""
    g.loft("belly_panel", [((0.30, 0, g.at("spine", 0.9)[2] - 0.10 * g.bulk), (0.04 * g.bulk, 0.09 * g.bulk)), ((0.10, 0, g.at("spine", 0.5)[2] - 0.14 * g.bulk), (0.05 * g.bulk, 0.11 * g.bulk)),
                           ((-0.12, 0, g.at("spine", 0.1)[2] - 0.12 * g.bulk), (0.05 * g.bulk, 0.10 * g.bulk))], "spine", color)


def teats(g, color=(190, 140, 150), **_):
    for i in range(3):
        p = g.at("spine", 0.15 + 0.22 * i)
        g.e("teat%d" % i, (p[0] - 0.08, -0.07 * g.bulk, p[2] - 0.17 * g.bulk), (0.02, 0.02, 0.02), "spine", color, seg=6, rings=4)


def single_eye(g, color=(255, 70, 60), **_):
    """One huge burning eye in the middle of the forehead, in place of the star."""
    g.e("cyclops", g.head_point(0.5, 0.05, -0.085 * g.head_f), (0.055, 0.04, 0.055), "head", color, glow=True, seg=8, rings=6)


def ember_eyes(g, color=EMBER, **_):
    pass


def pelt(g, color=(150, 150, 158), **_):
    """A cloak of grey wolf pelt over the shoulders (a thin sheet) for a beast that wears one."""
    n = g.at("neck", 0.1)
    cols = []
    for i in range(7):
        a = math.radians(-100 + 200 * i / 6)
        cols.append(((n[0] - 0.02 - 0.10 * math.cos(a), 0.11 * math.sin(a), n[2] + 0.02), (n[0] - 0.12 - 0.12 * math.cos(a), 0.15 * math.sin(a), n[2] - 0.30 + 0.05 * (i % 3))))
    g.sheet("pelt", cols, lambda z: {"spine": 1.0}, color)


GEAR = {name: fn for name, fn in globals().items() if callable(fn) and not name.startswith("_") and fn.__module__ == __name__}
