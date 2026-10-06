"""How the undead move: what biped_motion cannot do for them. Pure Python (no Blender), tested in test_undead_motion.py; creatures/undead.py feeds
it the measured feet and renders what it makes.

A two-legged undead is a biped_motion.Body with a posture of its own (POSTURES: a skeleton stands upright with a slight lean and long legs, a zombie
hunches, a giant stands wide), so idle, walk, run, hurt and die are the biped's. This module adds:

  * the attacks the undead need, each built on the biped's (its channels, its planted feet, its rest pose at both ends): an overhead slash with a
    blade held point down, a two-handed cleave, a maul with both arms, a slam into the ground, a rake of claws, a cast, an underhand scatter, a
    lantern swung up, a bite, a spear thrust behind a shield, a whip crack (the lash rolls out a segment at a time), a bow drawn to the cheek and
    loosed, and a jiangshi's hop forward with its arms out. A form's `weight` picks the timing: "heavy" holds the apex longer, swings quicker and
    settles deeper; the windup always lasts the engine's 0.35 s and the recovery its 0.30 s.
  * the jiangshi's gait: it hops with its feet together and its knees all but locked (both feet on anim.foot_pose at the same phase, so a planted
    foot does not slide; the body and both feet rise together through the air).
  * the floaters (a corpse candle, a banshee, a demilich): no legs; they hover with a bob and a sway and drift forward leaning into it, their
    flame, hair and shroud trailing.
  * the follow-through of the undead's hung things (SECONDARY): a skeleton's jaw and loose rags rattle, bandage ends trail, a lantern swings.

Angles are degrees from straight down, forward positive (skeleton2d.py); lengths are fractions of the leg's length L (a floater's of its height).
"""
import math

import anim
import biped_motion as bm
import secondary
from limbs import aim, down

REST = bm.REST
ENGINE_WINDUP, ENGINE_RECOVER, ENGINE_HURT = bm.ENGINE_WINDUP, bm.ENGINE_RECOVER, bm.ENGINE_HURT

# ---- postures -------------------------------------------------------------------------------------------------------------------
# How each kind of undead carries itself (see biped_motion.POSTURES). Upright bodies stand on nearly straight legs, so their gaits bend the knee
# more than they stand with and their longest stride is shorter than a goblin's: the leg has to reach the rear foot at toe-off.
_UPRIGHT_WALK = dict(crouch=0.88, bob=0.028, lift=0.12, lean=12.0, lean_amp=1.4, head=8.0, swing=20.0, stride_legs=0.75, max_stride=0.85, cycle=(0.45, 1.0))
_UPRIGHT_RUN = dict(crouch=0.78, bob=-0.050, lift=0.24, lean=24.0, lean_amp=2.2, head=12.0, swing=36.0, stride_legs=0.95, max_stride=1.0, cycle=(0.24, 0.6))


def _posture(crouch, stance_half, lean, head_lean, recoil, walk=None, run=None):
    return dict(crouch=crouch, stance_half=stance_half, lean=lean, head_lean=head_lean, recoil=recoil,
                gaits={"walk": dict(_UPRIGHT_WALK, **(walk or {})), "run": dict(_UPRIGHT_RUN, **(run or {}))})


POSTURES = {
    # a plain skeleton: upright on long legs, a faint forward hunch
    "bones": _posture(0.91, 0.20, 9.0, 6.0, 1.0),
    "alert": _posture(0.90, 0.21, 6.0, 2.0, 1.0, walk=dict(lean=10.0), run=dict(lean=22.0)),
    "stride": _posture(0.92, 0.22, 4.0, 0.0, 0.9, walk=dict(lean=8.0, swing=16.0), run=dict(lean=18.0)),
    "braced": _posture(0.86, 0.24, 10.0, 4.0, 0.9, walk=dict(crouch=0.82, swing=12.0), run=dict(crouch=0.76)),
    "knight": _posture(0.90, 0.22, 5.0, 2.0, 0.8, walk=dict(lean=8.0, swing=10.0, bob=0.035, lift=0.10), run=dict(lean=18.0, swing=22.0)),
    "hoplite": _posture(0.85, 0.27, 14.0, 4.0, 0.9, walk=dict(crouch=0.80, lean=16.0, swing=6.0), run=dict(lean=24.0, swing=12.0)),
    "regal": _posture(0.94, 0.16, 3.0, 0.0, 0.85, walk=dict(lean=6.0, swing=10.0, bob=0.02, lift=0.10, stride_legs=0.7), run=dict(lean=16.0, swing=22.0)),
    "still": _posture(0.95, 0.12, 1.0, -2.0, 0.7, walk=dict(lean=4.0, swing=6.0, bob=0.015, lift=0.09, stride_legs=0.65), run=dict(lean=14.0, swing=16.0)),
    "mummy": _posture(0.92, 0.16, 6.0, 2.0, 0.9, walk=dict(lean=8.0, swing=6.0, lift=0.09, stride_legs=0.65), run=dict(lean=18.0, swing=14.0)),
    "dancer": _posture(0.93, 0.14, 0.0, -6.0, 0.9, walk=dict(lean=4.0, swing=18.0, bob=0.04, lift=0.18), run=dict(lean=14.0)),
    "wanderer": _posture(0.88, 0.18, 16.0, 10.0, 1.05, walk=dict(lean=18.0, head=10.0, swing=10.0), run=dict(lean=28.0)),
    # a zombie lurches: hunched, short dragging steps with a heavy rise and fall, the body pitching over each step; a blow throws it about
    "shamble": _posture(0.86, 0.22, 22.0, 12.0, 1.35, walk=dict(duty=0.66, crouch=0.80, bob=0.055, lift=0.06, lean=24.0, lean_amp=5.0, head=12.0, swing=6.0, stride_legs=0.55,
                                                            max_stride=0.7, cycle=(0.7, 1.3)),
                        run=dict(duty=0.48, crouch=0.76, bob=-0.06, lift=0.14, lean=32.0, lean_amp=5.0, swing=14.0, max_stride=0.9, cycle=(0.4, 0.8))),
    # a ghoul is hunched and quick: chest well forward, head thrust ahead, a low fast scuttle
    "ghoul": _posture(0.80, 0.22, 34.0, 18.0, 1.1, walk=dict(crouch=0.76, lean=38.0, head=18.0, lift=0.16, swing=16.0, stride_legs=0.85, max_stride=1.0, cycle=(0.3, 0.7)),
                      run=dict(crouch=0.70, lean=52.0, head=26.0, lift=0.30, swing=30.0, stride_legs=1.1, max_stride=1.12, cycle=(0.2, 0.5))),
    # big and heavy: wide feet, a slow rolling walk with a deep rise and fall, a blow rocks it hard
    "heavy": _posture(0.86, 0.26, 16.0, 8.0, 1.25, walk=dict(duty=0.65, crouch=0.80, bob=0.05, lift=0.08, lean=20.0, lean_amp=3.5, head=8.0, swing=8.0, stride_legs=0.6,
                                                          max_stride=0.75, cycle=(0.8, 1.4)),
                      run=dict(duty=0.48, crouch=0.76, lean=28.0, lean_amp=4.0, swing=14.0, max_stride=0.9, cycle=(0.45, 0.8))),
    # a giant: barely bends, swings its legs like pendulums, sinks into each step; a blow hardly moves it
    "giant": _posture(0.87, 0.28, 16.0, 4.0, 0.6, walk=dict(duty=0.66, crouch=0.81, bob=0.06, lift=0.07, lean=18.0, lean_amp=2.5, head=4.0, swing=6.0, stride_legs=0.55,
                                                         max_stride=0.7, cycle=(0.9, 1.6)),
                      run=dict(duty=0.5, crouch=0.77, bob=-0.05, lift=0.12, lean=24.0, swing=10.0, max_stride=0.85, cycle=(0.5, 0.9))),
    # a jiangshi stands stiff with its feet together; it gets about by hopping (HOPS)
    "hop": _posture(0.95, 0.03, 2.0, 0.0, 0.7),
}

# the hop: a stance and a flight per cycle, both feet together. `duty` the part of the cycle the feet are down, `dip` how far the knees give on landing
# (of L), `height` how high the body rises (of L), `tuck` how far the feet are drawn up in the air, `lean` the body's tip forward
HOPS = {
    "walk": dict(duty=0.50, crouch=0.90, dip=0.06, height=0.16, tuck=0.06, lean=4.0, stride_legs=0.4, max_stride=0.5, cycle=(0.45, 0.8), lift=0.0, frames=10),
    "run": dict(duty=0.40, crouch=0.88, dip=0.08, height=0.26, tuck=0.10, lean=10.0, stride_legs=0.5, max_stride=0.6, cycle=(0.35, 0.7), lift=0.0, frames=10),
}

# the hung things the undead have beyond the goblin's (biped_motion.SECONDARY); a skeleton's jaw is a quick, loose spring, so it chatters
SECONDARY = dict(bm.SECONDARY, **{
    "jaw": dict(parents=["hips", "spine", "head"], bob=360.0, wind=0.0, freq=7.0, zeta=0.22),
    "rag": dict(parents=["hips"], bob=240.0, wind=-10.0, freq=3.2, zeta=0.35),
    "rag_b": dict(parents=["hips"], bob=240.0, wind=-16.0, freq=3.0, zeta=0.35),
    "band1": dict(parents=["hips", "spine"], bob=200.0, wind=-18.0, freq=2.6, zeta=0.35),
    "band2": dict(after="band1", bob=260.0, wind=-26.0, freq=2.0, zeta=0.3),
    "band_h": dict(parents=["hips", "spine", "arm_n", "fore_n"], bob=200.0, wind=-14.0, freq=2.4, zeta=0.35),
    "talisman": dict(parents=["hips", "spine", "head"], bob=300.0, wind=-14.0, freq=3.4, zeta=0.3),
    "lantern_hang": dict(parents=["hips", "spine", "arm_n", "fore_n", "item_n"], bob=260.0, wind=-6.0, freq=2.2, zeta=0.28),
    "chain1": dict(parents=["hips"], bob=260.0, wind=-6.0, freq=2.8, zeta=0.3),
    "chain2": dict(after="chain1", bob=300.0, wind=-8.0, freq=2.2, zeta=0.3),
    "strip0": dict(parents=["hips", "spine"], bob=160.0, wind=-20.0, freq=2.4, zeta=0.4),
    "strip1": dict(parents=["hips", "spine"], bob=180.0, wind=-26.0, freq=2.2, zeta=0.4),
    "strip2": dict(parents=["hips", "spine"], bob=200.0, wind=-32.0, freq=2.0, zeta=0.4),
    "held_head": dict(parents=["hips", "spine", "arm_f"], bob=80.0, wind=0.0, freq=4.0, zeta=0.6),
    "whip1": dict(parents=["hips", "spine", "arm_n", "fore_n", "item_n"], bob=200.0, wind=-6.0, freq=2.6, zeta=0.3),
    "whip2": dict(after="whip1", bob=240.0, wind=-8.0, freq=2.2, zeta=0.3),
    "whip3": dict(after="whip2", bob=260.0, wind=-10.0, freq=1.9, zeta=0.3),
    "whip4": dict(after="whip3", bob=280.0, wind=-12.0, freq=1.7, zeta=0.3),
    "whip5": dict(after="whip4", bob=300.0, wind=-14.0, freq=1.5, zeta=0.3),
    # a floater's flame, hair and shroud
    "tip1": dict(parents=["hips", "spine"], bob=260.0, wind=-12.0, freq=3.0, zeta=0.35),
    "tip2": dict(after="tip1", bob=300.0, wind=-16.0, freq=2.4, zeta=0.3),
    "hair1": dict(parents=["hips", "spine", "head"], bob=160.0, wind=-7.0, freq=2.2, zeta=0.4),
    "hair2": dict(after="hair1", bob=180.0, wind=-9.0, freq=1.8, zeta=0.35),
    "strip0a": dict(parents=["hips"], bob=140.0, wind=-5.0, freq=2.2, zeta=0.35),
    "strip0b": dict(after="strip0a", bob=160.0, wind=-7.0, freq=1.8, zeta=0.3),
    "strip1a": dict(parents=["hips"], bob=140.0, wind=-6.0, freq=2.0, zeta=0.35),
    "strip1b": dict(after="strip1a", bob=160.0, wind=-9.0, freq=1.7, zeta=0.3),
    "strip2a": dict(parents=["hips"], bob=140.0, wind=-7.0, freq=1.9, zeta=0.35),
    "strip2b": dict(after="strip2a", bob=160.0, wind=-11.0, freq=1.6, zeta=0.3),
})
WHIP = ["whip%d" % i for i in range(1, 6)]


# ---- bodies ---------------------------------------------------------------------------------------------------------------------
def biped_body(skel, feet, form, present=None):
    """A two-legged undead: biped_motion's Body with the form's posture, and the hop's gaits for a jiangshi."""
    body = bm.Body(skel, feet, form, present, posture=POSTURES[form.get("posture", "bones")])
    if form.get("body") == "hop":
        body.gaits.update({"hop_" + k: dict(v) for k, v in HOPS.items()})
    return body


class FloatBody:
    """What the motion needs to know about a floater: its flat skeleton, its form, the bones its rig has and `low`, how far below the root's rest
    height the lowest point of its meshes is (measured in Blender), so it can be held a set height off the ground."""
    def __init__(self, skel, form, low, present=None):
        self.skel, self.form, self.low = skel, form, low
        self.present = set(present) if present is not None else set(skel.rest)
        self.root = skel.order[0]
        pts = [p for h, t, _ in skel.rest.values() for p in (h, t)]
        self.size = max(p[1] for p in pts) - min(p[1] for p in pts)
        self.L = self.size
        self.hover = {"candle": 0.20, "ghost": 0.12, "skull": 0.42}.get(form.get("body"), 0.16) * self.size
        self.bob = 0.035 * self.size


# ---- secondary ------------------------------------------------------------------------------------------------------------------
def _with_secondary(body, frames, durations, wind, periodic, skip=()):
    """Every hung thing's follow-through (SECONDARY) for a clip of (rot, root, extra) frames, then the extras on top: `extra["jaw"]` opens the jaw
    that many degrees beyond where it rattles to. Bones in `skip` are posed by the clip itself (a whip in its crack)."""
    table = {k: v for k, v in SECONDARY.items() if k not in skip and not (v.get("after") in skip)}
    plain = [(rot, root) for rot, root, _ in frames]
    out = secondary.series(body.present, table, plain, wind, durations, periodic=periodic)
    result = []
    for i, (rot, root, extra) in enumerate(frames):
        for bone, series in out.items():
            rot[bone] = down(series[i])
        if extra.get("jaw") and "jaw" in body.present:
            j = rot.get("jaw", (0.0, 0.0, 0.0))
            rot["jaw"] = (0.0, j[1] + extra["jaw"], 0.0)
        result.append((rot, root))
    return result


class Clip(bm.Clip):
    pass


# ---- attacks --------------------------------------------------------------------------------------------------------------------
# The frames of an attack by weight: [(start second, how long)], how many are the windup, and the key times of the channels (the windup reached,
# held until, the middle of the swing, the impact, the follow-through, the rest pose). A heavy blow holds its apex longer, swings in two quick frames
# and holds the impact; both add up to the engine's windup and recover.
TIMINGS = {
    "normal": dict(frames=bm.ATTACK_FRAMES, windup=bm.ATTACK_WINDUP, t=(0.12, 0.27, 0.31, 0.35, 0.48, 0.59)),
    "heavy": dict(frames=[(0.00, 0.04), (0.04, 0.06), (0.10, 0.20), (0.30, 0.02), (0.32, 0.03), (0.35, 0.12), (0.47, 0.06), (0.53, 0.06), (0.59, 0.06)],
                  windup=5, t=(0.10, 0.30, 0.32, 0.35, 0.47, 0.59)),
}
CREEP = 0.08   # a held windup keeps pulling back a little (a moving hold), this much of the way from the swing


def _keys(times, windup, mid, hit, follow, start=REST, end=REST, creep=CREEP):
    tw, th, tm, tt, tf, te = times
    held = windup + creep * (windup - mid)
    return [(0.0, start, "out"), (tw, windup, "smooth"), (th, held, "in"), (tm, mid, "linear"), (tt, hit, "out"), (tf, follow, "smooth"), (te, end, "smooth")]


# Each kind: channels as (windup, mid-swing, impact, follow-through). d_lean, d_head: degrees tipped forward beyond the rest; px, pz: the pelvis (of L);
# arm_*, fore_*: world directions; item_n / item_f: the tilt of what is held (180 minus its direction, as biped_motion); d_item_*: the same, added to its
# rest tilt; jaw: degrees open; step_*, lift_*: a foot moved forward and lifted (of L). Channels a kind leaves out stay at rest.
KINDS = {
    # a blade held point down: raised up and back over the shoulder, then brought over the top and down in front (the blade turns a full circle)
    "slash": dict(d_lean=(-14, 4, 18, 20), d_head=(-8, 2, 12, 14), px=(-0.07, 0.04, 0.16, 0.17), pz=(-0.06, -0.06, -0.09, -0.06),
                  arm_n=(200, 150, 62, 40), fore_n=(225, 160, 72, 50), d_item_n=(150, 200, 280, 300, 360), arm_f=(50, 20, -20, -10), fore_f=(90, 60, 20, 20), step=0.2),
    # an overhead blow with something held upright (biped_motion's chop)
    "chop": dict(d_lean=(-16, 0, 16, 20), d_head=(-8, 2, 14, 16), px=(-0.07, 0.04, 0.16, 0.17), pz=(-0.07, -0.07, -0.08, -0.05),
                 arm_n=(205, 120, 48, 28), fore_n=(235, 140, 70, 45), item_n=(-70, 25, 100, 115), arm_f=(60, 20, -20, -10), fore_f=(100, 60, 20, 20), step=0.2),
    # a great blade in both hands: the whole body goes back, then over and down into the ground in front, and settles deep
    "cleave": dict(d_lean=(-20, 2, 24, 28), d_head=(-10, 2, 16, 18), px=(-0.08, 0.04, 0.17, 0.18), pz=(-0.08, -0.08, -0.14, -0.10),
                   arm_n=(200, 125, 52, 36), fore_n=(222, 140, 64, 46), item_n=(-62, 30, 104, 112), arm_f=(192, 118, 46, 32), fore_f=(214, 134, 60, 42), step=0.24),
    # both arms clubbed down from overhead, the chest thrown after them
    "maul": dict(d_lean=(-18, 0, 26, 30), d_head=(-12, 0, 16, 20), px=(-0.06, 0.04, 0.14, 0.16), pz=(-0.05, -0.06, -0.13, -0.10),
                 arm_n=(186, 140, 70, 50), fore_n=(196, 140, 58, 40), arm_f=(176, 130, 62, 44), fore_f=(186, 130, 52, 36), step=0.22),
    # both fists raised high and slammed into the ground in front
    "slam": dict(d_lean=(-16, 10, 44, 44), d_head=(-10, 4, 22, 24), px=(-0.05, 0.04, 0.12, 0.13), pz=(-0.04, -0.06, -0.20, -0.15),
                 arm_n=(184, 130, 30, 30), fore_n=(194, 120, 20, 22), arm_f=(178, 124, 28, 28), fore_f=(188, 116, 18, 20), step=0.16),
    # claws raked from behind the hip up and across, the other hand following (biped_motion's swipe, with both hands)
    "swipe": dict(d_lean=(-12, 2, 14, 16), d_head=(-6, 2, 12, 14), px=(-0.06, 0.04, 0.15, 0.16), pz=(-0.06, -0.07, -0.08, -0.05),
                  arm_n=(-65, 35, 88, 110), fore_n=(-25, 65, 98, 105), arm_f=(-30, -10, 60, 96), fore_f=(-5, 20, 80, 100), step=0.22),
    # a spell: the hand and the focus raised, then thrown forward with the chest behind it (biped_motion's cast)
    "cast": dict(d_lean=(-14, 2, 10, 8), d_head=(-6, 4, 10, 10), px=(-0.05, 0.02, 0.07, 0.07), pz=(-0.05, -0.06, -0.06, -0.04), jaw=(10, 14, 22, 12),
                 arm_n=(150, 100, 74, 64), fore_n=(175, 112, 70, 60), d_item_n=(0, 0, 0, 0), arm_f=(120, 80, 95, 85), fore_f=(150, 100, 100, 90), step=0.0, lift=0.0, heel=-10.0),
    # an underhand scatter (seed or teeth): the hand swept back low, then flung forward and up, open
    "throw": dict(d_lean=(-10, 4, 14, 16), d_head=(-6, 2, 10, 12), px=(-0.07, 0.03, 0.14, 0.15), pz=(-0.07, -0.06, -0.07, -0.05),
                  arm_n=(-50, 40, 112, 122), fore_n=(-30, 70, 142, 150), arm_f=(60, 30, -10, -10), fore_f=(90, 60, 20, 20), step=0.22),
    # a lantern swung back low, then up and out in front
    "lantern": dict(d_lean=(-10, 4, 14, 16), d_head=(-6, 2, 10, 10), px=(-0.06, 0.03, 0.13, 0.14), pz=(-0.05, -0.05, -0.07, -0.05), jaw=(0, 8, 16, 10),
                    arm_n=(-40, 40, 100, 108), fore_n=(-20, 60, 118, 122), arm_f=(30, 20, 0, 0), fore_f=(80, 70, 60, 60), step=0.18),
    # the head drawn back with the jaws open, then snapped forward and shut
    "bite": dict(d_lean=(-16, 8, 26, 28), d_head=(-26, 10, 32, 30), px=(-0.08, 0.06, 0.18, 0.18), pz=(-0.05, -0.05, -0.08, -0.05), jaw=(38, 42, 0, 6),
                 arm_f=(30, -10, -30, -20), fore_f=(40, 0, -20, -10), step=0.22),
    # a spear driven forward over a shield: the shield stays up, the far hand draws the spear back level and thrusts it
    "spear": dict(d_lean=(-6, 6, 16, 14), d_head=(-2, 4, 8, 8), px=(-0.08, 0.05, 0.19, 0.18), pz=(-0.08, -0.08, -0.10, -0.07),
                  arm_n=(46, 54, 62, 58), fore_n=(112, 104, 96, 98), arm_f=(-80, 10, 84, 76), fore_f=(96, 92, 90, 88), item_f=(92, 90, 88, 90), step=0.26, lift=0.12),
    # a whip: the arm up and back, then cut down; the lash follows a segment at a time and cracks out level in front (WHIP_KEYS)
    "whip": dict(d_lean=(-12, 4, 16, 18), d_head=(-6, 2, 10, 12), px=(-0.06, 0.04, 0.14, 0.15), pz=(-0.05, -0.05, -0.08, -0.05),
                 arm_n=(200, 150, 80, 60), fore_n=(222, 150, 72, 52), arm_f=(40, 30, 10, 10), fore_f=(80, 70, 60, 60), step=0.2),
    # a jiangshi's lunge: a little hop forward with both arms driven out, then a hop back
    "hop_claw": dict(d_lean=(-6, 8, 14, 12), d_head=(-4, 4, 8, 8), px=(0.0, 0.0, 0.0, 0.0), pz=(-0.08, 0.06, -0.06, -0.03),
                     arm_n=(70, 96, 100, 96), fore_n=(60, 100, 104, 98), arm_f=(66, 94, 98, 94), fore_f=(58, 98, 102, 96), both_feet=True, step=0.30, lift=0.14),
}
# a whip's lash: each segment's world direction over time, the segment k behind the handle that much later (a wave running down it): it hangs, is
# dragged back and up behind as the arm comes forward, rolls over the top and cracks out level in front, then falls
WHIP_KEYS = [(0.0, REST, "smooth"), (0.12, -40.0, "smooth"), (0.27, -60.0, "in"), (0.30, -170.0, "linear"), (0.33, -268.0, "out"), (0.40, -280.0, "smooth"),
             (0.48, -330.0, "smooth"), (0.53, -355.0, "smooth")]
WHIP_DELAY = 0.005


def attack_kind(form):
    return form.get("attack") or bm.attack_kind(form)


def attack_frames(body):
    """[(start second, duration)] of the attack's frames and how many of them are the windup."""
    timing = TIMINGS[body.form.get("weight", "normal")]
    return timing["frames"], timing["windup"]


def _rest(body):
    rest = bm._rest_channels(body)
    rot, _ = bm.idle_pose(body, 0.0)
    rest["item_f"] = 180.0 - bm.direction_of(body, rot, "item_f")
    return rest


def _channels(body, time):
    kind = KINDS[attack_kind(body.form)]
    times = TIMINGS[body.form.get("weight", "normal")]["t"]
    tw, th, tm, tt, tf, te = times
    rest = _rest(body)
    ch = {}
    for name, v in kind.items():
        if not isinstance(v, tuple):
            continue
        if name.startswith("d_item_"):
            bone = name[2:]
            end = rest[bone] + (v[4] if len(v) > 4 else 0.0)
            keys = _keys(times, *[rest[bone] + x for x in v[:4]], start=rest[bone], end=end)
            ch[bone] = anim.sample(keys, time)
        elif name in ("d_lean", "d_head", "px", "pz", "jaw"):
            ch[name] = anim.sample(_keys(times, *v, start=0.0, end=0.0), time)
        else:
            ch[name] = anim.sample([(t, rest.get(name, 0.0) if x == REST else x, e) for t, x, e in _keys(times, *v)], time)
    step, lift, heel = kind.get("step", 0.2), kind.get("lift", 0.10), kind.get("heel", -24.0)
    ch["step"] = anim.sample([(0.0, 0.0, "smooth"), (th, 0.0, "in"), (tt, step, "out"), (tf, step, "smooth"), (te, 0.0, "smooth")], time)
    back = (tf + te) / 2.0
    ch["lift"] = anim.sample([(0.0, 0.0, "smooth"), (th, 0.0, "smooth"), (tm, lift, "smooth"), (tt, 0.0, "smooth"), (tf, 0.0, "smooth"),
                              (back, lift if step else 0.0, "smooth"), (te, 0.0, "smooth")], time)
    ch["heel"] = anim.sample([(0.0, 0.0, "smooth"), (tt, 0.0, "out"), ((tt + tf) / 2.0, heel, "smooth"), (tf, 0.85 * heel, "smooth"), (te, 0.0, "smooth")], time)
    return kind, rest, ch


def attack_pose(body, time):
    """(rot, root, extra) of an attack at `time` seconds: the biped's attack, with the undead's kinds and channels."""
    kind_name = attack_kind(body.form)
    if kind_name == "shoot":
        return shoot_pose(body, time)
    kind, rest, ch = _channels(body, time)
    L = body.L
    r = 1.25 if body.form.get("weight") == "heavy" else 1.0     # a heavy blow drives the hips further down and forward
    px, pz = ch.get("px", 0.0) * L, ch.get("pz", 0.0) * L * r
    hip = (body.hip[0] + px, body.hip_z() + pz)
    rot = {}
    (nx, nlift, npitch), (fx, flift, fpitch) = bm._foot_base(body, "n"), bm._foot_base(body, "f")
    bm._plant(body, rot, "n", hip, nx + ch["step"] * L, npitch, nlift + ch["lift"] * L)
    if kind.get("both_feet"):
        bm._plant(body, rot, "f", hip, fx + ch["step"] * L, fpitch, flift + ch["lift"] * L)
    elif flift > 0.0 or fpitch != 0.0:
        bm._plant(body, rot, "f", hip, fx, fpitch, flift)
    else:
        bm._plant_heel(body, rot, "f", hip, fx, ch["heel"])
    bm._posture(body, rot, rest["lean"] + ch.get("d_lean", 0.0), rest["head"] + ch.get("d_head", 0.0))
    sk = body.skel
    for bone in ("arm_n", "fore_n", "arm_f", "fore_f"):
        aim(sk, rot, bone, ch.get(bone, rest[bone]))
    bm._hold_items(body, rot)
    for bone in ("item_n", "item_f"):
        if bone in ch:
            aim(sk, rot, bone, 180.0 - ch[bone])
    if kind_name == "whip":
        _crack(body, rot, time)
    return rot, (px, 0.0, hip[1] - body.hip[1]), {"jaw": ch.get("jaw", 0.0)}


def _crack(body, rot, time):
    """Lay the whip's segments along the lash's wave at `time`."""
    sk = body.skel
    idle, _ = bm.idle_pose(body, 0.0)
    for k, bone in enumerate(WHIP):
        if bone not in sk.rest:
            continue
        rest_dir = bm.direction_of(body, idle, bone)
        keys = [(t, rest_dir if v == REST else v, e) for t, v, e in WHIP_KEYS]
        keys[-1] = (keys[-1][0], rest_dir - 360.0, keys[-1][2])
        aim(sk, rot, bone, anim.sample(keys, time - k * WHIP_DELAY))


# ---- the bow --------------------------------------------------------------------------------------------------------------------
# The archer raises the bow arm straight at the target, nocks, draws the string to its cheek (held, still pulling), looses (the drawing hand flies
# back past the cheek and opens, the bow arm kicks), holds the follow-through and lowers. `aim` in the form tips the shot up (degrees).
SHOOT = dict(d_lean=(-4, -4, -6, -4), d_head=(4, 4, 2, 2), px=(-0.03, -0.03, -0.05, -0.03), pz=(-0.03, -0.03, -0.04, -0.03), kick=(0, 0, -7, -4))


def _cheek(body, posed):
    """A point on the near cheek of a posed head: the head bone's root, a third of the way up it and a little forward."""
    h, t, _ = posed["head"]
    return (h[0] + 0.34 * (t[0] - h[0]) + 0.02 * body.L, h[1] + 0.34 * (t[1] - h[1]))


def _solve_arm(body, rot, root, side, target, bend):
    sk = body.skel
    posed = sk.pose(rot, root)
    shoulder = posed["arm_" + side][0]
    a1, a2 = anim.ik2d(sk.length("arm_" + side), sk.length("fore_" + side), shoulder, target, bend)
    aim(sk, rot, "arm_" + side, math.degrees(a1))
    aim(sk, rot, "fore_" + side, math.degrees(a2))


def shoot_pose(body, time):
    times = TIMINGS[body.form.get("weight", "normal")]["t"]
    tw, th, tm, tt, tf, te = times
    rest = _rest(body)
    sample = lambda v, start=0.0, end=0.0: anim.sample(_keys(times, *v, start=start, end=end), time)
    L = body.L
    px, pz = sample(SHOOT["px"]) * L, sample(SHOOT["pz"]) * L
    hip = (body.hip[0] + px, body.hip_z() + pz)
    rot = {}
    bm._stand_feet(body, rot, hip)
    bm._posture(body, rot, rest["lean"] + sample(SHOOT["d_lean"]), rest["head"] + sample(SHOOT["d_head"]))
    sk = body.skel
    for bone in ("arm_n", "fore_n", "arm_f", "fore_f"):
        aim(sk, rot, bone, rest[bone])
    root = (px, 0.0, hip[1] - body.hip[1])
    posed = sk.pose(rot, root)
    cheek = _cheek(body, posed)
    shoulder = posed["arm_f"][0]
    up = math.radians(body.form.get("aim", 0.0))
    u = (math.cos(up), math.sin(up))
    reach = sk.length("arm_f") + sk.length("fore_f")
    # the grip is where the arrow's line from the cheek meets the bow arm held straight: |cheek + d u - shoulder| = reach
    cx, cz = cheek[0] - shoulder[0], cheek[1] - shoulder[1]
    b = cx * u[0] + cz * u[1]
    d = -b + math.sqrt(max(0.0, b * b - (cx * cx + cz * cz - reach * reach)))
    grip = (cheek[0] + d * u[0], cheek[1] + d * u[1])
    bow_dir = math.degrees(math.atan2(grip[0] - shoulder[0], -(grip[1] - shoulder[1])))
    # how far the bow arm is up: 0 at rest, 1 from the windup on, back to 0 at the end; the kick dips it after the release
    raise_ = anim.sample([(0.0, 0.0, "out"), (0.06, 0.7, "smooth"), (tw, 1.0, "smooth"), (tf, 1.0, "smooth"), (te, 0.0, "smooth")], time)
    kick = sample(SHOOT["kick"])
    for bone in ("arm_f", "fore_f"):
        aim(sk, rot, bone, rest[bone] + raise_ * (bow_dir + kick - rest[bone]))
    bm._hold_items(body, rot)
    bow_rest = 180.0 - rest["item_f"]
    aim(sk, rot, "item_f", bow_rest + raise_ * (180.0 + body.form.get("aim", 0.0) + kick * 0.5 - bow_rest))
    posed = sk.pose(rot, root)
    grip = posed["item_f"][0]
    # the drawing hand: to the string at the bow, drawn back to the cheek, then loosed past it; the arm is solved to that and blended with its rest
    # pose by `w`, so the clip starts and ends on the idle's arm
    nock = (grip[0] - 0.10 * L * u[0], grip[1] - 0.10 * L * u[1])
    loose = (cheek[0] - 0.16 * L * u[0], cheek[1] - 0.16 * L * u[1] + 0.02 * L)
    draw = [(0.0, nock), (0.06, nock), (tw, (cheek[0] + 0.30 * (nock[0] - cheek[0]), cheek[1] + 0.30 * (nock[1] - cheek[1]))),
            (th, (cheek[0] - 0.03 * L * u[0], cheek[1] - 0.03 * L * u[1])), (tm, loose), (tt, loose), (tf, (loose[0] - 0.02 * L, loose[1] - 0.06 * L)), (te, loose)]
    w = anim.sample([(0.0, 0.0, "out"), (0.06, 0.8, "smooth"), (tw, 1.0, "smooth"), (tf, 1.0, "smooth"), (te, 0.0, "smooth")], time)
    hand = _path(draw, time)
    _solve_arm(body, rot, root, "n", hand, 1)
    for bone in ("arm_n", "fore_n"):
        d = bm.direction_of(body, rot, bone)
        d = rest[bone] + ((d - rest[bone] + 180.0) % 360.0 - 180.0)
        aim(sk, rot, bone, rest[bone] + w * (d - rest[bone]))
    on_string = tw - 1e-9 <= time < tm - 1e-9
    if on_string:
        posed = sk.pose(rot, root)
        hand = posed["fore_n"][1]
        for bone in ("string_u", "string_l", "arrow"):
            if bone in sk.rest:
                head = posed[bone][0] if bone != "arrow" else grip
                target = hand if bone != "arrow" else (2 * grip[0] - hand[0], 2 * grip[1] - hand[1])
                aim(sk, rot, bone, math.degrees(math.atan2(target[0] - head[0], -(target[1] - head[1]))))
    return rot, root, {}


def _path(points, time):
    """A point moved smoothly through [(time, (x, z))]."""
    if time <= points[0][0]:
        return points[0][1]
    for (t0, p0), (t1, p1) in zip(points, points[1:]):
        if t0 <= time < t1:
            w = anim.smooth((time - t0) / (t1 - t0))
            return (p0[0] + w * (p1[0] - p0[0]), p0[1] + w * (p1[1] - p0[1]))
    return points[-1][1]


# ---- the hop --------------------------------------------------------------------------------------------------------------------
def hop_pose(body, gait, t, stride):
    """A jiangshi's hop at cycle position t: both feet on the same foot path (planted together, then lifted together), the knees giving a little as
    it lands and pushing it off, the body rising through the air in an arc and the feet drawn up under it."""
    h = HOPS[gait]
    L = body.L
    duty = h["duty"]
    u = t % 1.0
    base = body.hip_z(h["crouch"])
    if u < duty:
        tau = u / duty
        z = base - h["dip"] * L * math.sin(math.pi * tau)
        air = 0.0
    else:
        s = (u - duty) / (1.0 - duty)
        air = h["height"] * L * math.sin(math.pi * s)
        z = base + air
    hip = (body.hip[0], z)
    rot = {}
    for side in "nf":
        leg = body.legs[side]
        x, fz, pitch, _ = anim.foot_pose(u, stride, duty, h["tuck"] * L, leg.heel, leg.toe, leg.ankle_h)
        offset = (-0.02 if side == "n" else 0.02) * L
        rot.update(leg.solve(hip, (hip[0] + x + offset, fz + air), pitch))
    sway = 1.5 * math.sin(2.0 * math.pi * (u - 0.1))
    bm._posture(body, rot, body.posture["lean"] + h["lean"] + sway, body.posture["head_lean"] - 0.5 * sway)
    bm._arms(body, rot, t, 2.0)
    bm._hold_items(body, rot)
    return rot, (0.0, 0.0, z - body.hip[1])


def hop_feet_x(body, gait, t, stride, side):
    """Where the hop puts a foot's ankle, from the hip (the tests check the legs reach it)."""
    h = HOPS[gait]
    leg = body.legs[side]
    x, fz, _, _ = anim.foot_pose(t % 1.0, stride, h["duty"], h["tuck"] * body.L, leg.heel, leg.toe, leg.ankle_h)
    u = t % 1.0
    air = 0.0 if u < h["duty"] else h["height"] * body.L * math.sin(math.pi * (u - h["duty"]) / (1.0 - h["duty"]))
    return x + (-0.02 if side == "n" else 0.02) * body.L, fz + air


# ---- floaters -------------------------------------------------------------------------------------------------------------------
# A floater is held `hover` above the ground with a bob and a slow sway; drifting, it leans into the way it goes and bobs quicker; everything hung
# on it trails. Its root bone is turned in the world (`tilt`, degrees forward), the rest follow.
FLOAT_GAITS = {"walk": dict(cycle=1.2, frames=8, tilt=12.0, bob=1.0, wind=1.0), "run": dict(cycle=0.72, frames=8, tilt=22.0, bob=0.8, wind=1.5)}
FLOAT_IDLE_FRAMES, FLOAT_IDLE_SECONDS = 8, 1.6


def _float(body, rot, x, height, tilt, head=0.0, arms=None):
    """Turn the floater `tilt` degrees forward about its root and hold its lowest point `height` above the ground; (rot, root)."""
    sk = body.skel
    rest_dir = sk.rest_direction(body.root)
    aim(sk, rot, body.root, rest_dir - tilt)
    if "head" in sk.rest and body.root != "head":
        aim(sk, rot, "head", sk.rest_direction("head") - tilt - head)
    if "arm_n" in sk.rest:
        for bone in ("arm_n", "fore_n", "arm_f", "fore_f"):
            aim(sk, rot, bone, sk.rest_direction(bone) - tilt + (arms or {}).get(bone, 0.0))
    return rot, (x, 0.0, height - body.low)


def float_idle_pose(body, t):
    c = math.sin(2.0 * math.pi * t)
    rot = {}
    return _float(body, rot, 0.006 * body.size * math.sin(2.0 * math.pi * t + 0.7), body.hover + body.bob * c, 2.5 * math.sin(2.0 * math.pi * t - 0.8),
                  head=-2.0 * c)


def float_drift_pose(body, gait, t):
    g = FLOAT_GAITS[gait]
    c = math.sin(4.0 * math.pi * t)
    rot = {}
    return _float(body, rot, 0.0, body.hover + g["bob"] * body.bob * c, g["tilt"] + 3.0 * math.sin(4.0 * math.pi * t - 0.9), head=-0.5 * g["tilt"] - 2.0 * c)


# (windup, mid, impact, follow): x and z of the root (of the floater's height), its tilt and the head's, the arms (degrees from rest), the jaw
FLOAT_ATTACKS = {
    # a flame rears back and up, then darts forward, flaring
    "flare": dict(x=(-0.12, 0.20, 0.40, 0.34), z=(0.06, 0.02, -0.02, 0.0), tilt=(-18, 22, 32, 24), head=(-6, 4, 8, 6)),
    # the banshee rears back with her hands to her face, then throws her head forward screaming, her arms flung out behind
    "wail": dict(x=(-0.08, 0.10, 0.20, 0.18), z=(0.05, 0.02, 0.0, 0.0), tilt=(-14, 10, 18, 16), head=(-30, 0, 24, 20),
                 arms=dict(arm_n=(10, 40, 70, 60), fore_n=(-10, -60, -100, -90), arm_f=(8, 36, 64, 56), fore_f=(-8, -56, -96, -86))),
    # a skull rises, tips back with its jaw dropping, then dives at its prey and snaps shut
    "dive": dict(x=(-0.10, 0.30, 0.50, 0.42), z=(0.14, 0.08, 0.06, 0.04), tilt=(-24, 14, 22, 16), head=(0, 0, 0, 0), jaw=(30, 36, 0, 8)),
}


def float_attack_pose(body, time):
    spec = FLOAT_ATTACKS[attack_kind(body.form)]
    times = TIMINGS["normal"]["t"]
    ch = {k: anim.sample(_keys(times, *v, start=0.0, end=0.0), time) for k, v in spec.items() if isinstance(v, tuple)}
    arms = {b: anim.sample(_keys(times, *v, start=0.0, end=0.0), time) for b, v in spec.get("arms", {}).items()}
    rot, root = float_idle_pose(body, 0.0)
    rot = {}
    s = body.size
    base = float_idle_pose(body, 0.0)
    rest_tilt = 2.5 * math.sin(-0.8)
    rot, root = _float(body, rot, base[1][0] + ch["x"] * s, body.hover + ch["z"] * s, rest_tilt + ch["tilt"], head=ch.get("head", 0.0), arms=arms or None)
    return rot, root, {"jaw": ch.get("jaw", 0.0)}


FLOAT_HURT = dict(x=[(0.0, 0.0, "out"), (0.04, -0.08, "out"), (0.10, -0.12, "smooth"), (0.16, -0.04, "smooth"), (0.21, 0.0, "smooth")],
                  z=[(0.0, 0.0, "out"), (0.04, 0.03, "out"), (0.10, 0.05, "smooth"), (0.16, 0.02, "smooth"), (0.21, 0.0, "smooth")],
                  tilt=[(0.0, 0.0, "out"), (0.04, -16.0, "out"), (0.10, -26.0, "smooth"), (0.16, -8.0, "smooth"), (0.21, 0.0, "smooth")],
                  head=[(0.0, 0.0, "out"), (0.04, -14.0, "out"), (0.10, -20.0, "smooth"), (0.16, -6.0, "smooth"), (0.21, 0.0, "smooth")],
                  jaw=[(0.0, 0.0, "out"), (0.04, 20.0, "out"), (0.10, 26.0, "smooth"), (0.16, 8.0, "smooth"), (0.21, 0.0, "smooth")])


def float_hurt_pose(body, time):
    ch = {k: anim.sample(v, time) for k, v in FLOAT_HURT.items()}
    s = body.size
    base = float_idle_pose(body, 0.0)
    rest_tilt = 2.5 * math.sin(-0.8)
    rot, root = _float(body, {}, base[1][0] + ch["x"] * s, body.hover + ch["z"] * s, rest_tilt + ch["tilt"], head=ch["head"])
    return rot, root, {"jaw": ch["jaw"]}


# it gutters: shudders, tips over and sinks, hits the ground and rolls onto its side. The death is set on the ground by the render (grounded), so
# the root's height is the height of its lowest point.
FLOAT_DIE = dict(frames=bm.DIE["frames"], keys=dict(
    height=[(0.0, 1.0, "out"), (0.06, 1.15, "out"), (0.14, 0.9, "in"), (0.22, 0.55, "in"), (0.32, 0.0, "out"), (0.44, 0.04, "smooth"), (0.60, 0.0, "smooth"), (0.9, 0.0, "smooth")],
    tilt=[(0.0, 0.0, "out"), (0.06, -12.0, "out"), (0.14, 10.0, "smooth"), (0.22, 36.0, "in"), (0.32, 70.0, "out"), (0.44, 84.0, "smooth"), (0.60, 90.0, "smooth"), (0.9, 90.0, "smooth")],
    head=[(0.0, 0.0, "out"), (0.06, -20.0, "out"), (0.14, -10.0, "smooth"), (0.32, 10.0, "smooth"), (0.9, 14.0, "smooth")],
    jaw=[(0.0, 0.0, "out"), (0.06, 30.0, "out"), (0.32, 24.0, "smooth"), (0.6, 34.0, "smooth"), (0.9, 34.0, "smooth")],
    x=[(0.0, 0.0, "out"), (0.06, -0.04, "out"), (0.22, 0.04, "smooth"), (0.44, 0.10, "smooth"), (0.9, 0.10, "smooth")]))


def float_die_pose(body, time):
    ch = {k: anim.sample(v, time) for k, v in FLOAT_DIE["keys"].items()}
    base = float_idle_pose(body, 0.0)
    rest_tilt = 2.5 * math.sin(-0.8)
    rot, root = _float(body, {}, base[1][0] + ch["x"] * body.size, 0.0, rest_tilt + ch["tilt"], head=ch["head"])
    return rot, (root[0], 0.0, ch["height"] * (body.hover + body.bob * math.sin(0.0))), {"jaw": ch["jaw"]}


# ---- clips ----------------------------------------------------------------------------------------------------------------------
def _clip(body, poses, durations, wind, loop, grounded=False, skip=()):
    return Clip(_with_secondary(body, poses, durations, wind, loop, skip), durations, loop, grounded)


def _x(pose):
    return pose if len(pose) == 3 else (pose[0], pose[1], {})


def is_float(body):
    return isinstance(body, FloatBody)


def idle_clip(body):
    if is_float(body):
        n = FLOAT_IDLE_FRAMES
        dur = [FLOAT_IDLE_SECONDS / n] * n
        return _clip(body, [_x(float_idle_pose(body, i / n)) for i in range(n)], dur, 0.12, True)
    n = bm.IDLE_FRAMES
    dur = [bm.IDLE_SECONDS / n] * n
    return _clip(body, [_x(bm.idle_pose(body, i / n)) for i in range(n)], dur, 0.15, True)


def gait_name(body, gait):
    """The gait a form uses for its walk or run: its own hop for a jiangshi."""
    return "hop_" + gait if body.form.get("body") == "hop" else gait


def plan_gait(body, gait, speed, ppu):
    """(cycle seconds, stride units) for a walk or a run at `speed` game px/s with a sprite drawn at `ppu` px per unit: biped_motion.plan_gait on the
    form's own gait (a hop's stride is short, its legs are nearly straight). A floater has no feet to skate: its cycle is its own."""
    if is_float(body):
        return FLOAT_GAITS[gait]["cycle"], 0.0
    return bm.plan_gait(body, gait_name(body, gait), speed, ppu)


def gait_clip(body, gait, cycle, stride):
    if is_float(body):
        g = FLOAT_GAITS[gait]
        n = g["frames"]
        dur = [g["cycle"] / n] * n
        return _clip(body, [_x(float_drift_pose(body, gait, i / n)) for i in range(n)], dur, g["wind"], True)
    name = gait_name(body, gait)
    if name.startswith("hop_"):
        n = HOPS[gait]["frames"]
        dur = [cycle / n] * n
        return _clip(body, [_x(hop_pose(body, gait, i / n, stride)) for i in range(n)], dur, 1.0 if gait == "walk" else 1.4, True)
    n = bm.WALK_FRAMES if gait == "walk" else bm.RUN_FRAMES
    dur = [cycle / n] * n
    return _clip(body, [_x(bm.gait_pose(body, gait, i / n, stride)) for i in range(n)], dur, body.gaits[gait]["wind"], True)


def attack_clip(body):
    if is_float(body):
        frames = TIMINGS["normal"]["frames"]
        dur = [d for _, d in frames]
        return _clip(body, [float_attack_pose(body, t) for t, _ in frames], dur, 0.6, False)
    frames, _ = attack_frames(body)
    dur = [d for _, d in frames]
    skip = WHIP if attack_kind(body.form) == "whip" else ()
    return _clip(body, [attack_pose(body, t) for t, _ in frames], dur, 0.5, False, skip=skip)


def hurt_clip(body):
    spec = bm.hurt_frames()
    dur = [d for _, d in spec]
    if is_float(body):
        return _clip(body, [float_hurt_pose(body, t) for t, _ in spec], dur, 0.5, False)
    poses = []
    for t, _ in spec:
        rot, root = bm.hurt_pose(body, t)
        poses.append((rot, root, {"jaw": anim.sample([(0.0, 0.0, "out"), (0.04, 16.0, "out"), (0.10, 22.0, "smooth"), (0.16, 6.0, "smooth"), (0.21, 0.0, "smooth")], t)}))
    return _clip(body, poses, dur, 0.5, False)


def die_clip(body):
    spec = bm.die_frames()
    dur = [d for _, d in spec]
    if is_float(body):
        return _clip(body, [float_die_pose(body, t) for t, _ in spec], dur, 0.3, False, grounded=True)
    idle, _ = bm.idle_pose(body, 0.0)
    poses = []
    for t, _ in spec:
        rot, root = bm.die_pose(body, t)
        for side in "nf":   # what it holds stays in its hand as it falls, whichever way it was held
            turn = bm.direction_of(body, rot, "fore_" + side) - bm.direction_of(body, idle, "fore_" + side)
            aim(body.skel, rot, "item_" + side, bm.direction_of(body, idle, "item_" + side) + turn)
        poses.append((rot, root, {"jaw": anim.sample([(0.0, 0.0, "out"), (0.06, 26.0, "out"), (0.32, 18.0, "smooth"), (0.6, 30.0, "smooth"), (0.9, 30.0, "smooth")], t)}))
    return _clip(body, poses, dur, 0.3, False, grounded=True)


def windup_of(body):
    return TIMINGS["normal"]["windup"] if is_float(body) else attack_frames(body)[1]


RUN_SPEED = 1.9   # a run covers the ground this many times as fast as the walk (enemy.gd: RUN_SPEED)


def clips(body, speed, ppu):
    """{name: Clip} for a form whose walk covers the ground at `speed` game px/s, drawn at `ppu` px per unit."""
    walk = plan_gait(body, "walk", speed, ppu)
    run = plan_gait(body, "run", speed * RUN_SPEED, ppu)
    return {"idle": idle_clip(body), "walk": gait_clip(body, "walk", *walk), "run": gait_clip(body, "run", *run),
            "attack": attack_clip(body), "hurt": hurt_clip(body), "die": die_clip(body)}
