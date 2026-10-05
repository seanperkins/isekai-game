# Room Editor MCP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An MCP server, run headless by Godot, that lets an agent read, edit, check, preview and save the game's rooms with the room editor's own rules.

**Architecture:** A thin bootstrap script reads JSON-RPC lines from stdin on a thread and writes replies to `/dev/stdout`. It lazily loads pure classes under `scripts/editor/mcp/`: a protocol router, a tool table over a `RoomSession` (one `RoomEditModel` working set plus on-disk hashes), a spec converter and a CPU-drawn preview. New areas borrow existing biome art through one alias function.

**Tech Stack:** Godot 4.7 GDScript (tabs, typed signatures), GUT tests via `tools/run_tests.sh`, a Python 3 smoke client.

**Spec:** `docs/superpowers/specs/2026-10-04-room-editor-mcp-design.md`

## Global Constraints

- Godot 4.7, headless: `godot --headless --quiet --path . -s res://tools/mcp/room_mcp_boot.gd`; macOS and Linux only (`/dev/stdout`). stdout carries protocol lines only; logs go to stderr.
- JSON-RPC 2.0, newline-delimited. Errors: -32700 parse, -32600 invalid request, -32601 unknown method, -32602 bad params, -32603 internal. Lines up to 4 MiB (`McpProtocol.MAX_LINE = 4194304`). A failed tool is a normal result with `isError: true` and the model's own error string.
- Room-local pixels, y down; grid 4; `MAX_SCREENS` 6; `MIN_SOLID` 4; `MIN_WATER` 32; door 80; screen 640x360; wall 20; floor 40.
- `save` writes only `res://data/rooms/*.tres` (the tool takes no path). The launcher sets `HOME=$PWD/.tmp/editor-home`. Nothing reaches disk before `save`.
- Tests never write `res://data/rooms`: they use `res://.tmp/<name>` and remove it in `after_each`. We are only adding: no test or smoke step reshapes a shipped room on disk.
- A new `class_name` file needs `HOME="$PWD/.tmp/gdhome" godot --headless --import` before tests see it. Judge test runs by `tools/run_tests.sh` (it reads the log, not the exit code alone).
- Commit messages: `feat:`, `fix:`, `test:` or `docs:` prefix, no attribution lines. Commit on `feat/room-mcp` in `.worktrees/room-mcp`; do not push.

## Review Focus

- A 200 KB request line (a large `apply_room_spec`) arrives whole and the next request still answers: Task 2 smoke.
- Anything the engine prints to stdout corrupts the channel: Task 2 smoke parses every stdout line as JSON.
- Wrong-typed or missing arguments (`pos: "5,5"`, `a` with one number, unknown tool) return `isError` and change nothing: Tasks 4 and 5.
- A `ref` whose index went stale after a delete, or an unknown room: `isError`, nothing changed: Task 6.
- Off-grid, negative, enormous or infinite numbers in a spec, and a 6x6-screen preview at scale 1: Tasks 3, 8 and 9.

---

### Task 1: McpProtocol

**Files:**
- Create: `scripts/editor/mcp/mcp_protocol.gd`
- Test: `tests/test_mcp_protocol.gd`

**Interfaces:**
- Produces:
  - `class_name McpProtocol extends RefCounted`; `const VERSIONS := ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]`; `const MAX_LINE := 4194304`
  - `func _init(p_tools: Object)`: `p_tools` has `tool_list() -> Array` (`{name, description, inputSchema}`) and `call_tool(name: String, args: Dictionary) -> Dictionary` (an MCP result `{content: Array, isError: bool}`)
  - `func handle_line(line: String) -> String`: the reply without a trailing newline, or `""` when none is due (a notification)

- [ ] **Step 1: Import the worktree.** It has no `.godot/`. Run `HOME="$PWD/.tmp/gdhome" godot --headless --import` twice. Expected: both exit and `.godot/` exists.
- [ ] **Step 2: Write `tests/test_mcp_protocol.gd`** with a fake tools object (inner class) and these tests:
  - `test_initialize_echoes_a_known_version`: reply `result.protocolVersion == "2025-06-18"`, `result.capabilities` has key `tools`, `result.serverInfo.name == "isekai-rooms"`; an unknown version gives `VERSIONS[0]`.
  - `test_ids_keep_their_type`: a request with `"id":1` is answered with text containing `"id":1,` and not `"id":1.0`; a string id is echoed as a string.
  - `test_ping_and_notifications`: `ping` result is `{}`; a message with no `id` returns `""`.
  - `test_errors`: garbage line gives -32700 with `id` null; `[]` and a missing `method` give -32600; `nope` gives -32601; `tools/call` without `name` gives -32602; a line of `MAX_LINE + 1` characters gives -32600.
  - `test_tools_list_and_call_pass_through`: `tools/list` returns the fake's list; `tools/call` returns the fake's result unchanged, including `isError: true`.
  - `test_a_tool_that_returns_null_is_an_internal_error`: the call answers -32603 and the next request still works (GDScript has no exceptions; a script error in a handler leaves it returning null).
- [ ] **Step 3: Run** `tools/run_tests.sh mcp_protocol`. Expected: FAIL (class not declared).
- [ ] **Step 4: Implement `McpProtocol`** per the interface. A float id with no fraction is converted to int before stringifying.
- [ ] **Step 5: Re-import** (new class) and run `tools/run_tests.sh mcp_protocol`. Expected: exit 0, all tests passed.
- [ ] **Step 6: Commit** `git add scripts/editor/mcp tests && git commit -m "feat: the MCP protocol router"`

### Task 2: Bootstrap, launcher, registration, smoke client

**Files:**
- Create: `tools/mcp/room_mcp_boot.gd`, `tools/mcp/room_mcp.sh` (executable), `tools/mcp/smoke.py`, `.mcp.json`, `scripts/editor/mcp/room_tools.gd`

**Interfaces:**
- Consumes: `McpProtocol` (Task 1).
- Produces: `class_name RoomTools extends RefCounted` with `func _init(p_session = null)`, `func tool_list() -> Array`, `func call_tool(name: String, args: Dictionary) -> Dictionary`, `static func result(content: Array, is_error := false) -> Dictionary`, `static func ok(data: Variant) -> Dictionary` (one text item, `JSON.stringify(data)`), `static func fail(message: String) -> Dictionary`. In this task the table is empty and every call is `fail("unknown tool 'x'")`.
- `tools/mcp/smoke.py` holds `CALLS`, a list of `(request, check)` pairs later tasks append to.

- [ ] **Step 1: Write `tools/mcp/smoke.py`** (stdlib only). It starts `tools/mcp/room_mcp.sh`, writes each request as one line, reads one reply line each, and runs the check. First calls: `initialize` (`serverInfo.name == "isekai-rooms"`), `tools/list` (`result.tools` is a list), a `tools/call` of an unknown tool (`isError` true), then a `tools/call` whose `arguments.pad` is 200,000 `x` (a reply arrives, `isError` true, and a following `ping` answers). Afterwards it closes stdin and requires exit code 0 within 10 s, and requires that every stdout line parsed as JSON. Prints `smoke ok: N checks`.
- [ ] **Step 2: Run** `python3 tools/mcp/smoke.py`. Expected: FAIL (launcher missing).
- [ ] **Step 3: Write the launcher and `.mcp.json`.** `room_mcp.sh`: `set -euo pipefail`, `cd "$(dirname "$0")/../.."`, `mkdir -p .tmp/editor-home`, refuse with a stderr message if `/dev/stdout` does not exist, then `exec env -u XDG_DATA_HOME HOME="$PWD/.tmp/editor-home" "${GODOT:-godot}" --headless --quiet --path . -s res://tools/mcp/room_mcp_boot.gd`. `.mcp.json`: `{"mcpServers": {"rooms": {"command": "tools/mcp/room_mcp.sh", "args": []}}}`.
- [ ] **Step 4: Write `RoomTools` skeleton** per the interface.
- [ ] **Step 5: Write `room_mcp_boot.gd`** (`extends SceneTree`, no project class names, because autoloads do not exist when it compiles):
  - `_initialize`: open `/dev/stdout` once with `FileAccess.WRITE`; start a `Thread` that loops on `OS.read_string_from_stdin(65536)`, appending chunks until one ends in `\n` (a line longer than the buffer arrives in pieces), stops appending past `McpProtocol.MAX_LINE + 1` characters while still consuming to the newline, queues each line under a `Mutex`, and on an empty read sets an `eof` flag. The thread may only use `"4194304"` as a literal, not the class.
  - `_process(delta) -> bool`: on the first frame, `load()` `mcp_protocol.gd` and `room_tools.gd` and build `McpProtocol.new(RoomTools.new())`; each frame pop queued lines, write each non-empty `handle_line` result plus `\n`, and `flush()`; once `eof` is set and the queue is empty call `thread.wait_to_finish()` and `quit(0)`; return false.
- [ ] **Step 6: Run** `python3 tools/mcp/smoke.py`. Expected: `smoke ok`, exit 0, no stdout line that is not JSON.
- [ ] **Step 7: Commit** `git add tools/mcp .mcp.json scripts/editor/mcp tests && git commit -m "feat: the room MCP server boots and answers"`

### Task 3: RoomSpec

**Files:**
- Create: `scripts/editor/mcp/room_spec.gd`
- Test: `tests/test_room_spec.gd`

**Interfaces:**
- Produces `class_name RoomSpec`:
  - `static func to_json(r: RoomDef, indexed := false) -> Dictionary`: the spec of the design's "Room spec" section (`id, area, cell, size, start, solids, water, spawns, features, decor, exits`); `indexed` adds `index` to every element
  - `static func content_of(r: RoomDef) -> Dictionary`: runtime content `{solids: [{rect: Rect2, hard: bool}], water: [Rect2], spawns: [{id: String, pos: Vector2}], features: [Dictionary], decor: [Dictionary]}`
  - `static func content_from_json(spec: Dictionary) -> Dictionary`: `{content: Dictionary (same shape as content_of), errors: [{kind, index, error}]}`; kinds are `solid`, `water`, `spawn`, `feature`, `decor`

- [ ] **Step 1: Write failing tests.**
  - `test_every_shipped_room_round_trips`: for each of `ShippedRooms.load_all()`: `content_from_json(JSON.parse_string(JSON.stringify(to_json(r)))).content == content_of(r)` and `errors == []`.
  - `test_malformed_elements_are_reported_by_kind_and_index`: solids `[{"rect": [1, 2, 3]}, {"rect": [0, 0, 8, 8]}]` and spawns `[{"creature": "toad", "pos": "x"}]` give errors for `solid` 0 and `spawn` 0, and the good solid stays in `content`.
  - `test_non_finite_and_huge_numbers_are_shape_errors`: `{"rect": [0, 0, 1e999, 10]}` and `{"rect": [0, 0, 1e9, 10]}` (finite and `abs > 1e6` is out of range) are errors for `solid` 0.
  - `test_indexed_and_start`: `indexed` gives `index` 0..n-1 per kind; a room with no start has `"start": null`.
  - `test_decor_keys_pass_through`: `{"piece": "rubble", "pos": [1, 2], "light": [1, 0.5, 0.25, 1], "anchor": "top"}` becomes `{id: "rubble", pos: Vector2(1, 2), light: Color(1, 0.5, 0.25, 1), anchor: "top"}`; a feature spec without `id` yields an entry without `id` (the model generates one).
- [ ] **Step 2: Run** `tools/run_tests.sh room_spec`. Expected: FAIL.
- [ ] **Step 3: Implement `RoomSpec`.** Vectors and rects are number arrays; a spawn's `creature` is the stored `id`; decor `piece` is the stored `id`; `light` is `[r, g, b, a]`; every other feature or decor key passes through under its own name.
- [ ] **Step 4: Re-import, run** `tools/run_tests.sh room_spec`. Expected: exit 0.
- [ ] **Step 5: Commit** `git add scripts/editor/mcp tests && git commit -m "feat: RoomSpec converts a room to and from the MCP's JSON"`

### Task 4: RoomSession and the read tools

**Files:**
- Create: `scripts/editor/mcp/room_session.gd`
- Modify: `scripts/editor/mcp/room_tools.gd`, `tools/mcp/room_mcp_boot.gd`, `tools/mcp/smoke.py`
- Test: `tests/test_room_session.gd`, `tests/test_room_tools_read.gd`

**Interfaces:**
- Consumes: `RoomSpec.to_json`, `RoomTools.ok/fail/result`.
- Produces `class_name RoomSession extends RefCounted`:
  - `const ROOMS_DIR := "res://data/rooms"`; `var model: RoomEditModel`; `var dir: String`
  - `func _init(p_dir := ROOMS_DIR)`: loads `World.load_rooms(p_dir)`, creature ids from `DefLoader.load_dir("res://data/creatures")`, and the SHA-256 of each room file
  - `func reload() -> void`: rebuilds the model and the hashes from `dir`
  - `func changed_on_disk() -> Array`: ids whose file hash differs from the recorded one (a recorded `""` for a new room counts as changed when the file now exists)
  - `func state() -> Dictionary`: `{rooms, dirty, undo_depth, redo_depth, changed_on_disk}`
- `RoomTools._init(p_session: RoomSession = null)`; tools are added with `_add(name: String, description: String, schema: Dictionary, handler: Callable)`; `_check_args(schema: Dictionary, args: Dictionary) -> String` validates a JSON-schema subset (`type`, `properties`, `required`, `enum`, `items`, `minItems`, `maxItems`, `minimum`, `maximum`) and returns `""` or a reason such as `"pos: expected an array of 2 numbers"`. `call_tool` runs `_check_args` first.

- [ ] **Step 1: Write failing tests.**
  - `test_room_session.gd`: a session on a temp copy of the shipped rooms has 23 rooms, no dirty, and `changed_on_disk() == []`; rewriting one file on disk makes it appear in `changed_on_disk()`; `reload()` clears dirty and returns the model's depths to 0.
  - `test_room_tools_read.gd` (session on `ROOMS_DIR`, read-only): `list_rooms` returns 23 rooms with `counts`, and `area: "cave"` returns 6; `get_room` C1 has `spec.id == "C1"` with `solids[0].index == 0`, unknown room gives `isError` text `no room 'Z9'`; `catalog` has `features == ["glow_pool", "tablet", "switch", "altar"]`, `limits.grid == 4`, `limits.max_screens == 6`, `gates == ["wall_cling", "swim"]`, `prefabs.mound.width == 160`, non-empty `decor.cave`, `creatures` equal to `session.model.creature_ids`, `areas` equal to `TerrainArt.biomes()`; `problems` has `count == model.problems().size()` and the `room` filter narrows it; `world_size` has `rooms == 23`, `screens == 45`, three yardsticks; `state` equals `session.state()`.
  - `test_bad_arguments_are_refused`: `get_room` with `{}` gives `isError` `room: required`; `{"room": 5}` gives `room: expected a string`; an unknown tool gives `isError`; none of these changes `model.dirty`.
- [ ] **Step 2: Run** `tools/run_tests.sh room_session` and `tools/run_tests.sh room_tools_read`. Expected: FAIL.
- [ ] **Step 3: Implement `RoomSession`** and the tool table with `list_rooms`, `get_room` (spec via `RoomSpec.to_json(r, true)` plus each exit's partner from `model.partner_of`), `catalog` (sections `creatures, features, decor, prefabs, perks, gates, areas, limits`, an optional `section` argument), `problems` (`{count, items}`, optional `room`), `world_size` (`WorldSize.measure` with `yardsticks` and `area_rows`), `state`. Tool results are plain JSON types only.
- [ ] **Step 4: Point the bootstrap at a session.** In `room_mcp_boot.gd` build `RoomTools.new(load("res://scripts/editor/mcp/room_session.gd").new())`. Append smoke calls: `list_rooms` (23 rooms), `get_room` C1, `problems` (`items` is a list).
- [ ] **Step 5: Re-import; run both test files and `python3 tools/mcp/smoke.py`.** Expected: exit 0, `smoke ok`.
- [ ] **Step 6: Commit** `git add scripts/editor/mcp tools/mcp tests && git commit -m "feat: the MCP reads rooms, problems, catalogs and the size meter"`

### Task 5: Add tools

**Files:**
- Modify: `scripts/editor/mcp/room_tools.gd`
- Test: `tests/test_room_tools_add.gd`

**Interfaces:**
- Consumes: `RoomTools._add`, `_check_args`, `ok/fail`; `session.model` (`RoomEditModel`).
- Produces tools: `new_room {beside, edge, id, area, size: [w, h]}` -> `{ok, room}`; `grow_room {room, side, screens?}` -> `{ok, room, cell, size}`; `add_solid {room, a, b}`, `add_water {room, a, b}`, `add_spawn {room, creature, pos}`, `add_feature {room, kind, pos}`, `add_decor {room, piece, pos}`, `add_exit {room, edge, from, to, gate?, shortcut?}` -> `{ok, ref: {room, kind, index}}`. `a`, `b`, `pos` are arrays of exactly 2 numbers; `size` is 2 integers 1 to 6. The `ref` is read from `model.selection` after the call. A model error string becomes `fail(that string)`.

- [ ] **Step 1: Write failing tests** (`session` on a temp copy, `model` fresh each test):
  - `test_add_solid_succeeds`: `{"room": "C1", "a": [100, 100], "b": [200, 116]}` gives `ref.kind == "solid"`, `ref.index == <previous solid count>`, and `model.dirty.has("C1")`.
  - `test_refusals_carry_the_models_own_text`: `add_solid` 2 px wide gives `too small, or outside the room`; `add_water` 8 px gives `too small: water is at least 32 px each way`; `add_spawn` creature `nope` gives `unknown creature 'nope'`; `add_feature` kind `banner` gives `unknown feature 'banner'`; `add_decor` piece `zzz` gives `unknown decor 'zzz'`; `add_exit` edge `up` gives `not an edge`; `grow_room` side `bottom` gives the model's `a room grows to the left, right or top: the bottom stays where the floor is`; `new_room` area `nowhere` gives `unknown area 'nowhere'`.
  - `test_new_room_beside_a_free_edge_creates_a_paired_room`: use an edge and size that `tests/test_room_edit_new_room.gd` shows is free; result `ok`, the room exists, both rooms are dirty.
  - `test_add_exit_creates_the_partner`: on that new room add a second exit over a span `tests/test_room_edit_exits.gd` shows is free; `ref.kind == "exit"` and `model.partner_of(room, ref.index)` is not empty.
  - `test_wrong_typed_arguments_change_nothing`: `add_solid` with `a: [1]`, `pos: "5,5"` on `add_spawn`, `size: [0, 1]` on `new_room` each give `isError` with the `_check_args` reason, and afterwards `model.dirty` is empty and `model.undo_depth() == 0`.
- [ ] **Step 2: Run** `tools/run_tests.sh room_tools_add`. Expected: FAIL.
- [ ] **Step 3: Implement the eight tools** as one-line wrappers over the model calls listed in the design's Edit table; the model keeps every rule.
- [ ] **Step 4: Run** `tools/run_tests.sh room_tools`. Expected: exit 0 (Tasks 4 and 5 files).
- [ ] **Step 5: Commit** `git add scripts/editor/mcp tests && git commit -m "feat: the MCP adds rooms, solids, water, creatures, features, decor and exits"`

### Task 6: Change tools

**Files:**
- Modify: `scripts/editor/mcp/room_tools.gd`
- Test: `tests/test_room_tools_change.gd`

**Interfaces:**
- Consumes: Task 5's tools to build state.
- Produces: `_select(ref: Dictionary) -> String` (private; `""` and sets `model.selection`, or `no room 'X'` / `no such element: C1 solid 99`, where valid kinds are `solid, water, spawn, feature, decor, exit` and an index must be inside the matching array of the room). Tools: `set_field {ref, key, value}` -> `{ok, ref}`; `move {ref, delta: [dx, dy]}` -> `{ok, ref}`; `delete {ref}` -> `{ok, deleted: ref}`; `undo {}` and `redo {}` -> `{ok: true, undo_depth, redo_depth}`. `ref` schema: `{room: string, kind: enum, index: integer >= 0}`.

- [ ] **Step 1: Write failing tests:**
  - `test_a_stale_ref_after_a_delete_is_refused`: add two solids to C1, `delete` index of the first, then `set_field` on the old last index gives `isError` `no such element: C1 solid <n>`, and `RoomEditModel.same_room` still holds against a snapshot taken before the call.
  - `test_unknown_room_is_refused`: any of the four ref tools with room `Z9` gives `no room 'Z9'`.
  - `test_set_field_and_move`: `set_field` solid `x` to 120 reads back 120 through `model.get_field`; `move` by `[8, 0]` shifts the solid by exactly 8.
  - `test_delete_then_undo_restores_the_room`: after `delete` + `undo`, `same_room` against the original is true; `redo` deletes again.
  - `test_undo_with_nothing_to_undo`: `isError` `nothing to undo`; `redo` likewise `nothing to redo`.
  - `test_the_models_refusal_comes_through`: `set_field` of a solid `w` to 2 gives the model's too-small text.
- [ ] **Step 2: Run** `tools/run_tests.sh room_tools_change`. Expected: FAIL.
- [ ] **Step 3: Implement** the four ref tools and `undo`/`redo`: `move` runs `begin_move(selection)`, `move_to(delta)`, `end_move()` and fails with `cannot move this element` when `begin_move` is false; `delete` runs `delete_selection()`.
- [ ] **Step 4: Run** `tools/run_tests.sh room_tools`. Expected: exit 0.
- [ ] **Step 5: Commit** `git add scripts/editor/mcp tests && git commit -m "feat: the MCP edits, moves and deletes elements, with undo and redo"`

### Task 7: Save and revert

**Files:**
- Modify: `scripts/editor/room_edit_model.gd` (`save_dirty`), `scripts/editor/mcp/room_session.gd`, `scripts/editor/mcp/room_tools.gd`
- Test: `tests/test_room_edit_save.gd` (add one test), `tests/test_room_session.gd` (add tests), `tests/test_room_tools_save.gd`

**Interfaces:**
- Produces: `RoomEditModel.save_dirty(dir: String, only: Array = []) -> Dictionary` (a non-empty `only` writes just those dirty ids; removals of session-created files are unaffected). `RoomSession.save(ids: Array = [], force := false) -> Dictionary` returns `{saved: Array, removed: Array, errors: Dictionary, problems: Array}`; for each requested (default: every dirty) room whose file hash differs from the recorded one it records `errors[id] = "changed on disk since loaded"` unless `force`, writes the rest with `model.save_dirty(dir, only)`, records the new hash of each saved file, and `problems` holds `model.problems()` entries for saved rooms. `RoomSession.revert() -> void` is `reload()`. Tools: `save {rooms?, force?}` and `revert {}`; neither takes a path.

- [ ] **Step 1: Write failing tests** (temp dir `res://.tmp/room_mcp_save_test` filled with `ResourceSaver` copies of the shipped rooms in `before_each`):
  - model: `save_dirty(dir, ["C2"])` with C1 and C2 dirty writes only C2 and leaves C1 dirty.
  - `test_save_writes_only_dirty_rooms`: edit C1, `save()` gives `saved == ["C1"]`, and the reloaded file equals the model's room.
  - `test_stale_file_is_refused_then_forced`: rewrite `C1.tres` on disk with one extra solid, edit C1, `save()` gives `errors["C1"] == "changed on disk since loaded"` and the disk file is untouched; `save([], true)` writes it. A second edit and `save()` afterwards succeeds (hash was updated).
  - `test_a_new_room_whose_file_appeared_is_stale`: create a room with `new_room_beside`, write a file of that name, `save()` refuses it.
  - `test_save_subset_and_problems`: dirty C1 and C2, `save(["C2"])` saves only C2 and `problems` has only C2 entries.
  - `test_revert_drops_everything`: edit, `revert()`: `dirty` empty, `undo_depth() == 0`, the room equals disk.
  - tools: `save` and `revert` through `RoomTools`, and the `save` schema has no path property.
- [ ] **Step 2: Run** `tools/run_tests.sh room_edit_save`, `room_session` and `room_tools_save`. Expected: FAIL.
- [ ] **Step 3: Implement** the model parameter, `RoomSession.save/revert` and the two tools. Hashes come from `FileAccess.get_sha256(path)` (`""` when the file is missing).
- [ ] **Step 4: Run** `tools/run_tests.sh room_edit`, `room_session` and `room_tools`. Expected: exit 0.
- [ ] **Step 5: Commit** `git add scripts/editor tests && git commit -m "feat: the MCP saves dirty rooms and refuses a file that changed on disk"`

### Task 8: Preview

**Files:**
- Create: `scripts/editor/mcp/room_preview.gd`
- Modify: `scripts/editor/mcp/room_tools.gd`, `tools/mcp/smoke.py`
- Test: `tests/test_room_preview.gd`

**Interfaces:**
- Consumes: `WorldView.layout(rooms, rect)`, `RoomDef.world_rect()`.
- Produces `class_name RoomPreview`: constants `MAX_SIDE := 2000`, `MIN_SCALE := 0.25`, colours `C_AIR, C_SOLID, C_HARD, C_WATER, C_SPAWN, C_FEATURE, C_DECOR, C_START`; `static func clamp_scale(r: RoomDef, scale: float) -> float` (at least `MIN_SCALE`, and at most `MAX_SIDE / longest side px`); `static func image(r: RoomDef, scale: float) -> Image`; `static func text_map(r: RoomDef) -> String` (cell 40 px, 80 px when the room is over 3 screens wide; `#` solid, `~` water, `S` spawn, `F` feature, `d` decor, `=` exit gap, `.` empty, with a ruler row); `static func legend(r: RoomDef) -> String` (each spawn, feature and exit with its index, position and name); `static func world_image(rooms: Dictionary, dirty: Dictionary, width: int) -> Image`; `static func world_grid(rooms: Dictionary) -> String` (one 3-character cell per screen showing the covering room's id). Tool `preview {room?, scale?, text?}`: content is an `image` item (`mimeType` `image/png`, base64 `data`) then a `text` item; with no `room` it is the world.

- [ ] **Step 1: Write failing tests** on a synthetic 1x1-screen `RoomDef` with one solid, one water and one spawn:
  - `image` is 320x180 at scale 0.5; the pixel at the solid's centre is `C_SOLID`, at open space `C_AIR`, in the water `C_WATER`, at the spawn `C_SPAWN`.
  - `test_a_huge_room_is_clamped`: a 6x6-screen room at scale 1 gives an image whose longest side is at most 2000; scale 0.01 is raised to 0.25.
  - `test_text_map`: 16 columns by 9 rows plus a ruler, with `#` where the solid is and `S` at the spawn; a 4-screen-wide room uses 80 px cells.
  - `test_world`: two adjacent rooms `A1` and `B1` give a grid row `A1 B1`; a dirty room's rectangle edge is outlined in the dirty colour in `world_image`.
  - tool: `preview` returns an image item that `Image.load_png_from_buffer(Marshalls.base64_to_raw(data))` decodes with the expected size, then a text item; no `room` returns the world; unknown room gives `no room 'Z9'`.
- [ ] **Step 2: Run** `tools/run_tests.sh room_preview`. Expected: FAIL.
- [ ] **Step 3: Implement** with `Image.create_empty(w, h, false, Image.FORMAT_RGBA8)` and `fill_rect` (no font exists on a CPU image, so no letters in pictures). Hard ledges are outlined; exits are gaps in the wall tinted by gate; the start is a cross; screen boundaries are a faint grid.
- [ ] **Step 4: Append the smoke call** `preview` for C1 (first content item is `image`). Run `tools/run_tests.sh room_preview` and `python3 tools/mcp/smoke.py`. Expected: exit 0, `smoke ok`.
- [ ] **Step 5: Commit** `git add scripts/editor/mcp tools/mcp tests && git commit -m "feat: the MCP draws a schematic preview and a text map of a room or the world"`

### Task 9: apply_content and apply_room_spec

**Files:**
- Modify: `scripts/editor/room_edit_model.gd`, `scripts/editor/mcp/room_tools.gd`
- Test: `tests/test_room_edit_apply.gd`, `tests/test_room_tools_spec.gd`

**Interfaces:**
- Consumes: `RoomSpec.content_of`, `RoomSpec.content_from_json`.
- Produces: `RoomEditModel.apply_content(room_id: String, content: Dictionary) -> Array` (content in `RoomSpec.content_of` shape; returns `[]` on success or every refusal as `{kind, index, error}`; atomic; one undo step; leaves `exits`, `dressing`, `start`, `cell`, `size` and `area` alone). Tool `apply_room_spec {room, spec}` -> `{ok, counts: {solids, water, spawns, features, decor}}`; shape errors and model errors are combined into one `isError` list.
- Approach (decided): build a scratch `RoomEditModel.new(rooms, creature_ids)`, empty the target's six arrays there, replay `solids` (marking `hard` with `set_field(sel, "hard", true)`), `water`, `spawns`, `features`, `decor` through the public `add_*` calls so every existing check applies, merge the spec's other keys over each appended feature or decor entry (a given feature `id` replaces the generated one), collect errors tagged with kind and index, and only when there are none copy the six arrays into the real room and `_push(before)`.

- [ ] **Step 1: Write failing tests:**
  - `test_every_shipped_room_applies_to_itself`: `apply_content(id, RoomSpec.content_of(r))` returns `[]` and `same_room` holds for all 23, and `undo_depth() == 0` (an unchanged room pushes nothing). If a shipped room is refused, stop and report the room and element: a shipped room breaks an editor rule and the spec must change.
  - `test_replace_is_one_undo_step`: content with one solid leaves exactly that solid, `exits`/`dressing`/`start` unchanged, `undo_depth() == 1`, and `undo` restores the room.
  - `test_atomic_and_complete`: a valid solid plus a too-small water returns `[{kind: "water", index: 0, error: "too small: water is at least 32 px each way"}]` and changes nothing; two bad elements of different kinds give two entries.
  - `test_numbers_are_snapped_and_clipped_like_a_drag`: solid `[1, 1, 31, 30]` becomes the snapped rect; `[-50, -50, 100, 100]` ends up inside `RoomEditModel.bounds(room)`.
  - `test_hard_and_feature_ids`: a thin solid with `hard: true` lands in `hard_ledges`; a thick one with `hard: true` is refused with the model's `set_field` text; a feature given `id: "c1_altar_9"` keeps it.
  - tool: a 200 KB spec (many solids) applies or reports errors and answers; `shape errors` and `model errors` appear together.
- [ ] **Step 2: Run** `tools/run_tests.sh room_edit_apply` and `room_tools_spec`. Expected: FAIL.
- [ ] **Step 3: Implement** `apply_content` and the tool as decided above.
- [ ] **Step 4: Run** `tools/run_tests.sh room_edit`, `room_tools`. Expected: exit 0.
- [ ] **Step 5: Commit** `git add scripts/editor tests && git commit -m "feat: apply_room_spec replaces a room's content atomically in one undo step"`

### Task 10: Placeholder art for new areas

**Files:**
- Create: `data/area_art.json`, `tests/test_area_art.gd`
- Modify: `scripts/world/terrain_art.gd`, `scripts/world/room_builder.gd`, `scripts/game.gd`, `scripts/editor/room_view.gd`, `scripts/world/world_validator.gd`, `scripts/world/room_lint.gd`, `scripts/editor/room_editor.gd`, `scripts/editor/editor_panels.gd`, `scripts/editor/room_edit_model.gd`, `scripts/editor/world_view.gd`

**Interfaces:**
- Produces on `TerrainArt`: `static func art_biome(area: String) -> String` (the area itself when it has art, else its alias from `data/area_art.json`, else `""`); `static func known_area(area: String) -> bool`; `static func areas() -> Array` (`biomes()` plus the alias keys, sorted). `data/area_art.json` is the design's table: forest to grotto, swamp to flooded, village to cave, sacred to cave, cemetery to cave, crypt to deep, volcano to cave, demon to deep, last to deep, serpent to deep.

- [ ] **Step 1: List every site that turns an area into an art key.** Run `grep -rn --include='*.gd' "has_biome\|TerrainArt.ambient\|DressingLib\.\|ids_for_biome\|\.area\b" scripts tools` and check it against the sites above. Each site gets `TerrainArt.art_biome(area)` in front of the art call, except where an area name is data (altar `area`, `WorldSize` rows, `rebirth_choice`), which stays the area. A site found that is not listed here is added to this task, not skipped.
- [ ] **Step 2: Write failing tests** in `tests/test_area_art.gd`:
  - `art_biome("cave") == "cave"`; `art_biome("forest")` equals the JSON's value read directly; `art_biome("nowhere") == ""`; `known_area` agrees.
  - every key of `WorldSize.TARGETS` is a known area; every alias value `TerrainArt.has_biome` and is not itself an alias key; every `TARGETS` key has an entry in `WorldView.AREA_FILL`.
  - `RoomBuilder.build_room` of a `RoomDef` in area `forest` and one in area `grotto` with identical content has the same `get_child_count()`.
  - `new_room_beside` accepts area `forest`; `EditorPanels.areas()` contains `forest`; `WorldValidator` gives no "dressing needs a piece library" for a forest room whose dressing is valid for its aliased biome.
- [ ] **Step 3: Run** `tools/run_tests.sh area_art`. Expected: FAIL.
- [ ] **Step 4: Implement** `art_biome`, `known_area`, `areas` (load the JSON once into a static dictionary) and route every site. `RoomEditModel.new_room_beside` keeps its message `unknown area '%s'` but tests `TerrainArt.known_area`. Add an `AREA_FILL` colour for each of the eight new areas in `world_view.gd`. The MCP `catalog` `areas` section becomes `TerrainArt.areas()`, and Task 4's `areas` assertion in `tests/test_room_tools_read.gd` changes to match.
- [ ] **Step 5: Run the whole suite** `tools/run_tests.sh`. Expected: exit 0 with the previous test count plus the new tests and none failing. If the routing reaches into art generation or shipped-room tests beyond the sites above, stop and report: the spec says this becomes its own plan.
- [ ] **Step 6: Commit** `git add data/area_art.json scripts tests && git commit -m "feat: new areas borrow an existing biome's art until they have their own"`

### Task 11: stamp_prefab

**Files:**
- Modify: `scripts/editor/mcp/room_tools.gd`
- Test: `tests/test_room_tools_stamp.gd`

**Interfaces:**
- Consumes: `Prefabs.library()`, `Prefabs.stamp(room: Dictionary, id: String, origin: Vector2, flip := false, biome := "cave") -> Rect2`, `RoomSpec.content_of`, `RoomEditModel.apply_content`, `TerrainArt.art_biome`.
- Produces tool `stamp_prefab {room, prefab (enum of Prefabs.library() keys), origin: [x, y], flip?}` -> `{ok, bounds: [x, y, w, h], added: {solids, decor}}`. It builds a scratch dict from the room's current `solids` and `decor`, calls `Prefabs.stamp(scratch, prefab, origin, flip, TerrainArt.art_biome(room.area))`, appends only the new elements to `content_of(room)` and applies the result with `apply_content` (one undo step); a refusal becomes `fail` with the joined messages and changes nothing.

- [ ] **Step 1: Write failing tests** on a fresh 1x1 `cave` room made with `new_room_beside` (use the free edge from `test_room_edit_new_room.gd`):
  - `test_stamp_mound`: `origin: [200, 320]` gives `bounds == [200, 224, 160, 96]`, `added.solids == 3`, the room has those 3 solids, and one `undo` removes all three (so `undo_depth()` rose by exactly 1).
  - `test_flip_matches_prefabs_stamp`: flipped solids equal what `Prefabs.stamp` produces with `flip = true`.
  - `test_decor_uses_the_aliased_biome`: stamping `cap_stairs` into a `forest` room gives decor ids starting `grotto_`.
  - `test_unknown_prefab_and_bad_origin`: `prefab: "castle"` and `origin: [1]` give `isError` and change nothing.
- [ ] **Step 2: Run** `tools/run_tests.sh room_tools_stamp`. Expected: FAIL.
- [ ] **Step 3: Implement** the tool as described.
- [ ] **Step 4: Run** `tools/run_tests.sh room_tools`. Expected: exit 0.
- [ ] **Step 5: Commit** `git add scripts/editor/mcp tests && git commit -m "feat: the MCP stamps prefabs into a room in one undo step"`

### Task 12: Agent guide, full verification, review

**Files:**
- Modify: `docs/rooms.md`, `tools/mcp/smoke.py`

- [ ] **Step 1: Add a "Level making with the MCP" section to `docs/rooms.md`:** how it is registered (`.mcp.json`, server `rooms`, launcher `tools/mcp/room_mcp.sh`), the tool list in one table, the working-set rules (nothing on disk until `save`, `save` refuses a changed file, `revert` drops everything), the rules for agents (connect new areas with `new_room` and `add_exit`, do not reshape shipped rooms, run `problems` before `save`, run `tools/run_tests.sh` after `save`, review the `.tres` diff in git), refs shift after `delete`, and the preview is a schematic.
- [ ] **Step 2: Extend `tools/mcp/smoke.py`** with an agent-style session that never saves: `new_room` beside a shipped room (an edge `tests/test_room_edit_new_room.gd` shows is free), `apply_room_spec` with a solid and a spawn, `stamp_prefab`, `preview`, `problems`, `undo`, `state` (checks `dirty` is non-empty before `undo` and the call replies), then `revert`. Expected checks all pass.
- [ ] **Step 3: Run everything:** `tools/run_tests.sh` (expected: exit 0, no failures), `python3 tools/mcp/smoke.py` (expected: `smoke ok`), and `tools/world_size.sh` (expected: still reports 23 rooms; shipped data untouched, `git status` shows no change under `data/rooms`).
- [ ] **Step 4: Manual registration check.** From the repo root and from `.worktrees/room-mcp` run `claude mcp list`. Expected: a `rooms` line. If it reports the server needs approval, report that to the user instead of approving it.
- [ ] **Step 5: Commit** `git add docs/rooms.md tools/mcp && git commit -m "docs: level making with the room MCP"`
- [ ] **Step 6: Review the branch** with `debate:run` (per the project rules), fix what it finds, and report the branch state. Merging and pushing are the user's call.
