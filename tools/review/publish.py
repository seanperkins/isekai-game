"""Publish a creature to the review page: its sprites from the game's sheets or from a render folder, and the blocks of its page.

    python3 tools/review/publish.py sheet <form_id> [--content DIR]            what the game plays: assets/sheets + the clip tables
    python3 tools/review/publish.py frames <creature> <folder> [--scale S]     work that is not in the game yet: a render folder (frames/, raw/meta.json)

A sprites listing is {"image", "normal", "scale", "clips": {name: {"frames": [{"rect": [x, y, w, h]} | {"src": path}], "durations": [seconds], "loop": bool}}}.
Every file is written to a temporary name and renamed, the page last, so the page never sees half of a creature.
"""
import argparse
import importlib
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import feedback  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BLENDER_DIR = ROOT / "tools" / "art" / "blender"
ENGINE_STATES = {"windup", "recover", "downed"}   # the engine splits an attack in two and holds the last frame of a death; they are not clips to look at
ORDER = ("idle", "walk", "run", "attack", "hurt", "die")
BASE_OF = {"goblin": "goblin", "wolf": "gloom_wolf", "spider": "spider", "undead": "skeleton", "slime": "slime"}   # a species' base creature, as species_tree.SPECIES names it
BASE_CREATURES = {base: species for species, base in BASE_OF.items()}


def _ordered(names):
    names = list(names)
    return sorted(names, key=lambda n: (ORDER.index(n) if n in ORDER else len(ORDER), names.index(n)))


def _read(path):
    with open(path) as fh:
        return json.load(fh)


def _write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    try:
        tmp.write_text(json.dumps(data, indent=1))
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def _check_id(creature):
    if not isinstance(creature, str) or not feedback.ID_PATTERN.match(creature):
        raise ValueError("a creature id matches %s: %r" % (feedback.ID_PATTERN.pattern, creature))


# ---- listings ----------------------------------------------------------------------------------------------------------------------
def _sprite_size(form_id, root):
    try:
        text = (Path(root) / "data" / "creatures" / ("twin_%s.tres" % form_id)).read_text()
    except OSError:
        return 1.0
    m = re.search(r"^sprite_size = ([0-9.]+)", text, re.M)
    return float(m.group(1)) if m else 1.0


def _sheet_files(form_id, root):
    """(sheet json, clip table, is a form) for a twin form (anim_<id>) or, failing that, a base creature (<id> and data/enemy_clips.json)."""
    sheets = Path(root) / "assets" / "sheets"
    if (sheets / ("anim_%s.json" % form_id)).is_file():
        return sheets / ("anim_%s.json" % form_id), Path(root) / "data" / "form_clips.json", True
    if (sheets / (form_id + ".json")).is_file():
        return sheets / (form_id + ".json"), Path(root) / "data" / "enemy_clips.json", False
    raise ValueError("no sheet for %s in %s" % (form_id, sheets))


def sheet_listing(form_id, root=ROOT):
    """The clips the game plays for `form_id`, as a sprites listing over the game's own sheet."""
    sheet_path, table_path, is_form = _sheet_files(form_id, root)
    sheet, table = _read(sheet_path), _read(table_path).get(form_id)
    if not table:
        raise ValueError("%s has no clips in %s" % (form_id, table_path.name))
    frames, clips = sheet["frames"], {}
    for state in _ordered(table):
        if is_form and state in ENGINE_STATES:
            continue
        clip, fps, runs = table[state], float(table[state].get("fps", 50.0)), []
        for name in clip["frames"]:
            if runs and runs[-1][0] == name:
                runs[-1][1] += 1
            else:
                runs.append([name, 1])
        for name, _ in runs:
            if name not in frames:
                raise ValueError("%s: clip %s names a frame the sheet does not have: %s" % (form_id, state, name))
        clips[state] = {"frames": [{"rect": list(frames[name]["rect"])} for name, _ in runs], "durations": [count / fps for _, count in runs], "loop": bool(clip.get("loop"))}
    has_normal = bool(sheet.get("normal")) and (sheet_path.parent / sheet["normal"]).is_file()
    return {"image": "sheet.png", "normal": "sheet_n.png" if has_normal else None, "scale": _sprite_size(form_id, root), "clips": clips}


def sheet_media(form_id, root=ROOT):
    """{name in the creature's folder: the game's file} for what sheet_listing names."""
    sheet_path, _, _ = _sheet_files(form_id, root)
    sheet = _read(sheet_path)
    media = {"sheet.png": sheet_path.parent / sheet["image"]}
    if sheet.get("normal") and (sheet_path.parent / sheet["normal"]).is_file():
        media["sheet_n.png"] = sheet_path.parent / sheet["normal"]
    return media


def frames_listing(folder, scale=1.0):
    """The clips in a render folder (frames/<clip>_<n>.png, raw/meta.json with anims, durations and loops) as a sprites listing."""
    folder = Path(folder)
    meta = _read(folder / "raw" / "meta.json")
    clips = {}
    for clip in _ordered(meta["anims"]):
        count, durations = meta["anims"][clip], meta["durations"][clip]
        names = ["frames/%s_%d.png" % (clip, i) for i in range(count)]
        missing = [n for n in names if not (folder / n).is_file()]
        if missing or len(durations) != count:
            raise ValueError("%s: meta says %d frames and %d durations; missing files: %s" % (clip, count, len(durations), ", ".join(missing) or "none"))
        clips[clip] = {"frames": [{"src": n} for n in names], "durations": [float(d) for d in durations],
                       "loop": bool(meta.get("loops", {}).get(clip, clip in ("idle", "walk", "run")))}
    return {"image": None, "normal": None, "scale": float(scale), "clips": clips}


def frames_media(folder):
    folder, meta = Path(folder), _read(Path(folder) / "raw" / "meta.json")
    return {"frames/%s_%d.png" % (clip, i): folder / "frames" / ("%s_%d.png" % (clip, i)) for clip in meta["anims"] for i in range(meta["anims"][clip])}


def tree_meta(creature):
    """{title, species, stage, parent} from the species' form table; {} for something not in a tree."""
    title = creature.replace("_", " ").title()
    if creature in BASE_CREATURES:
        return {"title": title, "species": BASE_CREATURES[creature], "stage": 1, "parent": None}
    if str(BLENDER_DIR) not in sys.path:
        sys.path.insert(0, str(BLENDER_DIR))
    import export_forms
    species, form = export_forms.split_id(creature)
    try:
        forms = importlib.import_module("%s_forms" % species).FORMS
    except ImportError:
        return {}
    if form not in forms:
        return {}
    parent = forms[form].get("parent")
    parent_id = None if parent is None else (BASE_OF[species] if parent == BASE_OF[species] else export_forms.form_id(species, parent))
    return {"title": form.replace("_", " ").title(), "species": species, "stage": forms[form].get("stage"), "parent": parent_id}


# ---- pages -------------------------------------------------------------------------------------------------------------------------
def _page_path(content, creature):
    _check_id(creature)
    return Path(content) / "creatures" / creature / "page.json"


def _load_page(path, creature):
    try:
        page = _read(path)
        if isinstance(page, dict) and isinstance(page.get("blocks"), list):
            return page
    except (OSError, ValueError):
        pass
    return {"id": creature, "title": creature, "blocks": []}


def _save_page(path, page):
    page["updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    _write_json(path, page)


def set_block(content, creature, block, key=None):
    """Put `block` on the creature's page: replacing the block with the same `key` when there is one, else at the end."""
    path = _page_path(content, creature)
    page = _load_page(path, creature)
    if key is not None:
        block = dict(block, key=key)
        for i, existing in enumerate(page["blocks"]):
            if existing.get("key") == key:
                page["blocks"][i] = block
                break
        else:
            page["blocks"].append(block)
    else:
        page["blocks"].append(block)
    _save_page(path, page)


def write_creature(content, creature, listing, media, **meta):
    """Copy `media` ({name in the creature's folder: source file}), write sprites.json, then create or update page.json (keeping its other blocks)."""
    path = _page_path(content, creature)
    folder = path.parent
    for rel in media:
        parts = Path(rel).parts
        if not parts or Path(rel).is_absolute() or ".." in parts:
            raise ValueError("a media name stays inside the creature's folder: %r" % rel)
    for rel, source in media.items():
        dest = folder / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_name(dest.name + ".tmp")
        shutil.copyfile(source, tmp)
        os.replace(tmp, dest)
    _write_json(folder / "sprites.json", listing)
    page = _load_page(path, creature)
    page.update({k: v for k, v in meta.items() if k in ("title", "species", "stage", "parent")})
    if not any(b.get("type") == "sprites" and b.get("sprites") == "sprites.json" for b in page["blocks"]):
        page["blocks"].insert(0, {"type": "sprites", "sprites": "sprites.json"})
    _save_page(path, page)
    return path


# ---- command line ------------------------------------------------------------------------------------------------------------------
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--content", type=Path, default=feedback.DEFAULT_CONTENT)
    sub = ap.add_subparsers(dest="command", required=True)
    sheet = sub.add_parser("sheet", parents=[common], help="publish what the game plays for a form")
    sheet.add_argument("form_id")
    frames = sub.add_parser("frames", parents=[common], help="publish a render folder")
    frames.add_argument("creature")
    frames.add_argument("folder", type=Path)
    frames.add_argument("--scale", type=float, default=1.0, help="the game's draw scale for it (the twin's sprite_size)")
    args = ap.parse_args(argv)
    if args.command == "sheet":
        path = write_creature(args.content, args.form_id, sheet_listing(args.form_id), sheet_media(args.form_id), **tree_meta(args.form_id))
    else:
        path = write_creature(args.content, args.creature, frames_listing(args.folder, args.scale), frames_media(args.folder), **tree_meta(args.creature))
    print(path)


if __name__ == "__main__":
    main()
