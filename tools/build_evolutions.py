"""Build the evolutions page's data: every form of every species, its world twin, the extra monsters and the essences.

Reads docs/research/species-form-branches.md (the form tables of sections 3 to 8 and the world tables of section 10),
data/creatures/*.tres, data/rooms/*.tres, data/forms/*.tres and assets/sheets/*.json, and writes
  docs/evolutions/evolutions-data.js   window.EVOLUTIONS = {...}  (a script, not JSON, so the page also opens from a file)
Run from the project root, no arguments:  python3 tools/build_evolutions.py
The document is the source of truth: change a table there and re-run this. Nothing here is a game rule; it is a review page.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import time

DOC = "docs/research/species-form-branches.md"
OUT = "docs/evolutions"
ELEMENTS = ["water", "earth", "air", "light", "dark", "fire", "mind", "blood"]
LATER = {"fire", "mind", "blood"}  # elements no shipped creature carries yet
AREAS = [  # id, name, built (a shipped area with rooms)
    ("cave", "Cave", True), ("grotto", "Grotto", True), ("flooded", "Flooded Tunnels", True), ("deep", "The Deep", True),
    ("forest", "Forest", False), ("swamp", "Swamp", False), ("village", "Goblin village", False), ("sacred", "Sacred hall", False),
    ("cemetery", "Cemetery", False), ("crypt", "Crypt", False), ("volcano", "Volcano", False), ("demon", "Demon area", False),
]
AREA_IDS = [a[0] for a in AREAS]
# The rooms the calibration walks (tools/calibrate_essences.gd): a room the editor adds later is not part of the supply numbers.
SHIPPED = ["C1", "C2", "C3", "C4", "C5", "C6", "G1", "G2", "G3", "G4", "G5", "F1", "F2", "F3", "F4", "F5", "F6",
           "D1", "D2", "D3", "D4", "D5", "D6"]
SPECIES = [  # id, form-id letter, name, archetype, how it gets essence, base form name
    ("slime", "J", "Slime", "bouncer", "devours everything; parts sit in slots", "Slime"),
    ("wolf", "W", "Wolf", "quadruped", "devours living things; the pounce is the kill verb", "Pup"),
    ("undead", "U", "Undead", "biped", "drains life force; grafts parts from corpses", "Skeleton"),
    ("spider", "S", "Spider", "crawler", "devours living things; carries items in cocoons", "Spiderling"),
    ("goblin", "G", "Goblin", "biped", "learns instead of devouring; every form uses items", "Scrapper"),
]
LETTER_TO_SPECIES = {s[1]: s[0] for s in SPECIES}
DEFAULT_FRAMES = ("idle_1", "hang_1", "fly_1", "hover_1", "swim_1", "drift_1", "slither_1", "idle")
FORM_ID = re.compile(r"^([JWUSG])([234])([A-Z])(\d?)([a-z]?)$")
ELEMENT_RE = re.compile(r"\b(" + "|".join(ELEMENTS) + r")\b")


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def clean(text):
    """Markdown to plain text: bold, code and italic marks off."""
    text = re.sub(r"\*\*|`", "", text)
    return re.sub(r"\*(\w[^*]*)\*", r"\1", text)


def split_row(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse_tables(text):
    """Every markdown table in the text as (header cells, [row cells])."""
    lines = text.split("\n")
    tables = []
    i = 0
    while i < len(lines):
        if lines[i].startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s\-|:]+\|$", lines[i + 1]):
            header = split_row(lines[i])
            i += 2
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(split_row(lines[i]))
                i += 1
            tables.append((header, rows))
        else:
            i += 1
    return tables


def table_with(tables, *header_start):
    for header, rows in tables:
        if tuple(header[: len(header_start)]) == header_start:
            return rows
    raise SystemExit("no table starting with %s in %s" % (list(header_start), DOC))


def parse_reads(text):
    """(elements, mixed): the elements a form reads, in order. 'all five' is the five shipped elements; a mixed diet reads three."""
    t = text.lower()
    if "all five" in t:
        return ["water", "earth", "air", "light", "dark"], False
    els = []
    for e in ELEMENT_RE.findall(t):
        if e not in els:
            els.append(e)
    if not els:
        return ["water", "earth", "air"], True
    return els, False


def parse_essence(text):
    """'water 1, earth 1' -> {'water': 1, 'earth': 1}."""
    out = {}
    for part in text.split(","):
        m = re.match(r"^\s*([a-z]+)\s+(\d+)\s*$", part)
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


def parse_areas(text):
    out = []
    for part in text.split(","):
        a = part.strip().lower()
        if a in AREA_IDS and a not in out:
            out.append(a)
    return out


def split_essence(elements, total):
    """The tier's total split evenly across the elements; the remainder goes to the first ones."""
    base, rem = divmod(total, len(elements))
    return {e: base + (1 if i < rem else 0) for i, e in enumerate(elements)}


def parent_id(fid):
    m = FORM_ID.match(fid)
    sp, stage, line, digit = m.group(1), int(m.group(2)), m.group(3), m.group(4)
    if stage == 2:
        return sp + "1"
    if stage == 3:
        return "%s2%s" % (sp, line)
    return "%s3%s%s" % (sp, line, digit)


def parse_form_rows(rows):
    forms = []
    for r in rows:
        if len(r) != 9 or not FORM_ID.match(r[0]):
            continue
        fid, cell, source, reads, verb, gives_up, opened, host, profile = r
        name = re.search(r"\*\*(.+?)\*\*", cell).group(1)
        notes = [n.lower() for n in re.findall(r"\(([^)]*)\)", cell)]
        els, mixed = parse_reads(reads)
        m = FORM_ID.match(fid)
        forms.append({
            "id": fid, "species": LETTER_TO_SPECIES[m.group(1)], "stage": int(m.group(2)), "line": m.group(3), "parent": parent_id(fid),
            "name": name, "ask": "★" in cell, "built": any("built" in n for n in notes),
            "decided": any("decided" in n for n in notes), "secret": any("secret" in n for n in notes),
            "source": clean(source), "reads": els, "readsText": clean(reads), "mixed": mixed,
            "later": [e for e in els if e in LATER], "verb": clean(verb), "givesUp": clean(gives_up), "openedBy": clean(opened),
            "host": parse_areas(host), "profile": clean(profile),
        })
    return forms


def read_creatures():
    """data/creatures/*.tres -> id -> {name, essences, xp, untackleable}."""
    out = {}
    for path in sorted(glob.glob("data/creatures/*.tres")):
        text = read(path)
        cid = os.path.basename(path)[:-5]
        name = re.search(r'display_name = "([^"]+)"', text)
        ess = {}
        block = re.search(r"essences = \{(.*?)\}", text, re.S)
        if block:
            ess = {k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', block.group(1))}
        xp = re.search(r"^xp = (\d+)", text, re.M)
        out[cid] = {"id": cid, "name": name.group(1) if name else cid.replace("_", " ").title(), "essence": ess,
                    "xp": int(xp.group(1)) if xp else 0, "untackleable": "untackleable = true" in text}
    return out


def read_spawns():
    """area -> creature id -> count, over the shipped rooms."""
    out = {}
    for rid in SHIPPED:
        text = read("data/rooms/%s.tres" % rid)
        area = re.search(r'^area = "(\w+)"', text, re.M).group(1)
        m = re.search(r"\nspawns = \[(.*?)\n?\]\n", text, re.S)
        for cid in re.findall(r'"id": "(\w+)"', m.group(1)) if m else []:
            out.setdefault(area, {}).setdefault(cid, 0)
            out[area][cid] += 1
    return out


def read_sprites():
    """sheet id -> {image, rect} for the frame the bestiary shows by default. The sheets are copied next to the page (copy_sprites)."""
    out = {}
    for path in sorted(glob.glob("assets/sheets/*.json")):
        sid = os.path.basename(path)[:-5]
        if not os.path.exists("assets/sheets/%s.png" % sid):
            continue
        frames = json.loads(read(path))["frames"]
        name = next((f for f in DEFAULT_FRAMES if f in frames), next(iter(frames)))
        out[sid] = {"image": "sprites/%s.png" % sid, "rect": frames[name]["rect"]}
    return out


def copy_sprites(used):
    os.makedirs(os.path.join(OUT, "sprites"), exist_ok=True)
    for sid in sorted(used):
        shutil.copyfile("assets/sheets/%s.png" % sid, os.path.join(OUT, "sprites", "%s.png" % sid))


def read_forms_data():
    """data/forms/*.tres -> id -> {tint, size, sprite_set} for the slime forms that exist."""
    out = {}
    for path in sorted(glob.glob("data/forms/*.tres")):
        text = read(path)
        fid = os.path.basename(path)[:-5]
        tint = re.search(r"tint = Color\(([^)]*)\)", text)
        size = re.search(r"^size = ([\d.]+)", text, re.M)
        sheet = re.search(r'sprite_set = "(\w+)"', text)
        out[fid] = {"tint": [float(x) for x in tint.group(1).split(",")][:3] if tint else [1, 1, 1],
                    "size": float(size.group(1)) if size else 1.0, "sheet": sheet.group(1) if sheet else None}
    return out


# The built slime forms by the id of this document's form (data/forms/<id>.tres).
BUILT_SLIME = {"J2W": "weaver", "J3W1": "snare", "J4W1a": "silkbound", "J3W2": "arachne", "J2T": "tide", "J3T1": "brook",
               "J4T1a": "tidal", "J3T2": "tempest", "J2X": "toxic", "J3X1": "acid", "J4X1a": "venom", "J3X2": "blight",
               "J2B": "bulwark", "J3B1": "golem", "J4B1a": "stone", "J3B2": "crystal", "J2E": "echo", "J3E1": "phantom",
               "J4E2a": "storm", "J3E2": "sky", "J2G": "greater_slime", "J3G1": "vast", "J4G1a": "prime", "J3G2": "radiant"}
BASE_SPRITE = {"J1": "slime", "W1": "gloom_wolf", "S1": "spider", "G1": "goblin"}


def build():
    text = read(DOC)
    tables = parse_tables(text)

    tiers = {}
    for r in table_with(tables, "Stage", "Appears as", "Spawn", "Essence", "XP"):
        tiers[int(r[0])] = {"appears": r[1], "spawn": r[2], "essence": int(r[3]), "xp": int(r[4])}

    forms = []
    for header, rows in tables:
        if header[:2] == ["ID", "Form"]:
            forms.extend(parse_form_rows(rows))
    by_id = {f["id"]: f for f in forms}

    existing = read_creatures()
    spawns = read_spawns()
    sprites = read_sprites()
    form_data = read_forms_data()

    twin_existing = {}  # form or base id -> existing creature id
    for r in table_with(tables, "Creature id", "Twin of", "Note"):
        twin_existing[r[1].split()[0]] = r[0]

    support = []
    for r in table_with(tables, "ID", "Creature", "Area", "Role", "Essence", "XP", "Twin of", "Why it is needed"):
        support.append({"id": r[0], "name": r[1], "areas": parse_areas(r[2]), "role": r[3], "essence": parse_essence(r[4]),
                        "xp": int(r[5]), "twinOf": r[6], "why": clean(r[7])})
    parts = [{"part": r[0], "from": r[1], "usedFor": r[2]} for r in table_with(tables, "Part", "Dropped by", "Used for")]
    arrival = [{"essence": r[0], "arrives": r[1], "sources": r[2], "note": r[3]}
               for r in table_with(tables, "Essence", "Arrives in", "First sources", "Note")]
    overrides = {r[0]: {"role": r[1], "note": r[2]} for r in table_with(tables, "ID", "Role in the world", "Note")}

    # Species bases (form 1).
    bases = {}
    for sid, letter, name, arch, how, base_name in SPECIES:
        bases[letter + "1"] = {"id": letter + "1", "species": sid, "stage": 1, "name": base_name, "parent": None}
    sup_by_twin = {s["twinOf"]: s for s in support if s["twinOf"]}

    def twin_for(node):
        """The world twin of a form or base: an existing creature, a support monster (a base), or a tier-derived new creature."""
        nid = node["id"]
        if nid in twin_existing:
            c = existing[twin_existing[nid]]
            return {"status": "existing", "creature": c["id"], "name": c["name"], "role": "existing creature", "areas": [a for a in AREA_IDS if c["id"] in spawns.get(a, {})],
                    "essence": c["essence"], "xp": c["xp"], "note": ""}
        if nid in sup_by_twin:
            s = sup_by_twin[nid]
            return {"status": "new", "creature": s["id"], "name": s["name"], "role": s["role"], "areas": s["areas"], "essence": s["essence"], "xp": s["xp"], "note": s["why"]}
        t = tiers[node["stage"]]
        els = node["reads"]
        ov = overrides.get(nid)
        return {"status": "new", "creature": None, "name": node["name"], "role": ov["role"] if ov else t["appears"], "areas": node["host"],
                "essence": split_essence(els, t["essence"]), "xp": t["xp"], "note": ov["note"] if ov else t["spawn"]}

    for f in forms:
        f["twin"] = twin_for(f)
        f["children"] = [c["id"] for c in forms if c["parent"] == f["id"]]
        if f["id"] in BUILT_SLIME:
            fd = form_data.get(BUILT_SLIME[f["id"]], {})
            f["art"] = {"tint": fd.get("tint"), "size": fd.get("size"), "sheet": fd.get("sheet")}
    for b in bases.values():
        b["twin"] = twin_for(b)
        b["children"] = [f["id"] for f in forms if f["parent"] == b["id"]]
        b["reads"], b["later"] = [], []
        if b["id"] in BASE_SPRITE:
            b["art"] = {"sheet": BASE_SPRITE[b["id"]]}

    # Sprites a form can show: a sheet of its own, else the slime sheet tinted (a built slime form), else nothing yet.
    def sprite_of(node):
        art = node.get("art") or {}
        sheet = art.get("sheet")
        if sheet and sheet in sprites:
            return {"sheet": sheet, **sprites[sheet], "tint": None if node["id"] in bases else None}
        if art.get("tint") and "slime" in sprites:
            return {"sheet": "slime", **sprites["slime"], "tint": art["tint"], "size": art.get("size")}
        return None

    for node in list(forms) + list(bases.values()):
        node["sprite"] = sprite_of(node)
        node.pop("art", None)
        if node["sprite"] is None and node["twin"]["status"] == "existing" and node["twin"]["creature"] in sprites:
            node["sprite"] = {"sheet": node["twin"]["creature"], **sprites[node["twin"]["creature"]], "tint": None, "ofTwin": True}

    # Creatures: existing, support, and the new twins (a twin that is an existing creature is not repeated).
    creatures = []
    for cid, c in existing.items():
        areas = [a for a in AREA_IDS if cid in spawns.get(a, {})]
        twin_of = [k for k, v in twin_existing.items() if v == cid]
        creatures.append({"id": cid, "name": c["name"], "kind": "existing", "areas": areas, "role": "shipped" if areas else "shipped, not in a room yet", "essence": c["essence"], "xp": c["xp"],
                          "twinOf": twin_of[0] if twin_of else "", "count": {a: spawns[a][cid] for a in areas}, "sprite": sprites.get(cid)})
    for s in support:
        creatures.append({"id": s["id"], "name": s["name"], "kind": "support", "areas": s["areas"], "role": s["role"], "essence": s["essence"],
                          "xp": s["xp"], "twinOf": s["twinOf"], "why": s["why"], "sprite": sprites.get(BASE_SPRITE.get(s["twinOf"], ""))})
    for f in forms:
        if f["twin"]["status"] == "new":
            creatures.append({"id": "twin_" + f["id"], "name": f["name"], "kind": "twin", "areas": f["twin"]["areas"], "role": f["twin"]["role"],
                              "essence": f["twin"]["essence"], "xp": f["twin"]["xp"], "twinOf": f["id"], "species": f["species"], "stage": f["stage"]})

    # Essences.
    def units(c):
        return c["essence"]
    existing_supply = {e: 0 for e in ELEMENTS}
    existing_by_area = {a: {e: 0 for e in ELEMENTS} for a in AREA_IDS}
    for a, counts in spawns.items():
        for cid, n in counts.items():
            if existing[cid]["untackleable"]:
                continue
            for e, v in existing[cid]["essence"].items():
                existing_supply[e] += v * n
                existing_by_area[a][e] += v * n
    essences = []
    arrive = {a["essence"]: a for a in arrival}
    for e in ELEMENTS:
        reading = {sid: 0 for sid, *_ in SPECIES}
        for f in forms:
            if e in f["reads"]:
                reading[f["species"]] += 1
        carriers_support = [{"id": s["id"], "name": s["name"], "amount": s["essence"][e], "areas": s["areas"]} for s in support if e in s["essence"]]
        carriers_existing = [{"id": c["id"], "name": c["name"], "amount": c["essence"][e], "areas": c["areas"]} for c in creatures if c["kind"] == "existing" and e in c["essence"]]
        twin_units = sum(units(c).get(e, 0) for c in creatures if c["kind"] == "twin")
        twin_count = sum(1 for c in creatures if c["kind"] == "twin" and e in c["essence"])
        essences.append({"id": e, "later": e in LATER, "arrives": arrive[e]["arrives"], "sources": arrive[e]["sources"], "note": arrive[e]["note"],
                         "shippedSupply": existing_supply[e], "formsReading": reading, "formsReadingTotal": sum(reading.values()),
                         "existing": carriers_existing, "support": carriers_support, "twinTypes": twin_count, "twinUnits": twin_units})

    # Areas.
    areas = []
    for aid, name, built in AREAS:
        areas.append({"id": aid, "name": name, "built": built, "shippedEssence": existing_by_area[aid],
                      "existing": [c["id"] for c in creatures if c["kind"] == "existing" and aid in c["areas"]],
                      "support": [c["id"] for c in creatures if c["kind"] == "support" and aid in c["areas"]],
                      "twins": [c["id"] for c in creatures if c["kind"] == "twin" and aid in c["areas"]]})

    # Species and their lines.
    species = []
    for sid, letter, name, arch, how, base_name in SPECIES:
        mine = [f for f in forms if f["species"] == sid]
        lines = [{"id": f["id"], "name": f["name"], "forms": [g["id"] for g in mine if g["id"] == f["id"] or g["parent"] == f["id"]
                                                              or by_id.get(g["parent"], {}).get("parent") == f["id"]]} for f in mine if f["stage"] == 2]
        species.append({"id": sid, "letter": letter, "name": name, "archetype": arch, "essenceMethod": how, "base": letter + "1",
                        "counts": {str(s): sum(1 for f in mine if f["stage"] == s) for s in (2, 3, 4)}, "lines": lines})

    try:
        sha = subprocess.run(["git", "rev-parse", "--short=7", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sha = ""
    new_twins = sum(1 for c in creatures if c["kind"] == "twin")
    data = {"species": species, "forms": forms, "bases": list(bases.values()), "creatures": creatures, "essences": essences, "areas": areas,
            "parts": parts, "tiers": {str(k): v for k, v in tiers.items()}, "elements": ELEMENTS,
            "summary": {"forms": len(forms), "newTwins": new_twins, "support": len(support), "existing": len(existing),
                        "newCreatureTypes": new_twins + len(support), "built": sum(1 for f in forms if f["built"])},
            "built": {"date": time.strftime("%Y-%m-%d"), "sha": sha}}
    # The moveset and art GIFs are made by tools/moveset_gifs.gd and tools/art/sprite_gifs.py; their manifests ride along.
    for key, rel in (("movesets", "movesets/movesets.json"), ("art", "art/art.json")):
        path = os.path.join(OUT, rel)
        data[key] = json.loads(read(path)) if os.path.exists(path) else None
    os.makedirs(OUT, exist_ok=True)
    used = {n["sprite"]["sheet"] for n in list(forms) + list(bases.values()) if n["sprite"]}
    used |= {c["sprite"]["image"].split("/")[-1][:-4] for c in creatures if c.get("sprite")}
    copy_sprites(used)
    with open(os.path.join(OUT, "evolutions-data.js"), "w") as fh:
        fh.write("window.EVOLUTIONS = " + json.dumps(data, separators=(",", ":"), ensure_ascii=False) + ";\n")
    print("wrote %d forms, %d new twins, %d support monsters" % (len(forms), new_twins, len(support)))
    return data


if __name__ == "__main__":
    build()
