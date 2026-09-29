# Vertical slice playtest checklist

Run: open the project in Godot 4.7 and press F5 (or `godot` in the project folder).

Controls: A/D move · W/S or ↑/↓ aim · Space jump · J tackle · K hold to eat · I inspect · U/O/H/L skills · Esc skill screen · F3 input debug · F11 fullscreen/window
Gamepad: left stick / D-pad move (stick also aims) · A jump · X tackle · B hold to eat · Y inspect · LB/RB/LT/RT skills · D-pad aims too · Start skill screen · Back input debug

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
- [ ] Every active shows an effect: green cloud (Poison Breath), blue streak (Water Blade), thread line, dash afterimages.
- [ ] Fullscreen: HUD text scales up and stays crisp.
- [ ] Holding a direction while casting aims the skill (8-way); with nothing held it fires forward. Up + Hydraulic Propulsion = vertical boost.
- [ ] Esc / Start opens the Skills screen (game pauses): stats, grouped skills with icons and level pips, detail card with MP cost and next-level bar. Q/E or LB/RB switch to Compendium. Enter / A on an active assigns it to U (again: O). Esc / B closes.
- [ ] Downing and eating creatures earns XP (gold line under the slots); each level gives 1 EP, +2 max HP, +1 max MP.
- [ ] When an evolution is ready the Great Sage announces it; spend EP on it in the skill screen to evolve.
- [ ] Controller aiming: press Back to show the input overlay; tilt the stick and cast — "last cast" should show the aimed direction.
- [ ] The cave scrolls in both directions: stair towers at x ~1400 and the far east lead up to the middle and upper tiers, and stairs above the upper tier reach the top gallery.
- [ ] Sticky Thread aimed at rock (up, diagonal, or at a wall) sticks and draws a rope; you swing on it. Left/right pump, up/down reel, Jump lets go with your momentum.
- [ ] Sticky Thread aimed at an enemy still slows/holds it. Aimed at nothing in range, it just flashes.
- [ ] Upper tier swing gap: the three rocks with vines are anchors; chaining swings crosses the gap.
- [ ] Evolving Swing Thread puts it in Sticky Thread's slot; its rope is longer and launches harder.
- [ ] HUD skill slots form one block top-right shaped like the pad: LT/RT on top, LB/RB under them; each shows the button, icon and name, and dims when you can't afford it.
- [ ] Skill screen: the stick moves one row per push (hold to scroll slowly); A accepts; B closes.
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
