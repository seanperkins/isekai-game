import math
import os
import sys
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toon  # noqa: E402

RED = (200, 40, 40, 255)


def solid(w, h, rgba):
    return Image.new("RGBA", (w, h), rgba)


def encode(n):
    """A unit normal as the render's colour: each axis mapped from -1..1 to 0..255."""
    return tuple(int(round((c * 0.5 + 0.5) * 255)) for c in n) + (255,)


def facing(n):
    return Image.new("RGBA", (1, 1), encode(n))


def brightness(im):
    r, g, b, _ = im.getpixel((0, 0))
    return r / 200.0  # the albedo's red channel is 200


class ShadeTest(unittest.TestCase):
    def test_a_surface_facing_the_light_is_the_brightest_band_and_one_facing_away_the_darkest(self):
        lit = toon.unit(toon.LIGHT)
        away = tuple(-c for c in lit)
        albedo = solid(1, 1, RED)
        self.assertAlmostEqual(brightness(toon.shade(albedo, facing(lit))), toon.BANDS[-1][1], places=1)
        self.assertAlmostEqual(brightness(toon.shade(albedo, facing(away))), toon.BANDS[0][1], places=1)

    def test_the_shadow_band_leans_toward_a_cool_tint_and_the_lit_band_toward_a_warm_one(self):
        lit = toon.unit(toon.LIGHT)
        away = tuple(-c for c in lit)
        albedo = solid(1, 1, (120, 120, 120, 255))
        plain_dark = toon.shade(albedo, facing(away)).getpixel((0, 0))
        tinted_dark = toon.shade(albedo, facing(away), shadow=((40, 20, 200), 0.5)).getpixel((0, 0))
        self.assertGreater(tinted_dark[2], plain_dark[2], "more blue in the shadow")
        self.assertLess(tinted_dark[0], plain_dark[0] + 1, "and no more red")
        plain_lit = toon.shade(albedo, facing(lit)).getpixel((0, 0))
        warm_lit = toon.shade(albedo, facing(lit), glow=((255, 230, 120), 2.0)).getpixel((0, 0))
        self.assertGreater(warm_lit[0], plain_lit[0])
        self.assertGreater(warm_lit[0] - warm_lit[2], plain_lit[0] - plain_lit[2], "warmer: red up against blue")

    def test_a_tint_never_overflows_a_channel(self):
        lit = toon.unit(toon.LIGHT)
        out = toon.shade(solid(1, 1, (250, 250, 250, 255)), facing(lit), glow=((255, 255, 255), 1.0)).getpixel((0, 0))
        self.assertEqual(out[:3], (255, 255, 255))

    def test_rigkit_and_toon_agree_on_where_the_light_is(self):
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "rigkit.py")) as fh:
            source = fh.read()
        line = [l for l in source.split("\n") if l.startswith("LIGHT = ")][0]
        self.assertEqual(eval(line.split("=", 1)[1].split("#")[0]), toon.LIGHT)

    def test_a_shaded_sphere_has_only_as_many_brightnesses_as_there_are_bands(self):
        size = 40
        normal = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        albedo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        for y in range(size):
            for x in range(size):
                nx, ny = (x - 19.5) / 19.5, -(y - 19.5) / 19.5
                if nx * nx + ny * ny < 1:
                    normal.putpixel((x, y), encode((nx, ny, math.sqrt(1 - nx * nx - ny * ny))))
                    albedo.putpixel((x, y), RED)
        out = toon.shade(albedo, normal)
        seen = {out.getpixel((x, y))[0] for y in range(size) for x in range(size) if out.getpixel((x, y))[3]}
        self.assertEqual(len(seen), len(toon.BANDS))

    def test_empty_pixels_stay_empty_and_alpha_comes_from_the_albedo(self):
        albedo = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        albedo.putpixel((0, 0), RED)
        normal = solid(2, 1, encode((0, 0, 1)))
        out = toon.shade(albedo, normal)
        self.assertEqual(out.getpixel((1, 0))[3], 0)
        self.assertEqual(out.getpixel((0, 0))[3], 255)


class ToneTest(unittest.TestCase):
    def test_tone_is_what_shade_does_to_one_colour(self):
        lit = toon.unit(toon.LIGHT)
        for n in (lit, tuple(-c for c in lit)):
            via_shade = toon.shade(solid(1, 1, (100, 150, 60, 255)), facing(n), shadow=((60, 50, 130), 0.55), glow=((255, 236, 190), 0.5)).getpixel((0, 0))[:3]
            k = toon.band(sum(a * b for a, b in zip(n, toon.unit(toon.LIGHT))))
            self.assertEqual(toon.tone((100, 150, 60), k, shadow=((60, 50, 130), 0.55), glow=((255, 236, 190), 0.5)), via_shade)

    def test_the_palette_of_a_creature_keeps_every_material_in_every_band(self):
        colours = [(200, 40, 40), (40, 200, 40)]
        pal = toon.palette_of(toon.palette_colours(colours))
        wanted = {tuple(min(255, int(c * k)) for c in rgb) for rgb in colours for _, k in toon.BANDS}
        got = {toon.apply_palette(solid(1, 1, c + (255,)), pal).getpixel((0, 0))[:3] for c in wanted}
        self.assertEqual(got, wanted, "a small part's colour is never merged into a big one's")


class DownscaleTest(unittest.TestCase):
    def test_downscale_averages_and_keeps_alpha_crisp_without_a_dark_fringe(self):
        big = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for y in range(8):
            for x in range(6):  # 6 of 8 columns drawn: the edge pixel of a 4x4 shrink is half covered
                big.putpixel((x, y), RED)
        out = toon.downscale(big, (2, 2))
        self.assertEqual({out.getpixel((x, y))[3] for x in range(2) for y in range(2)}, {255})
        for p in ((0, 0), (1, 0)):  # (1, 0) is the half-covered edge pixel
            for got, want in zip(out.getpixel(p)[:3], RED[:3]):
                self.assertAlmostEqual(got, want, delta=2, msg="the sprite's colour, not a darker fringe")

    def test_a_pixel_less_than_half_covered_is_dropped(self):
        big = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for y in range(8):
            for x in range(5):  # 5 of 8 columns: the second 4-wide cell is 1/4 covered
                big.putpixel((x, y), RED)
        out = toon.downscale(big, (2, 2))
        self.assertEqual(out.getpixel((1, 0))[3], 0)


class OutlineTest(unittest.TestCase):
    def test_the_outline_rings_the_sprite_and_leaves_its_pixels_alone(self):
        im = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
        im.putpixel((2, 2), RED)
        out = toon.outline(im)
        self.assertEqual(out.getpixel((2, 2)), RED)
        for p in ((1, 2), (3, 2), (2, 1), (2, 3)):
            self.assertEqual(out.getpixel(p)[3], 255)
            self.assertLess(out.getpixel(p)[0], RED[0], "darker than the sprite")
        self.assertEqual(out.getpixel((1, 1))[3], 0, "four-neighbours only: no corners")
        self.assertEqual(out.getpixel((0, 0))[3], 0)

    def test_an_opaque_pixel_next_to_another_keeps_its_colour(self):
        im = Image.new("RGBA", (4, 3), (0, 0, 0, 0))
        im.putpixel((1, 1), RED)
        im.putpixel((2, 1), (40, 200, 40, 255))
        out = toon.outline(im)
        self.assertEqual(out.getpixel((1, 1)), RED)
        self.assertEqual(out.getpixel((2, 1)), (40, 200, 40, 255))


class PaletteTest(unittest.TestCase):
    def test_a_palette_limits_the_colours_and_keeps_alpha(self):
        im = Image.new("RGBA", (16, 1), (0, 0, 0, 0))
        for x in range(12):
            im.putpixel((x, 0), (x * 20, 255 - x * 20, 7 * x, 255))
        pal = toon.palette([im], 4)
        out = toon.apply_palette(im, pal)
        colours = {out.getpixel((x, 0))[:3] for x in range(12)}
        self.assertLessEqual(len(colours), 4)
        self.assertEqual(out.getpixel((15, 0))[3], 0)
        self.assertEqual(out.getpixel((3, 0))[3], 255)

    def test_one_palette_serves_every_frame_of_a_set(self):
        a = solid(2, 2, (250, 10, 10, 255))
        b = solid(2, 2, (10, 10, 250, 255))
        pal = toon.palette([a, b], 2)
        self.assertEqual(toon.apply_palette(a, pal).getpixel((0, 0))[:3], toon.apply_palette(solid(2, 2, (240, 20, 20, 255)), pal).getpixel((0, 0))[:3])


if __name__ == "__main__":
    unittest.main()
