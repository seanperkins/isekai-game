import math
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import dsp  # noqa: E402


def rms(x):
    return math.sqrt(sum(s * s for s in x) / len(x))


class DspTest(unittest.TestCase):
    def test_render_is_deterministic_for_a_seed(self):
        r = {"layers": [{"noise": "pink", "amp": 1.0, "env": [0.001, 0.05]}]}
        self.assertEqual(dsp.render(r, 0.1, 7), dsp.render(r, 0.1, 7))
        self.assertNotEqual(dsp.render(r, 0.1, 7), dsp.render(r, 0.1, 8))

    def test_envelope_rises_over_the_attack_then_decays(self):
        env = dsp.envelope(4410, 0.01, 0.05)
        self.assertEqual(env[0], 0.0)
        self.assertAlmostEqual(env[441], 1.0, places=6)
        self.assertLess(env[-1], env[441])

    def test_a_sine_oscillator_has_the_right_period(self):
        s = dsp.osc("sine", 200, 441.0, 441.0)  # 100 samples per period
        self.assertAlmostEqual(s[24], 1.0, places=3)
        self.assertAlmostEqual(s[99], 0.0, places=3)

    def test_lowpass_removes_high_frequency_energy(self):
        noise = dsp.noise("white", 20000, random.Random(1))
        self.assertLess(rms(dsp.lowpass(noise, 200.0)), 0.2 * rms(noise))

    def test_make_loop_wraps_without_a_jump_and_shortens_the_clip(self):
        x = [0.5 * math.sin(2 * math.pi * 220 * i / a.RATE) for i in range(a.RATE)]
        out = dsp.make_loop(x, 0.2)
        self.assertEqual(len(out), len(x) - int(0.2 * a.RATE))
        self.assertLess(a.seam_ratio(out), 2.0)

    def test_make_loop_rejects_a_clip_that_is_too_short(self):
        with self.assertRaises(ValueError):
            dsp.make_loop([0.0] * 1000, 0.2)

    def test_trim_silence_cuts_the_quiet_ends(self):
        quiet = [0.0] * 1000
        loud = [0.5] * 500
        left, right = dsp.trim_silence((quiet + loud + quiet, quiet + loud + quiet))
        self.assertEqual(len(left), 500)
        self.assertEqual(len(right), 500)

    def test_trim_silence_refuses_pure_silence(self):
        with self.assertRaises(a.AudioToolError):
            dsp.trim_silence(([0.0] * 100, [0.0] * 100))


if __name__ == "__main__":
    unittest.main()
