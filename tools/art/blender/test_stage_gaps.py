"""The real creatures on the photo stage: what each species cannot be posed in yet is a named list (stage_review.KNOWN_MISSING), not a surprise, and the walk
does not skate on any of them. Records every run with Godot and builds each species in Blender, so it is skipped without either."""
import json
import os
import re
import shutil
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stage_review as sr  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
GODOT = os.environ.get("GODOT", "godot")
STAGE = os.path.join(ROOT, ".tmp", "stage")
MAX_SLIDE_PX = 1.5   # a planted foot dragged over the ground, the most in one step


class TableTests(unittest.TestCase):
    def test_the_runs_per_species_are_the_recorders(self):
        with open(os.path.join(ROOT, "tools", "movement_recorder.gd")) as fh:
            src = fh.read()
        table = re.search(r"const SCRIPTS_FOR := \{(.*?)\n\}", src, re.S).group(1)
        theirs = {m.group(1): json.loads(m.group(2)) for m in re.finditer(r'"(\w+)": (\[[^\]]*\])', table)}
        self.assertEqual(sr.RUNS, theirs)
        self.assertEqual(sorted(sr.SPECIES), sorted(theirs))


@unittest.skipUnless(os.path.exists(BLENDER) and shutil.which(GODOT), "needs Blender and Godot")
class RealCreatureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        env = dict(os.environ, HOME=os.path.join(ROOT, ".tmp", "gdhome"))
        os.makedirs(env["HOME"], exist_ok=True)
        done = subprocess.run([GODOT, "--headless", "-s", "tools/record_movement.gd", "--", "all"], cwd=ROOT, env=env, capture_output=True, text=True)
        assert done.returncode == 0, done.stdout + done.stderr
        cls.reports = {}
        for species in sr.SPECIES:
            recordings = [os.path.join(STAGE, "%s_%s.json" % (species, script)) for script in sr.RUNS[species]]
            out = subprocess.run([BLENDER, "-b", "-P", os.path.join(os.path.dirname(os.path.abspath(__file__)), "stage_review.py"), "--", "--creature", species, "--gaps", "--recording", *recordings],
                                 capture_output=True, text=True)
            lines = [line for line in out.stdout.splitlines() if line.startswith("GAPS ")]
            assert lines, "%s: %s" % (species, (out.stdout + out.stderr)[-1500:])
            cls.reports[species] = json.loads(lines[-1][5:])

    def test_a_species_cannot_be_posed_only_in_the_states_listed_as_missing(self):
        for species, scripts in self.reports.items():
            for script, report in scripts.items():
                self.assertEqual(report["missing"], sr.KNOWN_MISSING.get(species, {}).get(script, []), "%s %s: the states with no pose changed" % (species, script))

    def test_no_species_skates(self):
        for species, scripts in self.reports.items():
            for script, report in scripts.items():
                self.assertLess(report["slide_px"], MAX_SLIDE_PX, "%s %s: a planted foot is dragged over the ground" % (species, script))


if __name__ == "__main__":
    unittest.main()
