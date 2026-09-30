# Room Editor — Design

Status: revised after round 1 of the debate (2026-09-29): scoped to a first shippable phase (P1) with the rest as named
later phases. Answers Sean's note: "I would also like a level design tool so that I can design my own levels with
existing tiles." Research: `docs/research/level-design-reference.md`.

## What I understood

Sean wants to design rooms of his own without writing `tools/build_world.gd` code: pick a biome, draw the ground, ledges
and walls with the tiles the game already has, place creatures, decor and exits, and see and play the result as it will
ship. A room is data (`RoomDef`: pixel size, solid rects, exits with spans, spawns, decor, features, an area that picks the
tileset), turned into `data/rooms/*.tres`; the game's own `RoomBuilder` and `TerrainPainter` draw it. The editor edits that
data and reuses that builder, so what he sees is what ships. He plays with keyboard and mouse or a controller; the editor is
a mouse tool.

**Success for the first phase (P1):** open a room, move a ledge, drop a toad, add an exit, press one key to play the room
from a spot with his unsaved edits, come back to the editor, save; start a brand-new room; and be told what the world
validator objects to before he saves. Rooms that cannot be *completed* are not detected yet (reachability is P3: the
shipped rooms use wall-cling gates and a jump-only check would condemn four of eleven of them); playing the room from the
editor is the completion check, as it is in Mario Maker.

## The phases

| Phase | What it delivers |
|---|---|
| **P1 (this spec)** | Separate editor scene; draw Blocks and Ledges; place creatures, decor and exits; move, delete, undo, redo, pan, fit, grid; New room; Validate (the existing `WorldValidator` strings); save; play from here in the real game with unsaved edits and no writes to the real save. The generator retired |
| P2 (later spec) | Lint rules lifted out of the test suite into one shared `room_lint.gd` with click-to-select results; resize handles; the hard-ledge toggle; feature placement (glow pool, rebirth pool, tablet, switch); prefab stamps; neighbour-exit overlay and paired exits with a multi-room save; jump ruler; play options (grant movement skills, shortcuts open) |
| P3 (later spec) | Reachability from one shared surface model promoted out of the tests, with per-room assumed abilities and `gate` awareness; World view; copy and paste; zoom; autosave; templates |

## Decisions (P1)

| Topic | Decision |
|---|---|
| Host | A **separate scene**, `res://scenes/room_editor.tscn`, started with `godot --path . res://scenes/room_editor.tscn` (a one-line `tools/edit_rooms.sh` wraps it). Not an `EditorPlugin` (RoomBuilder and TerrainPainter are runtime code, and play-testing must be the real game) and not a mode inside a running game (no F9, no `--edit`, no debug-build gate). The editor renders at the project's 640x360 canvas-items stretch: panels are laid out in that space and the room view has **Fit room** and **1:1** with pan, since a three-screen room does not fit at 1:1 |
| Data and source of truth | It edits `RoomDef` and saves `res://data/rooms/<id>.tres` with `ResourceSaver`, the call the generator used. **The generator is retired ("ejected once")**: `data/rooms/*.tres` are the source of truth; `tools/build_world.gd` (its `rooms()` and per-room builders, which only write those files) is deleted, `tools/prefabs.gd` stays as the editor's brush and test library, and the docs that call `build_world.gd` the source of truth (`room_def.gd`, `prefabs.gd` headers, the earlier plans) are corrected. No `authored` flag: there is nothing left to overwrite an edit. Git keeps the old code and the rationale comments |
| Working copy | The model edits a **deep copy** of each room (`RoomDef.duplicate(true)` plus a hand-rolled deep copy of the arrays of Dictionaries, verified by a test that mutates the copy's `spawns[0]["pos"]` and asserts the original is unchanged), never the object `load()` returned (the resource cache would hand the edit to every later `load`). Saved-and-reload tests load with `ResourceLoader.CACHE_MODE_IGNORE` from a temp path |
| Undo | **Snapshots**: the model copies the room's arrays before each discrete operation and on mouse-down of a drag; undo and redo swap snapshots, so a drag is one step and "undo restores the exact previous data" holds by construction. No command classes |
| Tiles | Drawing a **Block** (free rectangle) or a **Ledge** (fixed 12 px tall, drag sets x and width) writes a `Rect2` into `solids`; `RoomBuilder` classifies it by geometry (a solid at most 24 px tall and wider than 24 is a one-way ledge, everything else rock) and `TerrainPainter` paints it in the room's biome. The editor previews the biome's real art; **it does not choose individual tile pieces and nothing per-tile is saved**. The Block tool refuses (bumps to 25 px tall) a rect that would classify as a ledge, and the Ledge tool never produces one wider than 24 that is not a ledge. Existing `hard_ledges` entries are kept in step with their `solids` rect when it moves or is deleted (they are matched by exact `Rect2` equality) |
| Palette | **Creatures**: every `data/creatures` id, drawn in the view as a static marker (the sprite's first frame with the id), never as a live `Enemy`. **Decor**: the decor ids from `Prefabs` for the room's area (`Prefabs.decor_id(id, biome)`), with an optional light colour. **Exits**: drag along an edge; the target room is picked from a list; the matching exit in the neighbour is added by hand in P1 and the Validate list says when it is missing. **Start**: sets the room's `start` (only the first room needs one) |
| Snapping | 4 px, applied to the **drag delta** and to edges the user creates or resizes, never to an untouched origin (shipped rooms have geometry off the 4 px grid, and snapping an origin can turn a 54 px step into a 56 px one) |
| Editing model | Tools: **Select** (click, drag-move, Delete), Ledge, Block, Creature, Decor, Exit, Start. Pan with middle-drag, arrows or a trackpad two-finger pan; a grid overlay; the dragged rect is an overlay and the room is rebuilt on release, not on every mouse motion. Editor shortcuts (undo Cmd/Ctrl+Z, redo Shift+that, save Cmd/Ctrl+S, Delete, F5 play) are read in `_unhandled_key_input` so typing in a room-id field never triggers them; the room view uses `progress = null` in the build context so gates draw closed and a used switch stays selectable |
| Room menu | Open any room; **New room**: id (letters, digits, underscore; unique **case-insensitively**, since the file system is case-insensitive), area, size in screens, cell on the world grid (typed). A new room starts with a floor; it has no exits, so Validate reports it as unreachable until an exit is added. Deleting a room is not offered |
| Validate | A button lists `WorldValidator.validate(working rooms, creature ids)` as it stands: exit spans, matching exit, overlaps, one start, dressing, hard ledges, content. (Rules that only live in the test suite, and click-to-select, are P2.) |
| Save | Explicit (Cmd/Ctrl+S) and dev-only, from a project checkout: it writes every edited room to `<id>.tres.tmp` and renames over `<id>.tres`; an error is shown, the in-memory room is unchanged, and the old file is untouched. No `.bak` and no autosave: git is the backup. Each room is written independently in P1 (a paired exit is P2 and brings an all-or-nothing multi-room save) |
| Play from here | F5 (or the Play button) writes the working room set to `user://editor_play/rooms/` and starts the real game on it: `Game.rooms_dir` (default `res://data/rooms`, read where `Game._ready` loads rooms) and `Game.debug_start` (a room and position; `World.enter_at` already exists) are statics the editor sets before `change_scene_to_file("res://scenes/main.tscn")`. The player stands at the cursor, snapped down to the nearest floor, or at the room's start or first entrance if the cursor is in rock. **The real save is never written**: while `Game.editor_play` is set, `WorldProgress` and the Compendium use an in-memory profile, so nothing reaches `user://profile.json`. Death does not replay the run: the run card's restart goes back to the editor with the working set restored from a static holder. F5 in play returns to the editor. The player is a fresh slime (no skills): a room whose exits are gated needs P2's play options |
| Suite | `tests/test_rooms.gd`'s exact room-id assertion becomes "contains the shipped ids", so a new room does not turn the suite red. Editing a shipped room's spawns can move content-pin tests (the Grotto XP total, creature-supply counts); those tests own their numbers and are updated with the edit |

## Architecture (P1)

- `scripts/editor/room_edit_model.gd` (pure, no nodes): the working rooms (deep copies), the selection, snapping, hit-testing
  (which element is at a point), placement of each element, the `hard_ledges` sync, snapshot undo and redo, the dirty set.
- `scripts/editor/room_editor.gd` and `scenes/room_editor.tscn`: the view (RoomBuilder-rendered room, overlays, markers) and
  the palette, menus, Validate list and status bar; input goes to the model. One script until it passes about 500 lines.
- `scripts/editor/editor_session.gd`: static holder for the working set across the scene change to play and back.
- `scripts/game.gd`: `rooms_dir`, `debug_start`, `editor_play` statics and the return path.
- Changes: `scripts/world/world_progress.gd` (an in-memory profile), `tools/prefabs.gd` unchanged, `tools/build_world.gd` deleted.

## Failure modes and edge cases

- A save fails (disk, an invalid id): the error is shown, memory unchanged, the file untouched.
- The editor crashes or quits with unsaved edits: they are lost (no autosave in P1). Play-from-here writes the scratch copy,
  and the working set survives the scene changes through the static holder.
- The cursor is in rock or mid-air when playing: the player is placed on the nearest floor below, else at the start.
- An exit to a room id that does not exist: Validate reports it and Play refuses (`World._transition` would crash on it).
- A creature id whose data was removed: drawn as a red marker and Validate flags it.
- A decor id with no texture: refused on placement (the builder would crash on it).
- Dying in play: back to the editor, not a replay.
- The click on the Play button reaching the player as a skill press (LMB is `active_1`): play starts on the next scene, and
  the player is created after the mouse button is released; a test clicks the button through the input singleton.

## Testing

Pure units, headless: the model (place, move, resize-by-drag, delete each element; delta snapping and that an untouched
origin is never moved; the Block and Ledge clamps; `hard_ledges` kept in step on move and delete; hit-testing with
overlapping elements), snapshot undo and redo (exact previous data, a drag is one step, redo cleared by a new edit, the
deep-copy aliasing test), save-and-reload equality (temp dir, `CACHE_MODE_IGNORE`, including `hard_ledges`), room-id rules
(case-insensitive uniqueness), Validate on a good room and on rooms with each kind of fault, the suite change. Game statics:
`Game.rooms_dir` and `Game.debug_start` start the world at the given spot in a headless `main.tscn`; a play session leaves
`user://profile.json` byte-identical; the run card's restart returns to the editor and the model is unchanged. Scene smoke:
instantiate the editor scene, draw a ledge and place a toad with synthetic events (positions from the events, not
`get_global_mouse_position`), and check the built room contains the new solid. The shipped rooms all open in the model and
Validate reports nothing new for them. A real windowed screenshot of the editor and one of a room played from it are looked
at before merge.

## Rulings I made

1. **A separate scene, not a mode inside a running game and not a plugin.** Play-testing needs the real `Game`, and a mode
   inside it would share the run, the save and the scene reload on death. Cost if wrong: two scene changes per play.
2. **Eject the generator** rather than an `authored` flag. The `.tres` files already hold the expanded data; there is no other
   source. Cost if wrong: parametric authoring (a loop making 13 ledges) is gone from the tree (it is in git); the
   Prefabs library remains for the editor.
3. **Snapshots, not commands.** The data is a handful of arrays on one resource; a deep-copy snapshot is smaller and has no
   per-command invariants (the hard-ledge coupling). Cost if wrong: memory per step, negligible for eleven rooms.
4. **No reachability in P1.** A jump-only check is wrong for the shipped rooms (wall-cling gates, a 74 px column in the first
   room) and a second model beside the ones in the tests would disagree with the suite. Cost if wrong: an unfinishable room
   is found by playing it, not by a check.
5. **Snap the drag delta, 4 px.** Cost if wrong: one number.
6. **Play in the real game with an in-memory profile.** Cost if wrong: a profile abstraction to maintain; the alternative
   was writing Sean's save from a test session.
7. **No room deletion and no `.bak`.** Git is the safety net.

## Later

See the phase table: lint from the tests, click-to-select, resize handles, hard-ledge toggle, features, prefab stamps, paired
exits and multi-room save, play options, reachability, World view, copy and paste, zoom, autosave, templates, and a JSON
export for CI lint.
