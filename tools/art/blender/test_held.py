"""The held-item layer's pure rules (held.py): which gear is held, the item ids, the scale, the camera maths and the data table. No Blender."""
import ast
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import goblin_forms as forms  # noqa: E402
import held  # noqa: E402
import stage  # noqa: E402


def item_bone_functions():
    """{function name: default side} for every function of goblin_gear.py whose source names an item bone."""
    with open(os.path.join(HERE, "goblin_gear.py")) as fh:
        text = fh.read()
    out = {}
    for node in ast.parse(text).body:
        if not isinstance(node, ast.FunctionDef) or '"item_' not in (ast.get_source_segment(text, node) or ""):
            continue
        side = "n"   # the shield names item_n outright and has no side option
        names = [a.arg for a in node.args.args]
        if "side" in names:
            default = node.args.defaults[names.index("side") - (len(names) - len(node.args.defaults))]
            side = default.value
        out[node.name] = side
    return out


class HeldPiecesTest(unittest.TestCase):
    def test_every_HELD_piece_is_exactly_a_gear_function_bound_to_an_item_bone_with_that_default_side(self):
        self.assertEqual(held.HELD, item_bone_functions())

    def test_item_ids_differ_for_different_options_and_not_for_a_different_hand(self):
        self.assertEqual(held.item_id("hammer", {}), "hammer")
        self.assertEqual(held.item_id("hammer", {"side": "n"}), "hammer")
        big = held.item_id("hammer", {"side": "n", "big": 1.15})
        self.assertNotEqual(big, "hammer")
        self.assertTrue(big.startswith("hammer_") and len(big) == len("hammer_") + 6)
        self.assertEqual(big, held.item_id("hammer", {"big": 1.15, "side": "f"}))
        self.assertEqual(held.item_id("axe", {"side": "n"}), held.item_id("axe", {"side": "f"}))

    def test_all_items_covers_every_held_piece_at_default_options_and_every_forms_items_and_gives_big_hammers_and_cyan_lanterns_their_own_ids(self):
        items = held.all_items()
        for piece in held.HELD:
            self.assertEqual(items[piece], (piece, {}), piece)   # a piece no form holds (club, staff) can still be swapped in
        for form in forms.FORMS.values():
            for item, (piece, kw) in held.items_of(form["gear"]).items():
                self.assertEqual(items[item], (piece, kw))
        mastersmith = held.held_of(forms.FORMS["mastersmith"]["gear"])["n"]
        self.assertNotEqual(mastersmith, "hammer")
        self.assertEqual(items[mastersmith][1], {"big": 1.15})
        cyan = held.held_of(forms.FORMS["puck"]["gear"])["n"]
        self.assertNotEqual(cyan, "lantern")
        self.assertIn("color", items[cyan][1])

    def test_held_of_reads_the_hands_a_form_holds(self):
        self.assertEqual(held.held_of(forms.FORMS["smith"]["gear"]), {"n": "hammer", "f": "tongs"})
        self.assertEqual(held.held_of(forms.FORMS["goblin"]["gear"]), {"n": "", "f": ""})
        leprechaun = held.held_of(forms.FORMS["leprechaun"]["gear"])
        self.assertEqual((leprechaun["n"], leprechaun["f"]), ("hammer_small", "coin"))

    def test_form_entry_has_the_scale_and_what_each_hand_holds_and_an_empty_handed_form_has_the_scale_only(self):
        self.assertEqual(held.form_entry("smith", 45.0), {"scale": round(held.form_scale(forms.FORMS["smith"], 45.0), 4), "n": "hammer", "f": "tongs"})
        self.assertEqual(held.form_entry("goblin", 30.0), {"scale": 1.0})

    def test_a_piece_with_no_side_goes_to_its_default_hand(self):
        self.assertEqual(held.held_of([("tongs", {})]), {"n": "", "f": "tongs"})
        self.assertEqual(held.held_of([("shield", {"color": (1, 2, 3)})])["n"][:7], "shield_")

    def test_two_pieces_on_one_hand_is_an_error(self):
        with self.assertRaises(ValueError):
            held.held_of([("axe", {"side": "n"}), ("club", {"side": "n"})])

    def test_gear_that_is_not_held_is_ignored(self):
        self.assertEqual(held.items_of([("jerkin", {"color": (1, 2, 3)}), ("pauldron", {"side": "n"})]), {})


class ScaleTest(unittest.TestCase):
    def test_form_scale_is_1_for_a_default_form_at_ITEM_PPU_and_follows_the_kits_radius_factor(self):
        self.assertEqual(held.form_scale({}, held.ITEM_PPU), 1.0)
        self.assertAlmostEqual(held.form_scale({}, 45.0), 1.5)
        paladin = held.form_scale({"bx": 1.12}, held.ITEM_PPU)
        self.assertAlmostEqual(paladin, (1.04 * 1.12 + 0.90 * 1.0) / (1.04 + 0.90), places=6)
        self.assertAlmostEqual(paladin, 1.0643, places=3)


class CameraTest(unittest.TestCase):
    def test_project_puts_the_ground_on_the_margin_row_and_the_centre_on_the_middle_column(self):
        self.assertEqual(held.project(96, 30.0, 3, 0.3, 0.3, 0.0), (48.0, 93.0))
        self.assertEqual(held.project(96, 30.0, 3, 0.3, 1.3, 1.0), (78.0, 63.0))

    def test_project_agrees_with_the_cameras_own_parameters(self):
        canvas, ppu, margin, cx = 104, 27.5, 4, -0.2
        cp = stage.camera_params(canvas, ppu, margin, 1, cx)
        per_px = cp["ortho_scale"] / canvas
        for x, z in ((0.0, 0.0), (0.7, 1.4), (-0.5, 0.3)):
            px = canvas / 2 + (x - cp["location"][0]) / per_px
            py = canvas / 2 - (z - cp["location"][2]) / per_px
            got = held.project(canvas, ppu, margin, cx, x, z)
            self.assertAlmostEqual(got[0], px)
            self.assertAlmostEqual(got[1], py)

    def test_bone_turn_is_clockwise_degrees(self):
        up = ((0.0, 0.0), (0.0, 1.0))
        self.assertAlmostEqual(held.bone_turn(*up, (0.0, 0.0), (1.0, 0.0)), 90.0)
        self.assertAlmostEqual(held.bone_turn(*up, (0.0, 0.0), (-1.0, 0.0)), -90.0)
        self.assertAlmostEqual(held.bone_turn(*up, (0.0, 0.0), (0.0, -1.0)), 180.0)
        self.assertAlmostEqual(held.bone_turn(*up, (2.0, 2.0), (2.0, 3.0)), 0.0)

    def test_bone_turn_is_measured_from_the_rest_direction_and_stays_in_range(self):
        right = ((0.0, 0.0), (1.0, 0.0))
        self.assertAlmostEqual(held.bone_turn(*right, (0.0, 0.0), (0.0, 1.0)), -90.0)
        self.assertAlmostEqual(held.bone_turn(*right, (0.0, 0.0), (0.0, -1.0)), 90.0)
        self.assertAlmostEqual(held.bone_turn(*right, (0.0, 0.0), (-1.0, 0.0)), 180.0)

    def test_local_of_matches_the_assemblers_shape_transform(self):
        box = (10, 5, 30, 35)   # a 20 x 30 cell
        self.assertEqual(held.local_of(20, 35, box), (0.0, 0.0))
        self.assertEqual(held.local_of(10, 5, box), (-10.0, -30.0))
        self.assertEqual(held.local_of(25, 20, box), (5.0, -15.0))


class DataTest(unittest.TestCase):
    def test_an_armed_goblin_render_is_refused_and_a_wolf_render_is_not(self):
        with self.assertRaises(ValueError) as caught:
            held.check_empty_handed({"creature": "goblin"})
        self.assertIn("hold", str(caught.exception))
        with self.assertRaises(ValueError):
            held.check_empty_handed({"creature": "goblin", "hold": True})
        held.check_empty_handed({"creature": "goblin", "hold": False})
        held.check_empty_handed({"creature": "wolf"})
        held.check_empty_handed({"creature": "undead", "variant": "skeleton"})

    def test_update_table_merges_and_keeps_other_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "data", "held_items.json")
            held.update_table(path, items={"b": {"set": "held_b"}})   # creates the file and its folder
            held.update_table(path, items={"a": {"set": "held_a"}}, forms={"goblin": {"scale": 1.0}})
            held.update_table(path, forms={"goblin_smith": {"scale": 1.1, "n": "hammer"}})
            with open(path) as fh:
                text = fh.read()
            data = json.loads(text)
            self.assertEqual(list(data["items"]), ["a", "b"])
            self.assertEqual(list(data["forms"]), ["goblin", "goblin_smith"])
            self.assertTrue(text.endswith("}\n"))


if __name__ == "__main__":
    unittest.main()
