# Room Editor — Design

Status: draft for debate (2026-09-29). Answers Sean's note: "I would also like a level design tool so that I can design my
own levels with existing tiles." Research behind the choices: `docs/research/level-design-reference.md` (level design
principles, editor feature survey, validation, MVP, data format, in-game vs plugin).

## What I understood

Sean wants to design rooms of his own without writing `tools/build_world.gd` code: pick a biome, draw the ground, ledges
and walls with the tiles the game already has, place creatures, decor, pools and exits, and see and play the result as it
will ship. Today a room is data (`RoomDef`: pixel size, solid rects, exits with spans, spawns, decor, features, an area that
picks the tileset), authored in code and turned into `data/rooms/*.tres`; the game's own `RoomBuilder` and
`TerrainPainter` draw it. So the editor edits that data and reuses that builder.

Success: Sean can open a room, move a ledge, drop a toad, add an exit, press one key to play the room from that spot with
his unsaved edits, and press save; and he can start a brand-new room in the world. Rooms that cannot be completed, or that
have an exit that does not meet its neighbour, are flagged before he saves.

## Decisions

| Topic | Decision |
|---|---|
| Where it runs | **In the game, as a mode**, not an `EditorPlugin`. Started with `godot --path . -- --edit` (optionally `--edit=<room id>`) and toggled in a running game with F9 (debug builds only). It reuses `World`, `RoomBuilder`, `TerrainPainter` and the real `Player`, so what he sees is what ships and "play from here" is one process: no `@tool`, no editor restart, no launch arguments to pass across a process boundary. The research favoured a plugin for its free inspector and undo; here the palette is a set of game tiles and creatures, which is custom UI either way, and instant play-testing decides it |
| What it edits | `RoomDef` in place, in memory, then saves to `res://data/rooms/<id>.tres` with `ResourceSaver` (the same call `tools/build_world.gd` makes). A `.bak` of the previous file is written first. The game already loads that directory, so a saved room is live on the next run. No new format |
| Source of truth | New `RoomDef.authored: bool`. The editor sets it on the first save of a room. `tools/build_world.gd` refuses to overwrite a `.tres` whose `authored` is true (it prints which rooms it skipped), so re-running the generator can never erase hand edits. The code-built definition of an authored room becomes a historical seed; `docs/` says so. New rooms have no code seed at all |
| Tiles | The palette is the biome's own art: for the room's `area` it lists the terrain pieces the painter uses (a **Block** shows the biome's fill and cap tiles, a **Ledge** its `ledge_l/m/r`), so a Cave room and a Grotto room offer their own looks. Drawing a Block or a Ledge writes a `Rect2` into `solids`; the painter draws it. A ledge is one-way by default; a **Hard ledge** toggle writes it into `hard_ledges` too (see the one-way spec). Nothing new is drawn by the editor |
| Other palette groups | **Creatures** (every `data/creatures` id), **Decor** (the sprites `RoomBuilder.build_decor` accepts, with the optional light colour), **Features** (glow pool, rebirth pool, tablet, switch, with their fields), **Exits** (drag along an edge), **Prefabs** (`stamp` pieces, `ledge_chain`, `shaft_climb`, expanded to plain rects on placement, no live link) |
| Snapping | Positions and sizes snap to a grid the user picks (1, 4, 8, 16, 20 px; default 4) since existing rooms use rects like (260, 266, 120, 12). Thin rects are clamped to the ledge rule (height at most 24) or flagged, so a 25-32 px accident is visible |
| Editing model | Every change is an `EditCommand` (`do`, `undo`, a label, a merge key for drags) on a `CommandStack`; undo and redo are unlimited within a session. The view has pan (middle drag or space-drag), zoom (wheel, 25-400 %), and a selection with move, resize handles, delete, copy and paste |
| Play from here | F5 (or the Play button) builds the current in-memory `RoomDef` set into a real `World`, puts the player at the cursor (or the room's start) and hides the editor; Esc returns to the editor with the same view. Unsaved edits are played because the world is built from the objects in memory. The player has every skill the room's checks allow: a picker offers "none", "as the slime is at this point", or a checklist of skills, so an ability-gated room can be tried |
| Checks | A panel lists results and clicking one selects the offender. Layer 1 (lint, on every edit): a spawn or start inside a solid or floating over a pit, a rect under 8 px or 25-32 px thick, a solid overlapping an exit gap, an exit span outside its edge, a neighbour without a matching exit (the existing `WorldValidator` rules, reused as functions). Layer 2 (on a button, and before save): **reachability** by a grid flood fill with a jump budget from the live player constants (speed 140, jump 330, gravity 900: apex 60.5 px, flat range about 103 px), giving "each exit and each spawn is reachable from the entrance" and the region reached, drawn over the room. Wall cling, thread swing and water-jet dash extend the graph one ability at a time in later steps, off by default until each has its own test |
| Overlays | Grid, collision-only view (hides the paint), a jump-arc ruler from the cursor (the metrics above), the safe-clearance ring around entrances and pools |
| World | A **Room** menu: open any room, or **New room** (id, area, size in screens, cell on the world grid). A **World** view draws every room's rect on the grid with exits, and neighbours' exits are drawn on the edge of the room being edited so alignment is visible; adding an exit on an edge that touches a neighbour offers to add the matching exit in that neighbour too (an undoable pair). Deleting a room is not offered |
| Scope now | Everything above **except** the multi-ability reachability extensions, drag-to-arrange rooms in the World view (cell is typed), room templates and the clear-stamp (all "Later") |

## Architecture

Small units with one job, tested without a window where they are pure:

- `scripts/editor/room_edit_model.gd` (pure, no nodes): the working `RoomDef`, the selection, snapping, hit-testing
  (which element is at a point, which handle), the palette-to-data mapping (place block/ledge/spawn/decor/feature/exit),
  and the commands. The one place that knows the data shape.
- `scripts/editor/edit_command.gd`, `command_stack.gd`: `do`/`undo`/`merge`; the undo/redo stack.
- `scripts/editor/room_checks.gd` (pure): lint and reachability over a `RoomDef` and physics constants; returns
  `[{severity, message, at: Rect2 or Vector2, code}]`. Reads `Player` constants, never copies them.
- `scripts/editor/room_view.gd` (Node2D): renders the model through the real `RoomBuilder`/`TerrainPainter`, draws
  overlays and handles, turns mouse and key input into model calls. Rebuilds only the dirty room.
- `scripts/editor/editor_ui.gd` (Control): palette, property popups, check list, menus, status bar; talks to the model only.
- `scripts/editor/editor_mode.gd`: entry (`--edit`, F9), swaps between the editor and a play session, owns save/`.bak`.
- `scripts/world/room_def.gd`: `authored`. `tools/build_world.gd`: skips authored files.

## Failure modes and edge cases

- A save fails (disk, a room id that is not a valid file name): the error is shown, the in-memory room is unchanged, and the
  `.bak` is kept. Room ids are limited to letters, digits and underscore, unique, and not `..`-shaped.
- A crash or quit with unsaved edits: an autosave to `user://editor/<id>.autosave.tres` every 30 s and on play, offered on
  the next open. It never overwrites `res://`.
- The generator would overwrite: it skips `authored` files and reports them, so a re-run is safe.
- Editing a room the world graph depends on (its exits are another room's exits): a changed exit span shows the neighbour as
  "no matching exit" at once; saving is allowed (a work in progress) but the check panel says the world is broken.
- Play from here inside a room with a closed shortcut gate: the gate state comes from a fresh progress object, as on a new
  run; a "shortcuts open" toggle is in the play options.
- A creature id whose data was removed: the spawn is drawn as a red placeholder and the check panel flags it.
- Undo across a save: allowed; the file changes only on the next save.
- Zoomed-out large rooms (three screens tall): the view culls to the visible rect; the paint is rebuilt on change only.
- Sean edits an existing shipped room and the game's tests read it: the suite's room tests are the safety net; the check
  panel runs the same validator the suite does.

## Testing

Pure units, headless: the model (place, move, resize, delete of each element; snapping; clamping; hit-testing including
overlapping elements and handles; every command's undo restores the exact previous data; merge of a drag into one undo
step), the stack (undo/redo order, redo cleared by a new edit), the checks (each lint on a minimal bad room and a clean
one; reachability true on a room with a ledge chain, false when one gap is 10 px too wide, true again with the ability
that spans it; a room with no path to an exit), the builder round-trip (a saved-and-reloaded room equals the original,
including `hard_ledges` and `authored`), the generator skip. A view smoke test builds the room view for every shipped room
and checks it draws the same nodes `RoomBuilder` does. UI: instantiate the editor UI and drive a placement with synthetic
input events. Play from here: enter, the player is at the cursor inside the in-memory room, Esc returns and the model is
untouched. A real windowed screenshot of the editor, and one of a room played from it, are looked at before merge.

## Rulings I made

1. **In-game, not a plugin.** The reason is play-testing in one process with the real room builder. Cost if wrong: the
   editor's UI is hand-built rather than Godot's inspector; the model, commands and checks are host-independent, so an
   `EditorPlugin` shell could reuse them.
2. **Reuse `.tres`, add `authored`.** One format the game already loads, and the generator cannot erase edits. Cost if wrong:
   a later migration to JSON would be a converter, not a rewrite.
3. **Prefabs expand to plain rects.** The game never sees a prefab, and the editor does not need to remember one. Cost if
   wrong: no "move the whole stamp" after placing; copy, paste and group-select cover it.
4. **Reachability starts with jumping only** and grows one ability at a time, each with its own test, because an over-generous
   model declares broken rooms completable and an under-generous one flags good rooms. The panel says which abilities it
   assumed. Cost if wrong: false alarms on rooms that need a swing; the ability picker in play-from-here tests them by hand.
5. **Snap default 4 px**, because the shipped rooms are on a 2-4 px grid; 20 px would misplace them. Cost if wrong: one dropdown.
6. **No room deletion** in the tool: it would leave dangling exits in neighbours and is easy to do in git.

## Later

Multi-ability reachability (cling, swing, dash), drag-to-arrange rooms, room templates (arena, shaft, corridor from the
archetype table in the research), the per-room "cleared with X" stamp, a mini-map of reachable regions, layer toggles for
decor and dressing, and a `JSON` export for CI lint.
