# SDD ledger — plan: docs/superpowers/plans/2026-10-04-soul-layer-4-opening.md

Spec: docs/superpowers/specs/2026-10-04-the-opening-design.md (reachable, read). Spec and plan reviewed by the debate panel (docs/ledgers/soul-layer-4-spec-review.md, soul-layer-4-plan-review.md).
Branch feat/soul-opening, worktree .worktrees/soul-opening, main merged in at e051e94 (main had moved to 048b688 with the movement agent's plans 4c and 5a; no overlap with the files this plan touches).

## Gate
Gate: Ruling: starting while the movement agent works on the biped's movement — this plan edits scripts/game.gd, run.gd, ui/goddess_menu.gd, soul/soul_progress.gd and data/audio/cues.json, none of which the movement agent touches (it said so on 2026-10-04 and will message before the reach-model plan) — cost if wrong: a hand-merge in one of those files when main is merged back.

## Pre-flight (shared interfaces)
- T1 -> T2: OpeningDef (choices, trucks, result_for) produced; OpeningModel consumes them. Match.
- T1 -> T5: OpeningValidator.validate(def) and data/opening/opening.tres produced; Game.load_opening consumes both. Match.
- T2 -> T4: OpeningModel (phase, prompt, rows, row, move, act, chosen, result_line, done) produced; OpeningScene consumes them. Match.
- T3 -> T5/T6: SoulProgress.opening_seen, begin_opening, finish_opening produced; Game._ready and Run._begin call them; T6 reads them. Match.
- T4 -> T5/T6: OpeningScene.play(def) -> bool, signal finished, is_playing, text_lines, row_texts produced; Game.start_opening consumes play and finished; T6 reads is_playing and the layer's visibility. Match.
- T5 -> T6: Game.launch_override, opening_flag_used, Run.open_first_meeting, GoddessMenu always-process produced; T6's flow tests set the override and read Run and the menu. Match.
- Existing code read and matching: Game._prepare_restart (unpauses), GoddessMenu.line_text, Run.DEATH_CARD_SECONDS, Game.skill_screen, NavStep.step/reset, AltarMenu key handling, Audio's UI-bus pause rule, the audio boundary tests.

## Tasks
Task 1: complete (commits e051e94..398bc40, tests: tools/run_tests.sh opening_validator → PASS: 5 tests)
Task 2: complete (commits 398bc40..85a432b, tests: tools/run_tests.sh opening_model → PASS: 7 tests)
Task 3: complete (commits 85a432b..b9c2746, tests: tools/run_tests.sh soul → PASS: 35 tests)
Task 4: complete (commits b9c2746..fcacabf, tests: tools/run_tests.sh opening_scene → PASS: 7 tests)
Task 5: complete (commits fcacabf..0723f88, tests: tools/run_tests.sh game_opening → PASS: 4 tests)
Task 6: full suite after the last commit: PASS 2224 tests (TEST_TIMEOUT=900 tools/run_tests.sh), 0 SCRIPT ERROR
Task 6: complete (commits 0723f88..d755e47, tests: tools/run_tests.sh opening_flow → PASS: 4 tests)

## Final review (debate changeset panel, 048b688..d755e47, code and the user-facing docs)
Final: review: debate:run changeset panel — executor, auditor, cartographer, pentester (executor-b, simplifier, antigravity and deepseek are not in the current config). The pentester approved; the other three said REVISE. The report stage kept 3 findings and refuted 3 (all of the executor's).
Final: fixed the four-choice menu ran off the 360 px screen (rows from y 306, the footer at 338) — row and footer layout constants, a cap of OpeningDef.MAX_CHOICES = 5 enforced by the validator, and the road moved up; test_the_choices_and_the_footer_fit_the_screen and test_more_choices_than_fit_the_screen_are_named RED (the new constants missing) → GREEN, suite 2227/2227
Final: fixed confirming early left the truck halfway down the road while the figure vanished — test_taking_a_choice_early_brings_the_truck_in RED (0.0 vs 1.0, shown by removing the fix) → GREEN, suite 2227/2227
Final: fixed docs/design-review/index.html line 45 still said the opening scene is not built — doc edit, no test can fail on prose; verified with a grep for the opening in the three docs
Final: Ruling: declined the executor's three P1s, each refuted by the report stage against the code — (1) "the opening is marked seen without playing": only Run._begin sets seen, after her menu is accepted; a refused or failed start leaves an explicit unseen that replays next launch, and a failed load is the spec's single failure policy; (2) "--opening does not replay": the reload after her menu lands in the game by design, once per process; (3) "the pending start is lost on reload": Run._begin sets pending_start on the persistent progress object before the restart, as every death does — cost if wrong: a first launch that skips the trucks or lands somewhere other than the Cave
Final: Ruling: added a cap of five choices to OpeningDef and the validator while fixing the overflow — the overflow came from a data-driven count the layout could not hold, so the cap makes the layout and the data agree — cost if wrong: a def with more than five choices is refused by the validator and the opening is skipped with a loud push_error
Final: minor (deferred): no test reloads the real scene after her menu; the opening and goddess flow tests replace _restart with a counter (a real reload would take the runner's scene with it), so the pending start surviving a real reload is covered only by the shared mechanism's reading
Final: Review Focus lines are each pinned by a test: a profile with progress never sees the truck and a brand-new one always does, even after a headless or skipped launch (test_a_profile_with_a_map_and_no_flag_counts_as_seen, test_a_migrated_profile_with_only_compendium_or_bestiary_progress_counts_as_seen, test_a_headless_first_launch_leaves_a_fresh_profile_unseen, test_a_skipped_first_launch_leaves_a_fresh_profile_unseen, test_wants_opening_follows_flags_and_the_saved_flag); it cannot start over a pause, in an editor Play or headless (test_it_refuses_when_paused_or_already_playing, test_start_opening_refuses_over_a_pause, test_start_opening_refuses_in_an_editor_play, the headless cases of wants_opening); quitting replays it, accepting ends it, a death afterwards is death 1 (test_begin_opening_saves_an_explicit_false_and_it_reloads_unseen_even_with_a_map, test_a_new_profile_plays_the_trucks_then_meets_her_and_begins_the_first_life); a malformed opening.tres is named and never pauses or saves (test_a_malformed_opening_is_refused_and_named, the validator tests); the hit is audible while paused (test_the_opening_hit_cue_is_on_the_ui_bus_and_not_positional)
Coordination: main moved to 34c8baf (the movement agent's plans 4d and 5a) while this branch was built; none of its files overlap this plan's, and the branch merges main before it lands.
