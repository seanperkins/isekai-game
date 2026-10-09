"""Laying a clip out with the items a goblin holds (app/hands.js), a pure module: run through Node when it is installed."""
import json
import math
import os
import shutil
import subprocess
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
NODE = shutil.which("node")


def run(expr, *args):
    """Evaluate `expr` (a JS expression over the module's exports and the JSON arguments a0, a1, ...) in Node and return its JSON."""
    names = ", ".join("a%d" % i for i in range(len(args)))
    script = ('import * as hands from "%s/app/hands.js"; const [%s] = process.argv.slice(1).map((s) => JSON.parse(s)); console.log(JSON.stringify(%s));' % (HERE, names, expr))
    done = subprocess.run([NODE, "--input-type=module", "-e", script, *[json.dumps(a) for a in args]], capture_output=True, text=True, timeout=30)
    assert done.returncode == 0, done.stderr
    return json.loads(done.stdout)


def frame(w, h, hand=None):
    return {"w": w, "h": h, "hands": {"n": hand} if hand else {}}


def item(w, h, grip, scale=1.0):
    return {"w": w, "h": h, "grip": grip, "scale": scale}


def placed(layout, f, bounds):
    """The frame's rectangle and the item's bounds on the canvas of `layout`: (x0, y0, x1, y1) each."""
    x = math.floor(layout["ax"] - f["w"] / 2)
    body = (x, layout["ay"] - f["h"], x + f["w"], layout["ay"])
    return body, (layout["ax"] + bounds["x0"], layout["ay"] + bounds["y0"], layout["ax"] + bounds["x1"], layout["ay"] + bounds["y1"])


def inside(rect, layout):
    return rect[0] >= -1e-9 and rect[1] >= -1e-9 and rect[2] <= layout["w"] + 1e-9 and rect[3] <= layout["h"] + 1e-9


@unittest.skipUnless(NODE, "needs Node")
class LayoutTest(unittest.TestCase):
    def layout(self, frames, held):
        return run("hands.clipLayout(a0, a1)", frames, held)

    def bounds(self, f, held):
        return run("hands.itemBounds(a0, a1, a1.scale)", f["hands"]["n"], held["n"])

    def test_with_no_items_the_layout_is_todays_bottom_centre_box(self):
        got = self.layout([frame(20, 30), frame(21, 25)], {})
        self.assertEqual(got, {"w": 21, "h": 30, "ax": 10.5, "ay": 30})
        self.assertEqual(self.layout([frame(20, 30, {"x": 0, "y": -15, "a": 0})], {}), {"w": 20, "h": 30, "ax": 10, "ay": 30}, "frames with hands but no item chosen")

    def test_an_item_that_sticks_out_in_every_direction_is_inside_the_canvas_with_body_and_hand_aligned(self):
        cases = {
            "above": ({"x": 0, "y": -15, "a": 0}, item(4, 60, [0, -3])),
            "right": ({"x": 5, "y": -15, "a": 0}, item(40, 4, [-18, -2])),
            "left": ({"x": -5, "y": -15, "a": 0}, item(40, 4, [18, -2])),
            "below": ({"x": 0, "y": -5, "a": 0}, item(4, 30, [0, -28])),
        }
        for name, (hand, it) in cases.items():
            f = frame(20, 30, hand)
            layout = self.layout([f], {"n": it})
            bounds = self.bounds(f, {"n": it})
            body, thing = placed(layout, f, bounds)
            self.assertTrue(inside(body, layout), (name, "body", body, layout))
            self.assertTrue(inside(thing, layout), (name, "item", thing, layout))
            self.assertEqual((layout["w"], layout["h"]) == (20, 30), False, name + ": the canvas grew")
            self.assertTrue(isinstance(layout["w"], int) or float(layout["w"]).is_integer())

    def test_the_hand_on_the_canvas_is_the_anchor_plus_the_hand_for_frames_of_different_sizes(self):
        a, b = frame(20, 30, {"x": 4, "y": -20, "a": 0}), frame(31, 24, {"x": 6, "y": -12, "a": 0})
        it = item(30, 6, [-10, -3])
        layout = self.layout([a, b], {"n": it})
        for f in (a, b):
            body, thing = placed(layout, f, self.bounds(f, {"n": it}))
            self.assertTrue(inside(body, layout) and inside(thing, layout), f)
        self.assertEqual(run("hands.handAt(a0, a1)", layout, a["hands"]["n"]), [layout["ax"] + 4, layout["ay"] - 20])

    def test_fractional_edges_round_outward_to_whole_pixels(self):
        f = frame(20, 30, {"x": 0, "y": -15, "a": 45})
        it = item(10, 10, [0, -5])
        layout = self.layout([f], {"n": it})
        bounds = self.bounds(f, {"n": it})
        self.assertAlmostEqual(bounds["x1"], 5 * math.sqrt(2), places=4)
        self.assertEqual((layout["w"], layout["h"]), (math.floor(layout["w"]), math.floor(layout["h"])))
        body, thing = placed(layout, f, bounds)
        self.assertTrue(inside(thing, layout), (thing, layout))

    def test_item_bounds_turn_about_the_grip_clockwise_and_scale(self):
        flat = run("hands.itemBounds(a0, a1, 1)", {"x": 0, "y": 0, "a": 0}, item(10, 4, [0, 0]))
        self.assertEqual(flat, {"x0": -5, "y0": -4, "x1": 5, "y1": 0})
        turned = run("hands.itemBounds(a0, a1, 1)", {"x": 0, "y": 0, "a": 90}, item(10, 4, [0, 0]))
        for key, want in (("x0", 0), ("y0", -5), ("x1", 4), ("y1", 5)):
            self.assertAlmostEqual(turned[key], want, places=6, msg=key)
        double = run("hands.itemBounds(a0, a1, 2)", {"x": 1, "y": 2, "a": 0}, item(10, 4, [0, 0]))
        self.assertEqual(double, {"x0": -9, "y0": -6, "x1": 11, "y1": 2})


@unittest.skipUnless(NODE, "needs Node")
class MergeTest(unittest.TestCase):
    def test_merged_layouts_share_one_origin_and_hold_every_layout(self):
        got = run("hands.mergeLayouts(a0)", [{"w": 20, "h": 30, "ax": 10, "ay": 30}, {"w": 40, "h": 45, "ax": 8, "ay": 38}])
        self.assertEqual(got, {"w": 42, "h": 45, "ax": 10, "ay": 38}, "the origin is the larger of each side's, and the canvas reaches the farthest edge on every side")
        for l in ({"w": 20, "h": 30, "ax": 10, "ay": 30}, {"w": 40, "h": 45, "ax": 8, "ay": 38}):
            self.assertTrue(got["ax"] - l["ax"] >= 0 and got["ay"] - l["ay"] >= 0)
            self.assertTrue(got["ax"] + (l["w"] - l["ax"]) <= got["w"] and got["ay"] + (l["h"] - l["ay"]) <= got["h"])

    def test_layouts_with_no_items_merge_to_the_largest_box_as_before(self):
        got = run("hands.mergeLayouts(a0)", [{"w": 21, "h": 30, "ax": 10.5, "ay": 30}, {"w": 52, "h": 25, "ax": 26, "ay": 25}])
        self.assertEqual(got, {"w": 52, "h": 30, "ax": 26, "ay": 30})


if __name__ == "__main__":
    unittest.main()
