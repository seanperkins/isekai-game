<!-- Source of truth for the Isekai Chronicles design. The claude.ai Claude Docs copy is no longer kept in sync. Last updated 2026-10-03. -->

# Isekai Chronicles — Design Doc

Oct 1, 2026 · @Sean Perkins

## Concept

Isekai Chronicles is a side-scrolling platformer built in Godot where you die, reincarnate as monsters, and evolve each new body through what it eats and learns.

- **Inspirations:** So I'm a Spider, So What? and That Time I Got Reincarnated as a Slime, plus the wider isekai tradition of absurd reincarnation premises.
- **Structure inspirations:** Metroidvanias (Hollow Knight) for the fixed hand-built world, Dead Cells for permanent unlocks between lives that open new routes.
- **Current state:** a slime is the first playable form, already built around consuming things to gain powers.

## Opening sequence

The first time you play, the game opens with an unavoidable truck death, then a goddess who reincarnates you as a slime. The truck scene never plays again: it is a joke for anyone who knows isekai, not a real introduction.

1. The player is dropped into the world and a truck comes at them.
2. Working idea: play it like a JRPG, a turn-based fight where you try to dodge the trucks. If they dodge it, another truck comes. And another. Death is inevitable.
3. After dying, the player meets a god or goddess who apologizes: the death was an accident.
4. She offers to reincarnate them and presents the options. At first there is only one: slime.

The goddess is a recurring character. She remembers every previous life, reacts to how you died, and her reincarnation menu grows over the course of the game.

She seems a helpful ally, and stays that way until the reveal: she is using you to harvest souls from this world, and eventually becomes the antagonist.

The voice that announces skills and evolutions might be the voice of the world.

## Creature design

Every monster in the game is a potential reincarnation, defined by two axes: how it moves and how it gains essence.

**Core principle: every enemy is a potential you.** What you fight is what you could become — enemies double as a catalog of your build options, and beating or eating one is how you earn the right to be it. Keeps content lean (each creature serves as both foe and playable form), at the cost of designing each creature to work both as AI opponent and as a player-controlled kit.

**Movement archetype** — shared controllers instead of per-species code, so reincarnating into anything stays affordable:

Starting with three archetypes that give a wide spread of feel:

- Bouncer (slime) — the current first form. It should feel like a slime from a fantasy game: squash and stretch, gooey physics and springiness, split by place. Tight on the ground, so walking and platforming stay precise; gooey in the air and on walls; springy landings.
- Crawler (spider) — sticks to walls and ceilings
- Biped (monster-people) — grounded but flexible; the bucket for goblins, skeletons and other undead, maybe elf-like fey

The player is always a monster, never a human — more on-theme and it sidesteps the "am I the bad guy" problem. Biped species share the walk-run-jump controller but differ in essence method and skills (a goblin learns, a skeleton drains).

Later addition: quadruped (e.g. wolf — fast ground movement, pounce). Burrower and flier are off the table for now.

### Spider (crawler)

The next playable species, once the slime is in a good place: the essence overhaul, the skill tree screen, and slime movement that feels like a slime from a fantasy game.

A hit-and-run poisoner that controls space rather than rushing in. It walks on walls and ceilings, turning vertical shafts and overhangs into playgrounds.

- **Web-shooting** is the core verb, with two uses:
  - Shoot a web to catch or slow an enemy at range
  - Lay webs on the ground as traps that snare whatever walks in
- **Essence method:** devour, but only living things. It eats what it traps while it is alive, so it is limited in what it can get essence from. It can carry items in cocoons.
- **Immobilize:** web catches and pins enemies in place.
- **Movement:** use the web to zip quickly to a wall or dodge along the line.
- **Poison:** its damage flavor — immobilize, stay out of reach, and let poison tick them down. Ties into the evolution system (own a poison power, made from water and dark → toxic forms).

### Goblin (biped)

The improviser: weak alone, dangerous in how it scavenges and builds. Frantic and opportunistic — a sharp contrast to the spider's patient trapping.

- **Scavenge and craft:** picks up junk, drops and gear, and turns them into makeshift weapons or thrown items. Its skill tree is about what it can build and how fast.
- **Power from inventory:** its strength comes from what it carries, not its own body — a different progression texture.
- **Two layers:** weak in melee, dangerous with what it carries. The active layer is improvised throwables and traps: pick up junk and combine items into one-shot consumables mid-fight. The passive layer is one weapon slot and one armor slot, filled from loot. It is the richest option and the biggest build; the open problem is the controller, which has no free button for a hotbar, a combine action and a gear swap (see the review page, section 6).
- **Essence method:** it does not devour for essence. A goblin eats living things only to heal. It learns the nature of things instead, through combat, taming and interactions, and that learning is how it grows. How learning turns into essence is open.
- **Taming:** a goblin tamer evolution is wanted. Taming is one of the ways a goblin learns, and it is a new system: how it works and what a tamed creature does are open.
- **Items in every form:** all goblin evolutions can use items. Early on it throws what it finds, rocks first.

### Undead / skeleton (biped)

Undead is a branching evolution tree, not one creature. You start as a bare skeleton, and the essence you eat decides which way you develop. Three directions off the skeleton:

- **Flesh path** — skeleton → zombie → ghoul: tankier and more physical, possibly life-drain. Fed by flesh essence.
- **Bone-ranged path** — skeletal archer: precise, keeps its distance.
- **Bone-magic path** — lich-like caster: frail but powerful, bone magic and summoning. Fed by death/magic essence.

The skeleton forks before you ever reach flesh, so undead has a real branching tree from the very first form.

**Essence and items depend on the type.** Undead drain life force from living creatures. The exceptions are the zombie and the vampire, which devour instead (flesh for the zombie, blood for the vampire). Skeleton types can graft: parts from kills attach to the body and show on the sprite, such as ribs and flesh toward zombie and ghoul, a bow-arm toward archer, a skull and focus toward lich. Vampires can use items. The vampire is a new undead form tied to blood essence, and where it sits on the tree is open. What a graft gives (a power, stats, a nudge toward a path) and how many parts a skeleton can wear are also open.

**Essence-acquisition method** — varies by race group, so each form feels distinct while sharing one underlying system:

| Species | Archetype | Essence method |
| --- | --- | --- |
| Slime | Bouncer | Devour everything: creatures, stone creatures, flesh, items. Some items are too strong to digest, or take time to digest |
| Spider | Crawler | Devour living things only; carries items in cocoons |
| Goblin | Biped | Eats living things only to heal; learns the nature of things through combat, taming and interactions; every form can use items |
| Skeleton / undead | Biped | Drain life force from living creatures; zombie and vampire devour flesh and blood instead; skeleton types graft; vampires use items |

Other possible methods: commune or bond for pack beasts (the goblin's taming may cover it).

### Items

Besides essence, the world holds items you can collect: plain materials (stones, moss, sticks) and monster parts (a scorpion's tail, dragon scales). The game gets one shared set of items, and each species handles them in its own way, so the same pickup means something different to each body. Working examples:

- **Slime** devours items as well: everything gives it essence. A part it holds sits visibly inside the jelly and grants a passive tied to the part (a scorpion tail gives a sting, dragon scales give armor). Some items are too strong to digest, or take time to digest. Working reading, to confirm: a held part is a slot that grants its passive while it digests and then turns into essence, and a part too strong to digest stays as a lasting passive. A held part stays in the body until you die, and then goes into your remains. A body holds only a few parts, in visible slots that grow with evolution: about two at stage 1, rising to about five at stage 4 (working numbers). Parts compete for slots, and a higher form carries more.
- **Spider** carries items in cocoons: it webs what it wants to keep and carries a couple at a time. Its own essence comes only from living things. Cocoons count as carried items, so they stay in your remains if you die. Whether a cocoon can also hold a living or dead creature for later is open.
- **Goblin** carries and crafts: every goblin form can use items, and it throws what it finds (rocks first), builds throwables and wears gear. It eats living things only to heal; its strength comes from its inventory.
- **Undead** depends on the type: skeleton types graft parts onto their bodies (a scorpion tail on a skeleton), and vampires use items. Zombies and vampires devour flesh and blood; the rest drain life force.

**Parts come from corpses.** A kill leaves a corpse you can harvest a part from. Rare creatures and bosses leave a rare part on top. Plain materials (stones, moss, sticks) are simply lying in the world. Decided: the old "eat it or harvest it, not both" rule is species-specific. The slime devours corpses and items too, so for it a corpse is essence now or a part for a slot. The spider and the draining undead take essence from a creature while it is alive, so their choice comes at the kill: consume it alive for essence, or kill it and harvest a part. The goblin eats only to heal and learns by fighting, so a corpse is simply parts. Today a creature is eaten alive after a stun and leaves no corpse, which already matches the living-only eaters, so the new work is the corpse and the harvest. Eat-or-harvest also adds a second action at every kill on a controller with no free button, so it likely borrows a button while a corpse is in reach, as "Y: attune" does at rebirth pools.

**On death, items stay where you fell.** Your next life can go back for them as whatever species it is, using that species' own verb. The longer it takes to return, the more of them go missing, so a quick retrieval keeps everything and a long absence costs you. The clock runs only while you are playing your next life, not while paused or in menus. Soft items (moss, flesh, sticks) go first; hard ones (stones, scales, bone) go last. Only one remains pile exists: if you die again before returning, the old pile is replaced. Essence is different: it is lost, and only the seed carries over.

This is a new system: the game has no drops, pickups or inventory today. It is designed now and built after the spider and the essence overhaul: the first spider ships with plain devour, and the corpse system, harvesting, wrap and the other item verbs arrive together as one items milestone, built once for every species. Still open: the item list, how corpses and the stun-and-eat flow fit together, how fast the clock runs and exactly which items count as soft, and what each species' verb gives in practice.

## Essence, levels, skills and evolution

Level is the gate for evolution; the essence you have consumed decides which evolutions are on the menu.

**Essence is elemental** — each essence is one element. Working set of eight base elements:

- Fire
- Water
- Earth (covers stone, defense and raw force: the pure bruisers)
- Air
- Dark (shadow, curses, death — feeds undead, plus assassin/stealth paths)
- Light (counter to dark; feeds holy/support paths — e.g. a goblin toward paladin)
- Mind / psychic (casters and control)
- Blood (life-drain across species)

Poison and Physical are not on the list. Decided: poison is made from water and dark, and earth takes the place of physical. Spore is air and dark; whether earth joins it is still open.

An essence reads differently per species: dark makes a lich on a skeleton, an assassin on a goblin, a shadow-stalker on a spider; light can redeem a monster upward (goblin → paladin). Lightning, ice, poison and spore are not base essences: they come from combining the others (working recipes in Powers below). The first pass uses the five elements that existing creatures can carry: water, earth, air, light and dark. Dark is in the first pass because poison and spore are made from it, so the existing poison and spore creatures carry it. Fire, mind and blood come later, with new creatures.

**Thread is not an essence.** The spider's webs are a power family, not an element: a slime unlocks Sticky Thread, Binding Web and Swing Thread through the "eat a particular creature" route (eat a spider N times), and the playable spider has webs innately. Owning a thread power still offers the Weaver lineage. The game's other trait essences (shell, spore, sound, flight, armor, shock) get the same treatment: re-expressed as one of the base elements (or a mix of them), with the trait name surviving as a skill or form name.

- **Essence:** each monster holds amounts of different essences. Essences are used to create powers.
- **Levels:** character levels raise stats.
- **Stats:** feed into powers and skills, modifying how strong they are.
- **Skills:** level up through use.
- **Evolution:** reaching a level threshold triggers an evolution choice. The options depend on your essence mix.

| Essence eaten | Evolution option |
| --- | --- |
| Stone / defense | Spiked slime |
| Water + dark (a poison power) | Toxic slime |

**Unlock conditions:** each evolution sets its own rule on your essence mix — a threshold, a ratio, or whatever fits that form. At an evolution level, the player sees every evolution their current essence makes possible and picks one. Working idea: for evolutions within your species, the gate is the powers you have unlocked, since powers correspond to essence. A lineage is offered when you own one of its powers. The upgraded (evolved) form of the power then picks the form after it: the branch you took decides which child form is offered.

### Powers

A power is an ability or a passive.

Powers can unlock in more than one way:

- **Essence combinations:** the right mix of essences unlocks a power. Working recipes: lightning is fire and air, or light and air; ice is water and air; poison is water and dark; spore is air and dark, and maybe earth. Most powers need a single essence. A mix is for special powers: a few base powers, more powerful skills, and the occasional interesting branch of a power.
- **Other requirements:** eat a particular creature (a spider, say), dodge a number of times, drop to 1 HP a number of times, and similar.

Powers level up in the background from use. Essence is how powers evolve, and evolving spends it. Each evolution is authored with its own price in the element or elements that power runs on (Poison Breath evolves for a set amount of held poison; a mix power costs both elements). The price shows on the HUD prompt, which reads ready once you hold enough. The actual numbers are open and are tuned as data.

Evolving should be as frictionless as possible. Working idea: when you hit a threshold, the game tells you, and you press a button to evolve a power.

Working idea: the skill screen shows the skill tree and its branches, based on what you have unlocked with this species before. The tree grows as you find it: only discovered nodes show, plus ??? stubs for the branches of powers you own, and a recipe's exact ingredients appear only once earned.

**Tree screen: one combined, zoomable graph.** Powers and evolutions appear as connected nodes in a single tree that can zoom in and out. If evolutions are hard to show alongside powers, fall back to showing one evolution at a time, plus where the next evolution is once the player has unlocked it. Pan and zoom controls, and how a power two species share shows in each tree, are open.

## Reincarnation and soul progression

What you can reincarnate as reflects what your soul is capable of becoming, and that grows across runs.

- **Species unlocks:** each species has its own unlock condition before it appears on the goddess's menu. The default rule is to eat or defeat N of that creature, so the bestiary doubles as the species checklist; a special species can swap in its own condition (the rare Taratect, say). N and the list of special cases are still open.
- **Soul points:** earned on runs and kept between lives.
- **Spending soul points:** both on unlocking new species and on permanent perks.
- **A stronger soul:** can unlock things earlier within a species, such as starting further along its evolution.
- **Where and how far:** the head start has two parts and one currency. The rebirth pool you choose decides *where* you start (and its kit); soul points buy *how far along* at that pool, such as a higher kit level or an extra kit skill. Whether a soul can start a life past stage 1 of the evolution tree is still open.
- **Shrines:** working direction is that a rebirth pool is also the shrine: attune it and bank essence into soul points at the same object. Glow Pools stay plain rest.

## World structure and gates

One fixed, hand-built world, the same every life, with gates between sections that only certain forms or skills can pass. Death is a new life in the same world, not a new world; no procedural generation.

- **Species as runes:** like Dead Cells' runes, unlocking a new form opens routes that were closed before.
- **Gate types:** form-locked (only certain creature types can pass) or skill-locked (needs a skill that comes later).
- **Everything is solvable eventually:** no gate is a permanent dead end for any form.
- **Cross-run world state:** one form can change the world for a later one — the bird triggers something that opens the way for the wolf.

## Ending a run

Working idea: a run ends when you die, or when you beat the god of reincarnation.

**The god of reincarnation is the goddess**, the same character as the helpful ally, once the reveal turns her into the antagonist. Every soul point you bank at a shrine feeds her, so banking is the story's central choice: spend essence on powers now, or bank it for permanent progress. The Cave Serpent, which the game had planned as its goal, becomes an area boss on the way to her.

Shrines don't end a run; they let you bank essence into soul points. Whether a run can end any other way, and what else shrines do, is still open.

**Essence seed (working direction):** when you die, you lose the essence you hold, but what killed you leaves a small essence seed of its element, and your next life starts with it — dying to fire starts you with a little fire essence. Any elemental death counts: a creature kill seeds that creature's strongest element, and a hazard seeds its own (poison water, drowning); a fall or a crush seeds nothing. The seed is a small fixed amount, independent of how much you held, so banking at a shrine and spending on evolutions stay the only ways to keep essence. The exact amount and whether the seed carries across species are still open.

## Reference games

The combination here is novel, but several games cover pieces of it — worth studying.

| Game | What it shares | Note |
| --- | --- | --- |
| [Biomorph](https://godisageek.com/2024/01/biomorph-could-be-the-next-must-play-metroidvania-hands-on-preview/) | Metroidvania where you become enemies you kill; power up a form by killing more of that type | Closest to the species-as-unlock idea, minus reincarnation framing and essence diet |
| [Everything Is Crab](https://rogueliker.com/everything-is-crab-review/) | Spore-style animal evolution roguelite; eating levels you into new adaptations | Closest on the roguelite evolution loop |
| [Re:Monster](https://re-monster.fandom.com/wiki/Re:Monster_~The_Goblin_Reincarnation_Chronicles~) | The goblin-reincarnation premise this echoes; evolve/rank-up by eating | The game is a strategy title, not a platformer |
| [Carrion](https://store.steampowered.com/app/953490/CARRION/) | Reverse-horror; inhuman wall/ceiling movement as an amorphous creature | Reference for non-human movement feel |

## Open questions

- [x] Starting movement archetypes — bouncer, crawler, biped
- [x] Base essences — eight elements (poison is water and dark; earth replaces physical)
- [ ] Spore's recipe: air and dark, and whether earth joins
- [x] World structure — one fixed hand-built map, death is a new life in it
- [ ] Which essences feed which evolution branches for each species
- [x] Essence method for undead — drain life force; zombie and vampire devour; skeleton types graft; vampires use items
- [x] Goblin essence — no devouring for essence; it learns through combat, taming and interactions
- [ ] Essence method for any future species
- [ ] How a goblin's learning becomes essence, and how taming works (what a tamed creature does)
- [ ] Where the vampire sits on the undead tree
- [ ] Which parts the undead can graft, how many it can wear, and which path each part pushes toward
- [ ] Kits for the remaining bipeds (elf-like fey) and the later quadruped
- [x] Items — collectable materials and monster parts, one shared set handled differently per species
- [ ] Whether a spider's cocoon can hold a creature, and whether a slime's held part digests into essence
- [ ] How the goblin's crafting works in practice (which items combine, what the gear slots hold) and how its hotbar, combine and gear swap fit a controller with no free button
- [ ] The item list, how corpses fit the stun-and-eat flow, how fast remains lose items, and which items count as soft or hard
- [x] What the slime's absorb gives — a passive tied to the part
- [x] What the spider's cocoon does — carries items, a couple at a time
- [ ] What the undead's graft gives in practice, and how many slots the spider, goblin and undead bodies get
- [ ] Each species' unlock condition
- [ ] Which permanent perks soul points buy
- [ ] What shrines do besides banking essence (save, talk to the goddess?)
- [ ] How a run can end besides death or beating the god of reincarnation, if at all
- [ ] Which combinations of essences unlock which powers (lightning and ice are the first two)
- [x] How an evolution's cost is set — per power, in its own element(s)
- [ ] The actual essence amounts each evolution costs
- [x] Skill tree layout — one combined zoomable graph, with a one-evolution-at-a-time fallback
- [ ] Pan and zoom controls for the tree, and how a skill two species share shows in each tree
- [ ] When the goddess's reveal happens, and what changes after it
