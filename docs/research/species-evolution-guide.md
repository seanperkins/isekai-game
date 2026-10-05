# Species evolution guide: trees of powers and bodies for slime, spider, goblin, undead and wolf

Purpose: input for specifying each species' evolution tree, and for tightening the slime's. Written so a creative decision can be outlined rather than settled: most of what follows is a worked example or a menu, tagged [inf]. Companion to `area-level-design.md` (areas, zones, traps) and `metroidvania-reference.md` (abilities; section 2 covers Hollow Knight charms, Ori trees, Bloodstained shards, Aria souls, and is not repeated). Raw notes with every URL: `species-evolution-notes/` (`evolution-systems.md`, `species-ladders.md`, `skill-trees.md`), unedited; where they conflict with this document, this document wins. A visual summary is `species-evolution-report.html`.

Tags: **[repo]** read in this repository. **[read]** a fetched page (WebFetch has a small model summarise each page, so quoted phrases are the summary's words unless marked exact). **[inf]** inference or proposal, source named. **[gap]** nothing found. A number marked *placeholder* is mine. **The web-search budget ran out before this research started**, so every web claim comes from a page fetched by URL; Fandom, Bulbapedia, WikiMon and several others were blocked, so Tensura and Re:Monster mechanics rest on Wikipedia summaries only.

---

## 0. Bottom line

1. **The slime's tree has the right bones and two soft spots** (section 1). Every stage-3 form leads to the same stage-4 form, and the design doc's rule that your evolved power decides which child is offered is not built, so the stage-3 choice changes stats and a passive but never the ending. Both are cheap to fix (section 4).
2. **A choice is meaningful when its options trade, not stack.** Slay the Spire's campfire sets Rest against Smith; Dungeon Crawl's stated aim is "to avoid providing illusory gameplay choices where one alternative is always superior" [read]. Spore's editors are the cautionary tale: choices that carry no consequence read as cosmetic.
3. **Two or three options per choice, joins have exactly two named parents.** Hades, Slay the Spire and Path of Exile all offer three; Digimon's Jogress, Hades' duo boons, Vampire Survivors and Shin Megami Tensei fusion all join two [read]. Your stage 4 already does.
4. **Let the world flavour the fork.** Eevee evolves near moss or ice rocks, Lycanroc splits by time of day, Nocturne's outcomes follow the moon [read]. Your areas (cathedral, swamp, volcano) are the natural triggers.
5. **One element reads differently per species** (design doc). Section 3 gives a grid of examples: dark is a shadow-stalker on a spider, an assassin on a goblin, a lich on a skeleton, a barghest on a wolf, a toxic ooze on a slime.
6. **Each species needs its own verbs, not only stats.** Sections 5 to 9 outline a four-stage ladder for each, with the power families that feed it and the area that hosts each unlock.

7. **Power trees stay small and rich** (section 10): seven node types, 12 to 14 shipped recipes out of 28 possible pairs, a notch budget, and capstones that change a verb. One real collision to settle: lightning's planned light + air route is Jolt's existing recipe.

---

## 1. Where the system stands [repo]

**Essence and powers** (`essence-overhaul-design.md`, `data/skills`): five elements today (water, earth, air, light, dark); fire, mind and blood arrive with their first creature. A power unlocks from an element, a recipe (poison = water + dark, spore = air + dark, jolt = light + air) or by eating a creature (Sticky Thread: three spiders). Powers level by use. About 19 base powers and 8 evolutions exist. Proficiency powers unlock by doing: Leap after 40 jumps, Wall Cling after 15 wall touches, Swim after 20 s underwater, Pain Resistance after dropping to low health twice, Toughness after 20 physical hits, Glutton (secret) after five kills without taking damage. The unlock conditions are data (event counters, resets on damage, tags), so a streak or a species-specific counter needs no new engine.

**Power evolution:** four base powers each have two branches (Sticky Thread: Swing Thread or Binding Web; Hydraulic Propulsion: Water Blade or Jet Dash; Poison Breath: Miasma or Venom Bolt; Spore Cloud: Healing Spores or Puffball). The evolved power replaces its parent in the slot, the sibling closes for the life, and the price is essence you hold, set once on the parent (Poison Breath water 6, dark 10; Spore Cloud air 6, dark 12; Sticky Thread dark 14; Hydraulic Propulsion water 6). Body-lineage powers with no branch yet: Body Armor, Hardened Shell, Tremor (bulwark) and Echolocation (echo).

**Body evolution:** four stages, six lineages, 24 forms. Stage 2 is offered by the powers you own, with every open lineage on the menu and no cap (Sean decided this, essence overhaul "Open for Sean 6"), plus a Greater Slime fallback when fewer than two are open. Stage 3 is the lineage's two children; **stage 4 is the lineage's one Sovereign**, so both children lead to the same body. A stage costs a level cap (270, 403, 540 and 673 XP). A form is stats, one passive trait, granted skills, a tint and a size; most stage-3 and stage-4 forms add no new verb.

| Lineage | Opened by | Stage 3 (pick one) | Stage 4 | Traits and grants |
|---|---|---|---|---|
| Weaver | Sticky Thread | Snare, Arachne | Silkbound | spinner; Arachne grants Wall Cling |
| Tide | Hydraulic Propulsion | Brook, Tempest | Tidal | water thrift |
| Toxic | Poison Breath or Spore Cloud | Acid, Blight | Venom | venom blood; Blight grants Poison Resistance |
| Bulwark | Body Armor, Hardened Shell or Tremor | Golem, Crystal | Stone | hard shell; Golem grants Toughness |
| Echo | Echolocation | Phantom, Sky | Storm | sonar; both grant Leap |
| Greater | nothing (fallback) | Vast, Radiant | Prime | adaptable; grants Regeneration, Toughness, Mana Recovery |

**What the tree does not do yet:**
- The stage-3 choice does not change the ending (both children join one stage 4).
- The branch you took on a power does not decide the child (design doc working idea; deferred in the essence overhaul because Bulwark and Echo have no branching power and Toxic has four evolved powers for two children).
- Light has one power (Jolt) and no lineage; Greater has no powers at all.
- No other species has a tree. Only the slime has species data (`data/species/slime.tres`).

---

## 2. What makes an evolution choice good

| Principle | Evidence | Use here [inf] |
|---|---|---|
| **Trade, not upgrade.** A choice gives something up | Slay the Spire: Rest or Smith; Hollow Knight charms with limited notches; Darkest Dungeon quirks (5 good, 5 bad) [read] | A branch costs a verb or a sense: a fire-aligned spider loses Binding Web because fire burns webs |
| **Identity by restriction.** What a branch cannot do defines it | Dungeon Crawl species are defined by limits (trolls strong, weak at magic) [read] | Give each S3 form one thing it is bad at |
| **Two or three options.** Never a long menu | Hades 3 boons, StS 3 cards plus skip, PoE 3 ascendancies per class [read]; Eevee's 8 are told apart by clear, different conditions | At most three visible options per choice; five rows on screen at most (the tree screen's own limit) |
| **Joins have two named parents** | Jogress, Hades duo boons, Vampire Survivors weapon plus passive, SMT fusion [read] | Draw a join with exactly two inbound edges and show the missing parent as a ??? |
| **Let place and time flavour the fork** | Eevee and moss rocks, Lycanroc by time of day, E.V.O. era-specific options, Nocturne moon phase [read] | Area or altar sets which S2 or S3 options appear |
| **Preview before commit** | Nocturne shows the fusion result; Vampire Survivors' Collection hints pairings; Biomorph lets you try a form in the room where you killed it [read] | Show the S3 children or stubs on the card before the player confirms |
| **Reversibility is a lever** | Hades' Mirror: 8 talents plus 8 alternates that swap freely; Cassette Beasts' temporary fusion; Dungeon Crawl lets you renounce a god at a penalty [read] | A branch closed this life reopens next life (already true) |
| **Block the free best option** | Limited slots, offering subsets, making the best option conditional (duo boons need one boon from each god) [read] | Condition the apex on what you hold |
| **Hidden is for secrets only** | Tamagotchi's adult form depends on early care; Eevee's friendship and time conditions push players to wikis [read; summary-level] | Hide only the deepest secrets, show stubs one step ahead |

**One observation, not a reopening.** The essence overhaul accepted that after a Cave and Grotto clear almost every life is offered the same five lineages. By the definitions above that reads as an illusory choice: no lever decides the offer. If Sean wants weight there without touching the decision, three cheap levers are sourced: offer at most three lineages chosen by diet share (held essence per element, normalised, so it does not inherit the Bulwark bias the spec found), tie an offer to the area where you hit the cap, or let a soul perk lock a form as a head start. All [inf].

---

## 3. One element, five readings (the grid)

The design doc: "dark makes a lich on a skeleton, an assassin on a goblin, a shadow-stalker on a spider; light can redeem a monster upward". The ladders research found the same pattern in other games: dark on a slime is Alolan Muk (Poison/Dark from eating trash) or a Dragon Quest "vicious slime"; on a bone body it is Alolan Marowak's cursed fire; on a goblin it is a warlock's shadowflame [read]. [inf] drafts of the whole grid (a later element is in *italics*):

| Element | Slime | Spider | Goblin | Undead | Wolf |
|---|---|---|---|---|---|
| Water | tide: jets, blades, current | poison base with dark; dew-slick webs | bog bombs, flood traps | drowned regrowth in water | river hunter, scent trails |
| Earth | bulwark: shell, tremor | brood cocoons, burrow lair | tinker: rock craft, rigs | zombie and ghoul: tank | dire: knockback-proof |
| Air | echo: sense, glide-like leap | silk drift, longer zip | skulker: smoke, sneak | archer: returning bone throws | howl, speed |
| Light | lumen and mender: glow, heal | sparkweaver (with air = lightning) | paladin: redeemed upward | **hurts**: holy weakness, ward for a lich | grim: a guardian that wards the pack |
| Dark | toxic, vicious: rot | shadow-stalker: ceiling ambush | assassin: shadowflame | lich, vampire, ghoul feed | barghest: silent stalker, fear howl |
| *Fire* | ember: lava trail | burns webs (trade-off) | tinker: explosives | burning skeleton | hellhound (with dark) |
| *Mind* | echo and lumen: sense | hive: web network | tamer, shaman | lich: bone magic | pack bond |
| *Blood* | none yet | none yet | redcap-style assassin | vampire | bleed, pack hunt |

---

## 4. A menu of evolution shapes, each with an example [inf]

Sources noted per shape; "(exists)" marks what the slime already does.

| Shape | What it is | Worked examples |
|---|---|---|
| **Binary branch** (exists) | Two directions off one power | Spider: Web Shot becomes Snare Bolt (pins one target along a line) or Weave Net (an area net). Goblin: Junk Trap becomes Spiked Pit or Net Snare. Source: Hades Mirror alternates |
| **Three-way fork** | Three S2 or S3 options | Undead off the skeleton: flesh, bone-ranged, bone-magic (the design doc's three paths). Spider S3: Shadow-stalker, Venomspinner, Broodmother. Source: Hades, StS, PoE norm of three |
| **Convergence** (exists at S4) | Two parents, one child | Undead: a Ghoul holding a bone-magic graft becomes a Death Knight (join of flesh and bone-magic). Slime: Venom needs Acid and Blight. Source: Jogress, duo boons |
| **Branch decides child** (design doc, not built) | The evolved power picks the S3 form | Slime weaver: Swing Thread leads to Arachne, Binding Web to Snare. Tide: Jet Dash to Brook, Water Blade to Tempest. Toxic: the Poison Breath family to Acid, the Spore Cloud family to Blight. Source: design doc; fixes the 4-powers-for-2-children problem by choosing on the family, not the branch |
| **Fork by diet** | The dominant thing you ate or learned picks the form | Goblin lessons: mostly beasts gives Tamer, mostly junk and fire creatures gives Tinker, mostly shadows gives Skulker. Wolf: living prey of one kind. Source: Re:Monster's dedication ("evolved into a Spell Lord"); Tamagotchi |
| **Environment-triggered** | An area or condition offers the option | Slime at a lava pool with fire essence offers Ember; a spider on consecrated ground cannot spin dark webs; undead regress on holy tiles. Source: Eevee, Lycanroc, Nocturne |
| **Hidden or secret** | A ??? stub until a deed is done | Slime eats a mimic chest three times without using a power: Mimic Slime. Spider eats five goblins: Lure (a humanoid disguise that changes village standing). Goblin: a recipe learned only in a trap room. Source: Glutton (secret skill), Vampire Survivors Collection |
| **Regression** (temporary) | A downgrade that heals | A vampire starved of blood falls back to ghoul until fed; a slime loses a part slot when starving. Never remove a form already earned. Source: Hungry Shark, E.V.O. docks points rather than regressing |
| **Temporary fusion** | A timed merge, no regret | Goblin and tamed companion fuse for 20 s (*placeholder*) as a Rider; slime and a held part fuse a limb. Source: Cassette Beasts, Kirby Helpers |
| **One-time capstone** | An apex bought once per life | Undead Lich or Vampire at the crypt altar for most of the held dark or blood; slime apex in the demon area for a full bank of two elements; wolf apex after 10 pounce kills of one prey kind. Source: Hades' top Mirror cost, Slay the Spire's Searing Blow |
| **Modular body** | Parts show on the sprite | Undead grafts attach ribs, a bow-arm or a skull; slime held parts sit inside the jelly (gelatinous cube, King Slime's ninja). Source: Evolva, Cassette Beasts modular design, gelatinous cube |

---

## 5. Slime: tighten the tree, then add lineages

### Four cheap fixes
1. **Branch decides child.** Pair the power evolved with the S3 form (table above). For Toxic choose by family, so four evolved powers map to two children; if both families were evolved, offer both (the choice returns). Bulwark and Echo need branching powers: Tremor splits into **Aftershock** (a line wave) or **Shatter** (breaks cracked floors and armor), leading to Golem or Crystal; Echolocation splits into **Pulse Reveal** (reveals hidden walls and trap triggers, which doubles as trap sensing, `area-level-design.md` TR3) or **Sonic Lance** (a piercing note), leading to Phantom or Sky. [inf]
2. **Stage 4 inherits one passive from the S3 you took.** No new sprite, only a trait or a tint change: Stone from Golem keeps Toughness, Stone from Crystal keeps a reflect. Now the S3 choice is felt at S4 and the screen's "converge" node lists which parent you came by. [inf: Jogress, duo boons]
3. **Give each S3 form a restriction.** Golem: slower, cannot Leap. Crystal: brittle, cannot regenerate. Brook: cannot hold a heavy part. A branch is an identity when it gives something up. [inf: Dungeon Crawl species limits]
4. **Preview.** The card shows the two children, or stubs, before the first press. [inf: Nocturne]

### New lineage seeds [inf]
| Lineage | Opened by | Reads | Idea | Host |
|---|---|---|---|---|
| **Lumen** | Jolt | light + air | S3 Flash (stuns, blinks) or Halo (healing aura); light is the slime's thinnest element | cathedral font |
| **Hoarder** | Glutton (secret) | earth + light | translucent body shows held parts; S3 Pack (more part slots) or Gizzard (digests faster, spits an indigestible part as a shot); the gelatinous-cube pattern | goblin village junk piles |
| **Ember** | a fire power (later) | fire + earth | lava trail, lava immunity; Terraria's lava slime | volcano |
| **Mirror slime** (enemy) | a rare fleeing enemy | n/a | metal-slime pattern: very low HP, high defence, flees, pays a large essence jackpot; teaches chasing with the bouncer | cave first, deeper later |
| **Vicious variant** (enemy) | dark | n/a | an elite slime driven mad by dark power (Dragon Quest); a cheap crypt and demon-area enemy | crypt, demon |

### Worked builds [inf]
- **Swamp sniper:** Toxic, Poison Breath to Venom Bolt, S3 Acid, S4 Venom: pierces at range, takes damage from contact, cannot regenerate.
- **Tank that digests:** Bulwark with Hoarder-style slots: Tremor to Shatter, S3 Golem, slow but breaks armor; parts held in the shell give passives for a long time.
- **Aerial scout:** Echo, Echolocation to Pulse Reveal, S3 Sky (grants Leap), S4 Storm: reveals traps and hidden walls, weak in a straight fight.

---

## 6. Spider (S1 spiderling, S2 hunter, S3 fork, S4 capstone) [inf]

Identity (design doc): a hit-and-run poisoner that controls space, walking walls and ceilings; web zip is the signature; it devours living things only and carries items or prey in cocoons.

**Powers and their branches** (each a binary branch, replaces its parent in the slot):
| Power | Branch A | Branch B |
|---|---|---|
| Web Shot (catch or slow at range) | Snare Bolt: pins one target along a line | Weave Net: an area net that holds a group |
| Ground Web (laid trap) | Tripline: chain-triggers plates and other webs | Sticky Pit: slow zone with poison ticks |
| Venom Fang (bite) | Neurotoxin: slow and stun stacks | Necrotic Venom: a poison that spreads on death |
| Cocoon (store an item or prey) | Brood Sac: living prey hatches spiderlings | Larder: extra slots |

**Body fork at stage 3:**
| Form | Reads | Verb or passive | Gives up | Host |
|---|---|---|---|---|
| **Shadow-stalker** | dark + air | silent drop from the ceiling with a bonus strike in dim light | weak in lit rooms | crypt |
| **Venomspinner** | water + dark | webs apply poison and spread through trap webs | lower direct damage | swamp |
| **Broodmother** | earth + dark | cocoons hatch spiderlings that carry and harass | slow, fewer solo kills | forest |
| **Sparkweaver** (optional) | light + air (lightning) | a web that chains and stuns | fragile body | cathedral |

Stage 4: **Nightstalker**, **Plaguemother**, **Brood Queen** (commands spiderlings), **Stormweaver**. A secret fifth, **Lure**, unlocks by eating a number of goblins (the doc's "eat the creature while in a given form" unlock kind): a humanoid hybrid that passes as a goblin in the village, so the village's derived standing reads it as welcome (`area-level-design.md` VI2). Sources: Spider So-What's stage names change body plan (small taratect, zoa ele, arachne) with skills shaping the branch; Galvantula's electrified thread suggests lightning; jorogumo and drider for the disguise and hybrid [read]. Fire burns webs, a real trade-off for a later fire-aligned spider.

---

## 7. Goblin (S1 scrapper, S2 scavenger, S3 fork, S4 capstone) [inf]

Identity (design doc): the improviser; weak alone; power from what it carries; learns instead of eating; a tamer evolution is wanted; every form uses items.

- **S1 Scrapper:** throws rocks; roll. **S2 Scavenger:** fixed-recipe crafting (two items make one throwable), the radial wheel, a junk trap.
- **Power branches:** Rock Throw to Sling (range) or Scatter Stones (spread); Junk Trap to Spiked Pit or Net Snare; Offer (the taming verb) to Bond (one strong companion) or Whistle (commands a small group); Smoke Bomb to Blinding or Choking.
- **Fork, and how each is earned by lessons** (the doc: the first defeat, taming or interaction with each creature type teaches its elements once, repeats pay a trickle):

| Form | Reads | Verb | Lessons from | Host |
|---|---|---|---|---|
| **Tamer** | earth + air (mind later) | offer an item to a weakened creature; a companion that grows with lessons | wolves, spiders, beasts | forest, village |
| **Tinker** | earth (fire later) | explosive throwables, rigged traps, more recipe slots | junk, ants, fire creatures | village, volcano |
| **Skulker** | dark + air | sneak strike, smoke bomb | bats, shadows | crypt, demon |
| **Paladin** (alternate) | light | blessed throwables, a shield; redeemed upward | priests, light creatures | cathedral |

Stage 4: **Beastmaster**, **Engineer**, **Assassin**, **Paladin**. Source patterns: Terraria's goblin army (peon, thief, warrior, archer, sorcerer, warlock) shows one species holds a whole role roster, and its Tinkerer shows an enemy race becoming a friendly crafter; Pathfinder hobgoblins as disciplined engineers and alchemists; goblins riding wolves for the tamer link; Warcraft goblin priests channelling the Light for a fee for the redeemed path [read]. Every goblin form keeps items, so each stage 4 adds a gear-slot perk, not a body change. A fused **Rider** (goblin plus companion) is the temporary-fusion shape.

---

## 8. Undead (skeleton line; the tree is fixed by the design doc, this fills it) [inf]

The doc's paths: flesh (skeleton, zombie, ghoul, vampire), bone-ranged (skeletal archer), bone-magic (lich-like). A graft's shape steers the path: ribs and flesh toward zombie and ghoul, a bow-arm toward archer, a skull or focus toward lich.

| Stage | Flesh path | Bone-ranged path | Bone-magic path |
|---|---|---|---|
| 1 | Skeleton (drains life force) | same | same |
| 2 | **Zombie**: graft ribs and flesh; earth + dark; devours flesh; tank | **Skeletal Archer**: bow-arm graft; air + dark; returning bone throws | **Adept**: skull or focus graft; dark; summons a few bone minions |
| 3 | **Ghoul**: claws, paralysing touch, stench; dark + earth | **Deadeye** (optional): arrows that drain | **Lich**: frail, bouncing bone beams, blinks |
| 4 | **Vampire**: dark + blood (later); uses items | | **Skull** (optional): a floating, very frail, very strong capstone (demilich pattern) |

- **Convergence:** a Ghoul that holds a bone-magic graft becomes a **Death Knight** (flesh plus bone-magic join). [inf: Jogress, duo boons]
- **Graft passives to author:** a hooked claw (ghoul), a bone quiver (archer), a phylactery shard that anchors your remains (lich).
- **Holy is the undead's weakness everywhere in the sources:** revenants die to holy intervention, wraiths hate light, ghuls avoid daylight [read: Wikipedia; pathfinderwiki]. So hold undead unlocks in the crypt, cemetery and swamp; make the cathedral a gated challenge (`area-level-design.md` SA2: each form carries a `holy_resist`, so form changes exposure, not access).
- **Rank by drain:** a wraith becomes a dread wraith after consuming enough life force; a lich that loses its soul cage becomes a demilich, a skull; a Warcraft abomination is stitched from corpse parts, graft-as-capstone [read: pathfinderwiki; warcraft.wiki.gg].
- **Zombie variants per area** are a cheap content engine: swamp (fast), graveyard (maggot), frozen [read: Terraria]. Remains and the phylactery map to the altar and the remains pile.

---

## 9. Wolf (S1 pup, S2 hunter, S3 fork, S4 capstone) [inf]

Identity (design doc, species movesets): gallop and skid turn, pounce as the kill verb, vault; devours living things like the spider; a pack animal that can reuse the goblin's taming for bonding.

| Stage | Form | Reads | Verb or passive |
|---|---|---|---|
| 1 | Pup | none | pounce, gallop |
| 2 | Hunter | none | stronger pounce; one bonded packmate at a time |
| 3 | **Dire** | earth | tank: the pounce knocks down heavy targets, knockback-proof |
| 3 | **Grim** | light + air | a guardian that wards a companion and holds holy ground; unharmed in holy zones |
| 3 | **Barghest** | dark | silent in the dark; a fear howl (Mightyena's Intimidate); faster in dim light |
| 3 | **Hellhound** (later) | fire + dark | volcano and demon area |
| 4 | **Greatwolf** (Dire), **Warden** (Grim), **Omen** (Barghest) | | the Fenrir pattern: grows until chains and barriers break (a gate-breaking verb) |
| secret | **Moonbound** | | a night-only form from a rare drop (Terraria's werewolf charm) |

Sources: Lycanroc's fork by time of day (fast, tank, hybrid) as a clean three-way; Houndoom (dark and fire hellhound); Church Grim, a black dog buried to guard sacred ground, as the light-reading wolf for the cathedral; Fenrir; Mightyena's pack and Intimidate [read].

---

## 10. Power trees: node types, recipes, slots [inf]

### Node types
| Type | Rule | Per species tree | Source |
|---|---|---|---|
| **Seed** (base power) | one element or a creature trigger; levels by use | 6 to 8 | repo base powers; Skyrim use-levelling |
| **Fusion** (recipe power) | two elements, an AND of conditions; its hint appears only when a creature carries both | 4 to 6 | Hades duo boons need a boon from each god |
| **Branch** (evolution) | exclusive pair; replaces its parent in the slot; costs held essence; fixed for the life | 8 now, up to 10 | repo; Hades twin talents; Diablo 4 branches |
| **Rider** | a small node on one active using a third element; at most two per active; swappable at an altar; adds a shape (a cloud, a pierce, a heal), never "+10%" | 4 to 6 | Ori Charge Flame modifiers; Diablo 3 runes; Path of Exile 2 support gems |
| **Capstone** | one per lineage; needs an evolved power at a level plus a second element; changes the verb; not levelled; one owner species | 2 to 4 | PoE ascendancy; Hades legendary boons; FFXII single-owner licences |
| **Keystone** | a passive that rewrites one rule and carries a cost; one slot; fixed for the life | 1 to 2 | PoE keystones (72 of them: "Skills Cost Life instead of Mana") |
| **Body** | behavioural thresholds only (survive one lethal hit); bundle numbers into one node | at most 6 | HK charm categories; Diablo 4 removing passive nodes |
| **Stub** | a ??? one step past what you hold | n/a | repo tree-screen spec |

**Sizes (authoring targets).** Slime about 38 nodes (27 powers today, plus about 6 riders, 3 capstones, 2 keystones); spider about 30; goblin about 28 (its actives are items); undead about 26 per branch; wolf about 22. A tree is rich when the player cannot own it all: Skyrim gives 81 perk points for 180 perks (about 45%), Hollow Knight has 45 charms and 3 to 11 notches (well under 15%) [read]. Essence is lost on death and evolutions close siblings, so that scarcity is already built in. The screen's tree box (244 by 274 px) shows about 40 nodes at normal zoom [inf, assuming 48 by 20 px nodes], so one species fits one screen and the combined slime tree needs the camera.

### Recipes
Existing: poison (water + dark), spore (air + dark), jolt (light + air). Planned: ice (water + air) and lightning. **Collision:** lightning's second planned route, light + air, is exactly Jolt's existing recipe. Option [inf]: lightning is "fire + air, or evolve Jolt to level 5 and eat any fire", so the OR never equals another power's AND group (the unlock engine still needs the OR group, deferred in the spec).

| Recipe | Reads | Slime effect | Source |
|---|---|---|---|
| Storm Bolt (lightning) | fire + air, or Jolt at level 5 plus any fire | a chained bolt that stuns | planned lightning; Jolt collision above |
| Frost Snap | water + air | freezes a struck enemy for 2 s; it becomes a platform | planned ice; frozen Ripper (reference doc) |
| Scald Vent | fire + water | a rising hot cloud for 3 s that blinds shooters | Magicka steam |
| Molten Core | fire + earth | glowing body, contact burn, a flame trail; slow while armed | Noita lava |
| Mire | water + earth | the floor turns to mud, slowing all but you; sink to hide | physical logic |
| Grit Storm | earth + air | a sandblast that blinds and grounds flyers | physical logic |
| Smoke Veil | fire + dark | a stealth cloud; the first hit from inside crits | BotW surprising combos |
| Flare | fire + light | a blinding burst that reveals ambushers and staggers dark foes | Echolocation analogue |
| Dread | dark + mind | marks one enemy; it flinches and its neighbours panic | Magicka status logic |
| Clarity | light + mind | a 0.3 s slow window on any enemy telegraph | recognition test |
| Siphon | blood + dark | a touch or bite drains health and heals you | design doc drain |
| Transfusion | blood + light | converts held essence to health, or heals a companion | design doc light, taming |
| Bloodfire | fire + blood | below half health, attacks ignite and you speed up | Hollow Knight low-health charm |
| Thrall | mind + blood | charms a weakened creature | goblin taming, wolf bond |
| Marrow | earth + blood | bone plating that shatters into shards when broken | skeleton graft overlap |

**Pair budget:** eight elements give 28 pairs; Mages of Mystralia cut 20 behaviour runes to 11 and admits its hard-coded combinations were a compromise [read], so ship 12 to 14 recipes in total (three exist, two are planned, so pick 7 to 9 of the proposals below) and leave the other pairs as fizzles with a flavour line (light + dark either cancels or is a deliberate rare recipe, like Magicka's opposites). Physical pairs are guessable (steam, mud, magma); metaphorical ones delight but need a hint (Doodle God). Noita's designer warns that "the simulation can, in fact, be in the way of more interesting gameplay": keep only reactions that change decisions [read].

**The same recipe on five species** (Genshin gives each character its own skill and burst per element, so one element reads through each kit):
| Recipe | Slime | Spider | Goblin | Undead | Wolf |
|---|---|---|---|---|---|
| Poison | Poison Breath cone, Miasma or Venom Bolt | venom on fangs and web strands | dipped throwables | Rot Touch; zombie plague aura | poisoned pounce bite |
| Smoke Veil | exhaled veil | smoke cocoon bomb on a web line | smoke bomb (leads to assassin) | grave mist; vampire mist form | smoke sprint trail |
| Dread | hex touch | a hexed web: cursed prey takes extra when it moves | hex totem | lich curse, doom mark | fear howl |
| Siphon | engulf and drain | drains cocooned living prey | a leech knife in the weapon slot | native to vampire | rending bite heals on pounce kills |
| Thrall | an engulfed enemy fights for you briefly | a brood of hatchlings | a tamed companion, one at a time | raise a kill as a minion | pack bond |

### Levelling by use
Use-based growth fails on triggers the player can fire at will: Final Fantasy II players attacked their own party to grow stats; Skyrim had potion and trainer loops [read]. Mount and Blade levels weapon proficiency on "inflicting damage on other opponents", so the trigger is an effect landing, and the Experience point page notes the usual mitigation, a cap per encounter [read]. [inf] Count effects landing, cap per encounter, never level on a self-targetable trigger. Species proficiencies in the same style as Leap and Wall Cling: **spider** Ceiling Crawl (distance crawled on ceilings) and Zip Master (zips that end gripping a new surface); **wolf** Pounce (pounces that land hits); **goblin** Craft (items combined); **undead** Drain (drained kills); **slime** Bounce (rebound chains).

### Slots and trade-offs
- Four active quick slots stay. Add a passive notch budget (stage 1: 3, stage 4: 7); a passive or rider costs 1 to 3, a keystone 3. Held parts (2 to 5 slots) occupy notches, so one loadout surface serves parts and passives.
- **Overfed** (the overcharm analogue): one extra notch beyond budget, but a hit knocks out 25% (*placeholder*) of held essence, tying the risk to the essence economy rather than to damage.
- Respec: riders and passives free at altars and glow pools; evolutions, capstones and keystones fixed for the life; reincarnation is the respec (Diablo 4's free respec and Hades' free swap are the precedents).
- Hybrid floor: any two actives from different elements always fit; the price of hybrids is held essence (the spec's three dark prices sum to 36 against 29 held).

### Capstone and keystone examples
- **Plague Bloom** (Miasma branch): the cloud stays where it ends and spreads to the next living thing; the Venom Bolt branch gets **Hunter's Mark** instead (bolts home to poisoned targets). The branch picks which capstone exists.
- **Mycelium** (spore line): spores leave a permanent patch in a room until you leave it (changes the room, not a number).
- **Anchor Web** (thread line): place one persistent anchor per room and teleport to it.
- **Quartermaster** (goblin): unlimited combines in the radial wheel, one weapon slot.
- **Keystone Hollow Core** (earth): cannot jump over 2 tiles, takes no knockback, breaks floors beneath you. **Keystone Glutton's Debt:** hold at most 20 essence, but every devour is worth double.

### Price ladder
Anchor on the starting values (water 6; water 6 + dark 10; air 6 + dark 12; dark 14). A branch costs the parent's price; a rider 3 to 4 units of a third element; a capstone twice the parent's price split over two elements and gated on the branch's level; a keystone is priced in its downside. Later bodies cost more: stage multipliers 1, 1.5, 2, 3 (*placeholder*) so evolving the body again never becomes free. Price at least one element the power does not level on, so a scarce element is never the only cost. [inf: Hades Mirror batch costs, Pom of Power exemption, Skyrim's rising curve]

### Sample builds
| Build | Pieces |
|---|---|
| Slime, Venom Skirmisher | Poison Breath to Venom Bolt, Jolt, Hydraulic Propulsion to Jet Dash; Scald rider; Poison Resistance, Regeneration, Toughness |
| Slime, Garden | Spore Cloud to Healing Spores, Sticky Thread to Binding Web, Regeneration; Transfusion rider; Glutton's Debt |
| Spider, Pinner | Web Shot, Ground Web, Venom Fang, zip; Smoke Veil on the web; wall-walk; Anchor Web |
| Goblin, Alchemist | item wheel, poison-dipped throwables, smoke bomb, a tamed companion; Quartermaster |
| Skeleton to lich | bone caster with Dread and Thrall; the keystone "frail" |
| Wolf, Pack Hunter | pounce, a Dread howl, Pack Bond (Thrall); scent tracking |

---

## 11. Areas that unlock or flavour evolutions [inf]

| Area | Essence it carries | What it can unlock |
|---|---|---|
| Forest | air, earth, light | wolf pack bond; spider Broodmother; goblin herb lessons |
| Swamp | water, dark | deepens Toxic; spider Venomspinner; goblin bog lessons; swamp zombie |
| Goblin village | lessons | goblin Tamer and Tinker; slime Hoarder; Lure |
| Cemetery and crypt | dark, blood arrives | zombie, ghoul, vampire, lich, archer; spider Shadow-stalker; wolf Barghest |
| Cathedral | light, mind | goblin Paladin; wolf Grim; slime Lumen; spider Sparkweaver; undead are hurt |
| Volcano | fire arrives | slime Ember; goblin Tinker explosives; wolf Hellhound; fire lightning recipes |
| Demon area | fire, dark, blood | apex forms paid from held essence, since banking stops after the reveal |
| Traps | parts | a trap part as an edible or graftable item that unlocks a hidden form (a spring-trap Springy Slime); goblin recipes learned in trap rooms |

---

## 12. Soul layer and meta-progression [inf]

- **Death costs:** Dead Cells loses unspent cells and registers blueprints only when carried out; Hades keeps everything; E.V.O. docks about half. Your rule (essence is lost, only the seed carries, banking at altars keeps it) matches Dead Cells [read].
- **Species unlock conditions are runes** (Dead Cells): each unlock can open a route as well as a body; a special species swaps in its own condition (defeat a rare creature, or eat a creature while in a given form).
- **Perks that cost more each time** follow Hades' Mirror ranks; its Keys release the expensive tier in batches of 5, 10, 20 and 30, a model for gating a costly perk by progress.
- **A perk that locks a branch open** (Darkest Dungeon locks up to three good quirks): a head start in a chosen form.
- **Titles reward a pattern, not a count:** the spider novel's "Kin Eater" for eating kin. A title can be a permanent perk for a diet.
- **Naming drives evolution:** Tensura monsters evolve when named; a taming reward could fix a companion's form. [read: Wikipedia, summary-level]

---

## 13. Tree screen rules [inf]

1. Show requirements as a meter before they are earned; exact numbers only after Owned-once (the screen's own rule).
2. One edge style per relation: solid branch, double join for convergence, dashed for environment, dotted for secret.
3. A ??? stub shows slot and silhouette, never name or ingredients.
4. Closed this life reads dim with "reopens next life".
5. Convergence nodes list both parents and mark the missing one.
6. At most five candidate rows; fall back to one lineage at a time (`forms_focus`).
7. A per-species tree with the shared-power rule from the design doc (a power two species share shows in the species that has it innately, a ??? stub for others).
8. Overview zoom has no labels, so silhouette carries meaning: circle seed, hexagon fusion (two-colour fill), square keystone, diamond capstone, small dot rider, dashed ring stub. [inf]

---

## 14. Decisions for Sean

1. **Branch decides child** and **stage 4 inherits a passive** (section 5): build both, one, or neither? They are the two cheapest ways to make the slime's stage-3 choice matter.
2. **How many forms per non-slime species?** The slime has 24; the sketches here have 8 to 12 each. Art cost decides; modular parts (undead grafts) are the cheap path.
3. **Does a species-specific condition open a form** (Lure from eating goblins, Moonbound from a night drop), or are all forks menu choices?
4. **What does light do for an undead player?** It hurts them in the cathedral, so is there any light-aligned undead form, or is light closed to them?
5. **Which elements arrive first, fire, mind or blood?** The tinker, hellhound and vampire branches wait on them.
6. **Lightning versus Jolt:** make lightning "fire + air, or evolve Jolt to level 5 and eat any fire", or retire the light + air route?
7. **A passive notch budget** (3 to 7) and the **Overfed** risk: adopt, adapt or skip?

---

## Sources

Read (fetched; summarised by a small model; full lists with every URL in `species-evolution-notes/`):
- Evolution systems: pokemondb.net (evolution; Lycanroc, Goodra, Muk, Ariados, Galvantula, Houndoom, Marowak, Cofagrigus, Mightyena); Wikipedia (Eevee, Digimon, Spore, E.V.O.: Search for Eden, Evolva, Flow, Hungry Shark, Vampire Survivors, Tamagotchi, Shin Megami Tensei III: Nocturne, Dragon Quest Monsters, Cassette Beasts, Dungeon Crawl Stone Soup, Path of Exile, Slay the Spire, Kirby, Rogue Legacy, Hades, Hades II, Dead Cells, Game balance, Re:Monster, That Time I Got Reincarnated as a Slime, So I'm a Spider So What?, Aria of Sorrow); rogueliker.com (Everything Is Crab); godisageek.com (Biomorph); hades.wiki.fextralife.com (Mirror of Night, Boons); deadcells.wiki.gg (Runes); slaythespire.wiki.gg (Upgrade); darkestdungeon.wiki.gg (Quirks); raw.githubusercontent.com crawl manual.
- Ladders: Wikipedia (Slime (Dragon Quest), Gelatinous cube, Lich, Draugr, Werewolf, Goblin, Jorogumo, Arachne, Drider, Hellhound, Black dog, Fenrir, Warg, Ghoul, Wight, Revenant, Vampire, Bugbear, Kobold); terraria.wiki.gg (Slimes, King Slime, Goblin Army, Goblin Summoner, Skeleton, Necromancer, Zombie, Wall Creeper, Black Recluse, Werewolf); dragon-quest.org (Slime, Metal Slime); warcraft.wiki.gg (Goblin, Forsaken); pathfinderwiki.com (Ghoul, Lich, Vampire, Goblin, Giant spider, Skeleton, Ooze, Werewolf, Wolf, Wraith, Hobgoblin, Bugbear, Zombie, Wight).
- Skill trees and combinations: Wikipedia (Path of Exile, Path of Exile 2, Magicka, Noita, Final Fantasy II, X and XII, Mount and Blade, Experience point, Gothic, Diablo III, Salt and Sanctuary, Genshin Impact, Doodle God, Infinite Craft); poedb.tw Keystone; diablo4.wiki.fextralife.com Skills; en.uesp.net (Skyrim Perks and Leveling, Morrowind Leveling); hollowknight.wiki.fextralife.com Charms; hades.wiki.fextralife.com (Boons, Mirror of Night, Pom of Power); gamedeveloper.com (Mages of Mystralia spell crafting, Noita, what is depth, the short end of Skyrim, pack-ratting, power progression, Space Station 13, Hollow Knight secondary systems).
- Repo: `docs/isekai-chronicles-design-doc.md`; `docs/superpowers/specs/2026-10-03-essence-overhaul-design.md`; `2026-09-29-skill-evolution-branches-design.md`; `2026-10-03-skill-tree-screen-design.md`; `2026-10-04-species-movesets-design.md`; `data/forms`, `data/skills`, `scripts/forms/form_offers.gd`.

Not found: rank tiers, level caps and skill inheritance in the isekai sources (Fandom blocked); Monster Sanctuary shifts and catalysts; Digimon stage names and care branching; Path of Exile respec rules; Biomorph's kill count and Everything Is Crab's meta-progression; any sourced number for branches per stage (the 2 to 3 per choice and 8 to 12 forms per species are mine); designer essays on evolution trees (search was unavailable).
