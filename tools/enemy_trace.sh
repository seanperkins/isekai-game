#!/bin/bash
# Records the per-tick trace of every enemy scenario: TRACE_LABEL=<label> tools/enemy_trace.sh
# (add TRACE_EMIT=1 to also rewrite tests/support/enemy_trace_expected.json). Then:
#   python3 tools/enemy_trace_diff.py baseline <label>
cd "$(dirname "$0")/.." || exit 1
: "${TRACE_LABEL:?set TRACE_LABEL}"
mkdir -p .tmp/enemy-trace
gtimeout -k 5 400 env HOME="$PWD/.tmp/gdhome" TRACE_LABEL="$TRACE_LABEL" TRACE_EMIT="${TRACE_EMIT:-0}" \
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/support/enemy_trace_dump.gd -gexit \
  > ".tmp/enemy-trace/$TRACE_LABEL.log" 2>&1
grep -E "SCRIPT ERROR|Parse Error" ".tmp/enemy-trace/$TRACE_LABEL.log" && exit 1
ls -la ".tmp/enemy-trace/$TRACE_LABEL.json"
