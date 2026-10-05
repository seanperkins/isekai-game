# SDD ledger — plan: docs/superpowers/plans/2026-10-05-placement-f2f.md
Pre-flight: Task 2 consumes RoomLint.spawn_findings, the by-marker stripping and AreaWorlds.ORDER from Task 1; Task 3 consumes AreaPlacement from Task 2 and tools/creature_areas.json; no conflicts
Task 1: complete (commits 1f03c07..94287c8, tests: tools/run_tests.sh test_area_builder → PASS: 24 tests)
Task 2: complete (commits 94287c8..2f6011a, tests: tools/run_tests.sh test_placement → PASS: 10 tests)
Task 3: Ruling: the placement sizes creatures by their drawn size (sheet frame or the creature they wear, times sprite_size) because RoomLint's creature_fit sees none of the 169 (none has a sheet of its own) — cost if wrong: a creature drawn larger than its estimate overlaps a neighbour
Task 3: Ruling: a rare is drawn to a lair only while the lair's weighted load is under 8 per screen (a lair of the Deep's size takes three rares), and a lair is a preference, not a rule: the Deep has 32 rares and one lair — cost if wrong: a rare stands in an ordinary room
Task 3: Ruling: the pins about the hand-made rooms (lineage calibration, the shipped XP totals, deep, grotto and flooded) now read AreaWorlds.upto("DM"), the world without the placed creatures; F3 calibrates the world with them — cost if wrong: those pins describe a world nobody plays
Task 3: complete (commits 2f6011a..6b5483c, tests: tools/run_tests.sh test_placement_world → PASS: 10 tests)
Task 4: complete (docs, rendered the Deep's D2 and the Niche Gallery)
Final: panel REVISE x3 (executor, auditor, cartographer), pentester APPROVED; the full suite passed 3560/3560 before the fixes
Final: fixed auditor P2, a creature no room could hold only logged an engine error and the build still wrote the world — AreaModule.problems(), AreaBuilder.build_with(mods, dir, report) and build_areas.gd refuse to write and exit 1 with the id — test_a_creature_nothing_can_hold_is_a_problem_the_build_reports_and_the_world_still_builds RED→GREEN; checked by hand: a plan with an unplaceable creature exits 1
Final: fixed auditor P2, a creature on the generated floor could stand with its drawn body in a side wall (D3's Fenrir at x 65, 106 px wide) — surfaces are clipped to the faces of the side walls — test_no_creature_stands_with_its_drawn_body_in_a_side_wall, test_no_walking_creature_has_its_drawn_body_in_a_side_wall RED→GREEN; the rooms were rebuilt
Final: fixed executor, a hovering creature's x range ignored its width — the range is bounded by half its width plus the edge — test_a_flier_wider_than_the_air_beside_the_wall_still_hovers_inside_the_room
Final: fixed cartographer, the placement contract in docs/research/areas-f2.md still said slots by class and npc and rares only in a lair — rewritten to what is built
Final: suite 3564/3564 PASS (TEST_TIMEOUT=1700 tools/run_tests.sh)
