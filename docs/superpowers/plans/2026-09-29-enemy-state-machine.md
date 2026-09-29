# Enemy State Machine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, inline; Sean's standing choice) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fold `enemy.gd`'s twelve loose behaviour fields into one `_state` / `_state_t` / `_aim` per enemy with a `kind` resolved once, with no change to how any creature plays.

**Architecture:** In place in `scripts/enemies/enemy.gd`. A per-tick trace recorder and a scenario driver (committed, not a `test_` file) record every creature's behaviour on the CURRENT code; a compact committed characterization pins it; the fold then happens in one commit that ports every reader and writer, followed by pure restructurings, each gated by the differential and the suite.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`, ~185 s full), Python 3 for the trace diff.

**Spec:** `docs/superpowers/specs/2026-09-29-enemy-state-machine-design.md` (three debate rounds and a verification pass). Read it first; it is the authority for tokens, tick order, resets and the gravity table.

## Global Constraints

- `_state` tokens: swooper `idle/hover/warn/dive/climb`; charger, lizard, crab, snake `""/windup/charge/rest`; spitter `""/puff`; drifter `""/flash`; walker and dropper never write it. Initial value `"idle"` for the swooper, `""` otherwise.
- `charge_state()` returns `_state` for the charger and snake kinds and `""` for every other kind; `swoop_state()` returns `_state` for the swooper and `"idle"` for every other kind.
- `_clear_inactive()` (every non-active non-DYING tick): `_state = ""` for every kind except the swooper; never touches `_state_t`, `_aim`, `_spit_cd`, `_puff_t`. `_on_died` (synchronous, inside `if def.predatable`): the same clear AND the swooper's `_state = "idle"`.
- Tick order, RNG draws (bat: idle→hover and every climb end, including climb→idle), timers (decrement then compare `<= 0.0` at today's point) and one-tick lags are unchanged. The gravity rules per kind and status are unchanged (a stunned bat falls, a stunned moth holds, a stunned snake holds, a stunned hanging spider falls).
- `EnemyState.pick`'s signature, `frame_name()`'s output and `Enemy`'s public constants and `_speed()` are unchanged.
- No attribution lines in commit messages.

## Review Focus

1. A stunned bat resuming its swoop with its remaining timer and RNG stream (the inactive clear must not touch a swooper).
2. A charger or spitter falling through to `_walk` must never leak a token into `charge_state()` / `pick`.
3. A bat killed in `warn` must not flash while downed; a lizard's `charge_state()` is `""` synchronously after a lethal hit.
4. The serpent (no sheet, no animator) must not crash `anim_state()`.
5. The trace differential must be proved able to fail (sampled mutations).

---

### Task 1: Seams on the OLD code

**Files:** Modify `scripts/enemies/enemy.gd`, `tests/test_grotto_creatures.gd`.

- [ ] Add `func seed_rng(n: int) -> void: _rng.seed = n`; rename `_telegraphing()` to public `telegraphing()` (update its two internal callers and the three test calls `test_grotto_creatures.gd` `:78`, `:184`, `:187`); add `var _anim_state := ""` written in `_draw_sheet_frame` (`_anim_state = state`) and `func anim_state() -> String: return _anim_state`.
- [ ] Add a test in `tests/test_enemy_traces_seams.gd`... (fold into `test_grotto_enemy_flags.gd`): `seed_rng` makes two bats draw the same jitter; `anim_state()` is `""` for the serpent and `"fly"`/`"hover"`… for a bat with a sheet; `telegraphing()` is true during a lizard windup.
- [ ] Run the full suite green; commit `refactor: public seams on Enemy (seed_rng, telegraphing, anim_state)`.

### Task 2: The recorder, the driver, the characterization

**Files:** Create `tests/support/enemy_scenarios.gd` (scenario data), `tests/support/enemy_recorder.gd` (runs a scenario, returns the per-tick trace), `tests/support/enemy_trace_dump.gd` (a `GutTest` without the `test_` prefix: writes `.tmp/enemy-trace/<label>.json`, label from env `TRACE_LABEL`), `tools/enemy_trace.sh`, `tools/enemy_trace_diff.py`, `tests/test_enemy_traces.gd`.

- [ ] Scenario data: each `{name, creature, start, ticks, seed, player: [[tick, Vector2]], acts: [...]}` with acts `["stun", tick, seconds]`, `["slow", tick, seconds]`, `["stun_when", key, value, delay, seconds]`, `["kill_when", key, value, delay]`, keys among `charge_state`, `swoop_state`, `anim_state`, `telegraphing`. Floor top at y 6 (enemy at y 0). Scenarios: serpent walker patrol and chase; toad spit; toad stunned right after spitting; lizard plain; lizard stunned mid-windup / mid-charge / mid-rest; lizard killed in windup; crab plain; bat plain; bat stunned in warn; bat stunned in dive; bat killed in warn; bat alert lost in hover; bat slowed; spider drop; stunned hanging spider; moth plain; moth stunned in flash; moth player leaves mid-flash; snake plain; snake stunned in coil / lunge / retreat. Player positions off exact thresholds (not 80.0 or 120.0 px away).
- [ ] Recorder: `for tick in ticks: await get_tree().physics_frame` then apply this tick's scripted moves, then sample `{t, pos, vel, facing, charge, swoop, anim, tele}` plus new hazards (scan group `hazards`, record position and class once) and world events (`spore_puff`) and stub-player hits/poisons with the tick. Free hazards and enemies between scenarios. `seed_rng` right after `add_child`.
- [ ] Dump test writes the whole trace as JSON (positions rounded to 0.01). Record the BASELINE on the untouched code: `TRACE_LABEL=baseline tools/enemy_trace.sh`. `tools/enemy_trace_diff.py baseline <label>` exits non-zero on any difference and prints the first differing scenario/tick.
- [ ] `tests/test_enemy_traces.gd`: for each scenario, the run-length transition list and events (literal expected data generated once from the baseline by `tools/enemy_trace_diff.py --emit` and pasted into `tests/support/enemy_trace_expected.gd`), asserted after running the scenario in the test. Plus a small `use_sheet = false` test pinning `frame_name()` (toad windup → `toad_spit`, spider `spider_hang` / `spider_crawl`).
- [ ] Sampled mutation proof (each must fail the characterization or the differential, then be reverted): charger windup one tick late (`CHARGE_WINDUP` 0.5 → 0.52), bat dive aim taken at warn start, snake lunge speed 300 → 295, moth interval reset removed, bat climb draw only when going to hover. Record the results in the ledger.
- [ ] Full suite green; commit `test: a per-tick characterization of every enemy behaviour`.

### Task 3: The fold

**Files:** Modify `scripts/enemies/enemy.gd`, `tests/test_grotto_creatures.gd`, `tests/test_death_fx.gd`.

- [ ] One commit ports EVERY reader and writer: add `var _state := ""`, `var _state_t := 0.0`, `var _aim := Vector2.ZERO`, `enum Kind` and `var kind` resolved in `setup()` (snake by id, `_on_ceiling`, drifter, flight, armored charger, spitter, else walker) with the initial `_state`; port `_charger_act`, `_snake_act`, `_swoop_act`, `_spitter_act`, `_drift_act` (`_puff_windup` becomes `_state == "flash"` with `_state_t`), the two clears (`_clear_inactive()` called at the old inactive branch; the died handler's body per the constants above), `charge_state()`, `swoop_state()`, `frame_name()` (its toad case reads `_state == "puff"`), `_draw_sheet_frame` (`_state == "puff"` for the spit windup argument), `telegraphing()`; delete the eleven dead fields; edit the three test writes (`s._charge = "charge"` → `s._state = "charge"`; `m._puff_windup = 0.3` → `m._state = "flash"` and `m._state_t = 0.3`; `lizard._charge = "windup"` → `lizard._state = "windup"`).
- [ ] Add the selection test (`tests/test_enemy_kind.gd`): a literal id → kind map for every shipped def (`bat`/`spore_moth`/… ; `serpent` and `water_pool` walker), and the pairwise assertions (a non-snake `ceiling_walk` def has none of `flight`, `drifter`, `armored_charger`, spit damage; none has both `armored_charger` and spit damage).
- [ ] `TRACE_LABEL=fold tools/enemy_trace.sh && tools/enemy_trace_diff.py baseline fold` must report no difference; the full suite green; commit `refactor: one state, one timer and one aim per enemy, resolved by kind`.
- [ ] Restructure commits (each with the differential and suite green): `_act` and the gravity block as `match kind` (gravity rules exactly per the spec table); `telegraphing()` as a `match kind`; a final read for dead code. Commit each.

### Task 4: Gate

- [ ] Real playtest via the game launch: each creature's telegraph, attack, stun and death (screenshots not needed; the trace is the referee, but launch the game once and watch a bat, a toad, a lizard and the Grotto's moth and snake).
- [ ] Final whole-branch review (opus), one fix pass test-first, merge into main, push, remove the worktree, launch the game.
