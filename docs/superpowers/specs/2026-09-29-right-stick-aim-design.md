# Right-stick aiming: design

## Goal

Aim a skill in any direction with the right stick, and see where it will go. The left stick and the keys keep working
exactly as they do now.

## Today

- `Player.raw_aim()` reads the left stick (`Controls.last_stick`, raw, so a light tilt counts) or the keys
  (`move_left/right`, `aim_up/down`). `resolve_aim` snaps it to 8 directions; under `AIM_DEADZONE` (0.35) it is "no aim"
  and the skill casts forward (`facing`).
- `use_active` stores `ability.aim = aim_vector() if aim_held() else Vector2.ZERO` at the press. A channel latches
  `aim_dir()` at the press and never re-reads it.
- The same `raw_aim()` also drives things that are not casting: the puddle spread (`wants_spread`, aim snapped straight
  down on the floor) and rope reeling (`raw_aim().y`).
- `Controls` listens to `JOY_AXIS_LEFT_X/Y` only. The right stick is unbound.

## Design

1. **`Controls.aim_stick`** (Vector2): the raw right stick, filled from `JOY_AXIS_RIGHT_X/Y` in `_input`, beside
   `last_stick`. Nothing else in `Controls` changes; the right stick gets no input action, because it is read as a
   vector, not pressed.
2. **`Player.cast_aim()`**: the direction a skill is fired in. Right stick at or over `AIM_DEADZONE`: that direction,
   normalised and **not snapped** (free 360 degrees, which is the point of a second stick). Otherwise the existing
   `aim_vector()` (left stick or keys, 8-way, or forward). `use_active` calls `cast_aim()` when `cast_aim_held()`
   (right stick engaged, or `aim_held()`), and `last_cast` records it.
3. **`raw_aim()` is unchanged.** Spread and rope reeling stay on the left stick and keys, so tilting the right stick down
   never flattens the slime or reels a rope.
4. **Right stick beats left stick and keys for the cast only.** Moving with the left stick while aiming with the right
   is the intended play; the skill goes where the right stick points.
5. **A latched channel stays latched.** Holding Sticky Thread or Hydraulic Propulsion keeps the direction it had at the
   press; steering it live is a later change.
6. **`AimReticle`** (a `Node2D` child of the player): while the right stick is engaged, draws a small chevron and two
   fading dots 28 px and 40 px from the slime along the stick, in the water/silk white of the effects. Hidden the rest
   of the time, so keyboard and left-stick play look as they do today.
7. **Debug overlay**: `hud.gd`'s input line also shows the right stick.

## Failure modes

- Stick drift: a right stick resting at 0.2 must not aim; the deadzone is `AIM_DEADZONE`. Released, the reading returns
  to zero (`_input` receives the 0 event), so a skill cast afterwards goes back to the left stick or forward.
- Two pads: `aim_stick` follows the last pad that moved the right stick, like `last_stick`.
- Free angles reach every ability: each one reads `aim_dir()` (a normalised vector; Swing Thread's default is the only
  special case), so none assumes one of eight directions. One is exercised at 30 degrees in the tests.
- A skill screen or a room change while the stick is held: the reticle is hidden by the same `_channel`-style stop sites
  only if it needs them; it reads the stick every frame, so it needs none.

## Not in this change

Mouse aiming, aim assist toward nearby enemies, steering a channel with the right stick, remapping.

## Tests

- `Controls`: a right-stick motion event fills `aim_stick`; a zero event clears it.
- `Player.cast_aim`: right stick right-and-slightly-up gives that exact normalised vector (not snapped); under the
  deadzone falls back to the left stick's snapped aim, then to forward; right stick wins over a held left stick.
- `use_active` stores the free aim in `ability.aim`, and `last_cast["aim"]` matches.
- Spread and rope reel ignore the right stick.
- Reticle: hidden with no right stick, visible and pointing along it with one, gone again on release.
- An ability fired at 30 degrees (Venom Bolt or the thread) travels along that angle.
