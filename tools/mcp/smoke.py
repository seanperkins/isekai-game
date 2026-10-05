#!/usr/bin/env python3
"""Start the real room MCP server and talk to it over stdio, the way an agent's client does.

    python3 tools/mcp/smoke.py

It sends each request in CALLS as one line, reads one reply line, and runs the call's check. It also requires that every line the
server wrote to stdout is JSON (an engine message on that channel would corrupt the protocol) and that closing stdin ends the process
with exit code 0. Later tasks append to CALLS. Nothing here saves: no step touches data/rooms.
"""
import json
import queue
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
LAUNCHER = ROOT / "tools" / "mcp" / "room_mcp.sh"
REPLY_TIMEOUT = 60


def tool(name, args=None):
    return {"method": "tools/call", "params": {"name": name, "arguments": args or {}}}


def text_of(reply):
    """The JSON a tool put in its first text item."""
    return json.loads(reply["result"]["content"][0]["text"])


def is_error(reply):
    return reply.get("result", {}).get("isError") is True


# (label, request without jsonrpc/id, check(reply) -> bool)
CALLS = [
    ("initialize names the server", {"method": "initialize", "params": {"protocolVersion": "2025-06-18"}},
     lambda r: r["result"]["serverInfo"]["name"] == "isekai-rooms"),
    ("tools/list is a list", {"method": "tools/list"}, lambda r: isinstance(r["result"]["tools"], list)),
    ("list_rooms lists the 23 shipped rooms", tool("list_rooms"), lambda r: len(text_of(r)["rooms"]) == 23),
    ("get_room C1 has solids with indexes", tool("get_room", {"room": "C1"}),
     lambda r: text_of(r)["spec"]["id"] == "C1" and text_of(r)["spec"]["solids"][0]["index"] == 0),
    ("preview of C1 is a PNG image then text", tool("preview", {"room": "C1"}),
     lambda r: r["result"]["content"][0]["type"] == "image" and r["result"]["content"][0]["data"].startswith("iVBORw0KGgo")
     and r["result"]["content"][1]["type"] == "text"),
    ("preview of the world is a PNG image", tool("preview"), lambda r: r["result"]["content"][0]["type"] == "image"),
    ("problems has a count and a list", tool("problems"), lambda r: text_of(r)["count"] == len(text_of(r)["items"])),
    # an agent-style session; nothing is saved, and revert at the end drops it all
    ("new_room in a borrowed-art area", tool("new_room", {"beside": "C6", "edge": "left", "id": "Smoke1", "area": "forest", "size": [1, 1]}),
     lambda r: text_of(r)["room"] == "Smoke1"),
    ("apply_room_spec fills it", tool("apply_room_spec", {"room": "Smoke1", "spec": {
        "solids": [{"rect": [100, 260, 120, 12]}], "spawns": [{"creature": "spore_moth", "pos": [200, 200]}]}}),
     lambda r: text_of(r)["counts"]["solids"] == 1 and text_of(r)["counts"]["spawns"] == 1),
    ("stamp_prefab adds a mound", tool("stamp_prefab", {"room": "Smoke1", "prefab": "mound", "origin": [400, 320]}),
     lambda r: text_of(r)["added"]["solids"] == 3),
    ("preview of the new room", tool("preview", {"room": "Smoke1"}), lambda r: r["result"]["content"][0]["type"] == "image"),
    ("problems for the new room", tool("problems", {"room": "Smoke1"}), lambda r: isinstance(text_of(r)["items"], list)),
    ("state shows unsaved rooms", tool("state"), lambda r: "Smoke1" in text_of(r)["dirty"]),
    ("undo takes back the stamp", tool("undo"), lambda r: text_of(r)["ok"] is True),
    ("revert drops the session's edits", tool("revert"), lambda r: text_of(r)["state"]["dirty"] == []),
    ("the new room is gone after revert", tool("get_room", {"room": "Smoke1"}), is_error),
    ("an unknown tool is an error result", tool("nope"), is_error),
    ("a 200 KB line arrives whole and is answered", tool("nope", {"pad": "x" * 200000}), is_error),
    ("the server still answers after it", {"method": "ping"}, lambda r: r["result"] == {}),
]


def main():
    proc = subprocess.Popen([str(LAUNCHER)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    lines = queue.Queue()
    seen = []

    def pump():
        for line in proc.stdout:
            seen.append(line)
            lines.put(line)
        lines.put(None)

    threading.Thread(target=pump, daemon=True).start()
    failures = []
    for n, (label, request, check) in enumerate(CALLS, 1):
        message = {"jsonrpc": "2.0", "id": n, **request}
        proc.stdin.write(json.dumps(message) + "\n")
        proc.stdin.flush()
        try:
            line = lines.get(timeout=REPLY_TIMEOUT)
        except queue.Empty:
            failures.append(f"{label}: no reply in {REPLY_TIMEOUT} s")
            break
        if line is None:
            failures.append(f"{label}: the server closed stdout")
            break
        try:
            reply = json.loads(line)
            ok = reply.get("id") == n and bool(check(reply))
        except Exception as e:  # a malformed reply or a check that cannot read it
            ok, reply = False, f"{type(e).__name__}: {e}: {line[:200]!r}"
        if not ok:
            failures.append(f"{label}: unexpected reply {str(reply)[:300]}")
    proc.stdin.close()
    try:
        code = proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
        code = None
        failures.append("the server did not exit within 10 s of stdin closing")
    if code not in (0, None):
        failures.append(f"exit code {code}")
    for line in seen:
        try:
            json.loads(line)
        except ValueError:
            failures.append(f"a stdout line is not JSON: {line[:200]!r}")
    if failures:
        print("smoke FAILED:\n  " + "\n  ".join(failures))
        print("stderr:", proc.stderr.read()[-2000:])
        sys.exit(1)
    print(f"smoke ok: {len(CALLS)} checks")


if __name__ == "__main__":
    main()
