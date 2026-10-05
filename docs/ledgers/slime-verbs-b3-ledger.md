# The slime's form-four verbs (B3): execution ledger

Plan: `docs/superpowers/plans/2026-10-05-slime-verbs-b3.md`. Branch feat/slime-verbs, merged to main locally. Final suite 2776 tests; Python tests in tools/ pass.

```
Spec: design doc section 8 plus C1. Baseline 2719 (main feb6230).
Pre-flight: T1 produces cooldown/root/rows table consumed by T2-T4 rows. T2 VerbField/zone damage_type consumed by T3 none. T3 Player.glide independent. T4 Stats.set_timed_modifiers (C1 fix) consumed by copy. No conflicts.
Task 1: Ruling: test_content counts the authored skills (32) and leaves out form_verb skills, which are generated and counted in test_slime_verbs — a hard 32 would need a bump per verb — cost if wrong: none
Task 1: Ruling: the validator's status message is now 'slow, stun or root seconds' and the Gleipnir grants pin in the Python test lists its verb — both encode the new capability — cost if wrong: none
Task 1: Ruling: form_verb skills are left out of the skill-tree node count, the audio test's per-id cue rule (they play the default skill cue) and the autoload's authored-skill count; every verb gets a code-drawn placeholder icon (tools/art/verb_icons.py) because test_every_player_skill_has_an_icon requires one — cost if wrong: verbs share one sound and plain icons until audio and art are authored
Task 1: complete (commits 0134523..7f5948c, tests: tools/run_tests.sh → PASS: 2732 tests)
Task 2: Ruling: a zone verb takes damage_type (default poison, which every existing cloud keeps) — this closes the deferred minor from the C1 review, since Flood and Guardian need non-poison zones — cost if wrong: none
Task 2: Ruling: Engulf stuns and digests the enemy in place (a field that follows it) rather than drawing it into the body; Guardian has no weak-point nail; Flood/Network slow instead of adding water/route display — all recorded as fidelity approx in tools/form_verbs.json — cost if wrong: the verbs look simpler than the design text
Task 2: complete (commits 7f5948c..7faae2b, tests: tools/run_tests.sh → PASS: 2748 tests)
Task 3: Ruling: recall and other timers that must follow the game clock use Engine.get_physics_frames, because the test runner uses --fixed-fps and the wall clock does not advance with it — cost if wrong: none
Task 3: Ruling: Court's allies are in group verb_allies and not actors, so foes never see them and they cannot be hurt; Shed leaves a husk but enemies are not drawn to it; Stalk's steps appear at once — all fidelity approx in the table — cost if wrong: the design text promises more than these do
Task 3: complete (commits 7faae2b..f680a70, tests: tools/run_tests.sh → PASS: 2762 tests)
Task 4: Ruling: Transmute moves essence among the five first-pass elements only (never fire, mind or blood) and announces the gain as ABSORBED with source 'transmute' — it therefore counts toward absorbed-this-life thresholds, which only matter at stage 2 — cost if wrong: transmuted essence could count toward a later lineage gate
Task 4: Ruling: the 17-verb test gives every verb a fresh Player, because a glide or buff left by one verb changes the next snapshot and hid broken dispatches (found by mutation) — cost if wrong: none
Task 4: complete (commits f680a70..0de20f4, tests: tools/run_tests.sh → PASS: 2773 tests)
Final review: debate panel (executor, auditor, cartographer, pentester; round 1 REVISE). 6 survived, 1 refuted.
Final: fixed a stunned enemy stayed edible while rooted — test_a_stunned_enemy_that_is_rooted_cannot_be_eaten_until_the_root_ends RED→GREEN (re-graded Important: the plan's Review Focus names it)
Final: fixed Recall teleported to a room that was gone — test_a_recall_mark_does_not_follow_the_caster_into_another_room RED→GREEN (the mark carries its room)
Final: fixed Court allies froze under a foe at another height — test_allies_reach_a_foe_at_another_height RED→GREEN (they float to it)
Final: fixed two Python pins failed after Ariadne gained a verb — tools/test_build_species_forms.py updated, python tests 4 files OK (found because the GUT suite does not run Python tests; run them with the generators)
Final: Ruling: verb effects (fields, allies, vines, zones) stay parented to the caster's parent, like Spore Cloud, Miasma and the other clouds, and end on their own clock — the reviewer wanted them tied to the room; the verifier found it the existing convention with no wrong state (the worst case is a timed platform left in a freed room's coordinates) — cost if wrong: a vine can outlast the room it was grown in by up to its ten seconds
Final: minor (deferred): SporeCloudArea's class comment still says its damage is poison; it now takes a damage_type that defaults to poison
```
