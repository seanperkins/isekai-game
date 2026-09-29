import json
import os
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assemble_pieces as a  # noqa: E402

MAGENTA = (255, 0, 255, 255)
GREEN = (40, 200, 90, 255)


def piece(w, h, box):
    im = Image.new("RGBA", (w, h), MAGENTA)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            im.putpixel((x, y), GREEN)
    return im


class AssemblePiecesTest(unittest.TestCase):
    def test_a_piece_is_keyed_cropped_and_scaled_to_its_width_keeping_the_aspect(self):
        out = a.build_piece(piece(100, 100, (40, 10, 60, 90)), 10)  # the subject is 20x80
        self.assertEqual(out.size, (10, 40))
        self.assertEqual(out.getpixel((0, 0))[3], 255)

    def test_the_manifest_records_the_final_size_and_the_anchor(self):
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(d, "src")
            out = os.path.join(d, "out")
            os.makedirs(src)
            piece(100, 100, (40, 10, 60, 90)).save(os.path.join(src, "pole.png"))
            frames = [{"name": "pole", "width": 10, "anchor": "top"}]
            manifest = a.assemble(frames, src, out)
            self.assertEqual(manifest["pieces"]["pole"], {"size": [10, 40], "anchor": "top"})
            self.assertTrue(os.path.exists(os.path.join(out, "pole.png")))
            self.assertEqual(json.load(open(os.path.join(out, "pieces.json"))), manifest)

    def test_an_unknown_anchor_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "src"))
            piece(20, 20, (5, 5, 15, 15)).save(os.path.join(d, "src", "x.png"))
            with self.assertRaises(ValueError):
                a.assemble([{"name": "x", "width": 4, "anchor": "sideways"}], os.path.join(d, "src"), os.path.join(d, "out"))

    def test_a_missing_source_image_is_an_error(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "src"))
            with self.assertRaises(SystemExit):
                a.assemble([{"name": "gone", "width": 4, "anchor": "top"}], os.path.join(d, "src"), os.path.join(d, "out"))

    def test_names_are_validated(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError):
                a.assemble([{"name": "../x", "width": 4, "anchor": "top"}], d, d)


if __name__ == "__main__":
    unittest.main()
