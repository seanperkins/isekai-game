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


def build(variant=None):
    rig = k.Rig("wolf")
    rig.bone("hips", (-0.30, 0, 0.55), (-0.10, 0, 0.58))
    rig.bone("spine", (-0.10, 0, 0.58), (0.30, 0, 0.62), "hips")
    rig.bone("neck", (0.30, 0, 0.62), (0.52, 0, 0.78), "spine")
    rig.bone("head", (0.52, 0, 0.78), (0.86, 0, 0.72), "neck")
    rig.bone("tail1", (-0.36, 0, 0.58), (-0.58, 0, 0.52), "hips")
    rig.bone("tail2", (-0.58, 0, 0.52), (-0.78, 0, 0.42), "tail1")
    rig.bone("tail3", (-0.78, 0, 0.42), (-0.94, 0, 0.30), "tail2")
    for s, y in (("n", -0.11), ("f", 0.11)):
        rig.bone("sho_" + s, (0.28, y, 0.58), (0.30, y, 0.36), "spine")
        rig.bone("fore_" + s, (0.30, y, 0.36), (0.28, y, 0.16), "sho_" + s)
        rig.bone("paw_" + s, (0.28, y, 0.16), (0.40, y, 0.03), "fore_" + s)
        rig.bone("thigh_" + s, (-0.30, y, 0.55), (-0.18, y, 0.36), "hips")
        rig.bone("shin_" + s, (-0.18, y, 0.36), (-0.34, y, 0.20), "thigh_" + s)
        rig.bone("meta_" + s, (-0.34, y, 0.20), (-0.24, y, 0.03), "shin_" + s)
    rig.build()

    rig.part(k.ellipsoid("chest", (0.18, 0, 0.58), (0.34, 0.16, 0.20)), "spine", FUR)
    rig.part(k.ellipsoid("pelvis", (-0.22, 0, 0.56), (0.27, 0.14, 0.18)), "hips", FUR)
    rig.part(k.limb("neck", (0.30, 0, 0.62), (0.54, 0, 0.78), 0.14, 0.10, 8), "neck", FUR)
    rig.part(k.ellipsoid("skull", (0.60, 0, 0.78), (0.17, 0.125, 0.135)), "head", FUR)
    rig.part(k.limb("muzzle", (0.66, 0, 0.76), (0.88, 0, 0.71), 0.08, 0.045, 7), "head", MUZZLE)
    rig.part(k.ellipsoid("nose", (0.89, 0, 0.71), (0.03, 0.035, 0.03), 6, 4), "head", NOSE)
    rig.part(k.limb("ear_n", (0.54, -0.07, 0.86), (0.50, -0.09, 1.04), 0.05, 0.0, 5), "head", EAR)
    rig.part(k.limb("ear_f", (0.54, 0.07, 0.86), (0.50, 0.09, 1.04), 0.05, 0.0, 5), "head", EAR, far=True)
    rig.part(k.ellipsoid("eye", (0.69, -0.09, 0.82), (0.055, 0.055, 0.055), 6, 4), "head", EYE, glow=True)
    rig.part(k.ellipsoid("star", (0.62, -0.05, 0.89), (0.05, 0.05, 0.06), 6, 4), "head", STAR, glow=True)
    rig.part(k.limb("tail1", (-0.36, 0, 0.58), (-0.58, 0, 0.52), 0.07, 0.085, 7), "tail1", TAIL)
    rig.part(k.limb("tail2", (-0.58, 0, 0.52), (-0.78, 0, 0.42), 0.085, 0.08, 7), "tail2", TAIL)
    rig.part(k.limb("tail3", (-0.78, 0, 0.42), (-0.94, 0, 0.30), 0.08, 0.0, 7), "tail3", TAIL)
    for s, y in (("n", -0.11), ("f", 0.11)):
        far = s == "f"
        c = FUR_DARK
        rig.part(k.limb("sho_" + s, (0.28, y, 0.58), (0.30, y, 0.36), 0.10, 0.075, 7), "sho_" + s, c, far)
        rig.part(k.limb("fore_" + s, (0.30, y, 0.36), (0.28, y, 0.16), 0.075, 0.058, 7), "fore_" + s, c, far)
        rig.part(k.limb("paw_" + s, (0.28, y, 0.16), (0.40, y, 0.035), 0.058, 0.062, 7), "paw_" + s, c, far)
        rig.part(k.limb("thigh_" + s, (-0.30, y, 0.55), (-0.18, y, 0.36), 0.12, 0.08, 7), "thigh_" + s, c, far)
        rig.part(k.limb("shin_" + s, (-0.18, y, 0.36), (-0.34, y, 0.20), 0.08, 0.058, 7), "shin_" + s, c, far)
        rig.part(k.limb("meta_" + s, (-0.34, y, 0.20), (-0.24, y, 0.035), 0.058, 0.062, 7), "meta_" + s, c, far)
    return rig


def walk(i, n):
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
    return rot, (0.0, 0.0, 0.0)


def idle(i, n):
    p = i / n * 2 * math.pi
    s = math.sin(p)
    rot = {"spine": up(1.5 * s), "neck": up(-1.0 * s), "head": down(3 * s)}
    for side in "nf":
        rot["sho_" + side], rot["fore_" + side], rot["paw_" + side] = down(2), down(-3), down(1)
        rot["thigh_" + side], rot["shin_" + side], rot["meta_" + side] = down(3), down(-4), down(3)
    for name, lag, amp in (("tail1", 0.3, 5), ("tail2", 0.6, 9), ("tail3", 0.9, 14)):
        rot[name] = down(amp * math.sin(p - lag))
    return rot, (0.0, 0.0, 0.0)


# frame: crouch, coil, launch, extended, land, recover
POUNCE = {
    "spine": [-6, -10, 8, 10, -4, 0], "neck": [8, 14, -6, -12, 4, 0], "head": [6, 4, -10, -14, 2, 0],
    "sho": [-24, -34, 38, 50, 14, 4], "fore": [34, 46, -10, -30, 12, 0], "paw": [-10, -16, 6, 10, -2, 0],
    "thigh": [24, 36, -34, -46, -10, 4], "shin": [-30, -50, 30, 40, -14, -4], "meta": [8, 14, 10, 4, 0, 0],
    "lift": [0.0, 0.0, 0.18, 0.40, 0.0, 0.0],
}


def pounce(i, n):
    rot = {"spine": up(POUNCE["spine"][i]), "neck": up(POUNCE["neck"][i]), "head": down(POUNCE["head"][i])}
    for s in "nf":
        rot["sho_" + s], rot["fore_" + s], rot["paw_" + s] = down(POUNCE["sho"][i]), down(POUNCE["fore"][i]), down(POUNCE["paw"][i])
        rot["thigh_" + s], rot["shin_" + s], rot["meta_" + s] = down(POUNCE["thigh"][i]), down(POUNCE["shin"][i]), down(POUNCE["meta"][i])
    rot["tail1"], rot["tail2"], rot["tail3"] = down(-10), down(-14), down(-18)
    return rot, (0.0, 0.0, POUNCE["lift"][i])


ANIMS = {"idle": (6, idle, True), "walk": (8, walk, True), "pounce": (6, pounce, True)}
