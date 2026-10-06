"""The skeleton of a four-legged canine (the wolf family), as data, in standard coordinates: about 1.8 units from nose to tail tip, facing +x, ground
at z 0. The kit builds the armature from it, the motion code and its tests read the same numbers. Pure Python.

Proportions: `leg` stretches the legs (a long-legged hound is above 1, a stocky war wolf below), `neck` and `tail` their lengths, `head` the head.
The trunk is the hips (the pelvis and the loins), the spine (the chest) and the neck; the head carries a jaw and two ears; the tail is three
bones. A hind leg is digitigrade: thigh, shin down to the hock, then the metatarsus (`meta`) to the paw. A foreleg is the upper arm (`sho`), the
forearm (`fore`) and the paw.
"""
import skeleton2d

NEAR, FAR = -0.11, 0.11   # the y of the legs the camera sees, and of the others
BASE_SCALE = 1.0


TAIL_DROOPING = ((-0.18, -0.08), (-0.16, -0.13), (-0.12, -0.14))
# an ear's cross-sections along its length: (fraction of the way from the base to the tip, half its width, half its thickness). A wolf's ear is a broad plate: wide, and thin through.
# It faces forward and outward (EAR_FACE, the way its flat face points, for the near ear; the far one is its mirror), so it shows a triangle from the side and from the front.
EAR_SECTIONS = ((0.0, 0.056, 0.026), (0.30, 0.046, 0.022), (0.65, 0.031, 0.016), (0.90, 0.015, 0.009), (1.0, 0.004, 0.004))
EAR_FACE = (0.77, -0.64, 0.0)
TAIL_RAISED = ((-0.20, 0.04), (-0.18, 0.08), (-0.12, 0.12))      # carried high, over the haunches
TAIL_CURLED = ((-0.12, 0.14), (-0.02, 0.20), (0.10, 0.10))       # curled forward over the back


def core(leg=1.0, neck=1.0, tail=1.0, head=1.0, tail_shape=TAIL_DROOPING):
    """[(name, head, tail, parent)] in standard coordinates (x, y, z), parents first."""
    dz = 0.55 * (leg - 1.0)

    def T(x, z):   # a point on the trunk: it rides up with longer legs
        return (x, z + dz)

    def L(x, z):   # a point on a leg: its height scales with the leg
        return (x, z * leg)

    neck_end = T(0.30 + 0.22 * neck, 0.62 + 0.10 * neck)
    head_end = (neck_end[0] + 0.34 * head, neck_end[1] - 0.04 * head)
    bones = [
        ("hips", T(-0.30, 0.55), T(-0.10, 0.58), None),
        ("spine", T(-0.10, 0.58), T(0.30, 0.62), "hips"),
        ("neck", T(0.30, 0.62), neck_end, "spine"),
        ("head", neck_end, head_end, "neck"),
        ("jaw", (neck_end[0] + 0.12 * head, neck_end[1] - 0.05 * head), (neck_end[0] + 0.34 * head, neck_end[1] - 0.14 * head), "head"),
    ]
    prev, parent = T(-0.36, 0.58), "hips"
    for i, (dx, dzt) in enumerate(tail_shape, 1):
        end = (prev[0] + dx * tail, prev[1] + dzt * tail)
        bones.append(("tail%d" % i, prev, end, parent))
        prev, parent = end, "tail%d" % i
    for s, sign in (("n", -1), ("f", 1)):
        y = sign * 0.11
        bones.append(("ear_" + s, (neck_end[0] + 0.02 * head, sign * 0.07, neck_end[1] + 0.08 * head), (neck_end[0] - 0.03 * head, sign * 0.09, neck_end[1] + 0.26 * head), "head"))
    for s, y in (("n", NEAR), ("f", FAR)):
        sho, fore, paw = L(0.28, 0.58), L(0.30, 0.37), L(0.27, 0.16)
        bones += [("sho_" + s, (sho[0], y, sho[1]), (fore[0], y, fore[1]), "spine"),
                  ("fore_" + s, (fore[0], y, fore[1]), (paw[0], y, paw[1]), "sho_" + s),
                  ("paw_" + s, (paw[0], y, paw[1]), (paw[0] + 0.12, y, 0.03 * leg), "fore_" + s)]
        thigh, knee, hock = L(-0.30, 0.55), L(-0.18, 0.36), L(-0.34, 0.20)
        bones += [("thigh_" + s, (thigh[0], y, thigh[1]), (knee[0], y, knee[1]), "hips"),
                  ("shin_" + s, (knee[0], y, knee[1]), (hock[0], y, hock[1]), "thigh_" + s),
                  ("meta_" + s, (hock[0], y, hock[1]), (hock[0] + 0.10, y, 0.03 * leg), "shin_" + s)]
    return [(n, _xyz(h), _xyz(t), p) for n, h, t, p in bones]


def _xyz(point):
    """Trunk and head points are (x, z); leg points were given as (x, y, z). Return (x, y, z)."""
    return (point[0], 0.0, point[1]) if len(point) == 2 else tuple(point)


def placed(point, scale=1.0, origin=(0.0, 0.0, 0.0)):
    x, y, z = point
    return (x * scale + origin[0], y * scale + origin[1], z * scale + origin[2])


def skeleton(scale=1.0, origin=(0.0, 0.0, 0.0), **proportions):
    """The flat skeleton (skeleton2d.Skeleton2D) of a canine of these proportions."""
    rest = {}
    for name, head, tail, parent in core(**proportions):
        h, t = placed(head, scale, origin), placed(tail, scale, origin)
        rest[name] = ((h[0], h[2]), (t[0], t[2]), parent)
    return skeleton2d.Skeleton2D(rest)
