import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import gen_bed  # noqa: E402

MUSIC = {"provider": "synth", "dur": 8.0, "notes": [130.81, 196.0], "lfo": 0.1}
AMBIENCE = {"provider": "synth", "dur": 8.0, "lp": 900, "lfo": 0.05}


class GenBedTest(unittest.TestCase):
    def _lufs(self, stereo):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "b.wav")
            a.write_wav(p, stereo)
            return a.measure_lufs(p)

    def test_a_music_bed_lands_on_its_loudness_target(self):
        out = gen_bed.process(gen_bed.raw_samples(MUSIC, "t", "music"), "music")
        self.assertAlmostEqual(self._lufs(out), a.TARGET_LUFS["music"], delta=1.0)

    def test_an_ambience_bed_lands_on_its_loudness_target(self):
        out = gen_bed.process(gen_bed.raw_samples(AMBIENCE, "t", "ambience"), "ambience")
        self.assertAlmostEqual(self._lufs(out), a.TARGET_LUFS["ambience"], delta=1.0)

    def test_a_bed_loops_without_a_click_and_stays_under_the_ceiling(self):
        left, right = gen_bed.process(gen_bed.raw_samples(MUSIC, "t", "music"), "music")
        self.assertLess(a.seam_ratio(left), 3.0)
        self.assertLess(a.seam_ratio(right), 3.0)
        self.assertLessEqual(a.lin_to_db(a.peak(left)), a.PEAK_CEILING_DB - 0.5)

    def test_the_synth_provider_is_reproducible(self):
        one = gen_bed.raw_samples(MUSIC, "t", "music")
        self.assertEqual(one, gen_bed.raw_samples(MUSIC, "t", "music"))

    def test_an_unknown_provider_fails(self):
        with self.assertRaises(a.AudioToolError):
            gen_bed.raw_samples({"provider": "nope"}, "t", "music")

    def test_the_local_provider_names_the_file_it_needs(self):
        with self.assertRaises(a.AudioToolError) as ctx:
            gen_bed.raw_samples({"provider": "local", "file": "art_source/audio/raw/missing.wav"}, "t", "music")
        self.assertIn("art_source/audio/raw/missing.wav", str(ctx.exception))

    def test_build_writes_a_valid_ogg_and_a_failure_leaves_none(self):
        with tempfile.TemporaryDirectory() as d:
            gen_bed.build("t", "music", MUSIC, d)
            info = a.validate_ogg(os.path.join(d, "music", "t.ogg"))
            self.assertGreater(info["duration"], 5.5)
            with self.assertRaises(a.AudioToolError):
                gen_bed.build("u", "music", {"provider": "nope"}, d)
            self.assertFalse(os.path.exists(os.path.join(d, "music", "u.ogg")))


if __name__ == "__main__":
    unittest.main()
