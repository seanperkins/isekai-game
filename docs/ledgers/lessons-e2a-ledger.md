# SDD ledger — plan: docs/superpowers/plans/2026-10-05-lessons-e2a.md
Pre-flight: Task 3 consumes Lessons from Task 2 (learn(def) -> {first, element, essences}) — consistent; Task 4 consumes the deed Task 3 emits — consistent. The plan was not panel-reviewed separately; the finished branch is.
Task 1: complete (commits 9852455..f0749f4, tests: tools/run_tests.sh test_content → PASS: 10 tests)
Task 2: complete (commits f0749f4..af20814, tests: tools/run_tests.sh test_lessons → PASS: 8 tests)
Task 3: Ruling: a goblin drinking a water pool (terrain, not a creature) still pays its water essence as every species does; only creatures are learned from — the plan said it 'heals and says nothing else', but the design says a goblin 'eats living things only to heal', and a pool is not one — cost if wrong: the goblin gets water from pools; one condition to drop
Task 3: complete (commits af20814..e68c801, tests: tools/run_tests.sh test_player_lessons → PASS: 15 tests)
Task 4: Ruling: the Puck's gate is tested through FormGate.met on its FormDef (it is a stage-3 form of the Skulker, so a real offer needs a whole evolution first); the Beastcaller (stage 2, from the base goblin) is tested through real offers — cost if wrong: none
Task 4: tests/test_menagerie.gd pinned 186 creatures and 28 support monsters in three places (missed by Task 1's filtered runs); they now follow the data
Final: review: debate panel (executor, auditor, cartographer, pentester) — executor, auditor and pentester APPROVED with no findings; cartographer REVISE on two documentation nits (the report stage was not run: two doc findings, checked by hand)
Final: fixed tools/build_creatures.py's docstring still said 28 support monsters (now 29) — docstring only, no test applies; suite 3174/3174 on the branch before this edit
Final: minor (deferred): docs/design-review/index.html is a dated design-review page; its "In the game today" lines (devour is the only method, no drops or items) predate E1 and E2a and are left as a snapshot
