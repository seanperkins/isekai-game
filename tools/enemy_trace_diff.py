"""Diff two enemy traces recorded by tools/enemy_trace.sh: python3 tools/enemy_trace_diff.py baseline fold
Exits non-zero at the first scenario and tick that differ (positions are already rounded to 0.01 px)."""
import json
import sys

a = json.load(open(".tmp/enemy-trace/%s.json" % sys.argv[1]))
b = json.load(open(".tmp/enemy-trace/%s.json" % sys.argv[2]))
bad = 0
for name in a:
    if name not in b:
        print("MISSING", name)
        bad += 1
        continue
    for key in ("hazards", "events", "hits", "poisons"):
        if a[name][key] != b[name][key]:
            print("DIFF", name, key, a[name][key][:3], "vs", b[name][key][:3])
            bad += 1
    for x, y in zip(a[name]["samples"], b[name]["samples"]):
        if x != y:
            print("DIFF", name, "tick", x["t"], x, "vs", y)
            bad += 1
            break
    if len(a[name]["samples"]) != len(b[name]["samples"]):
        print("DIFF", name, "sample count")
        bad += 1
print("scenarios:", len(a), "differences:", bad)
sys.exit(1 if bad else 0)
