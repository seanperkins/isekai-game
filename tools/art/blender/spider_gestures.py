"""The verb gestures (tools/verb_anims.json) a spider plays that its blows (bite, pounce, slash, spit) are not: what a spider does for a rearing slam, a roar, a guard, a pointing foreleg, a flick
of the abdomen, a summons, a drink, spinning, a stalk and a throb. Pure Python. A plain spider's are spider_motion.ATTACKS entries (the body, the front pair and the second pair, as BITE has
them) registered by `register`; a drider (a person's upper body on a spider's) plays the biped's arms and lean for the same gestures, made by `drider_gesture` from attack_kinds.SPECS over
the spider half's LOWER keys.
"""


def register(attacks, swing, attack_keys):
    """Add the plain spider's gestures to spider_motion.ATTACKS; `swing` and `attack_keys` are its path builders."""
    s, k = swing, attack_keys
    attacks.update({
        # reared up high on the hind legs, the forelegs overhead, then crashed down on the prey
        "slam": k({"root_x": s(-0.20, -0.05, 0.30, 0.20), "root_z": s(0.30, 0.55, -0.10, -0.04), "pitch": s(28.0, 36.0, -14.0, -6.0), "abd": s(-10.0, -14.0, 8.0, 4.0),
                   "fang": s(30.0, 40.0, 6.0, 4.0)}, front=((-0.40, 2.40, 90.0), (0.20, 2.60, 80.0), (1.00, 0.0, 10.0)), f1=(0.30, 0.40)),
        # reared up with the forelegs flung wide and the fangs open, held
        "roar": k({"root_x": s(-0.10, -0.14, -0.14, -0.06), "root_z": s(0.20, 0.40, 0.45, 0.25), "pitch": s(24.0, 34.0, 38.0, 26.0), "abd": s(-12.0, -18.0, -20.0, -10.0),
                   "fang": s(40.0, 46.0, 46.0, 30.0)}, front=((-0.30, 1.80, 100.0), (-0.35, 2.30, 110.0), (-0.30, 2.40, 110.0)), f1=(0.0, 0.0)),
        # crouched low with the forelegs raised and crossed in front
        "guard": k({"root_x": s(-0.06, -0.08, -0.08, -0.04), "root_z": s(-0.18, -0.26, -0.26, -0.16), "pitch": s(-4.0, -8.0, -8.0, -4.0), "abd": s(4.0, 8.0, 8.0, 4.0),
                    "fang": s(10.0, 24.0, 24.0, 10.0)}, front=((0.00, 0.90, 50.0), (0.20, 1.20, 70.0), (0.25, 1.25, 70.0)), f1=(0.05, 0.10)),
        # one foreleg lifted and held out level ahead, the body still: a mark, a hunt, a fate
        "point": k({"root_x": s(-0.04, 0.0, 0.04, 0.02), "root_z": s(0.04, 0.04, 0.02, 0.0), "pitch": s(6.0, 8.0, 10.0, 6.0), "abd": s(-2.0, 0.0, 2.0, 0.0),
                    "fang": s(4.0, 6.0, 6.0, 2.0)}, front=((0.00, 1.20, 50.0), (0.80, 1.55, 30.0), (1.60, 1.60, 10.0)), f1=(0.0, 0.0)),
        # the abdomen curled back, then flicked forward over the body: a hurled glob, a decoy, a trap
        "throw": k({"root_x": s(-0.14, -0.06, 0.10, 0.06), "root_z": s(0.08, 0.16, -0.02, 0.0), "pitch": s(22.0, 26.0, -6.0, -2.0), "abd": s(-24.0, -20.0, 22.0, 8.0),
                    "fang": s(6.0, 10.0, 14.0, 6.0)}, front=((-0.10, 0.90, 40.0), (0.20, 0.90, 40.0), (0.40, 0.50, 30.0)), f1=(0.10, 0.20)),
        # reared up with the forelegs raised high and out, the fangs wide: a summons, a raising, an offer
        "summon": k({"root_x": s(-0.12, -0.18, -0.18, -0.08), "root_z": s(0.20, 0.50, 0.55, 0.30), "pitch": s(22.0, 34.0, 36.0, 24.0), "abd": s(-6.0, -14.0, -16.0, -8.0),
                     "fang": s(20.0, 40.0, 44.0, 24.0)}, front=((-0.20, 2.00, 70.0), (0.10, 2.70, 60.0), (0.30, 2.80, 60.0)), f1=(0.0, 0.30)),
        # the head down to the ground, the fangs working and the body low: to drink, devour or swallow
        "drink": k({"root_x": s(0.0, 0.06, 0.08, 0.02), "root_z": s(-0.10, -0.28, -0.30, -0.14), "pitch": s(-6.0, -30.0, -34.0, -14.0), "abd": s(4.0, 10.0, 12.0, 4.0),
                    "fang": s(10.0, 36.0, 6.0, 34.0)}, front=((0.10, 0.10, 10.0), (0.30, 0.05, 0.0), (0.40, 0.0, 0.0)), f1=(0.0, 0.0)),
        # the abdomen curled forward under the body and the forelegs working together in front of it: spinning, forging, rigging, bridging
        "craft": k({"root_x": s(0.0, 0.04, 0.04, 0.02), "root_z": s(-0.06, -0.12, -0.14, -0.08), "pitch": s(0.0, -8.0, -10.0, -4.0), "abd": s(-26.0, -34.0, -36.0, -20.0),
                    "fang": s(4.0, 8.0, 8.0, 4.0)}, front=((0.20, 0.90, 60.0), (0.60, 0.70, 70.0), (0.30, 0.90, 60.0)), f1=(0.0, 0.0)),
        # very low on a creeping step, the legs folded close: a veil, a stalk, a swap, a blink
        "sneak": k({"root_x": s(-0.04, 0.14, 0.26, 0.20), "root_z": s(-0.24, -0.30, -0.30, -0.18), "pitch": s(2.0, 0.0, 0.0, 2.0), "abd": s(6.0, 10.0, 10.0, 6.0),
                    "fang": s(2.0, 4.0, 4.0, 2.0)}, front=((0.10, 0.50, 20.0), (0.50, 0.30, 15.0), (0.70, 0.0, 10.0)), f1=(0.40, 0.30)),
        # the body rising and sinking and the abdomen throbbing: a heal, a light, a soul
        "pulse": k({"root_x": s(0.0, 0.0, 0.0, 0.0), "root_z": s(0.0, 0.08, -0.06, 0.0), "pitch": s(4.0, -4.0, 4.0, -2.0), "abd": s(-10.0, 16.0, -12.0, 6.0),
                    "fang": s(6.0, 18.0, 6.0, 4.0)}, front=((0.0, 0.40, 20.0), (0.0, 0.20, 10.0), (0.0, 0.40, 20.0)), f1=(0.0, 0.0)),
    })


def drider_gesture(spec, goblin_lean, goblin_head):
    """A biped spec (attack_kinds.SPECS) as one of spider_motion.GESTURES: the lean and the head as offsets, the arms as world directions; what the hands hold stays where the form rests it."""
    out = {"lean": tuple(v - goblin_lean for v in spec["lean"]), "head": tuple(v - goblin_head for v in spec["head"])}
    for bone in ("arm_n", "fore_n", "arm_f", "fore_f"):
        out[bone] = spec[bone]
    return out


def register_drider(gestures, specs, goblin_lean, goblin_head):
    """Give the driders every gesture they have none of their own for, from the biped's."""
    for name, spec in specs.items():
        gestures.setdefault(name, drider_gesture(spec, goblin_lean, goblin_head))
