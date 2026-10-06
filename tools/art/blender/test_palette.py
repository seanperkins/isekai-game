"""Colour roles (palette.py): the body is the primary colour, the limbs the secondary, the accents the tertiary, and the limbs are guaranteed to stand apart from the body in
value, so a leg in front of the body does not get lost in it. Pure Python."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette as pal  # noqa: E402
import spider_forms as sf  # noqa: E402


class ApartTest(unittest.TestCase):
    def test_a_limb_as_dark_as_the_body_is_lightened_until_it_stands_the_gap_apart(self):
        body = (54, 49, 65)
        limb = pal.apart(body, (53, 45, 61), 30)
        self.assertGreaterEqual(pal.luma(limb) - pal.luma(body), 29.0)
        self.assertLess(pal.dist(limb, (53, 45, 61)), 140, "and it is still the same family of colour")

    def test_a_limb_that_already_stands_apart_is_left_alone(self):
        self.assertEqual(pal.apart((54, 49, 65), (140, 120, 150), 30), (140, 120, 150))
        self.assertEqual(pal.apart((200, 200, 210), (60, 60, 70), 30), (60, 60, 70))

    def test_a_light_body_gets_a_darker_limb_not_a_lighter_one(self):
        limb = pal.apart((220, 214, 224), (214, 208, 218), 30)
        self.assertLessEqual(pal.luma(limb), pal.luma((220, 214, 224)) - 29.0)

    def test_the_result_is_a_valid_colour(self):
        for body in ((0, 0, 0), (255, 255, 255), (40, 36, 48), (230, 20, 30)):
            for limb in ((0, 0, 0), (255, 255, 255), (60, 60, 60)):
                out = pal.apart(body, limb, 30)
                self.assertTrue(all(0 <= c <= 255 and isinstance(c, int) for c in out), (body, limb, out))


class SpiderRolesTest(unittest.TestCase):
    def test_every_spiders_legs_stand_apart_from_its_body_in_value(self):
        for name, form in sf.FORMS.items():
            c = sf.colours_of(form)
            self.assertGreaterEqual(abs(pal.luma(c["leg"]) - pal.luma(c["chitin"])), sf.LEG_GAP - 1.0, "%s: the legs do not get lost in the body" % name)

    def test_every_spiders_accent_is_a_different_colour_from_its_legs(self):
        for name, form in sf.FORMS.items():
            c = sf.colours_of(form)
            self.assertGreaterEqual(pal.dist(c["joint"], c["leg"]), 60.0, "%s: the knee rings read against the leg" % name)


if __name__ == "__main__":
    unittest.main()
