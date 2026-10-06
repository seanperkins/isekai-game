"""Gear for the spider kit (spider_kit.py): markings, eyes, the brood, cocoons, silk, veils, scythes, a drider's clothes and what it holds. Each piece
is written against the bones and the sizes of the form's own skeleton (spider_skeleton.py), so it sits right on a lean stalker or a bloated
matriarch. A form lists its gear by name in spider_forms.py. Glowing parts (eyes, marks, venom, silk) are lit whatever their shape. Pure Python at
import (no bpy): the kit it is given does the building.
"""
import math

RED, BLOOD, EMBER = (206, 40, 52), (170, 30, 44), (255, 110, 50)
WATER, AIR, GOLD, PEACH, DARK = (86, 170, 236), (150, 222, 236), (232, 186, 80), (240, 186, 160), (58, 46, 82)
TAN, CLAY, SILK = (196, 170, 124), (150, 124, 90), (226, 222, 210)
EYE = (255, 70, 70)
FANG = (60, 50, 62)


def _rng(seed):
    """A small repeatable random sequence (the same spiderlings every render)."""
    state = [seed * 2654435761 % 4294967296 or 1]

    def nxt():
        state[0] = (1103515245 * state[0] + 12345) % 2147483648
        return state[0] / 2147483648.0
    return nxt


# ---- markings and eyes ------------------------------------------------------------------------------------------------------------
def hourglass(g, color=None, dim=False, cracks=False, slim=False, woven=False, runes=False, **_):
    """The red markings on the abdomen's side: two or three swept slashes (as on the plain spider), or thin glowing cracks, a woven diamond band,
    gold runes."""
    color = color or g.mark
    if runes:
        color = GOLD
    glow = False
    if cracks:
        for i, (u, v, du, dv) in enumerate(((-0.3, 0.2, 0.35, -0.25), (0.1, -0.1, 0.3, 0.2), (0.35, 0.35, 0.25, -0.15), (-0.05, 0.55, 0.25, 0.05))):
            g.mark_line("crack%d" % i, (u, v), (u + du, v + dv), 0.035, color, glow=True)
        return
    if woven or runes:
        for i in range(5):
            u = -0.55 + 0.27 * i
            g.mark_line("diaA%d" % i, (u, 0.05), (u + 0.13, 0.30), 0.04, color, glow=True)
            g.mark_line("diaB%d" % i, (u + 0.13, 0.30), (u + 0.26, 0.05), 0.04, color, glow=True)
        return
    w = 0.12 if not slim else 0.08
    g.mark_line("slash0", (-0.55, 0.30), (0.10, -0.05), w, color, glow=glow)
    g.mark_line("slash1", (-0.05, 0.62), (0.60, 0.18), w, color, glow=glow)
    g.mark_line("slash2", (0.55, -0.30), (0.80, -0.45), w * 0.7, color, glow=False)


def eyes(g, color=None, small=False, big=False, **_):
    """A cluster of eyes on the front of the carapace: two large forward ones and smaller ones above them."""
    color = color or g.eye
    r = 0.036 if not big else 0.05
    if small:
        r = 0.024
    pts = ((0.92, 1.05, -0.45), (0.78, 1.22, -0.40), (0.60, 1.30, -0.30), (1.02, 0.85, -0.40))
    for i, (u, v, y) in enumerate(pts):
        rr = r * (1.0 if i < 2 else 0.75)
        g.e("eye%d" % i, g.thorax_point(u, v, y), (rr, rr, rr), "body", color, glow=True, seg=6, rings=4)


def spider_eyes(g, color=EYE, **_):
    """A second row of small red spider eyes across a drider's forehead."""
    for i in range(3):
        g.e("feye%d" % i, g.head_point(0.55 + 0.12 * i, 0.82 - 0.04 * i, -0.075), (0.012, 0.012, 0.012), "head", color, glow=True, seg=6, rings=4)


def seven_eyes(g, color=AIR, **_):
    """Seven large glowing eyes in an arc across the forehead and temples."""
    for i in range(7):
        a = math.radians(-70 + 140 * i / 6.0)
        g.e("seven%d" % i, g.head_point(0.55 + 0.32 * math.sin(a), 0.70 + 0.20 * math.cos(a), -0.075), (0.014, 0.014, 0.014), "head", color, glow=True, seg=6, rings=4)


def six_eyes(g, color=AIR, **_):
    for i in range(6):
        g.e("eye%d" % i, g.thorax_point(0.98 - 0.09 * i, 0.45 + 0.12 * (i % 2), -0.30), (0.018, 0.018, 0.018), "body", color, glow=True, seg=6, rings=4)


def fangs(g, size=1.0, drip=False, **_):
    """Bigger fangs, and beads of venom on their tips."""
    h, t, _ = g.bones["fang"]
    for s, y in (("n", -0.05), ("f", 0.05)):
        g.blade("bigfang_" + s, (h[0] + 0.01, y * g.th, h[2] - 0.03), (t[0] + 0.03 * size, y * g.th, t[2] - 0.05 * size), 0.05 * size, 0.03, "fang", g.fang_c, far=s == "f")
    if drip:
        for i in range(2):
            g.e("drop%d" % i, (t[0] + 0.03 * size + 0.01 * i, -0.04, t[2] - 0.06 * size - 0.035 * i), (0.022, 0.018, 0.026), "fang", WATER, glow=True, seg=6, rings=4)


# ---- the brood --------------------------------------------------------------------------------------------------------------------
LING = (92, 84, 104)


def spiderling(g, name, at, size, bone, color=None, glint=None):
    """A tiny spider: a round body (a shade lighter than its mother, so the mass of them reads as lumps) and a fringe of leg stubs."""
    color = color or LING
    g.e(name, at, (size, size * 0.8, size * 0.75), bone, color, seg=6, rings=4)
    for j, a in enumerate((-60, 0, 60)):
        ra = math.radians(a)
        g.l(name + "_l%d" % j, at, (at[0] + 1.8 * size * math.sin(ra), at[1] - 0.6 * size, at[2] - 1.6 * size * math.cos(ra) * 0.6), size * 0.30, size * 0.18, bone, color, sides=4)
    if glint:
        g.e(name + "_g", (at[0] + size * 0.6, at[1] - size * 0.7, at[2] + size * 0.3), (size * 0.25,) * 3, bone, glint, glow=True, seg=4, rings=3)


def brood(g, count=20, **_):
    """Spiderlings clinging all over the top and the near side of the abdomen as one lumpy mass, each with a pin-prick of red eye."""
    rnd = _rng(count)
    for i in range(count):
        u = -0.85 + 1.7 * rnd()
        v = 0.05 + 0.95 * rnd()
        y = -1.0 + 1.2 * rnd()
        size = 0.034 + 0.016 * rnd()
        spiderling(g, "ling%d" % i, g.abdomen_point(u, v, y, out=1.04), size, "abdomen", glint=EYE if i % 3 == 0 else None)


def egg_sac(g, color=TAN, **_):
    c = g.abdomen_point(0.75, -0.75, 0.0, out=0.9)
    g.e("eggsac", c, (0.10, 0.09, 0.085), "abdomen", color, seg=8, rings=6)


def plates(g, color=TAN, **_):
    """Armoured plates over the top of the abdomen."""
    for i in range(4):
        u = -0.5 + 0.33 * i
        a = g.abdomen_point(u, 0.92 - 0.1 * abs(u), 0.0, out=1.02)
        b = g.abdomen_point(u + 0.22, 0.85 - 0.1 * abs(u), 0.0, out=1.02)
        g.blade("plate%d" % i, a, (b[0], b[1], b[2] + 0.06), 0.10, 0.09 * g.ab, "abdomen", color)


def crown(g, color=None, gem=None, **_):
    """A crest of chitin spines over the head, and a gem glint between the eyes."""
    color = color or g.chitin
    for i in range(5):
        p = g.thorax_point(-0.2 + 0.25 * i, 0.9, -0.2)
        g.blade("spine%d" % i, p, (p[0] - 0.04, p[1], p[2] + 0.13 + 0.05 * (i % 2)), 0.06, 0.035, "body", color)
    if gem:
        g.e("gem", g.thorax_point(0.98, 0.75, -0.25), (0.022, 0.018, 0.022), "body", gem, glow=True, seg=6, rings=4)


def wrapping(g, color=TAN, **_):
    """Bands of silk wound round the abdomen."""
    for i in range(4):
        g.band("wrap%d" % i, -0.6 + 0.4 * i, 0.035, color)


def cocoons(g, color=(214, 196, 150), core=(120, 100, 84), **_):
    """Lumpy pale cocoons strapped over the abdomen, each a rounded oval with a faint dark shape inside."""
    for i, (u, v, y) in enumerate(((-0.45, 0.6, -0.6), (0.25, 0.75, -0.55), (0.75, 0.15, -0.6), (0.0, -0.1, -1.0), (-0.1, 0.95, 0.2))):
        p = g.abdomen_point(u, v, y, out=1.0)
        g.e("cocoon%d" % i, p, (0.11, 0.08, 0.08), "abdomen", color, seg=8, rings=6)
        g.e("cocoon%d_c" % i, (p[0], p[1] - 0.07, p[2]), (0.05, 0.02, 0.03), "abdomen", core, seg=6, rings=4)


def held_cocoon(g, color=(214, 196, 150), core=(120, 100, 84), **_):
    """One more cocoon clutched between the front legs, held in close under the head."""
    a = _held_tip(g, "n0", 98.0, 0.62)
    c = (a[0] - 0.04, -0.12, a[2] - 0.02)
    g.e("held", c, (0.10, 0.07, 0.075), "body", color, seg=8, rings=6)
    g.e("held_c", (c[0] + 0.01, c[1] - 0.06, c[2]), (0.045, 0.02, 0.03), "body", core, seg=6, rings=4)


def swarmlings(g, **_):
    """The rear of the abdomen breaking up into a tight cloud of spiderlings and specks, carried by the four swarm bones that scuttle."""
    rnd = _rng(7)
    for j in range(1, 5):
        h, t, _ = g.bones["swarm%d" % j]
        for i in range(7):
            at = (h[0] + (rnd() - 0.5) * 0.16, -g.sh["ay"] * (0.2 + 0.8 * rnd()), h[2] + (rnd() - 0.5) * 0.16)
            if i < 3:
                spiderling(g, "sw%d_%d" % (j, i), at, 0.028 + 0.012 * rnd(), "swarm%d" % j, glint=AIR if i == 0 else None)
            else:
                g.e("speck%d_%d" % (j, i), at, (0.014, 0.012, 0.014), "swarm%d" % j, g.chitin, seg=4, rings=3)


# ---- hide -------------------------------------------------------------------------------------------------------------------------
def knobs(g, color=(86, 78, 92), **_):
    """A knobbly, scarred hide: lumps standing out over the abdomen."""
    rnd = _rng(3)
    for i in range(14):
        p = g.abdomen_point(-0.9 + 1.8 * rnd(), -0.3 + 1.3 * rnd(), -1.0 + 1.1 * rnd(), out=1.02)
        g.e("knob%d" % i, p, (0.04, 0.035, 0.035), "abdomen", color, seg=5, rings=4)


def leg_spikes(g, color=TAN, **_):
    """Spikes along the femurs and dust caked on the lower legs."""
    for key in g.leg_keys:
        far = key[0] == "f"
        h, t, _ = g.bones["fem_" + key]
        m = tuple(h[i] + 0.6 * (t[i] - h[i]) for i in range(3))
        g.blade("lspike_" + key, m, (m[0] - 0.02, m[1], m[2] + 0.08), 0.035, 0.02, "fem_" + key, color, far=far)


def dust(g, color=TAN, **_):
    g.leg_low = color


def clay_crust(g, color=CLAY, **_):
    """Clay and stone crusted over the abdomen and the carapace."""
    rnd = _rng(11)
    for i in range(9):
        p = g.abdomen_point(-0.8 + 1.6 * rnd(), 0.1 + 0.8 * rnd(), -0.6, out=1.0)
        g.e("clay%d" % i, p, (0.07, 0.05, 0.045), "abdomen", color, seg=5, rings=4)
    g.leg_low = color


def hair(g, **_):
    """A tarantula's hair: tufts along the abdomen's outline and bristles on the legs."""
    for i in range(12):
        a = math.radians(30 + 300 * i / 11.0)
        p = g.abdomen_point(math.cos(a), math.sin(a), -0.1, out=1.0)
        q = g.abdomen_point(math.cos(a) * 1.25, math.sin(a) * 1.25, -0.1, out=1.0)
        g.blade("tuft%d" % i, p, q, 0.05, 0.03, "abdomen", g.dark)
    for key in g.leg_keys:
        for bone in ("fem_", "tib_"):
            h, t, _ = g.bones[bone + key]
            m = tuple(h[i] + 0.5 * (t[i] - h[i]) for i in range(3))
            g.blade("bristle_%s%s" % (bone, key), m, (m[0] + 0.03, m[1], m[2] + 0.06), 0.06, 0.02, bone + key, g.leg_c, far=key[0] == "f")


def ribbons(g, color=RED, **_):
    """Red cloth ribbons tied at the knees, fluttering."""
    for key in g.leg_keys:
        if int(key[1]) > 1:
            continue
        h, t, _ = g.bones["tib_" + key]
        g.blade("ribbon_" + key, (h[0], h[1], h[2] - 0.02), (h[0] - 0.12, h[1], h[2] - 0.08), 0.05, 0.012, "tib_" + key, color, far=key[0] == "f")


def venom_sheen(g, color=WATER, **_):
    for key in g.leg_keys:
        if key[0] != "n":
            continue
        h, t, _ = g.bones["tib_" + key]
        m = tuple(h[i] + 0.45 * (t[i] - h[i]) for i in range(3))
        g.e("sheen_" + key, (m[0], m[1] - 0.02, m[2]), (0.014, 0.012, 0.05), "tib_" + key, color, glow=True, seg=5, rings=4)


def blisters(g, color=WATER, **_):
    """Swollen blister-sacs glowing blue over the abdomen."""
    rnd = _rng(5)
    for i in range(9):
        p = g.abdomen_point(-0.75 + 1.5 * rnd(), -0.3 + 1.1 * rnd(), -0.55, out=1.0)
        r = 0.035 + 0.03 * rnd()
        g.e("blister%d" % i, p, (r, r * 0.8, r), "abdomen", color, glow=i % 2 == 0, seg=6, rings=4)


def vapour(g, color=(150, 160, 190), **_):
    for i in range(3):
        p = g.abdomen_point(-0.3 + 0.35 * i, 1.0, 0.0, out=1.05)
        g.blade("vapour%d" % i, p, (p[0] - 0.08, 0.0, p[2] + 0.16 + 0.04 * (i % 2)), 0.06, 0.02, "abdomen", color)


def maw(g, color=(16, 12, 24), lip=(80, 60, 110), **_):
    """A wide gaping mouth on the front of the carapace, a rim of violet round the dark."""
    g.e("maw_lip", g.thorax_point(1.0, -0.2, -0.3), (0.06, 0.07, 0.08), "body", lip, seg=8, rings=5)
    g.e("maw", g.thorax_point(1.06, -0.2, -0.4), (0.045, 0.06, 0.06), "body", color, seg=8, rings=5)


def sparks(g, color=GOLD, **_):
    """Small sparks of swallowed lamplight caught on the fangs and spines, fading."""
    h, t, _ = g.bones["fang"]
    g.e("spark0", (t[0] + 0.03, -0.07, t[2] + 0.01), (0.026,) * 3, "fang", color, glow=True, seg=5, rings=3)
    for i, (u, v, y) in enumerate(((0.2, 0.9, -0.5), (-0.4, 0.75, -0.6), (0.6, 0.5, -0.7), (-0.1, 0.2, -1.0))):
        g.e("spark%d" % (i + 1), g.abdomen_point(u, v, y, out=1.03), (0.022,) * 3, "abdomen", color if i % 2 == 0 else (150, 120, 70), glow=i % 2 == 0, seg=5, rings=3)


def smoke(g, color=(64, 52, 100), **_):
    """Edges dissolving into smoke: dark wisps off the abdomen and the knees."""
    for i in range(4):
        a = math.radians(40 + 50 * i)
        p = g.abdomen_point(math.cos(a), math.sin(a), 0.0, out=1.0)
        g.blade("smoke%d" % i, p, (p[0] - 0.14, 0.0, p[2] + 0.04 + 0.03 * i), 0.07, 0.02, "abdomen", color, glow=False)


def midline(g, color=EMBER, **_):
    """A hairline ember glow along the abdomen's midline."""
    g.mark_line("mid", (-0.85, 0.15), (0.85, 0.35), 0.025, color, glow=True)


def scythes(g, color=None, edge=(120, 112, 136), **_):
    """Oversized curved scythes on the front pair: a long blade along the tibia and a hooked one past the claw, with a pale edge catching the light."""
    color = color or g.leg_c
    for s in "nf":
        key = s + "0"
        far = s == "f"
        th, tt, _ = g.bones["tib_" + key]
        h, t, _ = g.bones["tar_" + key]
        d = (t[0] - h[0], t[1] - h[1], t[2] - h[2])
        g.blade("scythe_a_" + key, th, (tt[0] + 0.3 * (tt[0] - th[0]), tt[1], tt[2] + 0.3 * (tt[2] - th[2])), 0.12, 0.03, "tib_" + key, color, far=far)
        tip = (h[0] + 2.8 * d[0], h[1], h[2] + 2.8 * d[2])
        g.blade("scythe_b_" + key, h, tip, 0.15, 0.03, "tar_" + key, color, far=far)
        g.blade("scythe_e_" + key, (h[0] + 0.5 * d[0], h[1] - 0.012, h[2] + 0.5 * d[2] + 0.02), tip, 0.025, 0.01, "tar_" + key, edge, far=far)


def coil(g, color=AIR, beads=False, **_):
    """A coil of silk line at the spinnerets."""
    tip = g.abdomen_point(1.0, 0.0, 0.0, out=1.02)
    for i in range(3):
        a = 2.0 * math.pi * i / 3.0
        g.e("coil%d" % i, (tip[0] - 0.04 + 0.04 * math.cos(a), 0.0, tip[2] - 0.03 + 0.04 * math.sin(a)), (0.03, 0.02, 0.012), "abdomen", color, glow=True, seg=6, rings=3)
    if beads:
        for i in range(2):
            g.e("bead%d" % i, (tip[0] - 0.02 * i, -0.02, tip[2] - 0.07 - 0.02 * i), (0.016,) * 3, "abdomen", WATER, glow=True, seg=5, rings=3)


def cable(g, color=AIR, **_):
    """A short thick coil of bright silk cable looping from raised spinnerets, close to the body."""
    tip = g.abdomen_point(1.0, 0.2, 0.0, out=1.0)
    for i in range(4):
        a = 2.0 * math.pi * i / 4.0
        g.l("cable%d" % i, (tip[0] + 0.05 * math.cos(a), 0.0, tip[2] + 0.05 * math.sin(a)), (tip[0] + 0.05 * math.cos(a + 1.6), 0.0, tip[2] + 0.05 * math.sin(a + 1.6) - 0.02),
            0.016, 0.016, "abdomen", color, glow=True, sides=4)


def _held_tip(g, key, angle, reach):
    """Where a raised foreleg's claw is held in the idle (spider_motion.RAISED): `angle` from the hip, `reach` of the leg's length."""
    hip, knee, _ = g.bones["fem_" + key]
    _, ankle, _ = g.bones["tib_" + key]
    length = math.hypot(knee[0] - hip[0], knee[2] - hip[2]) + math.hypot(ankle[0] - knee[0], ankle[2] - knee[2])
    a = math.radians(angle)
    return (hip[0] + reach * length * math.sin(a), hip[1], hip[2] - reach * length * math.cos(a))


def veil(g, color=(66, 92, 112), thread=(170, 228, 238), **_):
    """A sheer silk veil held up on the raised forelegs and draped back over the body: glowing threads from where the foreleg tips are held, over the
    back to the end of the abdomen, and hanging down the near side, a pale sheet between them. Skinned to the body at the front and the abdomen
    behind."""
    lead = _held_tip(g, "n0", 140.0, 0.84)
    back = g.abdomen_point(0.75, 0.6, -0.3, out=1.1)
    top = g.abdomen_point(-0.2, 1.0, -0.3, out=1.15)
    y = -g.sh["ay"] * 1.2
    front = lead[0]

    def weights(v):
        u = max(0.0, min(1.0, (front - v.x) / max(1e-6, front - back[0])))
        return {"body": (1.0 - u) ** 2, "abdomen": 1.0 - (1.0 - u) ** 2}

    def edge(u):
        if u <= 0.5:
            w = 2 * u
            return (lead[0] + (top[0] - lead[0]) * w, lead[2] + (top[2] - lead[2]) * w + 0.06 * math.sin(math.pi * w))
        w = 2 * u - 1
        return (top[0] + (back[0] - top[0]) * w, top[2] + (back[2] - top[2]) * w)
    for j, yy in enumerate((y, -y)):
        g.strip("veil_edge%d" % j, [(edge(i / 8.0)[0], yy, edge(i / 8.0)[1]) for i in range(9)], 0.03, weights, thread, glow=True, far=j == 1)
    cols = []
    for i in range(7):
        x, z = edge(0.08 + 0.88 * i / 6.0)
        bottom = max(g.sh["hc"] * 1.1, z - 0.12 - 0.22 * (i / 6.0) - 0.05 * (i % 2))
        cols.append(((x, y, z), (x - 0.03, y, bottom)))
        if i % 2 == 0:
            g.strip("veil_drop%d" % i, [(x, y - 0.006, z), (x - 0.015, y - 0.006, (z + bottom) / 2), (x - 0.03, y - 0.006, bottom)], 0.022, weights, thread, glow=True)
    g.sheet_xy("veil", cols, weights, color)


# ---- the drider's things ----------------------------------------------------------------------------------------------------------
def bodice(g, color=DARK, sleeves=True, **_):
    """A close bodice over the chest and the waist, and its sleeves."""
    g.dress_torso(color)
    if sleeves:
        for s in "nf":
            h, t, _ = g.bones["arm_" + s]
            g.l("sleeve_" + s, h, t, 0.040 * g.tall, 0.034 * g.tall, "arm_" + s, color, far=s == "f")


def kimono(g, shroud=False, hood=False, **_):
    """A long robe over the torso with wide hanging sleeves and a skirt that falls over the front of the spider (cloth on the cloth bones); a wide
    obi; for the spirits a ragged shroud, for the norn a hood thrown back."""
    robe, trim = g.form.get("robe", DARK), g.form.get("trim", RED)
    g.dress_torso(robe)
    if not shroud:
        g.obi(trim)
    for s in "nf":
        far = s == "f"
        h, t, _ = g.bones["arm_" + s]
        g.l("sleeve_" + s, h, t, 0.045 * g.tall, 0.05 * g.tall, "arm_" + s, robe, far=far)
        fh, ft, _ = g.bones["fore_" + s]
        g.loft("cuff_" + s, [((fh[0], fh[1], fh[2]), (0.05 * g.tall, 0.04 * g.tall)), ((fh[0] + (ft[0] - fh[0]) * 0.6, fh[1], fh[2] + (ft[2] - fh[2]) * 0.6), (0.06 * g.tall, 0.045 * g.tall))],
               "fore_" + s, robe, axis="z", sides=6, far=far)
        g.blade("hang_" + s, (fh[0] + (ft[0] - fh[0]) * 0.5, fh[1], fh[2] + (ft[2] - fh[2]) * 0.5 - 0.02), (fh[0] - 0.02, fh[1], fh[2] - 0.13 * g.tall), 0.07 * g.tall, 0.01,
                "fore_" + s, robe if not shroud else trim, far=far)
    g.skirt(robe, trim, ragged=shroud)
    if hood:
        g.hood(robe, trim)


def loincloth(g, color=(80, 60, 50), **_):
    g.skirt(color, color, ragged=True, short=True)


def fan(g, color=RED, rib=(40, 30, 40), **_):
    """A folding fan open in the near hand."""
    h, t, _ = g.bones["item_n"]
    for i in range(3):
        a = math.radians(-40 + 40 * i)
        g.blade("fan%d" % i, h, (h[0] + 0.12 * math.sin(a) * g.tall, -0.11 * g.tall, h[2] + 0.13 * math.cos(a) * g.tall), 0.07 * g.tall, 0.01, "item_n", color)
    g.l("fanrib", h, (h[0], -0.11 * g.tall, h[2] + 0.04), 0.008, 0.008, "item_n", rib, sides=4)


def sleeve_silk(g, color=AIR, **_):
    for s in "nf":
        fh, ft, _ = g.bones["fore_" + s]
        g.blade("ssilk_" + s, (fh[0], fh[1], fh[2] - 0.03), (fh[0] - 0.03, fh[1], fh[2] - 0.18 * g.tall), 0.02, 0.01, "fore_" + s, color, far=s == "f", glow=True)


def leg_tips(g, **_):
    """Long sharp black leg tips showing under the hem."""
    for s in "nf":
        h, t, _ = g.bones["tar_%s0" % s]
        g.blade("ltip_" + s, h, (t[0] + 0.02, t[1], t[2]), 0.03, 0.02, "tar_%s0" % s, (24, 22, 30), far=s == "f")


def silk_strand(g, color=AIR, **_):
    """A fine strand of silk drawn out between the fingers of the near hand."""
    h, t, _ = g.bones["item_n"]
    g.l("strand", h, (h[0] + 0.12 * g.tall, -0.10 * g.tall, h[2] - 0.10 * g.tall), 0.009, 0.006, "item_n", color, glow=True, sides=4)


def bow(g, color=(124, 92, 64), string=(220, 220, 230), **_):
    """A small bow in the far hand: a curved stave of three blades and a string."""
    h, t, _ = g.bones["item_f"]
    k = g.tall
    top, bot = (h[0] + 0.03 * k, h[1], h[2] + 0.16 * k), (h[0] + 0.03 * k, h[1], h[2] - 0.16 * k)
    mid = (h[0] + 0.06 * k, h[1], h[2])
    g.l("bow_a", mid, top, 0.014 * k, 0.008 * k, "item_f", color, far=True, sides=4)
    g.l("bow_b", mid, bot, 0.014 * k, 0.008 * k, "item_f", color, far=True, sides=4)
    g.l("bow_s", (top[0] - 0.04 * k, top[1], top[2]), (bot[0] - 0.04 * k, bot[1], bot[2]), 0.004, 0.004, "item_f", string, far=True, sides=4)


def hairband(g, color=(196, 160, 90), **_):
    g.loft("hairband", [(g.head_point(0.35, 0.80, 0.0), (0.012, 0.075 * g.tall)), (g.head_point(0.70, 0.95, 0.0), (0.012, 0.075 * g.tall))], "head", color, axis="x", sides=6)


def shuttle(g, color=(150, 110, 70), **_):
    h, t, _ = g.bones["item_n"]
    g.blade("shuttle", (h[0] - 0.04, -0.12 * g.tall, h[2]), (h[0] + 0.10 * g.tall, -0.12 * g.tall, h[2] + 0.04), 0.035, 0.03, "item_n", color)


def tapestry(g, color=(150, 214, 228), pattern=DARK, **_):
    """A half-woven band of silk hanging from the arms, worked with dark diamonds."""
    fh, ft, _ = g.bones["fore_f"]
    _, an, _ = g.bones["arm_n"]
    cols = []
    for i in range(4):
        u = i / 3.0
        x = fh[0] + (ft[0] - fh[0]) * u
        z = fh[2] + (ft[2] - fh[2]) * u - 0.02
        cols.append(((x, -0.13 * g.tall, z), (x - 0.02, -0.13 * g.tall, z - 0.16 * g.tall - 0.03 * (i % 2))))
    g.sheet_xy("tapestry", cols, lambda v: {"fore_f": 1.0}, color)
    for i in range(2):
        x = fh[0] + (ft[0] - fh[0]) * (0.3 + 0.4 * i)
        z = fh[2] + (ft[2] - fh[2]) * (0.3 + 0.4 * i) - 0.09 * g.tall
        g.e("diamond%d" % i, (x, -0.14 * g.tall, z), (0.022, 0.006, 0.03), "fore_f", pattern, seg=4, rings=3)


def silk_ropes(g, color=(210, 216, 226), knot=AIR, **_):
    """Seven pale silk ropes hanging from the waist side by side like a curtain, each tied with a glowing knot."""
    h, t, _ = g.bones["waist"]
    for i in range(7):
        x = h[0] - 0.06 * g.tall + 0.025 * g.tall * i
        top = (x, -0.10 * g.tall, h[2] + 0.04)
        bot = (x - 0.02, -0.11 * g.tall, max(g.sh["hc"] * 0.5, h[2] - 0.16 * g.tall - 0.02 * (i % 3)))
        g.l("rope%d" % i, top, bot, 0.007, 0.006, "waist", color, sides=4)
        g.e("knot%d" % i, (bot[0], bot[1], bot[2] + 0.05), (0.012,) * 3, "waist", knot, glow=True, seg=4, rings=3)


def oni(g, horn=(214, 206, 182), tusk=(232, 228, 210), **_):
    """An oni's horned, tusked head and a muscular bare chest."""
    k = g.tall
    g.blade("horn_n", g.head_point(0.45, 0.85, -0.05), g.head_point(0.25, 1.25, -0.06), 0.035 * k, 0.03, "head", horn)
    g.blade("horn_f", g.head_point(0.40, 0.85, 0.05), g.head_point(0.18, 1.20, 0.06), 0.035 * k, 0.03, "head", horn, far=True)
    g.blade("tusk", g.head_point(0.85, 0.20, -0.03), g.head_point(0.92, 0.42, -0.04), 0.02 * k, 0.015, "head", tusk)
    c = g.bones["chest"]
    g.e("pec", (c[0][0] + 0.06 * k, -0.02, c[0][2] + 0.14 * k), (0.06 * k, 0.07 * k, 0.05 * k), "chest", g.skin)
    for s in "nf":
        h, t, _ = g.bones["arm_" + s]
        g.e("delt_" + s, (h[0], h[1], h[2] - 0.02), (0.05 * k, 0.045 * k, 0.05 * k), "arm_" + s, g.skin, far=s == "f")


def halo(g, color=GOLD, gem=PEACH, **_):
    """A thin warm-gold band above the brow and a glint at the forehead."""
    k = g.tall
    g.loft("halo", [(g.head_point(0.25, 1.05, 0.0), (0.012, 0.08 * k)), (g.head_point(0.75, 1.15, 0.0), (0.012, 0.08 * k))], "head", color, axis="x", sides=6, glow=True)
    g.e("glint", g.head_point(0.85, 0.72, -0.07), (0.012,) * 3, "head", gem, glow=True, seg=4, rings=3)


def gold_thread(g, color=GOLD, **_):
    """A glowing gold thread held taut between the hands."""
    hn, _, _ = g.bones["item_n"]
    hf, _, _ = g.bones["item_f"]
    g.l("thread", hn, (hf[0], -0.10 * g.tall, hf[2]), 0.008, 0.008, "item_n", color, glow=True, sides=4)


def shears(g, color=GOLD, **_):
    h, t, _ = g.bones["waist"]
    g.blade("shears", (h[0] + 0.05, -0.11 * g.tall, h[2] + 0.06), (h[0] + 0.07, -0.11 * g.tall, h[2] - 0.02), 0.03, 0.01, "waist", color)


def hat(g, color=(120, 82, 46), band=(196, 44, 52), **_):
    """A wide-brimmed hat."""
    k = g.tall
    g.loft("brim", [(g.head_point(-0.05, 0.92, 0.0), (0.012, 0.13 * k)), (g.head_point(1.30, 0.92, 0.0), (0.012, 0.13 * k))], "head", color, axis="x", sides=8)
    g.loft("crown_h", [(g.head_point(0.25, 0.95, 0.0), (0.06 * k, 0.07 * k)), (g.head_point(0.85, 1.0, 0.0), (0.05 * k, 0.065 * k))], "head", color, axis="x", sides=6)
    g.loft("hatband", [(g.head_point(0.24, 0.98, 0.0), (0.015, 0.072 * k)), (g.head_point(0.86, 1.03, 0.0), (0.015, 0.067 * k))], "head", band, axis="x", sides=6)


def kente(g, gold=GOLD, red=(196, 44, 52), green=(60, 120, 70), **_):
    """A bright woven sash across the chest in gold, red and green."""
    g.dress_torso((120, 92, 60), bare_chest=True)
    c = g.bones["chest"]
    for i, col in enumerate((gold, red, green, gold)):
        a = (c[0][0] - 0.05 + 0.025 * i, -0.075 * g.tall, c[0][2] + 0.02 + 0.04 * i)
        b = (c[1][0] + 0.06 - 0.02 * i, -0.075 * g.tall, c[1][2] - 0.03 + 0.03 * i)
        g.l("kente%d" % i, a, b, 0.016 * g.tall, 0.016 * g.tall, "chest", col, sides=4)


def story_pot(g, color=(168, 96, 60), **_):
    h, t, _ = g.bones["waist"]
    g.e("pot", (h[0] + 0.02, -0.12 * g.tall, h[2] + 0.02), (0.04, 0.035, 0.045), "waist", color, seg=8, rings=5)


def story_thread(g, color=GOLD, wisp=AIR, **_):
    h, t, _ = g.bones["item_n"]
    k = g.tall
    g.l("sthread", h, (h[0] + 0.14 * k, -0.10 * k, h[2] + 0.08 * k), 0.008, 0.008, "item_n", color, glow=True, sides=4)
    g.e("swisp", (h[0] + 0.15 * k, -0.10 * k, h[2] + 0.10 * k), (0.02,) * 3, "item_n", wisp, glow=True, seg=5, rings=3)


GEAR = {name: fn for name, fn in globals().items() if callable(fn) and not name.startswith("_") and fn.__module__ == __name__ and name not in ("spiderling",)}
