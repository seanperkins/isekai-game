"""The step after the 3D render, in the way Dead Cells does it: the render gives a flat colour pass and a normal pass, and this turns
them into a pixel sprite. A cel shade picks one of a few brightness bands from the angle between each pixel's normal and the light, the
result is shrunk to game size with crisp alpha, given a dark outline, and snapped to one palette shared by every frame of a set (which
is also what keeps neighbouring frames from flickering between near colours).

Colours and normals arrive as images: the normal pass encodes each axis from -1..1 to 0..255 (R = right, G = up, B = toward the viewer,
all in camera space). Pure Pillow, no numpy.
"""
import math

from PIL import Image

LIGHT = (-0.45, 0.70, 0.55)  # from the upper left, in front of the sprite (camera space)
# (the band applies while N.L is below the limit, brightness multiplier): shadow, mid, lit
BANDS = ((0.05, 0.55), (0.40, 0.85), (9.0, 1.18))


def unit(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def decode(rgb):
    """The unit normal a pass pixel encodes."""
    return unit(tuple(c / 255.0 * 2.0 - 1.0 for c in rgb[:3]))


def band(dot, bands=BANDS):
    for limit, k in bands:
        if dot < limit:
            return k
    return bands[-1][1]


def _toward(rgb, tint, amount):
    return tuple(c + (t - c) * amount for c, t in zip(rgb, tint))


def tone(rgb, k, shadow=None, glow=None):
    """One colour under one band's brightness `k`, with the optional hue shift (see shade). Integers, clamped to 255."""
    out = (rgb[0] * k, rgb[1] * k, rgb[2] * k)
    if k < 1.0 and shadow:
        out = _toward(out, shadow[0], (1.0 - k) * shadow[1])
    elif k > 1.0 and glow:
        out = _toward(out, glow[0], min(1.0, (k - 1.0) * glow[1]))
    return tuple(min(255, int(c)) for c in out)


def shade(albedo, normal, light=LIGHT, bands=BANDS, shadow=None, glow=None):
    """The albedo times the cel band its normal picks, so a band below 1 darkens and one above 1 brightens. The alpha is the albedo's.
    `shadow` and `glow` are optional ((r, g, b), amount): a darkened pixel is pulled toward the shadow colour in proportion to how dark
    it is, a brightened one toward the glow colour in proportion to how bright, the hue shifting that pixel artists use (cool shadows,
    warm lights) so a dark creature does not just go black."""
    light = unit(light)
    out = Image.new("RGBA", albedo.size, (0, 0, 0, 0))
    a_px, n_px, o_px = albedo.load(), normal.load(), out.load()
    cache = {}
    for y in range(albedo.height):
        for x in range(albedo.width):
            r, g, b, al = a_px[x, y]
            if al == 0:
                continue
            key = n_px[x, y][:3]
            k = cache.get(key)
            if k is None:
                n = decode(key)
                k = cache[key] = band(n[0] * light[0] + n[1] * light[1] + n[2] * light[2], bands)
            o_px[x, y] = tone((r, g, b), k, shadow, glow) + (255,)
    return out


def downscale(im, size):
    """Shrink with a box filter (Pillow premultiplies RGBA, so no dark fringe), then make the alpha crisp: half covered or more is solid."""
    small = im.resize(size, Image.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return small


def outline(im, dark=0.35):
    """A one pixel outline outside the sprite (4-neighbours), each pixel the average colour of what it touches, darkened."""
    out = im.copy()
    src, dst = im.load(), out.load()
    for y in range(im.height):
        for x in range(im.width):
            if src[x, y][3]:
                continue
            near = [src[nx, ny] for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                    if 0 <= nx < im.width and 0 <= ny < im.height and src[nx, ny][3]]
            if near:
                dst[x, y] = tuple(int(sum(p[i] for p in near) / len(near) * dark) for i in range(3)) + (255,)
    return out


def palette(images, colours):
    """One palette (a Pillow 'P' image) for all the images' opaque pixels."""
    pixels = [p[:3] for im in images for p in im.getdata() if p[3]]
    strip = Image.new("RGB", (max(1, len(pixels)), 1))
    strip.putdata(pixels or [(0, 0, 0)])
    return strip.quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def apply_palette(im, pal):
    """The image with its opaque pixels snapped to the palette; alpha is untouched."""
    snapped = im.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    src, snap, dst = im.load(), snapped.load(), out.load()
    for y in range(im.height):
        for x in range(im.width):
            if src[x, y][3]:
                dst[x, y] = snap[x, y][:3] + (255,)
    return out


def palette_colours(materials, bands=BANDS, shadow=None, glow=None, dark=0.35):
    """Every colour a creature can show: each material colour in each band, and each of those darkened for the outline."""
    seen = []
    for rgb in materials:
        for _, k in bands:
            c = tone(rgb, k, shadow, glow)
            for colour in (c, tuple(int(v * dark) for v in c)):
                if colour not in seen:
                    seen.append(colour)
    return seen


def palette_of(colours):
    """A Pillow 'P' image whose palette is exactly these colours (at most 256)."""
    pal = Image.new("P", (1, 1))
    flat = [v for c in colours[:256] for v in c]
    pal.putpalette(flat + [0] * (768 - len(flat)))
    return pal
