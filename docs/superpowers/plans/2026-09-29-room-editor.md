# Room Editor (P1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A separate editor scene in which Sean opens a room, moves a ledge, drops a toad, adds a paired exit, plays the room from a spot in the real game with unsaved edits, comes back, saves, starts a new room beside an existing one, and is told what the world validator objects to first.

**Architecture:** A pure model (`RoomEditModel`: deep-copied rooms, snapshot undo, every edit, save) sits under a thin view (`RoomView`: the game's own `RoomBuilder` through a camera, overlays, tools) and panels (`EditorPanels`). Play hands the working rooms to `Game` in memory (`Game.play_request`) and back through `Game.editor_resume`. The validator gains one graph rule (`reachable`), the suite's content pins iterate a shipped-id list, and `tools/build_world.gd` is deleted.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-29-room-editor-design.md`

## Global Constraints

- Run tests with `tools/run_tests.sh [file-substring]` from `/Users/sean/sites/isekai-game/.worktrees/room-editor`; any SCRIPT ERROR or Parse Error fails the run. After adding or renaming a `class_name` script or a scene, run `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1` before the tests.
- Find code by symbol; line numbers drift. BSD `sed` on this machine needs `sed -i ''`; edit files with Python or the Edit tool, never `git checkout` a file to undo a mutation you made on top of uncommitted work (copy it to `.tmp/` first and restore from the copy).
- Constants copied from the spec: snap 4 px on drag deltas and created edges; `MIN_EXIT` 36; undo cap 200; `KEEP_CLEAR` 64; exit bounds are the validator's own (`WALL` to `size.y - FLOOR` on a left or right edge, `WALL` to `size.x - WALL` on a top or bottom edge); new-room ids are letters, digits and underscore, unique case-insensitively.
- The editor never edits `dressing`, `decor`, `features`, `start` or `hard_ledges` except that moving or deleting a solid keeps `hard_ledges` consistent with it.
- New files that Godot indexes get a `.gd.uid` from the import; stage directories (`git add scripts tests tools docs scenes data`) so those are committed.
- The suite runs with `HOME=$PWD/.tmp/gdhome`; the editor is launched with `HOME=$PWD/.tmp/editor-home` (Task C2). No production code special-cases the sandbox except `RoomEditor.in_sandbox`, which only gates Play.
- No attribution lines in commit messages.
- Tests that set `Game.play_request`, `Game.editor_resume` or `RoomEditor.sandbox_root` reset them in `after_each`.

## Review Focus

1. A saved room reloading different from what the editor showed (deep-copy aliasing into the resource cache, `features[i]["kit"]`, float versus int spans), and Save writing a room the user never touched.
2. An exit that the validator rejects after the editor wrote it: a side exit ending at `height - 40`, a target that merely shares an edge line, a partner span off by the neighbour's origin, moving an exit leaving its partner behind, deleting one leaving a one-sided exit.
3. Undo not restoring exact previous data: a click pushing a step, a drag pushing several, an exit or a new room needing two undos, redo surviving a new edit, the cap.
4. Play writing anything to the real profile, `Compendium.progress` changing, a death reaching the reincarnation menu or reloading `main.tscn` instead of the editor, F5 doing nothing while the skill screen is open or firing on the death card.
5. A content pin going red after the suite change when a scratch room is added, or a pin silently no longer covering a shipped room (the shipped list must hold C1-C6 and G1-G5 and every pin must still reach them).
6. The generator's load-bearing rationale being lost in the deletion (`docs/rooms.md` must keep the edge and one-way rules, the depth bands, C1's start, C5's entry-ledge headroom, the G1/G3 ledge chains, G2/G3's overhangs as mass, G3's hanging wall).

## File Map

- Modify: `scripts/world/world_validator.gd` (`reachable`, the graph rule, public `edge_range`/`edge_origin`/`touches`), `scripts/game.gd`, `tests/test_rooms.gd`, `tests/test_world_validator.gd`, `tests/test_room_dressing.gd`, `tests/test_grotto_rooms.gd`, `tests/test_form_offers.gd`, `tests/test_skill_caps.gd`, `tests/test_progression_stages.gd`, `tests/test_rebirth_kit.gd`, `scripts/world/room_def.gd` and `tools/prefabs.gd` (header comments), `docs/playtest-checklist.md`.
- Create: `tests/support/shipped_rooms.gd`, `scripts/editor/room_edit_model.gd`, `scripts/editor/room_editor.gd`, `scripts/editor/room_view.gd`, `scripts/editor/editor_panels.gd`, `scripts/editor/editor_return.gd`, `scenes/room_editor.tscn`, `tools/edit_rooms.sh`, `docs/rooms.md`, and tests `tests/test_room_reachable.gd`, `tests/test_room_edit_model.gd`, `tests/test_room_edit_exits.gd`, `tests/test_room_edit_save.gd`, `tests/test_editor_play.gd`, `tests/test_room_editor_scene.gd`.
- Delete: `tools/build_world.gd`.

---

## Milestone A: the validator and the suite (no editor code)

### Task A1: `WorldValidator.reachable` and the graph rule

**Files:** Modify `scripts/world/world_validator.gd`, `tests/test_rooms.gd`, `tests/test_grotto_rooms.gd`; Create `tests/test_room_reachable.gd`.

**Interfaces:**
- Produces: `WorldValidator.reachable(rooms: Dictionary, skip_gated := false) -> Array` (ids, start first; `[]` unless exactly one start), and in `validate` one error per unreached room: `"<id>: no way in from the start room"`. Also public statics `edge_range(r: RoomDef, edge: String) -> Vector2` (lo, hi along the edge, in the room's own pixels), `edge_origin(r: RoomDef, edge: String) -> float` (the room's world origin along that edge's axis) and `touches(a: Rect2, b: Rect2, edge: String) -> bool` (the old `_touches`), all used by Task B3.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_reachable.gd`)

```gdscript
extends GutTest
## WorldValidator.reachable: what the start room reaches by following exits, and the rule that every room must be reached.

func _room(id: String, cell: Vector2i, exits: Array, extra: Dictionary = {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.cell = cell
	r.exits = exits
	for k in extra:
		r.set(k, extra[k])
	return r

func _exit(edge: String, room: String, extra: Dictionary = {}) -> Dictionary:
	var e := {"edge": edge, "from": 200.0, "to": 320.0, "room": room}
	for k in extra:
		e[k] = extra[k]
	return e

func _line() -> Dictionary:  # A - B - C in a row, A is the start
	return {
		"A": _room("A", Vector2i(0, 0), [_exit("right", "B")], {"start": Vector2(100, 310)}),
		"B": _room("B", Vector2i(1, 0), [_exit("left", "A"), _exit("right", "C")]),
		"C": _room("C", Vector2i(2, 0), [_exit("left", "B")]),
	}

func test_the_start_reaches_a_chain_start_first() -> void:
	assert_eq(WorldValidator.reachable(_line()), ["A", "B", "C"])

func test_a_room_with_no_way_in_is_reported() -> void:
	var rooms := _line()
	rooms["B"].exits = [_exit("left", "A")]
	rooms["C"].exits = []
	var errors := "\n".join(WorldValidator.validate(rooms))
	assert_string_contains(errors, "C: no way in from the start room")
	assert_eq(WorldValidator.reachable(rooms), ["A", "B"])

func test_gated_and_shortcut_links_count_unless_skipped() -> void:
	var rooms := _line()
	rooms["A"].exits = [_exit("right", "B", {"shortcut": "s1"})]
	assert_eq(WorldValidator.reachable(rooms), ["A", "B", "C"], "a shortcut link is a link")
	assert_eq(WorldValidator.reachable(rooms, true), ["A"], "skipped when asked")
	rooms["A"].exits = [_exit("right", "B", {"gate": "wall_cling"})]
	assert_eq(WorldValidator.reachable(rooms, true), ["A"])

func test_an_exit_to_an_unknown_room_is_skipped_not_a_crash() -> void:
	var rooms := _line()
	rooms["A"].exits.append(_exit("top", "Z"))
	assert_eq(WorldValidator.reachable(rooms), ["A", "B", "C"])
	assert_string_contains("\n".join(WorldValidator.validate(rooms)), "unknown room 'Z'")

func test_with_no_start_or_two_starts_the_rule_is_skipped() -> void:
	var rooms := _line()
	rooms["A"].start = RoomDef.NO_START
	assert_eq(WorldValidator.reachable(rooms), [])
	assert_string_contains("\n".join(WorldValidator.validate(rooms)), "exactly one start")
	assert_false("\n".join(WorldValidator.validate(rooms)).contains("no way in"))
	rooms["A"].start = Vector2(100, 310)
	rooms["C"].start = Vector2(100, 310)
	assert_eq(WorldValidator.reachable(rooms), [])

func test_the_public_edge_helpers() -> void:
	var r := _room("A", Vector2i(2, 1), [], {"size": Vector2i(2, 1)})
	assert_eq(WorldValidator.edge_range(r, "right"), Vector2(20.0, 320.0), "a side edge ends at height - FLOOR")
	assert_eq(WorldValidator.edge_range(r, "top"), Vector2(20.0, 1260.0), "a top edge ends at width - WALL")
	assert_eq(WorldValidator.edge_origin(r, "left"), 360.0)
	assert_eq(WorldValidator.edge_origin(r, "bottom"), 1280.0)
	assert_true(WorldValidator.touches(Rect2(0, 0, 640, 360), Rect2(640, 0, 640, 360), "right"))
	assert_false(WorldValidator.touches(Rect2(0, 0, 640, 360), Rect2(700, 0, 640, 360), "right"))

func test_the_shipped_world_is_one_connected_graph() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	assert_eq(WorldValidator.reachable(rooms).size(), rooms.size())
	assert_eq("\n".join(WorldValidator.validate(rooms)), "")
```

(`tests/test_rooms.gd`'s `test_the_main_route_needs_no_skills` keeps the ungated pin.)

In `tests/test_rooms.gd` replace `_reach(skip_gated)` with the validator: delete the function and change the two callers to `WorldValidator.reachable(rooms, true)` and `WorldValidator.reachable(rooms)`. In `tests/test_grotto_rooms.gd` change `_reach_ungated()` to `return WorldValidator.reachable(rooms, true)`.

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_room_reachable`
Expected: FAIL (Parse Error: `reachable`, `edge_range`, `edge_origin`, `touches` not found in `WorldValidator`).

- [ ] **Step 3: Implement** in `scripts/world/world_validator.gd`

```gdscript
## The rooms the start room reaches by following exits, start first. Exits to unknown rooms are skipped (validate reports
## them). `skip_gated` leaves out exits that carry a `gate` or a `shortcut`. Empty unless exactly one room is the start.
static func reachable(rooms: Dictionary, skip_gated := false) -> Array:
	var start := ""
	var starts := 0
	for id in rooms:
		if (rooms[id] as RoomDef).is_start():
			start = id
			starts += 1
	if starts != 1:
		return []
	var seen := [start]
	var frontier := [start]
	while not frontier.is_empty():
		var id: String = frontier.pop_back()
		for e in (rooms[id] as RoomDef).exits:
			if skip_gated and (e.has("gate") or e.has("shortcut")):
				continue
			var to: String = e.get("room", "")
			if rooms.has(to) and not seen.has(to):
				seen.append(to)
				frontier.append(to)
	return seen

## The span an exit on `edge` may cover, in the room's own pixels: clear of the corners and, on a side edge, of the floor.
static func edge_range(r: RoomDef, edge: String) -> Vector2:
	var size := r.pixel_size()
	return Vector2(RoomDef.WALL, size.y - RoomDef.FLOOR if _vertical_edge(edge) else size.x - RoomDef.WALL)

## The room's world position along the axis an exit on `edge` runs (y for a left or right edge, x for a top or bottom one).
static func edge_origin(r: RoomDef, edge: String) -> float:
	var origin := r.world_rect().position
	return origin.y if _vertical_edge(edge) else origin.x
```

Rename `_touches` to `touches` (definition and its one caller in `_check_exit`), use `edge_range` and `edge_origin` in `_check_exit` (`var limits := edge_range(a, edge); var lo := limits.x; var hi := limits.y`) and in `world_span` (`var base := edge_origin(r, e.get("edge", ""))`), and in `validate` after the `_check_rebirth_pools` call add:

```gdscript
	if starts == 1:
		var reached := reachable(rooms)
		for id in ids:
			if not reached.has(id):
				errors.append("%s: no way in from the start room" % id)
```

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_room_reachable`, `test_world_validator`, `test_rooms`, `test_grotto_rooms`, `test_rebirth_pool`, `test_shortcut`, `test_set_dressing`.
Expected: all PASS.

- [ ] **Step 5: Mutation check.** Change `reachable`'s `rooms.has(to) and` to nothing: `test_an_exit_to_an_unknown_room_is_skipped_not_a_crash` must crash or fail. Restore from a copy in `.tmp/`.

- [ ] **Step 6: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs && git commit -m "feat: the world validator reports rooms the start cannot reach; the reachability walk moves out of the tests"
```

---

### Task A2: content pins iterate the shipped rooms

**Files:** Create `tests/support/shipped_rooms.gd`; Modify `tests/test_rooms.gd`, `tests/test_room_dressing.gd`, `tests/test_grotto_rooms.gd`, `tests/test_form_offers.gd`, `tests/test_skill_caps.gd`, `tests/test_progression_stages.gd`, `tests/test_rebirth_kit.gd`.

**Interfaces:**
- Produces: `ShippedRooms.IDS` (`["C1".."C6", "G1".."G5"]`), `ShippedRooms.load_all() -> Dictionary` (id to RoomDef, only the shipped ids, from `res://data/rooms`), `ShippedRooms.only(rooms: Dictionary) -> Dictionary`.

- [ ] **Step 1: Write the helper and the scratch-room test (RED).** `tests/support/shipped_rooms.gd`:

```gdscript
class_name ShippedRooms
extends RefCounted
## The eleven rooms the game shipped with. Content pins (XP totals, supplies, dressing) are about these rooms; a room the editor
## adds later is not part of them, while rule tests (spawn in rock, ledge reach, exits, one start) still run on every room.

const IDS := ["C1", "C2", "C3", "C4", "C5", "C6", "G1", "G2", "G3", "G4", "G5"]

static func only(rooms: Dictionary) -> Dictionary:
	var out := {}
	for id in IDS:
		if rooms.has(id):
			out[id] = rooms[id]
	return out

static func load_all() -> Dictionary:
	return only(World.load_rooms("res://data/rooms"))
```

Add a test to `tests/test_rooms.gd`:

```gdscript
func test_the_shipped_list_names_rooms_that_exist() -> void:
	for id in ShippedRooms.IDS:
		assert_true(rooms.has(id), id)
```

and change `test_the_world_has_the_cave_and_the_grotto_and_validates` to assert `ShippedRooms.IDS` are all in `ids` (a loop of `assert_true(ids.has(id), id)`) instead of `assert_eq(ids, [...])`.

- [ ] **Step 2: Scope each content pin.** In each file, the aggregate that a new room would join reads the shipped rooms:
  - `tests/test_room_dressing.gd`: `before_all` gets `rooms = ShippedRooms.load_all()` (the tests there are pins over every cave room).
  - `tests/test_grotto_rooms.gd`: keep `rooms = World.load_rooms(...)` for the validate and cell tests; in `test_the_pacing_rule` build `open` as `WorldValidator.reachable(rooms, true)` and then filter it with `ShippedRooms.IDS.has(id)` *after* the walk (the walk passes through new rooms), and build `all_cave` from `ShippedRooms.only(rooms)`.
  - `tests/test_form_offers.gd`: `before_all` loads `World.load_rooms("res://data/rooms")` once (the current code loads it per id) and keeps only shipped cave rooms: `ShippedRooms.only(all)` filtered by `area == "cave"`.
  - `tests/test_skill_caps.gd::test_the_top_levels_are_reachable_against_what_their_sources_supply`: `var rooms := ShippedRooms.load_all()`.
  - `tests/test_progression_stages.gd::test_a_full_first_pass_of_the_cave_stays_under_the_stage_one_cap`: `var rooms := ShippedRooms.load_all()`.
  - `tests/test_rebirth_kit.gd`: both tests that pass a supply use `FormOffers.supply(ShippedRooms.load_all(), creatures, forms)` (the creatures loaded as in the second test) instead of `FormOffers.default_supply(forms)`.

- [ ] **Step 3: Run each edited file.** Expected: PASS (same numbers, the shipped rooms are the only rooms today).

- [ ] **Step 4: The scratch-room check (the change's proof).** Write a scratch cave room `res://data/rooms/ZZ_scratch.tres` (a `RoomDef` at `cell (0, -2)`, `area "cave"`, a `spawns` list of one spider, one toad, one vine_snake, one mushroom_crab, one spore_moth, a paired exit is not needed for the pins) with a throwaway script under `.tmp/`:

```gdscript
extends SceneTree
func _init() -> void:
	var r := RoomDef.new()
	r.id = "ZZ_scratch"
	r.area = "cave"
	r.cell = Vector2i(0, -2)
	r.spawns = [{"id": "spider", "pos": Vector2(100, 300)}, {"id": "toad", "pos": Vector2(200, 300)},
		{"id": "vine_snake", "pos": Vector2(300, 300)}, {"id": "mushroom_crab", "pos": Vector2(400, 300)},
		{"id": "spore_moth", "pos": Vector2(500, 300)}]
	ResourceSaver.save(r, "res://data/rooms/ZZ_scratch.tres")
	quit()
```

Run it (`env HOME="$PWD/.tmp/gdhome" godot --headless -s .tmp/<dir>/scratch.gd`), then `tools/run_tests.sh` on the pin files (`test_rooms`, `test_room_dressing`, `test_grotto_rooms`, `test_form_offers`, `test_skill_caps`, `test_progression_stages`, `test_rebirth_kit`). Expected: every content pin PASS; the *rule* tests that run on every room (spawn in rock, ledge reach) may PASS or FAIL on the scratch room, and `test_rooms.gd`'s validate assertion FAILS on it (`ZZ_scratch: no way in from the start room`), which is the graph rule working. Record which failed in the ledger. Then delete `data/rooms/ZZ_scratch.tres` and its `.uid`, and run `git status --short data/` (expected: empty).

- [ ] **Step 5: Full suite and commit**

```bash
tools/run_tests.sh   # Expected: PASS
git add scripts tests tools docs && git commit -m "test: content pins iterate the shipped rooms so an edited or added room does not move them"
```

---

## Milestone B: the model and the save (headless, pure)

### Task B1: the model core, deep copy and snapshot undo

**Files:** Create `scripts/editor/room_edit_model.gd`, `tests/test_room_edit_model.gd`.

**Interfaces:**
- Produces: `RoomEditModel.new(source: Dictionary, creature_ids: Array = [])`; members `rooms: Dictionary`, `dirty: Dictionary`, `selection: Dictionary`, `creature_ids: Array`; `static copy_room(r: RoomDef) -> RoomDef`, `static same_room(a, b) -> bool` (both `RoomDef` or null), `static snap(v: float) -> float`, `static snap_delta(d: Vector2) -> Vector2`, `bounds(r: RoomDef) -> Rect2`; `undo() -> bool`, `redo() -> bool`, `undo_depth() -> int`, `redo_depth() -> int`; private `_snap(ids: Array) -> Dictionary`, `_push(before: Dictionary) -> void` (drops a step that changed nothing, clears redo, caps at `UNDO_CAP`, marks the changed rooms dirty), `_swap(snap: Dictionary) -> Dictionary`. Constants `GRID := 4.0`, `MIN_EXIT := 36.0`, `UNDO_CAP := 200`, `KEEP_CLEAR := 64.0`, `MIN_SOLID := 4.0`.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_model.gd`, part 1)

```gdscript
extends GutTest
## RoomEditModel: the working copy of the rooms and its snapshot undo.

var source := {}
var model: RoomEditModel

func before_each() -> void:
	source = ShippedRooms.load_all()
	model = RoomEditModel.new(source, ["bat", "toad", "spider", "water_pool"])

func test_the_model_edits_copies_never_the_loaded_rooms() -> void:
	assert_ne(model.rooms["C1"], source["C1"])
	model.rooms["C1"].solids.append(Rect2(1, 2, 3, 4))
	assert_false(source["C1"].solids.has(Rect2(1, 2, 3, 4)))

func test_a_nested_value_is_copied_too() -> void:
	var pool_room := ""
	for id in source:
		for f in (source[id] as RoomDef).features:
			if f.get("kind", "") == "rebirth_pool" and (f["kit"] as Dictionary).has("affinity"):
				pool_room = id
	assert_ne(pool_room, "", "a shipped room has a rebirth pool with a kit affinity")
	var feature: Dictionary = model.rooms[pool_room].features.filter(func(f): return f.get("kind", "") == "rebirth_pool" and f["kit"].has("affinity"))[0]
	var original: Dictionary = source[pool_room].features.filter(func(f): return f.get("kind", "") == "rebirth_pool" and f["kit"].has("affinity"))[0]
	var before: Dictionary = original["kit"]["affinity"].duplicate()
	feature["kit"]["affinity"]["zzz"] = 9
	assert_eq(original["kit"]["affinity"], before)

func test_a_copy_equals_its_source_by_exported_properties() -> void:
	for id in source:
		assert_true(RoomEditModel.same_room(source[id], model.rooms[id]), id)
	assert_false(RoomEditModel.same_room(source["C1"], source["C2"]))
	assert_true(RoomEditModel.same_room(null, null))
	assert_false(RoomEditModel.same_room(null, source["C1"]))

func test_snap_rounds_to_four_and_a_delta_is_snapped_per_axis() -> void:
	assert_eq(RoomEditModel.snap(5.9), 4.0)
	assert_eq(RoomEditModel.snap(6.1), 8.0)
	assert_eq(RoomEditModel.snap(-1.9), 0.0)
	assert_eq(RoomEditModel.snap_delta(Vector2(9.0, -5.0)), Vector2(8.0, -4.0))

# --- undo and redo (driven through a real edit, add_solid, tested fully in the next file) ---

func _add(a := Vector2(100, 100), b := Vector2(200, 140)) -> void:
	assert_eq(model.add_solid("C1", a, b), "")

func test_an_edit_is_one_undo_step_and_undo_restores_the_exact_data() -> void:
	var before := RoomEditModel.copy_room(model.rooms["C1"])
	_add()
	assert_eq(model.undo_depth(), 1)
	assert_true(model.undo())
	assert_true(RoomEditModel.same_room(before, model.rooms["C1"]))
	assert_eq(model.undo_depth(), 0)
	assert_false(model.undo(), "nothing left")

func test_redo_reapplies_and_a_new_edit_clears_it() -> void:
	_add()
	var after := RoomEditModel.copy_room(model.rooms["C1"])
	model.undo()
	assert_true(model.redo())
	assert_true(RoomEditModel.same_room(after, model.rooms["C1"]))
	model.undo()
	_add(Vector2(300, 100), Vector2(360, 140))
	assert_eq(model.redo_depth(), 0)
	assert_false(model.redo())

func test_a_step_that_changed_nothing_is_dropped() -> void:
	var before := model._snap(["C1"])
	model._push(before)
	assert_eq(model.undo_depth(), 0)

func test_the_undo_stack_is_capped() -> void:
	for i in RoomEditModel.UNDO_CAP + 20:
		model.add_solid("C1", Vector2(24 + (i % 40) * 4, 100), Vector2(28 + (i % 40) * 4, 140 + (i / 40) * 4))
	assert_eq(model.undo_depth(), RoomEditModel.UNDO_CAP)

func test_editing_marks_only_the_touched_room_dirty() -> void:
	_add()
	assert_eq(model.dirty.keys(), ["C1"])
```

- [ ] **Step 2: Run to verify it fails.** Run `tools/run_tests.sh test_room_edit_model`. Expected: FAIL (Parse Error: `RoomEditModel` not found). (Add `add_solid` in Task B2; for this task write the class with a minimal `add_solid` first, or run B1 and B2 back to back and treat B1's RED as the missing class.)

- [ ] **Step 3: Implement** the first half of `scripts/editor/room_edit_model.gd`:

```gdscript
class_name RoomEditModel
extends RefCounted
## The room editor's data: working copies of the rooms, the selection, every edit (each one undo step), the dirty set and the
## save. Pure data, no nodes. It is the one place that knows the shape of a RoomDef's arrays.

const GRID := 4.0
const MIN_EXIT := 36.0
const UNDO_CAP := 200
## Depth of the rock-free strip kept in front of a new room's default door, in the neighbour.
const KEEP_CLEAR := 64.0
const MIN_SOLID := 4.0

static var _prop_names: Array = []

var rooms := {}     # id -> RoomDef (working copies)
var dirty := {}     # id -> true: rooms edited since the last successful save
var creature_ids: Array = []
## {} or {"room", "kind": "solid" | "spawn" | "exit", "index"}
var selection := {}
var _undo: Array = []   # each: {id: RoomDef or null}, the state before a step
var _redo: Array = []
var _drag := {}         # a move in progress (Task B2)

func _init(source: Dictionary, p_creature_ids: Array = []) -> void:
	creature_ids = p_creature_ids
	for id in source:
		rooms[id] = copy_room(source[id])

## The exported (stored) properties of RoomDef, so a property added later is copied and compared without an edit here.
static func _props() -> Array:
	if _prop_names.is_empty():
		for p in RoomDef.new().get_property_list():
			if (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (p["usage"] & PROPERTY_USAGE_STORAGE) != 0:
				_prop_names.append(p["name"])
	return _prop_names

static func copy_room(r: RoomDef) -> RoomDef:
	var c := RoomDef.new()
	for name in _props():
		var v = r.get(name)
		c.set(name, v.duplicate(true) if (v is Array or v is Dictionary) else v)
	return c

## RoomDef == RoomDef compares identity, so two rooms are the same when every exported property is equal (null equals null).
static func same_room(a, b) -> bool:
	if a == null or b == null:
		return a == b
	for name in _props():
		if a.get(name) != b.get(name):
			return false
	return true

static func snap(v: float) -> float:
	return roundf(v / GRID) * GRID

static func snap_delta(d: Vector2) -> Vector2:
	return Vector2(snap(d.x), snap(d.y))

static func bounds(r: RoomDef) -> Rect2:
	return Rect2(Vector2.ZERO, r.pixel_size())

# --- snapshots ---

func _snap(ids: Array) -> Dictionary:
	var s := {}
	for id in ids:
		s[id] = copy_room(rooms[id]) if rooms.has(id) else null
	return s

## Records `before` as an undo step unless the rooms it covers are unchanged; marks the changed ones dirty.
func _push(before: Dictionary) -> void:
	var changed := false
	for id in before:
		if not same_room(before[id], rooms.get(id)):
			changed = true
			dirty[id] = true
	if not changed:
		return
	_undo.append(before)
	if _undo.size() > UNDO_CAP:
		_undo.pop_front()
	_redo.clear()

## Puts `snap` back and returns the state it replaced (the other stack's step).
func _swap(snap: Dictionary) -> Dictionary:
	var now := _snap(snap.keys())
	for id in snap:
		if snap[id] == null:
			rooms.erase(id)
			dirty.erase(id)
		else:
			rooms[id] = snap[id]
			dirty[id] = true
	selection = {}
	return now

func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_swap(_undo.pop_back()))
	return true

func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_swap(_redo.pop_back()))
	return true

func undo_depth() -> int:
	return _undo.size()

func redo_depth() -> int:
	return _redo.size()
```

- [ ] **Step 4: Run to verify it passes** once Task B2's `add_solid` exists (Steps 1-3 of B2 follow immediately; B1's tests call it). Expected: PASS.

- [ ] **Step 5: Commit** after B2 (one commit per task; B1's commit may hold the class with only `add_solid` stubbed to the minimal working form if you want it green alone: `add_solid(room_id, a, b)` per B2's Step 3).

---

### Task B2: solids, creatures, the selection, moving and deleting

**Files:** Modify `scripts/editor/room_edit_model.gd`; Append to `tests/test_room_edit_model.gd`.

**Interfaces:**
- Produces: `drag_rect(a: Vector2, b: Vector2) -> Rect2` (static, snapped corners), `label_for(rect: Rect2, hard: Array = []) -> String` (static: `"one-way ledge"` or `"rock"`), `rock(room_id: String, with_gates := false) -> Array` (interior solids plus the boundary walls, plus closed-shortcut gate rects when asked), `add_solid(room_id: String, a: Vector2, b: Vector2) -> String` (`""` on success, else a reason), `add_spawn(room_id: String, creature_id: String, pos: Vector2) -> String`, `hit(room_id: String, p: Vector2, pick: float) -> Dictionary` (a selection or `{}`), `select(sel: Dictionary)`, `begin_move(sel: Dictionary) -> bool`, `move_to(delta: Vector2) -> void`, `end_move() -> void`, `delete_selection() -> String`, `floor_spot(room_id: String, p: Vector2) -> Variant` (a `Vector2` or `null`). Task B3 extends `begin_move`/`move_to`/`delete_selection` for exits.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_edit_model.gd`)

```gdscript
# --- solids ---

func test_a_solid_is_dragged_between_snapped_corners_and_clipped_to_the_room() -> void:
	assert_eq(RoomEditModel.drag_rect(Vector2(101, 99), Vector2(203, 143)), Rect2(100, 100, 104, 44))
	assert_eq(RoomEditModel.drag_rect(Vector2(200, 140), Vector2(100, 100)), Rect2(100, 100, 100, 40), "backwards drags normalise")
	var size: Vector2 = model.rooms["C1"].pixel_size()
	assert_eq(model.add_solid("C1", Vector2(size.x - 40, 100), Vector2(size.x + 200, 140)), "")
	var s: Rect2 = model.rooms["C1"].solids.back()
	assert_eq(s.end.x, size.x, "clipped to the room")

func test_a_tiny_or_outside_solid_is_refused_and_pushes_no_step() -> void:
	assert_ne(model.add_solid("C1", Vector2(100, 100), Vector2(102, 140)), "")
	assert_ne(model.add_solid("C1", Vector2(-300, -300), Vector2(-100, -100)), "")
	assert_eq(model.undo_depth(), 0)

func test_the_live_label_matches_the_builders_one_way_rule() -> void:
	for r in [Rect2(0, 0, 100, 24), Rect2(0, 0, 100, 28), Rect2(0, 0, 24, 24), Rect2(0, 0, 28, 24), Rect2(0, 0, 200, 8)]:
		var one_way := RoomBuilder.is_one_way(r)
		assert_eq(RoomEditModel.label_for(r), "one-way ledge" if one_way else "rock", str(r))
	var hard := Rect2(0, 0, 100, 24)
	assert_eq(RoomEditModel.label_for(hard, [hard]), "rock", "a hard ledge is rock")

# --- creatures ---

func test_a_creature_is_placed_at_a_snapped_point_and_selected() -> void:
	assert_eq(model.add_spawn("C1", "toad", Vector2(303, 299)), "")
	var s: Dictionary = model.rooms["C1"].spawns.back()
	assert_eq([s["id"], s["pos"]], ["toad", Vector2(304, 300)])
	assert_eq(model.selection["kind"], "spawn")

func test_a_creature_is_refused_in_rock_a_ledge_a_wall_outside_and_for_an_unknown_id() -> void:
	var solid: Rect2 = model.rooms["C1"].solids[0]
	assert_ne(model.add_spawn("C1", "toad", solid.get_center()), "", "inside a solid")
	assert_ne(model.add_spawn("C1", "toad", Vector2(4, 100)), "", "inside the wall")
	assert_ne(model.add_spawn("C1", "toad", Vector2(-50, 100)), "", "outside")
	assert_ne(model.add_spawn("C1", "gorgon", Vector2(300, 100)), "", "unknown id")
	assert_eq(model.undo_depth(), 0)
	var thin := Rect2(400, 200, 80, 12)
	model.rooms["C1"].solids.append(thin)
	assert_ne(model.add_spawn("C1", "toad", Vector2(420, 206)), "", "a ledge counts as rock for placement")

# --- hit-testing ---

func test_hit_prefers_creatures_then_exits_then_the_smallest_solid_and_uses_the_pick_radius() -> void:
	model.rooms["C1"].solids = [Rect2(100, 200, 300, 60), Rect2(150, 200, 40, 20)]
	model.rooms["C1"].spawns = [{"id": "toad", "pos": Vector2(170, 210)}]
	assert_eq(model.hit("C1", Vector2(172, 212), 6.0)["kind"], "spawn")
	model.rooms["C1"].spawns = []
	var h := model.hit("C1", Vector2(170, 210), 0.0)
	assert_eq([h["kind"], h["index"]], ["solid", 1], "the smaller solid wins where they overlap")
	assert_eq(model.hit("C1", Vector2(96, 230), 6.0)["index"], 0, "a click a few pixels outside still picks with a radius")
	assert_eq(model.hit("C1", Vector2(96, 230), 0.0), {}, "and misses without one")
	var edge: Dictionary = model.rooms["C1"].exits[0]
	var band := RoomBuilder.gate_rect(model.rooms["C1"].pixel_size(), edge)
	assert_eq(model.hit("C1", band.get_center(), 0.0)["kind"], "exit")

# --- moving and deleting ---

func _solid_selection(i: int) -> Dictionary:
	return {"room": "C1", "kind": "solid", "index": i}

func test_moving_a_solid_snaps_the_delta_and_never_an_untouched_origin() -> void:
	model.rooms["C1"].solids = [Rect2(101, 202, 54, 22)]
	assert_true(model.begin_move(_solid_selection(0)))
	model.move_to(Vector2(9, 5))
	assert_eq(model.rooms["C1"].solids[0], Rect2(109, 206, 54, 22), "origin 101 + snapped 8, 202 + snapped 4")
	model.end_move()
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_eq(model.rooms["C1"].solids[0], Rect2(101, 202, 54, 22))

func test_a_drag_is_one_step_however_many_motions_and_a_click_pushes_none() -> void:
	model.rooms["C1"].solids = [Rect2(100, 200, 60, 20)]
	model.begin_move(_solid_selection(0))
	for i in 10:
		model.move_to(Vector2(i * 4, 0))
	model.end_move()
	assert_eq(model.undo_depth(), 1)
	model.begin_move(_solid_selection(0))
	model.end_move()
	assert_eq(model.undo_depth(), 1, "press and release without motion pushes nothing")

func test_a_moved_solid_stays_inside_the_room_and_keeps_hard_ledges_consistent() -> void:
	var r: RoomDef = model.rooms["C1"]
	var hard := Rect2(100, 200, 60, 20)
	r.solids = [hard]
	r.hard_ledges = [hard]
	model.begin_move(_solid_selection(0))
	model.move_to(Vector2(-5000, 8))
	model.end_move()
	assert_eq(r.solids[0].position.x, 0.0)
	assert_eq(r.hard_ledges[0], r.solids[0])
	assert_eq(WorldValidator.validate({"C1": r}).filter(func(e): return e.contains("hard ledge")), PackedStringArray())

func test_a_creature_moves_but_never_into_rock() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(300, 200, 60, 60)]
	r.spawns = [{"id": "toad", "pos": Vector2(200, 150)}]
	model.begin_move({"room": "C1", "kind": "spawn", "index": 0})
	model.move_to(Vector2(20, 0))
	assert_eq(r.spawns[0]["pos"], Vector2(220, 150))
	model.move_to(Vector2(120, 60))
	assert_eq(r.spawns[0]["pos"], Vector2(220, 150), "the last valid spot stays while the pointer is over rock")
	model.end_move()

func test_deleting_a_solid_or_a_creature_is_one_undoable_step() -> void:
	var r: RoomDef = model.rooms["C1"]
	var n_solids := r.solids.size()
	model.select(_solid_selection(0))
	assert_eq(model.delete_selection(), "")
	assert_eq(r.solids.size(), n_solids - 1)
	model.undo()
	assert_eq(model.rooms["C1"].solids.size(), n_solids)
	assert_ne(model.delete_selection(), "", "nothing selected after an undo")

# --- the spot Play starts from ---

func test_floor_spot_drops_to_the_first_rock_below_and_refuses_rock_and_no_floor() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(200, 250, 100, 12)]
	var floor_y: float = r.pixel_size().y - RoomDef.FLOOR
	assert_eq(model.floor_spot("C1", Vector2(250, 100)), Vector2(250, 250 - BodyConfig.BOTTOM), "lands on the ledge")
	assert_eq(model.floor_spot("C1", Vector2(120, 100)), Vector2(120, floor_y - BodyConfig.BOTTOM), "lands on the floor")
	assert_null(model.floor_spot("C1", Vector2(250, 255)), "inside rock")
	assert_null(model.floor_spot("C1", Vector2(-10, 100)), "outside the room")
```

The no-floor case is covered in Task B4 (`test_a_room_on_a_bottom_edge_is_connected_but_the_hole_has_no_floor_below`).

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (Parse Error: `add_solid`, `drag_rect`, ... not found).

- [ ] **Step 3: Implement** in `scripts/editor/room_edit_model.gd`:

```gdscript
# --- geometry ---

## A drag's rect: both corners snapped, normalised.
static func drag_rect(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(snap(a.x), snap(a.y)), Vector2.ZERO).expand(Vector2(snap(b.x), snap(b.y)))

## What the builder will make of a solid this size: a one-way ledge you jump up through, or rock.
static func label_for(rect: Rect2, hard: Array = []) -> String:
	return "one-way ledge" if RoomBuilder.is_one_way(rect, hard) else "rock"

## Rects nothing stands inside: interior solids and the boundary walls (the suite's spawn rule), and with `with_gates` the
## gates of closed shortcut exits (what the editor view and Play draw).
func rock(room_id: String, with_gates := false) -> Array:
	var r: RoomDef = rooms[room_id]
	var out: Array = r.solids.duplicate()
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		out.append(w["rect"])
	if with_gates:
		for e in r.exits:
			if e.has("shortcut"):
				out.append(RoomBuilder.gate_rect(r.pixel_size(), e))
	return out

func _in_rock(room_id: String, p: Vector2) -> bool:
	for rect in rock(room_id):
		if (rect as Rect2).has_point(p):
			return true
	return false

func _sel(room_id: String, kind: String, index: int) -> Dictionary:
	return {"room": room_id, "kind": kind, "index": index}

func select(sel: Dictionary) -> void:
	selection = sel

# --- solids and creatures ---

func add_solid(room_id: String, a: Vector2, b: Vector2) -> String:
	var r: RoomDef = rooms[room_id]
	var rect := drag_rect(a, b).intersection(bounds(r))
	if rect.size.x < MIN_SOLID or rect.size.y < MIN_SOLID:
		return "too small, or outside the room"
	var before := _snap([room_id])
	r.solids.append(rect)
	_push(before)
	selection = _sel(room_id, "solid", r.solids.size() - 1)
	return ""

func add_spawn(room_id: String, creature_id: String, pos: Vector2) -> String:
	var r: RoomDef = rooms[room_id]
	if not creature_ids.is_empty() and not creature_ids.has(creature_id):
		return "unknown creature '%s'" % creature_id
	var p := Vector2(snap(pos.x), snap(pos.y))
	if not bounds(r).has_point(p):
		return "outside the room"
	if _in_rock(room_id, p):
		return "inside rock: click open space"
	var before := _snap([room_id])
	r.spawns.append({"id": creature_id, "pos": p})
	_push(before)
	selection = _sel(room_id, "spawn", r.spawns.size() - 1)
	return ""

# --- hit-testing ---

## The element under a room-local point: the nearest creature within `pick`, else an exit's gap, else the smallest solid.
func hit(room_id: String, p: Vector2, pick: float) -> Dictionary:
	var r: RoomDef = rooms[room_id]
	var best := -1
	var best_d := INF
	for i in r.spawns.size():
		var d := (r.spawns[i]["pos"] as Vector2).distance_to(p)
		if d <= pick and d < best_d:
			best = i
			best_d = d
	if best >= 0:
		return _sel(room_id, "spawn", best)
	for i in r.exits.size():
		if RoomBuilder.gate_rect(r.pixel_size(), r.exits[i]).grow(pick).has_point(p):
			return _sel(room_id, "exit", i)
	var area := INF
	best = -1
	for i in r.solids.size():
		var s: Rect2 = r.solids[i]
		if s.grow(pick).has_point(p) and s.get_area() < area:
			area = s.get_area()
			best = i
	return _sel(room_id, "solid", best) if best >= 0 else {}

# --- moving ---

func begin_move(sel: Dictionary) -> bool:
	if sel.is_empty() or not rooms.has(sel["room"]):
		return false
	var r: RoomDef = rooms[sel["room"]]
	var i: int = sel["index"]
	match sel["kind"]:
		"solid":
			if i >= r.solids.size(): return false
			_drag = {"sel": sel, "before": _snap([sel["room"]]), "orig": r.solids[i]}
		"spawn":
			if i >= r.spawns.size(): return false
			_drag = {"sel": sel, "before": _snap([sel["room"]]), "orig": r.spawns[i]["pos"]}
		_:
			return _begin_move_exit(sel)
	selection = sel
	return true

## Moves the dragged element to its original place plus `delta` (snapped). An invalid spot leaves the last valid one.
func move_to(delta: Vector2) -> void:
	if _drag.is_empty():
		return
	var sel: Dictionary = _drag["sel"]
	var r: RoomDef = rooms[sel["room"]]
	var d := snap_delta(delta)
	match sel["kind"]:
		"solid":
			var orig: Rect2 = _drag["orig"]
			var moved := Rect2(orig.position + d, orig.size)
			moved.position = moved.position.clamp(Vector2.ZERO, r.pixel_size() - moved.size)
			var i: int = sel["index"]
			var was: Rect2 = r.solids[i]
			r.solids[i] = moved
			var h := r.hard_ledges.find(was)
			if h >= 0:
				r.hard_ledges[h] = moved
		"spawn":
			var p: Vector2 = (_drag["orig"] as Vector2) + d
			if bounds(r).has_point(p) and not _in_rock(sel["room"], p):
				r.spawns[sel["index"]]["pos"] = p
		_:
			_move_exit_to(d)

func end_move() -> void:
	if _drag.is_empty():
		return
	var before: Dictionary = _drag["before"]
	_drag = {}
	_push(before)

# --- deleting ---

func delete_selection() -> String:
	if selection.is_empty() or not rooms.has(selection["room"]):
		return "nothing selected"
	var r: RoomDef = rooms[selection["room"]]
	var i: int = selection["index"]
	match selection["kind"]:
		"solid":
			if i >= r.solids.size(): return "nothing selected"
			var before := _snap([selection["room"]])
			var gone: Rect2 = r.solids[i]
			r.solids.remove_at(i)
			var h := r.hard_ledges.find(gone)
			if h >= 0:
				r.hard_ledges.remove_at(h)
			_push(before)
		"spawn":
			if i >= r.spawns.size(): return "nothing selected"
			var before := _snap([selection["room"]])
			r.spawns.remove_at(i)
			_push(before)
		_:
			return _delete_exit()
	selection = {}
	return ""

# --- where Play starts ---

## Where Play puts the slime for a click at `p`: the point straight down to the first rock below, a ledge included; null when
## `p` is outside the room or in rock, or nothing is below it. The returned point is the player's origin (feet on the rock).
func floor_spot(room_id: String, p: Vector2) -> Variant:
	if not bounds(rooms[room_id]).has_point(p):
		return null
	var best := INF
	for rect in rock(room_id, true):
		var q: Rect2 = rect
		if q.has_point(p):
			return null
		if p.x >= q.position.x and p.x < q.end.x and q.position.y >= p.y and q.position.y < best:
			best = q.position.y
	if best == INF:
		return null
	return Vector2(p.x, best - BodyConfig.BOTTOM)

# The exit halves of begin_move / move_to / delete are written in Task B3.
func _begin_move_exit(_sel: Dictionary) -> bool:
	return false

func _move_exit_to(_d: Vector2) -> void:
	pass

func _delete_exit() -> String:
	return "nothing selected"
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_model`. Expected: PASS.

- [ ] **Step 5: Mutation checks** (restore each from a copy): remove the `moved.position.clamp` line (the clamp test fails); make `add_spawn` skip `_in_rock` (the refusal test fails); remove `hard_ledges` sync in `move_to` (the consistency test fails); make `end_move` always `_undo.append` (the click test fails).

- [ ] **Step 6: Import and commit (covers B1 and B2)**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs && git commit -m "feat: the room editor model holds deep copies, snapshot undo, solids, creatures, moving and deleting"
```

---

### Task B3: paired exits

**Files:** Modify `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_exits.gd`.

**Interfaces:**
- Produces: `add_exit(a_id: String, edge: String, from: float, to: float, opts := {}) -> String` (`from`/`to` are A-local pixels along the edge; `opts` may carry `gate` and `shortcut`; writes the partner in the room across the edge; `""` or a reason), `partner_of(room_id: String, index: int) -> Dictionary` (`{"room", "index"}` or `{}`; the validator's own rule: opposite edge, `room == room_id`, equal world span), and the exit halves of `begin_move`, `move_to` and `delete_selection`.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_exits.gd`)

```gdscript
extends GutTest
## Exits are written in pairs, in one undo step, by the validator's own rules.

var model: RoomEditModel

func before_each() -> void:
	model = RoomEditModel.new(ShippedRooms.load_all(), ["toad"])

func _errors() -> String:
	return "\n".join(model.validate())

## The exit dict in `room` that points at `to_room`.
func _exit_to(room: String, to_room: String) -> Dictionary:
	for e in model.rooms[room].exits:
		if e["room"] == to_room:
			return e
	return {}

func _remove_pair(a: String, b: String) -> Array:
	var ea := _exit_to(a, b)
	var eb := _exit_to(b, a)
	model.rooms[a].exits.erase(ea)
	model.rooms[b].exits.erase(eb)
	return [ea.duplicate(), eb.duplicate()]

func test_the_shipped_world_validates_clean() -> void:
	assert_eq(_errors(), "")

func test_adding_an_exit_reproduces_the_shipped_c1_c2_pair_exactly() -> void:
	var pair := _remove_pair("C1", "C2")
	assert_eq(model.add_exit("C1", "right", pair[0]["from"], pair[0]["to"]), "")
	assert_eq(_exit_to("C1", "C2"), pair[0])
	assert_eq(_exit_to("C2", "C1"), pair[1], "the partner's local span is right on both axes")
	assert_eq(_errors(), "")

func test_adding_a_shortcut_exit_copies_the_shortcut_to_the_partner() -> void:
	var pair := _remove_pair("C1", "C6")  # C1's top exit to C6 is a shortcut
	assert_true(pair[0].has("shortcut"))
	assert_eq(model.add_exit("C1", "top", pair[0]["from"], pair[0]["to"], {"shortcut": pair[0]["shortcut"]}), "")
	assert_eq(_exit_to("C6", "C1"), pair[1])
	assert_eq(_errors(), "")

func test_the_partner_is_right_for_a_vertical_pair_too() -> void:
	var pair := _remove_pair("C3", "C6")
	assert_eq(model.add_exit("C3", pair[0]["edge"], pair[0]["from"], pair[0]["to"], pair[0].duplicate()), "", "shortcut and gate copied")
	assert_eq(_exit_to("C6", "C3")["from"], pair[1]["from"])
	assert_eq(_errors(), "")

func test_one_add_is_one_undo_step_across_two_rooms() -> void:
	_remove_pair("C1", "C2")
	model.add_exit("C1", "right", 200.0, 320.0)
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.dirty.keys().size(), 2)
	model.undo()
	assert_true(_exit_to("C1", "C2").is_empty())
	assert_true(_exit_to("C2", "C1").is_empty())

func test_the_span_rules_are_the_validators_own() -> void:
	_remove_pair("C1", "C2")
	var h: float = model.rooms["C1"].pixel_size().y
	assert_eq(model.add_exit("C1", "right", h - 120.0, h - RoomDef.FLOOR), "", "a side door flush with the floor: to = height - 40")
	model.undo()
	assert_ne(model.add_exit("C1", "right", h - 120.0, h - 36.0), "", "height - 36 is into the floor")
	assert_ne(model.add_exit("C1", "right", 200.0, 230.0), "", "shorter than 36")
	assert_ne(model.add_exit("C1", "right", 4.0, 100.0), "", "starts inside the corner")
	assert_ne(model.add_exit("C2", "bottom", 60.0, 120.0), "", "no room across that edge covers the span")

func test_an_overlapping_span_is_refused_on_either_side() -> void:
	assert_ne(model.add_exit("C1", "right", 240.0, 300.0), "", "overlaps C1's existing exit to C2")
	assert_eq(model.undo_depth(), 0)

func test_a_span_the_neighbour_does_not_cover_is_refused() -> void:
	# C5 (tall, three screens) borders C4 across its west edge only along C4's range: a span below C4's floor range is refused
	var a: String = "C5"
	var c5: RoomDef = model.rooms[a]
	var refused := 0
	for e in c5.exits:
		if e["edge"] == "left":
			var b: RoomDef = model.rooms[e["room"]]
			var below := WorldValidator.edge_origin(b, "right") + WorldValidator.edge_range(b, "right").y + 40.0
			var from := below - WorldValidator.edge_origin(c5, "left")
			if model.add_exit(a, "left", from, from + 80.0) != "":
				refused += 1
	assert_gt(refused, 0, "a span past the neighbour's range is refused, not written one-sided")
	assert_eq(_errors(), "")

func test_moving_an_exit_moves_its_partner_in_one_step() -> void:
	var idx := 0
	for i in model.rooms["C1"].exits.size():
		if model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	var sel := {"room": "C1", "kind": "exit", "index": idx}
	var before_a: Dictionary = model.rooms["C1"].exits[idx].duplicate()
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(0, -40))
	model.end_move()
	assert_eq(model.rooms["C1"].exits[idx]["from"], before_a["from"] - 40.0)
	assert_eq(_errors(), "", "the partner moved with it")
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_eq(model.rooms["C1"].exits[idx], before_a)
	assert_eq(_errors(), "")

func test_a_move_that_would_leave_the_edge_or_hit_another_exit_stops_at_the_last_valid_spot() -> void:
	var idx := 0
	for i in model.rooms["C1"].exits.size():
		if model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	model.begin_move({"room": "C1", "kind": "exit", "index": idx})
	model.move_to(Vector2(0, 5000))
	model.end_move()
	assert_eq(_errors(), "")
	assert_lte(model.rooms["C1"].exits[idx]["to"], model.rooms["C1"].pixel_size().y - RoomDef.FLOOR)

func test_deleting_an_exit_deletes_its_partner_in_one_step() -> void:
	var idx := 0
	for i in model.rooms["C1"].exits.size():
		if model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	model.select({"room": "C1", "kind": "exit", "index": idx})
	assert_eq(model.delete_selection(), "")
	assert_true(_exit_to("C1", "C2").is_empty())
	assert_true(_exit_to("C2", "C1").is_empty())
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_false(_exit_to("C2", "C1").is_empty())
	assert_eq(_errors(), "")

func test_partner_of_uses_the_validators_rule() -> void:
	var idx := 0
	for i in model.rooms["C1"].exits.size():
		if model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	var p := model.partner_of("C1", idx)
	assert_eq(p["room"], "C2")
	assert_eq(model.rooms["C2"].exits[p["index"]]["room"], "C1")
	model.rooms["C2"].exits[p["index"]]["to"] += 8.0
	assert_true(model.partner_of("C1", idx).is_empty(), "a span that no longer matches is not a partner")
```

While writing `test_the_span_rules_are_the_validators_own`, confirm with `WorldValidator.touches` that C2 has no room beneath it (if it does, pick an edge of a shipped room that has none). In `test_a_span_the_neighbour_does_not_cover_is_refused`, if C5's shipped neighbours do not produce a refused case (a span is refused only when it lies outside the neighbour's range along the shared edge), derive the case from the shipped layout the way the spec's C5/C4 note does; the assertions that matter are that a span past the neighbour's range is refused and that no refused add leaves a validator error.

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`validate`, `add_exit`, `partner_of` not found). Add the wrapper `func validate() -> PackedStringArray: return WorldValidator.validate(rooms, creature_ids)` to the model in Step 3.

- [ ] **Step 3: Implement** in `scripts/editor/room_edit_model.gd` (replace the three `_..._exit` stubs from B2):

```gdscript
func validate() -> PackedStringArray:
	return WorldValidator.validate(rooms, creature_ids)

# --- exits ---

static func _exit(edge: String, from: float, to: float, room: String, opts: Dictionary) -> Dictionary:
	var e := {"edge": edge, "from": from, "to": to, "room": room}
	if opts.has("gate"):
		e["gate"] = opts["gate"]
	if opts.has("shortcut"):
		e["shortcut"] = opts["shortcut"]
	return e

## Does an exit on `edge` of `r` covering [from, to] (r-local) overlap another exit on that edge? `skip` is an index to ignore.
static func _overlaps(r: RoomDef, edge: String, from: float, to: float, skip := -1) -> bool:
	for i in r.exits.size():
		var e: Dictionary = r.exits[i]
		if i != skip and e["edge"] == edge and from < float(e["to"]) and float(e["from"]) < to:
			return true
	return false

static func _within(r: RoomDef, edge: String, from: float, to: float) -> bool:
	var limits := WorldValidator.edge_range(r, edge)
	return from >= limits.x and to <= limits.y and from < to

## The room across `edge` of `a` whose facing edge line coincides with a's and whose allowed range holds the world span.
func _across(a: RoomDef, edge: String, w0: float, w1: float) -> RoomDef:
	var opp: String = WorldValidator.OPPOSITE[edge]
	for id in rooms:
		var b: RoomDef = rooms[id]
		if b == a or not WorldValidator.touches(a.world_rect(), b.world_rect(), edge):
			continue
		var o := WorldValidator.edge_origin(b, opp)
		var limits := WorldValidator.edge_range(b, opp)
		if w0 >= o + limits.x and w1 <= o + limits.y:
			return b
	return null

func add_exit(a_id: String, edge: String, from: float, to: float, opts := {}) -> String:
	if not WorldValidator.OPPOSITE.has(edge):
		return "not an edge"
	var a: RoomDef = rooms[a_id]
	var lo := snap(minf(from, to))
	var hi := snap(maxf(from, to))
	if hi - lo < MIN_EXIT:
		return "too short: an exit is at least %d px" % int(MIN_EXIT)
	if not _within(a, edge, lo, hi):
		return "outside what this edge allows"
	if _overlaps(a, edge, lo, hi):
		return "overlaps another exit"
	var oa := WorldValidator.edge_origin(a, edge)
	var b := _across(a, edge, oa + lo, oa + hi)
	if b == null:
		return "no room across this edge covers that span"
	var opp: String = WorldValidator.OPPOSITE[edge]
	var ob := WorldValidator.edge_origin(b, opp)
	if _overlaps(b, opp, oa + lo - ob, oa + hi - ob):
		return "overlaps an exit in %s" % b.id
	var before := _snap([a_id, b.id])
	a.exits.append(_exit(edge, lo, hi, b.id, opts))
	b.exits.append(_exit(opp, oa + lo - ob, oa + hi - ob, a_id, opts))
	_push(before)
	selection = _sel(a_id, "exit", a.exits.size() - 1)
	return ""

## The exit in the neighbour that answers exit `index` of `room_id`, by the validator's rule: opposite edge, pointing back,
## the same world span. {} when there is none.
func partner_of(room_id: String, index: int) -> Dictionary:
	var a: RoomDef = rooms[room_id]
	var e: Dictionary = a.exits[index]
	var b: RoomDef = rooms.get(e.get("room", ""))
	if b == null or not WorldValidator.OPPOSITE.has(e.get("edge", "")):
		return {}
	var span := WorldValidator.world_span(a, e)
	for i in b.exits.size():
		var f: Dictionary = b.exits[i]
		if f.get("edge", "") == WorldValidator.OPPOSITE[e["edge"]] and f.get("room", "") == room_id \
				and WorldValidator.world_span(b, f).is_equal_approx(span):
			return {"room": b.id, "index": i}
	return {}

func _begin_move_exit(sel: Dictionary) -> bool:
	var r: RoomDef = rooms[sel["room"]]
	var i: int = sel["index"]
	if sel["kind"] != "exit" or i >= r.exits.size():
		return false
	var p := partner_of(sel["room"], i)
	var ids: Array = [sel["room"]]
	if not p.is_empty():
		ids.append(p["room"])
	_drag = {"sel": sel, "before": _snap(ids), "orig": r.exits[i].duplicate(), "partner": p}
	selection = sel
	return true

func _move_exit_to(d: Vector2) -> void:
	var sel: Dictionary = _drag["sel"]
	var a: RoomDef = rooms[sel["room"]]
	var orig: Dictionary = _drag["orig"]
	var edge: String = orig["edge"]
	var axis := d.y if edge == "left" or edge == "right" else d.x
	var lo := float(orig["from"]) + axis
	var hi := float(orig["to"]) + axis
	var i: int = sel["index"]
	if not _within(a, edge, lo, hi) or _overlaps(a, edge, lo, hi, i):
		return
	var p: Dictionary = _drag["partner"]
	if not p.is_empty():
		var b: RoomDef = rooms[p["room"]]
		var opp: String = WorldValidator.OPPOSITE[edge]
		var shift := WorldValidator.edge_origin(a, edge) - WorldValidator.edge_origin(b, opp)
		if not _within(b, opp, lo + shift, hi + shift) or _overlaps(b, opp, lo + shift, hi + shift, p["index"]):
			return
		b.exits[p["index"]]["from"] = lo + shift
		b.exits[p["index"]]["to"] = hi + shift
	a.exits[i]["from"] = lo
	a.exits[i]["to"] = hi

func _delete_exit() -> String:
	var r: RoomDef = rooms[selection["room"]]
	var i: int = selection["index"]
	if i >= r.exits.size():
		return "nothing selected"
	var p := partner_of(selection["room"], i)
	var ids: Array = [selection["room"]]
	if not p.is_empty():
		ids.append(p["room"])
	var before := _snap(ids)
	if not p.is_empty():
		(rooms[p["room"]] as RoomDef).exits.remove_at(p["index"])
	r.exits.remove_at(i)
	_push(before)
	selection = {}
	return ""
```

Note `_delete_exit` and the partner: when partner and exit are in the *same* room's list (impossible: a room cannot border itself), the removal order is safe. Remove the partner first only when it is in a different room; both cases are handled because they are different rooms.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_exits`, `test_room_edit_model`. Expected: PASS.

- [ ] **Step 5: Mutation checks.** In `_move_exit_to` remove the partner update (the "partner moved with it" test fails); in `add_exit` drop the `_overlaps(b, ...)` check (a refusal test needs a case for it: add one that pre-places an exit in B overlapping the span and see it refused); in `_across` replace the range check with `true` (the C5/C4-style test fails).

- [ ] **Step 6: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs && git commit -m "feat: exits are written in pairs, moved and deleted with their partner, by the validator's own rules"
```

---

### Task B4: new rooms beside a room, room ids, every shipped room opens

**Files:** Modify `scripts/editor/room_edit_model.gd`; Append to `tests/test_room_edit_exits.gd` (or a new `tests/test_room_edit_new_room.gd`).

**Interfaces:**
- Produces: `static valid_id(id: String) -> bool`, `id_error(id: String) -> String` (`""` when the id may be used: valid characters, not empty, unique case-insensitively), `new_room_beside(a_id: String, edge: String, new_id: String, area: String, size: Vector2i) -> String`, `static default_door(a: RoomDef, b: RoomDef, edge: String)` is private (`_default_door`).

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_new_room.gd`)

```gdscript
extends GutTest
## A new room is created beside an existing one, level with it, and connected at once.

var model: RoomEditModel

func before_each() -> void:
	model = RoomEditModel.new(ShippedRooms.load_all(), ["toad"])

func test_ids_are_letters_digits_and_underscore_and_unique_case_insensitively() -> void:
	assert_true(RoomEditModel.valid_id("D1"))
	assert_true(RoomEditModel.valid_id("my_room_2"))
	assert_false(RoomEditModel.valid_id(""))
	assert_false(RoomEditModel.valid_id("a b"))
	assert_false(RoomEditModel.valid_id("../x"))
	assert_ne(model.id_error("c1"), "", "c1 collides with C1 on a case-insensitive file system")
	assert_ne(model.id_error("C1"), "")
	assert_eq(model.id_error("Fresh"), "")

func _free_edge(id: String) -> String:
	# an edge of room `id` with nothing across it: try each, return the first that new_room_beside accepts on a scratch model
	for edge in ["right", "left", "top", "bottom"]:
		var m := RoomEditModel.new(ShippedRooms.load_all(), [])
		if m.new_room_beside(id, edge, "Probe", "cave", Vector2i(1, 1)) == "":
			return edge
	return ""

func test_a_room_beside_a_side_edge_is_bottom_aligned_and_connected() -> void:
	var edge := ""
	var a := ""
	for id in ["C4", "G4", "C2", "C1"]:
		for e in ["right", "left"]:
			var m := RoomEditModel.new(ShippedRooms.load_all(), [])
			if m.new_room_beside(id, e, "Probe", "cave", Vector2i(2, 2)) == "":
				a = id
				edge = e
				break
		if a != "":
			break
	assert_ne(a, "", "some shipped room has a free side edge")
	assert_eq(model.new_room_beside(a, edge, "Fresh", "cave", Vector2i(2, 2)), "")
	var r: RoomDef = model.rooms["Fresh"]
	var neighbour: RoomDef = model.rooms[a]
	assert_eq(r.world_rect().end.y, neighbour.world_rect().end.y, "the floors are level")
	assert_eq(r.area, "cave")
	assert_false(r.is_start())
	assert_eq(r.exits.size(), 1)
	assert_eq("\n".join(model.validate()), "", "connected, paired, no overlap")
	assert_true(WorldValidator.reachable(model.rooms).has("Fresh"))

func test_one_new_room_is_one_undo_step_and_undo_removes_it() -> void:
	var edge := _free_edge("C1")
	assert_ne(edge, "")
	model.new_room_beside("C1", edge, "Fresh", "cave", Vector2i(1, 1))
	assert_eq(model.undo_depth(), 1)
	assert_true(model.dirty.has("Fresh"))
	model.undo()
	assert_false(model.rooms.has("Fresh"))
	assert_false(model.dirty.has("Fresh"))
	assert_eq("\n".join(model.validate()), "")
	model.redo()
	assert_true(model.rooms.has("Fresh"))

func test_a_room_that_would_overlap_another_is_refused() -> void:
	var refused := 0
	for edge in ["right", "left", "top", "bottom"]:
		for id in model.rooms.keys():
			if model.new_room_beside(id, edge, "Fresh%d" % refused, "cave", Vector2i(4, 4)) != "":
				refused += 1
	assert_gt(refused, 0, "a 4x4 room collides with a neighbour somewhere")
	assert_eq("\n".join(model.validate()), "")

func test_a_bad_id_a_bad_area_or_a_bad_size_is_refused_and_writes_nothing() -> void:
	assert_ne(model.new_room_beside("C1", "right", "c1", "cave", Vector2i(1, 1)), "")
	assert_ne(model.new_room_beside("C1", "right", "Fresh", "nowhere", Vector2i(1, 1)), "")
	assert_ne(model.new_room_beside("C1", "right", "Fresh", "cave", Vector2i(0, 1)), "")
	assert_eq(model.undo_depth(), 0)

func test_a_room_on_a_bottom_edge_is_connected_but_the_hole_has_no_floor_below() -> void:
	var edge_found := ""
	var host := ""
	for id in model.rooms.keys():
		var m := RoomEditModel.new(ShippedRooms.load_all(), [])
		if m.new_room_beside(id, "bottom", "Probe", "cave", Vector2i(1, 1)) == "":
			host = id
			break
	assert_ne(host, "", "some room has nothing beneath it")
	assert_eq(model.new_room_beside(host, "bottom", "Fresh", "cave", Vector2i(1, 1)), "")
	assert_eq("\n".join(model.validate()), "")
	var e: Dictionary = model.rooms[host].exits.filter(func(x): return x["room"] == "Fresh")[0]
	var mid: float = (float(e["from"]) + float(e["to"])) / 2.0
	var h: float = model.rooms[host].pixel_size().y
	assert_null(model.floor_spot(host, Vector2(mid, h - 60.0)), "nothing below the hole: Play refuses")

func test_the_default_door_keeps_64px_clear_of_rock_in_the_neighbour() -> void:
	var host := "C1"
	for edge in ["right", "left", "top", "bottom"]:
		var m := RoomEditModel.new(ShippedRooms.load_all(), [])
		if m.new_room_beside(host, edge, "Fresh", "cave", Vector2i(1, 1)) != "":
			continue
		var a: RoomDef = m.rooms[host]
		var e: Dictionary = a.exits.filter(func(x): return x["room"] == "Fresh")[0]
		var size := a.pixel_size()
		var strip: Rect2
		match edge:
			"right": strip = Rect2(size.x - RoomEditModel.KEEP_CLEAR, e["from"], RoomEditModel.KEEP_CLEAR, e["to"] - e["from"])
			"left": strip = Rect2(0, e["from"], RoomEditModel.KEEP_CLEAR, e["to"] - e["from"])
			"top": strip = Rect2(e["from"], 0, e["to"] - e["from"], RoomEditModel.KEEP_CLEAR)
			_: strip = Rect2(e["from"], size.y - RoomEditModel.KEEP_CLEAR, e["to"] - e["from"], RoomEditModel.KEEP_CLEAR)
		for s in a.solids:
			assert_false((s as Rect2).intersects(strip), "%s edge: solid %s in the strip" % [edge, s])

func test_every_shipped_room_opens_in_the_model_and_round_trips_its_data() -> void:
	for id in ShippedRooms.IDS:
		assert_true(RoomEditModel.same_room(ShippedRooms.load_all()[id], model.rooms[id]), id)
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`valid_id`, `id_error`, `new_room_beside` not found).

- [ ] **Step 3: Implement**

```gdscript
# --- new rooms ---

const DOOR := 80.0
const MAX_SCREENS := 6
static var _id_rx: RegEx

static func valid_id(id: String) -> bool:
	if _id_rx == null:
		_id_rx = RegEx.new()
		_id_rx.compile("^[A-Za-z0-9_]+$")
	return _id_rx.search(id) != null

func id_error(id: String) -> String:
	if not valid_id(id):
		return "an id is letters, digits and underscore"
	for k in rooms:
		if String(k).to_lower() == id.to_lower():
			return "'%s' is already a room (ids differ by more than case)" % k
	return ""

## A new room across `edge` of `a_id`: bottom-aligned beside a side edge (level floors), left-aligned above or below.
## Created with the paired exit toward its neighbour, in one undo step. Returns "" or the reason.
func new_room_beside(a_id: String, edge: String, new_id: String, area: String, size: Vector2i) -> String:
	if not WorldValidator.OPPOSITE.has(edge):
		return "not an edge"
	var err := id_error(new_id)
	if err != "":
		return err
	if not TerrainArt.has_biome(area):
		return "unknown area '%s'" % area
	if size.x < 1 or size.y < 1 or size.x > MAX_SCREENS or size.y > MAX_SCREENS:
		return "a room is 1 to %d screens each way" % MAX_SCREENS
	var a: RoomDef = rooms[a_id]
	var cell: Vector2i
	match edge:
		"right": cell = Vector2i(a.cell.x + a.size.x, a.cell.y + a.size.y - size.y)
		"left": cell = Vector2i(a.cell.x - size.x, a.cell.y + a.size.y - size.y)
		"bottom": cell = Vector2i(a.cell.x, a.cell.y + a.size.y)
		_: cell = Vector2i(a.cell.x, a.cell.y - size.y)
	var b := RoomDef.new()
	b.id = new_id
	b.area = area
	b.cell = cell
	b.size = size
	for id in rooms:
		if (rooms[id] as RoomDef).world_rect().intersects(b.world_rect()):
			return "would overlap %s" % id
	var door := _default_door(a, b, edge)
	if door.x < 0.0:
		return "no free span for a door on that edge"
	var opp: String = WorldValidator.OPPOSITE[edge]
	var oa := WorldValidator.edge_origin(a, edge)
	var ob := WorldValidator.edge_origin(b, opp)
	var before := _snap([a_id, new_id])
	a.exits.append(_exit(edge, door.x, door.y, new_id, {}))
	b.exits.append(_exit(opp, oa + door.x - ob, oa + door.y - ob, a_id, {}))
	rooms[new_id] = b
	_push(before)
	selection = {}
	return ""

## A door of DOOR px along the shared edge (A-local from/to as a Vector2), inside both rooms' allowed range, clear of A's
## exits, with KEEP_CLEAR px in front of it free of A's interior solids. Side edges try from the floor upward; top and bottom
## edges from the middle outward. (-1, -1) when nothing fits.
func _default_door(a: RoomDef, b: RoomDef, edge: String) -> Vector2:
	var opp: String = WorldValidator.OPPOSITE[edge]
	var oa := WorldValidator.edge_origin(a, edge)
	var ob := WorldValidator.edge_origin(b, opp)
	var la := WorldValidator.edge_range(a, edge)
	var lb := WorldValidator.edge_range(b, opp)
	var lo := maxf(oa + la.x, ob + lb.x)
	var hi := minf(oa + la.y, ob + lb.y)
	var candidates: Array = []
	if edge == "left" or edge == "right":
		var w := hi - DOOR
		while w >= lo:
			candidates.append(w)
			w -= 20.0
	else:
		var mid := snap((lo + hi) / 2.0 - DOOR / 2.0)
		var step := 0.0
		while mid - step >= lo or mid + step + DOOR <= hi:
			if mid + step + DOOR <= hi:
				candidates.append(mid + step)
			if step > 0.0 and mid - step >= lo:
				candidates.append(mid - step)
			step += 20.0
	for w in candidates:
		var from: float = snap(w) - oa
		var to := from + DOOR
		if from < la.x or to > la.y or _overlaps(a, edge, from, to):
			continue
		if not _clear_in_front(a, edge, from, to):
			continue
		return Vector2(from, to)
	return Vector2(-1.0, -1.0)

func _clear_in_front(a: RoomDef, edge: String, from: float, to: float) -> bool:
	var size := a.pixel_size()
	var strip: Rect2
	match edge:
		"right": strip = Rect2(size.x - KEEP_CLEAR, from, KEEP_CLEAR, to - from)
		"left": strip = Rect2(0, from, KEEP_CLEAR, to - from)
		"top": strip = Rect2(from, 0, to - from, KEEP_CLEAR)
		_: strip = Rect2(from, size.y - KEEP_CLEAR, to - from, KEEP_CLEAR)
	for s in a.solids:
		if (s as Rect2).intersects(strip):
			return false
	return true
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_new_room`, `test_room_edit_exits`, `test_room_edit_model`. Expected: PASS. If a shipped room's edge is fully blocked the search-based tests still find another; a test that finds no host fails loudly (the messages say so).

- [ ] **Step 5: Mutation checks.** Skip the `_clear_in_front` call (the 64 px test fails on a room with a solid near its door); use the top-aligned cell for side edges (the level-floors test fails); make `id_error` case-sensitive (the `c1` assertion fails).

- [ ] **Step 6: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs && git commit -m "feat: a new room is created beside a room, level with it and connected"
```

---

### Task B5: save

**Files:** Modify `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_save.gd`.

**Interfaces:**
- Produces: `save_dirty(dir: String) -> Dictionary` returning `{"saved": Array of ids, "errors": Dictionary id -> message}`; each saved room leaves the dirty set, each failed one stays in it.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_save.gd`)

```gdscript
extends GutTest
## Save writes each edited room with ResourceSaver and reads back equal.

const TMP := "res://.tmp/room_edit_save_test"

var model: RoomEditModel

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	model = RoomEditModel.new(ShippedRooms.load_all(), ["toad"])

func after_each() -> void:
	var d := DirAccess.open(TMP)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))

func _load(id: String) -> RoomDef:
	return ResourceLoader.load("%s/%s.tres" % [TMP, id], "RoomDef", ResourceLoader.CACHE_MODE_IGNORE)

func test_an_edited_room_saves_and_reloads_equal_and_only_it_is_written() -> void:
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	model.add_spawn("C1", "toad", Vector2(300, 100))
	var result := model.save_dirty(TMP)
	assert_eq(result["saved"], ["C1"])
	assert_eq(result["errors"], {})
	assert_true(RoomEditModel.same_room(model.rooms["C1"], _load("C1")))
	assert_false(FileAccess.file_exists("%s/C2.tres" % TMP), "an untouched room is not written")
	assert_true(model.dirty.is_empty())

func test_a_room_with_features_dressing_and_a_nested_kit_round_trips() -> void:
	for id in ["C1", "G1"]:
		model.dirty[id] = true
	model.save_dirty(TMP)
	for id in ["C1", "G1"]:
		assert_true(RoomEditModel.same_room(model.rooms[id], _load(id)), id)

func test_a_failed_save_names_the_room_and_leaves_it_dirty() -> void:
	model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	var result := model.save_dirty("res://.tmp/does/not/exist/anywhere")
	assert_eq(result["saved"], [])
	assert_true(result["errors"].has("C1"))
	assert_true(model.dirty.has("C1"))

func test_a_new_room_saves_and_its_partner_edit_too() -> void:
	var edge := ""
	for e in ["right", "left", "top", "bottom"]:
		var m := RoomEditModel.new(ShippedRooms.load_all(), [])
		if m.new_room_beside("C1", e, "Fresh", "cave", Vector2i(1, 1)) == "":
			edge = e
			break
	assert_ne(edge, "")
	model.new_room_beside("C1", edge, "Fresh", "cave", Vector2i(1, 1))
	var result := model.save_dirty(TMP)
	result["saved"].sort()
	assert_eq(result["saved"], ["C1", "Fresh"])
	var reloaded := {}
	for id in ShippedRooms.IDS:
		reloaded[id] = _load(id) if id == "C1" else ResourceLoader.load("res://data/rooms/%s.tres" % id, "RoomDef")
	reloaded["Fresh"] = _load("Fresh")
	assert_eq("\n".join(WorldValidator.validate(reloaded)), "")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`save_dirty` not found).

- [ ] **Step 3: Implement**

```gdscript
## Writes each dirty room to `<dir>/<id>.tres` with ResourceSaver (the call the generator used). Rooms save independently: a
## failure leaves that room dirty and the others written. Returns {"saved": [ids], "errors": {id: message}}.
func save_dirty(dir: String) -> Dictionary:
	var saved: Array = []
	var errors := {}
	for id in dirty.keys():
		if not rooms.has(id):
			dirty.erase(id)
			continue
		var err := ResourceSaver.save(rooms[id], "%s/%s.tres" % [dir, id])
		if err == OK:
			saved.append(id)
			dirty.erase(id)
		else:
			errors[id] = error_string(err)
	return {"saved": saved, "errors": errors}
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_save`. Expected: PASS. Also try (a spike, not a required pin): save an untouched shipped room to `TMP` and compare the file text with `res://data/rooms/C1.tres`; if they are byte-identical, add `test_an_unedited_room_saves_byte_identical` (proof the eject leaves no git noise); if not, record the difference in the ledger as a `Ruling:` (the first real Save rewrites every room it touches).

- [ ] **Step 5: Mutation check.** Make `save_dirty` erase `dirty` unconditionally (the failed-save test fails).

- [ ] **Step 6: Full suite and commit (end of milestone B)**

```bash
tools/run_tests.sh   # Expected: PASS
git add scripts tests tools docs && git commit -m "feat: the room editor model saves its edited rooms and reads them back equal"
```

---

## Milestone C: the Game seam and the launcher

### Task C1: `Game.play_request`, `Game.editor_resume`, the return path

**Files:** Modify `scripts/game.gd`; Create `scripts/editor/editor_return.gd`, `scripts/editor/room_editor.gd` (skeleton), `scenes/room_editor.tscn`, `tests/test_editor_play.gd`.

**Interfaces:**
- Produces: `Game.play_request` (static Dictionary: `{"rooms": Dictionary, "room": String, "pos": Vector2}`), `Game.editor_resume` (static, `null` or `{"model": RoomEditModel, "room": String, "view": Dictionary}`), `Game.EDITOR_SCENE := "res://scenes/room_editor.tscn"`, `Game.return_to_editor()`, member `_editor_play`; `EditorReturn` (a child node that returns on F5); `RoomEditor` (skeleton) with `var model: RoomEditModel`, `var room_id: String`, `var view_state: Dictionary`.

- [ ] **Step 1: Write the failing tests** (`tests/test_editor_play.gd`)

```gdscript
extends GutTest
## Play from the editor: the real game on the working rooms, sandboxed from the real progress, and back.

var model: RoomEditModel
var game: Game

func before_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	model = RoomEditModel.new(ShippedRooms.load_all(), ["toad"])

func after_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	get_tree().paused = false
	SkillRules.reset_run()
	Announcer.queue.clear()
	var scene := get_tree().current_scene
	if scene != null:
		scene.queue_free()
		get_tree().current_scene = null

func _play(room_id := "C2", pos := Vector2(200, 250)) -> Game:
	Game.play_request = {"rooms": model.rooms, "room": room_id, "pos": pos}
	Game.editor_resume = {"model": model, "room": room_id, "view": {"zoom": 2.0}}
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	return game

func test_the_request_starts_the_world_at_the_spot_on_the_edited_geometry_and_is_cleared() -> void:
	model.add_solid("C2", Vector2(400, 200), Vector2(480, 216))
	await _play("C2", Vector2(200, 250))
	assert_eq(Game.play_request, {}, "consumed")
	assert_eq(game.world.current_id, "C2")
	assert_eq(game.world.rooms, model.rooms, "the world runs on the working set")
	var rect: Rect2 = model.rooms["C2"].world_rect()
	assert_almost_eq(game.player.global_position, rect.position + Vector2(200, 250), Vector2(2, 2))
	assert_true((game.world.rooms["C2"] as RoomDef).solids.has(Rect2(400, 200, 80, 16)))

func test_without_a_request_the_game_is_unchanged() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_eq(game.world.current_id, "C1")
	assert_eq(game.world.ctx["progress"], Compendium.progress)

func test_the_play_world_has_its_own_progress_and_the_real_one_is_untouched() -> void:
	var visited_before: Array = Compendium.progress.visited.duplicate()
	var shortcuts_before: Array = Compendium.progress.shortcuts.duplicate()
	await _play("C2")
	var progress = game.world.ctx["progress"]
	assert_not_null(progress)
	assert_ne(progress, Compendium.progress)
	assert_null(progress.profile, "no profile: it saves nothing")
	game.world.enter("C1")
	game.world.enter("C2")
	game.world.ctx["progress"].open("c6_drop")
	assert_eq(Compendium.progress.visited, visited_before)
	assert_eq(Compendium.progress.shortcuts, shortcuts_before)

func test_a_death_returns_to_the_editor_without_the_menu_and_the_model_is_unchanged() -> void:
	Compendium.progress.attune("G1")
	Compendium.progress.attune("C3")
	await _play("C2")
	var menus := 0
	game.run.choice_needed.connect(func(_d: Dictionary) -> void: menus += 1)
	var before := RoomEditModel.copy_room(model.rooms["C2"])
	game.player.health.take_hit(999, "physical")
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.6)
	Compendium.progress.rebirths.erase("G1")
	Compendium.progress.rebirths.erase("C3")
	assert_eq(menus, 0)
	var scene := get_tree().current_scene
	assert_true(scene is RoomEditor, "back in the editor, not a reloaded game")
	assert_eq((scene as RoomEditor).model, model, "the whole model came back")
	assert_true(RoomEditModel.same_room(before, model.rooms["C2"]))
	assert_eq(Game.editor_resume, null, "consumed by the editor")

func test_f5_returns_to_the_editor_even_while_the_skill_screen_pauses_the_tree() -> void:
	await _play("C2")
	get_tree().paused = true
	var ev := InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	get_viewport().push_input(ev)
	await wait_process_frames(3)
	await wait_seconds(0.2)
	assert_false(get_tree().paused, "unpaused on the way out")
	assert_true(get_tree().current_scene is RoomEditor)

func test_f5_is_ignored_while_the_death_card_shows_and_on_key_repeat() -> void:
	await _play("C2")
	var repeat := InputEventKey.new()
	repeat.keycode = KEY_F5
	repeat.pressed = true
	repeat.echo = true
	get_viewport().push_input(repeat)
	await wait_process_frames(3)
	assert_null(get_tree().current_scene if get_tree().current_scene is RoomEditor else null, "an echo does nothing")
	game.player.health.take_hit(999, "physical")
	await wait_process_frames(3)
	assert_true(game.run.death_card_visible())
	var ev := InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	get_viewport().push_input(ev)
	await wait_process_frames(3)
	assert_false(get_tree().current_scene is RoomEditor, "F5 does nothing under the death card")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (Parse Error: `Game.play_request`, `RoomEditor`).

- [ ] **Step 3: Implement.**

`scripts/game.gd`:

```gdscript
const EDITOR_SCENE := "res://scenes/room_editor.tscn"

## Set by the room editor before it changes to main.tscn, consumed and cleared by _ready:
## {"rooms": Dictionary, "room": String, "pos": Vector2} (the player's origin, room-local). Statics, not scene state, so both
## scenes reach them.
static var play_request := {}
## What the editor gets back when Play ends: {"model": RoomEditModel, "room": String, "view": Dictionary}. Consumed by the
## editor's _ready.
static var editor_resume = null

var _editor_play := false
```

In `_ready` (keep the order of everything else): after `world = World.new(); add_child(world)`:

```gdscript
	var request := Game.play_request
	Game.play_request = {}
	_editor_play = not request.is_empty()
	var rooms: Dictionary = request["rooms"] if _editor_play else World.load_rooms(ROOMS_DIR)
	# The editor's Play runs on a fresh in-memory progress, so nothing it visits or opens reaches the real profile.
	var progress = WorldProgress.new() if _editor_play else Compendium.progress
	if not _editor_play:
		for e in WorldValidator.validate(rooms, _creatures.keys()):
			push_error(e)
```

replace `var rooms := World.load_rooms(ROOMS_DIR)` and the validate loop with the block above; replace every `Compendium.progress` below (in the `world.setup` context, `sanitize`, `take_pending`, `is_attuned`, `bind_world`) with `progress`; replace the start block:

```gdscript
	var pools := RebirthChoice.pools(rooms)
	progress.sanitize(pools.map(func(p: Dictionary) -> String: return p["id"]))
	var start := {"default": false, "room": request["room"], "pos": request["pos"], "kit": {}} if _editor_play \
		else Game.resolve_start(pools, progress.take_pending(), progress.is_attuned)
```

and bind the run without progress in an editor session: `run.bind(player, world, null if _editor_play else Compendium.progress, pools)`. At the end of `_ready` add:

```gdscript
	if _editor_play:
		var back := EditorReturn.new()
		back.game = self
		add_child(back)
```

`_restart` and the new function:

```gdscript
func _restart() -> void:
	if _editor_play:
		return_to_editor()
		return
	_prepare_restart()
	get_tree().reload_current_scene.call_deferred()

## The end of an editor Play: the same clean-up as a restart, then back to the editor scene (the model waits in editor_resume).
func return_to_editor() -> void:
	_prepare_restart()
	Audio.reset()
	get_tree().change_scene_to_file.call_deferred(EDITOR_SCENE)
```

`scripts/editor/editor_return.gd`:

```gdscript
class_name EditorReturn
extends Node
## F5 during an editor Play returns to the editor. It runs while the tree is paused (the skill screen pauses it), ignores key
## repeats, and does nothing under the death card (the run is already returning).

var game: Game

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F5 or game == null:
		return
	if game.run != null and game.run.death_card_visible():
		return
	get_viewport().set_input_as_handled()
	game.return_to_editor()
```

`scripts/editor/room_editor.gd` (skeleton; the view arrives in Milestone D):

```gdscript
class_name RoomEditor
extends Node
## The room editor scene root. Task C1: it only takes its model back from Game.editor_resume; the view and panels follow.

var model: RoomEditModel
var room_id := ""
var view_state := {}

func _ready() -> void:
	var resume = Game.editor_resume
	Game.editor_resume = null
	if resume != null:
		model = resume["model"]
		room_id = resume["room"]
		view_state = resume["view"]
	else:
		var ids: Array = SkillRules.creature_defs.map(func(c: CreatureDef) -> String: return c.id)
		model = RoomEditModel.new(World.load_rooms("res://data/rooms"), ids)
		room_id = "C1"
```

`scenes/room_editor.tscn`: a `Node` named `RoomEditor` with the script (create with the same text form as `scenes/main.tscn`).

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_editor_play`, `test_game`, `test_rebirth_flow`, `test_run`, `test_grotto_flow`. Expected: PASS. If the real `change_scene_to_file` does not behave under GUT (`current_scene` null), keep the assertion on the changed scene by checking `get_tree().root.get_children()` for a `RoomEditor`, and record the way in the ledger.

- [ ] **Step 5: Mutation checks.** Bind `run` with `Compendium.progress` in an editor session (the menu test must fail with two pools attuned); pass `Compendium.progress` to the world in an editor session (the untouched-progress test fails); drop `process_mode` from `EditorReturn` (the paused F5 test fails).

- [ ] **Step 6: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs scenes && git commit -m "feat: the editor can play a room in the real game on unsaved rooms and come back to the same model"
```

---

### Task C2: the launcher and the sandbox check

**Files:** Create `tools/edit_rooms.sh`; Modify `scripts/editor/room_editor.gd`; Append to `tests/test_editor_play.gd`.

**Interfaces:**
- Produces: `RoomEditor.in_sandbox(user_dir: String, root: String) -> bool` (static, pure), `RoomEditor.sandbox_root` (static, `""` means "derive from `HOME`"), `RoomEditor.sandbox_ok() -> bool`.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_editor_play.gd`)

```gdscript
func test_in_sandbox_is_a_directory_prefix_test() -> void:
	var root := "/x/.tmp/editor-home"
	assert_true(RoomEditor.in_sandbox("/x/.tmp/editor-home/Library/Application Support/Godot/app_userdata/Slime", root))
	assert_true(RoomEditor.in_sandbox("/x/.tmp/editor-home", root))
	assert_true(RoomEditor.in_sandbox("/x/.tmp/editor-home/", root))
	assert_false(RoomEditor.in_sandbox("/x/.tmp/editor-home2/Library", root), "a sibling that shares the prefix")
	assert_false(RoomEditor.in_sandbox("/Users/sean/Library/Application Support/Godot/app_userdata/Slime", root))
	assert_false(RoomEditor.in_sandbox("/x/.tmp/editor-home/Library", ""), "an empty root is never a sandbox")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`in_sandbox` not found).

- [ ] **Step 3: Implement** in `room_editor.gd`:

```gdscript
## Tests inject a root; "" means HOME from the environment.
static var sandbox_root := ""

## Is `user_dir` (OS.get_user_data_dir()) inside `root`? A trailing-slash prefix test, so `editor-home2` is not inside
## `editor-home`.
static func in_sandbox(user_dir: String, root: String) -> bool:
	if root == "":
		return false
	var r := root.trim_suffix("/")
	var u := user_dir.trim_suffix("/")
	return u == r or u.begins_with(r + "/")

## True when the editor was launched through tools/edit_rooms.sh (its HOME is `.tmp/editor-home` of this checkout), so Play
## cannot write the real profile.
static func sandbox_ok() -> bool:
	var root := sandbox_root if sandbox_root != "" else OS.get_environment("HOME")
	if not root.ends_with("/.tmp/editor-home"):
		return false
	return in_sandbox(OS.get_user_data_dir(), root)
```

`tools/edit_rooms.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# Open the room editor. HOME is pointed at .tmp/editor-home so user:// (the profile, the bestiary, the audio settings) is a
# throwaway directory: Play from the editor can never write the real save. Delete .tmp/editor-home to reset that profile.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tmp/editor-home
exec env -u XDG_DATA_HOME HOME="$PWD/.tmp/editor-home" godot --path . res://scenes/room_editor.tscn
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_editor_play`. Then run the script once by hand for two seconds (`timeout 5 tools/edit_rooms.sh` from a shell that has a display) and confirm `.tmp/editor-home/Library/Application Support/Godot/app_userdata/Slime Isekai Prototype` exists.

- [ ] **Step 5: Commit**

```bash
chmod +x tools/edit_rooms.sh
git add scripts tests tools docs scenes && git commit -m "feat: tools/edit_rooms.sh launches the editor in a sandboxed HOME; Play refuses outside it"
```

---

## Milestone D: the view, the tools and the panels

### Task D1: the room view and coordinates

**Files:** Create `scripts/editor/room_view.gd`, `tests/test_room_editor_scene.gd`; Modify `scripts/editor/room_editor.gd` and `scenes/room_editor.tscn`.

**Interfaces:**
- Produces: `RoomView` (a `Node2D` in the root viewport with a `Camera2D`): `show_room(model: RoomEditModel, room_id: String)` (rebuilds the RoomBuilder node at the origin, `progress = null`, no spawns, and a per-area `CanvasModulate` matching `TerrainArt.ambient(area, Game.AMBIENT)`), `to_room(screen: Vector2) -> Vector2`, `to_screen(room_pt: Vector2) -> Vector2`, `fit()`, `one_to_one()`, `pan(delta_screen: Vector2)`, `zoom_by(factor: float, around: Vector2)`, `overlay: Node2D` (a `follow_viewport` `CanvasLayer`'s child for markers and outlines, untinted), `pick_radius() -> float` (8 screen px in room px), `state() -> Dictionary` (`{"zoom", "center"}`) and `restore(state: Dictionary)`.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_editor_scene.gd`, part 1; build the view directly, no full editor yet)

```gdscript
extends GutTest
## The room view: the game's own builder through a camera, and clicks mapped back to the room.

var model: RoomEditModel
var view: RoomView

func before_each() -> void:
	model = RoomEditModel.new(ShippedRooms.load_all(), ["toad"])
	view = RoomView.new()
	add_child_autofree(view)
	view.show_room(model, "C1")
	await wait_process_frames(2)

func test_the_view_builds_the_room_the_way_the_game_does() -> void:
	var built := view.room_node()
	assert_not_null(built)
	assert_eq(built.name, "C1")
	assert_eq(built.position, Vector2.ZERO, "the room sits at the origin, not its world position")
	assert_eq(built.get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy).size(), 0, "no live enemies")

func test_the_gates_of_closed_shortcuts_draw_closed() -> void:
	var closed := 0
	for e in model.rooms["C1"].exits:
		if e.has("shortcut"):
			closed += 1
	assert_gt(closed, 0)
	assert_eq(view.room_node().get_tree().get_nodes_in_group("gate_%s" % model.rooms["C1"].exits.filter(func(e): return e.has("shortcut"))[0]["shortcut"]).size(), 1)

func test_screen_and_room_points_map_both_ways() -> void:
	for p in [Vector2(10, 10), Vector2(320, 180), Vector2(600, 300)]:
		var screen := view.to_screen(p)
		assert_almost_eq(view.to_room(screen), p, Vector2(0.01, 0.01))

func test_fit_shows_the_whole_room_and_one_to_one_is_a_zoom_of_one() -> void:
	view.fit()
	await wait_process_frames(1)
	var size: Vector2 = model.rooms["C1"].pixel_size()
	var tl := view.to_screen(Vector2.ZERO)
	var br := view.to_screen(size)
	assert_true(Rect2(Vector2.ZERO, Vector2(640, 360)).encloses(Rect2(tl, br - tl)), "the whole room is on screen")
	view.one_to_one()
	await wait_process_frames(1)
	assert_almost_eq(view.to_screen(Vector2(100, 0)).x - view.to_screen(Vector2.ZERO).x, 100.0, 0.01)

func test_pan_moves_the_view_by_screen_pixels() -> void:
	var before := view.to_screen(Vector2(100, 100))
	view.pan(Vector2(30, -20))
	await wait_process_frames(1)
	assert_almost_eq(view.to_screen(Vector2(100, 100)) - before, Vector2(30, -20), Vector2(0.01, 0.01))

func test_the_pick_radius_is_eight_screen_pixels() -> void:
	view.one_to_one()
	assert_almost_eq(view.pick_radius(), 8.0, 0.01)
	view.zoom_by(2.0, Vector2(320, 180))
	assert_almost_eq(view.pick_radius(), 4.0, 0.01)

func test_state_round_trips() -> void:
	view.zoom_by(2.0, Vector2(320, 180))
	var s := view.state()
	var other := RoomView.new()
	add_child_autofree(other)
	other.show_room(model, "C1")
	other.restore(s)
	await wait_process_frames(1)
	assert_almost_eq(other.to_screen(Vector2(200, 200)), view.to_screen(Vector2(200, 200)), Vector2(0.01, 0.01))
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`RoomView` not found).

- [ ] **Step 3: Implement** `scripts/editor/room_view.gd`. Contract and the parts that are easy to get wrong:

```gdscript
class_name RoomView
extends Node2D
## The room as the game draws it, seen through a Camera2D in the root viewport. Overlays (markers, selection outlines, the
## drag rect) live on a follow_viewport CanvasLayer so the per-area CanvasModulate does not dim them.

const PICK_PX := 8.0
const ZOOM_MIN := 0.25
const ZOOM_MAX := 4.0

var camera := Camera2D.new()
var overlay := Node2D.new()
var _model: RoomEditModel
var _room_id := ""
var _room: Node2D
var _tint := CanvasModulate.new()
var _overlay_layer := CanvasLayer.new()

func _ready() -> void:
	camera.name = "Camera"
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT   # position is the room point at the screen's top-left
	add_child(camera)
	camera.make_current()
	add_child(_tint)
	_overlay_layer.follow_viewport_enabled = true
	_overlay_layer.layer = 5
	add_child(_overlay_layer)
	_overlay_layer.add_child(overlay)

func show_room(model: RoomEditModel, room_id: String) -> void:
	_model = model
	_room_id = room_id
	if _room != null:
		_room.queue_free()
	var def: RoomDef = model.rooms[room_id]
	_room = RoomBuilder.build_room(def, {"progress": null})
	_room.position = Vector2.ZERO
	add_child(_room)
	_tint.color = TerrainArt.ambient(def.area, Game.AMBIENT)
	fit()

func room_node() -> Node2D:
	return _room

func to_room(screen: Vector2) -> Vector2:
	return camera.position + screen / camera.zoom.x

func to_screen(room_pt: Vector2) -> Vector2:
	return (room_pt - camera.position) * camera.zoom.x

func pick_radius() -> float:
	return PICK_PX / camera.zoom.x

func fit() -> void:
	var size: Vector2 = _model.rooms[_room_id].pixel_size()
	var z := minf(640.0 / size.x, 360.0 / size.y)
	camera.zoom = Vector2(z, z)
	camera.position = (size - Vector2(640, 360) / z) / 2.0

func one_to_one() -> void:
	var c := to_room(Vector2(320, 180))
	camera.zoom = Vector2.ONE
	camera.position = c - Vector2(320, 180)

func pan(delta_screen: Vector2) -> void:
	camera.position -= delta_screen / camera.zoom.x

func zoom_by(factor: float, around: Vector2) -> void:
	var before := to_room(around)
	var z := clampf(camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	camera.position = before - around / z

func state() -> Dictionary:
	return {"zoom": camera.zoom.x, "position": camera.position}

func restore(s: Dictionary) -> void:
	if s.has("zoom"):
		camera.zoom = Vector2(float(s["zoom"]), float(s["zoom"]))
		camera.position = s.get("position", camera.position)
```

Notes for the implementer: `Camera2D` with `ANCHOR_MODE_FIXED_TOP_LEFT` makes `position` the room point at the viewport's top-left, which keeps `to_room`/`to_screen` linear and testable headless (no canvas-transform frame delay); if `camera.position` is not applied until a frame, keep the tests' `await wait_process_frames(1)`. The zoom of the canvas_items stretch is not involved because all positions are in the 640x360 viewport space. `to_room`/`to_screen` are pure functions of `camera` so tests do not depend on the canvas transform. `Game.AMBIENT` is a const on `Game`; reference it as `Game.AMBIENT`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs scenes && git commit -m "feat: the room view draws a room with the game's builder through a camera"
```

---

### Task D2: tools, markers, overlays and input

**Files:** Modify `scripts/editor/room_view.gd`; Append to `tests/test_room_editor_scene.gd`.

**Interfaces:**
- Produces on `RoomView`: `tool: String` (`"select"`, `"solid"`, `"creature"`, `"exit"`), `creature_id: String`, `signal changed` (the model was edited: the room is rebuilt), `signal message(text: String)`, `signal selection_changed`, and `func handle_event(event: InputEvent) -> bool` (mouse press, motion, release and wheel; the editor root calls it from `_unhandled_input`). Behaviour: Select picks with `model.hit(room, to_room(p), pick_radius())`, drags with `begin_move`/`move_to(total room-space delta)`/`end_move`, Delete or Backspace deletes; Solid drags a rect with the live label shown in the overlay and on release calls `add_solid`; Creature places on click; Exit drags along the nearest edge of the room to the press point and calls `add_exit(room, edge, from, to)` on release; middle-drag and two-finger scroll pan; wheel with Ctrl or pinch zooms. After each accepted edit the room node is rebuilt (`show_room`-style rebuild that keeps the camera), and refusals emit `message`.
- Markers: creature markers are static (the sheet's first frame when `SpriteSheet.available(id)`, else `Art.texture(id)`, else a labelled `ColorRect`); a spawn whose id is unknown to the model's `creature_ids` draws as a red box; the selection is an outline; exits draw their span in the overlay in a distinct colour and gate/shortcut exits with a marker.

- [ ] **Step 1: Write the failing tests** (append; events pushed with `view.handle_event`, positions from `view.to_screen`)

```gdscript
func _press(p: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = view.to_screen(p)
	return e

func _release(p: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := _press(p, button)
	e.pressed = false
	return e

func _motion(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = view.to_screen(p)
	return e

func test_the_solid_tool_drags_a_rect_with_a_live_label_and_writes_it_on_release() -> void:
	view.tool = "solid"
	view.handle_event(_press(Vector2(100, 100)))
	view.handle_event(_motion(Vector2(180, 116)))
	assert_eq(view.live_label(), "one-way ledge")
	view.handle_event(_motion(Vector2(180, 160)))
	assert_eq(view.live_label(), "rock")
	view.handle_event(_release(Vector2(180, 160)))
	assert_true(model.rooms["C1"].solids.has(Rect2(100, 100, 80, 60)))
	assert_eq(model.undo_depth(), 1)
	await wait_process_frames(2)
	assert_eq(view.room_node().name, "C1", "the room was rebuilt")

func test_the_creature_tool_places_a_marker_and_refuses_rock_with_a_message() -> void:
	view.tool = "creature"
	view.creature_id = "toad"
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	var solid: Rect2 = model.rooms["C1"].solids[0]
	view.handle_event(_press(solid.get_center()))
	view.handle_event(_release(solid.get_center()))
	assert_eq(messages.size(), 1)
	assert_eq(model.undo_depth(), 0)
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	assert_eq(model.rooms["C1"].spawns.back()["id"], "toad")

func test_select_picks_drags_and_deletes_with_the_keyboard() -> void:
	view.tool = "select"
	model.rooms["C1"].solids = [Rect2(100, 200, 60, 20)]
	view.handle_event(_press(Vector2(120, 210)))
	view.handle_event(_motion(Vector2(160, 210)))
	view.handle_event(_release(Vector2(160, 210)))
	assert_eq(model.rooms["C1"].solids[0], Rect2(140, 200, 60, 20))
	assert_eq(model.undo_depth(), 1)
	var del := InputEventKey.new()
	del.keycode = KEY_DELETE
	del.pressed = true
	view.handle_event(del)
	assert_eq(model.rooms["C1"].solids.size(), 0)

func test_a_click_on_nothing_clears_the_selection_and_pushes_nothing() -> void:
	view.tool = "select"
	model.select({"room": "C1", "kind": "solid", "index": 0})
	view.handle_event(_press(Vector2(5, 5)))
	view.handle_event(_release(Vector2(5, 5)))
	assert_eq(model.selection, {})
	assert_eq(model.undo_depth(), 0)

func test_the_exit_tool_drags_along_the_nearest_edge_and_writes_the_pair() -> void:
	for e in model.rooms["C1"].exits.duplicate():
		if e["room"] == "C2":
			var pair := model.partner_of("C1", model.rooms["C1"].exits.find(e))
			model.rooms["C2"].exits.remove_at(pair["index"])
			model.rooms["C1"].exits.erase(e)
	view.tool = "exit"
	var w: float = model.rooms["C1"].pixel_size().x
	view.handle_event(_press(Vector2(w - 3.0, 200)))
	view.handle_event(_motion(Vector2(w - 3.0, 320)))
	view.handle_event(_release(Vector2(w - 3.0, 320)))
	assert_eq(model.rooms["C1"].exits.filter(func(e): return e["room"] == "C2").size(), 1)
	assert_eq("\n".join(model.validate()), "")

func test_middle_drag_pans_and_the_wheel_with_control_zooms() -> void:
	var before := view.to_screen(Vector2(100, 100))
	view.handle_event(_press(Vector2(200, 200), MOUSE_BUTTON_MIDDLE))
	var m := _motion(Vector2(200, 200))
	m.relative = Vector2(20, 10)
	m.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	view.handle_event(m)
	assert_almost_eq(view.to_screen(Vector2(100, 100)) - before, Vector2(20, 10), Vector2(0.5, 0.5))
	var zoom_before := view.camera.zoom.x
	var wheel := _press(Vector2(200, 200), MOUSE_BUTTON_WHEEL_UP)
	wheel.ctrl_pressed = true
	view.handle_event(wheel)
	assert_gt(view.camera.zoom.x, zoom_before)

func test_a_creature_marker_is_static_and_an_unknown_id_is_red() -> void:
	model.rooms["C1"].spawns.append({"id": "gorgon", "pos": Vector2(300, 100)})
	view.show_room(model, "C1")
	await wait_process_frames(1)
	var markers := view.markers()
	assert_gt(markers.size(), 0)
	assert_eq(view.room_node().get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy).size(), 0)
	assert_true(markers.any(func(m): return m.get_meta("unknown", false)), "the unknown id is marked")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`tool`, `handle_event`, `live_label`, `markers` not found).

- [ ] **Step 3: Implement** the tool state machine in `RoomView`:

```gdscript
signal changed
signal message(text: String)
signal selection_changed

var tool := "select"
var creature_id := ""

var _press_room := Vector2.ZERO      # room-space point of the press
var _dragging := false
var _panning := false
var _rect_live := Rect2()            # the Solid tool's drag, or the Exit tool's span (as a rect on the edge)
var _live_text := ""
var _exit_edge := ""

func live_label() -> String:
	return _live_text

func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _button(event)
	if event is InputEventMouseMotion:
		return _motion(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_report(_model.delete_selection())
			return true
	return false
```

with `_button`/`_motion` implementing, per tool: **select** — press: `sel := _model.hit(room, p, pick_radius())`; if `sel.is_empty()`: `_model.select({})`, `selection_changed.emit()`; else `_model.select(sel)`, `_model.begin_move(sel)`, `_dragging = true`; motion while `_dragging`: `_model.move_to(p - _press_room)` and refresh the room + overlay; release: `_model.end_move()`, `changed.emit()`. **solid** — press stores `_press_room`; motion updates `_rect_live = RoomEditModel.drag_rect(_press_room, p).intersection(bounds)` and `_live_text = RoomEditModel.label_for(_rect_live, hard)`; release calls `_model.add_solid(room, _press_room, p)` and reports. **creature** — release at the press point calls `_model.add_spawn(room, creature_id, p)`; a non-empty result goes to `message` (the room is not rebuilt). **exit** — press picks the nearest edge (`left`, `right`, `top`, `bottom` by the distance from the press point to each edge of the room, ties to the first), stores `_exit_edge`; release calls `_model.add_exit(room, _exit_edge, along(_press_room), along(p))` where `along` is the y coordinate for a side edge and x for a top or bottom edge (the model sorts and snaps); a refusal goes to `message`. **any tool** — middle-button press starts `_panning`; motion with `button_mask & MOUSE_BUTTON_MASK_MIDDLE` calls `pan(event.relative)`; `MOUSE_BUTTON_WHEEL_UP/DOWN` with Ctrl (or Meta) zooms by 1.1 or 1/1.1 around the pointer, without a modifier pans vertically (a trackpad two-finger scroll also arrives as `InputEventPanGesture`: pan by its `delta` times 8; and `InputEventMagnifyGesture` zooms by its `factor`).

`_report(err)`: a non-empty `err` emits `message(err)`; success emits `changed` and rebuilds through `refresh()`:

```gdscript
func refresh() -> void:
	var s := state()
	show_room(_model, _room_id)
	restore(s)
	_redraw_overlay()
```

`_redraw_overlay()` clears `overlay`'s children and adds: one static marker per spawn (`_marker(spawn)`: a `Sprite2D` of `SpriteSheet.load_set(id).frame_texture(first frame)` when `SpriteSheet.available(id)`, else `Art.texture(id)` when it exists, else a labelled `ColorRect` 12x12; unknown ids get a red `ColorRect` with `set_meta("unknown", true)`; each marker is `add_to_group("editor_marker")`), one line per exit span along its edge, the selection outline (`Line2D` around the selected element's rect or a circle around a marker), the live rect while dragging (`_rect_live`) with its label, and the live exit span. `markers() -> Array` returns the nodes in group `editor_marker` under `overlay`. Keep `refresh()` cheap: it is called on every accepted edit and on each drag motion (a drag rebuilds the overlay only; the room is rebuilt once on release).

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Mutation checks.** Skip `_model.end_move()` on release (the drag test fails); use the press point instead of the nearest edge (the exit test fails); draw markers as live `Enemy` nodes (the no-actors test fails).

- [ ] **Step 6: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs scenes && git commit -m "feat: the editor's tools draw solids, place creatures, add exits and move things through the view"
```

---

### Task D3: panels

**Files:** Create `scripts/editor/editor_panels.gd`; Append to `tests/test_room_editor_scene.gd`.

**Interfaces:**
- Produces: `EditorPanels` (a `CanvasLayer`, layer 10, laid out in 640x360): a top bar with **room selector** (`OptionButton` of the model's ids, plus a `*` on dirty rooms), tool buttons (**Select**, **Solid**, **Creature**, **Exit**; hotkeys 1-4 are optional and not tested), **Undo**, **Redo**, **Fit room**, **1:1**, **Validate**, **Save**, **Play**, **New room...**; a left **creature palette** (an `ItemList` of `creature_ids`, shown for the Creature tool); a right **Validate list** (`ItemList` of the errors, hidden until Validate runs); a bottom **status bar** (`Label`: the room id, tool, the live label, the last message, `OS.get_user_data_dir()`); the **New room dialog** (a `ConfirmationDialog` with a neighbour edge, id `LineEdit`, area `OptionButton`, size in screens two `SpinBox`es, and the sentence "A room below or above a neighbour cuts a hole in its floor or ceiling: it is connected but not walkable until you add ledges.").
- Signals: `tool_chosen(name: String)`, `creature_chosen(id: String)`, `room_chosen(id: String)`, `undo_pressed`, `redo_pressed`, `fit_pressed`, `one_to_one_pressed`, `validate_pressed`, `save_pressed`, `play_pressed`, `new_room_requested(edge: String, id: String, area: String, size: Vector2i)`. Methods: `set_rooms(ids: Array, dirty: Dictionary)`, `set_status(text: String)`, `show_validation(errors: PackedStringArray)`, `set_tool(name: String)`, `id_error_for(model, text) -> String` is not needed (the dialog asks `RoomEditModel.id_error`).

- [ ] **Step 1: Write the failing tests** (append)

```gdscript
func _panels() -> EditorPanels:
	var p := EditorPanels.new()
	add_child_autofree(p)
	p.setup(model)
	await wait_process_frames(1)
	return p

func test_the_panels_list_rooms_creatures_and_mark_dirty_rooms() -> void:
	var p := await _panels()
	model.dirty["C2"] = true
	p.set_rooms(model.rooms.keys(), model.dirty)
	assert_true(p.room_labels().has("C2 *"))
	assert_true(p.room_labels().has("C1"))
	assert_eq(p.palette_ids(), ["toad"])

func test_pressing_the_buttons_emits_the_signals() -> void:
	var p := await _panels()
	watch_signals(p)
	p.press("Undo")
	p.press("Redo")
	p.press("Fit room")
	p.press("1:1")
	p.press("Validate")
	p.press("Save")
	p.press("Play")
	for s in ["undo_pressed", "redo_pressed", "fit_pressed", "one_to_one_pressed", "validate_pressed", "save_pressed", "play_pressed"]:
		assert_signal_emitted(p, s)
	p.press("Solid")
	assert_signal_emitted_with_parameters(p, "tool_chosen", ["solid"])

func test_the_validate_list_shows_the_validators_errors() -> void:
	var p := await _panels()
	model.rooms["C1"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	p.show_validation(model.validate())
	assert_true(p.validation_lines().any(func(l): return l.contains("unknown room 'Z'")))
	p.show_validation(PackedStringArray())
	assert_eq(p.validation_lines(), ["No problems found."] , "a clean world says so")

func test_the_new_room_dialog_refuses_a_taken_id_and_emits_a_valid_request() -> void:
	var p := await _panels()
	watch_signals(p)
	p.open_new_room("right")
	p.set_new_room_fields("c1", "cave", Vector2i(1, 1))
	assert_true(p.new_room_error().length() > 0, "c1 collides with C1")
	p.set_new_room_fields("Fresh", "cave", Vector2i(2, 1))
	assert_eq(p.new_room_error(), "")
	p.confirm_new_room()
	assert_signal_emitted_with_parameters(p, "new_room_requested", ["right", "Fresh", "cave", Vector2i(2, 1)])

func test_the_status_bar_shows_the_sandbox_directory_and_the_message() -> void:
	var p := await _panels()
	p.set_status("saved 2 rooms")
	assert_string_contains(p.status_text(), "saved 2 rooms")
	assert_string_contains(p.status_text(), OS.get_user_data_dir())
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`EditorPanels` not found).

- [ ] **Step 3: Implement** `scripts/editor/editor_panels.gd` as a `CanvasLayer` that builds its controls in `setup(model)` with plain `Button`, `OptionButton`, `ItemList`, `Label` and `ConfirmationDialog` nodes at 640x360 (a `HBoxContainer` toolbar at the top, height 24; the palette at left width 96 under the toolbar; the validation list at right width 200; the status label at the bottom, height 16). Add the test helpers used above as ordinary public methods: `press(label: String)` finds the button by its text and calls `pressed.emit()`; `room_labels()`, `palette_ids()`, `validation_lines()`, `status_text()`, `open_new_room(edge)`, `set_new_room_fields(id, area, size)`, `new_room_error() -> String` (uses `_model.id_error(id)` plus the size limits), `confirm_new_room()` (emits `new_room_requested` only when the error is empty and closes the dialog). Palette selection emits `creature_chosen(id)`; room selection emits `room_chosen(id)`. `show_validation` shows `"No problems found."` for an empty list. Style: the project's default theme; nothing decorative.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs scenes && git commit -m "feat: the editor's panels: toolbar, creature palette, validate list, status bar and the new-room dialog"
```

---

### Task D4: the editor scene, shortcuts, Save, Play and the round trip

**Files:** Modify `scripts/editor/room_editor.gd`, `scenes/room_editor.tscn`; Append to `tests/test_room_editor_scene.gd` and `tests/test_editor_play.gd`.

**Interfaces:**
- Produces: `RoomEditor` assembles a `RoomView`, an `EditorPanels` and a small `RoomDirty` title (window title `Room editor - <room>[*]`); `_unhandled_input(event)` forwards mouse events to `view.handle_event`; `_unhandled_key_input(event)` handles Cmd/Ctrl+Z (undo), Shift+Cmd/Ctrl+Z (redo), Cmd/Ctrl+S (save), F5 (play from the pointer), F (fit), and typing in a room-id field never triggers any (the dialog's `LineEdit` takes the key events first; verify with a test). Methods: `save()` (calls `model.save_dirty("res://data/rooms")`, shows `saved N rooms` or the per-room errors in the status bar, refreshes dirty marks), `play()` (uses the pointer position or the view centre: `model.floor_spot`, refuses with "click open floor" when null, refuses with "launch the editor with tools/edit_rooms.sh" when `not RoomEditor.sandbox_ok()`, refuses when the model's validator reports an exit to an unknown room; otherwise sets `Game.play_request` and `Game.editor_resume = {"model": model, "room": room_id, "view": view.state()}` and `change_scene_to_file("res://scenes/main.tscn")`), `open_room(id)`, `new_room(edge, id, area, size)` (calls the model, then `open_room(id)`).

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd`)

```gdscript
func _editor() -> RoomEditor:
	Game.editor_resume = null
	var ed: RoomEditor = load("res://scenes/room_editor.tscn").instantiate()
	add_child_autofree(ed)
	await wait_process_frames(3)
	return ed

func after_each_editor() -> void:
	pass

func test_the_scene_boots_on_c1_with_a_view_and_panels_and_draws_a_solid_from_events() -> void:
	var ed := await _editor()
	assert_eq(ed.room_id, "C1")
	assert_not_null(ed.view)
	assert_not_null(ed.panels)
	ed.panels.press("Solid")
	var a := ed.view.to_screen(Vector2(100, 100))
	var b := ed.view.to_screen(Vector2(200, 116))
	for ev in [_button_at(a, true), _motion_at(b), _button_at(b, false)]:
		get_viewport().push_input(ev)
	await wait_process_frames(2)
	assert_true(ed.model.rooms["C1"].solids.has(Rect2(100, 100, 100, 16)))
	assert_true(ed.view.room_node().get_child_count() > 0)

func _button_at(screen: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = screen
	return e

func _motion_at(screen: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = screen
	return e

func test_the_keyboard_shortcuts_undo_redo_and_save_and_typing_an_id_does_nothing() -> void:
	var ed := await _editor()
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	var z := InputEventKey.new()
	z.keycode = KEY_Z
	z.pressed = true
	z.ctrl_pressed = true
	get_viewport().push_input(z)
	await wait_process_frames(1)
	assert_eq(ed.model.undo_depth(), 0)
	var typed := InputEventKey.new()
	typed.keycode = KEY_Z
	typed.pressed = true
	typed.ctrl_pressed = true
	ed.panels.open_new_room("right")
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	ed.panels.focus_new_room_id()
	get_viewport().push_input(typed)
	await wait_process_frames(1)
	assert_eq(ed.model.undo_depth(), 1, "typing in the id field does not undo")

func test_play_refuses_in_rock_outside_the_sandbox_and_with_an_exit_to_a_missing_room() -> void:
	var ed := await _editor()
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	var solid: Rect2 = ed.model.rooms["C1"].solids[0]
	assert_string_contains(ed.play_error(solid.get_center()), "click open floor")
	RoomEditor.sandbox_root = "/nowhere/.tmp/editor-home"
	assert_string_contains(ed.play_error(Vector2(300, 100)), "tools/edit_rooms.sh")
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	ed.model.rooms["C1"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	assert_string_contains(ed.play_error(Vector2(300, 100)), "unknown room")
	RoomEditor.sandbox_root = ""

func test_save_writes_the_edited_rooms_to_the_data_directory_it_is_given() -> void:
	var ed := await _editor()
	ed.save_dir = "res://.tmp/editor_scene_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ed.save_dir))
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	ed.save()
	assert_true(FileAccess.file_exists("%s/C1.tres" % ed.save_dir))
	assert_string_contains(ed.panels.status_text(), "saved 1 room")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/C1.tres" % ed.save_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ed.save_dir))
```

and to `tests/test_editor_play.gd` the round-trip test the spec names:

```gdscript
func test_the_editor_plays_and_returns_and_save_after_the_round_trip_writes_the_edit() -> void:
	Game.editor_resume = null
	var ed: RoomEditor = load("res://scenes/room_editor.tscn").instantiate()
	add_child_autofree(ed)
	await wait_process_frames(3)
	ed.open_room("C2")
	ed.model.add_solid("C2", Vector2(400, 200), Vector2(480, 216))
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	assert_eq(ed.play_error(Vector2(200, 100)), "")
	ed.play(Vector2(200, 100))
	await wait_process_frames(3)
	await wait_physics_frames(3)
	var g := get_tree().current_scene
	assert_true(g is Game, "the real game")
	assert_eq((g as Game).world.current_id, "C2")
	(g as Game).return_to_editor()
	await wait_seconds(0.5)
	var back := get_tree().current_scene as RoomEditor
	assert_not_null(back)
	assert_eq(back.model, ed.model)
	assert_true(back.model.dirty.has("C2"), "the dirty set survived")
	back.save_dir = "res://.tmp/editor_roundtrip_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(back.save_dir))
	back.save()
	var reloaded := ResourceLoader.load("%s/C2.tres" % back.save_dir, "RoomDef", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_true(reloaded.solids.has(Rect2(400, 200, 80, 16)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/C2.tres" % back.save_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(back.save_dir))
	RoomEditor.sandbox_root = ""
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`view`, `panels`, `play_error`, `save`, `save_dir`, `open_room`, `play` not found).

- [ ] **Step 3: Implement** `RoomEditor` (replace the skeleton): `var view: RoomView`, `var panels: EditorPanels`, `var save_dir := "res://data/rooms"`; `_ready` builds `view` (added first, so the room draws under the panels) and `panels` (`setup(model)`), wires the signals (`tool_chosen` to `view.tool` and the palette, `undo_pressed` to `model.undo()` then `view.refresh()`, `fit_pressed`, `one_to_one_pressed`, `validate_pressed` to `panels.show_validation(model.validate())`, `save_pressed` to `save()`, `play_pressed` to `play(view.to_room(get_viewport().get_mouse_position()))`, `room_chosen` to `open_room`, `new_room_requested` to `new_room`, and `view.message` to `panels.set_status`, `view.changed` to update the dirty marks and the window title), restores the view state from `Game.editor_resume` when present, and forwards `_unhandled_input` mouse events to `view.handle_event`. `_unhandled_key_input` reads the shortcuts (`event.is_command_or_control_pressed()` covers Cmd on macOS and Ctrl elsewhere): a `LineEdit` that has focus consumes its own key events in `_gui_input`, so the shortcut handler never sees them; the test `focus_new_room_id()` (a helper on `EditorPanels` that opens the dialog's id field and grabs focus) proves it. `play_error(pos: Vector2) -> String` returns `""` or the first refusal in the order: not in the sandbox (`"launch the editor with tools/edit_rooms.sh so Play cannot touch your save"`), an exit to an unknown room (`"an exit points at an unknown room: fix it (Validate lists it)"`), no floor (`"click open floor"`). `play(pos)` calls `play_error`, shows a refusal in the status bar, else builds the request exactly as in Task C1 and calls `get_tree().change_scene_to_file("res://scenes/main.tscn")`. `save()` uses `save_dir`, reports `saved N room(s)` and each error `"<id>: <message>"`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`, `test_editor_play`. Expected: PASS.

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs scenes && git commit -m "feat: the editor scene: shortcuts, save, and Play with a refusal for rock, a missing sandbox and a broken exit"
```

---

### Task D5: look at it

**Files:** Create `tools/editor_shots.gd` (a windowed `-s` script, like `tools/aim_shots.gd`), commit the shots under `.tmp/` only (not committed).

- [ ] **Step 1:** Write `tools/editor_shots.gd` (`extends SceneTree`; run as `env HOME="$PWD/.tmp/editor-home" godot --path . -s tools/editor_shots.gd`, windowed, so `get_texture()` works): instantiate `res://scenes/room_editor.tscn`, wait frames, save `get_root().get_texture().get_image()` as `.tmp/<dir>/editor_c1.png`; open room `C2`, add a solid and a toad through the model, refresh, save `editor_c2_edited.png`; then start a `Game` with `Game.play_request` for that room and save `play_c2.png` after 60 physics frames. `root.get_node("...")` for autoloads (bare autoload names do not resolve in `-s` scripts).
- [ ] **Step 2:** Run it (unsandboxed, it needs a window). Read the three PNGs with the Read tool and check: the room is drawn as in the game, the palette and toolbar are legible and do not cover the room's interesting parts at fit zoom, the solid shows its label while dragging (take one frame mid-drag), the toad marker is a sprite not a box, the played room shows the edited solid. Fix what looks wrong (layout numbers, colours) and re-shoot; record the final look in the ledger.
- [ ] **Step 3:** Commit the script: `git add tools && git commit -m "tools: screenshots of the room editor and a room played from it"`.

---

## Milestone E: retire the generator

### Task E1: delete `tools/build_world.gd`, write `docs/rooms.md`, fix the headers

**Files:** Delete `tools/build_world.gd`; Create `docs/rooms.md`; Modify `scripts/world/room_def.gd`, `tools/prefabs.gd`.

- [ ] **Step 1: Write the failing test** (`tests/test_room_edit_model.gd`, append)

```gdscript
func test_the_generator_is_gone_and_no_code_refers_to_it() -> void:
	assert_false(FileAccess.file_exists("res://tools/build_world.gd"))
	for path in ["res://scripts/world/room_def.gd", "res://tools/prefabs.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("build_world"), path)
```

- [ ] **Step 2: Run to verify it fails** (the file exists and two headers name it).
- [ ] **Step 3: Move what only `build_world.gd` held.** `G_GLOW` (`const G_GLOW := Color(0.5, 1.0, 0.6)  # the Grotto's glowing fungus and spores`) goes next to the colour constants in `tools/prefabs.gd`; nothing else in `build_world.gd` is used elsewhere (`grep -rn "BuildWorld\|build_world\|G_GLOW" scripts tests tools`, expected: only the file itself and the two header comments). Write `docs/rooms.md` from `tools/build_world.gd`'s comments before deleting it (read the whole file once; copy, do not paraphrase away): a short intro (the `.tres` files in `data/rooms` are the source of truth; edit them with `tools/edit_rooms.sh`; the older dated plans refer to the retired generator), then a section per topic: the edge and one-way rules (floor top = height - 40, walls 20 thick; a thin solid of at most 24 px tall and wider than 24 is a one-way ledge; how to make a thin one rock from below with `hard_ledges`), the dressing depth bands, C1's start at y 308, C5's entry-ledge headroom, the G1 and G3 ledge chains topping at y 14, G2's and G3's overhangs as mass rather than ledges, G3's hanging chimney wall (the only thing that makes the G5 exit need Wall Cling physically: moving it changes the game and no test catches it), and one line per room (C1..C6, G1..G5) with its name and intent as `build_world.gd` states them. Update the two headers to say the room data lives in `data/rooms` and is edited by `tools/edit_rooms.sh`. Delete `tools/build_world.gd` (`git rm`).
- [ ] **Step 4: Run to verify it passes and the suite is green:** `tools/run_tests.sh`. Expected: PASS.
- [ ] **Step 5: Commit**

```bash
git add scripts tests tools docs && git commit -m "chore: retire the room generator; the room data is the source of truth and docs/rooms.md keeps its rationale"
```

### Task E2: playtest checklist and the final suite

**Files:** Modify `docs/playtest-checklist.md`.

- [ ] **Step 1:** Add lines to `docs/playtest-checklist.md` (hands-on; the headless suite cannot judge them): launch `tools/edit_rooms.sh` (the status bar shows a path inside `.tmp/editor-home`); open C2, drag a Solid (the label says ledge or rock as you drag) and drop a toad; add an exit on a free edge and see its partner appear in the neighbour (Validate is clean); press F5 on open floor and the real game starts there with your edits; die (no menu) or press F5 (also from the skill screen) to return with the same model; Cmd/Ctrl+Z undoes the whole exit in one step; Save writes only edited rooms (`git status` shows them); New room beside a room shows the level floors and a working door; Validate names a room nothing leads to; launching the editor without the script leaves editing and Save working and refuses Play with the reason.
- [ ] **Step 2:** Run the full suite. Expected: PASS.
- [ ] **Step 3: Commit**

```bash
git add docs && git commit -m "docs: playtest lines for the room editor"
```

---

## Final steps

Whole-branch review with an opus reviewer (`review-package` per the executing-plans skill; give it the Review Focus above verbatim and the spec), one fix pass (each fix RED to GREEN, suite green), a real windowed look at the editor and at a played room (Task D5's shots re-run on the merged tree), then `finishing-a-development-branch`: merge to `main`, run the full suite on the merged tree, push, relaunch the game.
