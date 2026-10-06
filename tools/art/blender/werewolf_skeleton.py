"""The skeleton of the upright wolf-men (moonbound, loup-garou, ulfhedinn, the beast of Gevaudan, lycaon, the wolfskin champion), as data, in standard
coordinates (about 2 units standing). The goblin's bone names, so `biped_motion` poses it with a werewolf posture, and extra bones for the jaw, the tail and
the ears. The legs are digitigrade: a long thigh, a shin that slopes back to a high ankle (the hock), and a long foot that stands on its toe pad.
Pure Python."""
import skeleton2d

NEAR, FAR = -0.24, 0.24
LEG_NEAR, LEG_FAR = -0.13, 0.13
BASE_SCALE = 1.0


def core(tall=1.0, arm=1.0):
    """[(name, head, tail, parent)] in standard coordinates (x, y, z), parents first. `tall` stretches the legs and trunk, `arm` the arms."""
    t = tall
    bones = [
        ("hips", (0, 0, 0.90 * t), (0, 0, 1.04 * t), None),
        ("spine", (0, 0, 1.04 * t), (0.07, 0, 1.50 * t), "hips"),
        ("head", (0.10, 0, 1.50 * t), (0.22, 0, 1.80 * t), "spine"),
        ("jaw", (0.24, 0, 1.68 * t), (0.52, 0, 1.60 * t), "head"),
    ]
    for s, y in (("n", NEAR), ("f", FAR)):
        bones += [
            ("arm_" + s, (0.08, y, 1.46 * t), (0.08 + 0.07 * arm, y, 1.46 * t - 0.32 * arm), "spine"),
            ("fore_" + s, (0.08 + 0.07 * arm, y, 1.46 * t - 0.32 * arm), (0.08 + 0.22 * arm, y, 1.46 * t - 0.64 * arm), "arm_" + s),
            ("item_" + s, (0.08 + 0.24 * arm, y, 1.46 * t - 0.66 * arm), (0.08 + 0.24 * arm, y, 1.46 * t - 0.54 * arm), "fore_" + s),
        ]
    for s, y in (("n", LEG_NEAR), ("f", LEG_FAR)):
        bones += [
            ("thigh_" + s, (0, y, 0.90 * t), (0.10, y, 0.54 * t), "hips"),
            ("shin_" + s, (0.10, y, 0.54 * t), (-0.06, y, 0.27 * t), "thigh_" + s),
            ("foot_" + s, (-0.06, y, 0.27 * t), (0.16, y, 0.02), "shin_" + s),
        ]
    prev, parent = (-0.06, 0, 0.98 * t), "hips"
    for i, (dx, dz) in enumerate(((-0.24, -0.08), (-0.22, -0.18), (-0.16, -0.20)), 1):
        end = (prev[0] + dx, 0, prev[2] + dz * t)
        bones.append(("tail%d" % i, prev, end, parent))
        prev, parent = end, "tail%d" % i
    for s, sign in (("n", -1), ("f", 1)):
        bones.append(("ear_" + s, (0.16, sign * 0.10, 1.76 * t), (0.04, sign * 0.15, 2.00 * t), "head"))
    return bones


def placed(point, scale=1.0, origin=(0.0, 0.0, 0.0)):
    x, y, z = point
    return (x * scale + origin[0], y * scale + origin[1], z * scale + origin[2])


def skeleton(scale=1.0, origin=(0.0, 0.0, 0.0), **proportions):
    """The flat skeleton (skeleton2d.Skeleton2D) of a wolf-man of these proportions."""
    rest = {}
    for name, head, tail, parent in core(**proportions):
        h, t = placed(head, scale, origin), placed(tail, scale, origin)
        rest[name] = ((h[0], h[2]), (t[0], t[2]), parent)
    return skeleton2d.Skeleton2D(rest)
