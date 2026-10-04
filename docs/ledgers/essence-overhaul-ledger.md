# Essence overhaul: execution ledger (2026-10-03)

Three plans run inline (executing-plans) on branch `feat/essence-overhaul`, cut from `docs/design-direction` at 6918700. Each section is that plan's ledger as written during the run. The whole-branch reviews were self-reviews: Sean's global instructions forbid a subagent verifying the author's own work.

```
# SDD ledger — plan: docs/superpowers/plans/2026-10-03-essence-overhaul-1-forms-by-powers.md
Workspace: .worktrees/essence-overhaul, branch feat/essence-overhaul cut from docs/design-direction (6918700). Executor: executing-plans (native, inline). Spec: docs/superpowers/specs/2026-10-03-essence-overhaul-design.md.
Baseline: tools/run_tests.sh on 6918700 → PASS: 1705 tests (about 8 min).
Pre-flight: Task 1 → Task 3: Task 1 adds FormDef.powers and build_forms.powers_of, Task 3 reads powers in FormOffers.lineage_powers and deletes FormDef.essences and build_forms.essences_of → compatible (Task 1 leaves essences in place).
Pre-flight: Task 2 → Task 3: Task 2 moves three editor tests off G1's kit affinity, Task 3 deletes the affinity block from G1/F1/D1 → compatible; Task 3 step 8 grep does not cover the bare word 'affinity', so run grep -rn affinity once after Task 3.
Task 1: complete (commits 6918700..fbfd259, tests: tools/run_tests.sh test_forms → PASS: 15 tests)
Task 2: complete (commits fbfd259..f850157, tests: tools/run_tests.sh test_room_editor → PASS: 107 tests)
Task 3: Ruling: docs/playtest-checklist.md:76 also claimed a kit grants 'seeded affinity' (the plan fixed only line 100) — removed that clause so the checklist matches the code — cost if wrong: one doc sentence
Task 3: complete (commits f850157..1056d0d, tests: tools/run_tests.sh → PASS: 1700 tests)
Final review: self-review, no subagent (Sean's global CLAUDE.md: never use a subagent to verify my own work; this overrides the skill's dispatch step). Checked Review Focus 1-5 against the tests that ran: (1) test_nothing_reached_offers_only_greater_slime; (2) test_a_power_that_evolved_away_still_opens_its_lineage; (3) test_a_real_engine_opens_a_lineage_when_a_power_is_granted_quietly; (4) NEW test_five_open_lineages_are_five_selectable_rows_none_dropped (commit 291df01; the plan named test_form_tab but its only edit there never asserted five offers; five rows end at y≈208, inside LIST_BOTTOM 320); (5) test_no_shipped_pool_carries_a_seeded_affinity plus a repo-wide grep for the retired names, clean.
Final: added test_five_open_lineages_are_five_selectable_rows_none_dropped — characterization test, passed on first run because Task 3 already made it true — suite 1700/1700 before it, test_form_tab 21/21 after
Final: minor (deferred): the Form tab stats column and hint text were not reviewed visually; only headless tests ran
Plan 1 complete: commits 6918700..291df01 on feat/essence-overhaul. Suite PASS: 1700 tests (+1 pin test, +2 in Task 1, -7 net in Task 3 from deleted supply/affinity tests).
```

```
# SDD ledger — plan: docs/superpowers/plans/2026-10-03-essence-overhaul-2-element-vocabulary.md
Workspace: .worktrees/essence-overhaul, branch feat/essence-overhaul, continuing from plan 1 (HEAD 291df01). Executor: executing-plans (native, inline). Spec: docs/superpowers/specs/2026-10-03-essence-overhaul-design.md.
Baseline: full suite after plan 1 → PASS: 1700 tests.
Pre-flight: Task 1 → Task 2: Task 1 produces TestDefs.satisfy(rules, id), Task 2 uses it in about 14 test files and the Hydraulic sweep → compatible.
Pre-flight: Task 2 → Task 3: Task 2 regenerates content (air/dark/etc.), Task 3's test_creature_hints and test_skill_screen read it; Task 2 step 4 notes test_skill_screen may fail on the Echolocation condition_text until Task 3 → ruling below: update that expected text in Task 2 so Task 2 stays green.
Pre-flight: Task 2 → Task 4: Task 2 sets the thresholds, Task 4 pins the resulting unlock points (CAVE_START_BEFORE, SPORE_CLOUD_NOW, levels 1,4,5,5) → compatible provided the generated data reproduces the numbers; Task 4 step 4 is the check and says how to adjust.
Pre-flight: Task 3 → Task 4: both edit tests/test_content.gd and test_skill_screen.gd? No: Task 3 edits test_skill_screen, test_def_validator, creates test_creature_hints; Task 4 edits test_content only → no overlap.
Task 1: complete (commits 291df01..8685c85, tests: tools/run_tests.sh test_defs → PASS: 8 tests)
Task 2: Ruling: tests/test_skill_screen.gd:252 pins Jolt's condition_text as 'Absorb shock essence ×4' and the plan did not list it; Jolt becomes a two-condition mix, so I set it to 'Absorb light essence ×4 and Absorb air essence ×4' (condition_text joins with ' and ') — and updated the Echolocation line to 'Absorb air essence ×6' now rather than in Task 3, so Task 2 stays green — cost if wrong: two expected strings
Task 2: Ruling: four test pins the plan did not list went stale with the new numbers: test_skill_screen tremor condition_text x24 -> x59; test_skill_caps TABLE echolocation curve 3 -> 9; test_player bat 'Essences: sound 1, flight 1' -> 'Essences: air 2'; test_status_text toad fixture {poison,water} -> {water,dark} and 'Essences: water 1, dark 1' (StatusText filters by Essences.ALL, so the plan's 'opaque fixture' claim does not hold there) — updated each to the spec's numbers — cost if wrong: four expected values
Task 2: complete (commits 8685c85..d3a2778, tests: tools/run_tests.sh → PASS: 1702 tests)
Task 3: complete (commits d3a2778..79d5f2a, tests: tools/run_tests.sh test_creature_hints → PASS: 6 tests)
Task 4: Ruling: this repo tracks a .uid for every .gd (402 tracked), and Godot generated tests/test_creature_hints.gd.uid (Task 3) and tools/calibrate_essences.gd.uid; the plan listed only calibration_walk.gd.uid — committed both extra uids with Task 4 — cost if wrong: two small files
Task 4: complete (commits 79d5f2a..8be6123, tests: tools/run_tests.sh → PASS: 1713 tests)
Final review: self-review, no subagent (Sean's global CLAUDE.md forbids a subagent verifying my own work). Review Focus: (1) self status prints 'Essences: none' (existing code); (2) test_an_unknown_source_in_an_unlock_is_rejected and test_an_unknown_element_in_an_unlock_is_rejected; (3) test_a_bat_names_echolocation_but_not_the_mixes_it_only_half_carries; (4) test_every_power_is_reachable_from_every_start_by_some_walk; (5) NEW test_only_black_spiders_count_toward_sticky_thread (the plan pinned the unlock's source dict but never that a Taratect or vine snake counts for nothing).
Final: added test_only_black_spiders_count_toward_sticky_thread — characterization test, passed first run — test_content 9/9
Final: minor (deferred): StatusText.creature_lines prints a bare 'Essences: ' for a creature carrying no elements; only the unappraisable Cave Serpent has none today
Final: minor (deferred): the Hydraulic sweep replaced 21 sites where the plan estimated about 22; no remaining four-water feeders were found by grep, but a test that feeds water by another shape (a loop of 5, a helper) was not searched exhaustively
Plan 2 complete: commits 291df01..HEAD on feat/essence-overhaul. Suite PASS: 1713 tests before the pin test, 1714 after.
```

```
# SDD ledger — plan: docs/superpowers/plans/2026-10-03-essence-overhaul-3-price-held-ep.md
Workspace: .worktrees/essence-overhaul, branch feat/essence-overhaul, continuing from plan 2 (HEAD 6857414). Executor: executing-plans (native, inline). Spec: docs/superpowers/specs/2026-10-03-essence-overhaul-design.md.
Baseline: full suite after plan 2 → PASS: 1713 tests, plus the Sticky Thread pin = 1714 expected.
Pre-flight: Task 1 → Task 2: Task 1 produces Ledger.size, SkillDef.evolution_price, SkillRulesEngine.ESSENCE_SPENT/held/evolution_price/can_afford; Task 2 evolve() and the Skills screen consume them with the same names → compatible.
Pre-flight: Task 1 → Task 3: Task 3's HUD consumes can_afford, ready_evolutions (exists at skill_rules_engine.gd:126), get_def(id).replaces → compatible.
Pre-flight: Task 2 → Task 3: both edit hud.gd (level_text vs evolve_text) and skill_screen.gd _build_stats (EP label vs essence loop) → different lines, sequential → compatible.
Pre-flight: Task 1 validator rule (a base power with evolutions needs a price) → existing tests that validate hand-built evolution defs may fail; found at Task 1 step 4 if so.
Task 1: Ruling: tests/test_def_validator.gd _with_parent fixture builds a parent with evolutions and no price, which the new price rule rejects (test_a_well_formed_pair_of_evolutions_is_valid failed); gave that fixture parent evolution_price {water: 3} — the plan did not list this fixture — cost if wrong: one fixture line
Task 1: complete (commits 6857414..0238bf0, tests: tools/run_tests.sh test_evolution_price → PASS: 5 tests)
Task 1: note: my first commit chain failed on a missing .uid (git add error) yet task-done still logged a completion line for a non-existent commit; I removed that false line by hand, generated the .uid with godot --import, committed (0238bf0) and re-ran task-done. From here every commit chain stops on failure.
Task 2: Ruling: the plan's 'var can := _rules.can_afford(id)' in skill_screen.gd is a parse error (_rules is untyped there, so := cannot infer); wrote 'var can: bool = _rules.can_afford(id)' — cost if wrong: none, same behavior
Task 2: complete (commits 0238bf0..f46f9d2, tests: tools/run_tests.sh → PASS: 1727 tests)
Task 3: complete (commits f46f9d2..53d656f, tests: tools/run_tests.sh → PASS: 1735 tests)
Final review: self-review, no subagent (Sean's global CLAUDE.md forbids a subagent verifying my own work). Review Focus: (1) test_can_afford_does_not_survive_a_new_life_at_the_same_ledger_size, mutation-checked: with the memo clear removed from reset_run() it fails, with it restored it passes; (2) test_evolve_refuses_when_the_price_is_not_held_and_spends_nothing, test_a_short_press_never_evolves_and_the_card_says_what_is_short, test_a_ready_but_unaffordable_evolution_has_no_line_until_it_can_be_paid; (3) test_one_line_per_ready_parent_not_one_per_branch, test_taking_one_branch_pays_once_and_closes_the_other; (4) test_evolution_branches builds unpriced defs and is green in the full suite; (5) the three validator tests in test_def_validator plus test_the_four_parents_carry_a_price_and_nothing_else_does.
Final: minor (deferred): the two-line HUD state ('Your body can evolve' above 'Evolve: <power>') was not seen in a real render; evolution_shots.gd only shows the body line. Line 2 is about 47 characters, wide enough to touch the announcer popup's left edge while a popup is showing
Final: minor (deferred): tools/evolution_shots.gd logs a Geometry2D decompose_many_polygons_in_convex error from slime_shapes.gd:37 under the windowed renderer; unrelated to this work, not investigated
Final: Ruling: docs/playtest-checklist.md lines 27, 28, 73, 76, 79 described EP, 'up to three forms by what you ate', and eating spore and shell; none of the three plans listed them — updated them to the final behavior in one docs commit after Task 3 — cost if wrong: manual-QA wording only
Plan 3 complete: commits 6857414..53d656f on feat/essence-overhaul. Suite PASS: 1735 tests.
```
