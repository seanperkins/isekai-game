# Species Movesets, Part 3a: Slime Tackle and Ooze Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first playable verbs, for the slime, in the sandbox: spread flat (Ooze), the puddle slide, and Tackle, with a collision box that follows, a low tunnel only a flat slime fits, the verb name on the HUD and a tint while a verb runs. None of them adds jump reach; wall stick and wall jump wait for the reach model (plan 3b).

**Architecture:** `VerbRunner` (pure statics) wraps `GroundAirStep`: it tracks facing, spread and the active burst, and lets the step run underneath so gravity, jump, coyote and the jump buffer never stop (a burst only owns horizontal velocity, as `Player._dash` does today). A burst is a data row (`BurstDef`) in the profile: Tackle and the puddle slide are the slime's two rows, and later roll and pounce are more rows. The caller (the sandbox now, `player.gd` later) fills the new `MoveInput` probes and applies the flat collision box.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`).

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` ("The movesets" slime bullets, "Structure", "Rules across all four"). Read it with this plan.

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. Every new `class_name` script needs `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and its `.uid` file committed. A SCRIPT ERROR, Parse Error or warning-as-error fails the whole run (type every `var`). Success prints `PASS: N tests`. Every test file starts with `extends GutTest`.
- Edits are limited to `scripts/movement/*`, `data/movement/*`, `scenes/movement_sandbox.tscn` (only if needed), `tests/test_movement_*.gd`, `tests/test_species_look.gd`, `tests/test_verb_runner.gd`, `tests/support/movement_sim.gd`. Do not edit `scripts/player/`, `scripts/enemies/`, `scripts/world/` or any art.
- Work in `.worktrees/slime-verbs` on `feat/slime-verbs`.
- Numbers (the player's today, ported): flat walk speed 0.5 times; flat box `BodyConfig.spread_size()` (28x10), standing box `BodyConfig.size()` (28x24), standing up needs 14 px (`STAND_RISE`) free above; spread starts and holds while the raw down input is at least 0.6 (it no longer needs the aim to snap to exactly down); Tackle 260 px/s along the facing for 0.15 s (nine ticks), no cooldown, no gravity change; puddle slide: starts on the floor with down held at 0.6 or more and `|vx|` of 100 or more, keeps the speed (`speed 0`), bleeds at 300 px/s^2, ends below 40 px/s, when down is released, on leaving the floor, or after 0.5 s, flat box; Tackle wins if both would start.
- Burst clock: a burst's remaining time is set at begin, and each tick it is checked first (ended when `<= 1e-6`) and decremented after, so a 0.15 s burst holds its velocity for exactly nine ticks.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`.

## Review Focus

1. **A jump while flat under a low ceiling.** Expect: refused, still flat, no buffered press (Task 1).
2. **Down plus a direction.** Expect: at 100 px/s or more a puddle slide, below that an ordinary flat walk at half speed (Tasks 1 and 3).
3. **Leaving the floor or releasing down mid-slide, and a slide after a Tackle.** Expect: it ends at once; from 260 px/s it stops at the 0.5 s cap (Task 3).
4. **A second Tackle press mid-tackle, and a tackle in the air.** Expect: no restart; gravity still pulls, and a jump still fires with the tackle speed kept (Task 2).
5. **Species without the rows.** Expect: the biped, spider and wolf ignore down and the Tackle button (Tasks 1 and 2); every Part 1 and 2 test, run through the runner, still passes.

---

## File map

- `scripts/movement/burst_def.gd` the data row; `movement_profile.gd` gains `verbs` and `bursts`; `data/movement/slime.tres` gets `ooze` and the two rows.
- `scripts/movement/move_input.gd`, `move_state.gd` gain the probes and verb state; `ground_air_step.gd` skips horizontal control while a burst runs.
- `scripts/movement/verb_runner.gd` the runner; `species_look.gd` and `movement_sandbox.gd` show it.
- `tests/test_verb_runner.gd`, `tests/support/movement_sim.gd` (drives the runner), the sandbox and look tests grow.

### Task 1: Ooze, the flat slime

**Files:**
- Create: `scripts/movement/verb_runner.gd`, `tests/test_verb_runner.gd`
- Modify: `scripts/movement/move_input.gd`, `scripts/movement/move_state.gd`, `scripts/movement/movement_profile.gd`, `data/movement/slime.tres`, `tests/support/movement_sim.gd`

**Interfaces:**
- Produces: `MoveInput.down := 0.0` (raw 0 to 1), `MoveInput.signature_pressed := false`, `MoveInput.clearance_above := 1000.0` (free px above the flat body; the caller probes it). `MoveState.facing := 1`, `MoveState.spread := false`, `MoveState.verb := ""`, `MoveState.verb_left := 0.0`, `MoveState.verb_dir := 1.0`, `MoveState.cooldowns := {}`. `MovementProfile.verbs: PackedStringArray := []` (slime: `["ooze"]`) and `MovementProfile.bursts: Array := []` (filled in Task 2).
- Produces: `class_name VerbRunner extends RefCounted` with `const SPREAD_DOWN := 0.6`, `const SPREAD_SPEED := 0.5`, `const STAND_RISE := 14.0`, `static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale := 1.0, jump_boost := 1.0) -> void`, `static func is_flat(s: MoveState, p: MovementProfile) -> bool` (spread, or a running burst whose row is `flat`). `MovementSim.tick` becomes `tick(dir := 0.0, pressed := false, held := false, boost := 1.0, down := 0.0, signature := false)` and calls `VerbRunner.step`, so every earlier envelope test now runs through the runner.

- [ ] **Step 1: Write the failing tests** in `tests/test_verb_runner.gd` (helpers `_in(dir := 0.0, on_floor := true, down := 0.0) -> MoveInput` and `_run(p, s, i, ticks)` calling `VerbRunner.step` at `1.0 / 60.0`; `slime` and `biped` loaded in `before_each` with `MovementProfile.of`):

```gdscript
func test_facing_follows_the_last_direction_pressed() -> void:
	var s := MoveState.new()
	assert_eq(s.facing, 1)
	_run(slime, s, _in(-1.0), 1)
	assert_eq(s.facing, -1)
	_run(slime, s, _in(0.0), 1)
	assert_eq(s.facing, -1, "letting go keeps it")

func test_down_on_the_floor_spreads_and_halves_the_walk() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(1.0, true, 1.0), 10)
	assert_true(s.spread)
	assert_eq(s.velocity.x, 70.0)
	assert_true(VerbRunner.is_flat(s, slime))

func test_it_stands_up_only_with_room_above() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(0.0, true, 1.0), 2)
	var low := _in()
	low.clearance_above = 0.0
	_run(slime, s, low, 5)
	assert_true(s.spread, "a low ceiling keeps it flat")
	_run(slime, s, _in(), 1)
	assert_false(s.spread)

func test_down_in_the_air_does_not_spread_and_only_the_slime_has_ooze() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(0.0, false, 1.0), 3)
	assert_false(s.spread)
	s = MoveState.new()
	_run(biped, s, _in(0.0, true, 1.0), 3)
	assert_false(s.spread)

func test_a_jump_stands_the_slime_up_with_room_and_is_refused_without() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(0.0, true, 1.0), 2)
	var jump := _in(0.0, true, 1.0)
	jump.jump_pressed = true
	jump.jump_held = true
	VerbRunner.step(s, jump, slime, 1.0 / 60.0)
	assert_eq(s.launched, "ground")
	assert_false(s.spread)
	s = MoveState.new()
	_run(slime, s, _in(0.0, true, 1.0), 2)
	var blocked := _in(0.0, true, 1.0)
	blocked.jump_pressed = true
	blocked.clearance_above = 0.0
	VerbRunner.step(s, blocked, slime, 1.0 / 60.0)
	assert_eq(s.launched, "")
	assert_true(s.spread)
	assert_eq(s.buffer, 0.0, "a refused press is not buffered")
```

- [ ] **Step 2: Run** `tools/run_tests.sh verb_runner`. Expected: FAIL (classes and fields missing).
- [ ] **Step 3: Implement.** Add the probe and state fields and `verbs`/`bursts` to the profile (`slime.tres` gets `verbs = PackedStringArray("ooze")`; others keep the empty default). `VerbRunner.step`: set `s.facing` from the sign of `i.dir` when it is not 0; tick the `cooldowns` (decrement, clamp, erase at 0); `_ooze`: when the profile has `"ooze"`, `want = i.on_floor and i.down >= SPREAD_DOWN and not i.jump_pressed`; `want` sets `spread`, otherwise `spread` clears only when `i.clearance_above >= STAND_RISE`; if `s.spread` and `i.jump_pressed` and `clearance_above < STAND_RISE`, pass the step a copy of the input with `jump_pressed = false` (add `MoveInput.copy()`); then call `GroundAirStep.step` with `speed_scale * SPREAD_SPEED` while spread. `is_flat` is `s.spread` for now. Update `MovementSim.tick` as specified (builds `down` and `signature_pressed` into the input). Run `godot --headless --import`.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_` and `tools/run_tests.sh verb_runner`. Expected: `PASS` (the envelope and release tests now run through the runner).
- [ ] **Step 5: Commit**: `git add scripts/movement data/movement tests` (with `.uid` files), `git commit -m "feat: VerbRunner and the slime's Ooze (spread flat)"`.

### Task 2: BurstDef and Tackle

**Files:**
- Create: `scripts/movement/burst_def.gd`
- Modify: `scripts/movement/verb_runner.gd`, `scripts/movement/ground_air_step.gd`, `data/movement/slime.tres`, `tests/test_verb_runner.gd`, `tests/support/movement_sim.gd` (only if a helper is needed)

**Interfaces:**
- Produces: `class_name BurstDef extends Resource` with `@export` fields `id := ""`, `trigger := "signature"` (`"signature"` or `"down_run"`), `speed := 0.0` (0 keeps the current speed), `min_start_speed := 0.0`, `duration := 0.15`, `decel := 0.0`, `min_speed := 0.0`, `needs_down := false`, `needs_floor := false`, `flat := false`, `cooldown := 0.0`. The slime's `bursts` first row is `tackle` (trigger `signature`, speed 260, duration 0.15, all else default).
- `GroundAirStep.step` skips `_horizontal` while `s.verb != ""`.

- [ ] **Step 1: Write the failing tests** (add to `tests/test_verb_runner.gd`):

```gdscript
func _signature() -> MoveInput:
	var i := _in()
	i.signature_pressed = true
	return i

func test_tackle_holds_260_for_nine_ticks_then_returns_control() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")
	assert_eq(s.velocity.x, 260.0)
	for k in 8:
		VerbRunner.step(s, _in(), slime, 1.0 / 60.0)
		assert_eq(s.velocity.x, 260.0, "tick %d" % (k + 2))
	assert_eq(s.verb, "tackle")
	VerbRunner.step(s, _in(), slime, 1.0 / 60.0)
	assert_eq(s.verb, "")
	assert_lt(s.velocity.x, 260.0)

func test_tackle_goes_the_way_the_slime_faces_and_a_second_press_does_not_restart_it() -> void:
	var s := MoveState.new()
	_run(slime, s, _in(-1.0), 1)
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_eq(s.velocity.x, -260.0)
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	assert_lt(s.verb_left, 0.12)

func test_a_jump_during_a_tackle_fires_and_keeps_the_tackle_speed() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), slime, 1.0 / 60.0)
	var j := _in()
	j.jump_pressed = true
	j.jump_held = true
	VerbRunner.step(s, j, slime, 1.0 / 60.0)
	assert_eq(s.launched, "ground")
	assert_eq(s.velocity.x, 260.0)

func test_gravity_still_pulls_during_an_air_tackle() -> void:
	var s := MoveState.new()
	var t := _signature()
	t.on_floor = false
	VerbRunner.step(s, t, slime, 1.0 / 60.0)
	assert_eq(s.velocity.x, 260.0)
	assert_gt(s.velocity.y, 0.0)

func test_species_without_a_tackle_row_ignore_the_button() -> void:
	var s := MoveState.new()
	VerbRunner.step(s, _signature(), biped, 1.0 / 60.0)
	assert_eq(s.verb, "")
	assert_eq(s.velocity.x, 0.0)

func test_a_tackle_mid_jump_adds_no_vertical_reach() -> void:
	var plain: float = MovementSim.flat_jump(slime)["rise"]
	var sim := MovementSim.new(slime)
	sim.tick(0.0, true, true)
	var rise := 0.0
	for k in 80:
		sim.tick(0.0, false, true, 1.0, 0.0, k == 12)
		rise = maxf(rise, -sim.pos.y)
		if sim.on_floor:
			break
	assert_almost_eq(rise, plain, 0.5)
```

- [ ] **Step 2: Run** `tools/run_tests.sh verb_runner`. Expected: FAIL (`BurstDef` and the begin/run logic are missing).
- [ ] **Step 3: Implement.** Write `BurstDef`; add the `tackle` sub-resource and `bursts = [SubResource(...)]` to `slime.tres` (`[ext_resource ... id="2_bd"]` for the script, `[sub_resource type="Resource" id="Resource_tackle"]`). In `VerbRunner`, after `_ooze` and before the step: with no active verb, poll `p.bursts` in order and begin the first row whose `can_begin` holds (`cooldowns[id] <= 0`, and for `"signature"` `i.signature_pressed`, for `"down_run"` `i.on_floor`, `i.down >= SPREAD_DOWN` and `absf(s.velocity.x) >= row.min_start_speed`); begin sets `verb`, `verb_left = row.duration`, `verb_dir = float(s.facing)` when `row.speed > 0` else `signf(s.velocity.x)`, and `velocity.x = verb_dir * (row.speed if row.speed > 0 else absf(velocity.x))`. While a verb is active: first end it if `verb_left <= 1e-6`, `row.needs_floor and not i.on_floor`, `row.needs_down and i.down < SPREAD_DOWN`, or `row.min_speed > 0 and absf(velocity.x) < row.min_speed` (ending clears `verb` and sets `cooldowns[id] = row.cooldown` when above 0); otherwise decrement `verb_left`, and when `row.decel > 0` move `velocity.x` toward 0 by `decel * dt`. In `GroundAirStep.step`, call `_horizontal` only when `s.verb == ""`.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_` and `tools/run_tests.sh verb_runner`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git commit -m "feat: BurstDef and the slime's Tackle"`.

### Task 3: The puddle slide

**Files:**
- Modify: `scripts/movement/verb_runner.gd` (`is_flat`), `data/movement/slime.tres`, `tests/test_verb_runner.gd`

**Interfaces:**
- Consumes: Task 2's burst machinery. Produces: the slime's second row `puddle` (trigger `down_run`, `speed` 0, `min_start_speed` 100, `duration` 0.5, `decel` 300, `min_speed` 40, `needs_down` true, `needs_floor` true, `flat` true) and `is_flat` true while a `flat` row runs.

- [ ] **Step 1: Write the failing tests** (helper `_running(p, vx) -> MoveState` with `velocity.x = vx` and `facing` set from its sign):

```gdscript
func test_down_at_run_speed_starts_a_puddle_slide_that_bleeds_and_ends() -> void:
	var s := _running(slime, 140.0)
	VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
	assert_eq(s.verb, "puddle")
	assert_true(VerbRunner.is_flat(s, slime))
	assert_almost_eq(s.velocity.x, 135.0, 0.001)
	var ticks := 1
	while s.verb != "" and ticks < 60:
		VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
		ticks += 1
	assert_between(ticks, 20, 23, "ends below 40 px/s")

func test_a_slide_after_a_tackle_stops_at_the_half_second_cap() -> void:
	var s := _running(slime, 260.0)
	var ticks := 0
	VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
	ticks += 1
	while s.verb != "" and ticks < 60:
		VerbRunner.step(s, _in(0.0, true, 1.0), slime, 1.0 / 60.0)
		ticks += 1
	assert_between(ticks, 30, 32)

func test_releasing_down_or_leaving_the_floor_ends_the_slide_at_once() -> void:
	var s := _running(slime, 140.0)
	_run(slime, s, _in(0.0, true, 1.0), 3)
	assert_eq(s.verb, "puddle")
	_run(slime, s, _in(0.0, true, 0.0), 1)
	assert_eq(s.verb, "")
	s = _running(slime, 140.0)
	_run(slime, s, _in(0.0, true, 1.0), 2)
	_run(slime, s, _in(0.0, false, 1.0), 1)
	assert_eq(s.verb, "")

func test_it_needs_run_speed_and_the_floor() -> void:
	var slow := _running(slime, 99.0)
	_run(slime, slow, _in(0.0, true, 1.0), 1)
	assert_eq(slow.verb, "")
	assert_true(slow.spread, "below 100 it is the ordinary flat walk")
	var air := _running(slime, 140.0)
	_run(slime, air, _in(0.0, false, 1.0), 1)
	assert_eq(air.verb, "")

func test_tackle_wins_when_both_would_start() -> void:
	var s := _running(slime, 140.0)
	var i := _in(0.0, true, 1.0)
	i.signature_pressed = true
	VerbRunner.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.verb, "tackle")
```

- [ ] **Step 2: Run** `tools/run_tests.sh verb_runner`. Expected: FAIL (the row and `is_flat` are missing).
- [ ] **Step 3: Implement.** Add the `puddle` sub-resource to `slime.tres` and its `bursts` entry after `tackle`; make `VerbRunner.is_flat` return true while `s.spread` or the running row is `flat`.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_` and `tools/run_tests.sh verb_runner`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git commit -m "feat: the slime's puddle slide"`.

### Task 4: Play it in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`, `scripts/movement/species_look.gd`, `tests/test_movement_sandbox.gd`, `tests/test_species_look.gd`

**Interfaces:**
- Consumes: `VerbRunner` (`step`, `is_flat`, `STAND_RISE`), `BodyConfig.size()` and `spread_size()`, the `tackle` and `aim_down` input actions.
- Produces: `SpeciesLook.clip_for(species, on_floor, vy, vx, land_timer, verb := "", flat := false)` (the slime passes `verb == "tackle"` as dashing and `flat` as spread to `SlimeState.pick`; other species ignore both). The sandbox's body is named `"Body"` with a collision child named `"Shape"`; a low tunnel `Rect2(900, -52, 240, 40)` (a 12 px gap above the floor).

- [ ] **Step 1: Write the failing tests.** `tests/test_species_look.gd`: `clip_for("slime", true, 0.0, 100.0, 0.0, "tackle", false)` is `"tackle"`, `clip_for("slime", true, 0.0, 0.0, 0.0, "", true)` is `"spread"`, and `clip_for("spider", true, 0.0, 0.0, 0.0, "tackle", true)` is `"hang"`. `tests/test_movement_sandbox.gd` (an `after_each` releases the `move_right`, `aim_down` and `tackle` actions; `_box_size()` reads `sb.body.get_node("Shape").shape.size`):

```gdscript
func test_down_flattens_the_collision_box_and_releasing_stands_it_up() -> void:
	assert_eq(_box_size(), BodyConfig.size())
	sb.scripted.down = 1.0
	await _frames(5)
	assert_eq(_box_size(), BodyConfig.spread_size())
	sb.scripted.down = 0.0
	await _frames(5)
	assert_eq(_box_size(), BodyConfig.size())

func test_a_flat_slime_fits_the_tunnel_and_a_standing_one_does_not() -> void:
	sb.body.global_position = Vector2(850.0, -12.0)
	sb.scripted.dir = 1.0
	await _frames(60)
	assert_lt(sb.body.global_position.x, 890.0, "standing, it stops at the tunnel mouth")
	sb.scripted.down = 1.0
	await _frames(120)
	assert_gt(sb.body.global_position.x, 950.0, "flat, it crawls in")

func test_inside_the_tunnel_it_stays_flat_with_down_released() -> void:
	sb.scripted.down = 1.0
	await _frames(3)
	sb.body.global_position = Vector2(1000.0, -12.0)
	await _frames(3)
	sb.scripted.down = 0.0
	await _frames(10)
	assert_eq(_box_size(), BodyConfig.spread_size())
	assert_true(sb.state.spread)

func test_real_input_starts_a_tackle() -> void:
	sb.scripted = null
	Input.action_press("move_right")
	await _frames(15)
	Input.action_press("tackle")
	await _frames(2)
	Input.action_release("tackle")
	assert_eq(sb.state.verb, "tackle")

func test_real_input_starts_a_puddle_slide() -> void:
	sb.scripted = null
	Input.action_press("move_right")
	await _frames(20)
	Input.action_press("aim_down")
	await _frames(3)
	assert_eq(sb.state.verb, "puddle")
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_sandbox` and `tools/run_tests.sh species_look`. Expected: FAIL (the new parameters, node names and fields are missing).
- [ ] **Step 3: Implement.** `SpeciesLook.clip_for` takes the two new parameters. In the sandbox: name the body `"Body"` and its collision shape `"Shape"`; add the tunnel block; read `down` (`Input.get_action_strength("aim_down")`) and `signature_pressed` (`Input.is_action_just_pressed("tackle")`) in `_read_input` (and copy and consume them from `scripted`, like `jump_pressed`); each physics frame set `i.clearance_above` to `0.0` when `body.test_move(body.global_transform, Vector2(0.0, -VerbRunner.STAND_RISE))` collides and `1000.0` otherwise, call `VerbRunner.step` instead of `GroundAirStep.step`, then size the shape to `BodyConfig.spread_size()` or `size()` by `VerbRunner.is_flat` with its position at `BodyConfig.BOTTOM - size.y / 2.0` before `move_and_slide`; pass the verb and flatness to `clip_for`; tint the sprite and rect `Color(1.5, 1.3, 0.7)` while `state.verb != ""`; the HUD adds `verb: <name>` (or `flat` while spread) and the key line mentions Tackle (`J`) and down (`S`).
- [ ] **Step 4: Run** `tools/run_tests.sh movement_sandbox`, then the whole suite with `TEST_TIMEOUT=900 tools/run_tests.sh`. Expected: `PASS`. Then take screenshots with a throwaway script under `.tmp/` (the slime flat in the tunnel, mid-tackle, and sliding), look at them, and hand the feel to Sean: run `godot --path . res://scenes/movement_sandbox.tscn`, keys A/D, Space, J tackle, S down.
- [ ] **Step 5: Commit**: `git commit -m "feat: the sandbox plays the slime's Tackle, Ooze and puddle slide"`.
