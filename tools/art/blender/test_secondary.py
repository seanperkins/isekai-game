"""Follow-through for things hung on a body (secondary.py): pure Python."""
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import secondary  # noqa: E402

N = 12


def frames(amp=10.0, bob=0.0):
    """A body whose spine swings by `amp` degrees and whose root bobs by `bob` over a loop of N frames."""
    out = []
    for i in range(N):
        s = math.sin(2 * math.pi * i / N)
        out.append(({"spine": (0.0, -amp * s, 0.0), "hips": (0.0, 0.0, 0.0)}, (0.0, 0.0, bob * s)))
    return out


TABLE = {
    "cloak1": dict(parents=["hips", "spine"], bob=0.0, wind=-10.0, k=0.15, c=0.35),
    "cloak2": dict(after="cloak1", bob=0.0, wind=-10.0, k=0.14, c=0.30),
    "ear": dict(parents=["hips", "spine"], bob=400.0, wind=0.0, k=0.22, c=0.40),
}


class SecondaryTest(unittest.TestCase):
    def test_bones_the_rig_lacks_are_skipped(self):
        out = secondary.series({"cloak1"}, TABLE, frames(), 1.0)
        self.assertEqual(set(out), {"cloak1"})

    def test_a_still_body_leaves_a_rigid_thing_hanging_unless_the_wind_blows(self):
        still = [({"spine": (0.0, 0.0, 0.0)}, (0.0, 0.0, 0.0))] * N
        calm = secondary.series({"cloak1"}, TABLE, still, 0.0)["cloak1"]
        self.assertTrue(all(abs(v) < 1e-6 for v in calm))
        blown = secondary.series({"cloak1"}, TABLE, still, 1.0)["cloak1"]
        self.assertTrue(all(abs(v - (-10.0)) < 0.5 for v in blown), "it settles at the wind's angle")

    def test_the_lower_segment_lags_the_upper_which_lags_the_body(self):
        out = secondary.series({"cloak1", "cloak2"}, TABLE, frames(), 0.0)
        peak = lambda series: series.index(max(series))
        body = [10.0 * math.sin(2 * math.pi * i / N) for i in range(N)]
        a1 = [b + r for b, r in zip(body, out["cloak1"])]
        self.assertGreater((peak(a1) - peak(body)) % N, 0)
        a2 = [x + r for x, r in zip(a1, out["cloak2"])]
        self.assertGreaterEqual((peak(a2) - peak(a1)) % N, 1)

    def test_the_body_bouncing_shakes_a_thing_even_when_the_spine_is_still(self):
        bouncing = [({"spine": (0.0, 0.0, 0.0)}, (0.0, 0.0, 0.03 * math.sin(2 * math.pi * i / N))) for i in range(N)]
        out = secondary.series({"ear"}, TABLE, bouncing, 0.0)["ear"]
        self.assertGreater(max(out) - min(out), 3.0)

    def test_the_loop_is_seamless(self):
        out = secondary.series({"cloak1", "cloak2"}, TABLE, frames(), 1.0)
        for series in out.values():
            self.assertLess(abs(series[0] - series[-1]), abs(max(series) - min(series)) * 0.7 + 1e-6)

    def test_a_mounted_rider_follows_the_mounts_bones_too(self):
        rider = [({"w_spine": (0.0, -8.0 * math.sin(2 * math.pi * i / N), 0.0), "hips": (0.0, 0.0, 0.0), "spine": (0.0, 0.0, 0.0)}, (0.0, 0.0, 0.0)) for i in range(N)]
        with_mount = secondary.series({"cloak1"}, TABLE, rider, 0.0, extra_chain=("w_spine",))["cloak1"]
        without = secondary.series({"cloak1"}, TABLE, rider, 0.0)["cloak1"]
        self.assertGreater(max(with_mount) - min(with_mount), max(without) - min(without))


if __name__ == "__main__":
    unittest.main()
