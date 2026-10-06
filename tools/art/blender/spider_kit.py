"""The spider kit: one skeleton (spider_skeleton.py) for the whole spider family, a body built from it and gear (spider_gear.py) added from a table
(spider_forms.py). Runs inside Blender. The body is glossy and faceted: a domed carapace with the eyes at its front, a big round abdomen carried up
behind (a tilted, flat-shaded egg whose facets catch the light), thin tapering legs that arc up to high knees with a ring of colour at each joint, and
for a drider a person's upper body rising from the front: a slim torso, a small head with hair that hangs on its own bones, thin arms, and clothes
that are thin sheets skinned to the body and the cloth bones.

Parts are placed relative to the bones and sizes of the form's own skeleton, so a lean stalker, a bloated matriarch and a tall drider share the code.
"""
import math

import rigkit as k
import spider_skeleton as skeleton
from wolf_kit import room

BLACK, LEG, MARK, EYE, JOINT, FANG = (40, 36, 48), (40, 34, 46), (214, 34, 44), (255, 70, 70), (176, 34, 44), (96, 40, 50)
GLOSS = (150, 146, 164)
SKIN, HAIR = (200, 188, 212), (58, 46, 82)


class Spider:
    def __init__(self, rig, form, pre="", scale=1.0, origin=(0.0, 0.0, 0.0)):
        self.rig, self.form, self.pre, self.s, self.o = rig, form, pre, scale, origin
        self.proportions = skeleton.proportions_of(form)
        self.sh = skeleton.shape(**self.proportions)
        self.bones = {n: (h, t, p) for n, h, t, p in skeleton.core(**self.proportions)}
        self.th, self.ab = self.proportions["thorax"], self.proportions["abdomen"]
        self.lw = form.get("leg_w", 1.0)
        d = self.proportions["drider"]
        self.tall = d["tall"] if d else 1.0
        self.chitin = room(form.get("chitin", BLACK), form.get("floor", 52))
        self.dark = tuple(int(c * 0.78) for c in self.chitin)
        self.leg_c = room(form.get("leg", LEG), form.get("floor", 50))
        # dust or clay caked on the lower legs: set before the legs are built
        self.leg_low = None
        for name, kw in form.get("gear", []):
            if name in ("dust", "clay_crust"):
                self.leg_low = kw.get("color", (176, 148, 104) if name == "clay_crust" else (196, 170, 124))
        self.mark = form.get("mark", MARK)
        self.eye = form.get("eye", EYE)
        self.joint = form.get("joint", JOINT)
        self.fang_c = room(FANG, 90)
        self.skin = form.get("skin", SKIN)
        self.hair_c = room(form.get("hair", HAIR), 70)
        self.leg_keys = list(skeleton.LEGS)

    # ---- placing things ----
    def P(self, x, y, z):
        return (x * self.s + self.o[0], y * self.s + self.o[1], z * self.s + self.o[2])

    def R(self, r):
        return r * self.s

    def bone(self, name, head, tail, parent=None):
        self.rig.bone(self.pre + name, self.P(*head), self.P(*tail), (self.pre + parent) if parent else None)

    def e(self, name, c, r, bone, rgb, far=False, glow=False, seg=10, rings=7, smooth=False):
        return self.rig.part(k.ellipsoid(self.pre + name, self.P(*c), tuple(self.R(v) for v in r), seg, rings, smooth=smooth), self.pre + bone, rgb, far, glow)

    def l(self, name, a, b, r0, r1, bone, rgb, far=False, glow=False, sides=6):
        return self.rig.part(k.limb(self.pre + name, self.P(*a), self.P(*b), self.R(r0), self.R(r1), sides, smooth=False), self.pre + bone, rgb, far, glow)

    def loft(self, name, rings, bone, rgb, axis="x", sides=8, far=False, glow=False):
        out = [(self.P(*ring[0]), (self.R(ring[1][0]), self.R(ring[1][1]))) + tuple(ring[2:]) for ring in rings]
        return self.rig.part(k.loft(self.pre + name, out, axis, sides, False), self.pre + bone, rgb, far, glow)

    def blade(self, name, root, tip, width, thick, bone, rgb, far=False, glow=False):
        return self.rig.part(k.blade(self.pre + name, self.P(*root), self.P(*tip), self.R(width), self.R(thick)), self.pre + bone, rgb, far, glow)

    def sheet_xy(self, name, columns, weights, rgb, far=False, glow=False):
        """A cloth sheet skinned to bones by `weights(vertex) -> {bone: weight}` (the vertex in standard coordinates)."""
        cols = [(self.P(*a), self.P(*b)) for a, b in columns]
        ob = k.sheet(self.pre + name, cols)

        def w(co):
            std = _Std((co.x - self.o[0]) / self.s, (co.y - self.o[1]) / self.s, (co.z - self.o[2]) / self.s)
            return {self.pre + b: v for b, v in weights(std).items() if v > 0.0}
        return self.rig.skin(ob, w, rgb, far, glow)

    def tilted(self, name, centre, radii, angle, bone, rgb, far=False, glow=False, seg=14, rings=9):
        """An ellipsoid whose long axis is turned `angle` degrees up from pointing straight back (about y, through its centre)."""
        ob = k.ellipsoid(self.pre + name, self.P(*centre), tuple(self.R(v) for v in radii), seg, rings, smooth=False)
        c = self.P(*centre)
        a = math.radians(angle)
        ca, sa = math.cos(a), math.sin(a)
        for v in ob.data.vertices:
            x, z = v.co.x - c[0], v.co.z - c[2]
            # the long axis lies along x; turning it up behind means the -x end rises
            v.co.x, v.co.z = c[0] + x * ca + z * sa, c[2] - x * sa + z * ca
        return self.rig.part(ob, self.pre + bone, rgb, far, glow)

    # ---- the idle pose, for gear that is held where the idle puts a hand or a claw ----
    def where(self, bone, u=1.0):
        """Where the idle pose puts the point `u` of the way along a bone, (x, z)."""
        import spider_motion
        return spider_motion.where(self.form, bone, u)

    def rest_point(self, bone, world, y=0.0):
        """The point (x, y, z) to build a part at, bound to `bone`, so that the idle pose carries it to `world` (x, z)."""
        import spider_motion
        x, z = spider_motion.rest_point(self.form, bone, world)
        return (x, y, z)

    # ---- points on the body ----
    def thorax_point(self, u, v, y=0.0):
        sh = self.sh
        return (sh["xc"] + u * sh["T"], y * sh["th_w"] * 1.6, sh["hc"] + v * sh["th_h"])

    def _axes(self):
        sh = self.sh
        a = math.radians(sh["a_dir"])
        A = (math.sin(a), -math.cos(a))           # along the abdomen, toward its end
        N = (A[1], -A[0])                          # perpendicular, toward its top
        return A, N

    def abdomen_point(self, u, v, y=-1.0, out=1.0):
        """A point on the abdomen's surface in the direction (`u` along it: -1 toward the pedicel, 1 toward the spinnerets; `v` up it: 1 its back;
        `y` across: -1 the near side, which faces the camera), pushed out `out` times from the centre."""
        n = math.sqrt(u * u + v * v + y * y) or 1.0
        return self._abd(u / n * out, v / n * out, y / n * out)

    def painted_point(self, u, v, out=1.0):
        """The point of the abdomen's near side that the camera sees at (u, v) of its outline."""
        depth = math.sqrt(max(0.0, 1.0 - u * u - v * v))
        return self._abd(u * out, v * out, -depth * out)

    def _abd(self, u, v, y):
        sh = self.sh
        A, N = self._axes()
        c = sh["a_centre"]
        return (c[0] + u * sh["ax"] * A[0] + v * sh["az"] * N[0], y * sh["ay"], c[1] + u * sh["ax"] * A[1] + v * sh["az"] * N[1])

    def head_point(self, u, v, y=0.0):
        """A point on a drider's head: `u` from the back of the skull (0) to the face (1), `v` from the chin (0) to the crown (1)."""
        h, t, _ = self.bones["head"]
        k_ = self.tall
        return (h[0] - 0.05 * k_ + 0.11 * k_ * u, y * k_, h[2] + 0.17 * k_ * v)

    # ---- markings ----
    def mark_line(self, name, a, b, width, rgb, glow=False):
        """A band painted on the abdomen's near side from (u, v) to (u, v), following its curve."""
        n = 4
        pts = []
        for i in range(n + 1):
            u = a[0] + (b[0] - a[0]) * i / n
            v = a[1] + (b[1] - a[1]) * i / n
            pts.append(self.painted_point(u, v, out=1.015))
        for i in range(n):
            taper = 1.0 - 0.5 * abs(i - (n - 1) / 2.0) / n
            self.l("%s_%d" % (name, i), pts[i], pts[i + 1], width * 0.5 * taper * self.ab, width * 0.5 * taper * self.ab, "abdomen", rgb, glow=glow, sides=5)

    def band(self, name, u, width, rgb):
        """A band wound round the abdomen at `u` along it: a thin disc a little bigger than the abdomen's section there."""
        sh = self.sh
        A, _ = self._axes()
        c = sh["a_centre"]
        f = math.sqrt(max(0.05, 1.0 - u * u)) * 1.06
        p = (c[0] + u * sh["ax"] * A[0], 0.0, c[1] + u * sh["ax"] * A[1])
        self.tilted(name, p, (width, sh["ay"] * f, sh["az"] * f), -sh["a_dir"] - 90.0, "abdomen", rgb, seg=12, rings=6)

    def strip(self, name, points, width, weights, rgb, glow=False, far=False):
        """A narrow ribbon through `points` (a thread of silk), skinned by `weights` so it can run from one bone to another."""
        cols = [((x, y, z + 0.5 * width), (x, y, z - 0.5 * width)) for x, y, z in points]
        return self.sheet_xy(name, cols, weights, rgb, far=far, glow=glow)

    # ---- the drider's clothes ----
    def dress_torso(self, rgb, bare_chest=False):
        k_ = self.tall
        w = self.bones["waist"]
        c = self.bones["chest"]
        self.loft("dress_w", [((w[0][0], 0, w[0][2] - 0.02), (0.075 * k_, 0.085 * k_)), ((w[1][0], 0, w[1][2]), (0.062 * k_, 0.072 * k_))], "waist", rgb, "z", 8)
        if not bare_chest:
            self.loft("dress_c", [((c[0][0], 0, c[0][2]), (0.062 * k_, 0.072 * k_)), ((c[0][0] + 0.25 * (c[1][0] - c[0][0]), 0, c[0][2] + 0.4 * (c[1][2] - c[0][2])), (0.070 * k_, 0.08 * k_)),
                                  ((c[1][0] - 0.01, 0, c[1][2] - 0.03 * k_), (0.072 * k_, 0.088 * k_))], "chest", rgb, "z", 8)

    def obi(self, rgb):
        k_ = self.tall
        w = self.bones["waist"]
        self.loft("obi", [((w[1][0], 0, w[1][2] - 0.03 * k_), (0.072 * k_, 0.082 * k_)), ((w[1][0] + 0.005, 0, w[1][2] + 0.04 * k_), (0.072 * k_, 0.082 * k_))], "waist", rgb, "z", 8)

    def skirt(self, rgb, trim, ragged=False, short=False):
        """A skirt from the waist falling over the front of the spider, flared, its hem uneven: a sheet skinned to the waist at the top and the cloth
        bones lower down, so it trails as the body moves."""
        k_ = self.tall
        w = self.bones["waist"]
        top_z = w[1][2]
        drop = (0.12 if short else 0.20) * k_
        hem_floor = self.sh["hc"] * 0.75
        cols = []
        for i in range(9):
            a = math.radians(200.0 - 220.0 * i / 8.0)          # round the near side, from behind to the front
            r_top, r_bot = 0.08 * k_, 0.15 * k_
            x0, y0 = w[1][0] + r_top * math.cos(a), -abs(r_top * math.sin(a)) - 0.01
            x1, y1 = w[1][0] + r_bot * math.cos(a), -abs(r_bot * math.sin(a)) - 0.02
            rag = (0.04 * (i % 2) + 0.02 * (i % 3)) * (1.6 if ragged else 0.6)
            cols.append(((x0, y0, top_z), (x1, y1, max(hem_floor, top_z - drop - rag * k_))))
        span = drop + 0.08 * k_

        def weights(v):
            u = max(0.0, min(1.0, (top_z - v.z) / span))
            return {"waist": 1.0 - 0.7 * u, "cloth1": 0.5 * u, "cloth2": 0.2 * u}
        self.sheet_xy("skirt", cols, weights, rgb)
        mirrored = [((a[0], -a[1], a[2]), (b[0], -b[1], b[2])) for a, b in cols]
        self.sheet_xy("skirt_f", mirrored, weights, rgb, far=True)

    def hood(self, rgb, trim):
        k_ = self.tall
        self.e("hood", self.head_point(-0.15, 0.25, 0.0), (0.07 * k_, 0.08 * k_, 0.07 * k_), "chest", rgb, seg=8, rings=6)
        self.e("hood_lining", self.head_point(-0.05, 0.30, -0.02), (0.05 * k_, 0.075 * k_, 0.055 * k_), "chest", trim, seg=8, rings=6)

    # ---- the body ----
    def build(self):
        for name, head, tail, parent in skeleton.core(**self.proportions):
            self.bone(name, head, tail, parent)
        sh = self.sh
        f = self.form
        ch, dark = self.chitin, self.dark
        xc, T, hc, H, W = sh["xc"], sh["T"], sh["hc"], sh["th_h"], sh["th_w"]
        # the carapace: a low dome, broadest behind the middle, rising to the eyes at the front
        self.loft("carapace", [((xc - T * 1.0, 0, hc + 0.00), (H * 0.45, W * 0.55)), ((xc - T * 0.55, 0, hc + 0.02), (H * 1.0, W * 0.95)),
                               ((xc + T * 0.05, 0, hc + 0.03), (H * 1.15, W * 1.0)), ((xc + T * 0.6, 0, hc + 0.04), (H * 1.1, W * 0.85)),
                               ((xc + T * 1.0, 0, hc + 0.03), (H * 0.75, W * 0.6)), ((xc + T * 1.15, 0, hc + 0.02), (H * 0.4, W * 0.4))], "body", ch, "x", 8)
        self.e("sternum", (xc, 0.0, hc - H * 0.45), (T * 0.75, W * 0.7, H * 0.5), "body", dark, seg=8, rings=5)
        self.e("pedicel", sh["pedicel"][:1] + (0.0,) + sh["pedicel"][1:], (0.05 * self.th, 0.05 * self.th, 0.045 * self.th), "body", dark, seg=6, rings=4)
        # the abdomen: an egg carried up behind, its facets catching the light
        c = sh["a_centre"]
        self.tilted("abdomen", (c[0], 0.0, c[1]), (sh["ax"], sh["ay"], sh["az"]), -sh["a_dir"] - 90.0, "abdomen", ch)
        # a glossy highlight high on the near side, toward the light
        if self.form.get("gloss", True):
            g = self.painted_point(0.25, 0.62, out=1.03)
            self.e("gloss", (g[0], g[1] - 0.004, g[2]), (0.09 * self.ab, 0.012, 0.045 * self.ab), "abdomen", self.form.get("gloss_c", GLOSS), seg=8, rings=5)
        tip = self.abdomen_point(1.0, -0.05, 0.0, out=1.0)
        self.e("spinneret", tip, (0.035 * self.ab, 0.03 * self.ab, 0.03 * self.ab), "abdomen", dark, seg=6, rings=4)
        # the chelicerae and the palps
        fh, ft, _ = self.bones["fang"]
        if not self.proportions["drider"]:
            for s, y in (("n", -0.045), ("f", 0.045)):
                self.l("chel_" + s, (fh[0], y * self.th, fh[2] + 0.01), (ft[0], y * self.th, ft[2] + 0.02), 0.048 * self.th, 0.03 * self.th, "fang", ch, far=s == "f")
                self.blade("fang_" + s, (ft[0], y * self.th, ft[2] + 0.03), (ft[0] - 0.03 * self.th, y * self.th, ft[2] - 0.035 * self.th), 0.03 * self.th, 0.02, "fang", self.fang_c,
                           far=s == "f")
            for s in "nf":
                h, t, _ = self.bones["palp_" + s]
                self.l("palp_" + s, h, t, 0.022 * self.th, 0.016 * self.th, "palp_" + s, self.leg_c, far=s == "f")
                self.e("palp_tip_" + s, t, (0.022 * self.th,) * 3, "palp_" + s, self.leg_c, far=s == "f", seg=6, rings=4)
        # the legs: thin and tapering, arcing up to high knees, a ring of colour at each joint, the claw a fine point
        lw = self.lw
        for key in self.leg_keys:
            far = key[0] == "f"
            i = int(key[1])
            hf, tf, _ = self.bones["fem_" + key]
            ht, tt, _ = self.bones["tib_" + key]
            ha, ta, _ = self.bones["tar_" + key]
            col = self.leg_c
            self.e("coxa_" + key, hf, (0.04 * lw, 0.04 * lw, 0.035 * lw), "fem_" + key, col, far, seg=6, rings=4)
            self.l("fem_" + key, hf, tf, 0.040 * lw, 0.032 * lw, "fem_" + key, col, far)
            self.e("knee_" + key, tf, (0.036 * lw,) * 3, "fem_" + key, self.joint, far, seg=6, rings=5)
            self.l("tib_" + key, ht, tt, 0.031 * lw, 0.022 * lw, "tib_" + key, col, far)
            self.e("ankle_" + key, tt, (0.021 * lw,) * 3, "tib_" + key, self.joint if i < 2 else col, far, seg=6, rings=4)
            self.l("tar_" + key, ha, ta, 0.017 * lw, 0.005, "tar_" + key, self.leg_low or col, far, sides=5)
        if self.proportions["drider"]:
            self.upper_body()

    def upper_body(self):
        """A person's upper body rising from the front of the cephalothorax: hips merging into the carapace, a slim torso, a neck, a small head with
        hair hanging on its own bones, thin arms with hands."""
        k_ = self.tall
        f = self.form
        skin = self.skin
        bw = self.proportions["drider"].get("broad", 1.0)     # an oni is broader through the chest and the arms
        w, c, hd = self.bones["waist"], self.bones["chest"], self.bones["head"]
        self.loft("hips", [((w[0][0] - 0.01, 0, w[0][2] - 0.04), (0.085 * k_, 0.09 * k_)), ((w[0][0], 0, w[0][2] + 0.02), (0.07 * k_, 0.08 * k_)),
                           ((w[1][0], 0, w[1][2]), (0.052 * k_ * bw, 0.062 * k_ * bw))], "waist", skin, "z", 8)
        self.loft("torso", [((c[0][0], 0, c[0][2]), (0.052 * k_ * bw, 0.062 * k_ * bw)), ((c[0][0] + 0.3 * (c[1][0] - c[0][0]), 0, c[0][2] + 0.45 * (c[1][2] - c[0][2])), (0.060 * k_ * bw, 0.07 * k_ * bw)),
                            ((c[1][0] - 0.005, 0, c[1][2] - 0.03 * k_), (0.062 * k_ * bw, 0.082 * k_ * bw)), ((c[1][0], 0, c[1][2]), (0.03 * k_ * bw, 0.04 * k_ * bw))], "chest", skin, "z", 8)
        self.l("neck", hd[0], self.head_point(0.45, 0.25), 0.022 * k_, 0.02 * k_, "head", skin, sides=6)
        self.e("skull", self.head_point(0.45, 0.55), (0.062 * k_, 0.055 * k_, 0.07 * k_), "head", skin, seg=8, rings=6)
        self.blade("nose", self.head_point(0.92, 0.50, -0.01), self.head_point(1.05, 0.42, -0.01), 0.02 * k_, 0.012, "head", skin)
        self.e("eye_h", self.head_point(0.85, 0.58, -0.04), (0.008, 0.006, 0.008), "head", (30, 24, 34), seg=4, rings=3)
        # hair: a cap over the skull and a fall down the back on the hair bones
        hair = self.hair_c
        self.e("hair_cap", self.head_point(0.32, 0.70), (0.066 * k_, 0.058 * k_, 0.062 * k_), "head", hair, seg=8, rings=6)
        for b, r0, r1 in (("hair1", 0.045, 0.040), ("hair2", 0.040, 0.012)):
            h, t, _ = self.bones[b]
            self.l(b, h, t, r0 * k_ * f.get("drider", {}).get("hair", 1.0) ** 0.3, r1 * k_, b, hair, sides=6)
        for s in "nf":
            far = s == "f"
            a, fo = self.bones["arm_" + s], self.bones["fore_" + s]
            self.e("shoulder_" + s, a[0], (0.028 * k_ * bw,) * 3, "arm_" + s, skin, far, seg=6, rings=4)
            self.l("arm_" + s, a[0], a[1], 0.022 * k_ * bw, 0.018 * k_ * bw, "arm_" + s, skin, far)
            self.l("fore_" + s, fo[0], fo[1], 0.018 * k_ * bw, 0.014 * k_ * bw, "fore_" + s, skin, far)
            self.e("hand_" + s, fo[1], (0.02 * k_, 0.016 * k_, 0.022 * k_), "fore_" + s, skin, far, seg=6, rings=4)


class _Std:
    def __init__(self, x, y, z):
        self.x, self.y, self.z = x, y, z
