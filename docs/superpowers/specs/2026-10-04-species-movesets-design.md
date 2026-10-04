# Species movesets: the verbs of slime, spider, biped and wolf — Design

Status: draft for review (2026-10-04). Builds on `2026-10-03-movement-model-design.md` (the shared ground/air step, three profiles, the slime spring and the sandbox, merged as `f7582e5`) and `docs/research/movement-archetypes.md`. The design doc (`docs/isekai-chronicles-design-doc.md`) names the archetypes; this spec decides what each one can do.

## Intent

Sean's brief: each species should have its own set of things it can do (its moveset), not only its own tuning, so that slime, spider, biped and wolf feel different, and tight and responsive. He wants to see and play them with real characters, not a square. Success: in the sandbox, each of the four plays as a distinct creature, each verb is tight (it answers the press on the tick, control returns fast), and nothing moves the base jump that the 23 hand-built rooms are linted against.

Scope: movement verbs and how they tie into combat (dash, pounce, web pull). Skills, elements and evolution stay in the essence design. Wiring into `player.gd` is a later plan (it is unblocked: `feat/essence-overhaul` has merged).

## Decisions (Sean, 2026-10-04)

- **Playable, with real sprites:** the sandbox shows the slime's own clips, the spider and gloom wolf sheets, and a labeled placeholder for the biped (no goblin art yet), instead of a square.
- **Three verbs each, one design for all four:** one spec so the species stay distinct from each other, then built in order slime, spider, biped, wolf.
- **One signature button, the rest contextual:** the existing Tackle button fires each species' signature verb; every other verb is automatic or triggered by a direction held or a press timed. No new buttons.
- **Innate, except the slime's Wall Cling:** every species starts with its verbs; the slime's Sticky wall stays the earned Wall Cling skill, because rooms gate on it today.
- **Biped is the acrobat:** roll and slide are one verb in two contexts; mantle and wall jump complete it.
- **Structure A:** verb states over the shared step (below).

## The movesets

All numbers are starting values, tuned by play in the sandbox. Speeds px/s, times s.

**Slime (bouncer).** Signature: Tackle.
- *Bounce chain.* A jump press at or before landing gives the +15% rebound, with the landing squash spring. Built (movement-model Part 1 and 2).
- *Ooze.* Down on the floor spreads the body flat (28x10, half speed; exists in `Player`). New: down at 100 or more px/s starts a puddle slide, which keeps momentum (decel 300) under low hazards and ends below 40 px/s or when released.
- *Sticky wall (earned: Wall Cling).* Stick 0.2 s at 15, then slide at 90; wall jump pushes off at 180, locks control 0.15, grace 0.1 after leaving the wall, range 6 px.
- *Tackle.* The existing dash: 260 for 0.15 s with the tackle hit.

**Spider (crawler).** Signature: Web zip.
- *Crawl.* Walks any solid surface (all terrain sticky except a "slick" flag set in the room editor), rounds corners, instant start and stop (0.03 and 0.02), 140. Input is screen-relative with a corner latch. Jump hops off along the surface normal at the base jump's strength.
- *Web zip.* Aim with the right stick, pointer or facing; a line goes to the first solid within 160 px (slick surfaces refuse it); pulls at 400, also usable as a dodge along the line; jump cancels and keeps 60% of the speed; cooldown 0.4; no MP cost (the thread skills that hold enemies stay separate).
- *Silk drop.* Down in the air spins a thread from where you are: the fall stops, down reels at 90, up climbs at 60, thread length 200, air control at half; jump lets go with the current velocity.

**Biped (goblin acrobat).** Signature: Roll or slide.
- *Roll or slide.* From standing, a roll: 0.35 at 220, invulnerable for the first 0.2, hitbox 12 px tall so it ducks low gaps. At 100 or more px/s it becomes a slide that keeps the speed (decel 350, at most 0.4).
- *Ledge mantle (automatic).* Airborne, not rising faster than 40 px/s, with the feet within 6 px below a ledge top and a wall ahead: grab and pull up in 0.25 to stand on the ledge.
- *Wall jump.* Brief slide at 90 (no stick), then kick off at 180; lock 0.15, grace 0.1, range 6 px.

**Wolf (quadruped).** Signature: Pounce.
- *Gallop and skid turn.* The tuned profile: 0.4 to 230, brake 0.1, so a reversal is a skid then straight back up; gears walk (under 90), trot (to 170), gallop (above), driving animation and footsteps. Built as a profile.
- *Pounce.* A committed leap along the aim (snapped like the existing aim) at 300 plus half the run speed for 0.35 s, then ballistic with weak air control; a bite on contact; cooldown 0.8.
- *Vault (automatic).* At 150 or more px/s, a step of 24 px or less is hopped without a jump press, keeping speed (0.2 s).

**Rules across all four.** A verb never takes control without a press, except the two assists (mantle and vault). Control returns within 0.5 s of any verb ending (roll 0.35, mantle 0.25, pounce 0.35, zip at most 0.4, slide at most 0.5; silk drop is never a lock). The base jump (63 px rise at 60 Hz, measured) is the floor for every species; verbs add reach, they never replace it.

## Structure

- **Verb states.** `MovementVerb` (a `RefCounted`): `can_begin(ctx) -> bool`, `begin(ctx)`, `step(ctx, dt) -> bool` (true while it runs), `end(ctx)`. A `VerbRunner` holds the active verb: while one runs it owns the velocity, otherwise `GroundAirStep` runs. `MovementProfile` gains `verbs: PackedStringArray` and `signature: String` (what Tackle fires); mantle and vault are marked automatic and are checked every tick.
- **Sensors.** Collision questions (floor, wall and ceiling normals, ledge top offset, step height ahead, clearance above, a ray to the first solid with its slick flag) go through one `MoveSensors` interface. The sandbox implements it with a `CharacterBody2D` and ray queries; `player.gd` implements the same later. Verbs are tested against a fake.
- **Crawl is separate.** The spider's surface walking is a `SurfaceModel` (a different locomotion mode chosen by the profile), built after a throwaway spike, because rotating "up" does not fit the ground step. Open questions for the spike: input latching at corners and corner hysteresis.
- **Wall verbs** (stick, slide, wall jump, the 6 px range) are the deferred items from the movement-model spec, now built as verbs shared by slime and biped.
- **Sprites.** The sandbox plays the existing clips (`data/slime_clips.json`, `data/enemy_clips.json`); a verb with no frames gets a placeholder pose (squash, tint, rotation) and goes on an art list.

## Build order (each step playable in the sandbox)

1. Sandbox with real animated sprites and species switching (slime, spider, wolf sheets; biped placeholder).
2. Slime: puddle slide, then sticky wall and wall jump.
3. Spider: web zip and silk drop, then the crawl spike and surface model.
4. Biped: roll or slide, mantle, wall jump.
5. Wolf: pounce, vault, skid turn and gears.

## Testing

Each verb has pure tests against a fake sensor: when it may start, its duration and speeds, that control returns within 0.5 s, and that the base jump is untouched (the envelope pin stays). The sandbox gets a smoke test per species. Whether each verb feels right is Sean's call per species.

## Art needs (placeholders until frames are generated)

Slime: puddle slide, wall stick pose. Spider: crawl on wall and ceiling, zip, drop. Biped: everything (no goblin sheet). Wolf: pounce, vault, skid. Frames follow the art pipeline (individual frames, assembled by a tool).

## Risks and open

- The crawl may need a redesign if the spike shows corner flip-flop.
- Mantle, vault and zip need new collision probes; their feel depends on probe distances tuned in the sandbox.
- The pounce's bite reuses `player.gd`'s tackle hit logic, so it is a real hit only after wiring into `Player`.
- Still open from the movement-model spec: the slime rebound against the G5 chimney guard (`tests/test_grotto_rooms.gd`), the wolf's 46 px run-up audit of ledge approaches, and pad-stick air momentum for the wolf. They belong to the wiring plan.
