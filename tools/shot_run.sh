#!/bin/bash
# Runs a shot tool without taking over the screen. Godot cannot render headless (its headless display driver is the dummy renderer),
# so a shot tool needs a real window; this gives it the smallest one it can get away with:
#  - the game starts fullscreen (display/window/size/mode=3), which takes over a Space and ignores --windowed and --position, so the
#    run uses a throwaway project of symlinks to the real one with a rewritten project.godot (tools/shot_project.py): a 32x18
#    borderless window that cannot take focus. The real project.godot is never touched;
#  - the tool draws the game into a SubViewport (tools/shot_stage.gd, ShotStage) and saves that, so its frames are full size;
#  - the app you were in gets the focus back if Godot takes it anyway (by process id: it never launches or opens anything);
#  - the game's sound is muted (--audio-driver Dummy) unless SHOT_AUDIO=1: a shot run is not for listening to.
# Usage:  tools/shot_run.sh tools/room_shots.gd [-- tool arguments ...]
# Environment:  GODOT (the binary, default godot); SHOT_AUDIO=1 (leave the sound on); SHOT_HOME (HOME for the run; default a throwaway one); SHOT_GODOT_ARGS (extra Godot
# flags, e.g. "--fixed-fps 60"); SHOT_DIR (the project copy goes to $SHOT_DIR.proj and the log to $SHOT_DIR.log, default .tmp/shotrun.PID,
# so two runs never touch each other). Written and tested on macOS: osascript is skipped where it is missing.
# SHOT_TIMEOUT is the seconds a run may take before it is killed (default 900; a tool whose script errors can otherwise wait forever).
# Exit status: the tool's own; 124 for a timeout; 1 when the window was not the tiny one (the tool did not use ShotStage, or the
# project copy failed).
cd "$(dirname "$0")/.." || exit 1
if [ $# -lt 1 ] || [ ! -f "$1" ]; then
	echo "usage: $0 tools/some_shots.gd [-- tool arguments ...]   (the tool must be a file under the project)" >&2
	exit 2
fi
tool="$1"
shift
[ "${1:-}" = "--" ] && shift

GODOT="${GODOT:-godot}"
SHOT_DIR="${SHOT_DIR:-$PWD/.tmp/shotrun.$$}"
# Each run gets a throwaway HOME (and so a fresh profile) unless SHOT_HOME names one: tools like evolution_shots save what they reach,
# and a profile shared with tools/run_tests.sh made its tests see forms nobody earned.
OWN_HOME=""
if [ -z "${SHOT_HOME:-}" ]; then OWN_HOME="$SHOT_DIR.home"; fi
HOME_DIR="${SHOT_HOME:-$OWN_HOME}"
PROJ="$SHOT_DIR.proj"
LOG="$SHOT_DIR.log"
mkdir -p "$(dirname "$SHOT_DIR")"
[ -n "$OWN_HOME" ] && rm -rf "$OWN_HOME"
mkdir -p "$HOME_DIR"
rm -rf "$PROJ" "$LOG"
pid=""
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null; rm -rf "$PROJ" $OWN_HOME' EXIT
mkdir -p "$PROJ"
for f in * .godot; do
	case "$f" in project.godot|.tmp|.git|.worktrees|node-compile-cache) continue;; esac
	[ -e "$f" ] && ln -s "$PWD/$f" "$PROJ/$f"
done
ln -s "$PWD/.tmp" "$PROJ/.tmp"  # the tools save their frames under res://.tmp
python3 tools/shot_project.py "$PWD/project.godot" "$PROJ/project.godot" || exit 1

# The focus is read and given back by process id through System Events, which only fronts a process that is already running. Never by
# name with `tell application "..." to activate`: that launches whatever app has that name, and two builds of one app (a terminal and
# an old test build of it) share a name, so it opened a new terminal each time.
front() { command -v osascript >/dev/null 2>&1 && osascript -e 'tell application "System Events" to unix id of first process whose frontmost is true' 2>/dev/null; }
refront() { osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $1) to true" >/dev/null 2>&1; }  # fails if that process is gone
mine=$(front)
case "$mine" in ''|*[!0-9]*) mine=""; echo "note: cannot read the frontmost app (Accessibility permission?), so focus will not be handed back" >&2;; esac

AUDIO_ARGS="--audio-driver Dummy"
[ "${SHOT_AUDIO:-0}" = "1" ] && AUDIO_ARGS=""
if [ -n "${SHOT_DRY_RUN:-}" ]; then  # print the command and stop (the tests read it)
	echo "HOME=$HOME_DIR $GODOT --path $PROJ --position 30000,30000 $AUDIO_ARGS ${SHOT_GODOT_ARGS:-} -s res://$tool -- $*"
	exit 0
fi
# shellcheck disable=SC2086  # AUDIO_ARGS and SHOT_GODOT_ARGS are lists of flags
env HOME="$HOME_DIR" "$GODOT" --path "$PROJ" --position 30000,30000 $AUDIO_ARGS ${SHOT_GODOT_ARGS:-} -s "res://$tool" -- "$@" > "$LOG" 2>&1 &
pid=$!
limit=$((SECONDS + ${SHOT_TIMEOUT:-900}))
while kill -0 "$pid" 2>/dev/null; do
	if [ "$SECONDS" -ge "$limit" ]; then
		echo "the tool ran past ${SHOT_TIMEOUT:-900} s and was stopped; the end of its log ($LOG):" >&2
		tail -n 15 "$LOG" >&2
		kill "$pid" 2>/dev/null
		wait "$pid" 2>/dev/null
		pid=""
		exit 124
	fi
	if [ -n "$mine" ]; then
		now=$(front)
		if [ -n "$now" ] && [ "$now" != "$mine" ]; then
			refront "$mine" || mine=""  # the app is gone (it was updated or quit mid-run): stop trying
		fi
	fi
	sleep 0.15
done
wait "$pid"
status=$?
pid=""
# Windowed and no bigger than 128 px each way (a tool may raise the 32x18 a little: the room editor sets a minimum size).
if ! grep -E "shots: window mode=0 size=\(([0-9]{1,3}), ([0-9]{1,3})\)" "$LOG" | awk -F'[(, )]+' '{ if ($5 <= 128 && $6 <= 128) ok = 1 } END { exit !ok }'; then
	echo "warning: the window was not a tiny windowed one ($(grep 'shots: window' "$LOG" | head -1)); the tool may have covered the screen. Log: $LOG" >&2
	exit 1
fi
if [ "$status" -ne 0 ]; then
	echo "the tool exited $status; the end of its log ($LOG):" >&2
	tail -n 15 "$LOG" >&2
fi
exit "$status"
