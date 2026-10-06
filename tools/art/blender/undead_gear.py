"""Gear for the undead kit: each piece is a function `fn(k, **options)` that adds meshes to an Undead (undead_kit.py), written in standard
coordinates read off the form's landmarks (`k.m`) and bound to the form's bones (undead_skeleton.py). Held things hang on `item_n` / `item_f`,
which the motion keeps at a fixed angle in the world (biped_motion._hold_items) and which point up at rest: a blade is built pointing up from the
hand and a form's `item_angle` turns it (180: point down). A form lists its gear in undead_forms.py.
"""
import math

from undead_kit import DARK, SOCKET, TEETH, shade

BONE, STEEL, IRON, GOLD, WOOD, RUST = (214, 204, 176), (160, 166, 178), (104, 108, 118), (222, 176, 66), (110, 78, 50), (150, 86, 54)
LEATHER, CYAN, VIOLET, ROSE, EMBER, WHITE = (110, 80, 56), (150, 222, 232), (98, 70, 128), (226, 150, 174), (255, 128, 48), (236, 236, 230)


def _y(k, side):
    return -k.m["sh"] if side == "n" else k.m["sh"]


def _grip(k, side):
    return (0.13, _y(k, side), k.m["wrist_z"])


def _far(side):
    return side == "f"


def _girth(k):
    """The radius of the trunk a garment wraps: a ribcage's or a body's."""
    return (0.11 if k.style == "bone" else 0.12) * max(k.bulk, 0.9)


def _chest(k, name, color, grow=1.08, low=None, high=None, belly=1.0):
    """A garment over the trunk: a wedge from `low` to `high` (standard z), a little bigger than what it covers."""
    m = k.m
    g = _girth(k) * grow
    low = m["waist"] - 0.04 if low is None else low
    high = m["neck"] + 0.01 if high is None else high
    mid = (low + high) / 2
    rings = [((0.02, 0, low), (0.85 * g * belly, 1.05 * g)), ((0.035, 0, mid), (0.95 * g * belly, 1.12 * g)), ((0.05, 0, high - 0.10), (1.0 * g, 1.18 * g)),
             ((0.05, 0, high), (0.75 * g, 1.0 * g))]
    k.loft(name, rings, "spine", color, sides=8)


def _skirt(k, name, color, length, top=None, flare=1.0, front=0.0, hem=None):
    """A skirt (a robe, a coat's tails, a kilt) as a sheet round the legs: bound to the hips at the top and, further down, more and more to both thighs
    at once, so the hem sways with the stride without tearing."""
    m = k.m
    top = m["waist"] - 0.02 if top is None else top
    end = top - length
    g = _girth(k)
    n = 14
    hem = hem or [0.0, 0.03, -0.01, 0.02, 0.0, 0.03, -0.02, 0.01, 0.03, 0.0, -0.01, 0.02, 0.0, 0.03]
    cols = []
    for i in range(n + 1):
        a = 2.0 * math.pi * (i % n) / n
        c, s = math.cos(a), math.sin(a)
        rx0, ry0 = 0.95 * g, 1.1 * g
        rx1, ry1 = (1.0 * g + 0.10 * length) * flare, (1.1 * g + 0.08 * length) * flare
        cols.append(((0.02 + rx0 * c, ry0 * s, top), (0.02 + front + rx1 * c, ry1 * s, end + hem[i % n] * length)))

    def weights(z):
        t = max(0.0, min(1.0, (top - 0.06 - z) / max(1e-6, 0.7 * length)))
        t = t * t * (3.0 - 2.0 * t)
        return {"hips": 1.0 - 0.8 * t, "thigh_n": 0.4 * t, "thigh_f": 0.4 * t}
    k.sheet(name, cols, weights, color)


def _cloak_sheet(k, name, color, length, spread=0.14, wrap=105.0, top=None, hem=None, inset=0.0):
    """A sheet hung from the shoulders and round the back on the cloak bones (follow-through), flaring to a ragged hem."""
    m = k.m
    top = (m["neck"] - 0.02) if top is None else top
    end = top - length
    hem = hem or [0.04, -0.03, 0.08, 0.0, 0.06, -0.02, 0.05, 0.01, 0.05]
    g = _girth(k) + 0.03 - inset
    n = len(hem)
    cols = []
    for i in range(n):
        a = math.radians(-wrap + 2.0 * wrap * i / (n - 1))
        c, s = math.cos(a), math.sin(a)
        cols.append(((-g * c + 0.02, (g + 0.04) * s, top), (-g * c - (0.10 + spread) * abs(c) - 0.02, (g + 0.10 + spread * 0.6) * s, end + hem[i] * length)))
    mid_z = top - length / 2.0

    def weights(z):
        t = max(0.0, min(1.0, (top - z) / max(1e-6, length)))
        b = max(0.0, min(1.0, (t - 0.30) / 0.35))
        b = b * b * (3.0 - 2.0 * b)
        return {"cloak1": 1.0 - b, "cloak2": b}
    k.sheet(name, cols, weights, color)
    return mid_z


def _strips(k, name, bone, color, width=0.07):
    h, t, _ = k.raw[bone]
    k.blade(name, h, t, width, 0.025, bone, color)


# ---- hung cloth --------------------------------------------------------------------------------------------------------------
def rag(k, color, **_):
    """A scrap of rotted cloth tied at the hips: a knot of it and two tails that swing (the rag bones)."""
    m = k.m
    k.e("rag_knot", (0.02, 0, m["hip"] + 0.02), (_girth(k) * 0.85, _girth(k) * 1.0, 0.045), "hips", color, seg=8, rings=5)
    _strips(k, "rag_front", "rag", color, 0.10)
    _strips(k, "rag_back", "rag_b", shade(color, 0.85), 0.09)


def rags(k, color, **_):
    """Torn sagging rags over a corpse's chest and hips."""
    m = k.m
    _chest(k, "rag_shirt", color, grow=1.06, low=m["waist"] - 0.02, high=m["neck"] - 0.08)
    for i, (x, y, z, l) in enumerate(((0.10, -0.10, m["waist"] - 0.02, 0.16), (-0.05, -0.12, m["waist"] - 0.02, 0.22), (0.06, 0.10, m["waist"], 0.14))):
        k.blade("rag_tail%d" % i, (x, y, z + 0.03), (x - 0.02, y, z - l), 0.08, 0.02, "hips", color)


def trousers(k, color, **_):
    for s in "nf":
        y = -k.m["leg_y"] if s == "n" else k.m["leg_y"]
        far = s == "f"
        hp, kn = k.raw["thigh_" + s][:2]
        an = k.raw["shin_" + s][1]
        r = 0.058 * k.bulk
        k.l("trouser_" + s, hp, kn, r * 1.3, r * 1.0, "thigh_" + s, color, far, sides=6)
        k.l("trouser_low_" + s, kn, (an[0] + 0.01, y, an[2] + 0.10), r * 1.0, r * 0.85, "shin_" + s, color, far, sides=6)
    k.loft("trouser_seat", [((0.0, 0, k.m["hip"] - 0.08), (0.09 * k.bulk, 0.12 * k.bulk)), ((0.01, 0, k.m["waist"]), (0.095 * k.bulk, 0.125 * k.bulk))], "hips", color, sides=8)


def boots(k, color, **_):
    for s in "nf":
        far = s == "f"
        y = -k.m["leg_y"] if s == "n" else k.m["leg_y"]
        an = k.raw["shin_" + s][1]
        k.l("boot_" + s, (an[0] + 0.02, y, an[2] + 0.22), (an[0], y, an[2]), 0.05 * max(1.0, k.bulk), 0.048 * max(1.0, k.bulk), "shin_" + s, color, far, sides=6)
        k.foot("bootfoot_" + s, s, color, far, big=1.15, length=1.05)


def pointed_shoes(k, color, **_):
    for s in "nf":
        far = s == "f"
        y = -k.m["leg_y"] if s == "n" else k.m["leg_y"]
        k.foot("shoe_" + s, s, color, far, big=1.1, length=1.0)
        fl = k.m["foot"]
        k.blade("shoe_tip_" + s, (fl * 0.7, y, 0.02), (fl + 0.12, y, 0.06), 0.05, 0.04, "foot_" + s, color, far)


def greaves(k, color, **_):
    for s in "nf":
        far = s == "f"
        y = -k.m["leg_y"] if s == "n" else k.m["leg_y"]
        kn, an = k.raw["shin_" + s][:2]
        k.l("greave_" + s, (kn[0] + 0.01, y, kn[2] - 0.02), (an[0] + 0.01, y, an[2] + 0.06), 0.05 * max(1.0, k.bulk), 0.04 * max(1.0, k.bulk), "shin_" + s, color, far, sides=6)
        k.e("kneecop_" + s, kn, (0.05 * k.bulk,) * 3, "thigh_" + s, color, far, seg=7, rings=5)


def cloak(k, color, length=0.9, lining=None, ragged=False, **_):
    hem = [0.10, -0.06, 0.14, -0.02, 0.12, -0.06, 0.10, 0.0, 0.12] if ragged else None
    _cloak_sheet(k, "cloak", color, length, hem=hem)
    if lining:
        _cloak_sheet(k, "cloak_lining", lining, length * 0.94, spread=0.10, wrap=60.0, inset=0.015, hem=hem)


def cape(k, color, length=0.5, **_):
    _cloak_sheet(k, "cape", color, length, spread=0.06)


def fur_cloak(k, color, length=1.0, fur=None, **_):
    _cloak_sheet(k, "fur_cloak", color, length, spread=0.20, hem=[0.06, -0.04, 0.10, 0.02, 0.08, -0.04, 0.06, 0.02, 0.06])
    m = k.m
    k.e("fur_collar", (0.0, 0, m["neck"] - 0.02), (_girth(k) * 1.15, _girth(k) * 1.35, 0.08), "spine", fur or shade(color, 1.2), seg=10, rings=6)


def coat(k, color, lining=(162, 30, 48), length=1.05, collar=False, **_):
    """A long high-collared coat: cut close over the chest, tails that swing from the shoulders, the lining showing at the open front, a collar up
    behind the head."""
    m = k.m
    _chest(k, "coat_chest", color, grow=1.12, low=m["waist"] - 0.04)
    _cloak_sheet(k, "coat_tails", color, length, spread=0.12, wrap=125.0)
    k.blade("coat_facing", (0.12, -0.10, m["neck"] - 0.06), (0.11, -0.12, m["neck"] - 0.06 - 0.7 * length), 0.05, 0.015, "spine", lining)
    if collar:
        for s, y in (("n", -0.09), ("f", 0.09)):
            k.blade("collar_" + s, (-0.02, y, m["neck"] - 0.04), (-0.06, y * 1.3, m["head_base"] + 0.30 * m["skull"]), 0.12, 0.02, "spine", lining if s == "n" else color, far=s == "f")
    for s in "nf":
        far = s == "f"
        sh, el = k.raw["arm_" + s][:2]
        wr = k.raw["fore_" + s][1]
        k.l("sleeve_" + s, sh, el, 0.06 * k.bulk, 0.05 * k.bulk, "arm_" + s, color, far, sides=6)
        k.l("sleeve_low_" + s, el, (wr[0], wr[1], wr[2] + 0.06), 0.05 * k.bulk, 0.055 * k.bulk, "fore_" + s, color, far, sides=6)


def hunting_coat(k, color, **_):
    m = k.m
    _chest(k, "hcoat_chest", color, grow=1.14, low=m["waist"] - 0.04)
    _skirt(k, "hcoat_skirt", color, 0.36, flare=0.95)
    _sleeves(k, color)
    k.e("hcoat_belt", (0.02, 0, m["waist"] - 0.02), (_girth(k) * 1.1, _girth(k) * 1.25, 0.03), "hips", LEATHER, seg=10, rings=4)


def patched_coat(k, color, patches=(), **_):
    m = k.m
    _chest(k, "pcoat_chest", color, grow=1.12, low=m["waist"] - 0.04)
    _skirt(k, "pcoat_skirt", color, 0.42, flare=1.0, hem=[0.0, 0.05, -0.02, 0.04, 0.0, 0.06, -0.03, 0.02, 0.05, 0.0, -0.02, 0.04, 0.0, 0.05])
    _sleeves(k, color)
    for i, c in enumerate(patches):
        k.box("patch%d" % i, (0.06 - 0.10 * i, -0.13 * max(1, k.bulk), m["waist"] + 0.12 + 0.12 * i), (0.04, 0.012, 0.04), "spine", c)


def _sleeves(k, color, grow=1.0, cuff=None):
    for s in "nf":
        far = s == "f"
        sh, el = k.raw["arm_" + s][:2]
        wr = k.raw["fore_" + s][1]
        r = (0.045 if k.style == "bone" else 0.055 * k.bulk) * grow
        k.l("sleeve_" + s, sh, el, r * 1.2, r, "arm_" + s, color, far, sides=6)
        k.l("sleeve_low_" + s, el, (wr[0], wr[1], wr[2] + 0.05), r, r * 1.15, "fore_" + s, cuff or color, far, sides=6)


def robe(k, color, length=0.7, collar=None, trim=None, **_):
    m = k.m
    _chest(k, "robe_chest", color, grow=1.14, low=m["waist"] - 0.04)
    _skirt(k, "robe_skirt", color, length, flare=1.1)
    _sleeves(k, color, grow=1.25, cuff=trim)
    if collar:
        k.e("robe_collar", (0.02, 0, m["neck"] + 0.02), (_girth(k) * 1.2, _girth(k) * 1.4, 0.07), "spine", collar, seg=10, rings=5)
        for s, y in (("n", -0.08), ("f", 0.08)):
            k.blade("robe_collar_" + s, (-0.03, y, m["neck"]), (-0.06, y * 1.4, m["head_base"] + 0.5 * m["skull"]), 0.12, 0.02, "spine", collar, far=s == "f")
    if trim:
        k.e("robe_trim", (0.03, 0, m["waist"] - 0.03), (_girth(k) * 1.2, _girth(k) * 1.4, 0.025), "hips", trim, seg=10, rings=4)


def qing_robe(k, color, trim=(150, 222, 232), **_):
    m = k.m
    _chest(k, "qing_chest", color, grow=1.16, low=m["waist"] - 0.04)
    _skirt(k, "qing_skirt", color, 0.62, flare=1.0, hem=[0.0] * 14)
    _skirt(k, "qing_hem", trim, 0.05, top=m["waist"] - 0.62, flare=1.12, hem=[0.0] * 14)
    _sleeves(k, color, grow=1.4, cuff=trim)
    k.box("qing_square", (0.13, -0.11, m["waist"] + 0.18), (0.035, 0.012, 0.05), "spine", shade(color, 1.35))


def chiton(k, color, **_):
    m = k.m
    _chest(k, "chiton_chest", color, grow=1.12, low=m["waist"] - 0.04, high=m["neck"] - 0.04)
    _skirt(k, "chiton_skirt", color, 0.36, flare=1.05)


def doublet(k, color, **_):
    m = k.m
    _chest(k, "doublet", color, grow=1.16, low=m["waist"] - 0.06)
    _skirt(k, "doublet_skirt", color, 0.14, flare=1.15, hem=[0.0] * 14)
    _sleeves(k, color, grow=1.1)


def tunic(k, color, **_):
    _skirt(k, "tunic_skirt", color, 0.30, flare=1.05)


def waistcoat(k, color, **_):
    _chest(k, "waistcoat", color, grow=1.06, low=k.m["waist"] - 0.03, high=k.m["neck"] - 0.06)


def kilt(k, color, stripes=None, **_):
    m = k.m
    _skirt(k, "kilt", color, 0.30, top=m["hip"] + 0.06, flare=1.0, hem=[0.0] * 14)
    if stripes:
        k.e("kilt_belt", (0.02, 0, m["hip"] + 0.05), (_girth(k) * 1.05, _girth(k) * 1.2, 0.03), "hips", stripes, seg=10, rings=4)
        k.blade("kilt_front", (0.11, -0.04, m["hip"] + 0.03), (0.13, -0.04, m["hip"] - 0.22), 0.07, 0.02, "hips", stripes)


def surcoat(k, color, **_):
    m = k.m
    _chest(k, "surcoat", color, grow=1.22, low=m["waist"] - 0.05, high=m["neck"] - 0.10)
    _skirt(k, "surcoat_skirt", color, 0.40, flare=1.15, hem=[0.0, 0.06, -0.02, 0.08, 0.0, 0.05, -0.03, 0.06, 0.02, 0.0, 0.07, -0.02, 0.04, 0.0])
    k.e("crest_scratch", (0.13 * k.bulk, -0.15, m["waist"] + 0.20), (0.03, 0.01, 0.05), "spine", (140, 130, 140))


def stole(k, color, bands=None, **_):
    m = k.m
    for s, y in (("n", -0.06), ("f", 0.06)):
        k.blade("stole_" + s, (0.10, y, m["neck"]), (0.15, y * 1.2, m["waist"] - 0.70), 0.07, 0.015, "spine", color, far=s == "f")
    if bands:
        for i in range(2):
            k.box("stole_band%d" % i, (0.13 + 0.01 * i, -0.075, m["waist"] - 0.25 - 0.18 * i), (0.04, 0.012, 0.022), "spine", bands)


def sash(k, color, **_):
    m = k.m
    k.e("sash", (0.02, 0, m["waist"] - 0.02), (_girth(k) * 1.15, _girth(k) * 1.3, 0.035), "hips", color, seg=10, rings=4)
    k.blade("sash_tail", (0.08, -0.12, m["waist"] - 0.02), (0.06, -0.14, m["waist"] - 0.34), 0.06, 0.015, "hips", color)


def scarf(k, color, **_):
    m = k.m
    k.e("scarf", (0.04, 0, m["neck"] + 0.01), (0.07 * max(1, k.bulk), 0.09, 0.035), "spine", color, seg=8, rings=5)
    _strips(k, "scarf_end", "scarf_tail", color, 0.06)


def hood(k, color, deep=False, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.e("hood", (0.04, 0, hb + 0.60 * s), (0.135, 0.115, 0.13), "head", color, seg=10, rings=6)
    k.l("hood_tip", k.raw["hood_tip"][0], k.raw["hood_tip"][1], 0.08, 0.0, "hood_tip", color, sides=6)
    if deep:
        k.e("hood_shadow", (0.12, -0.02, hb + 0.52 * s), (0.06, 0.07, 0.09), "head", SOCKET, seg=7, rings=5)
        k.e("hood_drape", (-0.02, 0, m["neck"] - 0.02), (0.13, 0.14, 0.07), "spine", color, seg=8, rings=5)


def headcloth(k, color, stripes=None, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.e("headcloth", (0.05, 0, hb + 0.64 * s), (0.115, 0.098, 0.105), "head", color, seg=10, rings=6)
    k.blade("headcloth_tail", (-0.04, 0, hb + 0.6 * s), (-0.08, 0, hb - 0.12), 0.16, 0.03, "head", color)
    if stripes:
        for i in range(3):
            k.e("hc_stripe%d" % i, (0.05, 0, hb + (0.5 + 0.13 * i) * s), (0.118, 0.10, 0.012), "head", stripes, seg=10, rings=3)


def nemes(k, color, stripes=None, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.e("nemes", (0.05, 0, hb + 0.66 * s), (0.12, 0.105, 0.12), "head", color, seg=10, rings=6)
    for side, y in (("n", -0.08), ("f", 0.08)):
        k.blade("lappet_" + side, (0.07, y, hb + 0.4 * s), (0.10, y * 1.2, hb - 0.28), 0.10, 0.02, "head", color, far=side == "f")
    if stripes:
        for i in range(3):
            k.e("nemes_stripe%d" % i, (0.05, 0, hb + (0.48 + 0.16 * i) * s), (0.123, 0.108, 0.014), "head", stripes, seg=10, rings=3)
    k.l("cobra", (0.17, -0.01, hb + 0.80 * s), (0.20, -0.01, hb + 1.02 * s), 0.025, 0.015, "head", GOLD, sides=5)
    k.e("cobra_hood", (0.20, -0.01, hb + 1.02 * s), (0.02, 0.012, 0.03), "head", GOLD, glow=True, seg=5, rings=3)


# ---- the head ----------------------------------------------------------------------------------------------------------------
def helm(k, color, style="iron", crest=None, slit=None, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    hd = k.shape["head"]
    if style == "great":
        k.loft("greathelm", [((0.07, 0, hb + 0.18 * s), (0.10 * hd, 0.095 * hd)), ((0.075, 0, hb + 0.60 * s), (0.115 * hd, 0.10 * hd)),
                             ((0.07, 0, hb + 0.95 * s), (0.10 * hd, 0.09 * hd)), ((0.06, 0, hb + 1.05 * s), (0.06 * hd, 0.06 * hd))], "head", color, sides=8)
        k.box("visor_slit", (0.18 * hd, -0.03, hb + 0.62 * s), (0.02, 0.06, 0.012), "head", slit or SOCKET, glow=bool(slit))
        k.l("helm_ridge", (0.18 * hd, -0.0, hb + 0.95 * s), (0.18 * hd, -0.0, hb + 0.25 * s), 0.014, 0.014, "head", shade(color, 1.3), sides=4)
        return
    k.e("helm", (0.06, 0, hb + 0.70 * s), (0.118 * hd, 0.10 * hd, 0.10 * hd), "head", color, seg=10, rings=6)
    k.e("helm_rim", (0.06, 0, hb + 0.62 * s), (0.122 * hd, 0.104 * hd, 0.022), "head", shade(color, 0.85), seg=10, rings=3)
    if style == "corinthian":
        k.blade("cheekguard", (0.10, -0.05, hb + 0.62 * s), (0.17 * hd, -0.05, hb + 0.20 * s), 0.10, 0.03, "head", color)
        k.blade("noseguard", (0.18 * hd, -0.01, hb + 0.65 * s), (0.20 * hd, -0.01, hb + 0.38 * s), 0.035, 0.02, "head", color)
    if style == "pushed":
        k.e("helm_peak", (0.00, 0, hb + 0.95 * s), (0.07, 0.06, 0.05), "head", color, seg=7, rings=4)
    if crest:
        k.blade("crest", (0.10, 0, hb + 0.95 * s), (-0.20, 0, hb + 1.02 * s), 0.16, 0.025, "head", crest)


def crown(k, color, style="jagged", **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    hd = k.shape["head"]
    k.e("crown_band", (0.07, 0, hb + 0.80 * s), (0.105 * hd, 0.09 * hd, 0.025), "head", color, seg=10, rings=3)
    n = 5 if style != "barrow" else 4
    for i in range(n):
        a = math.pi * (i + 0.5) / n
        x, y = 0.07 + 0.10 * hd * math.cos(a) * 0.9, -0.08 * hd * math.sin(a)
        h = (0.20 if i % 2 == 0 else 0.13) * s / 0.26 * 0.26
        k.blade("crown_spike%d" % i, (x, y, hb + 0.82 * s), (x, y, hb + 0.82 * s + h), 0.04, 0.015, "head", color)
        k.blade("crown_spike_b%d" % i, (x, -y, hb + 0.82 * s), (x, -y, hb + 0.82 * s + h * 0.9), 0.04, 0.015, "head", color, far=True)
    if style == "barrow":
        k.e("crown_gem", (0.17 * hd, -0.03, hb + 0.82 * s), (0.016, 0.01, 0.016), "head", (200, 60, 60), glow=True, seg=5, rings=3)


def cap(k, color, style="plumed", feather=None, band=None, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    hd = k.shape["head"]
    top = hb + 0.85 * s
    if style == "plumed":
        k.e("cap_crown", (0.06, 0, top + 0.02), (0.10 * hd, 0.09 * hd, 0.06), "head", color, seg=9, rings=5)
        k.e("cap_brim", (0.08, 0, top - 0.03), (0.16 * hd, 0.13 * hd, 0.018), "head", color, seg=10, rings=3)
        k.blade("plume", (0.0, -0.06, top + 0.03), (-0.20, -0.08, top + 0.14), 0.07, 0.02, "head", feather or (150, 60, 60))
    elif style == "pointed":
        k.l("cap_cone", (0.05, 0, top - 0.06), (-0.04, 0, top + 0.20), 0.11 * hd, 0.0, "head", color, sides=7)
    elif style == "fur_tall":
        k.l("cap_tall", (0.06, 0, top - 0.06), (0.05, 0, top + 0.24), 0.10 * hd, 0.085 * hd, "head", color, sides=8)
        k.e("cap_fur", (0.06, 0, top - 0.04), (0.125 * hd, 0.11 * hd, 0.045), "head", band or shade(color, 0.8), seg=10, rings=4)
    elif style == "ceremonial":
        k.loft("mitre", [((0.06, 0, top - 0.06), (0.10 * hd, 0.09 * hd)), ((0.06, 0, top + 0.14), (0.12 * hd, 0.06 * hd)), ((0.06, 0, top + 0.30), (0.04, 0.03))],
               "head", color, sides=6)
        k.e("mitre_band", (0.06, 0, top - 0.03), (0.105 * hd, 0.095 * hd, 0.025), "head", band or GOLD, seg=10, rings=3)
    elif style == "feathered":
        k.e("cap_crown", (0.05, 0, top + 0.01), (0.11 * hd, 0.095 * hd, 0.045), "head", color, seg=9, rings=5)
        k.blade("cap_feather", (0.0, -0.06, top + 0.03), (-0.22, -0.06, top + 0.18), 0.06, 0.02, "head", feather or WHITE)


def official_hat(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    hd = k.shape["head"]
    top = hb + 0.85 * s
    k.loft("hat", [((0.06, 0, top - 0.07), (0.115 * hd, 0.10 * hd)), ((0.06, 0, top + 0.06), (0.12 * hd, 0.10 * hd))], "head", color, sides=8)
    k.e("hat_brim", (0.06, 0, top - 0.06), (0.15 * hd, 0.13 * hd, 0.02), "head", color, seg=10, rings=3)
    k.e("hat_bead", (0.06, 0, top + 0.08), (0.03, 0.03, 0.025), "head", (180, 60, 60), seg=6, rings=4)


def flat_cap(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    top = hb + 0.82 * s
    k.e("flatcap", (0.05, 0, top), (0.115, 0.10, 0.05), "head", color, seg=10, rings=5)
    k.blade("flatcap_peak", (0.12, 0, top - 0.02), (0.22, 0, top - 0.04), 0.14, 0.02, "head", shade(color, 0.85))


def talisman(k, color, **_):
    h, t, _ = k.raw["talisman"]
    k.blade("talisman", (h[0], h[1] - 0.02, h[2]), (t[0], t[1] - 0.02, t[2]), 0.08, 0.012, "talisman", color)


def hair_thin(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    for i, (x, y) in enumerate(((-0.02, -0.04), (-0.06, 0.02), (0.02, 0.05))):
        k.blade("hair%d" % i, (x, y, hb + 0.95 * s), (x - 0.10, y, hb + 0.55 * s), 0.04, 0.015, "head", color)


def hair_slick(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.e("hair_slick", (0.04, 0, hb + 0.70 * s), (0.11, 0.095, 0.095), "head", color, seg=10, rings=6)
    k.blade("widow_peak", (0.10, -0.02, hb + 0.92 * s), (0.15, -0.02, hb + 0.70 * s), 0.06, 0.02, "head", color)


def beard(k, color, length=0.3, braid=False, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.l("beard", (0.12, 0, hb + 0.28 * s), (0.13 if not braid else 0.16, 0, hb + 0.28 * s - length), 0.07, 0.015, "jaw", color, sides=6)
    if braid:
        for i in range(3):
            k.e("braid%d" % i, (0.135 + 0.008 * i, -0.01, hb + 0.2 * s - length * (0.3 + 0.2 * i)), (0.03, 0.03, 0.025), "jaw", shade(color, 0.85), seg=5, rings=3)


def false_beard(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.l("false_beard", (0.15, 0, hb + 0.22 * s), (0.16, 0, hb - 0.08), 0.025, 0.02, "jaw", color, sides=5)


def antlers(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    for side, y in (("n", -0.06), ("f", 0.06)):
        far = side == "f"
        base = (0.04, y, hb + 0.92 * s)
        a = (-0.06, y * 1.6, hb + 1.60 * s)
        b = (-0.18, y * 2.0, hb + 2.30 * s)
        k.l("ant_a" + side, base, a, 0.025, 0.02, "head", color, far, sides=5)
        k.l("ant_b" + side, a, b, 0.02, 0.0, "head", color, far, sides=5)
        k.l("ant_c" + side, a, (0.10, y * 1.8, hb + 2.0 * s), 0.016, 0.0, "head", color, far, sides=4)
        k.l("ant_d" + side, ((a[0] + b[0]) / 2, y * 1.8, (a[2] + b[2]) / 2), (0.02, y * 2.0, hb + 2.45 * s), 0.014, 0.0, "head", color, far, sides=4)
        k.l("ant_e" + side, (-0.02, y * 1.3, hb + 1.3 * s), (-0.22, y * 1.5, hb + 1.55 * s), 0.014, 0.0, "head", color, far, sides=4)


def snout(k, color, **_):
    """A ghoul's lean hyena face: a long muzzle with yellow teeth."""
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.loft("muzzle", [((0.14, 0, hb + 0.40 * s), (0.05, 0.05)), ((0.26, 0, hb + 0.34 * s), (0.032, 0.035))], "head", color, axis="x", sides=6)
    k.blade("ghoul_teeth", (0.16, -0.02, hb + 0.30 * s), (0.26, -0.02, hb + 0.27 * s), 0.025, 0.02, "jaw", (226, 206, 120))
    k.blade("ear_n", (0.0, -0.06, hb + 0.80 * s), (-0.10, -0.08, hb + 1.05 * s), 0.06, 0.02, "head", color)


def fangs(k, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.blade("fang", (0.18, -0.03, hb + 0.30 * s), (0.18, -0.03, hb + 0.18 * s), 0.02, 0.012, "head", WHITE)


def fang_jaw(k, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    for i in range(3):
        x = 0.10 + 0.04 * i
        k.blade("jawfang%d" % i, (x, -0.04, hb + 0.24 * s), (x + 0.01, -0.04, hb + 0.38 * s), 0.025, 0.015, "jaw", TEETH)


def grin(k, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.box("grin", (0.18, -0.04, hb + 0.30 * s), (0.04, 0.01, 0.01), "head", (236, 226, 206))


def croc_head(k, color, teeth=WHITE, **_):
    """A crocodile's head on a mummy: a long toothed upper jaw over the face and a lower jaw on the jaw bone that opens."""
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.loft("croc_snout", [((0.10, 0, hb + 0.46 * s), (0.065, 0.075)), ((0.24, 0, hb + 0.38 * s), (0.04, 0.05)), ((0.34, 0, hb + 0.34 * s), (0.028, 0.035))], "head", color, axis="x", sides=6)
    k.loft("croc_jaw", [((0.10, 0, hb + 0.24 * s), (0.04, 0.06)), ((0.33, 0, hb + 0.20 * s), (0.022, 0.03))], "jaw", color, axis="x", sides=6)
    for i in range(3):
        x = 0.16 + 0.06 * i
        k.blade("croc_tooth%d" % i, (x, -0.04, hb + 0.36 * s), (x + 0.01, -0.04, hb + 0.28 * s), 0.025, 0.012, "head", teeth)


def mane(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.e("mane", (-0.02, 0, hb + 0.40 * s), (0.13, 0.13, 0.17), "head", color, seg=9, rings=6)
    for i in range(3):
        k.blade("mane_lock%d" % i, (-0.05, -0.04 + 0.04 * i, hb + 0.3 * s), (-0.10, -0.04 + 0.04 * i, hb - 0.20 - 0.04 * i), 0.10, 0.03, "spine", color, far=i == 2)


def nimbus(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.e("nimbus", (-0.02, 0.10, hb + 0.62 * s), (0.20, 0.012, 0.20), "head", color, far=True, glow=True, seg=16, rings=4)


# ---- the body ----------------------------------------------------------------------------------------------------------------
def ribs_showing(k, **_):
    m = k.m
    for i in range(2):
        k.e("showrib%d" % i, (0.06 + 0.02 * i, -0.10 * k.bulk, m["neck"] - 0.20 - 0.07 * i), (0.06, 0.03, 0.012), "spine", (214, 204, 176), seg=6, rings=3)


def bruise(k, color, **_):
    m = k.m
    k.e("bruise", (0.02, -0.11 * k.bulk, m["neck"] - 0.12), (0.06, 0.03, 0.05), "spine", color, seg=6, rings=4)
    k.e("shoulder_bone", (0.04, -m["sh"], m["shoulder_z"] + 0.02), (0.04, 0.03, 0.03), "arm_n", (214, 204, 176), seg=6, rings=4)


def clod(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.e("clod", (0.01, -0.02, hb + 0.95 * s), (0.05, 0.04, 0.035), "head", color, seg=6, rings=4)


def stains(k, color, **_):
    m = k.m
    k.e("stain0", (0.06, -0.12, m["waist"] + 0.05), (0.04, 0.02, 0.03), "spine", color, seg=6, rings=3)
    k.e("stain1", (0.0, -0.11, m["hip"] - 0.05), (0.04, 0.02, 0.03), "hips", color, seg=6, rings=3)


def claws(k, color, **_):
    for s in "nf":
        wr = k.raw["fore_" + s][1]
        y = _y(k, s)
        for i in range(2):
            k.blade("claw_%s%d" % (s, i), (wr[0] + 0.01 + 0.02 * i, y, wr[2] - 0.06), (wr[0] + 0.07 + 0.02 * i, y, wr[2] - 0.16), 0.025, 0.012, "fore_" + s, color, far=s == "f")


def nails(k, color, **_):
    for s in "nf":
        wr = k.raw["fore_" + s][1]
        y = _y(k, s)
        k.blade("nails_" + s, (wr[0] + 0.02, y, wr[2] - 0.07), (wr[0] + 0.06, y, wr[2] - 0.16), 0.03, 0.012, "fore_" + s, color, far=s == "f")


def wraps(k, color, **_):
    m = k.m
    _chest(k, "wraps_chest", color, grow=1.05, low=m["waist"] - 0.02, high=m["neck"] - 0.12)
    _skirt(k, "wraps_skirt", color, 0.28, flare=0.95, hem=[0.0, 0.06, -0.03, 0.05, 0.0, 0.07, -0.02, 0.04, 0.06, 0.0, -0.03, 0.05, 0.0, 0.06])


def wrap_stripes(k, color, **_):
    """The darker edges of the linen bands, round the trunk and the limbs."""
    m = k.m
    g = _girth(k) * 1.02
    for i in range(4):
        z = m["waist"] + 0.04 + (m["neck"] - m["waist"] - 0.10) * i / 3.0
        k.e("band_t%d" % i, (0.04, 0, z), (g * 0.95, g * 1.12, 0.012), "spine", color, seg=10, rings=3)
    for s in "nf":
        far = s == "f"
        for bone, n in (("thigh_", 2), ("shin_", 2), ("arm_", 1), ("fore_", 1)):
            h, t, _ = k.raw[bone + s]
            for j in range(n):
                f = (j + 0.6) / (n + 0.4)
                c = tuple(h[i] + (t[i] - h[i]) * f for i in range(3))
                r = (0.06 if bone == "thigh_" else 0.05 if bone == "shin_" else 0.048) * k.bulk
                k.e("band_%s%s%d" % (bone, s, j), c, (r, r, 0.012), bone + s, color, far, seg=8, rings=3)


def bandages(k, color, **_):
    for bone in ("band1", "band2", "band_h"):
        _strips(k, bone, bone, color, 0.05)


def collar_gold(k, color, **_):
    m = k.m
    k.e("collar_gold", (0.04, 0, m["neck"] - 0.03), (_girth(k) * 1.15, _girth(k) * 1.3, 0.05), "spine", color, seg=12, rings=5)


def phylactery(k, color, **_):
    m = k.m
    k.l("chain", (0.06, -0.06, m["neck"] - 0.02), (0.13, -0.08, m["neck"] - 0.18), 0.008, 0.008, "spine", (150, 146, 140), sides=3)
    k.e("phylactery", (0.135, -0.09, m["neck"] - 0.21), (0.03, 0.02, 0.04), "spine", color, glow=True, seg=6, rings=4)


def locket(k, color, gem=ROSE, **_):
    m = k.m
    k.e("locket", (0.135, -0.09, m["neck"] - 0.20), (0.03, 0.02, 0.04), "spine", color, seg=7, rings=5)
    k.l("needle", (0.10, -0.10, m["neck"] - 0.17), (0.17, -0.10, m["neck"] - 0.23), 0.006, 0.006, "spine", (200, 204, 214), sides=3)
    k.e("needle_gem", (0.172, -0.10, m["neck"] - 0.232), (0.012, 0.01, 0.012), "spine", gem, glow=True, seg=5, rings=3)


def charm(k, color, **_):
    m = k.m
    k.l("charm", (0.12, -0.08, m["neck"] - 0.06), (0.13, -0.09, m["neck"] - 0.16), 0.012, 0.008, "spine", color, sides=4)


def chainmail(k, color, **_):
    m = k.m
    _chest(k, "mail", color, grow=1.08, low=m["waist"] - 0.06)
    _skirt(k, "mail_skirt", color, 0.20, flare=1.05, hem=[0.0] * 14)
    for s in "nf":
        sh, el = k.raw["arm_" + s][:2]
        k.l("mail_sleeve_" + s, sh, el, 0.07 * k.bulk, 0.06 * k.bulk, "arm_" + s, color, s == "f", sides=6)


def plate(k, color, trim=None, **_):
    m = k.m
    _chest(k, "breastplate", color, grow=1.18, low=m["waist"] - 0.04, belly=1.05)
    k.loft("fauld", [((0.01, 0, m["waist"] + 0.0), (_girth(k) * 1.1, _girth(k) * 1.25)), ((0.02, 0, m["hip"] - 0.10), (_girth(k) * 1.2, _girth(k) * 1.3))], "hips", shade(color, 0.92), sides=8)
    for s in "nf":
        far = s == "f"
        sh, el = k.raw["arm_" + s][:2]
        wr = k.raw["fore_" + s][1]
        r = 0.05 * max(1.0, k.bulk)
        k.e("pauldron_" + s, (sh[0], sh[1], sh[2] + 0.02), (r * 1.7, r * 1.4, r * 1.3), "arm_" + s, color, far, seg=9, rings=5)
        k.l("rerebrace_" + s, sh, el, r * 1.05, r * 0.9, "arm_" + s, color, far, sides=6)
        k.l("vambrace_" + s, el, wr, r * 0.9, r * 0.8, "fore_" + s, color, far, sides=6)
        k.e("gauntlet_" + s, (wr[0] + 0.01, wr[1], wr[2] - 0.03), (r * 0.9, r * 0.8, r * 1.0), "fore_" + s, shade(color, 0.85), far, seg=7, rings=5)
        hp, kn = k.raw["thigh_" + s][:2]
        k.l("cuisse_" + s, hp, kn, r * 1.3, r * 1.0, "thigh_" + s, color, far, sides=6)
    if trim:
        k.e("plate_trim", (0.04, 0, m["neck"] - 0.04), (_girth(k) * 1.1, _girth(k) * 1.3, 0.03), "spine", trim, seg=10, rings=3)


def cuirass(k, color, small=False, **_):
    m = k.m
    _chest(k, "cuirass", color, grow=1.14, low=(m["waist"] + 0.08) if small else m["waist"] - 0.05, high=m["neck"] - 0.02)
    k.e("cuirass_ab", (0.12 * max(1, k.bulk), -0.06, m["waist"] + 0.16), (0.02, 0.05, 0.05), "spine", shade(color, 1.2), seg=6, rings=4)


def scale_vest(k, color, **_):
    m = k.m
    _chest(k, "scales", color, grow=1.12, low=m["waist"] - 0.04, high=m["neck"] - 0.03)
    for i in range(3):
        k.e("scale_row%d" % i, (0.04, 0, m["waist"] + 0.04 + 0.12 * i), (_girth(k) * 1.15, _girth(k) * 1.3, 0.012), "spine", shade(color, 0.75), seg=10, rings=3)


def pauldron(k, color, side="n", **_):
    sh = k.raw["arm_" + side][0]
    k.e("pauldron_" + side, (sh[0], sh[1], sh[2] + 0.02), (0.085 * k.bulk, 0.07 * k.bulk, 0.06 * k.bulk), "arm_" + side, color, _far(side), seg=9, rings=5)


def shoulder_plate(k, color, **_):
    sh = k.raw["arm_n"][0]
    k.box("shoulder_plate", (sh[0], sh[1] - 0.02, sh[2] + 0.03), (0.10 * k.bulk, 0.04, 0.06 * k.bulk), "arm_n", color)
    for i in range(2):
        k.e("bolt%d" % i, (sh[0] - 0.05 + 0.10 * i, sh[1] - 0.07, sh[2] + 0.05), (0.014, 0.01, 0.014), "arm_n", (190, 190, 196), seg=5, rings=3)


def patches(k, colors, **_):
    m = k.m
    spots = [((0.08, -0.12, m["neck"] - 0.14), "spine"), ((0.0, -0.13, m["waist"] + 0.08), "spine"), ((0.02, -0.11, m["hip"] - 0.05), "hips")]
    for i, ((x, y, z), bone) in enumerate(spots):
        k.e("patch%d" % i, (x, y * k.bulk, z), (0.07, 0.03, 0.06), bone, colors[i % len(colors)], seg=6, rings=4)
    th = k.raw["thigh_n"]
    k.e("patch_leg", tuple((th[0][i] + th[1][i]) / 2 for i in range(3)), (0.07 * k.bulk, 0.07 * k.bulk, 0.08), "thigh_n", colors[1 % len(colors)], seg=6, rings=4)


def stitches(k, color, **_):
    m = k.m
    hb, s = m["head_base"], m["skull"]
    k.box("stitch_face", (0.17, -0.06, hb + 0.55 * s), (0.008, 0.008, 0.06), "head", color)
    k.box("stitch_neck", (0.10, -0.06, m["neck"] + 0.01), (0.05, 0.008, 0.008), "spine", color)
    k.box("stitch_chest", (0.10, -0.14 * k.bulk, m["neck"] - 0.18), (0.008, 0.008, 0.10), "spine", color)
    el = k.raw["arm_n"][1]
    k.box("stitch_arm", (el[0], el[1] - 0.06, el[2] + 0.06), (0.05, 0.008, 0.008), "arm_n", color)


def big_arm(k, **_):
    """The near arm much bigger than the other: a fist and a forearm grafted on."""
    sk = k.skin
    el, wr = k.raw["fore_n"][:2]
    k.l("big_forearm", el, wr, 0.09 * k.bulk, 0.08 * k.bulk, "fore_n", shade(sk, 1.06), sides=7)
    k.e("big_fist", (wr[0] + 0.01, wr[1], wr[2] - 0.04), (0.08 * k.bulk, 0.07 * k.bulk, 0.08 * k.bulk), "fore_n", shade(sk, 1.06), seg=8, rings=6)


def spare_arm(k, **_):
    m = k.m
    sk = shade(k.skin, 0.9)
    a = (0.08, -0.14 * k.bulk, m["waist"] + 0.10)
    b = (0.16, -0.15 * k.bulk, m["waist"] - 0.10)
    k.l("spare_upper", a, b, 0.035, 0.03, "spine", sk, sides=5)
    k.l("spare_lower", b, (0.24, -0.15 * k.bulk, m["waist"] - 0.02), 0.03, 0.025, "spine", sk, sides=5)
    k.e("spare_hand", (0.25, -0.15 * k.bulk, m["waist"] - 0.01), (0.03, 0.025, 0.03), "spine", sk, seg=6, rings=4)


def chains(k, color, **_):
    for bone in ("chain1", "chain2"):
        h, t, _ = k.raw[bone]
        for j in range(3):
            f = (j + 0.5) / 3
            c = tuple(h[i] + (t[i] - h[i]) * f for i in range(3))
            k.e("%s_link%d" % (bone, j), c, (0.022, 0.012, 0.034), bone, color, seg=6, rings=4)


def iron_bands(k, color, **_):
    m = k.m
    g = _girth(k)
    for i in range(2):
        k.e("iron_band%d" % i, (0.03, 0, m["waist"] + 0.10 + 0.20 * i), (g * 1.08, g * 1.22, 0.022), "spine", color, seg=10, rings=3)
    for s in "nf":
        for bone in ("arm_", "thigh_", "fore_", "shin_"):
            h, t, _ = k.raw[bone + s]
            c = tuple(h[i] + (t[i] - h[i]) * 0.5 for i in range(3))
            r = 0.05 * k.bulk
            k.e("iron_%s%s" % (bone, s), c, (r, r, 0.02), bone + s, color, s == "f", seg=8, rings=3)


def rocks(k, color, **_):
    m = k.m
    for i, (x, y, z, bone) in enumerate(((0.05, -0.13, m["neck"] - 0.06, "spine"), (-0.06, 0.1, m["waist"] + 0.2, "spine"), (0.04, -0.12, m["hip"] - 0.02, "hips"))):
        k.e("rock%d" % i, (x, y * k.bulk, z), (0.045, 0.04, 0.035), bone, color, seg=5, rings=4)


def moss(k, color, **_):
    m = k.m
    k.e("moss0", (0.02, -0.13 * k.bulk, m["neck"] - 0.04), (0.08, 0.035, 0.035), "spine", color, seg=6, rings=4)
    sh = k.raw["arm_n"][0]
    k.e("moss1", (sh[0], sh[1] - 0.03, sh[2] + 0.05), (0.05, 0.03, 0.03), "arm_n", color, seg=6, rings=4)


def coins(k, color, **_):
    m = k.m
    k.e("belt", (0.02, 0, m["waist"] - 0.03), (_girth(k) * 1.2, _girth(k) * 1.35, 0.035), "hips", (90, 70, 50), seg=10, rings=4)
    for i in range(4):
        x = 0.12 - 0.08 * i
        k.e("coin%d" % i, (x * k.bulk, -0.15 * k.bulk, m["waist"] - 0.08 - 0.03 * (i % 2)), (0.025, 0.01, 0.025), "hips", color, glow=i == 0, seg=6, rings=3)
    for s in "nf":
        wr = k.raw["fore_" + s][1]
        k.e("torc_" + s, (wr[0], wr[1], wr[2] + 0.06), (0.05 * k.bulk, 0.05 * k.bulk, 0.02), "fore_" + s, color, s == "f", seg=8, rings=3)


def fists(k, color, **_):
    for s in "nf":
        wr = k.raw["fore_" + s][1]
        k.e("fist_" + s, (wr[0] + 0.01, wr[1], wr[2] - 0.04), (0.07 * k.bulk, 0.06 * k.bulk, 0.07 * k.bulk), "fore_" + s, color, s == "f", seg=8, rings=6)


def arm_ring(k, color, **_):
    wr = k.raw["fore_f"][1]
    k.e("arm_ring", (wr[0], wr[1], wr[2] + 0.05), (0.05 * k.bulk, 0.05 * k.bulk, 0.02), "fore_f", color, True, glow=True, seg=8, rings=3)


def ruff(k, color, **_):
    m = k.m
    k.e("ruff", (0.04, 0, m["neck"] + 0.01), (0.10, 0.11, 0.04), "spine", color, seg=12, rings=4)


def seed_bag(k, color, **_):
    m = k.m
    k.e("seed_bag", (-0.02, -0.14, m["hip"] - 0.04), (0.07, 0.05, 0.08), "hips", color, seg=7, rings=5)
    k.blade("bag_fang", (0.03, -0.17, m["hip"] - 0.02), (0.05, -0.17, m["hip"] + 0.06), 0.03, 0.015, "hips", BONE)
    k.l("bag_strap", (0.10, -0.12, m["neck"] - 0.04), (-0.02, -0.14, m["hip"] + 0.02), 0.012, 0.012, "spine", color, sides=4)


def dagger_belt(k, color, **_):
    m = k.m
    k.e("belt", (0.02, 0, m["waist"] - 0.03), (_girth(k) * 1.15, _girth(k) * 1.3, 0.03), "hips", LEATHER, seg=10, rings=4)
    k.blade("belt_dagger", (0.04, -0.15, m["waist"] - 0.02), (0.12, -0.15, m["waist"] - 0.18), 0.03, 0.012, "hips", color)


def quiver(k, color, fletch=WHITE, **_):
    m = k.m
    a, b = (-0.10, 0.04, m["neck"] - 0.02), (-0.04, 0.04, m["waist"] - 0.02)
    k.l("quiver", a, b, 0.045, 0.04, "spine", color, sides=6)
    for i in range(3):
        k.l("quiver_arrow%d" % i, (a[0] - 0.01 * i, a[1] - 0.02, a[2]), (a[0] - 0.04 - 0.02 * i, a[1] - 0.02, a[2] + 0.12), 0.012, 0.012, "spine", fletch, sides=3)


def throwing_bones(k, **_):
    m = k.m
    for i in range(3):
        k.l("tbone%d" % i, (0.06 - 0.03 * i, -0.15, m["waist"] - 0.06), (0.08 - 0.03 * i, -0.15, m["waist"] - 0.18), 0.012, 0.01, "hips", BONE, sides=4)


def bandolier(k, color, tips=(), **_):
    m = k.m
    a, b = (-0.06, -0.12, m["neck"] - 0.02), (0.12, -0.13, m["waist"] - 0.02)
    k.l("bandolier", a, b, 0.016, 0.016, "spine", color, sides=4)
    for i, c in enumerate(tips):
        f = (i + 0.5) / max(1, len(tips))
        x, z = a[0] + (b[0] - a[0]) * f, a[2] + (b[2] - a[2]) * f
        k.l("band_arrow%d" % i, (x, -0.135, z), (x + 0.02, -0.135, z + 0.12), 0.008, 0.008, "spine", (120, 90, 60), sides=3)
        k.e("band_tip%d" % i, (x + 0.02, -0.135, z + 0.13), (0.012, 0.008, 0.016), "spine", c, glow=c == VIOLET, seg=4, rings=3)


def horn_hip(k, color, **_):
    m = k.m
    k.l("hunt_horn_a", (0.06, 0.13, m["hip"]), (-0.06, 0.13, m["hip"] - 0.06), 0.02, 0.03, "hips", color, True, sides=5)
    k.l("hunt_horn_b", (-0.06, 0.13, m["hip"] - 0.06), (-0.10, 0.13, m["hip"] + 0.02), 0.03, 0.045, "hips", color, True, sides=5)


def pocket_hand(k, **_):
    """The far hand thrust in a coat pocket: a flap over it."""
    wr = k.raw["fore_f"][1]
    k.e("pocket", (wr[0], wr[1] + 0.02, wr[2] - 0.02), (0.06, 0.03, 0.06), "fore_f", (80, 70, 64), True, seg=6, rings=4)


def sand(k, color, **_):
    for s in "nf":
        y = -k.m["leg_y"] if s == "n" else k.m["leg_y"]
        k.e("sand_" + s, (0.04, y - 0.01, 0.06), (0.06, 0.05, 0.025), "foot_" + s, color, s == "f", seg=6, rings=3)


# ---- held things -------------------------------------------------------------------------------------------------------------
def sword_short(k, side="n", color=RUST, **_):
    """A short notched blade, built pointing up from the hand (the form holds it point down)."""
    x, y, z = _grip(k, side)
    b = "item_" + side
    k.blade("sword", (x, y, z + 0.06), (x, y, z + 0.52), 0.075, 0.025, b, color, _far(side))
    k.box("sword_guard", (x, y, z + 0.06), (0.06, 0.03, 0.014), b, (90, 70, 56), _far(side))
    k.l("sword_grip", (x, y, z + 0.06), (x, y, z - 0.05), 0.016, 0.016, b, (90, 70, 56), _far(side), sides=4)


def cleaver(k, side="n", color=(150, 150, 156), big=1.0, **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    k.l("cleaver_haft", (x, y, z - 0.06), (x, y, z + 0.34 * big), 0.018 * big, 0.018 * big, b, WOOD, _far(side), sides=5)
    k.loft("cleaver_blade", [((x + 0.02, y, z + 0.18 * big), (0.012, 0.012)), ((x + 0.12 * big, y, z + 0.22 * big), (0.010, 0.012)),
                             ((x + 0.12 * big, y, z + 0.50 * big), (0.010, 0.012)), ((x + 0.0, y, z + 0.46 * big), (0.012, 0.012))], b, color, axis="z", sides=4)
    k.box("cleaver_face", (x + 0.07 * big, y - 0.005, z + 0.34 * big), (0.075 * big, 0.012, 0.15 * big), b, color, _far(side))


def bone_cleaver(k, side="n", color=RUST, **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    k.l("femur_haft", (x, y, z - 0.10), (x, y, z + 0.55), 0.03, 0.03, b, BONE, _far(side), sides=5)
    k.e("femur_knob", (x, y, z - 0.12), (0.045, 0.04, 0.04), b, BONE, _far(side), seg=6, rings=4)
    k.box("bc_blade", (x + 0.10, y - 0.005, z + 0.48), (0.11, 0.015, 0.16), b, color, _far(side))


def greatsword(k, side="n", color=(130, 128, 136), length=1.1, **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    k.blade("gs_blade", (x, y, z + 0.10), (x, y, z + 0.10 + length), 0.11, 0.03, b, color, _far(side))
    k.l("gs_fuller", (x, y - 0.02, z + 0.14), (x, y - 0.02, z + 0.10 + 0.7 * length), 0.01, 0.006, b, shade(color, 0.7), _far(side), sides=3)
    k.box("gs_guard", (x, y, z + 0.09), (0.14, 0.03, 0.018), b, (96, 90, 84), _far(side))
    k.l("gs_grip", (x, y, z + 0.09), (x, y, z - 0.14), 0.018, 0.018, b, (70, 56, 46), _far(side), sides=4)
    k.e("gs_pommel", (x, y, z - 0.15), (0.03, 0.03, 0.03), b, (96, 90, 84), _far(side), seg=6, rings=4)


def spear(k, side="f", length=1.25, **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    k.l("spear_shaft", (x, y, z - 0.45), (x, y, z + length - 0.45), 0.016, 0.016, b, WOOD, _far(side), sides=5)
    k.blade("spear_head", (x, y, z + length - 0.47), (x, y, z + length - 0.20), 0.07, 0.02, b, (190, 140, 70), _far(side))


def shield(k, side="n", color=(186, 128, 62), size=1.0, forward=False, **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    dy = -0.07 if side == "n" else 0.07
    cx = x + (0.04 if forward else 0.0)
    k.e("shield", (cx, y + dy, z + 0.06), (0.20 * size, 0.035, 0.20 * size), b, color, _far(side), seg=14, rings=6)
    k.e("shield_boss", (cx, y + dy * 1.6, z + 0.06), (0.05 * size, 0.02, 0.05 * size), b, shade(color, 1.25), _far(side), seg=8, rings=4)
    k.e("shield_rim", (cx, y + dy * 1.1, z + 0.06), (0.21 * size, 0.02, 0.21 * size), b, shade(color, 0.8), _far(side), seg=14, rings=4)


def bow(k, side="f", color=WHITE, half=0.42, **_):
    """A recurve bow built upright in the hand, with its string (two bones that the draw aims at the hand) and an arrow (a bone that lies along
    the stave until it is nocked)."""
    x, y, z = _grip(k, side)
    z += 0.02
    b = "item_" + side
    far = _far(side)
    depth = 0.10
    pts = [(x - depth, z - half), (x - 0.02, z - 0.6 * half), (x + 0.02, z - 0.2 * half), (x + 0.02, z + 0.2 * half), (x - 0.02, z + 0.6 * half), (x - depth, z + half)]
    for i, ((x0, z0), (x1, z1)) in enumerate(zip(pts, pts[1:])):
        r0 = 0.024 if 1 <= i <= 3 else 0.016
        k.l("stave%d" % i, (x0, y, z0), (x1, y, z1), r0, r0 * 0.9, b, color, far, sides=5)
    k.blade("tip_u", (x - depth, y, z + half), (x - depth - 0.04, y, z + half + 0.05), 0.03, 0.015, b, color, far)
    k.blade("tip_l", (x - depth, y, z - half), (x - depth - 0.04, y, z - half - 0.05), 0.03, 0.015, b, color, far)
    for bone in ("string_u", "string_l"):
        h, t, _ = k.raw[bone]
        k.l(bone, h, t, 0.006, 0.006, bone, (230, 226, 210), far, sides=3)
    h, t, _ = k.raw["arrow"]
    ax, ay, az = h
    k.l("arrow_shaft", (ax, ay, az - 0.50), (ax, ay, az + 0.12), 0.008, 0.008, "arrow", (150, 116, 80), far, sides=3)
    k.blade("arrow_head", (ax, ay, az + 0.11), (ax, ay, az + 0.19), 0.035, 0.01, "arrow", STEEL, far)
    k.blade("arrow_fletch", (ax, ay, az - 0.38), (ax, ay, az - 0.50), 0.035, 0.008, "arrow", (210, 206, 196), far)


def arrow_glow(k, color, **_):
    h, t, _ = k.raw["arrow"]
    ax, ay, az = h
    k.blade("arrow_glow", (ax, ay - 0.01, az + 0.10), (ax, ay - 0.01, az + 0.22), 0.05, 0.012, "arrow", color, glow=True)


def staff(k, side="n", color=WOOD, top="crystal", glow=VIOLET, length=1.1, **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    far = _far(side)
    bottom, tip = z - 0.45, z - 0.45 + length
    k.l("staff", (x, y, bottom), (x + 0.02, y, tip), 0.017, 0.015, b, color, far, sides=5)
    if top == "crystal":
        k.l("staff_fork", (x + 0.02, y, tip - 0.04), (x - 0.04, y, tip + 0.06), 0.014, 0.0, b, color, far, sides=4)
        k.e("crystal", (x + 0.03, y, tip + 0.05), (0.035, 0.03, 0.05), b, glow, far, glow=True, seg=5, rings=4)
    elif top == "skull":
        k.e("staff_skull", (x + 0.03, y, tip + 0.05), (0.06, 0.05, 0.055), b, (214, 204, 176), far, seg=8, rings=5)
        k.e("staff_eye", (x + 0.08, y - 0.03, tip + 0.06), (0.012, 0.01, 0.012), b, glow, far, glow=True, seg=5, rings=3)
    elif top == "sun":
        k.e("staff_sun", (x + 0.02, y, tip + 0.06), (0.07, 0.015, 0.07), b, glow, far, glow=True, seg=10, rings=4)
        k.e("staff_sun_core", (x + 0.02, y - 0.02, tip + 0.06), (0.03, 0.012, 0.03), b, (255, 236, 170), far, glow=True, seg=6, rings=3)


def goblet(k, side="n", **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    k.l("goblet_stem", (x + 0.02, y, z - 0.02), (x + 0.02, y, z + 0.07), 0.012, 0.012, b, (200, 204, 214), _far(side), sides=4)
    k.loft("goblet_cup", [((x + 0.02, y, z + 0.07), (0.02, 0.02)), ((x + 0.02, y, z + 0.14), (0.045, 0.045))], b, (200, 204, 214), _far(side), sides=6)
    k.e("goblet_blood", (x + 0.02, y, z + 0.14), (0.04, 0.04, 0.008), b, (130, 20, 36), _far(side), seg=6, rings=3)


def lantern(k, side="n", color=EMBER, **_):
    """A hollowed turnip with a coal in it, hanging from its handle (the lantern_hang bone swings)."""
    h, t, _ = k.raw["lantern_hang"]
    k.l("lantern_cord", h, t, 0.008, 0.008, "lantern_hang", (110, 90, 70), sides=3)
    c = (t[0], t[1] - 0.01, t[2] - 0.06)
    k.e("turnip", c, (0.08, 0.07, 0.07), "lantern_hang", (196, 170, 150), seg=8, rings=6)
    k.e("turnip_top", (c[0] - 0.01, c[1], c[2] + 0.07), (0.035, 0.03, 0.03), "lantern_hang", (140, 90, 110), seg=6, rings=4)
    k.e("turnip_glow", (c[0] + 0.03, c[1] - 0.06, c[2] - 0.005), (0.04, 0.012, 0.03), "lantern_hang", color, glow=True, seg=6, rings=3)
    k.box("turnip_grin", (c[0] + 0.03, c[1] - 0.065, c[2] - 0.03), (0.035, 0.008, 0.008), "lantern_hang", color, glow=True)
    x, y, z = _grip(k, side)
    k.l("lantern_handle", (x, y, z - 0.02), (x + 0.01, y, z - 0.06), 0.01, 0.01, "item_" + side, (90, 70, 56), sides=3)


def whip(k, length=1.0, **_):
    """A whip of a human spine: a run of vertebrae down five bones."""
    for i in range(1, 6):
        bone = "whip%d" % i
        h, t, _ = k.raw[bone]
        k.l(bone, h, t, 0.014 if i < 5 else 0.01, 0.012 if i < 5 else 0.004, bone, (196, 186, 160), sides=4)
        k.e(bone + "_vert", tuple((h[j] + t[j]) / 2 for j in range(3)), (0.026, 0.022, 0.026), bone, (214, 204, 176), seg=5, rings=3)
    x, y, z = _grip(k, "n")
    k.l("whip_handle", (x, y, z - 0.10), (x, y, z + 0.06), 0.018, 0.018, "item_n", (70, 56, 46), sides=4)


def head_held(k, hair=(70, 60, 50), **_):
    """The dullahan's own head, under its far arm: pale, grinning, wild-haired."""
    h, t, _ = k.raw["held_head"]
    c = (h[0] + 0.04, h[1], h[2] + 0.06)
    k.e("held_head", c, (0.09, 0.08, 0.10), "held_head", (226, 222, 208), True, seg=9, rings=6)
    k.e("held_hair", (c[0] - 0.03, c[1], c[2] + 0.05), (0.09, 0.085, 0.08), "held_head", hair, True, seg=8, rings=5)
    k.blade("held_hair_tuft", (c[0] - 0.06, c[1], c[2] + 0.06), (c[0] - 0.18, c[1], c[2] + 0.12), 0.06, 0.02, "held_head", hair, True)
    k.e("held_eye", (c[0] + 0.08, c[1] - 0.04, c[2] + 0.01), (0.016, 0.012, 0.014), "held_head", (236, 220, 140), True, glow=True, seg=5, rings=3)
    k.box("held_grin", (c[0] + 0.08, c[1] - 0.04, c[2] - 0.05), (0.03, 0.008, 0.008), "held_head", (60, 30, 30), True)
    k.e("neck_stump", (0.04, 0, k.m["neck"] + 0.02), (0.05, 0.05, 0.025), "spine", (120, 40, 50), seg=7, rings=4)


def fangs_held(k, side="n", **_):
    pass


def crook_flail(k, color=GOLD, band=(52, 76, 150), **_):
    for s, d in (("n", 1), ("f", -1)):
        x, y, z = _grip(k, s)
        b = "item_" + s
        far = _far(s)
        k.l("rod_" + s, (x, y, z - 0.10), (x + 0.02 * d, y, z + 0.34), 0.016, 0.016, b, color, far, sides=4)
        k.e("rod_band_" + s, (x, y, z + 0.10), (0.022, 0.022, 0.02), b, band, far, seg=5, rings=3)
        if s == "n":
            k.l("crook_hook", (x + 0.02, y, z + 0.34), (x + 0.08, y, z + 0.38), 0.014, 0.012, b, color, far, sides=4)
            k.l("crook_hook2", (x + 0.08, y, z + 0.38), (x + 0.09, y, z + 0.30), 0.012, 0.01, b, color, far, sides=4)
        else:
            for i in range(3):
                k.l("flail%d" % i, (x - 0.02, y, z + 0.34), (x - 0.10 + 0.03 * i, y, z + 0.20), 0.01, 0.01, b, band, far, sides=3)


def balance(k, side="n", color=(196, 150, 70), heart=(162, 30, 48), feather=WHITE, **_):
    x, y, z = _grip(k, side)
    b = "item_" + side
    k.l("bal_post", (x, y, z), (x, y, z + 0.16), 0.01, 0.01, b, color, sides=3)
    k.l("bal_beam", (x - 0.08, y, z + 0.15), (x + 0.08, y, z + 0.15), 0.008, 0.008, b, color, sides=3)
    for i, (dx, item) in enumerate(((-0.08, heart), (0.08, feather))):
        k.e("bal_pan%d" % i, (x + dx, y, z + 0.08), (0.035, 0.03, 0.01), b, color, seg=6, rings=3)
        k.e("bal_item%d" % i, (x + dx, y, z + 0.10), (0.02, 0.015, 0.022), b, item, glow=i == 0, seg=5, rings=3)


def sword_hilt(k, color=GOLD, gem=ROSE, **_):
    m = k.m
    k.l("scabbard", (0.02, -0.16, m["hip"] + 0.02), (-0.20, -0.16, m["hip"] - 0.45), 0.024, 0.02, "hips", (60, 46, 56), sides=5)
    k.l("hilt", (0.02, -0.17, m["hip"] + 0.02), (0.08, -0.17, m["hip"] + 0.12), 0.015, 0.015, "hips", color, sides=4)
    k.box("hilt_guard", (0.02, -0.17, m["hip"] + 0.02), (0.012, 0.02, 0.05), "hips", color)
    k.e("hilt_gem", (0.085, -0.18, m["hip"] + 0.13), (0.016, 0.012, 0.016), "hips", gem, glow=True, seg=5, rings=3)


GEAR = {name: fn for name, fn in globals().items() if callable(fn) and not name.startswith("_") and fn.__module__ == __name__ and name not in ("shade",)}
GEAR["fangs"] = lambda k, side=None, **kw: (_handful(k, side) if side else fangs(k, **kw))


def _handful(k, side):
    x, y, z = _grip(k, side)
    for i in range(3):
        k.blade("handful%d" % i, (x - 0.01 + 0.02 * i, y - 0.02, z + 0.0), (x + 0.02 * i, y - 0.02, z + 0.09), 0.025, 0.012, "item_" + side, BONE)
