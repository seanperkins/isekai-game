#!/usr/bin/env bash
# Open the room editor. HOME is pointed at .tmp/editor-home so user:// (the profile, the bestiary, the audio settings) is a
# throwaway directory: Play from the editor can never write the real save. Delete .tmp/editor-home to reset that profile.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp/editor-home
exec env -u XDG_DATA_HOME HOME="$PWD/.tmp/editor-home" godot --path . res://scenes/room_editor.tscn
