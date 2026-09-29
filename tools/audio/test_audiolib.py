import math
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402


def sine(freq, seconds, amp=0.5):
    n = int(seconds * a.RATE)
    return [amp * math.sin(2 * math.pi * freq * i / a.RATE) for i in range(n)]


class AudioLibTest(unittest.TestCase):
    def test_normalize_peak_hits_the_target(self):
        out = a.normalize_peak(sine(440, 0.1, 0.25), -2.0)
        self.assertAlmostEqual(a.lin_to_db(a.peak(out)), -2.0, places=3)

    def test_normalize_peak_refuses_silence(self):
        with self.assertRaises(a.AudioToolError):
            a.normalize_peak([0.0] * 100, -2.0)

    def test_an_ogg_round_trips_as_stereo_vorbis(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "t.ogg")
            a.write_ogg(sine(440, 0.5), out)
            info = a.validate_ogg(out)
            self.assertEqual(info["channels"], 2)
            self.assertAlmostEqual(info["duration"], 0.5, delta=0.05)
            left, right = a.decode_pcm(out)
            self.assertEqual(len(left), len(right))
            self.assertGreater(a.peak(left), 0.3)

    def test_a_failed_encode_leaves_nothing_behind(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "sub", "t.ogg")
            with self.assertRaises(a.AudioToolError):
                a.encode_ogg(os.path.join(d, "missing.wav"), out)
            self.assertFalse(os.path.exists(out))
            self.assertFalse(os.path.exists(out + ".tmp.ogg"))

    def test_garbage_is_not_a_valid_ogg(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "bad.ogg")
            with open(p, "wb") as f:
                f.write(b"not audio")
            with self.assertRaises(a.AudioToolError):
                a.validate_ogg(p)

    def test_loudness_of_a_dual_mono_sine_matches_its_level(self):
        # EBU R128: a 1 kHz sine at -20 dBFS on both channels reads -20 LUFS.
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "s.wav")
            a.write_wav(p, sine(1000, 3.0, 0.1))
            self.assertAlmostEqual(a.measure_lufs(p), -20.0, delta=1.0)

    def test_seam_ratio_is_small_for_a_continuous_wrap_and_large_for_a_jump(self):
        self.assertLess(a.seam_ratio(sine(200, 1.0)), 1.5)  # exactly 200 cycles
        self.assertGreater(a.seam_ratio(sine(200, 1.00125)), 5.0)  # ends a quarter cycle in


if __name__ == "__main__":
    unittest.main()
