"""Run the pipeline's Python tests (tools/art/blender, tools/art, tools) on several processes at once, and say plainly what passed.

    python3 tools/run_art_tests.py [-j N] [substring]

The slow ones start Blender (a render each) or Godot, one after the other in a single `unittest` run; here the tests are dealt out to N workers, longest first, by what each took last time
(.tmp/test-logs/art-times.json). A test class with a `setUpClass` stays whole in one worker, the rest are dealt out one by one. `substring` keeps only the tests whose id contains it.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import shard_tests  # noqa: E402

ROOTS = [os.path.join("tools", "art", "blender"), os.path.join("tools", "art"), "tools"]
TIMES = os.path.join(ROOT, ".tmp", "test-logs", "art-times.json")
WHOLE_CLASS_SECONDS = 20.0   # what a class with a setUpClass counts for when nothing is known of it: it is usually Blender or Godot starting


def flatten(suite):
    for t in suite:
        if isinstance(t, unittest.TestSuite):
            yield from flatten(t)
        else:
            yield t


def discover():
    """[(root, unit id, test ids)]: a unit is one test, or a whole class when it has a setUpClass, to be run in one process."""
    units = {}
    for root in ROOTS:
        top = os.path.join(ROOT, root)
        suite = unittest.TestLoader().discover(top, pattern="test_*.py", top_level_dir=top)
        for t in flatten(suite):
            cls = type(t)
            whole = cls.setUpClass.__func__ is not unittest.TestCase.setUpClass.__func__
            unit = ".".join([cls.__module__, cls.__qualname__]) if whole else t.id()
            if "_FailedTest" in t.id() or "ModuleImportFailure" in t.id():
                unit = t.id()
            units.setdefault((root, unit), []).append(t.id())
    return [(root, unit, ids) for (root, unit), ids in units.items()]


def read_times():
    try:
        with open(TIMES) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def plan(units, jobs, times):
    """Deal the units out to at most `jobs` workers: [(root, [ids], [unit ids])], longest first to the lightest worker."""
    weight = {}
    for root, unit, ids in units:
        known = times.get(unit)
        weight[unit] = known if known is not None else (WHOLE_CLASS_SECONDS if len(ids) > 1 or unit.count(".") < 2 + (unit.split(".")[-1].startswith("test_") and 1 or 0) else 0.05)
    order = sorted(units, key=lambda u: (-weight[u[1]], u[1]))
    workers = [[] for _ in range(max(1, jobs))]
    load = [0.0] * len(workers)
    for u in order:
        i = load.index(min(load))
        workers[i].append(u)
        load[i] += weight[u[1]]
    out = []
    for w, total in sorted(zip(workers, load), key=lambda p: -p[1]):
        by_root = {}
        for root, unit, ids in w:
            by_root.setdefault(root, []).append((unit, ids))
        for root, items in by_root.items():
            out.append((root, [i for _, ids in items for i in ids], [u for u, _ in items]))
    return out


def run_worker(root, ids):
    """(seconds, output, per-test seconds) of one `unittest` process over `ids`, started in `root` (where its tests import their neighbours from)."""
    start = time.time()
    done = subprocess.run([sys.executable, "-m", "unittest", "--durations", "0", *ids], cwd=os.path.join(ROOT, root), capture_output=True, text=True)
    took = {}
    for line in done.stderr.splitlines():
        m = re.match(r"^([0-9.]+)s\s+\S+ \((\S+)\)$", line.strip()) or re.match(r"^([0-9.]+)s\s+(\S+)$", line.strip())
        if m:
            took[m.group(2)] = float(m.group(1))
    return time.time() - start, done.stdout + done.stderr, took, done.returncode


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("-j", "--jobs", type=int, default=max(2, min(6, (os.cpu_count() or 4) - 2)))
    ap.add_argument("only", nargs="?", default="")
    a = ap.parse_args(argv)
    units = [u for u in discover() if a.only in u[1] or any(a.only in i for i in u[2])]
    if a.only:
        units = [(r, u, [i for i in ids if a.only in i or a.only in u]) for r, u, ids in units]
    if not units:
        print("FAIL: no tests match %r" % a.only)
        return 1
    jobs = plan(units, a.jobs, read_times())
    from concurrent.futures import ThreadPoolExecutor
    started = time.time()
    with ThreadPoolExecutor(max_workers=a.jobs) as pool:   # no more processes at once than asked for: the jobs are started in the order of what they are expected to take
        results = list(pool.map(lambda j: run_worker(j[0], j[1]), jobs))
    times = read_times()
    ran, bad = 0, []
    for (root, ids, unit_ids), (secs, out, took, code) in zip(jobs, results):
        ran += len(ids)
        for u in unit_ids:
            members = [i for i in ids if i == u or i.startswith(u + ".")]
            if members:
                times[u] = round(sum(took.get(i, 0.0) for i in members) if len(members) == 1 else secs, 3)
        if code != 0 or "FAILED" in out.splitlines()[-1:][0:1] or "Traceback" in out:
            bad.append((root, ids, out))
    os.makedirs(os.path.dirname(TIMES), exist_ok=True)
    with open(TIMES, "w") as fh:
        json.dump(times, fh, indent=1, sort_keys=True)
    if bad:
        for root, ids, out in bad:
            print("---- %s (%d tests)\n%s" % (root, len(ids), out[-3000:]))
        print("FAIL: %d of %d tests are in a worker that failed" % (sum(len(b[1]) for b in bad), ran))
        return 1
    print("PASS: %d tests on %d workers in %.0f s" % (ran, len(jobs), time.time() - started))
    return 0


if __name__ == "__main__":
    sys.exit(main())
