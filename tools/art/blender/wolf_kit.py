"""The wolf kit: one skeleton (quad_skeleton.py) for the whole wolf family, a body built from it and gear (wolf_gear.py) added from a table
(wolf_forms.py). Runs inside Blender. Built from photographs of wolves (the head is one loft from the back of the skull to the nose: a broad brow, a
stop, a long deep muzzle; the ears are short upright triangles; a ruff sweeps back from the cheeks), faceted like the goblin's (goblin_kit.py): a deep chest tucked
up to the waist, a thick short neck carried level with the back, tapering legs in paler socks with domed paws, a bushy tail that hangs.

Parts are placed relative to the bones of the form's own skeleton, so a long-legged hound, a stocky war wolf and a thick-necked beast share the
code. Standard coordinates are those of quad_skeleton.py (about 1.8 units, nose to tail tip).
"""
import math

import quad_skeleton as skeleton
import rigkit as k

FUR, FUR_DARK, BELLY, EAR = (62, 56, 70), (48, 43, 56), (96, 88, 106), (40, 36, 48)


def room(rgb, floor=76):
    """A dark colour lifted so its shadows have somewhere to go: the shading ramps darken a colour in steps, and from near black there is nothing below.
    A colour already as light as `floor` is left alone."""
    lum = 0.30 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]
    if lum >= floor:
        return tuple(rgb)
    k = min(1.9, floor / max(lum, 1.0))
    return tuple(min(255, int(round(c * k))) for c in rgb)
EYE, STAR, NOSE, TAIL, FANG = (236, 232, 156), (150, 120, 208), (22, 20, 26), (66, 60, 76), (232, 228, 208)


class Wolf:
    def __init__(self, rig, form, pre="", scale=1.0, origin=(0.0, 0.0, 0.0)):
        self.rig, self.form, self.pre, self.s, self.o = rig, form, pre, scale, origin
        self.leg = form.get("leg", 1.0)
        self.neck_f = form.get("neck", 1.0)
        self.tail_f = form.get("tail", 1.0)
        self.head_f = form.get("head", 1.0)
        self.bulk = form.get("bulk", 1.0)          # how thick every part of the body is
        self.fur, self.belly = room(form.get("fur", FUR)), room(form.get("belly", BELLY), 104)
        self.dark = room(form.get("dark", tuple(int(c * 0.82) for c in self.fur)), 60)
        mix = lambda a, b, t: tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))
        self.socks = room(form.get("socks", mix(self.fur, self.belly, 0.55)), 84)     # the lower legs and the cheeks are paler than the back, as a wolf's are
        self.socks_far = tuple(int(c * 0.82) for c in self.socks)
        self.proportions = dict(leg=self.leg, neck=self.neck_f, tail=self.tail_f, head=self.head_f, tail_shape=form.get("tail_shape", skeleton.TAIL_DROOPING))
        self.bones = {n: (h, t, p) for n, h, t, p in skeleton.core(**self.proportions)}

    # ---- placing things ----
    def P(self, x, y, z):
        return (x * self.s + self.o[0], y * self.s + self.o[1], z * self.s + self.o[2])

    def R(self, r):
        return r * self.s

    def at(self, bone, t, y=None):
        """The point a fraction t of the way along a bone (standard coordinates)."""
        h, tl, _ = self.bones[bone]
        return tuple(h[i] + (tl[i] - h[i]) * t for i in range(3)) if y is None else (h[0] + (tl[0] - h[0]) * t, y, h[2] + (tl[2] - h[2]) * t)

    def head_point(self, u, v, y=0.0):
        """A point on the head: `u` along the head bone from its head (in head lengths), `v` up from it (in units), `y` across."""
        h, t, _ = self.bones["head"]
        dx, dz = t[0] - h[0], t[2] - h[2]
        n = math.hypot(dx, dz)
        ax, az = dx / n, dz / n
        length = n * u
        return (h[0] + ax * length - az * v * self.head_f, y, h[2] + az * length + ax * v * self.head_f)

    def bone(self, name, head, tail, parent=None):
        self.rig.bone(self.pre + name, self.P(*head), self.P(*tail), (self.pre + parent) if parent else None)

    def e(self, name, c, r, bone, rgb, far=False, glow=False, seg=10, rings=7, smooth=False):
        self.rig.part(k.ellipsoid(self.pre + name, self.P(*c), tuple(self.R(v) for v in r), seg, rings, smooth=smooth), self.pre + bone, rgb, far, glow)

    def l(self, name, a, b, r0, r1, bone, rgb, far=False, glow=False, sides=6):
        self.rig.part(k.limb(self.pre + name, self.P(*a), self.P(*b), self.R(r0), self.R(r1), sides, smooth=False), self.pre + bone, rgb, far, glow)

    def loft(self, name, rings, bone, rgb, axis="x", sides=8, far=False, glow=False):
        out = [(self.P(*ring[0]), (self.R(ring[1][0]), self.R(ring[1][1]))) + tuple(ring[2:]) for ring in rings]
        self.rig.part(k.loft(self.pre + name, out, axis, sides, False), self.pre + bone, rgb, far, glow)

    def blade(self, name, root, tip, width, thick, bone, rgb, far=False, glow=False):
        self.rig.part(k.blade(self.pre + name, self.P(*root), self.P(*tip), self.R(width), self.R(thick)), self.pre + bone, rgb, far, glow)

    def box(self, name, c, size, bone, rgb, far=False, glow=False):
        self.rig.part(k.box(self.pre + name, self.P(*c), tuple(self.R(v) for v in size)), self.pre + bone, rgb, far, glow)

    def sheet(self, name, columns, weights, rgb, far=False, glow=False):
        cols = [(self.P(*a), self.P(*b)) for a, b in columns]
        ob = k.sheet(self.pre + name, cols)
        self.rig.skin(ob, lambda v: {self.pre + b: w for b, w in weights(v.z).items()}, rgb, far, glow)

    def paw(self, name, side, bone, rgb, hind, far=False):
        """A paw: from the wrist or hock to the toes, a low dome with its sole on the ground."""
        y = skeleton.NEAR if side == "n" else skeleton.FAR
        h, t, _ = self.bones[bone]
        x0, bk = h[0], self.bulk
        rings = [((x0 - 0.03, y, 0.0), (0.040 * bk, 0.040 * bk), 1.0), ((x0 + 0.04, y, 0.0), (0.050 * bk, 0.048 * bk), 1.0),
                 ((x0 + 0.11, y, 0.0), (0.042 * bk, 0.050 * bk), 1.0), ((x0 + 0.16, y, 0.0), (0.020 * bk, 0.036 * bk), 1.0)]
        self.loft(name, rings, bone, rgb, "x", 8, far)

    # ---- the body ----
    def build(self):
        f = self.form
        for name, head, tail, parent in skeleton.core(**self.proportions):
            self.bone(name, head, tail, parent)
        b, fur, dark, belly = self.bulk, self.fur, self.dark, self.belly
        hips, spine = self.bones["hips"], self.bones["spine"]
        zc = lambda x: hips[0][2] + (x - hips[0][0]) / max(1e-6, spine[1][0] - hips[0][0]) * (spine[1][2] - hips[0][2])  # the trunk's height at x
        # the chest: deep behind the shoulders, tucked up toward the waist; the pelvis: broad over the haunches
        # the two halves overlap with the same section where they meet, so no seam shows between them
        self.loft("chest", [((0.34, 0, zc(0.34) - 0.01), (0.140 * b, 0.100 * b)), ((0.24, 0, zc(0.24) - 0.03), (0.178 * b, 0.122 * b)),
                            ((0.10, 0, zc(0.10) - 0.045), (0.185 * b, 0.124 * b)), ((-0.06, 0, zc(-0.06) - 0.025), (0.158 * b, 0.112 * b)),
                            ((-0.16, 0, zc(-0.16) - 0.02), (0.152 * b, 0.110 * b))], "spine", fur)
        self.loft("pelvis", [((-0.06, 0, zc(-0.06) - 0.025), (0.158 * b, 0.112 * b)), ((-0.16, 0, zc(-0.16) - 0.02), (0.152 * b, 0.110 * b)),
                             ((-0.26, 0, zc(-0.26) - 0.01), (0.160 * b, 0.118 * b)), ((-0.38, 0, zc(-0.38) - 0.02), (0.135 * b, 0.100 * b))], "hips", fur)
        self.loft("belly", [((0.14, 0, zc(0.14) - 0.12), (0.060 * b, 0.075 * b)), ((-0.04, 0, zc(-0.04) - 0.10), (0.045 * b, 0.065 * b))], "spine", belly)
        # the neck: thick as the head is deep, carried forward from the withers
        n0, n1 = self.at("neck", -0.05), self.at("neck", 1.0)
        self.l("neck", n0, n1, 0.138 * b, 0.102 * b, "neck", fur, sides=8)
        self.e("neck_base", n0, (0.150 * b, 0.140 * b, 0.140 * b), "neck", fur, seg=9, rings=7)
        self.e("neck_top", n1, (0.100 * b, 0.100 * b, 0.100 * b), "neck", fur, seg=8, rings=6)
        # the head, one loft from the back of the skull to the nose: a broad brow, a stop, then a long deep muzzle
        hp = self.head_point
        hs = self.head_f
        profile = ((-0.07, 0.000, 0.040, 0.040), (0.04, 0.000, 0.084, 0.080), (0.22, 0.012, 0.100, 0.096), (0.40, 0.010, 0.094, 0.088), (0.51, -0.012, 0.070, 0.066),
                   (0.70, -0.030, 0.056, 0.054), (0.90, -0.036, 0.046, 0.044), (0.99, -0.036, 0.038, 0.036))
        self.loft("head", [(hp(u, v), (a * hs, w * hs)) for u, v, a, w in profile], "head", fur, sides=10)
        self.loft("muzzle_top", [(hp(0.60, -0.004), (0.020 * hs, 0.034 * hs)), (hp(0.97, -0.014), (0.016 * hs, 0.026 * hs))], "head", belly, sides=6)
        for sg, y in (("n", -1), ("f", 1)):   # the cheek ruff: tufts that sweep back and down from the jaw
            col = self.socks_far if sg == "f" else self.socks
            self.blade("ruff_" + sg, hp(0.44, -0.030, y * 0.060 * hs), hp(0.10, -0.115, y * 0.100 * hs), 0.085 * hs, 0.030, "head", col, far=sg == "f")
        self.e("nose", hp(1.00, -0.034), (0.028 * hs, 0.030 * hs, 0.024 * hs), "head", NOSE, seg=6, rings=4)
        jaw = self.bones["jaw"]
        self.loft("jaw", [((jaw[0][0] + 0.02, 0, jaw[0][2] - 0.01), (0.036 * hs, 0.054 * hs)), ((jaw[0][0] + 0.12 * hs, 0, jaw[0][2] - 0.05 * hs * 0.4), (0.028 * hs, 0.042 * hs)),
                           ((jaw[1][0] - 0.02, 0, jaw[1][2] + 0.01), (0.022 * hs, 0.030 * hs))], "jaw", belly, sides=6)
        for s, y in (("n", -1), ("f", 1)):
            # an ear is a short rounded triangle: wide at the base, set at the back corner of the skull, leaning out a little
            base, tip = hp(0.14, 0.090, y * 0.062 * hs), hp(0.05, 0.250, y * 0.095 * hs)
            rings = []
            for t, ax, ay in ((0.0, 0.060, 0.017), (0.30, 0.048, 0.014), (0.65, 0.031, 0.010), (0.90, 0.013, 0.006), (1.0, 0.004, 0.003)):
                rings.append((tuple(base[i] + (tip[i] - base[i]) * t for i in range(3)), (ax * f.get("ears", 1.0) * hs, ay * hs)))
            self.loft("ear_" + s, rings, "ear_" + s, f.get("ear", self.dark), axis="z", sides=6, far=s == "f")
            self.e("eye_" + s, hp(0.50, 0.026, y * 0.066 * hs), (0.020, 0.015, 0.017), "head", f.get("eye", EYE), far=s == "f", glow=True, seg=8, rings=6)
        self.blade("fang_u", hp(0.82, -0.050), hp(0.82, -0.098), 0.020, 0.016, "head", FANG)
        self.blade("fang_l", hp(0.82, -0.080), hp(0.84, -0.040), 0.020, 0.016, "jaw", FANG)
        if f.get("star", True):
            self.e("star", hp(0.34, 0.100), (0.020, 0.012, 0.030), "head", f.get("star_colour", STAR), glow=True, seg=6, rings=4)
        # the tail: a thick brush, fullest past the middle and rounded at the tip, hanging from the rump
        tr = f.get("tail_r", 1.0)
        tcol = room(f.get("tail_colour", TAIL), 80)
        for i, (a, c) in enumerate(((0.052 * tr, 0.086 * tr), (0.086 * tr, 0.100 * tr), (0.100 * tr, 0.042 * tr)), 1):
            h, t, _ = self.bones["tail%d" % i]
            self.l("tail%d" % i, h, t, a * b, c * b, "tail%d" % i, tcol, sides=8)
            if i < 3:
                self.e("tail_joint%d" % i, t, (c * b,) * 3, "tail%d" % i, tcol, seg=8, rings=6)
        t3 = self.bones["tail3"][1]
        self.e("tail_tip", t3, (0.044 * tr * b, 0.046 * tr * b, 0.044 * tr * b), "tail3", f.get("tail_tip", tcol), seg=8, rings=6)
        # the legs: thin tapering limbs with round joints and flat paws; the hind ones are digitigrade
        for s, y in (("n", skeleton.NEAR), ("f", skeleton.FAR)):
            far = s == "f"
            for upper, lower, foot, r in (("sho_", "fore_", "paw_", (0.082, 0.056, 0.042)), ("thigh_", "shin_", "meta_", (0.112, 0.074, 0.048))):
                hu, tu, _ = self.bones[upper + s]
                hl, tl, _ = self.bones[lower + s]
                hf, tf, _ = self.bones[foot + s]
                c = dark if far else fur
                pale = self.socks_far if far else self.socks
                self.l(upper + s, hu, tu, r[0] * b, r[1] * b * 1.05, upper + s, c, far)
                self.e("joint_" + upper + s, tu, (r[1] * b * 1.02,) * 3, upper + s, c, far, seg=8, rings=6)
                self.l(lower + s, hl, tl, r[1] * b, r[2] * b * 1.2, lower + s, pale, far)
                self.e("joint_" + lower + s, tl, (r[2] * b * 1.12,) * 3, lower + s, pale, far, seg=8, rings=6)
                self.l(foot + s, hf, tf, r[2] * b * 1.1, r[2] * b * 0.9, foot + s, pale, far)
                self.paw("pad_" + foot + s, s, foot + s, pale, upper == "thigh_", far)
            hh = self.bones["thigh_" + s]
            self.e("haunch_" + s, (hh[0][0] + 0.03, y, hh[0][2] - 0.07), (0.115 * b, 0.075 * b, 0.145 * b), "thigh_" + s, dark if far else fur, far, seg=8, rings=6)
