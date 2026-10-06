"""The verb gestures (tools/verb_anims.json) the four-legged bodies play beyond the lunge, roar, slam and guard of quad_motion: what a wolf does for a bolt, a pointing mark, a toss, a summons, a drink,
a dig, a stalk and a shake. Pure Python. Each is quad_motion's four-value path per channel (windup, mid-swing, impact, follow-through; offsets from the rest, degrees for the trunk and head,
fractions of the foreleg for lengths), registered into its ATTACKS by `register`, so the same tests (timing, hind paws down, back to rest) cover them.
"""


def register(attacks, swing):
    """Add the gestures to quad_motion's ATTACKS, with `swing` its four-value path builder."""
    s = swing
    attacks.update({
        # the head thrown forward and up with the jaws open and a forepaw lifted, the body rising behind it: a bolt from the muzzle
        "cast": {
            "root_x": s(-0.04, 0.0, 0.04, 0.02), "root_z": s(-0.06, 0.04, 0.06, 0.02),
            "hips": s(6.0, 2.0, 0.0, 0.0), "spine": s(4.0, 10.0, 12.0, 6.0),
            "neck": s(-10.0, 14.0, 24.0, 12.0), "head": s(-4.0, 10.0, 16.0, 8.0), "jaw": s(6.0, 26.0, 34.0, 10.0),
            "fn_x": s(0.0, 0.06, 0.12, 0.06), "fn_lift": s(0.0, 0.5, 0.55, 0.2),
            "ff_x": s(0.0, 0.0, 0.0, 0.0), "ff_lift": s(0.0, 0.0, 0.0, 0.0),
        },
        # a forepaw lifted high and held out ahead along the line of sight, the head level over it and the body still: a mark, a hunt, a fate
        "point": {
            "root_x": s(-0.02, 0.0, 0.02, 0.0), "root_z": s(-0.04, -0.02, -0.02, -0.01),
            "hips": s(4.0, 2.0, 2.0, 0.0), "spine": s(-2.0, 4.0, 6.0, 2.0),
            "neck": s(-6.0, 6.0, 10.0, 4.0), "head": s(-2.0, 4.0, 8.0, 2.0), "jaw": s(2.0, 4.0, 4.0, 2.0),
            "fn_x": s(0.0, 0.14, 0.30, 0.22), "fn_lift": s(0.0, 0.55, 0.90, 0.50),
            "ff_x": s(0.0, 0.0, 0.0, 0.0), "ff_lift": s(0.0, 0.0, 0.0, 0.0),
        },
        # the head down and back, then tossed up and forward with the jaws opening as it lets go: a decoy, a stone, a trap
        "throw": {
            "root_x": s(-0.08, 0.02, 0.12, 0.08), "root_z": s(-0.12, -0.06, -0.02, 0.0),
            "hips": s(8.0, 4.0, -6.0, -2.0), "spine": s(-8.0, -2.0, 6.0, 2.0),
            "neck": s(-36.0, -14.0, 12.0, 4.0), "head": s(-16.0, -6.0, 8.0, 2.0), "jaw": s(0.0, 6.0, 38.0, 8.0),
            "fn_x": s(0.0, 0.0, 0.04, 0.0), "fn_lift": s(0.0, 0.0, 0.10, 0.0),
            "ff_x": s(0.0, 0.0, 0.0, 0.0), "ff_lift": s(0.0, 0.0, 0.0, 0.0),
        },
        # reared up on the hind legs with both forepaws lifted, the head back and the jaws open, held: a summons, a raising, an offer
        "summon": {
            "root_x": s(-0.06, -0.10, -0.10, -0.04), "root_z": s(0.0, 0.10, 0.12, 0.06),
            "hips": s(12.0, 16.0, 16.0, 10.0), "spine": s(14.0, 24.0, 26.0, 20.0),
            "neck": s(8.0, 30.0, 40.0, 28.0), "head": s(4.0, 26.0, 40.0, 24.0), "jaw": s(8.0, 34.0, 44.0, 24.0),
            "fn_x": s(0.0, 0.0, 0.05, 0.0), "fn_lift": s(0.4, 0.9, 1.0, 0.7),
            "ff_x": s(0.0, 0.0, 0.05, 0.0), "ff_lift": s(0.4, 0.85, 0.95, 0.65),
        },
        # the head down to the ground and the jaws lapping, the body lowered over the forepaws: to drink, devour or swallow
        "drink": {
            "root_x": s(0.0, 0.04, 0.06, 0.02), "root_z": s(-0.08, -0.14, -0.16, -0.08),
            "hips": s(4.0, 6.0, 6.0, 2.0), "spine": s(-8.0, -14.0, -16.0, -8.0),
            "neck": s(-30.0, -48.0, -52.0, -34.0), "head": s(-8.0, -18.0, -22.0, -10.0), "jaw": s(8.0, 28.0, 6.0, 26.0),
            "fn_x": s(0.0, 0.0, 0.0, 0.0), "fn_lift": s(0.0, 0.0, 0.0, 0.0),
            "ff_x": s(0.0, 0.0, 0.0, 0.0), "ff_lift": s(0.0, 0.0, 0.0, 0.0),
        },
        # the head low over the ground and a forepaw reaching out and raking back: a dig, for forging, spinning, rigging, bridging
        "craft": {
            "root_x": s(0.0, 0.04, 0.04, 0.02), "root_z": s(-0.06, -0.12, -0.14, -0.08),
            "hips": s(4.0, 6.0, 6.0, 2.0), "spine": s(-4.0, -10.0, -12.0, -6.0),
            "neck": s(-18.0, -32.0, -34.0, -22.0), "head": s(-6.0, -14.0, -16.0, -8.0), "jaw": s(2.0, 6.0, 8.0, 2.0),
            "fn_x": s(0.10, 0.30, -0.10, 0.04), "fn_lift": s(0.55, 0.35, 0.05, 0.30),
            "ff_x": s(0.0, 0.0, 0.0, 0.0), "ff_lift": s(0.0, 0.0, 0.0, 0.0),
        },
        # belly low to the ground on a creeping step, the head lowered and level, the forepaws going forward one after the other: a veil, a stalk, a swap, a blink
        "sneak": {
            "root_x": s(-0.04, 0.04, 0.10, 0.08), "root_z": s(-0.20, -0.26, -0.26, -0.16),
            "hips": s(6.0, 10.0, 10.0, 6.0), "spine": s(-6.0, -12.0, -12.0, -6.0),
            "neck": s(-14.0, -8.0, -6.0, -8.0), "head": s(-4.0, 2.0, 4.0, 0.0), "jaw": s(2.0, 4.0, 4.0, 2.0),
            "fn_x": s(0.0, 0.10, 0.22, 0.16), "fn_lift": s(0.0, 0.18, 0.12, 0.04),
            "ff_x": s(0.0, 0.20, 0.08, 0.14), "ff_lift": s(0.0, 0.04, 0.16, 0.08),
        },
        # a shake from the shoulders to the hips, the head following: a heal, a light, a soul
        "pulse": {
            "root_x": s(0.0, 0.0, 0.0, 0.0), "root_z": s(-0.04, 0.02, -0.02, 0.0),
            "hips": s(6.0, -8.0, 8.0, -4.0), "spine": s(-8.0, 8.0, -8.0, 4.0),
            "neck": s(-10.0, 14.0, -12.0, 6.0), "head": s(-6.0, 10.0, -8.0, 4.0), "jaw": s(4.0, 10.0, 4.0, 2.0),
            "fn_x": s(0.0, 0.0, 0.0, 0.0), "fn_lift": s(0.0, 0.0, 0.0, 0.0),
            "ff_x": s(0.0, 0.0, 0.0, 0.0), "ff_lift": s(0.0, 0.0, 0.0, 0.0),
        },
    })
