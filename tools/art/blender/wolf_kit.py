"""The wolf kit: one skeleton (quad_skeleton.py) for the whole wolf family, a body built from it and gear (wolf_gear.py) added from a table
(wolf_forms.py). Runs inside Blender. The body is angular and lean like the goblin's (goblin_kit.py): a deep wedge of a chest tucked up to the
waist, a long neck, a wedge of a head with a pointed muzzle and a hinged jaw, flat swept ears, thin tapering legs with flat paws, a bushy tail.

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
        """A flat paw: from the wrist or hock to the toe, a wedge with its sole on the ground."""
        y = skeleton.NEAR if side == "n" else skeleton.FAR
        h, t, _ = self.bones[bone]
        x0 = h[0]
        top = h[2]
        rings = [((x0 - 0.03, y, 0.0), (min(0.075, 0.5 * top + 0.02) * self.bulk, 0.050 * self.bulk), 1.0), ((x0 + 0.05, y, 0.0), (0.050 * self.bulk, 0.052 * self.bulk), 1.0),
                 ((x0 + 0.16, y, 0.0), (0.034 * self.bulk, 0.050 * self.bulk), 1.0), ((x0 + 0.23, y, 0.0), (0.020 * self.bulk, 0.040 * self.bulk), 1.0)]
        self.loft(name, rings, bone, rgb, "x", 6, far)

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
        # the neck: a thick wedge from the shoulders to the skull
        self.l("neck", self.at("neck", 0.0), self.at("neck", 1.0), 0.140 * b, 0.100 * b, "neck", fur, sides=7)
        # the head: a dome with a brow, a long pointed muzzle, a hinged jaw
        hp = self.head_point
        hs = self.head_f
        self.e("skull", hp(0.28, 0.01), (0.105 * hs, 0.092 * hs, 0.098 * hs), "head", fur, seg=10, rings=7)
        self.loft("brow", [(hp(0.48, 0.045), (0.022 * hs, 0.090 * hs)), (hp(0.62, 0.04), (0.018 * hs, 0.070 * hs))], "head", dark, sides=6)
        self.loft("muzzle", [(hp(0.45, -0.010), (0.056 * hs, 0.062 * hs)), (hp(0.75, -0.030), (0.040 * hs, 0.044 * hs)), (hp(0.98, -0.038), (0.028 * hs, 0.030 * hs))], "head", belly, sides=6)
        self.e("nose", hp(1.02, -0.034), (0.026 * hs, 0.030 * hs, 0.026 * hs), "head", NOSE, seg=6, rings=4)
        jaw = self.bones["jaw"]
        self.loft("jaw", [((jaw[0][0] + 0.02, 0, jaw[0][2] - 0.00), (0.030 * hs, 0.050 * hs)), ((jaw[0][0] + 0.12 * hs, 0, jaw[0][2] - 0.05 * (hs) * 0.4), (0.026 * hs, 0.040 * hs)),
                           ((jaw[1][0] - 0.02, 0, jaw[1][2] + 0.01), (0.020 * hs, 0.028 * hs))], "jaw", belly, sides=6)
        for s, y in (("n", -1), ("f", 1)):
            h, t, _ = self.bones["ear_" + s]
            self.blade("ear_" + s, h, t, 0.13 * hs * f.get("ears", 1.0), 0.024, "ear_" + s, f.get("ear", self.dark), far=s == "f")
            self.e("eye_" + s, hp(0.55, 0.035, y * 0.078 * hs), (0.028, 0.026, 0.028), "head", f.get("eye", EYE), far=s == "f", glow=True, seg=8, rings=6)
        self.blade("fang_u", hp(0.82, -0.050), hp(0.82, -0.098), 0.020, 0.016, "head", FANG)
        self.blade("fang_l", hp(0.82, -0.080), hp(0.84, -0.040), 0.020, 0.016, "jaw", FANG)
        if f.get("star", True):
            self.e("star", hp(0.40, 0.085), (0.024, 0.014, 0.034), "head", f.get("star_colour", STAR), glow=True, seg=6, rings=4)
        # the tail: three bushy tapering segments
        tr = f.get("tail_r", 1.0)
        for i, (a, c) in enumerate(((0.075 * tr, 0.100 * tr), (0.100 * tr, 0.105 * tr), (0.105 * tr, 0.0)), 1):
            h, t, _ = self.bones["tail%d" % i]
            self.l("tail%d" % i, h, t, a * b, c * b, "tail%d" % i, room(f.get("tail_colour", TAIL), 80), sides=6)
        # the legs: thin tapering limbs with round joints and flat paws; the hind ones are digitigrade
        for s, y in (("n", skeleton.NEAR), ("f", skeleton.FAR)):
            far = s == "f"
            for upper, lower, foot, r in (("sho_", "fore_", "paw_", (0.082, 0.056, 0.042)), ("thigh_", "shin_", "meta_", (0.112, 0.074, 0.048))):
                hu, tu, _ = self.bones[upper + s]
                hl, tl, _ = self.bones[lower + s]
                hf, tf, _ = self.bones[foot + s]
                c = dark if far else fur
                self.l(upper + s, hu, tu, r[0] * b, r[1] * b * 1.05, upper + s, c, far)
                self.e("joint_" + upper + s, tu, (r[1] * b * 1.1,) * 3, upper + s, c, far, seg=8, rings=6)
                self.l(lower + s, hl, tl, r[1] * b, r[2] * b * 1.2, lower + s, c, far)
                self.e("joint_" + lower + s, tl, (r[2] * b * 1.3,) * 3, lower + s, c, far, seg=8, rings=6)
                self.l(foot + s, hf, tf, r[2] * b * 1.1, r[2] * b * 0.9, foot + s, c, far)
                self.paw("pad_" + foot + s, s, foot + s, c, upper == "thigh_", far)
            hh = self.bones["thigh_" + s]
            self.e("haunch_" + s, (hh[0][0] + 0.03, y, hh[0][2] - 0.07), (0.115 * b, 0.075 * b, 0.145 * b), "thigh_" + s, dark if far else fur, far, seg=8, rings=6)
