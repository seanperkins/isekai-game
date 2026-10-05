"""Writes the parts a body can carry or wear (tools/parts.json) as data/parts/*.tres.

Run from the repo root:  python3 tools/build_parts.py
A row is {id, name, kind (graft, held or key), slot, worn_max, stats, color, text}; the validator in scripts/items/part_validator.gd checks
the written files. The drops that name these parts are on the creatures (tools/build_creatures.py).
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROWS = os.path.join(HERE, "parts.json")
OUT = "data/parts"
KINDS = ["graft", "held", "key"]
SCRIPT_ID = "1_part"


def load_rows(path=ROWS):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def check_rows(rows):
    seen = set()
    for r in rows:
        if r["kind"] not in KINDS:
            raise ValueError("%s: unknown kind %r" % (r["id"], r["kind"]))
        if r["id"] in seen:
            raise ValueError("two rows for %s" % r["id"])
        seen.add(r["id"])
        if r["kind"] == "graft" and not r["slot"]:
            raise ValueError("%s: a graft needs a slot" % r["id"])
        if r["kind"] != "graft" and r["slot"]:
            raise ValueError("%s: only a graft has a slot" % r["id"])
        if len(r["color"]) != 3:
            raise ValueError("%s: a colour is three numbers" % r["id"])


def q(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def num(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def tres(row):
    """The text of one PartDef file."""
    lines = ['[gd_resource type="Resource" script_class="PartDef" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/items/part_def.gd" id="%s"]' % SCRIPT_ID, "",
             "[resource]", 'script = ExtResource("%s")' % SCRIPT_ID, "id = %s" % q(row["id"]), "display_name = %s" % q(row["name"]),
             "kind = %s" % q(row["kind"])]
    if row["slot"]:
        lines.append("slot = %s" % q(row["slot"]))
    lines.append("worn_max = %d" % row["worn_max"])
    if row["stats"]:
        lines.append("stats = {%s}" % ", ".join("%s: %d" % (q(k), v) for k, v in sorted(row["stats"].items())))
    lines.append("text = %s" % q(row["text"]))
    lines.append("color = Color(%s, %s, %s, 1)" % tuple(num(c) for c in row["color"]))
    return "\n".join(lines) + "\n"


def build(out_dir=OUT):
    rows = load_rows()
    check_rows(rows)
    os.makedirs(out_dir, exist_ok=True)
    for r in rows:
        with open(os.path.join(out_dir, r["id"] + ".tres"), "w", encoding="utf-8") as fh:
            fh.write(tres(r))
    return rows


if __name__ == "__main__":
    print("wrote %d parts to %s" % (len(build()), OUT))
