# SDD ledger — plan: docs/superpowers/plans/2026-10-05-review-aids.md
Baseline 2865 (main af1ee1a).
Pre-flight: T1 Player.become_form/Game.form_arg and T2 form_card are independent. No conflicts.
Task 1: Ruling: become_form follows each form's first parent, since every generated form has one — cost if wrong: a form with two parents would be reached by its first line only
Task 2: Ruling: the Tree card lists the verb, what it gives up and how it is opened before the stats — the card clips past about twelve lines and these are what a reviewer wants first — cost if wrong: the stats of a form with many lines can be pushed off the card
Task 1: complete (commits f0929ba..259a20d, tests: tools/run_tests.sh → PASS: 2875 tests)
Task 2: complete (commits f0929ba..259a20d; covered by Task 1's full-suite run: 2875 tests)
Final review: debate panel (executor, auditor; round 1 REVISE). The two seats agreed on the Form tab; the auditor added two more.
Final: fixed `--species=wolf --form=weaver` stayed a wolf (set_species("slime") is a no-op, so advance_form refused Weaver and the game ignored it) — a form flag now decides the species in Game._ready; test_a_form_flag_wins_over_the_species_flag, test_a_form_flag_wins_over_the_goddess_pick RED→GREEN, suite 2881/2881
Final: fixed the debug chain saved every form it walked as reached (form_advanced → reach_form → _save) — become_form is silent (no form_advanced, no evolved_body); test_the_debug_start_does_not_record_the_forms_as_reached, test_the_game_does_not_save_the_forced_line_as_reached RED→GREEN, suite 2881/2881
Final: fixed the Form tab showed neither the verb nor what a form gives up — it now draws "Verb: …" and "Gives up: …" under the grants; test_the_form_tab_card_shows_the_verb_and_what_it_gives_up and test_the_form_tab_card_of_a_form_with_no_verb_has_neither_line RED→GREEN, suite 2881/2881
Final: Ruling: a form named by --form overrides --species and the goddess's pick — a form belongs to one species, so the two flags cannot disagree — cost if wrong: a wolf started with --species=wolf --form=weaver is a slime
Final: Ruling: the test suite's profile lives in .tmp/gdhome and outlives a run, so test_the_game_does_not_save_the_forced_line_as_reached clears forms_reached first — a stale save from the pre-fix RED runs had made it fail on a correct build — cost if wrong: none
Final: all three fixes mutation-checked (each mutant failed its test); Python tests (5 files) OK
