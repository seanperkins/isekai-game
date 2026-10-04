# Biped Moveset (plan 7a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The goblin acrobat's three verbs in the sandbox: roll or slide (its signature, one Tackle-button verb in two contexts), the automatic ledge mantle, and the wall slide with its wall jump.

**Architecture:** Roll and slide are two more `BurstDef` rows (they gain a speed ceiling, an invulnerable window and a shared cooldown; the speed floor and the floor requirement now apply to every trigger), plus a `crouched` state so a roll that ends under a low ceiling stays flat. The wall verbs are the slime's `WallStep` with the biped's numbers (no new code). Mantle is a pure `MantleStep` over a probe the caller fills; it owns the body for 0.25 s through the displacement channel (`surface_shift`) the zip uses. `player.gd` is untouched; the biped stays a placeholder (no goblin art).

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (Biped; Rules across all four).

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; the whole suite takes about 35 s.
- Roll (spec): under 100 px/s, 0.35 s at 220 along the facing. Slide: from 100 px/s up, keeps the speed (decel 350), at most 0.4 s. Both: invulnerable for the first 0.2 s, flat (they duck low gaps), on the Tackle button, floor only. A roll or slide that ends under a low ceiling stays crouched until it can stand.
- Mantle (spec): automatic, hard ledges only (a one-way ledge is jumped through). Airborne, not rising faster than 40, feet within 6 px (plus this tick's fall distance) below a hard ledge top, a wall ahead in the held or facing direction: pull up in 0.25 s and stand on it. One air verb per airtime. Mantle beats a wall jump on the same press; a jump pressed during it is buffered and fires when control returns.
- Wall jump (spec): slides at 90 (no stick), kicks off at 180, lock 0.15, grace 0.1, range 6 px; its rise equals the base jump's.
- No verb locks control for more than 0.5 s. The base jump pin and every other species are unchanged (`test_movement_envelope`).
- No attribution lines in commit messages. Do not push.

## Review Focus

1. A roll starts under 100 px/s and a slide from 100 up; neither starts in the air; a jump out of one fires at once (Task 1).
2. The invulnerable window is exactly the first 0.2 s and never outlasts the verb (Task 1).
3. A roll or slide that ends under a low ceiling stays crouched, walks at half speed and cannot jump until it fits (Task 1).
4. Mantle needs the feet within 6 px under a hard lip, never rising faster than 40, with a wall ahead; never a one-way ledge; a jump pressed during it fires after it (Task 3).
5. The biped's wall slide has no stick, its wall jump rises exactly as far as the base jump, and the other species are unchanged (Task 2).

---

### Task 1: Roll and slide

**Files:**
- Modify: `scripts/movement/burst_def.gd`, `move_state.gd`, `verb_runner.gd`, `data/movement/biped.tres`
- Test: `tests/test_verb_runner.gd`, `tests/test_movement_profile.gd`

**Interfaces:**
- Produces on `BurstDef`: `max_start_speed := 0.0` (0 for no cap: the body needs less horizontal speed than this to start it), `iframes := 0.0` (seconds from the start in which the body is invulnerable), `cooldown_group := ""` (rows with the same group share one cooldown; empty means the row's own id). `min_start_speed` and `needs_floor` now gate the start of every trigger (the slime's puddle already needed both). On `MoveState`: `invulnerable: bool`, `crouched: bool`. `biped.tres` bursts: `roll` (signature, speed 220, duration 0.35, max_start_speed 100, iframes 0.2, flat, needs_floor, cooldown 0.3, group `roll`) and `slide` (signature, speed 0 so it keeps the body's, min_start_speed 100, duration 0.4, decel 350, min_speed 20, iframes 0.2, flat, needs_floor, cooldown 0.3, group `roll`).

- [ ] **Step 1: Write the failing tests.** `test_movement_profile`: `test_the_biped_rolls_and_slides_with_the_spec_numbers` (the two rows' numbers; the other three species have no `roll` or `slide`). `test_verb_runner` (the biped, on the floor): `test_a_standing_biped_rolls_220_along_its_facing_for_035_s` (both facings; `is_flat`; ends after 21 to 23 ticks); `test_at_100_px_s_it_slides_and_at_99_9_it_rolls` (the slide keeps the speed it had, loses 350 px/s per second, and ends under 20 px/s or after 0.4 s); `test_neither_starts_in_the_air_and_both_end_when_it_leaves_the_floor`; `test_a_roll_and_a_slide_share_one_cooldown_of_0_3_s_from_the_end` (a slide cannot follow a roll at once); `test_invulnerable_for_exactly_the_first_twelve_ticks_and_not_after` (and false once the verb has ended, and with no verb); `test_a_roll_that_ends_under_a_low_ceiling_stays_crouched` (`clearance_above` 0 at the end: still `is_flat`, walks at half speed, `jump_pressed` does not launch; with `clearance_above` 1000 it stands on the next tick); `test_a_jump_during_a_roll_fires_at_once_and_ends_it` (`launched == "ground"`, the roll's verb cleared on leaving the floor); `test_the_slime_and_the_wolf_start_their_bursts_as_before` (Tackle at any speed; the pounce).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_profile` and `tools/run_tests.sh test_verb_runner`. Expected: FAIL.
- [ ] **Step 3: Implement** in `VerbRunner`: `_can_begin` rejects a row whose `needs_floor` the body does not meet, whose speed is under `min_start_speed` or (when `max_start_speed > 0`) not under it, or whose cooldown key (`cooldown_group` else `id`) is running; `_end` sets the cooldown under that key and `crouched = row.flat`; `_bursts` clears `invulnerable` first and sets it while `duration - verb_left < iframes - 1e-6` (before this tick's decrement); at the top of `_bursts`, with no verb running and `i.clearance_above >= STAND_RISE`, `crouched` clears; `is_flat` includes `crouched`; the half walking speed and the no-jump-under-a-low-ceiling rule apply to `spread or crouched`.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement` and `tools/run_tests.sh test_verb_runner`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the biped's roll and slide, bursts with a window of invulnerability`).

### Task 2: The wall slide and jump

**Files:**
- Modify: `data/movement/biped.tres`
- Test: `tests/test_movement_wall.gd`, `tests/test_movement_profile.gd`

- [ ] **Step 1: Write the failing tests.** `test_movement_profile`: `test_the_biped_has_the_wall_verb_with_the_spec_numbers` (verbs has `wall`; `wall_stick_time` 0, `wall_slide_speed` 90, `wall_jump_push` 180, `wall_lock` 0.15, `wall_grace` 0.1, `wall_bounce_keep` 0). `test_movement_wall` (the biped; same helpers): `test_a_falling_biped_pressing_into_a_wall_slides_at_90_at_once` (no stick: the first tick caps at 90); `test_the_biped_wall_jump_kicks_off_at_180_and_rises_as_far_as_the_base_jump` (the apex equals `330^2 / (2 * 900)` within 0.5 px, locked for nine ticks); `test_the_biped_wall_grace_is_0_1_s` (a press 0.09 s after leaving still jumps, 0.11 s does not); `test_the_biped_does_not_bounce_off_a_wall`.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_wall` and `tools/run_tests.sh test_movement_profile`. Expected: FAIL.
- [ ] **Step 3: Implement** the `biped.tres` numbers: `verbs = PackedStringArray("wall")`, `wall_stick_time = 0.0`, `wall_slide_speed = 90.0`, `wall_jump_push = 180.0`, `wall_lock = 0.15`, `wall_grace = 0.1`.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the biped slides and jumps off walls`).

### Task 3: The mantle

**Files:**
- Create: `scripts/movement/mantle_step.gd`
- Modify: `scripts/movement/move_input.gd`, `move_state.gd`, `movement_profile.gd`, `verb_runner.gd`, `data/movement/biped.tres`
- Test: `tests/test_mantle_step.gd` (new), `tests/test_movement_profile.gd`

**Interfaces:**
- Produces on `MoveInput`: `mantle: Vector2` (the displacement from the body's centre to where it would stand on the ledge ahead: `y` is minus the px from the feet up to the ledge top, `x` the way over it; ZERO for none; the caller probes it, for hard solids only, only where the standing box fits). On `MoveState`: `mantle_left: float` (seconds left, 0 when none), `mantle_total: Vector2` (the displacement it started with), `mantle_event: String` (`""`, `"start"`, `"stand"`), `queued_jump: bool` (a jump pressed during a verb that owns both axes, fired when control returns). On `MovementProfile`: `mantle_reach := 6.0`, `mantle_max_rise := 40.0`, `mantle_time := 0.25`; `biped.tres` verbs `["wall", "mantle"]`. Produces `MantleStep.step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> bool` (true while it owns the body; it sets `surface_shift` each tick like the zip).

- [ ] **Step 1: Write the failing tests.** `test_mantle_step`: `test_it_starts_airborne_at_a_ledge_with_a_wall_ahead` (`wall_side 1`, `dir 1`, `mantle (32, -4)`, vy 0: returns true, `mantle_left` 0.25, event `"start"`, velocity ZERO, `air_verb_used`); `test_the_feet_must_be_within_6_px_plus_the_fall_this_tick` (rise 6 yes, 7 no at rest; at vy 120 (2 px a tick) 8 yes and 8.5 no); `test_it_does_not_start_rising_faster_than_40` (-41 no, -40 yes); `test_it_needs_a_wall_in_the_held_or_facing_direction` (wall behind no; stick away from the wall no; no stick uses `facing`); `test_never_on_the_floor_or_with_no_probe_or_with_the_air_verb_spent`; `test_the_pull_goes_up_then_over_and_sums_to_the_displacement` (every `y` shift comes before any `x` shift; the shifts sum to `mantle_total`; it owns the body each tick, ends with event `"stand"` after 15 to 16 ticks and `mantle_left` 0). Through `VerbRunner` (biped): `test_mantle_beats_a_wall_jump_on_the_same_press`; `test_a_jump_pressed_during_the_mantle_fires_when_it_ends` (`queued_jump`, then `launched == "ground"` on the first tick with `on_floor`); `test_only_the_biped_mantles` (the other three ignore the probe). `test_movement_profile`: the numbers.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_mantle_step`. Expected: FAIL.
- [ ] **Step 3: Implement** `MantleStep`: reset `surface_shift` and `mantle_event`; start under the spec conditions (rise is `-i.mantle.y`, `0 < rise <= mantle_reach + max(0, vy * dt)`), zeroing the velocity and `jumping`, setting `air_verb_used`; while running, `GroundAirStep.timers` is not called, a press sets `queued_jump`, and each tick shifts by `path(u1) - path(u0)` where `path(u)` is `y = total.y * clamp(u / 0.6, 0, 1)`, `x = total.x * clamp((u - 0.6) / 0.4, 0, 1)` and `u` is the elapsed fraction of `mantle_time`. In `VerbRunner.step`, after the drop and before the crawl: `if p.verbs.has("mantle") and MantleStep.step(...)`: return; and before the ground step a `queued_jump` becomes a `jump_pressed` on a copy of the input and clears.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_mantle_step` and `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the biped mantles ledges`).

### Task 4: The biped in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`
- Test: `tests/test_movement_sandbox.gd`

**Interfaces:**
- Produces on `MovementSandbox`: the `mantle` probe for a profile with `"mantle"`: with a wall within 6 px (`wall_side`) the ledge top is the first hit of a ray down from 40 px above the feet at the wall's far side (hard and slick solids, never a one-way ledge; a wall taller than the ray starts inside it, which is no hit); the standing target is the wall's face plus the box's half width plus 2 px, on the ledge top; it is reported only when the standing box fits there (`test_move` at the target, 1 px above the lip). The placeholder rect shrinks to the flat box while flat and flickers at 60% alpha while `invulnerable`.

- [ ] **Step 1: Write the failing tests** (real collision, `sb.set_profile("biped")`):
  - `test_a_standing_biped_rolls_on_the_tackle_button_and_a_running_one_slides` (roll: 220 px/s, the box 10 px tall, about 77 px travelled, `invulnerable` seen; a run at 140 then the button: a slide that keeps going and slows).
  - `test_a_roll_ducks_the_tunnel_and_the_biped_stays_crouched_inside_it` (from x 860 into the 12 px tunnel at x 900 to 1140: the roll ends inside it, the box stays flat, it walks out at half speed and stands on the far side).
  - `test_a_biped_at_the_apex_beside_a_60_px_ledge_mantles_onto_it` (centre at x 504, y -69, vy 0, `dir` 1: `mantle_event` `"start"` seen, `state.air_verb_used`, within 30 frames it stands on the ledge: x over 520 and on the floor, y about -72, `launched` never `"wall"`).
  - `test_a_biped_beside_the_one_way_ledge_does_not_mantle` (centre at x 144, feet 3 px under its top, `dir` 1: no mantle).
  - `test_a_biped_wall_jumps_up_the_shaft` (between the shaft wall at x 1260 to 1300 and the end wall, jumping at the wall and pressing away: `launched == "wall"` at least twice and the body ends higher than a base jump reaches).
  - `test_the_other_species_are_unchanged`: the existing slime and spider checks stand; the wolf's low-step vault still passes.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: FAIL.
- [ ] **Step 3: Implement** the probe in `_physics_process` (`i.mantle` only for a profile with `"mantle"`), the placeholder's flat scale and the invulnerable flicker in `_draw_body`, and the biped's line in the HUD (roll and slide on J, mantle and wall jump automatic).
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement_sandbox`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the biped rolls, mantles and wall jumps in the sandbox`).

### Task 5: Specs and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Update the Biped bullets** to what was built (the rows and their numbers, the shared cooldown of 0.3 s, `min_speed 20`, the invulnerable flag, the crouch, the mantle probe and path, the queued jump, the wall numbers), the build order, Art needs and open items (hurt cancelling a verb outside the invulnerable window and the mantle's reach entry are the wiring and reach plans'; a jump out of a roll ends it and the speed bleeds at air control).
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the 2280 baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: spec the biped's moveset as built`).
