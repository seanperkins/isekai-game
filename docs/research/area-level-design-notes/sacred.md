> Unedited agent notes. Where they conflict with `../area-level-design.md`, that document wins.
> Note: these notes frame the area after the Deep as contested. Sean confirmed (2026-10-04) that everything is added and nothing replaced; see section 15 of the main document.

# Sacred cluster: cathedral, safe cemetery, crypt (research notes)

Tags: **[read]** page fetched and read; **[snippet]** search-result text only; **[inf]** my inference (source named); **[gap]** searched, nothing found; **[repo]** read in this repo. WebFetch summarises pages with a small model, so every quoted phrase is "as summarised", never verbatim-verified. A number marked *placeholder* is mine. WebSearch hit its 200-call session cap mid-run, so some topics (Ghosts 'n Goblins, Monster Hunter, Dungeon Keeper, Diablo) are snippet-only. Existing docs `area-level-design.md` and `level-design-reference.md` were read first and are cited as "doc A1/K3/V3/V4/V6/5.1-5.3", not repeated.

Repo facts used [repo]: 640x360 screens; 20 px generated ceiling and walls (`rooms.md`); one-way = thin solid at most 24 px, `hard_ledges` makes one rock from below (no shipped room uses it); exits carry a `gate` label from `WorldValidator.GATES` (`wall_cling`, `swim`); 64 px exit clearance; creature flags in `creature_def.gd`: `armored_charger` (front block), `charges` (wolf), `stomper` (drake slam), `projectile` ("spear" spitter), `pack`, `drifter`, `swimmer`, `contact_type` ("physical" or "shock"); design doc: undead drain life from living creatures, zombie/vampire devour, skeleton grafts, lich "bone magic and summoning", Light essence "counter to dark; feeds holy/support paths", one altar per area with a fixed local perk (all four perks assigned), "a last area past the Deep" ends in the goddess fight.

---

## 1. Precedents with design rationale

- **Symphony of the Night, Royal Chapel:** vertical ascent is the area's single navigational theme: "the longest continuous staircase in the game", an unbroken central tower, forest giving way to "an indigo sky and a stream of clouds", payoff is "the gorgeous chapel sidelined by stained-glass windows and terminating in an altar" [read: Game Developer, SotN economy and thematic structure]. The chapel is a long climb of "many long staircases, and a couple of bell towers" [read: inverteddungeon]. Lesson: the sacred set piece is the reward at the end of a vertical build-up, not the entry.
- **SotN, Catacombs and Colosseum:** the most compressed areas; compression "reinforces the area's claustrophobic associations"; the Catacombs' strongly horizontal structure "drives home the sense that this truly is the castle's bedrock"; the Colosseum uses "hard symmetry" [read: same article]. About half the map is negative space so areas "develop on their own terms" [read]. Lesson: crypt = low, long, horizontal, compressed; nave = tall; same game, opposite proportions.
- **Blasphemous:** checkpoints "roughly one per area and never more than seven screens apart"; reusable shortcuts (teleports, elevators) join distant districts such as the village Albero and the Convent; levers were "overused"; hierarchy district > zone > scene; mountains sit "on top of all the areas"; one branching point is the "Wasteland of the Buried Churches" [read: Game Developer]. Mother of Mothers' antechamber reproduces Cordoba-mosque arches; "Grievance Ascends" is nine walkways from Dante's circles [read: Play the Past]. Cathedral of Seville, rose windows, warm ochre lighting [snippet]. A buried church is an existing precedent for an underground cathedral.
- **Dark Souls, the sanctuary-graveyard-catacomb-tomb stack:** Firelink Shrine is a hub whose paths are "like roots"; the Catacombs are entered "in the graveyard of Firelink Shrine" and lead on to the Tomb of the Giants; "you don't find shortcuts ... you find how one area is connected" [read: TheGamer; Fextralife Catacombs]. Note it inverts the user's ask: here the safe place is the shrine, the graveyard is dangerous.
- **DS Catacombs rules:** skeletons "kept alive by the Undead Mages"; a divine-weapon finish keeps one down; killing the mages makes "all the local Skeletons ... die for good using any weapon"; the Skull Lantern is a rare mage drop [read: Fextralife]. Tomb of the Giants: dark, coffin-shaped slide ramps, pits, two bonfires at about one third and two thirds, "Skeleton Dogs" with "very low health" but "very high damage" [read: Fextralife]. Glowing eye sockets mark skeletons in the dark [snippet]. Catacomb modular layouts with unique placement [snippet].
- **DS Undead Burg / Parish:** "every new goal is either high above or far below you"; a kickable-ladder shortcut; one-way drops "enforce a one-way flow"; enemies as "breadcrumbs" [read: PCGamesN; Level Design Book]. Undead Parish holds a bell and church; layout resembles a real abandoned church [snippet].
- **DS Anor Londo:** white marble in sunlight right after dark areas; "giant sentinels", chest mimics, and archers guarding "the narrow walkway that leads to your destination" [read: Den of Geek]. Lesson: beauty reads as safe, so a holy area must signal threat in the beauty (a priest silhouette, a beam that hurts).
- **Bloodborne:** Hunter's Dream is a hub reached from lamps; Victorian Gothic "partly inspired by" Dracula and Romania/Czech architecture; interconnected with shortcuts [read: Wikipedia]. Yharnam architecture is Mannerist, "clamors for space" [read: Kill Screen, thin]. Cathedral Ward to Hemwick Charnel Lane via a tunnel into a graveyard; Hemwick is a "mass grave" with crematoria-like houses [snippet]. Design rationale for either: [gap].
- **Hollow Knight:** Resting Grounds is "a large cemetery ... grey and somehow a colorless area" turning blue with the Dream Nail, but it holds enemies (Belfly, Winged Sentry, Entombed Husk, Great Husk Sentry), NPCs (the Seer, the Grey Mourner) and connects west to Crystallised Mound, east to City of Tears by a lift, and to Blue Lake [read: Fextralife]. So it is quiet, not safe. Dirtmouth is "a quiet town that sits just above the remains of the kingdom" [read: Wikipedia]; "safe zone" status is [snippet]. Devs built by "exploration and discovery", not metrics [read: Game Developer]. City of Tears and Soul Sanctum design write-ups: [gap].
- **Dead Cells:** collisions and backgrounds "have to contrast as much as possible", background colours "fade into each other"; enemies, projectiles, spells get high saturation, contrast, brightness; complementary palettes for confined interiors, analogous for outdoors; the opener contrasts a warm glow with cold shadow [read: Game Developer art deep dive]. Graveyard (needs the Spider Rune) and Ossuary (red haze, corpse piles) [snippet].
- **Shovel Knight Lich Yard:** "got some ghostly flames so the level as a whole wouldn't feel so combat-heavy"; sketch notes darkness, ghost "walls", "falling into some tombs"; one dirt block under a skull does two jobs (a bounce route and an optional bypass) [read: Yacht Club 1/5 and 3/5, thin]. Gems marking platform edges in darkness: [snippet only; neither page I read says it].
- **Nioh:** the Dark Realm is "swirling grey smoke", approaching it spawns yokai; in human form Ki recovery drops "dramatically" but Yokai Force builds faster; yokai grow "ever more fearsome" in it; it is removed by a maximum Ki Pulse or by destroying the creature generating it [read: Fextralife]. A reviewer: yokai "regenerate faster and yours regenerate much, much slower", "sometimes hard to see in, especially in night levels", "sick of seeing it" by the end [read: twinelab].
- **Ender Lilies** cathedral: two floors, lower one long corridor rooms of rubble; blight clouds force running [snippet]. **Salt and Sanctuary:** sanctuaries only as creed-icon placement in the sources I could open [read: Wikipedia, no design content; gap]. **Ghosts 'n Goblins:** zombies crawl out then dive back, no endless chase [snippet].
- **Real architecture as the source:** cruciform plan, "long nave crossed by a transept", chancel with apse at the east end [read: Wikipedia Church architecture]. Crypts "below the main apse", later under chancel, nave and transepts; some churches "raised high to accommodate a crypt" [read: Wikipedia Crypt]. Churchyards adjoin or surround the church and are consecrated burial ground [read: Wikipedia Churchyard]. Catacombs are man-made passages, Roman ones outside city walls [read: Wikipedia, thin].

## 2. Layout patterns for sacred architecture in 2D

- **Nave and aisles:** a cruciform plan gives a ready room set: nave (long, tall), transept (the cross-arm, a hub), chancel/apse (end room), crypt (beneath the chancel) [read: Church architecture; Crypt]. In 2D the nave is a 3x1 corridor with the aisle as a lower or parallel lane [inf: cruciform plan; doc section 3 parallel branch].
- **Vertical layering:** cathedral above, crypt below, churchyard around is literal church layout [read: Crypt; Churchyard] and the Dark Souls Firelink/graveyard/Catacombs/Tomb stack is the game version [read: Fextralife; TheGamer]. Directions: climb to the sacred set piece (SotN), descend into the tomb (DS) [read].
- **Bell tower / central tower as shaft:** SotN chapel is one tall tower plus bell-tower climbs [read: GD; inverteddungeon]; Blasphemous puts mountains "on top" [read]. Shaft rules in doc FO2 (works up and down) and reference 2 (Vertical shaft) apply [inf].
- **Symmetry and rhythm:** hard symmetry is a deliberate compression device in SotN's Colosseum [read]; a nave of repeated bays gives a repeating hazard rhythm (beam, shade, beam) [inf: Colosseum symmetry; Compton and Mateas repetition in doc section 4].
- **Stained glass as light and landmark:** SotN chapel ends in stained-glass windows by the altar [read]; Dead Cells uses warm glow versus cold shadow to direct the eye [read]; Anor Londo's sunlit marble is the reveal [read]. A design write-up on stained glass as a 2D level-design tool: [gap]. Use [inf]: windows are decor with a `light` attribute (the decor catalog already has a `light` field [repo: rooms.md]) and, as holy emitters, the visible cause of a holy beam.
- **Pews as platforms or cover:** no design source found [gap]. [inf]: pews are 16-24 px hard ledges (vault and mantle surfaces the existing doc says are missing, doc 5.4) and low gaps beneath them are slide/roll lanes; as cover they are shade pockets under a holy beam.
- **Finished stone versus cave tiles:** no source on tile-set switching [gap]. Dead Cells: interiors use complementary palettes for a confined feel, outdoors analogous [read]; Blasphemous Mother of Mothers: marble, columns, warm light [snippet]. [inf]: a threshold room mixes both tile sets (cave wall breaking into cut masonry) as the area cue (doc A4).
- **Readability against ornate backgrounds:** Dead Cells: contrast collisions against backgrounds, let background colours "fade into each other", reserve peak saturation for threats [read]. Doc FO3/V9 add outline and value contrast [repo]. Fine tracery goes in the far parallax layer at low value contrast, never in the platform layer [inf: Dead Cells].
- **Crypt below the nave as a circuit:** Old St Peter's crypt let pilgrims "enter at one stair, pass by the tomb and exit" without disturbing the service above [read: Crypt]. A one-in, one-out stair loop under the apse is a ready crypt shape that joins two surfaces [inf].
- **Do not over-ornament:** Ori's one-off set dressing is called costly in doc section 6 [repo]; Hollow Knight built by discovery, not metrics [read]. Keep the cathedral to 3 or 4 repeated modules (bay, window, pew row, pier) [inf].

## 3. Holy zones and species-conditional hazards

What the reads show (the pattern, plainly): zones that hurt one class are **emitter-bound or cover-bounded, trade rather than ban, and never lock**.

- **Emitter-bound:** Nioh's realm dies when its generating creature dies or a Ki Pulse purifies it [read]; NetHack sanctuary exists only while "the priest is peacefully tending the altar and your alignment is greater than -4", "monsters will not enter", those inside "flee" and "can still use ranged attacks", exceptions include peacefuls and high priests [read: NetHack Wiki]; DS skeletons stop reviving when their mage dies [read]; Echoes safe zones are permanent crystals or "temporarily activated" by a beam shot at a generator [read: Wikipedia]. Pattern: an object you can reach switches the zone.
- **Cover pockets:** V Rising sun damage starts after "a few seconds" and "only stops when the player steps into a shadow, enters a roofed area, or dies" [read: Wikipedia]; Echoes safe zones heal Samus and suit upgrades "reduce or completely nullify" the damage [read: Wikipedia]. Dark creatures hurt by light crystals: [snippet; metroidwiki 403].
- **Weakness that is overcome:** Soul Reaver's Raziel is "initially vulnerable to water", later "learns to swim"; he returns to the material realm only through portals at full health [read: Wikipedia]. Water and sunlight kill vampires, hence the player is the affected class there [read].
- **A trade, not a pure penalty:** Nioh in human form loses Ki recovery but gains Yokai Force faster [read]. Darkest Dungeon's Crusader gets "bonus damage against Unholy enemies" as a soft counter (number 15% [snippet]; the wiki page I read gives none) [read].
- **Counter-biome:** Terraria's Hallow does not directly hurt the player; its pastel graphics and "a large rainbow in the background" announce it, enemies (pixies, unicorns) are what hurt, it needs "at least 125 Hallowed blocks" to count as a biome, and it spreads through blocks, not mud [read: wiki.gg]. Holy Water and Hallowed Seeds spread it [snippet]. Hallow is not species-conditional; it is a visually loud zone with its own roster.
- **Item-level:** holy water as a Castlevania "fiery grenade" subweapon [read: Wikipedia]; Blessed Hammer +50% to undead in Diablo II [snippet]; Boktai's player is advantaged by day because vampires "cannot be exposed to sunlight", and the Solar Station recharges the gun [read: Wikipedia]. Diablo Consecration heals allies on the ground [snippet]. Dungeon Keeper: graveyards make vampires from corpses, no holy zone [snippet; holy-zone design: gap].
- **How designers signal such a zone:** Nioh grey smoke [read]; Terraria palette and rainbow [read]; Echoes spherical light fields [read: Wikipedia]; Dead Cells warm light versus cold shadow [read]; V Rising roof/shadow rule [read]. Sound or banner cues as holy-zone signals: [gap].
- **Failure modes:** Nioh's realm is "hard to see in" at night and became tiresome through overuse [read: twinelab]. NetHack's ranged exception is a stated loophole [read].
- **Keeping it fair for the affected class:** no source states a fairness rule directly [gap]. Closest: V Rising (visible cause, cover, time before damage), Echoes (heal pockets, suits), Soul Reaver (weakness removable) [read].
- **How it should read when the player IS the affected class:** only Soul Reaver and V Rising are sourced; both let the player feel the hazard coming (a few seconds' grace, a visible roof/shadow) [read]. Everything else in section 6 is [inf].

## 4. Safe zones next to danger

- **Firelink Shrine** feels safe, per the article, because the early game is tightly interconnected and the hub is the root of every path; once Anor Londo grants fast travel, levels become "more spread out" [read: TheGamer, as summarised]. **Hades' House:** each death returns you to the hub and new dialogue "reduces the sense of meaninglessness" [snippet: Trill]. **Hunter's Dream:** a hub reached from lamps where you buy, level and upgrade [read: Wikipedia Bloodborne].
- **Resident Evil safe rooms:** music "often somewhat relaxing to bring about an air of calm", "brief reprieves from the horror", players save without threat [read: GameRant]. Composer Uchiyama said the music was intentionally "peaceful and relaxing elements with a little touch of the uneasy" [snippet: search result; the PC Gamer page was truncated and the GameRant page has no quote]. A warm lantern, item box, typewriter [snippet].
- **NetHack sanctuary** is the mechanical rulebook: enemies will not enter, those inside will not melee, ranged attacks still work; it needs the priest present [read]. So a safe zone must also remove or block ranged attackers [inf from the loophole].
- **Echoes safe zones** heal "one unit per second" [snippet] and are permanent (crystal) or temporary (beacon) [read: Wikipedia].
- **Cave Story:** the first level gives "two paths, one of which is blocked off until retrieving an item from the other" [read: Wikipedia]. The village as a "danger-free zone" is cited in doc section 6 [repo, not re-verified]; the Cemetery is a door on the village's right [snippet: fandom]. **Monster Hunter:** camps are "safe areas from the monsters" with a health-restoring tent [snippet]; design rationale [gap].
- **What a safe zone should still offer** (sourced pieces): save/rest (RE, Firelink, Hunter's Dream) [read]; NPCs and lore (Resting Grounds Seer and Grey Mourner) [read: Fextralife]; a way to travel on (Blasphemous elevators and teleports, Firelink roots) [read]; an altar equals a respawn here [repo].
- **Resting Grounds is not a template for "safe":** it has hostile enemies [read: Fextralife]. Use Dirtmouth, Firelink, RE safe rooms, Echoes safe zones and the NetHack sanctuary for safe rules.

## 5. Crypt and catacomb design

- **Compression:** SotN Catacombs are horizontal and compressed [read]; Ender Lilies' cathedral basement is long corridor rooms of rubble [snippet]. Tight corridors, burial niches, ossuaries: no design write-up found for niches as game spaces [gap]; real catacombs hold decorations, inscriptions and passages carved from soft rock [read: Wikipedia Catacombs, thin].
- **Reassembling skeletons:** DS rule: an emitter (the Undead Mage) keeps them rising; a "divine" finish or killing the mage ends it [read: Fextralife]. Skeletons appear as bone piles that assemble when approached [snippet: fandom]. Ghosts 'n Goblins zombies rise and dive back [snippet]. Lich Yard has darkness, ghost walls, tomb drops [read: Yacht Club, thin].
- **Necromancers:** emitter + minions, kill the emitter to clear them (DS) [read]; Soul Reaver and Nioh show the same emitter pattern [read].
- **Darkness:** Tomb of the Giants is "very dark" and needs Cast Light, Sunlight Maggot or Skull Lantern; skeletons' eye sockets glow [read; snippet]. Costs: lantern hand-slot [snippet].
- **Sealed doors, ossuaries, how a crypt attaches:** DS places the Tomb below the Catacombs below the Firelink graveyard, reached by sliding down coffin ramps [read]; real crypts sit under the chancel and may have an in-one-out stair [read: Crypt]. Attachment to a deepest-cave area: Blasphemous' reusable shortcuts, DS's one-way slide with a loop back [read]. Ossuary design write-ups: [gap].
- **Traps (flag only):** crypt-appropriate families: falling-tomb floors (Lich Yard "falling into some tombs" [read]), sliding coffin ramps (Tomb of the Giants [read]), dart/arrow niches (arrows from distant skeleton archers [snippet]), crushing sarcophagus lids, reassembly timers. [inf]

## 6. Rules for this game [inf unless noted]

### 6.1 Alignment overlay (room data)
- **Z1. Room data, not a gate.** Add a zone list to `RoomDef` (rect, `kind`, `effects`, optional `emitter`); keep it out of `WorldValidator.GATES`. Source: gates must match on both exit halves (`rooms.md`), zones are volumes, and Echoes/V Rising treat the harm as a place you can leave [read].
- **Z2. Kinds:** `holy` (harms undead, no effect on living by default), `safe` (truce: no spawns, no enemy entry, no holy damage, no cursed effect), `cursed` (crypt: weakens living, helps undead; mild effects only). Source: Echoes light/dark push-pull [read]; NetHack co-aligned sanctuary [read]; Nioh asymmetry [read].
- **Z3. Effects keyed on creature class tags** (`living`, `undead`, `bone`), not species ids, so the undead line's forms plug in: per-tag `{mode: dot | slow | heal | ward | repel | none, rate, knockback}`. Source: Nioh's form-dependent effect [read]; design doc undead tree [repo].
- **Z4. Full-height volume.** A holy or cursed rect runs floor to ceiling including the 20 px ceiling band, else the spider's ceiling lane (doc 5.1) and any ceiling crawler sidesteps it. Source: doc 5.1; V Rising roof rule shows the cover must be explicit [read].
- **Z5. Emitter-bound.** A zone may name an `emitter` (a priest creature, a censer, a window decor id); while it is dead or extinguished the zone is off for the life. A censer or window is switchable by a species verb at range (zip anchor, archer arrow, bone bolt, thread). Source: Nioh generator kill; NetHack priest tending altar; DS necromancer; Echoes generators [read]. Persist state per life only (doc V5).
- **Z6. Death-seed leak.** Dying to holy damage seeds a light-element next life; any gate keyed on light essence would leak, same as doc 5.3. Gate light-keyed things on a permanent eaten or evolved essence, never the seed. Source: doc 5.3; design doc seed rule [repo].
- **Z7. Validator checks (new, proposed):** (1) zone spans floor to ceiling; (2) no holy or cursed volume within 64 px of an exit span or on an arrival pad (`exit_blocked` clearance [repo]); (3) altar, glow pool, tablets and any `safe` rect never overlap `holy`; (4) on any main-lane path the longest continuous exposure between cover pockets meets the doc V4 cap; (5) every `holy` rect on a main lane has a cover pocket and a switchable emitter or a bypass; (6) a species mark on anything only one kind reaches (doc K4).

### 6.2 Holy zone hard for undead without a lock
- **H1. Damage over time, with knockback to the last safe tile, never instant kill on main lanes** (doc V3). Source: Echoes, V Rising, Soul Reaver non-lethal attrition [read].
- **H2. A grace window before damage and a visible cause.** Beams from stained-glass windows are the holy volumes; aisle shadow, pew rows and confessional alcoves between them are the cover. Source: V Rising "a few seconds", shadow/roof stops it [read]; Dead Cells warm/cold [read]; windows as landmark (SotN) [read].
- **H3. Telegraph at least 340 ms for any pulsed holy attack** (doc V6); the zone edge draws as a floor inlay line plus a light-colour change. Source: doc V6; Terraria palette signalling [read].
- **H4. Cost, not ban:** inside a beam an undead keeps moving but loses regen or drains slowly; the skeleton line is frailer, zombie/ghoul tankier, lich has a `ward` skill, vampire a speed trade, so form changes the exposure, not the access. Per-form exposure is data (a `holy_resist` stat). Source: Nioh trade; Darkest Dungeon Crusader soft counter [read]; Soul Reaver weakness overcome [read].
- **H5. Switchable and bypassable.** Every holy hall has (a) a switchable emitter and (b) an undercroft or loft route off the main lane that avoids the beam rows. The main route stays base-jump only (doc A2). Source: NetHack/Nioh/Echoes emitters [read]; doc A2/A6.
- **H6. Introduce alone, then mix:** first holy room is one beam, one cover pocket and a tablet, no priest; second adds a priest; third mixes with a shielded guard. Source: doc section 4 (introduce gimmicks individually); Nioh overuse complaint [read].
- **H7. When the player is undead the hazard reads like V Rising:** sprite desaturates and gives off wisps, a small HUD bar fills, a hit sound fires, knockback is visible; a living player sees the same beam as dressing only. Source: V Rising, Nioh smoke [read].
- **H8. Frequency cap:** at most one holy-heavy room in three inside the cathedral; relief rooms in shade. Source: Nioh "sick of seeing it" [read]; doc pacing [repo].
- **H9. Holy font = water rect with `holy` kind:** slime swims it, undead takes holy DoT, others pass. Source: `swim` gate and water rects [repo]; Echoes selective harm [read]. Hazard fairness holds because the font is never the only route.

### 6.3 Cemetery as safe zone
- **C1. Kind `safe` is a truce, not a consecration:** no spawns, enemies turn back at the boundary, holy and cursed effects are off inside, visually warm lantern or moon, not holy light, because a holy look would tell undead it hurts. In fiction the graves are protected by custom, so priests and undead both honour it. Source: NetHack sanctuary [read]; Churchyard consecrated ground [read]; RE warm lantern [snippet].
- **C2. Remove or wall off ranged attackers with line of sight to the zone,** since NetHack sanctuary still allows ranged attacks. Source: NetHack [read].
- **C3. Music and light:** calm, with "a little touch of the uneasy" so the cathedral and crypt stay in the mind. Source: RE composer [snippet]; Hunter's Dream hub function [read].
- **C4. Offers:** the cluster's altar (one per area, first-room rule [repo]), a glow pool, one lore tablet, a vista of the cathedral (gate seen before use, doc A3), and one shortcut (lift or one-way drop). Source: Blasphemous shortcuts [read]; Resting Grounds NPC lore [read]; doc A3.
- **C5. Size:** 2 or 3 rooms: lych-gate threshold (1x1), churchyard with altar and pool (2x1), mausoleum door to the crypt (1x1). Source: churchyard adjoins the church [read]; doc A4.
- **C6. Not a dead end:** two exits, never a pocket; altar within 7 screens of every gate in the cluster (doc K3, Blasphemous figure [read]).
- **C7. Decision for Sean: can an undead feed here?** Undead drain life from living creatures; a safe zone has no hostile spawns. Options: harmless fauna (predatable, non-hostile), or none (undead banks essence elsewhere). Source: design doc [repo].
- **C8. Open-sky question:** an outdoor cemetery runs into doc 5.2 (spider ceiling); the safe alternative is a churchyard cavern with a cavern ceiling, like Blasphemous' buried churches [read].

### 6.4 Species lanes [inf: marker rules K4/K5; verbs from existing doc and repo flags]
| Species | Cathedral | Crypt |
|---|---|---|
| Slime | holy font water route; squeeze beneath pews; bounce on cushion decor (check reach model, doc 5.6) | sealed niches via small gaps; coffin slide |
| Spider | nave vault ribs and clerestory crawl lane above the beams; zip across the nave using chandelier or censer anchors; can also shoot the emitter | ceiling crawl over floor traps; anchors in ossuary vaults |
| Wolf | long nave gallop; pounce over transept pit; vault pews (hard 24 px or less) | pounce over a burial pit; packs of skeleton dogs are the hazard (DS) |
| Biped | bell-tower wall jump; mantle onto choir loft; roll or slide under pews | slide under low hard crypt ceiling; mantle burial shelves |
| Undead | side aisles in shade, confessional alcoves; zombie tanks the beam; lich wards; archer extinguishes the emitter from range; skeleton uses bone ladder | cursed zone advantage (regen), dark rooms are friendly; bone creatures may be neutral to undead (see R3) |
Every gate in either hall has one species mark and one reward flag (doc K1, K4).

### 6.5 Creature roster (mapped to real flags; mark new behaviour)
- **R1. Priest (spitter):** `projectile` "holy", `contact_type` "holy" is NEW (a value beside "shock"); carries the `emitter` for a holy zone. Source: DS archers guarding a walkway [read: Den of Geek]; spitter pattern [repo].
- **R2. Shielded guard (armored_charger):** existing front block; the holy-shield version resists front tackles and charges down an aisle; the wolf-like `charges` variant for a hound. Source: `creature_def.gd` [repo]; Anor Londo sentinels [read].
- **R3. Bone walkers with revive link (the summoner pattern):** a necromancer is a stationary or slow caster whose `revive_link` re-raises nearby bone walkers unless it is dead; this is cheaper than spawning. NEW behaviour. Whether bone creatures attack an undead player is a decision; they are not living, so a draining undead cannot feed on them. Source: DS Catacombs rules [read]; design doc lich "summoning" [repo].
- **R4. Bone hounds:** low HP, high damage chargers (Skeleton Dogs [read]); pack flag [repo].
- **R5. Ghost (drifter):** existing drifter flag; holy-only or ignores walls is NEW. Source: Lich Yard ghost walls [read].
- **R6. Gargoyle (dropper or swooper):** ambush from the nave vault, telegraphed; existing swooper/dropper. Source: "Enemies coming from above are less noticeable", doc section 6 [repo].
- **R7. Revive blockers as data:** a bone creature stays down if its link is dead or if finished by a light, fire or crush effect (the "divine finish" of DS). Source: DS [read].

### 6.6 Room counts and attach rules
- Cathedral 5 or 6 rooms, about 10 to 12 screens; cemetery 2 or 3 rooms, about 4 screens; crypt 4 or 5 rooms, about 8 to 10 screens. Cluster 11 to 14 rooms, about 22 to 26 screens, roughly 50 percent of today's 23 rooms and 45 screens [repo: doc 1]; a lean cut is 5+2+4 = 11 rooms. Source: areas run 5 to 6 rooms and 9 to 14 screens [repo].
- **A1/A2/A4/A5 (doc):** two edges to existing rooms once the shortcut opens; altar and pool on the base jump; one threshold room with a cue in the previous area; every gate return route has a reward.
- **Constraint:** a link joining an early area to the cluster would bypass the main route's Swim door (F2-F3) [repo: doc section 1]; Dormans closes such loops [repo]. So the cluster's second edge is a one-way shortcut opened from the far side, after the swim door.
- **Goddess slot (decision):** the design doc ends with "a last area past the Deep ... ends in her fight"; the cathedral could be that area (priests serve the goddess who reincarnates you), colliding with the same slot the forest and volcano want [repo]. Sean decides which.
- **Fifth-altar perk:** all four perks are assigned; a cluster altar needs a fifth or shares one [repo: design doc]. Sean decides.

### 6.7 Candidate cluster layouts (screens W x H; ALT = altar, POOL = glow pool, G = gate/verb)
**A. Vertical stack off the Deep (crypt first, cathedral last)**
```
 Cathedral (up)                         Bell Shaft 1x3 (wall jump / cling / zip) -> Loft 2x1 (mantle) -> Vestry 1x1 (rare)
   Nave 3x1  (beams, shade, priests)         |
   Transept 1x1 --- Font Chapel 1x1 (slime swim, holy water)
        |                 ^ lift (shortcut, one-way down to Churchyard)
 Cemetery (middle, SAFE)
   Lych Gate 1x1 -- Churchyard 2x1 (ALT, POOL, tablet, vista of nave) -- Mausoleum 1x1
                                        |
 Crypt (below)                          Stair 1x2 -- Ossuary Hall 2x1 -- Niche Gallery 3x1 (low hard ceiling, slide, dark)
                                                      |-- Necromancer Vault 1x1 (rare, emitter)
                                        Coffin Slide 1x2 (one-way) <-- Deep D2 (3-exit room), also D6
 Return: Ossuary Hall -> one-way shortcut back to Deep, opened from the far side
```
Attach edges: Deep D2 (existing three-exit room) into the Coffin Slide, plus a one-way shortcut from the Loft down to a late Cave or Grotto ledge (closes a loop, after the swim door). Threshold: Coffin Slide with bone piles and a tablet. Base jump route: Slide, Ossuary, Stair, Mausoleum, Churchyard (ALT); the Bell Shaft, Loft and Vestry are the verb-gated side rooms [inf]. Verbs: slime font/pew gap; spider vault; wolf nave gallop; biped bell shaft; undead shade aisles.

**B. Cemetery hub with two spokes (safe hub)**
```
                Cathedral spoke:  Nave 3x1 -- Transept 1x1 -- Bell Shaft 1x3 -- Loft 2x1
                                       |
 Deep D2 -- Gate Tunnel 1x1 -- Churchyard HUB 2x1 (ALT, POOL, SAFE) -- Lych Gate 1x1
                                       |
                Crypt spoke:    Stair 1x2 -- Ossuary 2x1 -- Niche Gallery 3x1 -- Vault 1x1
                                (cursed/dark) -- Coffin Slide down to a Deep dead end D5 (one-way)
```
Attach: a new edge from D2 into the Gate Tunnel (threshold, no spawns, vista); a one-way link from the Crypt to D5 closes a loop. Three exits at the hub follow the doc's Hub archetype (3+ exits, no enemies at arrival, one sightline to a locked exit). Verbs gate the loft, the font and the vault; the base jump reaches the hub and the nave's side aisle. Hub-and-spoke risks: both spokes depend on one altar, so keep each spoke at most 7 screens from it.

**C. Ring around the church (crypt, nave, cemetery, tunnel)**
```
 Deep D2 -> Coffin Slide 1x2 -> Ossuary 2x1 -> Niche Gallery 3x1 -> Undercroft Stair 1x2 (one-way up, Old St Peter's loop)
                                                          |
 Churchyard 2x1 (ALT, POOL, SAFE) <- Lych Gate 1x1 <- Nave 3x1 (beams) <- Transept 1x1 <- Choir Loft 2x1 (mantle) <- Bell Shaft 1x3
   |                                                       ^
   +--> Tunnel 1x1 --> Deep D6 (one-way shortcut, opened from the cemetery side)
```
A ring (one cycle inside the cluster): enter through the crypt, climb through the church, exit by the cemetery and a shortcut to the Deep. The undead's easiest way is the crypt (cursed bonus) and the hardest the nave; living species find the crypt dark and the nave plain. Main route base-jump only through the shadows; the bell shaft and loft are species verbs. Source: Old St Peter's one-way circuit [read]; DS shrine/graveyard/catacomb stack [read]; doc cycles (A1) [repo].

## Sources

[read] (opened, content used; summariser output):
- https://www.gamedeveloper.com/design/economy-and-thematic-structure-symphony-of-the-night-s-level-design [read]
- https://www.gamedeveloper.com/design/how-i-blasphemous-i-level-design-iterates-on-classic-metroidvanias [read]
- https://www.playthepast.org/?p=7842 [read]
- https://www.gamedeveloper.com/design/how-the-i-hollow-knight-i-devs-mapped-out-their-metroidvania- [read]
- https://www.gamedeveloper.com/production/art-design-deep-dive-giving-back-colors-to-cryptic-worlds-in-i-dead-cells-i- [read]
- https://hollowknight.wiki.fextralife.com/Resting_Grounds [read]
- https://en.wikipedia.org/wiki/Hollow_Knight [read, one line used]
- https://darksouls.wiki.fextralife.com/The_Catacombs [read]
- https://darksouls.wiki.fextralife.com/Tomb_of_Giants [read]
- https://www.thegamer.com/dark-souls-1-fromsoftwares-magnum-opus-of-interconnected-level-design/ [read]
- https://book.leveldesignbook.com/studies/sp/undead-burg [read]
- https://www.pcgamesn.com/dark-souls-remastered/undead-burg-level-design-verticality [read]
- https://www.denofgeek.com/games/dark-souls-anor-londo/ [read]
- https://en.wikipedia.org/wiki/Bloodborne [read]
- https://www.killscreen.com/understanding-sublime-architecture-bloodborne/ [read, thin]
- https://nioh2.wiki.fextralife.com/Yokai [read]
- https://twinelab.net/blog/2020/05/29/nioh-2/ [read]
- https://terraria.wiki.gg/wiki/The_Hallow [read]
- https://nethackwiki.com/wiki/Sanctuary [read]
- https://en.wikipedia.org/wiki/Metroid_Prime_2:_Echoes [read]
- https://en.wikipedia.org/wiki/V_Rising [read]
- https://en.wikipedia.org/wiki/Legacy_of_Kain:_Soul_Reaver [read]
- https://en.wikipedia.org/wiki/Boktai:_The_Sun_Is_in_Your_Hand [read]
- https://darkestdungeon.wiki.gg/wiki/Crusader_(Darkest_Dungeon)/Strategy [read, no numbers]
- https://en.wikipedia.org/wiki/Castlevania_(1986_video_game) [read, holy water line only]
- https://www.inverteddungeon.com/index.php?section=locations&page=chapel [read, thin]
- https://www.yachtclubgames.com/blog/specter-of-torment-level-design-deep-dive-1-5/ and .../deep-dive-3-5/ [read, thin]
- https://gamerant.com/resident-evil-best-safe-room-themes/ [read, no composer quote]
- https://en.wikipedia.org/wiki/Crypt [read]
- https://en.wikipedia.org/wiki/Church_architecture [read]
- https://en.wikipedia.org/wiki/Churchyard [read]
- https://en.wikipedia.org/wiki/Catacombs [read, thin]
- https://en.wikipedia.org/wiki/Cave_Story , https://en.wikipedia.org/wiki/Salt_and_Sanctuary , https://en.wikipedia.org/wiki/Ender_Lilies:_Quietus_of_the_Knights [read, nothing on safe areas or sanctuaries; one Cave Story design line used]
- https://gmtk.substack.com/p/the-world-design-of-hollow-knight [read; it is about Silksong, nothing used]
- https://en.wikipedia.org/wiki/Dracula's_Castle_(Castlevania:_Symphony_of_the_Night) [read, no area detail]

[snippet] (search-result text only):
- https://www.gamesradar.com/castlevania-symphony-night-designed-upside-down/ ; https://deadcells.wiki.gg/wiki/Ossuary ; https://deadcells.fandom.com/wiki/Biomes (Graveyard, Ossuary)
- https://bloodborne.wiki.fextralife.com/Hemwick_Charnel_Lane (Cathedral Ward, Hemwick)
- https://darksouls.fandom.com/wiki/Skeleton ; https://medium.com/@bramasolejm030206/preface-ec08bc1459d0 (catacomb modularity)
- https://blasphemous.fandom.com/wiki/Mother_of_Mothers (Seville, rose windows)
- https://diablo.fandom.com/wiki/Consecration_(Diablo_III) ; https://diablo.fandom.com/wiki/Blessed_Hammer_(Diablo_II) (+50% to undead)
- https://dungeonkeeper.fandom.com/wiki/Graveyard ; https://dungeonkeeper.fandom.com/wiki/Vampire
- https://ghostsngoblins.fandom.com/wiki/Ghosts_'n_Goblins_Stage_1
- https://ender.fandom.com/wiki/Cathedral (two floors, blight clouds)
- https://www.pcgamer.com/the-art-of-crafting-the-perfect-videogame-safe-room/ (Uchiyama quote, page body truncated)
- https://www.metroidwiki.org/wiki/Safe_Zone ; https://www.metroidwiki.org/wiki/Light_Crystal (403 on fetch; light hurts Ing, one heal per second)
- https://cavestory.fandom.com/wiki/Mimiga_Village ; https://www.trillmag.com/entertainment/gaming/safe-havens-the-role-of-hub-areas-in-rpgs/ (403)
- https://www.pcgamer.com/games/action/monster-hunter-wilds-pop-up-camp/ ; https://en.wikipedia.org/wiki/Monster_Hunter:_World (camps)
- https://hollowknight.fan/areas-and-exploration/what-is-dirtmouth (Dirtmouth as safe zone)

Fetch failures (skipped, not retried): n4g.com Anor Londo (403), medium.com Jamesroha (403), metroidwiki.org (403), trillmag.com (403), galaron.substack.com safe havens (404), PC Gamer safe-room (truncated).

Not found [gap]: a designer write-up on holy zones or fairness for a hurt class; stained glass as a 2D level-design device; pews as platforms; finished-stone versus cave tile switching; Hemwick, Cathedral Ward, City of Tears, Soul Sanctum, Salt and Sanctuary and Monster Hunter design rationale; ossuary and burial-niche level design; sound or banner cues for holy zones.
