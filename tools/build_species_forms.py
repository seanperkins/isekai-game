"""Write data/forms/*.tres for the wolf, undead, spider and goblin forms of docs/research/species-form-branches.md.

The design doc is the source: this reads its form tables (through tools/build_evolutions.py's parser) and writes one FormDef
file per form that is not a slime form. The files may be edited by hand afterwards, like the slime's. Run from the project root:
  python3 tools/build_species_forms.py
The 24 slime files and the slime's 18 planned form-4s are not written here.
"""
import os
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_evolutions as be  # noqa: E402

OUT = "data/forms"
STAGE_BASE = {2: {"max_hp": 5, "max_mp": 3}, 3: {"max_hp": 12, "max_mp": 6, "atk": 1}, 4: {"max_hp": 22, "max_mp": 10, "atk": 2, "def": 1}}
STAGE_SIZE = {2: 1.12, 3: 1.25, 4: 1.4}
COLORS = {"water": (0.55, 0.8, 1.0), "earth": (0.9, 0.78, 0.6), "air": (0.8, 0.95, 1.0), "light": (1.0, 0.95, 0.7),
          "dark": (0.7, 0.6, 0.85), "fire": (1.0, 0.6, 0.45), "mind": (0.95, 0.7, 0.95), "blood": (0.9, 0.45, 0.5)}


def slug(name):
    """A form's name as an ASCII id part: accents folded, apostrophes dropped, other non-letters as underscores."""
    n = name.translate(str.maketrans({"ð": "d", "Ð": "d", "þ": "th", "æ": "ae", "ø": "o"}))
    n = unicodedata.normalize("NFKD", n)
    n = "".join(c for c in n if not unicodedata.combining(c))
    n = n.replace("'", "").replace("’", "")
    return re.sub(r"[^a-zA-Z0-9]+", "_", n).strip("_").lower()


def flavour(reads, stage):
    """The stat changes the elements a form reads add to its stage's base."""
    s = dict(STAGE_BASE[stage])
    late = stage >= 3

    def add(key, n):
        s[key] = s.get(key, 0) + n

    for e in reads:
        if e == "earth":
            add("def", 2 if late else 1)
        elif e == "air":
            add("spd", 12 if late else 8)
            add("jump_height", 15 if late else 10)
        elif e in ("dark", "blood", "fire"):
            add("atk", 1)
        elif e == "water":
            add("mp_regen", 40 if late else 25)
        elif e == "light":
            add("max_mp", 2)
        elif e == "mind":
            add("max_mp", 3)
    return dict(sorted(s.items()))


def tint(reads, stage):
    els = reads or ["water", "earth", "air"]
    rgb = [sum(COLORS[e][i] for e in els) / len(els) for i in range(3)]
    if stage == 4:
        rgb = [c + 0.05 for c in rgb]
    return [round(min(1.0, c), 3) for c in rgb]


def check_raw(f):
    """The doc's own cells, before the parser filters them to known names: an element or area it does not know is an error."""
    for part in f["readsText"].split("+"):
        if part.strip() not in be.ELEMENTS:
            raise ValueError("%s: reads %r, which is not an element" % (f["dataId"], part.strip()))
    for part in f["hostText"].split(","):
        if part.strip().lower() not in be.AREA_IDS:
            raise ValueError("%s: host names unknown area %r" % (f["dataId"], part.strip()))


def check_row(f):
    for e in f["reads"]:
        if e not in be.ELEMENTS:
            raise ValueError("%s: reads unknown essence %r" % (f["dataId"], e))
    if not f["host"]:
        raise ValueError("%s: names no area" % f["dataId"])
    for a in f["host"]:
        if a not in be.AREA_IDS:
            raise ValueError("%s: host names unknown area %r" % (f["dataId"], a))


def check_unique(forms):
    seen = set()
    for f in forms:
        if f["dataId"] in seen:
            raise ValueError("two forms share the id %s" % f["dataId"])
        seen.add(f["dataId"])


def species_forms():
    """The non-slime forms of the doc with their data ids, parents, lineage, stats, tint and size."""
    doc = be.parse_tables(be.read(be.DOC))
    forms = []
    for header, rows in doc:
        if header[:2] == ["ID", "Form"]:
            forms.extend(be.parse_form_rows(rows))
    forms = [f for f in forms if f["species"] != "slime"]
    ids = {f["id"]: "%s_%s" % (f["species"], slug(f["name"])) for f in forms}
    line_name = {(f["species"], f["line"]): slug(f["name"]) for f in forms if f["stage"] == 2}
    for f in forms:
        f["dataId"] = ids[f["id"]]
        check_raw(f)
        f["parents"] = [f["species"]] if f["stage"] == 2 else [ids[f["parent"]]]
        f["lineage"] = line_name[(f["species"], f["line"])]
        f["stats"] = flavour(f["reads"], f["stage"])
        f["tint"] = tint(f["reads"], f["stage"])
        f["size"] = STAGE_SIZE[f["stage"]]
        check_row(f)
    check_unique(forms)
    return forms


SLIME_LINEAGE = {"W": "weaver", "T": "tide", "X": "toxic", "B": "bulwark", "E": "echo", "G": "greater"}


def read_parent(parent_id):
    """A built slime form's traits, grants and tint, read from its file: a new form-4 inherits them."""
    text = be.read("data/forms/%s.tres" % parent_id)

    def arr(key):
        m = re.search(r"^%s = \[(.*?)\]$" % key, text, re.M)
        return re.findall(r'"([^"]+)"', m.group(1)) if m else []

    rgb = re.search(r"^tint = Color\(([^)]*)\)", text, re.M).group(1).split(",")[:3]
    return arr("traits"), arr("grants"), [float(c) for c in rgb]


def slime_forms():
    """The slime's new stage-4 forms of the doc (every slime form that is not one of the 24 built), ready to write."""
    doc = be.parse_tables(be.read(be.DOC))
    forms = []
    for header, rows in doc:
        if header[:2] == ["ID", "Form"]:
            forms.extend(be.parse_form_rows(rows))
    out = [f for f in forms if f["species"] == "slime" and f["id"] not in be.BUILT_SLIME]
    for f in out:
        f["dataId"] = slug(f["name"])
        check_raw(f)
        parent = be.BUILT_SLIME[f["parent"]]
        traits, grants, rgb = read_parent(parent)
        f["parents"] = [parent]
        f["lineage"] = SLIME_LINEAGE[f["line"]]
        f["traits"], f["grants"] = traits, grants
        f["stats"] = flavour(f["reads"], f["stage"])
        f["tint"] = [round(min(1.0, c + 0.05), 3) for c in rgb]
        f["size"] = STAGE_SIZE[f["stage"]]
        check_row(f)
    check_unique(out)
    return out


def q(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def num(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def arr(items):
    return "[%s]" % ", ".join(q(i) for i in items)


def tres(f):
    """The text of one FormDef file, laid out like data/forms/snare.tres."""
    stats = ",\n".join('"%s": %s' % (k, v) for k, v in f["stats"].items())
    r, g, b = f["tint"]
    lines = [
        '[gd_resource type="Resource" script_class="FormDef" format=3]', "",
        '[ext_resource type="Script" path="res://scripts/forms/form_def.gd" id="1_h3eka"]', "",
        "[resource]", 'script = ExtResource("1_h3eka")',
        "id = %s" % q(f["dataId"]), "display_name = %s" % q(f["name"]), "species = %s" % q(f["species"]),
        "stage = %d" % f["stage"], "lineage = %s" % q(f["lineage"]), "parents = %s" % arr(f["parents"]),
        "stats = {\n%s\n}" % stats,
    ]
    if f.get("traits"):
        lines.append("traits = %s" % arr(f["traits"]))
    if f.get("grants"):
        lines.append("grants = %s" % arr(f["grants"]))
    lines += [
        "tint = Color(%s, %s, %s, 1)" % (num(r), num(g), num(b)), "size = %s" % num(f["size"]),
        "blurb = %s" % q(f["verb"]),
        "reads = %s" % arr(f["reads"]), "host = %s" % arr(f["host"]), "source = %s" % q(f["source"]),
        "verb_text = %s" % q(f["verb"]), "gives_up = %s" % q(f["givesUp"]), "opened_by = %s" % q(f["openedBy"]),
    ]
    return "\n".join(lines) + "\n"


def build(out_dir=OUT):
    """Writes the other species' forms (the slime's new ones are build_slime)."""
    forms = species_forms()
    os.makedirs(out_dir, exist_ok=True)
    for f in forms:
        with open(os.path.join(out_dir, f["dataId"] + ".tres"), "w", encoding="utf-8") as fh:
            fh.write(tres(f))
    return [f["dataId"] for f in forms]


def build_slime(out_dir=OUT):
    forms = slime_forms()
    os.makedirs(out_dir, exist_ok=True)
    for f in forms:
        with open(os.path.join(out_dir, f["dataId"] + ".tres"), "w", encoding="utf-8") as fh:
            fh.write(tres(f))
    return [f["dataId"] for f in forms]


if __name__ == "__main__":
    print("wrote %d forms and %d new slime forms to %s" % (len(build()), len(build_slime()), OUT))
