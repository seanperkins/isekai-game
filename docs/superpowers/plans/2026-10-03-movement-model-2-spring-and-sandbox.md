# Movement Model, Part 2: Spring and Sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The slime's cosmetic squash-and-stretch spring as one pure, tested class, and a sandbox scene to drive the biped, slime and wolf profiles with real collision.

**Architecture:** `SquashSpring` is a damped spring that turns vertical speed and landings into a volume-preserving sprite scale; it is cosmetic and never touches a hit shape. The sandbox builds its own floor, ledges and body in `_ready`, drives the body with part 1's `GroundAirStep`, copies the body's velocity back into the step's state after `move_and_slide`, and touches no existing script.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`).

**Spec:** `docs/superpowers/specs/2026-10-03-movement-model-design.md` ("The slime's visual spring", "Sandbox"). Part 1 (`docs/superpowers/plans/2026-10-03-movement-model-1-step-and-profiles.md`) must be complete first.

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. Every new `class_name` script needs `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and its `.uid` file committed. A SCRIPT ERROR or Parse Error fails the whole run. Success prints `PASS: N tests`. Every test file starts with `extends GutTest`.
- New files only; do not edit `scripts/player/player.gd`, `scripts/world/room_lint.gd` or any existing script.
- Spring: `f` 3.5 Hz, `zeta` 0.4, `dt` capped at 1/30 s; target stretch `clampf(absf(vy) / 400.0, 0.0, 1.0) * 0.22`; landing kick `-clampf(fall_speed / 500.0, 0.0, 1.0) * 0.22 * 20.0` added to the spring's velocity; output clamped to plus or minus 0.22 and mapped to `(1 / (1 + s), 1 + s)`. The spring changes only the sprite's scale; hurt and attack shapes follow the art frame.
- Work in `.worktrees/movement-model` on `feat/movement-model`, continuing after part 1's commits on the same branch.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`.

## Review Focus

1. **A long frame on the spring.** `dt = 0.25` after a landing. Expect: finite, scale within 0.78 to 1.22 plus 1e-4 of slack (Task 1).
2. **Absurd inputs.** `vy = 1e6`, a fall speed of `1e6`. Expect: the scale stays within 0.78 to 1.22 (with 1e-4 of slack, since `Vector2` stores float32), never inverts or reaches zero, and keeps volume (Task 1).
3. **The state follows the body.** After a landing in the sandbox the step's `velocity.y` is 0, not the pre-collision speed (Task 2).

---

### Task 1: The squash spring

**Files:**
- Create: `scripts/movement/squash_spring.gd`
- Test: `tests/test_squash_spring.gd`

**Interfaces:**
- Produces: `class_name SquashSpring extends RefCounted`: `const LIMIT := 0.22`, `const MAX_DT := 1.0 / 30.0`, `const F := 3.5`, `const ZETA := 0.4`, `update(vy: float, dt: float) -> void` (steps the spring toward the stretch target for `vy`), `land(fall_speed: float) -> void` (kicks the spring's velocity), `sprite_scale() -> Vector2` (`s = clampf(value, -LIMIT, LIMIT)`; returns `Vector2(1.0 / (1.0 + s), 1.0 + s)`).

- [ ] **Step 1: Write the failing test** `tests/test_squash_spring.gd` (helper `_settle(sp, vy, ticks)` calls `update(vy, 1.0 / 60.0)` that many times):

```gdscript
func test_at_rest_and_in_steady_motion() -> void:
	var sp := SquashSpring.new()
	_settle(sp, 0.0, 60)
	assert_eq(sp.sprite_scale(), Vector2.ONE)
	_settle(sp, 400.0, 300)
	assert_almost_eq(sp.sprite_scale().y, 1.22, 0.01, "fast vertical motion stretches")

func test_a_landing_squashes_overshoots_and_settles() -> void:
	var sp := SquashSpring.new()
	sp.land(500.0)
	sp.update(0.0, 1.0 / 60.0)
	assert_lt(sp.sprite_scale().y, 1.0, "squashed")
	var peak := 0.0
	var low := 1.0
	for _k in 90:
		sp.update(0.0, 1.0 / 60.0)
		peak = maxf(peak, sp.sprite_scale().y)
		low = minf(low, sp.sprite_scale().y)
	assert_gt(peak, 1.0, "springs back past rest")
	assert_gte(low, 0.78)
	_settle(sp, 0.0, 300)
	assert_almost_eq(sp.sprite_scale().y, 1.0, 0.01)

func test_a_long_frame_and_absurd_inputs_stay_bounded_and_keep_volume() -> void:
	var sp := SquashSpring.new()
	sp.land(500.0)
	sp.update(0.0, 0.25)
	for k in 200:
		if k % 7 == 0:
			sp.land(1e6)
		sp.update(1e6 if k % 2 == 0 else -1e6, 1.0 / 60.0)
		var v := sp.sprite_scale()
		assert_true(is_finite(v.x) and is_finite(v.y))
		assert_between(v.y, 0.78 - 0.0001, 1.22 + 0.0001)
		assert_almost_eq(v.x * v.y, 1.0, 0.000001)
```

- [ ] **Step 2: Run** `tools/run_tests.sh squash_spring`. Expected: FAIL.
- [ ] **Step 3: Implement** `SquashSpring`: with `w = TAU * F`, each `update` clamps `dt` to `MAX_DT`, then `v += (w * w * (target - y) - 2.0 * ZETA * w * v) * dt` and `y += v * dt` (semi-implicit Euler); `land` adds the kick to `v`.
- [ ] **Step 4: Run** `tools/run_tests.sh squash_spring`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git commit -m "feat: squash spring for the slime's sprite"`.

### Task 2: The sandbox

**Files:**
- Create: `scripts/movement/movement_sandbox.gd`, `scenes/movement_sandbox.tscn`
- Test: `tests/test_movement_sandbox.gd`

**Interfaces:**
- Consumes: `GroundAirStep`, `MoveState`, `MoveInput`, `MovementProfile.of`, `SquashSpring`, `BodyConfig` (read-only, for the body box).
- Produces: `class_name MovementSandbox extends Node2D` with `var scripted: MoveInput = null` (when set it replaces polled input), `var profile: MovementProfile` (starts as the slime), `var state := MoveState.new()`, `var body: CharacterBody2D`, `func set_profile(id: String) -> void` (also gives `state` a fresh `MoveState()` and zeroes `body.velocity`, so no momentum carries over), `func set_boost(on: bool) -> void` (on is a jump boost of `sqrt(1.85)`), `func last_jump() -> Dictionary` (`{"rise", "airtime"}` of the most recent completed jump, taken from take-off to landing: the take-off y is the body's position before the move of the frame where `state.launched != ""`, matching `MovementSim`). The scene file is a `Node2D` with the script attached; the script builds everything else in `_ready` (the `Player._build_body` precedent).

- [ ] **Step 1: Write the failing test** `tests/test_movement_sandbox.gd`: instantiate the scene with `add_child_autofree`, then:
  - a scripted jump (`scripted.jump_pressed = true` once, which the sandbox consumes by clearing it after it builds that frame's `MoveInput`, so the test needs no frame-exact timing; `jump_held = true` for 30 physics frames, then cleared) awaited for 90 physics frames (`await get_tree().physics_frame` in a loop): the body left the floor and is on the floor again, `last_jump()["rise"]` is within 3 px of 63.25 for the slime, and `state.velocity.y == 0.0` after the landing;
  - `set_boost(true)` then the same jump: `last_jump()["rise"]` is above 100;
  - a running body (`scripted.dir = 1`) on `set_profile("wolf")` exceeds 200 px/s within 40 frames, and the same run on `set_profile("biped")` never exceeds 140.5.
- [ ] **Step 2: Run** `tools/run_tests.sh movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement** the sandbox: a `StaticBody2D` floor (top at `y = 0`, from `x = 0` to `1400`) and three ledges at `x >= 400` whose tops sit 40, 60 and 100 px above the floor (a partial hop, a full base jump with 3 px to spare, and one that needs the boost); a `CharacterBody2D` starting at `x = 100` with the `BodyConfig` box; per physics frame: build the `MoveInput` from `Input` (`move_left`, `move_right`, `jump`; `on_floor` from the body) or `scripted` (clearing `scripted.jump_pressed` afterwards, so a press is seen exactly once), call `GroundAirStep.step` with `jump_boost` from the boost toggle, set `body.velocity` from `state.velocity`, `move_and_slide`, then copy `body.velocity` back into `state.velocity`; keys 1 to 3 call `set_profile` and `B` toggles the boost; a `ColorRect` for the body drawn with `SquashSpring.sprite_scale()` (fed by `update(vy)` each frame and `land(fall_speed)` on landing, feet kept at the box bottom); a `Label` HUD with the profile id, speed, boost state and the last jump's rise and airtime.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_sandbox`, then the whole suite with `TEST_TIMEOUT=900 tools/run_tests.sh`. Expected: `PASS` for both, with the pre-existing test count unchanged plus the new tests. Then run `godot --path . res://scenes/movement_sandbox.tscn`, note each profile's HUD rise and airtime (a windowed run needs a display; with none, hand the whole step to Sean), and leave the feel verdict to Sean: whether it feels right is his call, not an agent's.
- [ ] **Step 5: Commit**: `git commit -m "feat: movement sandbox scene"`.
