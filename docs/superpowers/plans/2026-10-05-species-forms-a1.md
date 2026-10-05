# Species-aware forms (A1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The form system works for any species, not only the slime: a form belongs to a species, each species has its own base, and loading, validating, offering, reaching and the Tree tab all take a species. No new content and no change to what the slime does.

**Architecture:** `FormDef` gains `species` (default `"slime"`, so the 24 `.tres` files load unchanged). A species' base form id is the species id (`"slime"` is today's `Form.BASE`). `Form` is built for a species; `FormLoader`, `FormValidator`, `FormOffers`, `WorldProgress` and `SkillTreeModel` stop assuming the slime. A second species is exercised by in-memory fixtures; real wolf, undead, spider and goblin forms arrive in piece A3.

**Tech Stack:** Godot 4.7, GDScript, GUT. Run one file with `tools/run_tests.sh <file-substring>`; the whole suite with `tools/run_tests.sh`.

**Spec:** `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md` (piece A1) and `docs/research/species-form-branches.md` (sections 1 and 2: the shape every species follows; the form ids and counts).

## Global Constraints

- The existing form tests, skill tree tests and evolution tests pass **unchanged** (24 slime forms, six lineages, the slime's offers). Baseline before this plan: 2591 tests passing.
- `Form.BASE` keeps its value `"slime"` and stays defined; code that means "the slime" may keep using it.
- A species' base form id is the species id. Species ids: `slime`, `wolf`, `undead`, `spider`, `goblin`.
- No edit to any `data/forms/*.tres` and none to `tools/build_forms.gd`.
- GDScript style of the surrounding files: tabs, static typing, `##` doc comments, no trailing comments that restate code.
- A run must end with no `SCRIPT ERROR` or `Parse Error` in `.tmp/test-logs/gut.log` (`tools/run_tests.sh` checks this).

## Review Focus

- A form of one species naming another species' base as its parent (a wolf form with parent `"slime"`): the validator reports it, and `Form.advance` refuses it. (Task 3, Task 1)
- A `FormDef` loaded from a `.tres` with no `species` line: it is a slime form. (Task 1)
- A species with no stage-2 forms in the data: loader, offers and the Tree model return empty results, not an error. (Tasks 2, 4, 6)
- Saved progress: `reach_form` of a species' base id stores nothing and `is_form_reached` is true for every base; an unknown id in `forms_reached` is untouched. (Task 5)
- A stage-3 or stage-4 form whose lineage differs from its parent's: the validator reports it (the tree screen groups by lineage). (Task 3)

---

### Task 1: `FormDef.species` and a species-aware `Form`

**Files:**
- Modify: `scripts/forms/form_def.gd`, `scripts/forms/form.gd`
- Test: `tests/test_form_species.gd` (new)

**Interfaces:**
- Produces: `FormDef.species: String` (`@export`, default `"slime"`); `Form.SPECIES: Array` (`["slime","wolf","undead","spider","goblin"]`); `Form.DEFAULT_SPECIES := "slime"`; `Form.BASE` unchanged; `static func Form.is_base(id: String) -> bool` (true when `id` is in `SPECIES`); `Form._init(p_species := DEFAULT_SPECIES)`; `var species: String`.
- Changed: `Form.advance(id, forms)` also requires `f.species == species`; `Form.reset()` returns to `form_id = species`.

- [ ] **Step 1: Write the failing tests** in `tests/test_form_species.gd` (new file, `extends GutTest`). Add the shared helper `static func make(id, species, stage, lineage, parents) -> FormDef` (sets the five fields, `display_name = id`) and `static func wolf_forms() -> Dictionary` (the fixture used by later tasks: `wolf_moonbound` stage 2 lineage `moonbound` parents `["wolf"]`; `wolf_loup_garou` and `wolf_ulfhedinn` stage 3, lineage `moonbound`, parent `wolf_moonbound`; `wolf_black_dog` stage 2 lineage `black_dog`, parent `wolf`). Tests:
  - `test_a_form_def_without_a_species_is_a_slime_form`: `FormDef.new().species == "slime"`, and every form from `FormLoader.load_all()` has `species == "slime"`.
  - `test_is_base_knows_every_species_and_nothing_else`: true for each of `Form.SPECIES`, false for `"weaver"` and `""`.
  - `test_a_wolf_body_starts_at_the_wolf_base`: `Form.new("wolf")` has `species == "wolf"`, `form_id == "wolf"`, `stage == 1`; `Form.new()` has `form_id == "slime"`.
  - `test_a_wolf_body_advances_into_a_wolf_form_and_a_slime_body_does_not`: with `wolf_forms()`, `Form.new("wolf").advance("wolf_moonbound", forms)` is true and sets `stage == 2`; `Form.new().advance("wolf_moonbound", forms)` is false and changes nothing.
  - `test_a_form_of_another_species_with_a_matching_parent_id_is_refused`: a fixture form `make("odd", "wolf", 2, "x", ["slime"])`; `Form.new()` (slime) `advance("odd", {"odd": f})` is false (species differs although the parent matches).
  - `test_reset_returns_to_the_species_base`: after advancing, `reset()` gives `form_id == "wolf"`, `stage == 1`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_species`. Expected: FAIL (`species` not a member of `FormDef`; `Form.new("wolf")` too many arguments).
- [ ] **Step 3: Implement** the interface above. `advance` keeps its other checks (`f.stage == stage + 1`, `f.parents.has(form_id)`).
- [ ] **Step 4: Run** `tools/run_tests.sh test_form` (matches every form test file). Expected: `PASS`, all earlier form tests unchanged.
- [ ] **Step 5: Commit** `git add scripts/forms tests/test_form_species.gd && git commit -m "feat: a form belongs to a species and a body is built for one"`

### Task 2: `FormLoader` species queries

**Files:**
- Modify: `scripts/forms/form_loader.gd`
- Test: `tests/test_form_species.gd`

**Interfaces:**
- Consumes: Task 1's `FormDef.species`, `Form.DEFAULT_SPECIES`, `wolf_forms()`.
- Produces: `static func FormLoader.of_species(forms: Dictionary, species: String) -> Dictionary` (the subset, keys unchanged); `static func FormLoader.stage2_forms(forms: Dictionary, species := Form.DEFAULT_SPECIES) -> Array` (the species' stage-2 forms: those listing the species' base as a parent and belonging to it, in id order).

- [ ] **Step 1: Write failing tests:** `test_of_species_splits_a_mixed_dictionary` (the slime data merged with `wolf_forms()`: `of_species(all, "wolf").size() == 4`, `of_species(all, "slime").size() == 24`, `of_species(all, "goblin")` is empty); `test_stage2_forms_default_to_the_slime` (`stage2_forms(all).size() == 6`); `test_stage2_forms_of_the_wolf_are_in_id_order` (`["wolf_black_dog", "wolf_moonbound"]` by id); `test_a_species_with_no_forms_has_no_stage2_forms` (`stage2_forms(all, "spider") == []`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_species`. Expected: FAIL (`of_species` not found).
- [ ] **Step 3: Implement** `of_species` by filtering on `species`; `stage2_forms` = `children_of(forms, species)` filtered to `f.species == species`.
- [ ] **Step 4: Run** `tools/run_tests.sh test_form`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: the form loader answers per species"` (plus the test file).

### Task 3: `FormValidator` checks species, parentage and lineage

**Files:**
- Modify: `scripts/forms/form_validator.gd`
- Test: `tests/test_form_species.gd`

**Interfaces:**
- Consumes: `Form.SPECIES`, `Form.is_base`, `FormDef.species`.
- Changed rules in `validate(forms, skill_ids, check_art := false) -> PackedStringArray` (the slime's messages stay word for word):
  - `"%s: unknown species '%s'"` when `f.species` is not in `Form.SPECIES`.
  - A parent that is a base id: it must equal `f.species` and `f.stage` must be 2; a base of another species gives `"%s: parent '%s' is another species' base"`.
  - A parent form of another species gives `"%s: parent '%s' is a %s form"`.
  - Lineage: the slime's lineage must be in `LINEAGES` (unchanged); any other species needs a non-empty lineage (`"%s: no lineage"`); a stage-3 or stage-4 form's lineage must equal its parent's (`"%s: lineage '%s' differs from its parent's '%s'"`).
  - The "stage-2 lineage form needs an opening power" rule applies to the slime only; a non-slime stage-2 form may list powers or none.

- [ ] **Step 1: Write failing tests:** `test_the_fixture_species_passes_the_validator` (`validate(wolf_forms(), skill_ids)` is empty); `test_the_slime_data_still_passes_beside_a_second_species` (merge, empty); then one test per new message, each building a fixture and asserting `errs.size() == 1` and the exact message: unknown species `"werewolf"`; a wolf form with parent `"slime"`; a stage-3 wolf form whose parent is a slime form `weaver`; a stage-3 form with lineage `x` under a `moonbound` parent; a wolf stage-2 form with empty lineage; a wolf stage-2 form with no powers is fine.
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_species`. Expected: FAIL.
- [ ] **Step 3: Implement** the rules; keep the loop structure and message style of the file.
- [ ] **Step 4: Run** `tools/run_tests.sh test_form`. Expected: PASS (`test_the_data_passes_its_validator` included).
- [ ] **Step 5: Commit** `git commit -am "feat: the form validator checks species, parentage and lineage"`.

### Task 4: `FormOffers` offers per species

**Files:**
- Modify: `scripts/forms/form_offers.gd`
- Test: `tests/test_form_species.gd`

**Interfaces:**
- Produces: `static func FormOffers.lineage_order(forms: Dictionary, species := Form.DEFAULT_SPECIES) -> Array` (the slime: `LINEAGE_ORDER` plus `"greater"`; another species: its stage-2 forms' lineages, de-duplicated, in form-id order).
- Changed: `FormOffers.offers(forms, form, rules)` at stage 1 uses `form.species`: the slime is unchanged; any other species is offered all of its stage-2 forms in id order (the gate arrives with A3 and B1). `open_lineages` and `lineage_powers` stay slime-only and say so in their doc comments.

- [ ] **Step 1: Write failing tests** (a `FakeRules` as in `test_form_offers.gd`): `test_a_wolf_at_stage_one_is_offered_every_wolf_line` (`["wolf_black_dog", "wolf_moonbound"]`); `test_a_wolf_form_is_offered_its_children` (`offers(forms, f, rules)` with a `Form` advanced to `wolf_moonbound` gives `["wolf_loup_garou", "wolf_ulfhedinn"]`); `test_the_slime_offers_do_not_change_beside_a_wolf` (merged dictionary, nothing reached: `["greater_slime"]`); `test_lineage_order_for_the_slime_is_the_six_lineages` (`["weaver","tide","toxic","bulwark","echo","greater"]`); `test_lineage_order_for_the_wolf` (`["black_dog","moonbound"]`); `test_a_species_with_no_forms_offers_nothing` (`offers({}, Form.new("spider"), rules) == []` and `lineage_order({}, "spider") == []`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_species`. Expected: FAIL.
- [ ] **Step 3: Implement**; `_first_offers` gains a `species` argument.
- [ ] **Step 4: Run** `tools/run_tests.sh test_form`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: form offers follow the body's species"`.

### Task 5: `WorldProgress` bases and `Player.species`

**Files:**
- Modify: `scripts/world/world_progress.gd` (lines 90-97), `scripts/player/player.gd` (the `form` declaration near line 107, `setup` near line 129)
- Test: `tests/test_form_species.gd`

**Interfaces:**
- Consumes: `Form.is_base`.
- Produces: `Player.species: String` (default `Form.DEFAULT_SPECIES`; set before `setup`, which builds `form = Form.new(species)`); `WorldProgress.reach_form` ignores every base id and `is_form_reached` is true for every base id.

- [ ] **Step 1: Write failing tests:** `test_every_base_is_reached_by_definition` (`WorldProgress.new()`: `is_form_reached("wolf")` and `("slime")` true; `reach_form("wolf")` leaves `forms_reached` empty; `reach_form("wolf_moonbound")` stores it; an unknown id `"nonsense"` can be stored and read back and nothing else changes); `test_a_wolf_player_starts_as_the_wolf_base` (a `Player` built as in `tests/test_evolution_flow.gd` with `player.species = "wolf"` set before `setup`: `form.form_id == "wolf"` and `form_def() == null`); `test_a_wolf_player_evolves_into_a_wolf_form_only` (after `setup`, add `wolf_forms()` to `player.forms`; `advance_form("wolf_moonbound", true)` is true; a slime player's `advance_form("wolf_moonbound", true)` is false); `test_a_wolf_player_at_the_cap_is_offered_wolf_forms` (`progression.add_xp(Progression.stage_total(1))` then `form_offers()` ids equal the two stage-2 wolf forms); `test_a_new_run_returns_a_wolf_to_the_wolf_base` (advance, call `rules.start_run()`, `form.form_id == "wolf"`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_species`. Expected: FAIL.
- [ ] **Step 3: Implement.** The player's body, movement and sheet stay the slime's until piece D1; say so in a doc comment on `species`.
- [ ] **Step 4: Run** `tools/run_tests.sh test_form` and `tools/run_tests.sh test_evolution`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: the player and the world's progress know the species"`.

### Task 6: `SkillTreeModel` for the body's species

**Files:**
- Modify: `scripts/ui/skill_tree_model.gd` (`_form_nodes`, `_form_slots`, `_row_powers`, `build`)
- Test: `tests/test_form_species.gd` (and `tests/test_skill_tree_model.gd` stays unchanged)

**Interfaces:**
- Consumes: `FormOffers.lineage_order`, `FormLoader.stage2_forms(forms, species)`, `Form.is_base`.
- Produces: the model derives the species from `current_form` (a base id is its own species; otherwise `forms[current].species`, else the slime); the base node's id is the species id, named by a new `static func SkillTreeModel.base_name(species: String) -> String` (`Slime`, `Wolf`, `Skeleton`, `Spiderling`, `Scrapper`); stage-2 forms and the row order come from that species; for a species other than the slime every lineage counts as open (A3 gives them gates). `build`'s signature does not change.

- [ ] **Step 1: Write failing tests** (build the model as `test_skill_tree_model.gd` does, with `forms = merged data + wolf_forms()`, `current = "wolf"`): `test_the_wolf_tree_has_the_wolf_base_and_its_lines` (the form nodes contain `"wolf"`, `"wolf_moonbound"`, `"wolf_black_dog"` and none of the slime's forms; `"wolf"` has state `CURRENT`); `test_wolf_stage_three_forms_are_stubs_until_a_parent_is_named`; `test_the_slime_tree_is_unchanged_with_wolf_forms_loaded` (`current = "slime"`: the node ids equal those built without the wolf forms); `test_a_species_with_no_forms_gives_only_its_base` (`current = "spider"`, `forms` = the slime data: exactly one form node, `"spider"`, no error).
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_species`. Expected: FAIL.
- [ ] **Step 3: Implement**; replace the three `Form.BASE` and `FormOffers.LINEAGE_ORDER` uses with the species-derived values. The layout (two rows per lineage, one Sovereign) is the slime's and is reworked in B2, so leave a one-line note there.
- [ ] **Step 4: Run** `tools/run_tests.sh test_skill_tree` and `tools/run_tests.sh test_tree_tab`. Expected: PASS, unchanged.
- [ ] **Step 5: Commit** `git commit -am "feat: the Tree tab draws the body's own species"`.

### Task 7: Whole suite, roadmap and review

**Files:**
- Modify: `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md` (mark A1 built, with the test count)

- [ ] **Step 1: Run** `tools/run_tests.sh`. Expected: `PASS: N tests` with N greater than 2591 and no `SCRIPT ERROR`.
- [ ] **Step 2: Grep for stragglers:** `grep -rn "Form.BASE" scripts` lists only slime-specific uses (the base node of a slime-only screen, `world_progress`'s default); change any that should be species-driven.
- [ ] **Step 3: Update the roadmap** (one line: A1 built, branch `feat/species-forms`).
- [ ] **Step 4: Commit** `git commit -am "docs: A1 built"`.
