# Spider Web Zip (plan 4b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The spider's signature verb in the sandbox: aim, fire a thread at the first solid within 160 px, be pulled to it at 400 px/s, and grip the surface it arrives at.

**Architecture:** A pure `ZipStep` (statics over `MoveState` and `MoveInput`, like `SurfaceStep`) that reads the world through the sweep probe the crawl already uses and one new `cast` probe (a ray that reports where and what it hit). It moves the body by a displacement each tick (`surface_shift`, the channel the crawl uses) and hands it to `SurfaceStep` by attaching on arrival. `VerbRunner` gives it the body while a zip runs. The thread and the head-first pose are cosmetic and live in the sandbox. `player.gd` is untouched.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (Spider: Web zip; Structure: probes) and `docs/research/spider-locomotion.md` (feel rules: spiders never leap without a dragline; the thread is the point).

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; the whole suite takes about 35 s. After a new `class_name` script run `godot --headless --import` and commit its `.uid`.
- Spec numbers: range 160 px, pull 400 px/s, a jump cancels and keeps 60% of the zip speed, cooldown 0.4 s from the end of the zip, no cost when nothing is in range, one air verb per airtime, anchors are terrain only (hard solids; a one-way ledge's top counts only when the aim goes downward).
- Aim is the player's cast aim (a free pointer direction, else the left stick 8-way, else facing): the caller resolves it into `MoveInput.aim` (ZERO for none); with none the zip goes along the facing.
- No windup: the thread fires on the press (a delay would cost the responsiveness the species is built on); the readable tell is the look.
- The base jump pin and every other species are unchanged (`test_movement_envelope`).
- No attribution lines in commit messages. Do not push.

## Review Focus

1. A diagonal zip into a corner or along a wall stops at the first contact and grips the surface it hit, and never ends inside a solid (Task 2).
2. A zip that finds nothing in range costs nothing: no cooldown, no air verb used (Task 2).
3. A jump press on the zip's first tick, and a zip fired from a ceiling or a wall, both behave (Task 2).
4. One air verb per airtime: a second zip in the same airtime is refused until it grips a surface (Task 3).
5. The sandbox moves the body by the zip's displacement even though the spider is not on a surface (Task 4).

---

### Task 1: Probes, state and numbers

**Files:**
- Modify: `scripts/movement/move_input.gd`, `move_state.gd`, `movement_profile.gd`, `data/movement/spider.tres`, `tests/support/fake_surface_world.gd`
- Test: `tests/test_movement_profile.gd`, `tests/test_fake_surface_world.gd`

**Interfaces:**
- Produces on `MoveInput`: `aim: Vector2` (the resolved cast aim, ZERO for none; not necessarily normalised, a stick may be partial) and `cast: Callable` (`(from: Vector2, to: Vector2, include_oneway: bool) -> Dictionary`: `{}` when nothing is hit, else `{"point": Vector2, "normal": Vector2, "oneway": bool}`, offsets from the body's centre, the first hard solid along the segment, a one-way ledge's top included only when `include_oneway` and the segment goes down); `copy()` carries both.
- Produces on `MoveState`: `zip_dir` (the unit direction while a zip runs, else ZERO), `zip_left` (px of thread left to pull), `zip_cooldown` (s), `zip_target` (the anchor, offset from the body's centre at the start, for the caller's thread), `zip_event` (`""`, `"start"`, `"fizzle"`, `"grip"`, `"arrive"`, `"cancel"`).
- Produces on `MovementProfile`: `zip_range := 160.0`, `zip_speed := 400.0`, `zip_keep := 0.6`, `zip_cooldown := 0.4`. `spider.tres` verbs become `["crawl", "zip"]`.
- Produces on `FakeSurfaceWorld`: `input()` also binds `cast` (the nearest rect hit along the segment, with the face normal; a one-way rect only when `include_oneway` and the segment goes down).

- [ ] **Step 1: Write the failing tests.** `test_movement_profile`: `test_the_spider_zips_with_the_spec_numbers` (verbs have `"zip"` and `"crawl"`; the four values above; the other species have no `"zip"`); `test_copy_keeps_aim_and_cast`. `test_fake_surface_world`: `test_cast_reports_the_first_hard_solid_with_its_normal` (a cast right from (180,-60) over 100 px hits the block's left face: point x 20 (offset), normal LEFT); `test_cast_ignores_a_ledge_unless_asked_and_going_down` (a cast straight down onto the one-way ledge top is `{}` without `include_oneway` and hits with it; a cast sideways never hits it); `test_cast_is_empty_in_open_air`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_profile` and `tools/run_tests.sh test_fake_surface_world`. Expected: FAIL.
- [ ] **Step 3: Implement** the fields (doc comments) and the fake world's `cast` (reuse the segment-against-rectangle test, returning the entry t and face).
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: aim and cast probes, zip state and numbers`).

### Task 2: The zip

**Files:**
- Create: `scripts/movement/zip_step.gd`
- Test: `tests/test_zip_step.gd` (new)

**Interfaces:**
- Consumes: Task 1; `SurfaceStep`'s `HT`, `HN` and `tangent`; `FakeSurfaceWorld`.
- Produces `ZipStep` (`class_name`, `extends RefCounted`): `static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool` (true while a zip runs or ended this tick; false otherwise or with no probes) and `static func direction(aim: Vector2, facing: int) -> Vector2` (the unit direction: a free aim as it is, a partial stick snapped to 8 ways, ZERO aim to `Vector2(facing, 0)`).

- [ ] **Step 1: Write the failing tests** (helpers as in `test_surface_step.gd`: a world, a state, a tick that sets `signature_pressed`, `aim`, `jump_pressed` and applies `surface_shift`):
  - `test_the_direction_is_the_aim_8_way_or_the_facing`: `direction(Vector2(1, 0.1), 1) == Vector2.RIGHT`; `Vector2(0.7, -0.7)` is `Vector2(0.7071, -0.7071)` within 0.001; ZERO with facing -1 is `Vector2.LEFT`; a free aim `Vector2(0.9, -0.3).normalized()` is returned unchanged.
  - `test_the_thread_pulls_at_400_to_the_first_solid_and_grips_it`: on the floor at (120,-12), aim right: the first tick has `zip_event == "start"` and `zip_target` toward the block's left face; every following tick moves 400/60 px until the box touches the face: `zip_event == "grip"`, `surface_n == LEFT`, centre x within 1.5 of 188, and `zip_dir == ZERO`.
  - `test_nothing_in_range_costs_nothing`: aim left from (1200,-12) with the nearest solid beyond 160: `zip_event == "fizzle"`, `zip_cooldown == 0.0`, `air_verb_used` false, `step` false.
  - `test_the_range_is_160_px`: a block 150 px away is zipped to, one 170 px away fizzles.
  - `test_a_zip_up_grips_the_ceiling_and_a_diagonal_one_stops_at_the_first_contact`: from the floor under the slab (600,-12) aim up: `surface_n == DOWN` at the underside; a diagonal aim (1,-1) from (400,-12) toward the pillar's left face grips `LEFT` and never overlaps (the fake world's sweep from the end position is clear).
  - `test_a_jump_cancels_and_keeps_60_percent`: press jump 5 ticks in: `zip_dir == ZERO`, `velocity` is the direction times 240, `launched == "zip_cancel"`, `zip_cooldown == 0.4`; a press on the first tick behaves the same with no displacement.
  - `test_the_cooldown_runs_from_the_end_and_blocks_a_new_zip`: after a grip, a press at once is refused, 0.4 s later it zips.
  - `test_a_zip_from_a_wall_and_a_ceiling_works`: from the block's left face (n LEFT) aim up-left to open air finds nothing in range and fizzles; from the slab's underside (n DOWN) aim down to the floor 150 px below zips and grips `UP`.
  - `test_too_close_is_not_a_zip`: a solid within 14 px of the centre in the aim direction fizzles.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_zip_step`. Expected: FAIL.
- [ ] **Step 3: Implement.** Start (a press, `zip_cooldown` 0, not an airborne zip with `air_verb_used`): `cast(ZERO, dir * range, dir.y > 0)`; no hit or a hit nearer than 14 px is a fizzle that changes nothing else; a hit sets `zip_dir`, `zip_left` to the hit's distance, `zip_target`, detaches the surface (`surface_n = ZERO`), marks `air_verb_used` when airborne (`surface_n` was ZERO and not on the floor), `zip_event = "start"`. Running: a jump press (or buffer) cancels as above; else `move = min(zip_speed * dt, zip_left)` along `zip_dir`; `sweep(motion)` blocking ends it at the contact: `surface_shift = travel`, `surface_n` the axis-snapped sweep normal (a wall, floor or ceiling), `surface_since = 99.0`, `surface_latch = ZERO`, `zip_event = "grip"`, `zip_cooldown = zip_cooldown`; thread out (`zip_left` spent) without contact: `"arrive"`, airborne with zero velocity. Every end sets `zip_dir = ZERO`.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_zip_step`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the web zip, a thread pulling the spider to the first solid`).

### Task 3: The runner

**Files:**
- Modify: `scripts/movement/verb_runner.gd`
- Test: `tests/test_verb_runner.gd`

- [ ] **Step 1: Write the failing tests:** `test_a_zip_owns_the_body_before_the_crawl_and_the_ground_step` (a spider on the floor with the press: after the step `surface_shift` is nonzero, `surface_n` is ZERO, `velocity` is ZERO); `test_one_air_zip_per_airtime` (a spider in the air zips once, a second press after `arrive` is refused until `surface_n` is set again; gripping a surface resets it); `test_a_spider_without_the_zip_verb_ignores_the_button` (the spider profile with `verbs` emptied: `signature_pressed` does nothing); `test_the_other_species_are_untouched` (the existing Tackle tests stay green).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_verb_runner`. Expected: FAIL.
- [ ] **Step 3: Implement** in `VerbRunner.step`: for a profile with `"zip"`, call `ZipStep.step` first and return when it returns true; `air_verb_used` clears when `s.surface_n` is not ZERO.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_verb_runner` and `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the runner gives the body to a zip`).

### Task 4: The zip in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_movement_sandbox.gd`

**Interfaces:**
- Consumes: `ZipStep`, `MoveInput.aim`, `cast`.
- Produces on `MovementSandbox`: `_cast` (a physics ray from the body's centre returning `point`, `normal`, `oneway` as Task 1 says), the aim read from the stick or keys (snapped to 8 ways at 0.3 or more, else ZERO; `scripted.aim` in tests), a thread line from the spider's rear to the anchor shown while a zip runs and for 0.15 s after, and the head-first pose.

- [ ] **Step 1: Write the failing tests** (real collision, the spider key):
  - `test_a_zip_pulls_the_spider_to_a_wall_and_it_grips`: from the floor at x 560 aiming left at the 60 px ledge block's right face (x 600... choose the nearest solid within 160 px of a placed position) the body moves at about 400 px/s, ends touching the face, and `state.surface_n` is the face's normal.
  - `test_a_zip_to_the_ceiling_grips_the_underside`: from the floor under the slab at x 800, aim up: it ends hanging (`surface_n == DOWN`, y within 1.5 of -138).
  - `test_nothing_in_range_leaves_the_spider_where_it_is`: aim left from open floor with nothing within 160 px: the body does not move and `zip_event` was `"fizzle"`.
  - `test_a_jump_cancels_the_zip_in_the_air_with_60_percent_speed`: mid-zip a press leaves the spider airborne with `velocity` about 240 px/s along the aim.
  - `test_the_thread_shows_while_it_zips_and_fades`: the thread line is visible during the zip and hidden 0.3 s after it ends.
  - `test_the_head_leads_the_zip`: during a zip up-right the sprite's rotation is within 0.3 rad of the zip direction's angle (mirrored when it goes left).
  - `test_the_other_species_ignore_the_button`: the slime's Tackle still starts on the same press.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement.** `_cast` mirrors `_ray` (`intersect_ray`, hard-only mask 1 or 3 for a downward cast), returning the hit relative to the body; fill `i.cast` and `i.aim` for crawlers. Apply `state.surface_shift` to the body every tick for a crawler (a zip moves it while it is off every surface), then the existing crawl or normal path. While `state.zip_dir` is set or its cooldown just started, draw a `Line2D` from a point behind the spider (opposite the zip direction, 10 px) to the anchor (`body.global_position + state.zip_target` captured on the `"start"` event), fade it over 0.15 s after the end; the sprite shows the `drop` frame rotated head-first (rotation the zip direction's angle, mirrored with `flip_h` when going left).
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the spider zips in the sandbox, thread and all`).

### Task 5: Specs and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Update the Web zip bullet** to what was built (no windup; the displacement model and why a sweep stops it; grips the surface it hits; a jump cancel; the cooldown and the air verb) and Art needs (a thread frame or line style, a head-first zip pose). Record open items: the pointer aim (the cast aim's free direction) is the wiring plan's, slick refusal is not built, and zipping onto a moving platform is not covered.
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the 2106 baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: spec the spider's web zip as built`).
