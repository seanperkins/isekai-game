> Unedited agent notes. Where they conflict with `../species-evolution-guide.md`, that document wins. The web-search budget was exhausted before this research began, so every web claim comes from a directly fetched page.

# Skill-tree, elemental-combination and use-based levelling research (Isekai Chronicles)

Method note. WebSearch hit its session cap (200 of 200) before the first query, so every source below was reached by direct WebFetch of a URL I guessed or found through Game Developer's own site-search page. Fetches are summarised by a small model: quoted strings are as the summariser returned them, NOT re-fetched verbatim. Tags: [read] page opened and summary used; [snippet] search/listing text only; [inf] my inference (source named); [gap] searched, nothing usable. Local repo docs (the five read-first files) are cited as "repo".
Numbers I computed myself are tagged [inf] with the inputs.

## 1. Tree shapes and node types

### 1a. Quoted sizes and branching numbers
- Path of Exile: "All classes share the same selection of 2,268 passive skills" and each class "starts at a different position", in "separate trunks for each class (aligned with the permutations of the three core attributes)". Max passive points 123 on a non-Scion character "(99 from levelling and 24 from quest rewards)" as of 3.0. Ascendancy: three per class, "Up to 8 Ascendancy skill points can be assigned out of 12 or 14." [read] wikipedia.org/wiki/Path_of_Exile
- Same page, derived: 123 of 2,268 is about 5.4% of nodes taken; the player's skill is the path, not the pool. [inf] (123/2268)
- PoE keystones: 72 total = 49 tree keystones + 8 cluster-jewel + 15 timeless-jewel. Examples (text as returned): Resolute Technique "Your hits can't be Evaded. Never deal Critical Strikes"; Chaos Inoculation "Maximum Life becomes 1, Immune to Chaos Damage"; Blood Magic "Removes all mana. Skills Cost Life instead of Mana". Each rewrites a rule and carries its own price. [read] poedb.tw/us/Keystone
- PoE 2 (pre-release statement): "The passive skill tree will have 2000 skills and will allow dual specialization"; "240 active skill gems and 200 support gems"; "twelve character classes that have three ascendancy classes each". Support gems are the modifier layer. [read] wikipedia.org/wiki/Path_of_Exile_2
- Diablo 4, Lord of Hatred rework: "Each Active Skill now has three skill branches that open progressively"; "up to 83 available Skill Points"; skills "ranked up to Rank 15"; "Players choose one modifier from each branch. The first two branches generally provide broader Skill modifiers, while the third branch contains Bonus Skill Variants"; "traditional Passive Skill nodes have been removed from the tree"; "respecs are free and can be done anywhere." This is the closest big-game cousin of a power with 2-3 branches. [read] diablo4.wiki.fextralife.com/Skills (single wiki summary; treat the numbers as unverified against Blizzard)
- Diablo III: runes are "skill modifiers ... unlocked as the player levels up" that "often completely chang[e] the gameplay of each skill" (meteor: one rune cuts cost, another turns it to ice "causing cold damage rather than fire"). The reviewer quoted contrasts it with Diablo II where players "often regretted how I allotted my ability points." [read] wikipedia.org/wiki/Diablo_III
- Skyrim: 18 skills, "180 skill perks are available, 251 if including all ranks"; "Most perks have both a skill level requirement and a prerequisite perk"; "81 perk points total" at level 81, "insufficient for all perks"; Legendary resets a skill "to level 15, refunding perks"; unlocking all perks needs "level 252". [read] en.uesp.net/wiki/Skyrim:Perks
- Skyrim derived: 180 perks vs 81 points means a player takes under half of what exists (about 45%). [inf] (81/180)
- Hollow Knight: "a total of 45 different Charms" (40 inventory slots; 5 transform), costs "1 to 3 or even 4 notches", Knight "starts off with 3 Notches" and "There are a total of 11 Notches". Derived: a player slots roughly 4 to 6 of 40, i.e. well under 15%. [read] hollowknight.wiki.fextralife.com/Charms; [inf] ratio from 3-11 notches over 1-4 cost
- Hades: Supergiant brainstorm "something like 50-or-so ideas" per god and implement "about 15 strong concepts" per god (Alice Lai). Four rarities (Common, Rare, Epic, Heroic) on the wiki. Mirror of Night: 16 talents (8 primary, 8 alternates), max combined rank 102. [read] gamedeveloper.com/design/how-supergiant-added-new-goddess-demeter-to-i-hades-i-pantheon; [read] hades.wiki.fextralife.com/Boons; [read] hades.wiki.fextralife.com/Mirror+of+Night
- Slay the Spire: developers found "about 75 different cards available was the right balance to give some potential strategy to the player"; more would make "deck construction ... much more haphazard". Not a tree, but the same small-pool lesson. [read] wikipedia.org/wiki/Slay_the_Spire
- Bloodstained: six shard types (Conjure, Manipulative, Directional, Passive, Familiar, Skill); Rank and Grade each max 9; Rank "adding secondary abilities", Grade through duplicates; over 100 shards listed. [read] bloodstainedritualofthenight.wiki.fextralife.com/Shards
- Ori and the Blind Forest: "three ability trees"; "Each skill must be learned in sequential order from one of three ability trees"; points come from enemies, plants, spirit light containers and ability cells. [read] wikipedia.org/wiki/Ori_and_the_Blind_Forest
- Monster Sanctuary: 111 monsters, each with "a skill tree for you to customise"; the founder says growth "is dependent on a branching skill tree", "You can come up with a lot of crazy synergies", and "The downside of this is that you can easily make bad builds." Exact nodes per monster not found. [read] store.steampowered.com/app/814370/Monster_Sanctuary/; [read] gamedeveloper.com/design/how-indies-add-flavor-to-monster-combat-25-years-after-pokemon; [gap] skills-per-tree number (fandom 402, wiki.gg 404)
- Salt and Sanctuary: "an extensive skill tree providing hundreds of combinations"; devs said the original design "was much more complex, but some cuts had to be made". Node counts not found. [read] wikipedia.org/wiki/Salt_and_Sanctuary; [gap] node counts
- Final Fantasy X: Sphere Grid is "a pre-determined grid of interconnected nodes consisting of various statistic and ability bonuses"; in the International version "all of the characters start in the middle of the grid", and the Expert grid "has fewer nodes in total". [read] wikipedia.org/wiki/Final_Fantasy_X
- Final Fantasy XII: License Board "an array of panels"; all characters can reach every licence, except "each Quickening and Esper license may only be activated by a single character," which prevents "complete homogenization". [read] wikipedia.org/wiki/Final_Fantasy_XII

### 1b. Node taxonomy seen in the wild
- Stat/small (PoE small passives), notable (PoE), keystone (PoE, rule-rewriting, 72), ascendancy (PoE, class capstone layer, up to 8 of 12/14 points), modifier/support (PoE 2 support gems, D3 runes, D4 per-skill branches, HK charms), ability/active (Ori ability cells, Aria/Bloodstained conjure), passive (Bloodstained passive shard "cost no MP"), familiar (Bloodstained), capstone (ascendancy, D4 "Variant"). [read] sources above; the grouping into this list is [inf].
- Exclusive twins: Hades Mirror "You cannot use both a Talent and its alternate version"; swapping is free. [read] hades.wiki.fextralife.com/Mirror+of+Night
- Prerequisite gates as a discovery device: Hades duo boons "can only be offered by the game if you have a Boon equipped from each of those two deities", legendary boons need specific prerequisite boons, and "Each Olympian deity has only one, aside from Poseidon and Hermes" (the exception as the page gives it). Skyrim perks use skill-level plus prerequisite chains. [read] hades.wiki.fextralife.com/Boons; [read] en.uesp.net/wiki/Skyrim:Perks
- Hades Pom of Power: raises one boon's level; "Legendary, Duo, and some support boons" cannot be levelled. So capstone-grade nodes are exempt from the numeric treadmill. [read] hades.wiki.fextralife.com/Pom+of+Power

### 1c. What makes 20-40 nodes feel rich
- Take less than you can see: Skyrim about 45%, HK well under 15%, StS a 75-card pool. A tree is rich when the player cannot own it all; for this game, essence is lost on death and evolutions close siblings, so the scarcity is already built in. [inf] Skyrim/HK/StS numbers + repo
- Few systems, multiplied: "Depth is the possibility space that allows players to make meaningful choices"; Elden Ring's weapon, scaling attribute and ash of war make "insane playstyles" from "merely adequate" parts. Three small interacting layers beat one big flat tree. [read] gamedeveloper.com/game-platforms/what-is-depth-and-how-do-you-add-it-to-your-game-
- Branching per skill, not per class: D4 LoH puts three branches inside each active; Hades twin talents; HK spell upgrades. Small total node count, but each node reads as "my version of this power". [inf] D4/Hades/HK
- Verbs not numbers: D3 runes "completely chang[e] the gameplay"; PoE keystones rewrite rules; Bycer's critique of Skyrim: "for all the character customizations, the gameplay is shallow" because "You're still moving the same way and swinging the weapon the same." [read] gamedeveloper.com/design/the-short-end-of-skyrim
- Stat soup avoidance: PoE hides raw stat nodes behind a 2,268-node pool and gives players notables and keystones as the meaningful stops; D4 LoH removed passive nodes from the tree entirely to focus on skill customisation; HK charms are single clear effects ("charm effects are stackable"). [read] PoE wiki + D4 + HK secondary-systems analysis (gamedeveloper.com/design/secondary-systems-analysis---hollow-knight); stat-soup framing [inf]
- The pitfalls list from power-progression writing: "Power Creep", "Monotony", "Burnout"; frequent small rewards vs larger milestones. [read] gamedeveloper.com/design/power-progression-in-games-crafting-rewarding-player-experiences
- A tree can fail by being too permissive: Monster Sanctuary admits "you can easily make bad builds"; FFXII keeps single-owner licences so characters do not homogenise. Species-locked capstones serve the same purpose here. [read] GD monster article + FFXII; the species application is [inf]

## 2. Use-based levelling and mastery
- Skyrim (UESP): skill XP per use, "successfully picking a lock gives you more Lockpicking XP than does breaking your lockpick"; character XP to level "= (Current level + 3) * 25" (level 2 needs 100 XP, level 50 needs 1,300); skill cost "= Skill Improve Mult * (level-1)^1.95 + Skill Improve Offset" with multipliers from 0.25 (Smithing) to 900 (Enchanting). [read] en.uesp.net/wiki/Skyrim:Leveling
- Skyrim exploits named: Fortify Restoration potion loop; Oghma Infinium shelf duplication (patched in 1.9.26.0.8); trainer pickpocketing works "up to skill level 30 or so" and "the highest you can go with this 'exploit' is level 76" (76 is that exploit's ceiling, not a trainer cap). Over-levelling without combat skills leaves enemies "far too hard". [read] same page
- Skyrim vs Oblivion design: "restricting the enemy scaling" and "condensing the number of character aspects down" (Bycer). [read] gamedeveloper.com/design/the-short-end-of-skyrim
- Morrowind: "Each time your character increases any combination of Major or Minor skills ten times, they become eligible to gain a level"; attribute multipliers 1-4 increases = 2x, 5-7 = 3x, 8-9 = 4x, 10+ = 5x; trap: a near-capped attribute (96 +5 = 101) loses the multiplier, forcing planning. [read] en.uesp.net/wiki/Morrowind:Leveling
- Final Fantasy II: stats grow "depending on what actions they take"; designer Kawazu was frustrated with "the abstract nature of experience point systems" and wanted "something unpredictable"; exploits: "having their characters attack each other and repeatedly cast spells"; "negative feedback" sent the next game back to ordinary levels. [read] wikipedia.org/wiki/Final_Fantasy_II
- Experience-point article: use-based progression is used by Final Fantasy II, Elder Scrolls, SaGa, Grandia; failure mode is grinding "one specific activity over and over"; mitigation noted: "a limit on the experience a character gains from a single encounter". [read] wikipedia.org/wiki/Experience_point
- Gothic: learning points "are spent by finding the appropriate teacher"; fighting skills have "two proficiency levels"; attributes 10 to 100 in "1 or 5 point increments"; guild choice limits magic circles ("four magic circles (out of six)") for the Swamp camp. Teacher-gated mastery = a diegetic spend. [read] wikipedia.org/wiki/Gothic_(video_game)
- Mount and Blade: "Weapon proficiencies can be improved over time by inflicting damage on other opponents", so the trigger is an effect landing, not a button press. [read] wikipedia.org/wiki/Mount_%26_Blade
- Bloodstained: Grade rises by duplicates (max 9, mostly numbers), Rank by deliberate spend (max 9, adds effects). Two axes: numbers by repetition, behaviour by choice. [read] bloodstainedritualofthenight.wiki.fextralife.com/Shards (the "alchemy" cost detail is from repo reference, not this page)
- Salt and Sanctuary: gather "salt in order to gain power"; per-level cost and respec not found. [gap]
- Pacing lesson: Skyrim's ^1.95 curve and Morrowind's ten-increase gate both make early ranks cheap and late ranks costly; FFII shows the cost of exploitable triggers. For this game the repo says Echolocation "levels at 3 air per level and would reach the stage cap on a Cave and Grotto clear". [read] UESP pages + repo; mapping [inf]
- Resource-gated branching precedents: Hades Pom of Power (spend a pickup to level a boon, exempting Legendary/Duo); Hades Mirror (Darkness plus Chthonic Keys "in batches of two", batches of 5, 10, 20, 30 keys); Bloodstained Rank; D3 runes (free, no spend). Nothing found that spends a held elemental resource to pick one of two exclusive branches except this game's own spec. [read] Hades pages, Bloodstained, D3; the last clause [inf]
- Hoarding: "In-game currency is always a better incentive than a souvenir"; remedies are consumption pressure (breakable weapons), caps and clear value. Essence lost on death is a hard form of use-it-or-lose-it, so a visible price and an "affordable now" prompt matter. [read] gamedeveloper.com/design/pack-ratting-in-video-games-do-players-have-to-have-it-all-; application [inf] with repo (essence lost on death)
- Hades devs interview gave nothing on boons or respec (page was about subgenre origins). [gap] gamedeveloper.com/design/hades-devs-say-accidentally-inventing-a-subgenre-was-surreal-

## 3. Elemental combination design
- Magicka: "eight base elements: water, life, shield, cold, lightning, arcane, earth, and fire"; chain "up to five elements"; two hybrids (steam = water + fire, ice = water + cold) for "ten total elements"; opposing pairs cannot combine (fire and cold); precedence: "Shields take precedence over projectiles (earth and ice), which take precedence over beams (life and arcane), which take precedence over steam ... lightning ... sprays". Special spells ("Magicks") need "specific combinations" and "Spellbooks found throughout campaign levels or dropped by enemies". No mana bar: "a majority of the most powerful spells from the beginning". [read] wikipedia.org/wiki/Magicka
- Noita: wands are containers, spells the contents; four wand stats (cast delay, recharge, mana, mana recharge); spells split into projectiles, modifiers, movement, utility. World: "wood can burn ... Lava can be poured into water ... to create rock, while also evaporating some of it into steam"; "alchemical reactions, like making new magical liquids by combining two others". Six material classes (solids, liquids, magical liquids, gases, powders, organic/other). [read] wikipedia.org/wiki/Noita_(video_game); [read] noita.wiki.gg/wiki/Materials
- Noita design stance (Petri Purho): an unplanned oil-lantern-and-fire death "had never happened to me before"; but "The simulation can, in fact, be in the way of more interesting gameplay" and destructible buildings left "just a bunch of rubble"; workflow "implementing things and then testing them". Lesson: keep only reactions that change decisions. [read] gamedeveloper.com/game-platforms/road-to-the-igf-nolla-games-i-noita-i-
- Mages of Mystralia (article by game director Patric Mondou): went "from 20 different behavior runes to a mere 11"; augment runes; four triggers (onHit, onEnd, onTimer, onCast); one compromise: the defensive category "ended-up having a lot of hard-coded combinations. We didn't like it"; runes unlock one by one so "we can play the game from beginning to end and feel what it's like to learn each rune one by one"; UI feels "like programming, without ... any numeric values". [read] gamedeveloper.com/design/creative-process-of-a-procedural-spell-crafting-system
- Doodle God: start with "fire, water, air and earth"; "249 elements across 26 categories"; pure trial and error with "a hint ... every few minutes"; recipes mix physical ("Water and Lava to obtain Steam and Stone") and metaphorical ("Water and Fire to obtain Alcohol") logic; reviews split 4/5 and 2.5/5. [read] wikipedia.org/wiki/Doodle_God
- Infinite Craft: two elements in, one out; "over 300 million recipes are created each day"; first discoverer labelled "First Discovery"; critics love the surprise and note "occasionally incoherent results." Scale destroys authored coherence. [read] wikipedia.org/wiki/Infinite_Craft
- Genshin: seven elements ("Anemo (air), Geo (earth), Pyro (fire), Hydro (water), Cryo (ice), Electro (electricity), and Dendro (plants)"); Hydro then Cryo freezes; Pyro + Electro = Overloaded; "Each character possesses two combat abilities leveraging their element: an Elemental Skill and an Elemental Burst." The same element is read through each character's own two slots. Full reaction table not obtained. [read] wikipedia.org/wiki/Genshin_Impact; [gap] full reaction list (fandom 402)
- Breath of the Wild: Nintendo called it "active multiplicative" gameplay, "countless events occur, and the player can freely create solutions"; discoveries meant to feel "surprising and unpredictable" ("Baked Apple", elemental Chuchu jelly); "in-world chemistry". Rule counts not published in that article. [read] gamedeveloper.com/design/5-design-lessons-learned-from-i-the-legend-of-zelda-breath-of-the-wild-i-; [read] wikipedia.org/wiki/The_Legend_of_Zelda:_Breath_of_the_Wild
- Space Station 13: depth from "unintended combinations of deliberately designed systems"; mastery is a "knowledge economy"; warning: "If everyone could become a top tier geneticist within an hour or two of playing, then a lot of the fun would be killed." [read] gamedeveloper.com/design/space-station-13-a-case-study-in-emergent-gameplay-and-system-heavy-design
- Divinity Original Sin 2 surfaces: the Wikipedia summary only says players use "water, ice, oil and fire" and that skills "used in combination, can cause significant damage or unique effects"; no rule table found. [read] wikipedia.org/wiki/Divinity:_Original_Sin_II; [gap] surface interaction table and Larian commentary (fextralife 404 x3)
- Alchemy/colour-mixing metaphor sources: none found for a formal colour-mix UI; Magicka's steam and ice hybrids are the closest read. [gap]
- What these add up to (design rules):
  - Cap pairs: Magicka's 8 elements and 5-queue limit give huge space but they kept opposites and precedence; Mystralia cut 20 to 11. 8 elements give 28 unordered pairs; authoring about 12-16 of them is the Mystralia move. [inf] Magicka + Mystralia + C(8,2)=28
  - Physical-metaphor pairs are guessable (steam, mud, magma); metaphorical ones (alcohol) delight but need a hint. [inf] Doodle God
  - Gate with discovery, not a menu: Magicka spellbooks, Hades "must hold both" duos, Mystralia progressive unlock. [inf]
  - A hint clock: Doodle God's hint every few minutes; the repo already uses a creature hint when it carries every element. [inf] Doodle God + repo
  - Opposites and fizzles: Magicka forbids fire + cold; light + dark should either cancel or be a deliberate rare recipe. [inf] Magicka
  - Same recipe, species verb: Genshin gives each character an Elemental Skill and Burst per element; D3 rune changes meteor from fire to cold. [inf]

## 4. Build identity and constraints
- HK notch budget: 3 start, 11 max, costs 1 to 4; overcharm "allows you to equip one additional charm above the charm notch limit, however your character will take double damage from all sources" (GD wording; the wiki summary's "5 attempts" claim is not used). [read] gamedeveloper.com/design/secondary-systems-analysis---hollow-knight; [read] HK Charms wiki
- Bloodstained: "The player can only equip a limited number of shards, but like equipment, shards can be swapped out on the fly"; passive shards are always on and cost no MP, conjure shards cost MP. [read] wikipedia.org/wiki/Bloodstained:_Ritual_of_the_Night; [read] fextralife Shards
- Respec policies: D4 LoH free anywhere; Hades Mirror swap free; Skyrim Legendary reset (level 15 and refund); StS has no tree. HK charm-swap and PoE respec rules: re-fetched Wikipedia for both, neither states them. [read] D4, Hades Mirror, UESP Perks; [gap] HK bench-swap and PoE respec points (not confirmed by any fetched page)
- Active vs passive balance in a small kit: D4 LoH removing passive nodes shows the pull toward actives; Bloodstained keeps six types with passives free of MP; FFXII single-owner licences keep identity. A kit of four quick slots is the binding constraint on actives; passives need their own, cheaper budget. [read] D4, Bloodstained, FFXII; recommendation [inf]
- Synergy design: Hades duo boons are gated behind owning both parents; StS devs "had no issue when players discovered card synergies that created powerful combinations" because it is single-player. Both support authoring a few strong designed synergies rather than a uniform stat bonus. [read] Boons wiki + StS wiki
- Hybrid builds: Monster Sanctuary "crazy synergies" but "bad builds"; give hybrid builds a floor via cheap riders and swap-at-altar. [read] GD monster article; floor idea [inf]
- Capstone/keystone must change play: PoE keystones (72) rewrite resource and defence rules with a cost; Hades legendary/duo are non-levelling set pieces; D3 runes alter the skill's element. Rule: a capstone changes a verb or resource, carries a downside or commitment, and is not numerically levelled. [read] poedb Keystone, Pom of Power, D3; rule [inf]

## 5. Tree legibility on 640x360
- PoE solves size by volume plus zoom (2,268 nodes); FFX Sphere Grid is a fixed grid with start positions, and its Expert version cut nodes to make free roaming legible. [read] PoE and FFX wiki pages; reading as a legibility trade [inf]
- Skyrim's tree is presented as a parallax constellation per skill (Todd Howard talk: "parallax movement and takes the player beyond just shifting through numbers"), i.e. 18 small trees, not one big one. [read] gamedeveloper.com/design/todd-howard-s-2012-dice-keynote-speech-transcribed-contextualized-glorified; [read] UESP Perks
- Readability rules from UI case study: "every item has its own distinct silhouette and color that make it easy to spot at a glance"; custom font attention to "letter height", "boldness" and spacing. [read] gamedeveloper.com/design/6-game-ui-you-should-study
- Controller navigation of non-grid elements: Unity's automatic navigation "uses each object's position to determine which object will be selected when navigating up, down, left, or right", links each object to "up to 4" others, and is "not necessarily one-to-one" (several items can lead to the same target), which is the failure the repo's `neighbor()` edge-first rule with a 45-degree window is built to avoid; explicit navigation lets you hand-wire neighbours. [read] gamedeveloper.com/design/stupid-unity-ui-navigation-tricks; mapping to `neighbor()` [inf]
- Fog of war on graphs, ??? stubs at small resolutions, Hollow Knight map discovery: nothing usable (Wikipedia HK gives only Stag Stations and the charm-notch sentence). [read] wikipedia.org/wiki/Hollow_Knight; [gap] graph fog and ??? stub precedents
- [read] repo (tree-screen spec), this game's own constraints: tree box `Rect2(158, 46, 244, 274)`, FONT_SMALL 8, 27 non-enemy skills (19 base + 8 evolutions) plus 25 form nodes, two zoom levels, camera follows selection, `neighbor()` with a 45-degree edge preference, secrets reserve no slot.
- Capacity math: assuming a node 48 x 20 px with an 8 px gap and a label of at most 9 characters at roughly 5 px per character (assumption), the 244 x 274 box shows about 4 columns by 10 rows, i.e. about 40 nodes at normal zoom; so a 20-40 node species tree fits one screen and a combined slime tree of about 60 powers + forms needs the camera. [inf] repo box size + assumed glyph width
- Shape language for the overview zoom (no labels): circle seed, hexagon fusion (two-colour fill), square keystone, diamond capstone, small dot rider, dashed ring stub. Silhouette carries meaning when text is hidden. [inf] The Long Dark silhouette point + repo overview zoom

## 6. Ideas for this game (all [inf], source named)

### 6a. Node-type taxonomy for powers
| Type | Rule | Count per species tree | Derives from |
|---|---|---|---|
| Seed (base power) | One element, or a creature trigger; active or passive; levels by use | 6 to 8 | repo base powers; Skyrim use-levelling [inf] |
| Fusion (recipe power) | Two-element recipe, AND of conditions; the "duo boon" of this game; hint appears only when a creature carries both | 4 to 6 | Hades duo boons (must hold both parents) [inf] |
| Branch (evolution) | Exclusive pair, replaces parent in the slot, costs held essence, permanent for the life | 8 now, up to 10 | repo; Hades twin talents; D4 branches [inf] |
| Rider (modifier) | Small node attached to one active; uses a third element not in the parent's recipe; max 2 riders per active; swappable at an altar; changes shape (adds a cloud, a pierce, a heal), never "+10%" | 4 to 6 | Ori Charge Flame modifiers (repo), D3 runes, PoE 2 support gems [inf] |
| Capstone | One per lineage; requires an evolved power at a level plus a second element; changes the verb; not levelled; one owner (species-locked) | 2 to 4 | PoE ascendancy, Hades legendary, FFXII single-owner licences [inf] |
| Keystone (trade) | Passive that rewrites one rule and carries a cost; one keystone slot; permanent for the life | 1 to 2 | PoE keystones (72) [inf] |
| Body (utility passive) | Behavioural thresholds only (survive one lethal hit, immune to a medium); bundle numeric nodes into one | at most 6 | HK charm categories, D4 passive removal [inf] |
| Stub (state, not type) | ??? one step past what you hold; recipe hidden until owned once | n/a | repo spec [inf] |
- Sizes: slime today is 27 powers (19 + 8); adding about 6 riders, 3 capstones and 2 keystones gives about 38, inside 20-40. Compare Skyrim about 10 perks per skill, Hades 16 talents, HK 45 charms. [inf] repo counts + UESP + Mirror + HK
- Nodes ratio: about 40% active, 60% passive/body/rider by node count; slotted loadout about 1:1 (4 actives : 4 passive notches at stage 4). [inf] Bloodstained passives free of MP, D4 actives-first trend

### 6b. Cross-element recipes (two elements, species reading in 6c)
Existing or planned first, then new. Slime effect shown; fire, mind and blood arrive with their first creatures.
1. Poison = water + dark: Poison Breath (existing). [read] repo
2. Spore = air + dark: Spore Cloud (existing). [read] repo
3. Jolt = light + air: shock power (existing). [read] repo
4. Frost Snap = water + air (ice, planned): freeze a struck enemy solid for 2 s; it becomes a platform. [inf] repo planned recipe + frozen-Ripper platform from the repo reference
5. Storm Bolt = fire + air OR own Jolt at level 5 and eat any fire: lightning. The planned second route "light + air" is identical to Jolt's recipe, so it would either re-unlock Jolt or collide; use "evolve through Jolt" as the OR. [inf] repo (Jolt = light + air, lightning = fire+air or light+air) + Doodle God multiple routes
6. Scald Vent = fire + water (steam): a rising hot cloud for 3 s that blinds shooters and lifts you slightly. [inf] Magicka steam, Noita steam
7. Molten Core = fire + earth (magma): glowing body, contact burn and a flame trail, slow while armed. [inf] Noita lava, PoE keystone-style trade-off
8. Mire = water + earth: floor patch turns to mud, slows all but you; you can sink in it to hide. [inf] Doodle God physical logic
9. Grit Storm = earth + air: short sandblast that blinds and grounds flyers. [inf] Doodle God physical logic
10. Smoke Veil = fire + dark: stealth cloud; first hit from inside crits. [inf] BotW "surprising" combos
11. Flare = fire + light: blinding burst that reveals ambushers and staggers dark foes. [inf] Echolocation analog from repo
12. Dread = dark + mind (hex): marks one enemy; it flinches from you and nearby foes panic. [inf] Magicka status logic
13. Clarity = light + mind: a 0.3 s slow window on any enemy telegraph; reveals weak points. [inf] Hades-style synergy, repo "tests recognition"
14. Siphon = blood + dark: touch or bite drains HP and heals you. [inf] design doc undead drain
15. Transfusion = blood + light: convert held essence into HP, or heal a companion. [inf] design doc light redeems, taming companion
16. Bloodfire = fire + blood: below half HP attacks ignite and you gain speed. [inf] HK low-health charm style (Fury analog, unverified)
17. Thrall = mind + blood: charm a weakened creature; ties to goblin taming and a wolf pack bond. [inf] design doc taming and bond methods
18. Mirage = water + mind: leaves a reflection decoy for 3 s. [inf] Magicka-style precedence, none cited
19. Marrow = earth + blood: bone plating that shatters into shards when broken (skeleton graft overlap). [inf] design doc grafts
- Pair budget: 19 above of 28 possible pairs is too many to ship at once; ship 12 to 14 and leave the rest as "no reaction" fizzles with a flavour line. Unused pairs: light + dark, water + fire (if steam is cut), earth + light, air + blood, air + mind, water + blood. [inf] C(8,2)=28, Mystralia 20 to 11
- Ships in order of the creatures: the first-pass 5 elements (water, earth, air, light, dark) give 10 pairs. Three exist today (poison, spore, jolt), one is planned (ice = water + air), and my proposals for this set are mire (water + earth) and grit (earth + air); the other four first-pass pairs (light + dark, light + water, light + earth, earth + dark) stay unused. [inf] C(5,2)=10 + repo element list and recipes
- OR recipes: write each as a short list of AND groups; the OR must not equal another power's AND group (Jolt vs lightning); also needs the unlock engine to grow an OR group (deferred in the spec). [inf] repo

### 6c. Same recipe on five species (verbs from the design doc)
| Recipe | Slime | Spider | Goblin | Undead (skeleton line) | Wolf | Tag and source |
|---|---|---|---|---|---|---|
| Poison (water + dark) | Poison Breath cone, Miasma or Venom Bolt | venom on fangs and web strands, pinned prey ticks down | dipped throwables via item recipes | Rot Touch: skeleton converts rot to drain, zombie plague aura | poisoned pounce bite | [inf] design doc spider poison + goblin items + undead drain |
| Smoke Veil (fire + dark) | exhaled veil, crit from inside | smoke cocoon bomb on a web line | smoke bomb throwable, leads to assassin | grave mist (lich), vampire mist form with blood | dust-and-smoke sprint trail | [inf] design doc "dark = assassin on goblin" |
| Dread (dark + mind) | hex touch | hexed web: cursed prey takes extra when it moves | hex totem item | lich curse, doom mark | howl of dread, area fear | [inf] design doc "dark = lich on skeleton" |
| Siphon (blood + dark) | engulf-and-drain | drains cocooned living prey | leech knife in the weapon slot (it only heals by eating) | native to vampire, skeleton drain | rending bite heals on pounce kills | [inf] design doc essence methods |
| Thrall (mind + blood) | gel thrall: an engulfed enemy fights for you briefly | brood of hatchlings (Weaversong analog in repo reference) | tamed companion, one at a time | raise a kill as a minion | pack bond: borrow a pack mate | [inf] design doc taming + bond methods, repo reference Weaversong |
- Source for the columns: design doc species verbs and essence methods; Genshin "Elemental Skill and Burst per character" for the principle. [inf]
- Light vs dark per species (design doc): dark = lich on skeleton, assassin on goblin, shadow-stalker on spider; light redeems upward (goblin to paladin). Add: light on a wolf reads as a guardian howl; on a slime as a purifying glow. [inf] design doc, two examples invented
- Goblin unification: its fixed two-item recipe table and the essence two-element recipe grammar are the same shape, so one recipe popup can serve both: items for the goblin, essence for everyone else. [inf] design doc + Infinite Craft/Doodle God two-in-one-out

### 6d. Slot constraints, riders, trade-offs
- Four active quick slots stay. Add a passive notch budget: stage 1 = 3, stage 4 = 7; costs 1 to 3 per passive or rider; keystone costs 3. Body parts the slime holds (2 to 5) are passives that occupy notches, so there is one loadout surface, not three. [inf] HK 3 to 11 notches, repo parts 2 to 5
- Overcharm analog "Overfed": one extra notch beyond budget, but a hit knocks out 25% of held essence. Ties the risk to the essence economy rather than damage. [inf] HK overcharm (double damage)
- Respec: riders and passives free at altars and Glow Pools; evolutions, capstones and keystones fixed for the life; reincarnation is the respec (already ruled for evolutions). [inf] Hades Mirror free swap, D4 free respec, repo "exclusive per life"
- Hybrid floor: any two actives from different elements fit at all times; the price of hybrids is held essence, which is the existing "three dark prices sum to 36 vs 29 held" pressure. [inf] repo spec
- A capstone rule set: (1) changes a verb or resource, (2) carries a cost or commitment, (3) not levelled, (4) one owner species. [inf] PoE keystones, Pom of Power exemption, FFXII single-owner licences

### 6e. Capstone and keystone examples
- Poison line capstone: Plague Bloom: the Miasma cloud stays where it ends and spreads to the next living thing it touches (Miasma branch only); Venom Bolt branch gets Hunter's Mark instead: bolts home to poisoned targets. Branch choice picks which capstone exists. [inf] D4 variants, repo branches
- Spore line capstone: Mycelium: spores leave a permanent patch in a room until you leave it (changes the room, not a number). [inf] Cross-run world state in design doc
- Thread line capstone: Anchor Web: place one persistent anchor per room and teleport to it. [inf] repo reference "Thread Recall"
- Keystone Hollow Core (earth): cannot jump over 2 tiles, takes no knockback and breaks floors beneath you. [inf] PoE Resolute Technique style
- Keystone Glutton's Debt (any): you can no longer hold more than 20 essence, but every devour is worth double. [inf] PoE Chaos Inoculation style rule rewrite + death loses essence
- Goblin capstone: Quartermaster: unlimited item combines in the radial wheel but only one weapon slot. [inf] design doc

### 6f. Passive/active ratios and sample builds
| Tree | Nodes | Actives | Passives and body | Riders | Capstones and keystones | Tag and source |
|---|---|---|---|---|---|---|
| Slime | about 38 | about 10 | about 14 | 6 | 3 + 2 | [inf] repo 27-power baseline |
| Spider | about 30 | 8 (web shot, trap web, zip, poison fang, ...) | 10 | 5 | 3 + 1 | [inf] design doc spider verbs |
| Goblin | about 28 | items only (thrown, trap, combine) | gear and lessons | 4 | 3 + 1 | [inf] design doc goblin two layers |
| Undead (per branch of three) | about 26 each | 6 | 9 | 4 | 2 + 1 | [inf] design doc three undead paths |
| Wolf | about 22 | 5 (pounce, howl, ...) | 8 | 3 | 2 + 1 | [inf] design doc wolf, smaller kit |
Counts are authoring targets. [inf] Skyrim about 10 perks per tree (UESP); HK 45 charms; repo 27 power baseline.
- Build A, slime "Venom Skirmisher": Poison Breath to Venom Bolt (water 6 + dark 10), Jolt, Hydraulic Propulsion to Jet Dash; rider on Venom Bolt = Scald (fire); passives: Poison Resistance, Regeneration, Toughness. [inf] repo powers
- Build B, slime "Garden": Spore Cloud to Healing Spores, Sticky Thread to Binding Web, Regeneration, rider on Healing Spores = Transfusion; keystone Glutton's Debt. [inf] repo powers
- Build C, spider "Pinner": web shot, trap web, poison fang, zip; riders Smoke Veil on trap web; passive wall-walk; capstone Anchor Web. [inf] design doc spider
- Build D, goblin "Alchemist": item wheel, throwables with poison dip (Poison), smoke bomb (Smoke Veil), tamed companion; passive lessons trickle; capstone Quartermaster. [inf] design doc goblin
- Build E, skeleton to lich: bone caster; Dread, Thrall, mind and dark essence; keystone with the cost "frail". [inf] design doc undead
- Build F, wolf "Pack Hunter": pounce, howl (Dread), Pack Bond (Thrall); passive scent tracking. [inf] design doc wolf

### 6g. How the evolution price should scale (starting rules, tuned as data)
- Anchor: repo starting values are water 6; water 6 + dark 10; air 6 + dark 12; dark 14. [read] repo (essence-overhaul spec)
- Tier ladder: branch 1x the parent's price; rider 3 to 4 units of a third element; capstone 2x the parent's price, split over two elements and gated on branch level; keystone priced in the downside, not essence. [inf] Hades Mirror batch prices 5, 10, 20, 30 keys, Pom of Power exemption
- Stage multiplier for later bodies: stage 1 x1, stage 2 x1.5, stage 3 x2, stage 4 x3, so evolving the body again does not become free. [inf] Hades Mirror escalation, Skyrim ^1.95
- Hard sink rule: price at least one element the power does not level on, so a scarce element is never the only cost (the dark overdraw: three families draw on dark). [inf] repo calibration notes
- Affordable-now prompt: show "Ready, needs 2 more dark" (already in spec); hoarding is cured by clear value plus loss on death. [inf] pack-ratting article + repo
- Use-based mastery: count effect landings, not button presses (M&B), cap per encounter (Experience point page), and use the Skyrim style rising cost curve for later levels; avoid levelling on a self-targetable trigger (FFII, Skyrim potion loop). [inf] M&B, FFII, UESP

## Sources
Local repo (read-first docs, all [read]): docs/isekai-chronicles-design-doc.md; docs/superpowers/specs/2026-10-03-essence-overhaul-design.md; docs/superpowers/specs/2026-09-29-skill-evolution-branches-design.md; docs/superpowers/specs/2026-10-03-skill-tree-screen-design.md; docs/research/metroidvania-reference.md.

Web pages, all [read]:
- https://en.wikipedia.org/wiki/Path_of_Exile [read]
- https://en.wikipedia.org/wiki/Path_of_Exile_2 [read]
- https://poedb.tw/us/Keystone [read]
- https://en.wikipedia.org/wiki/Magicka [read]
- https://en.wikipedia.org/wiki/Noita_(video_game) [read]
- https://noita.wiki.gg/wiki/Materials [read]
- https://en.wikipedia.org/wiki/Divinity:_Original_Sin_II [read] (thin)
- https://en.wikipedia.org/wiki/Monster_Sanctuary [read] (thin)
- https://store.steampowered.com/app/814370/Monster_Sanctuary/ [read]
- https://en.wikipedia.org/wiki/Hades_(video_game) [read] (thin)
- https://hades.wiki.fextralife.com/Boons [read]
- https://hades.wiki.fextralife.com/Mirror+of+Night [read]
- https://hades.wiki.fextralife.com/Pom+of+Power [read]
- https://hollowknight.wiki.fextralife.com/Charms [read]
- https://en.wikipedia.org/wiki/Final_Fantasy_II [read]
- https://en.wikipedia.org/wiki/Final_Fantasy_X [read]
- https://en.wikipedia.org/wiki/Final_Fantasy_XII [read]
- https://en.uesp.net/wiki/Skyrim:Leveling [read]
- https://en.uesp.net/wiki/Skyrim:Perks [read]
- https://en.uesp.net/wiki/Morrowind:Leveling [read]
- https://en.wikipedia.org/wiki/Experience_point [read]
- https://en.wikipedia.org/wiki/Gothic_(video_game) [read]
- https://en.wikipedia.org/wiki/Mount_%26_Blade [read]
- https://en.wikipedia.org/wiki/Salt_and_Sanctuary [read] (thin)
- https://en.wikipedia.org/wiki/Bloodstained:_Ritual_of_the_Night [read]
- https://bloodstainedritualofthenight.wiki.fextralife.com/Shards [read]
- https://en.wikipedia.org/wiki/Ori_and_the_Blind_Forest [read]
- https://en.wikipedia.org/wiki/Diablo_III [read]
- https://en.wikipedia.org/wiki/Diablo_IV [read] (nothing on the skill tree)
- https://diablo4.wiki.fextralife.com/Skills [read]
- https://en.wikipedia.org/wiki/Slay_the_Spire [read]
- https://en.wikipedia.org/wiki/Doodle_God [read]
- https://en.wikipedia.org/wiki/Infinite_Craft [read]
- https://en.wikipedia.org/wiki/Genshin_Impact [read]
- https://en.wikipedia.org/wiki/The_Legend_of_Zelda:_Breath_of_the_Wild [read]
- https://www.gamedeveloper.com/design/power-progression-in-games-crafting-rewarding-player-experiences [read]
- https://www.gamedeveloper.com/design/5-design-lessons-learned-from-i-the-legend-of-zelda-breath-of-the-wild-i- [read]
- https://www.gamedeveloper.com/design/how-supergiant-added-new-goddess-demeter-to-i-hades-i-pantheon [read]
- https://www.gamedeveloper.com/design/how-indies-add-flavor-to-monster-combat-25-years-after-pokemon [read]
- https://www.gamedeveloper.com/design/secondary-systems-analysis---hollow-knight [read]
- https://www.gamedeveloper.com/game-platforms/road-to-the-igf-nolla-games-i-noita-i- [read]
- https://www.gamedeveloper.com/design/creative-process-of-a-procedural-spell-crafting-system [read]
- https://www.gamedeveloper.com/design/the-short-end-of-skyrim [read]
- https://www.gamedeveloper.com/design/todd-howard-s-2012-dice-keynote-speech-transcribed-contextualized-glorified [read] (one line on the skill-tree UI only)
- https://www.gamedeveloper.com/design/space-station-13-a-case-study-in-emergent-gameplay-and-system-heavy-design [read]
- https://www.gamedeveloper.com/game-platforms/what-is-depth-and-how-do-you-add-it-to-your-game- [read]
- https://www.gamedeveloper.com/design/ten-ways-to-add-depth-and-replayability-to-your-game [read] (not used above)
- https://www.gamedeveloper.com/design/6-game-ui-you-should-study [read]
- https://www.gamedeveloper.com/design/pack-ratting-in-video-games-do-players-have-to-have-it-all- [read]
- https://www.gamedeveloper.com/design/hades-devs-say-accidentally-inventing-a-subgenre-was-surreal- [read] (no boon content)
- https://www.gamedeveloper.com/design/what-everyone-gets-wrong-about-soulslike-design [read] (no build content)
- https://www.gamedeveloper.com/design/video-understanding-the-remarkable-tech-and-design-of-i-noita-i- [read] (landing text only, no design content)
- https://www.gamedeveloper.com/design/stupid-unity-ui-navigation-tricks [read]
- https://en.wikipedia.org/wiki/Hollow_Knight [read] (charms and map: nothing beyond one charm-notch sentence and Stag Stations)

Listing pages used only to discover URLs, all [snippet]: gamedeveloper.com/search?q= for skill tree, Hades boons, elemental interactions, progression system, Noita, Hollow Knight charms, Slay the Spire, Path of Exile passive tree, Magicka, Divinity Original Sin, talent tree, Skyrim, elemental combinations, build diversity, metroidvania, crafting recipes, pixel art UI, gamepad menu navigation.

Failed (do not retry): poewiki.net (Anubis block); magicka.fandom.com, monster-sanctuary.fandom.com, genshin-impact.fandom.com (402); magic.wizards.com colour-pie article, little alchemy Wikipedia, darksouls.wiki.fextralife.com, lastepoch/diablo4 skill-tree pages, divinityoriginalsin2.wiki.fextralife.com (404 x4), pathofexile/genshin/monster-sanctuary/magicka fextralife subdomains (no such host), store.steampowered.com Salt and Sanctuary (age gate), gdcvault BotW URL (wrong talk).

## Not found
[gap] DOS2 surface rules and Larian commentary; Genshin full reaction table; Last Epoch tree numbers; Monster Sanctuary nodes per tree; Salt and Sanctuary node counts and respec; HK and PoE respec policy pages; controller navigation and fog-of-war graph precedents; any 640x360 skill-screen precedent; magic colour-pie article; Hades boon slot structure.
