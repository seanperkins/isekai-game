#!/bin/bash
# Frames of the Menagerie without taking over the screen: tools/shot_run.sh runs tools/menagerie_shots.gd in its tiny off-screen window.
# Run from anywhere:  tools/menagerie_shots.sh [x ...]      Frames land in .tmp/menagerie-frames/stop_N.png, one per x (a whole number:
# the player's position along the room, up to 8); with no x, eight stops spread along the room. The room MCP's menagerie_shot tool
# runs this.
# GODOT=/path/to/godot overrides the binary. SHOTS_OUT=/dir puts the frames there instead (the project copy and the log go beside it
# as DIR.proj and DIR.log), so runs in different directories cannot touch each other.
cd "$(dirname "$0")/.." || exit 1
OUT="${SHOTS_OUT:-$PWD/.tmp/menagerie-frames}"
STOPS=8  # how many frames to expect: one per x, else the eight default stops
STOPS_ARG=()
if [ $# -gt 0 ]; then
	for x in "$@"; do
		case "$x" in ''|*[!0-9]*) echo "usage: $0 [x ...]  (whole numbers only, got '$x')" >&2; exit 2;; esac
	done
	[ $# -gt 8 ] && { echo "usage: $0 [x ...]  (at most 8)" >&2; exit 2; }
	STOPS=$#
	STOPS_ARG=("--stops=$(IFS=,; echo "$*")")
fi
rm -rf "$OUT"
SHOT_DIR="$OUT" tools/shot_run.sh tools/menagerie_shots.gd -- --room=menagerie --out="$OUT" "${STOPS_ARG[@]}" || exit $?
n=$(ls "$OUT" 2>/dev/null | wc -l | tr -d ' ')
echo "$n of $STOPS frames in $OUT"
width=""
command -v sips >/dev/null 2>&1 && width=$(sips -g pixelWidth "$OUT/stop_0.png" 2>/dev/null | awk '/pixelWidth/ {print $2}')
if [ -n "$width" ] && [ "$width" -ne 1280 ]; then
	echo "warning: the frames are ${width} px wide, not 1280, so the viewport is not what was asked for" >&2
	exit 1
fi
[ "$n" -eq "$STOPS" ]
