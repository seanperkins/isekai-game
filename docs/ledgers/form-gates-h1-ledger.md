# SDD ledger — plan: docs/superpowers/plans/2026-10-05-form-gates-h1.md
Baseline 2960 (main 1ecdba9).
Pre-flight: T1 vocabulary and FormGate -> T2 and T3 emit the events (consume T1) -> T4 gate data (consumes T1 to T3's vocabulary and Deeds.RESERVED) -> T5 offers and cards (consume FormGate and the data). T2 and T3 both touch enemy.gd (T2: last_blow in receive_hit/receive_tackle; T3: the weak-point branch of receive_tackle): T3 reads T2's code before editing. No other conflicts.
Plan not panel-reviewed: the branch review at the end covers it.
Task 1: Ruling: the deed events live in `Deeds` (Deeds.EVENTS, Deeds.known), not in Events.ALL — two tests pin that list and every entry needs an audio-catalog cue; the rules engine's unknown-event warning and the DefValidator ask Deeds.known so a skill could count a deed too — cost if wrong: two places to look for event names
Task 1: Ruling: SkillRulesEngine._current is now the public condition_value and answers `held` too; _current stays as a one-line alias — cost if wrong: none
Task 1: complete (commits c0c3d72..fd6fe4a, tests: tools/run_tests.sh test_form_gate → PASS: 26 tests)
Task 2: Ruling: "marked" is a kill on an enemy the mark verb is aiming at or the player has appraised — the design's marked kill (Black Shuck, whose own verb is the mark) has no earlier mark verb to count, so appraising counts — cost if wrong: Black Shuck is easier to open than its text suggests
Task 2: Ruling: "fleeing" is moving away from the player faster than 20 px/s at the blow; "dark" is an area in DeedTags.DARK_AREAS (deep, swamp, cemetery, crypt, demon); "ceiling" is hanging from one or having left one within 1.2 s (a silk drop onto prey) — cost if wrong: thresholds to tune in F3
Task 2: complete (commits fd6fe4a..3da2551, tests: tools/run_tests.sh test_defeated → PASS: 15 tests)
Task 3: Ruling: barrier_broken and hidden_found are emitted by the dissolve and reveal verbs but no room has a dissolvable or hidden node yet, so both are in Deeds.RESERVED for F2 (the rooms) — a form that needs one stays shut until then — cost if wrong: Fenrir and Wepwawet cannot be earned in the shipped world until F2
Task 3: Ruling: a dissolve verb does not count as a hit or a miss (it is a door-opener as much as a strike) — cost if wrong: a perfect-hit streak ignores dissolves
Task 3: Ruling: the first room of a run is announced again after SkillRules.start_run (the enter_start ran before the ledger was cleared); room_cleared fires once per room visit and is alone when no verb ally is out — cost if wrong: re-entering a room whose enemies respawned can clear it again
Task 3: complete (commits 3da2551..5f1fe93, tests: tools/run_tests.sh test_deeds_world → PASS: 16 tests)
Task 4: the gate atoms that wait on a later piece (counted from the data): E2 27, E1 19, F2 9. Deeds.RESERVED lists them; test_form_gates_data fails if a reserved entry is unused or a used, unemitted deed is not reserved.
Task 4: Ruling: where the design text names a power no skill has (Howl, Web Shot, Ground Web, Brood Sac, Venom Fang, a summon, a rally, the wail), the gate counts uses of the parent's verb (skill_used) or the deed it stands for; each row's `note` says which — cost if wrong: those forms open on a stand-in until the powers are designed
Task 4: Ruling: `avenged` is a real deed: SoulProgress.last_death_cause is saved with the soul section (a new key; older saves load none) and the game gives it to the player at each life's start — cost if wrong: a profile that dies to a damage type (poison) has nothing to avenge
Task 4: Ruling: essence totals by stage are 26, 34 and 44, split over the form's reads (the slime offers at 24 to 26); F3 recalibrates — cost if wrong: late forms are too easy or too hard to open
Task 4: added the deeds `village_visited_unseen` and `prey_freed` (both reserved), the `element` tag on lesson_learned and `avenged` on defeated
Task 4: complete (commits 5f1fe93..1643495, tests: tools/run_tests.sh test_form_gates_data → PASS: 6 tests)
Task 5: Ruling: the Tree tab still names every stage-2 form of another species (the plan's "name it once its gate has progress" is dropped: the card carries the progress, and a hidden form would hide what to work towards) — cost if wrong: the Tree shows forms the player has not earned a look at
Task 5: no existing test assumed every stage-2 form of another species was on offer, so none needed updating
Task 5: complete (commits 1643495..e4d5d4a, tests: tools/run_tests.sh test_form_offers_gates → PASS: 9 tests)
Final review: debate panel (executor, auditor, cartographer, pentester; round 1 REVISE; pentester approved). 4 raw, 3 survived, 1 refuted.
Final: fixed eating the room's last enemy alive never cleared the room (consume() sets GONE without `downed`) — the game also checks on the enemy's tree_exiting; test_eating_the_last_enemy_alive_clears_the_room RED→GREEN, suite 3043 less the fixed twin-predation expectation
Final: fixed "kills in a row" gates counted interrupted runs (Nightstalker, Plaguemother, Redcap) and a streak that reset after it was reached would have closed a form again — a new `streak` kind reads the best unbroken run this life (a kill of another kind or the reset event ends a run); Ledger.best_streak, test_best_streak_*, test_a_streak_of_a_kind_of_kill_is_broken_by_a_kill_of_another_kind, test_a_streak_that_was_reached_stays_reached_after_a_later_hit RED→GREEN; `reset_counter` is no longer a gate kind
Final: fixed the soul design spec still listed {"points","perks","deaths"} — it names opening_seen and last_death_cause now (docs)
Final: fixed (mine, found by the full suite) test_twin_predation expected eaten twins to carry no species
Final: refuted by the verifier: a late defeat clearing the wrong room (a room change always builds fresh enemies, so a stray defeat finds threats; the real room change keeps the old room frozen)
Final: all fixes mutation-checked; Python tests (9 files) OK
