# Drop Through One-Way Ledges (plan 5a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every species can press down while standing on a one-way ledge to drop through it, in the shared model and the sandbox.

**Architecture:** The model decides, the caller collides. `VerbRunner` turns a fresh press of down on a one-way floor into a short `fall_through` timer on `MoveState`; the caller ignores one-way collision while it runs (the sandbox clears the one-way bit of the body's mask, the player will do the same). The spider, which is not on the ground step while it crawls, detaches from the ledge. `player.gd` is untouched.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (Structure: probes; Known gaps: 133 of 172 room solids are one-way). Sean, 2026-10-04: "all species should probably be able to press down on a one way ledge to drop down".

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; the whole suite takes about 35 s.
- The trigger is a **press** of down (the edge `VerbRunner` already computes as `down_pressed`), only while standing on a one-way ledge; a hard floor and the air are unchanged. Down held from before landing does not drop.
- `fall_through` is 0.2 s: long enough for the body to clear a 6 px ledge's margin, short enough to land on the next floor.
- The slime's Ooze (down on a floor flattens) and the puddle slide (down while running) do not start on the press that drops through.
- The base jump pin and every other behaviour are unchanged (`test_movement_envelope`).
- No attribution lines in commit messages. Do not push.

## Review Focus

1. A held down never drops: landing on a one-way ledge with down already held does nothing until it is released and pressed (Task 1).
2. The slime does not spread or start a puddle slide on the dropping press, and still does both on a hard floor (Task 1).
3. The spider on a ledge drops through and does not grip the ledge it just left (Task 2).
4. All four species fall through the sandbox ledge to the floor on real collision, and nobody falls through a hard floor (Task 3).

---

### Task 1: The shared model

**Files:**
- Modify: `scripts/movement/move_input.gd`, `move_state.gd`, `movement_profile.gd`, `verb_runner.gd`
- Test: `tests/test_verb_runner.gd`, `tests/test_movement_profile.gd`

**Interfaces:**
- Produces: `MoveInput.on_oneway_floor: bool` (the body stands on a one-way ledge; the caller probes it); `MoveState.fall_through: float` (seconds left in which the caller ignores one-way ledges); `MovementProfile.fall_through := 0.2` (all species).

- [ ] **Step 1: Write the failing tests.** `test_movement_profile`: `test_every_species_falls_through_for_a_fifth_of_a_second` (all four ids have `fall_through == 0.2`). `test_verb_runner` (each of biped, slime, wolf, spider): `test_a_press_of_down_on_a_one_way_ledge_starts_a_fall_through` (`on_floor` and `on_oneway_floor` true, `down` 1.0 on a fresh press: `fall_through == 0.2`; it runs down by one tick each step and is zero after 12 ticks); `test_a_held_down_does_not_drop` (the same input for two ticks: the second does not restart it after it has run out; and landing with down already held, `down_prev` 1.0, never starts one); `test_a_hard_floor_and_the_air_do_not_drop` (`on_oneway_floor` false, or `on_floor` false: stays 0.0); `test_the_slime_does_not_spread_or_slide_on_the_dropping_press` (a slime on a one-way ledge pressing down: `spread` stays false and, running at 120 px/s, `verb` is not `"puddle"`; on a hard floor the same input spreads and starts the puddle slide as before).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_profile` and `tools/run_tests.sh test_verb_runner`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `VerbRunner.step`, after the press edge: `on_oneway := i.on_oneway_floor or (s.surface_n == Vector2.UP and s.surface_oneway)`; if `s.down_pressed and on_oneway` set `s.fall_through = p.fall_through`, else decrement-clamp it. While `s.fall_through > 0.0`, `_ooze` does not flatten and a burst whose row needs the floor and the down input (the puddle) does not begin.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement` and `tools/run_tests.sh test_verb_runner`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: a press of down on a one-way ledge starts a fall-through`).

### Task 2: The spider lets go of the ledge

**Files:**
- Modify: `scripts/movement/surface_step.gd`
- Test: `tests/test_surface_step.gd`

- [ ] **Step 1: Write the failing tests:** `test_the_spider_on_a_one_way_ledge_drops_through_it` (on the ledge top with `surface_oneway` true and `fall_through` set: after the step `surface_n` is ZERO and `surface_event == "drop_through"`; on a hard floor with `fall_through` set (it cannot be set there, but if it were) nothing happens); `test_it_does_not_grip_the_ledge_it_is_falling_through` (airborne over the ledge with the floor probe seeing it and `fall_through` live: no attach; after it runs out, an attach is possible again).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_surface_step`. Expected: FAIL.
- [ ] **Step 3: Implement** in `SurfaceStep.step`: while attached to a floor that is a one-way ledge, `fall_through > 0.0` detaches (`surface_n = ZERO`, `surface_lock` for the fall-through time, event `"drop_through"`); `_attach` refuses to grip a floor while `fall_through > 0.0`.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_surface_step` and `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: a crawling spider drops through a one-way ledge`).

### Task 3: The sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_movement_sandbox.gd`

- [ ] **Step 1: Write the failing tests** (real collision; the sandbox's one-way ledge at x 160 to 260, top y -50, so a body standing on it has its centre at y -62):
  - `test_every_species_drops_through_a_one_way_ledge_with_down` (biped, slime, wolf, spider in turn: placed on the ledge and settled, `scripted.down = 1.0`: within 60 frames the body is on the floor, y within 2 of -12, having passed through the ledge; for the spider also `surface_n == UP` again).
  - `test_nobody_falls_through_a_hard_floor` (each species on the floor pressing down for 30 frames stays at y -12; the slime also spreads as before).
  - `test_down_already_held_does_not_drop_on_landing` (a body dropped onto the ledge with `scripted.down` already 1.0 stays on it until down is released and pressed again).
  - `test_a_jump_through_the_ledge_from_below_still_works` (a body below the ledge jumping up passes through it and lands on top).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement.** `i.on_oneway_floor = body.is_on_floor()` and a downward `_ray` from the centre to the feet plus 3 px reporting `SurfaceStep.ONEWAY`; before the body moves each tick, `body.set_collision_mask_value(2, state.fall_through <= 0.0)` (layer 2 is the one-way ledges).
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: every species drops through a one-way ledge in the sandbox`).

### Task 4: Spec and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Add a shared-rules bullet:** "Down on a one-way ledge drops through it (all species), a fresh press only, 0.2 s of ignoring one-way ledges; the wiring plan sets the body's one-way collision off for that time." Record the open item: the player's room collision (`room_builder.gd`, one-way with a 6 px margin) needs the same mask toggle when the runner is wired in.
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the 2166 baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: spec dropping through one-way ledges`).
