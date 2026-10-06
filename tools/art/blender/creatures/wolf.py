"""The wolf: a quadruped with a bushy three-bone tail. About 1.8 units from nose to tail tip, rendered at 30 px per unit (about 55 game
pixels, as today's gloom wolf). Rear legs are digitigrade (knee forward, hock back). The walk is a diagonal trot: near fore with far hind,
then far fore with near hind. The pounce leaves the ground, so its root z is a height above it.
"""
import math

import rigkit as k

NAME = "wolf"
CANVAS = 96
PPU = 30.0
MARGIN = 3

FUR, FUR_DARK, MUZZLE, EAR = (62, 56, 70), (50, 45, 58), (92, 84, 100), (40, 36, 48)
EYE, STAR, NOSE, TAIL = (236, 236, 160), (160, 130, 210), (24, 22, 28), (70, 64, 80)


def down(d):
    return (0.0, -d, 0.0)


def up(d):
    return (0.0, d, 0.0)


def build_into(rig, p="", s=1.0, origin=(0.0, 0.0, 0.0), fur=FUR, belly=MUZZLE, barding=None):
    """Add a wolf to `rig`: bone names get the prefix `p`, every coordinate is scaled by `s` and moved by `origin` (so a wolf can carry a
    rider). `barding` is an optional colour for armour plates over the shoulders and flanks. The caller builds the rig afterwards."""
    def P(x, y, z):
        return (x * s + origin[0], y * s + origin[1], z * s + origin[2])

    def bone(name, head, tail, parent=None):
        rig.bone(p + name, P(*head), P(*tail), p + parent if parent else None)

    def part(ob, bone_name, rgb, far=False, glow=False):
        rig.part(ob, p + bone_name, rgb, far, glow)

    bone("hips", (-0.30, 0, 0.55), (-0.10, 0, 0.58))
    bone("spine", (-0.10, 0, 0.58), (0.30, 0, 0.62), "hips")
    bone("neck", (0.30, 0, 0.62), (0.52, 0, 0.78), "spine")
    bone("head", (0.52, 0, 0.78), (0.86, 0, 0.72), "neck")
    bone("tail1", (-0.36, 0, 0.58), (-0.58, 0, 0.52), "hips")
    bone("tail2", (-0.58, 0, 0.52), (-0.78, 0, 0.42), "tail1")
    bone("tail3", (-0.78, 0, 0.42), (-0.94, 0, 0.30), "tail2")
    for side, y in (("n", -0.11), ("f", 0.11)):
        bone("sho_" + side, (0.28, y, 0.58), (0.30, y, 0.36), "spine")
        bone("fore_" + side, (0.30, y, 0.36), (0.28, y, 0.16), "sho_" + side)
        bone("paw_" + side, (0.28, y, 0.16), (0.40, y, 0.03), "fore_" + side)
        bone("thigh_" + side, (-0.30, y, 0.55), (-0.18, y, 0.36), "hips")
        bone("shin_" + side, (-0.18, y, 0.36), (-0.34, y, 0.20), "thigh_" + side)
        bone("meta_" + side, (-0.34, y, 0.20), (-0.24, y, 0.03), "shin_" + side)

    def ell(name, c, r, bone_name, rgb, far=False, glow=False, seg=12, rings=8):
        part(k.ellipsoid(p + name, P(*c), (r[0] * s, r[1] * s, r[2] * s), seg, rings), bone_name, rgb, far, glow)

    def lmb(name, a, b, r0, r1, bone_name, rgb, far=False, sides=7):
        part(k.limb(p + name, P(*a), P(*b), r0 * s, r1 * s, sides), bone_name, rgb, far)

    ell("chest", (0.18, 0, 0.58), (0.34, 0.16, 0.20), "spine", fur)
    ell("pelvis", (-0.22, 0, 0.56), (0.27, 0.14, 0.18), "hips", fur)
    lmb("neck", (0.30, 0, 0.62), (0.54, 0, 0.78), 0.14, 0.10, "neck", fur, sides=8)
    ell("skull", (0.60, 0, 0.78), (0.17, 0.125, 0.135), "head", fur)
    lmb("muzzle", (0.66, 0, 0.76), (0.88, 0, 0.71), 0.08, 0.045, "head", belly)
    ell("nose", (0.89, 0, 0.71), (0.03, 0.035, 0.03), "head", NOSE, seg=6, rings=4)
    lmb("ear_n", (0.54, -0.07, 0.86), (0.50, -0.09, 1.04), 0.05, 0.0, "head", EAR, sides=5)
    lmb("ear_f", (0.54, 0.07, 0.86), (0.50, 0.09, 1.04), 0.05, 0.0, "head", EAR, far=True, sides=5)
    ell("eye", (0.69, -0.09, 0.82), (0.055, 0.055, 0.055), "head", EYE, glow=True, seg=6, rings=4)
    ell("star", (0.62, -0.05, 0.89), (0.05, 0.05, 0.06), "head", STAR, glow=True, seg=6, rings=4)
    lmb("tail1", (-0.36, 0, 0.58), (-0.58, 0, 0.52), 0.07, 0.085, "tail1", TAIL)
    lmb("tail2", (-0.58, 0, 0.52), (-0.78, 0, 0.42), 0.085, 0.08, "tail2", TAIL)
    lmb("tail3", (-0.78, 0, 0.42), (-0.94, 0, 0.30), 0.08, 0.0, "tail3", TAIL)
    for side, y in (("n", -0.11), ("f", 0.11)):
        far = side == "f"
        lmb("sho_" + side, (0.28, y, 0.58), (0.30, y, 0.36), 0.10, 0.075, "sho_" + side, FUR_DARK, far)
        lmb("fore_" + side, (0.30, y, 0.36), (0.28, y, 0.16), 0.075, 0.058, "fore_" + side, FUR_DARK, far)
        lmb("paw_" + side, (0.28, y, 0.16), (0.40, y, 0.035), 0.058, 0.062, "paw_" + side, FUR_DARK, far)
        lmb("thigh_" + side, (-0.30, y, 0.55), (-0.18, y, 0.36), 0.12, 0.08, "thigh_" + side, FUR_DARK, far)
        lmb("shin_" + side, (-0.18, y, 0.36), (-0.34, y, 0.20), 0.08, 0.058, "shin_" + side, FUR_DARK, far)
        lmb("meta_" + side, (-0.34, y, 0.20), (-0.24, y, 0.035), 0.058, 0.062, "meta_" + side, FUR_DARK, far)
    if barding:  # plates over the shoulder, flank and neck
        ell("plate_sho", (0.26, -0.15, 0.62), (0.16, 0.05, 0.17), "spine", barding, seg=8, rings=6)
        ell("plate_hip", (-0.22, -0.13, 0.60), (0.18, 0.05, 0.15), "hips", barding, seg=8, rings=6)
        lmb("plate_neck", (0.34, -0.10, 0.66), (0.54, -0.09, 0.80), 0.09, 0.07, "neck", barding, sides=6)


def build(variant=None):
    rig = k.Rig("wolf")
    build_into(rig)
    rig.build()
    return rig


def walk(i, n, pre=""):
    p = i / n * 2 * math.pi
    rot = {}
    for s, end, phase in (("n", "front", 0.0), ("f", "front", math.pi), ("n", "rear", math.pi), ("f", "rear", 0.0)):
        a = p + phase
        swing, lift = 26 * math.sin(a), 46 * max(0.0, math.cos(a))
        if end == "front":
            rot["sho_" + s], rot["fore_" + s], rot["paw_" + s] = down(swing), down(-lift), down(-0.7 * (swing - lift))
        else:
            rot["thigh_" + s], rot["shin_" + s], rot["meta_" + s] = down(0.8 * swing), down(-lift), down(-0.7 * (0.8 * swing - lift) + 8)
    rot["spine"] = up(2.5 * math.sin(2 * p))
    rot["neck"] = up(-1.5 * math.sin(2 * p))
    rot["head"] = down(2 * math.sin(2 * p))
    for name, lag, amp in (("tail1", 0.4, 8), ("tail2", 0.9, 12), ("tail3", 1.4, 16)):
        rot[name] = down(amp * math.sin(p - lag))
    return {pre + name: v for name, v in rot.items()}, (0.0, 0.0, 0.0)


def idle(i, n, pre=""):
    p = i / n * 2 * math.pi
    s = math.sin(p)
    rot = {"spine": up(1.5 * s), "neck": up(-1.0 * s), "head": down(3 * s)}
    for side in "nf":
        rot["sho_" + side], rot["fore_" + side], rot["paw_" + side] = down(2), down(-3), down(1)
        rot["thigh_" + side], rot["shin_" + side], rot["meta_" + side] = down(3), down(-4), down(3)
    for name, lag, amp in (("tail1", 0.3, 5), ("tail2", 0.6, 9), ("tail3", 0.9, 14)):
        rot[name] = down(amp * math.sin(p - lag))
    return {pre + name: v for name, v in rot.items()}, (0.0, 0.0, 0.0)


# frame: crouch, coil, launch, extended, land, recover
POUNCE = {
    "spine": [-6, -10, 8, 10, -4, 0], "neck": [8, 14, -6, -12, 4, 0], "head": [6, 4, -10, -14, 2, 0],
    "sho": [-24, -34, 38, 50, 14, 4], "fore": [34, 46, -10, -30, 12, 0], "paw": [-10, -16, 6, 10, -2, 0],
    "thigh": [24, 36, -34, -46, -10, 4], "shin": [-30, -50, 30, 40, -14, -4], "meta": [8, 14, 10, 4, 0, 0],
    "lift": [0.0, 0.0, 0.18, 0.40, 0.0, 0.0],
}


def pounce(i, n, pre=""):
    rot = {"spine": up(POUNCE["spine"][i]), "neck": up(POUNCE["neck"][i]), "head": down(POUNCE["head"][i])}
    for s in "nf":
        rot["sho_" + s], rot["fore_" + s], rot["paw_" + s] = down(POUNCE["sho"][i]), down(POUNCE["fore"][i]), down(POUNCE["paw"][i])
        rot["thigh_" + s], rot["shin_" + s], rot["meta_" + s] = down(POUNCE["thigh"][i]), down(POUNCE["shin"][i]), down(POUNCE["meta"][i])
    rot["tail1"], rot["tail2"], rot["tail3"] = down(-10), down(-14), down(-18)
    return {pre + name: v for name, v in rot.items()}, (0.0, 0.0, POUNCE["lift"][i])


ANIMS = {"idle": (6, idle, True), "walk": (8, walk, True), "pounce": (6, pounce, True)}
