#!/bin/bash
# Frames of the Menagerie without taking over the screen. Godot cannot render headless (its headless display driver is the dummy
# renderer), so the window is opened far off-screen, and the app you were in gets the focus back as soon as Godot takes it.
# Run from anywhere:  tools/menagerie_shots.sh      Frames land in .tmp/menagerie-frames/stop_N.png.
# GODOT=/path/to/godot overrides the binary.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
OUT=.tmp/menagerie-frames
STOPS=8  # tools/menagerie_shots.gd takes one frame at each of its STOPS
mkdir -p .tmp/gdhome
rm -rf "$OUT"

front() { osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null; }
mine=$(front)
[ -z "$mine" ] && echo "note: cannot read the frontmost app (Accessibility permission?), so focus will not be handed back" >&2

env HOME="$PWD/.tmp/gdhome" "$GODOT" --path . --position 30000,30000 --resolution 1280x720 \
	-s res://tools/menagerie_shots.gd -- --room=menagerie > .tmp/shots.log 2>&1 &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
	if [ -n "$mine" ]; then
		now=$(front)
		if [ -n "$now" ] && [ "$now" != "$mine" ]; then
			osascript -e "tell application \"$mine\" to activate" >/dev/null 2>&1
		fi
	fi
	sleep 0.15
done
wait "$pid"
n=$(ls "$OUT" 2>/dev/null | wc -l | tr -d ' ')
echo "$n of $STOPS frames in $OUT"
[ "$n" -eq "$STOPS" ]
