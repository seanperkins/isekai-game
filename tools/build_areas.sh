#!/usr/bin/env bash
# Build the new areas' rooms into data/rooms (tools/areas/). `tools/build_areas.sh --check` writes nothing and fails when a room would change.
# Godot's exit code is not evidence (a script error exits 0), so an engine error in the output fails the run too.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp/gdhome
out=$(gtimeout -k 5 120 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_areas.gd -- "$@" 2>&1)
code=$?
echo "$out" | grep -v "^Godot Engine"
if echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error'; then exit 1; fi
exit "$code"
