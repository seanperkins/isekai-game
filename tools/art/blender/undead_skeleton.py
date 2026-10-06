"""The undead skeletons as data: every bone an undead form has, as a table of (name, head, tail, parent) in the form's own coordinates, so the kit
(undead_kit.py) builds its armature from this and the motion code (undead_motion.py, biped_motion.py) and its tests pose the same numbers. A bone
moved here moves everywhere, and the hung things (a jaw, a cloak, bandage ends, a bow's string, a whip) are bones here too, so the tests see them.
Pure Python.

Three kinds of body (`form["body"]`):
  biped   a person's skeleton with the goblin's bone names (hips, spine, head, arm_n/f, fore_n/f, item_n/f, thigh_n/f, shin_n/f, foot_n/f), so
          biped_motion poses it; a jiangshi is one too (it only moves differently)
  candle  a flame on a stub of candle: stub, flame, two flame tips
  ghost   a shrouded woman with no legs: waist, chest, head, arms, hair and the strips of her shroud
  skull   one floating skull and its jaw

Coordinates: x forward, y across (the near side, which the camera sees, is y < 0), z up, in units where a man stands about 1.9 tall with his
hips at 1.0. A form's proportions (`shape` in undead_forms.py) stretch the standard: `tall` every height, `bx` every width, `leg` the legs,
`torso` the trunk, `arm` the arms, `head` the skull, `shoulder` how far apart the arms hang.
"""
import math

import skeleton2d

ANKLE = 0.09
NECK_GAP = 0.04


def _shape(form):
    s = dict(tall=1.0, bx=1.0, leg=1.0, torso=1.0, arm=1.0, head=1.0, shoulder=1.0, foot=1.0)
    s.update(form.get("shape", {}))
    if form.get("style", "bone") == "bone" and form.get("body", "biped") in ("biped", "hop"):
        s["head"] *= 1.25   # a skull reads big: at 17 pixels a man's skull is a pinhead
    return s


def _gear(form):
    return {name for name, _ in form.get("gear", [])}


def landmarks(form):
    """Named points of a biped form in its own coordinates (x, y, z), before the build is applied: the joints the bones run between."""
    s = _shape(form)
    hip = 1.0 * s["leg"]
    knee = ANKLE + (hip - ANKLE) * 0.49
    waist = hip + 0.12 * s["torso"]
    neck = hip + 0.58 * s["torso"]
    sh = 0.17 * s["shoulder"]
    shoulder_z = neck - 0.05 * s["torso"]
    elbow_z = shoulder_z - 0.30 * s["arm"]
    wrist_z = shoulder_z - 0.56 * s["arm"]
    skull = 0.26 * s["head"]
    return dict(hip=hip, knee=knee, waist=waist, neck=neck, sh=sh, shoulder_z=shoulder_z, elbow_z=elbow_z, wrist_z=wrist_z, skull=skull,
                head_base=neck + NECK_GAP, leg_y=0.085, foot=0.20 * s["foot"], arm=s["arm"])


def biped_core(form):
    """[(name, head, tail, parent)] of every bone a two-legged undead has, before the build is applied."""
    m = landmarks(form)
    hb, sk = m["head_base"], m["skull"]
    bones = [
        ("hips", (0.0, 0, m["hip"]), (0.0, 0, m["waist"]), None),
        ("spine", (0.0, 0, m["waist"]), (0.04, 0, m["neck"]), "hips"),
        ("head", (0.05, 0, hb), (0.08, 0, hb + sk), "spine"),
        ("jaw", (0.06, 0, hb + 0.30 * sk), (0.06 + 0.52 * sk, 0, hb + 0.14 * sk), "head"),
    ]
    for s, y in (("n", -m["sh"]), ("f", m["sh"])):
        bones += [
            ("arm_" + s, (0.03, y, m["shoulder_z"]), (0.05, y, m["elbow_z"]), "spine"),
            ("fore_" + s, (0.05, y, m["elbow_z"]), (0.12, y, m["wrist_z"]), "arm_" + s),
            ("item_" + s, (0.13, y, m["wrist_z"] - 0.03), (0.13, y, m["wrist_z"] + 0.07), "fore_" + s),
        ]
    for s, y in (("n", -m["leg_y"]), ("f", m["leg_y"])):
        bones += [
            ("thigh_" + s, (0.0, y, m["hip"]), (0.03, y, m["knee"]), "hips"),
            ("shin_" + s, (0.03, y, m["knee"]), (0.0, y, ANKLE), "thigh_" + s),
            ("foot_" + s, (0.0, y, ANKLE), (m["foot"], y, 0.03), "shin_" + s),
        ]
    return bones


def biped_hung(form):
    """The hung bones a form's gear asks for, before the build is applied: each one rides the bone it hangs from and is followed through."""
    m = landmarks(form)
    gear = dict(form.get("gear", []))
    hb, sk, hip, neck = m["head_base"], m["skull"], m["hip"], m["neck"]
    out = []
    if "rag" in gear or "loincloth" in gear:
        out += [("rag", (0.10, -0.02, hip + 0.02), (0.12, -0.02, hip - 0.24), "hips"),
                ("rag_b", (-0.10, 0.0, hip + 0.02), (-0.13, 0.0, hip - 0.22), "hips")]
    if "cloak" in gear or "coat" in gear or "fur_cloak" in gear or "cape" in gear:
        opts = gear.get("cloak") or gear.get("coat") or gear.get("fur_cloak") or gear.get("cape") or {}
        length = opts.get("length", 0.9)
        top, end = neck - 0.02, neck - 0.02 - length
        mid = (top + end) / 2.0
        out += [("cloak1", (-0.07, 0, top), (-0.13, 0, mid), "spine"), ("cloak2", (-0.13, 0, mid), (-0.18, 0, end), "cloak1")]
    if "scarf" in gear:
        out += [("scarf_tail", (-0.04, -0.10, neck - 0.02), (-0.20, -0.12, neck - 0.30), "spine")]
    if "hood" in gear:
        out += [("hood_tip", (-0.06, 0, hb + 0.70 * sk), (-0.24, 0, hb + 0.30 * sk), "head")]
    if "bandages" in gear:
        out += [("band1", (-0.08, -0.04, neck - 0.10), (-0.20, -0.06, neck - 0.36), "spine"), ("band2", (-0.20, -0.06, neck - 0.36), (-0.30, -0.06, neck - 0.62), "band1"),
                ("band_h", (0.12, -m["sh"], m["wrist_z"] - 0.02), (0.06, -m["sh"] - 0.02, m["wrist_z"] - 0.30), "fore_n")]
    if "bow" in gear:
        o = gear["bow"]
        a = o.get("half", 0.42)
        g = (0.13, m["sh"], m["wrist_z"] + 0.02)
        string_x = g[0] - o.get("depth", 0.10)
        reach = (a * a + (0.62 * m["arm"]) ** 2) ** 0.5   # the string reaches the drawing hand at full draw, however long the arm
        out += [("string_u", (string_x, m["sh"], g[2] + a), (string_x, m["sh"], g[2] + a - reach), "item_f"),
                ("string_l", (string_x, m["sh"], g[2] - a), (string_x, m["sh"], g[2] - a + reach), "item_f"),
                ("arrow", (g[0] - 0.02, m["sh"] - 0.03, g[2]), (g[0] - 0.02, m["sh"] - 0.03, g[2] + 0.30), "item_f")]
    if "whip" in gear:
        # a lash of five segments hanging from the hand in a loose coil: down, forward, up, back and down again
        seg = gear["whip"].get("length", 1.0) / 5.0
        x, z = 0.13, m["wrist_z"] - 0.04
        parent = "item_n"
        for i, d in enumerate((8.0, 70.0, 150.0, 230.0, 330.0)):
            dx, dz = seg * math.sin(math.radians(d)) * 0.8, -seg * math.cos(math.radians(d)) * 0.8
            out.append(("whip%d" % (i + 1), (x, -m["sh"] - 0.02, z), (x + dx, -m["sh"] - 0.02, z + dz), parent))
            x, z, parent = x + dx, z + dz, "whip%d" % (i + 1)
    if "talisman" in gear:
        out += [("talisman", (0.06 + 0.40 * sk, -0.02, hb + 0.92 * sk), (0.08 + 0.42 * sk, -0.02, hb + 0.10 * sk), "head")]
    if "lantern" in gear:
        out += [("lantern_hang", (0.13, -m["sh"], m["wrist_z"] - 0.04), (0.14, -m["sh"], m["wrist_z"] - 0.22), "item_n")]
    if "chains" in gear:
        out += [("chain1", (0.04, -0.13, hip + 0.04), (0.06, -0.15, hip - 0.18), "hips"), ("chain2", (0.06, -0.15, hip - 0.18), (0.04, -0.15, hip - 0.38), "chain1")]
    if "strips" in gear:
        top = neck - 0.04
        out += [("strip%d" % i, (-0.10, (i - 1) * 0.08, top), (-0.18, (i - 1) * 0.10, top - 0.55 - 0.08 * (i % 2)), "spine") for i in range(3)]
    if "head_held" in gear:
        out += [("held_head", (0.06, m["sh"], m["elbow_z"] + 0.02), (0.06, m["sh"], m["elbow_z"] + 0.20), "arm_f")]
    return out


def candle_core(form):
    """A flame on a candle stub: the stub (the root), the flame and its face, two flame tips that trail."""
    return [
        ("hips", (0.0, 0, 0.0), (0.0, 0, 0.16), None),
        ("spine", (0.0, 0, 0.16), (0.0, 0, 0.46), "hips"),
        ("head", (0.03, 0, 0.24), (0.06, 0, 0.40), "spine"),
        ("tip1", (-0.01, 0, 0.40), (-0.04, 0, 0.50), "spine"),
        ("tip2", (-0.04, 0, 0.50), (-0.09, 0, 0.57), "tip1"),
    ]


def ghost_core(form):
    """A floating woman: the waist of her shroud (the root), her chest, head, arms, two lengths of hair and three strips of shroud."""
    out = [
        ("hips", (0.0, 0, 0.70), (0.0, 0, 0.86), None),
        ("spine", (0.0, 0, 0.86), (0.04, 0, 1.24), "hips"),
        ("head", (0.06, 0, 1.27), (0.12, 0, 1.50), "spine"),
        ("hair1", (0.0, 0, 1.44), (-0.12, 0, 1.18), "head"),
        ("hair2", (-0.12, 0, 1.18), (-0.18, 0, 0.92), "hair1"),
    ]
    for s, y in (("n", -0.15), ("f", 0.15)):
        out += [("arm_" + s, (0.03, y, 1.20), (0.10, y, 0.98), "spine"), ("fore_" + s, (0.10, y, 0.98), (0.20, y, 1.24), "arm_" + s)]
    for i, (x, y) in enumerate(((0.10, -0.06), (-0.02, 0.0), (-0.13, 0.06))):
        a = "strip%d" % i
        out += [(a + "a", (x, y, 0.72), (x - 0.04, y, 0.42 + 0.04 * i), "hips"), (a + "b", (x - 0.04, y, 0.42 + 0.04 * i), (x - 0.10, y, 0.14 + 0.06 * i), a + "a")]
    return out


def skull_core(form):
    """One skull: the cranium (the root) and its jaw."""
    return [
        ("head", (0.0, 0, 0.10), (0.04, 0, 0.42), None),
        ("jaw", (0.0, 0, 0.18), (0.20, 0, 0.12), "head"),
    ]


CORES = {"biped": biped_core, "hop": biped_core, "candle": candle_core, "ghost": ghost_core, "skull": skull_core}


def bones(form):
    """[(name, head, tail, parent)] of every bone of this form, in its own coordinates (the build applied), parents first."""
    body = form.get("body", "biped")
    raw = CORES[body](form) + (biped_hung(form) if body in ("biped", "hop") else [])
    s = _shape(form)
    return [(n, placed(h, s), placed(t, s), p) for n, h, t, p in raw]


def placed(point, s):
    x, y, z = point
    return (x * s["bx"] * s["tall"], y * s["bx"] * s["tall"], z * s["tall"])


def feet(form):
    """{side: (ankle_h, heel, toe)} of the bone feet the kit builds (undead_kit.foot): what the motion's tests stand a form on. Blender measures the real
    ones (boots and all) from the meshes."""
    s = _shape(form)
    k = s["tall"]
    f = (ANKLE * k, 0.05 * s["bx"] * k * s["foot"], (landmarks(form)["foot"] + 0.02) * s["bx"] * k)
    return {"n": f, "f": f}


def skeleton(form):
    """The flat skeleton (skeleton2d.Skeleton2D) of a form: what the motion code poses and the tests check."""
    return skeleton2d.Skeleton2D({n: ((h[0], h[2]), (t[0], t[2]), p) for n, h, t, p in bones(form)})
