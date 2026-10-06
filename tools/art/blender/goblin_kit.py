"""The goblin kit: one skeleton for the whole goblin tree. A form is data (tools/art/blender/goblin_forms.py): proportions, colours, gear and a
stance. This builds the body from them and goblin_gear.py adds the gear. Runs inside Blender.

Coordinates in this file and in goblin_gear.py are for a standard goblin standing at the origin, facing +X, about 1.6 units tall (hips at
z 0.80, shoulders at 1.28, head centred at (0.14, 0, 1.56)); `Goblin.P` maps them onto this form's proportions and place, so a gear piece is
written once and fits a stout goblin, a tall one or a small one riding a wolf.

The body is lean, in the style of docs/research/images/art-target/goblin-reference-sheet.png: a narrow wedge of a chest, thin tapered limbs, a small
angular head with a brow, a short nose and flat ears swept back, flat wedge feet. Gear was written for an older, rounder body, so gear that
hangs on the head or the torso is drawn through a fit: the head's parts shrink about the head (HEAD_FIT) and the torso's close in on its axis
(TORSO_FIT), which keeps sixty pieces of gear right without rewriting each.
"""
import math

import goblin_skeleton as skeleton
import rigkit as k

SKIN = (104, 124, 66)
AMBER = (232, 184, 84)
NEAR, FAR = skeleton.NEAR, skeleton.FAR
BASE_BX, BASE_TALL = skeleton.BASE_BX, skeleton.BASE_TALL
HEAD_FIT = dict(anchor=(0.12, 0.0, 1.38), scale=0.80)
TORSO_FIT = dict(axis=0.03, sx=0.58, sy=0.80)


def down(d):
    return (0.0, -d, 0.0)


def up(d):
    return (0.0, d, 0.0)


class Goblin:
    def __init__(self, rig, form, pre="", scale=1.0, origin=(0.0, 0.0, 0.0)):
        self.rig, self.form, self.pre, self.s, self.o = rig, form, pre, scale, origin
        self.bx = form.get("bx", 1.0) * BASE_BX        # build: widens every part
        self.tall = form.get("tall", 1.0) * BASE_TALL    # stretches every height
        self.skin = form.get("skin", SKIN)
        self.root_parent = None  # the bone this goblin's hips hang from (a mount's spine)
        self.zones = {}          # bone -> "head", "torso" or "" (what fit its gear is drawn through)

    # ---- placing things ----
    def P(self, x, y, z):
        """A point of the standard goblin, moved onto this one."""
        return (x * self.bx * self.s + self.o[0], y * self.bx * self.s + self.o[1], z * self.tall * self.s + self.o[2])

    def R(self, r):
        return r * self.s * 0.5 * (self.bx + self.tall)

    def zone(self, bone):
        return self.zones.get(bone, "")

    def fit(self, p, bone):
        """A point as gear written for the old body should sit on this one: parts of the head and the torso are pulled onto the leaner shapes."""
        zone = self.zone(bone)
        if zone == "head":
            a, s = HEAD_FIT["anchor"], HEAD_FIT["scale"]
            return (a[0] + s * (p[0] - a[0]), a[1] + s * (p[1] - a[1]), a[2] + s * (p[2] - a[2]))
        if zone == "torso":
            return (TORSO_FIT["axis"] + TORSO_FIT["sx"] * (p[0] - TORSO_FIT["axis"]), TORSO_FIT["sy"] * p[1], p[2])
        return p

    def fit_radius(self, r, bone):
        zone = self.zone(bone)
        if zone == "head":
            return r * HEAD_FIT["scale"]
        if zone == "torso":
            return r * math.sqrt(TORSO_FIT["sx"] * TORSO_FIT["sy"])
        return r

    def fit_radii(self, r, bone):
        zone = self.zone(bone)
        if zone == "head":
            return tuple(v * HEAD_FIT["scale"] for v in r)
        if zone == "torso":
            return (r[0] * TORSO_FIT["sx"], r[1] * TORSO_FIT["sy"], r[2])
        return tuple(r)

    def bone(self, name, head, tail, parent=None, raw=False):
        parent_name = (self.pre + parent) if parent else self.root_parent
        if not raw and parent in self.zones:
            self.zones[name] = self.zones[parent]
            head, tail = self.fit(head, parent), self.fit(tail, parent)
        self.rig.bone(self.pre + name, self.P(*head), self.P(*tail), parent_name)

    def e(self, name, c, r, bone, rgb, far=False, glow=False, seg=12, rings=8, grow=1.0, raw=False, smooth=True):
        """An ellipsoid at standard point `c` with standard radii `r`, bound to `bone`."""
        if not raw:
            c, r = self.fit(c, bone), self.fit_radii(r, bone)
        radii = tuple(self.R(v) * grow for v in r)
        self.rig.part(k.ellipsoid(self.pre + name, self.P(*c), radii, seg, rings, smooth=smooth), self.pre + bone, rgb, far, glow)

    def l(self, name, a, b, r0, r1, bone, rgb, far=False, glow=False, sides=7, raw=False, smooth=None):
        """A tapered limb between two standard points."""
        if not raw:
            a, b = self.fit(a, bone), self.fit(b, bone)
            r0, r1 = self.fit_radius(r0, bone), self.fit_radius(r1, bone)
        self.rig.part(k.limb(self.pre + name, self.P(*a), self.P(*b), self.R(r0), self.R(r1), sides, smooth=sides > 7 if smooth is None else smooth),
                      self.pre + bone, rgb, far, glow)

    def box(self, name, c, size, bone, rgb, far=False, glow=False, raw=False):
        if not raw:
            c, size = self.fit(c, bone), self.fit_radii(size, bone)
        self.rig.part(k.box(self.pre + name, self.P(*c), tuple(self.R(v) for v in size)), self.pre + bone, rgb, far, glow)

    def loft(self, name, rings, bone, rgb, axis="z", sides=8, far=False, glow=False, raw=False, smooth=False):
        """A solid through cross-sections [(centre, (a, b)[, flat])] in standard coordinates (rigkit.loft)."""
        out = []
        for ring in rings:
            c, (a, b) = ring[0], ring[1]
            if not raw:
                c = self.fit(c, bone)
                a, b = self.fit_radius(a, bone), self.fit_radius(b, bone)
            out.append((self.P(*c), (self.R(a), self.R(b))) + tuple(ring[2:]))
        self.rig.part(k.loft(self.pre + name, out, axis, sides, smooth), self.pre + bone, rgb, far, glow)

    def blade(self, name, root, tip, width, thick, bone, rgb, far=False, glow=False, raw=False):
        """A flat triangular slab: an ear, a horn, a spike."""
        if not raw:
            root, tip = self.fit(root, bone), self.fit(tip, bone)
            width, thick = self.fit_radius(width, bone), self.fit_radius(thick, bone)
        self.rig.part(k.blade(self.pre + name, self.P(*root), self.P(*tip), self.R(width), self.R(thick)), self.pre + bone, rgb, far, glow)

    def sheet(self, name, columns, weights, rgb, far=False, glow=False):
        """A thin sheet of cloth through `columns` [(top, bottom)] (standard points), bound to several bones by `weights(z) -> {bone: weight}`."""
        cols = [(self.P(*a), self.P(*b)) for a, b in columns]
        ob = k.sheet(self.pre + name, cols)
        # the weights are written for the standard goblin: hand them the standard height of the vertex, whatever this goblin's height or mount
        self.rig.skin(ob, lambda v: {self.pre + b: w for b, w in weights((v.z - self.o[2]) / (self.tall * self.s)).items()}, rgb, far, glow)

    def torso(self, name, bone, rgb, grow=1.0, top=1.36, bottom=0.96, far=False):
        """The chest and waist as a flat shaded wedge through four cross-sections: narrow at the waist, broad across the upper back, taking the
        grown size (a jerkin is the torso a little bigger)."""
        rings = [((0.015, 0, bottom), (0.074, 0.100)), ((0.03, 0, 1.08), (0.100, 0.128)), ((0.058, 0, 1.20), (0.132, 0.154)), ((0.07, 0, top), (0.100, 0.124))]
        self.loft(name, [(c, (a * grow, b * grow)) for c, (a, b) in rings], bone, rgb, raw=True, sides=8)

    def foot(self, name, side, bone, rgb, big=1.0, length=1.0, far=False, plate=None, toe_lift=0.0):
        """A flat wedge of a foot: a heel, a tapering ball and a toe, with a flat sole at the ground."""
        y = skeleton.LEG_NEAR if side == "n" else skeleton.LEG_FAR
        rings = [((-0.04 * big, y, 0.0), (0.075 * big, 0.050 * big), 1.0), ((0.06 * length, y, 0.0), (0.062 * big, 0.050 * big), 1.0),
                 ((0.16 * length, y, toe_lift * 0.5), (0.034 * big, 0.038 * big), 1.0), ((0.22 * length, y, toe_lift), (0.016 * big, 0.022 * big), 1.0)]
        self.loft(name, rings, bone, rgb, axis="x", sides=6, far=far, raw=True)

    # ---- the body ----
    def build(self):
        f = self.form
        sk = self.skin
        ears = f.get("ears", 1.0)
        for name, head, tail, parent in skeleton.core():
            self.bone(name, head, tail, parent, raw=True)
        self.zones.update({"hips": "torso", "spine": "torso", "head": "head"})
        for name, head, tail, parent in skeleton.ears(ears):
            self.bone(name, head, tail, parent, raw=True)
            self.zones[name] = ""
        hd = f.get("head", 1.0)
        # pelvis and torso: a wedge, narrow at the waist and broad across the upper back
        self.loft("pelvis", [((0.0, 0, 0.78), (0.080, 0.100)), ((0.012, 0, 0.88), (0.096, 0.118)), ((0.02, 0, 0.97), (0.082, 0.104))], "hips", sk, raw=True)
        self.torso("torso", "spine", sk)
        # the head: a small dome, a brow, a short wedge of a nose, a receding jaw
        self.neck(sk)
        self.e("skull", (0.12, 0, 1.55), (0.130 * hd, 0.118 * hd, 0.135 * hd), "head", sk, raw=True, seg=10, rings=7, smooth=False)
        self.loft("brow", [((0.18, 0, 1.585), (0.030 * hd, 0.100 * hd)), ((0.245, 0, 1.585), (0.022 * hd, 0.075 * hd))], "head", sk, axis="x", raw=True, sides=6)
        self.loft("snout", [((0.17, 0, 1.52), (0.052 * hd, 0.082 * hd)), ((0.27, 0, 1.50), (0.036 * hd, 0.056 * hd))], "head", sk, axis="x", raw=True, sides=6)
        self.blade("nose", (0.25, 0, 1.545), (0.33 * hd, 0, 1.505), 0.062 * hd, 0.056 * hd, "head", sk, raw=True)
        self.loft("jaw", [((0.09, 0, 1.46), (0.045 * hd, 0.085 * hd)), ((0.22, 0, 1.44), (0.028 * hd, 0.050 * hd))], "head", sk, axis="x", raw=True, sides=6)
        for s, y in (("n", -1), ("f", 1)):
            root, tip = (0.08, y * 0.13, 1.60), (-0.14 * ears, y * 0.30 * ears, 1.63 + 0.05 * ears)
            self.blade("ear_" + s, root, tip, 0.095, 0.022, "ear_" + s, sk, far=s == "f", raw=True)
            self.e("eye_" + s, (0.255 * hd, y * 0.088, 1.572), (0.034, 0.034, 0.034), "head", AMBER, far=s == "f", glow=True, seg=8, rings=6, raw=True)
        self.e("tooth", (0.255 * hd, -0.045, 1.425), (0.016, 0.014, 0.034), "head", (232, 228, 200), seg=6, rings=4, raw=True)
        # arms: thin, tapering, with a round elbow and a mitten of a hand
        for s, y in (("n", NEAR), ("f", FAR)):
            far = s == "f"
            self.e("shoulder_" + s, (0.06, y, 1.27), (0.074, 0.070, 0.074), "arm_" + s, sk, far, raw=True, seg=8, rings=6)
            self.l("arm_" + s, (0.06, y, 1.27), (0.10, y, 1.02), 0.052, 0.040, "arm_" + s, sk, far, sides=6, raw=True)
            self.e("elbow_" + s, (0.10, y, 1.02), (0.044, 0.044, 0.044), "arm_" + s, sk, far, raw=True, seg=8, rings=6)
            self.l("fore_" + s, (0.10, y, 1.02), (0.24, y, 0.79), 0.040, 0.030, "fore_" + s, sk, far, sides=6, raw=True)
            self.e("hand_" + s, (0.25, y, 0.76), (0.050, 0.042, 0.052), "fore_" + s, sk, far, raw=True, seg=8, rings=6)
        # legs: a thigh tapering to a round knee, a thin shin, a flat foot
        for s, y in (("n", skeleton.LEG_NEAR), ("f", skeleton.LEG_FAR)):
            far = s == "f"
            self.l("thigh_" + s, (0.0, y, 0.80), (0.03, y, 0.48), 0.066, 0.046, "thigh_" + s, sk, far, sides=6, raw=True)
            self.e("knee_" + s, (0.03, y, 0.48), (0.048, 0.048, 0.048), "thigh_" + s, sk, far, raw=True, seg=8, rings=6)
            self.l("shin_" + s, (0.03, y, 0.48), (0.0, y, 0.11), 0.040, 0.026, "shin_" + s, sk, far, sides=6, raw=True)
            self.foot("foot_" + s, s, "foot_" + s, sk, far=far)

    def neck(self, rgb):
        self.l("neck", (0.07, 0, 1.30), (0.12, 0, 1.44), 0.050, 0.044, "head", rgb, sides=6, raw=True)
