#!/usr/bin/env bash
# Run the GUT suite headless and fail on anything that is not a clean, non-empty pass.
#
# Godot's exit code is not evidence. A GDScript runtime error aborts only the
# function it happens in, and GUT can print "Nothing was run" and still exit 0.
# So this reads the log and the JUnit XML, not just the exit code.
#
# Usage: tools/run_tests.sh [file-substring]   e.g. tools/run_tests.sh ledger
set -uo pipefail
cd "$(dirname "$0")/.."

mkdir -p .tmp/test-logs .tmp/gdhome
log=.tmp/test-logs/gut.log
xml=.tmp/test-logs/results.xml
rm -f "$xml"

args=(-s addons/gut/gut_cmdln.gd -gdir=res://tests -gprefix=test_ -gexit "-gjunit_xml_file=res://$xml")
if [ "$#" -gt 0 ]; then args+=("-gselect=$1"); fi

# --fixed-fps runs every physics frame as fast as the machine can instead of waiting 1/60 s of real time for each, so the
# suite takes about half a minute instead of ten (every test still sees 60 Hz time). FIXED_FPS=0 turns it off.
fps_args=()
if [ "${FIXED_FPS:-60}" != "0" ]; then fps_args=(--fixed-fps "${FIXED_FPS:-60}"); fi

gtimeout -k 5 "${TEST_TIMEOUT:-480}" env HOME="$PWD/.tmp/gdhome" godot --headless "${fps_args[@]}" "${args[@]}" >"$log" 2>&1
code=$?

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
