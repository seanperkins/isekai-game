"""Colour roles, pure Python. A creature's body is its primary colour, its limbs the secondary, its accents (knee rings, markings, eyes) the tertiary. A limb is drawn in front
of the body, in a flat-lit sprite a few dozen pixels wide, so the limbs must stand apart from the body in value or they are lost in it: `apart` guarantees it."""
import math


def luma(rgb):
    return 0.30 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]


def dist(a, b):
    return math.sqrt(sum((p - q) ** 2 for p, q in zip(a, b)))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def room(rgb, floor=76):
    """A dark colour lifted so its shadows have somewhere to go: the shading ramps darken a colour in steps, and from near black there is nothing below.
    A colour already as light as `floor` is left alone."""
    lum = luma(rgb)
    if lum >= floor:
        return tuple(rgb)
    k = min(1.9, floor / max(lum, 1.0))
    return tuple(min(255, int(round(c * k))) for c in rgb)


LIGHT = (232, 226, 240)     # what a limb is lightened toward: a pale tint, so it stays of its own hue family


def apart(body, limb, gap):
    """`limb` moved, if it needs it, until its value is at least `gap` away from `body`'s: lighter when the body is dark, darker when the body is light. One that already stands
    apart is returned as it is."""
    want = luma(body)
    if abs(luma(limb) - want) >= gap:
        return tuple(limb)
    light = want <= 140.0
    target = want + gap if light else want - gap
    goal = LIGHT if light else (0, 0, 0)
    lo, hi = 0.0, 1.0
    for _ in range(30):
        mid = (lo + hi) / 2.0
        c = tuple(limb[i] + (goal[i] - limb[i]) * mid for i in range(3))
        if (luma(c) >= target) if light else (luma(c) <= target):
            hi = mid
        else:
            lo = mid
    out = tuple(max(0, min(255, int(math.ceil(limb[i] + (goal[i] - limb[i]) * hi)) if light else int(math.floor(limb[i] + (goal[i] - limb[i]) * hi)))) for i in range(3))
    return out
