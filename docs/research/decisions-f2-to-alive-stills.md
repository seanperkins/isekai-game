# What was decided on your behalf, F2a to alive stills

Every `Ruling:` and every deferred minor from the eight ledgers in `docs/ledgers/`, in the order they were made. Each ruling ends with what it costs if wrong.

## Rulings I made (31)


### F2a forest

- AreaBuilder.changed is named stale — on the script object build_areas.gd loads at run time, 'changed' is Resource's signal, so builder.changed(world) does not parse — cost if wrong: a rename
- the forest joins the cave on C3's RIGHT edge (span 200..320, a hop up of 46 from C3's highest ledge), not its top as the sketch says: C3's top has no ledge route to the ceiling and a shipped room's solids are not the builder's to change; the Cave Mouth is therefore at (3,0), and the forest's other cells shift one to the east of the plan's (Treeline (4,0), Clearing (6,0), Trunk (6,-3), Canopy (7,-3), Nest (10,-3), Trail (7,0), Den (10,0)) — cost if wrong: the cells in the plan
- the Root Hollow (FO4) drops into C4 (not C1 as the sketch says: C1's top is C6's shortcut and its altar is below the free span) and that exit pair carries the label gate wall_cling: the drop is one way down, and without the label C3 and C6 become ungated through the forest, which breaks the cave's pacing pins (test_rooms: C3 is behind the wall-cling chimney; test_grotto_rooms: the ungated Cave is worth 108) — cost if wrong: a label on one exit pair
- the `ResourceSaver.save != OK` guard in AreaBuilder.serialize survives mutation (a failed save leaves no file, so the text is "" either way) — kept as the explicit statement of intent — cost if wrong: one redundant line

### F2b swamp and village

- the Sump is the village module's (VI5, area swamp, flooded art), not the swamp's SW6 — the swamp module alone must build a valid world and the Sump's top joins the Yard — cost if wrong: one id
- executor's claim that flank puts ledges at y=936 in a three-screen room is wrong (floor_y of 1x3 is 1040, less 52 is 988; test_flank_stands_either_side_of_the_opening_a_hop_above_the_floor passes) — no change — cost if wrong: none
- cartographer P1, the village's two goblins, a rat and a junk heap in the Yard stand on the way to the Sump — kept: the village is a dead-end spur off the swamp that no required route passes (the Sump hole is a shortcut shut until opened from the far side), so none of its fights is required, VI4's fight-free spine holds; VI5 asks for staged sentries and standing makes them neutral to goblins in F2e — cost if wrong: remove four spawns
- F6 (a shipped room) gains one switch feature besides the exit — the shortcut needs a switch on the far side (the lint pairs every shortcut with a switch) — cost if wrong: delete one feature and the shortcut

### F2c cemetery, cathedral, crypt

- the Gate Tunnel attaches at D7's top (the table's), not D6's right edge: D6 is the Taratect's arena and a boss room has exactly one exit; the exit carries wall_cling like D7's own way in — cost if wrong: one exit
- AreaWorlds.upto(prefix) (the world with the later areas taken out) replaces the per-test without() lists, so a new area only adds its prefix to ORDER; the world-size pins of test_forest and test_deep_rooms (24 shipped rooms, D7's exits) now read the right world — cost if wrong: test helper only
- the Coffin Slide is 2x1, not 1x1: the Ossuary's hole is at its east end (cell 24) so a player walking in from the stair is not dropped at the door, and the slide's own hole is over D5's cell (23) — cost if wrong: one room's size
- executor's two ledge_reach findings (the Bell Shaft's and the Crypt Stair's ledges "disconnected from the floor") are wrong: the builder refuses to write a world with a finding and wrote these rooms; the numbers quoted (floor 1840, 1200) are not either room's (1040, 680) — no change — cost if wrong: none

### F2d volcano and demon area

- the Cooled Vault carries no heat_resist label: the gate is not a label yet (GATES holds wall_cling and swim) and a label on a floor hole would not hold a walker — it is a plain side room until heat is a rule — cost if wrong: add one label and one exit key
- executor's "the diff has no data/rooms/VO*.tres or DM*.tres" — the frozen changeset left out generated rooms on purpose (they are in the commits, `test_the_checked_in_rooms_are_what_the_builder_writes` reads them and passes) — no change — cost if wrong: none
- cartographer P1, "the Throne door assertion expects 640": the floor of a 1x2 room is 680 (720 less the 40 floor slab) and the test passes — no change — cost if wrong: none

### F2e the nine deeds

- RoomLint gains a 21st rule (room_tag), so the two pins of 20 rules read 21 — cost if wrong: two numbers
- the barrier and the hidden door share a base (RoomBlock), the gap, the lamp and the vigil another (RoomDeed, once per life through the rules ledger: SkillRules.count(event, {id})); the autoload is read by path at run time so the scripts compile without it — cost if wrong: two small base classes
- the village deeds are said on leaving the area village (the Sump below is the swamp's, so dropping into it is leaving); kept needs the Yard seen and no village kill, unseen needs all four village rooms and nobody alerted — cost if wrong: one list and one condition
- no AreaKit helpers for the five kinds (a feature call with an extras dictionary says it) and moonlit is a room tag, not a DeedTags area list like dark — a forest's cave mouth and den are not open sky — cost if wrong: a helper or two
- executor 2, RoomDeed falling back to /root/SkillRules when no ledger is given — kept: a feature tree built without a ledger (a standalone preview) then says its deed with no once-per-life check, which is harmless there — cost if wrong: a preview could say a deed twice

### F2f placing 169 creatures

- the placement sizes creatures by their drawn size (sheet frame or the creature they wear, times sprite_size) because RoomLint's creature_fit sees none of the 169 (none has a sheet of its own) — cost if wrong: a creature drawn larger than its estimate overlaps a neighbour
- a rare is drawn to a lair only while the lair's weighted load is under 8 per screen (a lair of the Deep's size takes three rares), and a lair is a preference, not a rule: the Deep has 32 rares and one lair — cost if wrong: a rare stands in an ordinary room
- the pins about the hand-made rooms (lineage calibration, the shipped XP totals, deep, grotto and flooded) now read AreaWorlds.upto("DM"), the world without the placed creatures; F3 calibrates the world with them — cost if wrong: those pins describe a world nobody plays

### F3 calibration

- no threshold changes — on the diet of the common creatures (the hand-made ones and the new commons) the full world reproduces every pinned property of the hand-made calibration (reveals after each first area on four starts, offers at the first evolution, every power's unlock within one eat of the Cave-start pins but Jolt's, within ten), and the old diet reproduces the hand-made numbers exactly (Toxic 15, Tide 17, Echo 18, Bulwark 43, Weaver 45); the new elites and rares are optional dangerous creatures a stage-1 body does not eat, so a diet that eats them opens lineages and powers sooner (the full diet opens Bulwark in the Cave) — cost if wrong: a bold eater sees the menu fill up early
- the design doc's walk eats every spawn; the calibration's diet is now the common creatures, and the completionist diet is reported as the upper bound that the richer diets approach — cost if wrong: a number in the design doc that says "completionist" means the common diet
- no gate changes — every atom that names a creature, species, part, bond or element is met by the world; the scarcest essence a gate asks for (22 blood, for the Vampire, the Heart-Weigher, Beast of Gévaudan and the Bloodcap) is in the world three times over (65), checked at a margin of 2.5; 53 atoms (deeds, streaks, verbs used) name nothing in the world and are counted — cost if wrong: a life that skips the swamp, the crypt and the demon area is short of blood
- the "long" bond is a derived kind (a bond kept a while, Companion), not a creature's; it is feasible when any creature accepts a bond — cost if wrong: none
- executor 2, the "long" bond is feasible when any creature accepts a bond — it is a derived kind (Companion says it after a bond is kept a while), not a property a creature has, so the world's bond-capable creatures are what it can be asked of — cost if wrong: a bond that cannot be kept long enough

### Alive stills

- the motion is procedural, not new art — the 140 twins have one frame each and no animation sheet to draw from; a 1.8 s breath (3 %), an 11 Hz hop (3 px) and a 6 % lean while it moves are enough to read as alive — cost if wrong: a twin that looks like it is wobbling rather than walking until its hand-drawn frames exist
- only the ACTIVE state moves — a stunned or downed still holds rigid, and the hurt box does not change with the lean — a hit lands where the creature is, not where it is drawn — cost if wrong: none seen
- cartographer P1, the hurt box follows the lean — declined; the hurt box is the body rectangle and the lean is drawn only, so it is already independent of the lean; pinned with test_the_hurt_box_does_not_move_with_the_breathing (passes before and after, so it guards the property rather than a fix) — cost if wrong: a hit that misses a creature drawn leaning, by a few pixels

## Deferred minors (2)


### F2c cemetery, cathedral, crypt

- docs/design-review/index.html still says "23 rooms in four areas" and "there is no generator": a dated snapshot of the design review page, not regenerated by this branch

### Alive stills

- hand-drawn frames for the 140 twins would replace the procedural motion; none are drawn, so a twin that is one still stays a still that moves
