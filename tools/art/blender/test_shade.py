"""The v2 shading: ramps per material, shaded at final resolution so every pixel is an exact ramp colour (shade.py). Pure Pillow."""
import math
import os
import sys
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shade  # noqa: E402

GREEN = (110, 150, 70)
RED = (190, 60, 50)


def enc(n):
    return tuple(int(round((c * 0.5 + 0.5) * 255)) for c in shade.unit(n)) + (255,)


def flat(colour, n, size=(1, 1)):
    return Image.new("RGBA", size, colour + (255,)), Image.new("RGBA", size, enc(n))


class RampTest(unittest.TestCase):
    def test_a_ramp_runs_dark_to_light_with_the_base_in_the_middle(self):
        r = shade.ramp(GREEN)
        self.assertEqual(len(r), 5)
        self.assertEqual(r[2], GREEN)
        value = [max(c) for c in r]
        self.assertEqual(value, sorted(value))
        self.assertEqual(len(set(r)), 5)

    def test_shadows_shift_toward_violet_and_lights_toward_warm_yellow(self):
        import colorsys
        r = shade.ramp(GREEN)
        hue = lambda c: colorsys.rgb_to_hsv(*(v / 255.0 for v in c))[0]
        away = lambda h, target: min(abs(h - target), 1 - abs(h - target))
        for dark in (r[0], r[1]):
            self.assertLess(away(hue(dark), 0.72), away(hue(GREEN), 0.72))
        for light in (r[3], r[4]):
            self.assertLess(away(hue(light), 0.12), away(hue(GREEN), 0.12))
        self.assertLess(colorsys.rgb_to_hsv(*(v / 255.0 for v in r[4]))[1], colorsys.rgb_to_hsv(*(v / 255.0 for v in GREEN))[1], "highlights are paler")

    def test_a_baked_ramp_keeps_only_the_middle_steps(self):
        self.assertEqual(shade.ramp(GREEN, bake=0.5), shade.ramp(GREEN)[1:4])
        self.assertEqual(shade.ramp(GREEN, bake=0.0), [GREEN])


class ReduceTest(unittest.TestCase):
    def test_materials_snap_and_alpha_is_crisp(self):
        a = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        n = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for y in range(8):
            for x in range(7):  # seven of eight columns drawn: the right-hand cells are three quarters covered
                a.putpixel((x, y), (112, 148, 72, 255))  # close to GREEN, not exactly
                n.putpixel((x, y), enc((0, 0, 1)))
        small_a, _ = shade.reduce_passes(a, n, (2, 2), [GREEN, RED])
        self.assertEqual(small_a.getpixel((0, 0)), GREEN + (255,))
        self.assertEqual(small_a.getpixel((1, 0)), GREEN + (255,), "three quarters covered is solid")
        a2 = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        n2 = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        for y in range(2):
            for x in range(2):  # a quarter of a 4x4 cell
                a2.putpixel((x, y), (190, 60, 50, 255))
                n2.putpixel((x, y), enc((0, 0, 1)))
        sa, _ = shade.reduce_passes(a2, n2, (2, 2), [GREEN, RED])
        self.assertEqual(sa.getpixel((0, 0))[3], 0, "a quarter covered is dropped")

    def test_normals_are_averaged_and_renormalised(self):
        a = Image.new("RGBA", (2, 1), GREEN + (255,))
        n = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        n.putpixel((0, 0), enc((1, 0, 0)))
        n.putpixel((1, 0), enc((0, 0, 1)))
        _, sn = shade.reduce_passes(a, n, (1, 1), [GREEN])
        x, y, z = (c / 255.0 * 2.0 - 1.0 for c in sn.getpixel((0, 0))[:3])  # the raw colour, not normalised for us
        self.assertAlmostEqual(math.sqrt(x * x + y * y + z * z), 1.0, delta=0.03)
        self.assertGreater(x, 0.4)
        self.assertGreater(z, 0.4)


class ShadeTest(unittest.TestCase):
    def test_a_surface_facing_the_light_takes_the_light_end_and_one_facing_away_the_dark_end(self):
        lit = shade.unit(shade.LIGHT)
        away = tuple(-c for c in lit)
        ramp = shade.ramp(GREEN)
        a, n = flat(GREEN, lit)
        self.assertEqual(shade.shade(a, n).getpixel((0, 0))[:3], ramp[4])
        a, n = flat(GREEN, away)
        self.assertEqual(shade.shade(a, n).getpixel((0, 0))[:3], ramp[0])

    def test_every_pixel_is_an_exact_ramp_colour(self):
        size = 24
        a = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        n = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        for y in range(size):
            for x in range(size):
                nx, ny = (x - 11.5) / 11.5, -(y - 11.5) / 11.5
                if nx * nx + ny * ny < 1:
                    a.putpixel((x, y), GREEN + (255,))
                    n.putpixel((x, y), enc((nx, ny, math.sqrt(1 - nx * nx - ny * ny))))
        out = shade.shade(a, n)
        seen = {out.getpixel((x, y))[:3] for x in range(size) for y in range(size) if out.getpixel((x, y))[3]}
        self.assertTrue(seen <= set(shade.ramp(GREEN)), seen)
        self.assertGreaterEqual(len(seen), 4, "a sphere shows most of the ramp")

    def test_empty_pixels_stay_empty(self):
        a = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        n = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        self.assertEqual(shade.shade(a, n).getpixel((1, 0))[3], 0)

    def test_an_edge_turned_from_the_camera_toward_the_back_light_catches_a_rim(self):
        rim = shade.unit(shade.RIM)
        edge = shade.unit((rim[0], rim[1], 0.05))
        away_from_key = shade.unit((0.9, -0.3, 0.05))
        ramp = shade.ramp(GREEN)
        a, n = flat(GREEN, edge)
        with_rim = shade.shade(a, n).getpixel((0, 0))[:3]
        without = shade.shade(a, n, rim=False).getpixel((0, 0))[:3]
        self.assertGreater(ramp.index(with_rim), ramp.index(without))

    def test_a_sharp_crease_darkens_the_darker_side(self):
        a = Image.new("RGBA", (2, 1), GREEN + (255,))
        n = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        n.putpixel((0, 0), enc(shade.LIGHT))            # facing the key light
        n.putpixel((1, 0), enc((-0.2, -0.3, 0.9)))      # a different surface, turned well away from it
        plain = shade.shade(a, n, creases=False)
        creased = shade.shade(a, n, creases=True)
        ramp = shade.ramp(GREEN)
        self.assertEqual(creased.getpixel((0, 0)), plain.getpixel((0, 0)))
        self.assertLess(ramp.index(creased.getpixel((1, 0))[:3]), ramp.index(plain.getpixel((1, 0))[:3]))

    def test_a_lower_bake_uses_fewer_steps(self):
        lit = shade.unit(shade.LIGHT)
        a, n = flat(GREEN, lit)
        self.assertEqual(shade.shade(a, n, bake=0.5).getpixel((0, 0))[:3], shade.ramp(GREEN)[3])


class HysteresisTest(unittest.TestCase):
    def half_covered(self):
        a = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        n = Image.new("RGBA", (2, 1), (0, 0, 0, 0))
        a.putpixel((0, 0), GREEN + (255,))   # one of two covered: exactly on the edge of existing
        n.putpixel((0, 0), enc((0, 0, 1)))
        return a, n

    def test_an_edge_pixel_on_the_fence_keeps_what_it_was_last_frame(self):
        a, n = self.half_covered()
        was_there = Image.new("RGBA", (1, 1), GREEN + (255,))
        was_empty = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
        kept, _ = shade.reduce_passes(a, n, (1, 1), [GREEN], previous=was_there)
        gone, _ = shade.reduce_passes(a, n, (1, 1), [GREEN], previous=was_empty)
        self.assertEqual(kept.getpixel((0, 0))[3], 255)
        self.assertEqual(gone.getpixel((0, 0))[3], 0)

    def test_a_clear_change_still_changes(self):
        a = Image.new("RGBA", (2, 1), GREEN + (255,))
        n = Image.new("RGBA", (2, 1), enc((0, 0, 1)))
        was_empty = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
        now, _ = shade.reduce_passes(a, n, (1, 1), [GREEN], previous=was_empty)
        self.assertEqual(now.getpixel((0, 0))[3], 255, "fully covered appears whatever it was")

    def test_a_pixel_just_past_a_shading_boundary_stays_on_its_old_step_but_a_clear_move_goes(self):
        ramp = shade.ramp(GREEN)
        edge = shade.BANDS[2]  # between steps 2 and 3
        def lit(lum):
            """A normal whose angle to the key light has exactly this cosine."""
            key = shade.unit(shade.LIGHT)
            rest = shade.unit((-key[1], key[0], 0.0))
            side = math.sqrt(max(0.0, 1 - lum * lum))
            return shade.encode(tuple(lum * key[i] + side * rest[i] for i in range(3)))
        a = Image.new("RGBA", (1, 1), GREEN + (255,))
        prev_steps = {(0, 0): (GREEN, 2)}
        near = Image.new("RGBA", (1, 1), lit(edge + 0.02) + (255,))
        far = Image.new("RGBA", (1, 1), lit(edge + 0.2) + (255,))
        stays = shade.shade(a, near, creases=False, rim=False, previous=prev_steps)
        goes = shade.shade(a, far, creases=False, rim=False, previous=prev_steps)
        recorded = {}
        shade.shade(a, far, creases=False, rim=False, record=recorded)
        self.assertEqual(recorded, {(0, 0): (GREEN, 3)})
        self.assertEqual(stays.getpixel((0, 0))[:3], ramp[2])
        self.assertEqual(goes.getpixel((0, 0))[:3], ramp[3])

    def test_a_pixel_that_now_shows_another_material_does_not_inherit_the_old_ones_step(self):
        ramp = shade.ramp(GREEN)
        edge = shade.BANDS[2]
        key = shade.unit(shade.LIGHT)
        rest = shade.unit((-key[1], key[0], 0.0))
        lum = edge + 0.02
        n = shade.encode(tuple(lum * key[i] + math.sqrt(1 - lum * lum) * rest[i] for i in range(3)))
        a = Image.new("RGBA", (1, 1), GREEN + (255,))
        normal = Image.new("RGBA", (1, 1), n + (255,))
        inherited = shade.shade(a, normal, creases=False, rim=False, previous={(0, 0): (RED, 2)})
        self.assertEqual(inherited.getpixel((0, 0))[:3], ramp[3], "the red there before is not the green here: its history does not hold it back")


class PaletteTest(unittest.TestCase):
    def test_a_creature_with_a_great_many_materials_gets_a_palette_that_fits_with_every_ramp_in_it(self):
        materials = [((i * 37) % 256, (i * 91) % 256, (i * 53) % 256) for i in range(45)]
        colours = shade.palette_colours(materials)
        self.assertLessEqual(len(colours), 256)
        for m in materials:
            for c in shade.ramp(m):
                self.assertIn(shade.unkey(c), colours)   # a ramp colour on the background key is in it moved off the key

    def test_the_palette_of_a_creature_is_its_ramps_and_the_outline_darks(self):
        colours = shade.palette_colours([GREEN, RED])
        for c in shade.ramp(GREEN) + shade.ramp(RED):
            self.assertIn(c, colours)
        self.assertTrue(any(max(c) < min(max(g) for g in shade.ramp(GREEN)) for c in colours), "the outline darks are in it")


class UnkeyTest(unittest.TestCase):
    @staticmethod
    def keyed(c):   # tools/art/slice_sheets.keyed: what the assembler erases as the background
        r, g, b = c[:3]
        return r > 150 and b > 150 and g < 120 and min(r, b) - g > 60

    def test_a_colour_the_background_key_would_erase_is_pulled_clear_of_it_and_stays_close(self):
        c = shade.unkey((190, 113, 224))
        self.assertFalse(self.keyed(c))
        self.assertLessEqual(max(abs(a - b) for a, b in zip(c, (190, 113, 224))), 20)

    def test_a_colour_the_key_leaves_alone_is_not_touched(self):
        for c in ((40, 80, 200), (255, 140, 255), (200, 60, 60), (190, 130, 224)):
            self.assertEqual(shade.unkey(c), c)

    def test_every_colour_of_the_range_comes_out_clear(self):
        for r in range(0, 256, 15):
            for g in range(0, 256, 15):
                for b in range(0, 256, 15):
                    self.assertFalse(self.keyed(shade.unkey((r, g, b))), (r, g, b))


class StaleFramesTest(unittest.TestCase):
    def test_a_rerender_with_fewer_frames_leaves_none_of_the_old_ones(self):
        import tempfile
        import spike
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("run_0.png", "run_0_n.png", "run_8.png", "run_8_n.png", "idle_0.png", "gone_3.png", "gone_3_n.png", "notes.txt"):
                open(os.path.join(tmp, name), "w").close()
            spike.clear_stale(tmp, ["run_0", "idle_0"])
            self.assertEqual(sorted(os.listdir(tmp)), ["idle_0.png", "notes.txt", "run_0.png", "run_0_n.png"])


if __name__ == "__main__":
    unittest.main()
