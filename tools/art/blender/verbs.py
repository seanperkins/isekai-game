"""Which kind of verb each form casts (tools/form_verbs.json, built by tools/build_form_verbs.py), so a creature's attack animation can follow it. Pure Python."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ENEMY_KINDS = ("bolt", "burst", "ring", "dash", "zone", "mark", "pull", "aura", "chain", "heal", "ward", "buff", "rage", "blink", "devour", "summon")   # scripts/abilities/verb_kinds.gd


def table(path=None):
    """{form id: verb kind} for every form that has a verb; the form id is `<species>_<form>` (a slime form is its bare name)."""
    with open(path or os.path.join(ROOT, "tools", "form_verbs.json")) as fh:
        return {v["form"]: v["spec"].get("kind") for v in json.load(fh)}


def kind_of(form_id, kinds=None):
    """The kind of the verb `form_id` casts, or None when it has none or an enemy does not cast it."""
    kind = (kinds if kinds is not None else table()).get(form_id)
    return kind if kind in ENEMY_KINDS else None


def anim_of(form_id, kinds=None):
    """The gesture the verb `form_id` casts plays (verb_anims.py), or None when it has no verb."""
    import verb_anims
    kind = (kinds if kinds is not None else table()).get(form_id)
    return verb_anims.archetype_of(kind) if kind else None
