"""The goblin kit: one skeleton for the whole goblin tree. A form is data (tools/art/blender/goblin_forms.py): proportions, colours, gear and a
stance. This builds the body from them and goblin_gear.py adds the gear. Runs inside Blender.

Coordinates in this file and in goblin_gear.py are for a standard goblin standing at the origin, facing +X, about 1.6 units tall (hips at
z 0.80, shoulders at 1.28, head centred at (0.14, 0, 1.56)); `Goblin.P` maps them onto this form's proportions and place, so a gear piece is
written once and fits a stout goblin, a tall one or a small one riding a wolf.
"""
import math

import rigkit as k

SKIN = (122, 140, 70)
AMBER = (255, 196, 64)
NEAR, FAR = -0.20, 0.20  # the y of the arm and leg the camera sees, and of the other
BASE_BX, BASE_TALL = 1.12, 0.90  # every goblin is a little stockier and shorter than the standard one: the painted goblins are chunky


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

    # ---- placing things ----
    def P(self, x, y, z):
        """A point of the standard goblin, moved onto this one."""
        return (x * self.bx * self.s + self.o[0], y * self.bx * self.s + self.o[1], z * self.tall * self.s + self.o[2])

    def R(self, r):
        return r * self.s * 0.5 * (self.bx + self.tall)

    def bone(self, name, head, tail, parent=None):
        self.rig.bone(self.pre + name, self.P(*head), self.P(*tail), (self.pre + parent) if parent else self.root_parent)

    def e(self, name, c, r, bone, rgb, far=False, glow=False, seg=12, rings=8, grow=1.0):
        """An ellipsoid at standard point `c` with standard radii `r`, bound to `bone`."""
        radii = tuple(self.R(v) * grow for v in r)
        self.rig.part(k.ellipsoid(self.pre + name, self.P(*c), radii, seg, rings), self.pre + bone, rgb, far, glow)

    def l(self, name, a, b, r0, r1, bone, rgb, far=False, glow=False, sides=7):
        """A tapered limb between two standard points."""
        self.rig.part(k.limb(self.pre + name, self.P(*a), self.P(*b), self.R(r0), self.R(r1), sides), self.pre + bone, rgb, far, glow)

    def box(self, name, c, size, bone, rgb, far=False, glow=False):
        self.rig.part(k.box(self.pre + name, self.P(*c), tuple(self.R(v) for v in size)), self.pre + bone, rgb, far, glow)

    # ---- the body ----
    def build(self):
        f = self.form
        sk = self.skin
        ears = f.get("ears", 1.0)
        self.bone("hips", (0, 0, 0.80), (0, 0, 0.95))
        self.bone("spine", (0, 0, 0.95), (0.05, 0, 1.30), "hips")
        self.bone("head", (0.07, 0, 1.32), (0.13, 0, 1.62), "spine")
        for s, y in (("n", NEAR), ("f", FAR)):
            self.bone("arm_" + s, (0.06, y, 1.28), (0.10, y, 1.04), "spine")
            self.bone("fore_" + s, (0.10, y, 1.04), (0.22, y, 0.84), "arm_" + s)
            self.bone("item_" + s, (0.23, y, 0.82), (0.23, y, 0.92), "fore_" + s)
        for s, y in (("n", -0.11), ("f", 0.11)):
            self.bone("thigh_" + s, (0.0, y, 0.80), (0.03, y, 0.48), "hips")
            self.bone("shin_" + s, (0.03, y, 0.48), (0.0, y, 0.11), "thigh_" + s)
            self.bone("foot_" + s, (0.0, y, 0.11), (0.22, y, 0.05), "shin_" + s)
        hd = f.get("head", 1.0)
        self.e("pelvis", (0, 0, 0.88), (0.17, 0.15, 0.13), "hips", sk)
        self.e("torso", (0.04, 0, 1.13), (0.20, 0.17, 0.24), "spine", sk)
        self.e("skull", (0.14, 0, 1.56), (0.23 * hd, 0.20 * hd, 0.21 * hd), "head", sk)
        self.l("nose", (0.30 * hd, 0, 1.56), (0.46 * hd, 0, 1.50), 0.055, 0.0, "head", sk, sides=6)
        for s, y in (("n", -1), ("f", 1)):
            tip = (-0.20 * ears, y * 0.46 * ears, 1.62 + 0.22 * ears)
            self.bone("ear_" + s, (0.10, y * 0.16, 1.62), tip, "head")
            self.l("ear_" + s, (0.10, y * 0.16, 1.62), tip, 0.07, 0.0, "ear_" + s, sk, far=s == "f", sides=5)
            self.e("eye_" + s, (0.31 * hd, y * 0.10, 1.62), (0.05, 0.05, 0.05), "head", AMBER, far=s == "f", glow=True, seg=8, rings=6)
        self.e("tooth", (0.30 * hd, -0.05, 1.42), (0.025, 0.02, 0.05), "head", (240, 236, 210), seg=6, rings=4)
        for s, y in (("n", NEAR), ("f", FAR)):
            far = s == "f"
            self.l("arm_" + s, (0.06, y, 1.28), (0.10, y, 1.04), 0.065, 0.052, "arm_" + s, sk, far, sides=6)
            self.l("fore_" + s, (0.10, y, 1.04), (0.22, y, 0.84), 0.052, 0.045, "fore_" + s, sk, far, sides=6)
            self.e("hand_" + s, (0.23, y, 0.82), (0.065, 0.06, 0.065), "fore_" + s, sk, far)
        for s, y in (("n", -0.11), ("f", 0.11)):
            far = s == "f"
            self.l("thigh_" + s, (0.0, y, 0.80), (0.03, y, 0.48), 0.085, 0.066, "thigh_" + s, sk, far)
            self.l("shin_" + s, (0.03, y, 0.48), (0.0, y, 0.11), 0.066, 0.048, "shin_" + s, sk, far)
            self.e("foot_" + s, (0.09, y, 0.065), (0.15, 0.065, 0.065), "foot_" + s, sk, far)
