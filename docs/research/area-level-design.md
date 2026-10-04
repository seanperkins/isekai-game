# Area and level design reference: world layout, four movement kits, the forest and the volcano

Purpose: input for specifying the next areas and for judging the four shipped ones. Parts 1 to 9 cover the forest and the volcano; part 2 (sections 10 to 15) adds a cathedral, a safe cemetery, a crypt, a swamp, a goblin village, a demon area and traps. Companion to `level-design-reference.md` (gating, teach/test/twist, room sizes, jump metrics, save placement, enemy-placement lint, validation layers; not repeated here) and `metroidvania-reference.md` (abilities and enemies). Raw per-topic notes with every source: `area-level-design-notes/` (`world-layout.md`, `forest.md`, `volcano.md`), unedited; where they conflict with this document, this document wins. A visual summary is `area-level-design-report.html`.

Tags: **[repo]** = I read it in this repository. **[read]** = a fetched page. WebFetch has a small model summarise each page, so a quoted phrase is exact only where the notes say "exact"; treat the rest as the summary's words. **[snippet]** = search-result text only. **[inf]** = inference, source named. **[gap]** = searched, nothing found. A number marked *placeholder* is mine, unsourced and meant to be tuned.

---

## 0. Bottom line

1. **The world today is a corridor with one loop, and that loop needs Wall Cling** (section 1). Without Wall Cling it is a tree. New areas should attach with two edges and close a loop, not hang off the end of the chain.
2. **Four movement kits change what a "gate" is.** No precedent found where changing form costs a death and the world stays fixed; the closest are Dead Cells (fixed world, persistent unlocks) and Rogue Legacy (a new body per life) (section 3). Rules that follow: show every species gate before it can be used, cluster gates so one rebirth clears several, make every species reward persist.
3. **Engine facts decide several designs** (section 5): the generated 20 px ceiling lets a spider crawl over any floor hazard; open sky has to remove or replace that ceiling; a fire death seed can leak a fire-keyed gate; today's rooms have almost nothing for mantle, vault, roll's duck or the puddle slide to act on.
4. **Forest:** the best-supported role is the surface hub above the cave (Super Metroid's Crateria, Zero Mission, Dirtmouth, Firelink). Stage the reveal: hold the cave music until the player is outside, make the first room safe, put a tunnel before it (section 6).
5. **Volcano:** heat is a soft gate (Norfair), flagged per room (Metroid Prime), with escalating pressure and a loud warning. Lava on main lanes should hurt and knock back, not kill. First fire essence must be reachable without a fire creature (section 7).
6. **Everything is added, nothing is replaced** (Sean, 2026-10-04): the forest, volcano and part-2 areas sit beside the design doc's "last area past the Deep" and the unbuilt Serpent Lair. The work is wiring (section 15), not choosing a winner.
7. **Part 2: one zone layer and one trap layer** (section 10). Heat, holy, taint, mud and a safe cemetery are all volumes with an effect per creature class; traps are a trigger plus a hazard. Every holy-zone precedent has a switch you can reach, a trap must show its trigger or its hazard, and any element a death can seed must never be what a gate checks.
8. **The Deep becomes a hub** (section 15): a crypt cluster, a volcano and the Serpent Lair gate hang off it, a surface spine runs forest, swamp, village, and the world roughly triples. The village needs an altar that is neutral for every species.
9. **Target: at least as big as Super Metroid** (section 17, Sean 2026-10-04). Super Metroid is 255 rooms and 1,274 screens; this world is 23 rooms and 45 screens today and about 69 rooms and 125 screens with every planned addition. Matching 255 rooms at today's room size is the realistic bar, which means roughly 3.7 times the planned content.

---

## 1. Where the world stands [repo]

Audit of the exits in `data/rooms/*.tres` (all 23 files, parsed with a throwaway script), `docs/rooms.md` and the specs.

| Area | Rooms | Screens | Gates (exit pairs) | Altar | Rest pool | Dead ends (one exit) |
|---|---|---|---|---|---|---|
| Cave | 6 | 11 | `wall_cling` C2-C3 | C1 | C4 | none |
| Grotto | 5 | 14 | `wall_cling` G3-G5 | G1 | G4 | G5 (rare) |
| Flooded | 6 | 11 | `swim` F2-F3, F4-F6 | F1 | F5 | F5, F6 (rare) |
| Deep | 6 | 9 | `wall_cling` D2-D6 | D1 | D5 | D5 (world end), D6 (rare) |

- **23 rooms, 23 links, one cycle:** C1 - C2 - C3 (Wall Cling) - C6 - C1 (the switch shortcut). Remove the Wall Cling link and the graph is a tree. Only F4 has four exits; G3, D2 and C2 have three; every other room has one or two.
- **Altars are always in the area's first room** (C1, G1, F1, D1); pools are one per area, in a late room or a nook. Areas are 9 to 14 screens.
- **The main route passes the Swim door** (F2-F3), so everything from F3 on, including the whole Deep, sits behind a skill the game teaches in 20 s of water. The other gates guard rare rooms and the cave shortcut only. No species verb gates anything yet: both labels are slime skills.
- **A rebirth starts at an altar you choose** (design doc, altars). So a species errand costs altar-to-gate walking, not a walk from C1. That makes *distance from an altar to each species lane* the number to cap and measure, and weakens the case for long return shortcuts.

Dormans' warning fits: a non-linear mission mapped on a strictly linear space makes the player "travel back and forth a lot" [read: Dormans 2010]. Species side routes on today's chain are that case.

---

## 2. World-scale layout

### Theory that transfers
- **Mission and space are independent** (Dormans): the same ordered tasks can be mapped on a linear chain, a hub or a loop [read]. Hub-and-spoke gives "easy access to many parts"; one key (the Forest Temple's boomerang) opens many locks that were visible from the start [read: Dormans].
- **Cycles:** a cycle is two paths between start and goal; lock and key is "path A, locked door, path B, key, back to A"; a shortcut or hidden-shortcut cycle removes backtracking; Unexplored has 24 cycle types and averages "a couple of embedded cycles" [read: Game Developer Unexplored; Boris the Brave]. Cycle types "only control the main flow" and say little about layout [read], so using them at world scale is my extrapolation [inf].
- **Insert, do not append:** new sections go "into the existing cycle" [read: Unexplored]. Guacamelee's DLC attached through an existing doorway "blocked off by a cave-in" and "must not disrupt the game's overall progression path" [read: Game Developer, Guacamelee DLC].
- **Loops are capped on purpose:** Dormans closes connections that would short-circuit the mission, e.g. final room to a room near the entrance [read]. A loop must not skip the spine.
- **Start narrow, then open:** Super Metroid's first act is a funnel, the world opens after Kraid and the Varia Suit; difficulty of exploration tracks "how many available directions a player has to choose from"; "show locks before providing keys" [read: Invisible Hand; Bimmel].
- **Key breadth is a variable:** Silksong's early keys "only open a few locks" while Cling Grip "lets us open up a lot of different locks" [read: GMTK, exact].

### Shipped maps
- **Hub off the surface:** Super Metroid's Crateria links every area but Norfair and is the full-circle return; Zero Mission: "Brinstar, Norfair, and Chozodia all have paths connected to Crateria" [read: Invisible Hand; goombastomp]. Dark Souls' Firelink is a hub with paths "like roots", loops that skip areas, and Blighttown visible from the shrine [read: TheGamer]. Hollow Knight starts in Dirtmouth above the ruins [read: Wikipedia].
- **Two connected hubs when an act changes:** Silksong's Citadel is "self contained", with its own fast travel [read: GMTK]. Castlevania Portrait of Ruin hangs four themed areas off a castle hub [read: Wikipedia].
- **Direction reversal as pacing:** Silksong act 1 climbs, act 3 descends [read: GMTK]. Today's world only goes down and right [repo].
- **Rest spacing:** Blasphemous: checkpoints "roughly one per area and never more than seven screens apart" [read, exact]. Its respawn rule matches ours only loosely: here the respawn is the altar, not a glow pool, so the figure is a comparison for altar spacing [inf].
- **Region size in rooms:** Super Metroid has **255 rooms and 1,274 map tiles (screens) on Zebes**, plus Ceres (6 rooms, 12 tiles). Per area, rooms and tiles: Crateria 34 and 234, Brinstar 54 and 248, Norfair with Lower Norfair 76 and 362, Wrecked Ship 16 and 69, Maridia 56 and 283, Tourian 19 and 78. A room averages 4.9 tiles (median 4, largest 42; 66 rooms are a single tile, 36 are ten or more) [read: the `region/**/*.json` room files of vg-json-data/sm-json-data, summed from each room's `mapTileMask`; the Map Rando logic page agrees on 255 rooms]. Hollow Knight lists 19 named locations with no room counts found; Dead Cells publishes no room counts or sizes (the "250 combat tiles, 1 monster per 5" in Deepnight's article is an invented example) [read]. A comparison image in the shared Drive folder "00 - Map Size Comparisons" (18 games scaled to one room height) puts rough map bounding-box area, as a multiple of Super Metroid, at: Ender Lilies about 12x, Rain World with DLC about 10x, Shadow Labyrinth about 9x, Afterimage about 7x, Prince of Persia: The Lost Crown with DLC about 5.6x, Aeterna Noctis about 4.4x, GRIME about 3.9x, Silksong about 3.8x, FIST about 2.7x, Blasphemous 2 with DLC about 1.8x, Symphony of the Night (both castles) about 1.3x, Ori about 0.6x [inf: measured from the image; several maps are "densified" or have camera-zoom shifts, so treat as plus or minus 30%]. Hollow Knight and Dead Cells are not in the image.
- **Fast travel:** every comparable game adds it as the world grows (Stag, Bell Beast, owl statues, spirit wells, teleports) [read]. Altar-to-altar warping would be a new system, not a layout rule; see section 9.

### Rules for new areas [inf]
| # | Rule | Source | Check |
|---|---|---|---|
| A1 | Attach through an existing connector (a floor hole, ledge chain, doorway) and give the area at least two edges to existing rooms once its shortcut is open | Unexplored insertion; Guacamelee door | edge count per area |
| A2 | The area's altar and rest pool are reached on the base jump; species verbs and `heat_resist` only open side rooms, shortcuts and one rare room | the game's own rule; Guacamelee DLC | base-reach pass (exists) |
| A3 | A gate is seen before it can be used: gate room within one room of the spine | Super Metroid glass tunnel; Dead Cells "hole in the ground you saw"; Dormans Forest Temple | graph distance |
| A4 | One threshold room per entry, with a vista or cue of the next area, in the previous area too (volcano: glow, ash, a tablet) | Dormans threshold guardian; Blighttown vista; Norfair | tag `threshold` |
| A5 | Every room on a gate's return route has a reward, shortcut or rest; if not, bypass it | Bimmel; Subtractive Design | per-room feature check |
| A6 | Keep sequence breaks possible but never needed: hidden skips on side rooms, never on the spine | Silksong skips; afewbitsshort | none |

---

## 3. Four kits, one world

### Precedents
- **Dragon's Trap:** each form has a lane marked on the level (mouse form walks on checkered "mouse blocks"; piranha form swims); forms "unlock specific world areas"; death returns you to a hub town [read: Wikipedia; gaminghistory101 for the hub only].
- **Shantae:** dance forms cost magic and act as keys; reviewers criticised the map [read: Wikipedia]. **Portrait of Ruin / Monster Boy:** free swapping anywhere, with some parts needing both characters; Monster Boy added teleporters to cut backtracking [read: Wikipedia].
- **Biomorph** widened forms from per-room to everywhere ("a tremendous effort") and keeps a base kit in every form: "He can still dodge and wall jump" [read: Gamerant]. Same shape as our base-jump floor.
- **Majora's Mask** keeps masks, songs and dungeon-completion proof across a reset, adds owl-statue warps, and cut the cycle from seven days to three because a week was "too burdensome for players to remember" [read: Wikipedia; zeldadungeon].
- **Dead Cells:** the island map, how levels connect, and where the keys are "never changes"; a rune turns "that hole in the ground you saw in your previous run" into a route [read: Game Developer; MCV].
- **Rogue Legacy:** a new heir (trait) each life; dwarfism "can fit into small gaps" [read: Wikipedia]. No page says traits gate routes [gap].
- **Direct precedent for "die to change species, fixed world":** none found [gap].

### How designers keep swapping tolerable [read, summarised]
Free swap (Portrait of Ruin, Monster Boy) or a small cost (Shantae); swap stations (Dragon's Trap secret doors, Carrion deposit spots [snippet]); death to a hub, not the far start (Dragon's Trap); warps to shorten the return (owl statues, Monster Boy, Blasphemous); a gate visible before its key exists. Our cost is a death, so only the last three apply.

### Rules [inf]
| # | Rule | Source | Check |
|---|---|---|---|
| K1 | Every species-gated reward persists (opens a shortcut or flips a permanent unlock), never a one-shot pickup that dies with the body | Dead Cells runes; Majora's persistent masks | each reward writes a flag in the opened-shortcut list |
| K2 | Cluster gates so one rebirth as X clears several: at least 2 gates per species within an area or two adjacent areas (*placeholder*) | Silksong key breadth; Rogue Legacy | count per species per neighbourhood |
| K3 | Cap the walk from an altar to each species lane (*placeholder:* 7 screens, borrowing Blasphemous' figure) | altar-start rebirth [repo]; Blasphemous | path length, altar to gate |
| K4 | One visible tile marker per species lane, used only for that lane; the data carries the species mark the planned validator requires | Dragon's Trap mouse blocks; movesets spec | every gate room has one marker |
| K5 | Every area has lanes for at least two species, rotating which, so no species is lane-less across the world | Silksong Clawline two routes; Dark Souls start routes | area x species table (2+ per area; no empty species row) |
| K6 | The map pins a seen gate with the species glyph, so nothing has to be remembered; cap unsolved pins per species (*placeholder:* 3) | Majora's notebook and 7-to-3 cut | gate-seen event |
| K7 | Gate rewards that justify a death are visible and immediate; no second tax (lost map progress) | Rogue Legacy; Dead Cells | review |
| K8 | Size rooms for the fastest kit: the wolf's gallop and the spider's zip must not cross a room in seconds without lane hazards | Carrion: "a matter of seconds" from map start to end | traversal time per species per room |

---

## 4. Room-level craft (new material only)

Teach/test/twist, sightlines, gate rooms, save rooms and jump metrics are in `level-design-reference.md` sections 1.1 to 1.9.

- **Rhythm is what the player's hands feel.** Smith, Treanor, Whitehead and Mateas split a level into rhythm groups of 5, 10, 15 or 20 s, each with density low, medium or high and a beat type (regular, random, swing), joined by "a small platform that acts as a rest area" [read: UCSC paper]. Their generator picks rhythm first and geometry second, so the same rhythm "feels the same" over different geometry [read]. Use: describe a room as a rhythm (hops per screen, pauses), then check it per species; a wolf crosses a 3x1 room in a fraction of a slime's time.
- **Compton and Mateas** build levels from components, patterns, cells and cell structures: basic (one component repeated), complex (same component, changing tweak, e.g. widening gaps), compound (alternating components), composite (two components so close they need a coordinated action) [read]. Rhythmic obstacles "make each individual jump easier to time". Cell structures named: branch, parallel branch, setback or penalty, valve, hub, portal [read]. Mapping [inf]: `ledge_chain` is a complex pattern; a species lane beside the base route is a parallel branch; a one-way drop is a valve; a floor hole with a chain back up (G1/C5, G4/F1) is a setback.
- **Wayfinding** (Level Design Book, rated by how certain the player is to get it): subtle (room shape suggests function, ambient sound), coarse (composition and sightlines, lighting and colour contrast, repetition of earlier elements, 2D ground cues such as "planks that extend off the ledge" and ledge markers), direct (deep barriers such as pits, lava, rivers) [read]. Players follow contrast and the direction they move; they rarely look up unless something draws the eye [snippet: Wheeler]. Lynch's five elements (paths, edges, districts, nodes, landmarks) carry over as district = biome palette and sound, node = hub or altar, landmark = a visible tree or glow [snippet; inf].
- **Pacing:** intensity is "a gut feeling ... not a hard science"; after intense stretches, low-intensity areas "feel like rewards", and unbroken intensity makes the player "go numb" [read: Level Design Book]. Spread rewards evenly; long gaps without one frustrate [read: Bimmel].
- **Introduce hazards alone, then mix:** "introduce your gimmicks to the player individually", with foreshadowing before a hazard is integral and safe zones to break pace [read: galaxytrail; Game Developer level-design patterns]. Shovel Knight's rules: "No unitaskers", no concept overstays [read: Yacht Club]. One new rule per area, one timed hazard type per room [inf].
- **Rhythm needs hold time, not just position:** Dark Souls 3 requires "a guaranteed duration of at least 340ms" for an attack signal plus attack, about 21 frames at 60 fps [read: Game Developer]. A hard floor for any timed hazard telegraph [inf].

---

## 5. Engine facts that change the design [repo unless noted]

1. **The spider walks over every floor hazard.** Every room gets a generated 20 px ceiling (`RoomBuilder.edge_walls`, `RoomDef.WALL`), all terrain is crawlable except a "slick" flag that is not built, and a zip reaches the first hard solid within 160 px. A lava pit, thorn bed or flooded gap in a floor is no gate for the spider unless the ceiling above it is tagged hot or slick, or absent. Slime and wolf have no such shortcut. Decide the slick flag before the volcano.
2. **Open sky is the same question.** The ceiling is a 20 px solid cut only at exits; the camera clamps to the room rect (`World.view_center`) with no smoothing or dead zone, so sky is art, not space. A room whose whole top is an exit span may already open the sky, but I did not verify that the validator accepts a span that long [unverified]. A no-ceiling flag removes the spider's ceiling lane; a canopy band of solids and one-way ledges restores it. Treat sky and the spider bypass as one design choice.
3. **The fire seed can leak a gate.** The design doc seeds the next life with the element of whatever killed you, hazards included. If a gate is keyed on "has fire essence", dying in the first lava room hands over the key. Gate `heat_resist` on the permanent eaten or evolved essence, and make the seed a one-life, timed, mild-heat grace [inf: volcano notes R3; Terraria's stacked 7 s immunities as precedent].
4. **Verbs with nothing to act on.** The movesets spec records that today's rooms hold no hard step of 24 px or less and no hard low ceiling, and 133 of 172 interior solids are one-way, so mantle, vault, roll's duck and the puddle slide have almost nothing to do (movesets spec, known gaps). New areas must include hard ledges, short hard steps and low hard ceilings on purpose; this is the strongest design argument for the forest and volcano, which have natural versions (thick branch lips, fallen logs, bramble lines, vent hoods).
5. **Reach is about to be per species.** The movesets spec plans `ReachModel`, a `species_reach` lint rule and a per-species validator pass, with a species mark required on anything only a species reaches. Lanes and `heat_resist` here should be written in those terms, not as a parallel scheme. Those files belong to the reach-model plan (and `room_lint.gd` and `world_validator.gd` are touched by the soul-layer session): this document proposes, it edits nothing.
6. **Constants to use** [repo]: step at most 54 px (`rooms.md`), `REACH_RISE 55`, `REACH_GAP 60`, `REACH_HOP 80`, base rise 63 px, gaps between floating solids at least 36 px, an exit zone of 64 px kept clear. The slime's timed-rebound chain reaches about 1.6x the base rise and already breaks the G5 chimney guard; a bounce pad in the forest must be checked against the reach model, not assumed.
7. **Negative cells look cheap.** The map's bounds merge every room's world rect and offset by `bounds.position`; `new_room_beside` already builds a room above (`cell.y - size.y`); I found no code assuming non-negative cells in `scripts/world`, `scripts/ui` or `scripts/editor`. C3 sits at row 0, so a forest above the cave is rooms at row -1 or higher. Not covered by a test [inf]. The map shrinks as areas are added (the Deep spec already noted ~25 px per 1x1 room).

---

## 6. The forest (surface, outside the cave)

### What the precedents say
- **Super Metroid Crateria:** the surface is where you begin and where Act 1 returns "right where you landed". The cave you surface through keeps the Brinstar music "until you reach the outdoor environment", delaying recognition [read: Invisible Hand, exact]. Retraversing a route builds "a mental safe zone" [read].
- **Zero Mission:** "Clear skies, glowing mushrooms, and nothing to fight" on the first surface screens; the surface is the hub that "makes backtracking feel natural" [read: goombastomp].
- **Dead Cells:** "bursting out of a darkened room into blinding sunlight"; "a mandatory elevator ... a long tunnel" signals a biome change; recolouring one gradient map changes a biome's palette [read: Game Developer art deep dive]. Outdoor levels use analogous palettes, indoor ones complementary [read].
- **Hollow Knight Greenpath** is dark green and underground-style, with ambush enemies in foliage: a palette hand-off, not a sky reveal [read: hookshot blog; inf]. **Cave Story** puts the surface late (Outer Wall, Balcony, escape) [read: Wikipedia; snippet]; its village is a "danger-free zone" for practising movement [read].
- **Terraria:** hills reveal cave entrances, Living Trees "always have an underground room", day and night swap the enemy roster on the same forest (slimes by day, zombies at night) [read: wiki.gg].
- **Ori:** blockout of "the platforms and shapes Ori will run and jump on" before any art; the Ginso Tree is a tall ascent with a rising-water escape [read: Game Developer Q&A; Xbox Wire]. Its set dressing is one-off and costly, so not a pattern to copy [read].
- **No source** on camera, scale or music recipes for a surface reveal, nor on how a screen-grid engine draws open sky [gap]. The sourced ingredients are: hold the music, delay recognition, make the first room safe, change the palette, put a tunnel first.

### Layout and readability
- **Vertical:** a trunk is the shaft. Design every shaft for climbing and falling (Cave Story's rule: "what was once easy going left to right suddenly becomes difficult ... coming back") [read]. Hollow Knight maps each terrain type to one ability: shafts to wall climb, high ledges to double jump, wide gaps to dash, and excludes pass-through platforms so "every surface is solid and predictable" [read: ludonauta]. We keep one-way ledges, so give them a distinct edge [inf].
- **Readability:** Celeste's solids carry "a one-pixel border around the external edge", a flat dark infill and the most vibrant colours; backgrounds are desaturated [read: aran.ink]. Dead Cells: "collisions contrast sharply against backgrounds", interactables sit mid-contrast, threats get peak saturation [read]. The sources disagree on whether backgrounds should be more or less saturated; they agree on lower value contrast and an outlined walkable edge, so use value contrast plus outline, not saturation [read; inf]. Foreground props only at the margins, never over the character [read: sandromaglione].
- **Landmark:** one dominant object that "can't merge with the rest of the scene" (a giant tree, a waterfall, a clearing) [read: Game Developer composition; inf for the tree].
- **Camera:** Scroll Back's techniques (look at the projected position, snap on landing, a window "as high as a standard jump") are optional, and ours is a different camera (section 5). Its warning applies as is: "Enemies coming from above are less noticeable" [read]; put ambush spawns inside the visible window or telegraph them [inf].
- **Day and night** is one palette swap and a second roster if wanted [inf, from Dead Cells gradient maps and Terraria]. Weather is Super Metroid's mood device [read: goombastomp].

### Forest rules [inf]
| # | Rule | Source |
|---|---|---|
| FO1 | First surface room has no creature spawns; cave music holds until the player is outside; a tunnel or climb precedes it | Super Metroid; Zero Mission; Dead Cells |
| FO2 | Every shaft works up and down; main-route hops at most 54 px (repo step), so a 1x3 trunk is a long chain | Cave Story; `rooms.md` |
| FO3 | Platform surfaces outlined, background at lower value contrast, foreground at room margins; species sprites tested on the sky palette | Celeste; Dead Cells; Cave Story hero contrast |
| FO4 | Hazards one at a time: thorns (static, single touch), a spring or bounce cap, wind, hanging vines, then mix | galaxytrail; Celeste ch. 1 |
| FO5 | Decide sky versus ceiling per room (section 5.2) and say what the spider's lane is | engine facts |

### Species lanes [inf]
- **Slime:** mushroom or leaf caps as bounce pads (checked against the reach model); trunk bark for the cling climb straight up beside the ledge zigzag.
- **Spider:** a canopy band or branch undersides as a continuous crawl lane; zip across canopy gaps.
- **Wolf:** a 3x1 forest-floor trail with wide gaps (more than the base jump's horizontal reach) for gallop and pounce; fallen logs under 24 px for the vault.
- **Biped:** wall jump on trunks and cliffs; mantle onto thick branch lips (hard ledges); slide under a bramble line (low hard ceiling).

### Sketch: surface hub above the cave (7 to 8 rooms; screens W x H) [inf]
```
              Canopy Walk 3x1 --zip gaps--> Nest 1x1 (rare, spider)
                    |
              Great Trunk 1x3  zigzag ledges = base route; straight climb = cling / zip / wall jump
                    |
C3 (top) -> Cave Mouth 1x1 -> Treeline 2x1 -> Clearing 1x1 (rest pool, hub)
                                   |                  \-> Floor Trail 3x1 (wolf) -> Den 1x1 (rare, pounce gap)
                                   \-> Root Hollow 1x1 (hard lips: mantle; bramble: slide) -> one-way drop to C1 (shortcut)
```
The Mouth is the threshold (A4); the drop closes a second loop (A1). Base jump reaches the Clearing; every other connection is a lane.

**Alternatives.** (B) A second area between Cave and Grotto, Greenpath-style: a long climb-out tunnel, a no-spawn "sun step" room, a loop shortcut; weaker, since Greenpath is not daylight, and it cuts the C5-G1 floor-hole link. (C) A late reward after the Deep: delayed recognition, scripted music, a one-way drop back; it would sit beside the design doc's last area, not replace it.

---

## 7. The volcano (fire)

### What the precedents say
- **Norfair:** heat is the gate, staged by confinement: after the High Jump Boots "the available area is still miniscule", a "prolonged situation of near-captivity", then the Varia Suit as "a radical and complete change of pace" [read: Invisible Hand]. Magma pools still hurt after Varia until the Gravity Suit [snippet].
- **Metroid Prime Magmoor:** "most of the rooms ... have a flag set which detects if Samus is wearing the Varia Suit"; damage at "a constant rate" without it [read: Prime wiki]. **Dread (Cataris):** thermal pumps and trapdoors redirect magma, opening passages "while sealing others"; some rooms are "too hot to enter now" [read: omegametroid]. Escalating ticks, glowing heat doors and a louder track are [snippet].
- **Ori's Mount Horu:** stop the lava flows at devices, then escape debris; reviewers cited "difficulty spikes during the escape sequences" and "needlessly punishing" [read: gamerwalkthroughs; Wikipedia]. The puzzle half landed, the chase half drew the complaints [inf].
- **Celeste Core:** one switch flips magma, fireballs and conveyor walls to ice, and changes music, friction, background and colour grade [read: celeste.ink]. A room-level mode that retints everything is cheap and readable [inf].
- **Hollow Knight's cut lava area (Boneforest):** bottom of the world, entered from Deepnest's bottom-right, instant-kill lava, lava-worm minibosses guarding a locked gate, cut because "Boneforest made the world map too big!" [read: fan-compiled page quoting the developers]. A direct precedent for a lava branch off the deepest area, and a warning on scope.
- **Terraria:** lava does 80 damage plus a 7 s burn; each lava-immunity accessory adds 7 s, stackable to 49 s; water on lava makes obsidian, but water evaporates in the Underworld [read: wiki.gg]. Minecraft: obsidian forms "when flowing water touches a lava source block" [read].
- **Rising lava, numbers:** one contest wiki lists rising lava at "1 every 8 frames" while submerged, with some versions instant-kill; no speeds in px/s anywhere [read; gap]. Toto Temple dropped rising lava because "anything that makes you lose control over your character deliberately is NOT going to be fun" [read].
- **No design rationale found** for Mario, Donkey Kong Country or Spelunky's lava zones; Blasphemous, Cave Story and Rayman were not searched [gap]. No source gives eruption cycle times, crumble delays or the share of a room that may be hazard [gap].

### Rules [inf]
| # | Rule | Source |
|---|---|---|
| V1 | Add a `heat_resist` gate in the exit schema beside `wall_cling` and `swim`; rooms carry a `heat` flag; the grant is reachable without passing a `heat_resist` gate; at most one rare room per area behind it | Norfair; Prime flag; `WorldValidator.GATES` |
| V2 | Gate `heat_resist` on permanent essence, not on the death seed; make the seed a one-life timed grace | section 5.3 |
| V3 | Main-lane lava hurts over time and knocks back to the last safe tile; instant kill only in a rare room and never within one screen of its entry | Terraria; Horu; death restarts the world [repo] |
| V4 | Mild heat is a clock: refuges are rest pools or water rects; cap the longest exposed path between refuges (*placeholder*, tuned like a 7 s immunity) | Terraria; Silksong heat lamps [snippet] |
| V5 | Prefer player-controlled changes (a switch drains or raises a rect) over a timed rise; decide whether a drained state persists per life | Horu; Dread; Celeste |
| V6 | Every timed hazard declares a telegraph of at least 340 ms (21 frames), aim 500 to 600 ms visible plus audible, safe window at least the active window | Dark Souls 3 |
| V7 | Every lethal hazard names its `seed_element` (empty for crush and fall): lava, fire burst, eruption and fire creatures seed fire; rockfall seeds nothing; decide steam | design doc seed rule |
| V8 | First fire essence reachable without a fire creature: a deliberate teaching death, or a creature-free ember vent behind a platforming trial near the first rest pool | Spelunky's "expected part of gameplay"; Boneforest's reward behind lava minibosses |
| V9 | Lava and fire are the room's highest saturation and brightness; platforms mid; parallax faded; no lava-coloured parallax at lava brightness behind a platform; one-way ledges get a distinct cap in heat rooms | Dead Cells three tiers |
| V10 | Lava hazard share of walkable floor capped (*placeholder:* 40% on main lanes, 60% elsewhere) | none |
| V11 | Foreshadow: glow, ash and a heat tablet in the previous area, a lava pool seen through a gap, a no-damage transition room before full heat | Norfair; Dead Cells tunnel; atmosphere series [read] |

### Species lanes [inf]
- **Slime:** water essence quenches a lava rect to obsidian for a limited time (consumes the held essence; a `quench` tag on a lava rect needs a water source in the same or previous room); deep water rects are refuges.
- **Spider:** zip across lava spans, and crawl the ceiling unless it is hot or slick (section 5.1). Anchors avoid one-way ledge sides (a shipped fix).
- **Wolf:** gallop or pounce across gaps timed to eruption windows; vault low lava lips.
- **Biped:** roll's invulnerable window passes a fire-burst curtain (check the i-frames cover the burst's active time); mantle above surging lava.

### Sketch: a descent off the Deep (7 rooms; screens W x H) [inf]
```
[Deep: bottom room] -- open floor gap, red glow seen below (foreshadow)
 Ashfall 1x1      landing, ash motes, heat tablet, no heat damage (threshold)
 Ember Hall 2x1   mild heat, rest pool at the west end, first lava lip (DoT + knockback)
 Chimney 1x2      shaft down, rockfall (seeds nothing) teaches rhythm
 Forge Row 2x1    eruption vents (>= 340 ms telegraph), fire creatures
    |-- east: zip or pounce across a lava span --> Magma Chamber 1x1 (altar)
    |-- south: heat_resist --------------------> Cooled Vault 1x1 (rare; instant-kill lava allowed)
 Ash Cut 1x1      one-way shortcut back up to Ember Hall; opens by quench or from above
```
Main route (base jump only): Ashfall to Magma Chamber. The Deep is already the hardest area, so the volcano's main route must be easier than its entry.

**Alternatives.** (B) Beside the Flooded Tunnels: a steam gallery as the transition, a natural slime lane (quench with carried water), two hazards competing for one gate, so keep `swim` on the Flooded side. (C) Hub and spokes around a three-screen magma hub with a switch that drains the slag pit, each species lane a different spoke. A branch off the midpoint of the chain is the weakest (costliest transition and foreshadow).

---

## 8. Area template (what each new area spec should state)

1. **Role and attach point:** which connector, which two edges, which loop it closes (A1).
2. **One new rule** (heat, open sky) and the gate or lane it feeds; how it is introduced alone first (section 4).
3. **Room list** with sizes in screens, the threshold room, the altar room, the rest pool, one rare room; areas so far are 5 to 6 rooms and 9 to 14 screens.
4. **Species table:** area x species, the lane, its marker, its reward and the flag it writes (K1, K4, K5).
5. **Constraints from section 5:** ceiling and spider, seed leak, hard ledges for the unused verbs.
6. **Readability and rhythm notes:** palette tiers, a rhythm description per room, telegraph floors.
7. **Lint additions** proposed against `ReachModel` and the validator, owned by the reach-model plan.

---

## 9. Decisions for Sean

1. **Where does each area attach?** My lean, tagged [inf]: forest as the surface hub above the cave, with one base-jump entrance and a one-way drop back to C1; volcano as a descent off the Deep. Both lean on strong precedent. Sean confirmed (2026-10-04) that everything is added and nothing replaced, so both sit beside the design doc's "last area past the Deep" (the goddess fight) and the unbuilt Serpent Lair; section 15 wires them all together.
2. **Open sky versus a ceiling** for forest rooms, and whether to build the slick flag first (section 5.1, 5.2). It decides the spider's lanes in both new areas.
3. **Fast travel:** altar-to-altar warping after the third area is a new system, not a layout rule. Wanted, deferred or never?
4. **Respawn spacing:** should altars follow a maximum distance (Blasphemous: seven screens) or stay one per area?

---

## 10. Part 2: one zone layer and one trap layer

Five more areas (cathedral, cemetery, crypt, swamp, goblin village, demon area) and traps arrived after parts 1 to 9. They share one engine gap: **`RoomDef` has no hazard, zone or trigger data** (its parts are solids, decor, dressing, spawns, exits, features and water [repo: `room_def.gd`]). Heat, holy, taint, mud, a safe cemetery, spikes and darts are all new room data. Four agents each proposed their own field; the rule below merges them so there is one scheme, not four. Full notes: `area-level-design-notes/` (`sacred.md`, `swamp-village.md`, `demon.md`, `traps.md`).

### Zones (volumes with an effect)
| # | Rule [inf] | Source |
|---|---|---|
| Z1 | One `zones` array: `{rect, kind, effects, emitter?}`, with `kind` in `heat`, `holy`, `taint`, `mud`, `safe`. Zones are volumes you can leave; **gates stay labels on exits** (`wall_cling`, `swim`, `heat_resist`) and a zone may be what a gate label protects | Echoes and V Rising treat harm as a place [read]; `rooms.md` gate rule [repo] |
| Z2 | Effects key on creature **class tags** (`living`, `undead`, `bone`, `demon`), not species ids, so the undead line's forms plug in; each tag maps to `dot`, `slow`, `heal`, `ward`, `repel` or `none` with a rate and knockback | Nioh's form-dependent effect [read]; design doc undead tree [repo] |
| Z3 | A zone is a **full-height** volume including the 20 px ceiling band, or the spider's ceiling lane sidesteps it | section 5.1 |
| Z4 | A zone may name an **emitter** (a priest, a censer, a stained-glass window, a spawn gate). While it is dead or extinguished the zone is off for that life | NetHack priest at the altar, Nioh's generating creature, Dark Souls' Undead Mage, Echoes generators: every holy-zone precedent has a switch [read] |
| Z5 | One lint per kind of mistake: zone spans floor to ceiling; no zone inside a 64 px exit zone or on an arrival pad; altar, pool, tablet and any `safe` rect never overlap `holy`; longest continuous exposure on a main lane stays under the V4 cap; every main-lane `holy` or `taint` zone has a cover pocket and a switchable emitter or a bypass | sacred and demon notes |
| Z6 | **Seed leak, generalised.** Dying to holy damage seeds light, to taint or a demon seeds dark, to fire seeds fire, to gas seeds poison. A gate keyed on "has element X" leaks when X is seedable. Gate on the permanent eaten or evolved essence, never the seed, for every element | section 5.3 |

### Traps (a trigger plus a hazard)
One `traps` array beside `zones`: `{kind, rect, trigger, telegraph_ms, cycle, seed_element, layer, persist, weight?, disarm?}`. Kinds: spike, dart_launcher, fire_jet, gas_vent, falling_block, collapse_floor, boulder, pit, saw, mimic, ambush_lock, web_snare. Full table and 13 lint ideas: `traps.md` section 5. These files are owned by the reach-model plan: this document proposes, it edits nothing.

---

## 11. Sacred cluster: cathedral, cemetery, crypt

### What the sources say
- **Holy zones that hurt one class are emitter-bound, cover-bounded and trade rather than ban.** NetHack's sanctuary exists only while the priest tends the altar; Nioh's Dark Realm dies with its generator; Dark Souls' skeletons stop rising when the Undead Mage dies; Echoes' dark zones need generators and crystals [read]. When the player is the affected class, the hazard has a grace period and visible cover: V Rising's sun damage starts after "a few seconds" and stops in shadow or under a roof; Soul Reaver's water weakness is later overcome [read]. No source states a fairness rule outright [gap].
- **Beauty reads as safe**, so a holy hall must show threat inside the beauty: Anor Londo's sunlit marble hides giant sentinels and archers on the walkway [read]. Nioh's smoke zone became tiresome through overuse and is hard to see in at night, so cap how often it appears [read].
- **Sanctuaries still allow ranged fire** (NetHack), so a safe cemetery has to remove or wall off anything with line of sight [read].
- **The graveyard is not always safe.** Hollow Knight's Resting Grounds is quiet but holds enemies [read]; Dark Souls' graveyard is the dangerous part. Use Firelink, Resident Evil safe rooms and the NetHack sanctuary as the rulebook for "safe".
- **Proportions:** Symphony of the Night's chapel is the longest staircase, a tall climb that ends at stained glass and an altar; its Catacombs are compressed and horizontal "bedrock" [read]. Real crypts sit under the chancel, and Old St Peter's let pilgrims "enter at one stair, pass by the tomb and exit" without disturbing the service above, a ready-made one-way circuit [read].
- **Dark Souls stacks shrine, graveyard, catacombs, tomb** with coffin slide ramps down, and skeletons that return until their necromancer dies [read].
- No source found on stained glass, pews or burial niches as 2D level tools, nor on holy-zone sound cues [gap].

### Rules [inf]
| # | Rule | Source |
|---|---|---|
| SA1 | Holy is damage over time with knockback to the last safe tile, never instant death on main lanes; a grace of about a second before the first tick; stained-glass windows are the visible cause (beams), shade between beams, confessional alcoves and pew gaps are the cover | V Rising; Echoes; volcano V3 |
| SA2 | Hard for undead, not a lock: each undead form carries a `holy_resist` stat (skeleton frail, zombie and ghoul tanky, lich has a ward, vampire trades speed); every holy hall has a switchable emitter and an undercroft or loft bypass; the main route stays base-jump only | Nioh trade; NetHack; Soul Reaver |
| SA3 | Introduce holy alone (one beam, one cover pocket, a tablet), then add a priest, then mix with a shielded guard; at most one holy-heavy room in three | Nioh overuse; section 4 |
| SA4 | Read it from the affected side: an undead sprite desaturates and sheds wisps and a small bar fills; a living player sees the same beam as dressing | V Rising |
| SA5 | **Cemetery = kind `safe`, a truce:** no spawns, enemies turn back at the edge, no holy or taint effect inside, a warm lantern or moon rather than holy light (so it does not tell undead it hurts), calm music with "a little touch of the uneasy" | NetHack; Resident Evil safe rooms [snippet] |
| SA6 | The cemetery holds the cluster's altar, a pool, a tablet, a vista of the nave (A3) and one shortcut; 2 or 3 rooms (lych gate, churchyard, mausoleum door); never a dead end | churchyard layout [read]; A3 |
| SA7 | Crypt: low, long, compressed; reassembling bone creatures tied to a `revive_link` necromancer (cheaper than spawning); a bone creature stays down if its link is dead or a light, fire or crush effect finishes it | SotN Catacombs; Dark Souls |
| SA8 | Crypt traps: sliding coffin ramps, falling tomb floors, dart niches, collapsing sarcophagus floors, mimic coffin (section 14) | Dark Souls; Lich Yard |

### Species lanes [inf]
| Species | Cathedral | Crypt |
|---|---|---|
| Slime | holy font as a water route (holy dot for undead only); squeeze under pews; bounce on cushion decor (check reach model) | sealed niches through small gaps; coffin slide |
| Spider | vault ribs and clerestory above the beams; zip on chandeliers and censers; shoot the emitter | ceiling crawl over floor traps; vault anchors |
| Wolf | long nave gallop; pounce a transept pit; vault pews (hard steps of 24 px or less) | pounce a burial pit; skeleton dogs are the pack |
| Biped | bell-tower wall jump; mantle the choir loft; roll under pews | slide under low hard crypt ceilings; mantle burial shelves |
| Undead | side aisles in shade; zombie tanks the beam; lich wards; archer extinguishes the emitter from range | cursed-zone regen; dark rooms are friendly; bone creatures may be neutral (open) |

Roster on real flags: priest (spitter, with a new `holy` projectile and contact type, carries the emitter), shielded guard (`armored_charger`), bone walkers with a revive link, bone hounds (`pack`), ghost (`drifter`), gargoyle (ceiling dropper).

### Sketch: cemetery hub with two spokes (about 11 to 14 rooms, 22 to 26 screens) [inf]
```
              Cathedral spoke:  Nave 3x1 -- Transept 1x1 -- Bell Shaft 1x3 -- Loft 2x1
                                     |   (beams, shade, priests; font chapel off the transept)
 Deep D2 -- Gate Tunnel 1x1 -- Churchyard HUB 2x1 (ALTAR, POOL, SAFE) -- Lych Gate 1x1
                                     |
              Crypt spoke:      Stair 1x2 -- Ossuary 2x1 -- Niche Gallery 3x1 -- Vault 1x1
                                (dark, cursed)  -- Coffin Slide: one-way down to a Deep dead end D5 (closes a loop)
```
Alternatives: a vertical stack off the Deep (crypt first, cathedral last) and a ring (enter by the crypt, climb the church, leave by the cemetery and a one-way tunnel to the Deep). The ring has the best flow (Old St Peter's circuit) and the hub the clearest altar. **Attach rule:** a link from an early area would bypass the Swim door (F2-F3), so the second edge is a one-way shortcut opened from the far side.

---

## 12. Swamp and goblin village

### Swamp: one new rule, bog mud
- **Template:** Donkey Kong Country 2's Hornet Hole: the Kongs "can neither walk nor attack while they are stuck", jumping is the only escape, it sits on floors and walls, it is taught early with a barrel and a few spots, and the spider-like Squitter is immune to the floor honey [read: Mario Wiki].
- **Warning:** Maridia's quicksand needs "shady timing" to jump out of, and without the Gravity Suit Samus slides "left and right randomly" [read: Invisible Hand]. Sinking terrain must never need tuned timing.
- **Fair low visibility:** a light cue in the distance, a linear route, "do not create mazes", a carried light (Ori's Misty Woods lantern), hazards that do not act off screen, withhold the map rather than the platforms [read: Level Design guide; gamerwalkthroughs; snippet].
- **Distinct from the existing areas:** the Flooded Tunnels own deep water and the `swim` gate, the Grotto owns poison. Reject "more water" and "more poison": mud is one new rule, murk is an overlay, boardwalks are structure.

| # | Rule [inf] | Source |
|---|---|---|
| SW1 | New `mud` zone: walk about 60% speed, sinks about 20 px/s to a hard floor 12 px deep, no damage, escaped by one jump press measured from the sunk position (all numbers *placeholder*) | Hornet Hole; Maridia |
| SW2 | Lint `mud_escape`: any ledge reached from mud is at most 43 px above the surface (55 reach minus 12 sunk); mud is never the only exit from a pit; none inside a 64 px exit zone | `REACH_RISE 55` [repo] |
| SW3 | Mud is a lane modifier, not a gate: never in `GATES`; slime and spider are immune, the others are slowed | Hornet Hole |
| SW4 | Murk is a no-physics overlay, never over the walkable edge; every murk room has a light cue and a linear spine; ambushers telegraph (ripple, bubbles) at least 340 ms | Misty Woods; DS3 floor |
| SW5 | Depth cues (stilts, reed tops, board ends) on every water rect; at most one swim sump, the link to the Flooded Tunnels, reusing `swim` | wayfinding |
| SW6 | Guide wisps are decor on the main route only; false wisps lead only to optional rooms | folklore "mislead and/or guide" [read] |
| SW7 | Forest to swamp: canopy thins and the tint shifts over 2 to 3 screens, grass breaks into one harmless mud patch (the teaching spot), then boards, ambient water and wisps before the first span, a root-hollow seam so the palette changes behind a door | Dead Cells tunnel and gradient maps; no designer write-up found [gap] |

Spider note: slick exists in the movement layer (`SurfaceStep.SLICK`, `ZipStep`) but **no `slick` field exists in `scripts/world` or `data`** [repo], so mud cannot gate the spider and the 20 px ceiling lets it cross any span. Acceptable, since mud gates nothing.

### Goblin village
- **Hostility turned into welcome:** Hollow Knight's Mantis Village is hostile at the entrance; after the Lords trial the Mantis "bow", the gate opens and the rest of the village is accessible [read].
- **Species-based welcome, cheaply:** Skyrim's Orc strongholds let non-orcs in, but residents "will continuously tell you that you are not welcome" and services are off until quests are done; the page does not say residents attack [read: UESP]. Majora's Mask forms get different reactions (a guard blocks Deku Link) [read].
- **The failure mode:** Divinity Original Sin 2: guards "stay hostile no matter what you do" and lock out merchants (player reports) [read]. Never ratchet hostility permanently.
- **Structure:** a bridge chokepoint that forces a fight, ambushes ramping 1, 2, then 4, and a loop back over a jump impossible from below (Undead Burg) [read]; elevated forts "commonly inaccessible from the ground, but for the occasional drawbridge", "any approach is immediately visible to guards" (Breath of the Wild camps) [read]; a safe node with rest, shop and altar (Mimiga Village, Silksong hubs) [read; snippet]; services that grow as you finish things (Songclave, Terraria) [snippet; read].
- No 2D metroidvania found where species changes a settlement's behaviour [gap].

| # | Rule [inf] | Source |
|---|---|---|
| VI1 | **The altar and rest pool sit in a neutral gatehouse with no hostile spawns for any species.** A non-goblin must never respawn inside a hostile palisade (rebirth is at your chosen altar [repo]) | rebirth rule; Mimiga |
| VI2 | Standing is derived, never a one-way ratchet: `standing = f(current species, persistent trust flag)`. Welcome (goblin or trusted), wary (no attack, services off, speech lines), hostile (inner ring and optional rooms only). Attacking a villager costs trust for that life only | Skyrim; Mantis; DOS2 |
| VI3 | Any species can earn trust through a trial (a Mantis-style arena, or delivering a scavenged item); it persists across lives (K1) | Mantis; K1 |
| VI4 | The spine through the village is base-jump reachable and fight-free for every species; welcome and trust gate only crafting, taming and the rare room, plus one lore reward | Skyrim services; A2 |
| VI5 | Structure: one ground gate (drawbridge or palisade), elevated forts reached by verb lanes, rooftops as the test bed for the unused hard-ledge verbs (section 5.4); first approach staged hostile only for non-goblins: chokepoint, then 1, 2, 4 sentries | Undead Burg; BotW camps |
| VI6 | Goblin content: a tinker's bench turning scavenged junk into consumables and trap kits, junk piles in swamp and camp edges (no respawn within a life), a captive "bound" beast to free and tame, an optional raid scene | Terraria Goblin Tinkerer and Army [read] |
| VI7 | Shortcuts: a one-way drop to the forest Clearing (closes a loop, A1), a palisade gate opened from inside by a switch, one trust-gated shortcut | Undead Burg; Mantis gate |

### Sketch: linear with a village loop (11 rooms, 18 to 20 screens; `*` main route, base jump only) [inf]
```
Forest Clearing* 1x1 (hub, forest pool)
   |  tunnel seam (palette hand-off)
Boardwalk* 2x1 -- teaching mud patch, wisps ahead
Bog Flat* 2x1 -- one mud span, mud-lurker ambusher
   |--[zip] stilt undersides --> Stilt Roost 1x1 (rare: spider or slime)
   |--[pounce] 3-wide mud span --> Hunting Blind 1x1 (rare: wolf, junk cache)
Gate Shrine* 1x1 (ALTAR, neutral, pool)
   |  drawbridge chokepoint (wary lines, 1-2-4 sentries for non-goblins)
Village Yard* 2x1 (crafting, tame pen)      Palisade Roofs 2x1 (mantle, wall jump)
   +--[trust] Chieftain Hall 1x1 (trial)
One-way drop -> Forest Clearing (loop)      Sump 1x1 [swim] -> Flooded Tunnels (second link)
```
Alternatives: village first with the swamp as the long optional spoke (hostile first approach leads), or the swamp as a hinge to the Flooded Tunnels with the village on a stilt island (needs the swim link).

---

## 13. The demon area

### What the sources say
- **Written rationale is thin.** The Inverted Castle exists because the designers wanted "to add more content in a way that would be easier than creating new assets" and the castle "works in both orientations" [read: Wikipedia]; how it was re-gated is [gap], and the unlock sources conflict. A Link to the Past's Dark World is a copy of the Light World map stored as an "overlay" with different tiles; Miyamoto cut three worlds to two because "players would've gotten confused" [read]. Harmony of Dissonance's two castles share a layout, and "the destruction of a wall in one castle can cause a change in the other" [read]. Ghosts 'n Goblins' second loop "transforms" the Demon Realm [read].
- **Cautionary:** Dark Souls' Lost Izalith. Miyazaki: "my greatest regret is the Bed of Chaos", the team "had no way to find a common goal" [read]. A theme with no rule and no boss concept is what failed.
- **What separates a demon area from lava:** rules about choice and trust, not temperature: pacts and curses (Dead Cells, Hades, Cuphead), spawners (Gauntlet's generators "can be destroyed"), false walls (Dark Souls), a second pass with changed enemies, spreading corruption (Terraria's Corruption cannot overlap the Hallow) [read]. Ganon's Castle floats above "an abyss of churning fire", so demon fire belongs in the parallax, not on the hazard layer [read].
- **Enemies:** Doom 2016 found that "demons, except for melee demons, should hold their position" [read]; Dead Cells' curse clears by kill count but nearly any hit kills while cursed [read]. No source on summon-on-low-HP [gap].

| Mechanic | Cost here [inf] | Verdict |
|---|---|---|
| Destroyable demon gate (finite waves, one deliberate act, persistent flag) | low | **the one new rule** |
| Taint zone sharing the zone layer; costs a resource (no regen, slower remains), not HP; a `ward` rect is the refuge | low | yes |
| Optional pact altar (opt-in cost, persistent reward) | low | yes |
| False wall, side rooms only, with a hint | low | yes |
| Overlay rooms (`variant_of` an existing room, new tiles and spawns, same exits) | medium | the affordable second pass |
| Curse as a max-HP cut that clears by kills or a glow pool | medium | yes, never one-hit death |
| Literal vertical flip (SotN) | HIGH: 133 of 172 solids are one-way and would flip, water and exits flip, the reach pass reruns | no |

### Rules [inf]
| # | Rule | Source |
|---|---|---|
| DE1 | The one new rule is **sealed gates**: `spawn_gate {pos, waves, max_alive, telegraph_ms >= 340, seal, flag}`; closing one writes a persistent flag. The boss door lists only the base-jump gate's flag; verb gates open a shortcut or the rare room | Gauntlet; Ganon's six barriers; K1 |
| DE2 | Taint, curse, false walls and pacts reuse the zone layer and section 14's seed table; demon creatures seed dark, fire stays volcano-only, blood is not seeded (a later element) | Z6 |
| DE3 | A second pass is an overlay of two to four rooms behind a world flag, with shared state (a shortcut opened in the overlay opens in the original), not a flipped map | ALttP; Harmony of Dissonance |
| DE4 | Roster, one attribute plus one trigger each: hound (dasher, at least 340 ms wind-up), imp (holds position, a variant applies a curse stack), caller (emits imps only while its glyph is lit), ward-bearer (nullifies hits from one direction), blinker (short teleport with a fake-out, at most one per room), rider (possesses a dormant corpse, one per area) | Doom 2016; Build a Bad Guy [read] |
| DE5 | The boss is fully authored and sits beside the shortcut that closes the loop | Blasphemous; Bed of Chaos |

### Sketch: "Three Seals", hub and spokes (7 rooms, 13 screens) [inf]
```
 [crypt or cathedral exit]  base jump
        |
  Threshold 1x1  tablet, red-black palette, no spawns, no taint
        |
  Gate Hall 3x1  ALTAR + pool; three sealed gates visible from the start;
     |        |         |   boss door needs ONLY the Middle flag
   West 2x1  Middle 2x1  East 2x1   each: one spawn_gate, a taint strip, a ward
   (zip)     (jump)      (pounce / roll)
     |          +--> Throne 1x2  boss "caller"; opens on the Middle flag (base jump only)
     +-- West flag opens a link Throne -> Gate Hall (shortcut)       East flag opens Reliquary 1x1 (rare)
```
Alternatives: a mirrored pass (overlay of two Deep rooms plus two new rooms, after the reveal flag; cheapest, shares the most with the last area's unlock flag, the reveal) and a linear pact descent with two optional pact rooms (weakest placement precedent, best cost fairness).

### Interactions to settle (nothing is replaced)
The volcano descent (section 7), the crypt cluster (section 11), this area, the design doc's "last area past the Deep" and the unbuilt Serpent Lair all hang off the Deep; section 15 wires them. Also: blood essence is tied to the vampire, a dark-keyed gate leaks through the seed (Z6), whether demons hate undead or hold the same side is open, and which side the goddess is on decides how holy and demon art signal factions.

---

## 14. Traps

### What the sources say
- **A trap is a trigger plus a hazard.** "The trigger may be invisible or the hazard may be invisible, but they cannot be both" [read: Ludomotion]. Same shape: at least one of trigger, mechanism or payload must be observable, else the player gets "tedious paranoia" [read: Kate Plays]. Spelunky: "Arrow traps can always be spotted ahead of time" [read].
- **Sen's Fortress** shows the cost of hidden cues: the designers made traps "scream trap", yet Miyazaki doubted anyone would notice the worn steps that warn of boulders; there is no bonfire mid-fortress [read: soulslore; PCGamesN].
- **Numbers found:** Terraria's dart trap cools down 200 ticks (3.33 s), fires darts at 45 tiles/s and poisons, 40 damage (80 Expert) [read]; Dead Cells caps hazard damage at 30% of max HP per hit and its pressure spikes "shine briefly" before firing [read]; Minecraft plates stay active 20 ticks, weighted ones 10 [read]. No source gives fire-jet or gas cycle times, safe-window ratios or traps per screen [gap].
- **Weight and filters:** Dwarf Fortress plates trigger by weight range, cannot be made civilians-only, and any webbed or unconscious creature triggers any plate [read]. Terraria offers player-only, enemy-only, both and projectile plates [read].
- **The licence to kill is narrower here.** Spelunky kept lethal arrow traps in the start area because "death and failure is an expected part of gameplay" [read], but its world is random and runs are short; here a death costs an altar trip and decaying remains [repo].
- **Traps as locks and tools:** Terraria's Dangersense lights traps and triggers; Metroid Dread's Pulse Radar reveals hidden blocks at an Aeion cost [read]. Dead Cells traps hurt enemies too; Hades spike traps hit Zagreus lightly and enemies hard [read; snippet].
- **Player-laid:** Dead Cells' Wolf Trap roots for 5 s with a 14 s cooldown; Don't Starve's Tooth Trap does 60 damage over 10 uses and does not aggro neighbours; Minecraft's cobweb slows the player to 25% while spiders are immune and mobs do not path around it; Dwarf Fortress "titans" are immune to traps entirely [read]. Monster Hunter capture needs a weakened monster, a pitfall or shock trap, then tranquilliser bombs [read].

### Rules [inf]
| # | Rule | Source |
|---|---|---|
| TR1 | Plates declare `weight` (light, medium, heavy) and `filter` (player, enemy, any). Slime and spider are light, goblin and undead medium, wolf heavy: only the wolf trips `heavy` plates, so a heavy plate can lock a side vault for the wolf | Dwarf Fortress; Terraria |
| TR2 | Roll's invulnerable window passes projectile traps but not crush, pit or collapse; the spider crosses floor traps on the ceiling unless a ceiling-layer trap threatens crawlers; webbed creatures trigger any plate | section 5.1; DF |
| TR3 | A `sense` ability reveals triggers and wires in a radius, never the hazard timing (Echolocation is the natural fit) | Dangersense; Pulse Radar |
| TR4 | Every timed, plate, sight, stand or enter-triggered trap has `telegraph_ms >= 340`, aim 500 to 600, safe window at least the active window; static and continuous traps (spike, saw) must instead be fully visible; mimics show a tell frame | DS3; Dead Cells |
| TR5 | At least one of trigger or hazard is visible (`trap_visibility`); a hidden sight trigger plus an invisible hazard fails | Ludomotion |
| TR6 | Non-lethal main-route traps deal at most 30% of max HP per hit; lethal traps only in rare rooms; no lethal trap within a screen of an altar or pool; remains snap out of trap rects so retrieval never re-enters the trap | Dead Cells; design doc remains rule |
| TR7 | Timed traps start at a fixed phase on room entry so a learned rhythm transfers to every life and species; the first instance of each kind appears alone in a room with a safe view of trigger and hazard | Sen's; PoP; section 4 |
| TR8 | Persistence: one-shot traps stay fired for the life and reset at rebirth; a trap disarmed by a switch or a species verb writes a flag and stays disarmed on every life, drawn visibly cut or jammed; cycle traps have no state | K1; Dark Souls shortcuts |
| TR9 | **Combo deaths need a rule.** If a creature damaged you within about 2 s (*placeholder*) and the killing blow is seedless (spike, crush, fall), the creature's strongest element seeds; otherwise the killing source seeds as below | design doc seed rule; PoP push-into-traps |

Seeds by family: spikes, saw, boulder, falling block, crusher, collapse, pit and arrow seed nothing; fire jet and brazier seed fire; gas vent and tipped dart seed poison; drowning trap seeds water; web snare seeds thread only when a thread creature landed the damage; mimic and ambush seed the creature's strongest element. Gate on permanent essence, never the seed (Z6).

### Player-laid traps (spider web, goblin junk trap) [inf]
1. Cap by cooldown and a carried count refilled at an altar or pool, not free placement (Dead Cells' 14 s, Silksong's bench refills); a web costs the spider silk, so each web is a decision.
2. Enemy reaction by class: beasts and walkers trigger; flyers and spiders are immune to ground webs; smart enemies (goblins, undead) avoid traps they saw you lay, so value is highest out of sight or behind bait; bosses are immune to snare and partly resistant to damage.
3. Snare, then eat or tame: a web holds a living target about 3 s (*placeholder*) at no damage; the spider may eat a snared creature at or below a weakened threshold (*placeholder* 30%), and the same threshold lets the goblin net it and tame it instead. No source gives the threshold [gap].
4. Decide aggro explicitly: Don't Starve's trap damage does not aggro neighbours, so players grind packs. Here, trap damage aggros the pack.
5. Goblin junk traps re-arm with junk, since one-shot traps feel wasteful (Dwarf Fortress).

### Trap families by area [inf]
| Area | Families | Note |
|---|---|---|
| Cave | stalactite drop (the decor exists), collapse floor, spike pits | teach plates and sight triggers alone, none lethal |
| Grotto | spore gas, enemy web snare, spike nests | undead immune to gas |
| Flooded | drowning pits, current vents, flooded trapdoors | no lethal trap near the swim gate |
| Deep | crushers, dart slits, collapsing bridges | hardest area; main route easier than the entry |
| Crypt | plate-and-dart corridor, collapsing sarcophagus floor, mimic coffin, ambush seal door | the trap-room set piece |
| Cathedral | falling chandelier on a tripwire, pendulum blades, statue ambush | roll passes blades; spider uses beams |
| Cemetery | grave pit, spike fence | pits seed nothing; the safe zone has no lethal trap |
| Swamp | poison vents, sinking logs, snapping plants | slime is light on sinking logs |
| Goblin village | goblin-laid tripwire, net, pit-spike, deadfall | a goblin disarms and keeps them; others see a lock |
| Demon | seal plates (weight), fire jets, crush walls | pair with the sealed-gate rule |
| Volcano | fire-jet cycles, rockfall, collapsing crust | volcano rules apply |
| Forest | snares, log traps with knockback, thorn pits | log trap as a knockback tool |

---

## 15. Wiring everything together (nothing is replaced)

Sean, 2026-10-04: "we aren't replacing anything, we are only adding". So the design doc's last area (the goddess fight) and the Serpent Lair stay, and the forest, swamp, village, cathedral cluster, crypt, volcano and demon area are built beside them. Parts 1 to 14 framed the area after the Deep as contested; it is a wiring problem: where each edge leaves from, in what order the spokes open, and how much content that is.

### Scale [repo, inf]
Today: 23 rooms, 45 screens, four areas. Additions from the sketches: forest 7 to 8 rooms; swamp 5 to 6; village 5 to 6; sacred cluster 11 to 14 (cathedral 5 to 6, cemetery 2 to 3, crypt 4 to 5); volcano 7; demon area 6 to 7; plus the last area and the Serpent Lair. That is roughly 40 to 50 new rooms: the world roughly triples before the last area. Consequences:
- **Build each addition as an isolable slice** (the Fungal Grotto and Deep specs ship their rare room as a separable slice), one area at a time, each leaving the suite green.
- **The Map tab will shrink.** Its scale is the smaller of box over bounds, merged across every room [repo: `skill_screen_model.gd`, `skill_screen.gd`]; the Deep spec already noted a 1x1 room is about 25 px. At triple the rooms, plan region pages or a zoom before the second new area lands.
- **Altars:** one per area is the rule; eight more areas means eight more altars and a perk question (all four perks are assigned). Sharing a perk per cluster is the cheap answer.

### Proposed wiring [inf]
Every edge follows A1 (two edges into the existing graph once shortcuts open) and the Swim-door rule: any link from an early area into later content is a one-way shortcut opened from the far side.
1. **Surface spine** (early, optional, base-jump entrance): Cave top (C3) to Forest to Swamp to Goblin village. Loops: a one-way village drop to the forest clearing; a swamp sump (reusing the `swim` gate) to the Flooded Tunnels as the second link.
2. **Main chain, unchanged:** Cave, Grotto, Flooded, Deep.
3. **The Deep becomes a hub.** D2 already has three exits and the Deep is the only branch point with room data to spare. Three spokes leave it:
   - the **crypt cluster** (cemetery hub, crypt spoke, cathedral spoke) off D2, with a one-way coffin slide down to a Deep dead end (D5) that closes a loop; the **demon area** hangs off the far end of the cluster (the Diablo order: church, catacombs, hell) behind sealed gates, as the late optional spoke;
   - the **volcano** as a descent off the Deep's lower end, with its heat-gated rare vault and a one-way ash cut back up;
   - the **Serpent Lair** as the sealed gate, and the **last area** beyond it, opened by the reveal exactly as the design doc says.
4. **Order of play:** the surface spine is open from the start, the chain follows, then the Deep offers the crypt cluster and the volcano in either order. That raises the number of directions a player can choose as skill grows (Bimmel), and Silksong's rule that each key opens only a few locks keeps each spoke's gates local.

### Checks across the whole graph [inf]
- Every addition has at least two edges (A1): forest (C3 and the village drop), swamp (forest and sump), village (swamp and drop), cluster (D2 and the coffin slide to D5), volcano (Deep and the ash cut), demon area (cluster and a shortcut back to the cemetery hub).
- No loop short-circuits the mission (Dormans): the village drop returns to the forest, never to the Deep; the cluster's shortcut returns to the Deep, never to an early area.
- Altar spacing: every gate within about seven screens of an altar (K3), measured on the finished graph.
- The two untouched design-doc areas (the Serpent Lair and the last area) keep their unlock rules; no new area adds a required key to them.

---

## 16. Decisions added by part 2

1. **Confirm or move the wiring in section 15.** Nothing is replaced. The open choices are which Deep room each spoke leaves from, whether the demon area hangs off the crypt cluster or opens only after the reveal, and whether the village drop returns to the forest or the cave.
2. **Can an undead feed in a safe zone?** Undead drain life from living creatures and a safe zone has no hostile spawns. Options: harmless fauna that can be drained, or none (undead banks essence elsewhere).
3. **Are bone creatures hostile to an undead player?** They are not living, so a draining undead cannot feed on them. Likewise, do demons hate undead?
4. **A fifth altar perk.** All four perks are assigned to the four altars; each new area cluster either shares one or needs another.
5. **Combo-death seed rule (TR9)** and **village standing (VI2)** are both unsourced designs; confirm or replace them.
6. **Which side is the goddess on?** It decides whether holy art signals safe or threat in the cathedral and demon area.

---

## 17. Size target: at least as big as Super Metroid

Sean, 2026-10-04: "lets make sure we are at least as big as super metroid." This section turns that into numbers.

### The yardstick [read, repo, inf]
| | Rooms | Screens | Screens per room |
|---|---|---|---|
| Super Metroid (Zebes) | 255 | 1,274 map tiles | 4.9 (median 4, max 42) |
| This world today | 23 | 45 (640 by 360) | 2.0 |
| With every planned addition | about 69 | about 125 | about 1.8 |

Planned additions, from the sketches: forest 9 rooms and about 16 screens, swamp and village about 11 rooms and 19 screens, sacred cluster about 12 rooms and 24 screens, volcano 7 rooms and 10 screens, demon area 7 rooms and 13 screens.

On raw counts the finished plan reaches **27% of Super Metroid's rooms and 10% of its screens**. Two things shrink the screen gap, neither precisely:
- **Screen size is not the same.** A Super Metroid map tile is one 16 by 16 block screen; ours is 640 by 360 pixels with a 28 pixel slime. Equal pixel area would be about 360 of our screens; equal body-scaled area about 550; equal screen count 1,274 [inf: assumes a 16 by 32 pixel Samus and a 28 by 28 slime].
- **Our rooms are smaller.** Super Metroid's median room is 4 screens; ours is about 2.

**Recommended bar [inf]:** at least 255 rooms at today's room size (about 560 screens), which meets the body-scaled estimate. The strict bar (1,274 screens) needs about 650 rooms at today's size, or 255 rooms that average 5 screens like Super Metroid's.

### Room budget by area [inf]
Super Metroid's six areas run 16 to 76 rooms (Wrecked Ship smallest, Norfair largest, mean 42). Twelve areas averaging about 21 rooms reach the bar; the table gives 256:
| Area | Today | Planned sketch | Target |
|---|---|---|---|
| Cave | 6 | 6 | 18 |
| Fungal Grotto | 5 | 5 | 20 |
| Flooded Tunnels | 6 | 6 | 20 |
| The Deep (hub) | 6 | 6 | 26 |
| Forest | 0 | 9 | 24 |
| Swamp | 0 | 6 | 20 |
| Goblin village | 0 | 5 | 18 |
| Sacred cluster (cathedral, cemetery, crypt) | 0 | 12 | 40 |
| Volcano | 0 | 7 | 26 |
| Demon area | 0 | 7 | 26 |
| Last area | 0 | not sketched | 16 |
| Serpent Lair | 0 | 1 | 2 |
| **Total** | **23** | **about 70** | **256** |

That is about 3.7 times the planned content (186 more rooms) and 11 times what exists. Four levers, mixable:
1. **Grow the existing four areas to 18 to 26 rooms.** The cheapest single lever: the four existing areas alone account for 61 of the 233 rooms still to build (23 now, 84 target), and their themes and creatures already exist.
2. **Raise the room size.** Super Metroid's median is 4 screens, ours 2. Larger rooms (3 by 1 corridors, 2 by 2 chambers, 1 by 3 shafts) add screens without adding rooms; each new area could aim at 3 screens per room.
3. **Add areas.** Hollow Knight lists 19 locations and Silksong has 12 areas; two more areas of 18 rooms close the gap without growing any other.
4. **Nest optional rooms.** Super Metroid's 66 single-screen rooms (a quarter of all rooms) are small connectors and item closets; short rare rooms are cheap rooms.

### What this size changes elsewhere [inf]
- **Respawn and travel.** One altar per area and a seven-screen rule (K3) cannot both hold at 40 to 60 screens per area. At this scale add altars per sub-region or altar-to-altar warping; every comparable game adds fast travel as the map grows (section 2). This is the strongest push on decision 3 in section 9.
- **The Map tab** scales to fit the whole world; at 256 rooms it needs region pages or a zoom, before the second new area lands (section 15).
- **Production.** Each area is an isolable slice. `tools/world_size.sh` is the size meter: it prints rooms, screens and rooms per area against Super Metroid and the table above, straight from `data/rooms`. The room editor's World button shows the same numbers (totals, the three yardsticks, rooms per area against the budget) above and below the map; both read `WorldSize` (`scripts/world/world_size.gd`), where the budget lives in `TARGETS`. It is informational only: it never fails a build and no test checks the world against it. Re-run it per merge.
- **Content per room.** Super Metroid pays for its size with reuse: a quarter of its rooms are one screen. Our rule that each room has one idea (section 4) keeps most new rooms cheap.

---

## Sources

Read (fetched; summarised by a small model unless noted):
- Dormans, "Adventures in level design" (2010), pcgworkshop.com/archive/dormans2010adventures.pdf (read as text)
- gamedeveloper.com: Unexplored cyclic dungeon generation; Invisible Hand of Super Metroid; How Blasphemous level design iterates; Dead Cells procedurally generated metroidvania (also deepnight.net); Dead Cells art design deep dive; Building a house for the devil (Guacamelee DLC); Carrion level designer interview; Scroll Back (cameras); Composition in level design; Level design patterns in 2D games; Anatomy of an enemy attack in Dark Souls 3; GDC 2018 level design workshop; Atmosphere in games part 8; Ori WotW Q&A; book excerpt World design for 2D action-adventures
- boristhebrave.com Unexplored dungeon generation; dicegoblin.blog cyclic dungeons; gmtk.substack.com (Silksong world design); acmi.net.au (Hollow Knight); thegamer.com (Dark Souls interconnected design; Ori art interview); goombastomp.com (Super Metroid; Zero Mission); mcvuk.com (Dead Cells)
- Smith, Treanor, Whitehead, Mateas, "Rhythm-Based Level Generation for 2D Platformers" (eis.ucsc.edu/papers/smith-fdg-09.pdf, read as text); Compton and Mateas, "Procedural Level Design for Platform Games" (AAAI 2006, cdn.aaai.org .../18755, read as text)
- book.leveldesignbook.com: wayfinding, pacing; rubenbimmel.itch.io pacing devlog; subtractivedesign.blogspot.com; afewbitsshort.com sequence breaking; dreamnoid.com
- Wikipedia: Wonder Boy III Dragon's Trap; Shantae Risky's Revenge; Castlevania Portrait of Ruin; Monster Boy; Majora's Mask; Rogue Legacy and 2; Hollow Knight; Ori and the Blind Forest; Cave Story; Animal Well; Super Metroid; Spelunky; Metroidvania
- gamerant.com Biomorph interview; zeldadungeon.net (Aonuma on the cycle); gaminghistory101.com Wonder Boy retrospective; resetera.com Dragon's Trap thread
- Forest: aran.ink Celeste tilesets; hookshotchargebeamrevive.wordpress.com Hollow Knight; soldierfromthesurface.com Cave Story; ludonauta.itch.io Hollow Knight terrain; sandromaglione.com pixel platformer guide; galaxytrail.tumblr.com platform gimmicks; ljvmiranda921.github.io Celeste part 2; terraria.wiki.gg Forest and Layers; news.xbox.com Ori preview; toschestation.net Pellen interview
- Volcano: wiki.metroidprime.run Varia Suit; omegametroid.com Furnace of Cataris; gamerwalkthroughs.com Mount Horu; celeste.ink Core; mossbag69.blogspot.com Hollow Knight cut content; terraria.wiki.gg Lava and Underworld; minecraft.wiki Obsidian; magmmlcontest.com Rising Lava; mariowiki.com Falling Platform; yachtclubgames.com Specter of Torment level design; retrostylegames.com platformer tips; tadeasjun.com 2D level design

Snippet only (not opened, or body empty): TV Tropes Sorting Algorithm of Threatening Geography and Lethal Lava Land (403; trope-level ordering only, no designer rationale); Metroid wikis (402/403); PC Gamer "how to design a great Metroidvania map" (no body); Wheeler "35 ways to guide the player" (wayfinding perception claims); Lynch element summaries; Dread heat and Silksong Mount Fay heat lamps; Isma's Tear; GamesRadar Animal Well; Hollow Knight region and room counts. Pages that failed twice were skipped, not retried. Metroid Dread Report failed a certificate check and was not retried.

Not found: any game where changing form costs a death in a fixed world; rooms per region for Hollow Knight, Super Metroid, Ori; biome-order rationale from a designer; surface-reveal camera or music recipes; open-sky handling in a screen-grid engine; eruption or crumble timings; hazard share per room.

Part 2 sources (read; full lists with every URL are in `area-level-design-notes/`):
- Sacred cluster: gamedeveloper.com (Symphony of the Night economy and thematic structure; Blasphemous); nethackwiki.com Sanctuary; Wikipedia (V Rising, Soul Reaver, Metroid Prime 2 Echoes, Boktai, Crypt, Churchyard, Church architecture); Fextralife (Dark Souls Catacombs and Tomb of Giants, Hollow Knight Resting Grounds, Nioh Yokai); terraria.wiki.gg The Hallow; thegamer.com and pcgamesn.com (Dark Souls interconnection, Undead Burg); denofgeek.com Anor Londo; twinelab.net (Nioh 2).
- Swamp and village: mariowiki.com Hornet Hole; mezunian.com Bramble Scramble; gamerwalkthroughs.com Misty Woods; worldofleveldesign.com (Left 4 Dead 2 guide); terraria.wiki.gg (Jungle, Housing, Goblin Tinkerer, Goblin Army); thenerdstash.com and rogueranker.com (Mantis Lords); en.uesp.net Orc strongholds; fromsoftwiki.org covenants; steamcommunity.com (Divinity Original Sin 2 undead discussion, player reports); architectureofzelda.com monster strongholds; book.leveldesignbook.com and slickaria.blog (Undead Burg).
- Demon area: Wikipedia (Inverted Castle, Harmony of Dissonance, Gauntlet, Doom, Diablo, Blasphemous, Cuphead, Bloodstained); shmuplations.com and goombastomp.com (Symphony of the Night); soulslore.wikidot.com Dark Souls design works; glitterberri.com and sourcegaming.info (A Link to the Past); architectureofzelda.com Ganon's Castle; timeextension.com and shacknews.com (Ghosts 'n Goblins); gamedeveloper.com (Doom 2016; Build a Bad Guy); deadcells.wiki.gg Curse; kotaku.com and pvplive.net (Hades level design).
- Traps: ludomotion.com; kateplays.substack.com; gamedeveloper.com (Fairness, Discovery and Spelunky; Spelunky analysis; level design patterns; enemy attacks and telegraphing); awweide.substack.com (Prince of Persia); pcgamesn.com Sen's Fortress; terraria.wiki.gg (Traps, Dart Trap, Pressure Plates); dwarffortresswiki.org (Trap, Pressure plate); deadcells.wiki.gg (Hazards, Deployable traps); dontstarve.wiki.gg Tooth Trap; minecraft.wiki (Cobweb, Pressure Plate); game8.co (Silksong tools, Monster Hunter capture); yachtclubgames.com checkpoint design.

Not found in part 2: designer write-ups on holy-zone fairness, stained glass, pews or burial niches as 2D level tools; a designer account of a forest-to-marsh transition; any 2D metroidvania where species changes a settlement's behaviour; how the Inverted Castle was re-gated; summon-on-low-HP as a documented enemy pattern; fire-jet, gas-vent or crumble-floor cycle times; traps per screen. The web-search budget ran out mid-run, so several topics are snippet-only (marked in the notes).
