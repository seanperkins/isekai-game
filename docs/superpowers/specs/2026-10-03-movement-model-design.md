# Movement model: shared ground/air step, three profiles, slime spring — Design

Status: revised after a Claude-only review (Opus skeptic and Sonnet simplifier; the external panel is blocked on this private repo, no ZDR-capable model in the registry) (2026-10-03). Evidence and rationale: `docs/research/movement-archetypes.md`. Sean's decisions (2026-10-03): every species keeps at least the base rise; the spider clings to all terrain with a "slick" opt-out (a later spec); the slime sprite spring is cosmetic and hit shapes follow the art frame; this spec covers the shared ground/air model only, as new files, wired into `player.gd` after `feat/essence-overhaul` merges.

## Goal

Make slime, biped and wolf move differently and tightly with one pure, testable model plus data profiles, without moving the held base jump that every hand-built room is linted against.

## Scope

In: `MovementProfile` data, three profiles (biped, slime, wolf), a pure `GroundAirStep` (ground and air control, gravity, coyote, jump buffer, release styles, slime rebound), a cosmetic spring for the slime's squash and stretch, a sandbox scene to feel the profiles, and the tests that pin the jump envelope.

Out (each its own later spec or plan): wall stick, wall grace and wall jump (they need `on_wall` and `get_wall_normal` from collision, so they arrive with the integration plan, together with the 6 px wall-jump range and the 8 px corner correction); the spider's surface model and its spike; wiring into `Player` (written against the merged `player.gd`: stat scaling including `slide_speed`, water, rope, spread, tackle, the seven reach tests); enemies' movement; the biped's signature move (open); art.

## The envelope (a contract, not a tuning target)

The base jump today, measured at the engine's 60 Hz tick order (the launch tick already moves the body): **rise 63.25 px, airtime 0.75 s (45 ticks), 105 px of travel at 140 px/s.** `RoomLint` pins ledge reach at `REACH_RISE 55`, `REACH_GAP 60`, `REACH_HOP 80`, and seven tests derive reach from `Player.JUMP_VELOCITY` and `GRAVITY`. For a **held** jump on flat ground:

- every profile's rise is within 1 px of the base and at least `RoomLint.REACH_RISE`;
- biped and slime airtime is within one tick of the base; the biped's held jump is today's jump exactly;
- the wolf's flatter arc is shorter, and its travel at top speed is at least 1.2 times the base;
- from a standstill, biped and slime travel at least 0.9 times the base distance (the lint's gaps assume no run-up, because today's speed is instant). **The wolf is the exception**: it needs about 46 px of run-up (0.4 s to top speed), and from a standstill it travels about 29 px. The integration plan audits each ledge's approach before the wolf is playable (a deliberate gating or a longer ramp);
- the `jump_height` stat still scales rise: at a boost of `sqrt(1.85)` the rise is 1.7 to 1.95 times the unboosted rise (today 1.83).

**Known consequence, recorded for the integration plan:** the slime's rebound raises the apex by 15% (72.65 px against 63.25 unboosted). `tests/test_grotto_rooms.gd` derives the earliest apex from `Player` constants and pins the screen of the G5 opening at 93.775 + 3 px (`test_the_chimney_screens_the_g5_opening_below_every_early_jump`, a chimney in G3); a rebound at the stage-2 boost would reach about 107.8 px. Either the integration plan updates that test's model to include the rebound (and the chimney screen, or the rooms around it), or the rebound is capped. This spec does not decide; Part 1's tests pin the rebound at 1.10 to 1.20 times the unrebounded rise so the number stays visible.

## Model

Pure statics over a `MoveState` and a `MoveInput` (the style of `PlayerWater` and `Player.wants_spread`): `GroundAirStep.step(state, input, profile, dt, speed_scale, jump_boost)` mutates `state.velocity` and its timers; the caller moves the body. Tick order: timers, horizontal control, gravity, jump, release.

- **Timers** all use one idiom: decrement and clamp to zero first (`t = maxf(0.0, t - dt)`), then test `t > 0.0`. Floating-point residue is therefore never treated as time left.
- **Ground.** Toward `dir * top` at `top / ground_accel_time`; with no input, to rest at `top / ground_stop_time`; with input opposing the velocity, brake to rest at `top / ground_turn_time` first (it accelerates from rest on the next tick). `top = top_speed * speed_scale`; a zero scale roots the body.
- **Air.** Toward `dir * top` at the ground accel times `air_accel_mult`. With no input the speed bleeds to rest over `air_stop_time`, unless `air_keeps_momentum` (the wolf).
- **Gravity** applies only when airborne and starts from `gravity`. It is multiplied by `apex_gravity_mult` while jump is held and `|vy| < apex_band`, **and** by `fall_mult` while `vy > 0` (when both apply, both multiply), **and** by the soft-release factor while rising with jump released. A body on the floor has positive `vy` zeroed.
- **Jump.** Fires when the buffer (`buffer` seconds after a press) is live and the body is on the floor or within `coyote` seconds of leaving it; sets `vy = -jump_velocity * jump_boost`. A jump that fires on the first floor tick after at least 0.12 s of air (a press made at or before the landing tick, or within the profile's `rebound_grace` after it) gets the **rebound**: launch speed times `sqrt(1 + rebound_rise)`. A button held through landing does nothing, and the bonus never compounds. One launch per press: firing clears buffer and coyote. `state.launched` says what happened this tick: `""`, `"ground"`, `"coyote"` or `"rebound"`.
- **Release** (jump released while rising from a jump, never on the launch tick): `CUT` caps `vy` at `-launch_speed * release_factor` once and never raises speed; `SOFT` multiplies gravity by `release_factor` until the apex.

## Profiles (starting values, tuned by play; pinned by the envelope tests)

| | biped | slime | wolf |
|---|---|---|---|
| `top_speed` | 140 | 140 | 230 |
| `ground_accel_time` / `ground_stop_time` / `ground_turn_time` | 0.04 / 0.03 / 0.03 | 0.05 / 0.06 / 0.08 | 0.40 / 0.10 / 0.10 |
| `air_accel_mult` / `air_stop_time` / `air_keeps_momentum` | 1.0 / 0.03 / false | 0.5 / 0.35 / false | 0.25 / 0.35 / true |
| `jump_velocity` / `gravity` / `fall_mult` | 330 / 900 / 1.0 | 328.5 / 900 / 1.53 | 403 / 1344 / 1.3 |
| `apex_band` / `apex_gravity_mult` | 0 / 0.5 | 40 / 0.5 | 0 / 0.5 |
| `release_style` / `release_factor` | CUT / 0.35 | SOFT / 2.5 | SOFT / 2.0 |
| `coyote` / `buffer` | 0.10 / 0.10 | 0.10 / 0.15 | 0.10 / 0.10 |
| `rebound_rise` | 0 | 0.15 | 0 |
| `rebound_grace` | 0 | 0.08 | 0 |

The wolf's long run-up (0.4 s) and short brake (0.1 s) are the point: slow to start, fast to stop and turn. The wall fields (slide 90 px/s, stick 15 px/s for 0.2 s on the slime, grace 0.15 s, push 180, lock 0.15 s, bounce 85% from 100 px/s) are on the profile now.

## The slime's visual spring (cosmetic)

One class, `SquashSpring`: a damped spring (`f` 3.5 Hz, `zeta` 0.4, `dt` capped at 1/30 s for stability) whose target is a stretch from vertical speed (`clampf(|vy| / 400, 0, 1) * 0.22`) and which a landing kicks into a squash in proportion to fall speed. Its output `s` is clamped to plus or minus 0.22 and mapped to a volume-preserving scale `(1 / (1 + s), 1 + s)`. It changes only the sprite's scale (feet kept planted by the existing sprite-position formula); hurt and attack shapes follow the art frame and never the spring.

## Sandbox

`scenes/movement_sandbox.tscn`: starts on the slime; a wide floor and three ledges at 40, 60 and 100 px (a partial hop, a full base jump with 3 px to spare, and one that needs the boost key), a body driven by `GroundAirStep` (its velocity copied back into the state after `move_and_slide`), keys 1 to 3 switching profile, `B` toggling the stage-4 jump boost (`sqrt(1.85)`), and a HUD line with the profile id, speed and last jump's rise and airtime. It does not use `Player` and touches no existing script. Whether it feels right is Sean's call.

## Constraints on the work

New files only under `scripts/movement/`, `data/movement/`, `scenes/`, `tests/`; no edits to `player.gd`, `room_lint.gd` or any existing script. The branch is cut from main in `.worktrees/movement-model`.

## Open

The rebound against the G5 chimney screen (above); the wolf's standing reach (above); the biped's signature move; walls and the corner correction (integration plan); the spider's surface model (spec after a spike).
