"""How the suite is dealt out to processes (tools/shard_tests.py): every file runs exactly once, the work is balanced by what each took, and the times are remembered."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shard_tests as st  # noqa: E402


class PlanTests(unittest.TestCase):
    def test_every_file_runs_exactly_once(self):
        files = ["tests/test_%d.gd" % i for i in range(23)]
        shards = st.plan(files, 5)
        self.assertEqual(sorted(f for s in shards for f in s), sorted(files))
        self.assertEqual(len(shards), 5)

    def test_no_process_is_left_with_nothing_and_a_few_files_use_a_few_processes(self):
        self.assertEqual(len(st.plan(["tests/test_a.gd", "tests/test_b.gd"], 6)), 2)
        self.assertEqual(st.plan([], 4), [])

    def test_the_slow_files_are_spread_not_piled_on_one_process(self):
        files = ["tests/test_%d.gd" % i for i in range(8)]
        times = {"tests/test_0.gd": 30.0, "tests/test_1.gd": 28.0, "tests/test_2.gd": 20.0, "tests/test_3.gd": 18.0}
        times.update({"tests/test_%d.gd" % i: 1.0 for i in range(4, 8)})
        shards = st.plan(files, 4, times)
        load = [sum(times[f] for f in s) for s in shards]
        self.assertLessEqual(max(load), 31.0, "the longest one sets how long the run takes: %s" % load)
        for slow in ("tests/test_0.gd", "tests/test_1.gd", "tests/test_2.gd", "tests/test_3.gd"):
            self.assertEqual(sum(1 for s in shards if slow in s), 1)
        self.assertEqual(len({next(f for f in s if f in times and times[f] > 10) for s in shards}), 4, "each of the four slow ones leads its own process")

    def test_a_file_with_no_time_counts_as_the_median_of_the_rest(self):
        w = st.weights(["tests/test_a.gd", "tests/test_b.gd", "tests/test_new.gd"], {"tests/test_a.gd": 2.0, "tests/test_b.gd": 4.0}, {})
        self.assertEqual(w["tests/test_new.gd"], 3.0)

    def test_with_no_times_at_all_the_bigger_file_counts_as_the_slower(self):
        w = st.weights(["tests/test_a.gd", "tests/test_b.gd"], {}, {"tests/test_a.gd": 400000, "tests/test_b.gd": 4000})
        self.assertGreater(w["tests/test_a.gd"], w["tests/test_b.gd"])

    def test_a_plan_is_the_same_every_time(self):
        files = ["tests/test_%d.gd" % i for i in range(30)]
        self.assertEqual(st.plan(files, 4, {f: float(i % 7) for i, f in enumerate(files)}), st.plan(files, 4, {f: float(i % 7) for i, f in enumerate(files)}))


class RecordTests(unittest.TestCase):
    XML = """<?xml version="1.0"?><testsuites><testsuite name="tests/test_a.gd"><testcase name="x" time="1.5"/><testcase name="y" time="0.5"/></testsuite>
    <testsuite name="tests/test_b.gd"><testcase name="z" time="3.0"/></testsuite></testsuites>"""

    def test_the_time_of_a_file_is_the_sum_of_its_tests_and_older_files_are_kept(self):
        with tempfile.TemporaryDirectory() as d:
            xml, out = os.path.join(d, "r.xml"), os.path.join(d, "times.json")
            with open(xml, "w") as fh:
                fh.write(self.XML)
            with open(out, "w") as fh:
                json.dump({"tests/test_old.gd": 9.0, "tests/test_a.gd": 100.0}, fh)
            times = st.record([xml], out)
            self.assertEqual(times, {"tests/test_old.gd": 9.0, "tests/test_a.gd": 2.0, "tests/test_b.gd": 3.0})
            self.assertEqual(st.read_times(out), times)

    def test_a_missing_times_file_is_no_times(self):
        self.assertEqual(st.read_times("/nonexistent/times.json"), {})


class SuiteTests(unittest.TestCase):
    def test_the_test_files_are_the_games_and_not_the_support_code(self):
        files = st.test_files()
        self.assertGreater(len(files), 300)
        self.assertTrue(all(f.startswith("tests/test_") and f.endswith(".gd") for f in files))
        self.assertNotIn("tests/support/verb_arena.gd", files)


if __name__ == "__main__":
    unittest.main()
