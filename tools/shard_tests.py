"""Plan how to run the GUT suite on several Godot processes at once, and remember what each test file took so the next plan is balanced.

    python3 tools/shard_tests.py plan N          one line per process: its test scripts, comma separated, as res:// paths (GUT's -gtest)
    python3 tools/shard_tests.py record XML...   add the time each file took in these JUnit results to .tmp/test-logs/times.json

tools/run_tests.sh uses both: the files are dealt out longest first to whichever process has the least to do, by the times of the last run (a file it has no time for
counts as the median, or by its size when nothing has run yet).
"""
import json
import os
import statistics
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
TIMES = os.path.join(ROOT, ".tmp", "test-logs", "times.json")
TESTS = os.path.join(ROOT, "tests")


def test_files(folder=TESTS):
    """Every test script of the suite, as `tests/<name>.gd` (GUT's prefix is `test_`); support code and helpers under tests/ are not tests."""
    return sorted("tests/" + n for n in os.listdir(folder) if n.startswith("test_") and n.endswith(".gd"))


def weights(files, times, sizes):
    """How long each file is expected to take: what it took last time, else the median of those that did, else its size."""
    known = [times[f] for f in files if f in times]
    guess = statistics.median(known) if known else None
    return {f: times[f] if f in times else (guess if guess is not None else max(0.05, sizes.get(f, 0) / 40000.0)) for f in files}


def plan(files, n, times=None, sizes=None):
    """Deal `files` out to at most `n` processes, longest first to the one with the least to do: a list of lists, none empty."""
    w = weights(files, times or {}, sizes or {})
    shards = [[] for _ in range(max(1, min(n, len(files))))]
    load = [0.0] * len(shards)
    for f in sorted(files, key=lambda f: (-w[f], f)):
        i = load.index(min(load))
        shards[i].append(f)
        load[i] += w[f]
    return [sorted(s) for s in shards if s]


def read_times(path=TIMES):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def record(xml_paths, path=TIMES):
    """Merge the time per test file of these JUnit results into the times file (a file not in them keeps its last time)."""
    times = read_times(path)
    for xml in xml_paths:
        for suite in ET.parse(xml).getroot().iter("testsuite"):
            name = suite.get("name") or ""
            took = sum(float(c.get("time") or 0.0) for c in suite.iter("testcase"))
            if name:
                times[name] = round(took, 3)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        json.dump(times, fh, indent=1, sort_keys=True)
    return times


def main(argv):
    if len(argv) >= 3 and argv[1] == "plan":
        files = test_files()
        sizes = {f: os.path.getsize(os.path.join(ROOT, f)) for f in files}
        for shard in plan(files, int(argv[2]), read_times(), sizes):
            print(",".join("res://" + f for f in shard))
        return 0
    if len(argv) >= 3 and argv[1] == "record":
        record(argv[2:])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
