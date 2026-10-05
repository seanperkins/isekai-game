#!/bin/bash
# Frames of the Menagerie without taking over the screen. Godot cannot render headless (its headless display driver is the dummy
# renderer), so this opens the smallest window it can get away with:
#  - the project starts fullscreen (display/window/size/mode=3), which takes over a Space and ignores --windowed and --position, so
#    the run uses a throwaway copy of the project (symlinks to everything, a rewritten project.godot) with a 32x18 borderless window
#    that cannot take focus; the real project.godot is never touched;
#  - the game is drawn into a 1280x720 SubViewport that tools/menagerie_shots.gd saves, so the frames are full size;
#  - the app you were in gets the focus back if Godot takes it anyway.
# Run from anywhere:  tools/menagerie_shots.sh [x ...]      Frames land in .tmp/menagerie-frames/stop_N.png, one per x (the player's
# position along the room, up to 8); with no x, eight stops spread along the room. The room MCP's menagerie_shot tool runs this.
# GODOT=/path/to/godot overrides the binary.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
OUT="$PWD/.tmp/menagerie-frames"
PROJ="$PWD/.tmp/shotproj"
STOPS=8  # how many frames to expect: one per x, else the eight default stops
STOPS_ARG=()
if [ $# -gt 0 ]; then
	for x in "$@"; do
		case "$x" in ''|*[!0-9.]*) echo "usage: $0 [x ...]  (numbers only, got '$x')" >&2; exit 2;; esac
	done
	[ $# -gt 8 ] && { echo "usage: $0 [x ...]  (at most 8)" >&2; exit 2; }
	STOPS=$#
	STOPS_ARG=("--stops=$(IFS=,; echo "$*")")
fi
mkdir -p .tmp/gdhome
rm -rf "$OUT" "$PROJ"
trap 'rm -rf "$PROJ"' EXIT
mkdir -p "$PROJ"
for f in * .godot; do
	case "$f" in project.godot|.tmp|.git|.worktrees|docs|art_source|node-compile-cache) continue;; esac
	[ -e "$f" ] && ln -s "$PWD/$f" "$PROJ/$f"
done
python3 - "$PWD/project.godot" "$PROJ/project.godot" <<'PY' || exit 1
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
text, n = re.subn(r"^window/size/mode=\d+$", "window/size/mode=0\nwindow/size/borderless=true\nwindow/size/no_focus=true", text, flags=re.M)
text = re.sub(r"^window/size/window_width_override=.*$", "window/size/window_width_override=32", text, flags=re.M)
text = re.sub(r"^window/size/window_height_override=.*$", "window/size/window_height_override=18", text, flags=re.M)
if n != 1:
    sys.exit("project.godot has no window/size/mode line to rewrite")
open(sys.argv[2], "w", encoding="utf-8").write(text)
PY

front() { osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null; }
mine=$(front)
[ -z "$mine" ] && echo "note: cannot read the frontmost app (Accessibility permission?), so focus will not be handed back" >&2

env HOME="$PWD/.tmp/gdhome" "$GODOT" --path "$PROJ" --position 30000,30000 \
	-s res://tools/menagerie_shots.gd -- --room=menagerie --out="$OUT" "${STOPS_ARG[@]}" > .tmp/shots.log 2>&1 &
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
rm -rf "$PROJ"
if ! grep -q "shots: window mode=0 size=(32, 18)" .tmp/shots.log; then
	echo "warning: the window was not the tiny windowed one ($(grep 'shots: window' .tmp/shots.log | head -1)); it may have covered the screen" >&2
	exit 1
fi
n=$(ls "$OUT" 2>/dev/null | wc -l | tr -d ' ')
echo "$n of $STOPS frames in $OUT"
width=$(sips -g pixelWidth "$OUT/stop_0.png" 2>/dev/null | awk '/pixelWidth/ {print $2}')
if [ -n "$width" ] && [ "$width" -ne 1280 ]; then
	echo "warning: the frames are ${width} px wide, not 1280, so the viewport is not what was asked for" >&2
	exit 1
fi
[ "$n" -eq "$STOPS" ]
