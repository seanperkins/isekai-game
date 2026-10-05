# F2: the new areas

What F2 builds and how. Source: `docs/research/area-level-design.md` (the sketches, rules and room budget), `docs/research/species-form-branches.md` section 10 (which creature lives in which area) and `docs/research/items-e2.md` (the buttons and items). F2 ships in pieces, each its own plan, branch and review: **F2a** the builder and the forest, **F2b** swamp and village, **F2c** the sacred cluster (cemetery, cathedral, crypt), **F2d** volcano and demon area, **F2e** the nine deeds that wait on rooms, **F2f** the placement of every creature.

## Built so far

**F2a (built 2026-10-05):** the builder and the forest. `tools/build_areas.sh` writes the rooms (`--check` writes nothing and fails when a room would change); `tools/areas/area_kit.gd` is the kit, `tools/areas/forest.gd` the first module, `tools/areas/areas.gd` the list of modules. Nine forest rooms, FO1 to FO9 (the cells below are the built ones): the Cave Mouth joins C3's right edge (a hop up of 46 from C3's highest ledge, not its top: C3 has no ledge route to its ceiling and a shipped room's solids are not the builder's to change), the Root Hollow drops into C4 and that exit pair carries the label `wall_cling` (one way down; without it C3 and C6 would be reachable without a gate through the forest). Spawns are the four support monsters that name the forest; twins come in F2f. The forest's vertical joins copy the shipped pattern: a zigzag of ledges whose last one stands in the ceiling opening (the Clearing's, as G1's), and a ledge either side of the floor opening above (the Trunk's, as C5's).

**F2b (built 2026-10-05):** the swamp and the goblin village, ten rooms east of the forest. `tools/areas/swamp.gd` (prefix `SW`, five rooms) and `tools/areas/village.gd` (prefix `VI`, four rooms and the Sump). The forest's Den (FO9) opens east onto the Root Seam (SW1, no creatures), the Boardwalk (SW2) crosses to the Bog Flat (SW3), where the Stilt Roost (SW4) climbs above and the Hunting Blind (SW5) lies east; the Bog Flat's floor opens onto the village's Gate Shrine (VI1: a glow pool, no altar, no creatures, so a non-goblin never wakes in a hostile palisade), with the Palisade Roofs (VI2) west of it, the Village Yard (VI3) under both and the Chieftain Hall (VI4) off the Yard. The Yard's floor opens onto the Sump (VI5, area `swamp`, flooded art, a water rect), whose bottom is a second link to the Flooded Tunnels: a hole into F6's top that is a shortcut (`sump_drop`), shut until a swimmer opens it from F6's own highest ledge, where a switch stands (the module attaches it, marked `by`, so the next run strips and rebuilds it). A `swim` label would not hold the hole: a walker sinks through water, drops through F6 and F4 and walks into the Deep. It is a one-way drop; the way back up is the long way round. Spawns are the support monsters that name the area (swamp: blood leech, bog wisp, firefly swarm; village: village goblin, cave rat, junk heap, goblin shaman). The module base gained `link` and `attach_feature`, the kit `AreaKit.climb` (the zigzag up to a ceiling opening) and `AreaKit.flank` (a ledge either side of a floor opening), and `AreaModule.link`. **Art only for now:** mud, murk and the guiding wisps; the village's standing, trust, trial, tame pen and bench. **Not built:** the sketch's verb lanes to the Stilt Roost (zip) and the Hunting Blind (pounce) and the palisade's hard ledges: `GATES` holds only `wall_cling` and `swim`, so every room is reachable on the base jump; the village's one-way drop to the forest Clearing; altars (pools only).

**F2c (built 2026-10-05):** the sacred cluster, thirteen rooms above and east of the Deep: `tools/areas/cemetery.gd` (prefix `CM`), `cathedral.gd` (`CA`, area `sacred`) and `crypt.gd` (`CR`). D7, the antechamber of the Taratect's arena, opens upward onto the Gate Tunnel (CM1, at cell (18,4)) with `gate: wall_cling` on both ends, the label D7's own way in carries (D6, the arena, gains nothing: a boss room has exactly one exit). The Churchyard (CM2, 2x1) is the truce: a glow pool, a tablet, no altar and no spawns; the Lych Gate (CM3) leads east. The cathedral lies north: a climb from the Churchyard up into the Nave (CA1, 3x1, pews), the Transept (CA2) with the Font Chapel (CA3, a pool) beside it, and above the Transept the Bell Shaft (CA4, 1x3), a zigzag to a door onto the Loft (CA5). The crypt lies east: the Crypt Stair (CR1, 1x2) down from the Lych Gate, the Ossuary (CR2), the Niche Gallery (CR3, 3x1) and the Vault (CR4); a hole at the Ossuary's east end drops onto the Coffin Slide (CR5, 2x1), a chute whose own hole drops into D5 (the Deep's dead end gains a top exit): one way down, since D5 has no ledge to climb out by. Spawns are the support monsters that name each area (cemetery: skeleton, ghost, carrion crow; sacred: candle wisp, chapel priest, stained-glass moth, shield guard, gargoyle, ghost; crypt: skeleton, junk heap, vampire bat, bone hound). **Art only for now:** holy beams and the priest's emitter, the safe zone's turn-back, the crypt's curse and dark, the revive link and the traps. **Not built:** the cathedral's species lanes (they need verb gates the validator has no labels for), the cemetery's altar (pools only) and its shortcut, the Churchyard's vista of the nave, a hard-ledge test bed in the Bell Shaft.

## The builder

Rooms stay `RoomDef` resources in `data/rooms/`. The new ones are written by a headless GDScript tool, not by hand: `tools/build_areas.gd` (run by `tools/build_areas.sh`) loads the shipped rooms, builds the rooms each area module in `tools/areas/` describes, attaches them to the shipped world by adding the exits the module names to existing rooms, and saves every changed room with `ResourceSaver` (the same writer the room editor uses, so a re-run changes nothing). An area module builds its rooms with `AreaKit`: `ledge`, `stairs`, `shaft`, `link` (which writes both ends of an exit from one world span), `spawn`, `decor`, `feature`. The tool runs `WorldValidator` and `RoomLint` over the whole world before it writes and refuses to write a world that has a finding.

Art is borrowed (`data/area_art.json`): forest from the grotto, swamp from the flooded tunnels, village, sacred, cemetery and volcano from the cave, crypt and demon from the deep. Decor ids carry the borrowed biome's prefix.

## Where the areas go

The shipped world fills cells x 0 to 23, y 0 to 8. The new areas take free cells (cell = one 640 by 360 screen):

| Area | Cells | Attaches to |
|---|---|---|
| forest | x 3 to 10, y -3 to 1 (built) | C3's right edge (the Cave Mouth), C4's top (a drop) |
| swamp and village | x 11 to 16, y -1 to 4 (built) | the Den's east door, F6's top (the Sump, `swim`) |
| cemetery, cathedral | x 18 to 24, y 0 to 4 (built) | D7's top (the Gate Tunnel, `wall_cling`) |
| crypt | x 22 to 28, y 4 to 6 (built) | the Lych Gate, and D5 (the Coffin Slide) |
| volcano | x 19 to 26, y 9 to 11 | D4's bottom (Ashfall) |
| demon area | x 26 to 30, y 2 to 5 | the crypt or the cathedral (Threshold) |

A module may move a room to a free cell if the sketch's shape needs it; `WorldValidator` rejects an overlap.

## Placement of creatures

Every creature the game has (the 169 new ones) stands in at least one room of one of its areas. `tools/creature_areas.json` (written by `tools/build_creatures.py` from the design table) gives each creature its areas and a class: `common`, `elite`, `rare` (the table's rare, boss, miniboss and guardian) or `npc` (hostile for now: the game has no neutral creature). The placement step gives each room slots by class and puts each creature in the room of its areas with the fewest placed so far (ties by room id), a rare only in a room marked `lair`, each at a floor spot `RoomLint` accepts (`creature_fit`). It adds only spawns whose ids are new creatures and replaces its own on every run, so the hand-authored spawns of the shipped rooms are never touched.

## The nine deeds (F2e)

| Deed | Where it comes from |
|---|---|
| `defeated {moonlit}` | rooms tagged `moonlit` (the forest's open rooms): the player knows it is in moonlight, as it knows it is in the dark |
| `barrier_broken` | a `barrier` feature: a wall that the dissolve verb removes |
| `hidden_found` | a `hidden` feature (a secret room's door): the reveal verb shows it |
| `gap_crossed` | a `gap` feature: crossing it airborne from one side to the other, once per gap per life |
| `lamp_drunk` | a `lamp` feature: the interact button, once per lamp per life |
| `vigil_kept` | a `vigil` feature: standing at it for 10 seconds undamaged |
| `room_held` | a room tagged `hold`: staying in it 20 seconds with a threat alive, once per room per life |
| `village_visited_unseen` | leaving the village having visited its rooms with no enemy there alerted |
| `village_kept` | leaving the village having killed none of its creatures |

## Not built here

Neutral creatures (the village's merchants and guardians fight like any creature for now), altars with perks in the new areas (pools only), hazard rules beyond what the existing rooms use (mud, heat, taint are art and text until a later piece), and boss arenas.
