# Enemy Behaviour State Machines — Design

Status: revised after debate round 2 (2026-09-29). Answers Sean's question "We will use a state machine for
enemies as well?" (the slime already has `SlimeState`). A behaviour-preserving refactor of `scripts/enemies/enemy.gd`:
each enemy gets one named state, one timer and one aim vector, chosen by a `kind` resolved once.

## Goal

`Enemy` (586 lines) mixes identity and damage, the shared senses, status handling, the visual and seven behaviours. The
behaviours live in twelve loose fields (`_charge`, `_charge_t`, `_swoop`, `_swoop_t`, `_dive_dir`, `_spit_windup`,
`_puff_t`, `_puff_windup`, `_lunge_dir`, and the shared `_spit_cd`, `_on_ceiling`, `_home_*`, `_anchor`, `_rng`) and a
precedence chain repeated in four places (`_act`, the gravity block, `_telegraphing`, two copies of the reset). Each new
creature added a branch in all four. At most one of those timers is live for any creature (the snake already reuses
`_charge`/`_charge_t`). This folds them into `_state` / `_state_t` / `_aim`, resolves `kind` once, and makes each of the
four sites one `match kind`, so a new creature is a data flag and one branch per site, not a hunt through the file.

Non-goals: no change to how any creature plays (numbers, timings, tick order, RNG draws, precedence, telegraphs, which
state survives a stun); no new creature; no change to `EnemyStatus`, `DeathFx`, `EatCover`, contact damage or the
sheets; no change to `EnemyState.pick`'s signature or to `frame_name()`; no behaviour classes (see "Later").

## Decisions

| Topic | Decision |
|---|---|
| Scope | In place, in `enemy.gd`. `_state: String`, `_state_t: float`, `_aim: Vector2` (folding `_dive_dir` and `_lunge_dir`) stay on `Enemy` for good. `_spit_cd`, `_slow`, `_anim_t`, `_home_x`, `_home_y`, `_anchor`, `_rng`, `_hurt_t`, `facing` and `_on_ceiling` (the Dropper flag) stay separate fields as today. The Walker stays `_walk`; the Dropper stays the flag; the Spitter stays a short interrupt |
| Public state strings | Unchanged, so `EnemyState.pick` and every test are untouched. `charge_state()` returns `_state` for the charger, lizard, crab and snake kinds (`""`, `windup`, `charge`, `rest`) and `""` for every other kind; `swoop_state()` returns `_state` for the swooper (`idle`, `hover`, `warn`, `dive`, `climb`) and `"idle"` for every other kind (today it never changes for them). The snake keeps `windup` (coil), `charge` (lunge), `rest` (retreat), `""` (hide) |
| Selection | `kind` is resolved once in `setup()` (before `_ready` builds the body) from `_act`'s precedence: snake (by id), ceiling walker (`ceiling_walk`), drifter, flight, armored charger, spitter (spit damage), else walker. The old chain is deleted with the fold, so the selection test carries a literal map of def id to kind. Only one pair in the old chain has two machines live at once (an armored charger with spit falls through from `_charger_act` to `_spitter_act`), which one `_state` cannot hold: the test asserts, for every shipped def, that no pair of `ceiling_walk`, `armored_charger` and spit damage co-occurs |
| Initial value | Set in `setup()`: `"idle"` for the swooper, `""` for every other kind |
| Gravity | Stays one five-line `match kind` beside today's block; the table below is scenario design, not a data structure |
| The referee | A physics-tick recorder and a compact characterization test written FIRST against the current code (below) |
| Timers | Each kind keeps today's exact arithmetic: decrement then compare `<= 0.0` at the same point in the tick. There is no shared auto-decrement. Timers that are not state timers (the moth interval `_puff_t`, the spit cooldown, the slow) stay separate |
| Later | Extracting Charger, Swooper, Drifter and Snake into `RefCounted` classes is a separate decision, taken only if a creature with a genuinely new movement arrives or `enemy.gd` is still hard to work in after this. Phase A makes it mechanical. The snake's two small fixes are follow-ups (below), not part of this work |

## Seams added to the OLD code first (Phase A step 1: no behaviour change, suite green)

The current code exposes no way to observe several states, or to set them up, without private fields. Before any
recording, these public seams are added and the tests that poke privates are moved onto them (still green on unchanged code):

- `seed_rng(n: int)`: reseeds the enemy's RNG (`_ready` seeds it from `get_instance_id()`); called right after `add_child`,
  before any draw. It matters only to the bat (draws on idle→hover and on every climb end, including climb→idle).
- `telegraphing() -> bool`: the public name for `_telegraphing()`; `test_grotto_creatures` calls it at three places.
- `anim_state() -> String`: the clip the enemy is playing (the `EnemyState.pick` result `_draw_sheet_frame` already computes,
  read from the animator); the referee runs with sheets ON so the argument wiring is observed.
- `force_state(name: String, seconds := 0.0)`: sets up a state for tests and scripted scenes (today it writes `_charge`/`_charge_t`,
  or `_puff_windup` for a moth). It replaces the three test writes `test_grotto_creatures.gd:161` (`_charge`), `:183`
  (`_puff_windup`) and `test_death_fx.gd:196` (`_charge`), which a getter cannot do and which would otherwise stop parsing when
  the fields are folded. `test_art_visuals.gd:50` writes `_on_ceiling`, which stays a field, and `:46` writes `_spit_cd`, which stays.

## The per-tick order (`_physics_process`), written down so the fold cannot reorder it

1. `status.update(delta)`; 2. `_anim_t += delta` (the bat's idle bob and the moth's height read it); 3. GONE: free and return;
4. `_spit_cd` and `_slow` decrement (every status except GONE); 5. ACTIVE with a player: `_sense`, then the behaviour's step;
6. otherwise, unless DYING (a death effect owns the body): `velocity.x = 0` and `_clear_inactive()`; 7. gravity by `match kind` and
status; 8. `move_and_slide`; 9. contact damage; 10. `_hurt_t`; 11. `_update_visual`.

Two clears, exactly as today, gated by kind (a bare `_state = ""` for a bat would hit no branch of its `match`):

- **`_clear_inactive()`** (stun, downed, no player; every such tick): for every kind EXCEPT the swooper, `_state = ""` (which clears the
  lizard's and crab's and the snake's charge, mid-charge and mid-rest included, the toad's spit windup and the moth's flash). It never
  touches `_state_t`, `_aim`, `_spit_cd` (which keeps ticking) or the moth's `_puff_t` (which freezes). A bat stunned in `warn`
  resumes `warn` with its remaining time; a moth re-flashes on its first active tick in range.
- **`_on_died()`** (synchronous in the died handler, inside `if def.predatable`; `test_death_fx` asserts `charge_state() == ""`
  with no await): `_clear_inactive()`'s effect AND the swooper's `_state = "idle"`, so a bat killed in `warn` does not flash while it lies downed.

## Gravity and the stun hold, per kind and status (today's rules)

| Kind | ACTIVE | STUNNED | DYING / DOWNED |
|---|---|---|---|
| walker, charger, spitter | falls | falls | falls |
| swooper (flight) | no gravity | **falls** | falls |
| dropper on its ceiling | no gravity, velocity 0 | **falls** (`_on_ceiling` stays true; after the stun it sits where it landed in `hang` with no gravity until prey passes: today's behaviour, pinned) | falls |
| drifter | no gravity | holds, `velocity.y = 0` | falls |
| snake on its tether | no gravity | holds, `velocity = 0` | falls |

An ACTIVE enemy with no player takes the inactive branch (step 6) and still gets its ACTIVE gravity treatment.

## Scenario notes: today's behaviour by kind (the tests are the truth; this is not maintained documentation)

| Kind | States (public string) | Transitions and one-tick lags to preserve | Telegraphs |
|---|---|---|---|
| Walker (`_walk`) | patrol, chase | alert and \|dy\| < 48: chase along the CURRENT facing (turns only when \|dx\| > 32; holds at ledges and walls); else patrol home ±48 at half speed, reversing at a wall or ledge. `_blocked_ahead` is false while airborne | none |
| Charger | `""`, windup, charge, rest | walk → windup when alert, \|dy\| < 24, 32 < ahead ≤ 120 (0.5 s, velocity 0 that tick); windup → charge (0.6 s, 3×; movement starts the NEXT tick) → rest when the time is up or blocked (1.0 s) → walk; the rest→walk tick returns true and it can wind up again on the very next tick; in walk it returns false and `_walk` moves it | windup |
| Spitter | walk, puff | alert, cooldown over, within 90: puff (0.4 s, faces the player, velocity 0) → on the launch tick lob the blob (5 s cooldown) and return true; the NEXT tick it returns false and the toad walks or chases. There is no `recover` state: the spit pose is only the predicate `_spit_cd > SPIT_COOLDOWN − SPIT_POSE_SECONDS` used by `pick` and `frame_name()` | puff |
| Swooper | idle, hover, warn, dive, climb | idle bobs (`sin(_anim_t)`); alert → hover above the player (speed-capped, 0.8 s + jitter); alertness lapsing → idle; → warn (0.3 s) → dive at where the player is WHEN WARN ENDS (0.6 s, 2.2×, velocity 0 on the transition tick, ends on floor or wall) → climb (0.8 s, velocity (−dive.x·speed·0.5, −speed·0.8)) → hover or idle. The timer decrements unconditionally before the match | warn |
| Dropper | hang → falls | on the ceiling: velocity 0; alert and \|dx\| < 40 and the player below it: clear the flag on that tick and return (gravity acts this tick, the walker moves from the NEXT tick) | none |
| Drifter | drift, flash | drift about home ±96 at 60 % speed holding home height ±14 (turning at walls; movement is set before the puff logic, so the flash does not stop it); in range (≤ 320) and in sight: the 3.0 s interval counts down, at ≤ 0.4 s flash (0.4 s) then drop a puff 12 px under itself and reset; leaving range or sight for one tick resets the interval to 3 s and cancels the flash | flash |
| Snake | `""` (hide), windup (coil), charge (lunge), rest (retreat) | `_state_t` decrements first every tick; hide: velocity 0, alert and \|dx\| < 40 and 0 < dy ≤ 110 → coil (0.5 s); coil → lunge along the line to where the player is at the end of the coil (0.3 s or reach ≥ 80 from the anchor, 300 px/s; velocity starts the tick AFTER the coil ends and the lunge moves once more on the tick it decides to retreat, ending about 85 px out) → retreat to the anchor at 100 px/s (ends by distance ≤ 3) → hide; off the anchor with nothing pending (a stun cleared the charge): retreat | coil |

## Testing approach

- **The recorder.** A helper connects to `get_tree().physics_frame` and samples once per physics tick (asserting each sample
  advances `Engine.get_physics_frames()` by exactly 1: `await wait_physics_frames(1)` spans two ticks in GUT, so it is never used
  to sample). Scripted mid-scenario moves (player position, stun, slow, lethal hit) fire on tick numbers from the same recorder,
  never on wall-clock waits. Each sample records `global_position`, `velocity`, `facing`, `charge_state()`, `swoop_state()`,
  `anim_state()` (sheets ON), `telegraphing()`, and events stamped with the TICK: hazards spawned (`SpitBlob`, `SporePuff`, with
  position), the `spore_puff` world event, player hits and poisons from the stub. Hazards are freed between scenarios.
- **The differential (one-off, not committed).** The driver runs every scenario and writes the full per-tick trace (0.01 px) to
  `.tmp/` on the OLD commit; after each Phase A commit the same driver is diffed against it. The driver is committed; the file is not.
- **The committed characterization** (`tests/test_enemy_traces.gd`) asserts compactly what a reader can check: per scenario the
  run-length transition list `(first tick, state, anim_state, telegraphing)`, the events with their ticks, and the end position. One
  plain approach/hold/retreat pass per kind (walker, charger, spitter, swooper, dropper, drifter, snake; the crab and lizard, and
  the two moths, differ only by data), and every interruption case for every kind that has a state: stun mid-windup, mid-charge,
  mid-rest, mid-warn, mid-dive, mid-flash and mid-coil; a slowed creature; alert lost mid-hover; a lethal hit mid-telegraph
  (including a bat in `warn`: no flash on the corpse); a toad stunned right after spitting (its cooldown elapses during the stun); a
  toad walking during the spit pose; a stunned hanging spider; a charger re-winding after rest; a bat's climb returning to hover or
  idle; patrol home bounds. The snake's reach is recorded as the tick it is reached (a float32 knife-edge at exactly 80 px), and
  `velocity = _aim * LUNGE_SPEED` and `distance_to(_anchor)` stay bit-identical.
- **The referee is proved on a sample:** one mutation per creature of the riskiest lags (charger movement one tick late, the
  swooper's dive aim at warn end, the snake's overshoot, the moth's interval reset, the bat's climb RNG draw) must fail the
  characterization; the differential covers the rest, because it fails on any change.
- A separate small `use_sheet = false` test pins the legacy `frame_name()` path (toad windup/spit, spider hang/crawl).
- Every existing enemy suite stays green; only the tests that poke privates change (moved onto the seams in step 1, above).
  Suites that read `Enemy` constants or drive enemies and are run every step: `test_enemy*`, `test_grotto_*`, `test_pale_moth`,
  `test_tuning` (pins `SPIT_COOLDOWN`, `SPIT_TICK`, `SPIT_RANGE`, `WARN_SECONDS`, `DIVE_SECONDS`, `CLIMB_SECONDS`), `test_spore_cloud`,
  `test_tackle_reach`, `test_hit_fairness`, `test_enemy_sheets`, `test_death_cause`, `test_death_fx`, `test_art_visuals`.
  `Enemy` keeps its public constants as aliases (`SPIT_*`, `WARN_SECONDS`, `DIVE_SECONDS`, `CLIMB_SECONDS`, `CHARGE_*`, `ALERT_MEMORY`,
  `BASE_SPEED`, `CONTACT_MARGIN`, `LEDGE_DEPTH`, `BODY_SIZE`, `BODY_BOTTOM`, `SLOW_SECONDS`, `PUFF_*`, `CLIPS`) and `_speed()` keeps its name.
- Selection test: the literal id → kind map for every shipped def, and the no-pair assertion above.

## Follow-ups (not part of this work; issue text)

1. The snake's lunge and retreat ignore the slow (they use `LUNGE_SPEED` and `RETREAT_SPEED`, not `_speed()`): multiply by 0.5
   while slowed; a slowed lunge then covers 45 px, bounded by its timer instead of the 80 px reach.
2. The snake's retreat ends only by distance, so an anchor inside rock hangs it in `rest`: arm a timeout (2.0 s, the slowest legitimate
   retreat being 85 px at 50 px/s = 1.7 s) on BOTH entries to `rest`, and on expiry re-anchor at its current position (a step toward the
   anchor that ends short of 3 px would fall straight back to `rest` through the off-anchor check).

## Build order

1. Seams on the OLD code, the three test writes and three `_telegraphing()` calls moved onto them, suite green.
2. The recorder, the driver, the differential recorded on the old commit, the committed characterization, the legacy-path test, the
   sampled mutation proof.
3. The fold, one commit each with the suite and the differential green: `_state` / `_state_t` / `_aim` and `kind` (with the getters'
   mapping and the initial values); `_clear_inactive()` and `_on_died` per kind; the gravity `match`; `_telegraphing()` and `_act` as
   `match kind`; delete the dead fields.
4. Real playtest of each creature (telegraph, attack, stun, death), review, merge.
