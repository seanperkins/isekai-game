# The Flooded Tunnels — Design

Status: revised after debate round 1 (2026-10-01). Sub-project 6, the third area. It builds on the exploration spec
(`2026-09-28-exploration-world-design.md`: the Flooded Tunnels, deep water, Swim, the shock creatures), the Fungal Grotto
(`2026-09-29-fungal-grotto-design.md`: the template for an area, its pacing and its climb chains) and the room editor
(`2026-10-01-room-editor-p3-design.md`: a new biome is data, so the area is authored with the editor's model). The art for the biome already
ships: `assets/tiles/flooded`, `assets/backgrounds/flooded` and the `flooded_*` decor rows in `DecorLib`.

## Inspiration

| Source | What it gave |
|---|---|
| *That Time I Got Reincarnated as a Slime* | The lizardmen of the marsh: a **Bog Lizardman** that holds a post and throws a spear. The slime's own kit (Predator, Water Blade, Black Lightning) is why the area adds shock and a water skill |
| *So I'm a Spider, So What?* | The labyrinth's water stratum: a flooded dungeon you cannot simply walk through, with strange things in the water and a body that has to learn to move in it. The **Glass Eel**, **Drift Jelly** and **Cave Crayfish** are this area's own cave-lake creatures in that spirit |

Nothing here copies a name or a design: the creatures and skills keep the game's own names.

## Goal

Ship the third area. You drop into it from the Glow Pool (G4) and can climb back. It adds five core rooms (F1–F5) and one optional rare room
(F6), four creatures and one rare one, deep water and swimming, the shock damage type and essence with the Jolt skill, a rebirth pool with
the second real kit, and water in the editor.

Two isolable slices sit at the end of the build order and the core ships and tests without either: **the rare slice** (the Storm Eel, its
derived sheet and F6) and **the Water tool** (the editor's draw, select, move, delete and inspector for water). The core editor work is
smaller and not optional: water survives every editor operation, shows in the room view and is linted.

## Decisions

| Topic | Decision |
|---|---|
| Entry | G4's floor opens: a `bottom` exit from G4 to F1's `top`, two-way (a ledge chain under the drop, the same `Prefabs` stamp the Grotto's chains use) |
| Rooms | F1 Seep Mouth (2×1), F2 Sump (1×2, a water column), F3 Eel Run (3×1), F4 Marsh Hall (2×1), F5 Glow Pool (1×1, holds the tablet; the area's last room); slice: F6 Storm Pocket (1×1, above F4) |
| Water | `RoomDef.water`: deep water rects. Shallow water is decor only (the `flooded_*` decor and the tile art), as in the exploration spec |
| Swim | A proficiency learned by being underwater (`submerged` ×20). Water cannot trap anyone, because twenty seconds in it teaches the way out. A water column is the Swim door; the Grotto's rule applies to it (a graph label, and other traversal skills may pass) |
| Shock | A new damage type (armor already applies to physical only), a new essence `shock`, and Jolt, the player's burst |
| Creatures | Glass Eel, Cave Crayfish, Drift Jelly, Bog Lizardman; in the slice the rare Storm Eel (a derived sheet of the Glass Eel, no new drawing) |
| Art | The creatures' frames are generated one at a time (the Grotto's pipeline), assembled into sheets with traced shapes. Tiles, backgrounds and decor exist; `simple_layers` is on, so no dressing library is needed. Two skill icons (Swim, Jolt) |
| Evolution | The first evolution's affinity reads the supply of the areas a stage-1 life plays (`FormOffers.FIRST_EVOLUTION_AREAS`), so a later area does not dilute it (below) |
| Rebirth | F1 holds the area's pool and the second real kit |
| Pacing | One rule, below: the Flooded's first pass pays real XP but cannot reach stage 2's cap alone |
| Out of scope | The Serpent Lair, the sealed arena and victory; Storm Jet (the Jolt + Hydraulic Propulsion evolution); impulse damping in water; the Deep (the next spec); a behaviour framework for `Enemy` |

## Layout

Cells are screens (640×360). G4 is cell (10,7), 1×1, x 6400–7040, y 2520–2880.

| row \ col | 10 | 11 | 12 | 13 | 14 | 15 | 16 |
|---|---|---|---|---|---|---|---|
| 5 | | | | | | F6 (slice) | |
| 6 | | | F3 | F3 | F3 | F4 | F4 |
| 7 | G4 | | F2 | | | F5 | |
| 8 | F1 | F1 | F2 | | | | |

G4's bottom exit is F1's top (two-way, a ledge chain). F1's east exit meets F2's lower row. F2's top exit (gate `swim`) is F3's floor hole. F3's east exit meets F4's west. F4's bottom exit is F5's top (two-way, a ledge chain). In the slice, F4's top exit (gate `swim`) is F6's floor hole.


World pixels: F1 x 6400–7680, y 2880–3240; F2 x 7680–8320, y 2520–3240; F3 x 7680–9600, y 2160–2520; F4 x 9600–10880, y 2160–2520; F5
x 9600–10240, y 2520–2880; F6 x 9600–10240, y 1800–2160. No two overlap (nor any Cave or Grotto room), and every neighbour pair shares an
exact world span (the validator enforces both). The map tab's room count goes from 11 to 16 (17 with F6); its bounds are computed from the
rooms.

- **F1** (the landing): a soft floor under G4's drop, the area's rebirth pool a little way in, a first crayfish, and the **learning pool**: a
  deep pool (about 200×90 px) with a stepped shallow end. Twenty seconds in it teaches Swim; a jelly hangs in it so the pool is not free time.
- **F2** (the first door): a tall room whose water column runs from its floor to the top exit, with no ledge inside it. F1's east exit
  enters on its lower row. A non-swimmer walks in and stands in the water; twenty seconds there teaches Swim, and then the column is
  climbable. Its top exit opens into F3's floor, whose lower water covers the span so a swimmer keeps swimming through.
- **F3** (eels): a wide corridor, deep water along its lower part with eels and jellies, dry ledges above.
- **F4** (the marsh): shallow-water decor and dry platforms, the lizardmen's post, crayfish. A ledge chain under its floor hole reaches F5. In
  the slice, a second water column rises in its left half to a top exit into F6.
- **F5** (the end): the Glow Pool and the tablet, the area's last room.
- **F6** (slice): a rare pocket above F4's column, with the Storm Eel.

### Traversal (nothing is a one-way drop)

- The two floor holes (G4→F1 and F4→F5) each get a ledge chain back up, from the `Prefabs` stamp, with the Grotto's geometry rules (the
  top ledge at local y 12–15, flush with the span's west edge, every hop at most 55 px rise). A new **directed** reachability test covers the
  two chains.
- Water cannot trap you. A non-swimmer who sinks into any water, a pit with no way out included, accrues `submerged` and learns Swim after
  20 s, and a swimmer can leave. So the area has no geometry rule for a non-swimmer's exit; the only rules are about the doors.
- A water column's door is **structural**, derived like the Grotto's chimney `T`, not hand-copied: the bob's apex is
  `B = BOB_VELOCITY² · (jump_height / 100) / (2 · GRAVITY · WATER_GRAVITY)`, with the jump height at stage 2's ceiling (Leap 8 and Echo's
  +10, 155) = 160² · 1.55 / (2 · 900 · 0.35) = 63.0 px. A new **gate test** (run on F2's column, and F4's in the slice) asserts that no solid
  lies inside the water column between its floor and its sill (a ledge inside defeats it) and that the sill is at least `B + 3` above the
  floor. A swimmer needs nothing else.
- A **Wall Cling** wall jump is a dry-land move: in water, without Swim, a wall gives no bob, so Wall Cling alone does not climb a column. Other
  traversal skills (Hydraulic Propulsion, whose impulse is not damped in water, and threads) may pass the column, exactly as Wall Cling,
  Sticky Thread and Hydraulic Propulsion may reach G5 and C3. The column is a door for Swim, not a wall against everything.

## Water and swimming

- `RoomDef.water` is an array of `Rect2` (local px), each at least 32×32 and inside the room. `RoomBuilder.build_room` builds one **`DeepWater`**
  per rect: a `Node2D` holding its rect in group `deep_water`, drawn as a translucent tint with a lighter surface line and bubbles while the
  player is under; solids draw in front of it. `DeepWater.contains(tree, world_point)` is the one query everything uses.
- The player is **in water** while the centre of its body is inside a water rect.
- **Without Swim**, in water: horizontal speed ×0.6, gravity ×0.35 (`WATER_GRAVITY`), a sink cap of 60 px/s, and a Jump is a **bob**:
  `−160 · sqrt(jump_height / 100)` (`BOB_VELOCITY` is 160; the boost is the dry jump's), allowed only from the floor or a ledge. A wall gives
  nothing. There is no mid-water jump.
- **With Swim** (a capability `swim` plus a modifier on a new stat `swim_speed`, base 120, values `[0, 30, 60]` by level, so 120 / 150 /
  180 px/s): in water, no gravity and 8-way movement from the same stick or keys that steer (`move_left`, `move_right`, `aim_up`,
  `aim_down`; the right stick still aims). Jump while the body centre is within `SURFACE_REACH` (24 px) of the top edge of its water rect
  launches out of it at the normal jump velocity, and the player is out of the water when its centre leaves the rect.
- `submerged` is a new player event in `Events.ALL`, emitted once per second spent in water by the player only (the Events doc, which says
  every event is edge-triggered, learns this one is periodic). Swim is a proficiency: `submerged` ×20 to unlock, ×40 per level, max 3.
- No drowning and no damage from water. Entering and leaving water emit the existing audio-only world events `water_entered` and
  `water_exited` (`data/audio/cues.json` already maps them to `water_in` and `water_out`; `test_audio_boundary`'s `reserved` list drops them),
  from the player's in-and-out edge.
- A knockback in water is untouched (no special rule).
- Lint (below) reports a swimmer spawn outside water; a ground creature in water just walks (nothing special: the tint is cosmetic to it).

## Creatures

New ids: `glass_eel`, `cave_crayfish`, `drift_jelly`, `bog_lizardman` (and `storm_eel` in the slice), added to `Sources.ALL`, generated by
`tools/build_content.gd`, with their portraits read from the creature's own sheet frame.

| Creature | HP | ATK | DEF | SPD | Essences | XP | Behaviour |
|---|---|---|---|---|---|---|---|
| Glass Eel | 4 | 2 | 0 | 140 | shock 1, water 1 | 3 | Swims inside its water rect only. Patrols, then darts at you when you are in the same rect and in sight. Contact shocks you (2 shock) and stuns you for 0.3 s |
| Cave Crayfish | 9 | 3 | 3 | 60 | shell 1, water 1 | 5 | The Crab's armored charger on its own numbers and sheet: patrols, telegraphs, lunges when level with you; stunned only from behind |
| Drift Jelly | 3 | 2 | 0 | 30 | shock 1, water 2 | 3 | The moth's drifter (no gravity, a vertical bob, a slow loop) confined to its water rect. Stings on contact (2 shock, 0.3 s) and cannot be tackled: a tackle skips it (it is not a target) and touching it hurts. Jolt, a thread or a skill will do |
| Bog Lizardman | 7 | 3 | 1 | 80 | earth 1, water 1 | 5 | The toad's spitter with a spear: holds a post, and in sight and level (within 40 px, 140 px away) it raises its spear (the windup), throws it flat at where you were (the throw pose), and waits 3 s. The spear is a `SpitBlob` without gravity and with a physical hit, freed on any rock the ray finds (the blob's own test). Not armored: a front tackle stuns it |
| Storm Eel (rare, slice) | 10 | 4 | 1 | 160 | shock 3, water 2 | 10 | The Glass Eel's behaviour on a lightened, enlarged derived sheet; its shock stuns for 0.6 s |

First-time value per spawn is twice the XP (down plus eat, paid once each): eel 6, crayfish 10, jelly 6, lizardman 10, storm eel 20.

### What `CreatureDef` and `Enemy` gain

- `CreatureDef` gains `swimmer` (the eels and the jelly: confined to a water rect, and the one flag Jolt's stun reads), `untackleable`
  (the jelly), `contact_type` (default `"physical"`; the eels and the jelly are `"shock"`), `shock_stun` (seconds, default 0.3),
  `projectile` (`"glob"` default, `"spear"` for the lizardman) and `puffs` (the two moths: the spore puff in `_drift_act` is gated on it, so
  the jelly drifts without puffing). The crayfish reuses `armored_charger`.
- **Contact.** `Enemy`'s contact hit reads `def.contact_type` where it now hard-codes `"physical"`; after a shock hit lands it calls
  `player.shock(def.shock_stun)`. `Player.shock(seconds)` is `_dash = maxf(_dash, seconds)`: the same lock a hit's knockback already uses (no
  walk input, no swim input velocity while it runs). Gating the other actions is a later change if a playtest says the stun is too weak.
- **Kinds.** `Enemy.Kind` gains one value, `SWIMMER` (the eels). `_resolve_kind` precedence becomes: the vine snake by id, a ceiling walker, a
  drifter, **a swimmer**, a flier, an armored charger, a spitter. Confinement is not a Kind: for any creature with `def.swimmer`, the
  **home water** (the rect holding its position) is resolved on the first physics frame (a spawn's position and room are not set when
  `setup` runs), and its position is clamped to that rect, shrunk by its half body, after every move. A swimmer with no home water
  idles, and lint reports it. The eel's states are `""` and `dart`, exposed through `charge_state()` (which widens to SWIMMER); the jelly
  has no state beyond the drifter's.
- **Animation.** `EnemyState.pick` gets an arm for every new id: the eels `swim` / `dart` (on `charge`), the jelly `drift`, the crayfish the
  crab's, the lizardman the toad's `puff` (windup) and `spit` (throw). `data/enemy_clips.json` gains each sheet's clips, and the test that
  walks every creature × every state still passes.
- **Tackle.** A creature with `untackleable` is skipped by the player's tackle-target search, so a tackle toward a jelly does nothing and
  never swallows a tackle aimed at a creature behind it.
- **Jolt.** An ability modelled on `poison_breath`: it iterates the `actors` group, takes every enemy within its radius (a distance test, no
  new node), calls `receive_hit(damage, "shock")` and, for a creature with `swimmer`, `status.stun(1.5)` (`EnemyStatus.stun` takes seconds).
  It never hurts the player. A stunned jelly is eatable, so Jolt is also the jelly's XP.

### Frames (each generated alone, then assembled with a shared per-creature scale)

- Glass Eel (7): swim ×3 (loop 1,2,3,2), dart, stunned, hurt, downed.
- Cave Crayfish (11): the crab's list (idle, walk ×3, windup, charge ×2, rest, stunned, hurt, downed).
- Drift Jelly (6): drift ×3 (loop 1,2,3,2), stunned, hurt, downed.
- Bog Lizardman (9): idle, walk ×3, windup (spear raised), throw, stunned, hurt, downed.
- Storm Eel: derived from the eel's frames (`derive_from`, `lighten`, an enlarge factor); no prompts.
- Their deaths, corpses, hit shapes and the contact fairness rules are the Cave's. The jelly is the one exemption from "you can hit what
  can hit you" (`test_hit_fairness`'s principle): it cannot be tackled, so its entry in that test says so.

## Skills and essences

| Skill | Source | Unlock | Effect | Levels |
|---|---|---|---|---|
| Swim | proficiency | `submerged` ×20 | Swimming as above | `submerged` ×40 per level, max 3: 120 / 150 / 180 px/s |
| Jolt | essence | absorb shock ×4 | Active, 5 MP: a burst of shock around you (radius 40) that deals 3/4/5/6/7 shock and stuns swimmers for 1.5 s | used ×8, max 5 |

- `shock` joins `Essences.ALL` (it feeds Jolt) and `RebirthKit.ESSENCES` (a kit may seed it). `water` and `shell` already exist.
- Registration surfaces: `Essences.ALL`, `RebirthKit.ESSENCES`, `Events.ALL`, `Sources.ALL`, `StatKeys` and `Stats` (`swim_speed`), the
  skill screen's stat label and effect text (Swim's speed line), `tools/build_content.gd` (skills and creatures), the icon manifest (Swim
  and Jolt get icons, generated like the existing ones), `test_skill_caps`'s `TABLE`, `DefValidator`, the compendium.
- `Damage.hit` already applies armor to `"physical"` only, so shock needs no change there; one test pins it.

## Evolution supply (the first evolution is not diluted)

`FormOffers.supply` today counts every spawn of every room on disk, and the stage 1 → 2 affinity is units absorbed over that supply
(`ELIGIBLE` 0.6). The Flooded adds 29 water units to a world that has 9, so a life that evolves in G4 (the Grotto's pacing rule) could
reach at most 9/38 = 0.24 Tide affinity where a Cave life reaches it today, and Bulwark dilutes the same way (44 to 55).

- `FormOffers.FIRST_EVOLUTION_AREAS := ["cave", "grotto"]` and `supply` takes an optional `areas` filter. `default_supply` passes the
  constant: the affinity that picks the first evolution divides by the supply of the areas a stage-1 life plays. Later areas add no
  denominator, and stage 2 → 3 and 3 → 4 are not by affinity.
- A test derives the constant instead of trusting it: the ungated first-time XP of those areas is at least stage 1's cap (270) and the
  same without the last area is below it (the Grotto's rule, restated for the list). A life reborn in the Flooded counts its Flooded
  absorptions in the numerator in full, so its affinities can pass 1 (it ate water things in a water place: Tide first).
- `test_form_offers`, `test_form_tab` and `test_rebirth_kit` pin their supply to the Cave and Grotto already; they gain the explicit scope.

## Rebirth

- F1's `rebirth_pool` has id `F1`, area `flooded`, and the kit: skills Leap, Wall Cling and Swim (level 1, quietly granted), character
  level 4, and affinity seeds chosen by a test, not by hand. The test counts the lineages eligible from the seeds plus what a life eats in
  F1 and F2 (the rooms before the first door) against the first-evolution supply, and asserts at least two are eligible and more than the
  same life has without the seeds.
- A level-4 life needs 25 + 30 + 35 + 40 + 45 + 50 = 225 XP to the cap. The Flooded's whole first pass is 188, so an F1 life reaches its
  first evolution by climbing back up to the Grotto (the chain under G4) or the Cave as well, which is by design: a test asserts that a
  life started at the kit's level can reach the cap from the ungated XP of every room reachable from F1 with Swim.

## Editor and lint

Core (not optional):
- `RoomDef.water` rides `RoomEditModel`'s snapshots, undo and redo and the room file for free (`_props()` copies every exported property).
  `_shift_content` gains a `water` arm so a Grow to the west or north does not detach water from its solids and swimmers (with a case in
  `test_room_edit_grow`).
- The room view draws water read-only with the in-game tint. `RoomLint` gains `water_rect` (a rect outside the room, or smaller than
  32×32) and `swimmer_dry` (a swimmer spawn outside every water rect). `WorldValidator.GATES` gains `swim` (a gated exit still matches on both
  halves), and `docs/rooms.md` says so.

Slice (the Water tool, droppable):
- The **Water tool** draws a rect as the Solid tool does (same drag and snap, minimum 32), selects with kind `water`, moves, deletes, and has
  inspector fields X, Y, Width, Height. `hit_all` lists water last (it is a volume: anything in it is hit first). The kind needs an arm in each
  place a kind is listed (the selection-kinds doc and `hit_all`'s comment, `begin_move`, `move_to`, `delete_selection`, `get_field`,
  `set_field`, the lint `pick` so Validate selects it, the room view's outline, the toolbar and the inspector).

## Pacing

One rule, computed by a test from the room data. A spawn's **first-time value** is twice its `xp` (the down and again the eat; a
`water_pool` pays once), the Grotto's own sum. The rule is over the Flooded's non-optional rooms (F1–F5, gated rooms included, F6 never):

- The Flooded's first pass is at least 150, so a stage-1 life that has just evolved in G4 meets real payoff here.
- It is below stage 2's cap, 403, so stage 2's evolution needs more than this area.

A guide, not a contract: F1 2 crayfish and 2 jellies (20 + 12); F2 2 eels (12); F3 4 eels and 3 jellies (24 + 18); F4 4 lizardmen and 3
crayfish (40 + 30); F5 2 eels and 2 lizardmen (12 + 20) sum to 188. Jellies pay only with a stun source (Jolt, a thread), so a life without
one collects 164, still over 150.

## Existing tests rescoped

`tests/support/shipped_rooms.gd` (`IDS`, and its docstring's room and rule counts), `test_rooms` (the room id list), `test_constants`
(`Sources.ALL`, `Essences.ALL`, `Events.ALL`), `test_content` (counts of skills and creatures; its "every essence skill is supplied" check
learns shock), `test_enemy_sheets` (`SETS`), `test_skill_caps` (`TABLE`), `test_decor_lib` (its used-id pins change when the F rooms use
`flooded_*` pieces), the rebirth kit tests (the eligibility test skips every pool outside the Grotto and hard-codes G1–G4 as the rooms a life
eats in: it learns F1 and F1/F2), `test_world_view` (the room count, 11 to 16/17), `test_audio_boundary` (`reserved`), `test_hit_fairness`
(the jelly), `test_room_lint` (the rules count, 13 to 15), `test_form_offers` (the scoped supply), and the progression pacing tests (the Cave
and Grotto rules stay scoped to their areas).

## Testing approach

- Data: every room validates; spawn keys unique; the pacing rule; the F1 kit eligibility; the first-evolution areas rule; every world event
  has a cue; no spawn or decor over a floor hole; the two water lint rules.
- Water: a body in a rect is in water, one outside is not; each non-swim modifier on the exact constants, with the bob boosted by
  `jump_height` and no bob from a wall; Swim moves 8-way and leaves at the surface within `SURFACE_REACH`; `submerged` once per second and
  only in water; a non-swimmer who stays 20 s in F2's column learns Swim.
- Traversal: the directed chain test and the gate test on each column.
- Creatures: each behaviour scripted (eel confined to its rect, resolved after the spawn is placed, darts, shocks and stuns; jelly drifts,
  never puffs, is skipped by a tackle; crayfish and lizardman telegraph; the spear flies flat and dies on rock); every sheet loads with every
  frame; every creature × state has a clip.
- Skills: Jolt stuns swimmers, damages the rest and never the player; Swim unlocks and levels from `submerged`.
- Editor: water survives snapshot, undo, redo, save and a Grow; the lint rules fire from a room built in a test; and in the slice, the Water
  tool draws, selects, moves, deletes and undoes.
- Real screenshots of each room, each creature, a swim (in and out of water) and the editor's water.

## Build order

1. Data: `RoomDef.water`, `Events.SUBMERGED`, the shock essence, the two skills and four creature defs and their registration, the
   `CreatureDef` flags, the lint and validator checks, the first-evolution supply scope, the rescoped tests.
2. Water: `DeepWater`, the builder, the player's modifiers and swim, `Player.shock`, the audio edges.
3. Art: the four creature frame sets and the two icons, generated in parallel.
4. Behaviours: the eel's `SWIMMER`, the jelly's puff gate and confinement, the lizardman's spear, `Jolt`, the clips.
5. Rooms: F1–F5 authored through the editor model, the stamps and chains, the F2 column and its gate test, the F1 pool and kit, G4's hole
   (moving its contents).
6. The editor core (water kept, shifted, drawn, linted).
7. The Water tool (a slice).
8. The rare slice: the derived Storm Eel sheet, def and clips, F4's second column and F6.
9. Review, gate, merge.

## Rulings made in this spec

- Hydraulic Propulsion and threads may pass a water column (the Grotto's rule for G5 and C3): damping impulses in water is out of scope. Wall
  Cling alone does not (a wall gives no bob in water). Cost if wrong: a water-essence life skips Swim's door.
- The Swim door is self-teaching: 20 s in the column teaches Swim, so the F1 pool is a convenience, and water can never trap anyone. Cost if
  wrong: the door costs a delay, not a decision.
- The supply for the first evolution is scoped to the Cave and Grotto by a constant a test derives (not recomputed from "rooms reachable
  before the first evolution"). Cost if wrong: a fifth area must edit the constant if it feeds the first evolution.
- The shock stun reuses the hit lockout (`_dash`); action gating is deferred.
- The Bog Lizardman stays (the user asked for creatures from these series) but is the toad's spitter with a projectile flag, not a new Kind.
- The Water tool is a slice, not core; the editor core is the part that keeps water safe.
