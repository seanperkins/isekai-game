> Unedited agent notes. Where they conflict with `../area-level-design.md`, that document wins.

# Traps research for Isekai Chronicles (level traps and player/creature-laid traps)

Tags: [read: name] fetched and read (WebFetch summarised by a small model; no quote below was re-fetched verbatim, so treat quoted phrases as the summary's words, not the page's). [snippet] search-result text only (page not opened, or fetch failed). [inf: source] my inference, source named. [gap] searched, nothing found. [repo] read in this repo. A number marked *placeholder* is mine, unsourced, for tuning. WebSearch budget ran out partway; Cave Story, Castlevania, Rain World and Weaversong were not searched (see Gaps).

Not repeated (already in `docs/research/area-level-design.md` and `notes/volcano.md`) [repo]: Dark Souls 3 attack signal of at least 340 ms (about 21 frames at 60 fps); lava lethality and DoT-plus-knockback rule; hazard-budget placeholders; seed-leak problem for fire gates; Shovel Knight "no unitaskers"; spider walks over every floor hazard because of the generated 20 px ceiling.

---

## 1. Taxonomy of level traps, grouped by what they test

A trap is two parts. "A trap is not a single component. It actually consists of two things: a trigger and a hazard." Trigger attributes: visibility, avoidability, timing, cooldown, delay, activation duration, reversibility. Optional extensions: distraction, complication, pressing need, tool, puzzle. [read: Ludomotion]

**TIMING (rhythm; the trap is always on a clock and the player waits or hurries)**
- Arrow, dart and blow-pipe launchers. Terraria Dart Trap: cooldown "200 ticks (3.33 seconds)", damage 40 classic and 80 Expert, darts fly at 45 tiles/s, poisoned; stone-head art "similar to Indiana Jones imagery" [read: Terraria Dart Trap]. Spelunky 2 arrow trap: range 6 tiles, 24 blocks/s, damage 2 (3 when flaming in dark levels) [snippet: spelunky.fandom Arrow Trap (2), fetch 402]. An indie devlog arrow trap fires one arrow per 1.5 s [snippet: sawtop devlog].
- Fire jets, geysers, eruptions: telegraph by shake plus sound (Toto Temple) [repo, volcano.md]. No cycle times found [gap].
- Chompers, guillotines, swinging blades, pendulums, saw launchers, spinning axes. Prince of Persia (PoP) chompers: "requires you to be very comfortable with the timing of the chompers" [read: awweide PoP]. Sen's Fortress has swinging axe blades on catwalks [read: PCGamesN]. Dead Cells lists sawblade launchers, spinning axe traps, spiked flails, log traps, electric waves [read: Dead Cells Hazards].
- Collapsing and crumbling floors, falling platforms: Celeste crumble blocks give "a second" before you fall with them and respawn after "a few seconds"; falling blocks wobble, then fall, and return only if you die or leave [snippet: neoseeker/celestegame fandom]. Dead Cells mechanised platforms drop "after a slight delay" [read: Dead Cells Hazards]. Mario Wiki gives no timings [repo, volcano.md].
- Disappearing platforms with a visible rhythm; Mega Man layers them with an enemy, so timing plus attention [read: Level Design Patterns].
- Crushers and falling blocks: Dead Cells Crusher "slows down then violently crushes" [read: Dead Cells Deployable traps]; Zelda Shadow Temple falling spikes "periodically fall", cost one heart and reset the room, with a sign hinting at the counter [snippet: zeldadungeon]. No fall delays found [gap].

**OBSERVATION (read the room before you act; the trap is a visible puzzle)**
- Spikes: instant death in PoP and VVVVVV [read: Monochroma]; PoP spikes kill if you drop or jump onto them, not if you walk in [snippet: TV Tropes via search]. Celeste's spike hurtbox is 2 px shorter than the wall hitbox [snippet: celeste.ink via search]. Dead Cells: spikes are the commonest hazard, static, on floors, walls and ceilings, damage capped "at 30% of the player's HP per hit" [read: Dead Cells Hazards].
- Pits, trapdoors, deep drops: PoP's three killers are spikes, pits of three or more levels, and guillotines [read: Wikipedia PoP]. Classic screens use "high edges and cliffs as pit traps" [read: Monochroma].
- Loose floor tiles: PoP Level 4 and 6 use a falling tile to land on a pressure plate and hold a portcullis open [snippet: search summary of a PoP analysis]. Mechner "was asking himself how he could recombine falling floors and pressure plates in a way that was different" from the ten earlier times [snippet].
- Poison gas and tipped darts: Terraria dart traps apply Poisoned [read: Terraria Dart Trap]. Gas-vent timings [gap].
- Pressure plates and tripwires: Terraria natural traps are wired to plates, some far from the trap, red and green plates fire from enemy contact, player-only plates exist [read: Terraria Traps; Terraria Pressure Plates]. PoP plates open portcullises that slip shut after a few seconds [snippet].

**MEMORY / SEQUENCE (the trap stack is learnt across deaths)**
- Sen's Fortress "trap road": pendulums and rolling boulders "were all there from the start"; no bonfire mid-fortress, so a death restarts the gauntlet [read: soulslore Design Works; PCGamesN]. Spelunky relies on repeated runs: "there's only one way to find anything out: the hard way" [read: Fairness, Discovery & Spelunky].
- PoP: 60-minute limit, restart at the start of the level, timer keeps running [read: Wikipedia PoP].

**SPEED / ROUTE (escape the trap, or pick a route through it)**
- Rolling boulder: Derek Yu wanted players to "play out some of those scenes from Indiana Jones" [snippet: search summary]; Wikipedia credits Indiana Jones as an influence [read: Wikipedia Spelunky]. Sen's boulders come down stairs with worn, rounded steps as the cue [read: PCGamesN].
- Rising lava and chases: volcano.md [repo].
- Ambush rooms, monster closets, sealing doors: closets are walls that lower; the entrance can't be opened from inside; arenas "usually don't release monsters until the player is locked in" [snippet: ZDoom/Doomworld results; ZDoom fetch hung]. Zelda barred doors seal until the room is cleared [snippet].

**ROUTE CHOICE / GREED (the cost is hidden in the reward)**
- Mimics and fake chests. A fair "cursed container" has a visible bounded container, a reward above baseline loot, and a cost the player can read through colour and material, sound, environmental storytelling and UI friction; "if players cannot read the risk, the mechanic is no longer a decision" [read: yaninagames; last clause also seen as a search snippet]. Sen's Fortress mimic chest is cited as unfair [read: PCGamesN]. D&D origin of the mimic [snippet: Wikipedia, not opened].
- Terraria Dead Man's Chests combine several traps; trapped chests are player-made only [read: Terraria Traps].
- Guarded treasure and trap density: classic D&D stocking is one-sixth of rooms traps or tricks [snippet: OSE SRD result; fetch 500].

---

## 2. Fairness and telegraphing

**The core rules**
- "The trigger may be invisible or the hazard may be invisible, but they cannot be both." [read: Ludomotion] Same shape: "At least one of these three components must be observable to the naked eye without a dice roll" (trigger, mechanism, payload); a gotcha trap breeds "tedious paranoia" [read: Kate Plays].
- Spelunky: "Arrow traps can always be spotted ahead of time, and you can nearly always avoid them or trigger them with an object." Unfair means consequences out of proportion, or a penalty from circumstances outside the player's control [read: Fairness, Discovery & Spelunky]. The same series calls arrow traps "extremely cheap in dark levels", where "you can't see the trap coming" [read: Spelunky Analysis Pt 2].
- A trap needs an answer: "if you are still alive, a solution exists"; a death from experimenting is acceptable "at least the first time" [read: Monochroma]. Use traps that "are not beyond the scope of the mechanics" [snippet].
- Telegraph needs a pre-attack delay so the hit is "not because they didn't know what they were being asked to do" [read: Game Developer Enemy Attacks and Telegraphing; the page has no numbers].
- Visual cues in the world: scuff marks, missing dust, draught from a crack, a ticking sound, the dead adventurer [read: Kate Plays]. Sen's designers "tried hard to make them obvious and create things that screamed trap"; Miyazaki doubted anyone would catch the worn steps on a first pass [read: soulslore Design Works]. Dead Cells: pressure spikes "shine briefly, as if to explode", and carnivorous plants got "a yellow indicator warning before ... bites" in 1.8 [read: Dead Cells Hazards].
- Safe zones and foreshadowing: the Zelda dungeon doorway is a safe zone; a hazard is introduced "under a controlled environment" before it matters [read: Level Design Patterns].

**When a hidden or lethal first exposure is acceptable**
- Spelunky: the starting area's arrow traps stayed lethal because "death and failure is an expected part of gameplay"; testers wanted less damage [read: Wikipedia Spelunky]. The condition: the world is random and runs are short. Our world is fixed and a death costs a trip back from an altar plus decaying remains [repo], so this licence is narrower [inf: Wikipedia Spelunky + design doc line 107].
- Super Meat Boy: infinite lives, "quick restarts", short levels, obvious goals [read: Wikipedia SMB]; levels are 10 to 30 s [snippet: Steam thread]. Celeste's rooms are shorter still [snippet]. Retry cost is the lever, not trap leniency [inf: both].
- Hollow Knight returns the player to safe ground after spike or acid damage instead of a death [snippet: speedrun wiki, GameDev.net critique; fetches 402/403]. Designer intent unconfirmed [gap]. Zelda falling spikes do the same (a heart and a room reset) [snippet].

**Numbers found**
- Telegraph floor: 340 ms (21 frames at 60 fps) [repo: Dark Souls 3 article, already in volcano.md].
- Reusable launcher cycle: 3.33 s (Terraria), 1.5 s (indie devlog), see section 1. Spelunky arrow trigger range 6 tiles [snippet].
- Per-hit hazard cap: 30% of max HP (Dead Cells) [read: Dead Cells Hazards].
- Forgiveness windows (Celeste, whose "everything is fudged a tiny bit in the player's favor"): wall jump from 2 px away [read: Matt Makes Games]; coyote and input buffer 5 frames each, corner correction 4 px [snippet: celeste.ink via search]. PoP used "very generous input buffers" [read: awweide PoP].
- Plate timing: Minecraft plates stay active 20 ticks, weighted ones 10 ticks [read: Minecraft Pressure Plate]. Terraria lists no plate delays [read: Terraria Pressure Plates].
- Checkpoints: Shovel Knight once had "checkpoints everywhere, almost on every other screen... it was getting obsessive"; no spacing numbers [read: Yacht Club]. PoP put one after the Level 3 gate jump so the set piece is not repeated [read: awweide PoP]. Blasphemous: at most seven screens [repo].
- Trap density per screen or per room: [gap]. Only the D&D one-sixth figure [snippet], Spelunky's per-tile 33% spike chance inside a 10x8 template tile grid (not a room density) [read: Spelunky Gen Part 2], and Dead Cells' monster-tile ratio [repo].
- Safe-window to active-window ratio: [gap] (volcano.md placeholder: safe at least active).

---

## 3. Traps as level-design tools

**Traps as locks**
- Detect-and-disarm: Terraria's Dangersense potion lights "all traps, including their triggers"; Mechanical Lens or Grand Design show the wires [read: Terraria Traps]. Metroid Dread's Pulse Radar "sends out a nifty pulse revealing all breakable surfaces and blocks hidden in your immediate vicinity", costs the Aeion gauge [read: Nintendo Life]; it also shows pit blocks, which Scan Pulse does not [snippet: metroid.fandom via search]. Zelda: the Eye of Truth reveals the stone umbrella that blocks falling spikes [snippet].
- Switch-disarm: Terraria wires an Actuator to a switch so you can get out of a trap [snippet: search result on Dart Trap wiring]; PoP plates open gates [snippet]. A designer-authored "disarm lever on a trap gauntlet" precedent was not found [gap].
- Cost to search: free searching makes paranoia; give it a cost or reveal by ability [read: The Alexandrian]. A trap you can only Search for "will be boring" [read: The Alexandrian].

**Traps plus enemies**
- Sen's Fortress layers hidden archers, casters and firebomb giants on boulders and blades; no mid bonfire [read: PCGamesN].
- Knockback into hazards: PoP "pushing them into traps while fighting" [read: Wikipedia PoP]; Dead Cells log traps do damage and push "a fair distance"; lava "instantly kills enemies", toxic pools hurt only the player [read: Dead Cells Hazards].
- Trap rooms as set pieces: Sen's "trap road", with the payoff "I made it" at Anor Londo [read: PCGamesN]; PoP's gate jump plus checkpoint [read: awweide PoP].

**Traps that harm enemies (level turned against them)**
- Hades spike traps hit Zagreus lightly and enemies hard [snippet: Hades wiki]; Terraria damaging traps deal 50% base damage to Old One's Army enemies [read: Terraria Traps]; Dead Cells nearly every trap hurts both [read: Dead Cells Hazards]. Per-target damage tables are normal.
- Spelunky: shopkeeper and tiki systems chain through traps to give "a living, breathing ecosystem"; combine "simple behaviors" [read: Game Developer How I Spelunky].

**Persistence of disarmed state**
- Dark Souls: shortcuts unlocked from one side stay open, enemies respawn, bosses do not [snippet: gamefaqs/gamepressure results]. Celeste falling blocks return when you die or leave [snippet]. PoP restarts the level [read: Wikipedia PoP]. Spelunky regenerates [read: Spelunky Gen]. Fixed-world precedents: Majora and Dead Cells runes in area-level-design.md [repo].

---

## 4. Player-laid and creature-laid traps

| Game | Placement limit, cost, cooldown | Enemy reaction | Source |
|---|---|---|---|
| Dead Cells | Deployables shoot out as a projectile and land; cooldown 14 s for Wolf Trap, Crusher, Bombard; 20 s decoy; 120 s Night Light; powered turrets need the player within a radius, shrunk by terrain; no stated cap on count | Wolf Trap roots for 5 s and adds 34 DPS; turrets fire at enemies in range [read: Dead Cells Deployable traps]; turrets "have their own health" and can be destroyed [snippet: search result] | [read: Dead Cells Deployable traps] |
| Don't Starve | Tooth Trap: 60 damage, 10 uses, manual reset, can be picked up and moved | Most mobs trigger it; bees, butterflies, flying birds, Batilisk, mosquitoes, shadows do not; damage does not aggro neighbours; food as bait | [read: Don't Starve Tooth Trap] |
| Terraria | Wire, plates, actuators; plate colours choose who triggers (player, enemy, both, projectile) | Red/green plates fire on enemy contact | [read: Terraria Traps; Pressure Plates] |
| Dwarf Fortress | Cage, stone-fall (one shot), weapon (1 to 10 weapons, 50% jam on a kill) | Hostiles trigger; thieves, flyers, "trapavoid" creatures and titans do not [read]; some invaders recognise some traps and avoid them [snippet: search summary of the DF wiki]; unconscious or webbed creatures trigger any plate [read]; wiki: a trap that works once "not trying hard enough" [read] | [read: DF Trap; DF walkthrough; DF Pressure plate] |
| Hollow Knight Silksong | Tools Tacks, Sting Shard, Snare Setter (a silk rune that ignites on contact, uses shell canisters and the wielder's Silk); refilled at benches with Shell Shards (Straight Pin: 12 uses, 3 shards each) | Pierce enemies that touch them | [read: Game8 Silksong tools] (numbers [snippet: fextralife]) |
| Orcs Must Die | Traps cost currency, reset after a cooldown that starts on trigger, up to ten chosen traps per level | Enemies path through | [snippet: wiki results] |
| RimWorld | Hidden from raiders; colonists know trap tiles and path around; 0.5% accidental trigger; some sapper raiders know 30% | Aware actors avoid; unaware walk the fast lane | [snippet: rimworldwiki via search; fetch 403] |
| Minecraft cobweb | Player 25% walk speed; mobs "do not try to pathfind around cobwebs" | Spiders, cave spiders, shulkers, vexes immune | [read: Minecraft Cobweb] |

- AI reaction menu: trigger (DF, Terraria red plates, Silksong) [read]; avoid (DF trapavoid [read], RimWorld aware actors and DF invaders [snippet]); ignore or immune (flyers in Don't Starve, spiders in cobwebs, titans in DF) [read]. "An intelligent creature is never going to build a trap that it might fall victim to itself" (D&D guidance) [snippet: search result]; The Alexandrian's "placement has to make sense" [read: The Alexandrian]; Lihzahrd plates trigger only for players [read: Terraria Pressure Plates].
- Kill versus capture. Monster Hunter: capture needs the monster weakened ("limping", a skull icon), a Pitfall or Shock trap, then two tranquiliser bombs; capture ends the hunt faster, lowers risk, but can cost carve time [read: Game8 MH capture]. DF cage traps keep creatures alive "indefinitely" [read: DF Trap]. Tiger Style's Spider: build a triangle of web strands to catch insects, eat a quota to open the portal, hornets cannot be webbed and must be attacked [read: Wikipedia Spider]. No numeric limping threshold anywhere [gap].
- Balance pitfalls found: single-use traps feel poor (DF wiki) [read]; trap resets and trinkets pull toward spam (Orcs Must Die Trap Reset Trinket) [snippet]; undetectable pickup-and-reposition (Don't Starve) is both a feature and an exploit [read]; trap damage that does not aggro lets players grind groups (Don't Starve) [read]; full immunity classes need to exist or bosses get cheesed (DF titans) [read]; webs and nets stop pathing but not AI intent (Minecraft) [read].

---

## 5. Rules for THIS game (all [inf], source named)

**5.1 Species and traps**
| Species | Plate weight | Trap behaviour |
|---|---|---|
| Slime | light | Passes `heavy` plates; takes reduced piercing (spike, dart, saw) and full fire and acid, so slime is a poor spike gate and a good plate gate [inf: Dead Cells per-target hazard table; Terraria 50% to a target class] |
| Spider | light | Floor traps are no gate (ceiling crawl, repo fact) so the lane test is the ceiling: tag ceiling-layer traps (falling spikes, web-cutters) so they threaten crawlers; a snared creature triggers plates (DF: webbed creatures trigger any plate) [inf: DF Pressure plate; repo] |
| Goblin | medium | Roll's invulnerable window passes projectile traps; it does not pass crush, pit or collapse (nothing to dodge) [inf: roll window from volcano.md R8; Dead Cells Crusher]; picks up and re-lays traps like Don't Starve [inf: Don't Starve Tooth Trap] |
| Wolf | heavy | Only species that trips `heavy` plates; fastest crossing of a timed rect, so a timed trap needs a safe window at least as long as the slowest species' crossing time [inf: Rhythm paper in area-level-design.md; Weighted plates, Minecraft/DF] |
| Undead biped | medium (planned) | Immune or near-immune to poison gas and tipped darts, not to crush [inf: Terraria Poisoned dart; Dead Cells toxic pools hurt only the player] |
- Plate rule: plates declare `weight` (`light`, `medium`, `heavy`) and `filter` (`player`, `enemy`, `any`). DF cannot make a plate for civilians only, so offer the filter explicitly [inf: DF Pressure plate]. Terraria shows the six useful variants [read: Terraria Pressure Plates].
- Sensing: a `sense` ability reveals trap triggers and wires in a radius, never the hazard timing [inf: Terraria Dangersense, Pulse Radar]. Spider web vibration sense or wolf scent are natural species flavours [inf].

**5.2 Death seed per trap family** (design doc seed rule: creature kill seeds its strongest element, hazard seeds its own, fall or crush seeds nothing) [repo]
| Family | Seed | Why |
|---|---|---|
| Spikes, saw, boulder, falling block, crusher, collapse, pit, arrow | none | impale and crush are physical like a fall [inf: design doc rule] |
| Fire jet, eruption, brazier | fire | volcano.md V7 [repo] |
| Gas vent, tipped dart, bramble poison | poison | Terraria poisoned dart [read] plus the spec's poison water [repo] |
| Drowning trap, flooded trapdoor | water | spec's drowning rule [repo] |
| Web snare, net | thread | thread seed exists in the playtest checklist [repo]; spider webs [inf] |
| Mimic, ambush closet | the creature's strongest element | creature-kill rule [repo] |
- Any lethal trap with an element is an unlock-leak risk if a gate reads "has element": gate on permanent essence, never the seed (volcano.md R3) [repo]. Apply to crypt poison and demon fire too.
- Combo deaths (knockback into spikes, snared then killed): proposed rule, needs Sean's decision: if a creature damaged you within the last 2 s (*placeholder*) and the killing blow is seedless (spike, crush, fall), the creature's strongest element seeds, so the enemy owns the kill; otherwise the killing source seeds as in the table. A snare never kills by itself, so thread seeds only when a thread creature (spider, weaver) landed the damage. Without a rule, knockback-into-spike rooms seed nothing for a creature-caused death [inf: design doc seed rule, creature kill seeds its strongest element and fall or crush seeds nothing [repo]; PoP push-into-traps and Dead Cells log knockback [read]].

**5.3 Minimal room-data schema** (rooms already store `solids` as Rect2 arrays and `decor` as dict arrays [repo], so `traps` is an array of dicts; all fields [inf])
| kind | rect | trigger | telegraph_ms | cycle | seed_element |
|---|---|---|---|---|---|
| spike | Rect2 | `{"t":"static"}` | 0 | none | "" |
| dart_launcher | muzzle Rect2 + `dir` | `{"t":"sight","range_px":96}` or `{"t":"plate","id":"p1"}` or `{"t":"timer"}` | 400 | `{"period_ms":3300,"active_ms":150,"phase_ms":0}` | "" or poison |
| fire_jet | Rect2 | `{"t":"timer"}` | 500 | period 2400, active 600 | fire |
| gas_vent | Rect2 | `{"t":"timer"}` | 500 | period 4000, active 1200 | poison |
| falling_block | Rect2 | `{"t":"plate","id":"p2"}` or tripwire rect | 450 (shake) | `"once"` | "" |
| collapse_floor | Rect2 | `{"t":"stand","delay_ms":500}` | 500 (crack) | `{"respawn_ms":4000}` | "" |
| boulder | start Rect2 + path | plate or tripwire | 600 (rumble) | `"once"` | "" |
| pit / trapdoor | Rect2 | plate (weight) or `stand` | 400 | `"once"` | "" |
| saw | path + speed | `{"t":"continuous"}` | 0 (path drawn) | loop | "" |
| mimic | chest Rect2 | `{"t":"interact"}` | 0 (tell frame) | `"once"` | creature's |
| ambush_lock | room Rect2 | `{"t":"enter"}` | 600 | `"once"`, persistent when cleared | creature's |
| web_snare | Rect2 | `{"t":"contact"}` | n/a | `{"hold_ms":3000}` (placeholder) | thread |
Extra optional columns: `layer` (floor, ceiling, wall, air), `damage_pct` (lethal rooms only above 30), `disarm` (switch id or species verb), `persist` (`reset`, `life`, `permanent`), `weight`. Numbers in the table are placeholders except where the section above names a source (Terraria 3.33 s, 340 ms floor, Celeste ~1 s, Dead Cells 30% cap).

**5.4 Validator and lint ideas** (names are proposals for `RoomLint` / `WorldValidator`; owned by the reach-model plan, not edited here [repo])
1. `trap_telegraph`: every timed, plate, sight, stand or enter-triggered trap has `telegraph_ms` of at least 340 (21 frames at 60 fps; ceil of 20.4); aim 500 to 600; safe window at least active window. Exempt: `static` and `continuous` traps (spike, saw), which must be fully visible instead; `interact` traps (mimic) must show a tell frame and are exempt from the ms floor; player-laid traps (web snare) are exempt because the player chose the timing [repo + inf: Dark Souls 3 article, Dead Cells shine, Ludomotion].
2. `trap_visibility`: at least one of trigger or hazard visible; flag a hidden sight trigger plus invisible hazard (no `decor` tell) [inf: Ludomotion, Kate Plays].
3. `trap_base_route`: with lethal traps blocked and timed traps passable only if safe window is at least slowest-species crossing time plus margin, the area's main route (first room to altar and rest pool) exists on the base jump (63 px) [inf: base-reach pass in area-level-design.md; Monochroma "a solution exists"].
4. `trap_entry_zone`: no trap rect within the exit zone (existing 64 px) of any exit; raise to a larger buffer (*placeholder* 160 px) so the first screen after a transition is safe [inf: Zelda doorway safe zone; Dead Cells tunnel].
5. `trap_altar_radius`: no lethal trap with a kill flag within one screen (640 px) of an altar or rest pool; forbids a respawn-kill loop [inf: Sen's no mid bonfire; PoP restart; Yacht Club on checkpoint frustration].
6. `trap_remains`: a death inside a lethal rect must snap the remains pile to the nearest safe tile outside any trap rect, so retrieval never requires re-entering the trap [inf: design doc remains rule, line 107].
7. `trap_one_concept`: one timed trap kind per room; the first instance of each kind in the game appears alone in a room with a safe view of both trigger and hazard and an altar or pool within seven screens [inf: Shovel Knight, Level Design Patterns foreshadow, Blasphemous figure].
8. `trap_seed`: every lethal trap names `seed_element` or explicitly empty [inf: volcano.md R5].
9. `trap_ceiling_lane`: for a floor trap in a hallway, flag the spider bypass unless the ceiling has a ceiling-layer trap or is non-crawlable [inf: repo engine fact].
10. `trap_knockback`: enemy patrol bounds on the main route stay at least one knockback distance from lethal traps unless tagged intentional [inf: PoP push-into-trap; Dead Cells log knockback].
11. `trap_lock_reachable`: a trap's `disarm` switch or verb must be reachable without crossing that trap [inf: Alexandrian, Terraria actuator-switch].
12. `trap_damage_cap`: non-lethal main-route traps deal at most 30% of max HP per hit; lethal traps only in rare rooms [inf: Dead Cells cap; volcano.md V3].
13. `trap_phase_fixed`: timed traps start at a fixed phase on room entry so a learned rhythm transfers to every life and species [inf: Sen's and PoP memorisation].

**5.5 Map of trap families to areas** (all [inf]; family names from section 1; element per 5.2)
| Area | Families | Species angle | Note |
|---|---|---|---|
| Cave (existing) | stalactite drop (the decor already exists), collapse floor, spike pits | slime bounces off a collapse; spider crawls over | teach plate and sight trigger alone, no lethal |
| Grotto | spore puff and poison gas, web snare (enemy spiders), spike nests | undead immune to gas | thread and poison seeds |
| Flooded | drowning pits, current vents, trapdoor with water seed | slime swims | water seed, no lethal near the swim gate |
| Deep | crushers, dart slits, collapsing bridges over the fire descent | wolf heavy plates | hardest area, main route stays easier than the entry |
| Crypt (off the Deep) | plate-and-dart corridor, collapsing sarcophagus floor, mimic coffin, ambush seal door, poison gas | sense reveals plate wires; heavy plate locks a side vault for the wolf | trap-room set piece; Sen's, PoP, Spelunky vault |
| Cathedral | falling chandelier on a tripwire, pendulum blades, statue ambush | spider uses ceiling beams; roll passes blade | timing set piece; light rhythm |
| Cemetery | grave pit, spike fence, rising-dead ambush on plot plates | goblin disarms for scrap | pits seed nothing |
| Swamp | poison vents, sinking logs, snapping plants, web snare | slime light on sink logs | poison and thread |
| Goblin village | goblin-laid tripwire and net, pit-spike, deadfall; trap that reads "player-species goblin passes" | goblin disarms and keeps; others see it as a lock | enemy traps harm the player; the player turns them on goblin guards |
| Demon | seal plates (weight), fire jets, crush walls | heavy plates; roll passes fire | fire and curse seeds |
| Volcano | fire jet cycles, rockfall, collapsing crust, quench platforms | per volcano.md lanes | volcano.md rules apply |
| Forest | snares, log traps with knockback, thorn pits, web snare | wolf pounce over pits | log trap as knockback tool |
- Persistence tie-in: one-shot triggered traps stay fired for the life and reset at rebirth; a trap disarmed through a switch or species verb writes a flag in the opened-shortcut list and stays disarmed on every life; cycle traps never persist (they have no state) [inf: area-level-design.md K1 persisting rewards; Dark Souls shortcuts snippet; Celeste falling-block reset snippet]. A disarmed trap should be visibly cut, jammed or sealed [inf: Kate Plays on visible cues]. Enemy-laid traps in the goblin village can be permanently dismantled by a goblin verb [inf: Don't Starve pickup].

**5.6 Player-laid traps: spider webs and goblin junk traps** (all [inf], source named)
1. Cap by cooldown and a carried count, not by free placement: web and junk-trap cooldown of about 8 to 14 s (*placeholder*, borrowed from Dead Cells' 14 s) and a small carried count refilled at an altar or glow pool, the way Silksong refills tools at benches [inf: Dead Cells Deployable traps [read]; Game8 Silksong tools [read]]. Webs cost the spider a resource (silk) so a web is a decision [inf: Silksong Snare Setter "uses ... the wielder's own Silk" [read]].
2. Enemy reaction by class: beasts and most walkers trigger traps; flyers and spiders are immune to ground webs and plates (spider-kin cannot be snared by webs); smart enemies (goblins, undead biped line) avoid traps they have seen the player lay, so a trap's value is highest when laid out of sight or behind bait; bosses and large creatures are immune to snare, partly resistant to damage, so a trap never solos a boss [inf: Don't Starve immune list [read]; Minecraft Cobweb "spiders ... immune", mobs do not path around webs [read]; DF "titans ... immune to traps entirely" [read]; RimWorld aware actors avoid [snippet]].
3. Snare, then eat or tame: a web snare holds a living target for about 3 s (*placeholder*) at no damage; a spider may eat a snared creature at or below a weakened-HP threshold (*placeholder* 30%) for health or essence, and the same threshold lets the goblin throw a net or spring a pit and then tame the creature instead. Trap-to-capture needs the weakened state, as capture does in Monster Hunter (limping, then trap, then tranquilliser), which also shortens the fight and lowers risk [inf: Game8 MH capture [read]; Wikipedia Spider, catch then eat [read]]. The threshold has no source value [gap].
4. Aggro: decide explicitly. Don't Starve's trap damage does not aggro neighbours, so players grind packs for free [read: Don't Starve Tooth Trap]; recommended here: web and junk-trap damage does aggro the pack and wakes sleepers, so trap-grinding costs risk [inf: same source, reversed].
5. Single-use junk traps are fine for the goblin only if scavenging is cheap; the DF wiki says one-shot traps feel wasteful, so let a sprung goblin trap be re-armed with junk (a Tooth Trap resets by hand, 10 uses) [inf: DF Trap [read]; Don't Starve Tooth Trap [read]].
6. Player traps and world traps share one hit table: a webbed creature triggers plates beneath it (DF) and enemy-laid traps never trigger on their own kind [inf: DF Pressure plate [read]; Alexandrian "intelligent creatures wouldn't build traps that harm themselves" [read]].

---

## Gaps (searched, nothing usable, or not searched)
- Cycle times for fire jets, gas vents, saw paths, collapse delays; trap telegraph durations other than 340 ms. Safe-window ratios. Hazards per screen. [gap]
- Why Hollow Knight returns the player to safe ground after hazards (no designer quote). [gap]
- Super Meat Boy saw numbers, Cave Story, Castlevania, Rain World, Hollow Knight Weaversong, Indiana Jones trap-room design essays: not searched or no body. [gap]
- Spelunky arrow-trap frame data; Derek Yu design writing on tiki traps (only the Indiana Jones credit and the shopstorm essay found). [gap]
- Monster Hunter limping threshold as a number; Orcs Must Die and RimWorld pages blocked (403, snippets only). [gap]

## Sources
Read (38):
- https://www.gamedeveloper.com/design/fairness-discovery-spelunky [read]
- https://www.gamedeveloper.com/design/a-spelunky-game-design-analysis---pt-2 [read]
- https://awweide.substack.com/p/the-making-of-prince-of-persia [read]
- https://kateplays.substack.com/p/telegraphing-danger [read]
- https://www.gamedeveloper.com/design/level-design-patterns-in-2d-games [read]
- https://terraria.wiki.gg/wiki/Traps [read]
- https://deadcells.wiki.gg/wiki/Deployable_traps [read]
- https://dontstarve.wiki.gg/wiki/Tooth_Trap [read]
- https://en.wikipedia.org/wiki/Super_Meat_Boy [read]
- https://tinysubversions.com/spelunkyGen/ [read]
- https://tinysubversions.com/spelunkyGen2/ [read]
- https://en.wikipedia.org/wiki/Spider:_The_Secret_of_Bryce_Manor [read]
- https://www.gamereactor.eu/interview-derek-yu/ [read]
- https://www.gamedeveloper.com/design/how-i-spelunky-i-got-its-procedural-hook-actually-got-finished [read]
- https://www.mattmakesgames.com/articles/celeste_and_forgiveness/index.html [read]
- https://www.pcgamesn.com/dark-souls-remastered/sens-fortress-trap-house [read]
- http://soulslore.wikidot.com/das1-design-works/ [read]
- https://terraria.wiki.gg/wiki/Dart_Trap [read]
- https://www.nintendolife.com/guides/metroid-dread-pulse-radar-location-how-to-scan-for-hidden-areas [read]
- https://en.wikipedia.org/wiki/Spelunky [read]
- https://dwarffortresswiki.org/index.php/DF2014:Trap [read]
- https://df-walkthrough.readthedocs.io/en/latest/chapters/chap06-traps.html [read]
- https://game8.co/games/Hollow-Knight-Silksong/archives/547890 [read]
- https://deadcells.wiki.gg/wiki/Hazards [read]
- https://minecraft.wiki/w/Cobweb [read]
- https://game8.co/games/Monster-Hunter-Wilds/archives/483227 [read]
- https://www.yachtclubgames.com/blog/check-point-design/ [read]
- https://www.gamedeveloper.com/design/enemy-attacks-and-telegraphing [read]
- https://thealexandrian.net/wordpress/45020/roleplaying-games/rulings-in-practice-traps [read]
- https://yaninagames.com/blog/cursed-tomb-treasure/ [read]
- https://en.wikipedia.org/wiki/Prince_of_Persia_(1989_video_game) [read]
- https://www.gamedeveloper.com/design/against-the-death-penalty [read] (no usable trap content; death-penalty framing only)
- https://www.gamedeveloper.com/design/the-path-to-monochroma-platformer-design-elements [read]
- https://www.ludomotion.com/blogs/trap-is/ [read]
- https://www.gamedeveloper.com/design/traversal-level-design-principles [read] (almost nothing on traps)
- https://minecraft.wiki/w/Pressure_Plate [read]
- https://dwarffortresswiki.org/index.php/Pressure_plate [read]
- https://terraria.wiki.gg/wiki/Pressure_Plates [read]
Repo, read: docs/research/area-level-design.md, .../area-level-design-notes/volcano.md, docs/isekai-chronicles-design-doc.md (seed and remains lines), data/rooms/C1.tres (format only) [repo].

Snippet only (search-result text; page not opened or fetch failed):
- https://spelunky.fandom.com/wiki/Arrow_Trap_(2) [snippet] (fetch 402; range 6 tiles, 24 blocks/s, damage 2)
- https://hollow-knight-speedrunning.fandom.com/wiki/Hazard_warp [snippet] (fetch 402)
- https://gamedev.net/tutorials/game-design/game-design-and-theory/hollow-knight-design-critique-r4996 [snippet] (fetch 403)
- https://hades.fandom.com/wiki/Tartarus [snippet] (spike trap, short delay, light damage to player, heavy to enemies)
- https://rimworldwiki.com/wiki/Trap [snippet] (fetch 403)
- https://mhworld.kiranico.com/en/guide/trapping?ver=8 [snippet] (fetch 403)
- https://orcsmustdie.fandom.com/wiki/Trap_Reset_Trinket and https://orcsmustdie.wiki.gg/wiki/Traps [snippet]
- https://celestegame.fandom.com/wiki/Objects and Neoseeker Celeste walkthrough [snippet] (crumble about one second)
- https://celeste.ink/wiki/Spike_Jumps and /wiki/Tech [snippet] (spike hurtbox, coyote and buffer 5 frames, corner correction)
- https://www.zeldadungeon.net/wiki/Falling_Spikes and Blade Trap pages [snippet]
- https://hollowknightsilksong.wiki.fextralife.com/Straight_Pin [snippet]
- https://forum.zdoom.org/viewtopic.php?f=39&t=49241 and Giant Bomb Monster Closet [snippet] (ZDoom fetch hung)
- https://oldschoolessentials.necroticgnome.com/srd/index.php/Designing_a_Dungeon [snippet] (fetch 500)
- https://en.wikipedia.org/wiki/Mimic_(Dungeons_&_Dragons) [snippet]
- https://metroid.fandom.com/wiki/Pulse_Radar [snippet]
- https://sawtop.itch.io/paint-by-monsters/devlog/443026/devlog-3-of-tiles-and-arrow-traps [snippet]
- https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/PrinceOfPersia1 [snippet] (spike walk-in survival, loose tile plate puzzle)
- https://steamcommunity.com/app/40800/discussions/0/846959520914606872/ [snippet] (SMB level length)
- Dark Souls shortcut persistence: gamepressure and gamefaqs results [snippet]
