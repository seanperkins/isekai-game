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
