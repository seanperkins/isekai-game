# F2: the new areas

What F2 builds and how. Source: `docs/research/area-level-design.md` (the sketches, rules and room budget), `docs/research/species-form-branches.md` section 10 (which creature lives in which area) and `docs/research/items-e2.md` (the buttons and items). F2 ships in pieces, each its own plan, branch and review: **F2a** the builder and the forest, **F2b** swamp and village, **F2c** the sacred cluster (cemetery, cathedral, crypt), **F2d** volcano and demon area, **F2e** the nine deeds that wait on rooms, **F2f** the placement of every creature.

## Built so far

**F2a (built 2026-10-05):** the builder and the forest. `tools/build_areas.sh` writes the rooms (`--check` writes nothing and fails when a room would change); `tools/areas/area_kit.gd` is the kit, `tools/areas/forest.gd` the first module, `tools/areas/areas.gd` the list of modules. Nine forest rooms, FO1 to FO9 (the cells below are the built ones): the Cave Mouth joins C3's right edge (a hop up of 46 from C3's highest ledge, not its top: C3 has no ledge route to its ceiling and a shipped room's solids are not the builder's to change), the Root Hollow drops into C4 and that exit pair carries the label `wall_cling` (one way down; without it C3 and C6 would be reachable without a gate through the forest). Spawns are the four support monsters that name the forest; twins come in F2f. The forest's vertical joins copy the shipped pattern: a zigzag of ledges whose last one stands in the ceiling opening (the Clearing's, as G1's), and a ledge either side of the floor opening above (the Trunk's, as C5's).

## The builder

Rooms stay `RoomDef` resources in `data/rooms/`. The new ones are written by a headless GDScript tool, not by hand: `tools/build_areas.gd` (run by `tools/build_areas.sh`) loads the shipped rooms, builds the rooms each area module in `tools/areas/` describes, attaches them to the shipped world by adding the exits the module names to existing rooms, and saves every changed room with `ResourceSaver` (the same writer the room editor uses, so a re-run changes nothing). An area module builds its rooms with `AreaKit`: `ledge`, `stairs`, `shaft`, `link` (which writes both ends of an exit from one world span), `spawn`, `decor`, `feature`. The tool runs `WorldValidator` and `RoomLint` over the whole world before it writes and refuses to write a world that has a finding.

Art is borrowed (`data/area_art.json`): forest from the grotto, swamp from the flooded tunnels, village, sacred, cemetery and volcano from the cave, crypt and demon from the deep. Decor ids carry the borrowed biome's prefix.

## Where the areas go

The shipped world fills cells x 0 to 23, y 0 to 8. The new areas take free cells (cell = one 640 by 360 screen):

| Area | Cells | Attaches to |
|---|---|---|
| forest | x 3 to 10, y -3 to 1 (built) | C3's right edge (the Cave Mouth), C4's top (a drop) |
| swamp and village | x 9 to 16, y -1 to 4 | the forest's east, F6's top (the Sump, `swim`) |
| cemetery, cathedral | x 16 to 26, y 0 to 4 | D7's top (the Gate Tunnel) |
| crypt | x 24 to 27, y 4 to 8 | the cemetery, and D5 (the Coffin Slide) |
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
