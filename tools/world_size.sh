#!/usr/bin/env bash
# Print how big the shipped world is next to Super Metroid (rooms, screens, rooms per area). Informational: the numbers never fail anything.
# Only an engine error does, because then the numbers cannot be trusted. Godot's exit code is not evidence, so this reads the log.
#
# Usage: tools/world_size.sh
set -uo pipefail
cd "$(dirname "$0")/.."

mkdir -p .tmp/test-logs .tmp/gdhome
log=.tmp/test-logs/world_size.log

gtimeout -k 5 120 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/world_size.gd >"$log" 2>&1

if grep -qE 'SCRIPT ERROR|Parse Error' "$log"; then
  echo "world_size: engine error (see $log)"
  grep -nE 'SCRIPT ERROR|Parse Error' "$log" | head -10
  exit 1
fi
if ! grep -q 'WORLD SIZE' "$log"; then
  echo "world_size: no report was printed (see $log)"
  tail -10 "$log"
  exit 1
fi
grep -vE '^Godot Engine' "$log"
