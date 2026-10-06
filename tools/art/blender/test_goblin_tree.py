"""The goblin tree as data: it must describe exactly the forms the game has, and use only gear, poses and frames that exist.
Pure Python (the Blender-side modules are read as text, since bpy is not available here)."""
import ast
import glob
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import goblin_forms as forms  # noqa: E402
import goblin_tree as tree  # noqa: E402


def module_tree(*parts):
    with open(os.path.join(HERE, *parts)) as fh:
        return ast.parse(fh.read())


def dict_keys(module, name):
    for node in module.body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == name for t in node.targets):
            return {k.value for k in node.value.keys}
    raise AssertionError(name + " not found")


def function_names(module):
    return {n.name for n in module.body if isinstance(n, ast.FunctionDef) and not n.name.startswith("_")}


class FormsTableTest(unittest.TestCase):
    def test_it_describes_exactly_the_goblin_forms_the_game_has(self):
        in_game = {os.path.basename(p)[len("goblin_"):-len(".tres")] for p in glob.glob(os.path.join(ROOT, "data", "forms", "goblin_*.tres"))}
        self.assertEqual(set(forms.FORMS) - {"goblin"}, in_game)
        self.assertEqual(len(in_game), 28)

    def test_stages_follow_parents_and_every_line_is_one_root_two_branches_four_leaves(self):
        for name, f in forms.FORMS.items():
            if name == "goblin":
                continue
            self.assertIn(f["parent"], forms.FORMS, name)
            self.assertEqual(f["stage"], forms.FORMS[f["parent"]]["stage"] + 1, name)
        for line in tree.LINES:
            stages = sorted(f["stage"] for f in forms.FORMS.values() if f["line"] == line)
            self.assertEqual(stages, [2, 3, 3, 4, 4, 4, 4], line)

    def test_every_form_names_gear_poses_and_frames_that_exist(self):
        gear = function_names(module_tree("goblin_gear.py"))
        arms, stances = dict_keys(module_tree("creatures", "goblin.py"), "ARMS"), dict_keys(module_tree("creatures", "goblin.py"), "STANCES")
        for name, f in forms.FORMS.items():
            for g, _ in f["gear"]:
                self.assertIn(g, gear, "%s wears %s" % (name, g))
            self.assertIn(f.get("arms", "free"), arms, name)
            self.assertTrue(f.get("stance") is None or f["stance"] in stances, name)
            self.assertIn(f.get("still", "idle_0").split("_")[0], ("idle", "walk", "attack"), name)
            if f.get("ride"):
                self.assertIn("mount", f, name)

    def test_widths_are_the_widths_of_the_forms_frames(self):
        with open(os.path.join(ROOT, "tools", "art", "forms_goblin_frames.json")) as fh:
            spec = {f["name"]: f["width"] for f in json.load(fh)["frames"]}
        for name, f in forms.FORMS.items():
            if name != "goblin":
                self.assertEqual(f["width"], spec[name], name)

    def test_the_saved_sheet_from_before_has_every_form_for_sizing_and_comparison(self):
        with open(os.path.join(HERE, "before", "forms_goblin.json")) as fh:
            frames = json.load(fh)["frames"]
        self.assertEqual(set(frames), set(forms.FORMS) - {"goblin"})


class TreeLayoutTest(unittest.TestCase):
    def test_the_rows_hold_every_form_once_a_line_to_a_row_root_first(self):
        rows = tree.tree_order()
        self.assertEqual(rows[0], ["goblin"])
        flat = [n for r in rows for n in r]
        self.assertEqual(sorted(flat), sorted(forms.FORMS))
        for row in rows[1:]:
            self.assertEqual(len(row), 7)
            self.assertEqual(forms.FORMS[row[0]]["stage"], 2)

    def test_a_stage_three_form_is_followed_by_its_own_children(self):
        for row in tree.tree_order()[1:]:
            self.assertEqual(forms.FORMS[row[2]]["parent"], row[1])
            self.assertEqual(forms.FORMS[row[3]]["parent"], row[1])
            self.assertEqual(forms.FORMS[row[5]]["parent"], row[4])
            self.assertEqual(forms.FORMS[row[6]]["parent"], row[4])


if __name__ == "__main__":
    unittest.main()
