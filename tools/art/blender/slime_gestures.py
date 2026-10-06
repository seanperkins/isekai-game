"""The verb gestures (tools/verb_anims.json) a slime plays beyond its attack styles (lunge, slam, lash): what a jelly does for a roar, a guard, a pointing pseudopod, a toss, a summons, a drink, a
knead, a creep and a throb. Pure Python. Each is a set of soft-body channels like slime_motion's LUNGE (offsets from the rest: `sq` the squash, `lean`, `bulge`, `wave`, and the root's `x` and `z` in
body widths and heights; windup, mid-swing, impact, follow-through, settle), registered by `register` as attack styles of their own name; the styles the forms already name (throw, pulse, lash) are
left as they are, so the gestures called toss and throb are the new ones for the same archetypes.
"""


def register(styles, swing):
    """Add the gestures to slime_motion's attack styles; `swing` is its path builder."""
    s = swing
    styles.update({
        # stretched tall and wobbling hard, the body leaning back
        "roar": {"sq": s(-0.10, 0.30, 0.34, 0.20, 0.0), "lean": s(-0.10, -0.14, -0.14, -0.06, 0.0), "bulge": s(0.08, 0.10, 0.10, 0.04, 0.0),
                 "wave": s(0.06, 0.14, 0.16, 0.08, 0.02), "x": s(-0.02, -0.04, -0.04, -0.02, 0.0), "z": s(0.0, 0.10, 0.14, 0.08, 0.0)},
        # flattened wide and held, bulging out at the sides
        "guard": {"sq": s(-0.20, -0.34, -0.34, -0.20, -0.04), "lean": s(0.0, 0.0, 0.0, 0.0, 0.0), "bulge": s(0.10, 0.18, 0.18, 0.10, 0.0),
                  "wave": s(0.0, 0.0, 0.0, 0.0, 0.0), "x": s(-0.02, -0.04, -0.04, -0.02, 0.0), "z": s(0.0, 0.0, 0.0, 0.0, 0.0)},
        # the body leaning into a long stretch forward, like a pseudopod aimed at the target
        "point": {"sq": s(-0.08, 0.12, 0.14, 0.08, 0.0), "lean": s(-0.04, 0.20, 0.26, 0.16, 0.02), "bulge": s(0.04, 0.14, 0.18, 0.10, 0.0),
                  "wave": s(0.0, 0.06, 0.08, 0.04, 0.0), "x": s(-0.02, 0.10, 0.22, 0.16, 0.04), "z": s(0.0, 0.0, 0.0, 0.0, 0.0)},
        # coiled down and back, then flicked forward and up
        "toss": {"sq": s(-0.26, 0.14, -0.10, 0.06, -0.02), "lean": s(-0.16, 0.10, 0.18, 0.04, 0.0), "bulge": s(0.08, 0.0, 0.14, 0.0, 0.0),
                 "wave": s(0.02, -0.06, 0.06, -0.02, 0.0), "x": s(-0.06, 0.04, 0.08, 0.04, 0.02), "z": s(0.0, 0.12, 0.04, 0.0, 0.0)},
        # swollen up and rising, wobbling, held
        "summon": {"sq": s(0.0, 0.20, 0.26, 0.16, 0.0), "lean": s(0.0, 0.0, 0.0, 0.0, 0.0), "bulge": s(0.04, 0.14, 0.18, 0.10, 0.0),
                   "wave": s(0.02, 0.08, 0.10, 0.05, 0.0), "x": s(0.0, 0.0, 0.0, 0.0, 0.0), "z": s(0.0, 0.14, 0.20, 0.10, 0.0)},
        # tipped forward and sagging, bulging as it takes something in
        "drink": {"sq": s(-0.06, -0.16, -0.20, -0.10, 0.0), "lean": s(0.04, 0.20, 0.26, 0.16, 0.0), "bulge": s(0.06, 0.16, 0.20, 0.10, 0.0),
                  "wave": s(0.02, 0.04, 0.04, 0.02, 0.0), "x": s(0.0, 0.08, 0.12, 0.06, 0.0), "z": s(0.0, -0.04, -0.06, -0.02, 0.0)},
        # pressed down and let up, again, the wobble running through it: kneading
        "craft": {"sq": s(-0.18, 0.12, -0.20, 0.08, -0.02), "lean": s(0.0, 0.0, 0.0, 0.0, 0.0), "bulge": s(0.10, 0.0, 0.12, 0.0, 0.0),
                  "wave": s(0.06, -0.08, 0.08, -0.04, 0.0), "x": s(0.0, 0.0, 0.0, 0.0, 0.0), "z": s(0.0, 0.0, 0.0, 0.0, 0.0)},
        # flattened low and creeping forward
        "sneak": {"sq": s(-0.30, -0.34, -0.34, -0.22, -0.04), "lean": s(0.04, 0.06, 0.06, 0.04, 0.0), "bulge": s(0.14, 0.18, 0.18, 0.10, 0.0),
                  "wave": s(0.0, 0.0, 0.0, 0.0, 0.0), "x": s(-0.02, 0.12, 0.24, 0.18, 0.06), "z": s(0.0, 0.0, 0.0, 0.0, 0.0)},
        # swelling and shrinking in a rhythm, bulging at the swell
        "throb": {"sq": s(0.10, -0.12, 0.14, -0.06, 0.0), "lean": s(0.0, 0.0, 0.0, 0.0, 0.0), "bulge": s(0.14, 0.0, 0.16, 0.0, 0.0),
                  "wave": s(0.0, 0.05, 0.0, -0.03, 0.0), "x": s(0.0, 0.0, 0.0, 0.0, 0.0), "z": s(0.0, 0.04, 0.0, 0.0, 0.0)},
    })
