"""Which kind of verb each form casts (tools/form_verbs.json, built by tools/build_form_verbs.py), so a creature's attack animation can follow it. Pure Python."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ENEMY_KINDS = ("bolt", "burst", "ring", "dash", "zone", "mark", "pull", "aura", "chain", "heal", "ward", "buff", "rage", "blink", "devour", "summon")   # scripts/abilities/verb_kinds.gd


def rows(path=None):
    """Every verb row of tools/form_verbs.json."""
    with open(path or os.path.join(ROOT, "tools", "form_verbs.json")) as fh:
        return json.load(fh)


def table(path=None):
    """{form id: verb kind} for every form that has a verb; the form id is `<species>_<form>` (a slime form is its bare name)."""
    return {v["form"]: v["spec"].get("kind") for v in rows(path)}


def kind_of(form_id, kinds=None):
    """The kind of the verb `form_id` casts, or None when it has none or an enemy does not cast it."""
    kind = (kinds if kinds is not None else table()).get(form_id)
    return kind if kind in ENEMY_KINDS else None


def anim_of(form_id, path=None):
    """The gesture the verb `form_id` casts plays (verb_anims.py): the row's own `anim` where it says one, else its kind's; None when the form has no verb."""
    import verb_anims
    for row in rows(path):
        if row["form"] == form_id:
            return row.get("anim") or verb_anims.archetype_of(row["spec"]["kind"])
    return None


def kind_any(form_id, path=None):
    """The kind of the verb `form_id` casts, an enemy's or a player's, or None when it has none."""
    return table(path).get(form_id)
