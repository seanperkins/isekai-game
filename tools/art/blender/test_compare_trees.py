"""compare_trees.py: which forms of a goblin_tree.py output differ from another render of them. Pure Python."""
import json
import os
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare_trees as ct  # noqa: E402

META = {"hands": {"idle_0": {"n": [10.0, 20.0, 5.0], "f": [8.0, 21.0, -3.0]}}, "ppu": 40.0, "canvas": 96, "hold": False, "other": 1}


def make_form(root, name, pixel=(10, 20, 30, 255), frames=("idle_0", "idle_1"), meta=None):
    folder = os.path.join(root, name)
    os.makedirs(os.path.join(folder, "frames"))
    os.makedirs(os.path.join(folder, "raw"))
    for frame in frames:
        im = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
        im.putpixel((1, 1), pixel)
        im.save(os.path.join(folder, "frames", frame + ".png"))
    with open(os.path.join(folder, "raw", "meta.json"), "w") as fh:
        json.dump(META if meta is None else meta, fh)


class DifferentFormsTest(unittest.TestCase):
    def trees(self, **kw):
        base, new = tempfile.TemporaryDirectory(), tempfile.TemporaryDirectory()
        self.addCleanup(base.cleanup)
        self.addCleanup(new.cleanup)
        for root in (base.name, new.name):
            make_form(root, "smith")
            make_form(root, "hob")
        return base.name, new.name

    def test_identical_trees_differ_nowhere(self):
        base, new = self.trees()
        self.assertEqual(ct.different_forms(base, new), [])

    def test_one_changed_pixel_names_the_form(self):
        base, new = self.trees()
        import shutil
        shutil.rmtree(os.path.join(new, "hob"))
        make_form(new, "hob", pixel=(10, 20, 31, 255))
        self.assertEqual(ct.different_forms(base, new), ["hob"])

    def test_a_missing_frame_or_form_names_it(self):
        base, new = self.trees()
        os.remove(os.path.join(new, "smith", "frames", "idle_1.png"))
        import shutil
        shutil.rmtree(os.path.join(new, "hob"))
        self.assertEqual(ct.different_forms(base, new), ["hob", "smith"])

    def test_changed_hands_ppu_canvas_or_hold_in_the_meta_names_the_form(self):
        for key, value in (("hands", {"idle_0": {"n": [11.0, 20.0, 5.0], "f": [8.0, 21.0, -3.0]}}), ("ppu", 41.0), ("canvas", 104), ("hold", True)):
            with self.subTest(key=key):
                base, new = self.trees()
                with open(os.path.join(new, "smith", "raw", "meta.json"), "w") as fh:
                    json.dump(dict(META, **{key: value}), fh)
                self.assertEqual(ct.different_forms(base, new), ["smith"])

    def test_a_meta_key_that_is_not_compared_does_not_matter(self):
        base, new = self.trees()
        with open(os.path.join(new, "smith", "raw", "meta.json"), "w") as fh:
            json.dump(dict(META, other=2), fh)
        self.assertEqual(ct.different_forms(base, new), [])

    def test_extra_forms_in_the_new_tree_are_ignored(self):
        base, new = self.trees()
        make_form(new, "puck")
        self.assertEqual(ct.different_forms(base, new), [])


if __name__ == "__main__":
    unittest.main()
