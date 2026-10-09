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
import subprocess
import sys
import tempfile
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


def _held(form_id, root):
    """({"form": {"n", "f", "scale"}, "items": {id: {"image", "grip", "w", "h"}}}, {media name: file}) for a goblin form that has a row in data/held_items.json: what it holds
    by default, how much its items are scaled, and every item there is, so the page can put another in a hand. (None, {}) for a creature the table does not know."""
    table_path = Path(root) / "data" / "held_items.json"
    if not table_path.is_file():
        return None, {}
    table = _read(table_path)
    entry = table.get("forms", {}).get(form_id)
    if entry is None:
        return None, {}
    sheets = Path(root) / "assets" / "sheets"
    items, media = {}, {}
    for item_id, item in sorted(table.get("items", {}).items()):
        sheet_path = sheets / (item["set"] + ".json")
        if not sheet_path.is_file():
            continue
        rect = _read(sheet_path)["frames"][item.get("frame", "item")]["rect"]
        name = "items/%s.png" % item_id
        items[item_id] = {"image": name, "grip": list(item["grip"]), "w": rect[2], "h": rect[3]}
        media[name] = sheets / (item["set"] + ".png")
    return {"form": {"n": entry.get("n", ""), "f": entry.get("f", ""), "scale": entry["scale"]}, "items": items}, media


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
        clips[state] = {"frames": [_frame_entry(frames[name]) for name, _ in runs], "durations": [count / fps for _, count in runs], "loop": bool(clip.get("loop"))}
    has_normal = bool(sheet.get("normal")) and (sheet_path.parent / sheet["normal"]).is_file()
    listing = {"image": "sheet.png", "normal": "sheet_n.png" if has_normal else None, "scale": _sprite_size(form_id, root), "clips": clips}
    held, _ = _held(form_id, root)
    if held is not None:
        listing["held"] = held
    return listing


def _frame_entry(frame):
    """A listing frame: its rect on the sheet, and where its hands are when the sheet says (a goblin drawn empty-handed)."""
    entry = {"rect": list(frame["rect"])}
    if frame.get("hands"):
        entry["hands"] = frame["hands"]
    return entry


def sheet_media(form_id, root=ROOT):
    """{name in the creature's folder: the game's file} for what sheet_listing names."""
    sheet_path, _, _ = _sheet_files(form_id, root)
    sheet = _read(sheet_path)
    media = {"sheet.png": sheet_path.parent / sheet["image"]}
    if sheet.get("normal") and (sheet_path.parent / sheet["normal"]).is_file():
        media["sheet_n.png"] = sheet_path.parent / sheet["normal"]
    media.update(_held(form_id, root)[1])
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


def split_id(creature):
    """(species, form) of a form id: wolf_fenrir is ("wolf", "fenrir"), kraken ("slime", "kraken"); as export_forms.split_id."""
    head, _, rest = creature.partition("_")
    return (head, rest) if head in BASE_OF and rest else ("slime", creature)


def form_id(species, form):
    return form if species == "slime" else "%s_%s" % (species, form)


def _forms_of(species, repo):
    """The species' form table from the checkout's tools/art/blender (this checkout's when it has none). A process reads one checkout's: Python caches the module."""
    folder = Path(repo) / "tools" / "art" / "blender"
    folder = folder if folder.is_dir() else BLENDER_DIR
    if str(folder) not in sys.path:
        sys.path.insert(0, str(folder))
    try:
        return importlib.import_module("%s_forms" % species).FORMS
    except ImportError:
        return {}


def tree_meta(creature, repo=ROOT):
    """{title, species, stage, parent} from the species' form table; {} for something not in a tree."""
    title = creature.replace("_", " ").title()
    if creature in BASE_CREATURES:
        return {"title": title, "species": BASE_CREATURES[creature], "stage": 1, "parent": None}
    species, form = split_id(creature)
    forms = _forms_of(species, repo)
    if form not in forms:
        return {}
    parent = forms[form].get("parent")
    parent_id = None if parent is None else (BASE_OF[species] if parent == BASE_OF[species] else form_id(species, parent))
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


def species_form(creature):
    """(species, form) for the exporter: a base creature is its species' base form, anything else comes from its id."""
    if creature in BASE_CREATURES:
        return BASE_CREATURES[creature], creature
    return split_id(creature)


def publish_model(content, creature, repo=ROOT):
    """Export the creature's rig and clips to a glTF (tools/review/export_gltf.py runs Blender, on the checkout `repo`'s art code), put it in the creature's folder
    and set its `model` block."""
    folder = _page_path(content, creature).parent
    species, form = species_form(creature)
    with tempfile.TemporaryDirectory() as tmp:
        done = subprocess.run([sys.executable, str(Path(__file__).resolve().parent / "export_gltf.py"), species, form, "--out", tmp, "--art", str(repo)], capture_output=True, text=True)
        if done.returncode != 0:
            raise RuntimeError("the glTF export failed:\n" + (done.stdout + done.stderr)[-1500:])
        folder.mkdir(parents=True, exist_ok=True)
        for name in ("model.glb", "model.json"):   # the model first, then the page that shows it
            tmp_dest = folder / (name + ".tmp")
            shutil.copyfile(Path(tmp) / name, tmp_dest)
            os.replace(tmp_dest, folder / name)
    set_block(content, creature, {"type": "model", "gltf": "model.glb"}, key="model")


def tree_ids(species, repo=ROOT):
    """The creature ids of a species' whole tree, its base creature first."""
    return [form if form == BASE_OF[species] else form_id(species, form) for form in _forms_of(species, repo)]


def publish_tree(content, species, models=False, missing_only=False, repo=ROOT):
    """Publish every form of a species that has a sheet (with `models`, its 3D model too). {"published", "skipped" (no sheet or clips), "no_model" (export failed)}."""
    out = {"published": [], "skipped": [], "no_model": []}
    for creature in tree_ids(species, repo):
        if missing_only and _page_path(content, creature).is_file():
            continue
        try:
            listing, media = sheet_listing(creature, repo), sheet_media(creature, repo)
        except ValueError:
            out["skipped"].append(creature)
            continue
        write_creature(content, creature, listing, media, **tree_meta(creature, repo))
        out["published"].append(creature)
        if models:
            try:
                publish_model(content, creature, repo)
            except RuntimeError:
                out["no_model"].append(creature)
    return out


def add_figure(content, creature, source, caption, key=None, name=None):
    """Copy an image (GIF, PNG, SVG) into the creature's folder and put a `figure` block for it on its page."""
    path = _page_path(content, creature)
    name = name or Path(source).name
    if not re.match(r"^[A-Za-z0-9_.-]+$", name) or name.startswith("."):
        raise ValueError("a figure's file name is letters, digits, _ . -: %r" % name)
    dest = path.parent / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".tmp")
    shutil.copyfile(source, tmp)
    os.replace(tmp, dest)
    set_block(content, creature, {"type": "figure", "src": name, "caption": caption}, key=key)


# ---- command line ------------------------------------------------------------------------------------------------------------------
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--content", type=Path, default=feedback.DEFAULT_CONTENT)
    common.add_argument("--repo", type=Path, default=ROOT, help="the checkout whose sheets, data and art code to read (default: this one)")
    sub = ap.add_subparsers(dest="command", required=True)
    sheet = sub.add_parser("sheet", parents=[common], help="publish what the game plays for a form")
    sheet.add_argument("form_id")
    frames = sub.add_parser("frames", parents=[common], help="publish a render folder")
    frames.add_argument("creature")
    frames.add_argument("folder", type=Path)
    frames.add_argument("--scale", type=float, help="the game's draw scale for it (default: the twin's sprite_size, else 1)")
    tree = sub.add_parser("tree", parents=[common], help="publish a whole species")
    tree.add_argument("species", choices=sorted(BASE_OF))
    tree.add_argument("--models", action="store_true", help="export each form's 3D model too")
    tree.add_argument("--missing-only", action="store_true", help="leave a creature that already has a page alone")
    model = sub.add_parser("model", parents=[common], help="export the creature's 3D model and clips")
    model.add_argument("creature")
    figure = sub.add_parser("figure", parents=[common], help="put an image on a creature's page")
    figure.add_argument("creature")
    figure.add_argument("file", type=Path)
    figure.add_argument("--caption", default="")
    figure.add_argument("--key")
    args = ap.parse_args(argv)
    if args.command == "tree":
        result = publish_tree(args.content, args.species, args.models, args.missing_only, args.repo)
        print("published %d; no sheet or clips: %s; no model: %s" % (len(result["published"]), ", ".join(result["skipped"]) or "none", ", ".join(result["no_model"]) or "none"))
        return
    if args.command == "model":
        publish_model(args.content, args.creature, args.repo)
        return
    if args.command == "figure":
        add_figure(args.content, args.creature, args.file, args.caption, key=args.key)
        return
    if args.command == "sheet":
        path = write_creature(args.content, args.form_id, sheet_listing(args.form_id, args.repo), sheet_media(args.form_id, args.repo), **tree_meta(args.form_id, args.repo))
    else:
        scale = args.scale if args.scale is not None else _sprite_size(args.creature, args.repo)
        path = write_creature(args.content, args.creature, frames_listing(args.folder, scale), frames_media(args.folder), **tree_meta(args.creature, args.repo))
    print(path)


if __name__ == "__main__":
    main()
