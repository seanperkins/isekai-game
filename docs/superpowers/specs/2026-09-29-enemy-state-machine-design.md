# Enemy Behaviour State Machines — Design

Status: draft for review (2026-09-29). Answers Sean's question "We will use a state machine for enemies as well?"
(the slime already has `SlimeState`). A behaviour-preserving refactor of `scripts/enemies/enemy.gd`.

## Goal

`Enemy` (586 lines) mixes five jobs: identity and damage (defs, stats, tackles, threads, slow), the shared senses
(line of sight, alert memory), status handling (stun, down, die), the visual (sheet frames, shapes, tints) and
seven behaviours. The behaviours are held in ten loose fields (`_charge`, `_charge_t`, `_swoop`, `_swoop_t`,
`_spit_windup`, `_spit_cd`, `_puff_t`, `_puff_windup`, `_on_ceiling`, `_lunge_dir`, `_dive_dir`, `_anchor`) and a
precedence chain in `_act`, `_physics_process` and `_telegraphing`. Each new creature (the Grotto's three) added
another branch in four places. This makes each behaviour an explicit state machine in its own small class, so a
new creature is one class plus a table row, and the states are named and testable.

Non-goals: no change to how any creature plays (numbers, timings, precedence, telegraphs); no new creature; no
change to `EnemyStatus`, the death effects, `EatCover`, contact damage or the sheets; no generic behaviour-tree
framework.

## Decisions

| Topic | Decision |
|---|---|
| Shape | `EnemyBehaviour` (a `RefCounted`) owns one creature kind's movement and attack states. The `Enemy` node owns everything shared and asks its behaviour to act each physics tick. A state is a string plus a timer, changed only through `set_state(name, seconds)` |
| Behaviours | `WalkerBehaviour` (patrol and chase: the toad without spit, and the fallback for every walker), `ChargerBehaviour` (lizard, crab: walk, windup, charge, rest), `SpitterBehaviour` (toad: walk, puff, recover), `SwooperBehaviour` (bat: idle, hover, warn, dive, climb), `DropperBehaviour` (spider: hang, then it drops and crawls as a walker), `DrifterBehaviour` (moths: drift, flash), `SnakeBehaviour` (vine snake: hide, coil, lunge, retreat) |
| Selection | A static `EnemyBehaviour.for_creature(def, capabilities, spit_damage)` picks by the same precedence as today's `_act`: snake by id, then ceiling walkers, then `drifter`, then `flight`, then `armored_charger`, then spit damage, else walker. The Charger and Spitter fall through to walking exactly as `_charger_act` and `_spitter_act` returning false do today |
| What stays on `Enemy` | Setup from a `CreatureDef`, stats, health, `receive_hit` / `receive_tackle` / `receive_thread` / `slow_for`, the senses (`can_see`, `_sense`, `is_alert`), status and the death hooks, gravity as decided by `behaviour.gravity_mode()`, contact damage, hurt and telegraph tints, sheet loading and frame drawing, and every public name the rest of the game and the tests use (`charge_state()`, `swoop_state()`, `is_alert()`, `frame_name()`, `hurt_polygon()`, `slow_for()`, `def`, `status`, `health`, `facing`, `spawn_key`) |
| Animation | `EnemyState.pick` stays the one pure mapping and keeps its signature and tests. `Enemy._draw_sheet_frame` builds its inputs from `behaviour.pose()` (a Dictionary of `charge`, `swoop`, `spit_windup`, `spit_recent`, `on_ceiling`) instead of reading loose fields |
| Protection | A **characterization test** is written and committed FIRST: for each creature it runs a scripted scenario on a fixed floor with a fixed RNG seed and records the (state names, position) trace at fixed frames into a data file; after each migration step the same test must pass unchanged. That trace, not the refactor's author, is the referee |
| Tests that poke private fields | About 23 references in five test files read `_charge`, `_swoop`, `_puff_windup`, `_on_ceiling`, `_lunge_dir`. They move to the behaviour's public state (`enemy.behaviour.state`, `charge_state()`, `swoop_state()`); their assertions stay the same |
| Order | One behaviour per step, simplest first, the suite green after every step (Walker, Charger, Spitter, Swooper, Dropper, Drifter, Snake), then delete the dead fields |

## The base class

```gdscript
class_name EnemyBehaviour
extends RefCounted
## One creature kind's movement and attack states. The Enemy calls update() each physics tick while it is ACTIVE
## and the player exists; everything else about the body (gravity, contact, stun, death) stays on the Enemy.

var enemy                        # the owning Enemy (untyped: a cycle)
var state := ""                  # the current state name
var state_t := 0.0               # seconds left in it (0 when the state has no timer)

## Returns true when the behaviour owns this tick's movement (a fallthrough chain: Charger -> Spitter -> Walker).
func update(player: Node2D, to_player: Vector2, delta: float) -> bool: return false
func set_state(name: String, seconds := 0.0) -> void: state = name; state_t = seconds
func pose() -> Dictionary: return {}            # inputs for EnemyState.pick
func telegraphing() -> bool: return false       # drives the flash tint
func gravity_mode() -> String: return "normal"  # "normal" | "hover" | "tether" | "ceiling" (Enemy applies it)
func reset() -> void: pass                      # stun, death, downed: drop any pending windup
```

`Enemy._physics_process` keeps its shape: status update, sense, `behaviour.update(...)` while active, otherwise
`behaviour.reset()` and zero the horizontal velocity, gravity per `behaviour.gravity_mode()` and the enemy's status
(hover and tether hold while ACTIVE or STUNNED; a dying or downed body always falls), `move_and_slide`, contact.

## The state tables (today's behaviour, named)

Every number is the existing constant; the refactor moves them onto the behaviour and leaves `Enemy`'s public
constants (`CHARGE_*`, `DIVE_*`, `PUFF_*`, `LUNGE_*`, `SLOW_SECONDS`, `BODY_SIZE`, `BODY_BOTTOM`, `CLIPS`, ...) in place
as aliases where a test or another script reads them.

| Behaviour | States | Transitions (timers as today) |
|---|---|---|
| Walker | `patrol`, `chase` | alert and within 48 px vertically: chase (stop at ledges and walls, turn lock 32 px); else patrol home ±48 px at half speed |
| Charger | `walk`, `windup`, `charge`, `rest` | walk → windup when alert, level within 24 px, 32 < ahead ≤ 120 px (0.5 s); windup → charge (0.6 s, 3× speed) → rest when the time is up or blocked (1.0 s) → walk. Returns false in `walk` so the Walker moves it |
| Spitter | `walk`, `puff`, `recover` | walk → puff when alert, cooldown over and within 90 px (0.4 s, faces the player); puff → lob a blob (5 s cooldown) → recover (a 0.4 s spit pose) → walk |
| Swooper | `idle`, `hover`, `warn`, `dive`, `climb` | idle bobs; alert → hover above the player (0.8 s + jitter from the enemy's own RNG); → warn (0.3 s) → dive at where you were (0.6 s, 2.2× speed, ends on contact with floor or wall) → climb (0.8 s) → hover or idle |
| Dropper | `hang`, `drop`, then the Walker | hangs on the ceiling; alert and within 40 px in x and below it: drops (the ceiling flag clears) and walks for good |
| Drifter | `drift`, `flash` | drifts about home ±96 px at 60 % speed holding home height ±14; turns at walls; while the player is within 320 px and in sight: flash (0.4 s) then drops a puff under itself every 3 s |
| Snake | `hide`, `coil`, `lunge`, `retreat` | tethered to its anchor; alert and the player within 40 px in x and 0 < dy ≤ 110: coil (0.5 s) → lunge along the line to where it was (0.3 s or 80 px reach, 300 px/s) → retreat to the anchor (100 px/s, ends by distance, with a timeout) → hide. Off the anchor with nothing pending: retreat |

The two known gaps the Grotto review left (the snake's lunge ignoring the slow; the retreat ending only by distance)
are fixed here on purpose and pinned by new tests: the lunge and retreat speeds are multiplied by the slow factor,
and retreat gives up after `RETREAT_TIMEOUT` seconds and snaps to the anchor.

## Testing approach

- **Characterization first.** `tests/test_enemy_traces.gd` builds each creature on a flat floor with a stub player,
  seeds `_rng` explicitly, walks a scenario (approach, hold, retreat, pass under, stand at a distance) and asserts a
  recorded trace (`tests/data/enemy_traces.json`: every 10th frame's state names, and x/y within 0.5 px). It is
  recorded against the CURRENT code and must stay green, byte for byte, through every step. A mutation that changes
  any timer or precedence must fail it.
- The existing enemy suites (`test_enemy`, `test_enemy_ai`, `test_enemy_behaviour`, `test_enemy_contact`,
  `test_enemy_state`, `test_grotto_creatures`, `test_grotto_enemy_flags`, `test_death_fx`, `test_art_visuals`) stay
  green; the private-field pokes move to the public state as above.
- New unit tests per behaviour drive its state table directly (a stub `enemy`), so a transition is tested without
  physics.
- The selection table: for every shipped creature, `for_creature` returns the class the old `_act` chain would have
  chosen (asserted from the creature defs).
- The suite and a real playtest (each creature's telegraph and death) before merge.

## Build order

1. Characterization: the trace test and its recorded data, against today's code.
2. The base class, the selection function and `Enemy` delegating to a `WalkerBehaviour`; walkers (toad without spit, fallback) migrated.
3. Charger, Spitter (each with its unit tests).
4. Swooper, Dropper.
5. Drifter, Snake (with the two fixes above, each with a failing test first).
6. Delete the dead fields and `_act`'s chain; `pose()` feeds the animation; final trace and suite.
7. Review, gate, merge.
