# SDD ledger — plan: docs/superpowers/plans/2026-10-05-areas-f2b.md
Pre-flight: Task 2 and 3 consume AreaKit.climb/flank from Task 1; Task 3 consumes SW3 and SW6 built in Task 2 — consistent
Task 1: complete (commits 57d5268..eb09dfb, tests: tools/run_tests.sh test_area_kit → PASS: 24 tests)
Task 2: Ruling: the Sump is the village module's (VI5, area swamp, flooded art), not the swamp's SW6 — the swamp module alone must build a valid world and the Sump's top joins the Yard — cost if wrong: one id
Task 2: complete (commits eb09dfb..597293f, tests: tools/run_tests.sh test_swamp_village → PASS: 8 tests)
Task 3: complete (commits 597293f..2c43b7d, tests: tools/run_tests.sh test_swamp_village → PASS: 17 tests)
Task 4: complete (commit 5452089, docs: the swamp and the village)
Final: panel REVISE x4 (executor, auditor, cartographer, pentester)
Final: fixed auditor P1+P2 and pentester P1, the Sump's hole into F6 was a `swim` label that does not stop a walker (water lets it sink through F6 and F4 into the Deep) — it is now a shortcut `sump_drop` shut until a swimmer pulls a switch on F6's highest ledge, `AreaModule.attach_feature` marks the switch `by` and `AreaBuilder.build_with` strips it before a rebuild — test_the_sump_joins_f6_by_a_shortcut..., test_the_switch_that_opens_it..., test_f6_gains_exactly_one_exit_and_one_switch..., test_a_feature_a_module_attached_is_not_added_twice... RED→GREEN
Final: Ruling: executor's claim that flank puts ledges at y=936 in a three-screen room is wrong (floor_y of 1x3 is 1040, less 52 is 988; test_flank_stands_either_side_of_the_opening_a_hop_above_the_floor passes) — no change — cost if wrong: none
Final: Ruling: cartographer P1, the village's two goblins, a rat and a junk heap in the Yard stand on the way to the Sump — kept: the village is a dead-end spur off the swamp that no required route passes (the Sump hole is a shortcut shut until opened from the far side), so none of its fights is required, VI4's fight-free spine holds; VI5 asks for staged sentries and standing makes them neutral to goblins in F2e — cost if wrong: remove four spawns
Final: Ruling: F6 (a shipped room) gains one switch feature besides the exit — the shortcut needs a switch on the far side (the lint pairs every shortcut with a switch) — cost if wrong: delete one feature and the shortcut
Final: fixed (suite flake, not mine) test_web_tether's recast test: the player fell out of the thread's range during the 0.9 s wait (no floor), failing on 3 of 4 runs under load — a floor under the player — 4/4 runs PASS
Final: fixed suite finding, ShippedRooms.only kept F6's attached switch so three lint tests saw a shortcut with no exit — it strips features marked by — test_room_edit_features, test_room_edit_problems RED→GREEN
Final: suite 3433/3433 PASS (TEST_TIMEOUT=1700 tools/run_tests.sh)
