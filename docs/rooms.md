# Rooms

The room data in `data/rooms/*.tres` is the source of truth. There is no generator: edit rooms with the room editor
(`tools/edit_rooms.sh`, design in `docs/superpowers/specs/2026-09-29-room-editor-design.md`), which saves those files, and
the game's own `RoomBuilder` and `TerrainPainter` draw them. `tools/prefabs.gd` stays as a library of reusable pieces (ledge
chains, shaft climbs) for tests and for any script that wants to stamp them. The dated plans under `docs/superpowers/`
that say `tools/build_world.gd` is the source of truth are historical: that generator was retired when the editor landed,
and this file keeps the reasoning its comments carried, which the `.tres` files cannot.

## The edge and one-way rules

- Positions are local to each room, in pixels. A room sits at `cell` on a shared grid of 640x360 screens (`size` is in
  screens), so neighbours line up exactly.
- Floors, ceilings and side walls are generated from a room's size and its exits (`RoomBuilder.edge_walls`): the floor top is
  `height - 40`, the walls and ceiling are 20 thick, with a gap at every exit span. A side door flush with the floor ends at
  `height - 40` (320 in a 360-pixel room).
- A thin solid (at most 24 px tall and wider than 24) is a one-way ledge: you jump up through it and stand on it. A thicker
  solid is rock. To make a thin one rock from below on purpose, add its rect to the room's `hard_ledges` as well as `solids`.
  No shipped room uses `hard_ledges`.
- Every exit is matched by an exit on the neighbour's opposite edge covering the same world span (the validator checks it),
  with the same shortcut id. Keep 64 px in front of a door free of rock (`RoomLint`'s `exit_blocked`).
- An exit's `gate` is a label from `WorldValidator.GATES` (today `wall_cling`) that must match on both halves; it does not stop the
  player in play, but a gated bottom exit still counts as a floor hole (only a `shortcut` closes one), so no creature or decor may stand over it (set dressing may).
- Keep every step at most 54 px (the slime's ledge limit) and gaps between floating solids at least 36 px so the 28 px body
  fits.

The rules a room must meet that are not the world validator's (a spawn in rock, a ledge past the base jump, a start off the
floor, a blocked or too narrow exit, a feature id used twice, a switch with no exit, ...) are in `scripts/world/room_lint.gd`.
The editor's `Validate (N)` button lists them with the validator's findings, and the test suite runs the same functions on
every room.

## Decor

Decor is the standing and hanging pieces (crystals, fungus, hanging roots, stalactites) drawn in front of the back wall. The catalog the
editor offers is `DecorLib.CATALOG` in `scripts/world/decor_lib.gd`: 46 rows, `id -> {anchor, light}`. The 21 ids the shipped rooms use
are pinned to the data by `tests/test_decor_lib.gd`; the other 25 (all of `deep_*` and `flooded_*`, 5 grotto ids and `crystal_purple`)
are chosen, not pinned. An id belongs to a biome by its `<biome>_` prefix (none means cave). A new biome's art needs rows there. A
bottom-anchored piece stands on its position and a top-anchored one hangs from it; the editor places them on the surface below or the
rock above the click. An id outside the catalog is lint's `decor_unknown` and the builder skips it.

## Set dressing

Scenery props behind the play plane. `factor` is a prop's depth: 0.1-0.3 far (arches, pillars, floating ledges, waterfalls),
0.4-0.55 middle (crystals, mushroom groves, stalactites), 0.65-0.8 near (hanging roots at the edges). A prop appears at `pos`
when the camera is as close to it as the room allows and drifts by depth from there (see `SetDressing`). The editor does not
edit `dressing` (P3: scenery).

## Load-bearing details

These are the choices in the data that a test does not catch and a casual edit would break.

- **C1's start** is at (60, 308): the body centre sits 12 px above the floor top (320).
- **C5's entry ledge** by the left exit stops short of the platform that follows it (x 100 and on), so the taller slime has full
  headroom there. Its floor opens into the Grotto (G1) at x 220-380, which splits the floor in two; the east piece gets a
  ledge back to the zigzag.
- **The G1 and G3 ledge chains** under a floor hole climb back up to the room above with their top ledge at y 14, so the
  standing centre is 2 px inside the room above.
- **G2's and G3's overhangs** (the slabs the vine snakes hang from) are mass, not ledges: they are not meant to be stood on.
- **G3's hanging wall** (`Rect2(108, 20, 16, 400)`) drops from the ceiling to y 420, 100 px below the sill of the opening to G5
  (y 320), so the shaft between it and the west wall can only be climbed with Wall Cling. It is the one thing that makes the G5
  exit need Wall Cling physically, and no test catches moving it: leave it where it is unless the design of G5 changes.

## The rooms

| Id | Size, cell | What it is |
|---|---|---|
| C1 Start | 2x1 | the original lower hall; floor top 320 |
| C2 Thread Gap | 2x1 | spiders under the ceiling; a chimney up to C3 needs Wall Cling |
| C3 Spider Loft | 1x2 | a climb of ledges, entered from C2's chimney below |
| C4 Glow Pool | 1x1 | rest here |
| C5 Drop Shaft | 1x3 | a zigzag of ledges down to the floor, which opens into the Grotto (G1) at x 220-380 |
| C6 nook | 1x1 | a quiet crystal cavern with a tablet and the switch that opens the floor down into C1 for good |
| G1 Grotto Mouth | 2x1, cell (5, 5) | the landing under C5's floor; a ledge chain under the hole climbs back up to C5; the Grotto's rebirth pool stands a little way in, with the first real kit |
| G2 Spore Hall | 3x2, cell (7, 5) | the hub: two levels, the lower floor (with the hole down to G3) and an upper walkway that meets G1, with two shafts of ledges between them |
| G3 Vine Maze | 2x2, cell (8, 7) | snakes under overhangs, crabs below; a chain under the hole up to G2's floor, and a climb to the upper level and the exit to G4 |
| G4 Glow Pool | 1x1, cell (10, 7) | the last room, a rest before the area's end, with a tablet |
| G5 Pale Moth | 1x1, cell (7, 7) | the rare room, reached only by wall cling up the chimney in G3; the Pale Moth drifts here |
