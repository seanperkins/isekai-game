# Enemy Behaviour State Machines — Design

Status: revised after debate round 1 (2026-09-29). Answers Sean's question "We will use a state machine for
enemies as well?" (the slime already has `SlimeState`). A behaviour-preserving refactor of
`scripts/enemies/enemy.gd`, in three phases: **A** consolidate in place behind a characterization referee,
**B** extract the four real machines, **C** (separate commits) two small snake fixes.

## Goal

`Enemy` (586 lines) mixes identity and damage, the shared senses, status handling, the visual, and seven
behaviours. The behaviours live in twelve loose fields (`_charge`, `_charge_t`, `_swoop`, `_swoop_t`, `_dive_dir`,
`_spit_windup`, `_spit_cd`, `_puff_t`, `_puff_windup`, `_lunge_dir`, `_on_ceiling`, plus the shared `_home_x`,
`_home_y`, `_anchor`, `_rng`) and a precedence chain repeated in four places (`_act`, the gravity block, `_telegraphing`,
and two copies of the reset). Each new creature added a branch in all four. At most one of the timer fields is
live for any creature (the snake already reuses `_charge`/`_charge_t`); this makes that explicit: one named state,
one timer, one aim vector per enemy, chosen by a `kind` resolved once, so a new creature is one data flag and one
branch (or class) rather than four edits.

Non-goals: no change to how any creature plays (numbers, timings, tick order, RNG draws, precedence, telegraphs,
which fields survive a stun); no new creature; no change to `EnemyStatus`, `DeathFx`, `EatCover`, contact damage or
the sheets; no generic behaviour-tree framework; no change to `EnemyState.pick`'s signature or `frame_name()`.

## Decisions

| Topic | Decision |
|---|---|
| Phases | **A** (in place): add public seams, record the characterization, fold the fields into `_state` / `_state_t` / `_aim`, resolve a `kind` once, express gravity as a per-kind/per-status table, one `on_inactive_tick()` and one `on_died()`. **B**: extract Charger, Swooper, Drifter and Snake into typed `RefCounted` classes (four, not seven: the Walker stays `Enemy._walk`, the Dropper stays the `_on_ceiling` flag, the Spitter stays a small interrupt on `Enemy`). **C**: the snake's two fixes, each its own commit, test first |
| State names | The public strings stay exactly today's: `charge_state()` returns `""`, `"windup"`, `"charge"`, `"rest"`; `swoop_state()` returns `idle`, `hover`, `warn`, `dive`, `climb`; the snake keeps `windup` (coil), `charge` (lunge), `rest` (retreat), `""` (hide) so `EnemyState.pick`, `charge_state()` and every test are untouched. Table names below give the design word and the public string |
| Selection | `kind` is resolved once in `setup()` (so it exists before `_ready` builds the body) from `_act`'s precedence: snake (by id), ceiling walker (`ceiling_walk` capability), drifter, flight, armored charger, spitter (spit damage), else walker. After a Dropper drops it acts as a walker, which is what today's chain does because no shipped def combines `ceiling_walk` with the later flags; a selection test asserts that for every shipped def |
| Boundary | Extracted behaviours hold a typed `enemy: Enemy`. They may call the enemy's movement and sense methods (`_speed()`, `_blocked_ahead()`, `can_see()`, `is_alert()`) and write `enemy.velocity` and `enemy.facing` (never a copy: the player's rear-tackle check and `DeathFx` read `facing`). They read `_home_x`, `_home_y` and `_anchor` from the enemy lazily (those are captured in `_ready`, after tests place the body) |
| Referee | A characterization test is written FIRST against the current code, samples EVERY frame, compares positions to 0.01 px and records events, and each constant it claims to pin is mutated once to prove it fails the test |
| Timers | Each behaviour keeps today's exact arithmetic: decrement then compare `<= 0.0` at the same point in the tick, in the same order. There is no shared `state_t` auto-decrement. Timers that are not state timers (the moth's interval, the spit cooldown, the slow) are separate |

## What changes for the referee to work: public seams first (Phase A step 1)

The current code exposes no state names for the toad, spider, moth or walker. Before recording anything, Phase A
step 1 adds seams to the OLD code (no behaviour change) and the trace uses only public observables:

- `behaviour_state() -> String`: derived from today's fields (`patrol`/`chase`, `windup`/`charge`/`rest`, `puff`,
  `hang`/`crawl`, `drift`/`flash`, swoop names, snake names), written once now and kept through the refactor.
- `seed_rng(n: int)`: reseeds the enemy's RNG (today `_ready` seeds it from `get_instance_id()`); the trace calls it
  right after `add_child`, before any behaviour draws.
- `telegraphing() -> bool`: the public name for `_telegraphing()` (tests call it at `test_grotto_creatures.gd`).
- Trace record per frame: `behaviour_state()`, `charge_state()`, `swoop_state()`, `frame_name()`, `telegraphing()`,
  `facing`, `velocity`, `global_position`, and events: hazards spawned (`SpitBlob`/`SporePuff`, with position), the
  `spore_puff` world event, and player hits and poisons from the stub. Hazards are freed between scenarios.

## The per-tick order (`_physics_process`), written down so the refactor cannot reorder it

1. `status.update(delta)`; 2. `_anim_t += delta` (the bat's idle bob and the moth's height read it); 3. GONE: free and return;
4. `_spit_cd` and `_slow` decrement (every status except GONE); 5. ACTIVE with a player: `_sense`, then the behaviour's
`update`; 6. otherwise, unless DYING (a death effect owns the body): `velocity.x = 0` and `on_inactive_tick()`;
7. gravity per the table below; 8. `move_and_slide`; 9. contact damage; 10. `_hurt_t`; 11. `_update_visual`.

Two resets, exactly as today, not one:

- **`on_inactive_tick()`** (stun, downed, no player; every tick): clears the charge state (lizard, crab AND the snake,
  mid-charge or mid-rest included), the spit windup and the moth's flash. It does NOT touch `_swoop`, `_swoop_t`,
  `_dive_dir`, `_spit_cd` (which keeps ticking), `_puff_t` (which freezes) or `_lunge_dir`. So a bat stunned in
  `warn` resumes `warn` with its remaining time; a moth re-flashes on its first active tick in range.
- **`on_died()`** (synchronous in the died handler; `test_death_fx` asserts `charge_state() == ""` with no await):
  everything above AND `_swoop = "idle"`, so a bat killed in `warn` does not flash while it lies downed.

## Gravity and the stun hold, per kind and status (today's rules; a test per row)

| Kind | ACTIVE | STUNNED | DYING / DOWNED |
|---|---|---|---|
| walker, charger, spitter | falls | falls | falls |
| swooper (flight) | no gravity | **falls** | falls |
| dropper on its ceiling | no gravity, velocity 0 | **falls** (`_on_ceiling` stays true; after the stun it sits where it landed in `hang` with no gravity until prey passes: today's behaviour, pinned) | falls |
| drifter | no gravity | holds, `velocity.y = 0` | falls |
| snake on its tether | no gravity | holds, `velocity = 0` | falls |

An ACTIVE enemy with no player takes the inactive branch (step 6) and still gets its ACTIVE gravity treatment.

## The state tables (today's behaviour, named)

Every number is the existing constant; `Enemy` keeps its public constants as aliases where anything else reads them
(`SPIT_*`, `WARN_SECONDS`, `DIVE_SECONDS`, `CLIMB_SECONDS`, `CHARGE_*`, `ALERT_MEMORY`, `BASE_SPEED`, `CONTACT_MARGIN`,
`LEDGE_DEPTH`, `BODY_SIZE`, `BODY_BOTTOM`, `SLOW_SECONDS`, `PUFF_*`, `CLIPS`); `_speed()` keeps its name and place.

| Kind | States (design word → public string) | Transitions and one-tick lags to preserve | Telegraphs |
|---|---|---|---|
| Walker (`Enemy._walk`) | patrol, chase | alert and \|dy\| < 48: chase along the CURRENT facing (turns only when \|dx\| > 32; holds at ledges and walls); else patrol home ±48 at half speed, reversing at a wall or ledge. `_blocked_ahead` is false while airborne | none |
| Charger | walk → `""`, windup, charge, rest | walk → windup when alert, \|dy\| < 24, 32 < ahead ≤ 120 (0.5 s, velocity 0 that tick); windup → charge (0.6 s, 3× speed; movement starts the NEXT tick) → rest when the time is up or blocked (1.0 s) → walk; the rest→walk tick returns true and it can wind up again on the very next tick. In `walk` it returns false and the Walker moves it | windup |
| Spitter (on `Enemy`) | walk, puff | alert, cooldown over, within 90: puff (0.4 s, faces the player, velocity 0) → on the launch tick lob the blob (5 s cooldown) and return true; the NEXT tick it returns false and the toad walks or chases. There is no `recover` state: the spit pose is only the predicate `_spit_cd > SPIT_COOLDOWN − SPIT_POSE_SECONDS` used by `pick` and `frame_name()` | puff |
| Swooper | idle, hover, warn, dive, climb | idle bobs (`sin(_anim_t)`); alert → hover above the player (speed-capped, 0.8 s + jitter); alertness lapsing → idle; → warn (0.3 s) → dive at where the player is WHEN WARN ENDS (0.6 s, 2.2×, velocity 0 on the transition tick, ends on floor or wall) → climb (0.8 s, velocity (−dive.x·speed·0.5, −speed·0.8)) → hover or idle. The timer `_swoop_t` decrements unconditionally before the match; the RNG draws once on idle→hover AND on every climb end, including climb→idle | warn |
| Dropper (flag on `Enemy`) | hang → falls | on the ceiling: velocity 0; alert and \|dx\| < 40 and the player below it: clear the flag on that tick and return (gravity acts this tick, the walker moves from the NEXT tick) | none |
| Drifter | drift, flash | drift about home ±96 at 60 % speed, holding home height ±14 (turning at walls, movement set before the puff logic so the flash does not stop it); in range (≤ 320) and in sight: interval 3.0 s counts down, at ≤ 0.4 s flash (0.4 s) then drop a puff 12 px under itself and reset the interval; leaving range or sight for one tick resets the interval to the full 3 s and cancels the flash | flash |
| Snake | hide `""`, coil `windup`, lunge `charge`, retreat `rest` | `_charge_t` decrements first every tick; hide: velocity 0, alert and \|dx\| < 40 and 0 < dy ≤ 110 → coil (0.5 s); coil → lunge along the line to where the player is at the end of the coil (0.3 s or reach ≥ 80 from the anchor, 300 px/s; velocity starts the tick AFTER the coil ends and the lunge moves once more on the tick it decides to retreat, ending about 85 px out) → retreat to the anchor at 100 px/s (ends by distance ≤ 3) → hide; off the anchor with nothing pending (a stun cleared the charge): retreat | coil |

## Ownership of the shared state (Phase A/B)

- On `Enemy` throughout: `_rng` (seed via `seed_rng`), `_anim_t`, `_home_x`, `_home_y`, `_anchor`, `_spit_cd`, `_slow`, `_hurt_t`,
  `facing`, `_on_ceiling`, `_spit_damage`. The Drifter's `_puff_t` and the Swooper's `_dive_dir` move to their behaviours
  in Phase B; nothing else does.
- `receive_tackle`'s stun reaches the behaviour only through step 6 (`on_inactive_tick`), as today.
- The legacy sprite path (`frame_name()` when a creature has no sheet) reads `_spit_windup`, `_spit_cd` and `_on_ceiling`; it
  keeps reading them (through the getters) so it is unchanged.

## Testing approach

- **Characterization first** (`tests/test_enemy_traces.gd`, recorded against current code, unchanged through every step,
  transition lists and per-frame arrays inline, no JSON file): for each of bat, toad, lizard, crab, spider, spore moth,
  pale moth, vine snake a scenario of approach, hold, retreat, pass under, stand at a distance, with scenario positions
  kept off exact thresholds (the snake's 80 px reach and the charger's 120 px range are knife-edges in float32);
  plus the interruption cases the referee must not miss: stun mid-windup, mid-charge, mid-rest, mid-warn, mid-dive,
  mid-flash and mid-coil; a slowed creature; alert lost mid-hover; a lethal hit mid-telegraph; a toad stunned right after
  spitting (its cooldown elapses during the stun); a toad walking during the spit pose; a stunned hanging spider; a
  charger re-winding after rest; a bat's climb returning to hover or idle; patrol home bounds. It runs on
  `wait_physics_frames` (not wall-clock), samples every frame and compares positions to 0.01 px.
- **The referee is proved:** each timer and precedence constant is mutated once and the trace must fail; a constant
  that fails nothing gets its own assertion (the spit pose window, the puff interval, `SPIT_TICK`/`SPIT_SECONDS` are
  covered by event assertions, not positions).
- Every existing enemy suite stays green; only the tests that poke behaviour privates change to public names
  (`_charge` → `charge_state()`/`behaviour_state()`, `_on_ceiling` → a public getter, `_puff_windup` and `_telegraphing()` →
  `telegraphing()`, `_spit_cd` stays a field on `Enemy`): `test_art_visuals.gd:46,50`, `test_grotto_creatures.gd:128,161,183`
  (plus its `_telegraphing()` calls at 78, 184, 187), `test_death_fx.gd:196`. All 30 private `Enemy` references in eight
  test files are listed in the plan; `_speed()` keeps its name.
- Suites that read `Enemy` constants or drive enemies and must be run every step: `test_enemy*`, `test_grotto_*`,
  `test_pale_moth`, `test_tuning` (pins `SPIT_COOLDOWN`, `SPIT_TICK`, `SPIT_RANGE`, `WARN_SECONDS`, `DIVE_SECONDS`,
  `CLIMB_SECONDS`), `test_spore_cloud`, `test_tackle_reach`, `test_hit_fairness`, `test_enemy_sheets`,
  `test_death_cause`, `test_death_fx`, `test_art_visuals`.
- Selection test: for every shipped def the resolved `kind` equals what the old `_act` chain would have chosen, and no
  def combines `ceiling_walk`, `armored_charger` and spit damage.
- Each Phase B class gets direct tests against a real `Enemy` (physics-driven), not a stub, so a state is asserted by name.

## Phase C: the snake's two fixes (after A and B, each its own commit, test first, trace re-recorded for the snake only)

1. Slow: lunge and retreat speeds are multiplied by 0.5 while the snake is slowed (they use `LUNGE_SPEED` and
   `RETREAT_SPEED` today, not `_speed()`, so a thread or Spore Cloud does nothing to them). A slowed lunge then covers
   150 × 0.3 = 45 px: the timer, not the 80 px reach, bounds it (an accepted design change: a slowed snake strikes shorter).
2. `RETREAT_TIMEOUT` = 2.0 s (the slowest legitimate retreat is 85 px at 50 px/s = 1.7 s): on expiry it steps toward the
   anchor no further than rock allows (it does not teleport through rock); an anchor inside rock therefore cannot hang it in `rest`.

## Build order

1. Phase A: the seams and the referee (recorded on old code, mutation-proved); then, one commit each with the suite and the
   trace green: fold `_charge`/`_swoop`/`_spit_windup`/`_puff_windup` into `_state`/`_state_t`/`_aim` and add `kind`;
   gravity table; `on_inactive_tick()`/`on_died()`; public getters; update the nine private pokes.
2. Phase B: Charger, then Swooper, then Drifter, then Snake, each extracted with the trace and suite green after it and a
   per-step reader checklist (which of `charge_state`, `swoop_state`, `telegraphing`, `_draw_sheet_frame`, `on_died`,
   `frame_name` now read the behaviour).
3. Phase C: the snake fixes.
4. Real playtest of each creature (telegraph, attack, stun, death), review, merge.
