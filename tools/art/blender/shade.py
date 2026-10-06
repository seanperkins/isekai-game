"""Shading v2: the step after the 3D render, working at the sprite's own resolution so every pixel is an exact colour from a ramp.

The render gives a flat colour pass (one exact colour per material) and a camera-space normal pass. `reduce_passes` shrinks both to game size
(coverage decides which pixels exist, the colour snaps to the nearest material, the normals are averaged and renormalised, so nothing is
blended into mud). `shade` then lights each pixel from a five-step ramp made from its material (`ramp`: shadows lean cool and saturated,
lights lean warm and pale, the way pixel artists build them), with a rim light and creases for form. The normal map it shaded from is also what
the game's lights use, so a sprite is lit by the room's lights as well (docs/research/blender-pipeline-spike.md).

Pure Pillow, no numpy. Normals are encoded each axis -1..1 as 0..255: R right, G up, B toward the viewer.
"""
import colorsys
import math

from PIL import Image

LIGHT = (-0.45, 0.70, 0.55)   # the key light: upper left, in front
RIM = (0.85, 0.35, -0.2)      # a back light: upper right, behind, catching edges turned from the camera
BANDS = (-0.30, 0.15, 0.55, 0.88)   # N.L between ramp steps 0..4: the broad middle steps hold most of a form, the palest only a small cluster
HYST = 0.07                   # a pixel only changes shading step when it is this far past the boundary: the shimmer-killer
COVER_HYST = 24               # and only appears or vanishes when its coverage is this far (of 255) past one half
CREASE = 0.64                 # neighbours whose normals agree less than this (cos 50 degrees) have a crease between them
DARK = 0.35                   # the outline's darkness against what it touches


def unit(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def decode(rgb):
    return unit(tuple(c / 255.0 * 2.0 - 1.0 for c in rgb[:3]))


def encode(v):
    return tuple(max(0, min(255, int(round((c * 0.5 + 0.5) * 255)))) for c in unit(v))


def _toward(h, target, amount):
    d = ((target - h + 0.5) % 1.0) - 0.5  # the short way round the hue wheel
    return (h + d * amount) % 1.0


def ramp(rgb, bake=1.0):
    """Five colours for a material, darkest to lightest, the base in the middle. `bake` < 1 keeps fewer steps (the engine's lights do the rest):
    0.5 keeps the three middle ones, 0 only the base."""
    h, s, v = colorsys.rgb_to_hsv(*(c / 255.0 for c in rgb))

    def make(target, amount, ds, dv):
        c = colorsys.hsv_to_rgb(_toward(h, target, amount), min(1.0, s * ds), min(1.0, v * dv))
        return tuple(int(round(x * 255)) for x in c)
    steps = [make(0.72, 0.20, 1.15, 0.42), make(0.72, 0.10, 1.10, 0.68), tuple(rgb), make(0.12, 0.07, 0.90, 1.12), make(0.12, 0.13, 0.66, 1.26)]
    if bake >= 0.99:
        return steps
    return steps[1:4] if bake >= 0.4 else [steps[2]]


def _nearest(rgb, materials):
    return min(materials, key=lambda m: (m[0] - rgb[0]) ** 2 + (m[1] - rgb[1]) ** 2 + (m[2] - rgb[2]) ** 2)


def reduce_passes(albedo, normal, size, materials, previous=None):
    """Shrink the colour and normal passes to `size` without blending: a pixel exists where at least half of its block is drawn, takes the
    colour of the nearest material, and the average of the normals in its block, renormalised. With the previous frame's reduced pass, a pixel
    on the fence keeps what it was (hysteresis), so a slow edge does not flicker. Returns (albedo, normal) as RGBA."""
    materials = [tuple(m) for m in materials]
    a_small = albedo.convert("RGBa").resize(size, Image.BOX).convert("RGBA")
    n_small = normal.convert("RGBa").resize(size, Image.BOX).convert("RGBA")
    cover = albedo.split()[3].resize(size, Image.BOX)
    out_a = Image.new("RGBA", size, (0, 0, 0, 0))
    out_n = Image.new("RGBA", size, (0, 0, 0, 0))
    pa, pn, pc, oa, on = a_small.load(), n_small.load(), cover.load(), out_a.load(), out_n.load()
    before = previous.load() if previous is not None else None
    for y in range(size[1]):
        for x in range(size[0]):
            need = 128
            if before is not None:
                need += -COVER_HYST if before[x, y][3] else COVER_HYST
            if pc[x, y] < need:
                continue
            oa[x, y] = _nearest(pa[x, y][:3], materials) + (255,)
            on[x, y] = encode(decode(pn[x, y])) + (255,)
    return out_a, out_n


def _lum(n, light):
    return n[0] * light[0] + n[1] * light[1] + n[2] * light[2]


def _edges(count):
    return {1: (), 3: (0.05, 0.55)}.get(count, BANDS)


def _step(lum, count):
    return sum(1 for edge in _edges(count) if lum >= edge)


def _settle(lum, raw, was, count):
    """The step to use: the raw one, unless the pixel was on `was` last frame and has not moved clearly past the boundary between them."""
    if was is None or was == raw or was >= count:
        return raw
    edges = _edges(count)
    if raw > was and lum - edges[was] < HYST:
        return was
    if raw < was and edges[was - 1] - lum < HYST:
        return was
    return raw


def shade(albedo, normal, bake=1.0, rim=True, creases=True, previous=None, record=None):
    """Light every pixel from its material's ramp: the step comes from the normal's angle to the key light, a rim light lifts edges turned
    from the camera toward the back light, and a crease between two neighbours whose normals disagree darkens the darker one. `previous` is
    the last frame's {pixel: (material colour, step)} (hysteresis, as in reduce_passes; a pixel that now shows another material has no history); `record`, if a dict, receives this frame's steps for the next call."""
    key, back = unit(LIGHT), unit(RIM)
    w, h = albedo.size
    pa, pn = albedo.load(), normal.load()
    ramps, steps, count = {}, {}, {}
    lum = {}
    for y in range(h):
        for x in range(w):
            if pa[x, y][3] == 0:
                continue
            colour = pa[x, y][:3]
            r = ramps.setdefault(colour, ramp(colour, bake))
            n = decode(pn[x, y])
            lum[(x, y)] = _lum(n, key)
            was = (previous or {}).get((x, y))
            was = was[1] if was is not None and was[0] == colour else None   # only what the same material showed here last frame counts
            i = _settle(lum[(x, y)], _step(lum[(x, y)], len(r)), was, len(r))
            if record is not None:
                record[(x, y)] = (colour, i)
            if rim and len(r) > 1 and n[2] < 0.45 and _lum(n, back) > 0.55:
                i = min(len(r) - 1, i + 1)
            steps[(x, y)] = i
            count[(x, y)] = len(r)
    if creases:
        lower = {}
        for (x, y) in lum:
            for nx, ny in ((x + 1, y), (x, y + 1)):
                if (nx, ny) in lum and _lum(decode(pn[x, y]), decode(pn[nx, ny])) < CREASE:
                    dark = (x, y) if lum[(x, y)] <= lum[(nx, ny)] else (nx, ny)
                    lower[dark] = True
        for p in lower:
            steps[p] = max(0, steps[p] - 1)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po = out.load()
    for (x, y), i in steps.items():
        po[x, y] = ramps[pa[x, y][:3]][i] + (255,)
    return out


def unkey(colour):
    """The colour, moved off the pipeline's magenta background key if it was on it (tools/art/slice_sheets.keyed erases a pixel with red and blue
    both over 150, green under 120 and the red or blue more than 60 over the green: a purple-pink there would become a hole). Only green moves, as little as it takes."""
    r, g, b = colour[:3]
    if r > 150 and b > 150 and g < 120 and min(r, b) - g > 60:
        return (r, min(r, b) - 60, b) + tuple(colour[3:])
    return colour


def palette_colours(materials, bake=1.0, dark=DARK, lit_dark=0.62, limit=256):
    """Every colour a creature can show: its materials' ramps, and for the outline a dark of each material's shadow, base and lit steps (the outline
    is darker where it touches shadow and lighter where it touches light, and is snapped to the nearest of these). A creature with many materials
    keeps the ramps and drops outline darks, the least needed first, rather than overflow a palette."""
    ramps = [ramp(tuple(rgb), bake) for rgb in materials]
    seen = []

    def add(colour):
        colour = unkey(colour)
        if colour not in seen:
            seen.append(colour)
    for r in ramps:
        for c in r:
            add(c)
    for factor, pick in ((dark, 2), (lit_dark, 3), (dark, 1), (lit_dark, 2)):
        for r in ramps:
            c = r[min(pick, len(r) - 1)]
            colour = tuple(int(v * factor) for v in c)
            if colour not in seen and len(seen) < limit:
                seen.append(colour)
    return seen
