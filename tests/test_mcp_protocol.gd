extends GutTest
## McpProtocol: JSON-RPC 2.0 routing for the room MCP. A line goes in, a reply line comes out; the tools are a fake here.

class FakeTools:
	extends RefCounted
	func tool_list() -> Array:
		return [{"name": "echo", "description": "d", "inputSchema": {"type": "object"}}]
	func call_tool(name: String, _args: Dictionary):
		match name:
			"null":
				return null
			"bad":
				return {"content": [{"type": "text", "text": "no"}], "isError": true}
		return {"content": [{"type": "text", "text": "hi"}], "isError": false}

var proto: McpProtocol

func before_each() -> void:
	proto = McpProtocol.new(FakeTools.new())

func _reply(line: String) -> Dictionary:
	return JSON.parse_string(proto.handle_line(line))

func _req(id, method: String, params := {}) -> String:
	return JSON.stringify({"jsonrpc": "2.0", "id": id, "method": method, "params": params})

func test_initialize_echoes_a_known_version() -> void:
	var r := _reply(_req(1, "initialize", {"protocolVersion": "2025-06-18"}))
	assert_eq(r["result"]["protocolVersion"], "2025-06-18")
	assert_true(r["result"]["capabilities"].has("tools"))
	assert_eq(r["result"]["serverInfo"]["name"], "isekai-rooms")
	var u := _reply(_req(2, "initialize", {"protocolVersion": "1999-01-01"}))
	assert_eq(u["result"]["protocolVersion"], McpProtocol.VERSIONS[0])

func test_ids_keep_their_type() -> void:
	var text := proto.handle_line(_req(1, "ping"))
	assert_true(text.contains("\"id\":1,") or text.contains("\"id\":1}"), text)
	assert_false(text.contains("1.0"), text)
	assert_eq(_reply(_req("abc", "ping"))["id"], "abc")

func test_ping_and_notifications() -> void:
	assert_eq(_reply(_req(1, "ping"))["result"], {})
	assert_eq(proto.handle_line(JSON.stringify({"jsonrpc": "2.0", "method": "notifications/initialized"})), "")

func test_errors() -> void:
	var bad := _reply("this is not json")
	assert_eq(bad["error"]["code"], -32700)
	assert_eq(bad["id"], null)
	assert_eq(_reply("[]")["error"]["code"], -32600)
	assert_eq(_reply(JSON.stringify({"jsonrpc": "2.0", "id": 1}))["error"]["code"], -32600)
	assert_eq(_reply(_req(1, "nope"))["error"]["code"], -32601)
	assert_eq(_reply(_req(1, "tools/call", {"arguments": {}}))["error"]["code"], -32602)
	assert_eq(_reply("x".repeat(McpProtocol.MAX_LINE + 1))["error"]["code"], -32600)

func test_tools_list_and_call_pass_through() -> void:
	assert_eq(_reply(_req(1, "tools/list"))["result"]["tools"][0]["name"], "echo")
	var ok := _reply(_req(2, "tools/call", {"name": "echo", "arguments": {}}))
	assert_eq(ok["result"], {"content": [{"type": "text", "text": "hi"}], "isError": false})
	var bad := _reply(_req(3, "tools/call", {"name": "bad"}))
	assert_eq(bad["result"]["isError"], true)

func test_a_tool_that_returns_null_is_an_internal_error() -> void:
	var r := _reply(_req(1, "tools/call", {"name": "null", "arguments": {}}))
	assert_eq(r["error"]["code"], -32603)
	assert_eq(_reply(_req(2, "ping"))["result"], {})
