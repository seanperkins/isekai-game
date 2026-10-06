"""The gesture a verb's animation plays, by the kind of verb it is (tools/verb_anims.json). Pure Python.

A gesture is one of a few shared body motions (a slam, a roar, a point, a throw ...); each rig family authors them as presets in its own attack tables, so a form that casts a
`ring` and one that casts a `burst` raise their hands and bring them down whatever they are. The kinds are the game's (scripts/abilities/verb_kinds.gd KINDS); a kind added there
has to be given a gesture here, and tests/test_verb_anims.gd and test_verb_anims.py fail until it is.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))

# the vocabulary: what the body does, in the order the families author them
ARCHETYPES = (
    "cast",     # the free hand and the focus raised, then thrown forward with the chest behind it: a bolt, a chain, a pull
    "slam",     # both hands overhead, brought down together as the body drops: a burst or a ring
    "roar",     # the chest thrown back and the head up, the arms flung out: a howl, a call, a rage
    "lunge",    # a crouch and a spring forward with the whole body behind the arms: a dash, a chase
    "guard",    # braced low behind the forearms: a ward, a zone
    "claw",     # a clawed hand raised and cut down across the body: a tearing blow
    "point",    # one arm straight out along the line of sight, the chest turned into it: a mark, a hunt, a fate
    "throw",    # an overhand toss, the step forward: a decoy, a stone, a trap
    "summon",   # both arms raised palms up, the head back: a summons, a raising, an offer
    "drink",    # a hand to the mouth, the head tipped back: to drink, devour or swallow
    "craft",    # a deep crouch, both hands working low in front: forging, spinning, rigging, bridging
    "sneak",    # low and forward, one hand trailing: a veil, a stalk, a swap, a blink
    "pulse",    # the hands drawn to the chest, then opened outward: a heal, a light, a soul
)


def table(path=None):
    """{verb kind: archetype} as tools/verb_anims.json has it."""
    with open(path or os.path.join(ROOT, "tools", "verb_anims.json")) as fh:
        return json.load(fh)["kinds"]


def archetype_of(kind, kinds=None):
    """The gesture a verb of this kind plays; a KeyError for a kind the table does not know (that is a missing row, not a default)."""
    return (kinds if kinds is not None else table())[kind]
