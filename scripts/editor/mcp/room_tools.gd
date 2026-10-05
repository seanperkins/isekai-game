class_name RoomTools
extends RefCounted
## The room MCP's tools: a table of name, description, JSON schema and handler over one RoomSession. McpProtocol calls tool_list() and
## call_tool(); a tool that fails returns a normal MCP result with isError set and the reason as text, so the agent reads the same
## message an editor user would.

var _session

func _init(p_session = null) -> void:
	_session = p_session

func tool_list() -> Array:
	return []

func call_tool(name: String, _args: Dictionary) -> Dictionary:
	return fail("unknown tool '%s'" % name)

static func result(content: Array, is_error := false) -> Dictionary:
	return {"content": content, "isError": is_error}

## A successful result: `data` as one JSON text item.
static func ok(data: Variant) -> Dictionary:
	return result([{"type": "text", "text": JSON.stringify(data)}])

static func fail(message: String) -> Dictionary:
	return result([{"type": "text", "text": message}], true)
