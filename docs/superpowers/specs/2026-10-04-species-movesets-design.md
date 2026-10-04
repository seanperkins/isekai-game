# Species movesets: the verbs of slime, spider, biped and wolf — Design

Status: revised after a Claude-only review (Opus skeptic and Sonnet simplifier; the external panel is blocked on this private repo) (2026-10-04). Builds on `2026-10-03-movement-model-design.md` (the shared ground/air step, three profiles, the slime spring and the sandbox, merged as `f7582e5`) and `docs/research/movement-archetypes.md`. The design doc (`docs/isekai-chronicles-design-doc.md`) names the archetypes; this spec decides what each one can do.

## Intent

Sean's brief: each species should have its own set of things it can do (its moveset), not only its own tuning, so that slime, spider, biped and wolf feel different, and tight and responsive. He wants to see and play them with real characters, not a square. Success: in the sandbox each of the four plays as a distinct creature, each verb answers the press on the tick, control returns fast, and the base jump the 23 hand-built rooms are linted against is never lowered.

Scope: movement verbs and how they tie into combat (dash, pounce, web pull). Skills, elements and evolution stay in the essence design. Wiring into `player.gd` is a later plan (unblocked: `feat/essence-overhaul` has merged).

## Decisions (Sean, 2026-10-04)

- **Playable, with real sprites:** the sandbox shows the slime's own clips, the spider and gloom wolf sheets, and a labeled placeholder for the biped (no goblin art).
- **Three verbs each, one design for all four,** built in order slime, spider, biped, wolf.
- **One signature button, the rest contextual:** the existing Tackle button fires each species' signature; every other verb is automatic or triggered by a held direction or a timed press. No new buttons.
- **Innate, except the slime's Wall Cling,** which stays earned because rooms gate on it today (as a label).
- **Biped is the acrobat:** roll and slide are one verb in two contexts; mantle and wall jump complete it.
- **Structure A:** verb states over the shared step, simplified per the review (below).

## The movesets

Starting values, tuned by play in the sandbox. Speeds px/s, times s.

**Slime (bouncer).** Signature: Tackle.
- *Bounce chain.* A jump press at or before landing gives the +15% rebound with the landing squash. Built.
- *Ooze.* Down on the floor spreads the body flat (28x10, half speed; exists in `Player`). New: while at 100 or more px/s, the raw down input at 0.6 or more starts a puddle slide (it does not need the 8-way aim snap to read exactly down). It keeps momentum (decel 300) and ends below 40 px/s, when down is released, or after 0.5 s.
- *Sticky wall (earned: Wall Cling).* Stick 0.2 s at 15, then slide at 90; wall jump pushes off at 180 with the full jump speed upward, locks control 0.15, grace 0.1, range 6 px.
- *Tackle.* The existing dash: 260 for 0.15 s with the tackle stun.

**Spider (crawler).** Signature: Web zip.
- *Crawl.* Walks hard solid surfaces (all terrain sticky except a "slick" flag from the room editor), rounds corners, instant start and stop (0.03 and 0.02), 140. A one-way ledge is a floor on its top only: it cannot be clung to from below or the side. Input is screen-relative with a corner latch. Jump hops off along the surface normal at the base jump's strength.
- *Web zip.* Aim as the player's cast aim (pointer, then the left stick 8-way, then facing; the right stick and Tackle share a thumb on a pad). A ray goes to the first hard solid within 160 px, or the top face of a one-way ledge when travelling down (slick surfaces refuse it). It pulls at 400; jump cancels and keeps 60% of the speed; with no solid in range it fails and costs nothing; the 0.4 cooldown runs from the end of the zip; no MP cost (the thread skills that hold enemies stay separate). Zipping to an enemy stuns it on arrival, like a tackle.
- *Silk drop* (built last in the spider step). A press of down in the air, with a hard solid within 200 px above, spins a thread from the first one: the fall stops, down reels at 90, up climbs at 60 (never above the anchor), air control at half; jump lets go with the current velocity and no extra impulse. One per airtime.

**Biped (goblin acrobat).** Signature: Roll or slide.
- *Roll or slide.* From under 100 px/s it is a roll: 0.35 at 220 along facing. At 100 or more it is a slide that keeps the speed (decel 350, at most 0.4). Both are invulnerable for the first 0.2 and 12 px tall (they duck low gaps).
- *Ledge mantle (automatic, hard ledges only).* Airborne, not rising faster than 40, with the feet within 6 px (plus this tick's fall distance) below a hard ledge top and a wall ahead in the held or facing direction: grab, pull up in 0.25, stand on the ledge. One-way ledges are jumped through, so they never mantle.
- *Wall jump.* Slides at 90 (no stick), kicks off at 180; lock 0.15, grace 0.1, range 6 px.

**Wolf (quadruped).** Signature: Pounce.
- *Gallop and skid turn.* The tuned profile: 0.4 to 230, brake 0.1, so a reversal is a skid then straight back up. Two gears for animation and footsteps: walk (under 150) and gallop (the sheet has no trot).
- *Pounce.* A leap along the cast aim at 300 plus half the run speed for 0.35, **with gravity on** (so an upward pounce rises at most about 33 px, never more than the base jump), then ballistic with weak air control. A per-tick contact check along the leap bites (stuns, as a tackle) the first hostile it touches; it ends at a wall; cooldown 0.8 from the end.
- *Vault (automatic).* At 150 or more px/s, a hard step of 24 px or less ahead is hopped without a jump press (an impulse of `-sqrt(2 g (step + margin))` on one tick, about 0.2 s), keeping speed.

## Rules across all four

- No verb locks control for more than 0.5 s (roll 0.35, mantle 0.25, pounce 0.35, zip at most 0.4, slide at most 0.5, Tackle 0.15). A verb starts only on a press or a held-direction trigger, except the passive assists: mantle, vault, and wall slide.
- **The base jump (63 px rise at 60 Hz) is the floor for every species.** Verbs add reach, never replace it. **One air verb per airtime** (pounce, zip, roll, silk drop, mantle), reset on landing, wall contact or surface attach. Each verb's added reach has a ceiling pinned by a test; verbs may add horizontal reach freely.
- **Priority.** Evolve and death cancel everything. Hurt or knockback cancels any verb except inside the roll's or slide's invulnerable window. Deep water ends zip, pounce and slide. A verb cannot begin while predating, evolving, roped or in deep water. Mantle beats a wall jump on the same press; a jump pressed during a verb is buffered and fires when control returns. A roll or slide that ends under a low ceiling stays crouched until it can stand. Silk drop ends when the thread's body touches the floor.

## Structure

- **Verbs are static functions** in per-verb files, in the style of `GroundAirStep`: `can_begin(s, i, p) -> bool` (including the verb's own trigger) and `step(s, i, p, dt) -> bool` (true while it runs). Per-verb timers live in `MoveState`. A small `VerbRunner` polls `can_begin` each tick, runs the active verb, and otherwise runs `GroundAirStep`. A runner takes an `enabled` set (the sandbox passes all; the player will pass its skills, so Wall Cling stays earned).
- **Timers are never starved.** `GroundAirStep` exposes its timer update (coyote, buffer, `air_time`) and the runner calls it every tick, verb or not, so a press during a roll is buffered and a rebound still sees real air time.
- **Burst is one verb with rows.** Tackle, roll, slide, puddle slide and pounce are rows of one data-driven `Burst` (speed, run-speed fraction, duration, decel, minimum exit speed, invulnerable time, hitbox height, gravity scale, cooldown, aim mode, contact stun) in the profile. Verb code stays separate only where a verb senses the world: wall, mantle, zip, silk drop, crawl.
- **Probes are fields on `MoveInput`,** filled by the caller each tick (the sandbox now, the player later): floor, wall and ceiling normals, ledge-top offset, step height ahead, clearance above, water, plus the inputs verbs need (`down`, `up`, `signature_pressed`, `aim`) and the one query the zip needs, a ray `Callable` that reports the hit point, its normal, and the slick and one-way flags. There is no separate sensor object.
- **Profiles:** `MovementProfile` gains the Burst rows, the vault speed and step fields, and a `verbs` list; there is a fourth profile, `spider.tres` (0.03 and 0.02, 140, the base jump), and the envelope pins cover all four ids.
- **Crawl is separate.** The spider's surface walking is a `SurfaceModel` (a locomotion mode chosen by the profile), built after a throwaway spike. The spike answers corner latching and hysteresis, and what a crawler does with one-way ledges (above).
- **Wiring note.** `player.gd`'s `_dash` writers (knockback, shock stun, `apply_impulse`, the wall jump, the rope, water's `dashing` flag) become the runner's single owner in the wiring plan; this spec only sets the priority table.

## Build order (each step playable in the sandbox)

1. Sandbox with real animated sprites and species switching. No new scripts: replace the colour rect with a sprite driven by `SlimeAnimator` (it takes any clips), `SpriteSheet.load_set` and `SlimeState.pick` for the slime, a five-line state mapping each for the spider (hang, crawl, drop) and wolf (idle, walk, charge, windup), the colour rect kept as the labeled biped, a fourth key and `spider.tres`. A missing sheet falls back to the colour rect, so the sandbox test does not depend on import. The body box stays 28x24 for all four.
2. Slime: Burst (Tackle and puddle slide), then sticky wall and wall jump.
3. Spider: the crawl spike and surface model first (it is the species and the biggest risk), then web zip, then silk drop.
4. Biped: roll or slide (a Burst row), mantle, wall jump.
5. Wolf: pounce (a Burst row), vault, gears.

A running verb shows its name in the sandbox HUD and tints the sprite; there is no placeholder-pose system.

## Testing

Pure tests per verb with hand-filled `MoveInput` (when it may start, duration, speeds, control returns within 0.5 s, a jump press during a verb fires when it ends, one air verb per airtime). The base-jump pin runs for all four species. A verb's **maximum reach** is pinned (pounce rise, zip range, mantle and wall-jump height). Every probe has a sandbox test on real collision, including one-way ledges and the 6 px margin. A start-from-real-input test per species drives the sandbox with `Input` actions, so a verb that real input cannot trigger fails (for example the puddle slide). Whether each verb feels right is Sean's call per species.

## Constraints on the work

Edits `scripts/movement/movement_profile.gd`, `move_input.gd`, `move_state.gd`, `ground_air_step.gd`, `movement_sandbox.gd` and the movement tests (all from Part 1); adds new files under `scripts/movement/`, `data/movement/` and `tests/`. No edits to `player.gd`, `room_lint.gd` or other existing scripts.

## Art needs

Slime: puddle slide, wall stick pose. Spider: wall and ceiling crawl, zip, idle, rise, fall (only hang, drop and crawl exist). Biped: everything. Wolf: pounce, vault, skid, trot (only idle, walk, windup, charge and rest exist). Frames follow the art pipeline (individual frames, assembled by a tool).

## Known gaps and open

- **Room content.** Today's 23 rooms contain no hard step of 24 px or less and no hard low ceiling, and 133 of 172 interior solids are one-way. Roll's duck, the puddle slide's tunnel, vault and mantle have little to act on until rooms are built or edited for them; the sandbox provides them for tuning.
- **Species reach and gates.** The `wall_cling` exits are labels in the validator, not obstacles; the biped's wall jump, the spider's crawl and zip, and the pounce all reach more than the base jump, by design (the design doc's "species as runes"). Whether the validator and lint learn each species' kit is open, for the wiring plan.
- **Stun.** Every non-slime species stuns only through its signature (pounce bite, zip-to-enemy); a roll does not. The goblin's stun for eating and fighting arrives with the items milestone. Open: what a reborn biped hits with until then.
- From the movement-model spec, still open for the wiring plan: the slime rebound against the G5 chimney guard, the wolf's 46 px run-up audit of ledge approaches, pad-stick air momentum for the wolf, the 8 px corner correction, and the `slide_speed` stat scaling the wall slide.
