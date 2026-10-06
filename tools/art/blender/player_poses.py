"""The poses a player who is a two-legged creature needs beyond an enemy's: leaping (rise), falling, rolling, sliding, mantling a ledge, clinging to a wall and landing
(scripts/movement/species_look.gd names the clips: rise, fall, roll, slide, mantle, wall, land). Pure Python; they are held poses or short cycles, not gaits, so each is
written by aiming bones in the world (limbs.aim), with the feet planted by IK where they stand. A pose that leaves the ground is `grounded`: the render sets its lowest
point on the ground, since the game draws the sprite by its bottom edge.
"""
import math

import anim
import biped_motion as bm
from limbs import aim

# the clips a player body has and how many frames each has; "wall" and "land" hold one
FRAMES = {"rise": 1, "fall": 1, "roll": 4, "slide": 1, "mantle": 2, "wall": 1, "land": 1}
GROUNDED = {"rise": True, "fall": True, "roll": True, "slide": True, "mantle": True, "wall": True, "land": False}


def _set(body, rot, lean, head, arms, legs, item=None):
    """Aim the trunk and limbs in the world. `arms` and `legs` map bone -> direction (degrees from straight down, forward positive)."""
    sk = body.skel
    bm._posture(body, rot, lean, head)
    for bone in ("arm_n", "fore_n", "arm_f", "fore_f"):
        aim(sk, rot, bone, arms[bone])
    for bone in ("thigh_n", "shin_n", "foot_n", "thigh_f", "shin_f", "foot_f"):
        aim(sk, rot, bone, legs[bone])
    for s in "nf":
        tilt = 0.0 if item is None else item
        aim(sk, rot, "item_" + s, 180.0 - tilt)


def _rest_arms(body, rot):
    return {"arm_n": bm.direction_of(body, rot, "arm_n"), "fore_n": bm.direction_of(body, rot, "fore_n"),
            "arm_f": bm.direction_of(body, rot, "arm_f"), "fore_f": bm.direction_of(body, rot, "fore_f")}


def pose(body, name, k=0):
    """(rot, root) of the player pose `name` (frame `k` of it)."""
    rest, _ = bm.idle_pose(body, 0.0)
    lean0, head0 = 180.0 - bm.direction_of(body, rest, "spine"), 180.0 - bm.direction_of(body, rest, "head")
    rot = {}
    if name == "rise":      # up and away: the body stretched, the near knee driven up, the far leg trailing, the arms flung up and back
        _set(body, rot, lean0 - 14, head0 - 6, {"arm_n": 128, "fore_n": 150, "arm_f": 150, "fore_f": 166},
             {"thigh_n": 82, "shin_n": -38, "foot_n": 55, "thigh_f": -12, "shin_f": -58, "foot_f": -40})
    elif name == "fall":    # dropping: the legs hang a little apart, the arms up and out for balance
        _set(body, rot, lean0 - 4, head0, {"arm_n": 104, "fore_n": 124, "arm_f": 120, "fore_f": 138},
             {"thigh_n": 24, "shin_n": 2, "foot_n": 30, "thigh_f": -20, "shin_f": -30, "foot_f": 10})
    elif name == "roll":    # a curled ball, turning a quarter each frame
        _set(body, rot, 62.0, 70.0, {"arm_n": 96, "fore_n": 168, "arm_f": 90, "fore_f": 172},
             {"thigh_n": 150, "shin_n": 10, "foot_n": 40, "thigh_f": 138, "shin_f": 4, "foot_f": 36})
        return _turned(body, rot, -90.0 * k), (0.0, 0.0, 0.0)
    elif name == "slide":   # low on its back foot's heel with the near leg out in front, leaning back, arms behind
        _set(body, rot, -22.0, -12.0, {"arm_n": -48, "fore_n": -36, "arm_f": -60, "fore_f": -44},
             {"thigh_n": 104, "shin_n": 96, "foot_n": 70, "thigh_f": 128, "shin_f": 14, "foot_f": 4})
    elif name == "mantle":  # hanging by the hands, then pulled up until the chest is over the edge and a knee is on it
        if k == 0:
            _set(body, rot, 4.0, 2.0, {"arm_n": 148, "fore_n": 172, "arm_f": 156, "fore_f": 176},
                 {"thigh_n": 10, "shin_n": -6, "foot_n": 20, "thigh_f": 4, "shin_f": -14, "foot_f": 16})
        else:
            _set(body, rot, 44.0, 28.0, {"arm_n": 112, "fore_n": 68, "arm_f": 108, "fore_f": 60},
                 {"thigh_n": 88, "shin_n": -4, "foot_n": 18, "thigh_f": 36, "shin_f": -24, "foot_f": 10})
    elif name == "wall":    # clinging face to the wall: leaning into it, one hand high on it and the other lower, the near knee up and its foot flat against it
        _set(body, rot, 16.0, 4.0, {"arm_n": 128, "fore_n": 150, "arm_f": 100, "fore_f": 118},
             {"thigh_n": 100, "shin_n": 24, "foot_n": 92, "thigh_f": 58, "shin_f": 8, "foot_f": 70})
    elif name == "land":    # the weight comes down: a deep crouch, the arms forward
        hip = (body.hip[0], body.hip_z(0.60))
        _set_planted(body, rot, hip, lean0 + 14, head0 + 6, {"arm_n": 78, "fore_n": 100, "arm_f": 70, "fore_f": 94})
        return rot, (0.0, 0.0, hip[1] - body.hip[1])
    else:
        raise KeyError(name)
    return rot, (0.0, 0.0, 0.0)


def _set_planted(body, rot, hip, lean, head, arms):
    bm._stand_feet(body, rot, hip)
    bm._posture(body, rot, lean, head)
    for bone, d in arms.items():
        aim(body.skel, rot, bone, d)
    for s in "nf":
        aim(body.skel, rot, "item_" + s, 180.0)


def _turned(body, rot, spin):
    """The pose turned as a whole by `spin` degrees (counter-clockwise as the camera sees it when positive) about the hips: every direction in it moves by that much."""
    sk = body.skel
    out = {}
    # hips first (the root of the chain), then each bone by its own world direction plus the turn
    dirs = {}
    for bone in sk.order:
        dirs[bone] = bm.direction_of(body, rot, bone)
    for bone in sk.order:
        aim(sk, out, bone, dirs[bone] + spin)
    return out


def clip(body, name):
    """The frames of a player clip as a biped_motion.Clip: one pose, or the frames of a short cycle (durations are the engine's to set)."""
    n = FRAMES[name]
    frames = [pose(body, name, k) for k in range(n)]
    return bm.Clip(frames, [0.1] * n, name in ("roll",), grounded=GROUNDED[name])
