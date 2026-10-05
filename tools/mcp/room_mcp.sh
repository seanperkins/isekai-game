#!/usr/bin/env bash
# Start the room editor's MCP server on stdio (registered in .mcp.json as "rooms"). Godot runs headless on this checkout's data/rooms.
# HOME is pointed at .tmp/editor-home, as tools/edit_rooms.sh does, so user:// is a throwaway and Godot's log files have a writable
# home. --no-header (not --quiet) keeps stdout clean: --quiet would also silence the print() that carries the replies, and the
# header is the only thing the engine itself writes to stdout. GODOT overrides the binary.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p .tmp/editor-home
exec env -u XDG_DATA_HOME HOME="$PWD/.tmp/editor-home" "${GODOT:-godot}" --headless --no-header --path . -s res://tools/mcp/room_mcp_boot.gd
