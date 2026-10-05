# SDD ledger — plan: docs/superpowers/plans/2026-10-05-areas-f2d.md
Pre-flight: Task 2 consumes the crypt's CR4 and AreaWorlds.ORDER from Task 1; no conflicts
Task 1: Ruling: the Cooled Vault carries no heat_resist label: the gate is not a label yet (GATES holds wall_cling and swim) and a label on a floor hole would not hold a walker — it is a plain side room until heat is a rule — cost if wrong: add one label and one exit key
Task 1: complete (commits 51bc85a..624feb8, tests: tools/run_tests.sh test_volcano_demon → PASS: 11 tests)
Task 2: complete (commits 624feb8..4aa96a9, tests: tools/run_tests.sh test_volcano_demon → PASS: 20 tests)
Task 3: complete (docs commit, rendered and viewed)
Final: panel REVISE x3 (executor, auditor, cartographer), pentester APPROVED
Final: fixed auditor P2, the Threshold's tablet told the player to "break the middle seal": no seal exists — it now reads as atmosphere — test_no_tablet_in_the_new_areas_promises_a_seal_or_a_gate_that_is_not_built RED→GREEN
Final: fixed cartographer P2, the roadmap still listed F2b to F2d as to build — it now lists F2e, F2f, F3 and art
Final: Ruling: executor's "the diff has no data/rooms/VO*.tres or DM*.tres" — the frozen changeset left out generated rooms on purpose (they are in the commits, `test_the_checked_in_rooms_are_what_the_builder_writes` reads them and passes) — no change — cost if wrong: none
Final: Ruling: cartographer P1, "the Throne door assertion expects 640": the floor of a 1x2 room is 680 (720 less the 40 floor slab) and the test passes — no change — cost if wrong: none
Final: suite 3477/3477 PASS (TEST_TIMEOUT=1700 tools/run_tests.sh)
