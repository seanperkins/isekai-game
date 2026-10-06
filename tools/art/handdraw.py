"""Hand-drawn art in, through the same seam as the generated art.

The pipeline's contract is one PNG per frame at art_source/frames/<set>/<name>.png (transparent or magenta background) and a spec,
tools/art/<set>_frames.json, naming the frames and their width in game pixels; tools/art/assemble_frames.py turns those into the
sheet the game reads. This tool wraps the three things an artist needs around that seam, for Procreate, Aseprite or anything that
exports a PNG:

  handdraw.py inventory                      what each set has, and how much of it is hand-drawn
  handdraw.py pack <set> [--native]          a template per frame (the current art faded under guides) and a BRIEF.md
  handdraw.py check <set> <folder> [--native]  validate your exports and write <folder>/preview.png (yours at game size, then today's)
  handdraw.py import <set> <folder> [--native] back up what it replaces, install the frames, rebuild the sheet, record them as hand-drawn

Two routes, chosen per import:
  paint big (default): draw large, about the size of the sources (1254 px). The assembler shrinks the drawing to the frame's width,
    exactly as it does the generated frames. Keep outlines fat: a 16x shrink erases a line thinner than about 16 px.
  native (--native):   draw at the final pixel size (a 76 px wide sprite is 76 px). The frame is taken as drawn, never resized or blended;
    `"native": true` is written into the frame's spec entry.

Run from anywhere; needs Pillow (the system python3 here has it, or: uv run --python 3.12 --with Pillow python tools/art/handdraw.py ...).
"""
import argparse
import datetime
import glob
import json
import os
import re
import shutil
import subprocess
import sys
from collections import namedtuple

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assemble_frames as asm  # noqa: E402
from slice_sheets import keyed  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CANVAS = 1254          # the size of the generated sources
PAPER = (236, 236, 240, 255)
GUIDE = (214, 64, 64, 255)
SOFT = (170, 170, 190, 255)
FLOOR = 0.92           # where the feet go, as a fraction of the canvas height
SAFE = 0.05            # the margin the drawing stays inside
FADE = 0.35            # how much of the current art shows through under the guides
EDGE = 2               # px the drawing must stay from the canvas edge (paint big)
CLEAR = 0.10           # at least this share of the canvas must be transparent
KEEP = 0.88            # below this share of the ink surviving the shrink, fine detail is dropping out
STRAY = 3              # a separate mark this small (px, at game size) is a speck
ZOOM = 4               # the preview's magnification

Finding = namedtuple("Finding", "level code message")


# ---- specs and paths -------------------------------------------------------------------------------------------------

def _values(im):
    """The pixel values of a single-band image."""
    return im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()


def _open(path):
    """An image read and closed at once, as RGBA."""
    with Image.open(path) as im:
        return im.convert("RGBA")


def spec_path(root, set_name):
    return os.path.join(root, "tools", "art", set_name + "_frames.json")


def load_spec(root, set_name):
    path = spec_path(root, set_name)
    if not os.path.exists(path):
        raise ValueError("no spec for '%s' (expected tools/art/%s_frames.json)" % (set_name, set_name))
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def source_dir(root, spec, set_name):
    return os.path.join(root, "art_source", "frames", spec.get("derive_from", set_name))


def built_frame(root, set_name, name):
    """The current built sprite of a frame (cut from assets/sheets/<set>.png), or None."""
    meta, png = (os.path.join(root, "assets", "sheets", set_name + ext) for ext in (".json", ".png"))
    if not (os.path.exists(meta) and os.path.exists(png)):
        return None
    with open(meta) as fh:
        frame = json.load(fh).get("frames", {}).get(name)
    if frame is None:
        return None
    x, y, w, h = frame["rect"]
    return _open(png).crop((x, y, x + w, y + h))


def reference(root, spec, set_name, frame, native):
    """What a frame looks like now, to draw over: the built sprite when working at final size, else the big source, else the sprite."""
    src = os.path.join(source_dir(root, spec, set_name), frame["name"] + ".png")
    built = built_frame(root, set_name, frame["name"])
    if native:
        if built is not None:
            return built
        return asm.fit_frame(_open(src), frame["width"]) if os.path.exists(src) else None
    return _open(src) if os.path.exists(src) else built


# ---- checking --------------------------------------------------------------------------------------------------------

def components(mask, w, h):
    """The sizes of the 4-connected blobs of True in a w x h mask given as a flat list."""
    seen = [False] * (w * h)
    sizes = []
    for start in range(w * h):
        if not mask[start] or seen[start]:
            continue
        stack, count = [start], 0
        seen[start] = True
        while stack:
            i = stack.pop()
            count += 1
            x, y = i % w, i // w
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if mask[j] and not seen[j]:
                        seen[j] = True
                        stack.append(j)
        sizes.append(count)
    return sizes


def check_frame(im, target_width, native=False):
    """Findings for one exported frame: errors stop an import, warnings are shown. `target_width` is the frame's width in game pixels."""
    original = im.convert("RGBA")
    im = keyed(original)
    alpha = im.split()[3]
    box = alpha.getbbox()
    if box is None:
        return [Finding("error", "empty", "nothing is drawn (or everything is magenta)")]
    found = []
    w, h = im.size
    clear = sum(1 for v in _values(alpha) if v < 128) / float(w * h)
    was = _values(original.split()[3])
    if sum(1 for v in was if v < 128) / float(w * h) >= CLEAR:  # a transparent background: a magenta-like pixel is the drawing's, and is lost
        lost = sum(1 for before, after in zip(was, _values(alpha)) if before >= 128 and after < 128)
        if lost:
            found.append(Finding("warn", "key_colour", "%d opaque pixel(s) are close to magenta, the pipeline's background key, and will be erased (use pale lavender or soft rose for pinks)" % lost))
    if clear < CLEAR:
        found.append(Finding("error", "solid_background", "the background is not transparent (hide the template layer and the background colour before exporting)"))
    if not native and (box[0] < EDGE or box[1] < EDGE or box[2] > w - EDGE or box[3] > h - EDGE):
        found.append(Finding("error", "touches_edge", "the drawing runs into the canvas edge, so it is probably cut off"))
    crop = im.crop(box)
    if native:
        mask_img = asm.crisp_alpha(crop.copy()).split()[3]
    else:
        size = (target_width, max(1, round(crop.height * target_width / crop.width)))
        shrunk = crop.split()[3].resize(size, Image.BOX)
        values = list(_values(shrunk))
        ink = sum(values) / 255.0
        kept = sum(1 for v in values if v >= 128)
        if ink > 0 and kept / ink < KEEP:
            found.append(Finding("warn", "thin_detail", "fine lines are dropping out at game size (thicken outlines: they must stay at least one game pixel wide)"))
        mask_img = shrunk.point(lambda v: 255 if v >= 128 else 0)
    mw, mh = mask_img.size
    sizes = components([v >= 128 for v in _values(mask_img)], mw, mh)
    if len(sizes) > 1:
        specks = [s for s in sizes if s <= STRAY]
        if specks and len(specks) < len(sizes):
            found.append(Finding("warn", "stray_specks", "%d stray mark(s) of %d px or less at game size (erase them)" % (len(specks), STRAY)))
    return found


# ---- templates -------------------------------------------------------------------------------------------------------

def _font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # an older Pillow
        return ImageFont.load_default()


def _faded(ref):
    ref = ref.copy()
    ref.putalpha(ref.split()[3].point(lambda v: int(v * FADE)))
    return ref


def template(ref, canvas=CANVAS):
    """A canvas to paint on: the current art faded, standing on a red floor line, inside a dotted margin, with the facing marked."""
    im = Image.new("RGBA", (canvas, canvas), PAPER)
    floor = int(canvas * FLOOR)
    if ref is not None:
        r = keyed(ref.convert("RGBA"))
        box = r.split()[3].getbbox()
        if box is not None:
            r = r.crop(box)
            safe = int(canvas * (1 - 2 * SAFE))
            scale = min(safe / r.width, safe / r.height)
            r = r.resize((max(1, round(r.width * scale)), max(1, round(r.height * scale))), Image.LANCZOS if scale < 1 else Image.NEAREST)
            im.alpha_composite(_faded(r), ((canvas - r.width) // 2, floor - r.height))
    d = ImageDraw.Draw(im)
    line = max(2, canvas // 300)
    m = int(canvas * SAFE)
    d.line([(canvas // 2, 0), (canvas // 2, canvas)], fill=SOFT, width=1)
    for x in range(m, canvas - m, 24):  # the dotted margin
        d.line([(x, m), (x + 10, m)], fill=SOFT, width=1)
        d.line([(x, canvas - m), (x + 10, canvas - m)], fill=SOFT, width=1)
    for y in range(m, canvas - m, 24):
        d.line([(m, y), (m, y + 10)], fill=SOFT, width=1)
        d.line([(canvas - m, y), (canvas - m, y + 10)], fill=SOFT, width=1)
    d.line([(0, floor), (canvas, floor)], fill=GUIDE, width=line)
    size = max(12, canvas // 40)
    d.text((m + 8, m + 8), "faces right  ->   lowest point on the red line   (hide this layer before exporting)", fill=GUIDE, font=_font(size))
    return im


def native_template(ref, width, pad=8):
    """The same for work at final size: the canvas is the sprite's own size plus a margin, with the sprite faded under a floor line."""
    rw, rh = ref.size if ref is not None else (width, width)
    w, h = max(rw, width) + 2 * pad, rh + 2 * pad
    im = Image.new("RGBA", (w, h), PAPER)
    if ref is not None:
        im.alpha_composite(_faded(ref.convert("RGBA")), ((w - rw) // 2, h - pad - rh))
    ImageDraw.Draw(im).line([(0, h - pad), (w, h - pad)], fill=GUIDE, width=1)
    return im


def brief(set_name, spec, frames, native, canvas):
    route = ("Draw at the final pixel size: each canvas below is the sprite's own size plus a margin. Use a pixel brush with no smoothing "
             "or anti-aliasing. The frame is taken exactly as drawn." if native else
             "Paint big: each canvas is %d px square. The pipeline shrinks your drawing to the width below, so keep outlines fat "
             "(at least 16 px) and details bold; check shows what survives." % canvas)
    lines = [
        "# Hand-drawing the %s set" % set_name, "",
        route, "",
        "1. Open a template PNG as a new canvas (Procreate: Gallery, Import; Aseprite: File, Open).",
        "2. Add a layer above it. The creature faces right, its lowest point on the red line, inside the dotted margin. Nothing else: no ground, shadow, text or effects.",
        "3. Hide the template layer and any background colour. Export a PNG with a transparent background (Procreate: Share, PNG; Aseprite: File, Save Copy As).",
        "4. Name it exactly as its frame below (idle.png), in one folder, then:",
        "   `python3 tools/art/handdraw.py check %s <folder>%s` to see the preview and any problems," % (set_name, " --native" if native else ""),
        "   `python3 tools/art/handdraw.py import %s <folder>%s` to install them and rebuild the sheet." % (set_name, " --native" if native else ""),
        "",
        "| frame | width in game px | the pose |", "| --- | --- | --- |",
    ]
    for f in frames:
        note = f.get("prompt", "").replace("|", "/").replace("\n", " ")
        if f.get("attack_from") is not None:
            note += " (the front %d%% is where it hurts)" % round((1 - f["attack_from"]) * 100)
        lines.append("| %s | %d | %s |" % (f["name"], f["width"], note))
    style = spec.get("style")
    if style:
        lines += ["", "House style: %s" % style]
    return "\n".join(lines) + "\n"


def pack(root, set_name, out, native=False, canvas=CANVAS, only=None):
    spec = load_spec(root, set_name)
    os.makedirs(out, exist_ok=True)
    frames = [f for f in spec["frames"] if only is None or f["name"] in only]
    written = []
    for f in frames:
        ref = reference(root, spec, set_name, f, native)
        im = native_template(ref, f["width"]) if native else template(ref, canvas)
        path = os.path.join(out, f["name"] + ".png")
        im.save(path)
        written.append(path)
    path = os.path.join(out, "BRIEF.md")
    with open(path, "w") as fh:
        fh.write(brief(set_name, spec, frames, native, canvas))
    written.append(path)
    return written


# ---- check, preview, import ------------------------------------------------------------------------------------------

def _pngs(folder):
    return sorted(p for p in glob.glob(os.path.join(folder, "*.png")) if os.path.basename(p) != "preview.png")


def _stem(path):
    return os.path.splitext(os.path.basename(path))[0]


def _fitted(im, width, native):
    return asm.native_frame(im) if native else asm.fit_frame(im, width)


def preview(root, set_name, spec, shown, native):
    """Each drawn frame at game size, magnified, beside the built sprite it would replace."""
    rows = []
    for name, im, width in shown:
        try:
            mine = _fitted(im, width, native)
        except ValueError:
            continue
        old = built_frame(root, set_name, name)
        rows.append((name, mine, old))
    if not rows:
        return None
    pad, label = 8, 18
    cell_w = max(max(m.width, (o.width if o else 0)) for _, m, o in rows) * ZOOM
    w = 2 * cell_w + 3 * pad
    heights = [max(m.height, (o.height if o else 0)) * ZOOM + label + pad for _, m, o in rows]
    sheet = Image.new("RGBA", (w, sum(heights) + pad), PAPER)
    d = ImageDraw.Draw(sheet)
    y = pad
    for (name, mine, old), rh in zip(rows, heights):
        d.text((pad, y), "%s   yours (left) | now (right)" % name, fill=(40, 40, 60, 255), font=_font(12))
        base = y + rh - pad
        for i, im in enumerate((mine, old)):
            if im is None:
                continue
            big = im.resize((im.width * ZOOM, im.height * ZOOM), Image.NEAREST)
            sheet.alpha_composite(big, (pad + i * (cell_w + pad), base - big.height))
        y += rh
    return sheet


def check_folder(root, set_name, folder, native=False):
    """{frame: findings} for every PNG in the folder; writes folder/preview.png."""
    spec = load_spec(root, set_name)
    widths = {f["name"]: f["width"] for f in spec["frames"]}
    result, shown = {}, []
    for path in _pngs(folder):
        stem = _stem(path)
        if stem not in widths:
            result[stem] = [Finding("error", "unknown_frame", "'%s' is not a frame of %s" % (stem, set_name))]
            continue
        im = _open(path)
        result[stem] = check_frame(im, widths[stem], native)
        shown.append((stem, im, widths[stem]))
    sheet = preview(root, set_name, spec, shown, native)
    if sheet is not None:
        sheet.save(os.path.join(folder, "preview.png"))
    return result


def mark_native(text, names, on):
    """Set or clear `"native": true` on frames by editing the spec's text, so a hand-formatted spec keeps its layout."""
    for name in names:
        pat = re.compile(r'("name":\s*"%s")(,\s*"native":\s*true)?' % re.escape(name))
        text = pat.sub(lambda m: m.group(1) + (', "native": true' if on else ""), text, count=1)
    return text


def _prov_path(root):
    return os.path.join(root, "tools", "art", "provenance.json")


def load_provenance(root):
    if not os.path.exists(_prov_path(root)):
        return {}
    with open(_prov_path(root)) as fh:
        return json.load(fh)


def default_run(root):
    def run(set_name):
        subprocess.run([sys.executable, os.path.join("tools", "art", "assemble_frames.py"), set_name], cwd=root, check=True)
    return run


def import_frames(root, set_name, folder, native=False, run=None, stamp=None, today=None, source="hand"):
    """Install a folder of exported frames as the set's sources and rebuild its sheet. Nothing is touched unless every frame is accepted.
    `source` is what provenance records them as: "hand" for drawings, "blender" for renders (tools/art/blender)."""
    spec = load_spec(root, set_name)
    if "derive_from" in spec:
        raise ValueError("%s is a recolor of %s: draw %s instead" % (set_name, spec["derive_from"], spec["derive_from"]))
    widths = {f["name"]: f["width"] for f in spec["frames"]}
    files = _pngs(folder)
    if not files:
        raise ValueError("no PNG files in %s" % folder)
    unknown = [_stem(p) for p in files if _stem(p) not in widths]
    if unknown:
        raise ValueError("not frames of %s: %s (its frames: %s)" % (set_name, ", ".join(unknown), ", ".join(widths)))
    errors = []
    for path in files:
        for f in check_frame(_open(path), widths[_stem(path)], native):
            if f.level == "error":
                errors.append("%s: %s: %s" % (_stem(path), f.code, f.message))
    if errors:
        raise ValueError("\n".join(errors))
    stamp = stamp or datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    today = today or datetime.date.today().isoformat()
    dest = os.path.join(root, "art_source", "frames", set_name)
    backup = os.path.join(root, "art_source", ".replaced", set_name, stamp)
    os.makedirs(dest, exist_ok=True)
    for path in files:
        old = os.path.join(dest, _stem(path) + ".png")
        if os.path.exists(old):
            os.makedirs(backup, exist_ok=True)
            shutil.copyfile(old, os.path.join(backup, _stem(path) + ".png"))
        shutil.copyfile(path, old)
    names = [_stem(p) for p in files]
    with open(spec_path(root, set_name), encoding="utf-8") as fh:
        text = fh.read()
    marked = mark_native(text, names, native)
    if marked != text:
        with open(spec_path(root, set_name), "w", encoding="utf-8") as fh:
            fh.write(marked)
    prov = load_provenance(root)
    for n in names:
        prov.setdefault(set_name, {})[n] = {"source": source, "route": "native" if native else "paint", "date": today}
    with open(_prov_path(root), "w") as fh:
        json.dump(prov, fh, indent=1, sort_keys=True)
        fh.write("\n")
    (run or default_run(root))(set_name)
    return names


def inventory(root):
    prov = load_provenance(root)
    rows = []
    for path in sorted(glob.glob(os.path.join(root, "tools", "art", "*_frames.json"))):
        name = os.path.basename(path)[: -len("_frames.json")]
        with open(path, encoding="utf-8") as fh:
            spec = json.load(fh)
        src = source_dir(root, spec, name)
        rows.append({"set": name, "frames": len(spec["frames"]), "hand": sum(1 for v in prov.get(name, {}).values() if v.get("source") == "hand"),
                     "blender": sum(1 for v in prov.get(name, {}).values() if v.get("source") == "blender"),
                     "sources": sum(os.path.exists(os.path.join(src, f["name"] + ".png")) for f in spec["frames"]),
                     "derived": spec.get("derive_from", "")})
    return rows


# ---- command line ----------------------------------------------------------------------------------------------------

def _print_findings(result):
    bad = 0
    for stem, found in sorted(result.items()):
        if not found:
            print("  ok       %s" % stem)
        for f in found:
            print("  %-8s %s: %s: %s" % (f.level, stem, f.code, f.message))
            bad += f.level == "error"
    return bad


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("inventory")
    p = sub.add_parser("pack")
    p.add_argument("set")
    p.add_argument("--out")
    p.add_argument("--native", action="store_true")
    p.add_argument("--canvas", type=int, default=CANVAS)
    p.add_argument("--frames", help="comma-separated frame names (default: all)")
    for name in ("check", "import"):
        p = sub.add_parser(name)
        p.add_argument("set")
        p.add_argument("folder")
        p.add_argument("--native", action="store_true")
        if name == "import":
            p.add_argument("--source", default="hand", choices=["hand", "blender"], help="what to record the frames as (default hand)")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "inventory":
            print("%-22s %6s %5s %7s %8s  %s" % ("set", "frames", "hand", "blender", "sources", "note"))
            for r in inventory(ROOT):
                note = "recolor of " + r["derived"] if r["derived"] else ("sources not on this disk" if r["sources"] == 0 else "")
                print("%-22s %6d %5d %7d %8d  %s" % (r["set"], r["frames"], r["hand"], r["blender"], r["sources"], note))
        elif args.cmd == "pack":
            out = args.out or os.path.join(ROOT, ".tmp", "handdraw", args.set)
            only = args.frames.split(",") if args.frames else None
            written = pack(ROOT, args.set, out, native=args.native, canvas=args.canvas, only=only)
            print("%d files in %s: open BRIEF.md first" % (len(written), out))
        elif args.cmd == "check":
            bad = _print_findings(check_folder(ROOT, args.set, args.folder, native=args.native))
            print("preview: %s" % os.path.join(args.folder, "preview.png"))
            return 1 if bad else 0
        elif args.cmd == "import":
            names = import_frames(ROOT, args.set, args.folder, native=args.native, source=args.source)
            print("installed %d frame(s) into %s and rebuilt assets/sheets/%s.png; the old ones are in art_source/.replaced/" % (len(names), args.set, args.set))
            print("see it in the game: tools/creature_sheet.sh")
    except ValueError as err:
        print("refused: %s" % err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
