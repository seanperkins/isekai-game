> Unedited agent notes. Where they conflict with `../area-level-design.md`, that document wins (for example: ledge spacing uses the repo's 54 px step, glow pools are not respawn points, and a forest-to-Grotto link is not planned).
> Correction (2026-10-04): the Deepnight article's "250 combat tiles, 1 monster per 5 tiles" is the author's invented example ("taking some random numbers"), not Dead Cells data. Ignore any Dead Cells monster-ratio figure in these notes.

# World-scale layout and multi-form gating: research notes

Tags: [read] fetched and read; [snippet] search-result summary only; [inf] my inference; [gap] searched, nothing found.
Where a fetch tool summarized a page, numbers marked "exact" were re-fetched and quoted verbatim; others are as the summary gave them.
Game constants used below: room = 1-3 screens of 640x360; 4 areas of 5-6 rooms; one altar per area; species change only by dying.

## 1. Whole-map shape (hubs, chains, loops, attachment, fast travel)

### 1a. Theory: mission vs space, cycles
- Dormans 2010: a level is two structures, "mission" (ordered tasks) and "space" (rooms and connections); mission and space are independent, "the same mission can be mapped to many different spaces". [read] (Dormans 2010 PDF)
- Dormans 2010, the warning that matches our chain: "a non-linear mission featuring many parallel challenges and alternative options, can be mapped on to a strictly linear space, resulting in the player having to travel back and forth a lot." [read]
- Dormans 2010, Forest Temple: "basic layout follows a hub-and-spoke layout that provides easy access to many parts of the temple. The boomerang acts as key to many locks that can be encountered right from the beginning. Once it is obtained extra rooms in the temple are unlocked". One key, many pre-seen locks. [read]
- Dormans 2010: the mission has a threshold guardian before "the realm of adventure", a mid-level boss that gives the key item at "around halfway or two-thirds", then a level boss. Grammar rule 1 enforces a minimum length ("a dungeon needs to have a minimal length to be interesting at all"). [read]
- Dormans 2010: generator step "ensure that the growing space actually reconnects to previously generated parts" (adds loops), but open connections are closed off "to prevent short circuiting the mission, by accidently connecting the final room to a room near the entrance". Loops are added on purpose and capped so they cannot skip the spine. [read]
- Unexplored/cyclic generation: a cycle is two paths between start and goal; dungeons average "a couple of embedded cycles"; new sections are inserted "into the existing cycle" (a shortcut, a room of traps) rather than bolted on beside it. [read] (Game Developer, Unexplored)
- Unexplored locking pattern: player takes path A, meets a locked door, takes path B, finds the key, returns to A. Locks can be permanent or temporary; keys can be non-literal ("an enemy and the key is a weapon, or the lock is a pit of lava"). [read] (Game Developer, Unexplored)
- Boris the Brave: "Unexplored has 24 different cycle types" (exact); the generator "draws a large circular loop, with a entrance and goal node attached" (exact), splitting it into "two independent arcs"; "Minor cycles, are short detours from the main cycle that can be added, often including more keys and obstacles" (exact). [read]
- Boris the Brave: cycle types "only control the main flow of the dungeon, and specify very little about specific forks, layout or details" -> cycles are a flow-level tool, usable at world scale. The world-scale use is my extrapolation. [read] + [inf]
- Boris the Brave: "Hubs ... have the entire loop easy to navigate, but lock the actual exit behind some sort of challenge." [read]
- Dicegoblin lists "12 cycles" but that is Sersa Victory's tabletop adaptation, not Unexplored's 24. Named cycle patterns: lock-and-key ("show the players a locked door, and have them return later with a key"), foreshadowing loop ("first tease the actual goal"), hidden shortcut. [read]
- Metroidvania pacing writeups: start linear, then open; difficulty of exploration measured by "how many available directions a player has to choose from"; "show locks before providing keys". [read] (Bimmel)
- Subtractive Design pt 7 and 12: make sure the player "immediately see[s] an area that requires the use of an ability they don't have yet", and "tease an even more distant future ability" to motivate a return. Pt 18-19: "The levels should be built to reveal shortcuts upon gaining new abilities. This doesn't just happen by accident. You have to intend it." [read]

### 1b. Shipped maps
- Super Metroid: Crateria is the hub, the player "returns after completing the first act, creating a 'full circle' moment". Act 1 is a linear funnel (stone wall, then Brinstar's "shaft of no return": "the shaft is several screens high and populated with invincible flying bugs. There is simply no hope of returning"). Act 2 opens the world after Kraid + Varia Suit. Act 3 is vertical progression. [read] (Invisible Hand of Super Metroid)
- Super Metroid foreshadowing: one glass tunnel is "the only part of Maridia we will see for most of the game"; the Statue Room shows four boss silhouettes and "will become the gateway to the final area"; map rooms reveal different amounts. A yellow door in central Brinstar reveals a shortcut to the first Morph Ball room: "everything is connected". [read]
- Super Metroid: Norfair "remains largely inaccessible until heat protection is acquired" (Varia Suit). Heat gating of a fire area is a real precedent. [read]
- Dark Souls 1: Firelink is a "true hub" with paths "like roots spiraling out of it"; loops ("Circling through Darkroot Garden lets you skip the first area, putting you smack bang in the Undead Parish which has an elevator leading right back down to Firelink Shrine"); Blighttown "can be seen from Firelink Shrine itself". [read] (TheGamer)
- Dark Souls 1, same article: early routes differ by starting gift (Catacombs, New Londo, Darkroot Garden, Blighttown as listed in the article). A start-choice that changes the first route. [read]
- Dark Souls: loops are deliberate: "a path that could be reached in a straight line is forcibly made into a circle". [snippet] (Medium search summary)
- Hollow Knight: "several large, interconnected areas with unique themes", player starts in Dirtmouth "just above the remains" of Hallownest; Stag Stations are "progressively-unlocked" fast travel; "The complexity of the world was based on Metroid". [read] (Wikipedia)
- Hollow Knight: Ari Gibson: "It's a specific kind of lock-and-key type of progression, and we try to submerge that element in favour of a more naturalistic world." Team Cherry plan area by area ("we'll decide what area we're working on that month"). [read] (ACMI)
- Hollow Knight: designers say they "chipped away at a lot of the hard gating", power-ups ended up optional, speedrunners finish with few. [snippet]
- Hollow Knight: the Crossroads is the spoke centre, six regions branch from it (Greenpath, Crystal Peak, Fungal Wastes, Resting Grounds, Ancient Basin via tram); Hot Spring bench 4 rooms from the False Knight arena. [snippet] (guide-site summaries)
- Silksong: "a twisty, maze-like land with 12 distinctly different areas" (exact); Act 1 is "a giant U-bend through Pharloom" (exact), Act 1 climbs, Act 3 descends into the Abyss. [read] (GMTK)
- Silksong: "each key only opens a few locks" (exact) versus Cling Grip: "this one key lets us open up a lot of different locks" (exact). Key breadth is a design variable. [read]
- Silksong: "Silksong almost never asks you to backtrack" (exact) for the critical path, but backtracking is rewarded (Clawline reaches Sands of Karak plus a mask shard back in Far Fields). [read]
- Silksong sequence breaks: Flea Caravan relocation, a 500-rosary key skipping Lace, Wormways route skipping Lace, Drifter's Cloak, Fourth Chorus and Moorwing, a Sinner's Road route skipping The Last Judge. [read]
- Silksong: "I counted more than 50 across the map" (exact) secret walls; Bilewater and Putrified Ducts hidden so "it's entirely possible to play the entire game without ever knowing" (page summary). Hidden places stay off the map until found. [read]
- Silksong: Act 2 (Citadel) "feels self contained and disconnected", "there are separate fast travel systems, with the Bell Beast in Pharloom, and pneumatic elevators in the Citadel" (exact), with only one connection between the two (page summary). A bridging pair of hubs. [read]
- Blasphemous: map is district > zone > scene. Early areas are linear; the first real branch is three choices, two valid paths (page summary). "we don't want players to backtrack or explore areas if they don't want to." [read] (Game Developer)
- Blasphemous: "checkpoints ... were placed so that there was roughly one per area and never more than seven screens apart." (exact) Reusable shortcuts: "teleports and elevators"; one-time: levers, breakable glass cases. [read]
- Dead Cells: "The overall design of the map of the island, how the different levels are interconnected, where the keys to unlock new paths for your future runs are located etc. All of this never changes." Rooms are random inside a level; the world graph is fixed. Closest match to a fixed world with persistent unlocks. [read] (Game Developer mirror + deepnight)
- Dead Cells: each biome has its own "concept graph" (length, special tiles, labyrinth share, entrance-to-exit distance); ramparts "much more straightforward and linear than the sewers", sewers "very tight". Per-area flow shape varies on purpose. [read]
- Animal Well: 16x16 grid of flip-screen rooms "connected together in a labyrinth with multiple obvious and hidden connections"; about three times as many rooms were designed as shipped. [read] (Wikipedia). The "at least 500 cut" figure is from a headline only. [snippet] (GamesRadar)
- Portrait of Ruin: Dracula's Castle is the hub with four painting portals to thematically distinct outdoor/other areas; designers "had grown weary of creating indoor stages and elected to incorporate outdoor settings". [read] (Wikipedia)
- Ori (Definitive Edition): added "fast travel between spirit wells" and "full backtracking" after criticism of restricted re-entry. [read] (Wikipedia)
- Metroid Dread: nine areas; teleporters point you at where your newest upgrade works; "exploring is a horizontal activity while navigating is often a vertical one". [snippet] (search summaries of the GMTK Dread analysis; page itself blocked)
- Carrion deliberately rejects hub-and-spoke: "Once you enter a new area, it's locked off, and you are restricted to this contained area you have to work through." [read] (Game Developer)

### 1c. Attaching a new area to a built graph
- Guacamelee DLC (El Infierno): attached through "a sixth Chac Mool doorway in the Desierto Caliente that had been blocked off by a cave-in"; designer Jason Canam: "the DLC level must not disrupt the game's overall progression path"; optional, "main game is the primer, and El Infierno is the final exam"; 17 rooms. [read] (Game Developer)
- Unexplored: the insertion unit is a cycle node in an existing cycle, not an appended branch (see 1a). [read]
- Portrait of Ruin: new environments sit behind portals inside the existing hub rather than in the hub's own geometry. [read]
- Cave Story's first area gives "two paths, one of which is blocked off until retrieving an item from the other path". The smallest cycle, used as a tutorial. [read] (Wikipedia)

### 1d. Fast travel and shortcuts
- Genre baseline: new abilities "can also open up shortcuts that reduce travel time"; larger games add warps "eliminating tedious backtracking in the later parts of the game". [read] (Wikipedia Metroidvania)
- Majora's Mask: owl statues "provide warp points" (Song of Soaring). Monster Boy: "fast travel teleporters" appear as the game goes. Blasphemous: teleports/elevators. Hollow Knight: Stag. Silksong: Bell Beast, then elevators. Ori DE: spirit wells. [read] (respective Wikipedia and GMTK pages)

### 1e. Sizes and shape
- Region size in rooms: only Blasphemous gives a spacing figure (a checkpoint every <= 7 screens, ~1 per area); Animal Well 256 rooms total (16x16); Dead Cells one example "250 combat tiles" in a sewers level. No source gives rooms-per-region for Hollow Knight, Super Metroid or Ori. [gap]
- Vertical vs horizontal: Silksong Act 1 goal is "up", Act 3 is "down" (reversal as a pacing device); Super Metroid act 3 is vertical; Ori's Ginso Tree is a long vertical ascent. [read] (GMTK; Invisible Hand) / [snippet] (Ginso)
- Effect of shape on pacing, as a measured claim from a designer: [gap]. My reading: a vertical segment between two horizontal chains works as a threshold ("shaft of no return"). [inf]

## 2. Area ordering and difficulty ramp

- Trope evidence only (TV Tropes pages returned 403 twice, so this is search-result text): Zelda games usually put the forest dungeon first as "least hazardous", then fire in rugged mountains, then water, ice later; Green Hill style grassland is "often the first level"; ice worlds come "relatively late ... after regular natural levels ... before the truly unnatural". [snippet] (TV Tropes: Sorting Algorithm of Threatening Geography)
- Mega Man X stage interaction (beat the ice stage, fire stage's lava freezes): a fire/ice pair as a cross-area link. [snippet]
- Designer rationale for forest -> cave -> fire ordering from an actual designer or postmortem: [gap]. Survival-game biome guides say danger and loot rise with distance from spawn. [snippet] (Valheim guides; not a metroidvania)
- Wikipedia Level (video games): first level teaches mechanics (World 1-1), levels get "progressively increasing difficulty". Nothing on themes. [read]
- Cave Story: starts in a settlement, unlocks areas as weapons level, "The surface and escape mechanisms arrive in the final acts" (Sky Dragon, rocket). Outdoor/surface as the closing reward. [read] (Wikipedia)
- Silksong: the Citadel is "at the very top of Pharloom" and Act 1 is the climb to it (surface/height as destination), then Act 3 inverts. [read] (GMTK)
- Surface as start/hub: Hollow Knight (Dirtmouth above the kingdom), Super Metroid (Crateria is the hub and the full-circle return), Dark Souls (Firelink). [read]
- Surface as pacing relief: Portrait of Ruin's outdoor paintings exist because designers tired of indoor stages. Cave Story themes each zone with one mood ("warmth", "arid and oppressive"). [read]
- Fire late: Super Metroid's Norfair is lava-heavy and needs the Varia Suit; Ori's Mount Horu is a volcano reached late-game. [read] (Invisible Hand; Wikipedia Ori)
- Fire gating by an item/trait, not just distance: Norfair (heat suit) [read]. For us the analogue would be a species or skill trait. [inf]
- Dead Cells varies flow per biome: straightforward ramparts versus tight sewers. A new area can differ in shape, not just art. [read]
- Options with evidence, no recommendation made: (a) forest as a new start/hub above the cave (Dirtmouth, Crateria, Firelink); (b) forest as a late reward (Cave Story surface ending, Silksong's climb); (c) forest as a side branch behind a species gate (Dead Cells runes, Guacamelee door). Fire either deepest (Norfair, Mount Horu) or behind a heat gate. [inf]

## 3. Multi-form / transformation gating

### 3a. Precedents (form -> route mapping, switching cost)
- Wonder Boy III: Dragon's Trap: forms are earned by defeating dragons: Lizard-Man (fire), Mouse-Man ("walk on walls and ceilings designated by checkered 'mouse blocks'"), Piranha-Man (swim, water-only places), Lion-Man (vertical slash, hits targets others cannot), Hawk-Man (flies, hurt by water). Gating rule as the page summary puts it: "Different forms unlock specific world areas". [read] (Wikipedia)
- Dragon's Trap tile language: mouse blocks are a visible, form-specific surface; the lane marker is on the level, not in a menu. [read] (Wikipedia) / [inf] (reading it as a design rule)
- Dragon's Trap hub and respawn: death "will throw you back to the main hub town so you often don't need to do a tremendous amount of backtracking"; "secret doors" later let you cycle forms. (This source garbles the form list, so only these two claims are used.) [read] (gaminghistory101)
- Dragon's Trap player comments: form switching gets better later ("a 'secret' weapon that lets you change forms at will towards the very end"); "the transformations ... are the real star of the show". Forum opinion, not a designer. [read] (ResetEra)
- Dragon's Trap "environments let players get just far enough to realize they need another transformation". [snippet]
- Shantae: Risky's Revenge: dance transformations cost magic and are keys: monkey ("cling onto certain surfaces and dash between walls"), elephant ("smash rocks"), mermaid (swim), plus spider and harpy; Scuttle Town hub; reviewers criticised the map. [read] (Wikipedia)
- Portrait of Ruin: two characters, "freely switch ... at any time"; some parts need both ("combined abilities are needed"); critic: easy to control but "awkward during puzzle solving". [read] (Wikipedia)
- Monster Boy: five forms (pig, snake, frog, lion, dragon), switch "at will once obtained", teleporters added to cut backtracking. [read] (Wikipedia)
- Biomorph: forms were first limited to the room the monster was in; after reconsidering they "made sure that you could be any monster everywhere. It was a tremendous effort to pull this off." Base kit kept: "the player still feels like Harlo, just transformed. He can still dodge and wall jump." Biome built from a "recipe" with a theme and main feature. [read] (Gamerant interview)
- Carrion: abilities locked to sizes ("mass-based class system"); speed is a level-design problem: "it's a matter of seconds to go from the beginning of the map to the end, if there are no obstacles." Shed biomass at designated spots (search summary). [read] (Game Developer) / [snippet] (deposit spots)
- Majora's Mask: three transformation masks gate areas ("some areas can only be accessed by use of these abilities"). Across the reset Link keeps "weapons, equipment, masks, learned songs, and proof of dungeon completion"; quests and NPC states reset; a notebook tracks NPC schedules. [read] (Wikipedia)
- Majora's Mask: the cycle was cut from seven days to three because a week was "too burdensome for players to remember"; the same fear applies to us if too many pending gates must be held in memory. [read] (Wikipedia) / [inf] (application)
- Dead Cells runes: permanent unlocks make blocked paths usable on later runs: "That hole in the ground you saw in your previous run? You can now use it to grow a vine and access a new location." Rune rooms need a boss/elite (search summary). [read] (MCV) / [snippet] (wiki summary)
- Rogue Legacy: each death you pick an heir from random traits (dwarfism "can fit into small gaps"), a body choice that changes traversal; class unlocks and manor upgrades persist; layout is random but the architect can "lock down the design of a previously encountered castle ... in exchange for a percentage of any gold found". [read] (Wikipedia)
- Rogue Legacy 2: "Heirlooms, which are permanent ability upgrades that are hidden in special rooms" persist; dungeons procedural; traits "may either enhance or hinder combat efficiency". No page says traits gate routes. [read] (Wikipedia) / [gap] (trait -> route)
- Guacamelee: colour-coded obstacles removed by earned powers, dimension swap mid-jump. [snippet]
- Animal Well: items serve multiple uses; "Portions of the game world can only be accessed by using specific items". Three player layers (core puzzle platformer; secrets; community mysteries) per Basso. [read] (Wikipedia) / [snippet] (three layers quote)
- Direct precedent for "die and come back as X, species fixed per life, one fixed world": none found. Closest are Rogue Legacy (body per life), Dead Cells (fixed world, persistent keys), Majora's Mask (reset with persistent masks), Dragon's Trap (death to hub). [gap]

### 3b. How designers keep swapping tolerable
- Free swap anywhere (Portrait of Ruin, Monster Boy) or small resource cost (Shantae magic). [read]
- Swap at stations or by secret doors (Dragon's Trap, Carrion deposit spots). [read]/[snippet]
- Persistence of earned form across the world (Biomorph reversal, Majora's masks). [read]
- Fast travel/warp to shorten the "go back" leg (owl statues, Monster Boy teleporters, Blasphemous teleports). [read]
- Death returns you to a hub rather than the far start (Dragon's Trap). [read]
- Make the gate visible before the key exists (Dead Cells hole, Super Metroid glass tunnel, Dormans Forest Temple locks). [read]

### 3c. Lanes, parallel routes, completable base route
- One-form lanes: Dragon's Trap mouse blocks, Shantae monkey surfaces, Monster Boy frog hoops. [read]
- Parallel routes per choice: Silksong Clawline "two very different ways to reach it" (page summary); Blasphemous first branch has two valid paths; Dark Souls starting-gift routes. [read]
- Base route completable: Hollow Knight power-ups ended up optional [snippet]; Silksong "possible to play the entire game without ever knowing" some places [read]; Guacamelee DLC optional and ordered to earned abilities [read]; Biomorph keeps dodge and wall jump in every form [read]; Silksong sequence breaks [read].
- Soft gates with several solutions are a defended design choice ("a locked door might be openable via pressure pads, burning vines, shattering glass"). [read] (afewbitsshort)

## 4. Design rules for this game (all [inf])

Numbers marked (placeholder) are mine and unsourced.

1. Attach each new area into an existing loop, not on the end of the chain: pick an existing connector (blocked doorway, floor hole, ledge chain), make it the seam, and add the second connection later. Source: Unexplored insertion rule; Guacamelee El Infierno door. Check: new area's graph has >= 2 edges to existing rooms once its shortcut is open. [inf]
2. No new area may become required for the base-jump main route unless it sits on the spine; every species verb in the new areas only opens side rooms, shortcuts or rare rooms. Source: Guacamelee DLC "must not disrupt ... progression path"; Biomorph base kit; Silksong secret areas. Check: pathfinder with base jump only reaches the final room. [inf]
3. Cap travel between rest points at 7 screens: any path from altar/rest pool to the next must be <= 7 screens (4480 px of horizontal screens equivalent); new areas keep one altar plus >= 1 rest pool. Source: Blasphemous "never more than seven screens apart". Check: path-length script over the room graph. [inf]
4. Start narrow: at game start <= 2 open exits from room 1; open the graph only after the first area boss/skill. Source: Super Metroid act 1 funnel; Bimmel "how many available directions"; Blasphemous early linearity. [inf]
5. One-way back-door: every new area gets a return shortcut that opens a loop to an earlier hub; shortcuts persist after death. Source: Dark Souls Firelink loops; Metroidvania shortcut tenet; Dead Cells fixed keys. Check: each area has an openable one-way-ledge edge to an earlier area. [inf]
6. Every species gate must be seen before it is usable: place it on, or one room off, the main route, so a player passes it before they reach the altar of the area that holds it. Source: Super Metroid glass tunnel and statues; Dead Cells "hole in the ground you saw"; Dormans Forest Temple locks "right from the beginning"; Subtractive pts 7 and 12. Check: gate room is within 1 room of the spine. [inf]
7. Cluster gates so one "die and come back as X" run clears many: >= 2 gates per species within one area or two adjacent areas, plus the reward chain. Source: Silksong "each key only opens a few locks" versus Cling Grip; Rogue Legacy cost of a new body. Check: count gates per species per area-neighbourhood >= 2 (placeholder). [inf]
8. Every species-gated reward is persistent: it opens a shortcut toward room 1 or an altar, or flips a permanent unlock; never a one-shot pickup lost by dying. Source: Dead Cells runes; Majora's persistent masks and dungeon proof; Dark Souls shortcuts. Check: each gated reward writes a save flag that appears in the opened-shortcut list. [inf]
9. Each species verb gets one visible tile marker used only for its lane (like mouse blocks). Source: Dragon's Trap. Check: every gate room has exactly one species marker and no unmarked species-only route. [inf]
10. Every area has >= 1 lane for >= 2 different species (parallel routes), and no species is lane-less in any area. Source: Dark Souls starting-gift routes; Silksong Clawline two routes; Blasphemous parallel branches. Check: table area x species. [inf]
11. Map auto-marks a seen species gate with the required species glyph so the player need not remember. Source: Majora's notebook; Silksong map-poking; Aonuma 7-to-3 days cut. Check: gate-seen event creates a map pin. [inf]
12. Cap pending gates in memory: at most 3 unsolved species gates per species visible on the map at once (placeholder). Source: Majora's "too burdensome to remember". [inf]
13. Return trips pay: any room on a gate's return route has a reward, shortcut, or rest point; rooms with neither get locked or bypassed. Source: Bimmel "every revisitable area ... advance story or unlock mechanics; otherwise lock or bypass"; Subtractive "backtracking to have a purpose". [inf]
14. Fast-travel step: after the third area opens, unlocked altars can warp between each other; warp keeps only persistent shortcuts, nothing else. Source: Owl statues, Stag Stations, Bell Beast, Ori spirit wells, Blasphemous teleports, Monster Boy. Check: altar list has a `warp_unlocked` flag per altar. [inf]
15. One threshold room per new area entrance with a vista of the next zone and a rest point within 7 screens; for the volcano a visible glow in the area before it. Source: Dormans threshold guardian; Dark Souls Blighttown vista; Super Metroid statue room. Check: tag a `threshold` room per area. [inf]
16. Reverse the direction once: if the cave goes down-and-right, the forest should attach going up (surface), and one later segment should invert the direction. Source: Silksong U-bend and Act 3 descent. [inf]
17. Size rooms for the fastest kit: wolf gallop and spider zip must not cross a room in "a matter of seconds", so combine long rooms, hazards, or a lane-only variant. Source: Carrion's speed problem. Check: traversal time per room for each species >= placeholder seconds. [inf]
18. Heat/fire areas are gated by a trait or earned verb, not only by distance. Source: Norfair/Varia Suit; Mount Horu late. Check: volcano entry gate tagged with a species or skill id. [inf]
19. Keep sequence breaks possible but not required: hidden skips on side rooms, never on the spine. Source: Silksong skip routes and secret walls; afewbitsshort soft gates. [inf]
20. Species change cost is a feature, not a toll: gate rewards that justify a death should be visible, immediate, and persistent; do not add a second tax such as lost map progress. Source: Rogue Legacy lock-castle cost, Dead Cells persistent keys, Dragon's Trap hub respawn. [inf]

## Sources

[read] https://pcgworkshop.com/archive/dormans2010adventures.pdf (Dormans 2010; read via pdftotext of the fetched PDF)
[read] https://www.gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation-
[read] https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/
[read] https://dicegoblin.blog/making-meaningful-dungeons-with-cyclic-dungeon-generation/
[read] https://gmtk.substack.com/p/the-world-design-of-hollow-knight (Silksong analysis, Mark Brown)
[read] https://www.gamedeveloper.com/design/the-invisible-hand-of-super-metroid
[read] https://www.gamedeveloper.com/design/how-i-blasphemous-i-level-design-iterates-on-classic-metroidvanias
[read] https://www.thegamer.com/dark-souls-1-fromsoftwares-magnum-opus-of-interconnected-level-design/
[read] https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-
[read] https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/
[read] https://mcvuk.com/development-news/when-we-made-dead-cells/
[read] https://www.gamedeveloper.com/design/carrion-game-level-designer-krzysztof-chomicki-on-managing-amorphousness-gravity-and-screams
[read] https://www.gamedeveloper.com/design/building-a-house-for-the-devil---designing-guacamelee-s-dlc
[read] https://gamerant.com/biomorph-interview-kirby-inspirations-metroidvania-difficulty-indies/
[read] https://en.wikipedia.org/wiki/Wonder_Boy_III:_The_Dragon's_Trap
[read] https://www.resetera.com/threads/lttp-wonder-boy-and-the-dragons-trap-transformation-station.119178/
[read] https://gaminghistory101.com/2018/12/11/wonder-boy-retrospective-pt-4/ (form list in this source is wrong; used only for hub respawn and secret doors)
[read] https://en.wikipedia.org/wiki/The_Legend_of_Zelda:_Majora%27s_Mask
[read] https://www.zeldadungeon.net/aonuma-talks-more-about-the-three-day-cycle-of-mm/
[read] https://en.wikipedia.org/wiki/Castlevania:_Portrait_of_Ruin
[read] https://en.wikipedia.org/wiki/Shantae:_Risky%27s_Revenge
[read] https://en.wikipedia.org/wiki/Rogue_Legacy
[read] https://en.wikipedia.org/wiki/Rogue_Legacy_2
[read] https://en.wikipedia.org/wiki/Monster_Boy_and_the_Cursed_Kingdom
[read] https://en.wikipedia.org/wiki/Metroidvania
[read] https://en.wikipedia.org/wiki/Hollow_Knight
[read] https://www.acmi.net.au/stories-and-ideas/from-ludum-dare-to-pharloom/
[read] https://www.gamedeveloper.com/design/how-the-i-hollow-knight-i-devs-mapped-out-their-metroidvania- (teaser only, no area detail)
[read] https://en.wikipedia.org/wiki/Ori_and_the_Blind_Forest
[read] https://en.wikipedia.org/wiki/Cave_Story
[read] https://en.wikipedia.org/wiki/Animal_Well
[read] https://rubenbimmel.itch.io/metroidvania-pacing-chart/devlog/87273/the-pacing-of-metroidvania-games
[read] https://nikles.it/2016/game-design/metroidvania-metroid-like-world-design/ (thin: a 5-zone example)
[read] https://afewbitsshort.com/metroidvania-sequence-breaking-by-design/
[read] http://subtractivedesign.blogspot.com/2013/01/guide-to-making-metroidvania-style_16.html
[read] https://en.wikipedia.org/wiki/Level_(video_games) (no theme-order content)
[read] https://en.wikipedia.org/wiki/Metroid_Dread (thin: no area count or teleporter detail)

[snippet] https://tvtropes.org/pmwiki/pmwiki.php/Main/SortingAlgorithmOfThreateningGeography (403 on fetch; search text only)
[snippet] https://tvtropes.org/pmwiki/pmwiki.php/Main/LethalLavaLand (403 on fetch)
[snippet] https://www.pcgamer.com/how-to-design-a-great-metroidvania-map/ (fetch returned only page chrome)
[snippet] http://blog.mechanicalmonolithgames.com/2021/11/design-lessons-metroid-dread.html (socket closed on 3 tries)
[snippet] https://famiboards.com/threads/mark-brown-presents-metroid-dread-boss-keys-or-why-you-didnt-get-lost-in-metroid-dread.730/ (403)
[snippet] https://www.gamesradar.com/games/platformer/solo-dev-behind-breakout-metroidvania-hit-animal-well-says-his-game-has-256-encounters-but-he-had-to-cut-at-least-500-of-them-during-development/ (headline only)
[snippet] https://thinkygames.com/features/interview-how-animal-well-is-using-secrets-and-mysteries-to-be-a-different-kind-of-metroidvania/ (403; Basso "three layers" quote from search text)
[snippet] https://www.hallownest.net/mapping-stats/ (403)
[snippet] https://thomaswell.medium.com/what-can-hollow-knight-and-metroid-learn-from-each-other-5550601d1c12 (403)
[snippet] https://techraptor.net/gaming/reviews/wonder-boy-dragons-trap-review-all-grown-up (403)
[snippet] https://www.ausgamers.com/features/read/3628197 (maintenance page)
[snippet] https://www.gamesradar.com/blasphemous-2-has-the-best-interconnected-map-ive-seen-since-dark-souls/ (truncated)
[snippet] https://deadcells.wiki.gg/wiki/Runes_and_upgrades and https://holdtoreset.com/hollow-knight-forgotten-crossroads-guide/ (search text only)
[snippet] https://en.wikipedia.org/wiki/Biomorph_(video_game) (fetched; no form or level-design content, not cited for anything)
