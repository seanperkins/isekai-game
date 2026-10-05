# A verb for every form (C2): execution ledger

Plan: `docs/superpowers/plans/2026-10-05-species-verbs-c2.md`. Branch feat/verbs-all, merged to main locally. Final suite 2865 tests; Python tests pass.

```
Spec: roadmap C2. Baseline 2840 (main 439a628).
Pre-flight: T1 drain/reveal/bridge/VerbArena consumed by T2 and T3 (rows use them; tests use the arena). T2 rows and T3 rows share form_verbs.json (disjoint forms). No conflicts.
Task 1: Ruling: drain heals by max(1, power × drain) of the nominal power, not of the damage after armour — the cast knows its power, not what the target took — cost if wrong: a drain on an armoured target heals a little more than it dealt
Task 1: complete (commits d2c5406..9476bd9, tests: tools/run_tests.sh → PASS: 2852 tests)
Task 2: Ruling: the arena's first version let a real lizard hurt the player, so every snapshot differed and four dead-verb mutations survived; the player is now untouchable in the arena and vfx nodes are counted (a delayed mark shows as one) — found by mutation — cost if wrong: none
Task 3: Ruling: Task 2's and Task 3's rows were written together from the design doc's Verb and Gives-up columns and applied in two commits by species; the full suite below covers both — cost if wrong: none
Task 3: complete (commits 9476bd9..11e2187, tests: tools/run_tests.sh → PASS: 2860 tests)
Task 2: complete (commits 9476bd9..11e2187, tests: tools/run_tests.sh → PASS: 2860 tests; Tasks 2 and 3 ran as one full-suite pass)
Final review: debate panel (executor, auditor, cartographer; pentester skipped by the classifier; round 1 REVISE). 13 raw, 3 survived, 9 refuted (the verifier read HEAD, which already had the fixes below).
Final: fixed drain healed from the nominal power, not the damage dealt — test_a_drain_heals_by_the_damage_actually_dealt_not_the_power, test_a_drain_on_an_almost_dead_enemy_heals_only_what_was_left, test_a_drain_on_an_enemy_that_cannot_be_hit_heals_nothing RED→GREEN (supersedes the Task 1 ruling)
Final: fixed drain accepted values outside 0 to 1 — test_validate_knows_drain_reveal_and_bridge RED→GREEN
Final: fixed the arena counted any vfx, so a dead reveal could pass — a mark now lays a verb_marks marker and the arena counts that instead; test_a_mark_lays_a_marker_on_its_target RED→GREEN
Final: fixed the Python test files had their main guard before the new test classes (a direct run skipped them) — moved to the end of both; a direct run now runs all tests
Final: fixed the plan's row counts (50 and 49) and the design doc's stale status (it said nothing new was built) — docs
Final: Ruling: a bridge is laid wherever it is cast, over solid floor as well as over a gap (the plank there is harmless), and "no floor" does not error — the plan's "do nothing" reads as "nothing odd" — cost if wrong: a plank appears where a bridge is useless
Final: Ruling: the species rows' effects are approximations of the design text and say so in their notes; the reviewers did not dispute any row's spec
```
