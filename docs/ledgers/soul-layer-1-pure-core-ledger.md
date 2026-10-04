# SDD ledger — plan: docs/superpowers/plans/2026-10-04-soul-layer-1-pure-core.md

Spec: docs/superpowers/specs/2026-10-04-soul-layer-design.md (reachable, read).
Branch feat/soul-core, worktree .worktrees/soul-core, cut from docs/soul-layer-spec 569e9ab.

## Pre-flight (shared interfaces)
- T1 -> T4: spend_essence(element, units) -> bool produced; Banking.bank consumes it. Match.
- T2 -> T3: PerkDef.price_of(times) produced; SoulProgress.buy_perk consumes it. Match.
- T2 -> T4/T6/T8: SoulRules fields (bank_rate, level_prices, power_price, many_deaths) read by Banking, HeadStart, GoddessModel. Match.
- T3 -> T4/T5/T8: SoulProgress.add / perk_count / total_points consumed. Match.
- T6 -> T8: HeadStart.price/kit/cheapest consumed by GoddessModel. Match.
- T2/T7 -> T9: SpeciesDef, PerkDef, SoulRules, GoddessLines fields read by SoulValidator. Match.
- T3 -> T9: Compendium builds SoulProgress from DefLoader.load_dir("res://data/perks","PerkDef"); the dir only exists after T9. DefLoader returns [] for a missing dir, so no perks are known until T9. No conflict.

## Tasks
Task 1: complete (commits 569e9ab..62d5082, tests: tools/run_tests.sh spend_essence → PASS: 4 tests)
Task 2: Ruling: added two tests the brief did not list (SpeciesCatalog.load_all keyed by id and empty for a missing dir; a count rule with no n never opens) — the iron law forbids untested production code, and a missing n must not read as trivially met — cost if wrong: two extra tests
Task 2: complete (commits 62d5082..e46dd75, tests: tools/run_tests.sh species_unlocks → PASS: 7 tests)
Task 3: complete (commits e46dd75..2043d03, tests: tools/run_tests.sh soul_progress → PASS: 8 tests)
Task 4: complete (commits 2043d03..fae9fe2, tests: tools/run_tests.sh banking → PASS: 5 tests)
Task 5: complete (commits fae9fe2..5a56c3e, tests: tools/run_tests.sh soul_perks → PASS: 3 tests)
Task 6: complete (commits 5a56c3e..b6edfc9, tests: tools/run_tests.sh head_start → PASS: 5 tests)
Task 7: complete (commits b6edfc9..aecd89b, tests: tools/run_tests.sh goddess_lines → PASS: 4 tests)
Task 8: Ruling: the enum is GoddessModel.Pane, not Panel as the brief names it — Panel is a Godot control class and GoddessModel.Panel failed to resolve (Parse Error: Could not resolve external class member) — cost if wrong: plan 2's menu must say Pane (plan text updated)
Task 8: complete (commits aecd89b..d61cf61, tests: tools/run_tests.sh goddess_model → PASS: 10 tests)
Task 9: full suite after the last commit: PASS 1943 tests (tools/run_tests.sh, TEST_TIMEOUT=900)
Task 9: complete (commits d61cf61..7fa33c3, tests: tools/run_tests.sh soul_ → PASS: 20 tests)

## Final review (debate panel, whole branch 569e9ab..7fa33c3)
Final: review: debate:run changeset panel — executor, auditor, cartographer, pentester, antigravity. executor-b, simplifier and deepseek are not configured on this machine. The repo reads as private and the registry lacks route 31501, so the ZDR guard was lifted once with Sean's OK. cartographer's configured model gpt-6-luna is not offered through acpx (it failed); it was re-run with the executor seat's assignment and delivered APPROVED. Verdicts: executor REVISE, antigravity REVISE, auditor, pentester and cartographer APPROVED.
Final: fixed SoulProgress dropped unknown perk ids on load and re-saved the trimmed section — test_a_perk_the_data_does_not_hold_stays_in_the_file RED→GREEN, suite 1945/1945
Final: fixed SoulValidator crashed on a non-dictionary perk effect — test_a_malformed_effect_is_reported_not_crashed RED→GREEN, suite 1945/1945
Final: minor (deferred): SoulProgress.buy_perk returns true even if Profile.save() fails, because _save ignores its result (WorldProgress._save does the same and Profile already warns)
Final: Ruling: declined antigravity's "SoulPerks should not refresh stats and fill vitals; add a Finalize phase" — the spec fixes the order (kit, then perks, each refreshing) and the panel verifier agreed — cost if wrong: plan 2 may later fold the refreshes into one step
Final: Ruling: declined antigravity's "SoulProgress does not belong on the Compendium autoload" — the spec records it beside WorldProgress, which already holds cross-run progress there — cost if wrong: a later rename or move of one member
Final: Ruling: refined the spec's "unknown perk ids are dropped" to "not counted, kept in the saved section" — a perk dir that fails to load would otherwise erase purchases on the next save — cost if wrong: ids of perks removed for good stay in the save file
Final: Review Focus lines are each pinned by a test in tasks 2, 3, 4 and 7 (all in the 1945-test suite)
