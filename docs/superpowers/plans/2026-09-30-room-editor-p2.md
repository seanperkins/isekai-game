# Room Editor P2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a whole new playable room without a text editor: place tablets, switches, pools and rebirth pools, edit their text and kit, add shortcut exits, grow a room, click a problem and land on it, and play with Wall Cling granted and shortcuts open. "Validate clean" becomes the same thing as "the suite's rule tests pass".

**Architecture:** `RoomLint` (pure statics in `scripts/world/`) holds the suite's level-design rules; the suite's rule tests and the editor's problems list both call it. The model (`RoomEditModel`) gains features, `get_field`/`set_field`, `grow_room`, `surface_below` and `problems()`. The view and panels gain a Feature tool, an inspector, a right-hand slot, two rows of buttons and a read-only World view. `Game` gains `kit` and `open_shortcuts` for an editor Play.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-30-room-editor-p2-design.md`

## Global Constraints

- Run tests with `tools/run_tests.sh [file-substring]` from `/Users/sean/sites/isekai-game/.worktrees/room-editor-p2`; any SCRIPT ERROR or Parse Error fails the run. After adding or renaming a `class_name` script or a scene, run `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1` before the tests.
- BSD `sed` needs `sed -i ''`. Edit files with Python or the Edit tool. Never `git checkout` a file to undo a mutation made on top of uncommitted work: copy it to `.tmp/` first and restore from the copy. Never `rm` a path built from a shell variable (the safety check refuses it): spell the path out.
- Constants from the spec: `MIN_EXIT` 36, `CLEAR` 64, reach budget 55 / 60 / 80, pool clearance 200 px, `MAX_SCREENS` 6, feature boxes tablet `Rect2(-6, -18, 12, 18)`, switch `Rect2(-9, -22, 18, 22)`, pools `Rect2(-19, -20, 38, 24)`; the Wall Cling kit is `{"skills": ["leap", "wall_cling"]}`.
- Stage directories (`git add scripts tests tools docs scenes data`) so `.gd.uid` files are committed. No attribution lines in commit messages.
- A test that sets `Game.play_request`, `Game.editor_resume` or `RoomEditor.sandbox_root` resets them in `after_each`. Scene tests that push mouse events hide GUT's own UI first and push with `push_input(ev, true)` (see `tests/test_room_editor_scene.gd`).
- Real windowed screenshots are taken unsandboxed with `env HOME="$PWD/.tmp/editor-home" godot --path . -s res://tools/editor_shots.gd`; the script cannot name `RoomEditor` or an autoload at compile time.

## Review Focus

1. A feature the editor places, drags or lints being wrongly refused or flagged: on a ledge top, between co-planar ledges, along a floor, in a side doorway or the wall column, at x = 12, over a hole.
2. The lifted rule tests changing meaning: a rule that now flags shipped data, a suite test asserting more than its own rule, a mutation turning a different test red, `over_hole` or `pool_clearance` scope drifting from the suite's.
3. Typed inspector text lost or applied to the wrong element: Save, Undo, Play, a room switch, Grow, a click in the room, Tab, Delete/Backspace inside a field; an equal value pushing an undo step.
4. `grow_room` corrupting a room: a non-start room's `NO_START` shifting into a second start, exits on perpendicular edges, partners, dressing/decor, the bottom moving, an overlap, `MAX_SCREENS`.
5. Play from the editor touching the real profile or `Compendium.progress`, the kit raising Compendium slots, the entry room still holding a gate or a switch with shortcuts open, `play_error` and `play` disagreeing on the spot.
6. `set_field` erasing G1's `affinity`, removing a required key, or writing one half of an exit's shortcut.

## File Map

- Create: `scripts/world/room_lint.gd`, `scripts/editor/inspector_panel.gd`, `scripts/editor/editor_slot.gd`, `scripts/editor/world_view.gd`, `tests/test_room_lint.gd`, `tests/test_room_edit_features.gd`, `tests/test_room_edit_fields.gd`, `tests/test_room_edit_grow.gd`, `tests/test_room_edit_problems.gd`, `tests/test_world_view.gd`.
- Modify: `scripts/editor/room_edit_model.gd`, `scripts/editor/room_view.gd`, `scripts/editor/editor_panels.gd`, `scripts/editor/room_editor.gd`, `scripts/game.gd`, `data/rooms/G4.tres`, `tests/test_prefabs.gd`, `tests/test_rooms.gd`, `tests/test_player_spread.gd`, `tests/test_grotto_rooms.gd`, `tests/test_room_edit_new_room.gd`, `tests/test_room_edit_exits.gd`, `tests/test_room_editor_scene.gd`, `tests/test_editor_play.gd`, `tools/editor_shots.gd`, `scripts/world/room_def.gd`, `scripts/world/room_features.gd`, `tests/support/shipped_rooms.gd`, `docs/superpowers/specs/2026-09-29-room-editor-design.md` (phase table note), `docs/playtest-checklist.md`.

---

## Milestone A: RoomLint and the suite lift

### Task 1: `RoomLint` core and the geometry rules

**Files:** Create `scripts/world/room_lint.gd`, `tests/test_room_lint.gd`; Modify `tests/test_prefabs.gd`, `tests/test_rooms.gd`, `tests/test_player_spread.gd`.

**Interfaces:**
- Produces: `RoomLint.check(rooms: Dictionary) -> Array`, `RoomLint.check_room(r: RoomDef, rooms: Dictionary) -> Array`, `RoomLint.text(findings: Array, rules: Array) -> String`, `RoomLint.rock(r: RoomDef) -> Array`, `RoomLint.embedded(r: RoomDef, base: Vector2) -> bool`, `RoomLint.exit_zone(size: Vector2, e: Dictionary) -> Rect2`, constants `MIN_EXIT`, `CLEAR`, `MASS`, `START_TOLERANCE`, `RULES`. A finding is `{room, rule, text, pick}`. Rules in this task: `solid_outside`, `outside`, `in_rock`, `exit_blocked`, `exit_narrow`, `start_floor`; the other six rules return `[]` until Tasks 2 and 3.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_lint.gd`)

```gdscript
extends GutTest
## RoomLint: the suite's level-design rules as one module. Shipped rooms are clean; each rule goes red on a synthetic room.

func _room(id := "T1", extra := {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = "cave"
	for k in extra:
		r.set(k, extra[k])
	return r

func _rules(r: RoomDef, rooms := {}) -> Array:
	var world := rooms if not rooms.is_empty() else {r.id: r}
	return RoomLint.check_room(r, world).map(func(f): return f["rule"])

func test_the_shipped_world_has_no_findings() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	assert_eq(RoomLint.text(RoomLint.check(rooms), RoomLint.RULES), "")

func test_a_finding_names_its_room_rule_text_and_pick() -> void:
	var r := _room("T1", {"spawns": [{"id": "toad", "pos": Vector2(5, 5)}]})  # inside the boundary wall
	var f: Dictionary = RoomLint.check_room(r, {"T1": r})[0]
	assert_eq([f["room"], f["rule"]], ["T1", "in_rock"])
	assert_eq(f["pick"], {"room": "T1", "kind": "spawn", "index": 0})
	assert_string_contains(f["text"], "toad")

func test_text_joins_only_the_named_rules() -> void:
	var r := _room("T1", {"spawns": [{"id": "toad", "pos": Vector2(5, 5)}], "solids": [Rect2(600, 100, 100, 20)]})
	var findings := RoomLint.check_room(r, {"T1": r})
	assert_ne(RoomLint.text(findings, ["in_rock"]), "")
	assert_ne(RoomLint.text(findings, ["solid_outside"]), "")
	assert_eq(RoomLint.text(findings, ["exit_narrow"]), "")

func test_solid_outside() -> void:
	assert_true(_rules(_room("T1", {"solids": [Rect2(600, 100, 100, 20)]})).has("solid_outside"))
	assert_false(_rules(_room("T1", {"solids": [Rect2(100, 100, 100, 20)]})).has("solid_outside"))

func test_outside_covers_spawns_and_the_start() -> void:
	assert_true(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(900, 100)}]})).has("outside"))
	assert_true(_rules(_room("T1", {"start": Vector2(-5, 308)})).has("outside"))
	assert_false(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(300, 100)}]})).has("outside"))

func test_in_rock_for_spawns_and_the_start_includes_the_boundary_walls() -> void:
	assert_true(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(5, 100)}]})).has("in_rock"), "the left wall")
	assert_true(_rules(_room("T1", {"solids": [Rect2(100, 100, 100, 40)], "spawns": [{"id": "toad", "pos": Vector2(150, 120)}]})).has("in_rock"))
	assert_false(_rules(_room("T1", {"spawns": [{"id": "toad", "pos": Vector2(300, 100)}]})).has("in_rock"))

func test_a_feature_is_embedded_only_when_it_is_stuck() -> void:
	var r := _room("T1", {"solids": [Rect2(200, 200, 100, 12)]})
	assert_false(RoomLint.embedded(r, Vector2(250, 200)), "standing on top of a ledge")
	assert_false(RoomLint.embedded(r, Vector2(100, 320)), "standing on the floor")
	assert_true(RoomLint.embedded(r, Vector2(250, 204)), "four pixels into the ledge")
	assert_true(RoomLint.embedded(r, Vector2(12, 320)), "in the wall column")
	assert_true(RoomLint.embedded(r, Vector2(630, 320)), "in the right wall column")

func test_in_rock_flags_an_embedded_feature_and_not_one_on_a_ledge() -> void:
	var on_ledge := _room("T1", {"solids": [Rect2(200, 200, 100, 12)], "features": [{"kind": "tablet", "id": "t1_tablet_1", "pos": Vector2(250, 200), "title": "T"}]})
	assert_false(_rules(on_ledge).has("in_rock"))
	var sunk := _room("T1", {"solids": [Rect2(200, 200, 100, 12)], "features": [{"kind": "tablet", "id": "t1_tablet_1", "pos": Vector2(250, 204), "title": "T"}]})
	assert_true(_rules(sunk).has("in_rock"))

func test_exit_blocked_by_mass_but_not_by_a_ledge() -> void:
	var exit := {"edge": "right", "from": 200.0, "to": 320.0, "room": "T2"}
	var mass := _room("T1", {"exits": [exit], "solids": [Rect2(520, 200, 60, 100)]})
	assert_true(_rules(mass).has("exit_blocked"))
	var ledge := _room("T1", {"exits": [exit], "solids": [Rect2(520, 250, 60, 12)]})
	assert_false(_rules(ledge).has("exit_blocked"))

func test_exit_zone_starts_at_the_wall_face() -> void:
	var size := Vector2(640, 360)
	assert_eq(RoomLint.exit_zone(size, {"edge": "right", "from": 200.0, "to": 320.0}), Rect2(556, 200, 64, 120))
	assert_eq(RoomLint.exit_zone(size, {"edge": "left", "from": 200.0, "to": 320.0}), Rect2(20, 200, 64, 120))
	assert_eq(RoomLint.exit_zone(size, {"edge": "top", "from": 100.0, "to": 200.0}), Rect2(100, 20, 100, 64))
	assert_eq(RoomLint.exit_zone(size, {"edge": "bottom", "from": 100.0, "to": 200.0}), Rect2(100, 256, 100, 64))

func test_exit_narrow() -> void:
	assert_true(_rules(_room("T1", {"exits": [{"edge": "right", "from": 200.0, "to": 230.0, "room": "T2"}]})).has("exit_narrow"))
	assert_false(_rules(_room("T1", {"exits": [{"edge": "right", "from": 200.0, "to": 236.0, "room": "T2"}]})).has("exit_narrow"))

func test_min_exit_is_at_least_what_the_rigged_body_needs_on_every_edge() -> void:
	var body := BodyConfig.COLLISION * float(BodyConfig.SCALE)
	assert_gte(RoomLint.MIN_EXIT, body.y + 8.0, "a left or right exit")
	assert_gte(RoomLint.MIN_EXIT, body.x + 8.0, "a top or bottom exit")

func test_start_floor() -> void:
	var good := _room("T1", {"start": Vector2(60, 360.0 - RoomDef.FLOOR - BodyConfig.BOTTOM)})
	assert_false(_rules(good).has("start_floor"))
	assert_true(_rules(_room("T1", {"start": Vector2(60, 200)})).has("start_floor"))
	assert_false(_rules(_room("T1")).has("start_floor"), "a room that is not the start has nothing to check")
```

- [ ] **Step 2: Run to verify it fails.** Run `tools/run_tests.sh test_room_lint`. Expected: FAIL (Parse Error: `RoomLint` not found).

- [ ] **Step 3: Implement** `scripts/world/room_lint.gd`:

```gdscript
class_name RoomLint
extends RefCounted
## The level-design rules the suite enforces, as one module: the suite's rule tests call it and the room editor's problems list
## shows the same findings, so "Validate clean" and "the suite's rule tests pass" are one set. Pure statics, no nodes. The
## validator (WorldValidator) is what the game needs to load and run; this is design.
##
## A finding is {room, rule, text, pick}: pick is a room-editor selection ({room, kind, index}) of an element that is a selection
## kind (solid, spawn, exit, feature), else {}.

## The smallest exit span: the rigged body plus 8 on either axis (test_player_spread pins MIN_EXIT >= both).
const MIN_EXIT := 36.0
## Nothing may stand this close in front of an exit (measured from the wall face).
const CLEAR := 64.0
## A solid thicker than this on both axes is mass; thinner is a ledge.
const MASS := 24.0
const START_TOLERANCE := 0.6
const REACH_RISE := 55.0
const REACH_GAP := 60.0
const REACH_HOP := 80.0
const POOL_CLEARANCE := 200.0

const RULES := ["solid_outside", "outside", "in_rock", "exit_blocked", "exit_narrow", "start_floor", "ledge_reach", "over_hole",
	"pool_clearance", "feature_id", "shortcut_pair", "hint_unknown"]

static func check(rooms: Dictionary) -> Array:
	var out: Array = []
	var ids := rooms.keys()
	ids.sort()
	for id in ids:
		out.append_array(check_room(rooms[id], rooms))
	return out

func _noop() -> void:
	pass

## Every finding for one room; `rooms` is the whole world (exit partners, shortcuts and feature ids need it).
static func check_room(r: RoomDef, rooms: Dictionary) -> Array:
	var out: Array = []
	out.append_array(_solid_outside(r))
	out.append_array(_outside(r))
	out.append_array(_in_rock(r))
	out.append_array(_exit_blocked(r))
	out.append_array(_exit_narrow(r))
	out.append_array(_start_floor(r))
	return out

## The findings of the named rules, one per line; "" when there are none.
static func text(findings: Array, rules: Array) -> String:
	var lines: Array = []
	for f in findings:
		if rules.has(f["rule"]):
			lines.append("%s [%s] %s" % [f["room"], f["rule"], f["text"]])
	return "\n".join(lines)

static func _f(r: RoomDef, rule: String, msg: String, kind := "", index := -1) -> Dictionary:
	var pick := {} if kind == "" else {"room": r.id, "kind": kind, "index": index}
	return {"room": r.id, "rule": rule, "text": msg, "pick": pick}

## Interior solids plus the generated boundary walls and floor: what nothing may stand inside.
static func rock(r: RoomDef) -> Array:
	var out: Array = r.solids.duplicate()
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		out.append(w["rect"])
	return out

## A feature's `pos` is its base. It is stuck when its x is inside a side wall column (a wall or a side doorway), or the point
## one pixel above the base is inside rock: Rect2.has_point includes the top edge, so testing the base itself would flag every
## feature standing on a ledge and refuse every horizontal drag.
static func embedded(r: RoomDef, base: Vector2) -> bool:
	var width := r.pixel_size().x
	if base.x < RoomDef.WALL or base.x > width - RoomDef.WALL:
		return true
	var above := base - Vector2(0.0, 1.0)
	for rect in rock(r):
		if (rect as Rect2).has_point(above):
			return true
	return false

## The floor space in front of an exit that must stay open: CLEAR deep, the exit's span wide, from the wall face.
static func exit_zone(size: Vector2, e: Dictionary) -> Rect2:
	var a := float(e["from"])
	var b := float(e["to"])
	match e["edge"]:
		"left": return Rect2(RoomDef.WALL, a, CLEAR, b - a)
		"right": return Rect2(size.x - RoomDef.WALL - CLEAR, a, CLEAR, b - a)
		"top": return Rect2(a, RoomDef.WALL, b - a, CLEAR)
	return Rect2(a, size.y - RoomDef.FLOOR - CLEAR, b - a, CLEAR)

static func _solid_outside(r: RoomDef) -> Array:
	var out: Array = []
	var bounds := Rect2(Vector2.ZERO, r.pixel_size())
	for i in r.solids.size():
		if not bounds.encloses(r.solids[i]):
			out.append(_f(r, "solid_outside", "solid %s is outside the room" % r.solids[i], "solid", i))
	return out

static func _outside(r: RoomDef) -> Array:
	var out: Array = []
	var local := Rect2(Vector2.ZERO, r.pixel_size())
	for i in r.spawns.size():
		if not local.has_point(r.spawns[i]["pos"]):
			out.append(_f(r, "outside", "%s at %s is outside the room" % [r.spawns[i]["id"], r.spawns[i]["pos"]], "spawn", i))
	if r.is_start() and not local.has_point(r.start):
		out.append(_f(r, "outside", "the start at %s is outside the room" % r.start))
	return out

static func _in_rock(r: RoomDef) -> Array:
	var out: Array = []
	var rocks := rock(r)
	for i in r.spawns.size():
		for rect in rocks:
			if (rect as Rect2).has_point(r.spawns[i]["pos"]):
				out.append(_f(r, "in_rock", "%s at %s is inside %s" % [r.spawns[i]["id"], r.spawns[i]["pos"], rect], "spawn", i))
				break
	if r.is_start():
		for rect in rocks:
			if (rect as Rect2).has_point(r.start):
				out.append(_f(r, "in_rock", "the start at %s is inside %s" % [r.start, rect]))
				break
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		if embedded(r, f["pos"]):
			out.append(_f(r, "in_rock", "feature %s at %s is stuck in rock or a wall" % [f.get("id", "?"), f["pos"]], "feature", i))
	return out

static func _exit_blocked(r: RoomDef) -> Array:
	var out: Array = []
	var size := r.pixel_size()
	for i in r.exits.size():
		var zone := exit_zone(size, r.exits[i])
		for s: Rect2 in r.solids:
			if s.size.y > MASS and s.size.x > MASS and zone.intersects(s):
				out.append(_f(r, "exit_blocked", "solid %s blocks the %s exit" % [s, r.exits[i]["edge"]], "exit", i))
				break
	return out

static func _exit_narrow(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.exits.size():
		var e: Dictionary = r.exits[i]
		if float(e["to"]) - float(e["from"]) < MIN_EXIT:
			out.append(_f(r, "exit_narrow", "the %s exit %s..%s is narrower than %d px" % [e["edge"], e["from"], e["to"], int(MIN_EXIT)], "exit", i))
	return out

static func _start_floor(r: RoomDef) -> Array:
	if not r.is_start():
		return []
	var want := r.pixel_size().y - RoomDef.FLOOR - BodyConfig.BOTTOM
	if absf(r.start.y - want) > START_TOLERANCE:
		return [_f(r, "start_floor", "the start's y is %s, the floor stand is %s" % [r.start.y, want])]
	return []
```

Delete the stray `func _noop` (it is not needed; remove it before running).

- [ ] **Step 4: Lift the suite tests.** Replace the bodies (keep the test names) so each asserts only its own rule through `RoomLint.text(RoomLint.check(rooms), [rule])`:
  - `tests/test_prefabs.gd`: `test_every_solid_is_inside_its_room` → `["solid_outside"]`; `test_nothing_stands_in_front_of_an_exit` → `["exit_blocked"]`; `test_exits_fit_the_body` → `["exit_narrow"]`; `test_spawns_and_features_are_not_inside_solids` → `["in_rock"]`; `test_start_stands_on_the_floor` → `["start_floor"]`; delete `_exit_zone` and the `CLEAR` and `MIN_EXIT` constants (grep for other uses first: `grep -n "CLEAR\|MIN_EXIT\|_exit_zone" tests/test_prefabs.gd`).
  - `tests/test_rooms.gd`: `test_spawns_and_the_start_sit_inside_their_room_and_outside_rock` → `["outside", "in_rock"]`.
  - `tests/test_player_spread.gd`: `test_every_room_exit_fits_the_rigged_slime` → `["exit_narrow"]` (the body-derived relation is pinned in `test_room_lint.gd`).
  - In each file `rooms` already holds every room on disk (`World.load_rooms`); in `test_rooms.gd` it is the `before_all` set; in `test_player_spread.gd` the function loads its own.
  - Add the aggregate test to `tests/test_rooms.gd`:

```gdscript
func test_the_world_has_no_lint_findings() -> void:
	assert_eq(RoomLint.text(RoomLint.check(rooms), RoomLint.RULES), "", "Validate clean is the same set as the suite's rules")
```

- [ ] **Step 5: Run to verify it passes:** `tools/run_tests.sh test_room_lint`, `test_prefabs`, `test_rooms`, `test_player_spread`. Expected: PASS.

- [ ] **Step 6: Mutation checks.** For each rule move or edit one thing in a copy of real data inside a scratch test run (or a temporary edit of `data/rooms/C1.tres` restored from a copy in `.tmp/`): a C1 spawn into a ledge turns exactly `test_spawns_and_the_start_sit_inside_their_room_and_outside_rock` red and no other lifted test; narrowing an exit turns `test_exits_fit_the_body` and `test_every_room_exit_fits_the_rigged_slime` red; the others likewise. Record the result in the ledger. Restore the data.

- [ ] **Step 7: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools docs scenes data && git commit -m "feat: RoomLint holds the geometry rules the suite enforced in test bodies"
```

---

### Task 2: `ledge_reach`, `over_hole` and `pool_clearance`

**Files:** Modify `scripts/world/room_lint.gd`, `tests/test_room_lint.gd`, `tests/test_rooms.gd`, `tests/test_grotto_rooms.gd`.

**Interfaces:** Produces the rules `ledge_reach`, `over_hole`, `pool_clearance` and constants `REACH_RISE`, `REACH_GAP`, `REACH_HOP`, `POOL_CLEARANCE` (already declared).

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_lint.gd`)

```gdscript
func test_ledge_reach_from_the_floor_by_base_jumps() -> void:
	# floor top 320; a ledge 50 up is reachable, one 120 up with nothing between is not
	var reachable := _room("T1", {"solids": [Rect2(200, 270, 100, 12)]})
	assert_false(_rules(reachable).has("ledge_reach"))
	var too_high := _room("T1", {"solids": [Rect2(200, 190, 100, 12)]})
	assert_true(_rules(too_high).has("ledge_reach"))
	var stepped := _room("T1", {"solids": [Rect2(200, 270, 100, 12), Rect2(320, 220, 100, 12)]})
	assert_false(_rules(stepped).has("ledge_reach"), "each hop within the budget")

func test_the_reach_budget_constants_are_the_suites_numbers() -> void:
	assert_eq([RoomLint.REACH_RISE, RoomLint.REACH_GAP, RoomLint.REACH_HOP], [55.0, 60.0, 80.0])

func _hole_room(extra := {}) -> RoomDef:
	var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2"}
	var base := {"exits": [e]}
	for k in extra:
		base[k] = extra[k]
	return _room("T1", base)

func test_over_hole_flags_a_spawn_or_decor_above_an_open_bottom_exit() -> void:
	assert_true(_rules(_hole_room({"spawns": [{"id": "bat", "pos": Vector2(250, 280)}]})).has("over_hole"))
	assert_true(_rules(_hole_room({"decor": [{"id": "crystal_teal", "pos": Vector2(250, 300)}]})).has("over_hole"))
	assert_false(_rules(_hole_room({"spawns": [{"id": "bat", "pos": Vector2(500, 280)}]})).has("over_hole"), "beside it")

func test_over_hole_checks_dressing_too() -> void:
	var piece: String = DressingLib.pieces("cave")[0] if DressingLib.has_method("pieces") else "stalagmite"
	assert_true(DressingLib.has_piece("cave", piece), "the test needs a real cave piece")
	var over := _hole_room({"dressing": [{"piece": piece, "pos": Vector2(250, 300), "factor": 0.5}]})
	assert_true(_rules(over).has("over_hole"))

func test_over_hole_skips_an_exit_with_a_gate_or_a_shortcut() -> void:
	for opts in [{"gate": "wall_cling"}, {"shortcut": "s1"}]:
		var e := {"edge": "bottom", "from": 200.0, "to": 300.0, "room": "T2"}
		e.merge(opts)
		var r := _room("T1", {"exits": [e], "spawns": [{"id": "bat", "pos": Vector2(250, 280)}]})
		assert_false(_rules(r).has("over_hole"), str(opts))

func _pool(id: String, area: String, pos: Vector2) -> Dictionary:
	return {"kind": "rebirth_pool", "id": id, "area": area, "pos": pos, "kit": {}}

func test_pool_clearance_applies_to_every_pool_but_the_default() -> void:
	var near := _room("T1", {"features": [_pool("t1_pool_1", "cave", Vector2(300, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_true(_rules(near).has("pool_clearance"), "a new cave pool is held to it too")
	var far := _room("T1", {"features": [_pool("t1_pool_1", "cave", Vector2(100, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_false(_rules(far).has("pool_clearance"))
	var default := _room("T1", {"features": [_pool(WorldProgress.DEFAULT_POOL, "cave", Vector2(300, 320))], "spawns": [{"id": "toad", "pos": Vector2(400, 300)}]})
	assert_false(_rules(default).has("pool_clearance"), "the default pool is older than the rule")
```

If `DressingLib` has no `pieces()` helper, replace the first line of `test_over_hole_checks_dressing_too` by reading one real piece id from `assets/dressing/cave/pieces.json` through whatever `DressingLib` exposes (read `scripts/world/dressing_lib.gd` first); the test only needs a piece id for which `DressingLib.has_piece("cave", id)` is true.

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (the three rules are not in `check_room`).

- [ ] **Step 3: Implement** in `room_lint.gd`: add to `check_room` `out.append_array(_ledge_reach(r))`, `_over_hole(r)`, `_pool_clearance(r)` and the functions:

```gdscript
## test_rooms: every ledge (thin, wider than 20) reachable from the floor by hops within the base-jump budget.
static func _ledge_reach(r: RoomDef) -> Array:
	var out: Array = []
	var ledges: Array = r.solids.filter(func(s: Rect2) -> bool: return s.size.y <= MASS and s.size.x > 20.0)
	var reached: Array = []
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		if w["kind"] == "ground":
			reached.append(w["rect"])
	var frontier: Array = reached.duplicate()
	while not frontier.is_empty():
		var p: Rect2 = frontier.pop_back()
		for q in ledges:
			if reached.has(q):
				continue
			var rise: float = p.position.y - q.position.y
			var gap: float = maxf(0.0, maxf(p.position.x - q.end.x, q.position.x - p.end.x))
			if (rise > 0.0 and rise <= REACH_RISE and gap <= REACH_GAP) or (rise <= 0.0 and gap <= REACH_HOP):
				reached.append(q)
				frontier.append(q)
	for i in r.solids.size():
		var s: Rect2 = r.solids[i]
		if ledges.has(s) and not reached.has(s):
			out.append(_f(r, "ledge_reach", "the ledge at %s cannot be reached from the floor by the base jump" % s, "solid", i))
	return out

## `pos` with `extent` (centred in x) overlaps the span horizontally and sits within 120 px above the floor line or below it.
static func _over(span: Vector2, floor_y: float, pos: Vector2, extent: Vector2) -> bool:
	var x_overlap := pos.x + extent.x / 2.0 > span.x and pos.x - extent.x / 2.0 < span.y
	return x_overlap and pos.y >= floor_y - 120.0

## test_grotto_rooms: nothing spawns or stands over a bottom exit that has neither a gate nor a shortcut. A gated hole is open in
## play (RoomBuilder.is_exit_open reads only the shortcut); counting it is P3's, with the gate field.
static func _over_hole(r: RoomDef) -> Array:
	var out: Array = []
	var floor_y := r.pixel_size().y - RoomDef.FLOOR
	for e in r.exits:
		if e["edge"] != "bottom" or e.has("gate") or e.has("shortcut"):
			continue
		var span := Vector2(e["from"], e["to"])
		for i in r.spawns.size():
			if _over(span, floor_y, r.spawns[i]["pos"], Vector2(16, 12)):
				out.append(_f(r, "over_hole", "spawn %s is over its floor hole" % r.spawns[i]["id"], "spawn", i))
		for d in r.decor:
			if _over(span, floor_y, d["pos"], Vector2(24, 24)):
				out.append(_f(r, "over_hole", "decor %s is over its floor hole" % d["id"]))
		for p in r.dressing:
			if _over(span, floor_y, p["pos"], DressingLib.size(r.area, p["piece"])):
				out.append(_f(r, "over_hole", "dressing %s is over its floor hole" % p["piece"]))
	return out

## test_grotto_rooms: nothing spawns within 200 px of a rebirth pool (a new life stands on it). The default pool is exempt.
static func _pool_clearance(r: RoomDef) -> Array:
	var out: Array = []
	for f in r.features:
		if f.get("kind", "") != "rebirth_pool" or f.get("id", "") == WorldProgress.DEFAULT_POOL:
			continue
		for i in r.spawns.size():
			var d: float = (r.spawns[i]["pos"] as Vector2).distance_to(f["pos"])
			if d <= POOL_CLEARANCE:
				out.append(_f(r, "pool_clearance", "%s spawns %d px from the rebirth pool %s" % [r.spawns[i]["id"], int(d), f.get("id", "?")], "spawn", i))
	return out
```

- [ ] **Step 4: Lift the tests.** `tests/test_rooms.gd::test_every_ledge_is_reachable_from_its_floor_by_base_jumps` → `["ledge_reach"]`. `tests/test_grotto_rooms.gd::test_nothing_spawns_or_stands_over_a_floor_hole` → `["over_hole"]` (delete its `_over` helper) and `test_nothing_spawns_near_a_rebirth_pool` → `["pool_clearance"]`; its directed-climb helpers read `RoomLint.REACH_RISE` / `REACH_GAP` instead of the local `RISE` and `GAP` (delete those two constants; keep `BODY`). Run `grep -n "RISE\|GAP" tests/test_grotto_rooms.gd` to find every use.

- [ ] **Step 5: Run to verify it passes:** `tools/run_tests.sh test_room_lint`, `test_rooms`, `test_grotto_rooms`. Expected: PASS (shipped data clean: C3's gated hole carries a `gate`, so it is skipped as before).

- [ ] **Step 6: Mutation checks:** drop a C1 ledge out of reach turns only `test_every_ledge_is_reachable_from_its_floor_by_base_jumps` red; a spawn over C5's hole turns only the hole test red; a spawn at 150 px from G1's pool turns only the pool test red. Record them.

- [ ] **Step 7: Import and commit** (`git commit -m "feat: RoomLint holds ledge reach, the floor-hole rule and pool clearance"`).

---

### Task 3: the three new rules and the G4 hint fix

**Files:** Modify `scripts/world/room_lint.gd`, `tests/test_room_lint.gd`, `data/rooms/G4.tres`.

**Interfaces:** Produces the rules `feature_id`, `shortcut_pair`, `hint_unknown` and `RoomLint.hintable_skill_ids() -> Array`.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_lint.gd`)

```gdscript
func _feat(kind: String, id: String, extra := {}) -> Dictionary:
	var f := {"kind": kind, "id": id, "pos": Vector2(300, 320)}
	for k in extra:
		f[k] = extra[k]
	return f

func test_feature_id_flags_an_empty_or_duplicated_id_across_the_world() -> void:
	var a := _room("T1", {"features": [_feat("tablet", "dup", {"title": "T"})]})
	var b := _room("T2", {"cell": Vector2i(1, 0), "features": [_feat("glow_pool", "dup")]})
	var world := {"T1": a, "T2": b}
	assert_true(_rules(a, world).has("feature_id"))
	assert_true(_rules(b, world).has("feature_id"))
	var empty := _room("T1", {"features": [_feat("glow_pool", "")]})
	assert_true(_rules(empty).has("feature_id"))
	var ok := _room("T1", {"features": [_feat("glow_pool", "t1_glow_pool_1")]})
	assert_false(_rules(ok).has("feature_id"))

func test_shortcut_pair_in_both_directions() -> void:
	var exit_s := {"edge": "right", "from": 200.0, "to": 320.0, "room": "T2", "shortcut": "s1"}
	var lonely_exit := _room("T1", {"exits": [exit_s]})
	assert_true(_rules(lonely_exit).has("shortcut_pair"), "an exit with a shortcut and no switch can never open")
	var lonely_switch := _room("T1", {"features": [_feat("switch", "t1_switch_1", {"shortcut": "s1"})]})
	assert_true(_rules(lonely_switch).has("shortcut_pair"), "a switch whose shortcut no exit uses opens nothing")
	var paired := _room("T1", {"exits": [exit_s], "features": [_feat("switch", "t1_switch_1", {"shortcut": "s1"})]})
	assert_false(_rules(paired).has("shortcut_pair"))
	var across := {"T1": _room("T1", {"exits": [exit_s]}), "T2": _room("T2", {"cell": Vector2i(1, 0), "features": [_feat("switch", "t2_switch_1", {"shortcut": "s1"})]})}
	assert_false(_rules(across["T1"], across).has("shortcut_pair"), "the pair is world-wide")
	assert_false(_rules(across["T2"], across).has("shortcut_pair"))

func test_hint_unknown_accepts_only_skills_the_compendium_has_a_slot_for() -> void:
	var ok := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T", "hint": "echolocation"})]})
	assert_false(_rules(ok).has("hint_unknown"))
	var none := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T"})]})
	assert_false(_rules(none).has("hint_unknown"), "a hint is optional")
	var made_up := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T", "hint": "spore shell"})]})
	assert_true(_rules(made_up).has("hint_unknown"))
	var enemy_only := _room("T1", {"features": [_feat("tablet", "t1_tablet_1", {"title": "T", "hint": "flight"})]})
	assert_true(_rules(enemy_only).has("hint_unknown"), "flight is an enemy-only skill: the Compendium has no slot for it")

func test_hintable_skill_ids_exclude_enemy_only_skills() -> void:
	var ids := RoomLint.hintable_skill_ids()
	assert_true(ids.has("echolocation"))
	assert_true(ids.has("spore_cloud"))
	assert_false(ids.has("flight"))
	assert_false(ids.has("poison_spit"))

func test_the_g4_tablet_hints_a_real_skill() -> void:
	var g4: RoomDef = load("res://data/rooms/G4.tres")
	var tablet: Dictionary = g4.features.filter(func(f): return f["kind"] == "tablet")[0]
	assert_true(RoomLint.hintable_skill_ids().has(tablet["hint"]), "was 'spore shell', which hinted nothing")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (rules and `hintable_skill_ids` missing; the G4 test fails on the data).

- [ ] **Step 3: Implement.** In `room_lint.gd`:

```gdscript
static var _hintable: Array = []

## Skill ids a tablet hint can name: CompendiumModel keeps no slot for an enemy_only skill, so raise() on one does nothing.
static func hintable_skill_ids() -> Array:
	if _hintable.is_empty():
		for d in RebirthKit.skill_defs():
			if d.source != "enemy_only":
				_hintable.append(d.id)
	return _hintable
```

and in `check_room` (after the geometry rules) `out.append_array(_feature_id(r, rooms))`, `_shortcut_pair(r, rooms)`, `_hint_unknown(r)`:

```gdscript
static func _feature_id(r: RoomDef, rooms: Dictionary) -> Array:
	var counts := {}
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			counts[f.get("id", "")] = int(counts.get(f.get("id", ""), 0)) + 1
	var out: Array = []
	for i in r.features.size():
		var fid: String = r.features[i].get("id", "")
		if fid == "":
			out.append(_f(r, "feature_id", "a %s has no id" % r.features[i].get("kind", "feature"), "feature", i))
		elif int(counts[fid]) > 1:
			out.append(_f(r, "feature_id", "the feature id '%s' is used %d times in the world" % [fid, counts[fid]], "feature", i))
	return out

## The world's switch shortcuts must equal its exits' shortcuts.
static func _shortcut_pair(r: RoomDef, rooms: Dictionary) -> Array:
	var switches := {}
	var exits := {}
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			if f.get("kind", "") == "switch":
				switches[f.get("shortcut", "")] = true
		for e in (rooms[id] as RoomDef).exits:
			if e.has("shortcut"):
				exits[e["shortcut"]] = true
	var out: Array = []
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		if f.get("kind", "") == "switch" and not exits.has(f.get("shortcut", "")):
			out.append(_f(r, "shortcut_pair", "the switch %s opens '%s', which no exit uses" % [f.get("id", "?"), f.get("shortcut", "")], "feature", i))
	for i in r.exits.size():
		var e: Dictionary = r.exits[i]
		if e.has("shortcut") and not switches.has(e["shortcut"]):
			out.append(_f(r, "shortcut_pair", "the %s exit's shortcut '%s' has no switch: it can never open" % [e["edge"], e["shortcut"]], "exit", i))
	return out

static func _hint_unknown(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		var hint: String = f.get("hint", "")
		if f.get("kind", "") == "tablet" and hint != "" and not hintable_skill_ids().has(hint):
			out.append(_f(r, "hint_unknown", "the tablet %s hints '%s', which is not a skill the Compendium holds" % [f.get("id", "?"), hint], "feature", i))
	return out
```

In `data/rooms/G4.tres` change `"hint": "spore shell"` to `"hint": "spore_cloud"`. The commit message says it is a gameplay change (the tablet now raises `spore_cloud` to HINTED when read). If a test pins the old value or the tablet text, update it (`grep -rn "spore shell" tests scripts data`).

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_lint`, `test_rooms` (the aggregate), `test_interactables`, `test_compendium_model`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** change one shipped switch's shortcut and see only `shortcut_pair` fire; blank a feature id and see only `feature_id`; set C6's hint to `flight` and see only `hint_unknown`. Record.

- [ ] **Step 6: Commit** (`git commit -m "feat: RoomLint finds switches and shortcut exits that do not pair, duplicate feature ids and hints the Compendium ignores; G4's tablet hints spore_cloud (gameplay change)"`).

---

### Task 4: the door rule and the constant sweep

**Files:** Modify `scripts/editor/room_edit_model.gd`, `tests/test_room_edit_new_room.gd`, `tests/test_room_edit_exits.gd`.

**Interfaces:** `RoomEditModel.KEEP_CLEAR` and `RoomEditModel.MIN_EXIT` are removed; `_clear_in_front` uses `RoomLint.exit_zone`.

- [ ] **Step 1: Write the failing test** (append to `tests/test_room_edit_new_room.gd`; also change `test_the_default_door_keeps_64px_clear_of_rock_in_the_neighbour` to build the strip with `RoomLint.exit_zone(size, e)` instead of its own `Rect2(size.x - KEEP_CLEAR ...)` and to read `RoomLint.CLEAR`)

```gdscript
func test_every_door_the_editor_makes_passes_exit_blocked() -> void:
	var made := 0
	for host in ["C1", "C2", "C3", "C6"]:
		for edge in ["right", "left", "top", "bottom"]:
			var m := RoomEditModel.new(ShippedRooms.load_all(), [])
			if m.new_room_beside(host, edge, "Fresh", "cave", Vector2i(1, 1)) != "":
				continue
			made += 1
			assert_eq(RoomLint.text(RoomLint.check_room(m.rooms[host], m.rooms), ["exit_blocked", "exit_narrow"]), "", "%s %s" % [host, edge])
	assert_gte(made, 4)
```

- [ ] **Step 2: Run to verify** the new test passes or fails for the right reason (it may already pass: P1's strip was stricter in depth but started at the room edge, not the wall face; a door whose strip clears `[w - 64, w)` may still have mass in `[w - 84, w - 64)`; if it fails, that is the finding this task fixes).

- [ ] **Step 3: Implement.** In `room_edit_model.gd`: delete `KEEP_CLEAR` and the model's `MIN_EXIT` (`MIN_EXIT` is used by `add_exit`: reference `RoomLint.MIN_EXIT`); replace `_clear_in_front`'s strip with the lint zone:

```gdscript
func _clear_in_front(a: RoomDef, edge: String, from: float, to: float) -> bool:
	var zone := RoomLint.exit_zone(a.pixel_size(), {"edge": edge, "from": from, "to": to})
	for s in a.solids:
		if (s as Rect2).intersects(zone):  # any solid, ledges too: stricter than exit_blocked, which counts mass only
			return false
	return true
```

Update every reference found by `grep -rn "KEEP_CLEAR\|RoomEditModel.MIN_EXIT\|MIN_EXIT" scripts tests` (tests: `test_room_edit_new_room.gd`, `test_room_edit_exits.gd` use `RoomEditModel.MIN_EXIT` for a message; point them at `RoomLint.MIN_EXIT`).

- [ ] **Step 4: Run to verify:** `tools/run_tests.sh test_room_edit`, `test_room_lint`. Expected: PASS.

- [ ] **Step 5: Full suite and commit (end of milestone A)**

```bash
tools/run_tests.sh   # Expected: PASS
git add scripts tests tools docs scenes data && git commit -m "feat: the new-room door uses RoomLint's exit zone and constants"
```

---

## Milestone B: the model

### Task 5: `surface_below`, features and the `feature` selection arms

**Files:** Modify `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_features.gd`.

**Interfaces:**
- Produces: `RoomEditModel.FEATURE_KINDS`, `FEATURE_BOX`, `surface_below(room_id, p, with_gates := false) -> Variant`, `floor_spot(room_id, p, with_gates := true) -> Variant` (behaviour unchanged), `add_feature(room_id: String, kind: String, pos: Vector2) -> String`, selection kind `feature` in `hit`, `begin_move`, `move_to`, `delete_selection`, and explicit refusing fallbacks.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_features.gd`)

```gdscript
extends GutTest
## Features: placement on the surface below the click, ids, hit boxes, drag and delete; P1's floor_spot rule is unchanged.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func _features(room: String, kind := "") -> Array:
	return model.rooms[room].features.filter(func(f): return kind == "" or f["kind"] == kind)

# --- surface_below and floor_spot ---

func test_surface_below_finds_floor_ledge_and_refuses_rock_holes_and_outside() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(200, 250, 100, 12)]
	var floor_y: float = r.pixel_size().y - RoomDef.FLOOR
	assert_eq(model.surface_below("C1", Vector2(250, 100)), 250.0, "a ledge")
	assert_eq(model.surface_below("C1", Vector2(120, 100)), floor_y, "the floor")
	assert_null(model.surface_below("C1", Vector2(250, 255)), "inside rock")
	assert_null(model.surface_below("C1", Vector2(-10, 100)), "outside the room")

func test_surface_below_counts_a_closed_gate_only_when_asked() -> void:
	var r: RoomDef = model.rooms["C6"]
	var gate := Rect2(0, 0, 0, 0)
	for e in r.exits:
		if e.has("shortcut"):
			gate = RoomBuilder.gate_rect(r.pixel_size(), e)
	assert_ne(gate.size, Vector2.ZERO, "C6 has a shortcut exit in its floor")
	var p := Vector2(gate.get_center().x, 100)
	assert_null(model.surface_below("C6", p), "to a feature the gate is not rock: it vanishes when opened")
	assert_eq(model.surface_below("C6", p, true), gate.position.y)

func test_floor_spot_keeps_its_p1_behaviour_and_counts_gates_by_default() -> void:
	var r: RoomDef = model.rooms["C1"]
	r.solids = [Rect2(200, 250, 100, 12)]
	assert_eq(model.floor_spot("C1", Vector2(250, 100)), Vector2(250, 250 - BodyConfig.BOTTOM))
	assert_null(model.floor_spot("C1", Vector2(250, 255)), "inside rock")
	var c6: RoomDef = model.rooms["C6"]
	var gate: Rect2 = RoomBuilder.gate_rect(c6.pixel_size(), c6.exits.filter(func(e): return e.has("shortcut"))[0])
	var over := Vector2(gate.get_center().x, 100)
	assert_eq(model.floor_spot("C6", over), Vector2(over.x, gate.position.y - BodyConfig.BOTTOM), "a closed gate is a surface for Play")
	assert_null(model.floor_spot("C6", over, false), "with shortcuts open there is a hole")

# --- placing ---

func test_each_kind_is_placed_on_the_surface_with_its_defaults_and_selected() -> void:
	assert_eq(model.add_feature("C2", "tablet", Vector2(404, 100)), "")
	var t: Dictionary = _features("C2", "tablet").back()
	assert_eq(t["pos"].x, 404.0)
	assert_eq([t["title"], t["text"]], ["Tablet", ""])
	assert_eq(model.selection["kind"], "feature")
	assert_eq(model.add_feature("C2", "switch", Vector2(600, 100)), "")
	var s: Dictionary = _features("C2", "switch").back()
	assert_eq(s["shortcut"], s["id"], "a switch starts with its own id as its shortcut")
	assert_eq(model.add_feature("C2", "rebirth_pool", Vector2(700, 100)), "")
	var p: Dictionary = _features("C2", "rebirth_pool").back()
	assert_eq([p["area"], p["kit"]], ["cave", {}])
	assert_eq(model.add_feature("C2", "glow_pool", Vector2(800, 100)), "")
	assert_eq(model.undo_depth(), 4)

func test_a_feature_on_a_ledge_stands_on_top_of_it() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 100, 12)]
	assert_eq(model.add_feature("C2", "tablet", Vector2(240, 120)), "")
	assert_eq(_features("C2", "tablet").back()["pos"], Vector2(240, 200))
	assert_eq(RoomLint.text(RoomLint.check_room(r, model.rooms), ["in_rock"]), "", "a feature on a ledge is clean")

func test_placing_is_refused_in_rock_in_a_wall_in_a_doorway_over_a_hole_and_outside() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 100, 40)]
	assert_ne(model.add_feature("C2", "tablet", Vector2(250, 220)), "", "inside a solid")
	assert_ne(model.add_feature("C2", "tablet", Vector2(12, 100)), "", "x 12 is in the wall column")
	assert_ne(model.add_feature("C2", "tablet", Vector2(-50, 100)), "", "outside")
	assert_ne(model.add_feature("C2", "teapot", Vector2(300, 100)), "", "an unknown kind")
	var left_exit_y: float = (r.exits.filter(func(e): return e["edge"] == "left")[0]["from"] + 20.0)
	assert_ne(model.add_feature("C2", "tablet", Vector2(10, left_exit_y)), "", "a side doorway")
	assert_eq(model.undo_depth(), 0)
	# a hole: remove C2's floor under x=600..700 by adding a bottom exit pair is P1 work; use a room with a bottom exit
	var c5: RoomDef = model.rooms["C5"]
	var hole: Dictionary = c5.exits.filter(func(e): return e["edge"] == "bottom")[0]
	var mid := (float(hole["from"]) + float(hole["to"])) / 2.0
	assert_ne(model.add_feature("C5", "tablet", Vector2(mid, c5.pixel_size().y - 60.0)), "", "nothing below it")

func test_ids_are_unique_across_the_world_and_never_reuse_a_taken_one() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	model.add_feature("C2", "tablet", Vector2(500, 100))
	var ids := _features("C2", "tablet").map(func(f): return f["id"])
	assert_eq(ids, ["c2_tablet_1", "c2_tablet_2"])
	model.select({"room": "C2", "kind": "feature", "index": 0})
	model.delete_selection()
	model.add_feature("C2", "tablet", Vector2(600, 100))
	assert_eq(_features("C2", "tablet").map(func(f): return f["id"]), ["c2_tablet_2", "c2_tablet_1"], "the first unused n")

# --- selection, drag, delete ---

func test_hit_finds_a_feature_by_its_drawn_box_and_a_pools_upper_half() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	var base: Vector2 = _features("C2", "tablet").back()["pos"]
	assert_eq(model.hit("C2", base + Vector2(0, -12), 0.0)["kind"], "feature", "the tablet's body above its base")
	assert_ne(model.hit("C2", base + Vector2(0, 30), 0.0).get("kind", ""), "feature")
	model.add_feature("C2", "glow_pool", Vector2(600, 100))
	var pool: Vector2 = _features("C2", "glow_pool").back()["pos"]
	assert_eq(model.hit("C2", pool + Vector2(0, -15), 0.0)["kind"], "feature", "the pool's upper half")
	assert_eq(model.hit("C2", pool + Vector2(17, 2), 0.0)["kind"], "feature", "near its edge")

func test_spawns_beat_features_which_beat_exits_and_solids() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	var base: Vector2 = _features("C2", "tablet").back()["pos"]
	model.rooms["C2"].spawns.append({"id": "toad", "pos": base + Vector2(0, -8)})
	assert_eq(model.hit("C2", base + Vector2(0, -8), 0.0)["kind"], "spawn")

func test_a_feature_drags_along_the_floor_and_between_coplanar_ledges() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(200, 200, 60, 12), Rect2(300, 200, 60, 12)]
	model.add_feature("C2", "tablet", Vector2(220, 100))
	var sel := {"room": "C2", "kind": "feature", "index": r.features.size() - 1}
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(100, 0))
	assert_eq(r.features[sel["index"]]["pos"], Vector2(320, 200), "onto the next ledge at the same height")
	model.move_to(Vector2(0, 0))
	assert_eq(r.features[sel["index"]]["pos"], Vector2(220, 200))
	model.end_move()
	assert_eq(model.undo_depth(), 2, "the placement and the drag is one step each, a click pushes none")
	var floor_y: float = r.pixel_size().y - RoomDef.FLOOR
	model.begin_move(sel)
	model.move_to(Vector2(-60, 200))
	assert_eq(r.features[sel["index"]]["pos"].y, floor_y, "dropped to the floor")
	model.end_move()

func test_a_drag_into_rock_stays_at_the_last_valid_spot() -> void:
	var r: RoomDef = model.rooms["C2"]
	r.solids = [Rect2(400, 100, 100, 200)]
	model.add_feature("C2", "tablet", Vector2(300, 100))
	var sel := {"room": "C2", "kind": "feature", "index": r.features.size() - 1}
	var start: Vector2 = r.features[sel["index"]]["pos"]
	model.begin_move(sel)
	model.move_to(Vector2(120, 0))
	assert_eq(r.features[sel["index"]]["pos"], start, "x 420 is inside the solid")
	model.end_move()

func test_delete_removes_a_feature_and_never_an_exit() -> void:
	model.add_feature("C2", "tablet", Vector2(404, 100))
	var exits_before: Array = model.rooms["C2"].exits.duplicate(true)
	var n := _features("C2").size()
	assert_eq(model.delete_selection(), "")
	assert_eq(_features("C2").size(), n - 1)
	assert_eq(model.rooms["C2"].exits, exits_before, "Delete on a feature leaves the exits alone")
	model.select({"room": "C2", "kind": "decor", "index": 0})
	assert_ne(model.delete_selection(), "", "an unknown kind is refused, never routed to an exit")
	assert_eq(model.rooms["C2"].exits, exits_before)
	model.select({"room": "C2", "kind": "decor", "index": 0})
	assert_false(model.begin_move(model.selection))

func test_a_new_feature_is_lint_clean_and_undo_restores_the_room() -> void:
	var before := RoomEditModel.copy_room(model.rooms["C2"])
	model.add_feature("C2", "glow_pool", Vector2(404, 100))
	assert_eq(RoomLint.text(RoomLint.check(model.rooms), RoomLint.RULES), "")
	model.undo()
	assert_true(RoomEditModel.same_room(before, model.rooms["C2"]))
```

(Pick coordinates that are open air in the shipped rooms: if a chosen point is inside C2's data, adjust it when writing the test; the assertions, not the numbers, are the contract. The hole case uses C5's shipped bottom exit.)

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`surface_below`, `add_feature` not found).

- [ ] **Step 3: Implement** in `room_edit_model.gd`:

```gdscript
const FEATURE_KINDS := ["glow_pool", "tablet", "switch", "rebirth_pool"]
## The drawn box of each feature kind relative to its base point: the one source for hit-testing, the selection outline and the
## marker. The pools are the 37x23 water_pool sprite, whose bottom sits 4 px below the base.
const FEATURE_BOX := {
	"tablet": Rect2(-6, -18, 12, 18),
	"switch": Rect2(-9, -22, 18, 22),
	"glow_pool": Rect2(-19, -20, 38, 24),
	"rebirth_pool": Rect2(-19, -20, 38, 24),
}

## The top of the first solid or boundary floor at or under `p`: null when `p` is outside the room, inside rock, or nothing is
## below it. `with_gates` adds the gates of closed shortcut exits as surfaces (Play stands on them; a feature does not, since
## they vanish when the shortcut opens).
func surface_below(room_id: String, p: Vector2, with_gates := false) -> Variant:
	if not bounds(rooms[room_id]).has_point(p):
		return null
	var best := INF
	for rect in rock(room_id, with_gates):
		var q: Rect2 = rect
		if q.has_point(p):
			return null
		if p.x >= q.position.x and p.x < q.end.x and q.position.y >= p.y and q.position.y < best:
			best = q.position.y
	return null if best == INF else best

## Where Play puts the slime for a click at `p` (the surface below it, a closed gate included by default; Play passes false when
## shortcuts are open). The two defaults are opposite on purpose: Play stands on a closed gate, a feature never does.
func floor_spot(room_id: String, p: Vector2, with_gates := true) -> Variant:
	var y = surface_below(room_id, p, with_gates)
	return null if y == null else Vector2(p.x, float(y) - BodyConfig.BOTTOM)
```

(replace the existing `floor_spot` body with these two; delete its loop.)

```gdscript
## A feature's base for a candidate point: x snapped, y the surface found from one pixel above the candidate (so a point exactly
## on a surface top, as every drag step is, finds that surface instead of being "inside" it). A Vector2, or the reason it is refused.
func _feature_base(room_id: String, p: Vector2) -> Variant:
	var r: RoomDef = rooms[room_id]
	var q := Vector2(snap(p.x), snap(p.y))
	if not bounds(r).has_point(q):
		return "outside the room"
	var y = surface_below(room_id, q - Vector2(0.0, 1.0))
	if y == null:
		return "nothing to stand on there: click open space above a floor or a ledge"
	var base := Vector2(q.x, float(y))
	if RoomLint.embedded(r, base):
		return "stuck in rock or a wall"
	return base

## The first n for which "<room>_<kind>_<n>" is not used by any feature in the world.
func _feature_id(room_id: String, kind: String) -> String:
	var taken := {}
	for id in rooms:
		for f in (rooms[id] as RoomDef).features:
			taken[f.get("id", "")] = true
	var n := 1
	while taken.has("%s_%s_%d" % [room_id.to_lower(), kind, n]):
		n += 1
	return "%s_%s_%d" % [room_id.to_lower(), kind, n]

func add_feature(room_id: String, kind: String, pos: Vector2) -> String:
	if not FEATURE_KINDS.has(kind):
		return "unknown feature '%s'" % kind
	var base = _feature_base(room_id, pos)
	if base is String:
		return base
	var r: RoomDef = rooms[room_id]
	var id := _feature_id(room_id, kind)
	var f := {"kind": kind, "id": id, "pos": base}
	match kind:
		"tablet":
			f["title"] = "Tablet"
			f["text"] = ""
		"switch":
			f["shortcut"] = id
		"rebirth_pool":
			f["area"] = r.area
			f["kit"] = {}
	var before := _snap([room_id])
	r.features.append(f)
	_push(before)
	selection = _sel(room_id, "feature", r.features.size() - 1)
	return ""
```

`hit`: after the spawn loop and before the exit loop add

```gdscript
	for i in r.features.size():
		var f: Dictionary = r.features[i]
		var box: Rect2 = FEATURE_BOX.get(f.get("kind", ""), Rect2(-6, -12, 12, 12))
		if Rect2(box.position + (f["pos"] as Vector2), box.size).grow(pick).has_point(p):
			return _sel(room_id, "feature", i)
```

`begin_move`: add an arm `"feature"` storing `_drag = {"sel": sel, "before": _snap([sel["room"]]), "orig": r.features[i]["pos"]}` (guard `i >= r.features.size()`); make the exit path explicit (`"exit": return _begin_move_exit(sel)`) and the fallback `_: return false`. `move_to`: add a `"feature"` arm:

```gdscript
		"feature":
			var base = _feature_base(sel["room"], (_drag["orig"] as Vector2) + d)
			if base is Vector2:
				r.features[sel["index"]]["pos"] = base
```

(make the exit arm explicit, `"exit": _move_exit_to(d)`, with an `_: pass` fallback). `delete_selection`: add

```gdscript
		"feature":
			if i >= r.features.size():
				return "nothing selected"
			var before := _snap([selection["room"]])
			r.features.remove_at(i)
			_push(before)
		"exit":
			return _delete_exit()
		_:
			return "nothing selected"
```

(replacing the `_: return _delete_exit()` fallthrough). Update the doc comment of `selection` to list `"feature"`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit` (all model files). Expected: PASS (the P1 `floor_spot` tests stay green).

- [ ] **Step 5: Mutation checks:** restore the `_: return _delete_exit()` fallthrough (the delete test fails); query `surface_below` from `q` instead of `q - (0,1)` (the co-planar drag test fails); drop the `embedded` call (the wall and doorway cases fail); draw the pool box 24x12 (the upper-half hit fails).

- [ ] **Step 6: Import and commit** (`git commit -m "feat: the editor places, drags and deletes features that stand on the surface below the click"`).

---

### Task 6: `get_field` and `set_field`

**Files:** Modify `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_fields.gd`.

**Interfaces:** `RoomEditModel.get_field(sel: Dictionary, key: String) -> Variant`, `set_field(sel: Dictionary, key: String, value) -> String`. Keys: exit `shortcut`; tablet `title`, `text`; switch `shortcut`; rebirth pool `kit_level`, `kit_skills`.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_fields.gd`)

```gdscript
extends GutTest
## Inspector fields: flat keys through get_field and set_field, one undo step each, required keys never removed.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func _feature_sel(room: String, kind: String) -> Dictionary:
	for i in model.rooms[room].features.size():
		if model.rooms[room].features[i]["kind"] == kind:
			return {"room": room, "kind": "feature", "index": i}
	return {}

func _exit_sel(room: String, to_room: String) -> Dictionary:
	for i in model.rooms[room].exits.size():
		if model.rooms[room].exits[i]["room"] == to_room:
			return {"room": room, "kind": "exit", "index": i}
	return {}

func test_a_tablets_title_and_text_round_trip_in_one_step_each() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_eq(model.get_field(sel, "title"), "Worn tablet")
	assert_eq(model.set_field(sel, "title", "Moss"), "")
	assert_eq(model.get_field(sel, "title"), "Moss")
	assert_eq(model.set_field(sel, "text", "A new line."), "")
	assert_eq(model.undo_depth(), 2)
	model.undo()
	assert_eq(model.get_field(sel, "text"), "Eat what hunts by sound in the dark, and you will hear as it does.")

func test_an_equal_value_is_a_no_op() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_eq(model.set_field(sel, "title", "Worn tablet"), "")
	assert_eq(model.undo_depth(), 0)
	assert_false(model.dirty.has("C6"))

func test_required_keys_are_never_removed_and_optional_ones_are() -> void:
	var sel := _feature_sel("C6", "tablet")
	assert_ne(model.set_field(sel, "title", ""), "", "a tablet needs a title")
	assert_eq(model.get_field(sel, "title"), "Worn tablet")
	assert_eq(model.set_field(sel, "text", ""), "", "text is optional")
	assert_eq(model.get_field(sel, "text"), "")
	var sw := _feature_sel("C6", "switch")
	assert_ne(model.set_field(sw, "shortcut", ""), "", "a switch needs its shortcut")
	assert_eq(model.get_field(sw, "shortcut"), "c6_drop")

func test_an_unknown_field_or_kind_is_refused() -> void:
	assert_ne(model.set_field(_feature_sel("C6", "tablet"), "colour", "red"), "")
	assert_ne(model.set_field(_feature_sel("C4", "glow_pool"), "title", "x"), "", "a glow pool has no title")

func test_a_shortcut_id_must_be_a_valid_id() -> void:
	var sw := _feature_sel("C6", "switch")
	assert_ne(model.set_field(sw, "shortcut", "has space"), "")
	assert_ne(model.set_field(sw, "shortcut", "../x"), "")
	assert_eq(model.set_field(sw, "shortcut", "new_path"), "")
	assert_eq(model.get_field(sw, "shortcut"), "new_path")

func test_an_exits_shortcut_lands_on_both_halves_in_one_step() -> void:
	var sel := _exit_sel("C1", "C2")
	assert_eq(model.get_field(sel, "shortcut"), "")
	assert_eq(model.set_field(sel, "shortcut", "front_door"), "")
	var partner := model.partner_of("C1", sel["index"])
	assert_eq(model.rooms["C2"].exits[partner["index"]]["shortcut"], "front_door")
	assert_eq(model.undo_depth(), 1)
	assert_eq(model.set_field(sel, "shortcut", ""), "", "an empty value removes it from both")
	assert_false(model.rooms["C1"].exits[sel["index"]].has("shortcut"))
	assert_false(model.rooms["C2"].exits[partner["index"]].has("shortcut"))
	assert_eq("\n".join(model.validate()), "", "the validator still pairs them")

func test_a_pools_level_and_skills_merge_into_the_kit_and_keep_the_rest() -> void:
	var sel := _feature_sel("G1", "rebirth_pool")
	var affinity: Dictionary = model.rooms["G1"].features[sel["index"]]["kit"]["affinity"].duplicate()
	assert_eq(model.set_field(sel, "kit_level", 5), "")
	assert_eq(model.get_field(sel, "kit_level"), 5)
	assert_eq(model.set_field(sel, "kit_skills", ["leap"]), "")
	assert_eq(model.get_field(sel, "kit_skills"), ["leap"])
	assert_eq(model.rooms["G1"].features[sel["index"]]["kit"]["affinity"], affinity, "G1's affinity survives every edit")
	assert_eq(model.set_field(sel, "kit_level", 0), "", "0 unsets the level")
	assert_false(model.rooms["G1"].features[sel["index"]]["kit"].has("level"))

func test_a_kit_the_validator_rejects_is_refused_and_changes_nothing() -> void:
	var sel := _feature_sel("G1", "rebirth_pool")
	var before := RoomEditModel.copy_room(model.rooms["G1"])
	assert_ne(model.set_field(sel, "kit_skills", ["not_a_skill"]), "")
	assert_ne(model.set_field(sel, "kit_skills", ["poison_spit"]), "", "enemy-only")
	assert_ne(model.set_field(sel, "kit_level", 11), "")
	assert_true(RoomEditModel.same_room(before, model.rooms["G1"]))
	assert_eq(model.undo_depth(), 0)

func test_the_pool_area_and_kit_are_required_keys() -> void:
	var sel := _feature_sel("G1", "rebirth_pool")
	assert_eq(model.rooms["G1"].features[sel["index"]].has("area"), true)
	assert_eq(model.rooms["G1"].features[sel["index"]].has("kit"), true)
	model.set_field(sel, "kit_skills", [])
	assert_true(model.rooms["G1"].features[sel["index"]].has("kit"), "an empty list unsets skills but the kit stays a Dictionary")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`get_field`/`set_field` missing).

- [ ] **Step 3: Implement** in `room_edit_model.gd`:

```gdscript
## The value of an inspector field for the selection (see set_field for the keys), or null for an unknown one.
func get_field(sel: Dictionary, key: String) -> Variant:
	if sel.is_empty() or not rooms.has(sel["room"]):
		return null
	var r: RoomDef = rooms[sel["room"]]
	var i: int = sel["index"]
	match sel["kind"]:
		"exit":
			if i < r.exits.size() and key == "shortcut":
				return r.exits[i].get("shortcut", "")
		"feature":
			if i >= r.features.size():
				return null
			var f: Dictionary = r.features[i]
			match key:
				"title", "text", "shortcut":
					return f.get(key, "")
				"kit_level":
					return int((f.get("kit", {}) as Dictionary).get("level", 0))
				"kit_skills":
					return ((f.get("kit", {}) as Dictionary).get("skills", []) as Array).duplicate()
	return null

## Sets one inspector field: exit "shortcut" (both halves); tablet "title" (required) and "text"; switch "shortcut" (required);
## rebirth pool "kit_level" (0 unsets) and "kit_skills" (a list), merged into the kit so every other key (G1's affinity) is kept.
## Optional keys are removed by "" or 0; required keys are never removed. A refusal returns the reason and changes nothing; a
## value equal to the stored one pushes nothing.
func set_field(sel: Dictionary, key: String, value) -> String:
	if sel.is_empty() or not rooms.has(sel["room"]):
		return "nothing selected"
	var room_id: String = sel["room"]
	var r: RoomDef = rooms[room_id]
	var i: int = sel["index"]
	match sel["kind"]:
		"exit":
			if i >= r.exits.size() or key != "shortcut":
				return "no such field"
			return _set_exit_shortcut(room_id, i, str(value))
		"feature":
			if i >= r.features.size():
				return "nothing selected"
			return _set_feature_field(room_id, i, key, value)
	return "no such field"

func _set_exit_shortcut(room_id: String, i: int, value: String) -> String:
	if value != "" and not valid_id(value):
		return "a shortcut id is letters, digits and underscore"
	var r: RoomDef = rooms[room_id]
	if str(r.exits[i].get("shortcut", "")) == value:
		return ""
	var p := partner_of(room_id, i)
	var ids: Array = [room_id]
	if not p.is_empty():
		ids.append(p["room"])
	var before := _snap(ids)
	_write_exit_shortcut(r.exits[i], value)
	if not p.is_empty():
		_write_exit_shortcut((rooms[p["room"]] as RoomDef).exits[p["index"]], value)
	_push(before)
	return ""

static func _write_exit_shortcut(e: Dictionary, value: String) -> void:
	if value == "":
		e.erase("shortcut")
	else:
		e["shortcut"] = value

func _set_feature_field(room_id: String, i: int, key: String, value) -> String:
	var r: RoomDef = rooms[room_id]
	var f: Dictionary = r.features[i]
	var kind: String = f.get("kind", "")
	if (key == "title" or key == "text") and kind != "tablet":
		return "a %s has no %s" % [kind, key]
	if key == "shortcut" and kind != "switch":
		return "a %s has no shortcut" % kind
	if (key == "kit_level" or key == "kit_skills") and kind != "rebirth_pool":
		return "a %s has no kit" % kind
	var next: Dictionary = f.duplicate(true)
	match key:
		"title":
			if str(value) == "":
				return "a tablet needs a title"
			next["title"] = str(value)
		"text":
			if str(value) == "":
				next.erase("text")
			else:
				next["text"] = str(value)
		"shortcut":
			if not valid_id(str(value)):
				return "a shortcut id is letters, digits and underscore (and not empty)"
			next["shortcut"] = str(value)
		"kit_level":
			var kit: Dictionary = next.get("kit", {})
			if int(value) == 0:
				kit.erase("level")
			else:
				kit["level"] = int(value)
			next["kit"] = kit
		"kit_skills":
			var kit: Dictionary = next.get("kit", {})
			if (value as Array).is_empty():
				kit.erase("skills")
			else:
				kit["skills"] = (value as Array).duplicate()
			next["kit"] = kit
		_:
			return "no such field"
	if kind == "rebirth_pool":
		var errs := RebirthKit.validate(next["kit"])
		if not errs.is_empty():
			return errs[0]
	if next == f:
		return ""
	var before := _snap([room_id])
	r.features[i] = next
	_push(before)
	return ""
```

(Edge: `valid_id("")` is false, which also refuses an empty switch shortcut.)

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_fields`, `test_room_edit_features`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** rebuild the kit from only `level` and `skills` (the G1 affinity test fails); write only one exit half (the validator assertion fails); drop the equality early-return (the no-op test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: the model edits an exit's shortcut, a tablet's text and a pool's kit through one get_field and set_field"`).

---

### Task 7: `grow_room`

**Files:** Modify `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_grow.gd`.

**Interfaces:** `RoomEditModel.grow_room(room_id: String, side: String, screens := 1) -> String`; sides `left`, `right`, `top`.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_grow.gd`)

```gdscript
extends GutTest
## Growing a room: whole screens, left, right or top; local positions shift so world positions never move.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

## A room with room on every side and no neighbours: a lone 1x1 room far from the shipped ones.
func _lone() -> RoomDef:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.solids = [Rect2(100, 200, 80, 12)]
	r.spawns = [{"id": "toad", "pos": Vector2(300, 300)}]
	r.features = [{"kind": "glow_pool", "id": "l1_glow_pool_1", "pos": Vector2(400, 320)}]
	r.decor = [{"id": "crystal_teal", "pos": Vector2(110, 320)}]
	r.dressing = [{"piece": "stalagmite", "pos": Vector2(500, 320), "factor": 0.5}]
	r.exits = []
	return r

func _with_lone() -> void:
	model.rooms["L1"] = _lone()
	model._baseline["L1"] = RoomEditModel.copy_room(model.rooms["L1"])

func _world_pos(r: RoomDef, local: Vector2) -> Vector2:
	return r.world_rect().position + local

func test_growing_right_adds_a_screen_and_moves_nothing() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	assert_eq(model.grow_room("L1", "right"), "")
	var r: RoomDef = model.rooms["L1"]
	assert_eq(r.size, Vector2i(2, 1))
	assert_eq(r.cell, before.cell)
	assert_eq(r.solids, before.solids)
	assert_eq(model.undo_depth(), 1)

func test_growing_left_shifts_every_local_position_and_keeps_world_positions() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	assert_eq(model.grow_room("L1", "left"), "")
	var r: RoomDef = model.rooms["L1"]
	assert_eq(r.cell, Vector2i(19, 20))
	assert_eq(r.size, Vector2i(2, 1))
	assert_eq(_world_pos(r, r.spawns[0]["pos"]), _world_pos(before, before.spawns[0]["pos"]))
	assert_eq(_world_pos(r, r.features[0]["pos"]), _world_pos(before, before.features[0]["pos"]))
	assert_eq(_world_pos(r, r.decor[0]["pos"]), _world_pos(before, before.decor[0]["pos"]))
	assert_eq(_world_pos(r, r.dressing[0]["pos"]), _world_pos(before, before.dressing[0]["pos"]))
	assert_eq(r.solids[0].position + r.world_rect().position, before.solids[0].position + before.world_rect().position)
	assert_eq(r.solids[0].size, before.solids[0].size)

func test_growing_the_top_shifts_down_and_the_floor_stays_where_it_was_in_the_world() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	assert_eq(model.grow_room("L1", "top"), "")
	var r: RoomDef = model.rooms["L1"]
	assert_eq(r.cell, Vector2i(20, 19))
	assert_eq(r.world_rect().end, before.world_rect().end, "the bottom is anchored")
	assert_eq(_world_pos(r, r.features[0]["pos"]), _world_pos(before, before.features[0]["pos"]))

func test_the_bottom_is_not_offered() -> void:
	_with_lone()
	assert_ne(model.grow_room("L1", "bottom"), "")
	assert_eq(model.undo_depth(), 0)

func test_a_non_start_room_stays_a_non_start_and_the_start_room_keeps_its_start() -> void:
	_with_lone()
	model.grow_room("L1", "left")
	model.grow_room("L1", "top")
	assert_false(model.rooms["L1"].is_start(), "NO_START (-1, -1) must not move")
	var c1: RoomDef = model.rooms["C1"]
	var world_before: Vector2 = c1.world_rect().position + c1.start
	assert_eq(model.grow_room("C1", "left"), "") if false else null
	var err := model.grow_room("C1", "top")
	if err == "":
		assert_eq(model.rooms["C1"].world_rect().position + model.rooms["C1"].start, world_before)
		assert_true(model.rooms["C1"].is_start())

func test_exits_on_perpendicular_edges_shift_along_the_grown_axis() -> void:
	_with_lone()
	var r: RoomDef = model.rooms["L1"]
	r.exits = [{"edge": "bottom", "from": 100.0, "to": 200.0, "room": "L9"}, {"edge": "right", "from": 200.0, "to": 320.0, "room": "L8"}]
	model.grow_room("L1", "left")
	assert_eq([r.exits[0]["from"], r.exits[0]["to"]], [740.0, 840.0], "a bottom exit moves along x by one screen width")
	assert_eq([r.exits[1]["from"], r.exits[1]["to"]], [200.0, 320.0], "a right exit does not move in y when growing left")
	model.grow_room("L1", "top")
	assert_eq([r.exits[1]["from"], r.exits[1]["to"]], [560.0, 680.0], "a right exit moves along y by one screen height")
	assert_eq([r.exits[0]["from"], r.exits[0]["to"]], [740.0, 840.0])

func test_a_side_that_touches_a_neighbour_is_refused_as_an_overlap() -> void:
	var err := model.grow_room("C1", "right")  # C2 is there
	assert_string_contains(err, "overlap")
	assert_eq(model.undo_depth(), 0)

func test_the_screen_cap_is_six() -> void:
	_with_lone()
	for i in 5:
		assert_eq(model.grow_room("L1", "right"), "")
	assert_eq(model.rooms["L1"].size.x, 6)
	assert_ne(model.grow_room("L1", "right"), "")

func test_undo_restores_the_exact_previous_room() -> void:
	_with_lone()
	var before := RoomEditModel.copy_room(model.rooms["L1"])
	model.grow_room("L1", "left")
	model.undo()
	assert_true(RoomEditModel.same_room(before, model.rooms["L1"]))

func test_ceiling_attached_content_ends_up_mid_air_as_documented() -> void:
	_with_lone()
	model.rooms["L1"].solids.append(Rect2(300, 20, 120, 32))  # hangs from the ceiling
	model.grow_room("L1", "top")
	assert_eq(model.rooms["L1"].solids[1].position.y, 380.0, "20 + one screen: now far below the new ceiling")

func test_a_grown_room_keeps_the_world_valid() -> void:
	_with_lone()
	model.grow_room("L1", "left")
	model.grow_room("L1", "top")
	assert_false("\n".join(model.validate()).contains("L1: overlaps"))
```

(The `test_a_non_start_room...` body above contains an awkward conditional line `assert_eq(model.grow_room("C1","left"), "") if false else null`; delete that line when writing the test: the start-room part grows C1's top and asserts the start's world position is unchanged only when the model accepts the growth. C1's top edge has the shortcut exit to C6 and C6 sits above it, so `grow_room("C1", "top")` is an overlap refusal; use a start room that can grow, by giving the lone room `start = Vector2(60, 308)` and checking it moves with the content: assert `world(start)` unchanged after growing left and top.)

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`grow_room` missing).

- [ ] **Step 3: Implement:**

```gdscript
## Grows a room by whole screens on its left, right or top. The bottom is anchored (the floor stays under floor-standing content).
## Refused only when the result would overlap another room or exceed MAX_SCREENS. Growing left or top changes `cell` and shifts
## every local position of this room so world positions never move; the start shifts only when this room is the start.
func grow_room(room_id: String, side: String, screens := 1) -> String:
	if not ["left", "right", "top"].has(side):
		return "a room grows to the left, right or top: the bottom stays where the floor is"
	if screens < 1:
		return "grow by at least one screen"
	var r: RoomDef = rooms[room_id]
	var new_size := r.size
	var new_cell := r.cell
	var shift := Vector2.ZERO
	match side:
		"right":
			new_size.x += screens
		"left":
			new_size.x += screens
			new_cell.x -= screens
			shift.x = screens * RoomDef.SCREEN.x
		"top":
			new_size.y += screens
			new_cell.y -= screens
			shift.y = screens * RoomDef.SCREEN.y
	if new_size.x > MAX_SCREENS or new_size.y > MAX_SCREENS:
		return "a room is at most %d screens each way" % MAX_SCREENS
	var rect := Rect2(Vector2(new_cell) * RoomDef.SCREEN, Vector2(new_size) * RoomDef.SCREEN)
	for id in rooms:
		if id != room_id and (rooms[id] as RoomDef).world_rect().intersects(rect):
			return "would overlap %s" % id
	var before := _snap([room_id])
	r.size = new_size
	r.cell = new_cell
	if shift != Vector2.ZERO:
		_shift_content(r, shift)
	_push(before)
	return ""

func _shift_content(r: RoomDef, d: Vector2) -> void:
	for i in r.solids.size():
		r.solids[i] = Rect2((r.solids[i] as Rect2).position + d, (r.solids[i] as Rect2).size)
	for i in r.hard_ledges.size():
		r.hard_ledges[i] = Rect2((r.hard_ledges[i] as Rect2).position + d, (r.hard_ledges[i] as Rect2).size)
	for list in [r.spawns, r.features, r.decor, r.dressing]:
		for e in list:
			e["pos"] = (e["pos"] as Vector2) + d
	if r.is_start():
		r.start += d
	for e in r.exits:
		var along_x: bool = e["edge"] == "top" or e["edge"] == "bottom"
		var amount := d.x if along_x else d.y
		e["from"] = float(e["from"]) + amount
		e["to"] = float(e["to"]) + amount
```

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_grow`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** shift `start` without `is_start()` (the non-start test fails); skip the exit shift (the perpendicular-exit test fails); allow `bottom` (that test fails); drop the overlap check (the C2 test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: a room can be grown left, right or top without moving anything in the world"`).

---

### Task 8: `problems()` and the reserved id

**Files:** Modify `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_problems.gd`.

**Interfaces:** `RoomEditModel.problems() -> Array` of `{room, text, pick}`; `id_error` refuses `world`; `validate()` unchanged.

- [ ] **Step 1: Write the failing tests** (`tests/test_room_edit_problems.gd`)

```gdscript
extends GutTest
## problems(): lint findings and validator strings as one list, routed to rooms.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

func test_the_shipped_world_has_no_problems() -> void:
	assert_eq(model.problems(), [])

func test_a_lint_finding_carries_its_room_and_pick() -> void:
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	model.serial += 1
	var p := model.problems()
	assert_eq(p.size(), 1)
	assert_eq(p[0]["room"], "C2")
	assert_eq(p[0]["pick"]["kind"], "spawn")

func test_a_validator_string_is_routed_by_its_head_and_has_no_pick() -> void:
	model.rooms["C1"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	model.serial += 1
	var routed := model.problems().filter(func(p): return p["text"].contains("unknown room 'Z'"))
	assert_eq(routed.size(), 1)
	assert_eq(routed[0]["room"], "C1")
	assert_eq(routed[0]["pick"], {})

func test_overlap_strings_route_to_the_first_room_and_world_strings_to_none() -> void:
	var a: RoomDef = model.rooms["C1"]
	var dup := RoomEditModel.copy_room(a)
	dup.id = "ZZ"
	dup.start = RoomDef.NO_START
	model.rooms["ZZ"] = dup
	model.serial += 1
	var texts := model.problems().filter(func(p): return p["text"].contains("overlaps"))
	assert_gt(texts.size(), 0)
	assert_true(model.rooms.has(texts[0]["room"]))
	a.start = RoomDef.NO_START
	model.serial += 1
	var world := model.problems().filter(func(p): return p["text"].begins_with("world:"))
	assert_eq(world[0]["room"], "", "a world-level string opens no room")

func test_problems_are_recomputed_only_when_serial_changes() -> void:
	var first := model.problems()
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})  # a change that does not touch serial
	assert_eq(model.problems().size(), first.size(), "cached until an edit, undo or redo bumps serial")
	model.add_solid("C1", Vector2(100, 100), Vector2(160, 116))
	assert_gt(model.problems().size(), first.size())

func test_validate_is_unchanged_and_validator_only() -> void:
	assert_eq("\n".join(model.validate()), "")
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	assert_eq("\n".join(model.validate()), "", "lint findings are not in validate()")

func test_the_id_world_is_reserved_case_insensitively_for_rooms_but_not_for_shortcuts() -> void:
	assert_ne(model.id_error("world"), "")
	assert_ne(model.id_error("World"), "")
	assert_true(RoomEditModel.valid_id("world"), "valid_id also gates shortcut ids, so it stays permissive")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`problems` missing).

- [ ] **Step 3: Implement:**

```gdscript
var _problems_serial := -1
var _problems_cache: Array = []

## Lint findings and validator strings as one list of {room, text, pick}. A validator string's room is the text before its first
## ": " or " overlaps ", kept only when that is a room id. Recomputed when `serial` changes, never per mouse motion.
func problems() -> Array:
	if _problems_serial == serial:
		return _problems_cache
	var out: Array = []
	for f in RoomLint.check(rooms):
		out.append({"room": f["room"], "text": f["text"], "pick": f["pick"]})
	for s in validate():
		out.append({"room": _room_of(s), "text": s, "pick": {}})
	_problems_cache = out
	_problems_serial = serial
	return out

func _room_of(text: String) -> String:
	var cut := text.length()
	for sep in [": ", " overlaps "]:
		var at := text.find(sep)
		if at >= 0:
			cut = mini(cut, at)
	var head := text.substr(0, cut)
	return head if rooms.has(head) else ""
```

and in `id_error` first line `if id.to_lower() == "world": return "'world' is reserved"`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_edit_problems`, `test_room_edit_new_room`. Expected: PASS.

- [ ] **Step 5: Full suite and commit (end of milestone B)**

```bash
tools/run_tests.sh   # Expected: PASS
git add scripts tests tools docs scenes data && git commit -m "feat: the model lists lint findings and validator errors as one routed problems list"
```

---

## Milestone C: the Game seam

### Task 9: `kit` and `open_shortcuts` in an editor Play

**Files:** Modify `scripts/game.gd`, `tests/test_editor_play.gd`.

**Interfaces:** `Game.play_request` accepts optional `kit` (Dictionary) and `open_shortcuts` (bool).

- [ ] **Step 1: Write the failing tests** (append to `tests/test_editor_play.gd`)

```gdscript
func _request(extra := {}) -> void:
	Game.play_request = {"rooms": model.rooms, "room": "C6", "pos": Vector2(120, 250)}
	for k in extra:
		Game.play_request[k] = extra[k]
	Game.editor_resume = {"model": model, "room": "C6", "view": {}}
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)

func test_a_request_without_kit_or_open_shortcuts_still_plays() -> void:
	_request()
	await wait_physics_frames(3)
	assert_eq(game.world.current_id, "C6")
	assert_false(SkillRules.owned().has("wall_cling"))

func test_a_kit_starts_the_player_with_the_skills_and_never_touches_the_compendium() -> void:
	var leap_before := Compendium.model.state("leap")
	var cling_before := Compendium.model.state("wall_cling")
	_request({"kit": {"skills": ["leap", "wall_cling"]}})
	await wait_physics_frames(3)
	assert_true(SkillRules.owned().has("wall_cling"))
	assert_true(SkillRules.owned().has("leap"))
	assert_eq(Compendium.model.state("leap"), leap_before, "the kit grant raises no Compendium slot")
	assert_eq(Compendium.model.state("wall_cling"), cling_before)

func test_without_open_shortcuts_the_entry_room_has_its_gate_and_its_switch() -> void:
	_request()
	await wait_physics_frames(3)
	assert_eq(get_tree().get_nodes_in_group("gate_c6_drop").size(), 1)
	assert_gt(get_tree().get_nodes_in_group("actors").filter(func(n): return n is ShortcutSwitch).size(), 0)

func test_open_shortcuts_leaves_the_entry_room_with_neither_gate_nor_switch() -> void:
	_request({"open_shortcuts": true})
	await wait_physics_frames(3)
	assert_eq(get_tree().get_nodes_in_group("gate_c6_drop").size(), 0)
	assert_eq(get_tree().get_nodes_in_group("actors").filter(func(n): return n is ShortcutSwitch).size(), 0)
	assert_true(game.world.ctx["progress"].is_open("c6_drop"))

func test_open_shortcuts_never_reaches_the_real_progress() -> void:
	var before: Array = Compendium.progress.shortcuts.duplicate()
	_request({"open_shortcuts": true})
	await wait_physics_frames(3)
	assert_eq(Compendium.progress.shortcuts, before)
```

(the C6 spot `(120, 250)` must be open floor in C6; adjust to a point the data supports.)

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (the gate test with `open_shortcuts` fails; the kit test fails because `kit` is dropped).

- [ ] **Step 3: Implement** in `scripts/game.gd`. In `_ready`, right after `var progress = WorldProgress.new() if _editor_play else Compendium.progress`:

```gdscript
	if _editor_play and bool(request.get("open_shortcuts", false)):
		# before the world builds its first room, so the entry room has neither the gate nor the switch
		for id in rooms:
			for e in (rooms[id] as RoomDef).exits:
				if e.has("shortcut"):
					progress.open_shortcut(str(e["shortcut"]))
```

and change the editor start dict to `"kit": request.get("kit", {})`. `begin_life` becomes:

```gdscript
func begin_life(start: Dictionary) -> void:
	SkillRules.start_run()
	if not start["kit"].is_empty():
		# an editor Play passes no compendium: the kit grant must not raise slots in the (persistent) profile
		RebirthKit.apply(player, SkillRules, null if _editor_play else Compendium.model, start["kit"])
```

Update the doc comment above `play_request` to list `kit` and `open_shortcuts`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_editor_play`, `test_game`, `test_rebirth_flow`, `test_run`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** pass `Compendium.model` in an editor Play (the compendium assertion fails when the profile's slot was UNKNOWN; if the sandbox profile already holds NAMED, clear it for the test with `Compendium.profile`'s section before the test); open shortcuts after `world.setup` is irrelevant, so open them after `enter_at` instead (the gate test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: an editor Play can grant Wall Cling and open every shortcut"`).

---

## Milestone D: the view, inspector and panels

### Task 10: the Feature tool in the view

**Files:** Modify `scripts/editor/room_view.gd`, `tests/test_room_editor_scene.gd`.

**Interfaces:** `RoomView.tool == "feature"`, `RoomView.feature_kind: String`, feature markers in group `editor_marker` with meta `feature`, selection outline from `FEATURE_BOX`, `RoomView._commit_pending()` (a call to `get_viewport().gui_release_focus()`) at the top of `_press`.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd`, using its `_press`/`_release`/`_motion` helpers)

```gdscript
func test_the_feature_tool_places_a_feature_on_the_surface_and_refuses_with_a_message() -> void:
	view.tool = "feature"
	view.feature_kind = "tablet"
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	var t: Dictionary = model.rooms["C1"].features.back()
	assert_eq(t["kind"], "tablet")
	assert_eq(model.undo_depth(), 1)
	var solid: Rect2 = model.rooms["C1"].solids[0]
	view.handle_event(_press(solid.get_center()))
	view.handle_event(_release(solid.get_center()))
	assert_eq(messages.size(), 1)
	assert_eq(model.undo_depth(), 1)

func test_a_placed_feature_has_a_marker_and_an_outline_when_selected() -> void:
	view.tool = "feature"
	view.feature_kind = "glow_pool"
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	await wait_process_frames(1)
	assert_gt(view.markers().filter(func(m): return m.has_meta("feature")).size(), 0)
	assert_gt(view.overlay.get_children().filter(func(n): return n is Line2D).size(), 0, "the selection outline is drawn")

func test_select_picks_a_feature_by_clicking_its_body_and_drags_it() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	view.show_room(model, "C1")
	view.tool = "select"
	var base: Vector2 = model.rooms["C1"].features.back()["pos"]
	view.handle_event(_press(base + Vector2(0, -10)))
	view.handle_event(_motion(base + Vector2(60, -10)))
	view.handle_event(_release(base + Vector2(60, -10)))
	assert_eq(model.rooms["C1"].features.back()["pos"].x, base.x + 60.0)

func test_a_press_releases_gui_focus_first() -> void:
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	assert_true(edit.has_focus())
	view.tool = "select"
	view.handle_event(_press(Vector2(5, 5)))
	assert_false(edit.has_focus(), "a click in the room commits and releases a pending field")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`feature_kind`, feature tool missing).

- [ ] **Step 3: Implement** in `room_view.gd`: `var feature_kind := "tablet"`; in `_press` first line `_commit_pending()`, with `func _commit_pending() -> void: get_viewport().gui_release_focus()`; a `"feature"` arm in `_press` (`_pressed = true; _press_room = p`) and in `_release` (`_report(_model.add_feature(_room_id, feature_kind, p))`); `_marker` gains features: for each feature draw a sprite or box from `RoomEditModel.FEATURE_BOX` (the tablet a grey 12x18 `ColorRect`, the switch a brown 18x22, the pools the `water_pool` sprite tinted like the real pool or a teal 38x24 box; `holder.set_meta("feature", i)` and `add_to_group("editor_marker")`); `_selection_rect` gets `"feature"`: `Rect2(box.position + pos, box.size)`. Every `match` over a selection kind in the view gets an explicit `_` arm.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Commit** (`git commit -m "feat: the Feature tool places, selects and drags features in the view"`).

---

### Task 11: the inspector, the right-hand slot and click-to-land

**Files:** Create `scripts/editor/inspector_panel.gd`, `scripts/editor/editor_slot.gd`; Modify `scripts/editor/editor_panels.gd` (`typing()`), `tests/test_room_editor_scene.gd`.

**Interfaces:**
- `InspectorPanel` (a `VBoxContainer`): `build(model: RoomEditModel, sel: Dictionary)` builds the controls for the selection from a const per-kind field list; `signal field_error(text: String)`; each control is bound to the `sel` captured at build; `commit_pending()` is not needed (the `LineEdit` commits on `text_submitted` and `focus_exited`; `OptionButton` and `CheckBox` use `FOCUS_NONE`).
- `EditorSlot` (a `Control`, 168 px wide, scrolling): `show_inspector(model, sel)`, `show_problems(problems: Array)`, `hide_slot()`, `signal problem_clicked(problem: Dictionary)`, `is_showing() -> String` (`"inspector"`, `"problems"` or `""`).
- `EditorPanels.typing()` is "a `LineEdit` has focus".

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd`)

```gdscript
func _slot() -> EditorSlot:
	var s := EditorSlot.new()
	add_child_autofree(s)
	await wait_process_frames(1)
	return s

func test_the_inspector_edits_a_tablet_through_the_model() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	var slot := await _slot()
	slot.show_inspector(model, model.selection)
	assert_eq(slot.is_showing(), "inspector")
	var title: LineEdit = slot.find_field("title")
	title.text = "Moss"
	title.text_submitted.emit("Moss")
	assert_eq(model.rooms["C1"].features.back()["title"], "Moss")
	assert_eq(model.undo_depth(), 2, "placement then the edit")
	title.text_submitted.emit("Moss")
	title.focus_exited.emit()
	assert_eq(model.undo_depth(), 2, "Enter then focus loss is one step")

func test_a_pending_edit_goes_to_the_element_it_was_typed_for() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	model.add_feature("C1", "tablet", Vector2(400, 100))
	var first := {"room": "C1", "kind": "feature", "index": model.rooms["C1"].features.size() - 2}
	var slot := await _slot()
	slot.show_inspector(model, first)
	var title: LineEdit = slot.find_field("title")
	title.text = "First one"
	model.select({"room": "C1", "kind": "feature", "index": model.rooms["C1"].features.size() - 1})
	title.focus_exited.emit()
	assert_eq(model.rooms["C1"].features[first["index"]]["title"], "First one")

func test_a_refused_edit_shows_the_stored_value_and_reports_the_reason() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	var slot := await _slot()
	var errors := []
	slot.field_error.connect(func(t: String) -> void: errors.append(t))
	slot.show_inspector(model, model.selection)
	var title: LineEdit = slot.find_field("title")
	title.text = ""
	title.text_submitted.emit("")
	assert_eq(errors.size(), 1)
	assert_eq(title.text, "Tablet")

func test_the_pool_inspector_offers_level_and_the_kit_legal_skills() -> void:
	var sel := {"room": "G1", "kind": "feature", "index": model.rooms["G1"].features.find_custom(func(f): return f["kind"] == "rebirth_pool")}
	var slot := await _slot()
	slot.show_inspector(model, sel)
	var checks := slot.skill_checkboxes()
	assert_eq(checks.size(), 16, "29 skills less 5 enemy-only and 8 evolution")
	var ids := checks.map(func(c): return c.get_meta("skill"))
	assert_false(ids.has("flight"))
	assert_true(slot.find_field("kit_level") is OptionButton)
	for c in checks:
		assert_eq(c.focus_mode, Control.FOCUS_NONE)

func test_the_problems_list_lands_on_the_problem() -> void:
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	model.serial += 1
	var slot := await _slot()
	var clicked := []
	slot.problem_clicked.connect(func(p: Dictionary) -> void: clicked.append(p))
	slot.show_problems(model.problems())
	assert_eq(slot.is_showing(), "problems")
	slot.click_problem(0)
	assert_eq(clicked[0]["room"], "C2")
	assert_eq(clicked[0]["pick"]["kind"], "spawn")

func test_typing_means_a_line_edit_has_focus() -> void:
	var p := await _panels()
	assert_false(p.typing())
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	assert_true(p.typing())
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	add_child_autofree(box)
	edit.release_focus()
	assert_false(p.typing(), "a checkbox never counts")
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`EditorSlot` not found).

- [ ] **Step 3: Implement.**
  - `inspector_panel.gd`: `const FIELDS := {"exit": [["shortcut", "Shortcut", "line"]], "tablet": [["title", "Title", "line"], ["text", "Text", "line"]], "switch": [["shortcut", "Shortcut", "line"]], "rebirth_pool": [["kit_level", "Level", "level"], ["kit_skills", "Skills", "skills"]], "glow_pool": []}`. `build()` clears children, resolves the kind (`exit`, or the feature's `kind`), adds a title `Label`, then per field: `"line"` a `LineEdit` (named `field_<key>`, text from `model.get_field`, `text_submitted` and `focus_exited` call `_commit(key, line.text)`), `"level"` an `OptionButton` (`FOCUS_NONE`; items "none", 1..`Progression.LEVEL_CAP`; `item_selected` calls `_commit("kit_level", index)`), `"skills"` a `VBoxContainer` of `CheckBox`es (`FOCUS_NONE`, `set_meta("skill", id)`, one per kit-legal skill id from `RebirthKit.skill_defs()` filtered by `source != "enemy_only" and source != "evolution"`; `toggled` rebuilds the list from the ticked boxes and calls `_commit("kit_skills", ids)`). `_commit` calls `model.set_field(captured_sel, key, value)`; a non-empty result emits `field_error` and resets the control to `model.get_field(...)`. `find_field(key) -> Control` and `skill_checkboxes() -> Array`.
  - `editor_slot.gd`: a `ScrollContainer` (position (472, 50), size (168, 290)) holding either an `InspectorPanel` or an `ItemList` for problems (`show_problems` lists `"%s: %s" % [room, text]`, `click_problem(i)` and `item_selected` emit `problem_clicked(problems[i])`); forwards `InspectorPanel.field_error`; `find_field` and `skill_checkboxes` delegate to the inspector. The inspector is rebuilt with `queue_free` (remove the old child, then `queue_free`).
  - `editor_panels.gd::typing()` becomes `var f := ...gui_get_focus_owner(); return f is LineEdit`.
  - Land-on-problem lives in `RoomEditor` (Task 12).

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Commit** (`git commit -m "feat: an inspector for exit shortcuts, tablets, switches and pool kits, in a right-hand slot with a problems list"`).

---

### Task 12: the panels, the toggles, Grow, and the editor wiring

**Files:** Modify `scripts/editor/editor_panels.gd`, `scripts/editor/room_editor.gd`, `scripts/editor/room_view.gd` (`fit` free rect), `tests/test_room_editor_scene.gd`, `tests/test_room_edit_new_room.gd`, `tests/test_room_edit_exits.gd`.

**Interfaces:**
- `EditorPanels`: two rows (row one: room selector, Select, Solid, Creature, Feature, Exit; row two: Undo, Redo, Fit room, 1:1, Grow (`MenuButton`: Left, Right, Top), Validate (N), World, Wall Cling, Open shortcuts, Save, Play, New room); the Feature palette (`glow_pool`, `tablet`, `switch`, `rebirth_pool`) shows for the Feature tool; signals `grow_requested(side)`, `world_pressed`, `movement_toggled(on)`, `shortcuts_toggled(on)`, `feature_chosen(kind)`; `set_problem_count(n)` sets the Validate label; `toggle_panels()`.
- `RoomEditor`: `play_options := {"movement": false, "shortcuts": false}` (carried in `Game.editor_resume["play_options"]`), `_commit_pending()`, `_spot(pos) -> Variant`, `play_error`/`play` using `_spot`, `land_on(problem)`, `grow(side)`, a `Validate (N)` count updated on `serial`, `slot` handling.

- [ ] **Step 1: Write the failing tests** (append to `tests/test_room_editor_scene.gd` and `tests/test_editor_play.gd`; move P1's `validate()` uses in the scene tests to `problems()`)

```gdscript
func test_the_validate_button_carries_the_count_and_the_open_list_refreshes() -> void:
	var ed := await _editor()
	assert_eq(ed.panels.validate_label(), "Validate (0)")
	ed.model.rooms["C1"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(160, 116))
	ed.view.refresh()
	assert_eq(ed.panels.validate_label(), "Validate (1)")
	ed.panels.press("Validate (1)")
	assert_eq(ed.slot.is_showing(), "problems")
	ed.model.add_solid("C1", Vector2(300, 100), Vector2(360, 116))
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "problems", "an open list refreshes instead of closing")

func test_clicking_a_problem_opens_its_room_selects_it_and_centres_it() -> void:
	var ed := await _editor()
	ed.model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	ed.model.add_solid("C2", Vector2(100, 100), Vector2(160, 116))
	ed.panels.press("Validate (1)")
	ed.slot.click_problem(0)
	assert_eq(ed.room_id, "C2")
	assert_eq(ed.model.selection["kind"], "spawn")

func test_the_toggles_reach_the_play_request() -> void:
	var ed := await _editor()
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	ed.panels.press("Wall Cling")
	ed.panels.press("Open shortcuts")
	assert_true(ed.play_options["movement"])
	assert_true(ed.play_options["shortcuts"])
	ed.play(Vector2(300, 100))
	assert_eq(Game.play_request["kit"], {"skills": ["leap", "wall_cling"]})
	assert_true(Game.play_request["open_shortcuts"])
	Game.play_request = {}
	Game.editor_resume = null

func test_play_error_and_play_agree_on_the_spot_with_the_toggle_on_and_off() -> void:
	var ed := await _editor()
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	ed.open_room("C6")
	var gate: Rect2 = RoomBuilder.gate_rect(ed.model.rooms["C6"].pixel_size(), ed.model.rooms["C6"].exits.filter(func(e): return e.has("shortcut"))[0])
	var over := Vector2(gate.get_center().x, 100)
	assert_eq(ed.play_error(over), "", "a closed gate is a surface")
	ed.panels.press("Open shortcuts")
	assert_ne(ed.play_error(over), "", "with shortcuts open it is a hole")
	assert_null(ed._spot(over))

func test_grow_from_the_menu_changes_the_room_and_refuses_an_overlap() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	ed.grow("left")
	assert_eq(ed.model.rooms["C6"].size.x, 2) if false else null
	ed.open_room("C1")
	ed.grow("right")
	assert_string_contains(ed.panels.status_text(), "overlap")

func test_pending_text_is_committed_before_save_undo_and_play() -> void:
	var ed := await _editor()
	ed.save_dir = "res://.tmp/editor_scene_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ed.save_dir))
	ed.model.add_feature("C1", "tablet", Vector2(300, 100))
	ed.view.refresh()
	ed.slot.show_inspector(ed.model, ed.model.selection)
	var title: LineEdit = ed.slot.find_field("title")
	title.grab_focus()
	title.text = "Typed"
	ed.panels.press("Save")
	assert_eq(ed.model.rooms["C1"].features.back()["title"], "Typed", "Save committed the pending text first")
	var saved := ResourceLoader.load("%s/C1.tres" % ed.save_dir, "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_eq(saved.features.back()["title"], "Typed")
	title.grab_focus()
	title.text = "Typed again"
	ed.panels.press("Undo")
	assert_eq(ed.model.rooms["C1"].features.back()["title"], "Typed", "the text committed as an edit and Undo undid it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/C1.tres" % ed.save_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ed.save_dir))

func test_delete_and_undo_still_work_after_ticking_a_kit_skill() -> void:
	var ed := await _editor()
	ed.open_room("G1")
	var idx: int = ed.model.rooms["G1"].features.find_custom(func(f): return f["kind"] == "rebirth_pool")
	ed.model.select({"room": "G1", "kind": "feature", "index": idx})
	ed.slot.show_inspector(ed.model, ed.model.selection)
	ed.slot.skill_checkboxes()[0].button_pressed = true
	assert_false(ed.panels.typing(), "a checkbox never holds focus")
	var z := InputEventKey.new()
	z.keycode = KEY_Z
	z.pressed = true
	z.ctrl_pressed = true
	get_viewport().push_input(z)
	await wait_process_frames(1)
	assert_eq(ed.model.undo_depth(), 0)

func test_tab_hides_and_shows_every_panel() -> void:
	var ed := await _editor()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	await wait_process_frames(1)
	assert_false(ed.panels.panels_visible())
	get_viewport().push_input(tab)
	await wait_process_frames(1)
	assert_true(ed.panels.panels_visible())
```

Delete the line `assert_eq(ed.model.rooms["C6"].size.x, 2) if false else null` in `test_grow_from_the_menu_...` when writing it: C6's left neighbour space is free, so assert `ed.model.rooms["C6"].size.x == 2` after `ed.grow("left")`, then the C1-right overlap refusal.

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL.

- [ ] **Step 3: Implement.**
  - `EditorPanels`: rebuild `_build_bar` as two `HBoxContainer` rows at y 2 and y 26 (background `ColorRect` 48 px tall); `Grow` as a `MenuButton` (popup items Left, Right, Top; `get_popup().id_pressed` emits `grow_requested`); `Wall Cling` and `Open shortcuts` toggle buttons (`toggle_mode`, `FOCUS_NONE`); `Validate (N)` button text via `set_problem_count`; the Feature palette `ItemList` shown for the Feature tool; a `TOOLS` list with `Feature`; `toggle_panels()` hides or shows the palettes and the slot (`panels_visible()`); the old validation `ItemList` and `show_validation` go (the slot owns the list); `press(label)` keeps working (`Validate` matches by prefix).
  - `RoomEditor`: add `slot: EditorSlot` (child after the panels); `_commit_pending()` (`get_viewport().gui_release_focus()`) is the first line of `undo`, `redo`, `save`, `play`, `_ask_for_spot`, `open_room`, `_toggle_validation`, `grow`, `new_room`, the toggle handlers and the `_choosing_spot` branch of `_unhandled_input`; `_spot(pos)` returns `model.floor_spot(room_id, pos, not bool(play_options["shortcuts"]))` and both `play_error` and `play` use it; `play()` adds `"kit": CAVE_MOVEMENT_KIT if play_options["movement"] else {}` and `"open_shortcuts": play_options["shortcuts"]` and puts `play_options` in `editor_resume`; `const CAVE_MOVEMENT_KIT := {"skills": ["leap", "wall_cling"]}` (a test asserts `RebirthKit.validate(CAVE_MOVEMENT_KIT)` is empty); `_sync()` calls `panels.set_problem_count(model.problems().size())` (cached by `serial`), refreshes an open problems list in the slot, and shows the inspector for a non-empty selection when no list is open (hides the slot otherwise); `land_on(problem)` opens the room, selects `pick`, and centres the view on the selection's `FEATURE_BOX`/rect bounds (`view.center_on(rect)`); `grow(side)` calls `model.grow_room`, reports a refusal in the status bar, else `view.refresh()` and `_sync()`; Tab in `_unhandled_key_input` calls `panels.toggle_panels()` when `not panels.typing()`.
  - `RoomView.fit()` takes the free rectangle (toolbar 48 px, status 16 px, left strip 92 px when a palette shows, right slot 168 px when shown): `fit_in(free: Rect2)`; `RoomEditor` passes it.
  - Update the P1 tests that call `validate()` on the model for the Validate list (`test_room_editor_scene.gd` Validate tests) to the new `problems()`/slot behaviour; keep `model.validate()` calls that only need the validator.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_room_editor_scene`, `test_editor_play`, `test_room_edit`. Expected: PASS.

- [ ] **Step 5: Mutation checks:** drop `_commit_pending` from `save` (the Save test fails); make `typing()` count an `OptionButton` (the kit-skill test fails after ticking a box if focus stuck, so also set a checkbox to default focus and see it); use `floor_spot(room, pos)` without the toggle in `play` (the agree test fails).

- [ ] **Step 6: Commit** (`git commit -m "feat: two-row toolbar, the Validate count, Grow, the two play toggles and pending-text commits in the editor"`).

---

### Task 13: look at it

**Files:** Modify `tools/editor_shots.gd`.

- [ ] **Step 1:** Extend `tools/editor_shots.gd` to shoot: C2 with a tablet placed and its inspector open (`ed.slot.show_inspector(...)`), the problems list with one finding, G1's pool with the kit checklist, and a played room with Wall Cling granted and shortcuts open (build the request through `ed.panels.press("Wall Cling")` and `play`; the shot after 90 frames). Use `root.get_node(...)` for anything autoload.
- [ ] **Step 2:** Run it unsandboxed (`env HOME="$PWD/.tmp/editor-home" godot --path . -s res://tools/editor_shots.gd`), read every PNG, and fix what looks wrong (overlap of the right slot with the room, clipped labels, unreadable toolbar at 640 px, markers hidden under panels). Re-shoot until the toolbar rows, the inspector, the list and the checklist are legible. Record the final look in the ledger.
- [ ] **Step 3:** Commit (`git commit -m "tools: screenshots of the P2 editor"`).

---

## Milestone E: the World view

### Task 14: the read-only overview

**Files:** Create `scripts/editor/world_view.gd`, `tests/test_world_view.gd`; Modify `scripts/editor/room_editor.gd`, `scripts/editor/editor_panels.gd`.

**Interfaces:** `WorldView.layout(rooms: Dictionary, rect: Rect2) -> Array` of `{id, rect}`, `WorldView.room_at(layout: Array, point: Vector2) -> String`; `WorldView` (a `Control`) draws the layout and emits `room_chosen(id)`.

- [ ] **Step 1: Write the failing tests** (`tests/test_world_view.gd`)

```gdscript
extends GutTest
## The World view: a pure layout of every room at its world position, scaled to fit, and a click mapped back to a room.

func _rooms() -> Dictionary:
	return ShippedRooms.load_all()

func test_the_layout_has_one_rect_per_room_inside_the_panel() -> void:
	var panel := Rect2(20, 40, 600, 280)
	var layout := WorldView.layout(_rooms(), panel)
	assert_eq(layout.size(), 11)
	for item in layout:
		assert_true(panel.encloses(item["rect"]), item["id"])

func test_the_layout_keeps_relative_positions_and_one_scale() -> void:
	var rooms := _rooms()
	var layout := WorldView.layout(rooms, Rect2(0, 0, 600, 300))
	var by_id := {}
	for item in layout:
		by_id[item["id"]] = item["rect"]
	var scale: float = (by_id["C1"] as Rect2).size.x / rooms["C1"].world_rect().size.x
	for id in rooms:
		assert_almost_eq((by_id[id] as Rect2).size.x, rooms[id].world_rect().size.x * scale, 0.01, id)
	assert_lt((by_id["C1"] as Rect2).position.x, (by_id["C2"] as Rect2).position.x, "C2 is east of C1")

func test_one_room_fills_the_panel() -> void:
	var r := RoomDef.new()
	r.id = "A"
	var layout := WorldView.layout({"A": r}, Rect2(0, 0, 600, 300))
	assert_eq(layout.size(), 1)
	assert_gt((layout[0]["rect"] as Rect2).size.x, 300.0)

func test_room_at_maps_a_point_to_a_room_or_nothing() -> void:
	var layout := WorldView.layout(_rooms(), Rect2(0, 0, 600, 300))
	var c1: Rect2 = layout.filter(func(i): return i["id"] == "C1")[0]["rect"]
	assert_eq(WorldView.room_at(layout, c1.get_center()), "C1")
	assert_eq(WorldView.room_at(layout, Vector2(-50, -50)), "")

func test_clicking_the_view_chooses_a_room() -> void:
	var v := WorldView.new()
	add_child_autofree(v)
	v.setup(_rooms(), "C1")
	var chosen := []
	v.room_chosen.connect(func(id: String) -> void: chosen.append(id))
	var c4: Rect2 = v.layout().filter(func(i): return i["id"] == "C4")[0]["rect"]
	v.click(c4.get_center())
	assert_eq(chosen, ["C4"])
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`WorldView` missing).

- [ ] **Step 3: Implement** `world_view.gd`: `layout` computes the bounding `Rect2` of every `world_rect()`, `scale = min(rect.size.x / bounds.size.x, rect.size.y / bounds.size.y)`, centres the result in `rect` (a lone room fills as far as the aspect allows) and returns `{id, rect}`; `room_at` returns the id of the first rect that `has_point`; the `Control` draws each rect (area tint via `TerrainArt.ambient` or two fixed colours, id label, the current room outlined white), handles `gui_input` left click through `click(point)`, and `setup(rooms, current_id)`. `RoomEditor`: a `World` button toggles the view (hide the slot and palettes while it shows), `room_chosen` opens the room and hides the view. `EditorPanels` emits `world_pressed`.

- [ ] **Step 4: Run to verify it passes:** `tools/run_tests.sh test_world_view`, `test_room_editor_scene`. Expected: PASS.

- [ ] **Step 5: Screenshot the World view** (extend `tools/editor_shots.gd`), look at it, fix what looks wrong, commit (`git commit -m "feat: a read-only World view to jump between rooms"`).

---

### Task 15: docs, doc comments, playtest checklist, and the final suite

**Files:** Modify `scripts/world/room_def.gd`, `scripts/world/room_features.gd`, `scripts/editor/room_edit_model.gd` (selection comment), `scripts/editor/editor_panels.gd` (tools comment), `scripts/game.gd` (request docs), `scripts/editor/room_editor.gd` (status hint), `tests/support/shipped_rooms.gd`, `docs/superpowers/specs/2026-09-29-room-editor-design.md`, `docs/playtest-checklist.md`.

- [ ] **Step 1:** Sweep the doc comments listed in the spec's Architecture section: add `rebirth_pool` to the feature kinds in `room_def.gd` and `room_features.gd`; `selection` kinds list `solid`, `spawn`, `exit`, `feature`; the `TOOLS` comment; `game.gd`'s `play_request`/`editor_resume` docs (`kit`, `open_shortcuts`, `play_options`); the editor's status hint (add Tab and the Validate count); `shipped_rooms.gd` header (rule tests run on every room via `RoomLint`); a short note in the P1 spec's phase table that the decor palette, Start tool, hard-ledge toggle, dressing, prefab stamps, jump ruler and resize handles moved to P3 (see the P2 spec).
- [ ] **Step 2:** Add playtest lines to `docs/playtest-checklist.md` under the Room editor section: place a tablet and type its text (Save keeps it), add a switch and give a shortcut to an exit (Validate (N) shows the pair problems until both exist), place a rebirth pool and tick its skills (G1's affinity is untouched), grow a room left and top and see the world positions hold, click a problem to land on it, Tab hides the panels, Play with Wall Cling and Open shortcuts on a gated room, the World view jumps rooms.
- [ ] **Step 3:** Run the full suite. Expected: PASS.
- [ ] **Step 4:** Commit (`git commit -m "docs: sweep the editor's doc comments and add the P2 playtest lines"`).

---

## Final steps

Whole-branch review with an opus reviewer (`review-package` per the executing-plans skill; give it the Review Focus above verbatim and the spec), one fix pass (each fix RED to GREEN, suite green), a real windowed look at the editor and a played room on the merged tree, then `finishing-a-development-branch`: merge to `main`, run the full suite on the merged tree, push, relaunch the game.
