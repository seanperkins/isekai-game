class_name McpProtocol
extends RefCounted
## JSON-RPC 2.0 routing for the room MCP server (see docs/superpowers/specs/2026-10-04-room-editor-mcp-design.md). A request line goes
## in and a reply line comes out; the tools sit behind two methods, so this class knows nothing about rooms.
##
## The tools object offers `tool_list() -> Array` ({name, description, inputSchema}) and `call_tool(name, args) -> Dictionary`, an MCP
## result ({content: Array, isError: bool}). A tool that returns anything else (GDScript has no exceptions: a script error in a
## handler leaves it returning null) is answered with an internal error, and the server carries on.

const VERSIONS := ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
const MAX_LINE := 4194304
const SERVER_NAME := "isekai-rooms"

const PARSE_ERROR := -32700
const INVALID_REQUEST := -32600
const METHOD_NOT_FOUND := -32601
const INVALID_PARAMS := -32602
const INTERNAL_ERROR := -32603

var _tools: Object

func _init(p_tools: Object) -> void:
	_tools = p_tools

## The reply to one request line, without a trailing newline. "" when none is due: a notification (a message with no id) never
## gets one, whatever it asked for.
func handle_line(line: String) -> String:
	if line.length() > MAX_LINE:
		return _error(null, INVALID_REQUEST, "the line is longer than %d characters" % MAX_LINE)
	var json := JSON.new()
	if json.parse(line) != OK:
		return _error(null, PARSE_ERROR, "not JSON: %s" % json.get_error_message())
	var msg = json.data
	if not msg is Dictionary:
		return _error(null, INVALID_REQUEST, "a request is a JSON object")
	var notification: bool = not msg.has("id")
	var id = _norm_id(msg.get("id"))
	if not msg.get("method") is String:
		return "" if notification else _error(id, INVALID_REQUEST, "a request has a method")
	var params = msg.get("params", {})
	if not params is Dictionary:
		params = {}
	var reply := _dispatch(id, msg["method"], params)
	return "" if notification else reply

func _dispatch(id, method: String, params: Dictionary) -> String:
	match method:
		"initialize":
			var asked: String = str(params.get("protocolVersion", ""))
			return _result(id, {
				"protocolVersion": asked if VERSIONS.has(asked) else VERSIONS[0],
				"capabilities": {"tools": {}},
				"serverInfo": {"name": SERVER_NAME, "version": "1"},
			})
		"ping":
			return _result(id, {})
		"tools/list":
			return _result(id, {"tools": _tools.tool_list()})
		"tools/call":
			var name = params.get("name")
			if not name is String or name == "":
				return _error(id, INVALID_PARAMS, "tools/call needs a tool name")
			var args = params.get("arguments", {})
			if not args is Dictionary:
				return _error(id, INVALID_PARAMS, "arguments is an object")
			var out = _tools.call_tool(name, args)
			if not out is Dictionary:
				return _error(id, INTERNAL_ERROR, "the tool '%s' failed; see the server's stderr" % name)
			return _result(id, out)
		"notifications/initialized", "notifications/cancelled":
			return ""
	return _error(id, METHOD_NOT_FOUND, "unknown method '%s'" % method)

## JSON numbers parse as floats; an id that was written 1 must be answered 1, not 1.0.
static func _norm_id(id):
	if id is float and is_finite(id) and id == floorf(id) and absf(id) < 9007199254740992.0:
		return int(id)
	return id

static func _result(id, result: Dictionary) -> String:
	return JSON.stringify({"jsonrpc": "2.0", "id": id, "result": result})

static func _error(id, code: int, message: String) -> String:
	return JSON.stringify({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
