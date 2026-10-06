"""The undead kit: the bodies of the undead tree, built on the bones undead_skeleton.py gives a form, dressed with gear (undead_gear.py) from the
table in undead_forms.py. Runs inside Blender.

Coordinates in this file and in undead_gear.py are standard ones (undead_skeleton.py: a man about 1.9 tall, hips at 1.0, facing +x, the near
side y < 0) read off the form's landmarks (`self.m`: hip, knee, waist, neck, shoulders, elbows, wrists, the skull's base and size), and `P` maps
them onto the form's build, so one piece of gear fits a stooped skeleton and a giant.

The style is the goblin's (docs/research/images/art-target/goblin-reference-sheet.png): angular flat-shaded shapes, thin tapering limbs with round
joints, flat wedge feet, clear flat silhouettes for weapons. A skeleton is thin bone with knobbly joints, a ribcage of light bars over a dark
hollow and a skull with dark sockets and a pinpoint glint; a corpse is a body of flesh; a mummy is a body wrapped in linen.
"""
import math

import rigkit as k
import undead_skeleton as us

DARK, HOLLOW, SOCKET = (54, 42, 44), (66, 50, 50), (34, 26, 32)
TEETH = (226, 220, 196)


def room(rgb, floor=96):
    """A dark colour lifted so its shading ramp has somewhere to go (as wolf_kit.room)."""
    lum = 0.30 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]
    if lum >= floor:
        return tuple(rgb)
    f = min(1.9, floor / max(lum, 1.0))
    return tuple(min(255, int(round(c * f))) for c in rgb)


def shade(rgb, f):
    return tuple(max(0, min(255, int(round(c * f)))) for c in rgb)


class Undead:
    def __init__(self, rig, form):
        self.rig, self.form = rig, form
        self.shape = us._shape(form)
        self.body = form.get("body", "biped")
        self.m = us.landmarks(form) if self.body in ("biped", "hop") else {}
        self.bulk = form.get("bulk", 1.0)
        self.skin = form.get("skin", (214, 204, 176))
        self.style = form.get("style", "bone")
        raw = us.CORES[self.body](form) + (us.biped_hung(form) if self.body in ("biped", "hop") else [])
        self.raw = {n: (h, t, p) for n, h, t, p in raw}

    # ---- placing things ----
    def P(self, x, y, z):
        return us.placed((x, y, z), self.shape)

    def R(self, r):
        return r * self.shape["tall"] * math.sqrt(self.shape["bx"])

    def at(self, bone, t, y=None):
        h, tl, _ = self.raw[bone]
        p = tuple(h[i] + (tl[i] - h[i]) * t for i in range(3))
        return p if y is None else (p[0], y, p[2])

    def e(self, name, c, r, bone, rgb, far=False, glow=False, seg=10, rings=7, smooth=False):
        self.rig.part(k.ellipsoid(name, self.P(*c), tuple(self.R(v) for v in r), seg, rings, smooth=smooth), bone, rgb, far, glow)

    def l(self, name, a, b, r0, r1, bone, rgb, far=False, glow=False, sides=6):
        self.rig.part(k.limb(name, self.P(*a), self.P(*b), self.R(r0), self.R(r1), sides, smooth=False), bone, rgb, far, glow)

    def loft(self, name, rings, bone, rgb, axis="z", sides=8, far=False, glow=False):
        out = [(self.P(*ring[0]), (self.R(ring[1][0]), self.R(ring[1][1]))) + tuple(ring[2:]) for ring in rings]
        self.rig.part(k.loft(name, out, axis, sides, False), bone, rgb, far, glow)

    def blade(self, name, root, tip, width, thick, bone, rgb, far=False, glow=False):
        self.rig.part(k.blade(name, self.P(*root), self.P(*tip), self.R(width), self.R(thick)), bone, rgb, far, glow)

    def box(self, name, c, size, bone, rgb, far=False, glow=False):
        self.rig.part(k.box(name, self.P(*c), tuple(self.R(v) for v in size)), bone, rgb, far, glow)

    def sheet(self, name, columns, weights, rgb, far=False, glow=False):
        """A thin sheet through `columns` [(top, bottom)] (standard points), bound by `weights(z) -> {bone: weight}` (z standard)."""
        cols = [(self.P(*a), self.P(*b)) for a, b in columns]
        ob = k.sheet(name, cols)
        self.rig.skin(ob, lambda v: weights(v.z / self.shape["tall"]), rgb, far, glow)

    def bone_limb(self, name, a, b, r0, r1, bone, rgb, far=False, knob=None):
        """A thin bone: a shaft with a knob at its far end (a knee, an elbow)."""
        self.l(name, a, b, r0, r1, bone, rgb, far, sides=6)
        if knob:
            self.e(name + "_knob", b, (knob, knob * 0.9, knob), bone, rgb, far, seg=7, rings=5)

    # ---- the armature ----
    def bones(self):
        for name, head, tail, parent in us.bones(self.form):
            self.rig.bone(name, head, tail, parent)

    # ---- the body ----
    def build(self):
        self.bones()
        {"candle": self.candle, "ghost": self.ghost, "skull": self.floating_skull}.get(self.body, self.person)()

    def person(self):
        if self.style == "bone":
            self.bone_torso()
        else:
            self.flesh_torso()
        if not self.form.get("headless"):
            self.head()
        for s in "nf":
            self.arm(s)
            self.leg(s)

    # -- a skeleton's trunk: pelvis, a column of vertebrae, a ribcage of bars over a dark hollow, collarbones
    def bone_torso(self):
        m, b, sk = self.m, self.bulk, self.skin
        hip, waist, neck = m["hip"], m["waist"], m["neck"]
        self.loft("pelvis", [((0.0, 0, hip - 0.07), (0.05 * b, 0.07 * b)), ((0.01, 0, hip + 0.01), (0.085 * b, 0.12 * b)), ((0.0, 0, hip + 0.07), (0.065 * b, 0.10 * b))], "hips", sk, sides=6)
        top = neck - 0.03
        bottom = waist + 0.16 * self.shape["torso"]
        self.l("lumbar", (-0.01, 0, hip + 0.04), (0.0, 0, bottom + 0.02), 0.034 * b, 0.03 * b, "spine", sk)
        for i in range(3):
            z = hip + 0.08 + (bottom - hip - 0.06) * (i + 0.5) / 3.0
            self.e("vert%d" % i, (-0.01, 0, z), (0.032 * b, 0.03 * b, 0.016), "spine", sk, seg=6, rings=4)
        glow = self.form.get("glow_ribs")
        self.loft("hollow", [((0.02, 0, bottom), (0.06 * b, 0.07 * b)), ((0.04, 0, (bottom + top) / 2), (0.085 * b, 0.10 * b)), ((0.04, 0, top), (0.06 * b, 0.08 * b))],
                  "spine", glow or HOLLOW, sides=6, glow=bool(glow))
        n = 4
        for i in range(n):
            f = (i + 0.5) / n
            z = top - 0.02 - f * (top - bottom - 0.02)
            w = (0.105 - 0.025 * f * f) * b
            self.e("rib%d" % i, (0.035 - 0.01 * f, 0, z), (w, w * 1.12, 0.022), "spine", sk, seg=10, rings=4)
        self.l("sternum", (0.11 * b, -0.01, top - 0.02), (0.10 * b, -0.01, bottom + 0.06), 0.016, 0.012, "spine", sk, sides=4)
        self.l("collar", (0.06, -m["sh"] * 0.9, neck - 0.05), (0.08, m["sh"] * 0.9, neck - 0.05), 0.018 * b, 0.018 * b, "spine", sk, sides=5)
        if not self.form.get("headless"):
            self.l("neck", (0.04, 0, neck - 0.02), (0.06, 0, m["head_base"] + 0.04), 0.03 * b, 0.028 * b, "spine", sk, sides=5)

    # -- a corpse's trunk: pelvis, a chest that is a wedge of flesh, a neck; `bulk` fattens it
    def flesh_torso(self):
        m, b, sk = self.m, self.bulk, self.skin
        hip, waist, neck = m["hip"], m["waist"], m["neck"]
        self.loft("pelvis", [((0.0, 0, hip - 0.07), (0.075 * b, 0.10 * b)), ((0.01, 0, hip + 0.02), (0.095 * b, 0.12 * b)), ((0.02, 0, waist + 0.02), (0.085 * b, 0.11 * b))], "hips", sk, sides=8)
        t = self.shape["torso"]
        belly = self.form.get("belly", 1.0)
        rings = [((0.02, 0, waist - 0.02), (0.085 * b, 0.11 * b)), ((0.035, 0, waist + 0.12 * t), (0.095 * b * belly, 0.12 * b)),
                 ((0.05, 0, neck - 0.17 * t), (0.115 * b, 0.145 * b)), ((0.05, 0, neck - 0.04), (0.085 * b, 0.13 * b)), ((0.05, 0, neck + 0.01), (0.05 * b, 0.07 * b))]
        self.loft("torso", rings, "spine", sk, sides=8)
        self.l("neck", (0.04, 0, neck - 0.02), (0.07, 0, m["head_base"] + 0.06), 0.045 * min(b, 1.3), 0.04 * min(b, 1.3), "spine", sk, sides=6)

    # -- the head: a skull (bone), a face (flesh and mummy)
    def head(self):
        m, sk = self.m, self.skin
        hb, s = m["head_base"], m["skull"]
        hd = self.shape["head"]
        eye = self.form.get("eyes", (220, 220, 210))
        bone = self.style == "bone"
        c = (0.07, 0, hb + 0.60 * s)
        self.e("cranium", c, (0.10 * hd, 0.085 * hd, 0.10 * hd), "head", sk, seg=10, rings=7)
        # the face: a wedge forward and down from the cranium, a brow over the sockets
        self.loft("face", [((0.08, 0, hb + 0.40 * s), (0.07 * hd, 0.07 * hd)), ((0.16 * hd, 0, hb + 0.36 * s), (0.055 * hd, 0.055 * hd)),
                           ((0.19 * hd, 0, hb + 0.33 * s), (0.035 * hd, 0.04 * hd))], "head", sk, axis="x", sides=6)
        self.loft("brow", [((0.12 * hd, 0, hb + 0.66 * s), (0.026 * hd, 0.078 * hd)), ((0.18 * hd, 0, hb + 0.63 * s), (0.02 * hd, 0.06 * hd))], "head", shade(sk, 0.94), axis="x", sides=6)
        sock = SOCKET if bone else shade(sk, 0.5)
        sides = (("n", -1),) if self.form.get("one_eye") else (("n", -1), ("f", 1))
        for side, y in (("n", -1), ("f", 1)):
            far = side == "f"
            self.e("socket_" + side, (0.155 * hd, y * 0.042 * hd, hb + 0.55 * s), (0.034 * hd, 0.026 * hd, 0.032 * hd), "head", sock, far, seg=7, rings=5)
            if eye and (side, y) in sides:
                self.e("glint_" + side, (0.175 * hd, y * 0.048 * hd, hb + 0.55 * s), (0.016 * hd, 0.014, 0.016 * hd), "head", eye, far, glow=True, seg=6, rings=4)
        if bone:
            self.e("nasal", (0.19 * hd, -0.02, hb + 0.42 * s), (0.012, 0.012, 0.022), "head", SOCKET, seg=5, rings=3)
            self.box("teeth", (0.165 * hd, -0.01, hb + 0.29 * s), (0.04 * hd, 0.05 * hd, 0.012), "head", TEETH)
            self.loft("jawbone", [((0.07, 0, hb + 0.25 * s), (0.028 * hd, 0.06 * hd)), ((0.17 * hd, 0, hb + 0.20 * s), (0.02 * hd, 0.04 * hd))], "jaw", sk, axis="x", sides=6)
        else:
            self.blade("nose", (0.17 * hd, 0, hb + 0.50 * s), (0.22 * hd, 0, hb + 0.40 * s), 0.05 * hd, 0.04 * hd, "head", sk)
            self.loft("jawbone", [((0.07, 0, hb + 0.24 * s), (0.04 * hd, 0.07 * hd)), ((0.17 * hd, 0, hb + 0.20 * s), (0.026 * hd, 0.045 * hd))], "jaw", sk, axis="x", sides=6)

    # -- an arm: a bone of an arm with knobs (bone), a limb of flesh (flesh), and a hand
    def arm(self, s):
        m, sk, b = self.m, self.skin, self.bulk
        y = -m["sh"] if s == "n" else m["sh"]
        far = s == "f"
        sh = self.raw["arm_" + s][0]
        el = self.raw["arm_" + s][1]
        wr = self.raw["fore_" + s][1]
        hand = (wr[0] + 0.01, y, wr[2] - 0.03)
        if self.style == "bone":
            self.e("shoulder_" + s, sh, (0.045 * b, 0.04 * b, 0.045 * b), "arm_" + s, sk, far, seg=7, rings=5)
            self.bone_limb("humerus_" + s, sh, el, 0.032 * b, 0.026 * b, "arm_" + s, sk, far, knob=0.038 * b)
            self.l("forearm_" + s, el, wr, 0.027 * b, 0.024 * b, "fore_" + s, sk, far, sides=5)
            self.e("hand_" + s, hand, (0.036 * b, 0.028 * b, 0.045 * b), "fore_" + s, sk, far, seg=6, rings=4)
            self.blade("fingers_" + s, (wr[0], y, wr[2] - 0.02), (hand[0] + 0.01, y, hand[2] - 0.08), 0.055 * b, 0.025, "fore_" + s, sk, far)
        else:
            r = 0.042 * b
            self.e("shoulder_" + s, sh, (r * 1.3, r * 1.2, r * 1.3), "arm_" + s, sk, far, seg=8, rings=6)
            self.l("upper_" + s, sh, el, r * 1.15, r * 0.9, "arm_" + s, sk, far, sides=6)
            self.e("elbow_" + s, el, (r * 0.9,) * 3, "arm_" + s, sk, far, seg=7, rings=5)
            self.l("lower_" + s, el, wr, r * 0.9, r * 0.7, "fore_" + s, sk, far, sides=6)
            self.e("hand_" + s, hand, (r * 0.85, r * 0.7, r * 1.05), "fore_" + s, sk, far, seg=7, rings=5)

    # -- a leg: bone with knobbly knees and a flat bone foot, or flesh
    def leg(self, s):
        m, sk, b = self.m, self.skin, self.bulk
        far = s == "f"
        hp, kn = self.raw["thigh_" + s][0], self.raw["thigh_" + s][1]
        an = self.raw["shin_" + s][1]
        if self.style == "bone":
            self.bone_limb("femur_" + s, hp, kn, 0.038 * b, 0.03 * b, "thigh_" + s, sk, far, knob=0.042 * b)
            self.l("tibia_" + s, kn, an, 0.03 * b, 0.025 * b, "shin_" + s, sk, far, sides=5)
        else:
            r = 0.055 * b
            self.l("thigh_" + s, hp, kn, r * 1.2, r * 0.85, "thigh_" + s, sk, far, sides=6)
            self.e("knee_" + s, kn, (r * 0.85,) * 3, "thigh_" + s, sk, far, seg=7, rings=5)
            self.l("shin_" + s, kn, an, r * 0.8, r * 0.55, "shin_" + s, sk, far, sides=6)
        self.foot("foot_" + s, s, sk, far=far)

    def foot(self, name, side, rgb, far=False, big=1.0, length=1.0, bone=None):
        """A flat wedge of a foot whose sole lies on the ground: a heel, a ball and a toe. Only feet are bound to the foot bones (the motion measures
        them)."""
        y = -self.m["leg_y"] if side == "n" else self.m["leg_y"]
        fl = self.m["foot"] * length
        thin = 0.75 if self.style == "bone" else 1.0
        b = min(self.bulk, 1.4) * big
        rings = [((-0.05, y, 0.0), (0.06 * b * thin, 0.04 * b), 1.0), ((0.05 * length, y, 0.0), (0.05 * b * thin, 0.045 * b), 1.0),
                 ((fl * 0.75, y, 0.0), (0.03 * b * thin, 0.04 * b), 1.0), ((fl + 0.02, y, 0.0), (0.014 * b, 0.03 * b), 1.0)]
        self.loft(name, rings, bone or "foot_" + side, rgb, axis="x", sides=6, far=far)

    # ---- the floaters ----
    def candle(self):
        f = self.form
        flame, core, wax = f.get("skin"), f.get("core", (66, 48, 92)), f.get("wax", (222, 214, 190))
        self.loft("stub", [((0.0, 0, 0.0), (0.085, 0.085)), ((0.0, 0, 0.10), (0.08, 0.08)), ((0.0, 0, 0.15), (0.07, 0.07))], "hips", wax, sides=8)
        self.e("drip", (0.06, -0.05, 0.10), (0.03, 0.025, 0.05), "hips", shade(wax, 0.92), seg=6, rings=4)
        self.l("wick", (0.0, 0, 0.14), (0.0, 0, 0.20), 0.012, 0.01, "hips", (40, 34, 40), sides=4)
        self.loft("flame", [((0.0, 0, 0.13), (0.08, 0.08)), ((0.0, 0, 0.19), (0.155, 0.14)), ((0.0, 0, 0.29), (0.15, 0.135)), ((-0.01, 0, 0.37), (0.10, 0.09)),
                            ((-0.02, 0, 0.42), (0.05, 0.05))], "spine", flame, sides=8)
        self.e("core", (0.0, -0.05, 0.25), (0.08, 0.07, 0.10), "spine", core, seg=8, rings=6)
        for s, y in (("n", -0.035), ("f", 0.035)):
            self.e("eye_" + s, (0.10, y - 0.10, 0.31), (0.032, 0.03, 0.038), "head", SOCKET, far=s == "f", seg=6, rings=4)
        self.box("mouth", (0.10, -0.12, 0.22), (0.03, 0.02, 0.01), "head", SOCKET)
        self.blade("tip1", (-0.01, 0, 0.37), (-0.05, 0, 0.52), 0.13, 0.08, "tip1", flame, glow=True)
        self.blade("tip2", (-0.04, 0, 0.49), (-0.10, 0, 0.59), 0.07, 0.05, "tip2", flame, glow=True)

    def ghost(self):
        f = self.form
        skin, shroud, hair, shadow = f.get("skin"), f.get("shroud"), f.get("hair"), f.get("shadow", (66, 48, 92))
        self.loft("shroud", [((-0.02, 0, 0.40), (0.15, 0.13)), ((0.0, 0, 0.62), (0.13, 0.12)), ((0.01, 0, 0.80), (0.11, 0.11)), ((0.03, 0, 1.0), (0.085, 0.10)),
                             ((0.05, 0, 1.20), (0.07, 0.09))], "hips", shroud, sides=8)
        self.loft("bodice", [((0.03, 0, 0.92), (0.08, 0.09)), ((0.05, 0, 1.08), (0.085, 0.10)), ((0.05, 0, 1.22), (0.06, 0.08))], "spine", shroud, sides=8)
        self.e("fold", (-0.06, -0.08, 0.70), (0.05, 0.05, 0.16), "hips", shadow, seg=6, rings=4)
        for i in range(3):
            a, b = self.raw["strip%da" % i], self.raw["strip%db" % i]
            col = shroud if i != 1 else shade(shroud, 0.86)
            self.blade("strip%da" % i, a[0], a[1], 0.17, 0.04, "strip%da" % i, col)
            self.blade("strip%db" % i, (b[0][0], b[0][1], b[0][2] + 0.04), b[1], 0.12, 0.03, "strip%db" % i, col)
        hb = self.raw["head"][0]
        self.l("neck", (0.04, 0, 1.18), hb, 0.03, 0.03, "spine", skin)
        self.e("head", (0.10, 0, 1.38), (0.10, 0.085, 0.115), "head", skin, seg=10, rings=7)
        self.loft("jaw", [((0.10, 0, 1.30), (0.04, 0.05)), ((0.17, 0, 1.31), (0.03, 0.035))], "head", skin, axis="x", sides=6)
        for s, y in (("n", -0.035), ("f", 0.035)):
            self.e("eye_" + s, (0.18, y, 1.42), (0.03, 0.022, 0.026), "head", SOCKET, far=s == "f", seg=6, rings=4)
        self.e("mouth", (0.185, -0.02, 1.31), (0.028, 0.03, 0.05), "head", SOCKET, seg=6, rings=4)
        self.blade("hair1", (0.05, 0, 1.47), (-0.13, 0, 1.12), 0.14, 0.06, "hair1", hair)
        self.blade("hair2", (-0.11, 0, 1.20), (-0.19, 0, 0.88), 0.10, 0.05, "hair2", hair)
        self.e("crown_hair", (0.04, 0, 1.45), (0.09, 0.09, 0.07), "head", hair, seg=8, rings=5)
        for s in "nf":
            far = s == "f"
            sh, el = self.raw["arm_" + s][:2]
            wr = self.raw["fore_" + s][1]
            self.l("arm_" + s, sh, el, 0.022, 0.018, "arm_" + s, skin, far, sides=5)
            self.l("fore_" + s, el, wr, 0.018, 0.014, "fore_" + s, skin, far, sides=5)
            self.e("sleeve_" + s, el, (0.05, 0.045, 0.07), "arm_" + s, shroud, far, seg=6, rings=4)
            self.blade("hand_" + s, wr, (wr[0] + 0.02, wr[1], wr[2] + 0.07), 0.05, 0.02, "fore_" + s, skin, far)

    def floating_skull(self):
        f = self.form
        sk, eye, gem, band = self.skin, f.get("eyes", (98, 70, 128)), f.get("gem", (226, 150, 174)), f.get("band", (150, 130, 90))
        self.e("cranium", (0.0, 0, 0.30), (0.17, 0.15, 0.16), "head", sk, seg=12, rings=8)
        self.loft("face", [((0.06, 0, 0.20), (0.10, 0.11)), ((0.16, 0, 0.19), (0.08, 0.09)), ((0.21, 0, 0.17), (0.05, 0.06))], "head", sk, axis="x", sides=6)
        self.loft("brow", [((0.10, 0, 0.32), (0.04, 0.13)), ((0.19, 0, 0.30), (0.03, 0.10))], "head", shade(sk, 0.93), axis="x", sides=6)
        self.e("band", (0.0, 0, 0.36), (0.175, 0.155, 0.03), "head", band, seg=12, rings=4)
        self.e("brow_gem", (0.17, -0.02, 0.37), (0.03, 0.02, 0.035), "head", gem, glow=True, seg=6, rings=4)
        for s, y in (("n", -0.06), ("f", 0.06)):
            far = s == "f"
            self.e("socket_" + s, (0.165, y * 1.2, 0.25), (0.065, 0.05, 0.06), "head", SOCKET, far, seg=7, rings=5)
            self.blade("flame_" + s, (0.20, y * 1.2 - 0.03, 0.22), (0.18, y * 1.2 - 0.03, 0.32), 0.06, 0.02, "head", eye, far, glow=True)
        self.e("nasal", (0.215, -0.03, 0.18), (0.015, 0.015, 0.03), "head", SOCKET, seg=5, rings=3)
        self.box("teeth", (0.19, -0.02, 0.115), (0.05, 0.08, 0.016), "head", TEETH)
        for i, x in enumerate((0.15, 0.21)):
            self.e("tooth_gem%d" % i, (x, -0.07, 0.12), (0.016, 0.012, 0.016), "head", gem if i else (150, 210, 220), glow=True, seg=5, rings=3)
        self.loft("jawbone", [((0.02, 0, 0.12), (0.035, 0.10)), ((0.19, 0, 0.08), (0.025, 0.06))], "jaw", sk, axis="x", sides=6)
        self.box("teeth_l", (0.18, -0.02, 0.10), (0.04, 0.07, 0.012), "jaw", TEETH)
