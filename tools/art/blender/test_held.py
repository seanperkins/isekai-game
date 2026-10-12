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


# every goblin form's held pieces by the physical side they were built on before roles (captured from goblin_forms.FORMS before the migration)
OLD_SIDES = {
    "beastcaller": {'offering': 'n'},
    "pied_piper": {'pipe': 'n'},
    "orpheus": {'lyre': 'n'},
    "beast_rider": {'spear': 'n'},
    "wolf_lord": {'spear': 'n'},
    "lord_of_beasts": {'hawk': 'n'},
    "tinker": {'trap': 'n'},
    "knocker": {'pick': 'n', 'lantern': 'f'},
    "gremlin": {'wrench': 'n'},
    "rumpelstiltskin": {'spindle': 'n', 'straw': 'f'},
    "smith": {'hammer': 'n', 'tongs': 'f'},
    "mastersmith": {'hammer': 'n', 'sword_big': 'f'},
    "ring_maker": {'ring': 'n'},
    "skulker": {'dagger': 'n'},
    "redcap": {'axe': 'n'},
    "bloodcap": {'spiked_cap_held': 'n'},
    "puck": {'lantern': 'n'},
    "changeling": {'doll': 'n'},
    "leprechaun": {'hammer_small': 'n', 'coin': 'f'},
    "hob": {'bowl': 'n'},
    "tomte": {'stone': 'n', 'lantern': 'f'},
    "hearth_god": {'horn': 'f', 'stone': 'n'},
    "boggart": {'stone': 'n'},
    "paladin": {'shield': 'n'},
    "horn_bearer": {'horn': 'n'},
    "giant_killer": {'sling': 'f', 'sword_big': 'n'},
}

CYAN = (120, 190, 204)


class HeldPiecesTest(unittest.TestCase):
    def test_every_HELD_piece_is_exactly_a_gear_function_bound_to_an_item_bone_with_that_default_side(self):
        self.assertEqual(held.HELD, item_bone_functions())

    def test_ROLE_OF_covers_exactly_HELD_with_the_defaults_of_the_off_hand_pieces(self):
        self.assertEqual(set(held.ROLE_OF), set(held.HELD))
        self.assertEqual({p for p, r in held.ROLE_OF.items() if r == "secondary"}, {"tongs", "lantern", "coin", "straw", "shield"})
        self.assertEqual({p for p, r in held.ROLE_OF.items() if r == "primary"}, set(held.HELD) - {"tongs", "lantern", "coin", "straw", "shield"})
        self.assertEqual(held.TWO_HANDED, {"spear", "staff"})

    def test_role_of_honours_hand_and_physical_side_maps_roles_by_handed(self):
        self.assertEqual(held.role_of("axe", {}), "primary")
        self.assertEqual(held.role_of("axe", {"hand": "secondary"}), "secondary")
        self.assertEqual(held.role_of("lantern", {"side": "n"}), "secondary", "side is not a role")
        self.assertEqual((held.physical_side("primary", "n"), held.physical_side("secondary", "n")), ("n", "f"))
        self.assertEqual((held.physical_side("primary", "f"), held.physical_side("secondary", "f")), ("f", "n"))

    def test_item_ids_ignore_side_and_hand_and_the_pucks_lantern_keeps_its_id(self):
        self.assertEqual(held.item_id("hammer", {}), "hammer")
        self.assertEqual(held.item_id("hammer", {"side": "n", "hand": "primary"}), "hammer")
        big = held.item_id("hammer", {"hand": "primary", "big": 1.15})
        self.assertNotEqual(big, "hammer")
        self.assertTrue(big.startswith("hammer_") and len(big) == len("hammer_") + 6)
        self.assertEqual(big, held.item_id("hammer", {"big": 1.15, "side": "f"}))
        self.assertEqual(held.item_id("axe", {"hand": "primary"}), held.item_id("axe", {"hand": "secondary"}))
        self.assertEqual(held.held_of(forms.FORMS["puck"]["gear"])["primary"], "lantern_3b1f26")

    def test_all_items_covers_every_held_piece_at_default_options_and_every_forms_items_and_gives_big_hammers_and_cyan_lanterns_their_own_ids(self):
        items = held.all_items()
        for piece in held.HELD:
            self.assertEqual(items[piece], (piece, {}), piece)   # a piece no form holds (club, staff) can still be swapped in
        for form in forms.FORMS.values():
            for item, (piece, kw) in held.items_of(form["gear"]).items():
                self.assertEqual(items[item], (piece, kw))
        mastersmith = held.held_of(forms.FORMS["mastersmith"]["gear"])["primary"]
        self.assertNotEqual(mastersmith, "hammer")
        self.assertEqual(items[mastersmith][1], {"big": 1.15})
        cyan = held.held_of(forms.FORMS["puck"]["gear"])["primary"]
        self.assertNotEqual(cyan, "lantern")
        self.assertIn("color", items[cyan][1])

    def test_held_of_reads_the_roles_a_form_holds(self):
        self.assertEqual(held.held_of(forms.FORMS["smith"]["gear"]), {"primary": "hammer", "secondary": "tongs"})
        self.assertEqual(held.held_of(forms.FORMS["goblin"]["gear"]), {"primary": "", "secondary": ""})
        leprechaun = held.held_of(forms.FORMS["leprechaun"]["gear"])
        self.assertEqual((leprechaun["primary"], leprechaun["secondary"]), ("hammer_small", "coin"))
        self.assertEqual(held.held_of([("tongs", {})]), {"primary": "", "secondary": "tongs"}, "a piece with no hand goes to its default role")
        self.assertEqual(held.primary_piece(forms.FORMS["smith"]["gear"]), "hammer")
        self.assertIsNone(held.primary_piece(forms.FORMS["goblin"]["gear"]))

    def test_held_of_refuses_two_pieces_in_a_role_a_two_handed_secondary_and_a_two_handed_primary_beside_a_secondary(self):
        with self.assertRaises(ValueError):
            held.held_of([("axe", {}), ("club", {})])
        with self.assertRaises(ValueError):
            held.held_of([("spear", {"hand": "secondary"})])
        with self.assertRaises(ValueError):
            held.held_of([("spear", {}), ("lantern", {})])
        self.assertEqual(held.held_of([("spear", {})]), {"primary": "spear", "secondary": ""})

    def test_validate_form_names_the_form_and_checks_handed(self):
        with self.assertRaises(ValueError) as caught:
            held.validate_form("zz_twice", {"gear": [("axe", {}), ("club", {})]})
        self.assertIn("zz_twice", str(caught.exception))
        with self.assertRaises(ValueError) as caught:
            held.validate_form("zz_hand", {"gear": [], "handed": "x"})
        self.assertIn("zz_hand", str(caught.exception))
        held.validate_form("zz_ok", {"gear": [("axe", {})], "handed": "f"})
        for name, form in forms.FORMS.items():
            held.validate_form(name, form)

    def test_every_forms_roles_equal_what_its_sides_were_except_the_paladins(self):
        for name, form in forms.FORMS.items():
            if name == "paladin":   # re-authored: see the next test
                continue
            sides = OLD_SIDES.get(name, {})
            handed = form.get("handed", "n")
            roles = held.held_of(form["gear"])
            mine = {piece: held.physical_side(held.role_of(piece, kw), handed) for piece, kw in ((g[0], g[1]) for g in form["gear"]) if piece in held.HELD}
            self.assertEqual(mine, sides, name)
            self.assertEqual({r: i for r, i in roles.items() if i}, {("primary" if sides[p] == "n" else "secondary"): held.item_id(p, kw) for p, kw in ((g[0], g[1]) for g in form["gear"]) if p in held.HELD}, name)

    def test_the_paladin_holds_a_mace_in_the_primary_hand_and_the_shield_in_the_secondary_with_the_far_arm_primary(self):
        paladin = forms.FORMS["paladin"]
        self.assertEqual(paladin["handed"], "f")
        self.assertEqual(held.held_of(paladin["gear"]), {"primary": "club", "secondary": "shield"})
        self.assertNotIn("attack", paladin, "he plays the verb's own gesture, the throw")
        self.assertEqual(paladin["arms"], "shield_ready")
        sides = {piece: held.physical_side(held.role_of(piece, kw), paladin["handed"]) for piece, kw in paladin["gear"] if piece in held.HELD}
        self.assertEqual(sides, {"club": "f", "shield": "n"}, "the mace on the far arm behind his body, the shield on the near arm in front")

    def test_armor_keeps_its_physical_side(self):
        sides = [kw.get("side", "n") for name, kw in forms.FORMS["ironboot"]["gear"] if name == "pauldron"]
        self.assertEqual(sorted(sides), ["f", "n"], "the pauldrons are on both arms, as they were")

    def test_form_entry_has_handed_scale_and_roles(self):
        self.assertEqual(held.form_entry("smith", 45.0), {"scale": round(held.form_scale(forms.FORMS["smith"], 45.0), 4), "handed": "n", "primary": "hammer", "secondary": "tongs"})
        self.assertEqual(held.form_entry("goblin", 30.0), {"scale": 1.0, "handed": "n"})

    def test_two_pieces_of_gear_that_are_not_held_are_ignored(self):
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
