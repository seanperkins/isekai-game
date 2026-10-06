"""The goblin's skeleton as data, in standard goblin coordinates (see goblin_kit.py): the kit builds the armature from it and the motion code
(goblin_motion.py) and its tests read the same numbers, so a bone moved here moves everywhere. Pure Python.
"""
import skeleton2d

NEAR, FAR = -0.20, 0.20   # the y of the arm the camera sees, and of the other
BASE_BX, BASE_TALL = 1.04, 0.90  # every goblin is built a little shorter than the standard one, and this much broader
LEG_NEAR, LEG_FAR = -0.11, 0.11


def core():
    """[(name, head, tail, parent)] of every bone every goblin has, in standard coordinates (x, y, z), parents first."""
    bones = [
        ("hips", (0, 0, 0.80), (0, 0, 0.95), None),
        ("spine", (0, 0, 0.95), (0.05, 0, 1.30), "hips"),
        ("head", (0.07, 0, 1.32), (0.13, 0, 1.62), "spine"),
    ]
    for s, y in (("n", NEAR), ("f", FAR)):
        bones += [
            ("arm_" + s, (0.06, y, 1.28), (0.10, y, 1.02), "spine"),
            ("fore_" + s, (0.10, y, 1.02), (0.24, y, 0.78), "arm_" + s),
            ("item_" + s, (0.25, y, 0.76), (0.25, y, 0.86), "fore_" + s),
        ]
    for s, y in (("n", LEG_NEAR), ("f", LEG_FAR)):
        bones += [
            ("thigh_" + s, (0.0, y, 0.80), (0.03, y, 0.48), "hips"),
            ("shin_" + s, (0.03, y, 0.48), (0.0, y, 0.11), "thigh_" + s),
            ("foot_" + s, (0.0, y, 0.11), (0.22, y, 0.05), "shin_" + s),
        ]
    return bones


def ears(ears=1.0):
    """The two ear bones: flat blades swept back from the crown, nearly level, longer for a goblin with `ears` above 1."""
    out = []
    for s, y in (("n", -1), ("f", 1)):
        out.append(("ear_" + s, (0.08, y * 0.13, 1.60), (-0.14 * ears, y * 0.30 * ears, 1.63 + 0.05 * ears), "head"))
    return out


def placed(point, bx=1.0, tall=1.0, scale=1.0, origin=(0.0, 0.0, 0.0)):
    """A standard point (x, y, z) moved onto a goblin of build `bx`, height `tall`, at `scale` and `origin` (Goblin.P in goblin_kit.py)."""
    x, y, z = point
    return (x * bx * scale + origin[0], y * bx * scale + origin[1], z * tall * scale + origin[2])


def skeleton(bx=1.0, tall=1.0, scale=1.0, origin=(0.0, 0.0, 0.0), extra=()):
    """The flat skeleton (skeleton2d.Skeleton2D) of a goblin of this build: what the motion code poses and the tests check."""
    rest = {}
    for name, head, tail, parent in list(core()) + list(extra):
        h, t = placed(head, bx, tall, scale, origin), placed(tail, bx, tall, scale, origin)
        rest[name] = ((h[0], h[2]), (t[0], t[2]), parent)
    return skeleton2d.Skeleton2D(rest)
