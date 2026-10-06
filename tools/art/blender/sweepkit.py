"""The geometry of a swept tube, pure Python (no Blender): a leg, a neck or a tail as one smooth shape through its joints instead of a stack of cones and balls.

`resample` smooths a path through control points (the joints of a limb) with a Catmull-Rom curve and carries a cross-section along it; `rings` puts an ellipse at each
sample, perpendicular to the path (mitered at a bend, so a knee is as thick as the leg either side of it); `arclength_of` and `joint_weights` say how far along the bones a
vertex is and how its weight is shared between the two bones at a joint, which is what lets one tube bend like skin. rigkit.sweep builds the mesh from these.
"""
import math


def _sub(a, b):
    return tuple(p - q for p, q in zip(a, b))


def _add(a, b):
    return tuple(p + q for p, q in zip(a, b))


def _scale(a, k):
    return tuple(p * k for p in a)


def _dot(a, b):
    return sum(p * q for p, q in zip(a, b))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(a):
    n = math.sqrt(_dot(a, a))
    return _scale(a, 1.0 / n) if n > 1e-12 else a


def _smoothstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def resample(points, sections, per=3):
    """(points, sections, at): `per` samples for every pair of control points, along a Catmull-Rom curve through them, each with a (half width, half depth) section blended between
    its two neighbours' sections. `at` lists the index of each control point in the result."""
    n = len(points)
    out_p, out_s, at = [], [], []
    for i in range(n - 1):
        p0 = points[max(i - 1, 0)]
        p1, p2 = points[i], points[i + 1]
        p3 = points[min(i + 2, n - 1)]
        at.append(len(out_p))
        for k in range(per):
            t = k / float(per)
            t2, t3 = t * t, t * t * t
            p = tuple(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3) for a, b, c, d in zip(p0, p1, p2, p3))
            w = _smoothstep(t)
            s = tuple(x * (1.0 - w) + y * w for x, y in zip(sections[i], sections[i + 1]))
            out_p.append(p)
            out_s.append(s)
    at.append(len(out_p))
    out_p.append(tuple(points[-1]))
    out_s.append(tuple(sections[-1]))
    return out_p, out_s, at


def tangent_at(points, i):
    """The unit direction of the path at sample i."""
    lo, hi = max(i - 1, 0), min(i + 1, len(points) - 1)
    return _norm(_sub(points[hi], points[lo]))


def rings(points, sections, sides=10):
    """One ring of `sides` vertices for each sample: an ellipse of the sample's (half width, half depth) in the plane across the path. The width runs along the plane's own
    direction in the path's plane (front to back for a leg), the depth along y. A bend widens the ring by the cosine of its angle, so the leg does not pinch at a joint."""
    out = []
    up = (0.0, 1.0, 0.0)
    for i, c in enumerate(points):
        t = tangent_at(points, i)
        u = _norm(_cross(up, t))
        v = _norm(_cross(t, u))
        miter = 1.0
        for j in (i - 1, i + 1):
            if 0 <= j < len(points):
                d = _norm(_sub(points[j], c))
                miter = min(miter, abs(_dot(t, d)))
        a, b = sections[i]
        a = a / max(miter, 0.55)
        ring = []
        for k in range(sides):
            th = 2.0 * math.pi * k / sides
            ring.append(_add(c, _add(_scale(u, math.cos(th) * a), _scale(v, math.sin(th) * b))))
        out.append(ring)
    return out


def _project(p, poly):
    """(distance, arclength) of the closest point of the polyline to p."""
    best = (1e18, 0.0)
    run = 0.0
    for i in range(len(poly) - 1):
        a, b = poly[i], poly[i + 1]
        ab = _sub(b, a)
        L2 = _dot(ab, ab)
        t = 0.0 if L2 < 1e-18 else max(0.0, min(1.0, _dot(_sub(p, a), ab) / L2))
        q = _add(a, _scale(ab, t))
        d = math.sqrt(_dot(_sub(p, q), _sub(p, q)))
        if d < best[0]:
            best = (d, run + t * math.sqrt(L2))
        run += math.sqrt(L2)
    return best


def distance_to_polyline(p, poly):
    return _project(p, poly)[0]


def arclength_of(p, poly):
    """How far along the polyline the point nearest to p is."""
    return _project(p, poly)[1]


def joint_weights(s, joints, width):
    """The weight of each bone at arclength `s` when the joints between bones lie at the arclengths `joints`: one near a bone's middle, shared smoothly across `width` either
    side of a joint (even at the joint itself). Always sums to one."""
    fs = [_smoothstep((s - (b - width)) / (2.0 * width)) for b in joints]
    out = [1.0 - fs[0]] if fs else [1.0]
    for i in range(1, len(fs)):
        out.append(fs[i - 1] - fs[i])
    if fs:
        out.append(fs[-1])
    return out
