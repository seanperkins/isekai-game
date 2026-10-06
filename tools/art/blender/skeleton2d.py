"""A flat (x, z) copy of `Rig.pose` for rotations about the Y axis (every rotation the creatures use), so a pose can be checked without
Blender: where each bone's head and tail go, and the direction each bone ends up pointing. Pure Python.

Angles. `direction(head, tail)` is a bone's direction as an angle from straight down, forward (+x) positive, in degrees: 0 down, 90 forward,
180 up. A rotation `rot[bone] = (0, theta, 0)` turns the bone about its head and everything below it, and a positive theta turns it clockwise
as the camera sees it (the top of a leaning torso goes forward, a hanging arm goes back), so a bone's direction after the pose is
`rest direction - sum of theta down its chain`. `down(d)` and `up(d)` in the kits are `(0, -d, 0)` and `(0, d, 0)`.
"""
import math


def direction(head, tail):
    return math.degrees(math.atan2(tail[0] - head[0], -(tail[1] - head[1])))


def turn(point, theta):
    """A point turned about the origin by theta degrees about +Y: x' = x cos + z sin, z' = -x sin + z cos."""
    c, s = math.cos(math.radians(theta)), math.sin(math.radians(theta))
    return (point[0] * c + point[1] * s, -point[0] * s + point[1] * c)


class Skeleton2D:
    def __init__(self, rest):
        """`rest` is {bone: (head (x, z), tail (x, z), parent or None)}, parents before children."""
        self.rest = dict(rest)
        self.order = list(rest)

    @classmethod
    def from_rig(cls, rig):
        return cls({n: ((h.x, h.z), (t.x, t.z), p) for n, (h, t, p) in rig.rest.items()})

    def rest_direction(self, bone):
        head, tail, _ = self.rest[bone]
        return direction(head, tail)

    def length(self, bone):
        head, tail, _ = self.rest[bone]
        return math.hypot(tail[0] - head[0], tail[1] - head[1])

    def chain(self, bone):
        """The bone's ancestors, root first, not including the bone."""
        out, parent = [], self.rest[bone][2]
        while parent:
            out.append(parent)
            parent = self.rest[parent][2]
        return out[::-1]

    def pose(self, rot=None, root=(0.0, 0.0, 0.0)):
        """{bone: (head, tail, direction)} in the world for a pose, as `Rig.pose(rot, root)` would put them."""
        rot = rot or {}
        carry, total, out = {}, {}, {}
        for name in self.order:
            head, tail, parent = self.rest[name]
            theta = rot.get(name, (0.0, 0.0, 0.0))[1]
            if parent is None:
                origin, base = (head[0] + root[0], head[1] + root[2]), 0.0
            else:
                ph, _, _ = self.rest[parent]
                dx, dz = turn((head[0] - ph[0], head[1] - ph[1]), total[parent])
                origin, base = (carry[parent][0] + dx, carry[parent][1] + dz), total[parent]
            carry[name], total[name] = origin, base + theta
            dx, dz = turn((tail[0] - head[0], tail[1] - head[1]), total[name])
            out[name] = (origin, (origin[0] + dx, origin[1] + dz), self.rest_direction(name) - total[name])
        return out

    def point(self, bone, rest_point, rot=None, root=(0.0, 0.0, 0.0), posed=None):
        """Where a point that is fixed to a bone (given where it is in the rest pose) goes in a pose."""
        posed = posed or self.pose(rot, root)
        head, _, _ = self.rest[bone]
        total = self.rest_direction(bone) - posed[bone][2]
        dx, dz = turn((rest_point[0] - head[0], rest_point[1] - head[1]), total)
        return (posed[bone][0][0] + dx, posed[bone][0][1] + dz)
