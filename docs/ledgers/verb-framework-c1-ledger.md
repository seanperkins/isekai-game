# Verb framework (C1): execution ledger

Plan: `docs/superpowers/plans/2026-10-05-verb-framework-c1.md`. Branch feat/verbs, merged to main locally. Final suite 2719 tests.

```
Spec: roadmap C1. Baseline 2680 (feat/verbs at main 5ca27b5).
Pre-flight: T1 Ability.spec/VerbKinds.run/VerbAbility consumed by T2 (more kinds) and T3 (skills with spec, Player). T2 VerbKinds.validate consumed by T3 DefValidator. No conflicts.
Task 1: complete (commits 96b766a..1fa46f8, tests: tools/run_tests.sh → PASS: 2688 tests)
Task 2: complete (commits 1fa46f8..20e46f1, tests: tools/run_tests.sh → PASS: 2697 tests)
Task 2: Ruling: Player.ward uses its own _ward timer, not _invuln — _invuln > INVULN_SECONDS-HURT_FLASH draws the hurt flash and evolving() holds _invuln, so a 2 s ward on _invuln would flash the whole time — cost if wrong: one extra float checked in receive_hit/receive_poison
Task 2: Ruling: buff modifiers live under one source id 'verb_buff' and are lost if SkillSet.refresh() runs mid-buff (it clears all modifiers) — a skill unlock during a 5 s buff ends it early; a generation meta stops an older timer from ending a recast buff — cost if wrong: a buff may end early on unlock
Task 2: Ruling: validate() requires buff stats, accepts every other kind with no keys (defaults) and also checks damage_type is non-empty text — cost if wrong: none
Task 3: Ruling: skill_screen_model needs no change — its Skills and Compendium rows are built per GROUPS source, and no group names form_verb — cost if wrong: a held verb is not listed on the Skills tab (it shows in the slots)
Task 3: Ruling: FormValidator.validate gains a 4th optional arg verb_ids (the form_verb skill ids), since it only ever saw skill ids; a form with a verb fails when the caller passes none — cost if wrong: later callers (C2 data) must pass the ids
Task 3: Ruling: form_verb skills may not carry levels_on, and nothing may skill_level-depend on one — an empty-unlock skill with levels_on would otherwise be evaluated and could be auto-granted — cost if wrong: none
Task 3: complete (commits 20e46f1..75bd805, tests: tools/run_tests.sh → PASS: 2711 tests)
Final review: debate panel (executor, auditor, cartographer, pentester; round 1 REVISE; pentester and cartographer re-run once after a model-at-capacity error and an acpx model-name mismatch). 4 survived (3 distinct), 3 refuted.
Final: fixed a verb buff ended by any skill refresh — test_a_timed_modifier_survives_clear_modifiers_and_ends_by_name and test_a_buff_survives_a_skill_refresh RED→GREEN (Stats gains a timed bucket), suite 2719/2719
Final: fixed an evicted form verb could not be put back — test_the_skills_tab_lists_the_form_verbs_the_player_can_equip and test_an_evicted_form_verb_stays_equippable_and_can_be_put_back RED→GREEN (Skills tab BODY group from ActiveSlots.owned), suite 2719/2719
Final: fixed a spec that is not a dictionary crashed validation — test_a_form_verb_whose_spec_is_not_a_dictionary_is_reported_not_crashed and test_active_spec_ignores_a_spec_that_is_not_a_dictionary RED→GREEN, suite 2719/2719
Final: Ruling: a form_verb that uses its own ability scene is validated without a spec — the roadmap says verbs no primitive fits are built by hand, and Player._ability runs any Ability scene — cost if wrong: a bespoke verb scene is not checked beyond the generic rules
Final: minor (deferred): a zone verb's damage is always poison (SporeCloudArea hardcodes it) and zone takes no damage_type — fix when the first non-poison zone verb (Flood, Guardian) is built in B3
Final: minor (deferred): FormValidator.validate callers in tests do not pass verb_ids — update the shared helpers when the first form carries a verb (B3)
```
