# Fire, mind and blood (A2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The three elements no creature carries yet (fire, mind, blood) exist in the game's vocabulary: they validate, they are absorbed and counted, they show in the HUD and at altars once held, and the engine can say how much of each element was absorbed this life.

**Architecture:** `Essences.ALL` becomes the whole vocabulary of eight; `Essences.FIRST_PASS` keeps the five shipped elements, which keep their fixed rows at an altar. A later element gets an altar row only while some of it is held. `SkillRulesEngine.absorbed(element)` exposes the counter `held` already reads, for the slime's lineage gates (B1).

**Tech Stack:** Godot 4.7, GDScript, GUT. `tools/run_tests.sh <file-substring>` runs a file; `tools/run_tests.sh` the suite.

**Spec:** `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md` (A2) and `docs/research/species-form-branches.md` (section 10.4: where each essence arrives).

## Global Constraints

- Baseline 2626 tests. Every existing test passes unchanged except the vocabulary pin in `tests/test_constants.gd` (`Essences.ALL` was the five).
- Canonical order: water, earth, air, light, dark, fire, mind, blood. `Player` emits ABSORBED in `Essences.ALL` order.
- An altar's five first-pass rows keep their order and position; a later element's row appears after them, only while `held > 0`.
- No creature, skill or form data changes in this plan.

## Review Focus

- A creature carrying a later element: eating it absorbs that element and `held` rises. (Task 3)
- An altar with later essence held, then banked down to zero: the row disappears and the highlighted row never points past the end. (Task 3)
- A skill whose unlock counts a later element validates. (Task 1)
- `absorbed` ignores what was spent: it never goes down when essence is banked or spent on an evolution. (Task 2)
- A saved game or profile that mentions no later element loads unchanged. (Task 1: the suite)

---

### Task 1: The vocabulary

**Files:**
- Modify: `scripts/core/essences.gd`, `tests/test_constants.gd`
- Test: `tests/test_later_essences.gd` (new)

**Interfaces:**
- Produces: `Essences.FIRE`, `Essences.MIND`, `Essences.BLOOD` (`"fire"`, `"mind"`, `"blood"`); `Essences.FIRST_PASS := [WATER, EARTH, AIR, LIGHT, DARK]`; `Essences.LATER := [FIRE, MIND, BLOOD]`; `Essences.ALL := FIRST_PASS + LATER`.

- [ ] **Step 1: Write failing tests** in `tests/test_later_essences.gd`: `test_the_vocabulary_is_eight_elements_in_canonical_order` (`Essences.ALL == ["water","earth","air","light","dark","fire","mind","blood"]`, `FIRST_PASS.size() == 5`, `LATER == ["fire","mind","blood"]`); `test_a_creature_may_carry_a_later_element` (a `CreatureDef` with `essences = {"blood": 2}` validates: build as `TestDefs` does and run `DefValidator` on the creature list; no errors); `test_a_skill_may_unlock_on_a_later_element` (a `TestDefs.skill` whose unlock is `TestDefs.counter("absorbed", 3, {"essence": "fire"})` validates with no errors); `test_an_unknown_element_is_still_refused` (`"ether"` in a creature gives the error `unknown essence 'ether'`). Update the pin in `tests/test_constants.gd` to the eight.
- [ ] **Step 2: Run** `tools/run_tests.sh test_later_essences`. Expected: FAIL (no `Essences.LATER`).
- [ ] **Step 3: Implement** the constants.
- [ ] **Step 4: Run** `tools/run_tests.sh` . Expected: `PASS`. If a list that iterates `Essences.ALL` shows a failing test, fix the list in Task 3 rather than here; note which.
- [ ] **Step 5: Commit** `git add scripts/core tests && git commit -m "feat: fire, mind and blood join the essence vocabulary"`

### Task 2: `SkillRulesEngine.absorbed`

**Files:**
- Modify: `scripts/skills/skill_rules_engine.gd` (beside `held`)
- Test: `tests/test_later_essences.gd`

**Interfaces:**
- Produces: `func absorbed(element: String) -> int` (the ledger counter of ABSORBED events for the element this life, spending ignored).
- Consumes: `Events.ABSORBED`, `ESSENCE_SPENT`.

- [ ] **Step 1: Write failing tests:** `test_absorbed_counts_every_element_including_the_later_ones` (an engine as in `tests/test_spend_essence.gd`; `handle_event("absorbed", {"essence": "mind", "source": "x"})` three times: `absorbed("mind") == 3`, `held("mind") == 3`, `absorbed("fire") == 0`); `test_absorbed_never_goes_down_when_essence_is_spent` (absorb 4 blood, `spend_essence("blood", 3)`: `held == 1`, `absorbed == 4`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_later_essences`. Expected: FAIL (`absorbed` not found).
- [ ] **Step 3: Implement**, and make `held` read `absorbed`.
- [ ] **Step 4: Run** `tools/run_tests.sh test_later_essences` and `tools/run_tests.sh test_spend_essence`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: the engine says how much of an element was absorbed this life"`.

### Task 3: Eating, the HUD and the altar

**Files:**
- Modify: `scripts/soul/altar_model.gd`
- Test: `tests/test_later_essences.gd`

**Interfaces:**
- Consumes: `Essences.FIRST_PASS`, `Essences.ALL`, `SkillRulesEngine.held`.
- Produces: the altar's rows are attune, one per `FIRST_PASS` element, one per `LATER` element with `held > 0` (in `ALL` order), then the perk; `_row_count()` and `_element_at(row)` follow the same list; `move` and `adjust` stay inside it.

- [ ] **Step 1: Write failing tests:** `test_eating_a_blood_creature_absorbs_blood` (a `Player` set up as in `tests/test_player.gd` with a creature def whose essences are `{"blood": 2}`: after the eat completes, `rules.held("blood") == 2`; find how that file completes an eat and reuse it); `test_status_text_lists_a_later_element_once_it_is_held` (`StatusText` lines contain `"blood 2"` and not `"fire"`; use the helper `tests/test_status_text.gd` uses); `test_an_altar_shows_five_element_rows_until_a_later_one_is_held` (an `AltarModel` as in `tests/test_altar_model.gd`: `rows()` has 1 + 5 (+ perk) entries; after absorbing 2 blood, one more element row `{"element": "blood"}` sits after the five and before the perk); `test_banking_a_later_element_works_and_its_row_goes_when_empty` (hold 2 blood, move to its row, `adjust(1)`, `act()` banks it, `rows()` is back to five element rows, and `row()` is clamped inside `rows().size() - 1`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_later_essences`. Expected: FAIL.
- [ ] **Step 3: Implement** `AltarModel._elements() -> Array` and use it in `rows`, `_row_count`, `_element_at`; clamp `_row` in `rows()`' caller path (`move` already clamps; re-clamp after `_bank`).
- [ ] **Step 4: Run** `tools/run_tests.sh`. Expected: `PASS: N tests` with N above 2626.
- [ ] **Step 5: Commit** `git commit -am "feat: later essences are eaten, shown and banked once held"`.
