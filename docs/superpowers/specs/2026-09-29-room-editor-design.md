# Room Editor — Design

Status: revised after round 2 of the debate (2026-09-29): scoped to a first shippable phase (P1) with the rest as named
later phases. Answers Sean's note: "I would also like a level design tool so that I can design my own levels with
existing tiles." Research: `docs/research/level-design-reference.md`.

## What I understood

Sean wants to design rooms of his own without writing `tools/build_world.gd` code: pick a biome, draw the ground, ledges
and walls with the tiles the game already has, place creatures and exits, and see and play the result as it will ship. A
room is data (`RoomDef`: pixel size, solid rects, exits with spans, spawns, decor, features, an area that picks the
tileset), turned into `data/rooms/*.tres`; the game's own `RoomBuilder` and `TerrainPainter` draw it. The editor edits that
data and reuses that builder, so what he sees is what ships. He plays with keyboard and mouse or a controller; the editor is
a mouse tool.

**Success for the first phase (P1):** open a room, move a ledge, drop a toad, add an exit (its partner in the neighbour is
added with it), press one key to play the room from a spot with his unsaved edits, come back to the editor, save; start a
brand-new room beside an existing one; and be told what the world validator objects to before he saves. Rooms that cannot
be *completed* are not detected (physical reachability is P3: the shipped rooms use wall-cling gates and a jump-only check
would condemn four of eleven of them); playing the room from the editor is the completion check, as it is in Mario Maker.

## The phases

| Phase | What it delivers |
|---|---|
| **P1 (this spec)** | Separate editor scene; draw Solids (a live label says ledge or rock); place creatures; add exits (paired); New room beside a room; move, delete, undo, redo, pan, fit, grid; Validate; save; play from here in the real game with unsaved edits, sandboxed from the real save. The generator retired |
| P2 (later spec) | Lint rules lifted out of the test suite into one shared `room_lint.gd` with click-to-select results; resize handles; the hard-ledge toggle and its sync; a decor palette and a Start tool; feature placement (glow pool, rebirth pool, tablet, switch); prefab stamps; jump ruler; play options (grant movement skills, shortcuts open); editing `dressing` |
| P3 (later spec) | Physical reachability from one shared surface model promoted out of the tests, with per-room assumed abilities and `gate` awareness; World view; copy and paste; zoom; autosave; templates |

## Decisions (P1)

| Topic | Decision |
|---|---|
| Host | A **separate scene**, `res://scenes/room_editor.tscn`, started by `tools/edit_rooms.sh`: `env HOME="$PWD/.tmp/editor-home" godot --path . res://scenes/room_editor.tscn`. Not an `EditorPlugin` (RoomBuilder and TerrainPainter are runtime code, and play-testing must be the real game) and not a mode inside a running game. The room is drawn in the root viewport through a `Camera2D` (the project's 640x360 canvas-items stretch; **Fit room** and **1:1**, pan by middle-drag, arrows or a trackpad two-finger pan); the palette, menus, Validate list and status bar are a `CanvasLayer` laid out in 640x360; a per-area `CanvasModulate` matches the game's lighting. A click maps through the canvas transform and the room's world position |
| Real save | **Sandboxed by launching, with no production code**: the script sets `HOME` to `.tmp/editor-home`, so `user://` (the profile, the bestiary, the audio settings, every writer of `user://profile.json`) is a throwaway directory, as the test runner already does. Play and Save-independent state never touch the real save. The editor refuses **Play** with a message when `user://` is not inside `.tmp/editor-home` (launched from the Godot editor or without the script). The dev profile persists between plays; deleting `.tmp/editor-home` resets it |
| Data and source of truth | It edits `RoomDef` and saves `res://data/rooms/<id>.tres` with `ResourceSaver`, the call the generator used. **The generator is retired ("ejected once")**: `data/rooms/*.tres` are the source of truth; `tools/build_world.gd` (which only writes those rooms) is deleted, `tools/prefabs.gd` stays as a brush and test library, and the docs that call `build_world.gd` the source of truth are corrected (`room_def.gd` and `prefabs.gd` headers, a short `docs/rooms.md` that also keeps the load-bearing rationale comments the `.tres` cannot carry, such as G3's hanging chimney wall and G1's ledge-chain note); the older dated plans stay as historical records with that note. No `authored` flag: nothing is left to overwrite an edit |
| Working copy | The model edits **deep copies** of the rooms (`RoomDef.duplicate(true)`, or a hand-rolled deep copy if the test shows nested Dictionaries are shared), never the objects `load()` returned (the resource cache would hand the edit to every later `load`). The aliasing test mutates a nested value (`features[i]["kit"]["affinity"]`) on the copy and asserts the original is unchanged. Save-and-reload tests load with `ResourceLoader.CACHE_MODE_IGNORE` |
| Undo | **Snapshots of the whole working set** (eleven small resources, a few KB each): taken before each discrete operation and on the first motion of a drag (a click without a drag pushes nothing; a snapshot equal to the previous one is dropped); undo and redo swap them, so a drag, or an exit that changes two rooms, is one step and "undo restores the exact previous data" holds by construction. No command classes |
| Solids | One **Solid** tool: drag a rectangle; a live label says **one-way ledge** (at most 24 px tall and wider than 24: `RoomBuilder.is_one_way`) or **rock**, so nothing is clamped or hidden. It writes a `Rect2` into `solids`; `RoomBuilder` classifies it and `TerrainPainter` paints it in the room's biome. The editor previews the biome's real art; **it does not choose individual tile pieces and nothing per-tile is saved**. (`hard_ledges` are kept as they are in P1: no shipped room has one and there is no way to create one until P2's toggle) |
| Creatures | The palette lists every `data/creatures` id. A placed creature is a static marker: the sprite the game would use (the sheet's first frame if `SpriteSheet.available`, else `Art`, as `Enemy` looks it up), else a labelled box; never a live `Enemy`. The tool refuses a point inside rock; an id whose data was removed draws as a red marker and Validate flags it |
| Exits | Drag along an edge; the target is picked from the rooms that touch that edge. **The partner exit is written in the neighbour in the same operation** (opposite edge, the span shifted by the difference of the rooms' origins, same `gate` and `shortcut`), and deleting one deletes both; the validator compares world spans exactly, so an unpaired exit is a defect the editor should not let him make. The span rules of `WorldValidator` (inside 20..size-20) refuse a drag |
| Snapping | 4 px, applied to the **drag delta** and to edges the user creates, never to an untouched origin (shipped rooms have geometry off the 4 px grid, and snapping an origin can turn a 54 px step into a 56 px one) |
| Editing | Tools: **Select** (click with a minimum pick radius in screen px, drag-move, Delete or Backspace), Solid, Creature, Exit. The dragged rect is an overlay and the room is rebuilt on release. Editor shortcuts (undo Cmd/Ctrl+Z, redo Shift+that, save Cmd/Ctrl+S, F5 play) are read in `_unhandled_key_input`, so typing in a room-id field never triggers them. The room view builds with `progress = null`, so gates draw closed and a used switch stays selectable. Existing decor and features keep drawing and are not editable in P1 |
| New room | **Beside** an existing room on an edge: id (letters, digits, underscore; unique **case-insensitively**, since the file system is case-insensitive), area, size in screens; the cell is computed from that room's `world_rect()` and refused if it overlaps another (the validator reports overlaps). The new room is created with a floor and with the paired exit toward its neighbour, so it is connected to the world at once. Deleting a room is not offered |
| Validate | A button lists `WorldValidator.validate(working rooms, creature ids)` as it stands: exit spans, matching exit, overlaps, one start, dressing, hard ledges, content, rebirth pools, and a new **graph reachability** rule (every room reachable from the start room by following exits, the rule `tests/test_rooms.gd` already asserts, moved into the validator so the suite and the editor share it). A room with no way in is reported. Rules that live only in the suite's bodies (a spawn in rock, the ledge jump budget, a start off the floor, a solid outside the room) are P2's `room_lint`; until then **Validate clean is not suite green** |
| Save | Explicit (Cmd/Ctrl+S) and dev-only, from a project checkout: it writes each edited room straight to `res://data/rooms/<id>.tres` with `ResourceSaver` and lists any error, leaving that room dirty; git is the backup (no `.bak`, no autosave). Each room is saved independently; a paired exit dirties two rooms and both are saved by Save |
| Play from here | F5 (or the Play button) starts the real game on the working set: the editor sets `Game.play_request = {rooms, room, pos}` (a static, **consumed and cleared** by `Game._ready`, and reset by any test that sets it) and calls `change_scene_to_file("res://scenes/main.tscn")`. `Game._ready`, when a request is present, uses the request's rooms instead of loading the directory, enters at `room`/`pos` through `World.enter_at` (the floor point minus `BodyConfig.BOTTOM`), binds `Run` **without progress** so a death emits `restart_requested` at once and never opens the reincarnation menu, and uses a fresh `WorldProgress.new()` (no profile) so gates start closed as the editor view draws them. The player stands at the cursor snapped down to the nearest floor; in rock or with no floor below, Play refuses ("click open floor"). `Game._restart`, in a request session, runs `_prepare_restart()` and `Audio.reset()` and changes scene back to the editor instead of reloading; the working set comes back from a static on `RoomEditor` (`RoomEditor.resume`, a real scene swap in the test). F5 in play returns to the editor: it is read by a small child node with `PROCESS_MODE_ALWAYS` (the skill screen pauses the tree), ignores key repeats, and is ignored while the death card shows. The player is a fresh slime (no skills); evolution offers follow the saved world (`FormOffers.default_supply` reads `res://data/rooms`); a room whose exits are gated needs P2's play options |
| Suite | **Content pins iterate the shipped ids** (`tests/support` gains the list C1-C6, G1-G5: the exact id list becomes "contains the shipped ids", and the dressing, pacing, food and Grotto-size pins use the list) so a new or edited room does not turn them red; **rule tests keep running on every room** (spawn in rock, ledge reach, exits, one start), and graph reachability is now the validator's. A P1 edit can therefore still turn a rule test red until P2's `room_lint`, and editing a shipped room's spawns moves the pinned numbers: the author of the edit updates them. `dressing` is not edited by the editor; a new cave room has none and the dressing pins do not apply to it |

## Architecture (P1)

- `scripts/editor/room_edit_model.gd` (pure, no nodes): the working rooms (deep copies), the selection, snapping, hit-testing,
  placement of each element (solid, creature, exit with its partner, new room), whole-set snapshot undo and redo, the dirty
  set, the room-id rules. The one place that knows the data shape.
- `scripts/editor/room_editor.gd` and `scenes/room_editor.tscn`: the view (RoomBuilder-rendered room through a camera,
  overlays, markers), the palette, menus, Validate list and status bar; input goes to the model. `RoomEditor.resume` holds the
  working set across the scene swap. One script until it passes about 500 lines.
- `scripts/game.gd`: `play_request`, the editor-play branches in `_ready` and `_restart`, and a child node that returns on F5.
- `scripts/world/world_validator.gd`: the graph reachability rule; `tests/test_rooms.gd` calls it.
- `tools/edit_rooms.sh`; `docs/rooms.md`; `tools/build_world.gd` deleted.

## Failure modes and edge cases

- A save fails (disk, an invalid id): the error is shown, memory unchanged, the room stays dirty.
- The editor quits with unsaved edits: they are lost (no autosave in P1). The working set survives the scene changes to play
  and back.
- A creature id whose data was removed: a red marker, and Validate flags it. A decor id with no texture cannot be placed in P1
  (no palette); existing decor is untouched.
- An exit to a room id that does not exist: Validate reports it and Play refuses (`World._transition` would crash on it).
- Dying in play: back to the editor, not a replay, without a menu even when the dev profile has attuned pools.
- F5 with the skill screen open: it still returns (the listener runs while paused), and the tree is unpaused on the way out.
- The editor launched without the script: Play refuses so the real save cannot be written; editing and saving rooms work.
- Two exits on the same span, or an exit drag outside the allowed span: refused at drag time.
- A new cave room fails the dressing tests if they were run on it: they iterate the shipped ids only.
- Play does not use the edited rooms for evolution offers (`FormOffers` reads the saved directory).

## Testing

Pure units, headless: the model (place a solid, a creature, an exit with its partner, a new room beside another; move and
delete each; drag-to-create; delta snapping and that an untouched origin is never moved; the live ledge/rock label matches
`RoomBuilder.is_one_way`; hit-testing with overlapping elements and the pick radius), whole-set snapshot undo and redo (exact
previous data, a drag is one step, a click pushes none, an exit is one step across two rooms, redo cleared by a new edit, the
nested-value aliasing test), save-and-reload equality (temp directory and one save to a `res://` temp path, `CACHE_MODE_IGNORE`,
including `features`, `dressing` and the nested `kit`), room-id rules (case-insensitive uniqueness), the validator's graph
rule (a room with no way in is reported; the eleven shipped rooms validate clean), every shipped room opens in the model. The
suite change (shipped-id lists, `test_rooms.gd` calling the validator). Game seam, headless `main.tscn`: a `play_request`
starts the world at the spot on the edited geometry and is cleared; a death with two attuned pools in the dev profile returns
to the editor without the menu and the model is unchanged (real `change_scene_to_file`, with the current scene freed in the
test); F5 while paused returns and unpauses; F5 during the death card does nothing; a play session writes nothing to a fresh
profile path (the profile's `save()` calls counted). Scene smoke: instantiate the editor scene, draw a solid and place a toad
with synthetic events pushed through the viewport (positions from the events), and check the built room contains the new solid.
The Play refusal outside the sandbox and in rock. A real windowed screenshot of the editor and one of a room played from it
are looked at before merge.

## Rulings I made

1. **A separate scene, not a mode inside a running game and not a plugin.** Play-testing needs the real `Game`, and a mode
   inside it would share the run, the save and the scene reload on death. Cost if wrong: two scene swaps per play.
2. **The real save is protected by how the editor is launched (a `HOME` sandbox), not by profile plumbing.** It covers every
   writer (the profile, the bestiary, audio settings) with no production code. Cost if wrong: launching the editor another way
   disables Play (a message says why); the dev profile persists between plays.
3. **Eject the generator** rather than an `authored` flag. The `.tres` files already hold the expanded data. Cost if wrong:
   parametric authoring (a loop making 13 ledges) is gone from the tree (git has it); the Prefabs library remains.
4. **Snapshots of the whole set, not commands.** Cost if wrong: memory per step, negligible for eleven rooms.
5. **No physical reachability in P1**; the graph rule is in. A jump-only check is wrong for the shipped rooms and a second
   model beside the tests' would disagree with the suite. Cost if wrong: an unfinishable room is found by playing it.
6. **Snap the drag delta, 4 px; no clamps, a live label.** Cost if wrong: one number.
7. **Play hands the rooms over in memory, not through a scratch directory.** No stale files, no cache concern. Cost if wrong:
   the disk round trip is covered by the save test only.
8. **Paired exits in P1.** The validator's exact span match makes an unpaired exit a defect he cannot fix without a numeric
   readout. Cost if wrong: a fifteen-line function.
9. **No Start tool, decor palette, `hard_ledges` sync or resize in P1**: not in the success paragraph.
10. **No room deletion, no `.bak`, no autosave.** Git is the safety net.

## Later

See the phase table: lint from the tests with click-to-select, resize handles, hard-ledge toggle and sync, decor palette,
Start tool, features, prefab stamps, play options, dressing, physical reachability, World view, copy and paste, zoom,
autosave, templates, and a JSON export for CI lint.
