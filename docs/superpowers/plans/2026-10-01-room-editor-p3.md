# Room Editor P3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, inline) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Sean author a complete room in a new biome (`deep`, `flooded`) in the room editor: biomes from data, exact solid numbers and the hard-ledge toggle, a Decor tool, selection through overlapping things, and an exit `gate` / tablet `hint`.

**Architecture:** The model (`RoomEditModel`) gains the `decor` kind, `hit_all`, `surface_above`, a single solid writer (`_put_solid`) and solid / gate / hint fields; `DecorLib` is a new catalog of the 46 decor sprites; the view gains an Alt-press selection and a 3 px drag threshold; the inspector gains number, checkbox and string-choice controls and a `refresh()`; lint gains `decor_unknown` and a stricter `over_hole`; the validator gains `GATES` and a gate-pair check.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1. Tests: `tools/run_tests.sh [substr]` (full suite ~3 min). Import after adding a `class_name` script: `env HOME="$PWD/.tmp/gdhome" godot --headless --import`, then commit its `.uid`.

**Spec:** `docs/superpowers/specs/2026-10-01-room-editor-p3-design.md` (approved after four debate rounds; its Rulings 1-11 bind this plan).

## Global Constraints

- Tabs, `##` doc comments, names as in the surrounding code; no attribution lines in commit messages.
- A plain press in the Select tool behaves exactly as in P2 (`hit` = `hit_all[0]`); only an Alt/Option press selects through.
- A decor piece hits its **un-grown** drawn box (no `pick`); features and solids keep their grown boxes.
- Typed numbers are never snapped; a refused edit changes nothing and returns a reason string.
- Every refusal and every new undo step has one mutation (change the code, watch exactly its test go red, restore).
- Existing tests that assert old behaviour are rewritten **on purpose** and named in their task: `test_over_hole_skips_an_exit_with_a_gate_or_a_shortcut` (Task 12) and `test_selecting_a_feature_shows_its_inspector_and_a_solid_hides_it` (Task 7).
- Scene tests hide GUT's UI (`_gut_ui(false)` in `test_room_editor_scene.gd`), push viewport-coordinate mouse events with `get_viewport().push_input(ev, true)`, and do not click palette item rects (unlaid-out headless; the shots tool covers them). GUT counts a Godot engine error (for example `grab_focus` on a `FOCUS_NONE` control) as a failure.
- Do not push, merge or delete anything until the final steps.

## Review Focus

1. A plain press on a ledge beside or under a decor piece taking the decor, or any P2 press-drag changing (the un-grown decor box; the 3 px threshold; Alt is the only way to select through).
2. The solid inspector committing or showing a wrong number: SpinBox built value-before-range (every ledge at x >= 260 reading 100), a refresh after a Grow clamping to the old maximum, a refresh overwriting a focused field, a refresh committing.
3. Identical solids or a stolen `hard` mark through any path: add, drag onto an identical marked solid, typed set, thin-to-thick.
4. A hand-edited unknown decor id: the room builds, a click elsewhere still selects, its fallback box can be clicked, outlined, centred on from the problems list and deleted; `over_hole` measures real decor width.
5. Gate: both halves written and undone together; an unknown gate refused and flagged; a gated bottom exit counting as a hole for creatures and decor without flagging any shipped data (C3).

---

## Milestone A: Biomes

### Task 1: Biomes from data

**Files:** Modify `scripts/world/terrain_art.gd`, `scripts/editor/editor_panels.gd`, `scripts/editor/world_view.gd`, `tests/test_world_view.gd`; Create `tests/test_terrain_art.gd`, `tests/test_new_room_biomes.gd`.

**Interfaces:** Produces `TerrainArt.biomes() -> Array` (sorted names under `res://assets/tiles/` that `has_biome` accepts), `EditorPanels.areas() -> Array` (static, replaces the `AREAS` const; its three uses and the declaration change), `WorldView.AREA_FILL` entries for `deep` and `flooded`.

- [ ] **Step 1: Write the failing tests**

`tests/test_terrain_art.gd`:
```gdscript
extends GutTest
## TerrainArt: which biomes the art supports.

func test_biomes_lists_the_directories_that_have_terrain_art_sorted() -> void:
	assert_eq(TerrainArt.biomes(), ["cave", "deep", "flooded", "grotto"])

func test_has_biome_is_false_for_a_name_with_no_art() -> void:
	assert_false(TerrainArt.has_biome("no_such_biome"))
```

`tests/test_new_room_biomes.gd`:
```gdscript
extends GutTest
## A new room in every biome the art supports builds and validates, so a biome's art needs no code change to be offered.

func test_a_new_room_in_every_biome_builds_and_the_world_stays_valid() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	for biome in TerrainArt.biomes():
		var model := RoomEditModel.new(ShippedRooms.load_all(), ids)
		assert_eq(model.new_room_beside("C6", "left", "NB", biome, Vector2i(1, 1)), "", biome)
		var built := RoomBuilder.build_room(model.rooms["NB"], {"progress": null})
		assert_not_null(built, biome)
		add_child_autofree(built)
		assert_eq("\n".join(model.validate()), "", biome)

func test_the_new_room_dialog_offers_every_biome() -> void:
	assert_eq(EditorPanels.areas(), TerrainArt.biomes())
```

Append to `tests/test_world_view.gd`:
```gdscript
func test_every_biome_has_a_colour_on_the_overview() -> void:
	for biome in TerrainArt.biomes():
		assert_true(WorldView.AREA_FILL.has(biome), "%s needs an AREA_FILL entry" % biome)
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_terrain_art` etc. Expected: FAIL (`biomes` / `areas` not found).

- [ ] **Step 3: Implement.** In `terrain_art.gd`, after `has_biome`:
```gdscript
## The biomes with terrain art: the directory names under res://assets/tiles/ that has_biome accepts, sorted.
static func biomes() -> Array:
	var out: Array = []
	for d in DirAccess.get_directories_at("res://assets/tiles"):
		if has_biome(d):
			out.append(d)
	out.sort()
	return out
```
In `editor_panels.gd` replace `const AREAS := ["cave", "grotto"]` with
```gdscript
## The areas New room offers: every biome the terrain art supports.
static func areas() -> Array:
	return TerrainArt.biomes()
```
and change `for a in AREAS:` to `for a in areas():`, `AREAS.find(area)` to `areas().find(area)`, `AREAS[_new_area.selected]` to `areas()[_new_area.selected]`. In `world_view.gd` add to `AREA_FILL`: `"deep": Color(0.3, 0.35, 0.55), "flooded": Color(0.2, 0.5, 0.6)`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_terrain_art`, `test_new_room_biomes`, `test_world_view`, `test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** make `biomes()` return `["cave", "grotto"]` (the first and second tests fail); delete the `deep` colour (the overview test fails).

- [ ] **Step 6: Import (new `class_name`: none here, but the new test files need their `.uid`)** and commit: `git add -A scripts tests && git commit -m "feat: New room offers every biome the terrain art supports, and the overview colours them"`.

### Task 2: `build_decor` skips a decor id with no sprite

**Files:** Modify `scripts/world/room_builder.gd`; Create `tests/test_room_builder.gd`.

- [ ] **Step 1: Write the failing test** (`tests/test_room_builder.gd`):
```gdscript
extends GutTest
## RoomBuilder.build_decor: a hand-edited decor entry must never crash the builder.

func test_a_decor_entry_with_no_sprite_is_skipped_not_a_crash() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	RoomBuilder.build_decor(parent, {"decor": [
		{"id": "no_such_sprite", "pos": Vector2(10, 10), "anchor": "top"},
		{"id": "no_such_sprite", "pos": Vector2(20, 10)},
		{"id": "crystal_teal", "pos": Vector2(50, 50)}]})
	assert_eq(parent.get_child_count(), 1, "only the real sprite is built")
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_room_builder`. Expected: FAIL (a SCRIPT ERROR on `get_height()` of null).

- [ ] **Step 3: Implement.** In `build_decor` (room_builder.gd, `for d in layout.get("decor", [])`) fetch the texture first and skip:
```gdscript
	for d in layout.get("decor", []):
		var tex := Art.texture(d["id"])
		if tex == null:
			continue  # an id with no sprite (a hand edit): RoomLint's decor_unknown reports it
		var holder := Node2D.new()
		holder.position = d["pos"]
		var s := Art.sprite(d["id"], tex.get_height() if d.get("anchor", "bottom") == "top" else 0.0)
		holder.add_child(s)
```
(the `if d.has("light")` block and `parent.add_child(holder)` stay as they are).

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_builder`, `test_rooms`, `test_simple_layers`, `test_terrain`. Expected: PASS.

- [ ] **Step 5: Mutation check:** restore the unguarded `tex.get_height()` ordering (the test fails with a script error). Commit: `git commit -m "fix: a decor entry with no sprite is skipped instead of crashing the room builder"`.

---

## Milestone B: Selection and solid numbers

### Task 3: `hit_all`, and `hit` as its first element

**Files:** Modify `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_hit_all.gd`.

**Interfaces:** Produces `RoomEditModel.hit_all(room_id, p, pick) -> Array` of selection dictionaries: spawns nearest first (ties by index), then features by index, then exits by index, then solids smallest area first (ties by index). `hit` returns its first element or `{}`.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_hit_all.gd`):
```gdscript
extends GutTest
## hit_all: everything under a point in hit order; hit is its first element.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

## A lone room with a creature, a tablet and two nested solids stacked on one point.
func _stack() -> RoomDef:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.solids = [Rect2(100, 100, 200, 60), Rect2(150, 120, 40, 20)]   # the small one sits inside the big one
	r.spawns = [{"id": "toad", "pos": Vector2(170, 130)}]
	r.features = [{"kind": "tablet", "id": "l1_tablet_1", "pos": Vector2(170, 140), "title": "T"}]
	return r

func test_candidates_come_in_hit_order() -> void:
	model.rooms["L1"] = _stack()
	var kinds := model.hit_all("L1", Vector2(170, 130), 4.0).map(func(s): return s["kind"])
	assert_eq(kinds, ["spawn", "feature", "solid", "solid"])

func test_solids_are_smallest_area_first_with_ties_by_index() -> void:
	model.rooms["L1"] = _stack()
	var solids := model.hit_all("L1", Vector2(170, 130), 0.0).filter(func(s): return s["kind"] == "solid")
	assert_eq(solids.map(func(s): return s["index"]), [1, 0], "the small solid (index 1) before the big one")

func test_hit_is_the_first_candidate_and_empty_space_is_empty() -> void:
	model.rooms["L1"] = _stack()
	assert_eq(model.hit("L1", Vector2(170, 130), 4.0), model.hit_all("L1", Vector2(170, 130), 4.0)[0])
	assert_eq(model.hit_all("L1", Vector2(500, 300), 4.0), [])
	assert_eq(model.hit("L1", Vector2(500, 300), 4.0), {})

func test_spawns_are_nearest_first_with_ties_by_index() -> void:
	var r := _stack()
	r.spawns = [{"id": "toad", "pos": Vector2(176, 130)}, {"id": "bat", "pos": Vector2(171, 130)}, {"id": "bat", "pos": Vector2(171, 130)}]
	model.rooms["L1"] = r
	var spawns := model.hit_all("L1", Vector2(170, 130), 8.0).filter(func(s): return s["kind"] == "spawn")
	assert_eq(spawns.map(func(s): return s["index"]), [1, 2, 0])
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_room_edit_hit_all`. Expected: FAIL (`hit_all` missing).

- [ ] **Step 3: Implement.** Replace `hit` in `room_edit_model.gd` with:
```gdscript
## Every element under a room-local point, in hit order: creatures within `pick`, nearest first; then features (their drawn box
## grown by `pick`) and exits (their gap grown by `pick`) by index; then solids (grown by `pick`), smallest area first. Ties go by
## index. `hit` is the first element, so a plain press is the same as it was before hit_all existed.
func hit_all(room_id: String, p: Vector2, pick: float) -> Array:
	var r: RoomDef = rooms[room_id]
	var out: Array = []
	var near: Array = []
	for i in r.spawns.size():
		var d := (r.spawns[i]["pos"] as Vector2).distance_to(p)
		if d <= pick:
			near.append([d, i])
	near.sort_custom(func(a, b) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for n in near:
		out.append(_sel(room_id, "spawn", n[1]))
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		var box: Rect2 = RoomLint.FEATURE_BOX.get(f.get("kind", ""), Rect2(-6, -12, 12, 12))
		if Rect2(box.position + (f["pos"] as Vector2), box.size).grow(pick).has_point(p):
			out.append(_sel(room_id, "feature", i))
	for i in r.exits.size():
		if RoomBuilder.gate_rect(r.pixel_size(), r.exits[i]).grow(pick).has_point(p):
			out.append(_sel(room_id, "exit", i))
	var under: Array = []
	for i in r.solids.size():
		var s: Rect2 = r.solids[i]
		if s.grow(pick).has_point(p):
			under.append([s.get_area(), i])
	under.sort_custom(func(a, b) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for u in under:
		out.append(_sel(room_id, "solid", u[1]))
	return out

## The element under a room-local point: the first of hit_all, or {}.
func hit(room_id: String, p: Vector2, pick: float) -> Dictionary:
	var all := hit_all(room_id, p, pick)
	return all[0] if not all.is_empty() else {}
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit` (every model file, including the P1 `hit` tests in `test_room_edit_model.gd`) and `test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** sort solids largest first (the second test fails); skip the spawn sort (the third fails). Commit: `git commit -m "feat: hit_all lists everything under a point, and hit is its first element"`.

### Task 4: Alt-press selects under, and drags wait for 3 screen px

**Files:** Modify `scripts/editor/room_view.gd`, `tests/test_room_editor_scene.gd`.

**Interfaces:** `RoomView.CLICK_PX := 3.0`; `_press(p, alt := false, screen := Vector2.ZERO)`; an Alt/Option left press in the Select tool selects the candidate after the current selection in `hit_all` (wrapping; the first when the selection is not among them) and begins the move on it; a plain press is `hit`. In the Select tool `move_to` is not called until the pointer has travelled `CLICK_PX` screen pixels from the press, and then it applies from the press point.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd`, using its `_press` / `_release` / `_motion` helpers; `view`, `model` come from its `before_each`):
```gdscript
func _alt_press(p: Vector2) -> InputEventMouseButton:
	var e := _press(p)
	e.alt_pressed = true
	return e

## Two nested solids in a far-away room, stacked on one point.
func _nested_room() -> void:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.solids = [Rect2(100, 100, 200, 60), Rect2(150, 120, 40, 20)]
	model.rooms["L1"] = r
	model._baseline["L1"] = RoomEditModel.copy_room(r)
	view.show_room(model, "L1")

func test_a_plain_press_takes_the_first_candidate_and_alt_presses_walk_the_rest() -> void:
	_nested_room()
	view.tool = "select"
	var at := Vector2(170, 130)
	view.handle_event(_press(at))
	view.handle_event(_release(at))
	assert_eq(model.selection["index"], 1, "plain press: the smaller solid, as P2")
	view.handle_event(_alt_press(at))
	view.handle_event(_release(at))
	assert_eq(model.selection["index"], 0, "Alt-press: the next candidate")
	view.handle_event(_alt_press(at))
	view.handle_event(_release(at))
	assert_eq(model.selection["index"], 1, "and it wraps")

func test_an_alt_drag_moves_what_it_selected() -> void:
	_nested_room()
	view.tool = "select"
	var at := Vector2(170, 130)
	view.handle_event(_press(at))
	view.handle_event(_release(at))
	view.handle_event(_alt_press(at))
	view.handle_event(_motion(at + Vector2(40, 0)))
	view.handle_event(_release(at + Vector2(40, 0)))
	assert_eq(model.rooms["L1"].solids[0], Rect2(140, 100, 200, 60), "the big solid moved")
	assert_eq(model.rooms["L1"].solids[1], Rect2(150, 120, 40, 20), "the small one did not")

func test_a_creature_beside_a_selected_ledge_is_selected_by_a_plain_press() -> void:
	_nested_room()
	model.rooms["L1"].spawns = [{"id": "toad", "pos": Vector2(250, 120)}]
	view.tool = "select"
	view.handle_event(_press(Vector2(170, 130)))
	view.handle_event(_release(Vector2(170, 130)))
	view.handle_event(_press(Vector2(250, 120)))
	view.handle_event(_release(Vector2(250, 120)))
	assert_eq(model.selection["kind"], "spawn", "a plain press never keeps the old selection")

func test_a_press_with_a_pixel_of_jitter_moves_nothing_even_in_a_huge_room() -> void:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.size = Vector2i(6, 6)
	r.solids = [Rect2(100, 100, 200, 12)]
	model.rooms["L1"] = r
	model._baseline["L1"] = RoomEditModel.copy_room(r)
	view.show_room(model, "L1")
	view.tool = "select"
	var at := Vector2(200, 106)
	var press := _press(at)
	view.handle_event(press)
	var jitter := InputEventMouseMotion.new()
	jitter.position = press.position + Vector2(2, 0)   # 2 screen px: about 12 room px at this zoom
	view.handle_event(jitter)
	view.handle_event(_release(at))
	assert_eq(model.rooms["L1"].solids[0], Rect2(100, 100, 200, 12))
	assert_eq(model.undo_depth(), 0)

func test_a_drag_starts_after_three_screen_pixels_and_applies_from_the_press() -> void:
	_nested_room()
	view.tool = "select"
	var at := Vector2(170, 130)
	var press := _press(at)
	view.handle_event(press)
	var far := InputEventMouseMotion.new()
	far.position = press.position + Vector2(20, 0)
	view.handle_event(far)
	view.handle_event(_release(view.to_room(far.position)))
	var moved: Rect2 = model.rooms["L1"].solids[1]
	assert_almost_eq(moved.position.x, 150.0 + view.to_room(far.position).x - at.x, 4.0, "the whole distance applied, no lag")
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_room_editor_scene`. Expected: FAIL (Alt does nothing; the jitter test moves the ledge).

- [ ] **Step 3: Implement** in `room_view.gd`:
  - Add `const CLICK_PX := 3.0` beside `PICK_PX`, and fields `var _press_screen := Vector2.ZERO` and `var _dragging := false`.
  - In `_button`'s `MOUSE_BUTTON_LEFT` arm call `_press(to_room(e.position), e.alt_pressed, e.position)`.
  - Change `_press` to `func _press(p: Vector2, alt := false, screen := Vector2.ZERO) -> void:` and set `_press_screen = screen` and `_dragging = false` after `_pressed = true`; replace its `"select"` arm with:
```gdscript
		"select":
			var sel := _pick_candidate(_model.hit_all(_room_id, p, pick_radius()), alt)
			_model.select(sel)
			if not sel.is_empty():
				_model.begin_move(sel)
			selection_changed.emit()
			_serial_at_press = _model.serial
```
  - Add:
```gdscript
## A plain press takes the first candidate (what hit returns). An Alt press takes the one after the current selection, wrapping;
## the first when the selection is not among them.
func _pick_candidate(cands: Array, alt: bool) -> Dictionary:
	if cands.is_empty():
		return {}
	if not alt:
		return cands[0]
	return cands[(cands.find(_model.selection) + 1) % cands.size()]  # find is -1 when absent, so the first
```
  - In `_motion`, replace `"select": _model.move_to(p - _press_room)` with:
```gdscript
		"select":
			if not _dragging and e.position.distance_to(_press_screen) < CLICK_PX:
				return true  # a click with a little jitter is not a drag
			_dragging = true
			_model.move_to(p - _press_room)
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`, `test_room_edit`. Expected: PASS (the P2 select-drag tests travel well over 3 px).

- [ ] **Step 5: Mutation checks:** make `_pick_candidate` ignore `alt` (the first two tests fail); drop the `_dragging` guard (the jitter test fails); apply `move_to` from the motion's own delta instead of the press (the last test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: Alt-press selects under, and a drag starts only after 3 screen pixels"`).

### Task 5: One writer for a solid's rect

**Files:** Modify `scripts/editor/room_edit_model.gd`, `tests/test_room_edit_model.gd`.

**Interfaces:** Produces `RoomEditModel._has_solid(r, rect, skip := -1) -> bool` (static) and `_put_solid(room_id, i, rect, marked) -> String`: refuses a rect smaller than `MIN_SOLID`, not wholly inside the room, or identical to another solid; writes it; keeps `hard_ledges` in step (the entry keeps its list position; `marked` and thin means it is in the list, else it is not). `move_to`'s solid arm and `add_solid` use them.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_edit_model.gd`; its `model` comes from its `before_each`):
```gdscript
func _two_ledges_one_marked() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(100, 200, 100, 12), Rect2(300, 200, 100, 12)]
	r.hard_ledges = [Rect2(300, 200, 100, 12)]

func test_add_solid_refuses_an_identical_solid() -> void:
	_two_ledges_one_marked()
	assert_eq(model.add_solid("C2", Vector2(100, 200), Vector2(200, 212)), "an identical solid is already there")
	assert_eq(model.undo_depth(), 0)

func test_dragging_a_solid_onto_an_identical_marked_one_keeps_both_marks() -> void:
	_two_ledges_one_marked()
	var r: RoomDef = model.rooms["C2"]
	var sel := {"room": "C2", "kind": "solid", "index": 0}
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(200, 0))
	assert_eq(r.solids[0], Rect2(100, 200, 100, 12), "the identical step is refused: the solid stays where it last was valid")
	model.move_to(Vector2(260, 0))
	assert_eq(r.solids[0], Rect2(360, 200, 100, 12), "and sliding on works")
	model.end_move()
	assert_eq(r.hard_ledges, [Rect2(300, 200, 100, 12)], "B kept its mark; A never got it")

func test_a_marked_solid_keeps_its_mark_and_its_list_position_while_it_moves() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(100, 200, 100, 12), Rect2(300, 200, 100, 12)]
	r.hard_ledges = [Rect2(100, 200, 100, 12), Rect2(300, 200, 100, 12)]
	assert_true(model.begin_move({"room": "C2", "kind": "solid", "index": 0}))
	model.move_to(Vector2(40, 0))
	model.end_move()
	assert_eq(r.hard_ledges, [Rect2(140, 200, 100, 12), Rect2(300, 200, 100, 12)])

func test_a_solid_dragged_against_a_wall_slides_instead_of_freezing() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(100, 200, 100, 12)]
	assert_true(model.begin_move({"room": "C2", "kind": "solid", "index": 0}))
	model.move_to(Vector2(-400, 0))
	assert_eq(r.solids[0].position.x, 0.0, "clamped into the room, then written")
	model.end_move()
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_room_edit_model`. Expected: FAIL (the identical solid is accepted; the drag steals the mark).

- [ ] **Step 3: Implement** in `room_edit_model.gd`, after `add_spawn`:
```gdscript
## True when another solid in the room has exactly this rect. hard_ledges holds rect values, so two equal rects would make a mark
## ambiguous (a drag onto an identical marked solid would move the mark onto the wrong one).
static func _has_solid(r: RoomDef, rect: Rect2, skip := -1) -> bool:
	for i in r.solids.size():
		if i != skip and r.solids[i] == rect:
			return true
	return false

## The one writer for a solid's rect (a drag step, a typed number, the Rock-from-below toggle): refuses a rect smaller than
## MIN_SOLID, not wholly inside the room, or identical to another solid; writes it; and keeps hard_ledges in step: a `marked` thin
## rect is in the list (at the position its old rect had), anything else is not. Returns "" or the reason; a refusal writes nothing.
func _put_solid(room_id: String, i: int, rect: Rect2, marked: bool) -> String:
	var r: RoomDef = rooms[room_id]
	if rect.size.x < MIN_SOLID or rect.size.y < MIN_SOLID:
		return "too small: a solid is at least %d px each way" % int(MIN_SOLID)
	if not bounds(r).encloses(rect):
		return "outside the room"
	if _has_solid(r, rect, i):
		return "an identical solid is already there"
	var was: Rect2 = r.solids[i]
	r.solids[i] = rect
	var keep := marked and rect.size.y <= 24.0 and rect.size.x > 24.0
	var h := r.hard_ledges.find(was)
	if h >= 0 and keep:
		r.hard_ledges[h] = rect
	elif h >= 0:
		r.hard_ledges.remove_at(h)
	elif keep:
		r.hard_ledges.append(rect)
	return ""
```
In `add_solid`, after the size check add `if _has_solid(r, rect): return "an identical solid is already there"`. Replace `move_to`'s `"solid"` arm body with:
```gdscript
			var orig: Rect2 = _drag["orig"]
			var moved := Rect2(orig.position + d, orig.size)
			moved.position = moved.position.clamp(Vector2.ZERO, r.pixel_size() - moved.size)
			var i: int = sel["index"]
			_put_solid(sel["room"], i, moved, r.hard_ledges.has(r.solids[i]))  # a refused step keeps the last valid rect
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit`. Expected: PASS (including P1's `test_a_moved_solid_stays_inside_the_room_and_keeps_hard_ledges_consistent`).

- [ ] **Step 5: Mutation checks:** drop `_has_solid` from `_put_solid` (the drag test fails); make the mark remove-then-append (the position test fails); skip the clamp in `move_to` (the wall test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: one writer for a solid's rect refuses identical solids and keeps the hard mark in step"`).

### Task 6: Solid fields in `get_field` / `set_field`

**Files:** Modify `scripts/editor/room_edit_model.gd`, `tests/test_room_edit_fields.gd`.

**Interfaces:** `get_field` / `set_field` for kind `solid`, keys `x`, `y`, `w`, `h` (floats), `hard` (bool). Not snapped; goes through `_put_solid`; `hard` true on a thick solid is refused.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_edit_fields.gd`):
```gdscript
func _solid_sel(room: String, i: int) -> Dictionary:
	return {"room": room, "kind": "solid", "index": i}

func test_a_solids_numbers_read_back() -> void:
	var sel := _solid_sel("C1", 1)   # Rect2(420, 214, 100, 12)
	assert_eq([model.get_field(sel, "x"), model.get_field(sel, "y"), model.get_field(sel, "w"), model.get_field(sel, "h")], [420.0, 214.0, 100.0, 12.0])
	assert_eq(model.get_field(sel, "hard"), false)

func test_a_typed_number_is_not_snapped_and_is_one_step() -> void:
	var sel := _solid_sel("C1", 0)   # Rect2(260, 266, 120, 12): y 266 is off the grid
	assert_eq(model.set_field(sel, "y", 267.0), "")
	assert_eq(model.rooms["C1"].solids[0], Rect2(260, 267, 120, 12))
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.set_field(sel, "y", 267.0), "", "the stored value is a no-op")
	assert_eq(model.undo_depth(), 1)

func test_a_solid_typed_outside_the_room_or_onto_another_is_refused_and_changes_nothing() -> void:
	var sel := _solid_sel("C1", 0)
	assert_ne(model.set_field(sel, "x", 1200.0), "", "260..380 moved to 1200..1320 leaves a 1280 room")
	assert_ne(model.set_field(sel, "w", 2.0), "", "below MIN_SOLID")
	assert_eq(model.undo_depth(), 0, "a refusal changes nothing")
	model.rooms["C1"].solids.append(Rect2(500, 100, 120, 12))
	var other := _solid_sel("C1", model.rooms["C1"].solids.size() - 1)
	assert_eq(model.set_field(other, "x", 260.0), "", "x alone does not make it identical")
	var depth: int = model.undo_depth()
	assert_eq(model.set_field(other, "y", 266.0), "an identical solid is already there")
	assert_eq(model.rooms["C1"].solids[other["index"]], Rect2(260, 100, 120, 12))
	assert_eq(model.undo_depth(), depth, "the refused set pushed nothing")

func test_rock_from_below_adds_and_removes_the_mark_on_a_thin_solid_only() -> void:
	var thin := _solid_sel("C1", 1)
	assert_eq(model.set_field(thin, "hard", true), "")
	assert_true(model.rooms["C1"].hard_ledges.has(Rect2(420, 214, 100, 12)))
	assert_eq(model.get_field(thin, "hard"), true)
	assert_eq(model.set_field(thin, "hard", false), "")
	assert_false(model.rooms["C1"].hard_ledges.has(Rect2(420, 214, 100, 12)))
	var thick := _solid_sel("C1", 5)   # Rect2(480, 272, 96, 48): rock
	assert_ne(model.set_field(thick, "hard", true), "", "only a thin solid can be rock from below")

func test_a_solid_that_stops_being_thin_loses_its_mark_in_the_same_step() -> void:
	var sel := _solid_sel("C1", 1)
	model.set_field(sel, "hard", true)
	assert_eq(model.set_field(sel, "h", 30.0), "")
	assert_eq(model.rooms["C1"].hard_ledges, [])
	assert_eq("\n".join(model.validate()), "", "the validator would reject a mark on a thick solid")
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_room_edit_fields`. Expected: FAIL (`no such field`).

- [ ] **Step 3: Implement** in `room_edit_model.gd`. In `get_field` add before the final `return null`:
```gdscript
		"solid":
			if i < r.solids.size():
				var s: Rect2 = r.solids[i]
				match key:
					"x":
						return s.position.x
					"y":
						return s.position.y
					"w":
						return s.size.x
					"h":
						return s.size.y
					"hard":
						return r.hard_ledges.has(s)
```
In `set_field`'s `match sel["kind"]` add:
```gdscript
		"solid":
			if i >= r.solids.size():
				return "nothing selected"
			return _set_solid_field(room_id, i, key, value)
```
and add the doc line "solid `x` `y` `w` `h` (exact, not snapped) and `hard` (Rock from below, thin solids only)" to `set_field`'s comment, then:
```gdscript
func _set_solid_field(room_id: String, i: int, key: String, value) -> String:
	var r: RoomDef = rooms[room_id]
	var s: Rect2 = r.solids[i]
	var next := s
	var marked := r.hard_ledges.has(s)
	match key:
		"x":
			next.position.x = float(value)
		"y":
			next.position.y = float(value)
		"w":
			next.size.x = float(value)
		"h":
			next.size.y = float(value)
		"hard":
			if bool(value) and not (s.size.y <= 24.0 and s.size.x > 24.0):
				return "only a thin solid can be rock from below"
			marked = bool(value)
		_:
			return "no such field"
	var before := _snap([room_id])
	var err := _put_solid(room_id, i, next, marked)
	if err != "":
		return err
	_push(before)
	return ""
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_fields`, `test_room_edit_model`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** snap the typed value (`snap(float(value))`; the unsnapped test fails); drop the thin check (the thick `hard` refusal fails); pass `true` instead of `marked` to `_put_solid` (the thick-loses-mark test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: the model reads and sets a solid's x, y, w, h and Rock from below"`).

### Task 7: The solid panel: number and checkbox controls

**Files:** Modify `scripts/editor/inspector_panel.gd`, `scripts/editor/room_editor.gd`, `tests/test_room_editor_scene.gd`.

**Interfaces:** `InspectorPanel.FIELDS["solid"]`; controls `"number"` (a `SpinBox`, whole pixels, built **ranges, then value, then connect**) and `"check"` (a `CheckBox` bound to a bool, visible only for a thin solid); `_title` handles `solid`; `RoomEditor._inspectable` accepts `solid`.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd`; and **rewrite on purpose** `test_selecting_a_feature_shows_its_inspector_and_a_solid_hides_it` into the two tests below):
```gdscript
func test_a_selected_solid_shows_its_numbers_and_a_creature_hides_the_panel() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "inspector")
	var x: SpinBox = ed.slot.find_field("x")
	assert_eq([x.value, x.min_value, x.max_value], [420.0, 0.0, 1276.0], "a new SpinBox starts at 0..100: ranges first, then the value")
	assert_eq((ed.slot.find_field("y") as SpinBox).value, 214.0)
	ed.model.select({"room": "C1", "kind": "spawn", "index": 0})
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "", "a creature has no panel")

func test_typing_a_number_commits_it_once_and_never_while_building() -> void:
	var ed := await _editor()
	var depth_before: int = ed.model.undo_depth()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	assert_eq(ed.model.undo_depth(), depth_before, "building the panel commits nothing")
	var x: SpinBox = ed.slot.find_field("x")
	x.value = 440.0
	assert_eq(ed.model.rooms["C1"].solids[1].position.x, 440.0)
	assert_eq(ed.model.undo_depth(), depth_before + 1)

func test_a_refused_number_shows_the_stored_value_again() -> void:
	var ed := await _editor()
	var errors := []
	ed.slot.field_error.connect(func(t: String) -> void: errors.append(t))
	ed.model.rooms["C1"].solids.append(Rect2(500, 100, 120, 12))
	var i: int = ed.model.rooms["C1"].solids.size() - 1
	ed.model.select({"room": "C1", "kind": "solid", "index": i})
	ed.view.refresh()
	(ed.slot.find_field("x") as SpinBox).value = 260.0
	(ed.slot.find_field("y") as SpinBox).value = 266.0   # now identical to C1's first ledge
	assert_eq(errors.size(), 1)
	assert_eq((ed.slot.find_field("y") as SpinBox).value, 100.0, "back to the stored value")

func test_rock_from_below_is_a_checkbox_that_hides_for_a_thick_solid() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	var box: CheckBox = ed.slot.find_field("hard")
	assert_true(box.visible)
	box.button_pressed = true
	assert_true(ed.model.rooms["C1"].hard_ledges.has(Rect2(420, 214, 100, 12)))
	ed.model.select({"room": "C1", "kind": "solid", "index": 5})
	ed.view.refresh()
	assert_false((ed.slot.find_field("hard") as CheckBox).visible, "a thick solid is rock anyway")
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_room_editor_scene`. Expected: FAIL (no solid panel).

- [ ] **Step 3: Implement.** In `inspector_panel.gd`:
  - `FIELDS` gains `"solid": [["x", "X", "number"], ["y", "Y", "number"], ["w", "Width", "number"], ["h", "Height", "number"], ["hard", "Rock from below", "check"]],`.
  - `_make` gains arms `"number": return _number(key)` and `"check": return _check(key)`.
  - Add:
```gdscript
func _number(key: String) -> SpinBox:
	var box := SpinBox.new()
	box.name = "field_" + key
	box.custom_minimum_size = Vector2(150, 0)
	box.step = 1.0
	box.rounded = true
	_set_range(box, key)                                   # ranges first: a new SpinBox is 0..100 and would clamp the value
	box.value = float(_model.get_field(_sel, key))         # then the value
	box.value_changed.connect(func(v: float) -> void: _commit(key, v))  # then connect, so building never commits
	box.get_line_edit().add_theme_font_size_override("font_size", FONT)
	return box

## The SpinBox range for a solid's number from the room it is in (a Grow changes it under an open selection).
func _set_range(box: SpinBox, key: String) -> void:
	var size: Vector2 = _model.rooms[_sel["room"]].pixel_size()
	match key:
		"x":
			box.min_value = 0.0
			box.max_value = size.x - RoomEditModel.MIN_SOLID
		"y":
			box.min_value = 0.0
			box.max_value = size.y - RoomEditModel.MIN_SOLID
		"w":
			box.min_value = RoomEditModel.MIN_SOLID
			box.max_value = size.x
		"h":
			box.min_value = RoomEditModel.MIN_SOLID
			box.max_value = size.y

func _check(key: String) -> CheckBox:
	var box := CheckBox.new()
	box.name = "field_" + key
	box.text = "Rock from below"
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", FONT)
	box.button_pressed = bool(_model.get_field(_sel, key))
	box.visible = _thin_solid()
	box.toggled.connect(func(on: bool) -> void: _commit(key, on))
	return box

## Thin solids (a one-way ledge unless marked) are the only ones the mark means anything for.
func _thin_solid() -> bool:
	return float(_model.get_field(_sel, "h")) <= 24.0 and float(_model.get_field(_sel, "w")) > 24.0
```
  - `_title`: add `if kind == "solid": return "Solid %d" % _sel["index"]` before the feature lookup.
  - `_show_stored`: add arms before the final `else` (a `SpinBox` arm calling `_set_range(control, key)` then `set_value_no_signal(float(stored))`; a `CheckBox` arm calling `set_pressed_no_signal(bool(stored))` and setting `control.visible = _thin_solid()`), and `if stored == null: return` after `var stored = ...`.
  In `room_editor.gd`, `_inspectable`: add `"solid": return sel["index"] < r.solids.size()`.
  **Rewrite on purpose** the P2 scene test `test_selecting_a_feature_shows_its_inspector_and_a_solid_hides_it` (in `tests/test_room_editor_scene.gd`): keep the feature half; the solid half now expects `"inspector"` (the two new tests above cover the creature hiding it).

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** build the SpinBox value before its range (the first test shows 100); connect `value_changed` before setting the value (the commit-on-build test fails); drop the `_thin_solid` visibility (the checkbox test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: a solid's panel: x, y, width, height and Rock from below"`).

### Task 8: `refresh()`: the inspector never shows a stale number

**Files:** Modify `scripts/editor/inspector_panel.gd`, `scripts/editor/editor_slot.gd`, `scripts/editor/room_editor.gd`, `tests/test_room_editor_scene.gd`.

**Interfaces:** `InspectorPanel.refresh()`; `EditorSlot.refresh_inspector()`; `RoomEditor._sync_slot` calls it while the same selection is open.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd`):
```gdscript
func test_a_drag_updates_the_number_that_was_showing() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	assert_true(ed.model.begin_move(ed.model.selection))
	ed.model.move_to(Vector2(40, 0))
	ed.model.end_move()
	ed.view.refresh()
	assert_eq((ed.slot.find_field("x") as SpinBox).value, 460.0, "the field follows the drag")

func test_a_grow_moves_the_number_and_the_range_with_the_room() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	var solid: Rect2 = ed.model.rooms["C6"].solids[0]
	ed.model.select({"room": "C6", "kind": "solid", "index": 0})
	ed.view.refresh()
	var depth: int = ed.model.undo_depth()
	ed.grow("left")
	var x: SpinBox = ed.slot.find_field("x")
	assert_eq(ed.model.rooms["C6"].solids[0].position.x, solid.position.x + 640.0)
	assert_eq(x.value, solid.position.x + 640.0, "the shifted value is shown, not clamped to the old maximum")
	assert_eq(x.max_value, 1280.0 - 4.0)
	assert_eq(ed.model.undo_depth(), depth + 1, "a refresh never commits: only the grow is a step")

func test_a_refresh_leaves_a_focused_field_alone() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	var x: SpinBox = ed.slot.find_field("x")
	x.get_line_edit().grab_focus()
	x.get_line_edit().text = "431"
	ed.slot.refresh_inspector()
	assert_eq(x.get_line_edit().text, "431", "the author is typing in it")

func test_the_rock_from_below_checkbox_follows_the_height() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	(ed.slot.find_field("h") as SpinBox).value = 30.0
	assert_false((ed.slot.find_field("hard") as CheckBox).visible, "typed thick: the checkbox hides")
	(ed.slot.find_field("h") as SpinBox).value = 12.0
	assert_true((ed.slot.find_field("hard") as CheckBox).visible, "typed thin again: it shows")
```

- [ ] **Step 2: Run to verify it fails.** `tools/run_tests.sh test_room_editor_scene`. Expected: FAIL (stale numbers).

- [ ] **Step 3: Implement.** `inspector_panel.gd`:
```gdscript
## Re-reads every control from the model (after a drag, a Grow or any other edit made outside the panel), skipping a control
## that has keyboard focus: the author may be typing in it. Writes use set_value_no_signal / set_pressed_no_signal, so a refresh
## can never commit.
func refresh() -> void:
	for key in _fields:
		if not _has_focus(_fields[key]):
			_show_stored(key)

func _has_focus(c: Control) -> bool:
	if c is SpinBox:
		return (c as SpinBox).get_line_edit().has_focus()
	return c.has_focus()
```
`editor_slot.gd`: `func refresh_inspector() -> void: if _inspector != null: _inspector.refresh()`. `room_editor.gd` `_sync_slot`: after the `if slot.is_showing() != "inspector" or model.selection != _slot_sel:` block add an `else: slot.refresh_inspector()`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** `refresh()` without `_set_range` in the `SpinBox` arm of `_show_stored` (the Grow test fails); write with `box.value =` instead of `set_value_no_signal` (the Grow test's depth assertion fails); drop the focus check (the focus test fails).

- [ ] **Step 6: Full suite** (end of milestone B): `tools/run_tests.sh`. Expected: PASS. Commit: `git commit -m "feat: the inspector refreshes its numbers after a drag or a Grow, never under a field being typed in"`.

---

## Milestone C: Decor

### Task 9: `DecorLib`

**Files:** Create `scripts/world/decor_lib.gd`, `tests/test_decor_lib.gd`.

**Interfaces:** `DecorLib.CATALOG` (46 rows `id -> {anchor, light?}`), `biome_of(id) -> String`, `ids_for_biome(biome) -> Array`, `entry(id, pos) -> Dictionary`, `UNKNOWN_BOX := Rect2(-12, -24, 24, 24)`, `texture_box(id) -> Rect2` (bottom-anchored `Rect2(-w/2, -h, w, h)`, top-anchored `Rect2(-w/2, 0, w, h)`, the fallback box for an id with no catalog row or no sprite).

- [ ] **Step 1: Write the failing tests** (`tests/test_decor_lib.gd`):
```gdscript
extends GutTest
## DecorLib: the decor sprites the editor can place.

## Every decor entry the shipped rooms carry, as {id, anchor, light, room}.
func _shipped_decor() -> Array:
	var out: Array = []
	var rooms := World.load_rooms("res://data/rooms")
	for id in rooms:
		for d in (rooms[id] as RoomDef).decor:
			out.append({"room": id, "d": d})
	return out

func test_the_21_shipped_decor_ids_are_pinned_to_the_catalog() -> void:
	var ids := {}
	for item in _shipped_decor():
		var d: Dictionary = item["d"]
		ids[d["id"]] = true
		assert_eq(DecorLib.entry(d["id"], d["pos"]), d, "%s in %s" % [d["id"], item["room"]])
	assert_eq(ids.size(), 21)

func test_every_row_has_a_sprite_a_valid_anchor_and_a_light_that_is_absent_or_a_color() -> void:
	assert_eq(DecorLib.CATALOG.size(), 46)
	for id in DecorLib.CATALOG:
		var row: Dictionary = DecorLib.CATALOG[id]
		assert_not_null(Art.texture(id), "%s has a sprite" % id)
		assert_true(["bottom", "top"].has(row["anchor"]), id)
		assert_true(not row.has("light") or row["light"] is Color, id)

func test_every_biome_prefixed_sprite_has_a_row() -> void:
	var dir := DirAccess.open("res://assets/sprites")
	for f in dir.get_files():
		if f.ends_with(".png"):
			var sprite := f.trim_suffix(".png")
			for b in TerrainArt.biomes():
				if b != "cave" and sprite.begins_with(b + "_"):
					assert_true(DecorLib.CATALOG.has(sprite), "%s needs a catalog row" % sprite)

func test_biome_of_agrees_with_the_prefab_generators_naming() -> void:
	for biome in TerrainArt.biomes():
		for base in ["glow_fungus", "stalagmite", "wall_crystal"]:
			assert_eq(DecorLib.biome_of(Prefabs.decor_id(base, biome)), biome)

func test_ids_for_biome_partitions_the_catalog() -> void:
	var seen := 0
	for biome in TerrainArt.biomes():
		var ids := DecorLib.ids_for_biome(biome)
		seen += ids.size()
		for id in ids:
			assert_eq(DecorLib.biome_of(id), biome)
	assert_eq(seen, 46)
	assert_true(DecorLib.ids_for_biome("deep").has("deep_bones"))
	assert_false(DecorLib.ids_for_biome("cave").has("deep_bones"))

func test_entry_has_anchor_only_when_top_and_light_only_when_it_has_one() -> void:
	assert_eq(DecorLib.entry("vine", Vector2(1, 2)), {"id": "vine", "pos": Vector2(1, 2), "anchor": "top"})
	assert_eq(DecorLib.entry("rubble", Vector2(1, 2)), {"id": "rubble", "pos": Vector2(1, 2)})
	assert_true(DecorLib.entry("crystal_teal", Vector2.ZERO).has("light"))

func test_texture_box_is_bottom_or_top_anchored_and_falls_back_for_an_unknown_id() -> void:
	var tex := Art.texture("crystal_teal")
	assert_eq(DecorLib.texture_box("crystal_teal"), Rect2(-tex.get_width() / 2.0, -tex.get_height(), tex.get_width(), tex.get_height()))
	var vine := Art.texture("vine")
	assert_eq(DecorLib.texture_box("vine"), Rect2(-vine.get_width() / 2.0, 0.0, vine.get_width(), vine.get_height()))
	assert_eq(DecorLib.texture_box("no_such_sprite"), DecorLib.UNKNOWN_BOX)
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`DecorLib` not found).

- [ ] **Step 3: Implement** `scripts/world/decor_lib.gd`:
```gdscript
class_name DecorLib
extends RefCounted
## The decor sprites the editor can place: id -> {anchor: "bottom" | "top", light: Color (optional)}. A bottom-anchored piece
## stands on its position, a top-anchored one hangs from it (RoomBuilder.build_decor). The 21 ids the shipped rooms use are pinned
## to the data by test_decor_lib; the other 25 rows have no shipped instance and are chosen, not pinned: each takes the anchor of
## its cave counterpart and the light of its grotto or cave counterpart (deep_bones has none: bottom, no light). A new biome's art
## needs rows here. An id is bound to a biome by its `<biome>_` prefix; no prefix means cave (tools/prefabs.gd decor_id is the
## forward mapping).

const UNKNOWN_BOX := Rect2(-12, -24, 24, 24)

const CATALOG := {
	# cave (crystal_purple has no shipped instance)
	"crystal_blue": {"anchor": "bottom", "light": Color(0.3, 0.5, 1, 1)},
	"crystal_gold": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"crystal_prism": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	"crystal_purple": {"anchor": "bottom", "light": Color(0.75, 0.5, 1, 1)},
	"crystal_rose": {"anchor": "bottom", "light": Color(1, 0.55, 0.75, 1)},
	"crystal_teal": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"flowers": {"anchor": "bottom"},
	"glow_fungus": {"anchor": "bottom", "light": Color(0.35, 0.95, 0.7, 1)},
	"lichen_hang": {"anchor": "top", "light": Color(0.35, 0.95, 0.7, 1)},
	"puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"root_hang": {"anchor": "top"},
	"rubble": {"anchor": "bottom"},
	"stalactite": {"anchor": "top"},
	"stalagmite": {"anchor": "bottom"},
	"vine": {"anchor": "top"},
	"wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	# grotto
	"grotto_crystal_gold": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},  # chosen, not pinned
	"grotto_crystal_prism": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	"grotto_crystal_rose": {"anchor": "bottom", "light": Color(1, 0.55, 0.75, 1)},
	"grotto_flowers": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"grotto_glow_fungus": {"anchor": "bottom", "light": Color(0.5, 1, 0.6, 1)},
	"grotto_lichen_hang": {"anchor": "top"},
	"grotto_puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},  # chosen, not pinned
	"grotto_root_hang": {"anchor": "top"},
	"grotto_rubble": {"anchor": "bottom"},  # chosen, not pinned
	"grotto_stalagmite": {"anchor": "bottom"},  # chosen, not pinned
	"grotto_wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},  # chosen, not pinned
	# deep (no shipped room: chosen, not pinned)
	"deep_bones": {"anchor": "bottom"},
	"deep_glow_fungus": {"anchor": "bottom", "light": Color(0.5, 1, 0.6, 1)},
	"deep_lichen_hang": {"anchor": "top"},
	"deep_puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"deep_root_hang": {"anchor": "top"},
	"deep_rubble": {"anchor": "bottom"},
	"deep_stalagmite": {"anchor": "bottom"},
	"deep_wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	# flooded (no shipped room: chosen, not pinned)
	"flooded_crystal_gold": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"flooded_crystal_prism": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	"flooded_crystal_rose": {"anchor": "bottom", "light": Color(1, 0.55, 0.75, 1)},
	"flooded_flowers": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"flooded_glow_fungus": {"anchor": "bottom", "light": Color(0.5, 1, 0.6, 1)},
	"flooded_lichen_hang": {"anchor": "top"},
	"flooded_puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"flooded_root_hang": {"anchor": "top"},
	"flooded_rubble": {"anchor": "bottom"},
	"flooded_stalagmite": {"anchor": "bottom"},
	"flooded_wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
}

## The biome a decor id belongs to: its `<biome>_` prefix when `<biome>` is a biome with terrain art (and not cave), else cave.
static func biome_of(id: String) -> String:
	for b in TerrainArt.biomes():
		if b != "cave" and id.begins_with(b + "_"):
			return b
	return "cave"

## The catalog ids for a biome, sorted.
static func ids_for_biome(biome: String) -> Array:
	var out: Array = []
	for id in CATALOG:
		if biome_of(id) == biome:
			out.append(id)
	out.sort()
	return out

## The data a placed piece gets: `anchor: "top"` only when the catalog says so, `light` only when it has one.
static func entry(id: String, pos: Vector2) -> Dictionary:
	var row: Dictionary = CATALOG.get(id, {})
	var e := {"id": id, "pos": pos}
	if row.get("anchor", "bottom") == "top":
		e["anchor"] = "top"
	if row.has("light"):
		e["light"] = row["light"]
	return e

## The sprite's box relative to the piece's position (RoomBuilder.build_decor: a bottom-anchored sprite ends at the position, a
## top-anchored one starts there, both centred in x). An id with no catalog row or no sprite gets a fixed fallback box, so a
## hand-edited unknown piece can still be hit, outlined and deleted.
static func texture_box(id: String) -> Rect2:
	var tex := Art.texture(id) if CATALOG.has(id) else null
	if tex == null:
		return UNKNOWN_BOX
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	if CATALOG[id].get("anchor", "bottom") == "top":
		return Rect2(-w / 2.0, 0.0, w, h)
	return Rect2(-w / 2.0, -h, w, h)
```

- [ ] **Step 4: Import** (new `class_name`) and run: `env HOME="$PWD/.tmp/gdhome" godot --headless --import`, `tools/run_tests.sh test_decor_lib`. Expected: PASS. If the pinned test finds a mismatch, the data is the authority: fix the catalog row, not the data.

- [ ] **Step 5: Mutation checks:** flip `vine` to bottom (the pinned test fails); drop a row's sprite id typo (the sprite test fails); make `biome_of` ignore the prefix (the partition test fails).

- [ ] **Step 6: Commit** (`git add -A scripts tests && git commit -m "feat: DecorLib, the catalog of the 46 decor sprites"`).

### Task 10: The `decor` kind in the model

**Files:** Modify `scripts/editor/room_edit_model.gd`, `tests/test_room_edit_features.gd` (decor tests), `tests/test_room_edit_hit_all.gd`.

**Interfaces:** `surface_above(room_id, p) -> Variant`; `add_decor(room_id, id, pos) -> String`; `_decor_base(room_id, p, id) -> Variant` (the surface rule, x snapped, y from the surface; the P2 dip fallback in `move_to`); kind `decor` in `hit_all` (un-grown `texture_box` at `pos`, between features and exits), `begin_move`, `move_to`, `delete_selection`; the `selection` doc lists it.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_edit_features.gd`; it has `model` and `_features`):
```gdscript
func _decor(room: String) -> Array:
	return model.rooms[room].decor

func test_surface_above_is_the_underside_of_the_first_rock_and_null_in_rock_or_under_a_top_exit() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 100, 100, 12)]
	assert_eq(model.surface_above("C2", Vector2(250, 200)), 112.0, "the ledge's underside")
	assert_eq(model.surface_above("C2", Vector2(50, 200)), 20.0, "the generated ceiling")
	assert_null(model.surface_above("C2", Vector2(250, 105)), "inside rock")
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top")[0]
	var mid := (float(top["from"]) + float(top["to"])) / 2.0
	assert_null(model.surface_above("C2", Vector2(mid, 200)), "under a top exit the ceiling is cut: nothing to hang from")

func test_a_standing_piece_stands_on_the_surface_below_and_a_hanging_one_hangs_from_the_rock_above() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 100, 12)]
	assert_eq(model.add_decor("C2", "crystal_teal", Vector2(240, 120)), "")
	assert_eq(_decor("C2").back(), DecorLib.entry("crystal_teal", Vector2(240, 200)))
	assert_eq(model.selection["kind"], "decor")
	assert_eq(model.add_decor("C2", "vine", Vector2(240, 300)), "")
	assert_eq(_decor("C2").back(), DecorLib.entry("vine", Vector2(240, 212)), "hangs from the ledge's underside")
	assert_eq(model.undo_depth(), 2)

func test_decor_placement_is_refused_with_no_surface_an_unknown_id_or_outside() -> void:
	var r: RoomDef = model.rooms["C2"]
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top")[0]
	var mid := (float(top["from"]) + float(top["to"])) / 2.0
	assert_ne(model.add_decor("C2", "vine", Vector2(mid, 200)), "", "a hanging piece under a top exit")
	assert_ne(model.add_decor("C2", "no_such_sprite", Vector2(300, 200)), "", "an id outside the catalog")
	assert_ne(model.add_decor("C2", "crystal_teal", Vector2(-50, 200)), "", "outside the room")
	assert_eq(model.undo_depth(), 0)

func test_decor_hits_its_ungrown_box_so_a_ledge_beside_it_is_still_the_first_hit() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.spawns = []
	r.features = []
	r.solids = [Rect2(200, 200, 100, 12)]
	r.decor = [DecorLib.entry("crystal_teal", Vector2(260, 200))]
	var box := DecorLib.texture_box("crystal_teal")
	var on_art := Vector2(260, 200) + box.position + box.size / 2.0
	assert_eq(model.hit("C2", on_art, 8.0)["kind"], "decor", "on the crystal's art")
	assert_eq(model.hit("C2", Vector2(210, 206), 8.0)["kind"], "solid", "on the ledge, away from the crystal")
	assert_eq(model.hit("C2", Vector2(260, 206), 8.0)["kind"], "solid", "on the ledge under the crystal's foot: the box ends at the ledge's top")

func test_decor_drags_along_a_ledge_keeps_sliding_when_the_pointer_dips_and_deletes() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 160, 12)]
	r.decor = [DecorLib.entry("crystal_teal", Vector2(220, 200))]
	var sel := {"room": "C2", "kind": "decor", "index": 0}
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(60, 4))   # the pointer dips below the ledge top
	assert_eq(r.decor[0]["pos"], Vector2(280, 200))
	model.end_move()
	model.select(sel)
	assert_eq(model.delete_selection(), "")
	assert_eq(r.decor.size(), 0)
	model.undo()
	assert_eq(r.decor.size(), 1)

func test_an_unknown_decor_id_can_be_selected_and_deleted() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.spawns = []
	r.features = []
	r.decor = [{"id": "no_such_sprite", "pos": Vector2(300, 300), "anchor": "top"}]
	var box := DecorLib.UNKNOWN_BOX
	var inside := Vector2(300, 300) + box.position + box.size / 2.0
	assert_eq(model.hit("C2", inside, 0.0), {"room": "C2", "kind": "decor", "index": 0})
	model.select(model.hit("C2", inside, 0.0))
	assert_eq(model.delete_selection(), "")
	assert_eq(r.decor, [])
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`surface_above`, `add_decor` missing).

- [ ] **Step 3: Implement** in `room_edit_model.gd`: update the `selection` doc comment to list `"decor"`; in `hit_all` add after the features loop:
```gdscript
	for i in r.decor.size():
		var d: Dictionary = r.decor[i]
		var dbox := DecorLib.texture_box(str(d.get("id", "")))
		if Rect2(dbox.position + (d["pos"] as Vector2), dbox.size).has_point(p):  # un-grown: a grown box would cover the ledge it stands on
			out.append(_sel(room_id, "decor", i))
```
In `begin_move` add `"decor":` (guard `i >= r.decor.size()`; `_drag = {"sel": sel, "before": _snap([sel["room"]]), "orig": r.decor[i]["pos"]}`), in `move_to`:
```gdscript
		"decor":
			var orig: Vector2 = _drag["orig"]
			var id := str(r.decor[sel["index"]].get("id", ""))
			var pos = _decor_base(sel["room"], orig + d, id)
			if pos is String and d.y != 0.0:
				pos = _decor_base(sel["room"], orig + Vector2(d.x, 0.0), id)  # a pointer that dips: keep sliding along the surface
			if pos is Vector2:
				r.decor[sel["index"]]["pos"] = pos
```
in `delete_selection` a `"decor"` arm like `"spawn"`'s (`r.decor.remove_at(i)`), and after the features section:
```gdscript
# --- decor ---

## The bottom edge of the first rock at or above `p`: null when `p` is outside the room, inside rock, or nothing is above it (under
## a top exit the generated ceiling is cut). A closed shortcut gate is not rock here, as in surface_below's default.
func surface_above(room_id: String, p: Vector2) -> Variant:
	if not bounds(rooms[room_id]).has_point(p):
		return null
	var best := -INF
	for rect in rock(room_id):
		var q: Rect2 = rect
		if q.has_point(p):
			return null
		if p.x >= q.position.x and p.x < q.end.x and q.end.y <= p.y and q.end.y > best:
			best = q.end.y
	return null if best == -INF else best

## A decor piece's position for a candidate point: x snapped; y the surface it stands on (found from one pixel above the point, as
## for features) or, for a top-anchored piece, hangs from (found from one pixel below). A Vector2, or the reason it is refused.
func _decor_base(room_id: String, p: Vector2, id: String) -> Variant:
	var q := Vector2(snap(p.x), p.y)
	if not bounds(rooms[room_id]).has_point(q):
		return "outside the room"
	var top := str(DecorLib.CATALOG.get(id, {}).get("anchor", "bottom")) == "top"
	var y = surface_above(room_id, q + Vector2(0.0, 1.0)) if top else surface_below(room_id, q - Vector2(0.0, 1.0))
	if y == null:
		return "nothing to hang from there: click under a ledge or the ceiling" if top else "nothing to stand on there: click open space above a floor or a ledge"
	return Vector2(q.x, float(y))

func add_decor(room_id: String, id: String, pos: Vector2) -> String:
	if not DecorLib.CATALOG.has(id):
		return "unknown decor '%s'" % id
	var base = _decor_base(room_id, pos, id)
	if base is String:
		return base
	var r: RoomDef = rooms[room_id]
	var before := _snap([room_id])
	r.decor.append(DecorLib.entry(id, base))
	_push(before)
	selection = _sel(room_id, "decor", r.decor.size() - 1)
	return ""
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit` (all). Expected: PASS.

- [ ] **Step 5: Mutation checks:** grow the decor hit box by `pick` (the ledge-beside-crystal test fails); drop the dip fallback (the drag test fails); let `surface_above` count gates (add `true` to `rock`; the top-exit test fails only for a shortcut gate room, so also assert it on C1's gated top exit in Step 1 if not covered).

- [ ] **Step 6: Commit** (`git commit -m "feat: the model places, hits, drags and deletes decor: it stands on or hangs from rock"`).

### Task 11: The Decor tool, palette and outline

**Files:** Modify `scripts/editor/room_view.gd`, `scripts/editor/editor_panels.gd`, `scripts/editor/room_editor.gd`, `tests/test_room_editor_scene.gd`.

**Interfaces:** `RoomView.decor_id` and tool `"decor"`; `_selection_rect` decor arm; unknown decor drawn as a red box; `EditorPanels` tool `Decor`, a decor palette (`ItemList`, `FOCUS_NONE`), signal `decor_chosen(id)`, `set_decor_ids(ids)`, `decor_palette_visible()`, `choose_decor(id)`; `RoomEditor` rebuilds the palette on `open_room` and `_free_rect` counts it.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd`):
```gdscript
func test_the_decor_tool_places_a_piece_that_stands_on_the_surface() -> void:
	view.tool = "decor"
	view.decor_id = "crystal_teal"
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	var placed: Dictionary = model.rooms["C1"].decor.back()
	assert_eq(placed["id"], "crystal_teal")
	assert_eq(model.selection["kind"], "decor")
	assert_eq(model.undo_depth(), 1)

func test_the_decor_tool_without_a_choice_says_so_and_refuses_with_a_message() -> void:
	view.tool = "decor"
	view.decor_id = ""
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	assert_eq(messages.size(), 1)
	view.decor_id = "vine"
	var top: Dictionary = model.rooms["C1"].exits.filter(func(e): return e["edge"] == "top")[0]
	var mid := (float(top["from"]) + float(top["to"])) / 2.0
	view.handle_event(_press(Vector2(mid, 200)))
	view.handle_event(_release(Vector2(mid, 200)))
	assert_eq(messages.size(), 2, "a hanging piece under a top exit has nothing to hang from")
	assert_eq(model.undo_depth(), 0)

func test_the_selected_decor_outline_and_an_unknown_pieces_red_box() -> void:
	model.rooms["C1"].decor.append({"id": "no_such_sprite", "pos": Vector2(300, 300)})
	view.show_room(model, "C1")
	await wait_process_frames(1)
	var i: int = model.rooms["C1"].decor.size() - 1
	model.select({"room": "C1", "kind": "decor", "index": i})
	assert_eq(view.selection_rect(), Rect2(Vector2(300, 300) + DecorLib.UNKNOWN_BOX.position, DecorLib.UNKNOWN_BOX.size))
	model.select({})
	view.refresh()
	assert_gt(view.overlay.get_children().filter(func(n): return n is Line2D).size(), 0, "nothing is selected, so the lines are the unknown piece's red box")

func test_an_unknown_decor_piece_can_be_reached_from_the_problems_list_and_deleted() -> void:
	var ed := await _editor()
	ed.model.rooms["C1"].decor.append({"id": "no_such_sprite", "pos": Vector2(300, 300), "anchor": "top"})
	ed.model.serial += 1
	ed.view.refresh()
	ed.panels.press("Validate")
	var at := ed.model.problems().find_custom(func(p): return p["pick"].get("kind", "") == "decor")
	assert_gte(at, 0, "decor_unknown lists it")
	ed.slot.click_problem(at)
	assert_eq(ed.model.selection["kind"], "decor")
	assert_ne(ed.view.selection_rect().size, Vector2.ZERO, "it has a box to centre on")
	var n: int = ed.model.rooms["C1"].decor.size()
	assert_eq(ed.model.delete_selection(), "")
	assert_eq(ed.model.rooms["C1"].decor.size(), n - 1)

func test_the_decor_palette_shows_for_the_decor_tool_and_follows_the_rooms_area() -> void:
	var ed := await _editor()
	ed.panels.press("Decor")
	assert_true(ed.panels.decor_palette_visible())
	assert_false(ed.panels.palette_visible())
	assert_eq(ed.panels.decor_palette_ids(), DecorLib.ids_for_biome("cave"))
	ed.open_room("G1")
	assert_eq(ed.panels.decor_palette_ids(), DecorLib.ids_for_biome("grotto"), "rebuilt for the new room's area")
	ed.panels.choose_decor("grotto_flowers")
	assert_eq(ed.view.decor_id, "grotto_flowers")
	assert_eq(ed._free_rect().position.x, 92.0, "the palette is counted when fitting")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (no Decor tool).

- [ ] **Step 3: Implement.** `room_view.gd`: tool doc adds `"decor"`; `var decor_id := ""  # what the Decor tool places`; `_release` arm:
```gdscript
		"decor":
			if decor_id == "":
				message.emit("choose a decor piece in the palette first")
			else:
				_report(_model.add_decor(_room_id, decor_id, p))
```
`_selection_rect` arm `"decor"` (guard `i >= r.decor.size()`; `box := DecorLib.texture_box(...)`; `Rect2(box.position + pos, box.size)`); in `_redraw_overlay`, after the feature markers, draw a red box for each unknown piece:
```gdscript
	for i in r.decor.size():
		var id := str(r.decor[i].get("id", ""))
		if not DecorLib.CATALOG.has(id) or Art.texture(id) == null:
			var box := DecorLib.texture_box(id)
			_box(Rect2(box.position + (r.decor[i]["pos"] as Vector2), box.size), COL_UNKNOWN, true)
```
`editor_panels.gd`: `TOOLS := ["Select", "Solid", "Creature", "Feature", "Decor", "Exit"]` (update its comment); signal `decor_chosen(id: String)`; `var _decor_palette := ItemList.new()` built like `_feature_palette` (position (0,50), size (92,290), `FOCUS_NONE`, `_small`, `item_selected` emits `decor_chosen`), added to `_root`; `func set_decor_ids(ids: Array) -> void` (clear, add items); `set_tool` adds `_decor_palette.visible = tool_name == "decor"`; `decor_palette_visible()`, `decor_palette_ids()`, `choose_decor(id)` (select the item, emit `decor_chosen`). `room_editor.gd`: `panels.decor_chosen.connect(func(id: String) -> void: view.decor_id = id)`; `_refresh_decor_palette()` calling `panels.set_decor_ids(DecorLib.ids_for_biome(model.rooms[room_id].area))`, called at the end of `_ready` (before the first `_sync`) and in `open_room` after `view.show_room`; `_free_rect`'s `left` also counts `panels.decor_palette_visible()`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** drop the `open_room` rebuild (the area test fails); draw no red box (the outline test fails); leave `_free_rect` unaware (its last assertion fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: the Decor tool: a palette for the room's biome, an outline, a red box for an unknown piece"`).

### Task 12: `decor_unknown`, decor width and gated holes in `over_hole`

**Files:** Modify `scripts/world/room_lint.gd`, `tests/test_room_lint.gd`.

**Interfaces:** `RoomLint.RULES` gains `"decor_unknown"` (thirteenth); `_over_hole` skips only exits with a `shortcut` for spawns and decor (and also gated exits for dressing), measures decor by `DecorLib.texture_box(id).size.x`, and picks `{kind: "decor", index}`; the header doc lists `decor`.

- [ ] **Step 1: Write the failing tests** (in `tests/test_room_lint.gd`: add these and **rewrite on purpose** `test_over_hole_skips_an_exit_with_a_gate_or_a_shortcut`):
```gdscript
func test_decor_unknown_flags_an_id_outside_the_catalog_with_a_decor_pick() -> void:
	var bad := _room("T1", {"decor": [{"id": "no_such_sprite", "pos": Vector2(100, 320)}]})
	var f: Dictionary = RoomLint.check_room(bad, {"T1": bad}).filter(func(x): return x["rule"] == "decor_unknown")[0]
	assert_eq(f["pick"], {"room": "T1", "kind": "decor", "index": 0})
	var ok := _room("T1", {"decor": [DecorLib.entry("crystal_teal", Vector2(100, 320))]})
	assert_false(_rules(ok).has("decor_unknown"))

func test_the_rule_list_has_thirteen_rules() -> void:
	assert_eq(RoomLint.RULES.size(), 13)

func test_over_hole_skips_a_shortcut_exit_for_everything() -> void:
	var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2", "shortcut": "s1"}
	var piece: String = DressingLib.piece_names("cave")[0]
	var r := _room("T1", {"exits": [e], "spawns": [{"id": "bat", "pos": Vector2(250, 280)}],
		"decor": [DecorLib.entry("crystal_teal", Vector2(250, 300))],
		"dressing": [{"piece": piece, "pos": Vector2(250, 300), "factor": 0.5}]})
	assert_false(_rules(r).has("over_hole"))

func test_over_hole_counts_a_gated_hole_for_creatures_and_decor_but_not_dressing() -> void:
	var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2", "gate": "wall_cling"}
	var spawn := _room("T1", {"exits": [e], "spawns": [{"id": "bat", "pos": Vector2(250, 280)}]})
	assert_true(_rules(spawn).has("over_hole"), "only a shortcut closes a hole in play")
	var decor := _room("T1", {"exits": [e], "decor": [DecorLib.entry("crystal_teal", Vector2(250, 300))]})
	assert_true(_rules(decor).has("over_hole"))
	var piece: String = DressingLib.piece_names("cave")[0]
	var dressing := _room("T1", {"exits": [e], "dressing": [{"piece": piece, "pos": Vector2(250, 300), "factor": 0.5}]})
	assert_false(_rules(dressing).has("over_hole"), "C3's stone arch: dressing over a gated hole stays allowed")

func test_over_hole_measures_decor_by_its_texture_width() -> void:
	var wide := DecorLib.texture_box("deep_bones").size.x
	assert_gt(wide, 40.0, "the test needs a decor piece wider than the old fixed 24")
	var r := _hole_room({"area": "deep", "decor": [DecorLib.entry("deep_bones", Vector2(300.0 + 20.0, 320))]})
	assert_true(_rules(r).has("over_hole"), "its edge hangs over the hole although its centre is beside it")
	var far := _hole_room({"area": "deep", "decor": [DecorLib.entry("deep_bones", Vector2(300.0 + wide, 320))]})
	assert_false(_rules(far).has("over_hole"))
```
(delete the old `test_over_hole_skips_an_exit_with_a_gate_or_a_shortcut`; the two tests above replace it.)

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL.

- [ ] **Step 3: Implement** in `room_lint.gd`: add `"decor_unknown"` to `RULES`; in `check_room` add `out.append_array(_decor_unknown(r))`; in the header doc add `decor` to the pick kinds; add
```gdscript
static func _decor_unknown(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.decor.size():
		var id := str(r.decor[i].get("id", ""))
		if not DecorLib.CATALOG.has(id) or Art.texture(id) == null:
			out.append(_f(r, "decor_unknown", "decor '%s' is not a known decor sprite" % id, "decor", i))
	return out
```
and replace `_over_hole` with:
```gdscript
## test_grotto_rooms: nothing spawns or stands over a bottom exit that has no shortcut. Only a shortcut closes a hole in play
## (RoomBuilder.is_exit_open reads only the shortcut), so a gated hole counts for creatures and decor; dressing keeps the skip for a
## gated hole (C3's stone arch). A decor piece is measured by its sprite's width.
static func _over_hole(r: RoomDef) -> Array:
	var out: Array = []
	var floor_y := r.pixel_size().y - RoomDef.FLOOR
	for e in r.exits:
		if e["edge"] != "bottom" or e.has("shortcut"):
			continue
		var span := Vector2(e["from"], e["to"])
		for i in r.spawns.size():
			if _over(span, floor_y, r.spawns[i]["pos"], Vector2(16, 12)):
				out.append(_f(r, "over_hole", "spawn %s is over its floor hole" % r.spawns[i]["id"], "spawn", i))
		for i in r.decor.size():
			var d: Dictionary = r.decor[i]
			var width := DecorLib.texture_box(str(d.get("id", ""))).size.x
			if _over(span, floor_y, d["pos"], Vector2(width, 24)):
				out.append(_f(r, "over_hole", "decor %s is over its floor hole" % d["id"], "decor", i))
		if e.has("gate"):
			continue
		for p in r.dressing:
			if _over(span, floor_y, p["pos"], DressingLib.size(r.area, p["piece"])):
				out.append(_f(r, "over_hole", "dressing %s is over its floor hole" % p["piece"]))
	return out
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_lint`, `test_rooms`, `test_grotto_rooms`. Expected: PASS (the shipped world stays clean: C3's gated hole has nothing over it but dressing).

- [ ] **Step 5: Mutation checks:** restore the fixed `Vector2(24, 24)` extent (the width test fails); skip only `shortcut` OR `gate` as before (the gated tests fail); drop the dressing `gate` skip (the dressing test fails).

- [ ] **Step 6: Full suite** (end of milestone C): `tools/run_tests.sh`. Expected: PASS. Commit: `git commit -m "feat: decor_unknown, and over_hole counts a gated hole and measures decor by its width"`.

---

## Milestone D: Gate and hint

### Task 13: The validator knows the gates

**Files:** Modify `scripts/world/world_validator.gd`, `tests/test_world_validator.gd`.

**Interfaces:** `WorldValidator.GATES := ["wall_cling"]`; an exit whose `gate` is not in it is an error; a pair's gates must match as its shortcuts must.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_world_validator.gd`; uses its `_pair()` and `_errors()`):
```gdscript
func test_a_known_gate_on_both_halves_is_valid() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["gate"] = "wall_cling"
	rooms["B"].exits[0]["gate"] = "wall_cling"
	assert_eq(_errors(rooms), "")

func test_a_gate_on_one_half_only_is_reported() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["gate"] = "wall_cling"
	assert_string_contains(_errors(rooms), "A: right exit to B has a different gate than its partner")

func test_an_unknown_gate_is_reported_even_when_both_halves_agree() -> void:
	var rooms := _pair()
	rooms["A"].exits[0]["gate"] = "wall_clinng"
	rooms["B"].exits[0]["gate"] = "wall_clinng"
	assert_string_contains(_errors(rooms), "unknown gate 'wall_clinng'")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL.

- [ ] **Step 3: Implement** in `world_validator.gd`: add `const GATES := ["wall_cling"]  # the labels an exit's gate may carry; P4 gives them teeth`; in the exit check, after the span test add
```gdscript
	if e.has("gate") and not GATES.has(str(e["gate"])):
		out.append("%s: %s exit to %s has an unknown gate '%s'" % [a.id, edge, e.get("room", ""), e["gate"]])
```
and after the shortcut comparison add
```gdscript
	elif partner.get("gate", "") != e.get("gate", ""):
		out.append("%s: %s exit to %s has a different gate than its partner" % [a.id, edge, b.id])
```
(keeping the `if partner.is_empty(): ... elif shortcut ...: ... elif gate ...` chain), and update the class doc ("with the same shortcut id and the same gate").

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_world_validator`, `test_rooms`, `test_room_reachable`. Expected: PASS (shipped pairs C2/C3 and G3/G5 both carry `wall_cling` on both halves).

- [ ] **Step 5: Mutation check:** drop the partner gate comparison (the one-half test fails). Commit: `git commit -m "feat: the validator knows the gates: an unknown gate is an error and a pair must agree"`.

### Task 14: Gate and hint fields

**Files:** Modify `scripts/editor/room_edit_model.gd`, `scripts/editor/inspector_panel.gd`, `tests/test_room_edit_fields.gd`, `tests/test_room_editor_scene.gd`.

**Interfaces:** `get_field` / `set_field` exit `gate` (both halves, `""` removes, a gate outside `WorldValidator.GATES` is refused) via `_set_exit_pair_key` (which replaces `_set_exit_shortcut`); tablet `hint` (`""` removes, a value outside `RoomLint.hintable_skill_ids()` is refused); an inspector string-choice control tagged `choice` (selects by item text; a stored value outside the list shows as its own item).

- [ ] **Step 1: Write the failing tests.** Model (append to `tests/test_room_edit_fields.gd`):
```gdscript
func test_an_exits_gate_lands_on_both_halves_in_one_step_and_none_removes_it() -> void:
	var sel := _exit_sel("C1", "C2")
	assert_eq(model.get_field(sel, "gate"), "")
	assert_eq(model.set_field(sel, "gate", "wall_cling"), "")
	var partner := model.partner_of("C1", sel["index"])
	assert_eq(model.rooms["C2"].exits[partner["index"]].get("gate", ""), "wall_cling")
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.set_field(sel, "gate", ""), "")
	assert_false(model.rooms["C1"].exits[sel["index"]].has("gate"))
	assert_false(model.rooms["C2"].exits[partner["index"]].has("gate"))
	assert_eq("\n".join(model.validate()), "")

func test_an_unknown_gate_is_refused() -> void:
	var sel := _exit_sel("C1", "C2")
	assert_ne(model.set_field(sel, "gate", "wall_clinng"), "")
	assert_eq(model.undo_depth(), 0)

func test_a_tablets_hint_is_set_removed_and_checked_against_the_compendium() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_eq(model.get_field(sel, "hint"), "echolocation")
	assert_eq(model.set_field(sel, "hint", "spore_cloud"), "")
	assert_eq(model.get_field(sel, "hint"), "spore_cloud")
	assert_ne(model.set_field(sel, "hint", "flight"), "", "an enemy-only skill has no Compendium slot")
	assert_eq(model.set_field(sel, "hint", ""), "")
	assert_false(model.rooms["C6"].features[sel["index"]].has("hint"))
	assert_ne(model.set_field(_feature_sel("C4", "glow_pool"), "hint", "leap"), "", "only a tablet has a hint")
```
Scene (append to `tests/test_room_editor_scene.gd`):
```gdscript
func test_the_gate_dropdown_writes_both_halves_and_shows_a_stored_unknown_gate_as_its_own_item() -> void:
	var ed := await _editor()
	var idx := -1
	for i in ed.model.rooms["C1"].exits.size():
		if ed.model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	ed.model.select({"room": "C1", "kind": "exit", "index": idx})
	ed.view.refresh()
	var pick: OptionButton = ed.slot.find_field("gate")
	assert_eq(pick.get_item_text(pick.selected), "none")
	pick.item_selected.emit(1)   # wall_cling
	assert_eq(ed.model.rooms["C1"].exits[idx].get("gate", ""), "wall_cling")
	ed.model.rooms["C1"].exits[idx]["gate"] = "typo_gate"   # hand-edited data
	ed.slot.show_inspector(ed.model, ed.model.selection)
	var shown: OptionButton = ed.slot.find_field("gate")
	assert_eq(shown.get_item_text(shown.selected), "typo_gate", "the control never shows 'none' for a gate that is there")

func test_the_hint_dropdown_sets_and_clears_a_tablets_hint() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	var idx: int = ed.model.rooms["C6"].features.find_custom(func(f): return f["kind"] == "tablet")
	ed.model.select({"room": "C6", "kind": "feature", "index": idx})
	ed.view.refresh()
	var pick: OptionButton = ed.slot.find_field("hint")
	pick.item_selected.emit(0)   # none
	assert_false(ed.model.rooms["C6"].features[idx].has("hint"))
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL.

- [ ] **Step 3: Implement.** Model: rename `_set_exit_shortcut` to `_set_exit_pair_key(room_id, i, key, value)` and `_write_exit_shortcut` to `_write_exit_key(e, key, value)` (erase when `""`), then in `set_field`'s `"exit"` arm:
```gdscript
		"exit":
			if i >= r.exits.size():
				return "no such field"
			match key:
				"shortcut":
					if str(value) != "" and not valid_id(str(value)):
						return "a shortcut id is letters, digits and underscore"
					return _set_exit_pair_key(room_id, i, "shortcut", str(value))
				"gate":
					if str(value) != "" and not WorldValidator.GATES.has(str(value)):
						return "unknown gate '%s'" % str(value)
					return _set_exit_pair_key(room_id, i, "gate", str(value))
			return "no such field"
```
`get_field` exit: `if i < r.exits.size() and (key == "shortcut" or key == "gate"): return r.exits[i].get(key, "")`. `_set_feature_field`: include `"hint"` in the tablet-only check, add the `"hint"` arm:
```gdscript
			"hint":
				if str(value) == "":
					next.erase("hint")
				elif not RoomLint.hintable_skill_ids().has(str(value)):
					return "'%s' is not a skill the Compendium holds" % str(value)
				else:
					next["hint"] = str(value)
```
and `get_field`'s feature arm: `"title", "text", "shortcut", "hint": return f.get(key, "")`. Inspector: `FIELDS["exit"]` gains `["gate", "Gate", "choice"]`, `FIELDS["tablet"]` gains `["hint", "Hint", "choice"]`; `_make` gains `"choice": return _choice(key)`; add `_choice`, `_choices(key)` (`gate`: `WorldValidator.GATES`; `hint`: `RoomLint.hintable_skill_ids()`), `_select_choice(pick, stored)` exactly as:
```gdscript
func _choice(key: String) -> OptionButton:
	var pick := OptionButton.new()
	pick.name = "field_" + key
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_font_size_override("font_size", FONT)
	pick.set_meta("choice", true)  # selected by item text, unlike the index-based level choice
	pick.add_item("none")
	for v in _choices(key):
		pick.add_item(str(v))
	_select_choice(pick, str(_model.get_field(_sel, key)))
	pick.item_selected.connect(func(i: int) -> void: _commit(key, "" if i == 0 else pick.get_item_text(i)))
	return pick

func _choices(key: String) -> Array:
	return WorldValidator.GATES if key == "gate" else RoomLint.hintable_skill_ids()

func _select_choice(pick: OptionButton, stored: String) -> void:
	if stored == "":
		pick.select(0)
		return
	for i in pick.item_count:
		if pick.get_item_text(i) == stored:
			pick.select(i)
			return
	pick.add_item(stored)  # a stored value outside the list (hand-edited data) shows as its own item
	pick.select(pick.item_count - 1)
```
and in `_show_stored`'s `OptionButton` arm: `if control.has_meta("choice"): _select_choice(control, str(stored)) else: (control as OptionButton).select(int(stored))`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_fields`, `test_room_editor_scene`, `test_rooms`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** write only one exit half (the both-halves test fails); drop the `choice` meta (the unknown-gate display test fails); skip the hintable check (the `flight` refusal fails).

- [ ] **Step 6: Full suite** (end of milestone D): `tools/run_tests.sh`. Expected: PASS. Commit: `git commit -m "feat: an exit's gate and a tablet's hint in the inspector"`.

---

## Milestone E

### Task 15: Docs, shots, playtest lines and the final suite

**Files:** Modify `tools/editor_shots.gd`, `docs/rooms.md`, `docs/playtest-checklist.md`, `scripts/editor/room_editor.gd` (status hint), `scripts/editor/room_view.gd` (tool doc), `docs/superpowers/specs/2026-09-30-room-editor-p2-design.md` (one line under its phase table pointing at the P3 spec).

- [ ] **Step 1:** Status hint in `room_editor.gd` `_ready`: append ", Alt/Option-click selects what is under the selected thing". `docs/rooms.md`: a short section "Decor" (the catalog in `scripts/world/decor_lib.gd`, the 21 pinned ids, the 25 chosen rows, the `<biome>_` prefix rule, that a new biome's art needs catalog rows) and one line under the rules paragraph about gates (`WorldValidator.GATES`, a label for the validator and lint, a gated hole counts as a hole).
- [ ] **Step 2:** Extend `tools/editor_shots.gd`: create a `deep` room (`ed.new_room("left", "DeepA", "deep", Vector2i(1, 1))` beside C6) and a `flooded` room beside it, place a standing piece and a hanging piece with `ed.model.add_decor(...)` (use `deep_glow_fungus` and `deep_lichen_hang`), shoot the Decor tool with its palette, shoot the solid panel (select a ledge), and shoot the World view with both new biomes. Use `root.get_node(...)` for anything autoload; build the scene after frame 1. Run unsandboxed (`env HOME="$PWD/.tmp/editor-home" godot --path . -s res://tools/editor_shots.gd`), **read every PNG**, fix what looks wrong (clipped labels, a decor piece off its surface, the overview colours), re-shoot, and record the final look in the ledger.
- [ ] **Step 3:** Playtest lines under the Room editor section of `docs/playtest-checklist.md`: New room with Area `deep` or `flooded`; Decor tool (a standing piece on a ledge, a hanging piece under one; refused under a top exit and over a hole); a plain click on a ledge beside a crystal takes the ledge, **Option-click on a Mac (Alt-click elsewhere)** walks to what is under it, and an Option-drag moves it; a ledge's panel (type x, y, width, height; Rock from below on a thin ledge; the numbers follow a drag; Grow with a ledge selected); an exit's Gate (written to both rooms; Validate flags a hand-typed bad gate) and a tablet's Hint.
- [ ] **Step 4:** One line under the P3 row of the P2 spec's phase table: "P3 shipped as `2026-10-01-room-editor-p3-design.md`; what moved to P4 is listed there."
- [ ] **Step 5: Final suite:** `tools/run_tests.sh`. Expected: PASS.
- [ ] **Step 6: Commit** (`git commit -m "docs: the P3 playtest lines, the decor notes and shots of the new-biome editor"`).

---

## Final steps

Whole-branch review with an opus reviewer (`review-package` per the executing-plans skill; give it the Review Focus above verbatim and the spec), one fix pass (each fix RED to GREEN, suite green), a real windowed look at the editor on the merged tree, then `finishing-a-development-branch`: merge to `main`, run the full suite on the merged tree, push, relaunch the game.
