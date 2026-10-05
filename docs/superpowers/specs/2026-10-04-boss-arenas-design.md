# Boss arenas: big creatures in big rooms, a boss room that seals, and a world that warns you — Design

Status: draft for Sean's review (2026-10-04). Builds on the room system (`docs/rooms.md`), the species work (`2026-10-04-species-movesets-design.md`, its creature size ladder) and the research in `docs/research/level-design-reference.md` (arena and foreshadowing rules).

## Intent

Sean (2026-10-04): "We can have large creatures in larger rooms. Bosses should have their own rooms that lock behind a player so they have to fight. We can make it clear a boss is ahead."

Understanding, written back so it can be corrected:

1. **Room size follows creature size.** A creature that big needs space to move and attack in, so the room linter checks it and a drake can never end up in a corridor.
2. **A boss lives alone in a room built for it.** Crossing a marked line inside the room starts a short intro, the way back seals, and the boss wakes. The seal opens only when the boss is dead. Dying is a rebirth, so a sealed arena cannot strand anyone.
3. **The world warns you.** You are never surprised by a boss: a quiet room with a place to rest comes first, the ground shakes and the sound changes as you approach, and the approach carries traces of the creature, with a glimpse of it before you meet it.

Success: in the Deep, the player climbs toward something they can hear and half see, rests in a quiet room, walks into a large room, watches the doors close, and fights the Taratect with nowhere to run; killing it opens the doors, and it stays dead.

Scope: the framework (data, lock, wake, win, persistence, warning cues, lint) and the first boss, the Taratect in the Deep. Not in this spec: boss attack patterns and phases, a boss health bar, music, a reward beyond what a kill already gives, other bosses, a map marker.

## Decisions (Sean, 2026-10-04)

- **First boss: the Taratect only.** The framework is data, so a second boss later is a room and a creature id.
- **The arena seals a beat after a threshold.** You can turn back until you cross the line; after that you are committed.
- **Announce it three ways:** an antechamber (a quiet room right before the arena, where you can rest), sound and screen cues, and traces plus a glimpse. (A distinctive door look was offered and not picked.)
- **Room size is a lint rule**, not a convention.

## Design

### Boss room data

`RoomDef` gains two fields, both empty by default so no existing room changes:

- `boss: Dictionary`: `{"creature": id, "threshold": Rect2}`. `creature` names a spawn in the room's own `spawns` (the boss, whose id appears there once); `threshold` is a rect in local px, the line the player crosses to start the fight. A room with a `boss` is an arena.
- `tremor: float`: 0 for none, 0 to 1 for how hard the ground shakes while the player is in the room (the warning, below).
- `glimpse: Dictionary`: `{"creature": id, "pos": Vector2, "scale": float, optional "frame"}`, a dark silhouette of a creature drawn behind the room's solids (the warning, below).

All of a boss room's exits seal. Everything else about the room is ordinary data edited in the room editor.

### The arena's life

One `BossArena` node per arena room, driven by a pure `BossArenaModel` (a `RefCounted`, so it is tested without a scene). States:

| State | Meaning | Leaves it when |
|---|---|---|
| `waiting` | the boss is dormant, exits open | the player's body overlaps the threshold |
| `intro` | `INTRO_SECONDS` (0.8): a rumble cue, the doors slam, the boss turns and wakes | the timer ends |
| `fight` | exits sealed, the boss acts | the boss dies |
| `won` | the seals open, the boss is recorded as defeated | (final) |

Rebirth (the player dies) discards the room: the world builds rooms fresh on every entry (`RoomBuilder.build_room`), so an arena that is not won is `waiting` again with a full-health boss. Nothing in this spec changes that.

**The seal** is the arena's own gate, built the way a shortcut's is but not tied to one: the closed-shortcut path in `RoomBuilder.build_room` makes a gate only for an exit that `is_exit_open` calls closed and groups it by shortcut id (`World._open_gate` frees it on a shortcut event), and an ordinary exit has none. The gate-building code (the solid from `RoomBuilder.gate_rect`, with the painted art on it) is pulled into one `RoomBuilder` helper that both paths call. The arena calls it for every exit of its room when the intro starts, adds the solids to a group of its own (`boss_gate`), plays the slam cue, and frees only that group on `won`. The threshold must sit at least `SEAL_CLEARANCE` (96) px from every exit span, so a closing gate never lands on the player.

**The boss wakes.** `Enemy` gains `dormant: bool`. A dormant enemy is frozen where it spawned (no gravity, no movement, no AI, so a dropper stays on its ceiling), deals no contact damage, and refuses damage at both entry points: `can_be_hit()` and `receive_hit()` (area skills call the latter directly). Its hang or idle frame shows. The arena sets it on the boss at build time and clears it when the intro ends; the Taratect's spawn in the arena data is on the ceiling, where it hangs.

**The boss dies.** The arena listens to the boss node's `downed` signal, not the `enemy_died` world event: `Enemy._on_died` emits the event first and `downed` after, and `Game._spawn` connects `downed` to the compendium's `on_creature_defeated` and the player's progression. The arena connects after those and records the defeat on the next frame, so the Bestiary has the defeat before the profile says the boss never spawns again; a stop between the two leaves the boss alive, not unearned.

**Persistence.** `WorldProgress` (it owns the profile sections for shortcuts, tablets and the map, and writes them through `Profile.save`) gains a `bosses` section: the set of defeated boss creature ids. `WorldProgress._save` discards `Profile.save()`'s result today, for shortcuts too; for a boss the flag is kept in memory for the session either way, and a failed write is retried by the next progress save (the same rule as every other section), so a failed write costs at worst a second fight after a restart, never a boss that cannot be fought. A defeated boss is not spawned again and its room builds without an arena: the doors stay open and the room is an ordinary empty one. The reward is what a kill gives today (XP through the player's progression and the Bestiary defeat that the species unlock rule reads); the corpse's rare part in the design doc is not built, and building it is not in this spec.

**Camera.** The camera already follows inside a multi-screen room; it stays as it is. A small `shake(amount, seconds)` is added to the world's camera for the warning cues and the slam.

### Making it clear a boss is ahead

All three are data on rooms, so every boss gets the same grammar:

1. **The antechamber.** An arena has exactly one exit, and it leads to a room with a glow pool and no spawns. The glow pool is the existing feature that restores HP and MP (D5 pairs one with a tablet), so the player arrives at the fight rested, and the quiet pause before the door is the warning. It is a glow pool and not an altar because the world validator allows one altar per area and the Deep's is D1's (an altar is also the place the player is reborn, and a rest is not). The cost is that dying in the arena sends the player back to D1; whether the Deep gets a second altar by the arena, with the validator's rule relaxed, is Sean's call and is listed in the open items. (Research rule: a safe room immediately before the arena.)
2. **Sound and screen cues.** A room with `tremor` shakes the screen and drops dust from the ceiling every 5 to 9 seconds (a random gap) and plays a `boss_tremor` cue, scaled by the value: about 0.3 in the rooms leading up, 0.6 in the antechamber. The arena adds `boss_slam` (the doors) and `boss_wake` (the roar), and the death cue routing in `data/audio/cues.json` gets `"taratect": "enemy_death_boss"` (only the serpent has it; anything else falls to `enemy_death_beast`). Files come from the audio pipeline, with the nearest existing sounds as stand-ins until then.
3. **Traces and a glimpse.** The approach rooms carry decor of the creature (web strands, husks, claw marks on the walls; `deep_bones` exists, the web and claw pieces are new art from the art pipeline). The antechamber has a gap in its wall behind translucent web in which a large dark silhouette of the boss moves slowly: the room's `glimpse`, a sprite of the creature's own sheet frame tinted dark and scaled up, drawn by `RoomBuilder` behind the solids (not through `SetDressing`, which `RoomBuilder.simple_layers` switches off today), so no new art. Lint checks that the creature has a sheet and the position is inside the room.

### The Deep

Placement is for the plan to settle against the real geometry; the recommendation, from D2's layout (its chimney is two 16 px walls at x 900 to 1020, a wall-cling climb up through a top exit at 920 to 1000 into D6):

- `D6` becomes the arena, 2 screens wide (cells (19,5) and (20,5), both free), with the Taratect spawned far from the threshold, a flat floor with no gaps, and one exit only: a new left door.
- A new `D7` at cell (18,5) is the antechamber: 1 screen, a glow pool, a tablet (`tablet` is an existing feature) that says something lives beyond, the glimpse gap, `tremor` 0.6. Its right door meets D6's left door; its bottom exit is the wall-cling climb.
- `D2`'s chimney moves to the left half (its two walls and its top exit, at the matching span under D7), and `D2` gets `tremor` 0.3 and the first traces. D6's old bottom exit is removed.

### Room size follows creature size

`RoomLint` gets a `creature_fit` rule, constants beside the others and pinned by tests. For each spawn, with `W` and `H` the widest and tallest frame of its sheet (read through `SpriteSheet`):

- the **clear height** above the spawn's footing, up to the nearest solid, is at least `1.25 * H`;
- the **footing** it stands on (the floor or a solid's top, the contiguous run under the spawn) is at least `2 * W` wide.

Boss rooms add their own rules: at least 2 screens in one dimension; one exit; that exit leads to a room with a glow pool and no spawns; `boss.creature` is in `spawns` and at least 200 px from the threshold; the threshold is inside the room and `SEAL_CLEARANCE` from every exit span; the floor has no hole (so nothing falls out) and no water. A room with `tremor` has it in `[0, 1]`. The rules run in the editor's Validate and in the suite over every room, like the existing ones, and the shipped rooms must pass: the stone drake's bigger frames (108x99 for its windup) are checked against D3, D4 and D5, and what fails is fixed or waived with a reason in the room's data, not by loosening the rule.

The enemies' terrain body is a fixed 16x12 box whatever the sprite is (`Enemy.BODY_SIZE`), so a big creature is physically a small one that draws large. This spec leaves that as it is; per-creature bodies belong to the hitbox and reach-model plan the scale work called for, and the arena rules above are written against the sprite so they stay right when it lands.

## Constraints

- No existing room, creature or save changes behaviour: the new fields default to empty, `dormant` to false, `defeated_bosses` to empty.
- The seal never closes on the player (clearance rule), never traps a body that cannot fight: death is a rebirth.
- A defeated boss stays defeated across rebirths and saves; an undefeated one is full health every time you enter.
- No time estimates in plans; plans stay lean.

## Testing

- `BossArenaModel`: the four states and their transitions, the intro timer, exactly one transition per event, a win while `waiting` ignored.
- Real collision: crossing the threshold seals every exit after the intro (the player cannot pass a gate; a room's ordinary exits had none before), the boss is dormant until the intro ends (it does not move or fall, deals no contact damage, and an area skill's `receive_hit` does nothing), its death frees only the arena's gates, and the defeat survives a profile save and load.
- Ordering and failure: the Bestiary has the defeat before the profile does (stop between them and the boss is still alive next run); a failed profile write leaves the boss dead for the session and is retried by the next progress save.
- Rebirth: a lost fight rebuilds the arena `waiting`, the boss at full health.
- `RoomLint`: `creature_fit` on a cramped fixture and a roomy one at the boundary, every boss-room rule on a fixture that breaks it, and the shipped Deep rooms (D2, D6, D7, D3 to D5) all clean.
- `tremor`: the cue and shake fire on the schedule and scale with the value (a seeded generator).

## Known gaps and open

- No boss health bar, music, phases or attack tuning yet: the Taratect fights with its ordinary behaviour (crawl, drop) until a combat pass gives it a pattern. Its stats (HP 24, ATK 9) are the creature's today.
- The terrain body of big creatures (see above) and the per-species reach model are the next structural plan; the arena is built to survive both.
- **A second altar by the arena (Sean's call).** With one altar per area, dying to the boss means the walk back from D1. A second Deep altar in D7 would be a checkpoint, at the cost of relaxing `WorldValidator`'s one-altar-per-area rule and deciding what attuning two altars means.
- A way out of a fight that cannot be won (a "give up") is not offered: rebirth is the way out, and a fight where the boss cannot be damaged would be a bug, covered by the tests.
- Which other creatures become bosses, and whether the deep areas each get one, is open.
- The map does not mark a boss room.
