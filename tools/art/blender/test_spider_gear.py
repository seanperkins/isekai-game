"""The spider's gear that can be checked without Blender: what a marking asks the kit to paint."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spider_gear as sg  # noqa: E402


class FakeKit:
    mark = (200, 30, 40)

    def __init__(self):
        self.shapes = []

    def painted(self, name, outline, rgb, glow=False):
        self.shapes.append((name, list(outline), rgb, glow))

    def mark_line(self, name, a, b, width, rgb, glow=False):
        self.shapes.append((name, [a, b], rgb, glow))


class HourglassTest(unittest.TestCase):
    def test_the_plain_hourglass_is_two_triangles_meeting_point_to_point_one_above_the_other(self):
        g = FakeKit()
        sg.hourglass(g)
        self.assertEqual([n for n, *_ in g.shapes], ["glass_top", "glass_low"])
        top, low = g.shapes[0][1], g.shapes[1][1]
        self.assertGreater(min(v for _, v in top), 0.0, "the upper triangle is above the middle")
        self.assertLess(max(v for _, v in low), 0.0, "the lower one is below it")
        self.assertLess(min(v for _, v in top) - max(v for _, v in low), 0.2, "and they nearly touch at the waist")
        self.assertGreater(max(abs(u) for u, _ in top), 3 * min(abs(u) for u, v in top if v == min(w for _, w in top)), "each is wide at its far edge and narrow at the waist")

    def test_it_glows_so_it_reads_in_the_dark_and_at_a_few_pixels(self):
        g = FakeKit()
        sg.hourglass(g)
        self.assertTrue(all(glow for *_, glow in g.shapes))

    def test_a_slim_one_is_narrower(self):
        plain, slim = FakeKit(), FakeKit()
        sg.hourglass(plain)
        sg.hourglass(slim, slim=True)
        width = lambda kit: max(abs(u) for _, outline, _, _ in kit.shapes for u, _ in outline)
        self.assertLess(width(slim), width(plain))

    def test_the_cracked_and_woven_variants_stay_as_lines(self):
        for kw in ({"cracks": True}, {"woven": True}):
            g = FakeKit()
            sg.hourglass(g, **kw)
            self.assertTrue(g.shapes)
            self.assertTrue(all(len(outline) == 2 for _, outline, _, _ in g.shapes), kw)


if __name__ == "__main__":
    unittest.main()
