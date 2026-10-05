#!/usr/bin/env python3
"""Writes a skill file for every form verb in tools/form_verbs.json into data/skills/ (source "form_verb").
tools/build_species_forms.py gives each form its `verb` and the grant. The table is the one place a verb's cost, damage value and
spec live; `fidelity` says how much of the design doc's verb text the spec does (full, approx, needs) and `note` says what is missing.

Run from the repo root:  python3 tools/build_form_verbs.py
"""
import glob
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "form_verbs.json")
OUT = "data/skills"
SCENE = "res://scenes/abilities/verb.tscn"
FIDELITY = ("full", "approx", "needs")
PREFIX = "verb_"


def load_rows(path=TABLE):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def skill_id(form):
    return PREFIX + form


def q(text):
    return json.dumps(text, ensure_ascii=False)


def skill_tres(row):
    """The text of one SkillDef file: an active whose spec the verb scene runs. No unlock: the form grants it."""
    effect = {"kind": "active", "scene": SCENE, "values": [row["value"]], "spec": row["spec"]}
    lines = [
        '[gd_resource type="Resource" script_class="SkillDef" format=3]', "",
        '[ext_resource type="Script" path="res://scripts/skills/skill_def.gd" id="1_rpc81"]', "",
        "[resource]", 'script = ExtResource("1_rpc81")',
        "id = %s" % q(skill_id(row["form"])), "display_name = %s" % q(row["name"]),
        "description = %s" % q(row["text"]), "announce = %s" % q("New verb. Acquired [%s]." % row["name"]),
        'source = "form_verb"', "effects = [%s]" % json.dumps(effect, ensure_ascii=False), "mp_cost = %d" % row["mp"],
    ]
    return "\n".join(lines) + "\n"


def build(out_dir=OUT, rows=None):
    """Writes every verb's file and removes the verb files the table no longer has. Returns the skill ids."""
    rows = load_rows() if rows is None else rows
    os.makedirs(out_dir, exist_ok=True)
    ids = []
    for row in rows:
        ids.append(skill_id(row["form"]))
        with open(os.path.join(out_dir, ids[-1] + ".tres"), "w", encoding="utf-8") as fh:
            fh.write(skill_tres(row))
    for path in glob.glob(os.path.join(out_dir, PREFIX + "*.tres")):
        if os.path.basename(path)[:-5] not in ids:
            os.remove(path)
    return ids


if __name__ == "__main__":
    print("wrote %d form verbs to %s" % (len(build()), OUT))
