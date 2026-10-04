# SDD ledger — plan: docs/superpowers/plans/2026-10-04-soul-layer-2-scene-and-death-flow.md

Spec: docs/superpowers/specs/2026-10-04-soul-layer-design.md (reachable, read).
Branch feat/soul-scene, worktree .worktrees/soul-scene, cut from main c65b202; plan reviewed by the debate panel (docs/ledgers/soul-layer-2-plan-review.md).

## Pre-flight (shared interfaces)
- T1 -> T4: NavStep.step(stick, delta) and reset() produced; GoddessMenu consumes both. Match.
- T2 -> T5: Player.last_hit_cause produced; Run reads it with player.get("last_hit_cause"). Match.
- T3 -> T5: Goddess (load_default, line_for_death, model, soul, perks) produced; Run and Game consume it. Match.
- T4 -> T5: GoddessMenu.open(model, line) and confirmed(result) produced; Game connects run.goddess_needed (model, line) to open and confirmed to run.accept. Arity matches.
- T5 -> T6: Game.goddess_menu, assignable Run.goddess, resolve_start, begin_life produced; the end-to-end test consumes them. Match.
- Plan 1 on main (read, matches): GoddessModel.new(places, species, powers, soul, rules, last), the Pane enum (not Panel), SpeciesCatalog.unlocked(catalog, records), HeadStart.eligible_powers(compendium, skill_defs), SoulPerks.apply(player, soul, perks).

## Tasks
Task 1: complete (commits 6d88ac7..3647ef0, tests: tools/run_tests.sh nav_step → PASS: 3 tests)
Task 2: complete (commits 3647ef0..4b138c9, tests: tools/run_tests.sh player_death_cause → PASS: 7 tests)
Task 3: complete (commits 4b138c9..d29790c, tests: tools/run_tests.sh test_goddess.gd → PASS: 6 tests)
Task 4: complete (commits d29790c..a2d281b, tests: tools/run_tests.sh goddess_menu → PASS: 9 tests)
Task 5: complete (commits a2d281b..01b63be, tests: tools/run_tests.sh rebirth_flow → PASS: 21 tests)
Task 6: full suite after the last commit: PASS 1974 tests (tools/run_tests.sh, TEST_TIMEOUT=900). Note: an earlier full run was SIGTERM'd by the movement agent's pkill, not a failure.
Task 6: complete (commits 01b63be..996f508, tests: tools/run_tests.sh goddess_flow → PASS: 1 tests)

## Final review (debate changeset panel, c65b202..996f508, code only)
Final: review: debate:run changeset panel — executor, auditor, cartographer. executor-b, simplifier, antigravity and deepseek are not in the current config; pentester was skipped by the classifier (no security signal). All three said REVISE; the report stage kept 3 findings (two are the same menu overflow) and refuted 2.
Final: fixed the goddess menu's head start list ran off screen with 19 rows (a profile owning all 18 powers) — test_a_long_head_start_list_scrolls_to_keep_the_selected_row_visible RED→GREEN, suite 1975/1975
Final: fixed stale docs that described the removed pool menu and kits (docs/playtest-checklist.md lines 76 and 80, docs/rooms.md line 97, docs/design-review/index.html line 101 linked the deleted reincarnation_menu.gd) — doc edits, no test; suite 1975/1975
Final: Ruling: declined "Game.begin_life must apply start[species] to the body" — the spec leaves applying a species to the movement agent's wiring plan and only slime exists, so no choice can change the body — cost if wrong: a second species would not change the body until that plan lands
Final: minor (deferred): tests/test_rebirth_kit.gd's pacing test still reads the shipped pool kits, which the runtime now ignores; plan 3 Task 6 replaces it with a largest-head-start balance test
Final: Review Focus lines are each pinned by a test: no goddess or listener still restarts (test_with_no_menu_listening_the_default_is_taken, test_without_a_goddess_the_last_attuned_choice_is_taken); a forged, negative or stale result is ignored (test_accept_ignores_a_result_the_pending_model_did_not_produce); stick once per push and joypad motion handled (test_the_stick_steps_once_per_push, test_a_stick_push_navigates_through_process_and_the_event_alone_moves_nothing); cause set before died and not overwritten (test_the_cause_is_set_before_died_fires, test_a_hit_blocked_by_invulnerability_keeps_the_earlier_cause); one death counted (test_the_card_shows_her_line_for_the_cause_and_counts_one_death)
Coordination: the movement agent (session isekai-game-da) had pkill'd Godot and killed one of my full-suite runs; it told me, and I stopped overlapping suites. main moved to c8f63c7 (its slime-wall merge) while this branch was in review, so this branch merges main before it lands.
