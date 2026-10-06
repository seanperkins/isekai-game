"""The goblin tree: the base goblin and its 28 forms on one skeleton (goblin_kit.py), dressed from a table (goblin_forms.py) with gear
(goblin_gear.py). A rider's mount is the wolf kit. Every form gets idle, walk and attack; the pose of its arms, its stance and the angle of
whatever it holds come from small presets, so a new form is a few lines of data, not new animation.

Each form is sized so the still covers the same area (width times height) as the still its sheet frame has today (assets/sheets/forms_goblin.json), so
the game's size ladder is kept while the proportions are the form's own.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import goblin_forms as forms  # noqa: E402
import goblin_gear as gear  # noqa: E402
import goblin_kit as kit  # noqa: E402
import rigkit as k  # noqa: E402
from creatures import wolf  # noqa: E402
from goblin_kit import down, up  # noqa: E402

NAME = "goblin"
MARGIN = 3
PAD = 4
RIDER_SCALE = 1.0

# (near upper arm, near forearm, far upper arm, far forearm, how much it still swings), degrees; see goblin_kit.down
ARMS = {
    "free": (10, 34, 6, 20, 1.0),
    "guard": (24, 82, 24, 82, 0.15),          # both hands close to the chest
    "guard_n": (24, 82, 4, 24, 0.15),         # the near hand up, the other at the side
    "fists": (20, 70, 20, 70, 0.1),
    "offer": (48, 8, 40, 16, 0.2),            # arms out in front, giving
    "offer_up": (62, 30, 6, 24, 0.2),         # the near hand held up and out
    "carry": (38, 46, 12, 30, 0.3),
    "play": (76, 98, 76, 98, 0.0),            # both hands at the mouth
    "cradle": (36, 78, 44, 92, 0.0),          # an instrument held in the crook of an arm
    "raise_n": (150, 24, 8, 28, 0.2),         # the near arm high
    "raise_f": (22, 40, 150, 24, 0.2),        # the far arm high
    "lantern": (20, 30, 70, 30, 0.2),         # a lantern low, the other hand beckoning
    "shield": (40, 70, 36, 50, 0.15),
    "sword": (60, 50, 8, 24, 0.2),            # a blade over the shoulder
}
# extra degrees on named bones: the way a form stands
STANCES = {
    "hunch": {"spine": up(16), "head": up(-8), "thigh_n": down(12), "thigh_f": down(12), "shin_n": down(-24), "shin_f": down(-24), "foot_n": down(12), "foot_f": down(12)},
    "wide": {"thigh_n": down(16), "thigh_f": down(-16), "shin_n": down(-8), "shin_f": down(-8), "foot_n": down(-8), "foot_f": down(8)},
    "stomp": {"thigh_f": down(55), "shin_f": down(-70), "foot_f": down(20), "spine": up(6)},
    "hop": {"thigh_f": down(60), "shin_f": down(-80), "foot_f": down(20), "spine": up(-4)},
    "dance": {"thigh_n": down(-6), "thigh_f": down(50), "shin_f": down(-70), "foot_f": down(20), "spine": up(-6)},
    "tiptoe": {"foot_n": down(-32), "foot_f": down(-32), "thigh_n": down(4), "thigh_f": down(4), "shin_n": down(2), "shin_f": down(2)},
    "listen": {"head": (0.0, 14.0, 0.0), "spine": up(-3)},
    "ride": {"thigh_n": down(84), "thigh_f": down(84), "shin_n": down(-88), "shin_f": down(-88), "foot_n": down(6), "foot_f": down(6), "spine": up(2)},
}
ATTACK = {  # per frame: windup, windup peak, swing, impact, follow through, recover: the near arm and the spine
    "arm_n": [0, -100, -150, -10, 55, 20], "fore_n": [34, 40, 50, 30, 10, 25], "spine": [4, -6, -10, 8, 16, 6], "head": [-2, 4, 6, -4, -8, -2],
    "thigh_n": [8, -6, -10, 12, 22, 8], "shin_n": [-16, 6, 10, -16, -30, -16], "foot_n": [8, 0, 0, 4, 8, 8],
    "thigh_f": [8, 10, 12, 8, 0, 8], "shin_f": [-16, -18, -20, -14, -4, -16], "foot_f": [8, 8, 8, 6, 4, 8],
}
ITEM_SWING = [0, 50, 80, -30, -70, -10]  # the held thing, degrees clockwise from where it was made
COUNTS = {"idle": 6, "walk": 8, "attack": 6}


def _form(variant):
    return forms.FORMS[variant or "goblin"]


def build(variant=None):
    form = _form(variant)
    rig = k.Rig("goblin_" + (variant or "goblin"))
    scale, origin, mount = 1.0, (0.0, 0.0, 0.0), form.get("ride") and form["mount"]
    if mount:
        ws = mount["scale"]
        wolf.build_into(rig, "w_", ws, (0, 0, 0), fur=mount["fur"], belly=mount["belly"], barding=mount.get("barding"))
        scale = RIDER_SCALE
        seat = 0.78 * ws - 0.06
        origin = (0.02 * ws, 0.0, seat - 0.80 * form.get("tall", 1.0) * scale)
    g = kit.Goblin(rig, form, "", scale, origin)
    if mount:
        g.root_parent = "w_spine"
    g.build()
    for name, kw in form["gear"]:
        gear.GEAR[name](g, **kw)
    rig.build()
    return rig


# ---- poses ----
def _add(rot, bone, delta):
    cur = rot.get(bone, (0.0, 0.0, 0.0))
    rot[bone] = (cur[0] + delta[0], cur[1] + delta[1], cur[2] + delta[2])


def _legs_walk(rot, p):
    s, c = math.sin(p), math.cos(p)
    flex_n, flex_f = 55 * max(0.0, c), 55 * max(0.0, -c)
    thigh_n, thigh_f = 34 * s, -34 * s
    rot.update({"thigh_n": down(thigh_n), "shin_n": down(-flex_n), "foot_n": down(-0.7 * (thigh_n - flex_n)),
                "thigh_f": down(thigh_f), "shin_f": down(-flex_f), "foot_f": down(-0.7 * (thigh_f - flex_f))})


def _legs_idle(rot, p):
    bend = 7 + 2 * math.sin(p)
    rot.update({"thigh_n": down(bend), "shin_n": down(-2 * bend), "foot_n": down(bend),
                "thigh_f": down(bend), "shin_f": down(-2 * bend), "foot_f": down(bend)})


def goblin_pose(form, anim, i, n):
    """The goblin's own bones for frame i of an animation, with no prefix."""
    p = i / n * 2 * math.pi
    s = math.sin(p)
    rot = {}
    a = ARMS[form.get("arms", "free")]
    if anim == "walk":
        _legs_walk(rot, p)
        lean = 6 + 2 * math.sin(2 * p)
        rot["spine"], rot["head"] = up(lean), up(-lean * 0.7 + 2 * math.cos(2 * p))
        sway = 20 * s
    elif anim == "idle":
        _legs_idle(rot, p)
        rot["spine"], rot["head"] = up(4 + 1.5 * s), up(-2 - 1.5 * s)
        sway = 4 * s
    else:  # attack
        for bone, track in ATTACK.items():
            rot[bone] = up(track[i]) if bone in ("spine", "head") else down(track[i])
        sway = 0.0
    rot["arm_n"], rot["fore_n"] = down(a[0] - a[4] * sway), down(a[1])
    rot["arm_f"], rot["fore_f"] = down(a[2] + a[4] * sway), down(a[3])
    if anim == "attack":  # the near arm swings whatever it holds
        rot["arm_n"], rot["fore_n"] = down(a[0] + ATTACK["arm_n"][i] * 0.7), down(a[1] + (ATTACK["fore_n"][i] - 34) * 0.5)
    stance = form.get("stance")
    if form.get("ride"):
        rot.update({b: (0.0, 0.0, 0.0) for b in ("thigh_n", "thigh_f", "shin_n", "shin_f", "foot_n", "foot_f")})
        stance = "ride"
    if stance:
        for bone, delta in STANCES[stance].items():
            _add(rot, bone, delta)
    return rot


def _hold_items(form, rot, anim, i):
    """Keep whatever the goblin holds at the angle it was made at (or swinging, in an attack), whatever the arms do: the item bone cancels
    the rotation of the bones above it."""
    for s in "nf":
        chain = ["hips", "spine", "arm_" + s, "fore_" + s]
        if form.get("ride"):
            chain = ["w_hips", "w_spine"] + chain
        above = sum(rot.get(b, (0.0, 0.0, 0.0))[1] for b in chain)
        want = ITEM_SWING[i] if (anim == "attack" and s == "n") else form.get("item_angle", {}).get(s, 0.0)
        rot["item_" + s] = (0.0, want - above, 0.0)


def make(form, anim):
    def fn(i, n):
        rot, root = {}, (0.0, 0.0, 0.0)
        if form.get("ride"):
            wolf_fn = {"idle": wolf.idle, "walk": wolf.walk, "attack": wolf.pounce}[anim]
            rot, root = wolf_fn(i, n, "w_")
            root = (root[0], root[1], root[2] * form["mount"]["scale"])
        rot = dict(rot)
        rot.update(goblin_pose(form, anim, i, n))
        _hold_items(form, rot, anim, i)
        return rot, root
    return COUNTS[anim], fn, True


def today(variant):
    """(width, height) in game pixels of the still the game had for this form before the 3D pass (tools/art/blender/before/), so a re-render
    sizes the same whatever the live sheet holds; the base goblin uses its idle frame."""
    if variant and variant != "goblin":
        path, name = os.path.join(HERE, "before", "forms_goblin.json"), variant
    else:
        path, name = os.path.join(HERE, "..", "..", "..", "assets", "sheets", "goblin.json"), "idle_1"
    try:
        with open(path) as fh:
            rect = json.load(fh)["frames"][name]["rect"]
        return float(rect[2]), float(rect[3])
    except (OSError, KeyError):  # nothing to match: fall back to the width in the table
        return float(_form(variant)["width"]), None


def setup(rig, variant):
    """Size the camera for this form: the still covers the area of today's still, and the canvas holds every frame."""
    form = _form(variant)
    anims = {name: make(form, name) for name in COUNTS}
    count, fn, _ = anims["idle"]
    rig.stand(*fn(0, count))
    x0, x1, z0, z1 = rig.extent()
    w, h = today(variant)
    ppu = math.sqrt(w * h / ((x1 - x0) * (z1 - z0))) if h else w / (x1 - x0)
    lo_x, hi_x, hi_z = 1e9, -1e9, 0.0
    for name, (count, fn, _) in anims.items():
        for i in range(count):
            rig.stand(*fn(i, count))
            a, b, _, top = rig.extent()
            lo_x, hi_x, hi_z = min(lo_x, a), max(hi_x, b), max(hi_z, top)
    need = max((hi_x - lo_x) * ppu + 2 * PAD, hi_z * ppu + MARGIN + PAD)
    canvas = int(math.ceil(need / 8.0) * 8)
    still = form.get("still", "idle_0")
    return {"canvas": canvas, "ppu": ppu, "margin": MARGIN, "center_x": (lo_x + hi_x) / 2.0, "anims": anims, "still": still}
