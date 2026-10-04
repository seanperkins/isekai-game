# Spider Surface Crawl (plan 4a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The spider crawls floors, walls and ceilings and rounds corners in the sandbox, on the model the crawl spike validated, with a look that follows how spiders move.

**Architecture:** A pure `SurfaceStep` (statics over `MoveState` and `MoveInput`, like `GroundAirStep`) that reads the world only through two probe `Callable`s on `MoveInput` (a forward sweep and a ray), so it is tested on a small fake world of rectangles and then on real collision in the sandbox. `VerbRunner` hands the body to it while the spider is on a surface and back to `GroundAirStep` in the air. The spider's look is cosmetic and lives in `SpeciesLook` and the sandbox. `player.gd` is untouched.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (Spider, Structure), `docs/research/spider-crawl-spike.md` (the model, results, decisions) and `docs/research/spider-locomotion.md` (the feel rules). The spike code is on branch `archive/spider-crawl-spike` (`spikes/spider_crawl/crawler.gd`); read it, do not copy it blindly.

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests` and the full suite takes about 35 s. After a new `class_name` script run `godot --headless --import` and commit its `.uid`.
- The base jump is pinned for all four species (`test_movement_envelope`, measured with `MovementSim`, which has no probes): a spider without probes uses the ground step, so those pins must not move.
- The body never rotates; only its box swaps from 28x24 (`BodyConfig.size()`) to 24x28 on a wall. Surfaces are axis-aligned.
- Spider numbers: speed 140 on every surface, start 0.03 s and stop 0.02 s along it, corner lockout 0.10 s, back-round-a-corner window 0.6 s, a hop goes along the surface normal at `jump_velocity` (330) and locks steering `wall_lock` (0.15 s) off a wall or ceiling.
- A one-way ledge is a floor on its top only: its end drops the spider, and its side and underside are never probed or attached to.
- No attribution lines in commit messages. Do not push.

## Review Focus

1. One held direction rounds every corner of a block and of a pillar under a slab, both ways, and a one-tick stick dropout never strands the spider on a wall (Tasks 3 and 4).
2. A stick wiggled at a corner every 4 frames cannot round it more than once per 0.10 s (Task 4).
3. A one-way ledge's end drops the spider and is never wrapped; landing needs the body's centre over the ledge, or the box's rim catches the end and loops attach and fall (Task 5).
4. A hop off a wall or ceiling goes out along the normal and does not re-attach the same instant (Task 5).
5. The spider with no probes, and every other species, behave exactly as before (Tasks 1, 6 and 7).

---

### Task 1: Probes, state and profile fields

**Files:**
- Modify: `scripts/movement/move_input.gd`, `move_state.gd`, `movement_profile.gd`, `ground_air_step.gd` (rename `_timers` to the public `timers`), `data/movement/spider.tres`
- Test: `tests/test_movement_profile.gd`

**Interfaces:**
- Produces on `MoveInput`: `up: float` (raw up, 0 to 1), `on_ceiling: bool`, `sweep: Callable` (`(motion: Vector2) -> Dictionary`: `{}` when free, else `{"travel": Vector2, "normal": Vector2}`; hard solids only; swept from the body's centre with its current box), `ray: Callable` (`(from: Vector2, to: Vector2, hard_only: bool) -> int`: 0 nothing, 1 hard, 2 one-way; offsets from the body's centre), `stick() -> Vector2` (`Vector2(dir, down - up)`); `copy()` carries all of them.
- Produces on `MoveState`: `surface_n` (`Vector2.ZERO` when not on a surface, else the surface's outward normal), `surface_sigma` (1.0 or -1.0, the sense along the clockwise tangent), `surface_latch` (the direction held at the last corner, or ZERO), `surface_prev` (the way it was moving before that corner), `surface_since` (s since the last corner, starts 99.0), `surface_lock` (s of corner lockout left), `surface_oneway` (the surface under it is a one-way ledge), `surface_shift` (the displacement the caller applies this tick) and `surface_event` (`""`, `"concave"`, `"convex"`, `"ledge_fall"`, `"hop"`, `"attach"`).
- Produces on `MovementProfile`: `corner_lock := 0.10`, `crawl_back_window := 0.6`. `spider.tres` gets `verbs = PackedStringArray("crawl")`.

- [ ] **Step 1: Write the failing tests** in `tests/test_movement_profile.gd`: `test_the_spider_crawls_and_the_others_do_not` (spider `verbs.has("crawl")`, `corner_lock == 0.10`, `crawl_back_window == 0.6`; biped, slime, wolf have no `"crawl"`); `test_stick_is_dir_and_down_minus_up` (`dir 1, down 0.0, up 1.0` gives `Vector2(1, -1)`); `test_copy_keeps_the_probes_and_up` (a `copy()` has the same `sweep` and `ray` callables, `up` and `on_ceiling`).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_profile`. Expected: FAIL.
- [ ] **Step 3: Implement** the fields with doc comments; rename `GroundAirStep._timers` to `timers` and update its one caller.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: probes, surface state and spider crawl fields`).

### Task 2: A fake world of rectangles

**Files:**
- Create: `tests/support/fake_surface_world.gd`
- Test: `tests/test_fake_surface_world.gd`

**Interfaces:**
- Produces `FakeSurfaceWorld` (`extends RefCounted`): `add_hard(r: Rect2)`, `add_oneway(r: Rect2)`, `pos: Vector2` (the body's centre), `n: Vector2` (the surface normal the box is shaped for; the box is 28x24 on UP and DOWN, 24x28 on LEFT and RIGHT), `input() -> MoveInput` (a fresh input with `sweep` and `ray` bound to this world), `apply(s: MoveState)` (moves `pos` by `s.surface_shift`, sets `n` from `s.surface_n`), and `Rect2` constants for the spike's terrain: `FLOOR` (-200,0,1800,40), `BLOCK` (200,-100,100,100), `PILLAR` (450,-160,40,160), `SLAB` (450,-200,300,40), `LEDGE` one-way (850,-50,120,6), `SEAM_A` (1100,-60,50,60), `SEAM_B` (1150,-60,50,60). `build_spike_terrain()` adds them.

- [ ] **Step 1: Write the failing tests:** `test_sweep_stops_at_a_wall_and_reports_its_normal` (a body at (180,-12) on UP sweeping (10,0) against the block: travel x 6 within 0.01, normal `Vector2.LEFT`); `test_sweep_is_free_in_open_space_and_ignores_a_ledge_sideways`; `test_ray_reports_hard_and_oneway_and_respects_hard_only` (a ray down onto the ledge top is 2, with `hard_only` 0; onto the floor 1); `test_the_box_swaps_on_a_wall` (a sweep against a wall uses 24 wide when `n` is LEFT or RIGHT).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_fake_surface_world`. Expected: FAIL.
- [ ] **Step 3: Implement** the sweep as an axis-aligned box against each hard rect (the smallest travel; the normal is the rect face hit; ignore a rect the box already overlaps by under 0.01) and the ray as a segment against each rect's expanded edges, filtered by hardness.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_fake_surface_world`. Expected: PASS.
- [ ] **Step 5: Commit** (`test: a fake world of rectangles for the surface step`).

### Task 3: Moving along a surface and the concave corner

**Files:**
- Create: `scripts/movement/surface_step.gd`
- Test: `tests/test_surface_step.gd` (new)

**Interfaces:**
- Consumes: Task 1's fields; Task 2's `FakeSurfaceWorld`.
- Produces `SurfaceStep` (`class_name`, `extends RefCounted`): consts `HT := 14.0`, `HN := 12.0`, `STICK := 3.0`, `NONE := 0`, `HARD := 1`, `ONEWAY := 2`; `static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, jump_boost := 1.0) -> bool` (true while it owns the body this tick; false with no probes or in the air); `static func box_size(n: Vector2) -> Vector2`; `static func tangent(n: Vector2) -> Vector2` (the exact axis `n` turned 90 degrees clockwise).

- [ ] **Step 1: Write the failing tests.** Helper `_drive(world, s, p, stick, ticks)` runs `SurfaceStep.step` then `world.apply(s)` each tick at 1/60 s. On the spike terrain:
  - `test_the_box_matches_the_body_config`: `box_size(UP) == BodyConfig.size()`, `box_size(LEFT)` is its transpose.
  - `test_a_held_direction_crawls_at_140_and_stops_at_once`: `Vector2.RIGHT` for 30 ticks on the floor moves 70 px within 1 (140 times 0.5 s), then `Vector2.ZERO` moves 0.
  - `test_screen_relative_on_a_ceiling_and_a_wall`: on the slab's underside (n DOWN) the stick right moves right; on the block's left face (n LEFT) the stick up moves up and the stick right does nothing.
  - `test_a_wall_ahead_turns_the_crawl_up_it`: floor, stick right from x 120 into the block: `surface_event == "concave"` once, `surface_n == LEFT`, centre x within 1 of 188; it then climbs with the stick still right (the latch).
  - `test_the_latch_survives_a_release_and_a_different_direction_drops_it`: on that wall, a 3-tick zero stick then right again climbs on; the stick down then reverses it (screen-relative); the stick right after that does nothing.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_surface_step`. Expected: FAIL.
- [ ] **Step 3: Implement** from the spike's `_intent`, `_surface`, `_concave` and `_note`, rewritten in relative offsets: the sweep `motion = tangent * sigma * 140 * dt` blocked by a wall whose normal is perpendicular to `n` and opposes the motion is a concave corner (`surface_shift = travel + (n + motion_dir) * (HT - HN)`, new `surface_n` the wall normal, latch and `surface_prev` set, `surface_lock = p.corner_lock`); else `surface_shift = motion`. Normals and tangents are snapped to exact axes. The stick is `i.stick()`; intent as in the spike (`DEAD 0.2`, `LATCH_DOT 0.7`).
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_surface_step`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the surface step crawls a surface and turns up a wall`).

### Task 4: The convex corner, lockout and turning back

**Files:**
- Modify: `scripts/movement/surface_step.gd`
- Test: `tests/test_surface_step.gd`

- [ ] **Step 1: Write the failing tests** (spike terrain, `corner_lock` 0.10 unless said):
  - `test_one_held_direction_rounds_the_block_both_ways`: stick right from (120,-12) on UP until back on the floor at x > 330: events `concave, convex, convex, concave` and final `surface_n == UP`; the mirror with stick left from (420,-12) ends at x < 170.
  - `test_one_held_direction_rounds_the_pillar_and_slab`: stick right from (400,-12) completes in 6 events (concave, convex, convex, convex, concave, concave) and ends on the floor at x > 520 having visited all four normals; stick left from (540,-12) mirrors it in 6.
  - `test_noisy_input_still_gets_round`: the same with a seeded `RandomNumberGenerator` (seed 7): 5% zero sticks, 10% diagonals `(1, ±0.5)`, completes within 1000 ticks.
  - `test_pressing_back_just_after_a_corner_goes_back_round_it`: climb the block's left face, press right-then-up round the top corner, and one beat later press down: it rounds back and ends on the floor left of the block.
  - `test_a_corner_does_not_repeat_inside_the_lockout`: from (206,-112) on UP, a stick alternating left and right every 4 ticks for 240 ticks gives at most 1 round of the corner with `corner_lock` 0.10 and many (more than 20) with 0.06.
  - `test_a_convex_corner_moves_the_centre_about_19_px_and_a_concave_one_under_5`: read from `surface_shift` lengths on the events, within 1.5 px of 19.5 and under 5.
  - `test_it_crosses_a_tile_seam_without_an_event`: from (1040,-12) stick right over `SEAM_A` and `SEAM_B`: 4 events in all (a concave, two convex, a concave), none at the seam.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_surface_step`. Expected: FAIL on the new tests.
- [ ] **Step 3: Implement** the convex wrap from the spike's `_convex`: after the motion, `ray(motion, motion - n * (HN + STICK), hard_only)` finding nothing means the centre passed the end; bisect the edge along the motion (8 steps), turn the box rigidly about the corner (centre `edge + HN` out along the motion, 2 px below the surface level along `n`), set `surface_n` to the motion direction, re-probe the end face (no surface there: detach and report `"convex_nothing"`), and while `surface_lock > 0` neither corner kind starts (the body stays where it was). Add the back rule (`crawl_back_window`) to the intent.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_surface_step`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the surface step rounds convex corners, with a lockout and a way back`).

### Task 5: Ledge ends, hop and attach

**Files:**
- Modify: `scripts/movement/surface_step.gd`
- Test: `tests/test_surface_step.gd`

- [ ] **Step 1: Write the failing tests:**
  - `test_a_one_way_ledge_end_drops_the_spider`: on the ledge top (n UP, `surface_oneway` true) with stick right: at the end `surface_event == "ledge_fall"`, `surface_n == ZERO`, `step` returns false, `velocity.x` is half of 140 in the stick's direction; it never reports `"convex"` on a one-way ledge.
  - `test_a_hard_ledge_end_wraps_where_a_one_way_one_falls`: the same walk off the end of `SEAM_B`'s top edge wraps (`"convex"`).
  - `test_a_hop_goes_along_the_normal_at_the_base_jump_speed`: from the floor `velocity == Vector2(0, -330)`, `launched == "hop"`; from the block's left face (n LEFT) `velocity == Vector2(-330, 0)` and `lock == p.wall_lock`; from the slab's underside `velocity == Vector2(0, 330)`; `surface_n` ZERO and `step` returns true on the hop tick. `jump_boost 1.5` scales it.
  - `test_a_buffered_press_hops_on_attaching`: a press 3 ticks before landing hops on the attach tick.
  - `test_it_lands_on_a_floor_and_attaches_only_if_the_centre_is_over_it`: in the air with `on_floor` true and the centre over the floor, `step` attaches (`"attach"`, `surface_n == UP`); with the centre 10 px past a one-way ledge's end it does not attach and stays airborne.
  - `test_it_attaches_to_a_wall_or_ceiling_only_when_pressing_toward_it`: `wall_side -1` with the stick left attaches with `surface_n == RIGHT`, with no stick it does not; `on_ceiling` with the stick up attaches with `surface_n == DOWN`; never to a one-way solid; never within `surface_lock` of a hop.
  - `test_no_probes_means_not_a_crawler`: an input without callables returns false and sets nothing.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_surface_step`. Expected: FAIL on the new tests.
- [ ] **Step 3: Implement.** Ledge end: when the ray under the centre finds `ONEWAY` (cache `surface_oneway` each tick while the ray hits), losing it detaches with `velocity = motion_dir * 70`. Hop: `GroundAirStep.timers` first; a live buffer or a press while attached sets `velocity = n * p.jump_velocity * jump_boost`, `launched = "hop"`, `jumping = (n == UP)`, `lock = p.wall_lock` unless `n == UP`, `surface_lock = 0.1`, detaches, clears the buffer, and returns true. Attach (not on a surface, no probes needed beyond `ray`): floor needs `i.on_floor` and a `ray(ZERO, Vector2(0, HN + STICK), false)` hit; wall needs `i.wall_side != 0`, `stick.x * wall_side > 0.5` and a hard `ray` toward it; ceiling needs `i.on_ceiling`, `stick.y < -0.5` and a hard `ray` up; none while `surface_lock > 0`.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_surface_step`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: ledge ends, hops and attaching for the surface step`).

### Task 6: The runner hands the body over

**Files:**
- Modify: `scripts/movement/verb_runner.gd`
- Test: `tests/test_verb_runner.gd`

- [ ] **Step 1: Write the failing tests:**
  - `test_a_crawler_on_a_surface_skips_the_ground_step`: with the fake world and the spider profile on the floor (`surface_n UP`), stick right: `velocity` stays `Vector2.ZERO` (the caller moves it by `surface_shift`), and `surface_shift.x` is about 2.33.
  - `test_a_crawler_in_the_air_runs_the_ground_step`: after a hop, ticks with no probes' help see gravity pull (`velocity.y` rising by 15 a tick) and air control (stick right gives `velocity.x > 0`) from `GroundAirStep`.
  - `test_the_air_tackle_rule_and_every_other_species_are_untouched`: the slime and biped runs of existing tests pass unchanged; a spider with no probes (a `MoveInput` without callables) behaves exactly as the ground step (`launched == "ground"` on a press).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_verb_runner`. Expected: FAIL.
- [ ] **Step 3: Implement** in `VerbRunner.step`: for a profile with the `"crawl"` verb, call `SurfaceStep.step(s, i, p, dt, jump_boost)` before the ground step and return when it returns true.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_verb_runner` and `tools/run_tests.sh test_movement`. Expected: PASS (the envelope pins included).
- [ ] **Step 5: Commit** (`feat: the runner gives a crawling spider to the surface step`).

### Task 7: The spider crawls in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_movement_sandbox.gd`

**Interfaces:**
- Consumes: `SurfaceStep`, `MoveInput.sweep`, `ray`, `up`, `on_ceiling`.
- Produces on `MovementSandbox`: a crawl playground (`CRAWL_PILLAR := Rect2(760, -150, 30, 150)`, `CRAWL_SLAB := Rect2(760, -180, 130, 30)`, hard) and a one-way ledge (`ONEWAY_LEDGE := Rect2(1150, -50, 100, 6)`, physics layer 2, one-way); the body collides with layers 1 and 2.

- [ ] **Step 1: Write the failing tests** (the fixture's scripted input; `sb.set_profile("spider")`; real collision; each loop of frames):
  - `test_the_spider_walks_the_floor_and_a_ledge_block_with_one_held_direction`: held right from the start it goes over the 60 px ledge (x 520 to 600) and is back on the floor beyond x 610 with `state.surface_n == Vector2.UP`, having passed `LEFT` and `RIGHT` normals.
  - `test_the_spider_rounds_the_pillar_and_slab`: from just left of the pillar held right it visits all four normals and ends on the floor right of it.
  - `test_the_spider_hangs_from_the_slab_without_falling`: placed on the slab's underside (n DOWN) with the stick right for 60 frames it stays within 1 px of the underside.
  - `test_a_hop_off_a_wall_lands_back_on_the_floor`: on the 100 px ledge's left face, a hop goes left and it lands on the floor attached (`surface_n == UP`).
  - `test_the_one_way_ledge_is_walkable_from_above_and_drops_at_its_end`: hopped onto from below it carries the spider, and walking off its end drops it to the floor.
  - `test_the_slime_wolf_and_biped_are_unaffected_by_the_new_terrain`: each still jumps 63.25 px on the floor (the existing sandbox jump test, repeated per species with a tolerance).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement.** `_probes(i)` fills `i.sweep` (`body.test_move`, returning travel and normal) and `i.ray` (a physics ray from the body's centre plus the offset, masks 1 for hard-only and 3 otherwise, mapping a layer-2 collider to 2); `i.up` from `aim_up`; `i.on_ceiling = body.is_on_ceiling()`. When `state.surface_n` is not ZERO after the step: `body.global_position += state.surface_shift`, set the box to `SurfaceStep.box_size(state.surface_n)` centred (shape position zero), `body.move_and_collide(Vector2.ZERO)`, zero the velocity, and skip `move_and_slide`; leaving a surface restores the standing box. Add the terrain; set the body's collision mask to 3.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the spider crawls walls and ceilings in the sandbox`).

### Task 8: A look that follows how spiders move

**Files:**
- Modify: `scripts/movement/species_look.gd`, `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_species_look.gd`, `tests/test_movement_sandbox.gd`

**Interfaces:**
- Produces `SpeciesLook.STRIDE_PX := 24.0` (px per full 4-frame leg cycle), `SpeciesLook.stride_advance(phase: float, moved: float) -> float`, `SpeciesLook.stride_frame(phase: float) -> int` (0 to 3), `SpeciesLook.surface_angle(n: Vector2) -> float` (0 for UP, a quarter turn clockwise per step: RIGHT PI/2, DOWN PI, LEFT 3PI/2 as -PI/2). Sandbox consts `CORNER_EASE := 0.04` (the sprite settles in about 0.12 s), `PIVOT_SECONDS := 0.10`.

- [ ] **Step 1: Write the failing tests.** `test_species_look`: `stride_advance(0.0, 24.0) == 1.0`, no movement does not change the phase, `stride_frame(0.0) == 0`, `stride_frame(0.26) == 1`, `stride_frame(1.0) == 0` (it wraps), `surface_angle` for the four normals. Sandbox: `test_the_spider_sprite_follows_the_surface_with_an_ease` (on the block's wall the sprite's rotation passes through, and settles within 0.05 of, `PI / 2`... the right sign for a left face, within 0.2 s of the change, and is never more than 15 degrees off after that); `test_legs_turn_with_distance_and_freeze_when_it_stops` (the crawl frame changes while moving and the sprite's texture is identical across 20 frames once stopped, with no `hang` clip); `test_the_body_does_not_bob_or_squash` (the spider's sprite scale stays `Vector2.ONE` except the brief pivot squeeze); `test_a_reversal_pivots` (the sprite's x scale dips below 0.7 within 0.1 s of reversing and returns to 1.0 within 0.2 s).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_species_look` and `tools/run_tests.sh test_movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement.** In the sandbox for the spider: the stride phase advances by the distance moved each frame (not time) and the frame comes from `stride_frame`; stopped, it holds the frame it was on (the `hang` clip is not used); airborne shows `drop`; the sprite's rotation eases to `surface_angle` (`lerp_angle` with `1 - exp(-delta / CORNER_EASE)`) and its position keeps an offset that eases away after a corner (the body changes surface in one tick); the head points along the clockwise tangent when the sense is positive (mirror otherwise); a change of sense squeezes the x scale with a sine over `PIVOT_SECONDS`. No silk is drawn.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_species_look` and `tools/run_tests.sh test_movement_sandbox`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the spider's stride follows distance, corners ease and a reversal pivots`).

### Task 9: Specs and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Update the spider's Crawl bullet** to what was built: the clockwise-tangent surface model, the latch (survives a release, dropped by a clearly different direction), the 0.6 s way back, the 0.10 s corner lockout, one-way ledge ends drop the spider, a hop goes along the normal at the base jump, speed 140 on every surface; point to the spike notes. Add "silk waits for the zip and the silk drop" and the art additions (a turn frame, a corner-reach frame, a head-down silk pose) to Art needs. Record the open items: slick surfaces, moving platforms, gaps narrower than the box, hard ledges thinner than the box.
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the 2032 baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: spec the spider's crawl as built`).
