"""What every kit needs to put parts on a rig: a place (a scale and an origin), and the part builders bound to bones. Runs inside Blender. A kit
subclasses this and writes its body; parts are written in the kit's standard coordinates and `P` puts them where this creature is."""
import rigkit as k


class KitBase:
    def __init__(self, rig, pre="", scale=1.0, origin=(0.0, 0.0, 0.0)):
        self.rig, self.pre, self.s, self.o = rig, pre, scale, origin

    def P(self, x, y, z):
        return (x * self.s + self.o[0], y * self.s + self.o[1], z * self.s + self.o[2])

    def R(self, r):
        return r * self.s

    def bone(self, name, head, tail, parent=None):
        self.rig.bone(self.pre + name, self.P(*head), self.P(*tail), (self.pre + parent) if parent else None)

    def e(self, name, c, r, bone, rgb, far=False, glow=False, seg=10, rings=7, smooth=False):
        self.rig.part(k.ellipsoid(self.pre + name, self.P(*c), tuple(self.R(v) for v in r), seg, rings, smooth=smooth), self.pre + bone, rgb, far, glow)

    def l(self, name, a, b, r0, r1, bone, rgb, far=False, glow=False, sides=6):
        self.rig.part(k.limb(self.pre + name, self.P(*a), self.P(*b), self.R(r0), self.R(r1), sides, smooth=False), self.pre + bone, rgb, far, glow)

    def loft(self, name, rings, bone, rgb, axis="x", sides=8, far=False, glow=False):
        out = [(self.P(*ring[0]), (self.R(ring[1][0]), self.R(ring[1][1]))) + tuple(ring[2:]) for ring in rings]
        self.rig.part(k.loft(self.pre + name, out, axis, sides, False), self.pre + bone, rgb, far, glow)

    def blade(self, name, root, tip, width, thick, bone, rgb, far=False, glow=False):
        self.rig.part(k.blade(self.pre + name, self.P(*root), self.P(*tip), self.R(width), self.R(thick)), self.pre + bone, rgb, far, glow)

    def box(self, name, c, size, bone, rgb, far=False, glow=False):
        self.rig.part(k.box(self.pre + name, self.P(*c), tuple(self.R(v) for v in size)), self.pre + bone, rgb, far, glow)

    def sheet(self, name, columns, weights, rgb, far=False, glow=False):
        """A thin sheet of cloth through `columns` [(top, bottom)] (standard points), bound by `weights(standard z) -> {bone: weight}`."""
        cols = [(self.P(*a), self.P(*b)) for a, b in columns]
        ob = k.sheet(self.pre + name, cols)
        self.rig.skin(ob, lambda v: {self.pre + b: w for b, w in weights((v.z - self.o[2]) / self.s).items()}, rgb, far, glow)
