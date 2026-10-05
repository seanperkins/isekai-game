extends SceneTree
## Bootstrap for the room MCP server: godot --headless --quiet -s res://tools/mcp/room_mcp_boot.gd (tools/mcp/room_mcp.sh runs it).
##
## This script names no project class. The autoloads do not exist while a `-s` script compiles, so a script that mentions EventBus or
## anything that does would fail to parse; the real server is load()ed on the first frame instead.
##
## Protocol lines come in on stdin (read on a thread, because the read blocks) and go out through print(), one line each, which the
## engine flushes at once. The launcher passes --no-header, so print() is the only thing on stdout; everything else the engine says
## goes to stderr. (FileAccess on /dev/stdout is no way out: Godot refuses to open a pipe or a socket as a file.) A read is one line:
## fgets under it fills a buffer of up to MAX_LINE + 2 bytes, so a 200 KB request is not cut at the usual 64 KB. An empty read is the
## end of input (a client never sends a blank line), which ends the process.

const MAX_LINE := 4194304  # the same number as McpProtocol.MAX_LINE, which this script cannot name

var _thread := Thread.new()
var _mutex := Mutex.new()
var _lines: Array = []
var _eof := false
var _protocol = null

func _initialize() -> void:
	_thread.start(_read_stdin)

func _read_stdin() -> void:
	while true:
		var line := OS.read_string_from_stdin(MAX_LINE + 2).rstrip("\r\n")
		_mutex.lock()
		if line.is_empty():
			_eof = true
			_mutex.unlock()
			return
		_lines.append(line)
		_mutex.unlock()

func _process(_delta: float) -> bool:
	if _protocol == null:
		var protocol_script: GDScript = load("res://scripts/editor/mcp/mcp_protocol.gd")
		var tools_script: GDScript = load("res://scripts/editor/mcp/room_tools.gd")
		var session_script: GDScript = load("res://scripts/editor/mcp/room_session.gd")
		_protocol = protocol_script.new(tools_script.new(session_script.new()))
	_mutex.lock()
	var batch := _lines
	_lines = []
	var eof := _eof
	_mutex.unlock()
	for line: String in batch:
		var reply: String = _protocol.handle_line(line)
		if reply != "":
			print(reply)
	if eof:
		_thread.wait_to_finish()
		quit(0)
		return true
	return false
