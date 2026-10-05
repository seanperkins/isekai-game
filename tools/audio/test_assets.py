import glob
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import synth_sfx  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")


def oggs(kind):
    return sorted(glob.glob(os.path.join(AUDIO, kind, "*.ogg")))


class BuiltAssetsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, "data", "audio", "cues.json")) as f:
            cls.catalog = json.load(f)
        cls.pcm = {p: a.decode_pcm(p) for kind in ("sfx", "music", "ambience") for p in oggs(kind)}

    def test_every_file_is_stereo_vorbis(self):
        expected = 2 * len(("cave", "grotto", "flooded", "deep")) + len(self.catalog.get("themes", {})) + sum(
            int(r.get("variants", 1)) for r in synth_sfx.load_recipes().values())
        self.assertEqual(len(self.pcm), expected)  # every SFX variant, the eight beds and each theme's music
        for path in self.pcm:
            info = a.validate_ogg(path)
            self.assertEqual(info["channels"], 2, path)

    def test_nothing_peaks_above_the_ceiling(self):
        for path, (left, right) in self.pcm.items():
            top = a.lin_to_db(max(a.peak(left), a.peak(right)))
            self.assertLessEqual(top, a.PEAK_CEILING_DB, path)

    def test_sfx_are_not_silent(self):
        for path in oggs("sfx"):
            left, right = self.pcm[path]
            self.assertGreater(a.lin_to_db(a.peak(left)), -6.0, path)

    def test_music_and_ambience_hit_their_loudness_targets(self):
        for kind in ("music", "ambience"):
            for path in oggs(kind):
                self.assertAlmostEqual(a.measure_lufs(path), a.TARGET_LUFS[kind], delta=a.LUFS_TOLERANCE, msg=path)

    def test_loops_wrap_without_a_click(self):
        loops = [os.path.join(AUDIO, f) for rule in self.catalog["cues"].values() if rule.get("loop")
                 for f in rule["files"]]
        self.assertGreaterEqual(len(loops), 3)
        for path in oggs("music") + oggs("ambience") + loops:
            left, right = self.pcm[path]
            self.assertLess(a.seam_ratio(left), 3.0, path)
            self.assertLess(a.seam_ratio(right), 3.0, path)

    def test_every_recipe_has_its_files_and_no_sfx_is_orphaned(self):
        wanted = set()
        for name, recipe in synth_sfx.load_recipes().items():
            wanted.update(os.path.join(AUDIO, rel) for rel in synth_sfx.variant_files(name, recipe))
        self.assertEqual(wanted, set(oggs("sfx")))


if __name__ == "__main__":
    unittest.main()
