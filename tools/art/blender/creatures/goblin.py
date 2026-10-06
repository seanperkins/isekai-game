"""The goblin: a biped. About 1.6 units tall, rendered at 26 px per unit, so about 42 game pixels, a little taller than today's goblin.

Animations are functions (frame, count) -> (rotations, root offset); see rigkit.Rig.pose. Angles are degrees about the world axes. Two helpers
name the direction so the tables read in the picture: `down(d)` swings a bone that hangs down so its tip goes forward by d degrees (the
way a leg swings forward), `up(d)` leans a bone that points up forward by d degrees.
"""
import math

import rigkit as k

NAME = "goblin"
CANVAS = 64
PPU = 26.0
MARGIN = 3

SKIN, EAR, NOSE = (98, 162, 74), (120, 180, 90), (84, 140, 62)
CLOTH, EYE, TOOTH = (124, 86, 54), (255, 232, 92), (240, 236, 210)
WOOD, WOOD_DARK = (122, 84, 50), (88, 60, 38)

VARIANTS = {
    "grunt": {},
    "redcap": {"cloth": (150, 40, 40), "hat": (190, 40, 40), "skin": (110, 150, 80)},
    "shaman": {"cloth": (92, 60, 140), "skin": (88, 150, 110), "weapon": "staff", "hat": (92, 60, 140)},
}


def down(d):
    return (0.0, -d, 0.0)


def up(d):
    return (0.0, d, 0.0)


def build(variant=None):
    v = dict(VARIANTS.get(variant or "grunt", {}))
    skin, cloth = v.get("skin", SKIN), v.get("cloth", CLOTH)
    rig = k.Rig("goblin")
    rig.bone("hips", (0, 0, 0.80), (0, 0, 0.95))
    rig.bone("spine", (0, 0, 0.95), (0.05, 0, 1.30), "hips")
    rig.bone("head", (0.07, 0, 1.32), (0.13, 0, 1.62), "spine")
    for s, y in (("n", -0.20), ("f", 0.20)):
        rig.bone("arm_" + s, (0.06, y, 1.28), (0.10, y, 1.04), "spine")
        rig.bone("fore_" + s, (0.10, y, 1.04), (0.22, y, 0.84), "arm_" + s)
    for s, y in (("n", -0.11), ("f", 0.11)):
        rig.bone("thigh_" + s, (0.0, y, 0.80), (0.03, y, 0.48), "hips")
        rig.bone("shin_" + s, (0.03, y, 0.48), (0.0, y, 0.11), "thigh_" + s)
        rig.bone("foot_" + s, (0.0, y, 0.11), (0.22, y, 0.05), "shin_" + s)
    rig.bone("weapon", (0.22, -0.20, 0.84), (0.52, -0.20, 1.14), "fore_n")
    rig.build()

    rig.part(k.ellipsoid("pelvis", (0, 0, 0.88), (0.17, 0.15, 0.13)), "hips", skin)
    rig.part(k.limb("loincloth", (0.0, 0, 0.94), (0.05, 0, 0.58), 0.18, 0.12, 6), "hips", cloth)
    rig.part(k.ellipsoid("torso", (0.04, 0, 1.13), (0.20, 0.17, 0.24)), "spine", skin)
    rig.part(k.ellipsoid("head", (0.14, 0, 1.56), (0.23, 0.20, 0.21)), "head", skin)
    rig.part(k.limb("nose", (0.30, 0, 1.56), (0.46, 0, 1.50), 0.055, 0.0, 6), "head", NOSE)
    rig.part(k.limb("ear_n", (0.10, -0.16, 1.62), (-0.20, -0.46, 1.84), 0.07, 0.0, 5), "head", EAR)
    rig.part(k.limb("ear_f", (0.10, 0.16, 1.62), (-0.20, 0.46, 1.84), 0.07, 0.0, 5), "head", EAR, far=True)
    rig.part(k.ellipsoid("eye_n", (0.31, -0.10, 1.62), (0.05, 0.05, 0.05)), "head", EYE, glow=True)
    rig.part(k.ellipsoid("eye_f", (0.31, 0.10, 1.62), (0.05, 0.05, 0.05)), "head", EYE, far=True, glow=True)
    rig.part(k.limb("tooth", (0.30, -0.05, 1.46), (0.30, -0.05, 1.38), 0.025, 0.0, 4), "head", TOOTH)
    if v.get("hat"):
        rig.part(k.limb("hat", (0.14, 0, 1.70), (0.04, 0, 2.02), 0.20, 0.0, 7), "head", v["hat"])
    for s, y in (("n", -0.20), ("f", 0.20)):
        far = s == "f"
        rig.part(k.limb("arm_" + s, (0.06, y, 1.28), (0.10, y, 1.04), 0.065, 0.052, 6), "arm_" + s, skin, far)
        rig.part(k.limb("fore_" + s, (0.10, y, 1.04), (0.22, y, 0.84), 0.052, 0.045, 6), "fore_" + s, skin, far)
        rig.part(k.ellipsoid("hand_" + s, (0.23, y, 0.82), (0.065, 0.06, 0.065)), "fore_" + s, skin, far)
    for s, y in (("n", -0.11), ("f", 0.11)):
        far = s == "f"
        rig.part(k.limb("thigh_" + s, (0.0, y, 0.80), (0.03, y, 0.48), 0.085, 0.066, 7), "thigh_" + s, skin, far)
        rig.part(k.limb("shin_" + s, (0.03, y, 0.48), (0.0, y, 0.11), 0.066, 0.048, 7), "shin_" + s, skin, far)
        rig.part(k.ellipsoid("foot_" + s, (0.09, y, 0.065), (0.15, 0.065, 0.065)), "foot_" + s, skin, far)
    weapon = v.get("weapon", "club")
    if weapon == "club":
        rig.part(k.limb("handle", (0.20, -0.20, 0.82), (0.50, -0.20, 1.12), 0.035, 0.045, 6), "weapon", WOOD)
        rig.part(k.ellipsoid("knob", (0.57, -0.20, 1.19), (0.10, 0.10, 0.10)), "weapon", WOOD_DARK)
    else:  # a staff with a crystal
        rig.part(k.limb("staff", (0.14, -0.20, 0.55), (0.46, -0.20, 1.72), 0.03, 0.03, 6), "weapon", WOOD)
        rig.part(k.ellipsoid("crystal", (0.47, -0.20, 1.82), (0.07, 0.07, 0.11), 6, 4), "weapon", (170, 120, 255))
    return rig


def walk(i, n):
    p = i / n * 2 * math.pi
    s, c = math.sin(p), math.cos(p)
    flex_n, flex_f = 55 * max(0.0, c), 55 * max(0.0, -c)
    thigh_n, thigh_f = 34 * s, -34 * s
    lean = 6 + 2 * math.sin(2 * p)
    return ({
        "thigh_n": down(thigh_n), "shin_n": down(-flex_n), "foot_n": down(-0.7 * (thigh_n - flex_n)),
        "thigh_f": down(thigh_f), "shin_f": down(-flex_f), "foot_f": down(-0.7 * (thigh_f - flex_f)),
        "arm_n": down(-12 * s + 8), "fore_n": down(34),
        "arm_f": down(30 * s), "fore_f": down(18 + 10 * s),
        "spine": up(lean), "head": up(-lean * 0.7 + 2 * math.cos(2 * p)),
    }, (0.0, 0.0, 0.0))


def idle(i, n):
    p = i / n * 2 * math.pi
    s = math.sin(p)
    bend = 7 + 2 * s
    return ({
        "thigh_n": down(bend), "shin_n": down(-2 * bend), "foot_n": down(bend),
        "thigh_f": down(bend), "shin_f": down(-2 * bend), "foot_f": down(bend),
        "arm_n": down(10 + 2 * s), "fore_n": down(30), "arm_f": down(6 - 2 * s), "fore_f": down(20),
        "spine": up(4 + 1.5 * s), "head": up(-2 - 1.5 * s),
    }, (0.0, 0.0, 0.0))


ATTACK = {  # per frame: windup, windup peak, swing, impact, follow through, recover
    "arm_n": [0, -100, -150, -10, 55, 20], "fore_n": [34, 40, 50, 30, 10, 25],
    "spine": [4, -6, -10, 8, 16, 6], "head": [-2, 4, 6, -4, -8, -2],
    "thigh_n": [8, -6, -10, 12, 22, 8], "shin_n": [-16, 6, 10, -16, -30, -16], "foot_n": [8, 0, 0, 4, 8, 8],
    "thigh_f": [8, 10, 12, 8, 0, 8], "shin_f": [-16, -18, -20, -14, -4, -16], "foot_f": [8, 8, 8, 6, 4, 8],
    "arm_f": [6, 20, 30, 0, -14, 6], "fore_f": [20, 30, 40, 20, 10, 20],
}


def attack(i, n):
    rot = {}
    for bone, track in ATTACK.items():
        d = track[i]
        rot[bone] = up(d) if bone in ("spine", "head") else down(d)
    return rot, (0.0, 0.0, 0.0)


# name: (frames, function, rest the lowest point on the ground)
ANIMS = {"idle": (6, idle, True), "walk": (8, walk, True), "attack": (6, attack, True)}
