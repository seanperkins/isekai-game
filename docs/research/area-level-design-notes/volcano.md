> Unedited agent notes. Where they conflict with `../area-level-design.md`, that document wins (for example: ledge spacing uses the repo's 54 px step, glow pools are not respawn points, and a forest-to-Grotto link is not planned).
> Correction (2026-10-04): the Deepnight article's "250 combat tiles, 1 monster per 5 tiles" is the author's invented example ("taking some random numbers"), not Dead Cells data. Ignore any Dead Cells monster-ratio figure in these notes.

# Volcanic / fire area research for Isekai Chronicles

Tags: [read] fetched and read; [snippet] search-result summary only; [inf] my inference; [gap] searched, nothing usable; [not researched] never searched. Source numbers in brackets point to the Sources list at the end. Fetches were summarised by a small model, so quotes are as returned, not verbatim from the page.

## 1. Precedents and what makes them work

Super Metroid Norfair (heat as soft gate)
- Heat is the gate: "Norfair is nigh inexplorable due to extreme heat in most of its rooms eating your health away"; the Varia Suit "not only opens up the hot sections of Norfair" and "signifies a radical and complete change of pace" [read][S1].
- The gate is staged by confinement, not a wall: after the High Jump Boots "the available area is still miniscule", a "prolonged situation of near-captivity"; players "completely exhaust the available rooms, creating a strong feeling of familiarity, however hostile" [read][S1]. [inf] Heat is a legible "not yet" because the player is allowed to taste it, take damage, and retreat to a small known space.
- Varia halves damage and stops super-heated damage; magma pools still hurt until the Gravity Suit [snippet][S2]. [inf] Two-layer immunity (ambient heat vs contact with the liquid) is a precedent for "heat_resist" not covering lava contact.

Metroid Prime Magmoor
- "Most of the rooms in Magmoor Caverns have a flag set which detects if Samus is wearing the Varia Suit", damage at "a constant rate" without it; the suit adds a 10% damage reduction [read][S3]. No per-tick numbers on the page [gap].
- Visor tints orange, condensation, HUD warning when entering extreme heat early [snippet][S2]. [inf] Per-room heat flag plus a loud audio/visual warning is the checkable pattern; the warning, not the damage, is what makes the soft gate fair.

Metroid Dread (Cataris, Ferenia, Magmaa)
- Cataris is built on "thermal fuel pumps" and "thermal trapdoors": activating distributors redirects magma, opening passages "while sealing others behind the player", connected by vertical shafts and spider tracks, with some rooms "too hot to enter now" [read][S4].
- Heat doors glow, rooms are red on the map, tick damage escalates up to a full Energy Tank, superheated rooms get a more intense music track, and heat can be switched off in some rooms by neighbouring switches [snippet][S5].
- Wikipedia's Dread page has nothing on heat or area design; development notes only [read][S6]. No designer interview on heat found; Nintendo's Dread Report vol. 8 failed a certificate check [gap]. Ferenia/Magmaa specifics [gap].
- [inf] Heat that the player can turn off (a switch, a vent, a flooded room) converts a pure gate into a puzzle and gives non-suit species a lane.

Ori and the Blind Forest Mount Horu
- Structure: climb to the top, then descend through layered caverns; "each time you enter a cavern you'll have to make your way to a boulder or some other device to stop the lava flowing"; the escape means "jump over the lava and avoid falling debris" and "may need to try it a few times" [read][S7].
- Wikipedia lists reviewer criticism of "difficulty spikes during the escape sequences" and "needlessly punishing" [read][S8]. Soul Links (checkpoints) are creatable any time but cost energy cells [read][S8]. "No checkpoints inside escapes" and "forest fire as timer" [snippet][S9].
- [inf] The puzzle half (stop the flows, safe to fail) landed; the chase half drew the complaints. Chase beats belong in optional or rare rooms, with a restart point close by, in a game whose death restarts the world.

Celeste Core (hot/cold toggle)
- A switch flips magma blocks, fireballs and conveyor walls to ice blocks, ice balls and ice walls; it also changes "music, ground friction, background, and color grading"; "lava disappears and ice appears elsewhere" rather than converting [read][S10].
- Rising section: "constantly flip switches to change the direction of the vertically moving lava/ice... lava moves up and ice moves down" [read][S10]. Dash refills only via screen transitions, refills, bubbles [read][S10]. Maddy Thorson's GDC talk (rest and recovery, short screens) was not transcribed anywhere I could read [gap]; only "every level... a very small, self-contained story" [read][S11].
- [inf] One mode flag that retints the whole room (palette, audio) is cheap and readable; "hot" can be a room state, not a new tile type.

Hollow Knight / Silksong
- Hollow Knight's cut lava area "Forest of Bones/Boneforest": bottom of Hallownest, entered from Deepnest's bottom-right; early maps put it northeast but it was moved because designers did not want a lava zone at the top; it had instant-kill lava (maybe charm-manageable), a locked gate needing two torches guarded by lava-worm minibosses, a Double Jump reward, 50+ enemies; cut because "Boneforest made the world map too big!" and "we would have died making it. We're a tiny team!" [read][S12] (fan-compiled page quoting the devs). Gibson: "It seemed so cool! But it was totally the right thing to do" [snippet][S13].
- Hollow Knight gates by terrain type: double jump (Monarch Wings), wall climb (Mantis Claw), dash (Mothwing Cloak), acid pools (Isma's Tear); "every surface is solid and predictable" [read][S14]. Isma's Tear (acid immunity) is gated behind Crystal Heart and Dung Defender and is not needed to finish the game [snippet][S15]. [inf] This is the direct precedent for a hazard-immunity gate that also guards optional rooms.
- Silksong: Mount Fay drains health with cold unless the player stands in heat-lamp radius; Deep Docks has lava in the background that hurts on landing; Far Fields has lava pools on lower floors [snippet][S16]. [inf] Drain plus safe radius = this game's glow-pool pattern.

Terraria Underworld
- Bottom of the world, about 1500 tiles down in large worlds, ash-block ceiling, "large lava pools, Ash Blocks, and Hellstone"; water "will quickly evaporate" there, but flooding converts lava surfaces to obsidian before it evaporates [read][S17].
- Lava contact: 80 damage plus "On Fire!" 7 s (14 s Expert, 17.5 s Master); accessories each give 7 s of lava immunity, stackable to 49 s; Obsidian Skin Potion gives full immunity for its duration; water plus lava makes obsidian [read][S18].
- Ecology: Hellbats, Lava Slimes, Fire Imps, Demons, Voodoo Demons, Bone Serpents; Fire Imps are "particularly dangerous in confined spaces" [read][S17].
- Minecraft: "Obsidian is formed when flowing water touches a lava source block" [read][S19]; flowing-on-flowing gives cobblestone [snippet][S20]. [inf] Direction/volume matters: a limited water supply (the slime's essence) is a better quench rule than "water always wins".

Spelunky, Dead Cells, Shovel Knight
- Spelunky: Derek Yu kept an early area punishing because "death and failure is an expected part of gameplay"; destructible terrain from NetHack's pickaxe; four increasingly difficult areas [read][S21]. Spelunky 2 lavafalls/liquids [snippet][S22]. Hell/lava-zone design rationale [gap].
- Dead Cells: concept graph per biome sets length, special-room count, labyrinth density, entrance-to-exit distance, "consistent pacing with dramatic peaks and relaxing breaks"; spawn by ratio (250 combat tiles at 1 per 5 = 50 monsters); overall map fixed across runs [read][S23].
- Shovel Knight Specter of Torment rules: about 26 regular rooms and 6 secret rooms per level, about 5 enemies and 5 objects planned, "No unitaskers", no concept overstays, mechanics prepare for the boss, Lost City rooms descend while Flying Machine rooms ascend [read][S24]. Lost City is fire-themed [snippet][S25].

Not covered: Blasphemous, Cave Story, Axiom Verge, Rayman Legends [not researched]; Mario lava castles and Donkey Kong Country volcano levels: one search each, no design rationale surfaced [gap]; Mario Wiki falling-platform page gave behaviour but no timings [read][S26].

## 2. Hazard design patterns and fairness

Lava lethality
- Instant kill vs DoT: Make a Good Mega Man Level contest wiki: MaGMML2 rising lava deals "1 every 8 frames" while submerged; Episode Zero's is an instant kill; both can be softened by a pickup [read][S27]. Terraria: 80 on contact plus a 7 s burn [read][S18]. Hollow Knight's cut lava was instant kill, charm-manageable [read][S12].
- Loss of control is the real cost: Toto Temple Deluxe's team dropped rising lava because "anything that makes you lose control over your character deliberately is NOT going to be fun" (multiplayer party game, so weigh accordingly) [read][S28].
- [inf] For this game, instant-kill lava is the harshest option because death returns you to the first room of a fixed world. Use DoT plus knock-back to the last safe tile on main lanes; keep instant kill for rare-room puzzles only. Any lava death still seeds fire (the rule is element of the killer), so lava remains the teaching hazard.

Heat as clock and as gate
- Constant-rate ambient damage with a flag per room (Prime) [read][S3]; escalating ticks (Dread) [snippet][S5]; time-limited immunity that stacks, 7 s each to 49 s (Terraria) [read][S18]; cold drain with safe radius (Silksong) [snippet][S16]; permanent immunity item (Varia, Isma's Tear) [read][S1][snippet][S15].
- [inf] Use both kinds: a permanent adaptation gate (`heat_resist`) for deep/rare rooms, and a per-life clock (the death seed) for mild heat rooms. Glow pools and water rects reset the clock.

Rising, draining, switch-controlled lava
- Rising: "slowly begins rising", can "increase in speed after a certain point"; Scorched Factory and Rainbow Ravine brighten/dim the background to show lava proximity; Null and Void adds a screen-shake earthquake [read][S27]. No px/s figures anywhere [gap].
- Controlled flow: Horu (stop flows at devices) [read][S7]; Dread (redirect magma) [read][S4]; Celeste (toggle) [read][S10].
- [inf] Prefer player-controlled level changes (a switch drains or raises a rect) over a timed rise; in a fixed world that is replayed every life, the drained state should persist or reset per life as a deliberate rule.

Timed hazards: eruptions, geysers, falling rocks
- Toto Temple geysers: inactive/active states, placeholders "shake" before activating [read][S28]. [inf] Shake plus sound, then burst.
- Numbers: Dark Souls 3 article: "Attack Signal and Attack together need to have a guaranteed duration of at least 340ms"; human chain ~240 ms (perception ~100, cognition ~70, motor ~70); windows shortened below 340 ms only for select moves [read][S29]. General figures of "over 0.3 seconds" and "up to 3 seconds" for novices [snippet][S30].
- Cycle length, safe window and density for geysers or eruptions: [gap]. [inf] Starting values to tune: telegraph at least 340 ms (21 frames at 60 fps) as the hard floor, aim 500-600 ms visible plus audible; keep the safe window at least as long as the active window; one timed-hazard type per room (Shovel Knight "no unitaskers", no concept overstays [read][S24]).
- [inf] Falling rocks are a crush (seeds nothing) and eruptions or fire bursts seed fire; use rockfall to teach rhythm with no seed side-effect, and make the eruption telegraph visibly different (glow vs dust).

Crumbling and sinking platforms
- "Visibly fracture and slowly descend before abruptly disappearing", yellow warning stripes in Odyssey [read][S26]; "few seconds" respawn [snippet][S31]. Exact delays [gap]. [inf] Crack frames before the drop, at least 0.5 s standing time on first contact, respawn long enough that a retry never softlocks.

Fire/water interaction and hazard-to-platform precedents
- Water on lava makes obsidian (Terraria, Minecraft) [read][S17][S19]; in Terraria water evaporates in the Underworld, so flooding is only partly effective [read][S17]. Spelunky lets players blow ponds open to drain liquids [snippet][S22]. Celeste Core replaces lava with ice per mode [read][S10].
- [inf] Obsidian bridges are the platform-from-hazard lane; steam is the visual for failed or partial quench.

Rest and checkpoint placement
- Save rooms at "crossroads, so that they may service multiple paths"; "if you notice players struggling with a long stretch of rooms, you may want to break up the challenge with a save point in the middle" [read][S32]. Heather Robertson (GDC 2018): give players "intrinsic tasks" and "extrinsic tasks" for low-stakes moments [read][S33]. Generic: checkpoints "spaced appropriately, preventing frustration without diminishing challenge" [read][S34].
- [inf] Rest pool before the first lava room, one at the area's midpoint crossroads, none inside chase or rare rooms.

Hazard density: no source gives a percentage of a room [gap]. Budget approaches exist: Dead Cells ratios (1 monster per 5 combat tiles) [read][S23]; Shovel Knight "about 5 enemies and 5 objects planned" per level [read][S24]. [inf] Define a per-room hazard budget and cap the lava share of walkable floor (suggest 40% on main lanes, 60% elsewhere) as tunable lint thresholds, not research findings.

## 3. Readability and layout

- Dead Cells art rule: three tiers. Pathways: "the background of the levels and the collisions have to contrast as much as possible"; interactive elements sit between; threats "treated with high levels of saturation, contrast and brightness so the immediate danger is quickly identifiable" [read][S35]. [inf] Lava and fire are tier-3 and must be the most saturated and brightest thing in the room; platforms mid; background faded.
- Lava-level problem: "hard to differentiate the background from the hazards" and advice to dim the background or let hazards pop (Pixel Joint thread, fetch blocked) [snippet][S36]. Background brightening/dimming to signal proximity [read][S27]. GDC 2018: Nathan Fouts uses red crystal spikes to show danger; Andrew Yoder: acid pools "hard to notice" in first person [read][S33]; David Shaver: movement, sound, fire and sparks guide attention [read][S33].
- Celeste Core retints music, background, colour grade and friction per mode [read][S10]. [inf] Retinting parallax and a room-level "heat" colour grade is the cheap signal; avoid putting lava-coloured parallax at lava brightness behind platforms. Heat haze as a shader: [gap] no source.
- Hollow Knight keeps all terrain solid and predictable, no pass-through platforms [read][S14]; this game uses one-way ledges, so [inf] give them a distinct cap tile and outline over fire rooms.
- Vertical structure: Horu climbs then descends [read][S7]; Lost City rooms stack downward and Flying Machine upward "to give the feeling of ascending" [read][S24]; Dread Cataris uses shafts [read][S4]; Boneforest at the world's bottom [read][S12]; Underworld at the bottom [read][S17].
- Pacing: Norfair uses early confinement then a "radical change of pace" at the suit [read][S1]; Dead Cells graphs specify peaks and breaks [read][S23]; Dreamnoid: rows of biomes visited in order, plus save rooms mid-stretch [read][S32]; introduce a mechanic safely, then twist it (Chris Totten) [read][S33].
- Staging the first lava sight: transition rooms are advised between lava and water levels, with gradual change instead of "ice world to fire world, with no intervening transition" [read][S37]; foreshadow with silhouettes and recognisable shapes [read][S32]; lighting to highlight areas [snippet][S38]. [inf] Put red glow, ash motes and a heat-warning tablet in the previous area, plus a view of a lava pool through a gap in a floor or wall before any heat damage.
- Enemy ecology: Underworld mixes flyers (Hellbat, Fire Imp), crawlers (Lava Slime), and serpents; dangerous in confined spaces [read][S17]. Dread Cataris: mechanical enemies, flying critters, burrowers [read][S4]. Dead Cells biome room sets shape what enemies fit ("sewers... very tight") [read][S23]. Hollow Knight's cut area had lava-worm minibosses and 50+ enemies [read][S12]. [inf] Fire creatures should be emitters (spit, ember trail, burst on death) and lava-dwellers (rise out of lava, retreat), versus cave creatures that crawl on solid ground; pair with the Deep's drakes (fire drake) for continuity.

## 4. Concrete, checkable rules for THIS game (all [inf])

Repo facts used (read-only): gates are exit dictionaries like `{"gate": "wall_cling"}` (tests/test_room_reachable.gd:42, tests/test_room_lint.gd:134) and the reachability test counts "gated and shortcut links... unless skipped" [read][S39].

R1. Gate label [inf][S1][S3][S15]: add `heat_resist` in the same exit schema, `{"gate": "heat_resist"}`. Rooms carry a `heat` flag (Prime's per-room flag). Validator: (a) every `heat` room is reachable only via an exit with `heat_resist`, or is "mild" (contains a refuge); (b) the grant is reachable without passing a `heat_resist` gate (non-circular); (c) the main route (first room to area altar), computed with the base jump only and gated links skipped, contains no `heat` room and no lava crossing; (d) at most one rare room per area sits behind it.
R2. Mild heat as a clock [inf][S18][S16]: a mild `heat` room drains over time; refuges are glow pools or deep-water rects. Validator: longest heat-exposed path between refuges is at most a budget (parameter in seconds times the slowest species' ground speed, tuned like Terraria's 7 s per immunity [read][S18]).
R3. Death-seed key leak [inf][S21]: the fire seed starts the next life, so it can satisfy any gate keyed on "has fire", and dying to any reachable fire hazard hands it over. Rule: gate `heat_resist` on the permanent eaten/evolved essence, not on the seed, and define the seed as a one-life, timed, mild-heat grace (Terraria-style 7 s immunity precedent [read][S18]). Validator: treat the fire seed as obtainable at the first reachable fire hazard; fail any design where seed alone opens a `heat_resist` exit.
R4. First fire essence without a fire creature [inf][S21][S12]: yes. Options: (a) first lava room is a deliberate teaching death (Spelunky: death "an expected part" [read][S21]) whose seed gives one-life grace; (b) a creature-free pickup, an "ember vent" or brazier behind a pure-platforming trial near the first rest pool, so a validator can prove obtainability with no creature kill. Hollow Knight's Boneforest put the reward behind lava minibosses [read][S12], which this game must not require for the first fire essence.
R5. Death provenance [inf][S17][S18]: lava, fire burst, eruption and fire-creature kills seed fire; rockfall, falls and crushes seed nothing. Decide explicitly what steam seeds (suggest water, matching the drowning-seeds-water rule) and give each lethal hazard a `seed_element` field (empty for crush/fall); a lethal hazard with the field missing fails the lint.
R6. Lava lethality [inf][S18][S27][S12]: main-lane lava is DoT plus knock-back to the last safe tile (cap total lava share of floor as in section 2); instant kill only in the rare room, and never within one screen of the entry exit.
R7. Telegraph floor [inf][S29]: every timed hazard declares `telegraph_ms` at least 340 (21 frames at 60 fps), recommend 500-600; safe window at least the active window; one timed-hazard type per room [S24].
R8. Species lanes [inf]:
- Slime [S17][S19][S18]: water essence quenches a lava rect to obsidian for a limited time (consumes the held essence; a `quench` tag on a lava rect, with a drip or water rect nearby to recharge). Deep water rects act as cooling refuges. Validator: every `quench` lava rect has a reachable water source within the same room or the previous one.
- Spider [S10]: web zip over lava spans on anchor tiles. Because every room has a ceiling frame, the spider can crawl over any span; validator must treat a lava span as spider-crossable unless the ceiling band above it is tagged hot (a `heat` rect on the ceiling, reusing the room-state retint idea in Celeste [read][S10]) or has no crawlable surface. Zip anchors must avoid one-way ledge sides (repo commit subject "a one-way ledge's side is not a zip anchor" [read][git log]).
- Wolf [S29]: gallop or pounce across wide gaps timed to geyser windows; lane is a long flat run with an eruption rhythm at least 340 ms telegraphed; vault over low lava lips.
- Biped goblin [S29]: roll invulnerability to pass through a fire burst curtain during its active frames (verify the roll i-frame window is at least the burst's active window); mantle onto ledges above rising or surging lava; wall-jump shafts.
- Base jump only (63 px rise) for the main lane; each lane is optional and gated by the verb [S21][S14].
R9. Readability lint [inf][S35]: lava and fire sprites use the room's highest saturation and brightness; platforms mid contrast; no parallax layer uses the lava palette at lava brightness within a platform's silhouette; one-way ledges in heat rooms use a distinct cap tile.
R10. Foreshadow lint [inf][S37][S32]: the room that precedes the new area's entry must show at least one heat cue (glow, ash, embers, a tablet) and the entry sequence must include a transition room before full heat (see the attachment options below).

Candidate layouts (all [inf]; sizes in screens of 640x360, W by H; tags: JUMP=base jump only; ZIP spider; POUNCE wolf; ROLL biped; QUENCH slime; HEAT=`heat_resist` gate)

Layout A: "Descent", branch off the bottom of the Deep (Boneforest precedent [read][S12], Lost City descending [read][S24], gradual descent [read][S37]). 7 rooms.
```
 [Deep: bottom room]
        | JUMP (open floor gap, red glow seen below: foreshadow)
 A1 Ashfall 1x1   landing, ash motes, heat tablet, no heat damage (transition)
        | JUMP
 A2 Ember Hall 2x1  mild heat; rest pool at west end; first lava lip, DoT + knock-back
        | JUMP                       \  QUENCH: obsidian bridge -> A6 shortcut
 A3 Chimney 1x2    shaft down, rockfall (crush, seeds nothing) teaches rhythm
        | JUMP
 A4 Forge Row 2x1  eruption vents (>=340 ms telegraph), fire creatures
        |-- east: ZIP over lava span / POUNCE across gap --> A5 Magma Chamber 1x1  altar
        |-- south: HEAT ------------------------------------> A7 Cooled Vault 1x1  rare (instant-kill lava allowed here)
 A6 Ash Cut 1x1  one-way ledge shortcut back up to A2, opens via QUENCH or from above
```
Main route: Deep, A1, A2, A3, A4, A5 (JUMP only). A7 is the rare room (HEAT). ROLL: burst curtain in A4.

Layout B: "Climb then Escape", beside the Flooded Tunnels (steam transition [read][S37]; water/lava obsidian [read][S17][S19]; Horu climb-then-descend [read][S7]). 7 rooms.
```
 [Flooded: east room] (swim gate stays on the Flooded side)
        |
 B0 Steam Gallery 2x1  half water rects, half vents: transition room, steam = visual, no heat damage
        |
 B1 Cinder Landing 1x1   rest pool
        | JUMP
 B2 Stair of Ledges 1x2   climb, one-way ledges, lava below (DoT)
        |
 B3 Caldera Rim 3x1   long run; POUNCE/gallop gaps with geysers; rest pool at crossroads
        |-- up-left: HEAT --> B7 Ember Shrine 1x1 rare
        | JUMP
 B4 Drop Shaft 1x2   descent; lava level set by switch (drain)
        |
 B5 Magma Heart 1x1   altar
        | QUENCH/switch
 B6 Obsidian Cut 1x1   shortcut: one-way ledge back to B1
```
Slime lane: quench the lava in B3 with water carried from B0; ROLL through geysers; ZIP along the ceiling in B3 unless the ceiling is hot.

Layout C: "Hub and spokes" (3x1 hub, Dread Cataris-style redirected flows [read][S4], Wonder Boy hub-and-spoke gating [read][S40]). 6 rooms; attach at the Deep (or as a spoke off Layout A or B).
```
            C2 Smelter 1x2
               |  switch drains C3
 C1 Landing 1x1 -- C0 Magma Hub 3x1 -- C3 Slag Pit 2x1 (lava, drains)
 rest pool      |      altar in hub         |
                |                          C4 Cooling Chamber 1x1 (water rects)
                C5 Heart Vault 1x1   rare, HEAT
```
Gates: JUMP to hub and altar; C2 switch opens C3 (puzzle gate like Dread); ZIP/POUNCE/ROLL/QUENCH each open a different shortcut spoke into C0; C5 rare behind HEAT.

Attachment options for the cave-chain world [inf]:
1. Bottom of the Deep: strongest precedent (Boneforest at the bottom via Deepnest [read][S12]; Underworld at the bottom [read][S17]; Diablo-style gradual descent [read][S37]; Shovel Knight Lost City descends [read][S24]). Foreshadow with lava glow in the lowest Deep rooms; fire drakes as the first creatures. Risk: the Deep is already the hardest area, so ensure the new area's main route is easier than its entry.
2. Beside the Flooded Tunnels: fits water/lava interaction and a steam transition room [read][S37][S17]; natural slime lane. Risk: two hazards fighting for one gate; keep the `swim` gate on the Flooded side only.
3. A branch off the cave-chain's midpoint: weakest, because the transition and foreshadow costs rise [read][S37].

## Sources

[S1] https://www.gamedeveloper.com/design/the-invisible-hand-of-super-metroid [read]
[S2] https://www.metroidwiki.org/wiki/Varia_Suit and Metroid Wiki / Fandom Varia Suit, Extreme heat (search summaries; fandom 402, metroidwiki 403) [snippet]
[S3] https://wiki.metroidprime.run/wiki/Varia_Suit [read]
[S4] https://omegametroid.com/metroid-dread-walkthrough/the-furnace-of-cataris/ [read]
[S5] https://metroid.fandom.com/wiki/Extreme_heat (fetch 402; search summary of Dread heat) [snippet]
[S6] https://en.wikipedia.org/wiki/Metroid_Dread [read]
[S7] https://gamerwalkthroughs.com/ori-and-the-blind-forest/mount-horu/ [read]
[S8] https://en.wikipedia.org/wiki/Ori_and_the_Blind_Forest [read]
[S9] https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/OriAndTheBlindForest (search summary: no checkpoints in escapes) [snippet]
[S10] https://celeste.ink/wiki/Core [read]
[S11] https://www.tadeasjun.com/blog/2d-level-design/ [read]
[S12] http://mossbag69.blogspot.com/2018/02/hollow-knight-cut-content.html [read]
[S13] Search summary of a Game Informer interview with Ari Gibson on Boneforest, surfaced via https://en.wikipedia.org/wiki/Ari_Gibson results [snippet]
[S14] https://ludonauta.itch.io/platformer-essentials/devlog/1084669/the-hidden-genius-behind-hollow-knights-terrain-design [read]
[S15] https://hollowknight.wiki/w/Isma's_Tear and https://hollowknight.wiki.fextralife.com/Isma's_Tear (search summaries) [snippet]
[S16] https://hollowknight.wiki/w/Areas_(Silksong) and https://hollowknight.wiki/w/Mount_Fay (fetch 403; search summaries of Mount Fay, Deep Docks, Far Fields) [snippet]
[S17] https://terraria.wiki.gg/wiki/The_Underworld [read]
[S18] https://terraria.wiki.gg/wiki/Lava [read]
[S19] https://minecraft.wiki/w/Obsidian [read]
[S20] https://minecraft-archive.fandom.com/wiki/Water (search summary: flowing/flowing = cobblestone) [snippet]
[S21] https://en.wikipedia.org/wiki/Spelunky [read]
[S22] https://en.wikipedia.org/wiki/Spelunky_2 (search summary: liquids, lavafalls) [snippet]
[S23] https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/ [read]
[S24] https://www.yachtclubgames.com/blog/specter-of-torment-level-design-deep-dive-1-5/ [read]
[S25] https://gamerwalkthroughs.com/shovel-knight/lost-city/ (search summary: fire-themed) [snippet]
[S26] https://www.mariowiki.com/Falling_Platform [read]
[S27] https://magmmlcontest.com/wiki/index.php/Rising_Lava [read]
[S28] https://www.gamedeveloper.com/design/the-secret-to-designing-the-perfect-level- [read] (Toto Temple Deluxe)
[S29] https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3 [read]
[S30] https://bugnet.io/blog/how-to-design-enemy-attack-telegraphs (search summary) [snippet]
[S31] https://tvtropes.org/pmwiki/pmwiki.php/Main/TemporaryPlatform (search summary) [snippet]
[S32] https://dreamnoid.com/articles/how-to-create-your-own-metroidvania [read]
[S33] https://www.gamedeveloper.com/design/gdc-2018-level-design-workshop-an-expert-roundtable-q-a [read]
[S34] https://retrostylegames.com/blog/platformer-level-design-tips/ [read]
[S35] https://www.gamedeveloper.com/production/art-design-deep-dive-giving-back-colors-to-cryptic-worlds-in-i-dead-cells-i- [read]
[S36] http://pixeljoint.com/forum/forum_posts.asp?TID=12426 (fetch 403; search summary) [snippet]
[S37] https://www.gamedeveloper.com/design/atmosphere-in-games---part-8---world-design-and-level-progression [read]
[S38] https://www.pcgamer.com/how-to-design-a-great-metroidvania-map/ (fetch returned no article body; search summary on lighting) [snippet]
[S39] tests/test_room_reachable.gd and tests/test_room_lint.gd (local, grep only) [read]
[S40] https://www.gamedeveloper.com/design/book-excerpt-world-design-for-2d-action-adventures [read]
Also searched, nothing usable: Nintendo Dread Report vol. 8 (https://metroid.nintendo.com/news/metroid-dread-report-vol-8/, certificate error), https://www.metroidwiki.org/wiki/Extreme_heat (403), https://www.anatomyofgames.com/2014/01/13/anatomy-of-super-metroid-6-kraid-on-bungling-bay/ (403), https://tvtropes.org/pmwiki/pmwiki.php/Main/LethalLavaLand (403) [gap]
