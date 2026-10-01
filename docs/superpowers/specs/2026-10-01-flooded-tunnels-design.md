# The Flooded Tunnels — Design

Status: draft (2026-10-01). Sub-project 6, the third area. It builds on the exploration spec (`2026-09-28-exploration-world-design.md`:
the Flooded Tunnels, deep water, Swim, the shock creatures), the Fungal Grotto (`2026-09-29-fungal-grotto-design.md`: the template
for an area, its pacing and its climb chains) and the room editor (`2026-10-01-room-editor-p3-design.md`: a new biome is data, so
the area is authored in the editor and the editor learns water). The art for the biome already ships: `assets/tiles/flooded`,
`assets/backgrounds/flooded` and the `flooded_*` decor rows in `DecorLib`.

## Inspiration

The two series the game borrows its spirit from give this area its mood and its roster:

| Source | What it gave |
|---|---|
| *That Time I Got Reincarnated as a Slime* | The lizardmen of the marsh: a **Bog Lizardman** that holds a post and throws a spear. The slime's own kit (Predator, Water Blade, Black Lightning) is why the area adds shock and a water skill |
| *So I'm a Spider, So What?* | The labyrinth's water stratum: a flooded dungeon you cannot simply walk through, with strange things in the water and the player learning to move in it. The **Glass Eel**, **Drift Jelly** and **Cave Crayfish** are this area's own cave-lake creatures in that spirit |

Nothing here copies a name or a design: the creatures and skills keep the game's own names.

## Goal

Ship the third area. You drop into it from the Glow Pool (G4) and can climb back. It adds five core rooms (F1–F5) and one optional rare
room (F6), four creatures and one rare one, deep water and swimming (a gate that needs the new Swim skill), the shock damage type and
essence with the Jolt skill, a rebirth pool with the second real kit, and the editor's Water tool so the rooms are authored the way
every other room is.

The Storm Eel, its derived sheet and F6 are one isolable slice at the end of the build order, like the Pale Moth: the core area ships
and tests without it. The editor's Water tool is the other slice: the editor shows and keeps water without it.

## Decisions

| Topic | Decision |
|---|---|
| Entry | G4's floor opens: a `bottom` exit from G4 to F1's `top`, two-way (a ledge chain under the drop, the same `Prefabs` stamp the Grotto's chains use) |
| Rooms | F1 Seep Mouth (2×1), F2 Sump (1×2, the Swim gate), F3 Eel Run (3×1), F4 Marsh Hall (2×1), F5 Glow Pool (1×1, holds the tablet; the area's last room); optional slice F6 Storm Pocket (1×1) |
| Water | `RoomDef.water`: deep water rects. Shallow water is decor only (the `flooded_*` decor and the tile art), as in the exploration spec |
| Swim | A proficiency skill learned by being underwater (`submerged` ×20). F2's way on is a water-filled shaft only a swimmer can climb |
| Shock | A new damage type that ignores armor, a new essence `shock`, and Jolt, the player's burst |
| Creatures | Glass Eel, Cave Crayfish, Drift Jelly, Bog Lizardman; in the slice the rare Storm Eel (a derived sheet of the Glass Eel, no new drawing) |
| Art | The creatures' frames are generated one at a time (the Grotto's pipeline), assembled into sheets with traced shapes, then drawn like every creature. The tiles, backgrounds and decor exist; `simple_layers` is on, so no dressing library is needed. Two skill icons (Swim, Jolt) |
| Rebirth | F1 holds the area's pool and the second real kit (below) |
| Pacing | One rule, below: the Flooded's first pass pays real XP but cannot reach stage 2's cap alone |
| Out of scope | The Serpent Lair, the sealed arena and victory; Storm Jet (the Jolt + Hydraulic Propulsion evolution); the Deep (the next spec); a behaviour framework for `Enemy` |

## Layout

Cells are screens (640×360). G4 is cell (10,7), 1×1, x 6400–7040, y 2520–2880.

```
[G4 Glow Pool (10,7)]
      │ bottom exit (two-way, ledge chain)
[F1 Seep Mouth 2×1 (10,8)]─east─[F2 Sump 1×2 (12,7)]
                                      │ top exit, gate "swim" (a water-filled shaft)
         [F3 Eel Run 3×1 (12,6)]─east─[F4 Marsh Hall 2×1 (15,6)]
                                              │ bottom exit (two-way, ledge chain)
                                      [F5 Glow Pool 1×1 (15,7)]       (F6 Storm Pocket 1×1 (17,6): east of F4, a gated swim exit)
```

World pixels: F1 x 6400–7680, y 2880–3240; F2 x 7680–8320, y 2520–3240; F3 x 7680–9600, y 2160–2520; F4 x 9600–10880, y 2160–2520;
F5 x 9600–10240, y 2520–2880; F6 x 10880–11520, y 2160–2520. No two overlap and every neighbour pair shares an exact world span (the
validator already enforces both). The map tab's bounds grow from 11×9 to 18×9 cells.

- **F1** (the landing): a soft floor under G4's drop, the area's rebirth pool a little way in, a first crayfish, and the **learning pool**: a
  deep pool (about 200×90 px) with a ledge chain out whose every rise is within a bob (below). Twenty seconds in it teaches Swim. A jelly
  hangs in it so the pool is not free time.
- **F2** (the gate): a tall room whose shaft is water from its floor to the top exit. The west exit from F1 is on its lower row. Without
  Swim you can stand at its bottom and look up; with it you swim up and out. No ledge stands inside the water.
- **F3** (eels): a wide corridor, deep water along its lower part with eels and jellies, dry ledges above. The shaft arrives at its floor.
- **F4** (the marsh): shallow water decor and dry platforms, the lizardmen's post, crayfish. A ledge chain under its floor hole reaches F5.
- **F5** (the end): the Glow Pool and the tablet, the area's last room.
- **F6** (slice): a rare pocket behind a second gated swim exit, with the Storm Eel.

### Traversal (nothing is a one-way drop)

- The two floor holes (G4→F1 and F4→F5) each get a ledge chain back up, from the `Prefabs` stamp, with the Grotto's geometry rules (the
  top ledge at local y 12–15, flush with the span's west edge, every hop at most 55 px rise).
- A swimmer can go anywhere. A non-swimmer walks into F2 through its west door and stands on its floor (slowed by the water), and walks
  back out the same way: the only thing they cannot do is leave through the gated top exit, so they are never stuck.
- A new **directed** reachability test (extending the Grotto's chain test) covers the two chains, and a new **gate test** derives the
  Swim gate rather than hand-copying it: the bob apex `B` is computed from the constants (`BOB_VELOCITY² / (2 · GRAVITY · WATER_GRAVITY)`
  = 160² / (2 · 900 · 0.35) = 40.6 px), and the test asserts that no standing surface inside F2's water is within `B` of the next one up
  and that the lowest sill reaches at least `B + 3` above the highest surface a non-swimmer can stand on in the shaft (the same shape as
  the Grotto's chimney `T`).

## Water and swimming

- `RoomDef.water` is an array of `Rect2` (local px), at least 24×24 and inside the room. `RoomBuilder.build_room` builds one `WaterZone`
  (an `Area2D` in group `water`) per rect, drawn as a translucent tint with a lighter surface line and bubbles while the player is under;
  solids draw in front of it. `WaterZone.contains(world_point)` is the one query everything uses.
- The player is **in water** while the centre of its body is inside a water rect.
- **Without Swim**, in water: horizontal speed ×0.6, gravity ×0.35, a sink cap of 60 px/s, and a Jump is a **bob** (−160 velocity) that
  works only while grounded (on the floor or a ledge) or on a wall with Wall Cling; there is no mid-water jump. So a non-swimmer climbs
  a ledge chain of rises up to 40.6 px and nothing taller.
- **With Swim**, in water: no gravity, 8-way movement at the Swim level's speed (120 / 150 / 180 px/s) from the same stick or keys that
  steer (`move_left`, `move_right`, `aim_up`, `aim_down`; the right stick still aims), and Jump near the surface launches out of it with the
  normal jump velocity.
- `submerged` is a new player event in `Events.ALL`, emitted once per second spent in water, by the player only. Swim is a proficiency
  (`submerged` ×20 to unlock, ×40 per level, max 3). The event table in the prototype spec gains it, and the validator accepts it.
- No drowning and no damage from water. Entering and leaving it are audio-only world events with cues (`splash_in`, `splash_out`) built
  like the existing cues (every emitted event has a cue).
- Ground creatures ignore water entirely; a walker spawn inside a water rect is lint's `walker_in_water`. A swimmer spawn outside one is
  `swimmer_dry`. A start inside water is `start_in_water`.

## Creatures

New ids: `glass_eel`, `cave_crayfish`, `drift_jelly`, `bog_lizardman` (and `storm_eel` in the slice), added to `Sources.ALL`, generated by
`tools/build_content.gd`, with their portraits read from the creature's own sheet frame.

| Creature | HP | ATK | DEF | SPD | Essences | XP | Behaviour |
|---|---|---|---|---|---|---|---|
| Glass Eel | 4 | 2 | 0 | 140 | shock 1, water 1 | 3 | Swims inside its water rect only. Patrols, then darts at you when you are in the same rect and in sight. Contact shocks you (2 shock) and stuns you for 0.3 s |
| Cave Crayfish | 9 | 3 | 3 | 60 | shell 1, water 1 | 5 | The Crab's armored charger on its own numbers and sheet: patrols, telegraphs, lunges when level with you; stunned only from behind |
| Drift Jelly | 3 | 2 | 0 | 30 | shock 1, water 2 | 3 | Swims inside its water rect, bobbing up and down. Stings on contact (shock) and cannot be tackled: a tackle shocks you instead and does nothing to it. A skill, a thread or Jolt will do |
| Bog Lizardman | 7 | 3 | 1 | 80 | earth 1, water 1 | 5 | Holds a post (a short beat). In sight and level (within 40 px, 140 px away) it stops, raises its spear (a telegraph), then throws it along a flat line at where you were; 3 s between throws; the spear dies on rock. Not armored: a front tackle stuns it |
| Storm Eel (rare, slice) | 10 | 4 | 1 | 160 | shock 3, water 2 | 10 | The Glass Eel's behaviour on a lightened, enlarged derived sheet; its shock stuns for 0.6 s |

First-time value per spawn is twice the XP: eel 6, crayfish 10, jelly 6, lizardman 10, storm eel 20.

### What `CreatureDef` and `Enemy` gain

- `CreatureDef` gains `untackleable` (the jelly) and `shock_stun` (seconds a contact shock stuns, default 0.3), and `swimmer` (the eels and
  the jelly). The crayfish reuses `armored_charger`.
- `Enemy.Kind` gains `SWIMMER` and `THROWER`. A swimmer resolves its **home water**, the rect holding its spawn, once in `setup`; it has no
  gravity and never leaves the rect (`global_position` clamped to it, shrunk by its half body). A swimmer with no home water idles, and lint
  reports it. The eel's `swim` states are patrol and dart; the jelly's are drift and nothing else (a vertical bob, a slow pull toward you).
- The lizardman is a THROWER: its states are ""/windup/throw/rest, through the existing `charge` strings in `EnemyState.pick`, so no new
  parameter. Its spear is a **`Spear`** (a small `Area2D`, group `hazards`, like the toad's glob) flying straight, 220 px/s, one hit,
  2.5 s lifetime, freed on any solid.
- `Enemy.receive_tackle` returns early for `untackleable`, and the tackler takes the jelly's contact hit through the existing contact path.
- Shock: `Damage.hit` ignores armor for `"shock"` as it does for poison; `Player.receive_hit` with `"shock"` also calls a new
  `Player.shock(seconds)`: while it is positive the player's walk input and every action but the pause and the skill screen are ignored
  and a swimmer drifts (no input velocity), then it ends. An invulnerable player is not shocked.
- `data/enemy_clips.json` gains entries keyed by sheet name so every state `EnemyState.pick` can return has a clip; a test walks every
  creature × every state.

### Frames (each generated alone, then assembled with a shared per-creature scale)

- Glass Eel (7): swim ×3 (loop 1,2,3,2), dart, stunned, hurt, downed.
- Cave Crayfish (11): the crab's list (idle, walk ×3, windup, charge ×2, rest, stunned, hurt, downed).
- Drift Jelly (6): drift ×3 (loop 1,2,3,2), stunned, hurt, downed.
- Bog Lizardman (11): idle, walk ×3, windup (spear raised), throw, rest, stunned, hurt, downed.
- Storm Eel: derived from the eel's frames (`derive_from`, `lighten`, an enlarge factor); no prompts.
- Their deaths, corpses, hit shapes and the contact fairness rules are the Cave's.

## Skills and essences

| Skill | Source | Unlock | Effect | Levels |
|---|---|---|---|---|
| Swim | proficiency | `submerged` ×20 | Swimming as above | `submerged` ×40, max 3: 120 / 150 / 180 px/s |
| Jolt | essence | absorb shock ×4 | Active, 5 MP: a burst of shock around you (radius 40) that deals 3/4/5/6/7 shock and stuns jellies and eels for 1.5 s | used ×8, max 5 |

- `shock` joins `Essences.ALL` (it feeds Jolt). `water` and `shell` already exist.
- Jolt is an `Ability` modelled on `poison_breath`: it spawns a short-lived `Area2D` on the player and calls the enemy's hit path with the
  shock type. It never hurts the player. Both skills get icons, generated like the existing ones and added to `tools/art/manifest.json`.
- Registration surfaces: `Essences.ALL`, `Events.ALL`, `Sources.ALL`, `tools/build_content.gd` (skills and creatures), the icon manifest,
  `test_skill_caps` `TABLE`, `DefValidator`, the compendium and the skill screen's effect text (Swim's speed line).

## Rebirth

- F1's `rebirth_pool` has id `F1`, area `flooded`, and the kit: skills Leap, Wall Cling and Swim (level 1, quietly granted), character level
  4, and affinity seeds chosen by a test, not by hand (as the Grotto's: at least two lineages eligible, and more than the same life would
  have without the seeds). A life reborn at F1 skips the learning pool and meets F2's gate already able to pass it; that is the pool's
  purpose, the same as G1 granting Wall Cling.

## The editor learns water

- `RoomDef.water` is part of `RoomEditModel`'s snapshots (undo and redo restore it) and of the room file's save and load.
- The **Water tool** draws a rect exactly as the Solid tool does (same drag, same snap, same minimum), selects with kind `water`, moves,
  deletes, and has inspector fields X, Y, Width, Height (the solid panel's fields, no ledge check). `hit_all` lists water last (it is a
  volume, not a thing: any spawn, feature, decor, exit or solid in it is hit first). The room view draws it with the in-game tint and a
  blue outline when selected; the World view needs no change.
- `RoomLint` gains `water_outside_room`, `water_tiny`, `swimmer_dry`, `walker_in_water` and `start_in_water`; the world validator gains
  the `swim` label in `GATES` (a gated exit still must match on both halves).
- The Decor tool already offers the `flooded_*` pieces for a flooded room.

## Pacing

One rule, computed by a test from the room data. It sums each spawn's `xp` directly (never through a `Progression`, which stops paying at
the cap), over the Flooded's non-optional rooms (F1–F5, gated rooms included, F6 never):

- The Flooded's first pass is at least 150 XP, so a stage-1 life that has just evolved in G4 meets real payoff here.
- It is below stage 2's cap, 403, so stage 2's evolution needs more than this area.

A guide, not a contract: F1 2 crayfish and 2 jellies (32); F2 2 eels (12); F3 4 eels and 3 jellies (42); F4 4 lizardmen and 3 crayfish
(70); F5 2 eels and 2 lizardmen (32) sum to 188.

## Existing tests rescoped

`test_rooms` (the room id list), `test_constants` (`Sources.ALL`, `Essences.ALL`, `Events.ALL`), `test_content` (counts of skills and
creatures; its "every essence skill is supplied" check learns shock), `test_enemy_sheets` (`SETS`), `test_skill_caps` (`TABLE`), the
rebirth kit tests (the F1 pool and the supply check), `test_world_view` (the map's bounds), `test_room_lint` (the rules count) and the
progression pacing tests (Cave and Grotto rules stay scoped to their areas).

## Testing approach

- Data: every room validates; spawn keys unique; the pacing rule; the F1 kit meets the eligibility test; every world event has a cue; no
  spawn or decor over a floor hole; the water lint rules.
- Water: a body in a rect is in water, one outside is not; each non-swim modifier on the exact constants; Swim moves 8-way and leaves at
  the surface; `submerged` once per second only in water; Jump in water is a bob only when grounded.
- Traversal: the directed chain test and the derived Swim gate test; every F room is reachable from the start by a swimmer, and F3–F5 only
  past the gated exit.
- Creatures: each behaviour scripted (eel confined to its rect, darts, shocks and stuns; jelly drifts and ignores a tackle; crayfish and
  lizardman telegraph; the spear flies straight and dies on rock); every sheet loads with every frame; every creature × state has a clip.
- Skills: Jolt stuns jellies and eels and never the player; Swim unlocks and levels from `submerged`.
- Editor: the Water tool draws, selects, moves, deletes, undoes; the snapshot keeps water; the lint rules fire from a room built in a test.
- Real screenshots of each room, each creature, the swim (in and out of water) and the editor's water.

## Build order

1. Data: `RoomDef.water`, `Events.SUBMERGED`, the shock type and essence, the two skills and four creature defs and their registration, the
   `CreatureDef` flags, the lint and validator checks, the rescoped tests.
2. Water: `WaterZone`, the builder, the player's modifiers and swim, `Player.shock`, the audio cues.
3. Art: the four creature frame sets and the two icons, generated in parallel.
4. Behaviours: swimmer, thrower and `Spear`, `Jolt`, the clips.
5. Rooms: F1–F5 authored through the editor model, the stamps and chains, the gate, the F1 pool and kit, G4's hole (moving its contents).
6. The editor's Water tool (a slice).
7. The optional slice: the derived Storm Eel sheet, def and clips, and F6.
8. Review, gate, merge.
