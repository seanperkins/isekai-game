# Slime Wall, Ball and Crawl (plan 3c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A more forgiving jump press, the slime's wall stick, slide, wall jump and wall bounce, a ball pose on bounces, and a wobble while it crawls flat.

**Architecture:** Wall behaviour is a new pure `WallStep` (statics, the style of `GroundAirStep`) called from the step; the caller probes the wall into `MoveInput.wall_side`. Numbers are slime profile data. The ball and the wobble are cosmetic and live in `SpeciesLook` and the sandbox only; `player.gd` is untouched.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (slime section, Art needs) and `2026-10-03-movement-model-design.md` (Jump, profile table).

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; any `SCRIPT ERROR` or `Parse Error` fails the run. After a new `class_name` script run `godot --headless --import` and commit its `.uid`.
- The base jump is pinned: rise 63.25 px, airtime 0.75 s at 60 Hz. No change here may move it (`test_movement_envelope`).
- Step order: timers, horizontal, gravity, wall contact, jump, wall jump, release. Timers decrement, clamp at zero, then test; a countdown tested after float subtraction uses `> 1e-6` (as `VerbRunner` does).
- Slime wall numbers (spec): stick 0.2 s at 15 px/s, then slide at 90; wall jump push 180 with the full jump speed upward, steering locked 0.15 s; probe range 6 px.
- **Forgiving press (Sean, 2026-10-04), starting values tuned by play:** slime `buffer` 0.15 (was 0.1), new `rebound_grace` 0.08, `wall_grace` 0.15. Biped, wolf and spider keep 0.1 (`test_movement_jump` pins the biped).
- One air verb per airtime; wall contact resets it (spec).
- No attribution lines in commit messages. Do not push.

## Review Focus

1. A press 1 to 4 ticks after a hard landing is a timed rebound that keeps the chain; a press after the grace is a plain jump with chain 0 (Task 1).
2. Holding jump between two walls never gains height: the bounce reflects x only (Task 5).
3. A body rising past a wall, or falling beside one without pressing toward it, does not stick (Task 3).
4. Drifting into a wall slowly with jump held does not bounce or jitter; a bounce happens once per contact (Task 5).
5. A buffered press at the moment of contact is a wall jump, not a bounce (Task 5); a species without the wall verb ignores wall input (Task 3).

---

### Task 1: A more forgiving jump press

**Files:**
- Modify: `scripts/movement/movement_profile.gd`, `scripts/movement/move_state.gd`, `scripts/movement/ground_air_step.gd`, `data/movement/slime.tres`
- Test: `tests/test_movement_forgiving.gd` (new)

**Interfaces:**
- Produces: `MovementProfile.rebound_grace: float` (seconds after a hard landing in which a press still counts as its timed rebound; 0 for none), `MoveState.rebound_left: float`.

- [ ] **Step 1: Write the failing tests** in `tests/test_movement_forgiving.gd` (GutTest; `slime`, `biped` loaded in `before_each`). Helper `_land(sim: MovementSim)` drops a `MovementSim` from `pos.y = -300`, `on_floor = false`, ticking with no input until `sim.on_floor`. Tests:
  - `test_a_press_eight_ticks_before_landing_is_a_timed_rebound_and_twelve_is_not`: the hand-filled pattern of `test_a_buffered_press_fires_on_landing_inside_the_window_only`, on the slime with `s.air_time = 0.5`; 8 gives `launched == "rebound"`, 12 gives `""`.
  - `test_a_press_after_the_landing_inside_the_grace_is_a_timed_rebound`: after `_land`, tick `late` quiet ticks, then press with jump held: `late` 1 and 4 give `launched == "rebound"` and `chain == 1`; `late` 8 gives `"ground"` and `chain == 0`.
  - `test_late_presses_chain_up_to_the_cap`: two landings each followed by a press 2 ticks late: `chain == 2` and `launch_speed` is `328.5 * sqrt(1.6)` within 0.01.
  - `test_the_chain_resets_when_the_grace_runs_out`: rebound once, land, 10 quiet ticks: `chain == 0` and `rebound_left == 0.0`.
  - `test_walking_off_the_floor_inside_the_grace_ends_the_chain`: land with `chain == 1`, then `sim.on_floor = false` and tick: `chain == 0`.
  - `test_only_the_slime_is_forgiving`: slime `buffer == 0.15`, `rebound_grace == 0.08`; biped, wolf, spider `buffer == 0.1`, `rebound_grace == 0.0`.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_movement_forgiving`
Expected: FAIL (`rebound_grace` not a property; later cases fail on values).

- [ ] **Step 3: Implement.** `MovementProfile.rebound_grace` (export, doc line). `MoveState.rebound_left`. In `GroundAirStep._timers` and `_jump`:
  - `_timers`: `var was := s.rebound_left > 0.0`, decrement-clamp it, then `if was and (s.rebound_left <= 1e-6 or not i.on_floor): s.rebound_left = 0.0; s.chain = 0`.
  - `_jump`: `var fresh := i.on_floor and s.air_time >= REBOUND_MIN_AIR`; `if fresh and p.rebound_rise > 0.0: s.rebound_left = p.rebound_grace`; `var landing := fresh or (i.on_floor and s.rebound_left > 0.0)`. The hold bounce branch tests `fresh`, not `landing`. Both launch branches set `s.rebound_left = 0.0`. The chain reset line gains `and s.rebound_left <= 0.0`.
  - `slime.tres`: `buffer = 0.15`, `rebound_grace = 0.08`.

- [ ] **Step 4: Run to see them pass, then the movement suites**

Run: `tools/run_tests.sh test_movement` then `tools/run_tests.sh test_verb_runner`
Expected: PASS, including `test_movement_release`, `test_movement_bounce` and `test_movement_jump` unchanged.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement data/movement/slime.tres tests/test_movement_forgiving.gd
git commit -m "feat: the slime's jump press forgives early and late (buffer 0.15, rebound grace 0.08)"
```

### Task 2: Wall data and probes

**Files:**
- Modify: `scripts/movement/movement_profile.gd`, `move_input.gd`, `move_state.gd`, `data/movement/slime.tres`
- Test: `tests/test_movement_profile.gd`

**Interfaces:**
- Produces on `MovementProfile` (all `@export float`): `wall_stick_time` 0.2, `wall_stick_speed` 15.0, `wall_slide_speed` 90.0, `wall_jump_push` 180.0, `wall_lock` 0.15, `wall_grace` 0.1, `wall_bounce_keep` 0.0 (0 for no bounce), `wall_bounce_min` 100.0. The cling and the wall jump need `verbs.has("wall")`; the bounce needs `wall_bounce_keep > 0` and nothing else.
- Produces on `MoveInput`: `wall_side: int` (-1 a wall on the left, 1 on the right, 0 none; the caller probes within 6 px; the step ignores it on the floor); `copy()` carries it.
- Produces on `MoveState`: `lock` (steering lock, s), `wall_touch` (touching last tick), `wall_stick` (sticky seconds left), `wall_grace` (s), `wall_side` (the last wall touched), `clinging` (stuck or sliding this tick), `wall_bounced` (one tick), `last_vx` (the x velocity the step handed the body last tick).

- [ ] **Step 1: Write the failing tests** in `tests/test_movement_profile.gd`:
  - `test_the_slime_wall_numbers`: `verbs` has `"ooze"` and `"wall"`; the eight values above, with `wall_grace == 0.15` and `wall_bounce_keep == 0.85`.
  - `test_the_other_species_have_no_wall_kit`: biped, wolf, spider: no `"wall"` verb and `wall_bounce_keep == 0.0`.
  - `test_copy_keeps_the_wall_side`: `MoveInput.wall_side = -1`, `copy().wall_side == -1`.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_movement_profile`
Expected: FAIL (properties missing).

- [ ] **Step 3: Implement** the fields with doc comments, and in `slime.tres` `verbs = PackedStringArray("ooze", "wall")`, `wall_grace = 0.15`, `wall_bounce_keep = 0.85`.

- [ ] **Step 4: Run to see them pass**

Run: `tools/run_tests.sh test_movement_profile`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement data/movement/slime.tres tests/test_movement_profile.gd
git commit -m "feat: wall fields on the profile, input and state, with the slime's numbers"
```

### Task 3: Wall stick and slide

**Files:**
- Create: `scripts/movement/wall_step.gd`
- Modify: `scripts/movement/ground_air_step.gd`, `scripts/movement/verb_runner.gd`
- Test: `tests/test_movement_wall.gd` (new)

**Interfaces:**
- Produces: `WallStep.contact(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void` (tracks touch and grace, sticks and slides, later bounces) and `WallStep.jump(s: MoveState, i: MoveInput, p: MovementProfile, jump_boost: float) -> void` (Task 4).

- [ ] **Step 1: Write the failing tests.** Helper `_wall(side: int, dir: float) -> MoveInput` (`on_floor = false`, `wall_side`, `dir`). Tests, each a loop of `GroundAirStep.step(s, i, slime, 1.0 / 60.0)`:
  - `test_a_fall_onto_a_wall_sticks_for_twelve_ticks_then_slides_at_90`: start `velocity.y = 300`, `wall_side -1`, `dir -1`: ticks 1 to 12 give `velocity.y == 15.0` and `clinging`; tick 13 on, `velocity.y` rises but never above 90.0 and reaches 90.0.
  - `test_it_does_not_cling_without_pressing_toward_the_wall`: `dir` 0 and `dir` +1 (away): after 30 ticks `velocity.y > 200.0`, `clinging` false.
  - `test_it_does_not_cling_while_rising`: `velocity.y = -200`: one tick leaves it rising and `clinging` false.
  - `test_leaving_the_wall_rearms_the_stick`: cling, 3 ticks with `wall_side 0`, touch again with `velocity.y = 100`: sticks at 15.0 again.
  - `test_a_species_without_the_wall_verb_ignores_walls`: wolf profile, same fall: `velocity.y > 200.0` after 30 ticks.
  - In `tests/test_verb_runner.gd`, `test_wall_contact_refreshes_the_air_tackle`: tackle in the air (`air_verb_used`), end it, a second tackle is refused; a tick with `wall_side 1` clears `air_verb_used` and a tackle starts.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_movement_wall`
Expected: FAIL (`WallStep` not defined).

- [ ] **Step 3: Implement `WallStep.contact`.**
  - `touching := i.wall_side != 0 and not i.on_floor`. When touching, remember `s.wall_side = i.wall_side` and refill `s.wall_grace = p.wall_grace` if the profile has the wall verb; else decrement-clamp it. `s.wall_touch = touching`.
  - `cling := verbs.has("wall") and touching and i.dir * i.wall_side > 0.0 and (s.velocity.y > 0.0 or s.clinging)`. Starting a cling sets `s.wall_stick = p.wall_stick_time`. While clinging: `cap` is `wall_stick_speed` while `wall_stick > 1e-6` (then decrement it), else `wall_slide_speed`; `s.velocity.y = minf(s.velocity.y, cap)`.
  - Wire into `GroundAirStep.step` after `_gravity`: `WallStep.contact(...)`; at the start of `step` also `s.wall_bounced = false`; `_timers` decrements `s.lock`; `_horizontal` is skipped while `s.verb != "" or s.lock > 1e-6`; the end of `step` sets `s.last_vx = s.velocity.x`.
  - `VerbRunner.step`: `if i.on_floor or (p.verbs.has("wall") and i.wall_side != 0): s.air_verb_used = false`.

- [ ] **Step 4: Run to see them pass, then the movement suites**

Run: `godot --headless --import` then `tools/run_tests.sh test_movement` and `tools/run_tests.sh test_verb_runner`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement tests/test_movement_wall.gd tests/test_verb_runner.gd
git commit -m "feat: the slime sticks to a wall for 0.2 s, then slides at 90"
```

### Task 4: Wall jump

**Files:**
- Modify: `scripts/movement/wall_step.gd`, `scripts/movement/ground_air_step.gd`
- Test: `tests/test_movement_wall.gd`

**Interfaces:**
- Consumes: Task 3's `WallStep` and state fields.
- Produces: `WallStep.jump(...)`; `MoveState.launched == "wall"` for a wall jump.

- [ ] **Step 1: Write the failing tests** (same helper, slime):
  - `test_a_wall_jump_kicks_away_at_180_with_the_full_jump_speed`: cling to a wall on the left (`wall_side -1`), press jump: `velocity == Vector2(180.0, -328.5)`, `launched == "wall"`, `jumping`, `wall_grace == 0.0`. Wall on the right: `velocity.x == -180.0`. With `jump_boost 1.5`: `velocity.y == -328.5 * 1.5`.
  - `test_steering_is_locked_for_the_rest_of_the_wall_jumps_nine_ticks`: after the launch tick, with `dir` toward the wall and `wall_side 0`, `velocity.x == 180.0` for 8 ticks and has dropped below 180.0 on the 9th.
  - `test_a_wall_jump_works_inside_the_grace_and_not_after_it`: lose contact for 3 ticks then press: `launched == "wall"`; lose it for 12 ticks then press: `""`.
  - `test_a_press_just_before_touching_the_wall_still_jumps`: press 4 ticks before the first contact tick, with the button released: fires on contact.
  - `test_the_floor_jump_beats_the_wall_jump`: `on_floor` true with a wall: `launched == "ground"`.
  - `test_the_wall_jump_rises_exactly_as_far_as_the_base_jump`: integrate 120 ticks after the launch (`pos.y += velocity.y * dt`, jump held, no wall): the rise equals `MovementSim.flat_jump(slime, 1.0, 100.0, 0.0)["rise"]` within 0.001. This is the number the reach plan reads.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_movement_wall`
Expected: FAIL on the new tests.

- [ ] **Step 3: Implement `WallStep.jump`**, called in `GroundAirStep.step` right after `_jump`. It returns at once unless `s.launched == ""`, the profile has the wall verb, the body is off the floor, `s.buffer > 0.0` and `s.wall_grace > 0.0`. It sets `launch_speed = p.jump_velocity * jump_boost`, `launched = "wall"`, `velocity = Vector2(-s.wall_side * p.wall_jump_push, -launch_speed)`, `jumping = true`, and clears `buffer`, `coyote`, `wall_grace`, `clinging` and `wall_bounced`, and sets `lock = p.wall_lock`.

- [ ] **Step 4: Run to see them pass, then the movement suites**

Run: `tools/run_tests.sh test_movement`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement tests/test_movement_wall.gd
git commit -m "feat: wall jump, 180 push and the full jump upward, steering locked 0.15 s"
```

### Task 5: Wall bounce

**Files:**
- Modify: `scripts/movement/wall_step.gd`
- Test: `tests/test_movement_wall.gd`

**Interfaces:**
- Consumes: `MoveState.last_vx`, `MoveState.wall_touch`, `MovementProfile.wall_bounce_keep` and `wall_bounce_min`.
- Produces: `MoveState.wall_bounced` (true for the tick of a bounce).

- [ ] **Step 1: Write the failing tests.** Helper `_approach(s, speed)` runs one tick with `velocity.x = speed`, no wall, so `last_vx == speed`.
  - `test_holding_jump_into_a_wall_reflects_the_speed_at_85_percent`: speed 140 toward a wall on the right, then a first contact tick with `jump_held`: `velocity.x == -119.0` within 0.01, `wall_bounced`, `clinging` false, `velocity.y` unchanged by the tick's own gravity only.
  - `test_without_jump_held_it_sticks_instead`: same without `jump_held`: no bounce, `clinging`.
  - `test_a_slow_drift_into_a_wall_does_not_bounce`: speed 60 with jump held: `wall_bounced` false.
  - `test_a_bounce_happens_once_per_contact`: a second tick still touching: `wall_bounced` false and `velocity.x` is not reflected again.
  - `test_a_bounce_locks_steering_for_nine_ticks`: `dir` back into the wall after the bounce: `velocity.x` stays -119.0 for 8 ticks.
  - `test_a_bounce_never_launches_so_it_cannot_climb`: the bounce tick has `launched == ""` and leaves `jumping` as it was; and `test_holding_jump_between_two_walls_never_rises`: walls at x 0 and 100, the body starts at x 50, `velocity (140, 0)`, jump held, `wall_side` set from x (within 6 px of a wall), 300 ticks of `x += vx * dt`: `velocity.y >= 0.0` on every tick and `launched == ""` on every tick.
  - `test_a_press_at_the_moment_of_contact_is_a_wall_jump_not_a_bounce`: buffer live (press 2 ticks before) and jump held at first contact: `launched == "wall"`, `wall_bounced` false, `velocity.x == -180.0`.
  - `test_the_bounce_does_not_need_the_wall_verb`: slime profile duplicate with `verbs` emptied: the bounce still reflects and nothing sticks.
  - In `tests/test_verb_runner.gd`, `test_a_tackle_into_a_wall_with_jump_held_reflects_it`: tackling at 340 (one prior tick so `last_vx == 340`), then contact with jump held: `velocity.x` below -280.0.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_movement_wall`
Expected: FAIL on the new tests.

- [ ] **Step 3: Implement** in `WallStep.contact`, before the cling decision: a bounce needs `touching`, `not s.wall_touch` before this tick (first contact), `p.wall_bounce_keep > 0.0`, `i.jump_held`, and `s.last_vx * i.wall_side >= p.wall_bounce_min`. It sets `velocity.x = -i.wall_side * absf(s.last_vx) * p.wall_bounce_keep`, `lock = p.wall_lock`, `wall_bounced = true`, `clinging = false`, and returns before the cling logic. It never touches `velocity.y`. `WallStep.jump` already overrides it on the same tick (Task 4 clears `wall_bounced`).

- [ ] **Step 4: Run to see them pass, then the movement suites**

Run: `tools/run_tests.sh test_movement` and `tools/run_tests.sh test_verb_runner`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement tests/test_movement_wall.gd tests/test_verb_runner.gd
git commit -m "feat: holding jump into a wall bounces off it instead of sticking"
```

### Task 6: Poses and procedural shapes

**Files:**
- Modify: `scripts/movement/species_look.gd`
- Test: `tests/test_species_look.gd`

**Interfaces:**
- Produces: `SpeciesLook.clip_for(species, on_floor, vy, vx, land_timer, verb := "", flat := false, wall := false, ball := false) -> String`; the slime's `clips_for` gains a `"ball"` clip (frames `["fall"]`, a stand-in merged in code; `data/slime_clips.json` is shared with the game and stays untouched); `SpeciesLook.ball_scale(frame_size: Vector2) -> Vector2`; `SpeciesLook.crawl_scale(phase: float) -> Vector2`; `SpeciesLook.crawl_advance(phase: float, vx: float, dt: float) -> float`; consts `CRAWL_AMPLITUDE := 0.15`, `CRAWL_RATE := 0.2` (radians per px).

- [ ] **Step 1: Write the failing tests:**
  - `test_the_wall_pose_beats_every_other_slime_pose`: `wall` true with verb `"tackle"` and `ball` true gives `"wall"`.
  - `test_ball_replaces_only_the_airborne_and_landing_poses`: ball in the air rising or falling and on the floor with `land_timer 0.1` give `"ball"`; with verb `"tackle"` `"tackle"`; flat `"spread"`; on the floor idle `"idle"`; `run` stays `"run"`.
  - `test_other_species_ignore_wall_and_ball`: spider and wolf return the same clip with the flags set.
  - `test_every_clip_it_names_exists_in_the_data` extended: also iterate `wall` and `ball` true; `clips_for("slime")` has `"ball"`.
  - `test_the_ball_is_square`: `ball_scale(Vector2(42, 38))` is `Vector2(38.0 / 42.0, 1.0)`.
  - `test_the_crawl_wobble_stretches_and_squeezes_without_changing_volume`: `crawl_scale(0.0) == Vector2.ONE`; at `PI / 2` x above 1 and y below 1; at `3 * PI / 2` the reverse; `x * y` is 1.0 within 0.001 for ten phases; the stretch never exceeds `CRAWL_AMPLITUDE`; `crawl_scale(TAU + 0.3)` equals `crawl_scale(0.3)`.
  - `test_the_crawl_phase_follows_distance_travelled`: `crawl_advance(0.0, 70.0, 1.0)` is `70.0 * CRAWL_RATE`; speed 0 does not move it; the sign of `vx` does not matter.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_species_look`
Expected: FAIL.

- [ ] **Step 3: Implement.** `crawl_scale` is `Vector2(1.0 + a, 1.0 / (1.0 + a))` with `a = CRAWL_AMPLITUDE * sin(phase)`. The slime branch computes `SlimeState.pick(false, false, false, wall, verb == "tackle", flat, on_floor, vy, land_timer, vx)` and returns `"ball"` when `ball` and the pose is `rise`, `fall` or `land`.

- [ ] **Step 4: Run to see them pass**

Run: `tools/run_tests.sh test_species_look` and `tools/run_tests.sh test_slime`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement/species_look.gd tests/test_species_look.gd
git commit -m "feat: wall and ball poses and the crawl wobble shape, as pure functions"
```

### Task 7: Walls in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_movement_sandbox.gd`

**Interfaces:**
- Consumes: `MoveInput.wall_side`, `SpeciesLook.clip_for(..., wall, ball)`.
- Produces: `MovementSandbox.SHAFT_WALL := Rect2(1260, -300, 40, 300)` (a pillar 110 px from the right end wall, for climbing by wall jumps), `WALL_RANGE := 6.0`.

- [ ] **Step 1: Write the failing tests** (the existing fixture: scripted input, `_frames`). Place the body with `sb.body.global_position`:
  - `test_a_falling_slime_sticks_then_slides_down_the_left_wall`: at `Vector2(15, -250)` with `dir -1`: within 8 frames `body.velocity.y <= 16.0`, `sb.clip() == "wall"` and the sprite's `flip_h` is true; 25 frames later `body.velocity.y` is 90 within 1.
  - `test_a_jump_from_the_wall_kicks_off_and_up`: stuck as above, then `scripted.jump_pressed = true`: within 5 frames `state.launched == "wall"` was seen, and after 10 frames `body.velocity.x > 100.0` or the body is already clear of the wall (`global_position.x > 40.0`), and `body.velocity.y < 0.0` at the launch.
  - `test_holding_jump_into_the_wall_bounces_off_it`: at `Vector2(80, -120)` with `state.velocity.x = -140`, `dir -1`, `jump_held` true: over 80 frames `state.wall_bounced` is seen once, `sb.clip()` is never `"wall"`, and the final `body.velocity.x > 50.0`.
  - `test_the_shaft_wall_is_solid`: the body at `Vector2(1230, -12)` running right stops short of x 1260.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_movement_sandbox`
Expected: FAIL.

- [ ] **Step 3: Implement.** `_block(SHAFT_WALL)` in `_ready`. `_wall_side(dir: float) -> int`: 0 on the floor; else `test_move` by `side * WALL_RANGE` for the side the input points to first, then the other; fill `i.wall_side` after `clearance_above` in `_physics_process` (ignore the scripted input's own `wall_side`). `_draw_body` passes `state.clinging` as `wall`; mirrors the sprite by `state.wall_side < 0` while the clip is `"wall"` (a wall on the left faces left, as `Player._faces_left`); the HUD verb reads `"wall"` while clinging and the help line gains "press into a wall to stick, jump to kick off, hold jump to bounce".

- [ ] **Step 4: Run to see them pass**

Run: `tools/run_tests.sh test_movement_sandbox`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement/movement_sandbox.gd tests/test_movement_sandbox.gd
git commit -m "feat: wall probe, a shaft pillar and the wall pose in the sandbox"
```

### Task 8: Ball landings and the crawl wobble in the sandbox

**Files:**
- Modify: `scripts/movement/squash_spring.gd`, `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_squash_spring.gd`, `tests/test_movement_sandbox.gd`

**Interfaces:**
- Produces: `SquashSpring.calm() -> void` (zero offset and speed); sandbox consts `BALL_SECONDS := 0.3`, `BALL_SPIN := 12.0` (rad/s).

- [ ] **Step 1: Write the failing tests.**
  - `tests/test_squash_spring.gd` `test_calm_stops_a_squash`: after `land(500.0)` and a few updates `sprite_scale()` is not one; after `calm()` it is `Vector2.ONE`.
  - Sandbox, helper `_scales(n)` returns the sprite's scale each frame for `n` frames:
    - `test_a_plain_landing_still_squashes`: dropped from `Vector2(300, -150)` with no input, the minimum y scale in the 15 frames after landing is below 0.97 and `clip()` was `"land"`.
    - `test_a_timed_rebound_lands_as_a_ball_not_a_squash`: dropped the same way, `scripted.jump_pressed = true` once the body is falling within 30 px of the floor: `state.launched == "rebound"` is seen, `clip() == "ball"` within 2 frames of it, the sprite is rotating (`rotation != 0.0`), and the y scale never goes below 0.999 from the launch on.
    - `test_a_hold_bounce_is_a_ball_too`: dropped with `jump_held`: `clip() == "ball"` within 2 frames of `launched == "bounce"`.
    - `test_a_late_press_swaps_the_squash_for_the_ball`: dropped with no input; two frames after the landing press jump: `launched == "rebound"` and then `clip() == "ball"` with the y scale back at 0.999 or more within 3 frames.
    - `test_the_ball_ends_when_the_bouncing_does`: after a hold bounce with `jump_held` released, 200 frames later `clip() == "idle"` and the sprite rotation is 0.0.
    - `test_a_moving_flat_slime_wobbles_and_a_still_one_does_not`: `down 1.0`, `dir 1.0`: the sprite's x scale over 40 frames spans more than 0.1; with `dir 0.0` for 30 frames then sampling 10, it spans under 0.01.

- [ ] **Step 2: Run to see them fail**

Run: `tools/run_tests.sh test_squash_spring` and `tools/run_tests.sh test_movement_sandbox`
Expected: FAIL.

- [ ] **Step 3: Implement.**
  - `SquashSpring.calm()`.
  - Sandbox landing: on touching down record `_landing = true` and `_landing_speed = fall_speed` instead of kicking. After the step in the next tick: if `state.launched` is `"rebound"` or `"bounce"`, or `state.wall_bounced`, set `_ball_time = BALL_SECONDS`, `_spring.calm()`, `_land_timer = 0.0` and `_landing = false`; else if `_landing`, kick `_spring.land(_landing_speed)`, set `_land_timer = LAND_SECONDS` and clear the flag. A plain landing clears `_ball_time`. Decrement `_ball_time` each tick.
  - `_draw_body` passes `_ball_time > 0.0` as `ball`. For the `"ball"` clip the scale is `SpeciesLook.ball_scale(frame_size)` and the sprite rotates by `BALL_SPIN * _facing * delta` per tick (centred, as the sprite is); any other clip resets `rotation = 0.0`. While `state.spread` and not sliding and `absf(vx) > 8.0`: `_crawl_phase = SpeciesLook.crawl_advance(_crawl_phase, state.velocity.x, delta)` and the scale is multiplied by `SpeciesLook.crawl_scale(_crawl_phase)`.

- [ ] **Step 4: Run to see them pass**

Run: `tools/run_tests.sh test_squash_spring` and `tools/run_tests.sh test_movement_sandbox`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement tests/test_squash_spring.gd tests/test_movement_sandbox.gd
git commit -m "feat: bounces land as a spinning ball, and a flat slime wobbles as it crawls"
```

### Task 9: Specs, art list and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`, `docs/superpowers/specs/2026-10-03-movement-model-design.md`

- [ ] **Step 1: Update the species spec.**
  - Slime section: the bounce bullet says a press up to 0.15 s before landing or 0.08 s after it counts as the timed rebound; a new *Wall bounce* bullet (holding jump into a wall reflects speed at 85%, from 100 px/s, once per contact, x only so it never climbs, needs no Wall Cling); the sticky wall bullet records `wall_grace 0.15`; *Ball* (a bounce lands as a spinning ball, never the squash) and *Crawl* (a wobble tied to distance while flat and walking).
  - Art needs: slime gains a ball frame (a round, curled pose to replace the squared `fall` stand-in) and crawl frames (2 to 4, a flat body inching forward) alongside the puddle slide and wall pose.
  - The open-items list notes that the wall slide still ignores the `slide_speed` stat until the wiring plan.
- [ ] **Step 2: Update the model spec.** The profile table's slime buffer is 0.15; the Jump paragraph describes `rebound_grace` (a press up to that long after the landing tick still rebounds, and the chain resets when the grace runs out).
- [ ] **Step 3: Run the whole suite**

Run: `tools/run_tests.sh`
Expected: `PASS: N tests` with N above the 3b count and no `SCRIPT ERROR` or `Parse Error`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs
git commit -m "docs: spec the forgiving press, wall bounce, ball and crawl; art list gains the ball and crawl frames"
```
