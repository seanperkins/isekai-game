> Unedited agent notes. Where they conflict with `../species-evolution-guide.md`, that document wins. The web-search budget was exhausted before this research began, so every web claim comes from a directly fetched page.

# Evolution SYSTEM design precedents (Isekai Chronicles research notes)

Method and limits (read first)
- The WebSearch budget was exhausted (200 of 200) before the first query, so no search was possible. Every page below was fetched directly by URL; no search-result snippets exist, so there are no [snippet] items. [read]
- WebFetch answers come from a small summariser, so a claim tagged [read] means "the fetched page said this, as summarised". Only four sentences were re-fetched verbatim; they are marked EXACT. Everything else is paraphrase. [read]
- Blocked or failed after the stated tries (not retried): Fandom (402 on three different wikis), Bulbapedia 403, WikiMon 403, Wikirby 403, poewiki (Anubis wall), Fextralife Monster Sanctuary (DNS), chaosforge DCSS wiki (refused), Seven Seas 403, Wikipedia pages for Everything Is Crab, Digimon World and Hungry Shark Evolution (404). [gap]
- Tags: [read] fetched and read; [inf] my inference, with its source named; [gap] searched or fetched, nothing found. I did not re-survey Hollow Knight charms, Ori, Bloodstained or Aria; see docs/research/metroidvania-reference.md section 2 for those.

## 1. SURVEY: structure of evolution and transformation systems

Per entry: structure | what the player chooses | cost | reversible | preview | stages and pacing.

- Pokemon. Branching and conditional. Conditions: level, elemental stone, trade (sometimes holding an item), friendship (sometimes with time of day), gender, time of day, location, a known move. [read, pokemondb.net/evolution]
  - Eevee has 8 evolutions, added across Gen I (3), II (2), IV (2) and VI (1); a ninth Flying-type was planned for Sun and Moon and scrapped for resembling fan designs. [read, Wikipedia Eevee] (pokemondb's own summary said "seven" but listed eight; the Wikipedia count of 8 is used.)
  - Eevee's triggers are mostly environmental or item-based, not a menu: three stones for Vaporeon, Jolteon and Flareon; friendship by day or by night for Espeon and Umbreon; a nearby moss rock or ice rock (or a stone, by version) for Leafeon and Glaceon; a Fairy move plus affection for Sylveon. [read, pokemondb.net/evolution]
  - Creator note: Fujiwara wanted "a blank slate Pokemon" and Tajiri wanted one that could evolve into several types. Paraphrase. [read, Wikipedia Eevee]
  - Mega Evolution, Dynamax and Gigantamax are temporary, battle-only transformations, distinct from permanent evolution. [read, Wikipedia Pokemon series]
  - Preview, cost and reversibility of normal evolution: not stated on the pages read. [gap]
- Digimon. "Normally linear, but there are other methods, depending upon the media"; Jogress ("joint progress", "DNA Digivolution" in English) is two or more Digimon combining into one being. This is the clearest convergent precedent. [read, Wikipedia Digimon]
  - Stage names, care-based branching and de-digivolution rules were not on the pages read (Digimon Story: Cyber Sleuth page only gave "249 unique Digimon"). [gap]
- Spore. Five stages (Cell, Creature, Tribal, Civilization, Space), any of which you may stay in indefinitely; the studio called each phase "ten times more complicated" than the last. Eating and hunting earns DNA points, spent in editors (eighteen editors across phases); parts must first be collected from other creatures or skeletal remains. Playstyle (aggressive or peaceful) sets "consequence traits" for the next stage. Paraphrase. [read, Wikipedia Spore]
  - Critique: choices are cosmetic ("whatever the player thinks looks cool"); GameSpot found elements "extremely simple"; Wright targeted casual accessibility (Sims 2 score, not Half-Life). Paraphrase. [read, Wikipedia Spore]
- Everything Is Crab. Level-up picks from skill trees, "125+ evolution-based abilities", active and passive, in rarity tiers; some paths lock out others ("forcing you to think carefully about the long-term direction of your build"). Leveling comes from eating fruit and hunting; each pick changes appearance (stinger, fur). Runs last about 20 minutes. Re-roll selections, or raise rarity pools using boss and alpha-enemy materials. Paraphrase. [read, rogueliker.com review]
  - Important for diet design: in this review the eating gives levels, and the adaptation is a menu pick, not something the diet decides. [inf, from the same review]
  - What persists between runs: the review names only "pressure levels and standalone challenges". [gap]
- Monster Sanctuary. Every creature has its own skill tree; eggs from defeated monsters hatch into the roster; 111 monsters; "hatch, collect, evolve and train". [read, Wikipedia and Steam page]
  - The catalyst-item evolutions and Shifted (Light/Dark) variants were not on any page read. [gap]
- Biomorph. Kill an enemy and you can morph into it; at first the form works only in the room where you killed it, then "at a certain number" you can switch to it any time; the form is powered up by killing more of that type; you slot abilities and forms onto three face buttons. Reviewer: the morphing is "the star of the show". Paraphrase. No resource cost is mentioned. The kill count and any preview of new forms are not on the page. [read, godisageek.com] [gap for the count]
- Shin Megami Tensei and Persona. Recruit by negotiation, then fuse two demons into a stronger one; Nocturne lets you preview the result before committing; skill inheritance is randomised; "sacrificial fusion" adds a third demon; results vary with the Kagutsuchi moon phase and Deathstone items. [read, Wikipedia Nocturne]
  - Persona fusion runs from two Personas (Persona 2) to up to twelve (Persona 4); Social Link rank unlocks which Arcana can be summoned and fused. [read, Wikipedia Persona series]
  - Nocturne's Magatama (the protagonist's equipped item) gives skills on level-up and passive buffs and debuffs; whether swapping is reversible was not stated. [read] [gap for reversibility]
- Dragon Quest Monsters. Breed or synthesise two monsters into one; in the early games the parents vanish; the system is "often cited as one of the series' highlights, in part due to being able to create monsters that cannot otherwise be obtained". [read, Wikipedia DQM]
- Cassette Beasts. Any of 120 monsters can fuse temporarily in combat, giving "over 14,000 fusions" through modular parts "combined automatically"; one reviewer liked the procedural fusions less. Temporary, so no regret. [read, Wikipedia Cassette Beasts]
- Dungeon Crawl Stone Soup (DCSS). 27 species, 26 backgrounds, 26 gods (v0.33). Species change HP per level, skill rates, starting stats, special powers and limits; "humans are the average to which all other species are compared". Mutations: good or bad, many with levels, some temporary; a potion of mutation removes mutations but adds random ones; Demonspawn mutations are permanent; undead cannot mutate. Gods can be renounced with penalties. Paraphrase. [read, Wikipedia and crawl_manual.rst]
  - Stated aim of the project (EXACT fragment, re-fetched): "to avoid providing illusory gameplay choices where one alternative is always superior". [read, Wikipedia DCSS]
  - The developer-facing species and mutation guides are implementation docs and state no balance philosophy. [read, species_creation.md and mutation_creation.txt]
- Path of Exile. One shared passive tree of 2,268 passives; each of seven classes has three Ascendancy options, chosen through Labyrinth trials, with up to 8 ascendancy points out of 12 or 14. Whether a choice can be respecced was not on the page. [read, Wikipedia PoE] [gap for respec]
- Hades. A boon choice offers three persistent boosts; four rarities (Common, Rare, Epic, Heroic); five slots (Attack, Special, Cast, Call, Dash), one boon per slot; Duo boons are only offered if you hold a boon from each of the two gods; Legendary boons need a set of prerequisite boons. [read, Wikipedia and Fextralife Boons]
- Dead Cells. Cells spent at the Collector for permanent unlocks; blueprints must be carried out of a level to register; runes are permanent route-openers; three stat colours (Brutality, Tactics, Survival). Motion Twin deliberately arranged things so players "try out new combinations". Paraphrase. [read, Wikipedia and deadcells.wiki.gg]
- Kirby. Swallow an enemy to copy its ability; some games let you combine abilities; Super Star added Helpers; Forgotten Land added upgradeable abilities (Fire to Volcano Fire to Dragon Fire) and "Mouthful Mode". [read, Wikipedia Kirby] The enemy's look foreshadowing its power is the series' habit but the page did not say it. [inf, from the Sword Kirby example on that page]
- Rogue Legacy. On death you pick one of three random heirs (expandable to six), each with traits (colour-blindness, ADHD, dwarfism and others) and a class; gold funds a persistent Manor. [read, Wikipedia]
- Slay the Spire. After a fight you are offered one of three random cards, or skip; about 75 cards per character; at a campfire you Rest or Smith (upgrade one card); a card upgrades once, except Searing Blow; up to 20 Ascension levels. [read, Wikipedia and slaythespire.wiki.gg]
- Darkest Dungeon. Heroes hold at most 10 quirks (5 positive, 5 negative); at the cap a new quirk replaces a random one; the Sanitarium can permanently lock up to three positive quirks and remove or reinforce one per week; some quirks restrict stress relief options. [read, darkestdungeon.wiki.gg]
- E.V.O.: Search for Eden. Eat meat from kills to earn EVO points, spend them on eight body sections; five geological eras, with era-specific options; effectively linear; death does not regress you, it docks "roughly half" of your EVO points and returns you to the map. [read, Wikipedia]
- Evolva. Absorb DNA from creatures you killed to grow new abilities and visible traits (spikes, horns); 12 levels; publisher claim of "over one billion possible variations". [read, Wikipedia]
- Flow. Eating adds segments uniformly, you choose how deep to dive; critics called it "more of an art piece than a game"; Chen's thesis was dynamic difficulty. Diet does not change the form. [read, Wikipedia]
- Hungry Shark. Diet is gated by strength (a reef shark cannot eat stingrays, a mako can); you die if you stop eating; bigger sharks are bought with currency. [read, Wikipedia Hungry Shark]
- Vampire Survivors. A weapon evolves when fully upgraded and paired with a specific passive item (often at max level), opened from a chest; six weapon and six passive slots; the Collection menu hints at pairings. Two parents to one child. [read, Wikipedia]
- Tamagotchi. EXACT: "the resulting character depends on how the player has cared for it during the earlier baby, child and teen stages." The original models have six adult characters. A claim that players are not told the conditions appeared in the summary but could not be re-fetched verbatim. [read] [gap for the hidden-condition claim]

Stage counts and branch widths observed (no designer gave a "right" number): binary (this repo's own power evolutions; Hades Mirror pairs), three (Hades boons, Slay the Spire rewards, PoE ascendancies per class), eight (Eevee, a one-species hub), five stages (Spore, E.V.O.). [read, as listed above]

## 2. WHAT MAKES A CHOICE MEANINGFUL (versus cosmetic or a trap)

- Definition. A dominant strategy "is always the most likely to lead to success, making it objectively the best strategy" (EXACT, re-fetched); a meaningful decision is one whose alternatives are neither without effect nor is one clearly best (paraphrase; the first fetch returned this but a verbatim re-fetch returned a different sentence, so treat it as summary-level). [read, Wikipedia Game balance]
  - Power and costs: "power is everything that provides an advantage, while costs are essentially everything that is a disadvantage"; intransitive (rock-paper-scissors) relations are the standard dominance fix. [read, same page]
- Trade-offs, not upgrades. Slay the Spire's campfire sets Rest against Smith: you give up healing for a stronger deck. [read, slaythespire.wiki.gg] Hollow Knight charms cost limited notches, forcing loadout choices; a reviewer says "I could never find a 'right' answer when equipping them" and another says removing one "felt like trading a part of myself". Not re-fetched verbatim. [read, Wikipedia Hollow Knight]
- Identity. DCSS species are defined by what they cannot or can barely do (Trolls strong but weak at magic, Deep Elves the reverse), with Human as the baseline. [read, crawl_manual.rst] [inf: restrictions are what make a branch an identity, not a bigger number]
- Cosmetic trap. Spore's critics say the editors reward "whatever looks cool" because the choices carry no consequence; the consequence traits it did have came only from playstyle. [read, Wikipedia Spore]
- Dominance is not always fatal in single-player. Mega Crit welcomed strong card synergies because "it was a single-player game and there would be no opponent that would feel overwhelmed". The page's heading says they prevented dominant strategies; its content says the opposite, so cite the content. [read, Wikipedia Slay the Spire] [inf: tolerate a strong branch if it costs something; ban only a branch that is free]
- Commitment and regret. Everything Is Crab lets some paths lock out others on purpose (careful long-term direction). [read, rogueliker] Darkest Dungeon lets the player lock three good quirks to protect them from random replacement. [read, darkestdungeon.wiki.gg]
- Respec and reversibility. Hades' Mirror has 8 primary and 8 alternate talents; "you cannot use both a Talent and its alternate"; you can swap between them freely and the bonuses persist. [read, Fextralife Mirror of Night] DCSS lets you renounce a god at a penalty. [read, crawl_manual.rst] Cassette Beasts removes regret by making fusion temporary. [read, Wikipedia] PoE's respec rules: [gap].
- Preview and foreshadowing. SMT Nocturne shows the fusion result before you commit. [read, Wikipedia Nocturne] Vampire Survivors' Collection hints which passive evolves which weapon. [read, Wikipedia] Biomorph lets you try a form in the room where you killed it before it unlocks anywhere. [read, godisageek] Kirby's enemy-to-ability link is visible in the enemy's look. [inf, Kirby page example]
- Preventing one best branch (observed levers). Limit slots (Vampire Survivors 6 and 6; Hollow Knight notches; Darkest Dungeon 5 and 5). [read] Offer subsets, not menus (Hades, StS, PoE offer three). [read] Make the best option conditional on what you already hold (Duo and Legendary boons). [read, Fextralife Boons] Gate by place or time (Eevee, E.V.O. eras, Nocturne moon phase). [read]
- How many branches. Binary and three-way are the observed norm for a decision a player must hold in their head; eight appears only as a hub (Eevee) and its eight are told apart by clear, different conditions. [read] [inf: 2 to 3 visible options per choice point; never more than five rows on screen, which also matches the repo's own five-row Form tab]
- Keeping convergent trees readable. Observed convergence is always "two named parents" (Jogress, Duo boons, weapon plus passive, SMT two-demon fusion), not three-plus. [read] [inf: draw a join node with exactly two inbound edges, name both parents in the stub, show the missing parent as a ???]
- Repo fit: the essence spec's accepted outcome (after a Cave and Grotto clear almost every life is offered the same five lineages, essence-overhaul "Open for Sean 6") matches the Game balance and DCSS definitions of an illusory or trivial choice. [inf, from Game balance definition and DCSS fragment; repo spec read]

## 3. DIET- and CONSUMPTION-DRIVEN evolution

- Games where eating feeds the form: Spore (DNA points from eating and hunting; parts must be collected from other creatures or remains), Evolva (DNA from kills changes the body visibly), E.V.O. (meat becomes EVO points spent on body sections), Flow (eating adds segments), Hungry Shark (diet limited by strength), Carrion (store text: "Grow and evolve ... acquire more and more devastating abilities"), Kirby and Biomorph (the kill grants the form). [read, pages listed in Sources]
- Legibility patterns seen. Visible body change on absorb (Evolva spikes and horns; Everything Is Crab visual mutations). [read] Ladder of access (Hungry Shark: bigger body, bigger menu). [read] Era-limited menu keeps options small (E.V.O.). [read] Forms usable immediately in a safe place before unlocking everywhere (Biomorph). [read]
- Where the diet is not the decision. Flow adds uniform segments whatever you eat; Everything Is Crab turns eating into levels and then offers a menu. [read] [inf: a diet system only reads as "you are what you eat" if the eaten thing changes what the menu offers, which is the repo's existing recipe and powers-owned design]
- Random drops are the known enemy of diet clarity. Aria of Sorrow's soul drops are the repo's cited failure (random bad-luck streaks; see metroidvania-reference section 2.10, via the Holism essay); the page read here confirms "most enemies eventually yield unique souls" with varying acquisition rates. [read, Wikipedia Aria of Sorrow]
- Reading the diet as a verb. Re:Monster: Absorption "allows him to absorb the powers of anything he eats", for example eating insect monsters gives flight and an exoskeleton; a class change ("Noir Soldat") came through monster flesh. [read, Wikipedia Re:Monster] Tensura: Predator "absorbs and mimics the abilities of any creature he consumes". [read, Wikipedia Slime characters]
- Failure modes. Hidden conditions push players to wikis (Tamagotchi's adult form depends on early care; Eevee's friendship plus time-of-day conditions). [read, Wikipedia Tamagotchi; pokemondb] [inf: hidden conditions are fine for secrets, harmful for the main path]. Min-maxing: the Slay the Spire developers accept it in single-player. [read] No source on guide-following fixes was found. [gap]
- Fixes designers used (observed): permanence limits on bad outcomes (E.V.O. half-points on death rather than regression); a visible Collection or preview of recipes (Vampire Survivors, Nocturne); a re-roll tool (Everything Is Crab re-rolls selections, raises rarity pools with boss materials). [read]
- Fixes for this game (inferences). [inf, sources named per line]
  - Deterministic counts per creature (the repo's existing "N eaten" rule; Aria critique). [inf]
  - Show "diet share" as a bar per element on the Skills tab so the player sees why a form is offered (Hungry Shark's visible ladder). [inf]
  - Hide only the deepest secrets; show stubs one step ahead (Vampire Survivors Collection). [inf]

## 4. THE ISEKAI SOURCES' own mechanics (Wikipedia level; no usable non-Fandom wiki)

- Isekai framing. The body is often non-human; protagonists get "cheats"; the setting "can contain LitRPG elements and draws heavily from JRPG video games"; LitRPG treats visible stats as "a significant part of the reading experience". [read, Wikipedia Isekai and LitRPG]
- Re:Monster. Absorption: the protagonist (Rou, called Gobrou in the summary) gains powers of whatever he eats; line goblin to hobgoblin to ogre to apostle lord; classes (mage, cleric, support) and rare class steps; one character "evolved into a Spell Lord due to her dedication to magic"; the elder's naming of the protagonist matters. [read, Wikipedia Re:Monster] The summariser noted that the page has no stats, level or rank formulas. [gap for rank and level cap]
- That Time I Got Reincarnated as a Slime. Predator devours and mimics; Great Sage is a Unique Skill that acts as an AI advisor and "evolves into Raphael" after Rimuru becomes a Demon Lord; naming monsters drives their evolution (goblin to hobgoblin, ogre to Kijin and later Oni, lizardmen to Dragonewts). [read, Wikipedia characters list] The claim that Demon Lord status came through consuming defeated enemies is summariser-level and unverified; do not rely on it. [read, unverified]
- So I'm a Spider, So What? Skills are bought with skill points earned from leveling (she wasted her first points on Appraisal); titles reflect deeds ("Kin Eater" for eating kin); reaching a level cap triggers evolution; an administrator watches. The summariser's evolution chain mixes in a form that may belong to another character, so use it as "multi-stage evolution" only. [read, Wikipedia Spider, summary-level]
- Not found on any fetchable non-Fandom page: rank tiers, skill inheritance across evolution, exact level caps, the Predator to Gluttony to Beelzebuth chain, Re:Monster's rank-up rules. [gap] From prior knowledge only (not verified this run): skills in these works tend to evolve into upgraded versions, titles grant bonuses, and evolution is often forced by reaching a level cap or a life-threatening event. [inf, unverified memory]
- Mechanical lessons for this game. [inf, from the reads above]
  - Naming drives evolution (Tensura): a "named" mark could be a taming reward that fixes a companion's form. [inf, Slime characters page]
  - Titles reward a pattern, not a count ("Kin Eater"): a title can mean a permanent perk for a diet. [inf, Spider page]
  - Evolution is a rank-up gated by level cap (Spider), the same as this repo's level cap gating body evolution. [inf, Spider page, summary-level]
  - Specialisation by dedication (Spell Lord): a form chosen because you did one thing, which is the "fork by diet" shape below. [inf, Re:Monster page]
  - Skill inheritance: the repo's evolved power replacing its parent matches Great Sage becoming Raphael. [inf, Slime characters page]

## 5. META-PROGRESSION across deaths

- Dead Cells. Unspent cells are lost if you die; cells spent at the Collector buy permanent items; blueprints must be carried out of a level to register (banking); runes are permanent route-openers earned by defeating elites; the ten listed runes each gate named areas (Vine to the Toxic Sewers, Spider to the Prison Depths and others, Ram to the Ancient Sewers, Teleportation to many biomes, Explorer's reveals the map at 80 percent). [read, Wikipedia and deadcells.wiki.gg]
- Hades. Mirror of Night: 16 talents (8 plus 8 alternates), costs from about 10 to 30 Darkness per rank for cheap ones to 500 to 2,250 for the top one, with Chthonic Keys unlocking the bank in batches of 5, 10, 20, then 30. [read, Fextralife Mirror of Night] Pact of Punishment adds optional difficulty. [read, Wikipedia] Hades II: items from runs fund a Crossroads hub that unlocks and upgrades abilities, incantations and weapons. [read, Wikipedia Hades II]
- Rogue Legacy. Gold carries between lives into a Manor and unlocks classes; unspent gold must be paid to the Charon toll at the next entry, offset by upgrades; heirs are three random options. [read, Wikipedia Rogue Legacy]
- E.V.O. dock-half-on-death versus Hades' full keep versus Dead Cells' lose-unspent: three observed death costs. [read]
- Roguelite definition. Persistent progression through "a metagame"; unlocks include new characters at the start and new items and monsters in the generation. [read, Wikipedia Roguelike] Purists objected to the dilution. [read]
- Biomorph and Everything Is Crab meta-progression: not described on the pages read. [gap]
- Fit with this game's soul layer. [inf, source named]
  - The repo's "essence lost, only the death seed carries" rule matches Dead Cells' lose-unspent-cells, with banking at altars the equivalent of carrying cells to the Collector (and blueprints out of a level). After the reveal banking stops, so perks are paid from held essence directly, which is a rule with no precedent found in these sources. [gap]
  - [inf, Hades Mirror] Soul perks bought "several times at a rising price" follow Mirror's rank costs; gating the more expensive perk by progress milestones follows the Keys batches (5, 10, 20, 30).
  - [inf, Dead Cells runes] Species unlocks are runes, already the repo's design; each species unlock can double as a route key.
  - [inf, Hades Mirror, Dead Cells runes] A head start purchased at an altar resembles a Mirror rank, but the repo's "where" half (altar choice) is closer to Dead Cells' biome runes.
  - [inf, Hades Mirror alternates] Alternate-pair swapping maps to a perk that swaps which branch of a pair is open from the start of the next life.

## 6. IDEAS for THIS game (all [inf]; source named per item)

### 6a. The anti-dominance centrepiece (answers essence spec "Open for Sean 6")
1. Offer at most 3 stage-2 lineages, chosen by diet share, then allow skip-to-fallback. [inf: Hades, Slay the Spire and PoE all offer three; ranking by summed power levels was biased toward Bulwark per the repo spec, but diet share (held essence per element divided by the total) is normalised per element, so it does not inherit that bias; it needs a lineage-to-element table to be authored]
2. Gate the offer on held essence, not owned powers. Evolving a power spends essence, so evolving first can close or delay a lineage. [inf: Slay the Spire's Rest versus Smith; Hollow Knight notches; Game balance "power and costs"] Today `level_of > 0` makes every lineage open in a Cave clear, so the spend never competes with the form.
3. Tie each stage-2 offer to a place, so the area where you hit the level cap changes the menu. [inf: Eevee's rock-proximity forms; E.V.O. era-specific options; Nocturne's moon phase] For example the Cave altar offers Echo and Bulwark, the Grotto offers Toxic and Tide, the Flooded area offers Tide and Weaver.
4. Keep the exclusive-per-life rule and reopen next life. [inf: Hades Mirror alternates; DCSS renounce penalty]
5. Add a soul perk that locks one body form as a head start. [inf: Darkest Dungeon's lock three positive quirks]
6. Telemetry rule: if one lineage is picked more than about 40 percent, treat it as a rebalance flag; the number is mine, and the Slay the Spire note says tolerance is fine in single-player if the branch has a cost. [inf: Slay the Spire developer statement, Game balance]

### 6b. A menu of evolution SHAPES, each with a worked example
- Branch (binary). Slime: Hydraulic Propulsion to Water Blade or Jet Dash (exists). Spider: Web Shot to Snare Bolt (slows a line) or Trap Weave (a placed mine web). Source: Mirror alternates, repo specs. [inf]
- Branch (three). Stage 2 for the undead skeleton: Flesh (zombie), Bone-ranged (archer), Bone-magic (lich), matching the doc's three paths. Source: Hades three-choice norm, PoE 3 ascendancies. [inf]
- Converge (two parents to one). Undead: a Ghoul that also holds a bone-magic graft becomes a Death Knight (flesh path plus bone-magic path), shown as a join node. Slime stage 4 already converges. Source: Jogress, Duo boons, Vampire Survivors weapon plus passive. [inf]
- Fork by diet (specialisation by dedication). Goblin lessons: 60 percent of lessons from beasts gives Beastmaster, from undead gives Gravecaller, from arcane creatures gives Shaman. Wolf: devouring only living prey of one kind. Source: Re:Monster's Spell Lord, Tamagotchi care branches, Hungry Shark diet ladder. [inf]
- Environment-triggered. Slime at a lava pool in a volcano with fire essence becomes Magma Slime; spider on consecrated ground cannot spin dark webs. Source: Eevee ice and moss rocks, Nocturne moon phase. [inf]
- Hidden or secret. Slime eats a mimic chest three times without using any power, then a "Mimic Slime" stub appears as ??? in the tree; goblin recipe that unlocks only from a trap-room lesson. Source: Tamagotchi hidden conditions (summary-level), Vampire Survivors Collection hints, repo's secret skill Glutton. [inf]
- Regression (reversible downgrade). Vampire starved of blood falls back to Ghoul until fed; slime loses a body slot on starvation. Source: Hungry Shark death by starvation, Darkest Dungeon quirk replacement, E.V.O. docking half points. [inf] Always temporary; never remove a form already unlocked.
- Fusion (temporary). Goblin plus tamed companion fuse for 20 seconds as a Rider; slime plus a held part fuses a limb. Source: Cassette Beasts temporary fusion, Kirby Helpers. [inf]
- One-time capstone. Undead: the Lich (or Vampire) apex form costs most of the held dark (or blood) essence and can be taken once per life, in the crypt altar only; Slime: a stage-4 apex in the demon area costs a full bank of two elements. Wolf: "Dire Wolf" apex needs 10 pounce-kills of one prey kind and a held earth cost. Source: Mirror's top-cost talent (500 to 2,250 Darkness), Slay the Spire Searing Blow as a sink. [inf]
- Graft-as-modular-sprite for undead. Parts attach visually; modular compositing makes many bodies cheap. Source: Cassette Beasts modular design, Evolva visible spikes. [inf]

### 6c. Numbers (all [inf], from the observed ranges in section 1)
- Stages per species: 3 or 4 body stages; the slime's 4 with 24 forms is the upper bound. Observed 5 in Spore and E.V.O. [inf]
- Branches per decision: 2 for powers (their rule), 2 to 3 for body forms; one convergence at stage 4 only, with two named parents. [inf]
- Forms per non-slime species: 8 to 12 (art cost; Cassette Beasts reaches breadth through modular parts, not hand art). [inf]
- Rows on screen: at most 5 parallel candidate rows. [inf]
- Held parts or grafts: tuned per species; Vampire Survivors caps at 6 and 6 and Darkest Dungeon at 5 and 5 [read]; Hollow Knight grows to 11 notches per docs/research/metroidvania-reference.md section 2, not re-read here. [inf, observed caps]

### 6d. Legibility rules for the tree screen
1. Show requirements as a meter before they are earned, with exact numbers only after Owned-once. [inf: repo spec and Vampire Survivors hints]
2. One edge style per relation: solid branch, double join for convergence, dashed for environmental condition, dotted for secret. [inf]
3. A ??? stub shows slot and silhouette but never name or ingredients. [inf: repo spec; Biomorph's trial-in-the-room as foreshadow]
4. Closed this life shows dim with "reopens next life"; swapped alternate shows "inactive pair". [inf: Mirror alternates]
5. Preview before commit: show the stage-3 children (or stubs) on the card before the player confirms. [inf: Nocturne's fusion preview]
6. Convergence nodes list both parents and mark which one is missing. [inf: Jogress, Duo boons]
7. Never exceed five candidate rows; fall back to one lineage at a time (the repo's `forms_focus`). [inf]
8. Per-species tree, with the shared-power rule from the design doc. [inf: repo doc]

### 6e. Areas that unlock or flavour evolutions (new essences arrive with their area, per the repo doc)
- Forest (air, earth, light): wolf pack bond, spider canopy silk lineage; goblin herbalism lessons. [inf]
- Volcano (fire arrives): fire essence; Magma Slime (fire plus earth); fire burns webs, so a fire-aligned spider loses Binding Web, a real trade-off. Lightning recipes become possible (fire plus air). [inf: repo recipes]
- Swamp (water plus dark): deepens Toxic; goblin Bog Shaman; plague Zombie. [inf]
- Cathedral (light, mind): the doc's "light can redeem a monster upward" (goblin to Paladin); undead on consecrated tiles regress temporarily. [inf: repo doc; regression shape]
- Crypt (dark, blood arrives): skeleton grafts; Vampire (top of flesh path); Lich secret path. [inf: repo doc]
- Goblin village: lessons per creature type; tamer evolutions; slime eats gear to become an Armored Ooze. [inf: repo doc; Re:Monster naming and dedication]
- Demon area (fire, dark, blood; post-reveal): capstone forms paid in held essence because banking has stopped. [inf: repo doc; Mirror top cost]
- Traps: trap parts as graftable or edible parts that unlock hidden forms (spring-trap Springy Slime); goblin recipes learned from traps. [inf: repo doc parts and recipes]

## Sources

[read] https://rogueliker.com/everything-is-crab-review/
[read] https://godisageek.com/2024/01/biomorph-could-be-the-next-must-play-metroidvania-hands-on-preview/
[read] https://en.wikipedia.org/wiki/Monster_Sanctuary
[read] https://store.steampowered.com/app/814370/Monster_Sanctuary/
[read] https://en.wikipedia.org/wiki/Spore_(2008_video_game)
[read] https://en.wikipedia.org/wiki/Digimon
[read] https://en.wikipedia.org/wiki/Digimon_Story:_Cyber_Sleuth
[read] https://en.wikipedia.org/wiki/Re:Monster
[read] https://en.wikipedia.org/wiki/That_Time_I_Got_Reincarnated_as_a_Slime
[read] https://en.wikipedia.org/wiki/List_of_That_Time_I_Got_Reincarnated_as_a_Slime_characters
[read] https://en.wikipedia.org/wiki/So_I%27m_a_Spider,_So_What%3F
[read] https://en.wikipedia.org/wiki/Isekai
[read] https://en.wikipedia.org/wiki/LitRPG
[read] https://en.wikipedia.org/wiki/Hades_(video_game)
[read] https://en.wikipedia.org/wiki/Hades_II
[read] https://hades.wiki.fextralife.com/Mirror+of+Night
[read] https://hades.wiki.fextralife.com/Boons
[read] https://en.wikipedia.org/wiki/Dead_Cells
[read] https://deadcells.wiki.gg/wiki/Runes
[read] https://en.wikipedia.org/wiki/Rogue_Legacy
[read] https://en.wikipedia.org/wiki/Dungeon_Crawl_Stone_Soup
[read] https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/docs/crawl_manual.rst
[read] https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/docs/develop/species_creation.md
[read] https://raw.githubusercontent.com/crawl/crawl/master/crawl-ref/docs/develop/mutation_creation.txt
[read] https://en.wikipedia.org/wiki/Slay_the_Spire
[read] https://slaythespire.wiki.gg/wiki/Upgrade
[read] https://en.wikipedia.org/wiki/Kirby_(character)
[read] https://en.wikipedia.org/wiki/Path_of_Exile
[read] https://pokemondb.net/evolution
[read] https://en.wikipedia.org/wiki/Eevee
[read] https://en.wikipedia.org/wiki/Pok%C3%A9mon_(video_game_series)
[read] https://en.wikipedia.org/wiki/Carrion_(video_game)
[read] https://store.steampowered.com/app/953490/CARRION/
[read] https://en.wikipedia.org/wiki/Darkest_Dungeon
[read] https://darkestdungeon.wiki.gg/wiki/Quirks
[read] https://en.wikipedia.org/wiki/Megami_Tensei
[read] https://en.wikipedia.org/wiki/Shin_Megami_Tensei_III:_Nocturne
[read] https://en.wikipedia.org/wiki/Persona_(series)
[read] https://en.wikipedia.org/wiki/Dragon_Quest_Monsters
[read] https://en.wikipedia.org/wiki/Cassette_Beasts
[read] https://en.wikipedia.org/wiki/Roguelike
[read] https://en.wikipedia.org/wiki/E.V.O.:_Search_for_Eden
[read] https://en.wikipedia.org/wiki/Flow_(video_game)
[read] https://en.wikipedia.org/wiki/Evolva
[read] https://en.wikipedia.org/wiki/Hungry_Shark
[read] https://en.wikipedia.org/wiki/Vampire_Survivors
[read] https://en.wikipedia.org/wiki/Tamagotchi
[read] https://en.wikipedia.org/wiki/Game_balance
[read] https://en.wikipedia.org/wiki/Hollow_Knight
[read] https://en.wikipedia.org/wiki/Aria_of_Sorrow
[read] https://en.wikipedia.org/wiki/Metroidvania
[read] https://en.wikipedia.org/wiki/Sid_Meier (no "interesting decisions" line found)
[read] https://en.wikipedia.org/wiki/Biomorph_(video_game) (no gameplay content)
[read] https://en.wikipedia.org/wiki/The_Binding_of_Isaac_(video_game) (no transformation content)
[read] https://en.wikipedia.org/wiki/Etrian_Odyssey (no retire/rebirth content)
[read] https://en.wikipedia.org/wiki/Glossary_of_video_game_terms (none of the requested terms in the excerpt)
[read] https://yenpress.com/series/that-time-i-got-reincarnated-as-a-slime-light-novel (blurb only)
[gap] https://bulbapedia.bulbagarden.net/wiki/Methods_of_evolution (403)
[gap] https://wikimon.net/Evolution (403)
[gap] https://wikirby.com/wiki/Copy_Ability (403)
[gap] https://www.poewiki.net/wiki/Ascendancy_class (Anubis wall)
[gap] https://tensura.fandom.com/wiki/Predator, https://re-monster.fandom.com/wiki/Re:Monster_~The_Goblin_Reincarnation_Chronicles~, https://everything-is-crab.fandom.com/wiki/Evolution (402)
[gap] https://monstersanctuary.wiki.fextralife.com/Evolution (DNS), https://crawl.chaosforge.org/Mutation (refused), https://sevenseasentertainment.com/series/re-monster/ (403)
[gap] Wikipedia pages for Everything_Is_Crab, Digimon_World_(video_game), Hungry_Shark_Evolution, List_of_So_I'm_a_Spider_characters (404); hades.wiki.fextralife.com/Weapon+Aspects (404)
