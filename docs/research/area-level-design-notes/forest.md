> Unedited agent notes. Where they conflict with `../area-level-design.md`, that document wins (for example: ledge spacing uses the repo's 54 px step, glow pools are not respawn points, and a forest-to-Grotto link is not planned).
> Correction (2026-10-04): the Deepnight article's "250 combat tiles, 1 monster per 5 tiles" is the author's invented example ("taking some random numbers"), not Dead Cells data. Ignore any Dead Cells monster-ratio figure in these notes.

# Surface forest area: level-design research (Isekai Chronicles)

Tags: [read] fetched and read; [snippet] search-result summary only; [inf] my inference (source it derives from named); [gap] searched, nothing found.
Quotes are exact as fetched. Where sources disagree I say so. 27 pages were read with usable content (see Sources); several others loaded empty or 403 and are listed as [gap].

## 1. Precedents and what makes them work

### 1.1 Hollow Knight: Crossroads to Greenpath
- Crossroads has "a somber blue color palate, inhabited by slow-moving flies and beetles"; Greenpath has "a dark green color palate, where the enemies hide in foliage to surprise attack you." Area identity is carried by palette plus ambush enemy behaviour. [read] hookshotchargebeamrevive blog.
- Same page: what distinguishes the game is "how interconnected these areas are, and how the game manipulates your expectations as you explore"; the Deepnest entry uses corpses and spears to say what lives beyond, with no exposition. [read] hookshotchargebeamrevive blog.
- Greenpath connects southwest of Crossroads, behind a locked gate that opens after Elder Baldur. [snippet] gamerwalkthroughs / rogueranker search summary.
- Greenpath was called "Fungus 1" in development. [snippet] PC Gamer search summary; the article body never loaded (twice), so no design rationale from it. [gap]
- Greenpath is not daylight: it is a dark green underground-style valley. Hollow Knight is a precedent for palette hand-off between neighbouring areas, not for a sky reveal. [inf] from hookshot blog palette description.
- Hazards named for Greenpath: thorn traps, hanging spores, vine-suspended platforms that can be slashed down, acid pools. [snippet] exitlag / Thorns of Agony search summaries.
- Terrain rule: Hollow Knight "deliberately excludes pass-through platforms ... every surface is solid and predictable"; high ledges, shafts, wide gaps, acid and spikes each map to one ability gate. [read] ludonauta devlog.
- Design philosophy from Team Cherry: exploration and discovery from childhood games; the map system's balance of hiding secrets vs player-friendliness was "the largest design challenge"; hand-drawn sketches scanned into Unity. [read] Wikipedia Hollow Knight.
- Team Cherry rationale specifically for Greenpath's layout: [gap].

### 1.2 Super Metroid Crateria (and Zero Mission)
- Super Metroid opens on the surface: Samus lands "during an acid thunderstorm"; palette "blue, backgrounds are appropriately dark"; "Crateria directly connects to every area except Norfair." [read] goombastomp SM retrospective.
- The player descends a "strictly linear tunnel, surrounded by doors you cannot open yet"; a stone wall on the right blocks and forces you left: "It's clear that it's breakable, but you don't have the hardware yet." [read] GD Invisible Hand.
- Retraversal builds familiarity: "travelling this same route in both directions lets the player quickly set up a mental safe zone"; "a part of the world to call home - something that takes most Metroidvanias hours to achieve." [read] GD Invisible Hand.
- The surface is the hub you return to: "Before you know it, you are back in Crateria, right where you landed at the beginning." [read] GD Invisible Hand.
- Landing Site: flat ground "between two high cliff walls", ship doubles as save and recharge; hub to the Gauntlet, Brinstar and the flooded cavern. [snippet] metroid.fandom Landing Site.
- Zero Mission Crateria: "not as elaborate or expansive", but "Brinstar, Norfair, and Chozodia all have paths connected to Crateria, giving level design an almost essential hub that makes backtracking feel natural." [read] goombastomp ZM.
- Zero Mission surface mood: "Clear skies, glowing mushrooms, and nothing to fight assert safety on Zebes' surface." [read] goombastomp ZM.
- Super Metroid: Nintendo broke the large map "into smaller sections to manage graphic data complexity". [read] Wikipedia Super Metroid.

### 1.3 Ori and the Blind Forest / Will of the Wisps
- Process: "a strong concept on paper", then blockout of "polygons that define the platforms and shapes Ori will run and jump on", playtest, "design approved", and only then artists do set dressing. [read] GD Ori WotW Q&A (Mahler).
- Art team on readability: "a balance between making a composition with leading lines that will nudge you to focus on something and get the right contrast"; "being able to read quickly and efficiently." Biomes were separated by "different color palette and feel." [read] TheGamer Ori art interview.
- Mahler: backgrounds use one-off assets, "the one and only place you'll ever see those assets". High authoring cost; not a cheap pattern. [read] Wikipedia Ori.
- Ginso Tree: "a long, vertical ascent, with the goal of restoring the decaying tree's natural state", ending in an escape as "water quickly rose from below." [read] Xbox Wire gamescom 2014.
- Moon Studios: Ori kept small on screen to emphasise world scale. [snippet] search summary (80.lv / airborn-studios results, exact page unattributed).
- Silent Woods / Inkwater Marsh rationale: only that one designer overhauled the Silent Woods, Windtorn Ruins and Wellspring "in the final months of production to address playtest concerns". [read] chrismcentee portfolio. What was wrong or changed: [gap]. Storm audio scaled to exposed/sheltered areas in Inkwater Marsh. [snippet] interview search summary.
- Sunken Glades / Blackroot design rationale: [gap].

### 1.4 Cave Story
- Opening is "two paths, one of which is blocked off until retrieving an item from the other path"; levels are single-concept ("warmth" for Egg Corridor, "arid and oppressive" for Sand Zone). [read] Wikipedia Cave Story.
- Village is a "danger-free zone" for practising running and jumping. [read] soldierfromthesurface.
- Bidirectional difficulty: "what was once easy going left to right suddenly becomes difficult to manage when coming back from the other side." [read] soldierfromthesurface.
- Grassland pairs uneven terrain with "dive-bombing bats above you"; levels with "fewer enemies and conveniently located save points" train new mechanics. [read] soldierfromthesurface.
- Outer Wall and Balcony are the only stages on top of the island rather than underground, and sit near the end. [snippet] cavestory.fandom Balcony. Surface as late reward: precedent. [inf]
- Hero has "a high contrast between his white skin and red pants" to stand out against dark backgrounds. [read] Wikipedia Cave Story.

### 1.5 Celeste, Dead Cells, Blasphemous, Axiom Verge, Terraria, Silksong
- Celeste screen is 320x180 with 8x8 tiles; tileset palettes use "only 3-5 colors". [read] aran.ink tileset breakdown (a fan article by Aran P., not Celeste team art direction).
- Celeste teaches springs and spikes in chapter 1, adds a moving platform, then combines them. [read] ljvmiranda921 Celeste part 2. GDC "level design of Celeste" write-up has no usable body. [gap]
- Dead Cells Promenade (outdoor): analogous palettes for outdoor levels "allow for more nuances and depth in the landscape"; indoor uses complementary. [read] GD Dead Cells art deep dive.
- Dead Cells transitions: "a mandatory elevator before you access the ramparts, as well as a long tunnel before the sewers" to signal direction. [read] GD Dead Cells art deep dive.
- Dead Cells palette swap: textures are grayscale plus gradient maps; "Modifying the gradient map is then all we need to do in order to change the color palette of a biome." [read] GD Dead Cells art deep dive.
- Blasphemous: world split into districts, zones, scenes; checkpoints "roughly one per area and never more than seven screens apart"; reusable shortcuts; "I want players to beat the boss and go straight to wherever they want to be." [read] GD Blasphemous.
- Axiom Verge: critical path made obvious in early areas; things that block the path backwards. [snippet] search summary only; the two Happ interviews I opened (nintendolife, ibtimes) do not contain it. Axiom Verge 2 was made brighter and more outdoor. [snippet]
- Terraria forest: "occasional hills that can reveal cave entrances"; Mountain Cave is "a zigzag cave leading to underground"; Living Trees "always have an underground room"; day spawns are slimes, night spawns zombies and demon eyes. [read] terraria.wiki.gg Forest. Layer order Space / Surface / Underground / Cavern / Underworld; no tile heights on the page. [read] terraria.wiki.gg Layers; heights [gap].
- Silksong Moss Grotto: walkthrough facts only (floating platforms, bounceable mushrooms, vines); design rationale [gap]. [snippet] fextralife.

### 1.6 Staging the reveal of daylight after a long underground stretch
- Super Metroid delays recognition: "The game clearly tries to delay the moment of recognition until as late as possible - even the music in the cave where you surface (which is part of Crateria) is specially scripted not to change from the Brinstar music until you reach the outdoor environment." Music holds underground until the player is actually outside. [read] GD Invisible Hand.
- Dead Cells names the feeling: "bursting out of a darkened room into blinding sunlight"; outdoor levels use parallax textures, particles and atmospheric density; a mandatory tunnel or elevator sets the transition. [read] GD Dead Cells art deep dive.
- Zero Mission calibrates the first surface screens as safe: clear sky, nothing to fight. [read] goombastomp ZM.
- Hollow Knight's own account of leaving the tunnels into Greenpath exists only as a review sentence ("emerges from the tunnels"). [snippet] search summary, no URL.
- Documented camera, scale and music recipes for a surface reveal: [gap]. No designer talk found. The pieces above are the only sourced ingredients: hold music, delay recognition, safe first room, palette/gradient change, a tunnel before the exit.

## 2. Layout patterns for outdoor / forest rooms

### 2.1 Verticality and layers
- Ginso Tree is the clearest sourced vertical shaft: a tree as an ascent with a rising-water escape. [read] Xbox Wire.
- Terraria stacks surface, underground and cavern layers, with forest hills and Living Trees as the doorway between surface and underground. [read] terraria.wiki.gg Forest/Layers.
- Cave Story bidirectional rule: design each shaft for climbing and for falling. [read] soldierfromthesurface. Super Metroid's first tunnel is "mostly vertical, presenting different challenges when returning up than when falling down." [snippet] search summary of Bille's analysis (henrique-lage / Bille results; page not opened).
- Hollow Knight gates verticality by ability: "Vertical shafts demand Mantis Claw (wall climbing)", "High ledges require Monarch Wings". [read] ludonauta.

### 2.2 Open sky where rooms normally have a ceiling
- No source found on handling a ceiling-less room in a screen-grid engine. [gap]
- Sourced analogue: Super Metroid's surface is a flat floor "between two high cliff walls" with no visible roof. [snippet] metroid.fandom.
- Blasphemous moved from "scrolling environments to screen-based layouts" in June 2018 for performance and collaboration. [read] GD Blasphemous. Grid rooms plus open-air art are workable. [inf]

### 2.3 Camera in big open rooms
- Scroll Back (Keren) techniques: "Camera follows the projected (extrapolated) position of the player"; platform-snapping ("Camera snaps to the player only as it lands on a platform"); lerp smoothing; dead-zone window; "The camera-window is as high as a standard jump" (Rastan Saga example). [read] GD Scroll Back.
- Same article warns "Enemies coming from above are less noticeable, especially if [character] has already moved vertically within the window." [read] GD Scroll Back.

### 2.4 Foreground / background layering and keeping platforms readable
- Celeste: "a one-pixel border around the external edge of each solid"; all tilesets share "a dark, flat color" infill; solids stay most vibrant, backgrounds use "desaturated colors, which simulates the effect of atmospheric interference." [read] aran.ink.
- Dead Cells: "collisions contrast sharply against backgrounds", interactive elements (ladders, platforms) sit at mid-range contrast, backgrounds "fade into each other". [read] GD Dead Cells art deep dive.
- Pixel-platformer guide: main-layer objects get "a solid outline with high contrast"; the walkable outer edge gets more detail; foreground decoration "must never hide the main character" and goes "on the margin of the screen, generally in places that the character cannot reach"; far layers read as silhouettes. [read] sandromaglione guide.
- Hollow Knight splits foreground / middle ground / background; the middle ground gets "much stronger contrasts and thicker outlines." [snippet] medium 3d-environmental-art (fetch 403, so unverified).
- Composition guide: foreground "frames the scene", centre of interest holds dominants, background "closes composition with less detail." [read] GD Composition in Level Design.
- Conflict on saturation: aran.ink says desaturate the background; sandromaglione says backgrounds get "more saturated colors, as well as less amount of different colors" while inner tile fill is "less contrast". They agree on lower value contrast and fewer colours behind the play plane, and on an outlined walkable surface; they disagree on which way saturation goes. [read] both. Safe rule is value contrast plus outline, not saturation. [inf]
- Ori art team hand-painted "a top, down, left, right, back, and front light expression" for assets (expensive). [read] TheGamer.
- Hollow Knight no-pass-through rule is a readability trade: one-way ledges are a convenience this game already has. [inf] from ludonauta.

### 2.5 Landmarks, wayfinding, hubs, clearings
- A dominant "can't merge with the rest of the scene's objects but it still has to be consistent with those objects" (tower in Dishonored). Funnels and choke points steer players. [read] GD Composition. A giant tree or waterfall can be the forest's dominant. [inf]
- Clearings as hubs: Crateria landing site is the surface hub; Zero Mission calls the hub what "makes backtracking feel natural." [read] goombastomp ZM; [snippet] metroid.fandom.
- Blasphemous: shortcuts replace backtracking ("go straight to wherever they want to be"). [read] GD Blasphemous.
- Cave Story "Mimiga Village" model: danger-free hub for learning movement. [read] soldierfromthesurface.

### 2.6 Weather and day-night (only if cheap)
- Terraria: day and night swap enemy rosters on the same forest (slimes by day, zombies by night). [read] terraria.wiki.gg Forest.
- Dead Cells gradient maps recolour a biome by editing one map. [read] GD Dead Cells art deep dive. A dusk or night variant of the forest rooms via one palette swap is cheap. [inf]
- Super Metroid rain and thunder on the surface are its mood device; thunder effects stop while music continues. [snippet] metroid.fandom music page; "acid thunderstorm" [read] goombastomp SM.

## 3. Forest mechanics and hazards: cheap and fair

- Introduce each gimmick alone, then mix: "First, introduce your gimmicks to the player individually so that they learn how things work." [read] galaxytrail.
- Foreshadowing: "introducing the player to an element under a controlled environment, before this element is more integral to the game"; Layering combines hazards and "often relies on Foreshadowing to be able to present a fair challenge." [read] GD Level Design Patterns in 2D Games.
- Safe zones: "areas ... where the players are not exposed to negative interactions", used to break pace. [read] GD Level Design Patterns in 2D Games.
- Thorns/brambles: static, single-touch, readable as Celeste spikes (taught in chapter 1). [read] ljvmiranda921. Greenpath adds hanging spores and thorn traps. [snippet] exitlag.
- Bounce pads: "Spring: For bouncing high into the air. Quite useful if the player's normal jump isn't very strong." [read] galaxytrail. Silksong has bounceable mushrooms. [snippet] fextralife. Hollow Knight's pogo is optional: "you never actually need to do it. ... you can use it to get a few secrets." [read] toschestation (Pellen).
- Moving and falling platforms: hovering platform "works well linking separate gimmicks"; collapsing floor "doesn't always have to dump the player into lava or spikes - it could lead them to an alternate path"; flipover platform. [read] galaxytrail. Greenpath vine platforms that fall when slashed. [snippet]
- Wind: "Air Current: High-powered winds push you away in a specific direction." [read] galaxytrail. Celeste chapter 4 uses horizontal wind. [snippet] TV Tropes.
- Ambush from above: enemies above are less noticeable [read] GD Scroll Back; Greenpath enemies "hide in foliage" [read] hookshot blog; Cave Story pairs terrain with "dive-bombing bats above you" [read] soldierfromthesurface. Telegraph and camera bias are the fairness tools. [inf]
- Combat pacing: Dead Cells sewers are "very tight, restricting the ability to jump and dodge and forcing the player to think about their mob management"; some monsters are "placed where there is a lot of space to move and fight"; density example "1 monster for every 5 tiles". [read] GD Dead Cells hybrid approach. Outdoors implies fewer, more mobile enemies and more flyers. [inf]
- Large rooms for ranged enemies, conditional spawn by entrance side. [snippet] search summary, not in the page I read.
- Dead Cells pacing: "dramatic peaks and relaxing 'breaks'". [read] GD Dead Cells hybrid approach.
- Water crossings: no sourced design guidance beyond Terraria's forest lakes and ponds. [read] terraria.wiki.gg Forest. [gap] for fairness rules.

## 4. Concrete, checkable rules for THIS game (all [inf])

### 4.1 Sizing and room structure
- 640x360 is exactly 2x Celeste's 320x180, so Celeste's screen-scale lessons carry at 2x. [inf] from aran.ink.
- Main-route vertical shaft ledges at most about 56 px apart (63 px base rise minus roughly 10 percent margin); a 1x3 trunk (1080 px) then needs roughly 19 ledges. Check: no main-route rise exceeds 63 px. [inf] from the 63 px floor plus Scroll Back's jump-height window.
- Camera vertical window about 63 px tall with platform snap, look-ahead on wide rooms; ambush-from-above spawns must sit inside the visible window or be telegraphed by a shadow/sound. [inf] from GD Scroll Back.
- Open sky: add a per-room "no ceiling" flag or fill the 20 px ceiling with a canopy band of solids and one-way ledges so spider crawl keeps a ceiling lane. Cliff walls like Crateria's frame open air. [inf] from metroid.fandom Landing Site [snippet] and Scroll Back.
- Rest spacing: glow pool no more than seven screens apart in the forest, and one per hub clearing. [inf] from GD Blasphemous.
- Every room is crossed both ways because spawns respawn and death restarts at the first room: check each platforming room still works going up and going down. [inf] from soldierfromthesurface.
- Readability checklist per room: walkable surface has an outline or edge highlight; background layers have lower value contrast than the play plane; foreground props only at room margins; species sprites tested on the sky palette. [inf] from aran.ink, sandromaglione, Dead Cells, Cave Story hero contrast.
- First surface room has no creature spawns and music stays on the cave track until the player is outside. [inf] from Zero Mission safety and Super Metroid scripted music.

### 4.2 Species lanes through a forest
- Slime: mushroom-cap and leaf bounce pads raise it above base jump; cling on trunk bark gates a straight trunk climb over the ledge zigzag. [inf] from galaxytrail spring and ludonauta shaft-gate.
- Spider: bark and branch undersides are a continuous crawl lane; web zip crosses canopy gaps. Needs a canopy band if the room has open sky. [inf] from the sky-ceiling rule above.
- Wolf: 3x1 forest-floor trails and wide gaps for gallop and pounce; fallen logs for vault. Gap widths must exceed base-jump horizontal reach (read from player physics). [inf] from ludonauta wide gap = dash gate.
- Biped goblin: wall jump on trunks and cliffs, mantle onto thick branch lips, slide under head-height bramble lines. [inf] from ludonauta shaft = wall climb gate and Celeste spike lines.
- Main route stays base-jump only; each lane is a side path or shortcut. [inf] from the game's own rule and Blasphemous reusable shortcuts.

### 4.3 Where it attaches
- Surface above the Cave top (Crateria model): forest is the world's hub, with several roots down; base-jump route in, gate-verb shortcuts out. [inf] from goombastomp SM/ZM, GD Invisible Hand.
- Beyond the first area (Greenpath after Crossroads): long climb-out tunnel, then dark-green-to-daylight palette hand-off. [inf] from hookshot blog, Dead Cells tunnel.
- Late reward (after the Deep): delayed recognition, scripted music, a one-way drop back toward the first room so the player is "right where you landed". Fits death-restarts-in-first-room because it ends with a shortcut. [inf] from GD Invisible Hand and GD Blasphemous.

### 4.4 Three candidate layouts (screens: W x H; each screen 640x360)

Layout A, "Crateria hub": surface above the Cave top, optional but reachable by base jump.
```
        F6 Canopy Walk (3x1) --zip gaps--> [Nest 1x1 rare]
                |  (top of trunk)
        F5 Great Trunk (1x3) ledges=main, cling/zip=straight line
                |
Cave top -> F1 Mouth (1x1) -> F2 Treeline (2x1) -> F3 Clearing (1x1, glow pool, hub)
                                                      |  E                 |  S
                                    F4 Floor Trail (3x1, wolf) -> F8 Riverbank (2x1, water)
                                      (pounce gap -> [Den 1x1])        F7 Root Hollow (1x1)
                                                                          -> Fungal Grotto top (one-way switch)
```
Gates: F1-F4 base jump; F5 straight climb = slime cling or spider zip (zigzag ledges are the base route); F6 gap = spider zip; F4 Den = wolf pounce; F8 = swim.

Layout B, "Greenpath second area": after the Cave, a tunnel then forest, with a loop.
```
Cave (end) -> B1 Climb-out Tunnel (1x2, dark to light) -> B2 Sun Step (1x1, no spawns)
   -> B3 Bramble Path (2x1) -> B6 Spider Glade (2x2) -> B5 Mossy Bough (2x1) -> B3 (loop shortcut switch)
   B3 -> B4 Hollow Tree (1x2, interior) -> upper exit: wall jump -> B7 Fallen Giant (3x1, wolf vault) -> Fungal Grotto
```
Gates: B1-B3 base jump; B3 slide under bramble line = goblin; B4 upper exit = goblin wall jump; B7 = wolf vault; B6 = spider zip rare room.

Layout C, "Late surface after the Deep": short linear ascent then vista.
```
The Deep (top) -> C1 Long Stair (1x3) -> C2 Roots (2x1) -> C3 Threshold (1x1, no spawns, cave music holds)
   -> C4 Overlook (3x1, open sky, giant tree landmark, glow pool) -> C5 Return Drop (1x2, one-way to first room)
   C4 side: [Canopy Cache 1x1: cling] [Burrow 1x1: roll/slide]
```
Gates: C1-C4 base jump; C4 caches = species verbs; C5 one-way is the shortcut.

### 4.5 Open questions that no source answered
- How a screen-grid engine renders open sky inside the 20 px ceiling frame. [gap]
- Documented camera, scale and music recipes for a surface reveal. [gap]
- Team Cherry on Greenpath's design, Ori Sunken Glades/Blackroot rationale, Silksong Moss Grotto rationale, Terraria layer heights in tiles. [gap]

## Sources

[read]
- https://www.gamedeveloper.com/design/the-invisible-hand-of-super-metroid [read]
- https://aran.ink/posts/celeste-tilesets [read]
- https://hookshotchargebeamrevive.wordpress.com/2018/10/29/hollow-knight-how-to-design-an-immersive-world/ [read]
- https://www.thegamer.com/ori-and-the-will-of-the-wisps-art-interview/ [read]
- https://www.soldierfromthesurface.com/games/cavestory/ [read]
- https://www.gamedeveloper.com/production/art-design-deep-dive-giving-back-colors-to-cryptic-worlds-in-i-dead-cells-i- [read]
- https://www.gamedeveloper.com/design/scroll-back-the-theory-and-practice-of-cameras-in-side-scrollers [read]
- https://www.gamedeveloper.com/design/composition-in-level-design [read]
- https://en.wikipedia.org/wiki/Ori_and_the_Blind_Forest [read]
- https://en.wikipedia.org/wiki/Hollow_Knight [read]
- https://www.gamedeveloper.com/design/how-i-blasphemous-i-level-design-iterates-on-classic-metroidvanias [read]
- https://www.gamedeveloper.com/design/q-a-designing-the-gorgeous-metroidvania-i-ori-and-the-will-of-the-wisps-i- [read]
- https://ludonauta.itch.io/platformer-essentials/devlog/1084669/the-hidden-genius-behind-hollow-knights-terrain-design [read]
- https://www.gamedeveloper.com/design/level-design-patterns-in-2d-games [read]
- https://goombastomp.com/metroid-zero-mission-is-the-ideal-video-game-remake/ [read]
- https://goombastomp.com/super-metroid-retrospective-perfect-video-game/ [read]
- https://galaxytrail.tumblr.com/post/25734526468/2d-platform-game-gimmicks-the-what-and-how [read]
- https://terraria.wiki.gg/wiki/Forest [read]
- https://terraria.wiki.gg/wiki/Layers [read] (thin: no tile heights)
- https://news.xbox.com/en-us/2014/08/14/gamescom-ori-preview/ [read]
- https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach- [read] (Dead Cells)
- https://www.sandromaglione.com/articles/pixel-art-platformer-level-design-full-guide [read]
- https://ljvmiranda921.github.io/life/2020/08/15/celeste-part-2/ [read]
- https://en.wikipedia.org/wiki/Super_Metroid [read]
- https://en.wikipedia.org/wiki/Cave_Story [read]
- https://toschestation.net/on-bugs-and-bouncing-hollow-knights-william-pellen-interview/ [read] (pogo quote only)
- https://chrismcentee.com/portfolio-items/lead-designer-ori-and-the-will-of-the-wisps/ [read] (one sentence)

[snippet] (search summary only; page not opened or body empty)
- https://metroid.fandom.com/wiki/Landing_Site_(Crateria) [snippet]
- https://metroid.fandom.com/wiki/Planet_Zebes:_Arriving_at_Crateria [snippet]
- https://www.pcgamer.com/how-to-design-a-great-metroidvania-map/ [snippet] (fetched twice, body empty; "Fungus 1" is from the search summary)
- https://medium.com/3d-environmental-art/the-art-of-hollow-knight-f4c05dda3882 [snippet] (fetch 403)
- https://cavestory.fandom.com/wiki/Balcony [snippet]
- https://www.exitlag.com/blog/greenpath-in-hollow-knight/ [snippet]
- https://hollowknight.fandom.com/wiki/Thorns_of_Agony [snippet]
- https://rogueranker.com/hollow-knight-greenpath/ [snippet]
- https://gamerwalkthroughs.com/hollow-knight/greenpath/ [snippet]
- https://hollowknightsilksong.wiki.fextralife.com/Moss_Grotto [snippet]
- https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Celeste2018 [snippet] (wind in chapter 4)
- https://www.nintendolife.com/news/2016/09/interview_learning_more_about_tom_happ_and_the_making_of_axiom_verge [snippet] (opened; no level-design content, Axiom Verge claims come from search summary)
- https://www.ibtimes.co.uk/axiom-verge-interview-creator-tom-happ-solo-development-upcoming-pc-version-sequels-1497378 [snippet] (opened; no level-design content)
- https://www.gamedeveloper.com/design/video-the-level-design-of-i-celeste-i- [snippet] (opened; promo text only, no talk content)
- https://80.lv/articles/a-talk-with-ori-and-the-blind-forests-concept-artist [snippet] (Ori small-on-screen claim, search summary)
- https://henrique-lage.medium.com/how-super-metroid-changed-level-design-c6e612ea62a7 [snippet] (Bille-analysis summary: tunnel "different challenges when returning up than when falling down")
- https://www.anatomyofgames.com/2013/12/26/anatomy-of-super-metroid-4-shafted-anew/ [snippet] (fetch 403)
- https://primedpixel.co.uk/posts/lessons-ive-learnt-from-celestes-level-design/ [snippet] (fetch 404)
