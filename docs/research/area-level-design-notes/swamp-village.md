> Unedited agent notes. Where they conflict with `../area-level-design.md`, that document wins.

# Swamp and goblin village: sourced research for the forest cluster

Tags: **[read]** fetched and read this run. **[snippet]** search-result text only (page not opened, or the host returned 403). **[inf]** my inference, source named. **[gap]** searched, nothing found. **[repo]** read in this repository. **Not searched** = I did not look; that is different from [gap]. WebFetch summarises each page with a small model, so every quoted phrase below is the summariser's wording; none was re-fetched verbatim. Overlap with `area-level-design.md` (Dead Cells tunnel and palettes, Mimiga "danger-free zone", Majora's persistence) is cited in one line, not repeated. Numbers marked *placeholder* are mine and meant to be tuned.

---

## 1. Swamp precedents and what is cheap and fair

### What the precedents show
- **Maridia (Super Metroid), the slow-terrain warning.** Without the Gravity Suit "she just seems to slide left and right randomly", and jumping out of quicksand needs "shady timing"; the author reads this as deliberately obtuse, to teach why the suit matters [read: gamedeveloper Invisible Hand]. Maridia mixes water and quicksand as its two hazards and reads as "a genuine ecosystem" rather than a dungeon [read, same page]. Another source: Samus "moves very slowly in water", sand walls and quicksand floors, surfacing kills momentum, "a habitat" [snippet: Anatomy of Super Metroid, metroid wikis; 403 on fetch]. Lesson for sinking terrain: the escape must not need tuned timing [inf].
- **Hornet Hole (Donkey Kong Country 2), the closest sticky-terrain template.** "The Kongs can neither walk nor attack while they are stuck to the honey, and jumping is the only way they can free themselves from it." Honey sits on the ground (forces a jump across) and on walls (cling and jump up, wall jump between two honey walls). It is introduced early: a barrel and "a few spots on the ground" before it is used in earnest. The spider-like animal buddy Squitter "cannot be slowed down by the honey on the ground", so one character is immune [read: mariowiki Hornet Hole]. This is a cheap rule, per-species immunity, a one-input escape and early teaching in one level.
- **Bramble Scramble (DKC2), vines as a lane.** Vertical and horizontal vines replace barrel cannons; the level "zigzags all o'er the place, but is technically linear"; two themes (bramble throughout, flying section as breaks) keep it from going stale; praised because difficulty is fair, contrasted with the repetitive Bramble Blast [read: mezunian]. Hornet-pack weaving (Zingers packed tighter in the second set) is the hazard [snippet: mariowiki].
- **Misty Woods (Ori and the Blind Forest), reduced visibility.** "You also don't have access to the map as it's shrouded in mist"; the forest "will change as you head back to the right" so you are in a different place; the Shrouded Lantern must be found and returned, and while carrying the light you "won't be able to use special abilities"; plants "provide a landing" [read: gamerwalkthroughs]. Fairness comes from a carried light, learnable hazard patterns and a goal (relight the lantern), not from hiding the platforms. Ori's Silent Woods has tar that kills on touch [snippet: search summary].
- **Spelunky dark levels.** Some levels are "randomly plunged into darkness", in cave, jungle or temple levels [read: gamedeveloper Spelunky analysis pt 2]. A torch is provided at the start of a dark level; one summary calls dark levels fair for three reasons (several torches or flares, a larger light radius, and hazards and enemies that do not move off screen), while critics note enemies can see you when you cannot see them [snippet: search summary, original post not opened]. The Jungle's enemy set is leaping frogs, swimming piranhas and clinging monkeys, each simple, combining into complexity [snippet: gamedeveloper Yu interview summary].
- **Low-visibility rules from a level-design guide.** For dark tunnels: "Make sure that you can see where you need to go by placing a simple light in the distance or making the player only move forward"; "Do not create mazes"; fog, haze, smoke and rain add tension while "some lights up to let the player know where to go" [read: worldofleveldesign L4D2 guide, written for a 3D shooter, transfers as principle].
- **Dead Cells Toxic Sewers.** Complementary palettes "are great for giving a confined feeling to a space"; a long mandatory tunnel before the sewers "visually signals direction and location"; saturated backgrounds keep the player "awake and alert" [read: gamedeveloper art deep dive]. Sewers are tight, restricting jump and dodge, with poison clouds and wall-spike enemies [snippet: search summary].
- **Hollow Knight Greenpath, Fog Canyon, Queen's Gardens.** Greenpath is lush with acid lakes and vine-suspended platforms; Fog Canyon sits between Greenpath and the Fungal Wastes with acid lakes, thorns and explosive floating jellies; Isma's Tear (acid immunity) is the key [snippet: fandom and steam summaries]. Community view: Fog Canyon is the weakest area, only two enemy types, and "a hole in the map" for a long time because it cannot be finished until Shadow Dash [snippet: steam discussion]. Cautionary: a pocket that is visible long before its key reads as clutter [inf from that snippet].
- **Majora's Mask Southern Swamp.** Purple water around the Deku Palace is poisonous (half a heart per second), Deku Link hops lily pads, a boat tour crosses the murky water, a monkey guides you to the palace [snippet: zeldadungeon and zelda-archive summaries; 403 on fetch]. A guide-by-NPC plus a form-specific lane, not a depth trick [inf].
- **Terraria Jungle.** Surface biome "composed primarily of Mud Blocks with Jungle grass and Jungle vines, with a dark green background", water pools with bamboo, bee hives that fall from the ceiling, and enemies with "much more health" and damage than other surface areas [read: terraria.wiki.gg Jungle]. Identity is material, palette and an enemy-tier bump; the page lists no slow-mud mechanic [read].
- **Will-o'-the-wisp.** Folklore: a light that is "said to mislead and/or guide travellers", seen "over bogs, swamps, or marshes"; Welsh versions leave you lost when the fire goes out [read: Wikipedia]. The page has no video-game section; I did not search other pages for game uses [gap on that page, otherwise not searched].
- **Not searched:** Metroid Dread, Rayman, Blasphemous, Shovel Knight, Castlevania, Zelda swamp dungeons, Ori Inkwater Marsh design rationale (one search returned only walkthrough pages), Terraria quicksand.

### Which ingredients are cheap and fair here [inf]
| Ingredient | Cost in this engine | Fairness note | Source |
|---|---|---|---|
| Sticky or sinking mud | One new rect type, one step in the ground controller | One-input escape, shallow cap, taught alone first; per-species immunity | Hornet Hole; Maridia warning |
| Murk, fog, reduced visibility | Overlay and parallax only, no physics | Never over the walkable edge; a light cue and a linear route | L4D2 guide; Misty Woods; Dead Cells outline rule in existing doc |
| Boardwalks and stilts | Solids and one-way ledges, already supported | Doubles as the depth cue and the safe route | Level Design Book planks cue (existing doc) |
| Vine swing | Thread-swing exists for the slime; a new anchor class for others | Optional lane (Bramble Scramble) | Bramble Scramble |
| Poison water | Damage-zone system: does not exist | Repeats the Grotto spores and Flooded water | Southern Swamp (snippet) |
| Ambushers (frog, leech, lizard) | Existing creature archetypes with new art and spawn rules | Telegraph, in the visible window only | Spelunky Jungle; Scroll Back warning (existing doc) |
| Guide wisps | Decor lights, no logic | Main route only; lures only to optional rooms | Folklore "mislead and/or guide" |

### How games keep reduced visibility fair (sourced) [read unless marked]
1. Give a light cue in the distance and a linear route (L4D2 guide). 2. Provide a carried or placed light (Spelunky torch [snippet]; Ori lantern). 3. Hazards do not act off screen [snippet: Spelunky summary]. 4. Keep backgrounds saturated and platforms outlined so threats read (Dead Cells). 5. Withhold the map, not the platforms (Misty Woods). 6. Learnable hazard patterns inside the fog (Misty Woods).

---

## 2. How the swamp differs from what exists, and how it transitions out of the forest

### Difference from today's areas [repo + inf]
- Flooded Tunnels own **deep-water rects with Swim physics** and the `swim` gate; Fungal Grotto owns **poison spores and vines** (existing doc section 1). `RoomDef.water` rects are deep water only, at least 32x32, inside the room, never overlapping or touching (`room_def.gd` [repo]); shallow water is decor [repo]. `WorldValidator.GATES` is `["wall_cling", "swim"]` [repo].
- So the swamp must not be "more water" or "more poison". Candidate new rules: sinking mud (Hornet Hole template), murk (dressing only), boardwalk verticality. [inf]
- Recommended single rule: **bog mud**, a ground-contact rect that slows walking and sinks the body a little, escaped by jumping. Murk and boardwalks are dressing and structure, not rules; poison is rejected. [inf: Hornet Hole, Maridia, Grotto overlap]
- A deep sump that is the swamp's one link to the Flooded Tunnels may reuse the existing water rect and `swim` gate, so no new gate and no repeated mechanic. [inf]

### Transition out of the forest
- **Sourced ingredients:** a long tunnel before the sewers signals a biome change, and recolouring one gradient map changes a biome's palette [read: Dead Cells art deep dive]; Terraria separates Jungle by material (mud, jungle grass, vines) and a dark-green background [read]; Minecraft swamps smooth tints between biomes, put vines on trees and use denser green fog [snippet: minecraft.wiki summary]; Greenpath-to-Fog Canyon is a lateral hand-off between two green-grey areas [snippet].
- **No designer write-up of a 2D forest-to-marsh transition was found.** [gap]
- **Recommended sequence** [inf from the above]: canopy thins and the parallax tint shifts green-grey over 2 to 3 screens; floor grass breaks into first a single harmless mud patch (the teaching spot), then boards; ambient water sound and wisp lights arrive before the first mud span; a one-room tunnel or root hollow at the seam so the palette changes behind a door, as Dead Cells does.
- Keep the forest's saved light (day tint) behind you: swamp rooms use a lower value range and a cooler gradient map. [inf: Dead Cells gradient maps]

---

## 3. Goblin village precedents

- **Hollow Knight Mantis Village.** The entrance is hostile: "it becomes that everything here is very much out to kill you"; the throne room lets the player choose to "challenge" the Lords rather than ambushing; after victory the Mantis stay passive and "bow when you walk past them", the Deepnest gate opens and the rest of the village (with a bench) is accessible [read: thenerdstash, rogueranker]. A trial converts hostility into persistent world state and a shortcut.
- **Dirtmouth.** "A quiet town that sits just above the remains of the kingdom" [read: Wikipedia Hollow Knight, thin]; no design analysis of it found [gap].
- **Cave Story Mimiga Village.** "A danger-free zone" for practising running and jumping, the plot advanced by fetch quests, open-ended exploration [read: soldierfromthesurface]. Arthur's House is the teleport hub and a save point [snippet: wiki summary].
- **Silksong hubs.** Bone Bottom, Bellhart (houses built from bells, a decorable "Bellhome" rest point) and Songclave each give a rest bench, merchants and a wish-board; Songclave gains NPCs as wishes are completed [snippet: fextralife and hostedgg]. Each area "has its own colour palette and vibe and can be easily identified from a screenshot", the Citadel less so [read: GMTK].
- **Ori Wellspring Glades.** A hub of NPCs offering missions and powers; Grom rebuilds the Glades from collected ore [snippet: gamefaqs and fandom summaries]. Order of Ecclesia's Wygol Village is a deserted village whose villagers are rescued; the page gives no hub mechanics [read: Wikipedia, thin].
- **Terraria NPC housing.** A house needs light, table, chair and door, 60 to 750 tiles, minimum 7x9 including frame; NPCs move in when their spawn conditions are met [read: wiki.gg Housing]. The **Goblin Tinkerer** is a Bound Goblin found underground after defeating a Goblin Army; he reforges for a third of an item's value and sells Rocket Boots (5 gold), Grappling Hook (2 gold), Tinkerer's Workshop (10 gold); he was "tied up and left" by other goblins for disagreeing with them; "they could start a war over cloth" [read: wiki.gg Goblin Tinkerer]. A **goblin raid** starts at dawn, enters from a random world edge toward spawn, needs 80 + 40 x players kills (120 solo), with Peon, Thief, Warrior, Sorcerer and Archer [read: wiki.gg Goblin Army].
- **Breath of the Wild camps.** A "fixed set of archetypal buildings" (skull caves, sentry turrets, tree forts, water redoubts, multistory fortresses) is combined into settlements; tree forts are elevated, "commonly inaccessible from the ground, but for the occasional drawbridge"; Lizalfos water platforms mean "Any approach is immediately visible to guards"; loot is scavenged plunder (boxes, barrels, arrows, chests, low-quality weapons) built with rope cross-bracing [read: architectureofzelda]. Camps sit at the foot of landmarks as "environmental surprises" along the player's orbit [read: radiator blog]. A designer talk on camps as modular encounters was not found [gap]; GDC 2017 BotW panel exists [snippet].
- **Dark Souls Undead Burg.** A wooden bridge is "a chokepoint, forcing you to fight"; ambush teaching goes 1, 2, then 4 enemies; "one-way drops / verticality enforce a one-way flow"; optional loops return to the critical path; a merchant is hidden under crates near a bonfire [read: leveldesignbook]. The first approach pits swordsmen below against a firebomb thrower above, then a rat ambush trains corner-checking; Loop One uses a red ladder as a wayfinding marker; Loop Two returns over a bridge jump impossible from below [read: slickaria]. Rooftops reached from a waterway through an aqueduct [snippet: pcgamesn].
- **Not searched:** Dragon Quest towns, Salt and Sanctuary sanctuaries, Dirtmouth design analysis beyond Wikipedia.

### What makes a village a good level [inf from the above]
Vertical dwellings and rooftops give the unused mantle, vault and slide verbs hard ledges to act on (existing doc 5.4); a drawbridge or gate is the single ground entrance, elevated forts the rest (BotW); a bridge chokepoint and a 1-2-4 ramp stage the hostile first approach (Undead Burg); one safe node with rest, shop and altar (Mimiga, Silksong); a shortcut that closes a loop into the area you came from (Undead Burg ladder, Mantis gate); NPC services that grow as the player completes things (Songclave, Terraria).

---

## 4. Faction-aware areas

- **Skyrim Orc strongholds.** "Orc player characters receive immediate, unchallenged access"; others can enter but residents "will continuously tell you that you are not welcome", and merchants, trainers and followers are unavailable until the player completes Blood-Kin quests, which send word that you are "to be trusted"; the page does not say residents attack [read: UESP].
- **Majora's Mask forms.** Link's forms "receive different reactions from other characters"; "town guards do not permit Deku Link to leave due to his childlike appearance" while Goron and Zora can [read: Wikipedia]. Deku Scrubs talk only to a Deku, puppies approach Zora Link first [snippet: search summary].
- **Hollow Knight Mantis.** Earned, persistent respect after a trial (section 3) [read].
- **Dark Souls covenants.** Joining Forest Hunter makes the forest's hunters non-hostile and opens Shiva's shop; attacking Alvina or a member betrays the covenant and makes them hostile; killed NPCs make a covenant unjoinable without New Game Plus [read: fromsoftwiki].
- **BotW and TotK monster masks.** The Bokoblin Mask lets bokoblins approach without attacking unless provoked; attacking breaks it; Keese ignore the disguise [snippet: zelda wiki and hardcoregamer summaries; 403 on fetch].
- **Failure mode: Divinity Original Sin 2 undead.** Players report guards and non-undead NPCs attack on sight unless a helmet or full gear hides the undead face (reports conflict on the exact rule), the Mask of the Shapeshifter is an undead-specific fix, and once guards turned hostile "they will stay hostile no matter what you do", locking the player out of merchants [read: steam discussion, player reports, not official docs]. A permanent hostility ratchet is the pattern to avoid.
- **No source found** for a 2D metroidvania where the player's species changes a settlement's behaviour. [gap] Monster Hunter and Salt and Sanctuary: not searched.

### Fair, cheap pattern [inf from Skyrim, Mantis, Majora, DOS2]
Standing is derived, not stored as a one-way ratchet: `standing = f(current species, persistent trust flag)`. Welcome, wary or hostile only gates **services and side rooms** (Skyrim: services off, no attack); the **spine** through the village stays base-jump reachable and fight-free for every species; trust can be earned by any species (Mantis trial, Blood-Kin) and persists across lives (existing rule K1); attacking a villager costs trust for that life only, never permanently (DOS2).

---

## 5. Rules for this game [inf unless marked]

### Swamp: one new rule, bog mud
| # | Rule [inf] | Derives from |
|---|---|---|
| SW1 | New room data `mud: Array` of Rect2 beside `water`, same checks (at least 32x32, inside the room, no overlap or touch with other mud or water); built by a `MudPatch` node like `DeepWater` [repo: `room_def.gd` water field] | `room_def.gd`; Hornet Hole |
| SW2 | Physics, *placeholder*: walk speed about 60% on the mud surface; the body sinks at about 20 px/s to a hard floor 12 px deep (about one fifth of the 63 px base rise); no damage | Hornet Hole; Maridia |
| SW3 | Escape is one jump press, full base rise measured from the sunk position, no timing window; mud never kills by depth | Maridia "shady timing" warning |
| SW4 | Lint `mud_escape`: any ledge reached from a mud span must satisfy height above surface + 12 px at most `REACH_RISE` 55, so at most 43 px; mud is never the only exit from a pit; no mud inside a 64 px exit zone [repo: `REACH_RISE 55`, exit zone 64 px] | Suzy Cube margin rule (reference doc 1.9); Maridia |
| SW5 | Mud is not a gate (do not add to `WorldValidator.GATES`); it only modifies lanes. The main route crosses at most one short mud span after a harmless teaching patch | Hornet Hole early teaching; reference doc gating |
| SW6 | Murk is a no-physics overlay on background and parallax, never over a walkable edge; platform edges stay outlined; every murk room has a light cue (wisp, lantern, glow pool) visible from the entry and a linear spine | L4D2 guide; Dead Cells; Celeste outline (existing doc) |
| SW7 | Depth cues: stilts, reed tops and board ends show the surface; no deep-water rect without a visible rim or post; at most one swim sump, the link to the Flooded Tunnels, which reuses `swim` | Level Design Book wayfinding (existing doc); gate discipline |
| SW8 | Guide wisps are decor on the main route only; "false" wisps (a creature lure) may lead only to optional rooms, never over lethal ground, and never in the first swamp room | Folklore "mislead and/or guide" |
| SW9 | Introduce mud alone (one patch, no creatures), then with one ambusher, then with murk; one timed hazard type per room | Hornet Hole; Spelunky personalities; existing doc section 4 |
| SW10 | Bounded visibility rule: no timed hazard or ambusher inside murk beyond the lit window; ambush spawns telegraph (ripple, bubbles) at least 340 ms | Spelunky snippet; Dark Souls 3 floor in existing doc |

### Species lanes (swamp and village) [inf]
- **Slime:** mud is its medium, immune like Squitter to honey [read: Hornet Hole]: unslowed through low mud channels under the boardwalk (a squeeze lane); bounce caps (checked against the reach model) over wet gaps.
- **Spider:** the same immunity precedent; crawl and zip stilt and board undersides. Engine fact: slick is built in the movement layer (`SurfaceStep.SLICK`, `ZipStep` fizzles on slick, sandbox slick block and ceiling) but no `slick` field exists in `scripts/world` or `data` [repo: grep]. So mud is no gate for the spider and the 20 px ceiling lets it cross any mud span; a slick ceiling tag needs room data first. That is acceptable because mud gates nothing.
- **Wolf:** pounce clears a mud span (arc longer than the span); gallop across it is slowed, so wide mud strips are the wolf's lane only where the pounce lands on a hard lip; vault logs under 24 px.
- **Goblin biped:** mantle onto boardwalk and palisade lips (hard ledges), wall jump up stilt pairs (DKC2 honey walls allow the same trick [read]), roll or slide skims a short mud strip without sinking (*placeholder*), crawl-slide under huts.
- **Undead (planned):** walks the sump floor under murk unslowed, a bottom lane like Zora's [snippet: Majora's Mask]; wary at the village like every non-goblin.
- Every lane is optional; the base jump crosses the swamp and village spine. [inf: repo rule]

### Village: hub with altar, rest, crafting, shortcuts
| # | Rule [inf] | Derives from |
|---|---|---|
| VI1 | **Altar and rest pool sit in a neutral room with no hostile spawn for any species** (gatehouse shrine outside the palisade), never inside walls where a non-goblin would respawn into enemies; the altar is the area's first room by convention [repo] | rebirth at chosen altar [repo]; Mimiga "danger-free" |
| VI2 | Three standings per room, derived: welcome (goblin or trust flag), wary (no attack, services off, speech lines), hostile (inner ring only, optional rooms) | Skyrim; Mantis; BotW camp layers |
| VI3 | New spawn fields `hide_for_species` / `only_for_species` on guards and on the NPC service; a validator pass per species asserts the spine has no unavoidable hostile for that species and the altar room has none | Skyrim services; movesets per-species pass (existing doc 5.5) |
| VI4 | A trust trial (a Mantis-style challenge arena, or delivering a scavenged item) sets a persistent `village_trust` flag any species can earn; standing never ratchets down permanently, only per life | Mantis trial; Blood-Kin; DOS2 failure mode; K1 |
| VI5 | Village structure: one ground gate with a drawbridge or palisade chokepoint, elevated forts reached by verb lanes, rooftops as the hard-ledge test bed | BotW tree forts; Undead Burg; existing doc 5.4 |
| VI6 | First approach staged hostile only for non-goblins: bridge chokepoint, then 1, 2, 4 sentries teaching wary lines, watchtower sightlines so approach is visible | Undead Burg 1-2-4; BotW "approach immediately visible" |
| VI7 | Shortcuts: one-way drop from the village to the forest Clearing or Cave (closes a loop, rule A1); a palisade gate opened from inside by a switch; one trust-gated shortcut | Undead Burg ladder; Mantis gate; existing A1 |
| VI8 | Nothing required sits behind welcome or trust: crafting, taming and the rare room do, plus one cosmetic or lore reward for the trial | Skyrim "services unavailable"; K1 |

### Goblin-specific content [inf]
- **Crafting:** a Tinker's bench in the village yard that turns scavenged junk into consumables, reforge-style upgrades and trap kits (Terraria Tinkerer reforges and sells utility [read]); only goblins craft on arrival, others after trust.
- **Scavenging:** junk piles (boxes, barrels, arrows, low-quality weapons) as BotW-style plunder around swamp rooms and camp edges [read: architectureofzelda]; a pile type per room, no respawn within a life.
- **Taming and nature of creatures:** a frog, a bog hound or a captive "bound" beast to free and tame, echoing the Bound Goblin [read: Goblin Tinkerer]; bestiary pages unlocked by combat and interaction; the tamer evolution gets a village mentor.
- **Raid:** an optional goblin raid scene as the village defence event, entering from one screen edge, kill-count style (80 + 40 x players is Terraria's, not ours) [read: Goblin Army].

### Creature roster tied to existing archetypes [inf]
Eel becomes a mud lurker (ripples, then bite); jelly becomes a glow-bloat or false wisp; ant becomes a bog beetle; wolf pack becomes goblin hunters with tamed hounds; stone drake becomes a bog drake or armoured croc (late); Grotto vine and spore creatures stay out of the swamp; plus a ceiling leech and a leaping frog (Spelunky Jungle set [snippet]). Goblin guards: sentry (turret-style, ranged, watchtower), brute, scrounger.

### Sizes [inf; areas today are 5 to 6 rooms and 9 to 14 screens, existing doc]
Swamp 5 to 6 rooms, 9 to 11 screens; village 5 to 6 rooms, 8 to 10 screens; cluster about 11 rooms and 18 to 20 screens, so it is roughly one and a half areas; consider trimming the village to 5 rooms.

### Candidate cluster layouts
Verbs: J base jump, B bounce, Z zip or crawl, P pounce, M mantle, W wall jump, S swim. `*` = main route (base jump only).

**A. Linear with a village loop** (attaches at the forest Clearing; second edge is a drop to the cave)
```
Forest Clearing* 1x1 (hub, forest rest pool)
   |  tunnel seam (palette hand-off)
Boardwalk* 2x1 -- teaching mud patch, wisps ahead
   |
Bog Flat* 2x1 -- one mud span, ambusher (mud lurker)
   |--[Z] stilt undersides ---> Stilt Roost 1x1 (rare: spider/slime)
   |--[P] mud span 3 wide ----> Hunting Blind 1x1 (rare: wolf, junk cache)
Gate Shrine* 1x1 (ALTAR, neutral, rest pool)
   |  drawbridge chokepoint (wary lines, 1-2-4 sentries for non-goblins)
Village Yard* 2x1 (crafting, tame pen)       Palisade Roofs 2x1 (M, W, goblin lane)
   |                                             |
   +--[trust] Chieftain Hall 1x1 (trial) <-------+
   |
One-way drop -> Forest Clearing (loop)   Sump 1x1 [S] -> Flooded Tunnels (second link)
```
**B. Village first, swamp as the spoke** (hostile first approach, swamp is the long optional reward; attaches at the Floor Trail)
```
Floor Trail 3x1 (forest, wolf lane)
   |
Palisade Gate* 1x1 (ALTAR, neutral) --> Village Ring* 2x1 (wary for non-goblin)
   |                                        |-- Watchtower 1x2 [M, W] -> rooftops
   |                                        |-- Tinker Yard 1x1 (crafting, goblin welcome)
   |                                        \-- Back Gate (switch) -> Boardwalk* 2x1 -> Bog Flat* 2x1
Bog Flat* -- Wisp Lane 1x2 (guide lights, optional) -- Sump [S] -> Flooded Tunnels
Bog Flat* -- Drake Mire 1x1 (late, stone-drake variant, rare room)
```
**C. Swamp as hinge between forest and the Flooded Tunnels; village on a stilt island** (needs a swim link, so two edges are built in)
```
Forest Clearing* ---> Boardwalk* 2x1 ---> Bog Hall* 2x1 (mud, murk)
                                               |
                         Stilt Landing* 1x1 (ALTAR, neutral) ---> Island Village* 3x1 (rooftop loop)
                                               |                      |-- Crafting Stilt 1x1
                           Mud Channel [slime/spider] <-- Bog Hall    \-- Trial Hall 1x1 [trust]
                                               \--> Sump 1x1 [S] ---> Flooded Tunnels F2 side
Island Village -> one-way ladder drop -> Boardwalk (loop)
```
Recommendation: A for first build (clearest spine, altar outside the palisade, one extra edge via the drop); B if hostile-first approach should lead the player experience; C only if the Flooded link is wanted. Final attach slots are Sean's call [inf].

---

## Not found
A designer rationale for slowing or sinking terrain in a 2D platformer beyond Hornet Hole and Maridia; any designer account of a forest-to-marsh transition; any 2D metroidvania with species-dependent settlement hostility; Hollow Knight swamp-area designer commentary; Silksong or Dirtmouth hub analysis; BotW camp design talk.

---

## Sources
Read (fetched; summarised by a small model; thin pages marked):
1. https://www.gamedeveloper.com/design/the-invisible-hand-of-super-metroid [read]
2. https://www.mariowiki.com/Hornet_Hole_(Donkey_Kong_Country_2) [read]
3. https://www.mezunian.com/2020/05/08/great-stages-bramble-scramble-screechs-sprint-donkey-kong-country-2-diddys-kong-quest/ [read]
4. https://gamerwalkthroughs.com/ori-and-the-blind-forest/misty-woods/ [read]
5. https://www.gamedeveloper.com/design/a-spelunky-game-design-analysis---pt-2 [read, thin]
6. https://www.worldofleveldesign.com/categories/left4dead2_mapping/l4d2-visual-gameplay-reference-guide-campaign-design.php [read]
7. https://www.gamedeveloper.com/production/art-design-deep-dive-giving-back-colors-to-cryptic-worlds-in-i-dead-cells-i- [read]
8. https://terraria.wiki.gg/wiki/Jungle [read]
9. https://en.wikipedia.org/wiki/Will-o%27-the-wisp [read]
10. https://thenerdstash.com/top-5-reasons-why-the-mantis-lords-is-hollow-knights-best-boss/ [read]
11. https://rogueranker.com/mantis-lords-hollow-knight/ [read]
12. https://www.soldierfromthesurface.com/games/cavestory/ [read]
13. https://gmtk.substack.com/p/the-world-design-of-hollow-knight (Silksong article; only the palette quote used) [read]
14. https://terraria.wiki.gg/wiki/Housing [read]
15. https://terraria.wiki.gg/wiki/Goblin_Tinkerer [read]
16. https://terraria.wiki.gg/wiki/Goblin_Army [read]
17. https://www.architectureofzelda.com/monster-strongholds.html [read]
18. https://www.blog.radiator.debacle.us/2017/10/open-world-level-design-spatial.html [read]
19. https://book.leveldesignbook.com/studies/sp/undead-burg [read]
20. https://slickaria.blog/2020/09/30/analysis-random-design-tidbits-from-a-dark-souls-level-undead-burg/ [read]
21. https://en.uesp.net/wiki/Skyrim:Orc_Strongholds [read]
22. https://en.wikipedia.org/wiki/The_Legend_of_Zelda:_Majora%27s_Mask [read]
23. https://fromsoftwiki.org/wiki/DS1:Covenants [read]
24. https://steamcommunity.com/app/435150/discussions/0/1697168437881459851/ [read, player reports]
25. https://en.wikipedia.org/wiki/Hollow_Knight [read, thin: Dirtmouth sentence only]
26. https://en.wikipedia.org/wiki/Castlevania:_Order_of_Ecclesia [read, thin]

Repo files read: docs/research/area-level-design.md, docs/research/level-design-reference.md, scripts/world/room_def.gd, scripts/world/world_validator.gd (GATES line), scripts/movement/surface_step.gd and zip_step.gd (slick), grep over scripts, data and docs [repo].

Snippet only (search-result text; page not opened or host returned 403):
- https://www.anatomyofgames.com/2014/02/17/the-anatomy-of-super-metroid-13-mutual-of-omahas-maridia/ (403) and metroid wikis [snippet]
- https://www.zeldadungeon.net/wiki/Southern_Swamp (403) and zelda-archive Southern Swamp walkthrough [snippet]
- https://zeldawiki.wiki/wiki/Bokoblin_Mask (403), https://hardcoregamer.com/db/totk/bokoblin-mask-item-zelda-tears-of-the-kingdom/443077/ [snippet]
- https://hollowknight.wiki/w/Mantis_Village (403) and hollowknight.fandom.com Fog Canyon and Greenpath pages, steam threads on Fog Canyon [snippet]
- https://www.mariowiki.com/Bramble_Scramble_(Donkey_Kong_Country_2) [snippet]
- https://www.gamedeveloper.com/design/how-i-spelunky-i-s-designer-set-out-to-create-complexity-with-simplicity [snippet]; Spelunky dark-level fairness summary, original forum post not identified [snippet]
- https://minecraft.wiki/w/Swamp and https://minecraft.wiki/w/Biome (transition tints, fog) [snippet]
- https://hollowknightsilksong.wiki.fextralife.com/Songclave, https://hostedgg.com/wiki/silksong/bellhart, https://www.silksong.codes/en/guides/bone-bottom/ (Silksong hubs) [snippet]
- https://cavestory.fandom.com/wiki/Arthur's_House (Mimiga teleport hub) [snippet]
- https://gamefaqs.gamespot.com/xboxone/211254-ori-and-the-will-of-the-wisps/faqs/78217/wellspring-glades and the Ori fandom pages (Silent Woods tar) [snippet]
- https://www.pcgamesn.com/dark-souls-remastered/undead-burg-level-design-verticality [snippet]
- https://shapes.inc/fandom/dead-cells/biomes and ludoatlas Dead Cells biomes (Toxic Sewers tightness) [snippet]
- GDC 2017 "Change and Constant" BotW panel (named in a search summary) [snippet]
