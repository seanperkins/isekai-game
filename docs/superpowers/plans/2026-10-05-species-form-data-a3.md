# Form data for the other four species (A3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The 99 wolf, undead, spider and goblin forms of the design doc exist as `data/forms/*.tres`, load, validate and show in the Tree tab, each carrying the stats, tint, size, the essences it reads, where it is found, what it does and gives up, and how it opens. Their verbs are text until the verb system (C1) gives them behavior.

**Architecture:** `FormDef` gains display fields (`reads`, `host`, `source`, `verb_text`, `gives_up`, `opened_by`). A Python generator reads the design doc's form tables (reusing `tools/build_evolutions.py`'s parser) and writes the `.tres` files, so the doc stays the source and the data is regenerable; the files may then be edited by hand like the slime's. The slime's 18 new form-4s are not in this plan (B2 rebuilds the slime tree and its tests).

**Tech Stack:** Godot 4.7 GDScript and GUT; Python 3 for the generator and its `unittest`.

**Spec:** `docs/research/species-form-branches.md` (sections 3 to 7: the 99 forms) and `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md` (A3).

## Global Constraints

- Baseline 2636 tests. The 24 slime `.tres` files are not edited.
- A new form's id is `<species>_<slug of its name>` (`wolf_moonbound`, `undead_zombie`); the slug is ASCII, lowercase, with apostrophes dropped and other non-letters as `_`. The stage-2 forms' parent is the species id; every other form's parent is its doc parent.
- Lineage = the stage-2 form's slug; every descendant shares it (the validator enforces this since A1).
- Stats, tint and size follow the slime's scale: stage base `{2: hp 5 mp 3, 3: hp 12 mp 6 atk 1, 4: hp 22 mp 10 atk 2 def 1}`; size `{2: 1.12, 3: 1.25, 4: 1.4}`; per-element flavour in Task 3.
- `grants` and `traits` of a new form are empty (`[]`): no verb exists yet. `sprite_set` is `""`.
- Areas a form may name: cave, grotto, flooded, deep, forest, swamp, village, sacred, cemetery, crypt, volcano, demon.

## Review Focus

- A form file with no `reads`, `host` or text fields (every one of the 24 slime files) still loads and validates. (Task 1)
- `FormLoader.load_all()` now returns all species; code that means one species must say so. (Task 2)
- A name that slugs to an id already used (two forms called alike) is a generator error, not a silent overwrite. (Task 3)
- A form whose doc row has an element outside the vocabulary or an unknown area fails the generator, not the game. (Task 3)
- Every non-slime tree has at least two children per stage-2 and stage-3 form, and the secret Hierophant is a third child of the Lich. (Task 4)

---

### Task 1: `FormDef` display fields and their validation

**Files:**
- Modify: `scripts/forms/form_def.gd`, `scripts/forms/form_validator.gd`, `scripts/forms/form_loader.gd`
- Test: `tests/test_form_data_fields.gd` (new)

**Interfaces:**
- Produces: on `FormDef`: `reads: Array` (elements), `host: Array` (areas), `source`, `verb_text`, `gives_up`, `opened_by`: `String`; `FormValidator.AREAS: Array`; `static func FormLoader.load_species(species := Form.DEFAULT_SPECIES, dir := "res://data/forms") -> Dictionary` (`of_species(load_all(dir), species)`).

- [ ] **Step 1: Write failing tests:** `test_the_new_fields_default_to_empty` (a fresh `FormDef`: `reads == []`, `host == []`, the four strings `""`); `test_every_slime_form_still_loads_and_validates` (`FormValidator.validate(FormLoader.load_species(), skill_ids)` empty); `test_a_form_may_read_a_later_element` (a fixture with `reads = ["dark", "blood"]` validates); `test_an_unknown_element_in_reads_is_reported` (`"ether"` gives `"<id>: reads unknown essence 'ether'"`); `test_an_unknown_area_in_host_is_reported` (`"moon"` gives `"<id>: host names unknown area 'moon'"`); `test_load_species_filters` (`load_species("wolf")` is empty today and `load_species()` has 24).
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_data_fields`. Expected: FAIL.
- [ ] **Step 3: Implement** the fields (all `@export`, defaults empty), the two validator rules, `AREAS` and `load_species`.
- [ ] **Step 4: Run** `tools/run_tests.sh test_form`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: a form carries what it reads, where it is found and what it does"` (add the test).

### Task 2: Tests stop assuming the data is only the slime

**Files:**
- Modify: `tests/test_form_species.gd` (fixture ids to `fx_*`; slime data via `load_species`), `tests/test_forms.gd`, `tests/test_form_offers.gd`, `tests/test_skill_tree_model.gd`, `tests/test_skill_tree_view.gd`, `tests/test_form_sheets.gd`, `tests/test_grotto_rooms.gd`
- Test: the same files

**Interfaces:**
- Consumes: `FormLoader.load_species`.
- Changes nothing in `scripts/`: this task only makes tests say which species they mean, so they keep passing when Task 4 adds 99 forms.

- [ ] **Step 1: Switch each `FormLoader.load_all()` that means the slime** (the 24 forms, six lineages, `forms.size() == 24`) to `FormLoader.load_species()`; leave `test_pointer_aim.gd` and `test_channel.gd` (they index `["tide"]`) as they are. In `test_form_species.gd` rename the wolf fixture ids to `fx_moonbound`, `fx_loup_garou`, `fx_ulfhedinn`, `fx_black_dog` (species stays `"wolf"`) and build `_all()` from `load_species()`.
- [ ] **Step 2: Run** `tools/run_tests.sh`. Expected: `PASS` with the same count as before (2636 + Task 1's tests): nothing changes yet.
- [ ] **Step 3: Commit** `git commit -am "test: say which species a form test means"`.

### Task 3: The generator

**Files:**
- Create: `tools/build_species_forms.py`, `tools/test_build_species_forms.py`
- Modify: `tools/build_evolutions.py` (expose `parse_tables`, `parse_form_rows`, `read` as it already does; no change expected)

**Interfaces:**
- Consumes: `build_evolutions.parse_tables`, `parse_form_rows`, `DOC`, `ELEMENTS`.
- Produces: `slug(name: str) -> str`; `form_id(form: dict) -> str`; `tres(form: dict, ids: dict) -> str` (the file text); `build(out_dir="data/forms") -> list[str]` (the ids written); running `python3 tools/build_species_forms.py` writes the 99 files and prints the count.
- Flavour (added to the stage base): earth +1 def (stage 3 and 4: +2); air +8 spd and +10 jump_height (stage 3 and 4: +12 and +15); dark or blood or fire +1 atk; water +25 mp_regen (stage 3 and 4: +40); light +2 max_mp; mind +3 max_mp; cumulative over `reads`. Tint = the mean of the element colours (water 0.55 0.8 1.0, earth 0.9 0.78 0.6, air 0.8 0.95 1.0, light 1.0 0.95 0.7, dark 0.7 0.6 0.85, fire 1.0 0.6 0.45, mind 0.95 0.7 0.95, blood 0.9 0.45 0.5), plus 0.05 per channel at stage 4, capped at 1. A mixed-diet or empty `reads` takes water, earth, air.

- [ ] **Step 1: Write failing tests** (`unittest`, run `python3 -m unittest tools/test_build_species_forms.py`): `test_slug_folds_accents_and_drops_apostrophes` (`"Úlfheðinn"` → `ulfhedinn`, `"Beast of Gévaudan"` → `beast_of_gevaudan`, `"Cŵn Annwn"` → `cwn_annwn`, `"Heart-Weigher"` → `heart_weigher`); `test_every_non_slime_form_gets_a_unique_prefixed_id` (99 ids, all start with their species and `_`); `test_a_stage_two_form_grows_from_its_species_and_a_child_from_its_parents_id`; `test_stats_follow_the_stage_base_and_the_reads_flavour` (the Moonbound, reads dark, stage 2: `max_hp 5, max_mp 3, atk 1`; Loup-Garou, dark + blood, stage 3: `atk 3`); `test_a_duplicate_slug_is_an_error`; `test_an_unknown_area_or_element_is_an_error` (a row with host `moon`); `test_the_tres_text_lists_the_new_fields`.
- [ ] **Step 2: Run** the tests. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** the generator; the `.tres` text copies `data/forms/snare.tres`'s layout (the same header, ext_resource id `1_h3eka`, sorted-key `stats` block) and adds the new fields.
- [ ] **Step 4: Run** the Python tests. Expected: PASS.
- [ ] **Step 5: Commit** `git add tools && git commit -m "feat: a generator for the other species' forms, from the design doc"`.

### Task 4: The data, and the tests over it

**Files:**
- Create: `data/forms/*.tres` (99, generated); `tests/test_species_form_data.gd`
- Modify: `tools/build_evolutions.py`, `docs/evolutions/index.html` or `evolutions.js` (a form that has a data file is marked `in game data`)

**Interfaces:**
- Consumes: Task 1's fields, Task 3's generator.
- Produces: `FormLoader.load_all()` returns 123 forms; the page data has `inData` on each form.

- [ ] **Step 1: Write failing tests** in `tests/test_species_form_data.gd`: `test_the_species_have_their_forms` (`load_species(s).size()` is 21 wolf, 29 undead, 21 spider, 28 goblin, 24 slime); `test_the_data_passes_the_validator` (all 123); `test_every_stage_two_and_three_form_has_at_least_two_children` (non-slime); `test_the_hierophant_is_a_third_child_of_the_lich` (`undead_lich` has 3 children, one `undead_hierophant`); `test_every_new_form_says_what_it_reads_where_it_is_found_and_what_it_does` (non-empty `reads`, `host`, `verb_text`, `source`, `opened_by`); `test_later_elements_are_read_only_by_forms_that_wait_for_them` (every form that reads fire, mind or blood has `Essences.LATER` in `reads`, and the count of such forms is 20); `test_the_four_asks_exist` (`wolf_moonbound`, `undead_hierophant`, `undead_draugr`, `spider_weavermaid`); `test_the_tree_tab_draws_a_new_species_from_its_data` (`SkillTreeModel` with `current = "wolf"` over `load_all()` shows the wolf base, its three lines and the stage-3 stubs, nothing of the slime).
- [ ] **Step 2: Run** `tools/run_tests.sh test_species_form_data`. Expected: FAIL (no wolf forms).
- [ ] **Step 3: Run the generator:** `python3 tools/build_species_forms.py`; then `godot --headless --import` once so the new resources are known. Update the page builder to set `inData` by file existence and show a small tag.
- [ ] **Step 4: Run** `tools/run_tests.sh` and `python3 -m unittest tools/test_build_evolutions.py tools/test_build_species_forms.py`. Expected: `PASS`.
- [ ] **Step 5: Commit** `git add data/forms tests tools docs && git commit -m "feat: the wolf, undead, spider and goblin forms as game data"`.
