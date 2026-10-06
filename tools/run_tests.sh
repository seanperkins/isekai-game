#!/usr/bin/env bash
# Run the GUT suite headless and fail on anything that is not a clean, non-empty pass.
#
# Godot's exit code is not evidence. A GDScript runtime error aborts only the
# function it happens in, and GUT can print "Nothing was run" and still exit 0.
# So this reads the log and the JUnit XML, not just the exit code.
#
# Usage: tools/run_tests.sh [file-substring]   e.g. tools/run_tests.sh ledger      (JOBS=n sets how many processes a full run uses)
set -uo pipefail
cd "$(dirname "$0")/.."

# A fresh profile for every run: the game saves what the player did (deaths, the bestiary, the map, remains) under HOME, and a profile that
# remembers earlier runs changes what some tests see (the skill screen's tree tab failed on one that had 85 deaths in it).
rm -rf .tmp/gdhome
mkdir -p .tmp/test-logs .tmp/gdhome
log=.tmp/test-logs/gut.log
xml=.tmp/test-logs/results.xml
rm -f "$xml"

pre=(-gpre_run_script=res://tests/support/gut_isolation.gd)   # every test script starts from the game's own input state: the order files run in must not matter
args=(-s addons/gut/gut_cmdln.gd -gdir=res://tests -gprefix=test_ -gexit "${pre[@]}" "-gjunit_xml_file=res://$xml")
if [ "$#" -gt 0 ]; then args+=("-gselect=$1"); fi

# --fixed-fps runs every physics frame as fast as the machine can instead of waiting 1/60 s of real time for each, so the
# suite takes about half a minute instead of ten (every test still sees 60 Hz time). FIXED_FPS=0 turns it off.
fps_args=()
if [ "${FIXED_FPS:-60}" != "0" ]; then fps_args=(--fixed-fps "${FIXED_FPS:-60}"); fi

# A full run is dealt out to several Godot processes at once (each with a profile of its own, the files balanced by what they took last time: tools/shard_tests.py), so it takes about
# the time of its slowest test file instead of the sum of them all. JOBS=1 runs it in one process; a run of one file or of a few (a substring) is one process anyway.
jobs="${JOBS:-}"
if [ -z "$jobs" ]; then
  cpus=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 2)
  jobs=$(( cpus > 4 ? cpus - 2 : 2 ))
fi

code=0
if [ "$#" -eq 0 ] && [ "$jobs" -gt 1 ]; then
  rm -rf .tmp/gdhome-* ; rm -f .tmp/test-logs/gut-*.log .tmp/test-logs/results-*.xml
  plans=()
  while IFS= read -r line; do plans+=("$line"); done < <(python3 tools/shard_tests.py plan "$jobs")
  pids=()
  i=0
  for files in "${plans[@]}"; do
    mkdir -p ".tmp/gdhome-$i"
    gtimeout -k 5 "${TEST_TIMEOUT:-480}" env HOME="$PWD/.tmp/gdhome-$i" godot --headless "${fps_args[@]}" -s addons/gut/gut_cmdln.gd -gtest="$files" -gexit "${pre[@]}" \
      "-gjunit_xml_file=res://.tmp/test-logs/results-$i.xml" >".tmp/test-logs/gut-$i.log" 2>&1 &
    pids+=($!)
    i=$((i + 1))
    sleep 0.3
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || code=1
  done
  cat .tmp/test-logs/gut-*.log >"$log"
  # one results file for what reads it: the processes' counts added up (a process that wrote none is a failure of its own)
  tests=0; failures=0
  for ((k = 0; k < i; k++)); do
    part=".tmp/test-logs/results-$k.xml"
    if [ ! -f "$part" ]; then
      echo "FAIL: process $k wrote no results (see .tmp/test-logs/gut-$k.log)"
      tail -20 ".tmp/test-logs/gut-$k.log"
      exit 1
    fi
    t=$(grep -oE 'tests="[0-9]+"' "$part" | head -1 | grep -oE '[0-9]+'); f=$(grep -oE 'failures="[0-9]+"' "$part" | head -1 | grep -oE '[0-9]+')
    tests=$((tests + ${t:-0})); failures=$((failures + ${f:-0}))
  done
  python3 tools/shard_tests.py record .tmp/test-logs/results-*.xml
  echo '<?xml version="1.0"?><testsuites tests="'"$tests"'" failures="'"$failures"'"></testsuites>' >"$xml"
else
  gtimeout -k 5 "${TEST_TIMEOUT:-480}" env HOME="$PWD/.tmp/gdhome" godot --headless "${fps_args[@]}" "${args[@]}" >"$log" 2>&1
  code=$?
fi

if grep -qE 'SCRIPT ERROR|Parse Error|Nothing was run' "$log"; then
  echo "FAIL: engine error or empty run (see $log)"
  grep -nE 'SCRIPT ERROR|Parse Error|Nothing was run' "$log" | head -20
  exit 1
fi
if [ ! -f "$xml" ]; then
  echo "FAIL: no results file (godot exit $code, see $log)"
  tail -20 "$log"
  exit 1
fi
tests=$(grep -oE 'tests="[0-9]+"' "$xml" | head -1 | grep -oE '[0-9]+')
failures=$(grep -oE 'failures="[0-9]+"' "$xml" | head -1 | grep -oE '[0-9]+')
if [ "${tests:-0}" -eq 0 ]; then
  echo "FAIL: 0 tests ran (see $log)"
  exit 1
fi
if [ "${failures:-1}" -ne 0 ] || [ "$code" -ne 0 ]; then
  echo "FAIL: ${failures:-?} of $tests failed (godot exit $code, see $log)"
  grep -nE 'FAILED|\[Failed\]' "$log" | head -40
  exit 1
fi
echo "PASS: $tests tests"
