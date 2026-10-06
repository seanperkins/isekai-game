import json
import os
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import handdraw as h  # noqa: E402

MAGENTA = (255, 0, 255, 255)
BLUE = (40, 120, 255, 255)


def blob(w, h, box, bg=(0, 0, 0, 0), color=BLUE):
    """A canvas of `bg` with a solid rectangle `box` = (x0, y0, x1, y1)."""
    im = Image.new("RGBA", (w, h), bg)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            im.putpixel((x, y), color)
    return im


def make_root(tmp, name="wolf", frames=(("idle", 40), ("run", 48)), extra=None):
    """A tiny project: a spec, a hi-res source frame for each name, and no built sheet."""
    os.makedirs(os.path.join(tmp, "tools", "art"))
    os.makedirs(os.path.join(tmp, "art_source", "frames", name))
    spec = {"canonical": "x.png", "style": "S", "frames": [{"name": n, "width": w, "refs": [], "prompt": "The %s pose." % n} for n, w in frames]}
    spec.update(extra or {})
    with open(os.path.join(tmp, "tools", "art", name + "_frames.json"), "w") as fh:
        json.dump(spec, fh, indent=1)
    for n, _ in frames:
        blob(300, 200, (40, 30, 260, 170), bg=MAGENTA).save(os.path.join(tmp, "art_source", "frames", name, n + ".png"))
    return tmp


def read(path, mode="r"):
    with open(path, mode) as fh:
        return fh.read()


def size_of(path):
    with Image.open(path) as im:
        return im.size


def codes(findings):
    return {f.code for f in findings}


class CheckTest(unittest.TestCase):
    def test_a_clean_drawing_passes(self):
        self.assertEqual(h.check_frame(blob(400, 300, (50, 40, 350, 260)), 40), [])

    def test_a_magenta_background_counts_as_transparent(self):
        self.assertEqual(h.check_frame(blob(400, 300, (50, 40, 350, 260), bg=MAGENTA), 40), [])

    def test_a_solid_background_is_an_error(self):
        im = blob(400, 300, (50, 40, 350, 260), bg=(240, 240, 240, 255))
        found = h.check_frame(im, 40)
        self.assertIn("solid_background", codes(found))
        self.assertTrue(all(f.level == "error" for f in found if f.code == "solid_background"))

    def test_pixels_the_magenta_key_would_erase_are_flagged_in_a_transparent_drawing(self):
        im = blob(400, 300, (50, 40, 350, 260))
        for x in range(100, 110):
            for y in range(100, 110):
                im.putpixel((x, y), (230, 40, 200, 255))  # hot pink: the key rule treats it as background
        found = h.check_frame(im, 40)
        self.assertIn("key_colour", codes(found))
        self.assertTrue(all(f.level == "warn" for f in found if f.code == "key_colour"))
        self.assertIn("100", [f.message for f in found if f.code == "key_colour"][0])

    def test_a_pale_pink_survives_the_key(self):
        im = blob(400, 300, (50, 40, 350, 260))
        for x in range(100, 110):
            for y in range(100, 110):
                im.putpixel((x, y), (240, 190, 210, 255))
        self.assertNotIn("key_colour", codes(h.check_frame(im, 40)))

    def test_an_empty_frame_is_an_error(self):
        self.assertEqual(codes(h.check_frame(Image.new("RGBA", (50, 50), MAGENTA), 40)), {"empty"})

    def test_a_subject_cut_off_by_the_canvas_edge_is_an_error(self):
        found = h.check_frame(blob(400, 300, (0, 40, 350, 260)), 40)
        self.assertIn("touches_edge", codes(found))

    def test_strokes_thinner_than_a_game_pixel_are_flagged_when_painting_big(self):
        im = Image.new("RGBA", (1000, 600), (0, 0, 0, 0))
        for x in range(100, 900):  # a 1 px line 800 wide shrunk to 40: it vanishes
            im.putpixel((x, 300), BLUE)
        for y in range(100, 500):
            im.putpixel((100, y), BLUE)
        self.assertIn("thin_detail", codes(h.check_frame(im, 40)))

    def test_thin_strokes_are_fine_at_native_size(self):
        im = Image.new("RGBA", (60, 40), (0, 0, 0, 0))
        for x in range(10, 50):
            im.putpixel((x, 20), BLUE)
        self.assertNotIn("thin_detail", codes(h.check_frame(im, 40, native=True)))

    def test_a_stray_speck_away_from_the_subject_is_flagged(self):
        im = blob(60, 40, (5, 14, 55, 38))
        im.putpixel((30, 3), BLUE)
        im.putpixel((31, 3), BLUE)
        found = h.check_frame(im, 50)  # the drawing is 50 wide, so it is not resized
        self.assertIn("stray_specks", codes(found))
        self.assertTrue(all(f.level == "warn" for f in found if f.code == "stray_specks"))

    def test_two_real_parts_are_not_specks(self):
        im = blob(400, 300, (50, 100, 200, 260))
        for x in range(260, 350):
            for y in range(100, 260):
                im.putpixel((x, y), BLUE)
        self.assertNotIn("stray_specks", codes(h.check_frame(im, 40)))


class TemplateTest(unittest.TestCase):
    def test_the_template_is_the_canvas_size_with_a_fainter_reference_and_a_floor(self):
        ref = blob(300, 200, (0, 0, 300, 200), color=(10, 20, 200, 255))
        t = h.template(ref, canvas=600)
        self.assertEqual(t.size, (600, 600))
        mid = t.getpixel((250, 400))
        self.assertNotEqual(mid[:3], (10, 20, 200), "the reference is faded, so a drawing on top reads")
        self.assertNotEqual(mid[:3], h.PAPER[:3])
        floor = int(600 * h.FLOOR)
        self.assertEqual(t.getpixel((20, floor))[:3], h.GUIDE[:3], "the floor line is drawn")

    def test_a_template_without_a_reference_is_still_made(self):
        self.assertEqual(h.template(None, canvas=300).size, (300, 300))


class WorkflowTest(unittest.TestCase):
    def setUp(self):
        self._t = tempfile.TemporaryDirectory()
        self.root = make_root(self._t.name)
        self.addCleanup(self._t.cleanup)
        self.out = os.path.join(self.root, "out")
        self.ran = []

    def fake_run(self, set_name):
        self.ran.append(set_name)

    def drawn(self, names, box=(10, 10, 130, 90), size=(160, 100)):
        os.makedirs(self.out, exist_ok=True)
        for n in names:
            blob(size[0], size[1], box).save(os.path.join(self.out, n + ".png"))

    def test_pack_writes_a_template_per_frame_and_a_brief_naming_each(self):
        written = h.pack(self.root, "wolf", self.out, canvas=300)
        for n in ("idle", "run"):
            self.assertTrue(os.path.exists(os.path.join(self.out, n + ".png")))
            self.assertEqual(size_of(os.path.join(self.out, n + ".png")), (300, 300))
        brief = read(os.path.join(self.out, "BRIEF.md"))
        for needle in ("idle", "run", "40", "48", "The idle pose.", "faces right"):
            self.assertIn(needle, brief)
        self.assertEqual(len(written), 3)

    def test_pack_can_be_limited_to_some_frames(self):
        h.pack(self.root, "wolf", self.out, canvas=300, only=["run"])
        self.assertFalse(os.path.exists(os.path.join(self.out, "idle.png")))
        self.assertTrue(os.path.exists(os.path.join(self.out, "run.png")))

    def test_a_native_template_is_the_size_of_the_frame_not_the_canvas(self):
        h.pack(self.root, "wolf", self.out, native=True)
        w, ht = size_of(os.path.join(self.out, "idle.png"))
        self.assertLess(w, 100)
        self.assertLess(ht, 100)

    def test_import_installs_the_frames_backs_up_the_old_ones_and_runs_the_assembler(self):
        self.drawn(["idle", "run"])
        old = read(os.path.join(self.root, "art_source", "frames", "wolf", "idle.png"), "rb")
        h.import_frames(self.root, "wolf", self.out, run=self.fake_run, stamp="T1")
        installed = os.path.join(self.root, "art_source", "frames", "wolf", "idle.png")
        self.assertEqual(size_of(installed), (160, 100))
        backup = os.path.join(self.root, "art_source", ".replaced", "wolf", "T1", "idle.png")
        self.assertEqual(read(backup, "rb"), old)
        self.assertEqual(self.ran, ["wolf"])

    def test_import_records_the_frames_as_hand_drawn(self):
        self.drawn(["run"])
        h.import_frames(self.root, "wolf", self.out, run=self.fake_run, stamp="T1", today="2026-10-05")
        prov = json.loads(read(os.path.join(self.root, "tools", "art", "provenance.json")))
        self.assertEqual(prov["wolf"]["run"]["source"], "hand")
        self.assertEqual(prov["wolf"]["run"]["date"], "2026-10-05")
        self.assertNotIn("idle", prov["wolf"])

    def test_import_can_record_another_source_than_hand(self):
        self.drawn(["idle"])
        h.import_frames(self.root, "wolf", self.out, run=self.fake_run, stamp="T1", today="2026-10-06", source="blender")
        prov = json.loads(read(os.path.join(self.root, "tools", "art", "provenance.json")))
        self.assertEqual(prov["wolf"]["idle"]["source"], "blender")
        rows = {r["set"]: r for r in h.inventory(self.root)}
        self.assertEqual((rows["wolf"]["hand"], rows["wolf"]["blender"]), (0, 1))

    def test_import_refuses_a_name_the_set_does_not_have_and_installs_nothing(self):
        self.drawn(["idle", "gallop"])
        with self.assertRaises(ValueError) as ctx:
            h.import_frames(self.root, "wolf", self.out, run=self.fake_run)
        self.assertIn("gallop", str(ctx.exception))
        self.assertEqual(self.ran, [])
        self.assertFalse(os.path.exists(os.path.join(self.root, "art_source", ".replaced")))

    def test_import_refuses_a_drawing_with_an_error_and_installs_nothing(self):
        os.makedirs(self.out)
        blob(160, 100, (10, 10, 130, 90), bg=(255, 255, 255, 255)).save(os.path.join(self.out, "idle.png"))
        with self.assertRaises(ValueError) as ctx:
            h.import_frames(self.root, "wolf", self.out, run=self.fake_run)
        self.assertIn("solid_background", str(ctx.exception))
        self.assertEqual(self.ran, [])

    def test_import_refuses_an_empty_folder(self):
        os.makedirs(self.out)
        with self.assertRaises(ValueError):
            h.import_frames(self.root, "wolf", self.out, run=self.fake_run)

    def test_native_import_marks_only_those_frames_native_in_the_spec(self):
        self.drawn(["run"], box=(2, 2, 40, 30), size=(48, 36))
        h.import_frames(self.root, "wolf", self.out, native=True, run=self.fake_run, stamp="T1")
        spec = json.loads(read(os.path.join(self.root, "tools", "art", "wolf_frames.json")))
        by = {f["name"]: f for f in spec["frames"]}
        self.assertTrue(by["run"]["native"])
        self.assertNotIn("native", by["idle"])
        prov = json.loads(read(os.path.join(self.root, "tools", "art", "provenance.json")))
        self.assertEqual(prov["wolf"]["run"]["route"], "native")

    def test_a_derived_set_points_at_its_base(self):
        t = tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        root = make_root(t.name, name="pale", extra={"derive_from": "wolf"})
        os.makedirs(os.path.join(root, "out"))
        blob(160, 100, (10, 10, 130, 90)).save(os.path.join(root, "out", "idle.png"))
        with self.assertRaises(ValueError) as ctx:
            h.import_frames(root, "pale", os.path.join(root, "out"), run=self.fake_run)
        self.assertIn("wolf", str(ctx.exception))

    def test_check_set_writes_a_preview_and_returns_findings_per_frame(self):
        self.drawn(["idle"])
        result = h.check_folder(self.root, "wolf", self.out)
        self.assertEqual(result["idle"], [])
        self.assertTrue(os.path.exists(os.path.join(self.out, "preview.png")))

    def test_inventory_counts_hand_drawn_frames(self):
        self.drawn(["run"])
        h.import_frames(self.root, "wolf", self.out, run=self.fake_run, stamp="T1")
        rows = {r["set"]: r for r in h.inventory(self.root)}
        self.assertEqual((rows["wolf"]["frames"], rows["wolf"]["hand"]), (2, 1))

    def test_marking_native_edits_the_spec_text_and_nothing_else(self):
        text = '{"frames": [\n  {"name": "idle", "width": 40},\n  {\n   "name": "run",\n   "width": 48\n  }\n]}'
        marked = h.mark_native(text, ["run"], True)
        self.assertEqual(marked.replace(', "native": true', ""), text)
        self.assertTrue(json.loads(marked)["frames"][1]["native"])
        self.assertNotIn("native", json.loads(marked)["frames"][0])
        self.assertEqual(h.mark_native(marked, ["run"], True), marked, "marking twice changes nothing")
        self.assertEqual(h.mark_native(marked, ["run"], False), text, "and unmarking restores the text")


if __name__ == "__main__":
    unittest.main()
