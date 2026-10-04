# Slick Surfaces for the Spider (plan 4d) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A hard solid can be slick, and the spider cannot grip, crawl, zip to or hang a thread from it; the sandbox gets slick terrain to prove it.

**Architecture:** Slick is data on the world, read through the probes the crawl already uses. The ray probe gains a fourth result (`SLICK`, a hard solid that refuses grip) and the sweep and cast results gain a `slick` flag; `SurfaceStep`, `ZipStep` and `DropStep` refuse slick in the places they would grip. The sandbox marks solids slick with a physics layer. The room editor's slick flag and `room_builder.gd` are a later piece. `player.gd` is untouched.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (Spider: Crawl "all terrain sticky except a slick flag", Web zip "slick surfaces refuse it"). Sean, 2026-10-04: add slippery surfaces to test that the spider cannot use them (the game has no spike hazard tiles, only enemy-spawned hazards, so there is nothing to add for spikes).

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; the whole suite takes about 35 s.
- Slick is a **hard** solid that refuses grip: it still blocks the body, but the spider never attaches to it, never crawls along it, a zip aimed at it fizzles, a zip that touches it ends without gripping, and a thread cannot hang from it. A spider that reaches a slick floor uses the ground step (it walks like the other species).
- The other species and every sticky surface behave exactly as before; the base jump pin is unchanged.
- No attribution lines in commit messages. Do not push.

## Review Focus

1. Walking into a slick wall stops at it (no climb, no corner event), and a slick floor is walked on with the ground step, never gripped (Task 2).
2. Hopping at a slick wall, or up at a slick ceiling, with the stick pressed toward it does not grip (Task 2).
3. A zip aimed at a slick solid fizzles, and one whose path touches slick on the way to a sticky anchor stops there without gripping (Task 3).
4. A thread cannot be spun from a slick ceiling (Task 3).
5. Sticky solids in the same room still work (Tasks 2 to 4).

---

### Task 1: Slick in the probes and the fake world

**Files:**
- Modify: `scripts/movement/surface_step.gd` (the `SLICK` constant), `scripts/movement/move_input.gd` (probe docs), `tests/support/fake_surface_world.gd`
- Test: `tests/test_fake_surface_world.gd`

**Interfaces:**
- Produces: `SurfaceStep.SLICK := 3` (a ray probe's result for a hard solid that refuses grip); the sweep result gains `"slick": bool`, the cast result gains `"slick": bool` (both false for ordinary solids and ledges); `FakeSurfaceWorld.add_slick(r: Rect2)` (a hard rectangle flagged slick), the spike terrain gains `SLICK_BLOCK` (a wall and top at x 1300 to 1360) and `SLICK_CEILING` (a slab over open floor at x 1400 to 1500, underside y -80).

- [ ] **Step 1: Write the failing tests:** `test_a_ray_reports_slick_as_its_own_kind` (a ray into the slick block is `SurfaceStep.SLICK`, into the floor `HARD`); `test_sweep_and_cast_flag_a_slick_solid` (a sweep into the slick block's face returns the hit with `"slick": true`, into the ordinary block `false`; a cast likewise); `test_a_slick_solid_still_blocks_the_body` (the sweep stops at it as at any hard solid).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_fake_surface_world`. Expected: FAIL.
- [ ] **Step 3: Implement** the constant (doc comment on the probe docs), `add_slick`, the flags and the new terrain in the fake world.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: slick in the probes and the fake world`).

### Task 2: The crawl refuses slick

**Files:**
- Modify: `scripts/movement/surface_step.gd`
- Test: `tests/test_surface_step.gd`

- [ ] **Step 1: Write the failing tests:**
  - `test_a_slick_wall_ahead_stops_the_crawl_it_does_not_climb`: crawling right on the floor into `SLICK_BLOCK`: no `"concave"`, the spider stays on its floor surface and stops at the face (x within 1.5 of the face minus 14).
  - `test_it_does_not_grip_a_slick_floor_wall_or_ceiling`: airborne over the slick block's top with `on_floor`: no attach (`step` false); beside its face with `wall_side` and the stick toward it: no attach; under `SLICK_CEILING` with `on_ceiling` and the stick up: no attach; each of the sticky equivalents still attaches (the ordinary block's top, face and the slab's underside).
  - `test_walking_from_a_sticky_floor_onto_a_slick_one_lets_go_of_the_surface`: crawling right across a floor that turns slick: `surface_event == "slick"` and `surface_n` ZERO, `step` false afterwards (the ground step takes over).
  - `test_it_does_not_turn_round_a_corner_onto_a_slick_face`: wrapping over the end of a sticky block whose end face is slick detaches (`"convex_nothing"`) instead of gripping.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_surface_step`. Expected: FAIL.
- [ ] **Step 3: Implement.** `_support` already returns the ray's kind: treat `SLICK` as lost support (not the same as `NONE`: it detaches with event `"slick"`, with the re-attach lock); in the concave branch a sweep hit with `slick` true stops at the contact (`surface_shift = travel`, no corner); `_attach` accepts only a non-slick floor (`kind != NONE and kind != SLICK`) and `HARD` for wall and ceiling (slick is a different kind, so it already refuses); in `_wrap` the end-face check treats `SLICK` like `NONE`.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_surface_step` and `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the crawl refuses slick surfaces`).

### Task 3: The zip and the thread refuse slick

**Files:**
- Modify: `scripts/movement/zip_step.gd`, `scripts/movement/drop_step.gd`
- Test: `tests/test_zip_step.gd`, `tests/test_drop_step.gd`

- [ ] **Step 1: Write the failing tests:** `test_a_zip_aimed_at_a_slick_solid_fizzles` (aim at `SLICK_BLOCK` from the floor: `zip_event == "fizzle"`, no cooldown); `test_a_zip_that_touches_slick_on_its_way_stops_without_gripping` (a zip toward a sticky anchor whose path the box brushes against slick: the pull ends with `"arrive"`, `surface_n` ZERO, airborne; build it with a slick rectangle added in the path beside a sticky wall); `test_a_thread_cannot_hang_from_a_slick_ceiling` (airborne under `SLICK_CEILING`, a down press: `drop_event == "fizzle"`, no air verb used); `test_sticky_anchors_still_work` (the existing zip and drop starts on the ordinary slab).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_zip_step` and `tools/run_tests.sh test_drop_step`. Expected: FAIL.
- [ ] **Step 3: Implement.** `ZipStep._start` fizzles when the cast hit is slick; in `_pull` a blocking sweep with `slick` ends the zip as `"arrive"` at the travel instead of gripping. `DropStep._start` fizzles when the cast hit is slick.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_zip_step`, `tools/run_tests.sh test_drop_step` and `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the zip and the thread refuse slick solids`).

### Task 4: Slick terrain in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_movement_sandbox.gd`

**Interfaces:**
- Produces on `MovementSandbox`: `SLICK_BLOCK := Rect2(300, -90, 60, 90)` and `SLICK_CEILING := Rect2(300, -220, 60, 20)` (light blue, physics layer 3, value 4), probe masks that include layer 3 as a hard solid (hard-only 5, with ledges 7) and report `SurfaceStep.SLICK`, `"slick"` flags on `_sweep` and `_cast` results, and the body's mask becoming 7.

- [ ] **Step 1: Write the failing tests** (real collision, the spider):
  - `test_the_spider_crawling_into_the_slick_block_stops_at_it`: from x 250 on the floor held right: it stops at the face (x within 2 of 300 - 14) and stays on the floor (`surface_n == UP`, y -12).
  - `test_a_zip_at_the_slick_block_fizzles`: aimed right from x 200: `zip_event == "fizzle"` seen and the body does not move.
  - `test_a_hop_at_the_slick_block_does_not_grip_it`: hopping at the face holding toward it never gives `surface_n == LEFT`; it falls back to the floor.
  - `test_the_slick_ceiling_refuses_a_thread`: airborne under it (placed at (330, -150)) a down press fizzles; and a zip straight up from the floor under it at x 330 fizzles (distance beyond the hard anchors).
  - `test_the_sticky_ledge_blocks_next_to_it_still_work`: the ordinary ledge block at x 400 is still climbed with one held direction.
  - `test_the_other_species_treat_slick_as_an_ordinary_wall`: the slime and wolf stop at the slick block like any wall and still jump their heights.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement** a `_slick(r)` builder (a `StaticBody2D` on layer 4, a pale blue rectangle) and the probe changes above (`_ray`: layer 4 maps to `SLICK`; `_sweep` and `_cast` add `"slick"`; masks 5 and 7).
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: slick terrain in the sandbox`).

### Task 5: Specs and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Update the Crawl, Web zip and Silk drop bullets** with "slick (built, plan 4d): a hard solid that refuses grip; the spider never grips, crawls on or hangs a thread from it, and a zip at it fizzles"; update the open items (slick is built in the model and sandbox; the room editor's flag and `room_builder.gd` are a later plan; spikes: the game has no spike tiles). 
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the 2178 baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: spec slick surfaces for the spider`).
