import os
import sys
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assemble_frames as a  # noqa: E402

MAGENTA = (255, 0, 255, 255)
BLUE = (40, 120, 255, 255)


def frame(w, h, box, color=BLUE):
    """A magenta canvas with a solid rectangle `box` = (x0, y0, x1, y1)."""
    im = Image.new("RGBA", (w, h), MAGENTA)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            im.putpixel((x, y), color)
    return im


class AssembleFramesTest(unittest.TestCase):
    def test_fit_scales_to_the_width_and_keeps_the_aspect(self):
        out = a.fit_frame(frame(100, 50, (20, 10, 80, 40)), 30)  # the subject is 60x30
        self.assertEqual(out.size, (30, 15))

    def test_fit_keys_the_magenta_out_and_keeps_alpha_crisp(self):
        out = a.fit_frame(frame(100, 50, (20, 10, 80, 40)), 30)
        self.assertEqual(out.getpixel((0, 0))[3] in (0, 255), True)
        alphas = {p[3] for p in out.getdata()}
        self.assertTrue(alphas <= {0, 255})
        self.assertEqual(out.getpixel((15, 7))[3], 255)

    def test_a_shared_scale_keeps_relative_sizes(self):
        wide = frame(100, 50, (10, 10, 90, 40))   # subject 80x30
        narrow = frame(100, 50, (30, 5, 70, 45))  # subject 40x40
        scale = a.anchor_scale(wide, 40)          # the anchor is drawn 40 px wide: 0.5x
        self.assertAlmostEqual(scale, 0.5)
        self.assertEqual(a.fit_scaled(wide, scale).size, (40, 15))
        self.assertEqual(a.fit_scaled(narrow, scale).size, (20, 20), "a narrower drawing stays narrower")

    def test_fit_rejects_an_empty_frame(self):
        with self.assertRaises(ValueError):
            a.fit_frame(Image.new("RGBA", (10, 10), MAGENTA), 5)

    def test_the_hull_of_a_solid_block_is_its_four_corners(self):
        im = Image.new("RGBA", (10, 6), BLUE)
        hull = a.convex_hull(a.boundary_corners(im))
        self.assertEqual(set(hull), {(0, 0), (10, 0), (10, 6), (0, 6)})

    def test_shapes_are_local_to_the_bottom_centre(self):
        im = Image.new("RGBA", (10, 6), BLUE)
        hurt, attack = a.trace(im, None)
        self.assertEqual(set(map(tuple, hurt)), {(-5.0, -6.0), (5.0, -6.0), (5.0, 0.0), (-5.0, 0.0)})
        self.assertEqual(attack, [])

    def test_the_attack_shape_is_the_front_slice(self):
        im = Image.new("RGBA", (10, 6), BLUE)
        _, attack = a.trace(im, 0.5)
        xs = [p[0] for p in attack]
        self.assertEqual((min(xs), max(xs)), (0.0, 5.0))

    def test_the_hull_contains_every_opaque_pixel_of_a_blob(self):
        im = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
        for y in range(20):
            for x in range(20):
                if (x - 10) ** 2 + (y - 10) ** 2 <= 64:
                    im.putpixel((x, y), BLUE)
        hull = a.convex_hull(a.boundary_corners(im))
        for y in range(20):
            for x in range(20):
                if im.getpixel((x, y))[3] == 255:
                    c = (x + 0.5, y + 0.5)
                    for i in range(len(hull)):
                        p, q = hull[i], hull[(i + 1) % len(hull)]
                        cross = (q[0] - p[0]) * (c[1] - p[1]) - (q[1] - p[1]) * (c[0] - p[0])
                        self.assertGreaterEqual(cross, -1e-9, "pixel %s outside the hull" % (c,))

    @staticmethod
    def _poly_area(poly):
        return abs(sum(p[0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * p[1]
                       for i, p in enumerate(poly))) / 2.0

    @staticmethod
    def _inside(poly, c):
        inside = False
        for i in range(len(poly)):
            (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
            if (y1 > c[1]) != (y2 > c[1]) and c[0] < (x2 - x1) * (c[1] - y1) / (y2 - y1) + x1:
                inside = not inside
        return inside

    def _l_shape(self):
        """A tall bar on the left with a long low tail: a convex hull would fill the empty corner."""
        im = Image.new("RGBA", (30, 20), (0, 0, 0, 0))
        for y in range(4, 20):
            for x in range(0, 6):
                im.putpixel((x, y), BLUE)
        for y in range(16, 20):
            for x in range(6, 30):
                im.putpixel((x, y), BLUE)
        return im

    def test_the_outline_follows_the_drawn_pixels_not_the_hull(self):
        im = self._l_shape()
        opaque = sum(1 for p in im.getdata() if p[3] == 255)
        outline = a.outline(im)
        hull = a.convex_hull(a.boundary_corners(im))
        self.assertLess(self._poly_area(outline), opaque * 1.1, "hugs the pixels")
        self.assertGreater(self._poly_area(hull), opaque * 1.5, "the hull is the loose thing this replaces")

    def test_the_outline_contains_every_opaque_pixel_and_stays_small(self):
        im = self._l_shape()
        outline = a.outline(im)
        for y in range(im.height):
            for x in range(im.width):
                if im.getpixel((x, y))[3] == 255:
                    self.assertTrue(self._inside(outline, (x + 0.5, y + 0.5)), "pixel %d,%d outside" % (x, y))
        self.assertLess(len(outline), 20, "simplified")

    def test_a_solid_block_outlines_to_its_four_corners(self):
        outline = a.outline(Image.new("RGBA", (10, 6), BLUE))
        self.assertEqual(set(outline), {(0, 0), (10, 0), (10, 6), (0, 6)})

    def test_pack_places_every_frame_without_overlap_inside_the_sheet(self):
        frames = {"a": Image.new("RGBA", (200, 30)), "b": Image.new("RGBA", (200, 20)),
                  "c": Image.new("RGBA", (200, 40)), "d": Image.new("RGBA", (10, 10))}
        sheet, rects = a.pack(frames)
        self.assertLessEqual(sheet.width, a.SHEET_WIDTH)
        boxes = list(rects.values())
        for i, (x, y, w, h) in enumerate(boxes):
            self.assertTrue(x >= 0 and y >= 0 and x + w <= sheet.width and y + h <= sheet.height)
            for (x2, y2, w2, h2) in boxes[i + 1:]:
                self.assertTrue(x + w <= x2 or x2 + w2 <= x or y + h <= y2 or y2 + h2 <= y)
        self.assertEqual(set(rects), set(frames))


class DeriveTests(unittest.TestCase):
    def test_lightening_runs_on_the_keyed_crop_so_the_key_is_still_removed(self):
        im = frame(20, 20, (5, 5, 15, 15))
        out = a.fit_scaled(im, 1.0, {"lighten": 0.5})
        self.assertEqual(out.size, (10, 10))
        # every pixel is opaque: the magenta background was keyed and cropped away BEFORE any blending
        self.assertTrue(all(p[3] == 255 for p in out.getdata()))

    def test_lightening_blends_rgb_toward_white_and_keeps_alpha(self):
        im = frame(20, 20, (5, 5, 15, 15))
        plain = a.fit_scaled(im, 1.0)
        lighter = a.fit_scaled(im, 1.0, {"lighten": 0.5})
        p, q = plain.getpixel((2, 2)), lighter.getpixel((2, 2))
        for c in (0, 1):  # BLUE's blue channel is already 255
            self.assertGreater(q[c], p[c])
        self.assertEqual(q[3], p[3])
        self.assertEqual(q[:3], tuple(round(v + (255 - v) * 0.5) for v in p[:3]))

    def test_a_tint_blends_toward_its_colour_by_its_amount(self):
        im = frame(20, 20, (5, 5, 15, 15))
        out = a.fit_scaled(im, 1.0, {"tint": [200, 190, 255], "tint_amount": 0.5})
        px = out.getpixel((2, 2))
        self.assertEqual(px[:3], tuple(round(v + (t - v) * 0.5) for v, t in zip(BLUE[:3], (200, 190, 255))))

    def test_no_look_changes_nothing(self):
        im = frame(20, 20, (5, 5, 15, 15))
        self.assertEqual(list(a.fit_scaled(im, 1.0).getdata()), list(a.fit_scaled(im, 1.0, None).getdata()))


if __name__ == "__main__":
    unittest.main()
