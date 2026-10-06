#!/bin/bash
# One contact sheet of every creature without taking over the screen: tools/shot_run.sh runs tools/creature_sheet.gd in its tiny
# off-screen window, muted. Run from anywhere:  tools/creature_sheet.sh
# The sheet lands in .tmp/creature-sheet/sheet.png. GODOT=/path/to/godot overrides the binary. SHOTS_OUT=/dir puts it there instead
# (the project copy and the log go beside it as DIR.proj and DIR.log), so runs in different directories cannot touch each other.
cd "$(dirname "$0")/.." || exit 1
OUT="${SHOTS_OUT:-$PWD/.tmp/creature-sheet}"
rm -rf "$OUT"
SHOT_DIR="$OUT" tools/shot_run.sh tools/creature_sheet.gd -- --out="$OUT" || exit $?
[ -s "$OUT/sheet.png" ] || { echo "no sheet in $OUT" >&2; exit 1; }
echo "$OUT/sheet.png"
