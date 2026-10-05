# SDD ledger — plan: docs/superpowers/plans/2026-10-05-bonds-e2b.md
Pre-flight: Task 3 (Companion) consumes Lessons.times from Task 2 and CreatureDef.bonds is not used by it; Task 4 consumes Enemy.can_be_bonded (2) and Companion (3) — consistent. The plan was not panel-reviewed separately; the finished branch is.
Task 1: complete (commits 41ff8ca..521112d, tests: tools/run_tests.sh test_bonds_data → PASS: 5 tests)
Task 2: complete (commits 521112d..91e4873, tests: tools/run_tests.sh test_enemy_bond → PASS: 8 tests)
Task 3: complete (commits 91e4873..209ef80, tests: tools/run_tests.sh test_companion → PASS: 19 tests)
Task 4: Ruling: a goblin's offering is the first carried part (Inventory.take_carried), never a worn graft — the plan said 'a carried part' without naming which; Inventory gained take_carried() for it — cost if wrong: the goblin cannot choose which part to offer
Task 3: Ruling: a companion spares stunned creatures (it only strikes awake enemies), so it cannot kill the prey the player stunned to bond or eat — the plan said 'a foe that can be hit'; cost if wrong: a companion lets a stunned foe be
Task 4: complete (commits 209ef80..000ecb6, tests: tools/run_tests.sh test_player_bonds → PASS: 21 tests)
Final: review: debate panel (executor, auditor, cartographer, pentester) — pentester APPROVED; executor, auditor and cartographer REVISE with 6 findings (the report stage was not run; each checked against the code by hand)
Final: fixed a wolf whose companion cleared the room was credited a solo clear (Amarok's gate) — test_a_room_cleared_with_a_companion_beside_you_is_not_alone RED→GREEN, suite 3236 then rerun
Final: fixed rooted enemies still hurt companions — test_a_rooted_enemy_does_not_hurt_it RED→GREEN
Final: fixed companions fought and were hurt during the frozen room transition (they keep simulating as siblings of the frozen player) — test_it_does_nothing_while_its_owner_is_frozen RED→GREEN
Final: fixed companions could target terrain switches (team "terrain") — test_it_does_not_go_for_a_terrain_switch_or_anything_that_is_not_an_enemy RED→GREEN
Final: fixed the research doc still listed taming as not built (and parts, grafts, lessons, which earlier pieces built) — docs only
Final: Ruling: the companion's growth counts the first dealing with its type, so +1 ATK comes after three dealings (two trickles); the design doc said "per three trickles" — the code and plan said dealings, and the effect of one dealing earlier is nil — the doc now says dealings — cost if wrong: one subtraction in Companion.atk and a test
Final: full suite after the fix pass: PASS: 3241 tests
