# Spider Silk Drop (plan 4c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The spider's third verb in the sandbox: press down in the air, or hanging from a ceiling, and it spins a thread from the solid above and slides down it, reeling down, climbing up and steering a little, until it lets go or lands.

**Architecture:** A pure `DropStep` (statics over `MoveState` and `MoveInput`, like `ZipStep`) that moves the body by a displacement each tick (`surface_shift`) and reads the world through the sweep and `cast` probes the zip already uses. `VerbRunner` gives it the body while it runs; landing grips the floor through the crawl. The thread and the head-down pose are cosmetic and live in the sandbox. `player.gd` is untouched.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (Spider: Silk drop; Priority: silk drop ends when the thread's body touches the floor) and `docs/research/spider-locomotion.md` (spiders rappel head first, working the thread with a hind leg; climbing back up is slower than going down).

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; the whole suite takes about 35 s. After a new `class_name` script run `godot --headless --import` and commit its `.uid`.
- Spec numbers: a hard solid within 200 px above is needed; down reels at 90 px/s, up climbs at 60 px/s and never above the anchor; air control at half; a jump lets go with the current velocity and no extra impulse; one per airtime (it is the air verb: a zip or a drop in the same airtime is refused until a surface is gripped).
- It starts on a **press** of down (an edge, not a held direction) in the air, and also while hanging from a ceiling (Sean: "I can't drop down yet, like sliding down the web"). From a wall or the floor down is not a drop (down is crawling down a wall).
- A one-way ledge above is not an anchor (hard solids only). Touching the floor ends the drop and grips it.
- The base jump pin and every other species are unchanged (`test_movement_envelope`).
- No attribution lines in commit messages. Do not push.

## Review Focus

1. Holding down while hopping or landing never starts a drop; only a fresh press does (Task 2).
2. Climbing never takes the body above the anchor, and reeling down onto the floor lands and grips it rather than sinking into it (Task 2).
3. A drop with nothing above in range costs nothing (no air verb used) (Task 2).
4. A zip or drop in the same airtime is refused until a surface is gripped, and gripping gives it back (Task 3).
5. Steering into a wall stops the sideways motion without stopping the reel (Task 2).

---

### Task 1: State, numbers and the press edge

**Files:**
- Modify: `scripts/movement/move_state.gd`, `movement_profile.gd`, `verb_runner.gd`, `data/movement/spider.tres`
- Test: `tests/test_movement_profile.gd`, `tests/test_verb_runner.gd`

**Interfaces:**
- Produces on `MoveState`: `down_prev` (the raw down input last tick), `down_pressed` (true on the tick down crossed 0.6 from below), `drop_up` (px from the body's centre up to the anchor while a drop runs, 0.0 when none), `drop_vx` (the sideways speed, px/s), `drop_target` (the anchor as an offset from the body's centre at the start, for the thread), `drop_event` (`""`, `"start"`, `"fizzle"`, `"land"`, `"release"`).
- Produces on `MovementProfile`: `drop_range := 200.0`, `drop_reel := 90.0`, `drop_climb := 60.0`, `drop_air := 0.5`. `spider.tres` verbs become `["crawl", "zip", "drop"]`.
- `VerbRunner.step` sets `down_pressed` and `down_prev` first thing, for every species.

- [ ] **Step 1: Write the failing tests.** `test_movement_profile`: `test_the_spider_drops_with_the_spec_numbers` (verbs have `"drop"`; the four values; the others have no `"drop"`). `test_verb_runner`: `test_down_pressed_is_an_edge` (a state with `down_prev` 0.0 and an input `down` 1.0 gets `down_pressed` true and `down_prev` 1.0; the same input again gives false; releasing and pressing again gives true; 0.5 does not count).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_profile` and `tools/run_tests.sh test_verb_runner`. Expected: FAIL.
- [ ] **Step 3: Implement** the fields (doc comments) and the edge in `VerbRunner.step`.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: drop state, numbers and the down press edge`).

### Task 2: The silk drop

**Files:**
- Create: `scripts/movement/drop_step.gd`
- Test: `tests/test_drop_step.gd` (new)

**Interfaces:**
- Consumes: Task 1; `ZipStep` and `SurfaceStep` conventions; `FakeSurfaceWorld`.
- Produces `DropStep` (`class_name`, `extends RefCounted`): `static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool` (true while a drop runs or ended this tick; false otherwise and with no probes).

- [ ] **Step 1: Write the failing tests** (helpers as in `test_zip_step.gd`; a tick takes a stick `Vector2` for `dir`, `down` and `up`, and `press` marks `down_pressed` as `VerbRunner` would):
  - `test_a_press_of_down_in_the_air_spins_a_thread_from_the_solid_above`: airborne under the slab at (600,-100) (underside 60 px up): `drop_event == "start"`, `drop_up` within 1 of 52 (the centre to the underside), `drop_target` straight up, `air_verb_used`, `surface_n` ZERO, `velocity` ZERO (the fall stops), `step` true.
  - `test_it_needs_a_fresh_press_not_a_held_down`: the same with `down_pressed` false and `down` 1.0 does nothing.
  - `test_nothing_above_within_200_costs_nothing`: airborne at (100,-300): `drop_event == "fizzle"`, `air_verb_used` false, `step` false; a one-way ledge directly above is not an anchor (airborne at (900,-12) under the spike terrain's ledge: still a fizzle).
  - `test_down_reels_at_90_and_up_climbs_at_60`: held down for 30 ticks the body moves 45 px down (sum of `surface_shift.y`) and `drop_up` grows by 45; held up for 30 ticks it moves 30 px up.
  - `test_it_never_climbs_above_the_anchor`: held up long enough, `drop_up` stops at 12 (the box's half height) and the shift is ZERO.
  - `test_air_control_is_half`: stick right for 60 ticks: the sideways speed reaches 70 px/s (half of 140) and no more, the thread's anchor x does not move (`drop_target.x` unchanged).
  - `test_it_lands_on_the_floor_and_grips_it`: reeling down from 80 px above the floor: `drop_event == "land"`, `surface_n == UP`, the centre y within 1.5 of -12, `air_verb_used` false, `drop_up` 0.0.
  - `test_a_jump_lets_go_with_the_current_velocity`: while reeling down at 90 with the stick right at speed 70: a jump press ends it with `velocity == Vector2(70, 90)`, `launched == "drop_release"`, no extra impulse, `air_verb_used` still true; with the stick released and nothing held the velocity is `Vector2.ZERO` (a hanging release then falls under gravity from rest).
  - `test_a_wall_beside_stops_the_sideways_motion_not_the_reel`: beside the block's right face with the stick toward it: no x shift, y shift 1.5 a tick.
  - `test_it_starts_while_hanging_from_a_ceiling_and_not_from_a_wall_or_the_floor`: on the slab's underside (n DOWN) a press starts a drop (`drop_up` about 12, `surface_n` ZERO afterwards); from the block's face (n LEFT) and from the floor (n UP) a press does nothing.
  - `test_one_drop_per_airtime`: after a jump release, a second press is refused (`air_verb_used`) until a surface is gripped.
  - `test_no_probes_and_not_airborne_do_nothing`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_drop_step`. Expected: FAIL.
- [ ] **Step 3: Implement.** Start: `down_pressed`, `zip_dir` ZERO, a zip not running, and (`surface_n == ZERO` and not `air_verb_used`, or `surface_n == DOWN`); `cast(ZERO, Vector2(0, -drop_range), false)` (hard only); no hit or a hit nearer than the box's half height minus 0.5 fizzles; else `drop_up` is the hit's distance, `drop_target` its point, `drop_vx` the current sideways speed clamped to half the top speed, `air_verb_used = true`, `surface_n = ZERO`, `velocity = ZERO`, `drop_event = "start"`, and the same tick goes on to reel. Running each tick: `GroundAirStep.timers`; a live jump buffer lets go (`velocity = Vector2(drop_vx, reel velocity)`, `launched = "drop_release"`, `drop_up = 0.0`, `drop_event = "release"`, buffer and coyote cleared); else reel (`down >= 0.5` is +90, `up >= 0.5` is -60, else 0), the climb clamped so `drop_up` stays at or above 12, the sideways speed moved toward `dir * top_speed * drop_air` at the profile's air acceleration, a sweep of each axis stops a blocked one (a blocked reel downward onto a floor is the landing: `surface_n = UP`, `air_verb_used = false`, `drop_event = "land"`), `surface_shift` is the allowed displacement and `drop_up` grows by its y.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_drop_step`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the silk drop, a thread to slide down`).

### Task 3: The runner

**Files:**
- Modify: `scripts/movement/verb_runner.gd`
- Test: `tests/test_verb_runner.gd`

- [ ] **Step 1: Write the failing tests:** `test_a_drop_owns_the_body_after_the_zip_and_before_the_crawl` (a spider in the air under the slab with a down press: `drop_event == "start"` and `velocity` ZERO; with `zip_dir` set the zip keeps the tick); `test_the_air_verb_is_shared_by_the_zip_and_the_drop` (after a drop starts, a zip press in the same airtime is refused; after a floor grip it works); `test_a_spider_without_the_drop_verb_ignores_down` (verbs emptied); `test_the_other_species_are_untouched`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_verb_runner`. Expected: FAIL.
- [ ] **Step 3: Implement** in `VerbRunner.step`: for a profile with `"drop"`, call `DropStep.step` after the zip and before the crawl and return when it returns true.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_verb_runner` and `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the runner gives the body to a silk drop`).

### Task 4: The drop in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_movement_sandbox.gd`

**Interfaces:**
- Consumes: `DropStep`, `cast`, `sweep`, the thread node from the zip.
- Produces on `MovementSandbox`: the drop's thread (the same `Thread` line, from the anchor to the spider's rear while a drop runs and for 0.15 s after), the head-down pose (rotation a quarter turn so the head points down, mirrored by the sense), and the legs working as it reels (the crawl frames advance by the distance reeled).

- [ ] **Step 1: Write the failing tests** (real collision, the spider):
  - `test_hanging_from_the_slab_and_pressing_down_slides_to_the_floor`: place the spider hanging under the slab (n DOWN, x 830, y -138) and hold down: within 150 frames it is on the floor gripping it (`surface_n == UP`, y within 2 of -12).
  - `test_the_thread_runs_from_the_anchor_to_the_spider`: during the drop the thread is visible with its upper end at the slab's underside (y -150) and its lower end near the spider.
  - `test_up_climbs_back_toward_the_anchor_and_stops_there`: hold down 20 frames then up for 200: it ends 12 px under the underside, never higher.
  - `test_the_head_points_down_while_it_slides`: the sprite's rotation is within 0.3 rad of a quarter turn (either sign) a few frames in.
  - `test_a_jump_lets_go_and_it_falls`: a jump mid-drop leaves it airborne with the thread fading, and it lands on the floor later.
  - `test_the_slime_ignores_down_in_the_air`: the other species are unchanged (no drop event, existing jump pins).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement.** The standard path already applies `surface_shift` while off a surface. Capture `drop_target` into an absolute anchor on the `"start"` event for the thread (`_thread_anchor`, `_thread_dir` up) and keep the thread alpha 1 while `state.drop_up > 0.0`; the thread's lower end is the spider's rear (the centre plus 8 px up). The spider's pose: while `drop_up > 0.0` the target angle is a quarter turn (`PI / 2` for a positive sense, `-PI / 2` mirrored) and the frame is a crawl frame advanced by the distance reeled.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the spider slides down its thread in the sandbox`).

### Task 5: Specs and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Update the Silk drop bullet** to what was built (a press, in the air or hanging from a ceiling; hard solids only; the reel, climb and air control numbers; jump lets go; the air verb shared with the zip; landing grips the floor) and Art needs (a head-down hind-leg-on-thread pose). Record open items: the thread does not break when the anchor's solid ends under it sideways, a pendulum swing is not modelled (the body hangs and steers), the pointer is not involved, and the priority table.
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the 2135 baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: spec the spider's silk drop as built`).
