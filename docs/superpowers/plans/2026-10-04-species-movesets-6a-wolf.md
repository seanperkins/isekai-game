# Wolf Moveset (plan 6a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The gloom wolf's three verbs in the sandbox: the pounce (its signature), the automatic vault over low steps, and the skid when it reverses at a gallop.

**Architecture:** The pounce is one more row of the data-driven `BurstDef` machinery (it gains an aim, a share of the run speed and an end at a wall), so `VerbRunner` runs it like Tackle. The vault is a small pure `VaultStep` over a step-height probe the caller fills. The skid is a flag `GroundAirStep` sets. The look (a stretched leap, a braced skid with dust, the vault hop) is cosmetic and lives in `SpeciesLook` and the sandbox. `player.gd` is untouched.

**Tech Stack:** Godot 4.7, GDScript (typed everything, warnings are errors), GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (Wolf: Gallop and skid turn, Pounce, Vault; Rules across all four).

## Global Constraints

- `tools/run_tests.sh [substring]` prints `PASS: N tests`; the whole suite takes about 35 s.
- Pounce (spec): a leap along the cast aim (the caller resolves it into `MoveInput.aim`; with none, the facing) at **300 plus half the run speed** for **0.35 s, with gravity on** (so a pounce straight up rises at most about 33 px, never more than the base jump), then ballistic with the wolf's weak air control; it ends at a wall; **cooldown 0.8 s from the end**; one air verb per airtime. A per-tick contact check marks the first hostile it touches (`MoveInput.touching_hostile` to `MoveState.pounce_hit`; what that does is decided at combat wiring).
- Vault (spec): automatic, at **150 px/s or more**, a hard step **24 px or less** ahead is hopped without a jump press with an impulse of `-sqrt(2 g (step + margin))` on one tick (margin 6), keeping the speed. A higher step is a wall. A one-way ledge is jumped through, never vaulted.
- Skid: on the floor, the stick opposing a velocity of 150 or more. The movement itself is the tuned profile (0.4 s up, 0.1 s brake and turn); this only flags it for the look.
- No verb locks control for more than 0.5 s. The base jump pin and every other species are unchanged (`test_movement_envelope`).
- No attribution lines in commit messages. Do not push.

## Review Focus

1. A pounce straight up rises no more than the base jump, and a pounce into a wall ends there instead of sliding along it (Task 1).
2. A second pounce is refused for 0.8 s after the first ends and in the same airtime until the wolf lands (Task 1).
3. A step of 24 px is vaulted and one of 25 is not; the wolf under 150 px/s does not vault; it never vaults while airborne or into a one-way ledge (Task 2).
4. Skid flags only a real reversal at speed on the floor, never in the air or when the stick is released (Task 3).
5. The other species and the slime's Tackle are unchanged (Tasks 1 to 4).

---

### Task 1: The pounce

**Files:**
- Modify: `scripts/movement/burst_def.gd`, `move_input.gd`, `move_state.gd`, `verb_runner.gd`, `data/movement/wolf.tres`
- Test: `tests/test_verb_runner.gd`, `tests/test_movement_profile.gd`

**Interfaces:**
- Produces on `BurstDef`: `run_fraction: float` (the share of the body's horizontal speed added to `speed`), `aimed: bool` (the burst goes along `MoveInput.aim`, both axes, instead of the facing), `ends_at_wall: bool` (it ends when the body touches a wall it is moving toward).
- Produces on `MoveInput`: `touching_hostile: bool` (the caller's contact check this tick). On `MoveState`: `pounce_hit: bool` (a hostile was touched during the pounce running; cleared when a burst begins).
- `wolf.tres`: a `pounce` row (`trigger "signature"`, `speed 300`, `run_fraction 0.5`, `duration 0.35`, `aimed true`, `ends_at_wall true`, `cooldown 0.8`) in `bursts`.

- [ ] **Step 1: Write the failing tests.** `test_movement_profile`: `test_the_wolf_pounces_with_the_spec_numbers` (the row's values above; the other three species have no `pounce` row). `test_verb_runner` (the wolf profile, `MoveInput` by hand):
  - `test_a_pounce_goes_along_the_aim_at_300_plus_half_the_run_speed`: standing still, `aim` right and up `(0.7071, -0.7071)`: `verb == "pounce"`, `velocity` is `(212.1, -212.1)` within 0.1; running at 200 px/s the speed is 400 along the same aim.
  - `test_with_no_aim_it_goes_along_the_facing`: `aim` ZERO and facing -1: velocity `(-300, 0)`.
  - `test_gravity_acts_during_the_pounce_and_the_rise_is_below_the_base_jump`: a pounce straight up (`aim` `(0, -1)`) simulated with `MovementSim` ticks: the highest point is within 33.5 plus or minus 1 px and under the base jump's rise (63.25); horizontal velocity is not touched by the stick for 0.35 s (a stick held left changes nothing), then air control is weak.
  - `test_it_lasts_0_35_s_then_a_cooldown_of_0_8_s_from_its_end`: `verb` is `"pounce"` for 21 ticks, then `""`; a press 0.7 s after the end is refused and one after 0.8 s starts it.
  - `test_it_ends_at_a_wall_it_is_moving_toward`: `wall_side 1` while going right ends it that tick; `wall_side -1` while going right does not; a pounce straight up never ends at a wall.
  - `test_one_pounce_per_airtime`: a pounce started in the air uses the air verb; a second press after the first ends (cooldown passed) in the same airtime is refused until it lands.
  - `test_touching_a_hostile_marks_the_first_contact`: `pounce_hit` is false at the start, becomes true on the first tick with `touching_hostile`, and clears when the next pounce begins; contact outside a pounce is ignored.
  - `test_tackle_and_the_other_species_are_unchanged`: the slime's Tackle numbers and the existing burst tests stay green.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_profile` and `tools/run_tests.sh test_verb_runner`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `VerbRunner._begin`: for an `aimed` row the direction is `i.aim` normalised (the facing when ZERO) and the speed is `speed + run_fraction * |velocity.x|`, setting both velocity components (`verb_dir` the horizontal sign of the direction); a non-aimed row is as today. `_bursts` sets `pounce_hit` on `touching_hostile` while a burst runs; `_ended` gains `ends_at_wall and i.wall_side != 0 and s.verb_dir * float(i.wall_side) > 0.0`. `GroundAirStep` is unchanged: the burst already owns only the horizontal velocity, so gravity runs underneath.
- [ ] **Step 4: Run to see them pass, then the movement suites.** Run: `tools/run_tests.sh test_movement` and `tools/run_tests.sh test_verb_runner`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the wolf's pounce, a burst along the aim`).

### Task 2: The vault

**Files:**
- Create: `scripts/movement/vault_step.gd`
- Modify: `scripts/movement/move_input.gd`, `movement_profile.gd`, `verb_runner.gd`, `data/movement/wolf.tres`
- Test: `tests/test_vault_step.gd` (new), `tests/test_movement_profile.gd`

**Interfaces:**
- Produces on `MoveInput`: `step_ahead: float` (px height of a hard step in the direction of travel at the feet, 0 for none; a one-way ledge is never reported; the caller probes it). On `MovementProfile`: `vault_speed := 150.0`, `vault_step := 24.0`, `vault_margin := 6.0`; `wolf.tres` verbs `["vault"]` (the others have none). Produces `VaultStep.step(s: MoveState, i: MoveInput, p: MovementProfile) -> void` (applies the impulse and sets `launched = "vault"`).

- [ ] **Step 1: Write the failing tests.** `test_vault_step`: `test_a_step_of_24_is_hopped_with_the_impulse_and_the_speed_kept` (on the floor at 200 px/s, `step_ahead 24`: `velocity.y == -sqrt(2 * 1344 * 30)` within 0.01, `velocity.x` unchanged, `launched == "vault"`); `test_a_step_of_25_is_a_wall` (no impulse); `test_under_150_px_s_it_does_not_vault` (149.9 no, 150 yes); `test_it_never_vaults_in_the_air_or_with_no_step` (`on_floor` false, or `step_ahead 0`); `test_a_jump_press_on_the_same_tick_is_the_jump_not_a_vault` (a launch this tick wins: the vault adds nothing); `test_only_the_wolf_vaults` (the other profiles have no `vault` verb, so `VerbRunner.step` ignores the probe). `test_movement_profile`: the numbers.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_vault_step`. Expected: FAIL.
- [ ] **Step 3: Implement** `VaultStep.step`: it runs in `VerbRunner.step` after `GroundAirStep` (which resets `launched`), only for a profile with `"vault"`, on the floor, with `|velocity.x| >= vault_speed`, `0 < step_ahead <= vault_step` and nothing launched this tick.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_vault_step` and `tools/run_tests.sh test_movement`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the wolf vaults low steps`).

### Task 3: The skid

**Files:**
- Modify: `scripts/movement/move_state.gd`, `movement_profile.gd`, `ground_air_step.gd`
- Test: `tests/test_movement_ground.gd`

**Interfaces:**
- Produces `MoveState.skidding: bool` (set by `GroundAirStep._horizontal`) and `MovementProfile.skid_speed := 150.0`.

- [ ] **Step 1: Write the failing tests:** `test_the_wolf_skids_when_it_reverses_at_a_gallop` (the wolf at 230 px/s on the floor with the stick opposite: `skidding` true until the speed falls under 150, and the movement is the tuned one: brake and turn 0.1 s as before); `test_no_skid_in_the_air_or_with_the_stick_released_or_below_150`; `test_a_slime_and_a_biped_do_not_skid_at_their_top_speeds` (140 is under 150).
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_ground`. Expected: FAIL.
- [ ] **Step 3: Implement** the flag in `_horizontal` (on the floor, `dir` opposes the velocity, `|velocity.x| >= skid_speed`), cleared otherwise.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement`. Expected: PASS (every movement pin included).
- [ ] **Step 5: Commit** (`feat: flag the wolf's gallop skid`).

### Task 4: The wolf in the sandbox

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`, `scripts/movement/species_look.gd`
- Test: `tests/test_movement_sandbox.gd`, `tests/test_species_look.gd`

**Interfaces:**
- Produces on `MovementSandbox`: `STEP_LOW := Rect2(20, -16, 25, 16)` (a 16 px hard step at the left end for the vault), a hostile dummy (an `Area2D` named `Dummy` at x 120 to 140, y -50 to -10, for the pounce's contact), the `step_ahead` probe (a down-ray ahead of the feet in the direction of travel, hard solids only), `touching_hostile` from the dummy's overlap, and the wolf's look: a leaping pose stretched along its velocity while `verb == "pounce"`, a braced skid (leaning back) with dust puffs while `skidding`, and the airborne `windup` frame for the vault hop. `SpeciesLook.clip_for` gains `verb` handling for the wolf (`"pounce"` shows `windup`).

- [ ] **Step 1: Write the failing tests** (real collision, the wolf, `sb.set_profile("wolf")`; `scripted.aim` for the pounce):
  - `test_a_wolf_gallops_up_to_the_low_step_and_vaults_it`: from (95,-12) running left (set the starting speed to -200): it clears the 16 px step (its centre rises above y -12 - 10 while passing x 45 to 20) without a jump press, and keeps running.
  - `test_a_slow_wolf_stops_at_the_low_step_like_any_wall_and_a_40_px_ledge_is_not_vaulted`: at 100 px/s it does not vault; at 230 px/s toward the 40 px ledge at x 400 (from x 365) it stops at the wall.
  - `test_the_pounce_leaps_along_the_aim_and_lands`: standing at (100,-12), `aim` up-right and the button: it leaves the floor, travels 300 px/s along the aim for 0.35 s and lands; a second press at once is refused until 0.8 s after the end.
  - `test_the_pounce_marks_the_dummy`: aimed right from (60,-12) at the dummy: `state.pounce_hit` becomes true.
  - `test_the_pounce_ends_at_a_wall`: pouncing right into the slick block (a wall for the wolf) at (250,-12): the verb ends on contact.
  - `test_a_reversal_at_a_gallop_skids`: at 230 px/s the stick reversed: `state.skidding` is seen and dust puffs appear (nodes in the `dust` group) and fade away within 0.5 s.
  - `test_the_pounce_pose_follows_the_leap`: during the leap the sprite's rotation is within 0.3 rad of the velocity's angle (mirrored with `flip_h` going left).
  - `test_the_other_species_are_unchanged`: the slime still tackles on the same button and the spider still zips.
  - `test_species_look`: `clip_for("wolf", false, ..., "pounce")` is `"windup"`; the existing wolf clip tests stay.
- [ ] **Step 2: Run to see them fail.** Run: `tools/run_tests.sh test_movement_sandbox` and `tools/run_tests.sh test_species_look`. Expected: FAIL.
- [ ] **Step 3: Implement** the terrain, the dummy (monitoring `Area2D` with a collision shape; `touching_hostile = overlaps_body(body)`), the `step_ahead` probe (cast down from 6 px in front of the body's leading edge, from above the step height, over the feet; the height is the feet line minus the hit; 0 for nothing or for a hit under 1 px; ledges and slick count as hard), the skid dust (small `ColorRect` puffs tweened up and faded, added to the `dust` group), the pounce pose (rotate and stretch along the velocity) and the skid lean. Fill `i.step_ahead` and `i.touching_hostile` every tick for the wolf.
- [ ] **Step 4: Run to see them pass.** Run: `tools/run_tests.sh test_movement_sandbox` and `tools/run_tests.sh test_species_look`. Expected: PASS.
- [ ] **Step 5: Commit** (`feat: the wolf pounces, vaults and skids in the sandbox`).

### Task 5: Specs and the full suite

**Files:**
- Modify: `docs/superpowers/specs/2026-10-04-species-movesets-design.md`

- [ ] **Step 1: Update the Wolf bullets** to what was built (the pounce row and its numbers, the aim and wall rule, the contact flag; the vault numbers and the probe; the skid flag) and Art needs (a skid frame, pounce frames, a vault frame; `windup` and `charge` stand in). Record the open items: the pounce's combat effect and the stun are the wiring plan's; the wolf's 46 px run-up audit of ledge approaches and pad-stick air momentum stay open.
- [ ] **Step 2: Run the whole suite.** Run: `tools/run_tests.sh`. Expected: `PASS: N tests` with N above the 2198 baseline, no `SCRIPT ERROR` or `Parse Error`.
- [ ] **Step 3: Commit** (`docs: spec the wolf's moveset as built`).
