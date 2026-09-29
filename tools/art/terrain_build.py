"""Turn the raw Codex terrain images into game-sized, seamless assets.

Reads tools/art/terrain_manifest.json and art_source/terrain/<biome>/<piece>_raw.png.
Writes res://assets/tiles/<biome>/, res://assets/backgrounds/<biome>/ and decor into
res://assets/sprites/ (the folder Art.texture() and room decor already use).

Pieces:
  tile     square texture, wraps in x and y, downscaled to `size`
  strip_x  edge strip that wraps in x (cap_top, cap_bottom); trimmed to its content height
  strip_y  edge strip that wraps in y (edge_left); trimmed to its content width
  ledge    thin slab cut into a left cap, a wrapping middle and a right cap
  layer    parallax layer, `size` px, wraps in x
  decor    single object, trimmed and fitted inside `max`

Image models do not tile, so wrapping is forced with a cross-fade at the seam. Keying and alpha
handling match tools/art/slice_sheets.py (magenta becomes transparent, alpha is thresholded).
Run from the project root:  python3 tools/art/terrain_build.py cave
"""
import json
import os
import sys
from PIL import Image

RES = Image.Resampling.BOX


def keyed(im):
    """Turn the magenta background transparent without eating pink art.

    The bright palette has real pink crystals and flowers, so a colour test alone would punch holes
    in them. Magenta only counts when it connects to the image border through magenta (the
    background), plus a two-pixel fringe of magenta-tinted pixels next to it. Enclosed pure magenta
    (a gap inside a vine) is removed too.
    """
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    loose = bytearray(w * h)
    strict = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 150 and b > 150 and g < 120 and min(r, b) - g > 60:
                loose[y * w + x] = 1
                if r > 225 and b > 225 and g < 70:
                    strict[y * w + x] = 1
    gone = bytearray(strict)
    stack = [i for i in range(w * h) if loose[i] and (i % w in (0, w - 1) or i < w or i >= w * (h - 1))]
    for i in stack:
        gone[i] = 1
    while stack:
        i = stack.pop()
        x, y = i % w, i // w
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if loose[j] and not gone[j]:
                    gone[j] = 1
                    stack.append(j)
    for _ in range(2):  # fringe: tinted pixels touching removed background
        grow = []
        for y in range(h):
            for x in range(w):
                i = y * w + x
                if loose[i] and not gone[i]:
                    if any(gone[ny * w + nx] for nx in (x - 1, x, x + 1) for ny in (y - 1, y, y + 1)
                           if 0 <= nx < w and 0 <= ny < h):
                        grow.append(i)
        for i in grow:
            gone[i] = 1
    for i in range(w * h):
        if gone[i]:
            px[i % w, i // w] = (0, 0, 0, 0)
    return im


def shrink(im, size):
    """Resize with premultiplied alpha so keyed edges do not pick up black, then crisp the alpha."""
    out = im.convert("RGBa").resize(size, RES).convert("RGBA")
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return out


def column_cost(px, h, x0, x1, step=1):
    """Mean difference between columns x0 and x1 (alpha-aware), over every `step`th row."""
    total = 0.0
    rows = range(0, h, step)
    for y in rows:
        a, b = px[x0, y], px[x1, y]
        if a[3] < 128 and b[3] < 128:
            continue
        if (a[3] < 128) != (b[3] < 128):
            total += 1.0
        else:
            total += (abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])) / 765.0
    return total / len(rows)


def wrap_x(im, extra):
    """Make the image tile horizontally, keeping its original pixels.

    Image models do not tile. The image is `extra` columns wider than the result; this picks the
    start column s (0..extra-1) where the column after the crop, s+width, best matches column s, and
    crops [s, s+width). Nothing is blended, so nothing ghosts.
    """
    w, h = im.size
    width = w - extra
    px = im.load()
    step = max(1, h // 90)
    best = min(range(max(1, extra)), key=lambda s: column_cost(px, h, s, s + width, step))
    return im.crop((best, 0, best + width, h))


def mirror_x(im):
    """A guaranteed seamless loop for images the model could not tile: the image, then its reflection."""
    out = Image.new(im.mode, (im.width * 2, im.height))
    out.paste(im, (0, 0))
    out.paste(im.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (im.width, 0))
    return out


def wrap_y(im, extra):
    return wrap_x(im.transpose(Image.Transpose.ROTATE_90), extra).transpose(Image.Transpose.ROTATE_270)


OUTLINE = (44, 22, 68, 255)  # deep plum: reads against every pastel, unlike pure black


def outline(im, sides, pad_x, pad_y):
    """Add a 1 px dark outline where the silhouette meets air, so platforms stand out from the backdrop.

    `sides` is any of t, b, l, r: the sides of the shape that get a line. `pad_x`/`pad_y` add a
    transparent margin to hold it; skip the axis a strip tiles along, or the tile would gap.
    """
    px_ = 1 if pad_x else 0
    py_ = 1 if pad_y else 0
    out = Image.new("RGBA", (im.width + 2 * px_, im.height + 2 * py_), (0, 0, 0, 0))
    out.paste(im, (px_, py_))
    src = out.copy().load()
    dst = out.load()
    w, h = out.size

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    for y in range(h):
        for x in range(w):
            if src[x, y][3] >= 128:
                continue
            if ("t" in sides and solid(x, y + 1)) or ("b" in sides and solid(x, y - 1)) \
                    or ("l" in sides and solid(x + 1, y)) or ("r" in sides and solid(x - 1, y)):
                dst[x, y] = OUTLINE
    return out


BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def dither_fade(im, side, rows):
    """Dissolve the last `rows` rows/columns of a strip into nothing with an ordered dither.

    A strip laid over the stone fill ends in a straight line, and the two stone patterns never
    match there. Fading the edge in a Bayer pattern hides the join instead of drawing it.
    side: "b" fades the bottom rows, "t" the top rows, "r" the right columns.
    """
    px = im.load()
    w, h = im.size
    for i in range(rows):
        keep = 1.0 - (i + 1) / (rows + 1)  # share of pixels kept, falling towards the edge
        for k in range(w if side in "bt" else h):
            x, y = {"b": (k, h - rows + i), "t": (k, rows - 1 - i), "r": (w - rows + i, k)}[side]
            if px[x, y][3] and BAYER[y % 4][x % 4] / 16.0 >= keep:
                px[x, y] = (0, 0, 0, 0)
    return im


def is_green(c):
    """Moss, lichen and leaf pixels: green clearly above red and blue."""
    return c[3] >= 128 and c[1] > c[0] + 12 and c[1] > c[2] + 12


def shell(im, side, thickness, green_depth):
    """Keep only a thin shell of a strip that follows its silhouette, plus the moss hanging off it.

    An edge strip lies over the stone fill, and its own stone body never matches the fill's stones,
    so a whole strip leaves a visible line where it ends. The shell keeps the outline, a few pixels of
    rock and any green moss within `green_depth`, so the strip melts into the fill underneath.
    side: "t" (silhouette on top), "b" (on the bottom) or "l" (on the left).
    """
    px = im.load()
    w, h = im.size
    lines = w if side in "tb" else h
    span = h if side in "tb" else w
    for k in range(lines):
        def at(i):
            return (k, i if side == "t" else span - 1 - i) if side in "tb" else (i, k)
        edge = next((i for i in range(span) if px[at(i)][3] >= 128), None)
        if edge is None:
            continue
        for i in range(edge, span):
            x, y = at(i)
            depth = i - edge
            if depth >= thickness and not (is_green(px[x, y]) and depth < green_depth):
                px[x, y] = (0, 0, 0, 0)
    return im


def under_shadow(im, rows=3):
    """A soft plum shadow fading out below a platform's underside, so it lifts off the backdrop."""
    out = Image.new("RGBA", (im.width, im.height + rows), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    src = im.load()
    dst = out.load()
    for x in range(im.width):
        bottom = max((y for y in range(im.height) if src[x, y][3] >= 128), default=None)
        if bottom is None:
            continue
        for k in range(1, rows + 1):
            if dst[x, bottom + k][3] == 0:
                dst[x, bottom + k] = (OUTLINE[0], OUTLINE[1], OUTLINE[2], int(150 * (1 - (k - 1) / rows)))
    return out


def trim(im):
    box = im.getchannel("A").getbbox()
    return im.crop(box) if box else im


def surface_row(im, from_top=True):
    """First row (from the top or bottom) where at least 80% of the columns are opaque: the stone surface."""
    a = im.getchannel("A").load()
    rows = range(im.height) if from_top else range(im.height - 1, -1, -1)
    for y in rows:
        if sum(1 for x in range(im.width) if a[x, y]) >= im.width * 0.8:
            return y
    return 0


def surface_col(im):
    a = im.getchannel("A").load()
    for x in range(im.width):
        if sum(1 for y in range(im.height) if a[x, y]) >= im.height * 0.8:
            return x
    return 0


def divide(im, factor):
    return (max(1, round(im.width / factor)), max(1, round(im.height / factor)))


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", path, im.size)


META = {}


def build(biome, name, spec, raw):
    kind = spec["kind"]
    src = Image.open(raw)
    if kind == "tile":
        blend = spec.get("blend", 0)  # raw tiles are usually seamless already; blending only smears
        size = tuple(spec["size"])
        im = src.convert("RGBA").resize((size[0] + blend, size[1] + blend), RES)
        if blend:
            im = wrap_y(wrap_x(im, blend), blend)
        save(im, f"assets/tiles/{biome}/{name}.png")
    elif kind == "strip_x":
        # `top` strips keep the rows down to `depth` below the surface; `bottom` strips keep the rows
        # from `depth` above it. `surface` in the metadata is the row that lines up with the rect edge.
        im = trim(shrink(keyed(src), divide(src, spec.get("divide", 8))))
        im = wrap_x(im, spec.get("extra", 40))
        depth = spec.get("depth", 16)
        if spec.get("side", "top") == "top":
            surface = surface_row(im)
            im = im.crop((0, 0, im.width, min(im.height, surface + depth)))
            im = outline(im, "t", False, True)
            surface = surface_row(im)
            im = shell(im, "t", 5, 12)
        else:
            surface = surface_row(im, False)
            top = max(0, surface - depth)
            im = im.crop((0, top, im.width, im.height))
            surface -= top
            im = outline(im, "b", False, True)
            surface = surface_row(im, False)
            im = shell(im, "b", 5, 10)
        META[name] = {"surface": surface, "size": list(im.size)}
        save(im, f"assets/tiles/{biome}/{name}.png")
    elif kind == "strip_y":
        im = trim(shrink(keyed(src), divide(src, spec.get("divide", 8))))
        im = wrap_y(im, spec.get("extra", 40))
        surface = surface_col(im)
        im = im.crop((0, 0, min(im.width, surface + spec.get("depth", 12)), im.height))
        im = outline(im, "l", True, False)
        surface = surface_col(im)
        im = shell(im, "l", 5, 8)
        META[name] = {"surface": surface, "size": list(im.size)}
        save(im, f"assets/tiles/{biome}/{name}.png")
    elif kind == "ledge":
        im = trim(shrink(keyed(src), divide(src, spec.get("divide", 8))))
        cap = spec.get("cap", 20)
        surface = surface_row(im)
        im = im.crop((0, 0, im.width, min(im.height, surface + spec.get("depth", 14))))  # stay near the collision
        im = outline(im, "tblr", True, True)
        surface = surface_row(im)
        im = under_shadow(im)
        cap += 1  # the outline column belongs to the end cap
        META[name] = {"surface": surface, "size": [cap, im.height]}
        save(im.crop((0, 0, cap, im.height)), f"assets/tiles/{biome}/{name}_l.png")
        save(im.crop((im.width - cap, 0, im.width, im.height)), f"assets/tiles/{biome}/{name}_r.png")
        mid = im.crop((int(im.width * 0.3), 0, int(im.width * 0.7), im.height))  # top and bottom outline rows come along
        save(wrap_x(mid, spec.get("extra", 30)), f"assets/tiles/{biome}/{name}_m.png")
    elif kind == "layer":
        im = src.convert("RGBA")
        if spec.get("key"):
            im = keyed(im)
        if spec.get("plain"):  # a screen-sized frame, not a loop
            im = shrink(im, tuple(spec["size"])) if spec.get("key") else im.resize(tuple(spec["size"]), RES)
            save(im, f"assets/backgrounds/{biome}/{name}.png")
        elif spec.get("mirror"):
            im = shrink(im, tuple(spec["size"])) if spec.get("key") else im.resize(tuple(spec["size"]), RES)
            save(mirror_x(im), f"assets/backgrounds/{biome}/{name}.png")
        else:
            extra = spec.get("extra", 64)
            size = (spec["size"][0] + extra, spec["size"][1])  # wrapping crops `extra` columns
            im = shrink(im, size) if spec.get("key") else im.resize(size, RES)
            save(wrap_x(im, extra), f"assets/backgrounds/{biome}/{name}.png")
    elif kind == "decor":
        im = trim(keyed(src))
        mw, mh = spec["max"]
        scale = min(mw / im.width, mh / im.height)
        save(shrink(im, (max(1, round(im.width * scale)), max(1, round(im.height * scale)))), f"assets/sprites/{spec.get('out', name)}.png")
    else:
        raise ValueError(f"{name}: unknown kind {kind}")


def main():
    biome = sys.argv[1]
    only = sys.argv[2:]
    manifest = json.load(open("tools/art/terrain_manifest.json"))["biomes"][biome]
    for name, spec in manifest.items():
        if only and name not in only:
            continue
        raw = f"art_source/terrain/{biome}/{name}_raw.png"
        if not os.path.exists(raw):
            print("missing", raw)
            continue
        build(biome, name, spec, raw)
    if META:
        path = f"assets/tiles/{biome}/meta.json"
        old = json.load(open(path)) if os.path.exists(path) else {}
        old.update(META)
        json.dump(old, open(path, "w"), indent=1, sort_keys=True)
        print("wrote", path)


if __name__ == "__main__":
    main()
