"""The photo stage's numbers: the camera every bake and every movement review shares (stage.py). Pure Python."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stage  # noqa: E402


class CameraTests(unittest.TestCase):
    def test_the_ortho_scale_is_the_canvas_in_units(self):
        self.assertEqual(stage.camera_params(128, 40.0, 12, 2)["ortho_scale"], 128 / 40.0)

    def test_the_ground_sits_margin_pixels_above_the_bottom_of_the_frame(self):
        p = stage.camera_params(128, 40.0, 12, 2, 0.0)
        # the camera looks along +Y from -Y, centred on the canvas's middle height lifted by the margin
        self.assertEqual(p["location"], (0.0, -stage.CAMERA["y_distance"], 128 / 80.0 - 12 / 40.0))
        self.assertEqual(p["rotation_deg"], (90.0, 0.0, 0.0))

    def test_the_camera_follows_the_creature_sideways(self):
        self.assertEqual(stage.camera_params(128, 40.0, 12, 2, 1.5)["location"][0], 1.5)

    def test_the_render_is_the_canvas_times_the_supersample(self):
        self.assertEqual(stage.camera_params(128, 40.0, 12, 4)["resolution"], 512)


class TrackingCameraTests(unittest.TestCase):
    def test_a_tracking_view_is_as_wide_as_asked_and_centred_where_told(self):
        p = stage.tracking_camera_params(360.0, 40.0, 7.5, 2.0)
        self.assertEqual(p["ortho_scale"], 9.0)
        self.assertEqual(p["location"], (7.5, -stage.CAMERA["y_distance"], 2.0))
        self.assertEqual(p["rotation_deg"], (90.0, 0.0, 0.0))


class UnitTests(unittest.TestCase):
    def test_a_grid_step_is_sixteen_game_pixels(self):
        self.assertEqual(stage.GRID_PX, 16)

    def test_pixels_become_units_at_the_scale(self):
        self.assertEqual(stage.px_to_units(16, 40.0), 0.4)
        self.assertEqual(stage.px_to_units(0, 40.0), 0.0)

    def test_the_game_plane_maps_to_x_right_z_up(self):
        # the game's y points down: a ledge top 40 px above the floor is 40 px of height
        self.assertEqual(stage.game_to_stage((400.0, -40.0), 40.0), (10.0, 1.0))
        self.assertEqual(stage.game_to_stage((0.0, 0.0), 40.0), (0.0, 0.0))


if __name__ == "__main__":
    unittest.main()
