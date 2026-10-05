# The world's creatures (F2f) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every one of the 169 new creatures (the 140 world twins and the 29 support monsters) stands in at least one room of one of its areas, placed by the builder, so a player can meet every form in the world.

**Architecture:** `tools/build_creatures.py` writes `tools/creature_areas.json` (each creature's areas and class, the lairs, the quiet rooms). `AreaPlacement` (`tools/areas/placement.gd`, prefix `PL`) is the last module: it gives each creature a spot on a surface of a room of one of its areas and adds the spawn, marked `"by": "PL"`; the builder strips the marked spawns on every run, so a re-run changes nothing and hand-made spawns are never touched. Spots are checked by `RoomLint` (a spawn finding public as `RoomLint.spawn_findings`) and by the creature's drawn size.

**Tech Stack:** Godot 4.7 GDScript, Python 3 (`python3 -m unittest tools/test_build_creatures.py`), GUT (`tools/run_tests.sh [filter]`), `tools/build_areas.sh`.

**Spec:** `docs/research/areas-f2.md` ("Placement of creatures"), `docs/research/species-form-branches.md` section 10.

## Global Constraints

- Hand-authored spawns and the area modules' own spawns are never changed or removed by the placement; only spawns it added (marked `by: PL`) are replaced on a run.
- No creature stands in a quiet room (the thresholds, the truce, the rests), the start room or a boss arena. A rare stands in a lair when its areas have one with room, else in any room of its areas.
- A spawn passes every `RoomLint` spawn rule (inside the room, not in rock, not over a floor hole, clear of an altar) and has the clear height and the room its drawn size needs; two creatures on one surface do not overlap.
- The run is deterministic: the same world and plan place the same creatures at the same spots.
- No new creature data, no change to a creature's stats, XP or essence: calibration is F3. No push. No attribution lines in commits. No time or effort estimates.

## Review Focus

- A creature the plan lists but no room of its areas can hold fails the build with its id, rather than being dropped.
- A room never gets so many creatures that the first screen of it is a wall of them: the weighted load per screen is bounded, and a room's spawns stay where a player entering from each exit has the 64 px of clear floor.
- The room editor, the room spec and the MCP tools round trip a placed spawn without losing its `by` marker, so a later run does not add it twice.
- The shipped-rooms helper the old tests pin the world with does not see the placed spawns.

### Task 1: The plumbing

**Files:** Create `tools/creature_areas.json` (generated); Modify `tools/areas/area_builder.gd`, `scripts/editor/mcp/room_spec.gd`, `scripts/world/room_lint.gd`, `tests/support/shipped_rooms.gd`, `tests/support/area_worlds.gd`; Test `tests/test_area_builder.gd`, `tests/test_room_spec.gd` (or the spec's existing test file), `tests/test_room_lint.gd`

**Interfaces:**
- Produces: `AreaBuilder.build_with` strips spawns whose `by` is a module prefix; `RoomSpec` writes and reads a spawn's optional `by`; `RoomLint.spawn_findings(r: RoomDef) -> Array` (the `outside`, `in_rock`, `over_hole`, `altar_clearance` and `creature_fit` findings that name a spawn: each carries `pick.kind == "spawn"` and its `index`); `ShippedRooms.only` drops spawns with a `by`; `AreaWorlds.ORDER` ends with `"PL"`.

- [ ] **Step 1: Tests:** a module that adds a marked spawn to a shipped room is stripped and re-added once on a rebuild; a spawn without `by` is never stripped; the spec round trip keeps `by`; `spawn_findings` names an over-hole spawn and a spawn in rock and nothing for a good one; `ShippedRooms.only` has no marked spawn.
- [ ] **Step 2: Run** them. Expected: FAIL. **Step 3: Implement.** **Step 4: Run** them with `test_area_builder`, `test_room_lint`, `test_room_tools_read`, `test_room_edit_save`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the builder can place and replace marked spawns, and the data says where creatures live`.

### Task 2: The placement

**Files:** Create `tools/areas/placement.gd`; Modify `tools/areas/areas.gd`; Test `tests/test_placement.gd`

**Interfaces:**
- Produces: `class_name AreaPlacement extends AreaModule` with `_init(plan := {})` (the plan from `res://tools/creature_areas.json` when empty), `prefix() == "PL"`, `build(world)`, `static func size_of(def: CreatureDef) -> Vector2` (the drawn width and height: the sheet's frame, or the creature it wears, times `sprite_size`), `var unplaced: Array` (ids it could not place).

- [ ] **Step 1: Tests** on a small made-up world and plan: a creature lands in a room of its area on a floor or ledge, with the spawn marked `PL`; a quiet room, the start room and a boss room get none; a rare goes to a lair when the area has one with room and to another room when not; a creature too big for any footing is `unplaced` and the build reports its id; two creatures on one surface do not overlap; no creature stands under a ledge too low for its height or over a floor hole; the load is shared (the emptier room first); a second build is identical; existing spawns are untouched.
- [ ] **Step 2: Run** `tools/run_tests.sh test_placement`. Expected: FAIL. **Step 3: Implement.** **Step 4: Run** it. Expected: PASS.
- [ ] **Step 5: Commit** `feat: the placement finds every new creature a spot`.

### Task 3: The world

**Files:** Modify `tools/areas/areas.gd`; generated rooms; Test `tests/test_placement_world.gd`

- [ ] **Step 1: Tests** on the real world: all 169 creatures are placed (`unplaced` is empty), each in a room of one of its areas; the three quiet classes of room are empty; the world has no problems; no placed spawn is within a creature's width of another on its surface; no room's weighted load per screen is above the bound; the support monsters the area modules placed are still there; the checked-in rooms are what the builder writes; every shipped room keeps its hand-authored spawns.
- [ ] **Step 2: Run** it. Expected: FAIL. **Step 3: Register** the module last, tune the bound and the spacing until the real world fits, run `tools/build_areas.sh`. **Step 4: Run** the room, world, area and content suites. Expected: PASS.
- [ ] **Step 5: Commit** `feat: every creature has a place in the world`.

### Task 4: Seeing it, and the docs

**Files:** Modify `docs/research/areas-f2.md`, `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md`, `README.md`

- [ ] **Step 1: Render** a few crowded rooms (the Deep's D4, the Crypt's Gallery, the Nave) and look at them; fix anything unreadable through the placement's spacing.
- [ ] **Step 2: Update the docs:** F2f built, how to run it, what the plan file holds, the load bound, the lairs, what remains for F3.
- [ ] **Step 3: Run** `TEST_TIMEOUT=1700 tools/run_tests.sh` and `python3 -m unittest tools/test_build_creatures.py`. Expected: PASS.
- [ ] **Step 4: Commit** `docs: every creature has a place`.
