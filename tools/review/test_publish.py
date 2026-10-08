"""Publishing a creature's sprites to the review page, from the game's real sheets and a render folder."""
import json
import os
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import publish  # noqa: E402

SHOWN = {"idle", "walk", "run", "attack", "hurt", "die"}


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    return struct.unpack(">II", head[16:24])


class ListingTest(unittest.TestCase):
    def test_sheet_listing_for_goblin_hob_matches_the_games_clips(self):
        listing = publish.sheet_listing("goblin_hob")
        self.assertEqual(set(listing["clips"]), SHOWN)   # the engine's windup, recover and downed states are not clips to look at
        ticks = json.load(open(publish.ROOT / "data" / "form_clips.json"))["goblin_hob"]["walk"]
        walk = listing["clips"]["walk"]
        self.assertAlmostEqual(sum(walk["durations"]), len(ticks["frames"]) / ticks["fps"], places=6)
        self.assertEqual(len(walk["frames"]), len(walk["durations"]))
        self.assertTrue(walk["loop"])
        self.assertLess(len(walk["frames"]), len(ticks["frames"]), "runs of the same frame are merged")
        sheet_w, sheet_h = png_size(publish.ROOT / "assets" / "sheets" / "anim_goblin_hob.png")
        for clip in listing["clips"].values():
            for frame in clip["frames"]:
                x, y, w, h = frame["rect"]
                self.assertTrue(x >= 0 and y >= 0 and w > 0 and h > 0 and x + w <= sheet_w and y + h <= sheet_h, frame)
        self.assertEqual((listing["image"], listing["normal"], listing["scale"]), ("sheet.png", "sheet_n.png", 1.12))

    def test_sheet_listing_for_a_base_creature_reads_its_own_sheet_and_scale_is_one_with_no_twin(self):
        listing = publish.sheet_listing("goblin")
        self.assertEqual(listing["scale"], 1.0)
        self.assertIn("idle", listing["clips"])
        self.assertIn("run", listing["clips"])
        self.assertEqual(publish.sheet_media("goblin")["sheet.png"], publish.ROOT / "assets" / "sheets" / "goblin.png")

    def test_frames_listing_from_a_render_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            (folder / "frames").mkdir()
            (folder / "raw").mkdir()
            for name in ("idle_0", "walk_0", "walk_1", "walk_2"):
                (folder / "frames" / (name + ".png")).write_bytes(b"\x89PNG")
            (folder / "raw" / "meta.json").write_text(json.dumps(
                {"anims": {"idle": 1, "walk": 3}, "durations": {"idle": [1.2], "walk": [0.1, 0.1, 0.2]}, "loops": {"idle": True, "walk": True}}))
            listing = publish.frames_listing(folder, scale=1.25)
            self.assertEqual(listing["scale"], 1.25)
            self.assertEqual([f["src"] for f in listing["clips"]["walk"]["frames"]], ["frames/walk_0.png", "frames/walk_1.png", "frames/walk_2.png"])
            self.assertEqual(listing["clips"]["walk"]["durations"], [0.1, 0.1, 0.2])
            self.assertEqual(sorted(publish.frames_media(folder)), ["frames/idle_0.png", "frames/walk_0.png", "frames/walk_1.png", "frames/walk_2.png"])

    def test_frames_listing_refuses_a_folder_whose_meta_and_frames_disagree(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            (folder / "frames").mkdir()
            (folder / "raw").mkdir()
            (folder / "frames" / "walk_0.png").write_bytes(b"\x89PNG")
            (folder / "raw" / "meta.json").write_text(json.dumps({"anims": {"walk": 2}, "durations": {"walk": [0.1, 0.1]}, "loops": {"walk": True}}))
            with self.assertRaises(ValueError):
                publish.frames_listing(folder)


class WriteTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.content = Path(self._tmp.name)

    def page(self, creature):
        return json.loads((self.content / "creatures" / creature / "page.json").read_text())

    def test_write_creature_copies_media_and_keeps_other_blocks(self):
        listing, media = publish.sheet_listing("goblin_hob"), publish.sheet_media("goblin_hob")
        publish.write_creature(self.content, "goblin_hob", listing, media, title="Hob", species="goblin", stage=2, parent="goblin")
        folder = self.content / "creatures" / "goblin_hob"
        self.assertEqual((folder / "sheet.png").read_bytes(), media["sheet.png"].read_bytes())
        self.assertEqual(json.loads((folder / "sprites.json").read_text())["scale"], 1.12)
        publish.set_block(self.content, "goblin_hob", {"type": "note", "markdown": "kept"})
        publish.write_creature(self.content, "goblin_hob", listing, media)
        page = self.page("goblin_hob")
        self.assertEqual([b["type"] for b in page["blocks"]], ["sprites", "note"])
        self.assertEqual((page["title"], page["species"], page["stage"], page["parent"]), ("Hob", "goblin", 2, "goblin"))
        self.assertRegex(page["updated"], r"^\d{4}-\d\d-\d\dT")

    def test_write_creature_refuses_a_bad_id_or_media_name(self):
        listing = {"image": None, "normal": None, "scale": 1.0, "clips": {}}
        source = Path(self._tmp.name, "src.png")
        source.write_bytes(b"x")
        for bad in ("../x", "Hob", "a b", ""):
            with self.subTest(creature=bad), self.assertRaises(ValueError):
                publish.write_creature(self.content, bad, listing, {})
        for bad in ("../evil.png", "/abs.png", "a/../../evil.png"):
            with self.subTest(media=bad), self.assertRaises(ValueError):
                publish.write_creature(self.content, "ok", listing, {bad: source})
        self.assertFalse((self.content / "evil.png").exists())

    def test_set_block_replaces_by_key_and_appends_otherwise(self):
        publish.set_block(self.content, "x", {"type": "note", "markdown": "one"}, key="walk-review")
        publish.set_block(self.content, "x", {"type": "note", "markdown": "two"}, key="walk-review")
        publish.set_block(self.content, "x", {"type": "note", "markdown": "three"})
        publish.set_block(self.content, "x", {"type": "note", "markdown": "four"})
        self.assertEqual([b["markdown"] for b in self.page("x")["blocks"]], ["two", "three", "four"])
        self.assertEqual(self.page("x")["blocks"][0]["key"], "walk-review")

    def test_write_is_atomic_page_json_is_never_half_written(self):
        publish.set_block(self.content, "x", {"type": "note", "markdown": "before"})
        with mock.patch.object(publish.os, "replace", side_effect=OSError("disk gone")):
            with self.assertRaises(OSError):
                publish.set_block(self.content, "x", {"type": "note", "markdown": "after"})
        self.assertEqual([b["markdown"] for b in self.page("x")["blocks"]], ["before"])

    def test_the_frames_command_draws_at_the_twins_sprite_size_unless_told_otherwise(self):
        import contextlib
        import io
        folder = Path(self._tmp.name, "render")
        (folder / "frames").mkdir(parents=True)
        (folder / "raw").mkdir()
        (folder / "frames" / "idle_0.png").write_bytes(b"\x89PNG")
        (folder / "raw" / "meta.json").write_text(json.dumps({"anims": {"idle": 1}, "durations": {"idle": [1.0]}, "loops": {"idle": True}}))
        with contextlib.redirect_stdout(io.StringIO()):
            publish.main(["frames", "goblin_hob", str(folder), "--content", str(self.content)])
            publish.main(["frames", "goblin_paladin", str(folder), "--scale", "2", "--content", str(self.content)])
        scale = lambda c: json.loads((self.content / "creatures" / c / "sprites.json").read_text())["scale"]
        self.assertEqual((scale("goblin_hob"), scale("goblin_paladin")), (1.12, 2.0))

    def test_add_figure_copies_the_file_and_sets_a_figure_block_by_key(self):
        source = Path(self._tmp.name, "stick.gif")
        source.write_bytes(b"GIF89a")
        publish.add_figure(self.content, "goblin", source, "A person and the goblin", key="stick")
        publish.add_figure(self.content, "goblin", source, "Again", key="stick")
        self.assertEqual((self.content / "creatures" / "goblin" / "stick.gif").read_bytes(), b"GIF89a")
        self.assertEqual([(b["type"], b["src"], b["caption"]) for b in self.page("goblin")["blocks"]], [("figure", "stick.gif", "Again")])
        with self.assertRaises(ValueError):
            publish.add_figure(self.content, "goblin", source, "x", name="../evil.gif")
        with self.assertRaises(ValueError):
            publish.add_figure(self.content, "../x", source, "x")

    def test_the_cli_publishes_the_real_goblin_hob(self):
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()):
            publish.main(["sheet", "goblin_hob", "--content", str(self.content)])
            publish.main(["sheet", "goblin", "--content", str(self.content)])
        page = self.page("goblin_hob")
        self.assertEqual((page["species"], page["stage"], page["parent"], page["title"]), ("goblin", 2, "goblin", "Hob"))
        self.assertTrue((self.content / "creatures" / "goblin_hob" / "sheet_n.png").exists())
        self.assertEqual((self.page("goblin")["species"], self.page("goblin")["stage"]), ("goblin", 1))


if __name__ == "__main__":
    unittest.main()
