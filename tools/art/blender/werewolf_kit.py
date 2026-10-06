"""The werewolf kit: the upright wolf-men on one skeleton (werewolf_skeleton.py), a body built from it and gear (werewolf_gear.py) added from the table of
forms (wolf_forms.py). Runs inside Blender. A hunched, broad-chested, long-armed beast with a full wolf head (a hinged jaw, swept ears), clawed hands, digitigrade
legs standing on the toe pad, and a bushy tail. Faceted like the rest of the family (wolf_kit.py, goblin_kit.py).
"""
import math

import werewolf_skeleton as skeleton
from kitbase import KitBase
from wolf_kit import EAR, EYE, FANG, NOSE, STAR, room

FUR, BELLY = (62, 56, 70), (96, 88, 106)
CLAW = (214, 208, 190)


class Werewolf(KitBase):
    def __init__(self, rig, form, pre="", scale=1.0, origin=(0.0, 0.0, 0.0)):
        super().__init__(rig, pre, scale, origin)
        self.form = form
        self.tall, self.arm = form.get("tall", 1.0), form.get("arm", 1.0)
        self.bulk = form.get("bulk", 1.0)
        self.head_f = form.get("head", 1.0)
        self.fur, self.belly = room(form.get("fur", FUR)), room(form.get("belly", BELLY), 104)
        self.dark = room(form.get("dark", tuple(int(c * 0.82) for c in self.fur)), 60)
        self.bones = {n: (h, t, p) for n, h, t, p in skeleton.core(self.tall, self.arm)}

    def at(self, bone, t):
        h, tl, _ = self.bones[bone]
        return tuple(h[i] + (tl[i] - h[i]) * t for i in range(3))

    def build(self):
        f, b, fur, dark, belly = self.form, self.bulk, self.fur, self.dark, self.belly
        t, hs = self.tall, self.head_f
        for name, head, tail, parent in skeleton.core(self.tall, self.arm):
            self.bone(name, head, tail, parent)
        # trunk: a deep chest tapering to a lean waist, a broad pelvis
        self.loft("pelvis", [((0.0, 0, 0.86 * t), (0.10 * b, 0.13 * b)), ((0.01, 0, 0.96 * t), (0.12 * b, 0.16 * b)), ((0.02, 0, 1.06 * t), (0.10 * b, 0.14 * b))], "hips", fur, axis="z")
        self.loft("torso", [((0.02, 0, 1.04 * t), (0.10 * b, 0.14 * b)), ((0.05, 0, 1.20 * t), (0.15 * b, 0.19 * b)), ((0.08, 0, 1.38 * t), (0.22 * b, 0.26 * b)),
                            ((0.08, 0, 1.52 * t), (0.17 * b, 0.22 * b))], "spine", fur, axis="z")
        self.loft("belly", [((0.12, 0, 1.12 * t), (0.05 * b, 0.10 * b)), ((0.14, 0, 1.28 * t), (0.05 * b, 0.12 * b))], "spine", belly, axis="z")
        self.l("neck", (0.08, 0, 1.46 * t), (0.17, 0, 1.64 * t), 0.115 * b, 0.09 * b, "head", fur, sides=7)
        # the head: a dome, a brow, a long muzzle, a hinged jaw, ears, eyes and the star
        h0 = (0.19, 0, 1.72 * t)
        self.e("skull", h0, (0.12 * hs, 0.105 * hs, 0.115 * hs), "head", fur)
        self.loft("brow", [((h0[0] + 0.07, 0, h0[2] + 0.05), (0.025 * hs, 0.10 * hs)), ((h0[0] + 0.15, 0, h0[2] + 0.045), (0.02 * hs, 0.075 * hs))], "head", dark, sides=6)
        self.loft("muzzle", [((h0[0] + 0.08, 0, h0[2] - 0.02), (0.065 * hs, 0.07 * hs)), ((h0[0] + 0.19, 0, h0[2] - 0.04), (0.045 * hs, 0.05 * hs)),
                             ((h0[0] + 0.28, 0, h0[2] - 0.05), (0.03 * hs, 0.033 * hs))], "head", belly, sides=6)
        self.e("nose", (h0[0] + 0.31, 0, h0[2] - 0.045), (0.028 * hs, 0.03 * hs, 0.027 * hs), "head", NOSE, seg=6, rings=4)
        jh, jt, _ = self.bones["jaw"]
        self.loft("jaw", [((jh[0] + 0.02, 0, jh[2]), (0.032 * hs, 0.055 * hs)), ((jh[0] + 0.14, 0, jh[2] - 0.02), (0.028 * hs, 0.045 * hs)), ((jt[0] - 0.04, 0, jt[2] + 0.01), (0.02 * hs, 0.03 * hs))],
                  "jaw", belly, sides=6)
        self.blade("fang_u", (h0[0] + 0.24, 0, h0[2] - 0.075), (h0[0] + 0.24, 0, h0[2] - 0.135), 0.022, 0.018, "head", FANG)
        self.blade("fang_l", (h0[0] + 0.22, 0, h0[2] - 0.11), (h0[0] + 0.23, 0, h0[2] - 0.06), 0.022, 0.018, "jaw", FANG)
        for s, y in (("n", -1), ("f", 1)):
            h, tl, _ = self.bones["ear_" + s]
            self.blade("ear_" + s, h, tl, 0.12 * hs * f.get("ears", 1.0), 0.026, "ear_" + s, f.get("ear", dark), far=s == "f")
            self.e("eye_" + s, (h0[0] + 0.13, y * 0.085 * hs, h0[2] + 0.02), (0.028, 0.026, 0.028), "head", f.get("eye", EYE), far=s == "f", glow=True, seg=8, rings=6)
        if f.get("star", True):
            self.e("star", (h0[0] + 0.08, 0, h0[2] + 0.095 * hs), (0.024, 0.014, 0.034), "head", f.get("star_colour", STAR), glow=True, seg=6, rings=4)
        # the arms: long, thick at the shoulder, with a heavy forearm and a clawed hand
        for s, y in (("n", skeleton.NEAR), ("f", skeleton.FAR)):
            far = s == "f"
            c = dark if far else fur
            ah, at, _ = self.bones["arm_" + s]
            fh, ft, _ = self.bones["fore_" + s]
            self.e("shoulder_" + s, ah, (0.13 * b, 0.12 * b, 0.13 * b), "arm_" + s, c, far)
            self.l("arm_" + s, ah, at, 0.085 * b, 0.065 * b, "arm_" + s, c, far)
            self.e("elbow_" + s, at, (0.06 * b,) * 3, "arm_" + s, c, far, seg=8, rings=6)
            self.l("fore_" + s, fh, ft, 0.07 * b, 0.048 * b, "fore_" + s, c, far)
            hand = (ft[0] + 0.02, y, ft[2] - 0.05)
            self.e("hand_" + s, hand, (0.065 * b, 0.05 * b, 0.075 * b), "fore_" + s, c, far, seg=8, rings=6)
            for i, dy in enumerate((-0.025, 0.0, 0.025)):
                self.blade("claw_%s%d" % (s, i), (hand[0] + 0.03, y + dy, hand[2] - 0.05), (hand[0] + 0.07, y + dy, hand[2] - 0.15), 0.02, 0.016, "fore_" + s, CLAW, far)
        # the legs: a thick thigh, a shin sloping back to a high hock, a long foot on its toe pad
        for s, y in (("n", skeleton.LEG_NEAR), ("f", skeleton.LEG_FAR)):
            far = s == "f"
            c = dark if far else fur
            th, tt, _ = self.bones["thigh_" + s]
            sh, st, _ = self.bones["shin_" + s]
            fh, ft, _ = self.bones["foot_" + s]
            self.e("haunch_" + s, (th[0] + 0.03, y, th[2] - 0.12), (0.13 * b, 0.10 * b, 0.19 * b), "thigh_" + s, c, far)
            self.l("thigh_" + s, th, tt, 0.115 * b, 0.075 * b, "thigh_" + s, c, far)
            self.e("knee_" + s, tt, (0.065 * b,) * 3, "thigh_" + s, c, far, seg=8, rings=6)
            self.l("shin_" + s, sh, st, 0.075 * b, 0.05 * b, "shin_" + s, c, far)
            self.e("hock_" + s, st, (0.055 * b,) * 3, "shin_" + s, c, far, seg=8, rings=6)
            self.l("foot_" + s, fh, ft, 0.05 * b, 0.04 * b, "foot_" + s, c, far)
            self.loft("pad_" + s, [((ft[0] - 0.04, y, 0.0), (0.05 * b, 0.05 * b), 1.0), ((ft[0] + 0.05, y, 0.0), (0.04 * b, 0.05 * b), 1.0), ((ft[0] + 0.13, y, 0.0), (0.025 * b, 0.04 * b), 1.0)],
                      "foot_" + s, c, "x", 6, far)
            for i, dy in enumerate((-0.025, 0.025)):
                self.blade("toe_claw_%s%d" % (s, i), (ft[0] + 0.11, y + dy, 0.02), (ft[0] + 0.19, y + dy, 0.0), 0.02, 0.016, "foot_" + s, CLAW, far)
        # the tail: three bushy segments
        for i, (a, c) in enumerate(((0.08, 0.10), (0.10, 0.105), (0.105, 0.0)), 1):
            h, tl, _ = self.bones["tail%d" % i]
            self.l("tail%d" % i, h, tl, a * b, c * b, "tail%d" % i, room(f.get("tail_colour", fur), 80), sides=6)
