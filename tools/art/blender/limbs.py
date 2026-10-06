"""Limbs for the biped creatures, as numbers (no Blender): a leg that is placed by where its foot goes, and the helper that turns an absolute
direction into the rotation a bone needs. See skeleton2d.py for the angle conventions. Pure Python.
"""
import math

import anim
import skeleton2d as sk2


def down(d):
    return (0.0, -d, 0.0)


def up(d):
    return (0.0, d, 0.0)


def aim(skel, rot, bone, direction):
    """Set rot[bone] so the bone points `direction` degrees (from straight down, forward positive) in the world, given the rotations already in
    `rot` for its ancestors."""
    before = sum(rot.get(b, (0.0, 0.0, 0.0))[1] for b in skel.chain(bone))
    rot[bone] = (0.0, skel.rest_direction(bone) - direction - before, 0.0)


class Leg:
    """One leg of a biped: its two bones and its foot, as measured from the rig. `heel` and `toe` are how far the sole reaches behind and in
    front of the ankle, `ankle_h` how far the ankle is above the sole, all with the foot flat."""
    def __init__(self, skel, side, ankle_h, heel, toe, thigh="thigh_", shin="shin_", foot="foot_"):
        self.side = side
        self.names = (thigh + side, shin + side, foot + side)
        t, s, f = self.names
        self.l1, self.l2 = skel.length(t), skel.length(s)
        self.rest1, self.rest2, self.rest_foot = (skel.rest_direction(b) for b in self.names)
        self.hip = skel.rest[t][0]
        self.ankle_h, self.heel, self.toe = ankle_h, heel, toe
        self.reach = self.l1 + self.l2

    def solve(self, hip, ankle, pitch):
        """The rotations that put the ankle on `ankle` (world), the hip being at `hip` (world, x z), and tilt the foot `pitch` degrees, toe up
        positive. The knee goes forward."""
        a1, a2 = anim.ik2d(self.l1, self.l2, hip, ankle, 1)
        d1, d2 = math.degrees(a1) - self.rest1, math.degrees(a2) - self.rest2
        t, s, f = self.names
        return {t: down(d1), s: down(d2 - d1), f: down(pitch - d2)}

    def ankle_of(self, posed):
        return posed[self.names[1]][1]

    def sole(self, posed):
        """(heel, toe) in the world for a posed skeleton: the points that touch the ground."""
        foot = self.names[2]
        total = self.rest_foot - posed[foot][2]  # the foot's total turn, degrees
        ax, az = posed[foot][0]
        pts = []
        for x in (-self.heel, self.toe):
            dx, dz = sk2.turn((x, -self.ankle_h), total)
            pts.append((ax + dx, az + dz))
        return pts[0], pts[1]

    def contact(self, posed):
        """The x where the foot touches the ground in a posed skeleton: the heel when it is the lower end, the toe when that is, between them when
        the sole is flat (as anim.sole_contact decides)."""
        heel, toe = self.sole(posed)
        w = anim.smooth(0.5 + (toe[1] - heel[1]) / (0.08 * (self.heel + self.toe)))
        return w * heel[0] + (1.0 - w) * toe[0]
