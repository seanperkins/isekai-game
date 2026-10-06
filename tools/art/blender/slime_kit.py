"""The slime kit: one jelly dome (slime_motion.Shape) for the whole slime family, deformed per frame as a soft body, with the form's gear
(slime_gear.py) added from its table (slime_forms.py). Runs inside Blender.

The render is opaque and lit by its normals (shade.py), so the gel is suggested the way a pixel artist paints it: a bright rim (a slightly larger
shell of a pale colour behind the body, which shows as a 1 px light edge inside the outline), a soft inner glow (a patch of the near surface in a
light colour that always takes its brightest step), a glossy highlight at the upper left, and anything "inside" the jelly (a stone, a coin, a
thread) drawn just in front of the near surface, lagging the jelly on a spring.

Every mesh part is registered with how the soft body moves it:
  skin   each vertex goes where `slime_motion.deform` sends it (the body, the rim, patches and stripes on the surface, plates)
  carry  moved rigidly with the point of the body it hangs on (eyes, a crown, the stone)
  free   only the root moves it (hovering pebbles, a cloud)
and optionally belongs to a group the motion moves on top of that (`off` in the soft parameters). Chains of bones carry the appendages; post_pose
moves each chain's first bone by where the deformed surface has taken its root, and the armature does the rest.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import kitbase
import rigkit as k
import slime_motion as sm

EYE, GLINT = (22, 26, 56), (250, 252, 255)
RIM_GROW, RIM_BACK = 1.045, 1.15
INK_GROW, INK_BACK = 1.08, 1.3


def lighter(rgb, t):
    return tuple(int(round(c + (255 - c) * t)) for c in rgb)


def darker(rgb, t):
    return tuple(int(round(c * (1.0 - t))) for c in rgb)


def mesh_object(name, verts, faces, smooth=True):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    return k._object(name, bm, smooth)


def oriented_ellipsoid(name, a, b, ry, rn, y=0.0, segments=10, rings=6, smooth=True):
    """An ellipsoid from point a to point b (x, z) at depth y: as long as a to b, `ry` deep and `rn` thick across the line, so a leaf, a wisp,
    a ribbon end or a fold of pelt lies along its bone."""
    ax, az = b[0] - a[0], b[1] - a[1]
    half = math.hypot(ax, az) / 2.0
    ang = math.atan2(az, ax)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    c, s = math.cos(ang), math.sin(ang)
    mx, mz = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    for v in bm.verts:
        lx, ly, lz = v.co.x * half, v.co.y * ry, v.co.z * rn
        v.co = Vector((mx + lx * c - lz * s, y + ly, mz + lx * s + lz * c))
    return k._object(name, bm, smooth)


class SlimeKit(kitbase.KitBase):
    def __init__(self, rig, form):
        super().__init__(rig)
        self.form = form
        self.body = sm.SlimeBody(form)
        self.shape = self.body.shape
        c = form.get("colours", {})
        self.jelly = c.get("jelly", (46, 148, 226))
        self.rim = c.get("rim", lighter(self.jelly, 0.6))
        self.core = c.get("core", lighter(self.jelly, 0.4))
        self.eye = c.get("eye", EYE)
        self.ink = c.get("ink", darker(self.jelly, 0.45))
        self.soft_parts = []          # [dict(ob, rest, mode, anchor, group)]
        self.pivots = dict(form.get("groups", {}))
        if form.get("inner") is not None:
            self.pivots["inner"] = form["inner"]

    # ---- placing things on the body ----
    def S(self, phi, a, lift=0.0):
        """The surface point at plan angle `phi` and placement elevation `a` (height spread evenly: Shape.point), lifted off the surface along
        its normal by `lift` half-widths of a standard body (0.5 units), so a decal stands off the top of the dome as well as off its sides."""
        p = self.shape.point(phi, a, 0.0)
        if not lift:
            return p
        e = 0.5
        da = (self.shape.point(phi, min(89.9, a + e), 0.0), self.shape.point(phi, max(-89.9, a - e), 0.0))
        dp = (self.shape.point(phi + e, a, 0.0), self.shape.point(phi - e, a, 0.0))
        u = [da[0][i] - da[1][i] for i in range(3)]
        v = [dp[0][i] - dp[1][i] for i in range(3)]
        n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        out = (p[0], p[1], p[2] - 0.4 * self.shape.H)
        if sum(x * y for x, y in zip(n, out)) < 0:
            n = [-x for x in n]
        length = math.sqrt(sum(x * x for x in n)) or 1.0
        return tuple(p[i] + n[i] / length * lift * 0.5 for i in range(3))

    def near(self, x, z, lift=0.02):
        return self.shape.near_point(x, z, lift)

    def add(self, ob, rgb, mode="skin", anchor=None, group=None, glow=False, far=False, bone="body", flatten=False):
        """Bind a part to the root bone and register how the soft body moves it (`flatten`: a rigid part that is squashed on the ground rather
        than lifted off it)."""
        self.rig.part(ob, bone, rgb, far, glow)
        if bone == "body":
            rest = [tuple(v.co) for v in ob.data.vertices]
            if mode == "carry" and anchor is None:
                anchor = tuple(sum(v[i] for v in rest) / len(rest) for i in range(3))
            self.soft_parts.append(dict(ob=ob, rest=rest, mode=mode, anchor=anchor, group=group, flatten=flatten))
        return ob

    def blob(self, name, c, r, rgb, mode="carry", group=None, glow=False, far=False, seg=10, rings=7, smooth=True, anchor=None):
        return self.add(k.ellipsoid(name, c, r, seg, rings, smooth=smooth), rgb, mode, anchor or (c if mode == "carry" else None), group, glow, far)

    def patch(self, name, centre, radii, rgb, glow=False, lift=0.012, group=None, steps=(14, 10), mode="skin"):
        """A patch of the surface itself (an ellipse in plan angle and elevation, degrees), lifted a little off it: a decal that bends with the
        body, for an inner glow, a blush, a highlight, a plate."""
        (p0, a0), (rp, ra) = centre, radii
        nu, nv = steps
        verts, faces, index = [], [], {}
        for i in range(nu + 1):
            for j in range(nv + 1):
                u, v = -1.0 + 2.0 * i / nu, -1.0 + 2.0 * j / nv
                index[(i, j)] = len(verts)
                verts.append(self.S(p0 + rp * u, max(-89.0, min(89.0, a0 + ra * v)), lift))
        for i in range(nu):
            for j in range(nv):
                u, v = -1.0 + 2.0 * (i + 0.5) / nu, -1.0 + 2.0 * (j + 0.5) / nv
                if u * u + v * v <= 1.0:
                    faces.append((index[(i, j)], index[(i + 1, j)], index[(i + 1, j + 1)], index[(i, j + 1)]))
        used = sorted({i for f in faces for i in f})
        remap = {o: n for n, o in enumerate(used)}
        ob = mesh_object(name, [verts[i] for i in used], [tuple(remap[i] for i in f) for f in faces], smooth=True)
        return self.add(ob, rgb, mode, None, group, glow)

    def stripe(self, name, points, width, rgb, glow=False, lift=0.016, group=None, mode="skin", closed=False):
        """A thin band along a path of (plan angle, elevation) points on the surface, `width` degrees across: a ribbon, a vein, a thread, a crack."""
        pts = list(points) + ([points[0]] if closed else [])
        verts, faces = [], []
        for i, (p, a) in enumerate(pts):
            q = pts[min(i + 1, len(pts) - 1)]
            o = pts[max(i - 1, 0)]
            dp, da = q[0] - o[0], q[1] - o[1]
            n = math.hypot(dp, da) or 1.0
            sp, sa = -da / n * width / 2.0, dp / n * width / 2.0      # across the path, in angle space
            verts.append(self.S(p + sp, max(-89.0, min(89.0, a + sa)), lift))
            verts.append(self.S(p - sp, max(-89.0, min(89.0, a - sa)), lift))
        for i in range(len(pts) - 1):
            f = (2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1)
            faces.append(self._outward(verts, f))
        ob = mesh_object(name, verts, faces, smooth=True)
        return self.add(ob, rgb, mode, None, group, glow)

    def _outward(self, verts, f):
        p = [verts[i] for i in f]
        a = [p[1][i] - p[0][i] for i in range(3)]
        b = [p[3][i] - p[0][i] for i in range(3)]
        n = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
        c = [sum(q[i] for q in p) / 4.0 for i in range(3)]
        r = (c[0], c[1], c[2] - 0.4 * self.shape.H)
        return f if sum(x * y for x, y in zip(n, r)) >= 0 else tuple(reversed(f))

    def cblade(self, name, root, tip, width, thick, rgb, mode="carry", group=None, glow=False, far=False, anchor=None):
        return self.add(k.blade(name, root, tip, width, thick), rgb, mode, anchor or (root if mode == "carry" else None), group, glow, far)

    def chain_bones(self, chain):
        """[(bone, head (x, y, z), tail (x, y, z))] of a chain, at the depth of its root."""
        ch = self.body.chain(chain)
        y = ch["anchor"][1]
        out = []
        for b in ch["bones"]:
            (hx, hz), (tx, tz), _ = self.body.skel.rest[b]
            out.append((b, (hx, y, hz), (tx, y, tz)))
        return out

    def on_bone(self, ob, bone, rgb, far=False, glow=False):
        self.rig.part(ob, bone, rgb, far, glow)
        return ob

    # ---- the body ----
    def build(self):
        for name, (head, tail, parent) in self.body.skel.rest.items():
            y = 0.0
            for ch in self.body.chains:
                if name in ch["bones"]:
                    y = ch["anchor"][1]
            self.rig.bone(name, (head[0], y, head[1]), (tail[0], y, tail[1]), parent)
        verts, faces = self.shape.mesh()
        self.add(mesh_object("jelly", verts, faces), self.jelly, "skin")
        D = self.shape.D
        # two shells behind the body, a little larger: a bright gel rim, and outside it a dark ink line (the outline then darkens the ink)
        for name, grow, back, rgb, glow in (("rim", RIM_GROW, RIM_BACK, self.rim, True), ("ink", INK_GROW, INK_BACK, self.ink, False)):
            shell = [(x * grow, y * grow + back * D, z * (1.0 + (grow - 1.0) * 0.6)) for x, y, z in verts]
            self.add(mesh_object(name, shell, faces), rgb, "skin", glow=glow)
        if not self.form.get("no_core"):     # the soft inner glow: low in the middle of the near side, a gentle step lighter (or a form's own glow)
            glow = self.form.get("core_glow", False)
            at, size = self.form.get("core_at", (-100.0, -20.0)), self.form.get("core_size", 1.0)
            mid = tuple((a + b) // 2 for a, b in zip(self.jelly, self.core))
            self.patch("core_halo", at, (38.0 * size, 30.0 * size), mid, glow=glow, lift=0.008)
            self.patch("core", (at[0], at[1] - 3.0), (22.0 * size, 17.0 * size), self.core, glow=glow, lift=0.012)
        if not self.form.get("no_glint"):
            self.patch("gloss", (-132.0, 44.0), (15.0, 8.0), GLINT, glow=True, lift=0.02, steps=(8, 6))
            self.patch("gloss2", (-118.0, 26.0), (5.0, 4.5), GLINT, glow=True, lift=0.02, steps=(4, 4))
        if self.form.get("eyes", True):
            self.eyes()

    def eyes(self, places=((0.30, 0.50, 1.0), (0.66, 0.51, 0.92)), size=None, group="eyes"):
        """Two small glossy dark eyes at the upper front right, each with a white glint: placed where they show from the side, at a fraction of
        the half-width forward and of the height up, on the near surface."""
        size = size or self.form.get("eye_size", 1.0)
        places = self.form.get("eye_places", places)
        for i, (fx, fz, s) in enumerate(places):
            c = self.near(fx * self.shape.R, fz * self.shape.H, 0.0)
            r = (0.042 * s * size, 0.03 * s * size, 0.075 * s * size)
            glint = (c[0] - 0.012 * size, c[1] - 0.03 * size, c[2] + 0.032 * size)
            self.blob("eye%d" % i, c, r, self.eye, "carry", group, anchor=c)
            self.blob("eyeglint%d" % i, glint, (0.014 * size,) * 3, GLINT, "carry", group, glow=True, seg=6, rings=4, anchor=c)

    def finish(self):
        """Work out each group's pivot (the form's, or the middle of its parts) and hand the rig the soft-body hook."""
        sums = {}
        for p in self.soft_parts:
            g = p["group"]
            if g and g not in self.pivots:
                acc = sums.setdefault(g, [0.0, 0.0, 0.0, 0])
                for v in p["rest"]:
                    acc[0] += v[0]
                    acc[1] += v[1]
                    acc[2] += v[2]
                    acc[3] += 1
        for g, (x, y, z, n) in sums.items():
            self.pivots[g] = (x / n, y / n, z / n)
        self.rig.post_pose = self.post_pose
        self.rig.slime_kit = self

    # ---- the soft body, each frame ----
    def place(self, v, mode, anchor, soft):
        if mode == "skin":
            return sm.deform(v, soft, self.shape)
        if mode == "carry":
            d = sm.anchor_offset(soft, self.shape, anchor)
            return (v[0] + d[0], v[1] + d[1], v[2] + d[2])
        return v

    def posed_vertices(self, part, soft, floor=None):
        """Where a registered part's vertices are (before the root) under the soft parameters: pure arithmetic, also what the tests check. With
        `floor` (the ground's height before the root: minus the root's z) nothing goes below it: a rigid part (carried or free) is lifted whole
        until it clears the ground (a stone in a puddle, a crown that has fallen), a soft one (skinned, or a ring of light) is flattened on it."""
        off = soft.get("off", {})
        g = part["group"]
        out = [self.place(v, part["mode"], part["anchor"], soft) for v in part["rest"]]
        if g and g in off:
            pivot = self.place(self.pivots[g], part["mode"], part["anchor"], soft)     # the pivot moves as the part does
            out = [sm.group_transform(v, pivot, off[g]) for v in out]
        if floor is not None:
            if part["mode"] == "skin" or part.get("flatten"):
                out = [(x, y, max(z, floor)) for x, y, z in out]
            else:
                low = min(v[2] for v in out)
                if low < floor:
                    out = [(x, y, z + floor - low) for x, y, z in out]
        return out

    def post_pose(self, rig, rot, root):
        soft = sm.soft_of(rot)
        for ch in self.body.chains:
            dx, dz = sm.chain_offset(soft, self.body, ch)
            dy = sm.anchor_offset(soft, self.shape, ch["anchor"])[1]     # and in depth, so a root stays on the surface as the body spreads
            pb = rig.obj.pose.bones[ch["bones"][0]]
            pb.matrix = Matrix.Translation(Vector((dx, dy, dz))) @ pb.matrix
        for part in self.soft_parts:
            me = part["ob"].data
            flat = [c for v in self.posed_vertices(part, soft, -root[2]) for c in v]
            me.vertices.foreach_set("co", flat)
            me.update()
        bpy.context.view_layer.update()
