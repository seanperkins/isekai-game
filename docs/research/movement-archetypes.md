# Movement archetypes: slime, spider, biped, quadruped

Status: research and recommendation, 2026-10-03. Nothing is built. The design doc (`docs/isekai-chronicles-design-doc.md`, branch `docs/design-direction`, not on main) names the archetypes: bouncer (slime), crawler (spider), biped (goblin, skeleton), and a later quadruped (wolf). Numbers marked **start** are starting guesses to tune in a sandbox, not findings.

## The answer

1. **Differ by velocity model, never by responsiveness.** Tight is a property of the input path and the forgiveness windows, so all four share one "tight kit" (section 3). What differs is the ground curve, the air model, what releasing jump does, and what surface the body obeys.
2. **Slime, biped and wolf are one ground/air model plus three data profiles.** The spider needs its own surface model. That matches the design doc's "shared controllers instead of per-species code".
3. **The room envelope is fixed.** All 23 hand-built rooms are linted against today's base jump (section 2). Every species keeps at least that rise and reaches differently through shape, speed and surface.
4. **Slime = three layers.** A tight kinematic core, a gooey visual spring on top, hit shapes that follow the art frame. This is the design doc's "tight on the ground, gooey in the air and on walls, springy landings" made buildable.
5. **Spider: run a throwaway spike first**, like `archive/rig-spike`. The open questions are input mapping on walls and ceilings and corner hysteresis. The evidence here is thin.
6. **Do not touch `scripts/player/player.gd` yet.** `feat/essence-overhaul` has uncommitted edits to it. Build the new model as new files and wire it in after that branch merges.

## 1. What "tight" means (evidence)

- **Celeste's controller is the best-documented reference, and it is forgiving, not just fast.** From the released source (`Player.cs`): `MaxRun 90`, `RunAccel 1000` (about 0.09 s to top speed, used for starting, stopping and turning alike), `RunReduce 400` (only when above max speed in the input direction), `AirMult 0.65`, `JumpGraceTime 0.1`, `VarJumpTime 0.2`, half gravity at the apex while jump is held and `|vy| < 40`, `UpwardCornerCorrection 4` px, `WallJumpCheckDist 3` px. Thorson's own list calls these "widening timing and positioning windows" in the player's favor.
- **Tight is not instant.** Hollow Knight is instant both ways (community analysis, not Team Cherry) with a cancel-on-release jump. Celeste ramps in about 0.09 s. Sonic ramps for about 2 s (accel 0.046875 px/frame, decel 0.5, top 6 px/frame at 60 Hz, which is 169 px/s², 1800 px/s², 360 px/s) and still feels controlled because braking is about 11 times stronger than accelerating. GMTK's Platformer Toolkit found the same: the snappiest settings are not always the best, and many schemes work. So "different but tight" has room: change the curve, keep the response.
- **Two jump styles do different things with the same button.** *Cancel on release* (Hollow Knight): a fixed maximum, cut at any moment. *Sustain while held* (Celeste): holding keeps the rise speed up to 0.2 s, and releasing hands over to ordinary gravity. Cancel feels crisp and mechanical; sustain feels rounder. That is a real difference in what the input does, so it is a character lever.
- **Animation must never gate input.** Gish's jump is compress then expand and is physics-driven; that is the opposite of tight, so anticipation here stays cosmetic and runs alongside the launch.

## 2. Where we are today (code facts) and the envelope

`scripts/player/player.gd`: `SPEED 140`, `JUMP_VELOCITY -330`, `GRAVITY 900`, `WALL_JUMP_PUSH 180`, `WALL_SLIDE_SPEED 90`. Ground speed is `dir * speed` (instant start, instant stop). No coyote time, no jump buffer, no variable height (a fixed full jump), no corner correction, no fall multiplier. A wall jump locks horizontal input for 0.15 s. Body 28x24 (spread 28x10), viewport 640x360.

Derived: analytically **rise 60.5 px, apex at 0.367 s, airtime 0.733 s, 102.7 px of travel at 140 px/s**. Measured the way the engine ticks it (60 Hz, the launch tick already moves the body, simulated in a script): **rise 63.25 px (2.6 body heights), airtime 0.75 s (45 ticks), 105 px.** The 60 Hz figures are the ones to pin; `REACH_RISE 55` leaves 8 px of margin under 63.25.

What depends on it:

- `RoomLint._ledge_reach` (`scripts/world/room_lint.gd:17`) fails any ledge the base jump cannot reach: `REACH_RISE 55`, `REACH_GAP 60`, `REACH_HOP 80`. `SURFACE_LIFT := 44` is a literal derived from `JUMP_VELOCITY` and `GRAVITY`.
- Seven test files read `Player.JUMP_VELOCITY` / `GRAVITY` to derive reach: `test_world_entry`, `test_flooded_rooms`, `test_grotto_rooms`, `test_room_lint_water`, `test_player_water`, `test_player_in_water`, `test_player_rope`. `player_water.gd` hard-codes 900.
- The `jump_height` stat multiplies launch speed by `sqrt(jh/100)`, so rise scales with `jh` (stage-4 cap 185, about 112 px). Any new jump model must keep that.
- `enemy.gd` has its own `GRAVITY 900` and `velocity.x = facing * speed`. Its `ceiling_walk` is a static hang then drop (`Kind.DROPPER`), not ceiling locomotion, so there is nothing to reuse for the spider.

**Rule: every species keeps at least the base rise (63 px measured at 60 Hz).** Rooms are linted against one base jump, so a species with less rise strands in existing rooms. More reach (a faster wolf, a ceiling-walking spider) is a gating and level-design decision, not tuning.

## 3. The shared tight kit (all four)

| Feature | Start | Basis |
|---|---|---|
| Coyote time | 0.10 s | Celeste `JumpGraceTime` |
| Jump buffer | 0.10 s | common guidance 0.1 to 0.15 s |
| Corner correction | 8 px | Celeste 4 px at 320x180, doubled for 640x360 |
| Wall-jump range | 6 px | Celeste 3 px, doubled |
| Fall gravity multiplier | 1.0 biped, 1.53 slime, 1.3 wolf | solved below so the envelope holds |
| Input sampling | in `_physics_process`, same tick as the effect | already true |
| Facing | flips on the tick of input | already true |
| Landing | never steals control; the squash is cosmetic | rule |

**Re-solve rule.** Apex float and a heavier fall both change distance. With half gravity below `|vy| < 40` while held, the same `v0` gives rise 61.1 px and airtime 0.82 s (+12 px of distance). Setting `v0 = 328.5` and a fall multiplier of 1.53 restores the base jump (rise 63.15 px against 63.25, airtime 0.75 s, at 60 Hz). Pin it with a test (section 8), not by eye.

## 4. Profiles at a glance (all **start** values)

Accel is `top speed / time`.

| | Biped | Slime | Wolf | Spider |
|---|---|---|---|---|
| Top speed | 140 | 140 | 230 | 140 |
| Time to top / to stop | 0.04 / 0.03 s | 0.05 / 0.06 s | 0.40 / 0.10 s | 0.03 / 0.02 s |
| Air control (x ground accel) | 1.0 | 0.5, bleeds in 0.35 s | 0.25, no bleed | 0.6 |
| Max rise (60 Hz) | 63 | 63 | 64 | 63 (detach hop) |
| Time to apex | 0.37 s | 0.41 s (with float) | 0.30 s | 0.37 s |
| Release style | cancel to 35% | soft: gravity x2.5 | gravity x2 | fixed hop |
| Min tap hop (60 Hz) | about 14 px | about 26 px | about 33 px | none |
| Signature | crisp reference | bounce chain, wall stick | run-up distance, skid | surface adhesion, web zip |

## 5. Slime (the most concrete section)

**Anchor:** tight on the ground, gooey in the air and on walls, springy landings.

### Three layers

1. **Kinematic core (what the player feels).** All the numbers below. Responds on the input tick.
2. **Visual shell (what the player sees).** A second-order spring (t3ssel8r's model: `k1 = ζ/(π f)`, `k2 = 1/(2π f)²`, `k3 = r ζ/(2π f)`, stable semi-implicit integration) drives the sprite's scale: stretched by vertical speed, kicked into a squash on landing in proportion to fall speed. **Start:** `f` 3 to 4 Hz, `ζ` 0.3 to 0.5, `r` 0, squash and stretch clamped to about plus or minus 20 to 25%, volume-preserving (`sx = 1/sy`). Route the scale through the existing `_sprite.position.y = BODY_BOTTOM - frame_h * scale / 2` so the feet stay planted; `EVOLVE_SWELL` is the precedent for a scale multiplier.
3. **Hit shapes.** Per the forms spec, hitboxes follow the skin: traced from each art frame. They stay on the art frame and never follow the spring, so gameplay stays deterministic. (Default; open question 3.)

### Ground: tight

Near-instant: 0.05 s to top, 0.06 s to stop, a 0.08 s turn. At 60 Hz that is about 3 ticks, so platforming stays precise. The softness is in the shell (a lean, a small stretch while accelerating), not in control.

### Air: gooey

- Air accel is 0.5 times ground (Celeste uses 0.65), and with no input the horizontal speed bleeds over about 0.35 s, so a jump is committed and slightly ballistic.
- Jump release is **soft**: releasing while rising multiplies gravity by 2.5 until the apex instead of cutting speed. A tap gives about 26 px, a held jump the full 63. It reads as rounded, not clipped, which differs from the biped's cancel.
- Apex float on (half gravity, `|vy| < 40` start, while held), with `v0` and the fall multiplier solved as in section 3.

### Landing: springy

Gameplay springiness without a control loss: land with jump held or buffered and the rebound is +15% rise (a flat step, not compounding, so heights cannot ratchet). The base ledge still lints at 55, so the rebound speeds traversal and never gates. The visual spring supplies the squash.

### Walls: gooey

`wall_cling` already exists (slide 90 px/s, push 180, 0.15 s lock). Add a **stick** of about 0.2 s at near-zero fall speed before the slide starts, a wall-jump grace of 0.1 s after the wall is lost, and the 6 px wall-jump range. Spread (the puddle) stays as the squeeze verb.

## 6. Biped and wolf (lighter)

**Biped: the crisp reference.** Hollow-Knight-like feel: near-instant ground, full air control, cancel-on-release jump, no float. It is the baseline the others are deltas from, so tune it first and keep it boring. The design doc's "grounded but flexible" has no signature move yet (open).

**Wolf: the momentum gait.** The Sonic lesson is slow to start, fast to brake. Ramp to 230 px/s over 0.4 s but brake in 0.1 s, so a turn is a short skid then an immediate re-accelerate, never a lock. The wolf's run-up is the jump: at the same rise but a flatter 0.30 s arc (`v0 = 2h/t = 403`, `g = 1344`, fall multiplier 1.3, from Pittman's height and time parametrization), travel is about 134 px at top speed against 105 for a base jump. Rain World's pounce conserves momentum with weak air drift, which is the right reference for low air control. Gait gears (walk under 90, trot to 170, gallop above) drive animation and footsteps. A pounce is the existing tackle (260 px/s for 0.15 s) extended by run speed, i.e. a skill, not movement. Consequences to check: a long low body box against `MIN_EXIT 36` and the exit rules, camera look-ahead at 230 px/s on a 640 px view, and the extra reach as a rune-style gate.

## 7. Spider: surface model (spike first)

The evidence is thin: a Godot forum thread reporting that rotating by the last collision normal flips back and forth at 90-degree corners, plus feel reviews of Carrion (amorphous, so a feel reference, not a mechanism). The spike answers:

1. **Input mapping.** Hypothesis: stay **screen-relative**. On a ceiling, stick-right is screen-right (the tangent flips with the surface), on walls stick-up/down runs along the wall, stick away from a wall detaches with a hop, and stick-down on a ceiling drops. Latch the held direction through a corner until it is released or reversed, so rounding an outer corner never reverses input mid-turn. Do not rotate the camera; ease the sprite's rotation over a few ticks.
2. **Corner hysteresis.** Do not read the surface from last frame's collision normal alone. Probe ahead-and-down for outer corners and straight ahead for inner corners, commit to a surface, and lock the transition for about 0.1 s.
3. **Godot mechanics.** `CharacterBody2D.up_direction` rotates what counts as floor, wall and ceiling, so `is_on_floor()` means "on my current surface"; `floor_snap_length` (default 1.0) must cover the body's half-extent to wrap corners; adhesion is gravity along `-up_direction`. Every consumer of `is_on_floor()` in the player (animation pick, audio events, spread) then reads surface-relative and needs a check.
4. **Feel.** Skitter: 0.03 s to top, 0.02 s to stop, fixed detach hops along the surface normal. The signature is the **web zip**: fixed-speed travel along the line (start 400 px/s, about 160 px range), ending in a surface attach. It is a different verb from `Rope`, which is a pendulum with a release boost.

## 8. Architecture and verification

**Files (all new, none edit `player.gd`):** `scripts/movement/movement_profile.gd` (a Resource of tunables; `data/movement/{biped,slime,wolf}.tres`), `scripts/movement/ground_air_step.gd` (pure statics, `step(state, input, profile, dt) -> state`, in the style of `PlayerWater.adjust` and `wants_spread`), and `scripts/movement/surface_step.gd` (the spider spike). The release style is an enum on the profile.

**Wiring (after the overhaul merges):** replace the horizontal and gravity lines (`player.gd:160-170`), the jump branch (`:317-345`) and the wall-cling clamp (`:178`). Keep `Player.JUMP_VELOCITY` and `GRAVITY` as the slime profile's values until the seven reach tests are repointed at `MovementProfile`. Water, rope and the stat scaling (`spd`, `jump_height`) keep working through the same seams. Enemies keep their own movement for now; "every enemy is a potential you" is a later unification.

**Test without playing:** pure-step tests for frames to top speed and to stop, a buffered jump firing on the landing tick, the coyote window in ticks, each release style's tap and full heights, corner-correction cases. **Envelope pin:** measured at 60 Hz against a baseline built from `Player.JUMP_VELOCITY` and `GRAVITY`, every profile's rise within 1 px, and slime and biped airtime within one tick. Then a sandbox room with live sliders and jump-arc ghosts drawn from `RoomLint.REACH_*`, and a scripted-run regression (`test_scripted_run.gd` is the precedent), then a pass through `docs/playtest-checklist.md`.

## 9. Decisions

Decided by Sean, 2026-10-03:

1. Reach policy: every species keeps at least the base rise; species differ in shape, speed and surface.
2. Spider surfaces: all solid terrain is sticky, with a "slick" opt-out flag set in the room editor.
3. Slime spring: cosmetic only; hit shapes follow the art frame.
4. Next: spec and plan the shared ground/air model (new files only, wired into `player.gd` after the essence overhaul merges).

Still open: the biped's signature move (none, a roll, or a ledge grab).

## Sources

- Celeste source, `Player.cs` and `Input.cs` (verified lines): https://github.com/NoelFB/Celeste
- Thorson, "A short thread on a few Celeste game-feel things": https://threadreaderapp.com/thread/1238338574220546049.html
- Thorson, "Celeste & Forgiveness" and "Celeste and TowerFall Physics" (seen in search, not fetched): https://maddythorson.medium.com/celeste-forgiveness-31e4a40399f1, https://maddythorson.medium.com/celeste-and-towerfall-physics-d24bd2ae0fc5
- Sonic Physics Guide (constants from the mirror's quick-reference table): https://github.com/trentbrew/sonic-physics-guide
- Pittman, "Building a Better Jump" (GDC 2016; formulas from search excerpts): https://media.gdcvault.com/gdc2016/Presentations/Pittman_Kyle_BuildingBetterJump.pdf
- GMTK Platformer Toolkit: https://gmtk.itch.io/platformer-toolkit
- Hollow Knight movement, community analysis: https://forum.godotengine.org/t/how-to-make-jumping-like-hollow-knight/140318
- Rain World movement guide: https://rwtechwiki.github.io/Guides/moveguidedoc
- Gish, soft-body movement: https://en.wikipedia.org/wiki/Gish_(video_game)
- Carrion movement reviews: https://digitalchumps.com/carrion-review
- Godot `CharacterBody2D`: https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html
- Godot forum, sticking to walls and ceilings: https://forum.godotengine.org/t/characterbody2d-enemy-in-platform-game-stick-to-walls-ceiling/114535
- t3ssel8r, "Giving Personality to Procedural Animations using Math" (second-order dynamics; formulas from memory)
