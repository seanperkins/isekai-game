# Metroidvania room design and level-editor reference

Purpose: feature-set input for a small tile/rect-based room editor (Godot 4.7, rooms as `RoomDef` data, slime with jump / wall cling / thread swing / water-jet dash / poison breath).

Confidence tags: **[read]** = I fetched and read the page or PDF. **[snippet]** = only a search-result summary, not verified against the page. **[inf]** = my inference or convention, no source found. **[gap]** = searched, nothing sourced. Pages that returned 403 or TLS errors (PC Gamer, Maddy Thorson's "Celeste & Forgiveness", Mega Cat, devmag.org.za, pcgamesinsider) are not cited for content.

---

## 1. Level design principles for metroidvania rooms

### 1.1 Gating and ability locks
- Model the world as a lock-and-key graph before building rooms. One dev colour-coded nodes: blue = biomes, red = gates, yellow = abilities/items [read: Dreamnoid]. Another used yEd for a room-succession graph: mandatory vs optional rooms, straight edges = direct paths, curved edges = backtrack routes [read: Nikles].
- Keep two ability lists: mandatory abilities in strict order (critical path) and optional abilities that gate only secondary content, so sequence breaks cannot strand the main path [read: Dreamnoid].
- Mark Brown on Silksong: abilities are "keys" and in Act 1 "each key only opens a few locks", which keeps the player moving predictably; a later key that opens many locks makes the world non-linear [read: GMTK Substack]. Design choice: how many locks does each of your abilities open?
- An upgrade should change how you play, not just stats; a "key" is single-use gating. Obstacles should change to reflect abilities, e.g. gaps and heights that only a movement upgrade clears [read: Game Developer "Foundation of Metroidvania Design"].
- Soft gates exist too: Super Metroid limits early Norfair exploration with heat damage, and a one-way shaft with fast bugs "no hope of returning" splits the world into digestible chunks [read: Game Developer "Invisible Hand of Super Metroid"].
- A gate room should have one job: make the player *see* an area needing an ability they lack. Make the blocker memorable (light, landmark, room shape). After acquiring the ability, require it again immediately, then a third time to enter the new region [read: Subtractive Design / Kynan Pearson].

### 1.2 Teach, test, twist
- Nintendo's 4-step structure (from Hayashida, drawn from kishotenketsu): introduction (learn the mechanic), development (slightly more complicated), twist (something makes you think about it differently), conclusion (demonstrate mastery). Decide the *conclusion* first [read: Game Developer "Secret to Mario level design"].
- Celeste: mechanics introduced simply, tested in isolation, then combined; safe landings before pits; ice blocks foreshadowed in a tutorial. Fan analysis [read: Casey Jarmes].
- Super Metroid "locks you in" until you learn the needed input (brittle-floor room needs the run button); the Grapple Beam is planted in three separate teaching caverns before it gates progress [read: Invisible Hand]. Applied to the slime: each ability gets a no-enemy teaching room where failure costs only a respawn, then a test room, then a twist that combines two abilities (e.g. swing + poison).

### 1.3 Sightlines and foreshadowing
- Show the goal before it is reachable: Super Metroid's statue room shows bosses before you fight them; Maridia's glass tunnel keeps an unreachable area visible; the Charge Beam corridor has "two blocks that stand out like a sore thumb" [read: Invisible Hand].
- Secrets telegraphed by odd colouring on walls and blocks (Celeste) [read: Casey Jarmes]. Silksong hides secret walls from the map until found [read: GMTK Substack].
- Put the visible-but-locked thing on a route the player will retraverse (Maridia's tunnel) [read: Invisible Hand].

### 1.4 Room size, pacing, camera
- Reference sizes: Celeste uses a 320x180 canvas; default room is 40x23 tiles of 8 px and the camera scrolls between rooms [snippet: Aran P. Ink]. Thorson: 5 px is "more than half a tile" in a 320x180 game [read: Thorson thread via Thread Reader]. Spelunky: 4x4 grid of 10x8-tile room templates [snippet]. Super Metroid rooms are multi-screen grids [snippet].
- Hollow Knight's team used no analytic tile metrics; they built for "exploration and discovery" and grew the map organically [read: Game Developer]. No published room-size formula [gap].
- [inf] Size rooms as multiples of the camera viewport: one screen = puzzle/arena, several screens = traversal, tall = shaft. Put arrival pads (safe standing space) at every entrance.
- Camera: lead the camera in the falling direction or zoom out so the player can react; avoid hazards in blind spots below the view [read: davetech].
- Room-to-room links: Dead Cells' per-biome graph specifies how many tiles separate entrance from nearest exit [read: Deepnight]. Edgar matches doors by equal length and supports entrance-only / exit-only doors [read: Edgar docs]. [inf] For your exits with from/to spans: neighbour edges must have overlapping spans of equal length, and the arrival position must be a safe standable spot.

### 1.5 Save points and safe rooms
- Saves are pacing signals and confidence markers: place them before bosses and before teaching hard mechanics; Super Metroid deliberately breaks saves in the Wrecked Ship for tension [read: Invisible Hand]. Put save rooms at crossroads so they serve several paths, plus mid-stretch saves in hard sections [read: Dreamnoid]. Celeste gives "a moment to breathe" before a difficulty spike [read: Casey Jarmes].
- **[gap]** No sourced numeric spacing (minutes or rooms between saves). Treat spacing as a playtest-tuned value; a validator could report "rooms/path length since last save" rather than enforce a number.

### 1.6 Shortcuts, loops, backtracking
- "Levels should be built to reveal shortcuts upon gaining new abilities. This doesn't just happen by accident. You have to intend it." [read: Subtractive Design].
- Make revisits interesting: new paths from new abilities, collectibles first seen out of reach, changed enemy power, events that alter familiar spaces [read: Dreamnoid]. Super Metroid's first act ends back at the start, a "closed circle" [read: Invisible Hand].
- Silksong offers bypasses (purchasable keys skipping bosses, hidden routes) and fast travel to cut backtracking [read: GMTK Substack; Foundation article for fast travel].
- [inf] A shortcut gate should open from the far side and land in a hub or save room.

### 1.7 Secrets
- "Hide voluntary upgrades all over the place" so a lost player still finds something (Super Metroid's safety net) [read: Invisible Hand]. Two kinds: findable with no new ability, and backtrack-required [read: Foundation article].
- Track rewards in a tool so they do not cluster (Dreamnoid lists "empty chests") [read: Dreamnoid].

### 1.8 Difficulty curve inside a room
- Kishotenketsu applies per room: [inf] calm arrival, one core idea, a twist, then exit or reward. Celeste treats each screen as its own puzzle [read: Casey Jarmes].
### 1.9 Jump-distance and height metrics (making rooms completable)
- Derive everything from the player's jump. With `h(t) = v0*t - 0.5*g*t^2`, two choices (max height and jump duration) fix v0, g and horizontal distance; variable-height jumps add a third (minimum height) [read: Game Developer "Designing a 2D Jump"]. [inf, algebra] With time-to-apex `ta`: `g = 2h/ta^2`, `v0 = 2h/ta`, flat-ground range = horizontal speed x `2*ta`. Your build script and validator should read the live constants, not copies.
- Psychonauts 2 ships an editor "jump metrics tool" that draws the character's jump arc in the level while the game is not running [read: The Level Design Book]. The same page says "metrics are not magic": still walk the blockout.
- Readability rule (Suzy Cube, 3D but transferable): fixed minimum feature size (2 units ~ character height), max jump 5 units. Never make a landing exactly max height or a gap exactly max distance; heights and gaps should be clearly makeable or clearly not [read: Game Developer "Suzy Cube: Measuring Up"].
- Celeste's forgiveness widens the envelope: coyote time, jump buffering, half gravity at the apex, corner correction, wall jump within 2 px, super wall jump within 5 px [read: Thorson thread]. [inf] Compute metrics for the *unforgiven* envelope so grace features are margin.
- Survey sanity data: airtime 0.5-1.9 s, heights 0.6-5.6 character heights [read: davetech].
- **[gap]** No sourced "% of max jump" comfort rule (searched several phrasings). **[gap]** Mega Man metrics: nothing concrete found. Suggested tiers [inf]: "comfortable" / "tight" / "impossible", numbers measured from your own controller by simulation, tuned by playtest.

### 1.10 One-way platforms
- Semisolid ("as of Super Mario Maker, given the official name") means thin platforms you stand on and jump through from below [snippet: Super Mario Wiki]. Convention: jump up through, stand, drop down by pressing down; drop-through inputs seen in the wild: Down, Down+Jump, or Down twice [snippet: GameMaker community].
- Collision rule (tunnelling guard): ignore while moving up; while falling, collide only if the feet were above the platform at the start of the step [snippet: GameMaker forum].
- [inf, lint ideas] A ledge must not be embedded in a mass; needs head clearance above; drop-through must not be the only way out of a pit; do not use a one-way as wall or ceiling. Your <=24 px rule is a convention to keep, plus a lint that flags 25-32 px rects (likely a mistake).

### 1.11 Enemy placement
- Sourced: Dead Cells gives each enemy constraints (danger rating, platform compatibility, frequency, some once per tile/level) and counts monsters by total combat-tile length [read: Deepnight]. A telegraph must allow perceiving and responding without feeling sluggish; no numbers [read: Bugnet]. No hazards in blind spots [read: davetech].
- **[gap]** "Never spawn on a landing spot" has no direct source. [inf] Lint rules: keep spawns a clearance radius from entrances, save points and required-jump landing surfaces; ground enemy needs a floor run >= patrol length + telegraph distance; wall/ceiling enemies need that surface; spawn must not overlap a solid or float over a pit; no enemy inside a one-way ledge's drop-through column.

---

## 2. Room archetypes to template
Rules are [inf] unless a source is named.

| Archetype | Layout rules of thumb |
|---|---|
| Hub | 3+ exits, crossroads save point [Dreamnoid], no enemies at arrival, sightline to at least one locked exit, shortcuts terminate here. |
| Corridor | Two opposite exits (Edgar treats two opposite doors as a corridor [read]). One idea only; use for pacing or a single enemy beat; long ones need a mid ledge or rest spot. |
| Vertical shaft | Alternate left/right ledges no more than a comfortable jump apart (via the metrics tiers); wall-cling stretches need an unbroken wall of at least jump height; safe floor at the bottom; camera leads downward; decide deliberately if it is a one-way drop (Super Metroid's shaft split the world [read]). Your `shaft_climb` prefab is this. |
| Arena / boss | One camera screen, flat floor plus 1-2 ledges, no way to fall out, spawn pad at entrance, save room immediately before [Invisible Hand]. Locking doors can strand: Map Rando adds gray doors that do not close immediately and quick reload as softlock mitigation [read]. Then ability reveal, tutorial exit, shortcut back [Kynan Pearson]. |
| Ability gate | Blocker visible from a safe place; one purpose; preceded by a no-enemy teaching room; ability re-required twice after acquisition [Kynan Pearson]. Landmark it. |
| Shortcut door | Opened from the far side; lands in hub/save; placed after the hardest stretch so the return is cheap. |
| Secret nook | Dead-end, one screen, hinted by odd wall colour [Casey Jarmes], absent from the map until found [Silksong]. Some reachable with no new ability [Foundation article]. |
| Water room | Teach water movement in a shallow, hazard-free pool first; entry/exit ledges clear of the water; mark whether water blocks or enables passage (nothing sourced for slime specifically). |

---

## 3. Editor feature survey (value = for a solo dev with rect/prefab-based rooms; cost S/M/L)

| Feature | Who does it | Value | Cost |
|---|---|---|---|
| Layers (solid/decor/entity) | Tiled tile+object layers; LDtk IntGrid/auto/entity/tile layers; Ogmo tile/grid/entity/decal [snippet for Ogmo] ; Super Metroid keeps a visual layer and a behind-the-scenes physics layer [snippet] | High: separates collision from art; your `RoomDef` already does | S |
| Entities with typed fields | LDtk fields, value bounds, per-entity instance limit (a second PlayerStart moves the first) [read]; Tiled properties, classes, templates, inter-object "connection" arrows [read]; Ogmo values, nodes, resizable entities [snippet] | High: spawns, features, exits (resizable rect on an edge) | M |
| Auto-tiling | LDtk rules on IntGrid (Shift+R toggles rendered vs raw) [read]; Tiled automapping rule maps with probability, ModX/ModY, "AutoMap While Drawing" [read]; Godot terrain sets [read] | Low for MVP: you edit rects, and rendering by biome tileset is a game-side concern. Keep a "collision-only" view toggle | M-L |
| Prefab / stamp / brush | Tiled stamps, Ctrl+1-9 stamp slots, terrain/shape/bucket brushes [read]; Godot patterns saved in the TileSet [read]; LDtk stamp/random modes [read] | High: `stamp`, `ledge_chain`, `shaft_climb` as parametric brushes with ghost preview | M |
| Snapping and grid | Universal; Tiled coordinate grid [read] | High | S |
| Undo/redo | Mario Maker's Undodog [snippet]; Lönn undo/redo [read]; Godot `UndoRedo` (do/undo methods, merge modes) and `EditorUndoRedoManager` in plugins [read] | Non-negotiable; route every edit through commands from day one | S-M |
| Test-play from here | Mario Maker play-then-clear [read: Aramini]; Celeste Everest debug: Shift+click spawns player at cursor, debug map teleports to rooms, console `complete`, hitbox view [read: Celeste wiki]; Lönn teleport-to-room and F5-F7 hot reload [read] | Highest: turns a drawing tool into a design tool | M |
| Validation panel | Mario Maker forces the author to clear the course; no automated checks [read: Aramini]. Aramini's Unity tool gives live difficulty/probability [read] | High | M-L (see 4) |
| Jump-arc / ruler overlay | Psychonauts 2 jump metrics tool [read: Level Design Book] | High, cheap | S-M |
| Room graph / world view | LDtk world panel (W) with Free/GridVania/Linear layouts [read]; Tiled `.world` files, drag with World Tool, `onlyShowAdjacentMaps` [read]; Dead Cells per-biome graph [read]; yEd graphs [read] | High for a graph-of-rooms game; neighbour overlay to check exit alignment is M, drag-to-place rooms is L | M-L |
| Copy/paste | Godot selection + Ctrl+C/V to patterns [read]; Tiled rect/magic-wand/same-tile selection [read] | Medium | S |
| Hot reload | LDtk importer plugin for Godot reloads on save [snippet]; Everest F5 map reload [snippet]; Godot `@tool` script changes may need scene reload or editor restart [read] | High: reload RoomDef from disk on each play | S |
| Crash backup | LDtk backup and crash recovery [read] | Medium (`.bak` before each save) | S |
| Adopt LDtk/Tiled + importer | Godot LDtk importers exist [snippet] | You would still write an importer, exits/prefabs/validation/test-play, so it saves little unless you move to tile-based data | M |

---

## 4. Validation ideas

**Layer 1: lint (cheap, deterministic, run on every save).** [inf unless stated]
- Enemy or pickup inside a solid, or floating over a pit; spawn too close to an entrance, save, or landing.
- Gap or height beyond max jump (error) or within a margin of max (warning), per the Suzy Cube rule [read].
- Exit span outside its edge or embedded in a solid; neighbour room lacks an overlapping span (Edgar's equal-length door rule [read]).
- Zero-size or overlapping rects; 25-32 px rects; ledge without head clearance.
- Feature (save, gate, pickup) not in the reachable set.

**Layer 2: reachability.**
- *Grid flood fill with jump budget* [read: Tuts+]: node = (cell, jump value); jump value 0 on ground, +1 for a horizontal step from the ground, next even number on any vertical move; max = 2 x max jump height in cells; even values allow left/right/up/down, odd values up/down only; no diagonal moves through solids. Caveats from the source: minimum precision is one cell; if the algorithm allows more than the real physics, the bot gets stuck (or, here, the level is declared falsely completable), if less, valid paths are missed. It models jumping only: you must add edges for wall cling/wall jump, thread swing (anchor + arc range), water-jet dash (straight burst distance, cooldown) and water movement. [inf]
- *Platform graph* [read: Aramini et al., PDF]: nodes = platforms, edges = feasible jumps generated from physics parameters, four jump types (trivial, simple, falling, re-entrant), takeoff at platform edges, run/no-run variants. Difficulty of a path = sum of edge difficulties, success probability = product; DFS over acyclic paths shows the min-difficulty path. Tested on 58 users (2361 jumps): re-entrant hardest, falling easiest; model error (MAE) about 0.22-0.32, so a hint, not a verdict. Fits your data well: solid-rect tops and ledges are already platform nodes. [inf]
- *Simulation with the real controller*: Baumgarten's A* Mario agent won the 2009 competition by reusing the game's physics engine as a forward model [snippet]. [inf] Hybrid: analytic graph proposes edges; a headless run of the real player script certifies each edge and records which ability it needs; simulation also catches controller changes.

**Layer 3: exit-to-exit matrix.** Run reachability from each exit span to each other exit for each ability subset, producing "needs: none / wall cling / swing / dash". Super Metroid Map Rando records door-to-door links with requirement trees (items, techs, and/or, obstacles cleared, difficulty rating) in sm-json-data, "over 330,000 lines of manually crafted JSON" [read: maprando.com/logic/room/38, /about]. [inf] Compute yours instead of hand-authoring.

**Layer 4: world completability.** Forward-fill fixpoint: start with starting abilities, flood rooms via the computed links, collect abilities found, repeat; success if all rooms/gates are reached. Map Rando does the same for item placement and retries if progression stalls; it also requires "every room has a path to and from every other room" [read: /about]. Spelunky guarantees a start-to-exit path with no bombs or rope by generating the path first [snippet].

**Softlock and pit checks.** [inf, informed by Map Rando] For each entrance and arrival state (including falling in from above), require a path to some exit using only the abilities the player must already hold at that entrance. Flag pits with no exit; allow intentional one-way drops via an explicit flag. Map Rando says it mitigates rather than eliminates softlocks (gray doors, quick reload, rolling saves) [read].

**Human clear-check.** Mario Maker's clear check requires the author to beat the course before upload; losing a life restarts the check step [snippet: Fandom]; Aramini notes the game has no automated playability check [read]. [inf] Store a "cleared with abilities X on date, geometry hash H" stamp per room; any edit invalidates it.

**Playtest helpers.** Debug rooms and artificial save files with different ability sets [read: Dreamnoid].

---

## 5. Recommended MVP

### 5.1 Ordered feature list
1. **Data model first**: `RoomDef` plus its parts (exits, solids, spawns, decor, features) as separate `class_name` Resource scripts; the Resources doc warns inner classes do not serialize [read]. Give exits and spawns stable ids.
2. **Round trip**: load, edit, save `RoomDef`; room picker; render via the game's own room builder so the editor shows exactly what ships.
3. **Rect editing**: grid snap (8/16 px), pan/zoom, draw/move/resize/delete solids (thin = ledge preview), all as undoable commands.
4. **Exits, spawns, features, decor**: drag exits along edges (from/to), place creature spawns, save/gate/water, decor sprites; small property popup.
5. **Prefab brushes**: expose `stamp`, `ledge_chain`, `shaft_climb` with parameters and a ghost preview; bake to plain rects (no live link in MVP).
6. **Play from here**: launch the real game at room R and spawn point (x, y); reload `RoomDef` from disk on launch; plus an in-game debug key that teleports to the cursor (Celeste/Everest precedent [read]).
7. **Overlays**: max-jump arc/rulers from the cursor, collision-only toggle.
8. **Lint panel**: Layer 1 rules, click to jump to the offender.
9. **Reachability v1**: exit-to-exit for jump only, then add wall cling, swing, dash; show reachable region and the needs-matrix (Layers 2-3).
10. **World view**: neighbour overlay with exit-alignment check; later the world fixpoint and clear-stamps.

### 5.2 Data format
| | `.tres` (Resource) | JSON |
|---|---|---|
| Pros | Native; Inspector-editable; typed `@export`; text format is version-control friendly, binary `.res` for export [read]; `ResourceSaver` | Stable, greppable diffs; easy to validate outside Godot (Python in CI) and to hand or script edit; decoupled from script paths |
| Cons | Stores the script path (renames break) [read]; nested types need own `class_name` [read]; tool code needs `@tool` on every script it calls [read]; sub-resource id churn in diffs is **unverified** (save twice and diff) | Needs `to_dict`/`from_dict`; loses Inspector and typing; two formats to keep in sync |

Recommendation [inf]: keep `.tres` canonical because the game already loads it; emit JSON as a derived, read-only export for CI linting. No two-way sync in the MVP.

Source-of-truth trap [inf]: rooms today are generated by a build script. If the build regenerates `.tres`, it will overwrite hand edits. Either mark editor-authored rooms (`authored = true`) and have the build skip them, or "eject" a code-built room to raw data once, or let the editor emit a recipe (prefab calls + raw rects) that the build replays.

### 5.3 In-game scene vs EditorPlugin
| | EditorPlugin (proxy `Node2D` in the 2D viewport + dock/bottom panel) | In-game editor scene |
|---|---|---|
| Pros | Inspector, file system, save, dock layout free; `get_undo_redo()` integrates with editor history; `_handles`, `_edit`, `_forward_canvas_gui_input`, overlay drawing exist [read]; `EditorInterface.play_custom_scene(path)` and `_run_scene(scene, args)` (documented in the 4.7 class reference) can pass extra command-line args, and the game reads user args after `--` with `OS.get_cmdline_user_args()` [read; exact arg format `_run_scene` expects is unverified] | Instant edit/play toggle in one process (the Mario Maker model), real player and room builder, no `@tool` constraints, custom UI; `UndoRedo` class usable outside the editor (docs imply it, do not state it) [read] |
| Cons | Everything it touches must be `@tool`; tool code can crash the editor; script changes may need editor restart [read]; the play is a separate process, so no live edit-while-running (Godot 4.4 added an embedded game window and interactive in-game editing with camera override and object selection [snippet]; macOS embedding was added in 4.5 dev builds [snippet]; confirm in 4.7 on your Mac) | You build UI yourself (pickers, popups, text fields, panels); saving into `res://` from a running game is unverified (docs only say `res://` is likely read-only *after export*; `user://` is always writable [read]); crash loses unsaved work without autosave |

Recommendation [inf, opinion]: EditorPlugin first. The UI you would otherwise hand-build (inspector, undo, save, files) dominates solo-dev cost, and play-from-here works through launch args. Keep the game-side entry point (`--room`, `--spawn`) and the validator (pure functions over `RoomDef` + physics constants) independent of the editor host, so an in-game overlay can be added if process cold-start latency hurts iteration.

---

## 6. Sources
Read (fetched):
- https://book.leveldesignbook.com/process/blockout/metrics
- https://www.gamedeveloper.com/design/designing-a-2d-jump
- https://www.gamedeveloper.com/design/lessons-from-suzy-cube-measuring-up
- https://www.gamedeveloper.com/design/the-invisible-hand-of-super-metroid
- https://www.gamedeveloper.com/design/the-foundation-of-metroidvania-design
- https://www.gamedeveloper.com/design/the-secret-to-i-mario-i-level-design
- https://www.gamedeveloper.com/design/how-the-i-hollow-knight-i-devs-mapped-out-their-metroidvania-
- https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-
- https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/
- https://gmtk.substack.com/p/the-world-design-of-hollow-knight
- https://dreamnoid.com/articles/how-to-create-your-own-metroidvania
- https://nikles.it/2016/game-design/metroidvania-metroid-like-world-design/
- http://subtractivedesign.blogspot.com/2013/01/guide-to-making-metroidvania-style_16.html
- https://caseyjarmes.wordpress.com/2020/09/15/celeste-level-design-case-study/
- https://threadreaderapp.com/thread/1238338574220546049.html
- http://www.davetech.co.uk/gamedevplatformer
- https://bugnet.io/blog/how-to-design-enemy-attack-telegraphs (low quality)
- https://arxiv.org/pdf/1804.09153 (Aramini, Lanzi, Loiacono; read via PDF)
- https://code.tutsplus.com/how-to-adapt-a-pathfinding-to-a-2d-grid-based-platformer-theory--cms-24662t
- https://maprando.com/about and https://maprando.com/logic/room/38
- https://celeste.ink/wiki/Debug_Mode
- https://github.com/CelestialCartographers/Loenn/blob/master/README.md
- https://ldtk.io/ (plus /docs/general/world/, /editor-components/, /editor-components/entities/, /auto-layers/auto-layer-rules/)
- https://doc.mapeditor.org/en/stable/manual/ (introduction, automapping, objects, worlds, editing-tile-layers)
- https://ondrejnepozitek.github.io/Edgar-Unity/docs/basics/level-graphs/ and /docs/next/3d/basics/room-templates/
- https://docs.godotengine.org/en/stable/ (using_tilesets, using_tilemaps, making_plugins, running_code_in_the_editor, resources, data_paths, class_editorplugin, class_editorinterface, class_undoredo, class_os)

Snippet only (search summary, not verified):
- Aran P. Ink Celeste tilesets / camera facts: https://aran.ink/posts/celeste-tilesets
- Spelunky room sizes and guaranteed path: https://takenapeveryday.wordpress.com/2016/04/14/spelunky-level-generation/ (fetched page lacks tile sizes)
- Dead Cells "50:50 hand-made" and "known doable jumps" claims: search snippet only (pcgamesinsider 403; absent from the Deepnight text). Not relied on above.
- Super Mario Maker clear check: https://supermariomaker2.fandom.com/wiki/Clear_Check ; Undodog: https://www.mariowiki.com/Undodog
- Semisolid platforms: https://www.mariowiki.com/Semisolid_Platform ; drop-through inputs: https://forum.gamemaker.io/index.php?threads%2Fsemi-solid-platforms.14688=
- Godot embedded game window: https://github.com/godotengine/godot/pull/105884 and https://godotengine.org/article/dev-snapshot-godot-4-4-beta-1/
- Godot LDtk importer: https://github.com/heygleeson/godot-ldtk-importer
- Baumgarten A* Mario: https://www.aipanic.com/projects/marioai and https://github.com/jumoel/mario-astar-robinbaumgarten
- Super Metroid screens / BTS layer: https://metroidconstruction.com/SMMM/ (403 on fetch)
- Ogmo Editor 3 (thin page): https://ogmo-editor-3.github.io/docs/
