# Room editor MCP: design

An MCP server that lets an agent build and check levels with the room editor's own rules. It runs headless on `data/rooms`, keeps a working set in memory, and writes to disk only when told to.

## What I understood

You want the agent that makes levels (the forest, swamp, village, cathedral, volcano and demon areas from the research guides) to use the same tools you use in the room editor, not to hand-write `.tres` files. Success means:

- An agent can read the world, add rooms beside existing ones, shape them, populate them, see the result, see what is wrong, and save.
- Every rule the editor enforces (grid snap, minimum sizes, exit pairing, overlap checks, lint, the world validator) is enforced for the agent too, with the same error text.
- Nothing is lost by a bad session: edits live in memory, undo works, and nothing reaches disk until `save`.
- We are only adding to the world. The tools can edit shipped rooms (a new area needs a new exit in an old room), but the agent guide says: connect with new exits, do not reshape what exists.

Assumed, not said: the agent works from a checkout or worktree like any other task, so the server must run from whichever checkout the session is in.

## Decisions

| Question | Decision |
|---|---|
| Reach | Headless Godot on `data/rooms` of the current checkout. No live bridge to the editor window, no headless playtest. |
| Server | Godot speaks MCP itself (GDScript), so it reuses `RoomEditModel`, `RoomLint`, `WorldValidator` and `WorldSize` as they are. No second implementation in another language. |
| Tools | Four groups: edit rooms, validate, preview as an image, catalogs / prefabs / size meter. |
| Saving | One in-memory working set per server process. `save` writes dirty rooms. Nothing is written otherwise. |
| New areas | A placeholder art alias, so a room in `forest`, `swamp` and so on can exist and be drawn before its real art does. |

Rejected: a Python MCP server that re-implements the model (two copies of every rule that drift), and a bridge into the running editor (needs the GUI open, one agent at a time, no CI).

## Architecture

```
.mcp.json                          registers server "rooms"
tools/mcp/room_mcp.sh              launcher: cd to repo root, HOME=.tmp/editor-home, exec godot
tools/mcp/room_mcp_boot.gd         thin bootstrap: stdin thread, stdout writer, no project class references
scripts/editor/mcp/
  mcp_protocol.gd                  JSON-RPC 2.0 framing, method routing, error mapping (pure)
  room_tools.gd                    tool table: name, schema, handler (pure over a session)
  room_session.gd                  the working set: RoomEditModel, on-disk stamps, save, revert
  room_preview.gd                  CPU-drawn PNG and text map
  room_spec.gd                     RoomDef <-> JSON spec
data/area_art.json                 area name -> existing biome art (placeholder alias)
```

Each class has one job and is testable without a process: `mcp_protocol` takes a line and returns a line, `room_tools` takes a session and arguments and returns a result, `room_session` wraps the model, `room_preview` takes rooms and returns an `Image`, `room_spec` converts one room.

### Transport and bootstrap (what the spike showed)

- `godot --headless --no-header --path . -s script.gd`. `--no-header` removes the only line the engine itself writes to stdout, so `print(reply)` (one line, flushed by the engine at once) is the protocol channel and everything else the engine says goes to stderr. Not `--quiet`, which silences `print()` too, and not `FileAccess.open("/dev/stdout")`, which works when stdout is a file but fails when it is a pipe or socket (Godot refuses to open anything but a regular file), which is what a client gives us. Project code must not call `print()` while the server runs; the smoke test requires every stdout line to be JSON.
- `OS.read_string_from_stdin(n)` blocks, so it runs on a `Thread`. The main loop drains a queue each frame. On EOF the thread ends and the process quits; the bootstrap calls `wait_to_finish()` so Godot prints no thread warning.
- Autoloads (EventBus and others) do not exist yet when the `-s` script compiles, so a script that names a project class fails to parse. The bootstrap therefore contains no project class names: after the first frame it calls `load("res://scripts/editor/mcp/mcp_protocol.gd")` and hands lines to it.
- Measured on this machine: loading the model about 11 ms, drawing a PNG about 5 ms, `problems()` about 41 ms.
- Framing is newline-delimited JSON (the MCP stdio rule), so a message has no embedded newline. `read_string_from_stdin` takes a buffer size, so the reader keeps reading until it sees a newline and accepts lines up to 4 MiB; a longer line gets a -32600 error and is discarded. A test sends a 200 KB `apply_room_spec` to prove a large line survives.
- The launcher is a bash script, so Windows needs another one; the server itself uses nothing Unix-specific.

### Protocol

JSON-RPC 2.0 with `initialize`, `notifications/initialized`, `ping`, `tools/list` and `tools/call`. Protocol version is echoed from the client when it is one we know, else our newest. Capabilities: `tools` only. Error codes: -32700 parse error, -32600 invalid request, -32601 unknown method, -32602 bad params. A tool that fails returns a normal result with `isError: true` and the model's own error string as text, so the agent reads the same message an editor user sees. Notifications get no response.

## Tools

Coordinates are room-local pixels, y grows down, the model snaps to its 4 px grid. An element is addressed by `ref = {room, kind, index}` with kind in `solid`, `water`, `spawn`, `feature`, `decor`, `exit`. Indexes are positions in the room's arrays, so they shift after a delete: every edit returns the new `ref` and `get_room` lists indexes.

### Read

| Tool | Arguments | Returns |
|---|---|---|
| `list_rooms` | `area?` | `[{id, area, cell, size, counts, dirty}]` |
| `get_room` | `room` | the room spec (below), each element with its `index`, exits with their partner |
| `catalog` | `section?` one of `creatures`, `features`, `decor`, `prefabs`, `perks`, `gates`, `areas`, `limits` | the section, or all. `decor` is per biome, `prefabs` carry width, ceiling and walkable, `limits` carry screen 640x360, wall 20, floor 40, grid 4, door 80, max 6 screens, min solid 4, min water 32 |
| `problems` | `room?` | `{count, items: [{room, text, pick}]}`: `RoomLint.check` plus `WorldValidator`, as the editor's Problems panel shows them |
| `world_size` | none | `WorldSize.measure` totals, the three yardsticks and the per-area `n/target` rows |
| `preview` | `room?`, `scale?` 0.25 to 1 (default 0.5), `text?` | PNG image content plus a legend and a text map. No `room` draws the world map |
| `state` | none | `{rooms, dirty, undo_depth, redo_depth, changed_on_disk}` |

### Edit

Each edit is one undo step and returns `{ok: true, ref}` (`{ok: true, room}` for `new_room`) or an `isError` result with the model's reason.

| Tool | Arguments | Model call |
|---|---|---|
| `new_room` | `beside`, `edge` (left, right, top, bottom), `id`, `area`, `size: [w, h]` | `new_room_beside` |
| `grow_room` | `room`, `side` (left, right, top), `screens?` | `grow_room` |
| `add_solid` | `room`, `a: [x, y]`, `b: [x, y]` | `add_solid` |
| `add_water` | `room`, `a`, `b` | `add_water` |
| `add_spawn` | `room`, `creature`, `pos` | `add_spawn` |
| `add_feature` | `room`, `kind` (glow_pool, tablet, switch, altar), `pos` | `add_feature` |
| `add_decor` | `room`, `piece`, `pos` | `add_decor` |
| `add_exit` | `room`, `edge`, `from`, `to`, `gate?`, `shortcut?` | `add_exit`: also creates the partner exit across |
| `set_field` | `ref`, `key`, `value` | `set_field` (exit shortcut and gate, tablet title, text and hint, switch shortcut, altar perk, solid and water x y w h, solid hard) |
| `move` | `ref`, `delta: [dx, dy]` | `begin_move`, `move_to`, `end_move` |
| `delete` | `ref` | `select` then `delete_selection` |
| `stamp_prefab` | `room`, `prefab`, `origin`, `flip?` | `Prefabs.stamp` into the room's content, applied with `apply_content` (one undo step) |
| `undo`, `redo` | none | `undo`, `redo`; returns the new depths |

### Bulk

`apply_room_spec {room, spec}` replaces one room's `solids`, `hard_ledges`, `water`, `spawns`, `features` and `decor` in a single undo step. Dressing, exits, `start`, `cell`, `size` and `area` are not touched (exits need the partner room, so they stay `add_exit` in v1). It is all or nothing: if any element is refused, nothing is applied and the result lists every refusal as `{kind, index, error}` so the agent fixes the whole spec in one pass.

This needs one new public method, `RoomEditModel.apply_content(room_id, content: Dictionary) -> Array`, which returns the per-element errors (empty on success). It runs each element through the same checks as the single-element adds (snap, minimum size, inside the room, not in rock for spawns, feature base surface), on a scratch copy, and swaps it in with one `_push` only when the list is empty.

### Persist

| Tool | Arguments | Behaviour |
|---|---|---|
| `save` | `rooms?` (default: every dirty room), `force?` | `save_dirty("res://data/rooms")`. Refuses a room whose file changed on disk since this session loaded or last wrote it, unless `force`. Returns `{saved, removed, errors, problems}`; problems are for the saved rooms and do not block |
| `revert` | none | Rebuilds the whole working set from disk. Unsaved edits and the undo history are dropped (history entries can span rooms, so a partial revert is not offered) |

## Room spec

One JSON shape in both directions (`get_room` out, `apply_room_spec` in):

```json
{
  "id": "F1", "area": "forest", "cell": [4, 0], "size": [2, 1], "start": null,
  "solids":   [{"rect": [x, y, w, h], "hard": false}],
  "water":    [[x, y, w, h]],
  "spawns":   [{"creature": "goblin", "pos": [x, y]}],
  "features": [{"kind": "altar", "id": "f1_altar_1", "pos": [x, y], "perk": "", "title": "", "text": "", "hint": "", "shortcut": ""}],
  "decor":    [{"piece": "rubble", "pos": [x, y]}],
  "exits":    [{"edge": "right", "from": 200, "to": 280, "room": "F2", "gate": "", "shortcut": ""}]
}
```

`get_room` returns the full spec plus each element's `index`. `apply_room_spec` reads only the six content keys above and ignores the rest. Rules for the conversion:

- A feature keeps its `id` when the spec gives one (a switch's shortcut and an altar's id are referenced elsewhere) and gets a generated one (`<room>_<kind>_<n>`) when it does not. An altar's `area` defaults to the room's area.
- A decor entry is `piece` and `pos`; its other keys (`anchor`, `light` as `[r, g, b, a]`, `flip`) pass through under the same names, and `DecorLib.entry` fills `anchor` and `light` only when the spec leaves them out.
- Vectors and rects are arrays of numbers, `start` is `null` when the room has none (`RoomDef.NO_START`), and a spawn's `creature` is the stored `id`.

`room_spec.gd` owns both conversions, and a test proves the round trip changes nothing on all 23 shipped rooms.

## Session, saving and safety

- The session loads `World.load_rooms("res://data/rooms")` and takes the creature ids from `DefLoader.load_dir("res://data/creatures")` (the model's own tests do the same), so it does not depend on the `SkillRules` autoload.
- At load, the session records each room file's SHA-256 (not its modified time, which has one-second resolution). `save` recomputes it before writing and records the new hash after. A new room whose file has appeared on disk counts as changed. This is the guard against two agents, or an agent and the editor window, writing the same room.
- `save` writes only under `res://data/rooms/`. The tool takes no path.
- One server process is one working set. Two agents get two processes with separate sets; the stale-file check keeps them from overwriting each other.
- The launcher points `HOME` at `.tmp/editor-home`, as `tools/edit_rooms.sh` does, so `user://` is a throwaway and the real save is never touched. Godot's own log rotation also needs a writable HOME in the sandbox.
- No tool runs shell commands, reads outside the project or touches git. Committing the result is the agent's normal git work, reviewed as a diff of `.tres` files.

## Placeholder art for new areas

`RoomEditModel.new_room_beside` refuses any area without terrain art (`TerrainArt.has_biome`), and only cave, deep, flooded and grotto have art. New areas would be unusable. The fix is an alias, not new art:

- `data/area_art.json` maps an area name to the existing biome whose art it borrows, for example `{"forest": "grotto", "swamp": "flooded", "village": "cave", "sacred": "cave", "cemetery": "cave", "crypt": "deep", "volcano": "cave", "demon": "deep", "last": "deep", "serpent": "deep"}`. The values are placeholders you will change when the real art lands; the file is data, not code.
- One function, `TerrainArt.art_biome(area) -> String`, returns the aliased biome (or the area itself for the four that have art, or "" for an unknown area). `TerrainArt.known_area(area)` is `art_biome(area) != ""`.
- Every place that turns a room's area into an art key goes through `art_biome`. The call sites found so far: `RoomBuilder` (the `TerrainArt.has_biome(def.area)` branch and the `TerrainLayers`, `TerrainMotes`, `SetDressing` and `TerrainPainter` calls it makes), `TerrainArt.ambient` (called from `game.gd` and `room_view.gd`), `DressingLib.has_biome/has_piece/size` (from `world_validator.gd` and `room_lint.gd`), `DecorLib.ids_for_biome` (from `room_editor.gd`), and `RoomEditModel.new_room_beside`. The plan's first task greps for every use of `.area` and `has_biome`, lists them, and routes each. If the list reaches beyond these into art generation or the shipped-room tests, it becomes its own plan and the MCP ships with the four existing areas first.
- `world_view.gd`'s `AREA_FILL` only has colours for four areas. It gets one entry per aliased area so the world map and the size meter can tell them apart.
- A test asserts that every area in `WorldSize.TARGETS` (cave, grotto, flooded, deep, forest, swamp, village, sacred, volcano, demon, last, serpent) has an `art_biome`, so a new area cannot be added to the targets without a place to draw it.

## Preview

The headless renderer has no texture to read back, so previews are drawn on the CPU into an `Image` and encoded as PNG. They are schematics, not the game's art.

- Room preview: one pixel is `1 / scale` world pixels (default 0.5, so a screen is 320x180). `scale` is clamped so the longest side is at most 2000 px, which keeps a 6x6-screen room readable. Solids dark, hard ledges outlined, water blue, spawns red squares, features gold squares, decor green ticks, exits as gaps in the wall tinted by gate, the start as a cross, screen boundaries as a faint grid. A CPU `Image` has no font, so there are no letters in the picture: a text legend lists each spawn, feature and exit with its index, position and name.
- Text map: one character per 40 px cell, `#` solid, `~` water, `S` spawn, `F` feature, `d` decor, `=` exit gap, `.` empty, with a ruler. Cells become 80 px when the room is over 3 screens wide so the map stays under 100 columns.
- World preview: `WorldView.layout` places each room's rectangle (the same function the editor uses), filled by area colour, dirty rooms outlined. Ids cannot be drawn, so the text half is a grid with one cell per screen showing the id of the room that covers it, plus the size meter's totals.

## Failure modes

| Case | Result |
|---|---|
| Unknown tool or bad arguments | `isError` with the schema's reason |
| Unknown room id | `isError`: "no room 'X'" |
| Model refuses an edit | `isError` with the model's string, state unchanged |
| `apply_room_spec` has refusals | `isError` listing every `{kind, index, error}`, nothing applied |
| File changed on disk before `save` | that room is in `errors` with "changed on disk since loaded", others still save |
| Save fails for one room | that room stays dirty, the others are written (the model already works this way) |
| A handler hits a script error | GDScript has no exceptions: the engine logs the error to stderr, the handler returns null, and the protocol answers that call with a JSON-RPC internal error (-32603) and stays up |
| stdin closes | the process exits 0 |
| Process killed | the working set is lost by design; nothing was on disk |

## Testing

GUT, run through `tools/run_tests.sh`:

- `test_mcp_protocol.gd`: initialize, ping, `tools/list` schema shape, unknown method, parse error, notification with no response, a 200 KB line.
- `test_room_tools.gd`: every tool on a copy of the shipped rooms, saving into a temp directory (never `res://data/rooms`): each edit's success and one refusal, undo and redo, `problems` equal to the model's, `catalog` sections non-empty, `stamp_prefab` is one undo step.
- `test_room_spec.gd`: round trip on all shipped rooms, `apply_content` atomicity (one bad element changes nothing), one undo step.
- `test_room_preview.gd`: PNG decodes to the expected size, a solid's pixels are the solid colour, the text map has the expected rows.
- `test_room_session.gd`: stale-file refusal, `force`, `revert`, `save` writes only dirty rooms.
- `test_area_art.gd`: the alias table and every `WorldSize.TARGETS` area resolve.
- `tools/mcp/smoke.py` (Python, because it needs a JSON client): starts the real launcher, sends `initialize`, `tools/list`, `list_rooms`, `get_room C1`, `preview C1` and `problems`, and checks the replies parse and carry the right fields. It also checks that `.mcp.json` parses and names a launcher that exists and is executable. The plan has one manual step: `claude mcp list` from the repo root and from a worktree, which settles how the relative launcher path resolves.

## Milestones

Each one leaves the full suite green and is committed on its own.

1. Protocol, bootstrap, launcher, `.mcp.json`, session, read tools (`list_rooms`, `get_room`, `catalog`, `problems`, `world_size`, `state`), smoke script.
2. Edit tools, `save`, `revert`, undo and redo, the stale-file guard.
3. Preview (room, text map, world).
4. `apply_room_spec` with `RoomEditModel.apply_content`, `stamp_prefab`, the placeholder alias (or its own plan if the call-site list is large), and a short "level making with the MCP" section in `docs/rooms.md` for agents.

## Rulings

- Informational, not a gate: `save` reports problems and never blocks on them, as the editor does.
- Exits are not part of `apply_room_spec` in v1, because an exit needs its partner and a bulk replace would have to rewrite the neighbour. `add_exit` stays one call per door.
- The server edits shipped rooms when asked. A guard that makes them read-only would stop the one legitimate edit (a new exit in an old room), and git is the review.
- Refs are positional and shift on delete; stable element ids would mean changing `RoomDef`, which the game and every `.tres` file read.
- The alias table is data in `data/area_art.json`, not code, so changing a placeholder is a one-line edit.

## Not here, later

- A live bridge into the editor window.
- A headless playtest or reachability model. When one exists it plugs into `problems`.
- Dressing (background scenery) tools and a rewritten-exits bulk spec.
- Real art for the new biomes, which retires the alias entries one by one.
- A Windows launcher.
