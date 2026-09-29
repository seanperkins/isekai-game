# Metroidvania reference: abilities and enemies for the slime game

Scope and honesty: every entry below comes from pages I fetched or from web-search result summaries (tagged in section 6). Blocked sites (Fandom wikis, hollowknight.wiki, metroidwiki.org, StrategyWiki, GameFAQs, Neoseeker) returned 402/403, so several games rest on search summaries only. "Slime fit" and all of section 5 are my design inferences, not sourced facts. Items marked (?) are uncertain or came from a single summary.

## 1. ABILITIES

### 1a. Movement

| Ability | Games | What it does | Gate / level use | Slime fit |
|---|---|---|---|---|
| Double jump | HK Monarch Wings; Ori Double Jump (~50% more height, 100% more distance than jump 1); Aria "Malphas" ability soul; SotN Leap Stone; Metroid Space Jump (jump again at apex); Guacamelee Rooster Uppercut (short double jump) | Extra mid-air jump | Tall shafts, wide gaps | flight essence (bat, spore moth); or as Leap's evolution |
| Dash | HK Mothwing Cloak (ground or air); HK Shade Cloak (dash through enemies and attacks without damage); Ori Dash (~0.5 s); Guacamelee Dashing Derpderp; S&S "Dark Brand" (name uncertain, search said "Dart") air dash; ESA dash; Blasphemous 2 air dash; Dread Flash Shift (teleport-dash, up to 3 in a row) | Burst of horizontal speed | Wider gaps; Flash Shift also crosses pressure-plate doors and sensor doors | water essence: Hydraulic Propulsion / Jet Dash already |
| Wall jump / cling / climb | HK Mantis Claw; Ori Wall Jump + Climb (climb lets you charge-jump from walls); Super Metroid wall jump (spin toward wall, press away, chainable); Dread Spider Magnet (blue magnetic surfaces only); Dead Cells Spider Rune; S&S Shadowflip Brand; Blasphemous 2 ivy walls | Stick to or push off walls | Vertical shafts; surface-restricted climbing (magnet walls, ivy) | Wall Cling exists; add a surface-restricted "thread/sticky wall" variant |
| Glide | Ori Glide (Kuro's Feather) | Slow fall, cross gaps, float over thorns | Wide gaps over hazards | flight essence (moth, bat) |
| Swim / hazard immunity | Ori Water Dash (dash underwater, or near surface to launch out); Ori Burrow (move through sand/snow); Aria Skula soul (walk underwater); Blasphemous Nail Uprooted from Dirt (mud/water without slowdown); Blasphemous Silvered Lung of Dolphos (pass poison mist); HK Isma's Tear (acid pools) | Cross a hazard medium | Flooded areas, acid, gas | water essence; poison essence for gas immunity |
| Grapple / swing | Super Metroid and Dread Grapple Beam (swing; pull objects down); Ori WotW Grapple (hooks, blue moss); Axiom Verge Grapple Hook; ESA hookshot ("key item", used constantly) | Anchor and swing | Gaps with ceiling anchors | Sticky Thread already does this; thread essence (spider) |
| Ground pound | Ori Stomp (15 dmg small area; breaks weak ground; hits nail pegs); HK Desolate Dive (breaks floors, invulnerable during descent); Guacamelee Frog Slam (breaks green blocks); Dead Cells Ram Rune (breaks orange-glyph floor) | Downward slam | Breakable floors, drop-down shortcuts | armor/earth essence (armored lizard, mushroom crab) |
| Speed / charge dash | Super Metroid Speed Booster + Shinespark; HK Crystal Heart (hold ~0.8 s, release, infinite range until collision); Ori Charge Jump (hold 0.5 s, 50 dmg through enemies and barriers); Aria Black Panther Sonic Dash (Guardian soul) | Charged burst that breaks blocks | Long run-ups, "spark" puzzles, breakable blocks | Jet Dash branch |
| Squeeze / small form | Metroid Morph Ball; Guacamelee chicken; SotN Mist Form (pass grates); Zero Mission crawl section without Morph Ball | Fit through tiny gaps | Ducts, grates | Slime is already small: "flatten/ooze" through 1-tile gaps |
| Teleport / phase | Dread Flash Shift; Axiom Verge Remote Drone + Drone Teleport (swap to drone; launched high, climbs); Axiom Modified Lab Coat (phase through a wall (?) - summary only); HK Dreamgate (instant travel) | Reposition without crossing space | Gaps, vertical climbs, wall skips | thread essence: teleport to a placed thread anchor |
| Make a platform | Animal Well Bubble Wand (bubble you jump on, chained ascent); Disc (throw and ride); Dread Ice Missile (freeze enemy into platform); Super Metroid frozen Rippers as platforms | Temporary footing | Vertical gaps, unreachable ledges | thread: web-trapped enemy becomes a platform |
| Remote body part | Axiom Remote Drone (own health bar, drill breaks blocks); Dead Cells Homunculus Rune (detach head, control it, reach secrets) | Separate controllable unit | Tiny passages, switches | Small "bud" slime |

Note: the brief's "Phase Displacement" did not turn up as a Dread ability; Dread has Flash Shift and Phantom Cloak. "Phase Drift" is a Samus Returns ability (title seen, page not read).

### 1b. Traversal gates (lock and key)

Design write-ups describe the genre as a lock-and-key graph: decide which ability opens which door and in what order, and plan it as a graph before building.

| Lock type | Example | Key |
|---|---|---|
| Colour-coded barrier | Guacamelee: red blocks = Uppercut, blue = Dash, yellow = Headbutt, green = Frog Slam | Matching move |
| Biome entrance | Dead Cells: Vine Rune (climbing vines), Spider Rune (cling), Ram Rune (break floors), Teleportation Rune (monoliths) each gate specific biomes | Rune |
| Medium/hazard | Acid pools (Isma's Tear), poison mist (Silvered Lung), mud (Nail Uprooted) | Immunity item |
| Typed door/block | Wave Beam covers, Plasma doors, Storm Missile gates, speed-boost blocks (Dread); red/blue arcane barriers (S&S Redshift/Hardlight Brands) | Matching weapon or brand |
| Sensor / plate | Dread pressure-plate and sensor doors | Flash Shift, Phantom Cloak |
| Hidden route | Dread Pulse Radar reveals hidden blocks; Dead Cells Explorer's Rune reveals the map at 80% exploration | Sensing ability |
| Surface | Magnet walls (Spider Magnet), roots (Blasphemous Three Gnarled Tongues), red motes (Blood Perpetuated in Sand makes platforms) | Specific key |

### 1c. Combat

| Ability | Games | What it does | Slime fit |
|---|---|---|---|
| Projectile | HK Vengeful Spirit -> Shade Soul; Ori Spirit Arc (arrow); Axiom Nova (6 shots, all directions), Data Bomb (explosion through walls), Kilver (shotgun-like), Reverse Slicer (boomerang); Dread Diffusion Beam (through walls) | Ranged hit | poison/spore spit (toad) |
| Cone / stream | HK Howling Wraiths (~90 degree cone up, three damage ticks) and Abyss Shriek (up and down); Axiom Flamethrower (aimable stream, goes through walls) | Area in front | Poison Breath |
| Area burst | Ori Charge Flame (explosion, reflects projectiles), Light Burst (thrown orb); Super Metroid charge combos (Ice Shield = 4 crystals circling you; Wave Shield "most effective") | Radius damage | spore essence |
| Parry / counter | Dust Parry (stuns target, triggers Fidget projectiles); Dread melee counter (narrow window); Ori Stomp and Charge Flame reflect projectiles; HK Shade Cloak invulnerable dash | Turn enemy attack into opening | shell essence: reflect |
| Summon / familiar | Bloodstained Familiar Shard (blocks, buffs, attacks, heals; levels with XP; no MP); HK Weaversong (3 spiders follow and attack); HK Glowing Womb (Soul to Hatchlings); Ori Sentry (orbiting orb); Aria Guardian souls include summoned familiars | Autonomous helpers | thread essence, spore essence |
| Cloud aura | HK Spore Shroom (Focus releases damaging spore cloud); HK Defender's Crest (cloud around you) | Passive area damage | Spore Cloud + Regeneration |
| Bomb/mine | Cross Bomb (Dread, blasts four directions), Axiom Address Bomb | Placed damage / block breaker | spore puffs |

### 1d. Utility and sensing

- SotN Echo of Bat: in dark areas, press to learn the surroundings (used mostly in the catacombs). Direct analogue of Echolocation.
- Dread Pulse Radar: reveals destructible walls, empties the Aeion gauge. Phantom Cloak: invisibility, also drains Aeion.
- Animal Well Lantern (lights dark rooms, clears shadow ghosts), Firecrackers (light and distract), Remote (highlights egg chests, activates towers), Animal Flute (fast travel, wakes animals). UV Lantern effect not read (?).
- HK Dream Nail: reveals hidden dreams or opens gateways.
- Aria Galamoth soul (an ability soul): recognise places where time has stopped.

## 2. EVOLUTION / UPGRADE PATTERNS

1. **Replace, same cost, new footprint (HK spells).** Each of three spells has one upgrade: Vengeful Spirit -> Shade Soul (same 33 Soul cost, larger, ~12% faster, pierces walls); Desolate Dive -> Descending Dark (shockwave stronger, invulnerable the whole descent); Howling Wraiths -> Abyss Shriek (cone now up and down). One source lists Shade Soul as doubling damage (15 -> 30); another lists 30 for both, so I would not quote a number.
2. **Duplicate-count power (Dawn of Sorrow, Bloodstained).** DoS: up to 9 copies of a soul, each raising its power. Bloodstained: Grade rises by collecting duplicates (max 9, mostly numbers), Rank rises by alchemy (max 9, adds effects). Two axes: numbers by repetition, behaviour by deliberate spend.
3. **Three-branch tree (Ori Blind Forest).** Combat / Utility / Efficiency branches; skills learned in order within a branch, 2-3 AP each. Charge Flame has three modifiers: Burn, Blast (radius/damage up), Efficiency (half energy). Ultra Bash/Ultra Stomp make the base move deal more damage and bigger radius.
4. **Modifier slots (HK charms, Ori Spirit Shards).** HK: 3 notches growing to 11; equipping too many = Overcharmed (double damage taken). Charms alter existing skills: Flukenest turns Vengeful Spirit into a horde of flukes (more damage, less range), Shaman Stone boosts spells, Spell Twister cuts cost. Ori WotW: 3 shard slots growing to 8.
5. **Combos / fusion.** DoS Tactical Soul combos (Guardian + Bullet). Super Metroid Charge Beam + Power Bomb + Wave/Ice/Spazer/Plasma gives a beam-specific shield. Dust Storm + Fidget projectiles multiplies hits; Aerial Dust Storm moves you across the screen.
6. **Stack versus replace.** Metroid beams stack (Charge triples damage for all combos; Ice + Plasma changes cooldown 15 -> 12 frames). HK spells replace. Ori and HK let you re-pick; Metroid does not.
7. **One input, several releases (HK Nail Arts).** Hold attack then release: Cyclone Slash (release with Up/Down), Dash Slash, Great Slash. Three separate Nailmasters teach them; Nailmaster's Glory shortens charge.
8. **Type taxonomy (Aria).** Souls come in four roles: Bullet (one-time MP), Guardian (toggle, continuous MP), Enchant (passive), Ability (traversal). Same creature system, four behaviours.
9. **Spend souls to change gear (DoS).** Souls can be permanently spent to transform a weapon at a shop.
10. **Critique to learn from (Holism on Aria).** Random soul drops cause bad-luck streaks (110 of 113 enemies carry a soul); many souls are redundant; bosses drop lantern items instead of their own soul. Lesson: deterministic essence gains, distinct roles, bosses grant their own power.

**What this means for a 2-3 branch tree on one base skill.** Combine patterns 1, 3, 5: *Potency* branch (stronger numbers, from duplicates), *Shape* branch (new footprint: cone to cloud/bolt, pattern 1), *Utility* branch (side effect that doubles as a gate key or a summon). Ori's Charge Flame (Burn / Blast / Efficiency) is the ready template; Flukenest-style modifiers fit the "Shape" slot.

## 3. HELD / CHANNELED ATTACKS

| Attack | Ramp | Cost | Movement penalty | Release / cancel |
|---|---|---|---|---|
| Super Metroid Charge Beam | 60 frames (1 s) | none extra | spin-jump and turn-arounds delay charging (turn ~6 frames) | 3x damage; combined with any beam |
| Charge combos | 120 frames | consumes 1 Power Bomb | only Grapple, Power Bombs, Bombs usable | beam-specific shield (Ice, Wave, Spazer, Plasma) |
| Ori Charge Flame | hold 1 s | 1 energy (0.5 with Efficiency) | not stated | 12-15 dmg small area (sources differ), reflects projectiles; Blast: up to 24, radius ~1/3 screen |
| Ori Charge Jump | hold 0.5 s | none | none stated | ascends, 50 dmg to enemies in path |
| HK Focus | 0.25 s start-up; first heal ~1.14 s; later ticks ~0.89 s | 33 Soul per mask | cannot move by default (Shape of Unn allows) | damage interrupts and the spent Soul is wasted; Quick Focus +33% speed, Deep Focus heals 2 masks but +65% time |
| HK Nail Arts | hold attack; Nailmaster's Glory shortens | none | not stated | Cyclone / Dash / Great Slash; damage scales with nail upgrade |
| HK Crystal Heart | ~0.8 s | none | grounded or on wall | infinite range until collision or damage; jump or press again to cancel; 10 dmg contact; small enemies do not interrupt |
| Shinespark | run until blue, crouch-input | Energy | must have runway | 180-frame window; cannot fire downward; 70-frame crash; works underwater |
| Aria Guardian soul | hold to keep active | continuous MP drain | none stated | releasing stops |
| Dust Storm | hold | "continually draws power"; character turns red near depletion | mobile in air (Aerial Dust Storm) | sucks in items; combos with Fidget |
| Blasphemous 2 Veredicto Embers of Faith | toggled | Fervour drains while lit | none stated | stays lit until Fervour is gone |
| Dread Omega Cannon (EMMI only) | rapid fire | limited window | none stated | rapid strips the shield; charged blast kills the core |

Why the good ones feel good, from these sources:
- **Commitment is the cost.** Focus roots you and wastes the resource if hit, so it is used in safe windows. Shape of Unn and Quick Focus are sold as modifiers rather than defaults.
- **Short, visible ramp.** 0.5-1 s charges (Ori, Metroid, Crystal Heart) keep the tension without stalling play. Shinespark has a visible state (blue with echoes) and a time limit; Dust turns red when nearly out.
- **Two ways to end.** Release for the effect, or cancel/interrupt (Crystal Heart cancel; Aria toggles).
- **Drain-while-held versus pay-on-release.** Aria/Veredicto/Dust drain per second (soft-lock the player into a short window); Focus/Charge Flame pay once.
- **Release effect changes with context** (Cyclone with Up/Down; Aerial Dust Storm).
- **Payoff scaling.** Metroid pays 3x for 1 s; charge combos pay a consumable for a shield.

## 4. ENEMY ARCHETYPES

| Role | Examples (game) | Telegraph | Counter-play | Tests |
|---|---|---|---|---|
| Charger | HK Husk Hornhead (number variants change only charge speed/distance and hit reach); HK Squit (hovers until in range, hisses, lunges); HK Baldur (rolls into a ball, launches at you, bounces off walls, unrolls after a while); Dead Cells Disgusting Worm (fast once it sees you, very short-range bite) | Hiss, squawk, roll pose | Interrupt mid-charge (Squit flies off, stunned if it hits a wall); bait into wall or ground then punish; jump the roll | Dash, jump timing |
| Swooper | HK Vengefly (squawks then dives, otherwise hovers in small area); HK Belfly (shriek reveals glowing belly, flies in, explodes; 5 HP; hangs from dark ceilings); Metroid Skree (hangs on ceiling, dives and explodes); Metroid Kihunter (swoops, spits acid on the ground) | Squawk / shriek / rotation on approach | Stand still and hit in range (Vengefly); double-jump sideways when the shriek starts (Belfly) | Double jump, vertical dodge |
| Turret / spitter | HK Aspid Hunter (hovers, spits blobs, small opening after each); HK Primal Aspid (hovers out of melee reach, three blobs 35 degrees apart, high HP, worst in packs); HK Mantis Petra (hovers outside reach, throws scythes in a parabola); Dead Cells Grenadier (bombs pass through walls, explode after a delay) | Spit windup; scythe arc | Close in immediately after each spit; get above to lure close; use ranged skill | Air control, ranged attack |
| Shielded / armored | HK Husk Warrior (blocks; wait out recovery); Metroid Geemer (spines, needs missile/Plasma); Metroid Ripper (Super Missile or Screw Attack only; frozen Rippers become platforms); Dead Cells Shieldbearer (only from behind; whip ignores); Guacamelee colour shields (red Uppercut, yellow Headbutt, green Slam; shield regenerates if left ~5 s); Dread EMMI (rapid fire strips shield, charged shot kills core) | Colour or stance | Specific skill, get behind, or wait for recovery | Owning the right ability |
| Swarm | Metroid Rinka (infinite supply in Tourian); Metroid Zeb (flies out of pipes, weak) (?); HK Primal Aspid packs | Continuous spawn | Area attack, destroy the source, or ignore and move | Area damage, crowd movement |
| Ambusher | Metroid Skree (ceiling); HK Belfly (dark ceiling); Metroid Owtch (pops from ground in nearby rooms) (?); Ori Sand Worm (sand areas) (?) | Hidden until you approach | Light/sensing, pre-emptive strike | Sensing (Echolocation) |
| Leaper | HK Leaping Husk (variable jump angles, pushes you toward danger); Metroid Sidehopper (double jump attack); Metroid Dessgeega (Sidehopper cousin, thorns in X form) | Crouch before jump | Sidestep under the arc, hit on landing | Air dodge, spacing |
| Splitter | **No sourced example found in these games.** Near neighbours: Dead Cells Disgusting Worm (dies, six bombs); HK Volatile Gruzzer (explodes on defeat, leaks goo). General trope "Asteroids Monster" splits into smaller copies, usually three stages (TV Tropes summary, not a metroidvania) | n/a | n/a | n/a |
| Exploder | HK Belfly; HK Volatile Gruzzer; Dead Cells Kamikaze (relentless pursuit, stops briefly, explodes); Metroid Skree | Brief stop or shriek | Wait for it to come into range and hit first | Dodge and reaction |
| Summoner | HK Carver Hatcher (spawns Dirtcarvers when prey near; after five swoops and bites). 1 example found | Spawns visible | Kill hatcher first or thin adds | Prioritising targets |
| Patroller | HK Crawlid, Tiktik (no attacks except movement; placement adds difficulty); Metroid Zoomer/Zeela (walk set patterns along terrain), Ripper (horizontal); Ori Slug (crawls back and forth, does not pursue) | None | Wait, then strike | Baseline; teaches hit timing |
| Wall-crawler | HK Tiktik (walls, floors, ceilings; falls when hit but keeps crawling); Metroid Zoomer/Geemer; Space Pirates (climb walls, weakened plasma) | None | Wait for approach, strike; Geemer needs stronger hit | Wall cling |
| Swimmer | Metroid Skultera (lazy swim, darts and slices Energy when it sees you, homes in when approached). 1 example found | Turns toward you | Attack on approach | Swim / water movement |
| Pursuer | Dread E.M.M.I. (hunts by sound and sight, lives in a zone, zone doors lock during chase, narrow randomized parry window, Phantom Cloak hides you, respawn just outside the zone); Dead Cells Kamikaze | On-screen sound circle and vision cone | Hide, break line of sight, counter when flash appears, Omega Cannon | Stealth, dash |
| Mini-boss | HK False Knight (3 phases; slow leap, overhead slam, ground shockwave you must jump; stagger exposes face; phase 2 adds falling rocks); HK Mantis Lords (phase 1: one lord 210 HP; phase 2: two lords 160 HP each, synced attacks: boomerang, charge, overhead with delays; standing in centre is safe for healing); Ori Hornbug (pounce, charge, fire breath; damaged only from behind) | Wind-up delays | Learn each attack, use openings after stagger | Dash, jump, positioning |

Design lessons from the write-ups:
- HK early enemies build one behaviour at a time: Crawlid/Tiktik (movement only) -> Hornhead (charge) -> Warrior (block) -> Leaping Husk (jump) -> Guard (wave attack). Gruzzer (predictable flight) -> Vengefly (targets player) -> Aspid Hunter (keeps distance and shoots). Enemy form foreshadows attack; terrain changes behaviour.
- A forum thread notes most metroidvanias place enemies singly, HK varies encounters more; Trial of Fools is praised for enemy mixes.

## 5. RECOMMENDATIONS (my inferences)

Rules that follow from the sources: essence gains should be deterministic, not random drops (Holism critique); a boss should hand over its own power; skill level rises with repetition (Bloodstained Grade, DoS duplicates), and evolution is a separate deliberate step (Bloodstained Rank).

### 5a. Eight abilities

| # | Ability | Essence / creature | Biome | Modeled on | Cheap because |
|---|---|---|---|---|---|
| 1 | Glide (hold jump to slow fall) | flight, spore moth | Fungal Grotto shafts | Ori Glide | one gravity multiplier |
| 2 | Air Hop (Leap evolution) | flight, bat | Cave into Serpent Lair | HK Monarch Wings; Aria Malphas | second jump counter |
| 3 | Shell Slam (down-slam, breaks cracked floors, stuns shielded enemy from above) | armor/shell, armored lizard or mushroom crab | Cave, Serpent Lair | Ori Stomp; HK Desolate Dive; Dead Cells Ram Rune | charge behaviour in reverse |
| 4 | Ooze Squeeze (flatten to pass 1-tile gaps and grates) | water, plus base slime | Flooded Tunnels | Morph Ball; SotN Mist Form; Guacamelee chicken | shrink hitbox |
| 5 | Toxic Hide (immune to poison gas and acid pools) | poison, toad | Fungal Grotto, Serpent Lair | Silvered Lung; Isma's Tear | tile flag |
| 6 | Shell Reflect (short parry that sends projectiles back) | shell/armor, mushroom crab | Fungal Grotto vs toad spit | Ori Charge Flame/Stomp reflect; Dust Parry | reuse projectile |
| 7 | Pulse Reveal (Echolocation evolution: reveals cracked walls) | sound, bat | all | SotN Echo of Bat; Dread Pulse Radar | reveal flag on breakable tiles |
| 8 | Thread Recall (teleport to a placed thread anchor) | thread, black spider | Cave, Serpent Lair | Axiom Drone Teleport | reuses Sticky Thread anchor |

### 5b. Ten enemies (all reuse an existing creature's behaviour)

| # | Enemy | Essence | Biome | Reuses | Modeled on | Telegraph / counter / tests |
|---|---|---|---|---|---|---|
| 1 | Blast Bat (dive then pop) | flight | Cave | bat swoop | Belfly, Kamikaze | shriek and glowing belly; hit first; double jump |
| 2 | Tide Hopper | water | Flooded Tunnels | toad body, no spit | Leaping Husk, Sidehopper | crouch; sidestep; jump timing |
| 3 | Darter (swimmer) | water | Flooded Tunnels | bat swoop, water-bound | Skultera | turns then darts; Jet Dash |
| 4 | Roller | shell | Cave, Grotto | lizard charge + crab shell | Baldur | rolls into ball, bounces; wait for unroll; stomp from above |
| 5 | Cave Tick (wall crawler) | earth | Cave | black spider on wall | Tiktik, Zoomer/Geemer | patrols; falls when hit; spiked variant only hurt by Poison Breath |
| 6 | Wisp swarm | flight | Fungal Grotto | spore moth drift | Rinka, Primal Aspid packs | area attack; Spore Cloud |
| 7 | Hover Spitter | spore | Fungal Grotto | toad spit, moth hover | Aspid Hunter, Primal Aspid | 3-blob spread; close in after spit; Shell Reflect |
| 8 | Brood Spider (summoner) | thread | Serpent Lair | black spider | Carver Hatcher | spawns five hatchlings then chases; kill first |
| 9 | Scaled Guard (shielded) | armor | Serpent Lair | mushroom crab | Guacamelee colour shield, Shieldbearer | shield breaks only to one skill (e.g. Shell Slam); doubles as a gate |
| 10 | Mud Lurker (ambusher) | earth | Flooded Tunnels | vine snake, inverted (floor) | Owtch, Sand Worm | ripples before pop; Echolocation |

Stretch, not counted: an E.M.M.I.-style pursuer zone (sound-hunted, Echolocation ping as its trigger) would fit Serpent Lair but is not cheap.

### 5c. Evolution trees (2-3 branches each)

- **Hydraulic Propulsion** (already evolves into Water Blade and Jet Dash; keep both).
  - *Jet Dash* (movement): hold to charge ~0.8 s, release travels until it hits something, breaks marked blocks, cancel with jump (Crystal Heart).
  - *Water Blade* (attack): dash leaves a short cutting arc, with a held variant (Dash Slash / Cyclone Slash).
  - *Optional third, Torrent (utility)*: near the surface launches you out of water, underwater pushes objects (Ori Water Dash). New suggestion; not a replacement.
- **Sticky Thread**
  - *Snare*: slows -> binds; a bound enemy is briefly a platform (frozen Ripper, Ice Missile).
  - *Silk Line*: retractable line with recall to anchor (Grapple Beam, Drone Teleport).
  - *Weaver*: 3 small spiders that follow and attack (Weaversong; Familiar Shard).
- **Poison Breath**
  - *Miasma*: cone leaves a lingering cloud (Defender's Crest).
  - *Caustic Stream*: held channel that drains a meter (Aria Guardian soul; Flamethrower).
  - *Venom Bolt*: single piercing bolt, upgrade adds wall-pierce (Vengeful Spirit -> Shade Soul).
- **Spore Cloud**
  - *Healing Spores*: releases while Regeneration is active (Spore Shroom on Focus).
  - *Puffball*: placed mine cloud, damages over time.
  - *Sporelings*: converts the cloud into hatchlings that hunt (Glowing Womb, Flukenest).

## 6. SOURCES

Blocked (402/403/429/empty): Fandom wikis, hollowknight.wiki, metroidwiki.org, StrategyWiki, GameFAQs, Neoseeker, Steam guides, Digital Trends, PC Gamer (truncated), guides.gamercorner.net.

**Fetched and read:**
- https://en.wikipedia.org/wiki/Hollow_Knight
- https://en.wikipedia.org/wiki/Metroid_Dread
- https://en.wikipedia.org/wiki/Metroid:_Zero_Mission
- https://en.wikipedia.org/wiki/Ori_and_the_Blind_Forest
- https://en.wikipedia.org/wiki/Ori_and_the_Will_of_the_Wisps
- https://en.wikipedia.org/wiki/Castlevania:_Dawn_of_Sorrow
- https://en.wikipedia.org/wiki/Axiom_Verge
- https://en.wikipedia.org/wiki/Guacamelee!
- https://en.wikipedia.org/wiki/Environmental_Station_Alpha
- https://www.destructoid.com/reviews/review-environmental-station-alpha/
- https://hollowknight.wiki.fextralife.com/ (pages: Shade_Soul, Nail+Arts, Abilities, Charms, Baldur, Husk+Guard, False+Knight, Mantis+Lords, Tiktik, Volatile+Gruzzer, Belfly, Crystal+Heart, Cyclone+Slash, Focus)
- https://rogueranker.com/hollow-knight-spells/
- https://wiki.supermetroid.run/Charge_Beam , /Charge_Beam_Combos , /Shinespark
- https://omegametroid.com/super-metroid-walkthrough/special-abilities/
- https://www.thegamer.com/metroid-dread-abilities-explained/
- https://en.wikibooks.org/wiki/Metroid_franchise_strategy_guide/Creatures_in_Metroid,_Metroid_II,_and_Super_Metroid
- https://www.joshanthony.info/2021/11/06/examining-the-emmi-zones-of-metroid-dread/
- https://www.jasondeheras.com/gamedesign/2021/3/6/early-game-hollow-knight-enemies
- https://sourcegaming.info/2018/11/28/holism-aria-of-sorrows-soul-system/
- https://kb.speeddemosarchive.com/Ori/Skills_and_Abilities
- https://www.castlevaniacrypt.com/aos-souls-ability/
- https://castlevaniadungeon.net/Arsenal/ariasouls.html (attack souls page only)
- https://animalwell.wiki.gg/wiki/Tools
- https://www.thegamer.com/animal-well-best-items/
- https://saltandsanctuary.wiki.fextralife.com/Brands
- https://deadcells.wiki.gg/wiki/Runes_and_upgrades
- https://www.resetera.com/threads/enemy-placement-in-metroidvania-games.448726/

**Search-result summaries only (pages not opened):**
- Ori skills and WotW abilities: PC Gamer, oriandtheblindforest.fandom.com (Skills, Ability Tree), shapes.inc
- Bloodstained shards: bloodstainedritualofthenight.wiki.fextralife.com/Shards, strategywiki
- Blasphemous: blasphemous.wiki.fextralife.com, gameranx, pcgamesn.com/blasphemous-2/abilities
- Axiom Verge: axiom-verge.fandom.com, gamefaqs
- Guacamelee: guacamelee.fandom.com, steam combat guide
- Dust: elysiantail.fandom.com
- SotN relics: gamefaqs, gamercorner, strategywiki
- Aria souls: almarsguides.com, strategywiki, gamefaqs
- Dread abilities and EMMI: game8, digitaltrends, nintendo.com Metroid Dread Report vol. 2
- Metroid enemies (Skultera, Skree, etc.): wikitroid, metroidwiki.org, bogleech.com
- Hollow Knight charms and Carver Hatcher: hollowknight.wiki
- Dead Cells enemies: deadcells.fandom.com, gamepur
- Guacamelee shield colours: gamefaqs, Hardcore Gaming 101
- Splitter trope: tvtropes.org Asteroids Monster
- Lock-and-key framing: dreamnoid.com, researchgate "A Framework for Metroidvania Games"
