"""Build the bestiary page's data: every creature sheet with its traced hit shapes, copied next to the page.

Reads assets/sheets/*.json (frame rects, hurt and attack shapes: frame-local px, origin at the bottom centre, x right, y
down, so the floor is y = 0) and data/creatures/*.tres (names and stats), and writes
  docs/bestiary/bestiary-data.js   window.BESTIARY = {...}  (a script, not JSON, so the page also opens from a file)
  docs/bestiary/sheets/<id>.png    the sheets
Run from the project root, no arguments:  python3 tools/build_bestiary.py
The terrain body sizes are the game's: enemies use Enemy.BODY_SIZE (16x12) whatever they look like, the player BodyConfig (28x24).
"""
import glob
import json
import os
import re
import shutil
import subprocess
import time

SHEETS = "assets/sheets"
OUT = "docs/bestiary"
ENEMY_BODY = (16, 12)  # scripts/enemies/enemy.gd BODY_SIZE
PLAYER_BODY = (28, 24)  # scripts/player/body_config.gd COLLISION 14x12 at SCALE 2
PLAYER_SPECIES = {  # sheet id -> (display name, note)
    "slime": ("Slime", "The player's start. Also the Tackle: the attack shape."),
    "goblin": ("Goblin acrobat", "The biped species the player can become. No attack shape yet."),
}
ALSO_PLAYABLE = {"gloom_wolf": "the wolf species", "spider": "the spider species"}
NOT_CREATURES = {"commuter", "truck", "grandma"}  # the opening's battle sprites (data/opening_clips.json): sheets, but nothing for a bestiary
DEFAULT_FRAMES = ("idle_1", "hang_1", "fly_1", "hover_1", "swim_1", "drift_1", "slither_1", "idle")


def creature_def(cid):
    path = "data/creatures/%s.tres" % cid
    if not os.path.exists(path):
        return None, None
    text = open(path).read()
    name = re.search(r'display_name = "([^"]+)"', text)
    stats = {}
    block = re.search(r"stats = \{(.*?)\}", text, re.S)
    if block:
        for key, val in re.findall(r'"(\w+)": (\d+)', block.group(1)):
            stats[key] = int(val)
    return (name.group(1) if name else None), (stats or None)


def classify(cid, name):
    """A sheet's bestiary group ("player", "form" or "enemy"), display name and note: the player's species, the slime's animated
    forms (form_*), the art track's stills of a species' forms (forms_*), or an enemy."""
    if cid in PLAYER_SPECIES:
        name, note = PLAYER_SPECIES[cid]
        return "player", name, note
    if cid.startswith("forms_"):
        return "form", cid[6:].replace("_", " ").title() + " forms (player bodies)", "One still for each of the species' evolved forms: the player's body when it evolves."
    if cid.startswith("form_"):
        return "form", cid[5:].replace("_", " ").title() + " (player form)", "The slime's evolved form: it keeps the player's body."
    return "enemy", name or cid.replace("_", " ").title(), ("Its art is also %s." % ALSO_PLAYABLE[cid]) if cid in ALSO_PLAYABLE else ""


def build():
    creatures = []
    os.makedirs(os.path.join(OUT, "sheets"), exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SHEETS, "*.json"))):
        cid = os.path.basename(path)[:-5]
        if cid in NOT_CREATURES:
            continue
        sheet = json.load(open(path))
        frames = sheet["frames"]
        order = list(frames.keys())
        default = next((f for f in DEFAULT_FRAMES if f in frames), order[0])
        name, stats = creature_def(cid)
        group, name, note = classify(cid, name)
        bodies = []
        if group == "enemy":
            bodies.append({"label": "Terrain body (every enemy)", "w": ENEMY_BODY[0], "h": ENEMY_BODY[1]})
        if group != "enemy" or cid in ALSO_PLAYABLE:
            bodies.append({"label": "Player body", "w": PLAYER_BODY[0], "h": PLAYER_BODY[1]})
        shutil.copyfile(os.path.join(SHEETS, cid + ".png"), os.path.join(OUT, "sheets", cid + ".png"))
        creatures.append({
            "id": cid, "name": name, "group": group, "note": note, "stats": stats, "default": default,
            "image": "sheets/%s.png" % cid, "bodies": bodies, "order": order,
            "frames": {n: {"rect": f["rect"], "hurt": f.get("hurt", []), "attack": f.get("attack", [])} for n, f in frames.items()},
        })
    try:
        sha = subprocess.run(["git", "rev-parse", "--short=7", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sha = ""
    data = {"creatures": creatures, "refs": {"playerBox": list(PLAYER_BODY), "baseJump": 60},
            "built": {"date": time.strftime("%Y-%m-%d"), "sha": sha}}
    with open(os.path.join(OUT, "bestiary-data.js"), "w") as fh:
        fh.write("window.BESTIARY = " + json.dumps(data, separators=(",", ":")) + ";\n")
    print("wrote %d creatures" % len(creatures))


if __name__ == "__main__":
    build()
