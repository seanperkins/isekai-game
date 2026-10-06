"""Gear for the goblin kit: each piece is written once against the standard goblin (see goblin_kit.py) and bound to a bone. A form lists
its gear by name in goblin_forms.py. Held things hang on the `item_n` / `item_f` bones, which goblin.py keeps at a fixed angle in the world
whatever the arm does, so an upright pick stays upright through a walk.
"""
from goblin_kit import FAR, NEAR
from goblin_skeleton import LEG_FAR, LEG_NEAR

BONE, STEEL, IRON, GOLD, WOOD = (214, 206, 182), (170, 180, 194), (112, 118, 130), (222, 176, 66), (112, 78, 48)
EMBER, CYAN, STRAW, PINK = (255, 120, 40), (150, 226, 236), (224, 196, 96), (238, 150, 172)
Y = {"n": NEAR, "f": FAR}


# ---- head ----
def cap(g, color, tip=(0.02, 0, 2.02), base=1.69, r=0.215, **_):
    g.l("cap", (0.13, 0, base), tip, r, 0.0, "head", color, sides=8)


def floppy_cap(g, color, height=0.30, **_):
    g.l("cap_a", (0.13, 0, 1.69), (0.10, 0, 1.69 + height), 0.215, 0.12, "head", color, sides=8)
    g.bone("cap_tip", (0.10, 0, 1.69 + height), (-0.14, 0, 1.69 + height - 0.08), "head")
    g.l("cap_b", (0.10, 0, 1.69 + height), (-0.14, 0, 1.69 + height - 0.08), 0.12, 0.0, "cap_tip", color, sides=7)


def headband(g, color, **_):
    g.e("band", (0.14, 0, 1.66), (0.245, 0.215, 0.045), "head", color)


def feather(g, color, base=(0.10, 0.12, 1.72), tip=(-0.12, 0.16, 2.05), **_):
    g.l("feather", base, tip, 0.035, 0.0, "head", color, sides=4)


def hood(g, color, **_):
    g.e("hood", (0.07, 0, 1.58), (0.27, 0.24, 0.27), "head", color)
    g.bone("hood_tip", (-0.05, 0, 1.70), (-0.30, 0, 1.48), "head")
    g.l("hood_tip", (-0.05, 0, 1.70), (-0.30, 0, 1.48), 0.16, 0.0, "hood_tip", color, sides=7)


def scarf(g, color, face=False, tail=True, **_):
    g.e("scarf", (0.10, 0, 1.38), (0.19, 0.18, 0.07), "spine", color)
    if tail:
        g.bone("scarf_tail", (-0.04, -0.12, 1.36), (-0.30, -0.14, 1.12), "spine")
        g.l("scarf_tail", (-0.04, -0.12, 1.36), (-0.30, -0.14, 1.12), 0.05, 0.03, "scarf_tail", color, sides=5)
    if face:
        g.e("scarf_face", (0.26, 0, 1.46), (0.13, 0.17, 0.08), "head", color)


def goggles(g, color, lens=(190, 230, 240), **_):
    for s, y in (("n", -0.09), ("f", 0.09)):
        g.e("lens_" + s, (0.21, y, 1.71), (0.06, 0.05, 0.06), "head", lens, far=s == "f", glow=True, seg=8, rings=6)
    g.e("goggle_band", (0.14, 0, 1.70), (0.24, 0.21, 0.035), "head", color)


def helm(g, color, rim=None, wings=None, horns=None, **_):
    g.e("helm", (0.14, 0, 1.66), (0.245, 0.215, 0.17), "head", color)
    if rim:
        g.e("helm_rim", (0.14, 0, 1.60), (0.25, 0.22, 0.03), "head", rim)
    if wings:
        for s, y in (("n", -1), ("f", 1)):
            g.l("wing_" + s, (0.04, y * 0.20, 1.76), (-0.18, y * 0.34, 2.08), 0.06, 0.0, "head", wings, far=s == "f", sides=4)
    if horns:
        for s, y in (("n", -1), ("f", 1)):
            g.l("horn_" + s, (0.10, y * 0.20, 1.74), (0.20, y * 0.34, 2.02), 0.05, 0.0, "head", horns, far=s == "f", sides=5)


def crown(g, color, spikes=5, **_):
    for i in range(spikes):
        a = 3.14159 * 2 * i / spikes
        import math
        cx, cy = 0.14 + 0.17 * math.cos(a), 0.15 * math.sin(a)
        g.l("spike%d" % i, (cx, cy, 1.74), (cx, cy, 1.94), 0.035, 0.0, "head", color, far=cy > 0, sides=4)


def antlers(g, color, **_):
    for s, y in (("n", -1), ("f", 1)):
        g.l("ant_a" + s, (0.10, y * 0.10, 1.74), (-0.02, y * 0.22, 1.98), 0.04, 0.03, "head", color, far=s == "f", sides=5)
        g.l("ant_b" + s, (-0.02, y * 0.22, 1.98), (0.12, y * 0.30, 2.22), 0.03, 0.0, "head", color, far=s == "f", sides=5)
        g.l("ant_c" + s, (-0.01, y * 0.22, 2.00), (-0.18, y * 0.30, 2.14), 0.025, 0.0, "head", color, far=s == "f", sides=4)


def wreath(g, color, leaves=9, **_):
    import math
    for i in range(leaves):
        a = 3.14159 * 2 * i / leaves
        g.e("leaf%d" % i, (0.14 + 0.2 * math.cos(a), 0.17 * math.sin(a), 1.70), (0.045, 0.035, 0.03), "head", color, far=math.sin(a) > 0, seg=6, rings=4)


def mask(g, color, **_):
    g.e("mask", (0.20, -0.14, 1.74), (0.13, 0.03, 0.15), "head", color)


def beard(g, color, length=0.30, width=0.10, **_):
    g.l("beard", (0.30, 0, 1.44), (0.24, 0, 1.44 - length), width, 0.0, "head", color, sides=7)


def candle(g, **_):
    g.e("lamp_cap", (0.28, 0, 1.76), (0.05, 0.05, 0.05), "head", (80, 80, 90))
    g.e("flame", (0.28, 0, 1.84), (0.035, 0.035, 0.06), "head", (255, 226, 140), glow=True, seg=6, rings=4)


# ---- torso ----
def jerkin(g, color, skirt=0.0, collar=None, **_):
    g.torso("jerkin", "spine", color, grow=1.14)
    if skirt:
        g.l("skirt", (0.03, 0, 1.0), (0.04, 0, 1.0 - skirt), 0.20, 0.28, "hips", color, sides=9)
    if collar:
        g.e("collar", (0.08, 0, 1.37), (0.25, 0.23, 0.10), "spine", collar)


def apron(g, color, trim=None, **_):
    g.e("apron", (0.21, 0, 1.0), (0.05, 0.155, 0.32), "spine", color)
    g.l("apron_low", (0.19, 0, 0.84), (0.22, 0, 0.52), 0.15, 0.17, "hips", color, sides=7)
    if trim:
        g.e("apron_trim", (0.255, 0, 1.08), (0.03, 0.08, 0.07), "spine", trim, glow=True, seg=8, rings=6)


def cloak(g, color, length=0.80, spread=0.18, **_):
    """A thin sheet hung from the shoulders and wrapped round the back, flaring to a ragged hem; two bones bend it halfway down."""
    import math
    top, end = 1.36, 1.36 - length
    mid = (top + end) / 2.0
    g.bone("cloak1", (-0.08, 0, top), (-0.14 - spread * 0.4, 0, mid), "spine", raw=True)
    g.bone("cloak2", (-0.14 - spread * 0.4, 0, mid), (-0.20 - spread, 0, end), "cloak1", raw=True)
    hem = [0.04, -0.03, 0.09, 0.0, 0.07, -0.02, 0.06, 0.01, 0.05]  # uneven points along the bottom edge
    columns = []
    n = len(hem)
    for i in range(n):
        a = math.radians(-105.0 + 210.0 * i / (n - 1))
        c, sn = math.cos(a), math.sin(a)
        columns.append(((-0.095 * c + 0.0, 0.17 * sn, top), (-0.10 * c - (0.12 + spread) * abs(c), (0.17 + 0.10 + spread * 0.6) * sn, end + hem[i] * length)))

    def weights(z):
        t = max(0.0, min(1.0, (top - z) / max(1e-6, top - end)))
        blend = max(0.0, min(1.0, (t - 0.30) / 0.35))
        blend = blend * blend * (3.0 - 2.0 * blend)
        return {"cloak1": 1.0 - blend, "cloak2": blend}
    g.sheet("cloak", columns, weights, color)


def belt(g, color, buckle=None, **_):
    g.e("belt", (0.02, 0, 0.98), (0.195, 0.175, 0.045), "hips", color)
    if buckle:
        g.e("buckle", (0.215, 0, 0.98), (0.035, 0.05, 0.05), "hips", buckle, glow=True, seg=6, rings=4)


def sash(g, color, **_):
    belt(g, color)
    g.l("sash_tail", (0.15, -0.12, 0.98), (0.17, -0.15, 0.60), 0.045, 0.03, "hips", color, sides=5)


def bandolier(g, color, items=(), **_):
    g.l("bandolier", (-0.04, -0.175, 1.38), (0.17, -0.175, 0.98), 0.035, 0.035, "spine", color, sides=5)
    for i, c in enumerate(items):
        t = (i + 0.5) / max(1, len(items))
        g.e("bando%d" % i, (-0.04 + 0.21 * t, -0.20, 1.38 - 0.40 * t), (0.04, 0.04, 0.05), "spine", c, seg=6, rings=4)


def pauldron(g, color, side="n", **_):
    g.e("pauldron_" + side, (0.06, Y[side], 1.34), (0.125, 0.10, 0.09), "arm_" + side, color)


def pouch(g, color, glow=False, **_):
    g.e("pouch", (0.02, NEAR, 0.90), (0.075, 0.07, 0.085), "hips", color, glow=glow, seg=8, rings=6)


def necklace(g, color=BONE, **_):
    for i in range(5):
        g.e("bead%d" % i, (0.20 + 0.012 * (i % 2), -0.07 + 0.035 * i, 1.30 - 0.03 * abs(i - 2)), (0.025, 0.025, 0.03), "spine", color, seg=6, rings=4)


def patches(g, colors, **_):
    spots = [(0.10, -0.19, 1.22), (0.02, -0.21, 1.02), (0.08, -0.25, 0.84), (0.04, -0.27, 0.66)]
    for i, c in enumerate(colors):
        g.e("patch%d" % i, spots[i % len(spots)], (0.09, 0.02, 0.095), "spine" if i < 2 else "hips", c, seg=6, rings=4)


def rat_ball(g, **_):
    import math
    pelt = [(120, 108, 98), (136, 122, 110), (106, 96, 92)]
    g.bone("pack", (-0.14, 0, 1.30), (-0.26, 0, 1.00), "spine")
    for i in range(8):
        a = 2 * math.pi * i / 8
        c = (-0.20 + 0.10 * math.cos(a), 0.10 * math.sin(a) * 0.5, 1.12 + 0.12 * math.sin(a * 1.3))
        g.e("rat%d" % i, c, (0.10, 0.09, 0.09), "pack", pelt[i % 3], seg=8, rings=6)
    g.e("rat_nose", (-0.07, -0.05, 1.18), (0.03, 0.03, 0.03), "pack", PINK, seg=6, rings=4)
    g.e("rat_nose2", (-0.10, -0.04, 1.00), (0.03, 0.03, 0.03), "pack", PINK, seg=6, rings=4)


def hawk(g, side="n", **_):
    y = Y[side]
    b = "item_" + side
    g.e("hawk", (0.30, y, 1.08), (0.12, 0.06, 0.075), b, (140, 100, 70), seg=8, rings=6)
    g.e("hawk_head", (0.44, y, 1.15), (0.06, 0.05, 0.055), b, (150, 112, 80), seg=8, rings=6)
    g.l("hawk_beak", (0.49, y, 1.15), (0.55, y, 1.12), 0.02, 0.0, b, (230, 190, 70), sides=4)
    g.e("hawk_wing_n", (0.26, y - 0.07, 1.20), (0.22, 0.03, 0.12), b, (160, 120, 84), seg=8, rings=6)
    g.e("hawk_tip_n", (0.14, y - 0.075, 1.30), (0.10, 0.02, 0.06), b, CYAN, seg=6, rings=4)
    g.e("hawk_wing_f", (0.26, y + 0.07, 1.20), (0.22, 0.03, 0.12), b, (160, 120, 84), far=True, seg=8, rings=6)


# ---- legs and hands ----
def boots(g, color, height=0.34, big=1.0, plate=None, spike=False, **_):
    for s, y in (("n", LEG_NEAR), ("f", LEG_FAR)):
        far = s == "f"
        g.l("boot_" + s, (0.03, y, 0.11 + height), (0.0, y, 0.11), 0.054 * big, 0.050 * big, "shin_" + s, color, far, sides=7, raw=True)
        g.foot("bootfoot_" + s, s, "foot_" + s, plate or color, big=1.12 * big, length=1.1, far=far)
        if spike:
            g.blade("toespike_" + s, (0.24, y, 0.04), (0.36, y, 0.05), 0.05, 0.03, "foot_" + s, STEEL, far, raw=True)


def curled_shoes(g, color, **_):
    for s, y in (("n", LEG_NEAR), ("f", LEG_FAR)):
        far = s == "f"
        g.foot("shoe_" + s, s, "foot_" + s, color, big=1.05, length=1.05, far=far)
        g.blade("curl_" + s, (0.19, y, 0.03), (0.30, y, 0.17), 0.05, 0.05, "foot_" + s, color, far, raw=True)


def clogs(g, color, **_):
    for s, y in (("n", LEG_NEAR), ("f", LEG_FAR)):
        g.foot("clog_" + s, s, "foot_" + s, color, big=1.25, length=1.0, far=s == "f")


def wraps(g, color, **_):
    for s in "nf":
        g.e("wrap_" + s, (0.17, Y[s], 0.90), (0.042, 0.040, 0.075), "fore_" + s, color, far=s == "f", raw=True, seg=8, rings=6)


# ---- held things (on the item bones) ----
def club(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("handle", (0.20, y, 0.82), (0.50, y, 1.12), 0.035, 0.045, b, WOOD, sides=6)
    g.e("knob", (0.57, y, 1.19), (0.10, 0.10, 0.10), b, (88, 60, 38))


def dagger(g, side="n", color=STEEL, **_):
    """A short blade held point down, a flat slab you can see from the side."""
    y, b = Y[side], "item_" + side
    g.blade("dagger", (0.25, y, 0.82), (0.23, y, 0.42), 0.075, 0.03, b, color)
    g.box("hilt", (0.25, y, 0.82), (0.045, 0.05, 0.02), b, (80, 60, 50))


def axe(g, side="n", color=(168, 176, 188), **_):
    """A haft and a wedge of a blade, wide at the cutting edge in front, so the head is a clear shape against the body."""
    y, b = Y[side], "item_" + side
    g.l("axe_h", (0.22, y, 0.80), (0.30, y, 1.16), 0.030, 0.030, b, WOOD, sides=5)
    g.blade("axe_head", (0.47, y, 1.10), (0.31, y, 1.10), 0.22, 0.035, b, color)
    g.box("axe_eye", (0.31, y, 1.10), (0.04, 0.04, 0.05), b, (96, 100, 112))


def spear(g, side="n", length=1.4, couched=False, pennant=None, **_):
    y, b = Y[side], "item_" + side
    if couched:
        g.l("spear", (-0.15, y, 0.92), (0.95, y, 0.84), 0.028, 0.025, b, WOOD, sides=5)
        g.blade("spearhead", (0.95, y, 0.84), (1.20, y, 0.82), 0.10, 0.03, b, STEEL)
        if pennant:
            g.e("pennant", (0.80, y, 0.93), (0.20, 0.015, 0.07), b, pennant, glow=True, seg=8, rings=6)
    else:
        g.l("spear", (0.22, y, 0.55), (0.30, y, 0.55 + length), 0.026, 0.026, b, WOOD, sides=5)
        g.blade("spearhead", (0.30, y, 0.55 + length), (0.32, y, 0.80 + length), 0.10, 0.03, b, STEEL)


def sword_big(g, side="n", length=1.3, **_):
    y, b = Y[side], "item_" + side
    f = length / 1.3
    tip = (0.20 - 0.50 * f, y, 0.95 + 1.20 * f)
    g.blade("blade", (0.20, y, 0.99), tip, 0.11, 0.03, b, STEEL)
    g.blade("edge", (0.20, y + 0.03, 0.99), tip, 0.03, 0.01, b, GOLD, glow=True)
    g.e("guard", (0.21, y, 0.97), (0.04, 0.04, 0.12), b, GOLD)


def hammer(g, side="n", big=1.0, **_):
    y, b = Y[side], "item_" + side
    g.l("hammer_h", (0.22, y, 0.85), (0.00, y, 1.50), 0.035, 0.035, b, WOOD, sides=5)
    g.box("hammer_head", (-0.02, y, 1.56), (0.20 * big, 0.12 * big, 0.12 * big), b, IRON)


def hammer_small(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("sh_h", (0.22, y, 0.82), (0.30, y, 1.02), 0.025, 0.025, b, WOOD, sides=5)
    g.e("sh_head", (0.31, y, 1.05), (0.06, 0.04, 0.04), b, IRON)


def tongs(g, side="f", ingot=True, **_):
    y, b = Y[side], "item_" + side
    g.l("tong_a", (0.23, y, 0.82), (0.52, y - 0.02, 0.96), 0.02, 0.015, b, IRON, far=side == "f", sides=4)
    g.l("tong_b", (0.23, y, 0.82), (0.52, y + 0.02, 0.96), 0.02, 0.015, b, IRON, far=side == "f", sides=4)
    if ingot:
        g.e("ingot", (0.55, y, 0.98), (0.08, 0.05, 0.04), b, EMBER, far=side == "f", glow=True, seg=8, rings=6)


def pick(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("pick_h", (0.24, y, 0.70), (0.28, y, 1.55), 0.03, 0.03, b, WOOD, sides=5)
    g.l("pick_head", (0.12, y, 1.55), (0.46, y, 1.55), 0.03, 0.03, b, IRON, sides=5)


def wrench(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("wr_h", (0.22, y, 0.82), (0.14, y, 1.50), 0.04, 0.04, b, IRON, sides=5)
    g.e("wr_jaw", (0.12, y, 1.58), (0.075, 0.03, 0.10), b, STEEL)


def staff(g, side="n", color=WOOD, crystal=(170, 120, 255), **_):
    y, b = Y[side], "item_" + side
    g.l("staff", (0.14, y, 0.55), (0.46, y, 1.72), 0.03, 0.03, b, color, sides=6)
    g.e("crystal", (0.47, y, 1.82), (0.07, 0.07, 0.11), b, crystal, glow=True, seg=6, rings=4)


def spindle(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("spindle", (0.22, y, 0.80), (0.32, y, 1.30), 0.025, 0.02, b, WOOD, sides=5)
    g.e("skein", (0.27, y, 1.08), (0.07, 0.07, 0.12), b, GOLD, glow=True, seg=8, rings=6)


def pipe(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("pipe", (0.20, y, 0.84), (0.48, y, 1.04), 0.03, 0.028, b, (150, 100, 60), sides=5)
    g.e("pipe_glow", (0.33, y, 0.95), (0.05, 0.03, 0.05), b, (190, 235, 245), glow=True, seg=6, rings=4)


def lyre(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("lyre_a", (0.22, y, 0.70), (0.20, y, 1.04), 0.03, 0.03, b, GOLD, sides=5)
    g.l("lyre_b", (0.44, y, 0.70), (0.46, y, 1.04), 0.03, 0.03, b, GOLD, sides=5)
    g.l("lyre_c", (0.20, y, 1.04), (0.46, y, 1.04), 0.03, 0.03, b, GOLD, sides=5)
    g.e("strings", (0.33, y, 0.86), (0.10, 0.012, 0.16), b, (255, 236, 160), glow=True, seg=6, rings=4)


def horn(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("horn_a", (0.23, y, 0.85), (0.42, y, 0.80), 0.03, 0.055, b, BONE, sides=6)
    g.l("horn_b", (0.42, y, 0.80), (0.68, y, 0.60), 0.055, 0.09, b, BONE, sides=7)
    g.e("horn_band", (0.44, y, 0.79), (0.06, 0.06, 0.06), b, GOLD, seg=8, rings=6)


def lantern(g, side="f", color=(255, 214, 110), **_):
    y, b = Y[side], "item_" + side
    g.e("lantern", (0.25, y, 0.62), (0.075, 0.065, 0.095), b, color, far=side == "f", glow=True, seg=8, rings=6)
    g.e("lantern_cap", (0.25, y, 0.72), (0.06, 0.055, 0.03), b, (70, 66, 70), far=side == "f", seg=6, rings=4)


def stone(g, side="n", color=GOLD, **_):
    y, b = Y[side], "item_" + side
    g.e("stone", (0.30, y, 0.88), (0.085, 0.085, 0.085), b, color, glow=True, seg=8, rings=6)


def bowl(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.e("bowl", (0.34, y, 0.86), (0.10, 0.10, 0.05), b, WOOD)
    g.e("porridge", (0.34, y, 0.90), (0.075, 0.075, 0.03), b, (236, 226, 196), glow=True, seg=8, rings=4)


def trap(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.box("trap", (0.31, y, 0.92), (0.14, 0.09, 0.07), b, (180, 140, 70))
    g.l("spring", (0.31, y, 0.96), (0.31, y, 1.14), 0.03, 0.03, b, STEEL, sides=5)


def shield(g, color=STEEL, emblem=GOLD, **_):
    g.e("shield", (0.20, NEAR - 0.07, 0.96), (0.16, 0.04, 0.17), "item_n", color)
    g.e("sunburst", (0.20, NEAR - 0.11, 0.96), (0.075, 0.02, 0.075), "item_n", emblem, glow=True, seg=8, rings=6)


def shield_back(g, color=STEEL, emblem=GOLD, **_):
    g.e("shield_b", (-0.12, 0.0, 1.12), (0.05, 0.20, 0.22), "spine", color)
    g.e("sun_b", (-0.15, NEAR, 1.12), (0.03, 0.10, 0.10), "spine", emblem, glow=True, seg=8, rings=6)


def sling(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("sling", (0.24, y, 0.82), (0.22, y, 0.42), 0.015, 0.012, b, WOOD, sides=4)
    g.e("sling_stone", (0.22, y, 0.38), (0.04, 0.04, 0.04), b, (170, 170, 176), seg=6, rings=4)


def coin(g, side="f", **_):
    y, b = Y[side], "item_" + side
    g.e("coin", (0.34, y, 1.02), (0.05, 0.015, 0.05), b, GOLD, far=side == "f", glow=True, seg=8, rings=4)


def ring(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.e("ring", (0.30, y, 1.02), (0.085, 0.015, 0.085), b, GOLD, glow=True, seg=10, rings=6)
    g.e("ring_fire", (0.30, y, 1.02), (0.05, 0.02, 0.05), b, EMBER, glow=True, seg=6, rings=4)


def offering(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.e("meat", (0.30, y, 0.86), (0.06, 0.05, 0.04), b, (150, 70, 60), seg=6, rings=4)


def spiked_cap_held(g, side="n", color=(176, 28, 44), **_):
    y, b = Y[side], "item_" + side
    g.l("held_cap", (0.26, y, 1.0), (0.28, y, 1.26), 0.10, 0.0, b, color, sides=7)
    for i, dx in enumerate((-0.07, 0.0, 0.07)):
        g.l("held_spike%d" % i, (0.26 + dx, y, 1.02), (0.26 + dx * 1.6, y, 1.12), 0.015, 0.0, b, STEEL, sides=4)


def straw(g, side="f", **_):
    y, b = Y[side], "item_" + side
    g.e("straw", (0.14, y, 0.95), (0.12, 0.07, 0.10), b, STRAW, far=side == "f", seg=8, rings=6)


def doll(g, side="n", **_):
    y, b = Y[side], "item_" + side
    g.l("doll_string", (0.24, y, 0.82), (0.26, y, 0.52), 0.01, 0.01, b, (200, 190, 160), sides=3)
    g.e("doll", (0.26, y, 0.46), (0.05, 0.04, 0.07), b, STRAW, seg=6, rings=4)


def spoon(g, **_):
    g.l("spoon", (0.20, -0.12, 0.98), (0.26, -0.14, 1.16), 0.015, 0.02, "hips", WOOD, sides=4)


def trail(g, color=CYAN, **_):
    for i in range(3):
        g.e("swirl%d" % i, (-0.14 - 0.12 * i, 0.0, 0.10 + 0.05 * i), (0.07, 0.05, 0.035), "hips", color, glow=True, seg=6, rings=4)


GEAR = {name: fn for name, fn in globals().items() if callable(fn) and not name.startswith("_") and fn.__module__ == __name__}
