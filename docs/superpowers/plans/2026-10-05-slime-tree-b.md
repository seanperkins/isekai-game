# The slime's lineage gates and tree rebuild (B1, B2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The slime's stage-2 menu follows what it has absorbed (a reveal threshold shows a lineage in the Tree tab, a higher offer threshold puts it on the menu, each owned power helping a little), every Sovereign has one stage-3 parent, the slime has its 18 new stage-4 forms as data, and the Tree tab lays out several stage-4 forms per lineage without overlap.

**Architecture:** `FormDef` gains `reveal` and `offer` (element to amount), set on the five lineage forms. `FormOffers` reads them against `SkillRulesEngine.absorbed`; each owned lineage power counts as +3 of every element the lineage needs. The 18 new forms come from the same generator as A3 (extended), inheriting their stage-3 parent's traits, grants and tint. `SkillTreeModel._form_slots` places stage 4 first (one row each), then stage 3 and stage 2 at the mean of their children.

**Tech Stack:** Godot 4.7 GDScript and GUT; Python 3 for the generator.

**Spec:** `docs/research/species-form-branches.md` (section 8: the slime's 42 forms, the reveal and offer tables, the diet simulation) and `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md` (B1, B2).

## Global Constraints

- Baseline 2652 tests on `main` (`test_water_stream` is timing-flaky under load and passes alone).
- Reveal and offer numbers, verbatim from the design doc: Echo air 10 / 34; Tide water 16 / 26; Toxic water 10 and dark 8 / water 20 and dark 14; Bulwark earth 30 / 56; Weaver dark 24 / 26. Greater Slime has none. `POWER_BONUS = 3` per owned lineage power, applied to every element of the lineage's thresholds.
- The Greater Slime fallback is offered when fewer than two lineages are offered. No cap and no ranking.
- A Sovereign keeps one parent: `silkbound` under `snare`, `tidal` under `brook`, `venom` under `acid`, `stone` under `golem`, `storm` under `sky`, `prime` under `vast`. No branch rejoins.
- The 18 new form ids are the slug of the name with no prefix (`gleipnir`, `ariadne`, `beanstalk`, `selkie`, `kraken`, `tiamat`, `alkahest`, `pestilence`, `slime_mold`, `talos`, `philosophers_stone`, `cube`, `mimic`, `poltergeist`, `cloud_rider`, `shoggoth`, `king_slime`, `quicksilver_slime`). Their parents are the doc's: Snare: gleipnir; Arachne: ariadne, beanstalk; Brook: selkie; Tempest: kraken, tiamat; Acid: alkahest; Blight: pestilence, slime_mold; Golem: talos; Crystal: philosophers_stone, cube; Phantom: mimic, poltergeist; Sky: cloud_rider; Vast: shoggoth; Radiant: king_slime, quicksilver_slime.
- A new form grants and carries the traits of its stage-3 parent, wears its tint plus 0.05 per channel, and has no verb yet.

## Review Focus

- A fresh life (nothing absorbed): no lineage revealed, only Greater Slime offered. (Task 2)
- Owning every power of Bulwark (+9) with no earth absorbed reveals nothing: powers help, never gate alone. (Task 2)
- An evolved power (Poison Breath retired into Miasma) still counts as owned for its lineage. (Task 2)
- A lineage form missing its reveal or offer, or an offer below its reveal, fails the validator. (Task 1)
- The Tree tab for a slime with every form reached has no two form nodes overlapping, and neither does a wolf's. (Task 5)

---

### Task 1: `reveal` and `offer` on `FormDef`

**Files:**
- Modify: `scripts/forms/form_def.gd`, `scripts/forms/form_validator.gd`
- Test: `tests/test_form_gates.gd` (new)

**Interfaces:**
- Produces: `FormDef.reveal: Dictionary`, `FormDef.offer: Dictionary` (element id to positive int; default `{}`).
- Validator messages (exact): `"%s: a lineage form needs a reveal and an offer"` (a slime stage-2 form other than `greater`), `"%s: only a stage-2 lineage form carries a reveal and an offer"`, `"%s: reveal names unknown essence '%s'"`, `"%s: offer names unknown essence '%s'"`, `"%s: %s of '%s' must be positive"` (kind `reveal` or `offer`), `"%s: offer must name the same elements as its reveal"`, `"%s: offer of '%s' is below its reveal"`.

- [ ] **Step 1: Write failing tests** in `tests/test_form_gates.gd`: `test_the_fields_default_to_empty`; one test per message with a small fixture (a slime stage-2 form `x`, lineage `weaver`, `powers = ["sticky_thread"]`) asserting `Array(errors)` equals the single message; `test_a_valid_gate_passes` (`reveal {"dark": 24}`, `offer {"dark": 26}`); `test_greater_slime_has_no_gate` (the fixture with lineage `greater` and a reveal fails with the "only a stage-2 lineage form" message).
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_gates`. Expected: FAIL.
- [ ] **Step 3: Implement** the fields and rules. The existing slime data will fail "needs a reveal and an offer" until Task 2 adds it, so make that single rule apply only when `FormDef.reveal` or `offer` is non-empty OR in Task 2's commit: gate the missing-gate rule behind a `const REQUIRE_GATES := true` set in Task 2 (ledger the ruling).
- [ ] **Step 4: Run** `tools/run_tests.sh test_form`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: a lineage form carries a reveal and an offer threshold"`.

### Task 2: `FormOffers` follows what was absorbed

**Files:**
- Modify: `scripts/forms/form_offers.gd`, `data/forms/{weaver,tide,toxic,bulwark,echo}.tres`, `scripts/forms/form_validator.gd`
- Test: `tests/test_form_offers.gd` (rewritten), `tests/test_form_gates.gd`

**Interfaces:**
- Consumes: `SkillRulesEngine.absorbed(element)`, `level_of(power)`.
- Produces: `const POWER_BONUS := 3`; `static func revealed_lineages(forms, rules) -> Array` (in `LINEAGE_ORDER`), `static func offered_lineages(forms, rules) -> Array` (revealed and offer met); `open_lineages` becomes `revealed_lineages`'s name for old callers; `offers()` at stage 1 for the slime = `offered_lineages` plus `greater_slime` when fewer than two.

- [ ] **Step 1: Rewrite the failing tests** in `tests/test_form_offers.gd` with a `FakeRules` that answers `absorbed(e)` from a dictionary and `level_of(id)`: `test_the_gates_are_read_from_the_data` (the five reveal and offer dictionaries above); `test_a_lineage_is_revealed_at_its_threshold` (air 9: none, air 10: `["echo"]`); `test_toxic_needs_both_elements` (water 10 alone: none; water 10 and dark 8: `["toxic"]`); `test_a_power_helps_by_three_and_never_gates_alone` (Sticky Thread owned, dark 21: `["weaver"]`; dark 20: none; all three Bulwark powers owned, earth 0: none); `test_an_evolved_power_still_counts` (`level_of("poison_breath") == 4`, water 4 and dark 2 absorbed: `["toxic"]` since 4 + 6 and 2 + 6 meet 10 and 8 only with two powers owned: use `spore_cloud` as well); `test_offered_needs_the_higher_number` (air 10 to 33: revealed, not offered, offers `["greater_slime"]`; air 34: `["echo", "greater_slime"]`); `test_two_offered_lineages_never_add_greater_slime`; `test_a_fresh_life_offers_only_greater_slime`; keep the stage-2 and stage-3 offer tests.
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_offers`. Expected: FAIL.
- [ ] **Step 3: Implement** the functions; add `reveal` and `offer` to the five `.tres` files (`reveal = {"air": 10}` style, one key per element); turn the validator's "needs a reveal and an offer" rule on for slime lineage forms; update the doc comments.
- [ ] **Step 4: Run** `tools/run_tests.sh`. Expected: PASS; fix any existing test that assumed power-gating (`test_form_tab.gd`, `test_skill_tree_model.gd`, `test_evolution_*`) by absorbing the essence the new gate needs (ledger each).
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: the slime's lineages open by what it absorbed, with a reveal and an offer"`.

### Task 3: Calibration pins

**Files:**
- Test: `tests/test_lineage_gate_calibration.gd` (new)

**Interfaces:**
- Consumes: `CalibrationWalk` (`tests/support/calibration_walk.gd`: `order`, `eat`), the shipped rooms and creatures, `FormOffers`.

- [ ] **Step 1: Write the tests** (they pass on the data; if one does not, the numbers or the code are wrong: investigate): a helper walks the shipped rooms from a start area, eating every spawn once through a real `SkillRulesEngine`, and records `FormOffers.revealed_lineages` at the end of each area. `test_a_cave_start_reveals_three_in_the_cave_and_all_five_by_the_grotto` (`["tide", "toxic", "echo"]` after the Cave; all five after the Grotto); `test_a_grotto_start_reveals_echo_and_bulwark_first` (`["bulwark", "echo"]` after the Grotto); `test_a_flooded_start_reveals_tide_and_echo_first` (`["tide", "echo"]`); `test_a_deep_start_reveals_only_bulwark_first` (`["bulwark"]`, so the Greater fallback is offered at 270 XP's neighbourhood); `test_a_completionist_cave_start_is_offered_all_five_and_any_other_start_four` (offers at the end of the walk, Weaver missing for G1, F1 and D1).
- [ ] **Step 2: Run** `tools/run_tests.sh test_lineage_gate_calibration`. Expected: PASS (the tests pin the data; a mutation check: change `echo`'s reveal to 40 and see one fail, then restore).
- [ ] **Step 3: Commit** `git commit -am "test: pin the slime's lineage gates against the shipped world"`.

### Task 4: The Tree tab shows reveal progress

**Files:**
- Modify: `scripts/ui/skill_screen_model.gd` (`_form_tree_card`)
- Test: `tests/test_form_gates.gd`

**Interfaces:**
- Produces: `static func SkillScreenModel.gate_lines(def: FormDef, rules) -> Array` (strings): `"Shows at: dark 24 (you have 7)"`, `"On offer at: dark 26"`, and `"Each power you own counts +3"` when `def.powers` is non-empty. A stage-2 form's tree card appends them.

- [ ] **Step 1: Write failing tests:** `test_gate_lines_say_what_a_lineage_needs_and_what_you_have` (weaver, dark 7 absorbed: `["Shows at: dark 24 (you have 7)", "On offer at: dark 26", "Each power you own counts +3"]`); `test_toxic_lists_both_elements` (`"Shows at: water 10 (you have 0), dark 8 (you have 0)"`); `test_a_form_without_a_gate_has_no_lines` (greater slime: `[]`); `test_the_tree_card_of_a_stage_two_form_carries_them`.
- [ ] **Step 2: Run, expect FAIL; Step 3: implement; Step 4: run `tools/run_tests.sh test_form`, expect PASS; Step 5: commit** `git commit -am "feat: the Tree tab says what each lineage needs"`.

### Task 5: The generator writes the slime's 18 forms; the Sovereigns lose a parent

**Files:**
- Modify: `tools/build_species_forms.py`, `tools/test_build_species_forms.py`, `data/forms/{silkbound,tidal,venom,stone,storm,prime}.tres`
- Create: `data/forms/<the 18 ids>.tres` (generated)
- Test: `tests/test_forms.gd` (rewritten for the new shape), `tests/test_form_species.gd`, `tests/test_form_data_fields.gd`, `tests/test_species_form_data.gd` (counts)

**Interfaces:**
- Produces: `build_species_forms.slime_forms() -> list[dict]` (the 18, with `dataId`, `parents`, `lineage`, `traits`, `grants`, `tint`, `stats`, `size`) and `tres` writing `traits` and `grants` when present; the CLI writes 99 + 18.

- [ ] **Step 1: Write failing tests.** Python: `test_the_slime_has_eighteen_new_forms_with_their_parents_traits_and_grants` (`gleipnir` parent `snare`, `traits == ["spinner"]`, `grants == ["sticky_thread"]`; `ariadne` parent `arachne`, grants `["sticky_thread", "wall_cling"]`; `king_slime` parent `radiant`, lineage `greater`); `test_every_new_slime_id_is_unique_and_unprefixed`. GUT, in `tests/test_forms.gd`: the slime has 42 forms (stage 2: 6, 3: 12, 4: 24); `test_a_stage_two_or_three_slime_form_has_exactly_two_children`; `test_every_stage_three_and_four_form_has_one_parent` (no branch rejoins); `test_every_branch_reaches_stage_four`; delete the two shared-Sovereign tests.
- [ ] **Step 2: Run both. Expected: FAIL.**
- [ ] **Step 3: Implement** `slime_forms()` (parents mapped through `build_evolutions.BUILT_SLIME`; traits and grants and tint read from the parent's `.tres`), run the CLI, re-parent the six Sovereigns with one scripted edit, then `godot --headless --import`.
- [ ] **Step 4: Run** `tools/run_tests.sh` and the Python tests; fix every existing pin that counted 24 slime forms or 123 forms (`test_form_species`, `test_form_data_fields`, `test_species_form_data`, `test_skill_tree_model`, `test_evolution_trees`, `test_forms_reached`) and ledger each. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: the slime's tree has one parent per Sovereign and eighteen new stage-4 forms"`.

### Task 6: The Tree tab lays out several stage-4 forms per lineage

**Files:**
- Modify: `scripts/ui/skill_tree_model.gd` (`_form_slots`)
- Test: `tests/test_form_species.gd`, `tests/test_skill_tree_model.gd` (positions that changed)

**Interfaces:**
- Produces: slots as in the architecture note: stage 4 one row each in order of parent id then id; stage 3 and stage 2 at the mean row of their children; a lineage's block is as tall as its stage-4 count (at least one row); the species base at the middle of the band. Every edge still joins adjacent columns.

- [ ] **Step 1: Write failing tests:** `test_no_two_form_nodes_overlap_in_a_slime_tree_with_every_form_reached` (`SkillTreeModel.build` with `reached` = every slime form id and `current` = `"storm"`: for every pair of form nodes the rectangles `Rect2(pos, NODE_SIZE)` do not intersect); the same for `"wolf"` over `FormLoader.load_all()` with every wolf form reached; `test_stage_four_siblings_are_one_row_apart` (`gleipnir` and `silkbound` positions differ by `ROW_PITCH`); `test_a_stage_three_form_sits_between_its_children`; `test_every_form_edge_joins_adjacent_columns`.
- [ ] **Step 2: Run. Expected: FAIL.**
- [ ] **Step 3: Implement** the layout.
- [ ] **Step 4: Run** `tools/run_tests.sh`; update position pins in `test_skill_tree_model.gd` that encoded the old two-rows-per-lineage layout (ledger each). Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: the Tree tab lays out several stage-4 forms per lineage"`.
