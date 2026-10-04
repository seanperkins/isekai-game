# Movement Model, Part 1: Step and Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pure, tested ground/air movement step with three data profiles (biped, slime, wolf), new files only, with every profile's held jump pinned to today's envelope so existing rooms stay reachable. Part 2 adds the cosmetic spring and a sandbox scene.

**Architecture:** `GroundAirStep.step` is a pure static over a `MoveState` and a `MoveInput` (the style of `PlayerWater`): it mutates velocity and timers, the caller moves the body. Profiles are `MovementProfile` Resources in `data/movement/`. A tick-order simulator in `tests/support/` measures each profile's jump against a baseline built from `Player`'s own constants. Nothing in `scripts/player/` changes; wiring into `Player` (and walls) is a later plan against the merged `player.gd`. Part 2: `docs/superpowers/plans/2026-10-03-movement-model-2-spring-and-sandbox.md`.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`).

**Spec:** `docs/superpowers/specs/2026-10-03-movement-model-design.md`; evidence in `docs/research/movement-archetypes.md`. Read the spec with this plan.

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. Every new `class_name` script needs `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and its `.uid` file committed. A SCRIPT ERROR or Parse Error fails the whole run. Success prints `PASS: N tests`.
- New files only (`scripts/movement/`, `data/movement/`, `tests/`). Do not edit `scripts/player/player.gd`, `scripts/world/room_lint.gd` or any existing script: `feat/essence-overhaul` is editing `player.gd`. Reading `Player.SPEED`, `JUMP_VELOCITY`, `GRAVITY` and `RoomLint.REACH_RISE` from tests is fine.
- Work in `.worktrees/movement-model` on `feat/movement-model`, cut from main.
- Tick: 60 Hz, `dt = 1.0 / 60.0`. Tick order inside `step`: timers, horizontal control, gravity, jump, release. Every timer (coyote, buffer) is decremented and clamped to zero first (`t = maxf(0.0, t - dt)`), then tested `t > 0.0`. Gravity multipliers compound: held with `0 < vy < apex_band` applies both `apex_gravity_mult` and `fall_mult`. "Falling" means `vy > 0.0` strictly.
- Every test file starts with `extends GutTest`, declares `var biped: MovementProfile`, `var slime: MovementProfile`, `var wolf: MovementProfile`, and fills them in `before_each` with `MovementProfile.of("biped")` and so on.
- Profile values are the spec's table, copied into Task 1. The envelope (spec): a held flat jump's rise is within 1 px of the base and at least `RoomLint.REACH_RISE` (55); biped and slime airtime is within one tick of the base; wolf travel at top speed is at least 1.2 times the base; biped and slime standstill travel is at least 0.9 times the base; boost `sqrt(1.85)` scales rise 1.7 to 1.95 times; the slime rebound is 1.10 to 1.20 times the unrebounded rise.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`.

## Review Focus

1. **A frame hitch.** `dt = 0.25` after a slow frame. Expect: velocity finite, one gravity step of `g * dt`, timers clamped at zero (Task 3).
2. **Coyote and buffer together.** A press while a coyote window is open and a buffer is pending. Expect: exactly one launch, buffer and coyote cleared, no second launch next tick (Task 3).
3. **An analog stick and a stat of zero.** `dir = 0.5`, `speed_scale = 0`. Expect: half speed; a rooted body with `velocity.x == 0`, no division by zero (Task 2).
4. **Release at the wrong moment.** Releasing after the apex, or when already slower than the cut. Expect: no effect, and `CUT` never raises speed (Task 5).
5. **A rebound that raises reach.** The slime's buffered landing. Expect: launch speed equals the base times `sqrt(1.15)` every time with one state reused, and the apex is 1.10 to 1.20 times the unrebounded one (Task 5).

---

## File map

- `scripts/movement/movement_profile.gd` Resource of tunables with `IDS` and `of(id)`.
- `scripts/movement/move_input.gd`, `move_state.gd` the step's input and state (plain `RefCounted` fields).
- `scripts/movement/ground_air_step.gd` the pure step.
- `data/movement/{biped,slime,wolf}.tres` the three profiles.
- `tests/support/movement_sim.gd` the tick-order simulator; `tests/test_movement_*.gd`.

### Task 1: MovementProfile and the three profiles

**Files:**
- Create: `scripts/movement/movement_profile.gd`, `data/movement/biped.tres`, `data/movement/slime.tres`, `data/movement/wolf.tres`
- Test: `tests/test_movement_profile.gd`

**Interfaces:**
- Produces: `class_name MovementProfile extends Resource` with `enum ReleaseStyle { CUT, SOFT }`, `const IDS := ["biped", "slime", "wolf"]`, `static func of(id: String) -> MovementProfile` (loads `res://data/movement/<id>.tres`; null when `ResourceLoader.exists` is false, never calling `load` on a missing path), and `@export` fields named exactly as the spec's table: `id: String`, `top_speed`, `ground_accel_time`, `ground_stop_time`, `ground_turn_time`, `air_accel_mult`, `air_stop_time`, `air_keeps_momentum: bool`, `jump_velocity`, `gravity`, `fall_mult`, `apex_band`, `apex_gravity_mult`, `release_style: ReleaseStyle`, `release_factor`, `coyote`, `buffer`, `rebound_rise` (every unlisted type is `float`). Defaults are the biped's values.

- [ ] **Step 1: Write the failing test** in `tests/test_movement_profile.gd`:

```gdscript
func test_the_three_profiles_load_with_the_spec_values() -> void:
	assert_eq(MovementProfile.IDS, ["biped", "slime", "wolf"])
	for id in MovementProfile.IDS:
		var p := MovementProfile.of(id)
		assert_not_null(p, id)
		assert_eq(p.id, id)
		for v in [p.top_speed, p.ground_accel_time, p.ground_stop_time, p.ground_turn_time, p.air_stop_time, p.jump_velocity, p.gravity, p.fall_mult]:
			assert_gt(v, 0.0, id)
	var b := MovementProfile.of("biped")
	assert_eq([b.jump_velocity, b.gravity, b.fall_mult, b.release_factor], [330.0, 900.0, 1.0, 0.35])
	assert_eq(b.release_style, MovementProfile.ReleaseStyle.CUT)
	var s := MovementProfile.of("slime")
	assert_eq([s.top_speed, s.jump_velocity, s.fall_mult, s.apex_band, s.rebound_rise], [140.0, 328.5, 1.53, 40.0, 0.15])
	assert_eq(s.release_style, MovementProfile.ReleaseStyle.SOFT)
	var w := MovementProfile.of("wolf")
	assert_eq([w.top_speed, w.ground_accel_time, w.ground_turn_time, w.jump_velocity, w.gravity], [230.0, 0.4, 0.1, 403.0, 1344.0])
	assert_true(w.air_keeps_momentum)

func test_an_unknown_id_is_null() -> void:
	assert_null(MovementProfile.of("dragon"))
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_profile`. Expected: FAIL (script errors for the missing class).
- [ ] **Step 3: Implement** the script and the three `.tres` files (hand-written in the `gloom_wolf.tres` shape: `script_class="MovementProfile"`, `release_style = 0` for CUT and `1` for SOFT) with the spec's table values. Run `godot --headless --import`.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_profile`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git add scripts/movement data/movement tests/test_movement_profile.gd` (with the `.uid` files), then `git commit -m "feat: movement profiles for biped, slime and wolf"`.

### Task 2: Ground and air control

**Files:**
- Create: `scripts/movement/move_input.gd`, `scripts/movement/move_state.gd`, `scripts/movement/ground_air_step.gd`
- Test: `tests/test_movement_ground.gd`

**Interfaces:**
- Produces: `class_name MoveInput extends RefCounted` with `dir := 0.0`, `on_floor := true`, `jump_pressed := false`, `jump_held := false`.
- Produces: `class_name MoveState extends RefCounted` with `velocity := Vector2.ZERO`, `coyote := 0.0`, `buffer := 0.0`, `air_time := 0.0`, `jumping := false`, `launch_speed := 0.0`, `launched := ""` (reset to `""` at the start of every step; Task 3 sets it).
- Produces: `GroundAirStep.step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale := 1.0, jump_boost := 1.0) -> void`. This task implements the horizontal part only; later tasks add to the same function in the tick order.

- [ ] **Step 1: Write the failing test** in `tests/test_movement_ground.gd`, with three helpers: `_run(p, s, i, ticks)` (calls `step` that many times at `1.0 / 60.0`), `_in(dir := 0.0, on_floor := true) -> MoveInput`, `_at(vx: float) -> MoveState`:

```gdscript
func test_ground_ramps_per_profile() -> void:
	var s := MoveState.new()
	_run(biped, s, _in(1.0), 3)
	assert_eq(s.velocity.x, 140.0)
	s = MoveState.new()
	_run(slime, s, _in(1.0), 2)
	assert_almost_eq(s.velocity.x, 93.33, 0.05)
	_run(slime, s, _in(1.0), 2)
	assert_eq(s.velocity.x, 140.0)
	_run(slime, s, _in(), 4)
	assert_eq(s.velocity.x, 0.0, "stops in 0.06 s")
	s = MoveState.new()
	_run(wolf, s, _in(1.0), 12)
	assert_almost_eq(s.velocity.x, 115.0, 0.1)
	_run(wolf, s, _in(1.0), 12)
	assert_almost_eq(s.velocity.x, 230.0, 0.01)

func test_wolf_brakes_in_six_ticks_then_reverses() -> void:
	var s := _at(230.0)
	_run(wolf, s, _in(-1.0), 6)
	assert_almost_eq(s.velocity.x, 0.0, 0.001)
	_run(wolf, s, _in(-1.0), 2)
	assert_lt(s.velocity.x, 0.0)

func test_air_control_per_profile() -> void:
	var s := _at(140.0)
	_run(slime, s, _in(0.0, false), 10)
	assert_almost_eq(s.velocity.x, 73.33, 0.05, "bleeds at 400 px/s^2")
	s = _at(230.0)
	_run(wolf, s, _in(0.0, false), 30)
	assert_eq(s.velocity.x, 230.0, "the wolf keeps its momentum")
	s = _at(140.0)
	_run(biped, s, _in(0.0, false), 3)
	assert_eq(s.velocity.x, 0.0)
	s = MoveState.new()
	_run(slime, s, _in(1.0, false), 3)
	assert_almost_eq(s.velocity.x, 70.0, 0.05, "slime air accel is 1400 px/s^2")

func test_analog_input_and_a_zero_speed_stat() -> void:
	var s := MoveState.new()
	_run(biped, s, _in(0.5), 10)
	assert_eq(s.velocity.x, 70.0)
	s = _at(100.0)
	GroundAirStep.step(s, _in(0.5), biped, 1.0 / 60.0, 0.0)
	assert_eq(s.velocity.x, 0.0, "speed_scale 0 roots the body")
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_ground`. Expected: FAIL (classes missing).
- [ ] **Step 3: Implement** the three classes. Horizontal rules are the spec's Model section; compute the rates inline from `top = p.top_speed * speed_scale` (zero or less sets `velocity.x = 0` and skips control): on the floor, no input to rest at `top / p.ground_stop_time`, input opposing the velocity to rest at `top / p.ground_turn_time`, else toward `dir * top` at `top / p.ground_accel_time`; in the air, no input to rest at `top / p.air_stop_time` unless `p.air_keeps_momentum`, else toward `dir * top` at `top / p.ground_accel_time * p.air_accel_mult`. Use `move_toward`.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_ground`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git commit -m "feat: ground and air control in the movement step"` (with the new scripts, `.uid` files and the test).

### Task 3: Gravity, jump, coyote and buffer

**Files:**
- Modify: `scripts/movement/ground_air_step.gd`
- Create: `tests/support/movement_sim.gd`
- Test: `tests/test_movement_jump.gd`

**Interfaces:**
- Consumes: Task 2's `step`, `MoveState`, `MoveInput`.
- Produces: `class_name MovementSim extends RefCounted` (test support): `_init(p: MovementProfile)`, `var state := MoveState.new()`, `var pos := Vector2.ZERO` (floor at `y = 0`, up negative), `var on_floor := true`, and `tick(dir := 0.0, pressed := false, held := false, boost := 1.0) -> void`: builds a `MoveInput`, calls `step` at 1/60 s, then `pos += velocity * dt`, then lands (`pos.y >= -0.001` and `velocity.y >= 0` sets `pos.y = 0`, `velocity.y = 0`, `on_floor = true`; otherwise `on_floor = false`).
- Produces: `static func base_profile() -> MovementProfile`: `MovementProfile.new()` with `jump_velocity = -Player.JUMP_VELOCITY`, `gravity = Player.GRAVITY`, `top_speed = Player.SPEED`, `fall_mult = 1.0`, `apex_band = 0.0`, `release_style = CUT`, `rebound_rise = 0.0`, `air_keeps_momentum = false` (today's jump as a profile).
- Produces: `static func flat_jump(p: MovementProfile, boost := 1.0, hold_seconds := 100.0, start_speed := -1.0, rebound := false) -> Dictionary` returning `{"rise", "airtime", "distance"}`: starts at `velocity.x = p.top_speed` (or `start_speed` when it is `>= 0`), `state.air_time = 0.5` when `rebound`, tick 0 presses jump, `dir = 1` throughout, the jump is held while elapsed time `< hold_seconds` (tick 0 is always held), stops at the first landing; `rise` is the highest point above the floor, `airtime` is ticks times `dt`, `distance` is `pos.x`.

- [ ] **Step 1: Write the failing tests** in `tests/test_movement_jump.gd`:

```gdscript
func test_gravity_only_in_the_air_with_fall_and_apex_rules() -> void:
	var s := MoveState.new()
	GroundAirStep.step(s, MoveInput.new(), biped, 1.0 / 60.0)
	assert_eq(s.velocity.y, 0.0)
	var air := MoveInput.new()
	air.on_floor = false
	GroundAirStep.step(s, air, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 15.0, 0.001)
	s = MoveState.new()
	s.velocity.y = 100.0
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 100.0 + 900.0 * 1.53 / 60.0, 0.001, "falling is heavier")
	s = MoveState.new()
	s.velocity.y = -20.0
	air.jump_held = true
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -20.0 + 450.0 / 60.0, 0.001, "float at the apex while held")
	s = MoveState.new()
	s.velocity.y = 20.0
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 20.0 + 900.0 * 0.5 * 1.53 / 60.0, 0.001, "float and fall compound")
	s = MoveState.new()
	s.velocity.y = -20.0
	air.jump_held = false
	GroundAirStep.step(s, air, slime, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -20.0 + 900.0 / 60.0, 0.001, "no float once released")

func test_a_press_launches_and_the_boost_scales_it() -> void:
	var sim := MovementSim.new(biped)
	sim.tick(0.0, true, true)
	assert_eq(sim.state.velocity.y, -330.0)
	assert_eq(sim.state.launched, "ground")
	sim = MovementSim.new(biped)
	sim.tick(0.0, true, true, 1.3)
	assert_almost_eq(sim.state.velocity.y, -330.0 * 1.3, 0.001)

func test_coyote_lets_a_late_jump_through_for_three_ticks_not_nine() -> void:
	for late in [3, 9]:
		var sim := MovementSim.new(biped)
		sim.tick()  # a floor tick refills the coyote window
		sim.pos.y = -50.0
		sim.on_floor = false  # the floor ends under the body
		for _k in late:
			sim.tick()
		sim.tick(0.0, true, true)
		if late == 3:
			assert_lt(sim.state.velocity.y, -300.0)
			assert_eq(sim.state.launched, "coyote")
		else:
			assert_gt(sim.state.velocity.y, 0.0)
			assert_eq(sim.state.launched, "")

func test_a_buffered_press_fires_on_landing_inside_the_window_only() -> void:
	for early in [4, 8]:
		var s := MoveState.new()
		var i := MoveInput.new()
		i.on_floor = false
		i.jump_pressed = true
		i.jump_held = true
		GroundAirStep.step(s, i, biped, 1.0 / 60.0)  # the press, in the air
		i.jump_pressed = false
		for _k in early - 1:
			GroundAirStep.step(s, i, biped, 1.0 / 60.0)
		i.on_floor = true  # lands `early` ticks after the press
		s.velocity.y = 0.0
		GroundAirStep.step(s, i, biped, 1.0 / 60.0)
		assert_eq(s.velocity.y, -330.0 if early == 4 else 0.0, "%d ticks" % early)

func test_coyote_and_buffer_together_launch_once() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.on_floor = false
	i.jump_pressed = true
	i.jump_held = true
	s.coyote = 0.05
	s.buffer = 0.05
	GroundAirStep.step(s, i, biped, 1.0 / 60.0)
	assert_eq(s.velocity.y, -330.0)
	assert_eq(s.buffer, 0.0)
	assert_eq(s.coyote, 0.0)
	i.jump_pressed = false
	GroundAirStep.step(s, i, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -315.0, 0.001, "no second launch")
	assert_eq(s.launched, "")

func test_a_frame_hitch_stays_finite() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.on_floor = false
	i.dir = 1.0
	s.coyote = 0.1
	s.buffer = 0.1
	GroundAirStep.step(s, i, slime, 0.25)
	assert_almost_eq(s.velocity.y, 225.0, 0.001)
	assert_true(is_finite(s.velocity.x))
	assert_eq(s.coyote, 0.0)
	assert_eq(s.buffer, 0.0)
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_jump`. Expected: FAIL.
- [ ] **Step 3: Implement** in `step`: reset `launched`; coyote is `p.coyote` on the floor, else `maxf(0, coyote - dt)`; buffer is `p.buffer` on a press, else `maxf(0, buffer - dt)`; on the floor a positive `velocity.y` is zeroed; gravity airborne only, starting from `p.gravity`, times `p.apex_gravity_mult` while `i.jump_held` and `absf(vy) < p.apex_band` (a band of 0 never matches), times `p.fall_mult` while `vy > 0` (both apply together); a jump fires when `buffer > 0` and (`on_floor` or `coyote > 0`): `velocity.y = -p.jump_velocity * jump_boost`, `launch_speed` set, `jumping = true`, `launched = "ground"` on the floor or `"coyote"` off it, buffer and coyote cleared. `air_time` grows while airborne and resets to 0 after a floor tick's jump decision. Write `MovementSim` as specified.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_`. Expected: `PASS` (tasks 1 to 3).
- [ ] **Step 5: Commit**: `git commit -m "feat: gravity, jump, coyote and buffer in the movement step"`.

### Task 4: The envelope pin

**Files:**
- Test: `tests/test_movement_envelope.gd`

**Interfaces:**
- Consumes: `MovementSim.flat_jump`, `MovementSim.base_profile`, the three profiles, `RoomLint.REACH_RISE`.

This pin lands before release and rebound exist, on purpose: a held flat jump cannot depend on them, so it is the contract every later task must keep.

- [ ] **Step 1: Write the failing test** `tests/test_movement_envelope.gd`:

```gdscript
func test_the_base_jump_is_what_the_sim_measures() -> void:
	var b := MovementSim.flat_jump(MovementSim.base_profile())
	assert_almost_eq(b["rise"], 63.25, 0.05)
	assert_almost_eq(b["airtime"], 0.75, 0.001)
	assert_almost_eq(b["distance"], 105.0, 0.1)

func test_every_profile_keeps_the_base_rise() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	for p in [biped, slime, wolf]:
		var j := MovementSim.flat_jump(p)
		assert_almost_eq(j["rise"], base["rise"], 1.0, p.id)
		assert_gte(j["rise"], RoomLint.REACH_RISE, p.id)

func test_biped_is_the_base_held_jump_and_slime_matches_its_airtime() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	var j := MovementSim.flat_jump(biped)
	for key in base:
		assert_almost_eq(j[key], base[key], 0.0001, key)
	assert_almost_eq(MovementSim.flat_jump(slime)["airtime"], base["airtime"], 1.0 / 60.0 + 0.0001)

func test_the_wolf_trades_airtime_for_travel() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	var w := MovementSim.flat_jump(wolf)
	assert_lt(w["airtime"], base["airtime"])
	assert_gte(w["distance"], 1.2 * base["distance"])

func test_biped_and_slime_keep_the_standstill_gap() -> void:
	var base := MovementSim.flat_jump(MovementSim.base_profile())
	for p in [biped, slime]:
		assert_gte(MovementSim.flat_jump(p, 1.0, 100.0, 0.0)["distance"], 0.9 * base["distance"], p.id)

func test_the_jump_height_stat_still_scales_rise() -> void:
	for p in [biped, slime, wolf]:
		var ratio: float = MovementSim.flat_jump(p, sqrt(1.85))["rise"] / MovementSim.flat_jump(p)["rise"]
		assert_between(ratio, 1.7, 1.95, p.id)
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_envelope`. Expected: PASS at once (everything it needs exists after Task 3). Temporarily change the slime's `fall_mult` in `data/movement/slime.tres` to `1.0`, confirm `test_biped_is_the_base_held_jump_and_slime_matches_its_airtime` fails, then restore the value. A red assertion on a real change means a profile value or a step rule drifted from the spec: fix the profile or step, never the test's tolerance.
- [ ] **Step 3: Commit**: `git commit -m "test: pin every profile's held jump to the base envelope"`.

### Task 5: Release styles and the slime's rebound

**Files:**
- Modify: `scripts/movement/ground_air_step.gd`
- Test: `tests/test_movement_release.gd`

**Interfaces:**
- Consumes: Task 3's state (`jumping`, `launch_speed`, `air_time`, `launched`) and `MovementSim.flat_jump`.
- Produces: release behavior (`CUT`, `SOFT`) and the rebound launch, inside `step`.

- [ ] **Step 1: Write the failing tests** in `tests/test_movement_release.gd`:

```gdscript
func test_cut_caps_the_rise_speed_once() -> void:
	var sim := MovementSim.new(biped)
	sim.tick(0.0, true, true)
	sim.tick(0.0, false, false)
	assert_almost_eq(sim.state.velocity.y, -330.0 * 0.35, 0.001)
	assert_false(sim.state.jumping)
	sim = MovementSim.new(biped)
	sim.tick(0.0, true, false)
	assert_eq(sim.state.velocity.y, -330.0, "the launch tick is never cut")

func test_cut_never_raises_speed_and_nothing_happens_after_the_apex() -> void:
	var air := MoveInput.new()
	air.on_floor = false
	var s := MoveState.new()
	s.jumping = true
	s.launch_speed = 330.0
	s.velocity.y = -50.0
	GroundAirStep.step(s, air, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, -35.0, 0.001, "only gravity acted")
	s = MoveState.new()
	s.jumping = true
	s.launch_speed = 330.0
	s.velocity.y = 10.0
	GroundAirStep.step(s, air, biped, 1.0 / 60.0)
	assert_almost_eq(s.velocity.y, 25.0, 0.001)
	assert_false(s.jumping)

func test_tap_hops_are_rounded_per_profile_and_never_a_no_op() -> void:
	for row in [[biped, 8.0, 20.0], [slime, 18.0, 34.0], [wolf, 24.0, 40.0]]:
		var tap: float = MovementSim.flat_jump(row[0], 1.0, 0.0)["rise"]
		assert_between(tap, row[1], row[2], row[0].id)
		assert_lt(tap, 0.6 * MovementSim.flat_jump(row[0])["rise"], row[0].id)

func test_a_buffered_landing_rebounds_only_for_the_slime_and_never_compounds() -> void:
	var s := MoveState.new()
	for _n in 2:  # one state across two landings
		s.air_time = 0.5
		s.buffer = 0.05
		GroundAirStep.step(s, MoveInput.new(), slime, 1.0 / 60.0)
		assert_almost_eq(s.launch_speed, 328.5 * sqrt(1.15), 0.01)
		assert_eq(s.launched, "rebound")
	var w := MoveState.new()
	w.air_time = 0.5
	w.buffer = 0.05
	GroundAirStep.step(w, MoveInput.new(), wolf, 1.0 / 60.0)
	assert_eq(w.launch_speed, 403.0)
	assert_eq(w.launched, "ground")

func test_the_rebound_raises_the_apex_by_about_fifteen_percent() -> void:
	var ratio: float = MovementSim.flat_jump(slime, 1.0, 100.0, -1.0, true)["rise"] / MovementSim.flat_jump(slime)["rise"]
	assert_between(ratio, 1.10, 1.20)

func test_no_rebound_from_a_grounded_press_a_coyote_jump_or_a_held_button() -> void:
	var i := MoveInput.new()
	i.jump_pressed = true
	i.jump_held = true
	var s := MoveState.new()
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launch_speed, 328.5)
	assert_eq(s.launched, "ground")
	i.on_floor = false
	s = MoveState.new()
	s.air_time = 0.5  # long enough for a rebound, but the body is off the floor
	s.coyote = 0.05
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launch_speed, 328.5)
	assert_eq(s.launched, "coyote")
	i.on_floor = true
	i.jump_pressed = false  # held through the landing, never pressed
	s = MoveState.new()
	s.air_time = 0.5
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launched, "")

func test_air_time_and_the_rebound_come_from_a_real_flight() -> void:
	var sim := MovementSim.new(slime)
	var ticks := roundi(MovementSim.flat_jump(slime)["airtime"] * 60.0)
	sim.tick(0.0, true, true)
	for _k in range(1, ticks - 3):
		sim.tick(0.0, false, true)
	sim.tick(0.0, true, true)  # a press three ticks before the landing
	for _k in 6:
		sim.tick(0.0, false, true)
		if sim.state.launched != "":
			break
	assert_eq(sim.state.launched, "rebound")
	var hop := MovementSim.new(slime)
	hop.pos.y = -3.0  # a drop of five ticks, under the 0.12 s minimum
	hop.on_floor = false
	hop.tick()
	hop.tick()
	hop.tick(0.0, true, true)
	for _k in 6:
		hop.tick(0.0, false, true)
		if hop.state.launched != "":
			break
	assert_eq(hop.state.launched, "ground")
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_release`. Expected: FAIL.
- [ ] **Step 3: Implement** in `step`: after the jump decision, if `jumping`, `velocity.y < 0`, the jump was not launched this tick and `not i.jump_held`: `CUT` sets `velocity.y = maxf(velocity.y, -launch_speed * p.release_factor)` and clears `jumping`; `SOFT` is applied in the gravity step (multiply by `release_factor` while `jumping`, rising and released). Clear `jumping` when `velocity.y >= 0` or on the floor, inside the same not-launched-this-tick guard so the launch tick never clears it. The rebound: a jump firing with `i.on_floor` and `s.air_time >= REBOUND_MIN_AIR` (a named constant, 0.12) multiplies the launch speed by `sqrt(1.0 + p.rebound_rise)` and sets `launched = "rebound"` (a profile with `rebound_rise == 0` stays `"ground"`).
- [ ] **Step 4: Run** `tools/run_tests.sh movement_`. Expected: `PASS` (envelope tests included).
- [ ] **Step 5: Commit**: `git commit -m "feat: release styles and the slime's rebound"`.

Part 1 ends here with the model and profiles tested. Next: part 2 (the spring and the sandbox), then, after `feat/essence-overhaul` merges, the integration plan against the merged `player.gd` (wiring, walls, corner correction, the reach tests, the rebound against the G5 chimney, the wolf's run-up audit).
