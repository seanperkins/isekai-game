# Species Movesets, Part 3b: Faster Tackle and Slide, and the Slime's Bounce Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From Sean's feel notes on the sandbox: Tackle and the puddle slide are about 30% faster and carry farther, and the slime bounces: hold jump through a hard landing and it springs back up on its own, and a well-timed press at landing adds height on top, chaining to a cap.

**Architecture:** Two data edits (the Tackle and puddle rows) and one rule in `GroundAirStep`: a landing with enough impact and jump held relaunches at a fraction of the impact speed (hold bounce), and the existing timed rebound grows a chain. Both are profile numbers on the slime (`bounce_keep`, `rebound_rise`, `rebound_cap`); other species have zeros and are unchanged. The squash spring already fires on every landing. Wall stick and wall jump are plan 3c.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`).

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (the slime's bullets, which Task 3 updates). Sean's decisions on 2026-10-04: bounce is "both" (hold to bounce, plus a stronger timed chain: +30% and chained up to +60%), Tackle and the slide about 30% faster.

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. A SCRIPT ERROR, Parse Error or warning-as-error fails the whole run (type every `var`). `.uid` files for new scripts are committed. Success prints `PASS: N tests`. Every test file starts with `extends GutTest`.
- Edits are limited to `scripts/movement/*`, `data/movement/*`, `tests/*` (movement, verb runner, bounce, sandbox, release tests) and the spec. Do not edit `scripts/player/`, `scripts/enemies/`, `scripts/world/` or art.
- Work in `.worktrees/slime-bounce` on `feat/slime-bounce`.
- Numbers. Tackle: speed 340, duration 0.18 s (it holds for eleven ticks). Puddle slide: decel 150 px/s^2, ends below 70 px/s (the flat-walk speed), the other numbers unchanged (starts at 100 px/s or more, 0.5 s cap, ends on release or leaving the floor). Hold bounce: a landing after at least 0.12 s of air, with the impact speed (`last_vy`) at least 250 px/s (a drop of about 23 px, one body height) and jump held, relaunches at `min(impact * 0.85 / sqrt(fall_mult), jump_velocity * jump_boost)` with `launched == "bounce"`; it repeats while the conditions hold. The division by `sqrt(fall_mult)` is the point: the slime falls with 1.53 times gravity, so its impact speed is `sqrt(1.53)` (about 24%) above the speed it launched at, and without it a bounce would never decay; with it each bounce rises 0.72 times as high as the last, that is, launches at 0.85 times the last launch speed. Timed rebound: a buffered press on such a landing adds `min(0.3 * chain, 0.6)` to the rise (speed times `sqrt(1 + bonus)`), where `chain` counts consecutive timed rebounds (1, 2, 3...) and any landing with no timed rebound resets it to 0. Slime profile: `rebound_rise 0.3`, `rebound_cap 0.6`, `bounce_keep 0.85`, `bounce_min_impact 250`. A cap of 0 means a single link (the cap equals `rebound_rise`).
- The impact speed is the vertical velocity the step handed the body on the previous tick: `MoveState.last_vy`, set at the end of every step (the caller's physics then zeroes the body's velocity on landing).
- The base jump pin and every earlier test stay green; the hold bounce is capped at the base jump, so it adds no reach beyond the fall it came from, and the timed chain's ceiling is pinned by a test (about 1.6 times the base rise). The room validator learns these in the reach-model plan before they ship in the game.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`.

## Review Focus

1. **A soft landing with jump held.** A drop under about 23 px (impact under 250) must not bounce (Task 2).
2. **Releasing jump mid-bounce, and species without bounce.** Expect: the next landing is plain; the biped, wolf and spider never bounce (Task 2).
3. **Hold bounce plus a timed press at the same landing.** Expect: the press wins (a jump with the chain bonus), no double launch (Task 2).
4. **A landing with no press after a chain.** Expect: the chain resets (Task 2).
5. **The 0.5 s control rule and the slide numbers.** Expect: the slide still ends by 0.5 s from a Tackle's speed and ends at 70 px/s from a run (Task 1).

---

## File map

- `data/movement/slime.tres` the Tackle, puddle and bounce numbers; `scripts/movement/movement_profile.gd` three fields; `scripts/movement/move_state.gd` `last_vy`, `chain`; `scripts/movement/ground_air_step.gd` the bounce rule.
- `tests/test_verb_runner.gd`, `tests/test_movement_release.gd` updated; `tests/test_movement_bounce.gd` new; sandbox test grows; the spec's slime bullets.

### Task 1: Faster Tackle and slide

**Files:**
- Modify: `data/movement/slime.tres`, `tests/test_verb_runner.gd`, `tests/test_movement_sandbox.gd` (only if a tick count there changes)

- [ ] **Step 1: Update the tests first** in `tests/test_verb_runner.gd`: `test_tackle_holds_260_for_nine_ticks_then_returns_control` becomes `..._340_for_eleven_ticks_...` (the first press gives `340.0`; the loop runs 10 more ticks each at `340.0`; `verb` is still `"tackle"` after tick 11 and `""` after tick 12, with `velocity.x < 340.0`); `test_tackle_goes_the_way...` expects `-340.0`; the jump-during-tackle and air-tackle tests expect `340.0`; in `test_down_at_run_speed_starts_a_puddle_slide_that_bleeds_and_ends` the first slide tick is `137.5` and the end window is `assert_between(ticks, 28, 31, "ends below 70 px/s")`; `test_a_slide_after_a_tackle_stops_at_the_half_second_cap` keeps its 30 to 32 window.
- [ ] **Step 2: Run** `tools/run_tests.sh verb_runner`. Expected: FAIL (the data still has 260 and 300).
- [ ] **Step 3: Implement** in `data/movement/slime.tres`: the `tackle` row `speed = 340.0`, `duration = 0.18`; the `puddle` row `decel = 150.0`, `min_speed = 70.0`.
- [ ] **Step 4: Run** `tools/run_tests.sh verb_runner` and `tools/run_tests.sh movement_sandbox`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git add data tests` then `git commit -m "feat: the slime's Tackle and puddle slide are about 30% faster"`.

### Task 2: Hold bounce and the timed chain

**Files:**
- Modify: `scripts/movement/move_state.gd`, `scripts/movement/movement_profile.gd`, `scripts/movement/ground_air_step.gd`, `data/movement/slime.tres`, `tests/test_movement_release.gd`
- Create: `tests/test_movement_bounce.gd`

**Interfaces:**
- Produces: `MoveState.last_vy := 0.0` and `MoveState.chain := 0`; `MovementProfile.bounce_keep := 0.0`, `bounce_min_impact := 250.0`, `rebound_cap := 0.0` (the slime's values are in the constraints above); `launched == "bounce"`.

- [ ] **Step 1: Write the failing tests.** In `tests/test_movement_release.gd`: replace `test_a_buffered_landing_rebounds_only_for_the_slime_and_never_compounds` with `test_timed_rebounds_chain_thirty_then_sixty_percent_and_a_landing_without_a_press_resets` (one `MoveState`; three times set `s.air_time = 0.5` and `s.buffer = 0.05` and step with `MoveInput.new()`, expecting `launch_speed` of `328.5 * sqrt(1.3)`, then `328.5 * sqrt(1.6)`, then `328.5 * sqrt(1.6)` again (the cap), each with `launched == "rebound"`; then one landing with `s.air_time = 0.5` and no buffer, after which `s.chain == 0`; then a press landing again gives `328.5 * sqrt(1.3)`; the wolf with the same setup launches at `403.0` with `launched == "ground"`); change `test_the_rebound_raises_the_apex_by_about_fifteen_percent` to `..._thirty_percent` with `assert_between(ratio, 1.22, 1.38)`; rename `test_no_rebound_from_a_grounded_press_a_coyote_jump_or_a_held_button` to `..._or_a_held_button_without_a_hard_landing` (its assertions stay: a fresh state has `last_vy` 0). Create `tests/test_movement_bounce.gd` (`slime`, `biped` loaded in `before_each`; helper `_drop(p, height, hold) -> Array` that starts a `MovementSim` `height` px above the floor, off the floor, ticking up to 900 times with `jump_held = hold` and returning the `launch_speed` of each tick whose `state.launched == "bounce"`):

```gdscript
func test_a_hard_landing_with_jump_held_bounces_at_85_percent_until_it_settles() -> void:
	var launches := _drop(slime, 300.0, true)
	assert_between(launches.size(), 3, 6)
	assert_almost_eq(launches[0], 328.5, 0.01, "capped at the base jump")
	for k in range(1, launches.size()):
		assert_almost_eq(launches[k] / launches[k - 1], 0.85, 0.06)

func test_a_soft_landing_does_not_bounce() -> void:
	assert_eq(_drop(slime, 15.0, true).size(), 0)

func test_releasing_jump_stops_the_bouncing() -> void:
	assert_eq(_drop(slime, 300.0, false).size(), 0)

func test_species_without_bounce_never_bounce() -> void:
	assert_eq(_drop(biped, 300.0, true).size(), 0)

func test_a_hold_bounce_never_rises_above_the_base_jump() -> void:
	var sim := MovementSim.new(slime)
	sim.pos.y = -300.0
	sim.on_floor = false
	var highest := 0.0
	var landed := false
	for _k in 600:
		sim.tick(0.0, false, true)
		if sim.on_floor:
			landed = true
		if landed:
			highest = maxf(highest, -sim.pos.y)
	assert_lte(highest, MovementSim.flat_jump(slime)["rise"] + 0.5)

func test_a_timed_press_beats_the_hold_bounce_with_one_launch() -> void:
	var s := MoveState.new()
	var i := MoveInput.new()
	i.jump_held = true
	s.air_time = 0.5
	s.last_vy = 400.0
	s.buffer = 0.05
	GroundAirStep.step(s, i, slime, 1.0 / 60.0)
	assert_eq(s.launched, "rebound")
	assert_almost_eq(s.launch_speed, 328.5 * sqrt(1.3), 0.01)

func test_the_timed_chain_tops_out_near_one_point_six_times_the_base_rise() -> void:
	var base: float = MovementSim.flat_jump(slime)["rise"]
	var sim := MovementSim.new(slime)
	sim.state.chain = 5
	sim.state.air_time = 0.5
	sim.tick(0.0, true, true)
	var rise := 0.0
	for _k in 120:
		sim.tick(0.0, false, true)
		rise = maxf(rise, -sim.pos.y)
		if sim.on_floor:
			break
	assert_between(rise / base, 1.5, 1.7)
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_`. Expected: FAIL (fields and the rule are missing; `last_vy` and `chain` do not exist).
- [ ] **Step 3: Implement.** Add the two state fields and three profile fields (docs in the file's style); `slime.tres` gets `rebound_rise = 0.3`, `rebound_cap = 0.6`, `bounce_keep = 0.85`, `bounce_min_impact = 250.0`. In `GroundAirStep.step`, end with `s.last_vy = s.velocity.y` (after the existing `air_time` line). In `_jump`, compute `landing := i.on_floor and s.air_time >= REBOUND_MIN_AIR`. A live buffer on the floor or inside coyote launches as today, except that on a `landing` with `p.rebound_rise > 0` it increments `s.chain` and multiplies the launch speed by `sqrt(1.0 + minf(p.rebound_rise * s.chain, p.rebound_cap if p.rebound_cap > 0.0 else p.rebound_rise))` (`launched = "rebound"`). Otherwise, when `landing and p.bounce_keep > 0.0 and i.jump_held and s.last_vy >= p.bounce_min_impact`, launch at `minf(s.last_vy * p.bounce_keep / sqrt(p.fall_mult), p.jump_velocity * jump_boost)` with `launched = "bounce"`, `jumping = true` and the vertical velocity set (no buffer to clear). Finally, `if landing and s.launched != "rebound": s.chain = 0`. Update the `REBOUND_MIN_AIR` comment and the profile's `rebound_rise` doc to match.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_` and `tools/run_tests.sh verb_runner`. Expected: `PASS` (the envelope and release tests included).
- [ ] **Step 5: Commit**: `git add scripts data tests` (with the `.uid` file) then `git commit -m "feat: the slime's hold bounce and timed rebound chain"`.

### Task 3: Bounce in the sandbox, and the spec

**Files:**
- Modify: `tests/test_movement_sandbox.gd`, `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Write the failing test** in `tests/test_movement_sandbox.gd`: `test_holding_jump_after_a_long_fall_bounces_several_times`: with the slime, set `sb.body.global_position = Vector2(680.0, -300.0)` (above the 100 px ledge), `sb.scripted.jump_held = true`, then for 300 physics frames count the frames where `sb.state.launched == "bounce"`; assert `assert_between(bounces, 3, 6)`.
- [ ] **Step 2: Run** `tools/run_tests.sh movement_sandbox`. Expected: PASS already if Task 2's rule drives the sandbox (the sandbox runs the same step); if it fails, the failure names what differs between `MovementSim` and the real body (landing zeroing the velocity, the `last_vy` timing): fix that, not the test.
- [ ] **Step 3: Update the spec.** In the slime's bullets: *Bounce chain* (hold to bounce: a landing after 0.12 s of air at 250 px/s or more with jump held relaunches each bounce at 85% of the last launch speed, capped at the base jump; a timed press adds +30%, chained up to +60%); *Tackle* (340 px/s for 0.18 s); *Ooze* (the slide bleeds at 150 and ends at 70). Add to "Known gaps": the +60% chain reaches about 1.6 times the base rise (about 100 px), which the G5 chimney guard in `tests/test_grotto_rooms.gd` and the reach model must account for. Correct the Testing line to say a jump press during a burst fires at once and keeps the burst speed (movement is a lock only on the horizontal axis).
- [ ] **Step 4: Run** `tools/run_tests.sh movement_sandbox`, then the whole suite with `TEST_TIMEOUT=900 tools/run_tests.sh`. Expected: `PASS`. Then take screenshots with a throwaway script under `.tmp/` (a slime mid-bounce on the 100 px ledge, a tackle), look at them, and hand the feel to Sean: `godot --path . res://scenes/movement_sandbox.tscn`, hold Space after dropping from the right-hand ledge, and tap Space at the moment of landing to chain.
- [ ] **Step 5: Commit**: `git commit -m "feat: bounce in the sandbox; spec records the new slime numbers"`.
