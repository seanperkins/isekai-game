"""The spider: eight legs of three segments each, about 1.4 units across, rendered at 26 px per unit (about 37 game pixels, as today's).

The crawl is an alternating tetrapod gait: the near leg of pair 0, the far leg of pair 1, the near leg of pair 2 and the far leg of pair 3
step together, then the other four. Each leg swings about its hip and lifts by flexing its tibia while it moves forward.
"""
import math

import rigkit as k

NAME = "spider"
CANVAS = 64
PPU = 26.0
MARGIN = 3

BODY, ABDOMEN, LEG = (52, 48, 62), (40, 36, 50), (96, 82, 112)
MARK, EYE, FANG = (210, 52, 62), (255, 232, 140), (236, 230, 210)

HIP_Z = 0.45
HIPS_X = [0.30, 0.15, 0.00, -0.15]
# per pair, how far knee, ankle and foot lie ahead of the previous joint (negative: behind)
REACH = [(0.18, 0.25, 0.05), (0.08, 0.18, 0.05), (-0.08, -0.18, -0.05), (-0.18, -0.25, -0.05)]
SIDES = (("n", -1.0), ("f", 1.0))


def _joints(i, y):
    x0, (kx, ax, fx) = HIPS_X[i], REACH[i]
    hip = (x0, y * 0.10, HIP_Z)
    knee = (x0 + kx, y * 0.32, HIP_Z + 0.30)
    ankle = (x0 + kx + ax, y * 0.52, HIP_Z - 0.15)
    foot = (x0 + kx + ax + fx, y * 0.57, 0.02)
    return hip, knee, ankle, foot


def build(variant=None):
    rig = k.Rig("spider")
    rig.bone("body", (0.0, 0, HIP_Z), (0.25, 0, HIP_Z))
    rig.bone("abdomen", (-0.10, 0, HIP_Z + 0.05), (-0.50, 0, HIP_Z + 0.05), "body")
    for s, y in SIDES:
        for i in range(4):
            hip, knee, ankle, foot = _joints(i, y)
            rig.bone("fem_%s%d" % (s, i), hip, knee, "body")
            rig.bone("tib_%s%d" % (s, i), knee, ankle, "fem_%s%d" % (s, i))
            rig.bone("tar_%s%d" % (s, i), ankle, foot, "tib_%s%d" % (s, i))
    rig.build()

    rig.part(k.ellipsoid("thorax", (0.15, 0, HIP_Z), (0.22, 0.17, 0.15)), "body", BODY)
    rig.part(k.ellipsoid("abdomen", (-0.30, 0, HIP_Z + 0.06), (0.32, 0.23, 0.26)), "abdomen", ABDOMEN)
    rig.part(k.ellipsoid("mark", (-0.28, -0.20, HIP_Z + 0.04), (0.10, 0.05, 0.16), 8, 6), "abdomen", MARK, glow=True)
    rig.part(k.ellipsoid("mark2", (-0.46, -0.14, HIP_Z + 0.10), (0.05, 0.04, 0.10), 6, 5), "abdomen", MARK)
    for n, (ex, ey, ez) in enumerate(((0.34, -0.06, 0.55), (0.37, -0.03, 0.50), (0.33, -0.09, 0.49), (0.30, -0.08, 0.58))):
        rig.part(k.ellipsoid("eye%d" % n, (ex, ey, ez), (0.035, 0.035, 0.035), 6, 4), "body", EYE, glow=True)
    for s, y in SIDES:
        rig.part(k.limb("fang_" + s, (0.36, y * 0.05, 0.42), (0.40, y * 0.05, 0.28), 0.03, 0.0, 5), "body", FANG, far=s == "f")
    for s, y in SIDES:
        for i in range(4):
            hip, knee, ankle, foot = _joints(i, y)
            far = s == "f"
            rig.part(k.limb("fem_%s%d" % (s, i), hip, knee, 0.065, 0.05, 5), "fem_%s%d" % (s, i), LEG, far)
            rig.part(k.limb("tib_%s%d" % (s, i), knee, ankle, 0.05, 0.04, 5), "tib_%s%d" % (s, i), LEG, far)
            rig.part(k.limb("tar_%s%d" % (s, i), ankle, foot, 0.04, 0.02, 5), "tar_%s%d" % (s, i), LEG, far)
    return rig


def _legs(rot, swing, lift):
    """Fill `rot` with each leg's swing and lift: swing(side, pair) and lift(side, pair) are degrees, forward and up positive."""
    for s, _ in SIDES:
        for i in range(4):
            lean = 1.0 if REACH[i][1] > 0 else -1.0  # a leg that leans forward lifts by turning the other way from one that leans back
            rot["fem_%s%d" % (s, i)] = (0.0, -swing(s, i), 0.0)
            rot["tib_%s%d" % (s, i)] = (0.0, -lean * lift(s, i), 0.0)
            rot["tar_%s%d" % (s, i)] = (0.0, -lean * 0.6 * lift(s, i), 0.0)


def _group(s, i):
    """0 for the legs that step first, pi for the others."""
    return 0.0 if (s == "n") == (i % 2 == 0) else math.pi


def crawl(i, n):
    p = i / n * 2 * math.pi
    rot = {}
    _legs(rot,
          lambda s, j: 14 * math.sin(p + _group(s, j)),
          lambda s, j: 30 * max(0.0, math.cos(p + _group(s, j))))
    rot["abdomen"] = (0.0, -2.5 * math.sin(2 * p), 0.0)
    return rot, (0.0, 0.0, 0.0)


def idle(i, n):
    p = i / n * 2 * math.pi
    rot = {}
    _legs(rot, lambda s, j: 2.0 * math.sin(p + j * 0.5), lambda s, j: 4.0 + 2.0 * math.sin(p + j))
    rot["abdomen"] = (0.0, -3.0 * math.sin(p), 0.0)
    return rot, (0.0, 0.0, 0.0)


LUNGE = {  # per frame: settle, rear up, hold, strike, land, recover
    "body": [0, 16, 22, -8, -4, 0],
    "front": [0, 40, 55, -10, 10, 0],   # the front pair reaches up and forward
    "abdomen": [0, 6, 8, -6, -2, 0],
}


def lunge(i, n):
    rot = {"body": (0.0, -LUNGE["body"][i], 0.0), "abdomen": (0.0, -LUNGE["abdomen"][i], 0.0)}
    for s, _ in SIDES:
        for j in range(4):
            reach = LUNGE["front"][i] if j == 0 else (LUNGE["front"][i] * 0.4 if j == 1 else 0.0)
            rot["fem_%s%d" % (s, j)] = (0.0, -reach, 0.0)
            rot["tib_%s%d" % (s, j)] = (0.0, -0.4 * reach if j < 2 else 0.0, 0.0)
    return rot, (0.0, 0.0, 0.0)


ANIMS = {"idle": (6, idle, True), "crawl": (8, crawl, True), "lunge": (6, lunge, True)}
