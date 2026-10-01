# Vertical slice playtest checklist

Run: open the project in Godot 4.7 and press F5 (or `godot` in the project folder).

Controls: A/D move · W/S or ↑/↓ aim · Space jump · J tackle · K hold to eat · I inspect · U/O/H/L skills · Esc skill screen · F3 input debug · F11 fullscreen/window
Keyboard + mouse: the mouse cursor aims (any angle, with a small reticle) · LMB/RMB skills 1 and 2 (hold to channel) · left hand: Shift tackle · F hold to eat · R inspect · Q/E skills 3 and 4 (W/S hands the aim back to the keys until the mouse moves)
Gamepad: left stick / D-pad move (stick also aims, 8-way) · right stick aims (any angle, with a small reticle) · A jump · X tackle · B hold to eat · Y inspect · LB/RB/LT/RT skills · D-pad aims too · Start skill screen · Back input debug

- [ ] Jump feels responsive; after ~40 jumps a Great Sage pop-up announces Leap and jumps get higher.
- [ ] Touching the tall column mid-air ~15 times unlocks Wall Cling; sliding down it is slower; Space jumps off it.
- [ ] Tackle (J) stuns a bat; holding K next to it for ~1 s eats it and heals.
- [ ] A lizard can't be stunned head-on, only from behind.
- [ ] Killing an enemy leaves a body you can eat for ~5 s.
- [ ] Eating 3 bats announces Echolocation; eating toads/spiders eventually announces Poison Breath.
- [ ] Both water pools can be eaten once each; 4 water unlocks Hydraulic Propulsion into slot U.
- [ ] U fires the active in slot 1; Tab swaps it with another owned active; level-ups appear on the ticker.
- [ ] I with nothing near shows your status (HP, stats with eat/skill split, skills, essences).
- [ ] I near a creature shows more info as Appraisal levels up (name/HP → stats/essences → skills).
- [ ] Toads spit poison: an initial hit then ticks that stop at 1 HP.
- [ ] Dying reloads the room with a fresh run; the Compendium keeps what you discovered.
- [ ] Pop-ups are readable and don't pause the game.
- [ ] Casting an active costs MP (blue MP line under HP); with too little MP the ticker says "Not enough MP".
- [ ] Every active shows an effect: green cloud (Poison Breath), a blue crescent that slides to the target (Water Blade), a silk thread with a slight sag, dash afterimages.
- [ ] Fullscreen: HUD text scales up and stays crisp.
- [ ] Holding a direction (left stick, D-pad or W/S) while casting aims the skill (8-way); the right stick or the mouse cursor aims it at any angle (a few degrees off flat or straight up counts as exactly flat or up); with nothing held it fires forward. Up + Hydraulic Propulsion = vertical boost (a tap; holding stretches it a little and never flies).
- [ ] Esc / Start opens the Skills screen (game pauses): stats, grouped skills with icons and level pips, detail card with MP cost and next-level bar. Q/E or LB/RB switch to Compendium. Enter / A on an active assigns it to U (again: O; LMB/RMB with the mouse). Esc / B closes.
- [ ] Downing and eating creatures earns XP (gold line under the slots); each level gives 1 EP, +2 max HP, +1 max MP.
- [ ] A base skill that can evolve (Sticky Thread and Hydraulic Propulsion at level 3, Poison Breath and Spore Cloud at level 4) offers BOTH of its evolutions at once; the Great Sage announces them. In the Skills tab the card says what it replaces and what it closes; the first Enter arms it ("Press again to choose"), the second evolves. The other branch and the old skill disappear, and the new skill sits in the old one's slot. Moving the selection or closing the screen disarms it. Dying and being reborn reopens every branch.
- [ ] Controller aiming: press Back to show the input overlay; tilt the stick and cast — "last cast" should show the aimed direction. Push the right stick: the reticle appears in that direction, casts go that way, and the overlay's `rstick` shows the raw reading and `aim` the cast aim.
- [ ] Mouse aiming: move the mouse (4 px or more) or click: the reticle follows the cursor, the HUD chips read LMB/RMB/Q/E, and the eat and inspect prompts say F / R. A pad button or stick hands everything back to the pad.
- [ ] Mouse live: crouch or reel with S: the reticle hides and the chips show U/O/H/L until the mouse moves or clicks; a click still fires at the cursor.
- [ ] Mouse live: Shift tackles, hold F eats, R inspects, Q/E cast skills 3 and 4 in play and still switch tabs in the Skills screen.
- [ ] Unplug the pad while holding the right stick: the reticle goes away.
- [ ] Click a windowed game to focus it (F11 to window): note whether the click casts skill 1.
- [ ] The cave scrolls in both directions: stair towers at x ~1400 and the far east lead up to the middle and upper tiers, and stairs above the upper tier reach the top gallery.
- [ ] Sticky Thread aimed at rock (up, diagonal, or at a wall) sticks and draws a rope; you swing on it. Left/right pump, up/down reel, Jump lets go with your momentum.
- [ ] Sticky Thread aimed at an enemy still slows/holds it. Aimed at nothing in range, it just flashes.
- [ ] A thread-slowed enemy wears a few silk strands (and a small web in one corner) until the slow ends; a thread-held enemy is wrapped completely in a cocoon until it is free. A Spore Cloud or Binding Web patch slow, and a tackle stun, leave no webs on it.
- [ ] Hold Sticky Thread on an enemy: a silk strand stays taut to it; from Sticky Thread level 3 it stays stunned (below that it only stays slowed, wearing strands), MP ticks down one point every half second, and it lets go at 3 s or when you release. Hold Hydraulic Propulsion: a spray trails the slime and the burst carries on for up to 0.6 s. Holding a skill blocks other casts until you release.
- [ ] Upper tier swing gap: the three rocks with vines are anchors; chaining swings crosses the gap.
- [ ] Evolving Swing Thread puts it in Sticky Thread's slot; its rope is longer and launches harder.
- [ ] Binding Web (Sticky Thread's other branch) never ropes: it holds an enemy at once and leaves a pale web patch where the thread ends (at the enemy, at the rock, or at full range) that slows anything inside for 4 s.
- [ ] Miasma: the poison cone plus a green cloud that lingers where it ends and poisons; Venom Bolt: an instant green line that hurts every enemy on it; Healing Spores: a cloud around you that heals 1 HP a second while you stand in it; Puffball: the cloud lands where a lob would land (floor, wall, or the end of the arc) and is wide.
- [ ] HUD skill slots form one block top-right shaped like the pad: LT/RT on top, LB/RB under them; each shows the button, icon and name, and dims when you can't afford it.
- [ ] Skill screen: the left stick moves one row per push (hold to scroll slowly); A accepts; B closes. (Controls now keeps seeing input while the screen pauses the game, which is expected to make this work reliably.)
- [ ] Bestiary tab (third tab): creatures appear once seen on screen; appraising reveals stats/skills; eating shows essences and eat bonus; counts eaten and defeated; persists after death.
- [ ] The Cave is six rooms. Walking off a room's edge slides the camera into the next room, and you keep your speed. Enemies are back when you return.
- [ ] C2's chimney (Wall Cling) leads up to C3, and C3 leads left to the C6 nook. Tackle the cracked stone in C6: the floor opens and drops you into C1. On a new run the hole is still open.
- [ ] Inspect by the C6 tablet shows its lore. Inspect in C4's Glow Pool refills HP and MP, and a pop-up says "A voice — Your body settles."
- [ ] Menu → Map tab (fourth tab): visited rooms, a highlight on your room, dots for exits you haven't taken, and "Rooms found N/6".
- [ ] Dying shows "You dissolve." for a moment, then the run restarts in C1. The map and the opened shortcut stay.
- [ ] Enemies only notice you with a clear line of sight (rock blocks it) and give up about 2 s after losing you. Walkers turn at ledges and walls instead of falling off.
- [ ] Toads puff up (flashing) and lob a green glob in an arc: step aside and it misses; rock stops it.
- [ ] Lizards stop and flash, charge fast, then pant for a second: that's the moment to tackle them from behind.
- [ ] Bats hover above you, flash, then dive in a straight line at where you were; sidestep and they miss, then climb back.
- [ ] The slime is about twice its old size and drawn frame by frame: idle breathes, run is a four-frame squelch, jump/fall/land squash and stretch, the tackle stretches forward.
- [ ] Hold down (S / ↓ / stick down) on the floor: the slime flattens into a puddle at half speed, and un-squashes when you let go. It can't stand or jump under a low ceiling.
- [ ] Hold K/B next to a stunned enemy: the slime drapes over it and the enemy shrinks inside until it's eaten; letting go reveals the enemy again.

## Sound (by ear; headless tests cannot judge how it sounds)

- [ ] Open `tools/audio/preview.tscn` and play every cue. Note any that clip, click, sound harsh, or are far louder or quieter than their neighbours. Tune `volume_db` in `art_source/audio/recipes/*.json`, then rebuild with `tools/audio/synth_sfx.py` and `tools/audio/build_cues.py`.
- [ ] Play each biome bed for at least a minute. The loop point should be inaudible.
- [ ] In a run: jump, land from a small and a big drop, run, wall-slide, crouch-spread, tackle, eat, take a hit, drop below 30% HP (heartbeat), die. Each has a sound and none keeps looping after death or restart.
- [ ] Absorb a stack of essence: one pleasant rising chime, not a machine gun.
- [ ] Open the menu: the music dips and returns. The Sound tab's sliders change loudness; 0 is silent. Quit and relaunch: the values persist.
- [ ] Walk between rooms in the same biome: the music never restarts.
- [ ] Every creature is drawn frame by frame: bats flap and hover before a dive, toads hop, puff up, then spit, lizards wind up, charge and pant, spiders hang, drop and crawl. A stunned creature has its own dazed pose.
- [ ] Killing a creature plays a death that matches the blow: a tackle knocks it back and it tumbles onto its back, Poison Breath melts it green, Water Blade cuts it in two. It can't be eaten until it has finished falling, then the 5 s eat window starts.
- [ ] Contact hurts where the slime's drawn skin meets the creature's drawn body (the slime is wider than its old box); a spit glob that lands on a flat, spread slime still hits it, one passing well above misses.
- [ ] Every Cave room is dressed with scenery at different depths (arches, pillars, floating mossy islands with hanging roots, waterfalls, crystals, mushroom groves, stalactites). Walking sideways or climbing the three-screen shaft (C5), the far props drift slower than the near ones on both axes, and the ceiling scenery is at the ceiling when you are.
- [ ] None of the scenery ever draws over the slime, creatures or terrain, and none of it is mistakable for a platform you can stand on.
- [ ] Reaching level 10 stops XP and the HUD says "Lv 10/10 MAX" and "Your body can evolve". A new Form tab appears in the menu (Esc, then Q/E): it offers up to three forms chosen by what you ate (eat plenty of spiders and Weaver is offered first), and Enter evolves you. Launch with `-- --evolve` to start at the cap.
- [ ] Evolving plays a short glow, swell and ring (about a second, no damage, no walking), then your level resets to 1, your HP and MP keep their level bonuses, your skills level up to the new cap ("Your skills grew."), and the new body's skills are granted. The Weaver line (Weaver, Snare or Arachne, Silkbound Sovereign) is fully drawn; other forms are the plain slime tinted and scaled until their art is made.
- [ ] Skills sit at Lv5 until you evolve (the skills tab says "Capped until you evolve"), then Lv8, 12 and 15. Repeating the same enemy pays a quarter XP, so the Cave alone cannot reach the cap.
- [ ] The Cave's first room has a pale violet rebirth pool near the start (already attuned). Inspecting another rebirth pool ("Y: attune") says "Your body will remember this place" and unlocks it for every future run. With more than one unlocked pool, dying opens a menu (up/down, Enter or A; locked pools read "???") where you choose where the next life begins; the last choice is pre-selected. A rebirth pool's kit grants a few skills (known, not discovered: their conditions stay hidden until earned, then "You understand [Skill]."), a starting level (no EP) and seeded affinity.
- [ ] The Fungal Grotto: drop through the hole in the Drop Shaft's floor (C5) into G1. The chain of mushroom caps under the hole climbs back up to C5 (hop from cap to cap, then out onto C5's floor west of the hole); standing on the top cap never flickers between rooms. G2 (Spore Hall) has an upper walkway and a lower floor with a hole down into G3, and two shafts of caps climb between them; G3's chain climbs back up to G2. G3's east climb leads to G4 (a Glow Pool and a tablet).
- [ ] Spore Moths drift in slow loops, flash, then drop a spore puff that poisons once and fades; a Mushroom Crab charges like the lizard and a front tackle hurts it but does not stun it (hit it from behind); Vine Snakes hang under the overhangs, coil when you pass under, lunge, and retreat to their spot. Their deaths, corpses and eat window match the Cave's.
- [ ] Eat spore four times and Spore Cloud unlocks (a cloud that slows and poisons enemies, never you); eat shell four times and Hardened Shell unlocks (less knockback each level). Both cap at Lv5 until you evolve.
- [ ] A first pass through the Cave and the Grotto reaches the level-10 cap in G4 (Eat and down everything on the way), not sooner. The Grotto's rebirth pool (G1) attunes; dying then offers the menu, and the Grotto life starts at level 3 with Leap and Wall Cling known.
- [ ] The Pale Moth in G5 (a pale, larger moth) is reached only by wall-climbing the shaft on G3's west side; it is worth 16 XP and never needed for the cap.

- [ ] DEF helps against big hits by a percentage and never cancels one entirely: Body Armor levels shave more off a lizard charge than off a bat bite, and a level-1 slime still takes at least 1. Poison ignores DEF (toad spit and Spore Moth puffs cost the same with any Body Armor); Poison Resistance shaves both the spit and its ticks: at low levels a resisted spit still costs a little HP over its three seconds (from about level 6 the ticks alone may round away for the first spit and show up on the next).
- [ ] Poison Breath, Water Blade and Venom Bolt hit harder as ATK rises (eat spiders and vine snakes): the Skills tab's "Damage" line shows the ATK-boosted number, and Spore Cloud, Healing Spores, Puffball and Binding Web do not change. Miasma's cone counts once.
- [ ] Grotto creatures are sturdier than the Cave's: a Mushroom Crab has 10 HP and five weak-point tackles (one from behind, four while it is stunned) finish it inside a single stun; Vine Snakes and Spore Moths take a hit more than they used to. Body Armor's description says it stops physical damage only.

## Room editor (by hand; the headless suite cannot judge how it feels)

- [ ] Run `tools/edit_rooms.sh`. The editor opens on C1 drawn as the game draws it; the status bar shows a path inside `.tmp/editor-home`. Pick another room from the drop-down at the top left.
- [ ] Solid tool: drag a rectangle. A label says "one-way ledge" (at most 24 px tall) or "rock" while you drag; releasing draws it in the room's own tiles. Select tool: click it, drag it (it moves in 4 px steps), Delete removes it.
- [ ] Creature tool: pick a creature in the palette and click open space; a sprite marker appears. Clicking inside rock or a wall is refused with a message. An unknown creature id (edit a room file by hand to try) draws as a red box.
- [ ] Exit tool: drag along an edge with a neighbour (for example the right edge of C1 if you delete its exit first with Select and Delete). The exit appears on both rooms; Validate says "No problems found." A drag past what the neighbour covers is refused with a reason. Dragging an exit with Select moves both halves.
- [ ] Cmd/Ctrl+Z undoes a whole exit (both rooms) in one step, Shift+Cmd/Ctrl+Z redoes; typing in the New room id field never undoes.
- [ ] F5 (or Play, then click a spot) starts the real game in that room at that spot with your unsaved edits. Dying returns to the editor with no menu; F5 returns too, also from the skill screen (Esc). Nothing you did in play shows up in your real Bestiary or map.
- [ ] Save (Cmd/Ctrl+S) writes only the rooms marked `*`; `git status` shows exactly those `data/rooms/*.tres` files (a first save of an untouched room changes only the script id line).
- [ ] New room...: choose an edge, an id and a size; the room appears level with its neighbour with a door in the wall between them. A room above or below a neighbour warns that it cuts a hole and is not walkable until you add ledges.
- [ ] Validate names a room nothing leads to. Launching the editor any other way than `tools/edit_rooms.sh` still edits and saves, but Play refuses and says why.
- [ ] Feature tool (second toolbar row shows `Validate (N)`): pick `tablet` in the palette, click open air above a floor or ledge; it stands on the surface below. Type a title and a line in the right-hand panel, press Enter or click elsewhere, then Save: `git diff` on that room shows the text. Cmd/Ctrl+S saves even while you are typing in that panel.
- [ ] Place a `switch` and give an exit a shortcut (select the exit, type an id): `Validate (N)` counts a problem until a switch and an exit use the same id, then it clears. Clicking a line in the list opens that room, selects the thing and centres it.
- [ ] Place a `rebirth_pool`, set its level and tick two skills; select G1's pool and tick another: G1's affinity is untouched in the saved file.
- [ ] Grow menu: grow a room to the left and to the top. Everything in it stays where it was in the world (the World view's other rooms line up); a side that touches a neighbour is refused with "would overlap". Cmd/Ctrl+Z undoes a grow in one step.
- [ ] Tab hides every panel and shows them again; typing in a field does not trigger it.
- [ ] Play with `Wall Cling` on starts the slime with Leap and Wall Cling; with `Open shortcuts` on, a room whose floor is a closed shortcut (C6) is played with the hole open and no switch. Both toggles are still on after F5 brings you back, and nothing reaches your real save.
- [ ] World button: every room is a rectangle at its place in the world, the current one outlined; click one to open it, Esc or World again to close.
