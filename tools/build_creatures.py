"""Writes the world twins and the support monsters as creature data, so every form can be met in the world.

  data/creatures/twin_<form>.tres   one per form whose twin is a new creature (140)
  data/creatures/<id>.tres          the design doc's support monsters (29)
  scripts/core/menagerie_ids.gd     their ids, for Sources.ALL

Run from the repo root:  python3 tools/build_creatures.py
The rows come from the design doc through build_evolutions.collect() (tiers, essences, roles) and from data/forms (verb, art).
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_evolutions as be  # noqa: E402

OUT = "data/creatures"
IDS = "scripts/core/menagerie_ids.gd"
SCRIPT_ID = "1_hf3fk"  # the ext_resource id the shipped creature files use

# Stats by stage, calibrated on lizard 5/5/1/80, taratect 24/9/2/120 and the stone drake 28/7/5/40; speed shifts by species.
STAGE_STATS = {2: {"max_hp": 6, "atk": 3, "def": 1, "spd": 90}, 3: {"max_hp": 14, "atk": 5, "def": 2, "spd": 90},
               4: {"max_hp": 26, "atk": 8, "def": 3, "spd": 100}}
SPEED = {"wolf": 20, "spider": 10, "undead": -20, "slime": -20, "goblin": 0}
SPECIES_FLAGS = {"wolf": {"pack": True, "charges": True}, "goblin": {"pack": True}}
# A support monster's stats by the design table's role.
ROLE_STATS = {"common": {"max_hp": 4, "atk": 3, "def": 0, "spd": 90}, "rare": {"max_hp": 8, "atk": 4, "def": 1, "spd": 90},
              "elite": {"max_hp": 14, "atk": 5, "def": 2, "spd": 90}}
ELEMENT_TINT = {"water": [0.45, 0.65, 1.0], "earth": [0.75, 0.6, 0.4], "air": [0.8, 0.92, 1.0], "light": [1.0, 0.95, 0.6],
                "dark": [0.55, 0.45, 0.65], "fire": [1.0, 0.55, 0.3], "mind": [0.85, 0.65, 1.0], "blood": [0.9, 0.3, 0.35]}

# What a support monster looks like until it has art: a sheet and frame that exist, or a shipped creature it wears, tinted by its element.
SUPPORT_SET = {"wild_slime": ("slime", "idle_1"), "skeleton": ("forms_undead", "skeleton"), "village_goblin": ("goblin", "idle_1")}
SUPPORT_WEARS = {
    "cave_rat": "lizard", "junk": "mushroom_crab", "firefly_swarm": "pale_moth", "moon_hare": "toad", "tusker_boar": "stone_drake", "blood_leech": "vine_snake",
    "bog_wisp": "pale_moth", "goblin_shaman": "bog_lizardman", "candle_wisp": "spore_moth", "chapel_priest": "bog_lizardman",
    "stained_glass_moth": "pale_moth", "shield_guard": "stone_drake", "gargoyle": "spider", "ghost": "drift_jelly", "carrion_crow": "bat",
    "vampire_bat": "bat", "bone_hound": "gloom_wolf", "ember_beetle": "mushroom_crab", "lava_salamander": "lizard", "ash_moth": "spore_moth",
    "imp": "bat", "demon_hound": "gloom_wolf", "caller": "bog_lizardman", "blinker": "pale_moth", "ward_bearer": "stone_drake",
    "rider": "bog_lizardman"}
# The kit a support monster's description names, where the existing enemy kinds can do it.
# The three support monsters that are a species' base creature: eating one counts as eating that species.
SUPPORT_SPECIES = {"wild_slime": "slime", "skeleton": "undead", "village_goblin": "goblin"}
SUPPORT_FLAGS = {"shield_guard": {"armored_charger": True}, "ghost": {"drifter": True}, "bone_hound": {"pack": True, "charges": True},
                 "demon_hound": {"charges": True}}
FLAG_ORDER = ["armored_charger", "drifter", "pack", "charges"]
# What the creatures leave (design doc, the parts table). The two shipped creatures that leave claws are edited by hand in their files.
SUPPORT_DROPS = {"skeleton": [("ribs", 0.25), ("skull", 0.4)], "village_goblin": [("bow_arm", 0.25)], "shield_guard": [("weapon_arm", 0.3)],
                 "goblin_shaman": [("focus", 0.3)], "chapel_priest": [("focus", 0.3)], "moon_hare": [("moonstone", 0.15)]}
TWIN_DROPS = {"twin_undead_zombie": [("ribs", 0.3), ("flesh", 0.3)], "twin_undead_ghoul": [("ribs", 0.3), ("flesh", 0.3), ("claw", 0.3)],
              "twin_undead_bone_warrior": [("weapon_arm", 0.3)], "twin_undead_draugr": [("weapon_arm", 0.3)],
              "twin_undead_skeletal_archer": [("bow_arm", 0.3)], "twin_undead_mummy_priest": [("wrappings", 0.3)],
              "twin_undead_lich": [("phylactery_shard", 0.1)]}


def form_art(form_id):
    """data/forms/<id>.tres -> (verb, sprite_set, sprite_frame, size, tint) of the form."""
    with open("data/forms/%s.tres" % form_id, encoding="utf-8") as fh:
        text = fh.read()

    def one(pattern):
        m = re.search(pattern, text, re.M)
        return m.group(1) if m else ""
    tint = re.search(r"^tint = Color\(([^)]*)\)", text, re.M)
    rgb = [float(x) for x in tint.group(1).split(",")][:3] if tint else [1.0, 1.0, 1.0]
    size = one(r"^size = ([\d.]+)")
    return one(r'^verb = "(\w+)"'), one(r'^sprite_set = "(\w+)"'), one(r'^sprite_frame = "(\w+)"'), float(size) if size else 1.0, rgb


def twin_rows(data):
    rows = []
    for f in data["forms"]:
        t = f["twin"]
        if t["status"] != "new":
            continue
        form_id = be.data_id(f)
        verb, sheet, frame, size, tint = form_art(form_id)
        stats = dict(STAGE_STATS[f["stage"]])
        stats["spd"] += SPEED[f["species"]]
        rows.append({"id": "twin_" + form_id, "name": f["name"], "origin": "twin", "species": f["species"], "stage": f["stage"],
                     "role": t["role"], "form": form_id, "verb": verb, "stats": stats, "essences": dict(t["essence"]), "xp": t["xp"],
                     "flags": dict(SPECIES_FLAGS.get(f["species"], {})), "areas": t["areas"],
                     # a form with a still wears it; one without (the slime's) is the slime tinted, as the player draws it
                     "drops": TWIN_DROPS.get("twin_" + form_id, []),
                     "sprite_set": sheet or "slime", "sprite_frame": frame or "idle_1", "wears": "",
                     "sprite_size": size, "sprite_tint": [1.0, 1.0, 1.0] if sheet else tint})
    return rows


def support_rows(data):
    rows = []
    for c in data["creatures"]:
        if c["kind"] != "support":
            continue
        role = c["role"] if c["role"] in ROLE_STATS else "common"
        dominant = max(c["essence"], key=lambda e: c["essence"][e])
        row = {"id": c["id"], "name": c["name"], "origin": "support", "species": SUPPORT_SPECIES.get(c["id"], ""), "stage": 0, "role": c["role"], "form": "", "verb": "",
               "stats": dict(ROLE_STATS[role]), "essences": dict(c["essence"]), "xp": c["xp"], "flags": dict(SUPPORT_FLAGS.get(c["id"], {})),
               "areas": c["areas"], "drops": SUPPORT_DROPS.get(c["id"], []),
               "sprite_set": "", "sprite_frame": "", "wears": "", "sprite_size": 1.0, "sprite_tint": [1.0, 1.0, 1.0]}
        if c["id"] in SUPPORT_SET:
            row["sprite_set"], row["sprite_frame"] = SUPPORT_SET[c["id"]]
        else:
            row["wears"] = SUPPORT_WEARS[c["id"]]
            row["sprite_tint"] = ELEMENT_TINT[dominant]
        rows.append(row)
    return rows


def creature_rows():
    """Every twin and support monster as a row, in the design doc's order (twins first)."""
    data = be.collect()
    return twin_rows(data) + support_rows(data)


def q(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def num(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def dictionary(d):
    return "{\n%s\n}" % ",\n".join("%s: %s" % (q(k), d[k]) for k in sorted(d))


def tres(row):
    """The text of one CreatureDef file, laid out like data/creatures/gloom_wolf.tres."""
    lines = ['[gd_resource type="Resource" script_class="CreatureDef" format=3]', "",
             '[ext_resource type="Script" path="res://scripts/skills/creature_def.gd" id="%s"]' % SCRIPT_ID, "",
             "[resource]", 'script = ExtResource("%s")' % SCRIPT_ID, "id = %s" % q(row["id"]), "display_name = %s" % q(row["name"]),
             "stats = %s" % dictionary(row["stats"]), "essences = %s" % dictionary(row["essences"]), "xp = %d" % row["xp"]]
    for flag in FLAG_ORDER:
        if row["flags"].get(flag):
            lines.append("%s = true" % flag)
    if row["drops"]:
        lines.append("drops = [%s]" % ", ".join('{"part": %s, "chance": %s}' % (q(p), num(c)) for p, c in row["drops"]))
    lines.append("origin = %s" % q(row["origin"]))
    if row["stage"]:
        lines.append("stage = %d" % row["stage"])
    for key, field in (("form", "form"), ("species", "species"), ("role", "role"), ("verb", "verb"), ("sprite_set", "sprite_set"),
                       ("sprite_frame", "sprite_frame"), ("wears", "wears")):
        if row[field]:
            lines.append("%s = %s" % (key, q(row[field])))
    if row["sprite_size"] != 1.0:
        lines.append("sprite_size = %s" % num(row["sprite_size"]))
    if row["sprite_tint"] != [1.0, 1.0, 1.0]:
        lines.append("sprite_tint = Color(%s, %s, %s, 1)" % tuple(num(x) for x in row["sprite_tint"]))
    return "\n".join(lines) + "\n"


def ids_gd(rows):
    """scripts/core/menagerie_ids.gd: the ids by origin."""
    def block(name, ids):
        return "const %s := [\n%s\n]\n" % (name, ",\n".join("\t" + q(i) for i in ids))
    return ("class_name MenagerieIds\nextends RefCounted\n"
            "## Generated by tools/build_creatures.py: the world twins and the support monsters, in the design doc's order.\n\n"
            + block("TWINS", [r["id"] for r in rows if r["origin"] == "twin"]) + "\n"
            + block("SUPPORT", [r["id"] for r in rows if r["origin"] == "support"]) + "\nconst ALL := TWINS + SUPPORT\n")


def build(out_dir=OUT, ids_path=IDS):
    """Writes every creature file and the id list; returns the rows."""
    rows = creature_rows()
    os.makedirs(out_dir, exist_ok=True)
    for r in rows:
        with open(os.path.join(out_dir, r["id"] + ".tres"), "w", encoding="utf-8") as fh:
            fh.write(tres(r))
    with open(ids_path, "w", encoding="utf-8") as fh:
        fh.write(ids_gd(rows))
    return rows


if __name__ == "__main__":
    print("wrote %d creatures to %s and %s" % (len(build()), OUT, IDS))
