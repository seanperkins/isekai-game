> Unedited agent notes. Where they conflict with `../area-level-design.md`, that document wins.
> Note: these notes frame the area after the Deep as contested. Sean confirmed (2026-10-04) that everything is added and nothing replaced; see section 15 of the main document.

# Demon area research for Isekai Chronicles (how it differs from the volcano)

Tags: [read] page fetched and read; [snippet] search-result summary only; [inf] my inference (source named); [gap] searched, nothing usable. WebFetch summarises pages with a small model: every quoted phrase below is that summary's wording, none was re-fetched verbatim, so none is marked exact. Not repeated from the main doc: lava, heat gates, Norfair, Boneforest, Blasphemous' seven-screen checkpoints. Repo facts used [read, local]: docs/isekai-chronicles-design-doc.md and the main doc's engine facts (section 5: 20 px ceiling, 133 of 172 solids one-way, spider bypass, death seed).

## 1. Precedents and which have written rationale

Written designer rationale found (strongest first):
- **SotN Inverted Castle.** Igarashi's stated reason: the designers wanted "to add more content in a way that would be easier than creating new assets", and "the castle was designed in such a way that it works in both orientations" [read: Wikipedia Inverted Castle; same lines in Wikipedia Dracula's Castle (SotN)].
- Igarashi on intent: "people wouldn't defeat Dracula on their very first playthrough; we wanted them to defeat Richter once"; the intended journey was to aim for 100% on the normal castle and in doing so "discover the inverted castle and feel like they'd found something special"; total map is "200.6%" (100% + 100% + the 0.6% waterway) [read: shmuplations SotN interview].
- CONFLICT, unresolved: Wikipedia says the Inverted Castle is hidden until Alucard defeats Shaft with holy glasses [read: Wikipedia Inverted Castle]; Wikipedia's SotN page says it is revealed after beating Richter and breaking the spell [read]; the shmuplations summary read like a 100%-completion requirement, which I take as the small model blending "intent" with "rule". Cite Wikipedia for the unlock, shmuplations for intent.
- Content of the flip: separate map, same layout upside down, new enemies and items, five Dracula pieces to collect, zombie Trevor, Sypha and Grant [read: Wikipedia Inverted Castle, SotN].
- Verdict on it: "almost directionless nature" that pushes thorough exploration, "may not be as well designed on a whole as its main castle counterpart" but strong in "atmosphere, novelty, and non-linearity" [read: goombastomp]. Critics split: "triumph of level design" versus "constant transformations" and difficulty "achieved through being annoying" [read: Wikipedia Inverted Castle]. A Game Developer level-design essay calls the way it was made "lazy" in one phrase and defers analysis [read: gamedeveloper SotN economy].
- How the flip handled gates, one-way platforms or room-by-room changes: [gap]. A search summary says it drops ability locks and is freely explorable from the start [snippet, origin unclear, do not rely on it]. Igarashi's "you have to explain that through the story" line is [snippet].
- **Dark Souls, Demon Ruins / Lost Izalith.** Miyazaki: the demons are "based around the idea of Chaos", the team "decided on an oriental theme" with Angkor Wat as a reference; "my greatest regret is the Bed of Chaos", which "exposed a real problem in our production method" because "we had no way to find a common goal and work towards it when things went wrong"; an earlier plan had King Izalith on a throne with the Bed of Chaos sprawled at his feet [read: soulslore Design Works translation]. Lost Izalith was "a rushed zone" and Miyazaki admitted most of its shortcomings in Giant Bomb interviews [read: gamerant, only these two facts]; copy-pasted enemies [snippet]. Lesson [inf, from these two]: a "chaos" theme with no mechanic and no clear boss concept is what failed; a theme is not a rule.
- **A Link to the Past, Dark World.** Miyamoto: "At first there were 3 worlds, but players would've gotten confused"; Nakago: "I ended up just making one, but it was split into two and reborn" [read: glitterberri staff interview]. The Dark World is "a copy of the whole map of Hyrule (missing a few small areas...)" [read: Source Gaming]; stored as an "overlay" of the Light World with different tile art [read: Wikipedia ALttP]. Tezuka on the bunny form: wanted "a striking distinction" in how Link looks [read: nintendoeverything]; the Moon Pearl removes it [snippet].
- **Hades, Tartarus.** Gorinstein: "medium-sized chambers that are almost always completely walled in", merciful to players learning the cast, with extra wall-slam damage; small chambers early in a biome, larger later "reflective of the escalating encounters" [read: Kotaku, pvplive]. The Pact of Punishment raises attack, health or enemy count and alters boss fights [read: Wikipedia Hades]. Kasavin: an early goal was "to take the pain out of dying" [read: gamedeveloper Hades narrative].
- **Ghosts 'n Goblins.** After the final boss you learn you were "tricked by Satan" and must replay the whole game at higher difficulty; Fujiwara watched testers and reworked levels and enemies so their strategies stopped working [read: Time Extension]. Resurrection: "the second loop is a very different experience", the Demon Realm "transforms" and enemies and obstacles "change drastically" [read: Shacknews].
- **Blasphemous.** Art draws on Seville's Holy Week, Goya's flagellants, Roman Catholic imagery fused with body horror [read: Wikipedia Blasphemous]. Colinet (level designer): bosses sit near shortcuts so "I want players to beat the boss and go straight to wherever they want to be"; levers were "overused" [read: gamedeveloper]. Cabeza on art feeding level and enemy design in a cycle [snippet].
- **Zelda, Ganon's Castle (OoT).** Gothic form "an insult and mockery of the Three Goddesses", floats above "an abyss of churning fire", six trials as "microcosms of their respective temples" around a hexagonal tower [read: architectureofzelda]. Ganon's Tower in ALttP: [gap].
- **Cave Story, Blood-Stained Sanctuary ("Hell").** Hidden in the Balcony, weapons reset to level 1, "NO CHECKPOINTS IN THE ENTIRE LEVEL", three stages of instant-kill red spikes, debris and enemy waves, bosses Heavy Press and Ballos, and it is the route to the true ending [read: atrociousgameplay wiki]. Unlock items (Booster 2.0 and Iron Bond) [snippet].

No design rationale found: Hollow Knight Abyss and Black Egg Temple (only lore; the unbuilt Abyss expansion was dropped because the world "was built without considering this expansion" [snippet]); Cuphead's Inkwell Hell layout; Bloodstained's areas; Doom's Inferno; Diablo's Hell levels; Dead Cells (no hell area) [gap]. Vocabulary only, no rationale: Diablo descends cathedral, catacombs, caves, then Hell, "each with a mixture of the undead, animals, and demons", catacombs "long corridors and closed rooms", caves "non-linear" [read: Wikipedia Diablo]; Diablo II's Chaos Sanctuary on a stone in lava ringed by rivers of blood [snippet]; Hall's rejected Doom concept "hell steadily infects the level design" [read: Wikipedia Doom 1993]; Doom 2016 Hell "more atonal, dissonant and weird" in the score [read: Wikipedia Doom 2016].

## 2. What makes a demon area distinct, and what is cheap and fair

Distinct from lava (the volcano's hazard is an ambient or contact damage rect gated by a resist, per the volcano notes [read, local]):
- Demon areas in the sources are defined by rules that attack choice and trust, not by temperature: pacts and curses (Dead Cells, Hades, Cuphead's contracts [read]), spawners (Gauntlet [read]), false walls (Dark Souls [read]), a second pass with changed enemies (SotN, Harmony of Dissonance, GnG [read]), corruption that spreads (Terraria [read]).
- Fire is set dressing in the best-documented evil fortress: Ganon's Castle floats above churning fire [read]. [inf, Ganon's Castle plus the volcano's seed rule]: keep demon fire in parallax only, never on the hazard layer, so the fire seed stays tied to the volcano.

| Mechanic | Precedent | Cost here [inf] | Fair? [inf] |
|---|---|---|---|
| Destroyable demon gate (spawner) | Gauntlet generators "can be destroyed" [read]; Emitter with "an infinite supply" [read: Build a Bad Guy] | low: one entity, wave cap, a persistent flag | yes if telegraphed (>= 340 ms, volcano V6) and finite |
| Taint zone rect (corruption) | Terraria thorny Corruption, chasms, spread [read]; Blasphemous Guilt marker [read] | low if it shares one zone system with heat and holy | yes if it costs a resource, not HP, and has a ward refuge |
| Curse status with a visible clear condition | Dead Cells: 10 points from a chest, "killing enemies reduces the total points by one", near-everything kills while cursed [read] | medium: a status plus a counter | only if not one-hit-death (see section 6) |
| Optional pact altar | Hades Pact, Chaos Gate health cost that converts to a boon after 2 to 5 encounters [snippet]; Dead Cells chest [read] | low: an interactable that sets a flag | yes: opt-in |
| False wall | Dark Souls: hit or roll to remove, hints by sound, light or a message, hides covenants, shortcuts, rare gear and areas [read]; DS1 hinted, DS2 often did not [snippet] | low: tile flag plus reveal verb | yes only on side rooms with a hint; never on the spine |
| Overlay room (same geometry, new tiles and spawns) | ALttP Dark World overlay [read] | medium | yes |
| Literal vertical flip | SotN [read] | HIGH: one-way ledges flip (133 of 172 solids are one-way, main doc 5.4), water and exits flip, base-reach pass reruns | risky |
| Possession / infection | Hollow Knight Infection "control the minds of bugs, driving them to madness and undeath" [read: Wikipedia Hollow Knight] | medium: a state swap on an enemy | yes if telegraphed |
| Temptation pickup (taunting reward with a cost) | Dead Cells chest's taunt [snippet]; Cuphead soul contracts [read] | low | yes: opt-in |

Cheap and fair, in order [inf, from the table's sources]: destroyable gates, taint zones sharing the zone system, optional pact altars, false walls on side rooms, overlay rooms. Expensive: literal inversion, curse-as-instant-death.

Non-heat hazard vocabulary seen in sources [read unless marked]: thorny growth and vertical chasms (Terraria Corruption); instant-kill spikes, falling debris (10 damage), lightning (Cave Story Sanctuary); wall slams against enclosing walls (Hades Tartarus); spreading biome that "cannot overlap" its holy opposite (Terraria); a death-location marker that cuts a resource (Blasphemous Guilt); curse status (Dead Cells); rivers of blood [snippet: Diablo II].

## 3. Enemy ecology and archetypes

- Behaviour contrasts [read: gamedeveloper Doom 2016]: after iteration "demons, except for melee demons, should hold their position" and too many melee demons "lose that feeling of combat chess"; players need to read each demon "by how they look like and what I know they do". [inf]: demon rosters read as roles (rusher, holder, caller), cave rosters as animals.
- Tartarus examples: Wretched Thug slow, charged heavy swing that lunges forward; Wretched Lout fast long rushing charge; Bloodless hop away from ranged fire; Inferno Bomber throws bombs [snippet: search summary of Hades wikis]. No design interview on Hades enemy roles [gap].
- Movement and ability vocabulary [read: Build a Bad Guy, gamedeveloper]: stationary, walker, floater, waver, jumper, dasher, teleporter, shielder ("attacks nullified when hit from a specific direction"), emitter, thrower; "Most well-designed enemies are made up of multiple attributes, and use triggers to switch between conflicting attributes". That last line is the only sourced basis for summon-on-low-HP; no source on it directly [gap].
- Ranged enemies make "your level design … start to matter" (cover, elevation) [read: Level Design Book enemy page]. That page lists no teleporter, charger, spawner or summoner [read].
- Teleport with a fake-out: Hollow Knight's Soul Master teleports above the player to slam and can fake it with a second teleport; phase two shatters the arena floor [snippet].
- Possession: Infection turns bugs mad and undead [read]; the Pale King locked the other Vessels "in a pit called the Abyss" [read: Wikipedia Hollow Knight].
- Eat-the-demon: Bloodstained shards come from monsters and "reflect the essence of the monster" [read: Wikipedia Bloodstained]. [inf]: matches the essence-eating loop; a demon that grants a power only when eaten at a seal is a reward fit.
- Terraria Corruption roster: Eater of Souls, Devourer, Corruptor, World Feeder; boss Eater of Worlds [read]. Demon gates as spawners: Gauntlet's ghosts, demons and grunts enter "through specific generators" [read].
- Staging of bosses and minibosses [read unless marked]: Hades gives Tartarus one of the three Furies as its boss; Cave Story's Sanctuary is a gauntlet of waves then Heavy Press then Ballos with no checkpoint; Blasphemous parks bosses near shortcuts; GnG puts Firebrand in stage one to "set the tone"; Hollow Knight's Godhome chains bosses with no deaths and ends on a harder Absolute Radiance; Dark Souls' Bed of Chaos is the cautionary case. [inf]: a demon area boss should sit beside the shortcut that closes the loop (Blasphemous) and be fully authored, not a placeholder (Bed of Chaos).

## 4. Structural ideas worth stealing

| Idea | Precedent [read] | What it costs in a fixed world with persistent shortcuts and species lanes [inf] |
|---|---|---|
| Flipped second pass | SotN: same layout upside down, separate map, new enemies and items | every room re-authored and re-linted; gate and reach tables redone; fails the "reuse is cheap" premise here because one-way ledges and water flip |
| Overlay world | ALttP: copy of the map with some small areas missing, different tiles; "some shortcuts become blocked while others emerge" [read: Source Gaming]; enter by portal, leave only by Magic Mirror | cheapest faithful version: a room list that names `variant_of` an existing room with new tiles, spawns and hazard rects; exits stay in the same cells |
| Two versions that share state | Harmony of Dissonance: "mostly the same room layout, but monster types, items, and other aspects vary"; "the destruction of a wall in one castle can cause a change in the other"; warp rooms [read: Wikipedia] | the best fit for persistent shortcuts: one flag opens the shortcut in both versions |
| Post-event transformation | GnG Resurrection: Demon Realm "transforms" after the final stage [read]; SotN after Shaft [read] | maps onto "an area that appears only after a story event"; a world flag flips a room set |
| Remix trials around a locked core | Ganon's Castle: six short trials, each a "microcosm" of an earlier temple, around one barrier [read] | reuse room templates, not rooms; one trial per earlier area, each sealing one gate |
| Optional hell gauntlet | Cave Story Sanctuary: hidden, weapons reset, no checkpoints, gates the true ending [read] | too punishing here (death returns to an altar); keep it to a rare room |
| Visible seal opened by N sub-goals | Ganon's six barriers around one core [read]; Black Egg Temple sealed by three Dreamers [snippet: search summary; the Wikipedia page only mentions the temple's "seals"] | the base-jump gate opens the boss door; verb gates open a shortcut and a rare room; shows the lock early (main doc A2, A3) |

- Nest of Evil (Portrait of Ruin): bonus area unlocked at 888% map, 7 levels of 6 rooms, mostly reused assets [snippet: search summary; StrategyWiki 403, Wikipedia page has nothing]. Unverified; do not rely on the numbers.
- [inf, main doc K1 and A1]: any shortcut a demon area opens must write a flag that persists across deaths; attach with at least two edges once open; reuse via overlay of 2 to 3 rooms is the affordable second pass.
- [inf, design doc "Cross-run world state"]: the design doc already allows "one form can change the world for a later one", which is the Harmony of Dissonance shared-state pattern.

## 5. Relationships

- Opposed zones: Terraria's Corruption "is unable to overlap the Hallow"; the Hallow is "an extreme overcompensation of purity ... to counterbalance" evil; Corruption is dark purple with thorns, Hallow pastel with a rainbow [read: Terraria wiki Hallow, Corruption]. That is the only opposed-zone precedent I could read. Holy zones that hurt demons or undead as a documented design: [gap] (one search attempted, refused: session search budget exhausted).
- Faction signalling in art [read]: Ganon's Castle uses Gothic arches and spires so the evil seat mocks the holy ("blasphemous") shape; ALttP's Dark World is the same map with "polluted" water, trees with "faces contorted in pain" and skull rocks [read: Source Gaming]; Blasphemous fuses Roman Catholic imagery with body horror [read: Wikipedia Blasphemous], so the holy iconography is itself the horror [inf]. [inf]: the goddess reveal can make the holy palette the antagonist's, so "holy equals safe" must not be taught by art alone. This depends on an undecided slot.
- Placement precedents: Hades makes the hell biome first [read]; Diablo goes church, catacombs, caves, Hell [read]; Dark Souls puts Lost Izalith "even deeper than Blighttown" [read: Wikipedia Dark Souls]; ALttP's Dark World follows Agahnim [read]; Cave Story's Sanctuary sits behind the final act [read]; SotN's inversion follows the first ending beat [read]. [inf]: late, after a story beat, is the dominant pattern; early hell (Hades) works only when the whole game is hell.
- Collisions with open slots, flagged not resolved [inf, design doc lines 26, 186, 249 and the main doc section 9]:
  - The slot below the Deep now has four claimants: the volcano's Layout A, this area, the design doc's "last area past the Deep" (what it holds is still open), and the planned crypt off the Deep. The Serpent Lair is also unbuilt.
  - Blood: the design doc ties blood essence to the vampire at the top of the flesh path and lists blood as a later element; a demon area that hands out blood collides with that.
  - Dark essence is in the first pass and "feeds undead" (curses, death); a gate keyed on dark is opened by dying to a demon (death seed leak, volcano V2 logic).
  - Undead and demon: if demon zones hurt the holy, the light-path goblin (paladin) is penalised and undead may be favoured. Open.
  - Which side the goddess is on decides how holy and demon art signal factions. Open.
  - The final area's unlock is "the reveal"; an overlay or post-event demon realm could reuse that same flag, or compete with it.

## 6. Rules for this game [inf, each cites its source]

**D1 The area's one new rule: sealed gates.** A demon gate is a spawner that emits a finite number of waves and is closed by one deliberate act; closing it writes a persistent flag. Sources: Gauntlet destroyable generators [read]; Emitter [read]; Ganon's six barriers [read] and the Dreamers' seal [snippet]; main doc K1 (persistent rewards). It is fire-free, so it does not overlap the volcano's heat rule.
**D2 One shared zone rect.** The engine has no zone system. Propose one `zone` object with `kind` in {heat, holy, taint}; the volcano, cathedral and demon area share it (main doc rule against parallel schemes). Taint costs a resource and refuses rest, not HP (Terraria spread; Blasphemous Guilt [read]); a `ward` rect is the refuge.
**D3 Hazard vocabulary as room data** (field names are placeholders):
- `spawn_gate {pos, waves, max_alive, telegraph_ms >= 340, seal: attack|species_verb, flag}`: telegraph floor from Dark Souls 3's 340 ms (volcano V6 [read, local]).
- `zone {rect, kind: taint, effect: inert_pool|no_regen|slow_remains, ward_ref}`: spider note, a floor taint is crossable on the 20 px ceiling unless the ceiling band is tagged (main doc 5.1).
- `curse {source: pact_item, clear: kills_n|glow_pool, effect: max_hp_cut}`: Dead Cells' kill-count clear [read]; NOT one-hit death, because a death costs an altar walk here. Guilt-style markers overlap the existing remains system and the Flooded altar's slower-decay perk: do not add a second marker.
- `false_wall {reveal: hit|roll|verb, hint: sound|light|crack}`: Dark Souls hints [read]; side rooms only; the reveal verb must be one the species can do.
- `pact {offer, cost, flag}`: optional, Hades/Dead Cells opt-in [read]; reward persists via K1.
- `seal_door {needs: [flag...]}`: the boss door lists only the base-jump gate's flag; the verb gates' flags open a shortcut link or the rare room (main doc A2). Precedent: Ganon's Castle [read], Black Egg Temple [snippet].
- `variant_of: room_id`: overlay room (ALttP [read]).
- Every lethal hazard names `seed_element` (volcano V7). Taint and demon creatures seed dark; fire stays volcano-only; blood is not seeded (later element). A gate keyed on dark or light essence must key on the permanent essence, not the seed.
**D4 Species lanes.**
- Slime: the timed rebound reaches about 1.6x the base rise (main doc 5.6), so a gate's seal point can sit high; slime devours items (design doc), so digesting a `pact_item` can clear its curse [inf].
- Spider: zip to a seal point across a taint strip; crawl the ceiling unless it is tagged taint (main doc 5.1).
- Wolf: gallop a taint strip before its effect ticks (a clock, like the volcano's V4); pounce a gate's telegraphed wave; vault low lips.
- Goblin: roll through a telegraphed glyph burst (check i-frames cover the active window, volcano R8); mantle onto a seal ledge; wall-jump shafts. Light essence "redeems upward" (goblin to paladin, design doc), so a light-keyed seal is a possible lane; it also ties to the opposed-zone idea (Terraria Hallow [read]).
- Undead: skeletons graft parts and drain life force (design doc). OPEN QUESTION: are demons hostile to undead? Two options, both flagged. (a) Taint harms the living and holy harms the undead and demons, a symmetrical pair, so undead cross taint for free; (b) demons treat undead as allies, so some gates stay inert for them. Decide with the goddess's side.
**D5 Creature roster** tied to existing archetypes (names placeholders; each one attribute plus one trigger, per Build a Bad Guy [read]):
- Charger "hound": dasher with a >= 340 ms wind-up, holds off until the player enters its room.
- Spitter "imp": ranged bolt, holds position (Doom 2016 [read]); a variant applies a `curse` stack instead of HP damage.
- Summoner "caller": emits imps only while its glyph is lit; killing it or the glyph closes one gate.
- Shielded "ward-bearer": nullifies hits from one direction (Shielder [read]); breaks to the species verb that reaches its back.
- Teleporter "blinker": short hop with a fake-out after a hit (Soul Master [snippet]); at most one per room.
- Possessor "rider": takes over a dormant corpse or armour (Infection [read]); at most one per area, telegraphed.
- Roster size follows Shovel Knight's "about 5 enemies and 5 objects" per level (volcano notes, S24); no unitaskers.
**D6 Room counts and sizes.** [inf, main doc section 8: areas run 5 to 6 rooms and 9 to 14 screens] 6 to 7 rooms, 10 to 13 screens, one threshold room, one altar room, one rest pool, one rare room, 3 gates, 1 boss. An overlay variant needs 3 to 4 rooms, about 5 to 8 screens.

### Layout A "Three Seals", hub and spokes (7 rooms, 13 screens; W x H screens; room IDs DG0 to DG6)
```
 [Crypt or Cathedral exit]  JUMP
        |
  DG1 Threshold 1x1  tablet, red-black palette, no spawns, no taint (main doc rule A4)
        |
  DG0 Gate Hall 3x1  altar + rest pool; three sealed gates visible from the start;
     |        |         |   seal_door to DG5 needs ONLY the Middle flag
   DG2 West  DG3 Middle  DG4 East     each 2x1: one spawn_gate, a taint strip, a ward
   (ZIP)     (JUMP)      (POUNCE/ROLL)
     |          |          |
     |          +--> DG5 Throne 1x2  boss "caller"; door opens on the Middle flag (base jump only)
     |                |
     +-- West flag opens a link DG5 -> DG0 (shortcut, no room)       East flag opens DG6 Reliquary 1x1 (rare room)
```
Attach: off the crypt (planned) or past the cathedral. Main route, base jump only: DG1, DG0, DG3, DG5 (main doc A2: verbs open only a shortcut and a rare room). DG2's and DG4's gates are reached by a verb route; sealing each writes a persistent flag (D1, main doc K1), so the shortcut and the rare room stay open on later lives. Screens: 1 + 3 + 2 + 2 + 2 + 2 + 1 = 13. Precedent for the shape: Ganon's six barriers around one core [read]; the Dreamers' three seals are [snippet] only. Risk: three gates visible from the first screen is good (main doc A3), but the verb routes to DG2 and DG4 need a base-jump-reachable look at each seal first.

### Layout B "Mirrored Pass", overlay of 2 existing rooms plus 2 new ones after the reveal (4 rooms, about 6 screens: X' and Y' inherit their originals' size, assumed 2 each, Z' and W' 1 each)
```
 [existing room X] --reveal flag--> X' (variant_of X, taint zone, spawn_gate, false_wall)
        |                                    |
 [existing room Y] -----------------> Y' (variant_of Y)  --- Z' ---> W' 1x1 altar
```
Same exits and cells as the originals (ALttP overlay [read]); the flag is the reveal; a shortcut opened in X' also opens in X (Harmony of Dissonance [read]). Attach: over the Deep, reusing D-rooms, then a one-way drop into the last area slot. Cheapest, collides most with the last-area slot. Risk: one-way ledges and water rects must be re-checked per variant (main doc 5.4).

### Layout C "Pact Descent", linear with two optional pact rooms (7 rooms, 10 screens; room IDs P1 to P7)
```
 [Deep bottom, or cemetery]  JUMP
        |
  P1 Threshold 1x1 -> P2 Nave 2x1 (spawn_gate, taint) -> P3 Shaft 1x2 (false_wall, ward)
                                   |                            |
                         P4 Pact Room 1x1 (opt, curse)   P5 Pact Room 1x1 (opt, rare part)
        P6 Altar 1x1 -> P7 Boss 1x2 "caller" -> one-way drop to P2 (shortcut)
```
Screens: 1 + 2 + 2 + 1 + 1 + 1 + 2 = 10. The route P1, P2, P3, P6, P7 is base jump only; both pact rooms and the false wall are side content.
Attach: off the Deep bottom conflicts with the volcano's Layout A; the cemetery or crypt is cleaner. Precedent: Hades' pact and Dead Cells' chest as opt-in cost [read]. Risk: the weakest placement precedent (hell first), strongest cost-fairness precedent.

Attachment options: (1) off the crypt, after the cathedral (Diablo order [read]); (2) over the Deep after the reveal (SotN, ALttP [read]); (3) a rare room behind a gate off the Deep (Cave Story [read]). Any of these touches the last-area slot (section 5).

## Sources

[read] fetched and read:
- https://shmuplations.com/symphony/ [read]
- https://en.wikipedia.org/wiki/Inverted_Castle [read]
- https://en.wikipedia.org/wiki/Dracula%27s_Castle_(Castlevania:_Symphony_of_the_Night) [read]
- https://en.wikipedia.org/wiki/Castlevania:_Symphony_of_the_Night [read]
- https://goombastomp.com/symphony-of-the-night-inverted-castle/ [read]
- https://www.gamedeveloper.com/design/economy-and-thematic-structure-symphony-of-the-night-s-level-design [read]
- https://en.wikipedia.org/wiki/Castlevania:_Harmony_of_Dissonance [read]
- http://soulslore.wikidot.com/das1-design-works/ [read]
- https://gamerant.com/dark-souls-development-facts-trivia/ [read]
- https://en.wikipedia.org/wiki/Dark_Souls_(video_game) [read]
- https://darksouls.wikidot.com/illusory-wall [read]
- https://kotaku.com/hades-level-design-is-less-random-than-it-seems-1845254545 [read]
- https://pvplive.net/supergiant-games-designer-explains-hades-level-design/ [read]
- https://en.wikipedia.org/wiki/Hades_(video_game) [read]
- https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death [read]
- https://glitterberri.com/a-link-to-the-past/the-men-who-made-zelda/ [read]
- https://sourcegaming.info/2023/11/20/center-stage-the-dark-world-the-legend-of-zelda-a-link-to-the-past/ [read]
- https://en.wikipedia.org/wiki/The_Legend_of_Zelda:_A_Link_to_the_Past [read]
- https://nintendoeverything.com/nintendo-on-why-link-turns-into-a-rabbit-in-a-link-to-the-pasts-dark-world-non-zelda-characters-in-links-awakening/ [read]
- https://www.architectureofzelda.com/ganons-castle.html [read]
- https://www.timeextension.com/features/the-haunting-history-of-capcoms-ghosts-n-goblins-series [read]
- https://www.shacknews.com/article/122423/yes-ghosts-n-goblins-resurrection-will-require-two-playthroughs-but-with-a-twist [read]
- https://www.gamedeveloper.com/design/how-i-blasphemous-i-level-design-iterates-on-classic-metroidvanias [read]
- https://en.wikipedia.org/wiki/Blasphemous_(video_game) [read]
- https://en.wikipedia.org/wiki/Hollow_Knight [read]
- https://en.wikipedia.org/wiki/Cuphead [read]
- https://en.wikipedia.org/wiki/Bloodstained:_Ritual_of_the_Night [read]
- https://deadcells.wiki.gg/wiki/Curse [read]
- https://terraria.wiki.gg/wiki/The_Hallow [read]
- https://terraria.wiki.gg/wiki/The_Corruption [read]
- https://en.wikipedia.org/wiki/Gauntlet_(1985_video_game) [read]
- https://www.gamedeveloper.com/design/build-a-bad-guy-workshop---designing-enemies-for-retro-games [read]
- https://book.leveldesignbook.com/process/combat/enemy [read]
- https://www.gamedeveloper.com/design/-make-me-think-make-me-move-new-i-doom-i-s-deceptively-simple-design [read]
- https://en.wikipedia.org/wiki/Doom_(2016_video_game) [read]
- https://en.wikipedia.org/wiki/Doom_(1993_video_game) [read]
- https://en.wikipedia.org/wiki/Diablo_(video_game) [read]
- https://atrociousgameplay.miraheze.org/wiki/Blood_Stained_Sanctuary_(Cave_Story) [read]
- docs/isekai-chronicles-design-doc.md, docs/research/area-level-design.md, docs/research/area-level-design-notes/volcano.md [read, local]

Fetched, nothing on topic (not counted as evidence): https://80.lv/articles/the-game-kitchen-on-creating-original-blasphemous ; https://www.gamesradar.com/castlevania-symphony-night-designed-upside-down/ (truncated); https://www.gamedeveloper.com/design/-i-castlevania-i-s-koji-igarashi-offers-advice-to-today-s-metroidvania-devs ; https://en.wikipedia.org/wiki/Castlevania:_Portrait_of_Ruin ; https://en.wikipedia.org/wiki/Development_of_Doom (one line on Petersen). Failed: zeldauniverse.net Miyamoto interview (403), cavestory.fandom.com (402), strategywiki Nest of Evil (403).

[snippet] search-result summaries only:
- Igarashi "explain that through the story": search summary of https://groups.google.com/g/alt.fan.nb/c/MKYmUPKsZxw/m/8U8cEbD69IoJ [snippet]
- Inverted Castle ability-lock claim: search summaries (GameFAQs, TV Tropes class) [snippet]
- Giant Bomb Miyazaki interviews on Lost Izalith: via search summaries and https://gamefaqs.gamespot.com/boards/606312-dark-souls/66151087 [snippet]
- Illusory-wall fairness in DS1 vs DS2: https://steamcommunity.com/app/236430/discussions/0/558756256212317762 [snippet]
- Hades Tartarus enemies: https://hades.fandom.com/wiki/Wretched_Thug and https://hades.fandom.com/wiki/Wretched_Lout [snippet]
- Hades Chaos Gate: https://hades.fandom.com/wiki/Chaos_Gate and https://www.thegamer.com/hades-chaos-guide/ [snippet]
- Blasphemous art cycle (Cabeza): https://www.pockettactics.com/blasphemous-2/interview [snippet]
- Cuphead devil design, Moldenhauer quote: https://cuphead.wiki.gg/wiki/The_Devil and https://comicbook.com/gaming/news/cuphead-chad-jared-moldenhauer-interview/ [snippet]
- Hollow Knight Abyss expansion: https://hollowknight.wiki/w/The_Abyss_(Hollow_Knight) and Team Cherry interviews [snippet]
- Soul Master: https://hollowknight.fandom.com/wiki/Soul_Master and https://rogueranker.com/soul-master-hollow-knight/ [snippet]
- Diablo II Act 4: https://diablo.fandom.com/wiki/Chaos_Sanctuary [snippet]
- Cave Story Sanctuary unlock: https://steamcommunity.com/sharedfiles/filedetails/?id=942144318 [snippet]
- Nest of Evil: https://castlevania.fandom.com/wiki/Nest_of_Evil and https://strategywiki.org/wiki/Castlevania:_Portrait_of_Ruin/Nest_of_Evil [snippet]
- Moon Pearl removes the bunny form: https://zeldauniverse.net/2019/07/01/tezuka-explains-why-he-gave-link-a-bunny-form-in-a-link-to-the-past/ [snippet]

Not found: written rationale for Hollow Knight's Abyss or Black Egg Temple, Cuphead's Inkwell Hell, Bloodstained's areas, Doom's Inferno, Diablo's Hell, Dead Cells' hell; how SotN's Inverted Castle was re-gated or re-authored; a design source on holy zones hurting demons or undead; summon-on-low-HP as a documented pattern; Hades enemy-role interviews.
