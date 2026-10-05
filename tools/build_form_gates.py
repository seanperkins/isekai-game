"""The gates of the wolf, undead, spider and goblin forms: what opens each one, as data a run's ledger can satisfy.

  tools/form_gates.json   one row per non-slime form: the deed atoms its "Opened by" text asks for
  data/forms/*.tres       each form's `gate` = its essence atoms (from its `reads` and stage) plus its row's atoms

tools/build_species_forms.py calls gate_for() when it writes a form. An atom is `{"kind", "event", "tags", "n", "text"}` (kinds counter,
streak, skill_level, held and any, see scripts/forms/form_gate.gd); the events and tags are the game's (scripts/core/deeds.gd),
which GUT checks against every written gate. A deed with no emitter yet is in Deeds.RESERVED.
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROWS = os.path.join(HERE, "form_gates.json")
# The essence a form asks for in all, by stage, split evenly over its `reads` (the slime offers at 24 to 26).
TOTAL = {2: 26, 3: 34, 4: 44}
KINDS = ["counter", "streak", "skill_level", "held", "any"]


def load_rows(path=ROWS):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def essence_atoms(reads, stage):
    """One `absorbed` counter per element the form reads: the stage's total split evenly (rounded up)."""
    n = math.ceil(TOTAL[stage] / len(reads))
    return [{"kind": "counter", "event": "absorbed", "tags": {"essence": e}, "n": n, "text": "%s essence" % e} for e in reads]


def check_atom(atom, where):
    """The shape of a deed atom. The vocabulary (events and tags) is checked in the game's own test, against Deeds."""
    kind = atom.get("kind")
    if kind not in KINDS:
        raise ValueError("%s: unknown kind %r" % (where, kind))
    if not atom.get("text"):
        raise ValueError("%s: no text" % where)
    if kind == "any":
        if not atom.get("of"):
            raise ValueError("%s: an any needs members" % where)
        for member in atom["of"]:
            check_atom(dict(member, text=member.get("text", "member")), where + " (member)")
        return
    if int(atom.get("n", 0)) < 1:
        raise ValueError("%s: n must be at least 1" % where)
    if kind in ("counter", "streak") and not atom.get("event"):
        raise ValueError("%s: no event" % where)


def check_rows(rows, form_ids):
    """One row per form, each naming a real form, every atom well shaped."""
    seen = set()
    for r in rows:
        if r["form"] not in form_ids:
            raise ValueError("form_gates.json: unknown form '%s'" % r["form"])
        if r["form"] in seen:
            raise ValueError("form_gates.json: two rows for '%s'" % r["form"])
        seen.add(r["form"])
        for i, atom in enumerate(r["atoms"]):
            check_atom(atom, "%s atom %d" % (r["form"], i + 1))
    missing = sorted(set(form_ids) - seen)
    if missing:
        raise ValueError("form_gates.json: no row for %s" % ", ".join(missing))


def gate_for(form, by_form):
    """A form's whole gate: its essence atoms, then its row's deed atoms."""
    return essence_atoms(form["reads"], form["stage"]) + by_form[form["dataId"]]["atoms"]


def variant(v):
    """Godot's text form of a value (what a .tres line holds): dictionaries, arrays, strings, booleans and numbers."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"')
    if isinstance(v, dict):
        return "{%s}" % ", ".join("%s: %s" % (variant(k), variant(x)) for k, x in v.items())
    if isinstance(v, list):
        return "[%s]" % ", ".join(variant(x) for x in v)
    return str(v)
