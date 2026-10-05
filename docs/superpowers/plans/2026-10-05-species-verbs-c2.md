# A verb for every form (C2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every wolf, undead, spider and goblin form (99) grants a verb when the player evolves into it, and each verb does something in a test. The slime's 17 are done (B3); this adds rows to the same table.

**Architecture:** `tools/form_verbs.json` gains 99 rows (form, name, cost, damage value, spec, fidelity, note); `tools/build_form_verbs.py` writes their skill files and icons and `tools/build_species_forms.py` gives each form its `verb`, exactly as for the slime. Three small additions to the framework cover the verbs no existing kind fits: a `drain` key on the striking kinds (the caster heals by a fraction of the damage), a `reveal` kind (calls `reveal()` on `hidden` nodes in range, as `dissolve` calls `dissolve()`), and a `bridge` kind (a one-way platform laid ahead over a gap). The slime's whole-set arena test becomes a shared helper so every species is checked the same way: each verb, cast by a fresh Player in an arena, changes something it should.

**Tech Stack:** Godot 4.7 GDScript, GUT, Python 3 (generators, Pillow for icons).

**Spec:** `docs/research/species-form-branches.md` (the Verb and Gives-up columns, sections 3, 4, 6, 7) and `docs/superpowers/plans/2026-10-05-slime-verbs-b3.md`.

## Global Constraints

- Baseline 2840 tests on `main` (439a628). Every row carries `fidelity`: `full`, `approx` (does the part a test can see) or `needs` (names the system it waits for). Most verbs here are `approx`: their cost is a stat window, a summon, a mark, a zone or a strike standing in for items, grafts, taming, standing and the world's hidden things, which do not exist yet (E, F).
- A form with no row has no verb: the four species' base forms (wolf, goblin, spider, skeleton) have none. Costs 2 to 9 MP, damage values 0 to 20, cooldowns 1 to 25 s.
- `drain` is a number from 0 to 1 on `bolt`, `burst`, `ring`, `dash`, `mark`, `chain` and `dissolve`: the caster heals by at least 1 and at most `drain` times the damage it deals. `reveal` takes `radius` (default 160); `bridge` takes `length` (default 160) and `seconds` (default 15).
- Existing kinds and the slime's verbs do not change.

## Review Focus

- A `drain` hit heals the caster by what the spec says, never above its max HP, and a delayed `mark` whose caster is gone does not error. (Task 1)
- `reveal` with nothing hidden, and `bridge` with no floor or gap, do nothing and do not error. (Task 1)
- Every non-slime form but the four bases has a row, and each row validates (spec keys, fidelity, mp). (Tasks 2 to 4)
- Every verb changes something observable in a fresh Player's arena. (Tasks 2 to 4)

---

### Task 1: `drain`, `reveal`, `bridge` and the shared arena

**Files:**
- Create: `scripts/abilities/verb_bridge.gd`, `tests/support/verb_arena.gd`, `tests/test_verb_extras.gd`
- Modify: `scripts/abilities/verb_kinds.gd`, `tools/art/verb_icons.py` (glyphs for `reveal` and `bridge`), `tests/test_verb_essence.gd` (uses the arena)
- Test: `tests/test_verb_extras.gd`, `tests/test_verb_essence.gd`, `tools/test_verb_icons.py`

**Interfaces:**
- Produces: spec key `drain` (STRIKES); kinds `reveal` {radius} and `bridge` {length, seconds}; `VerbBridge` (`Node2D` with one one-way `StaticBody2D`, group `verb_bridges`); group `hidden` (nodes with `reveal()`); `VerbArena.snapshot(...)` and `VerbArena.run(test, form_id, row)` as in the slime's test.

- [ ] **Step 1: Write failing tests** (stub foes as before; a real `Player` where health matters): `test_a_drain_hit_heals_the_caster_by_a_fraction_of_the_damage` (value 10, `drain 0.5`: the caster at 10/30 HP gains 5, never above max, at least 1 for a tiny hit); `test_a_drain_with_no_foe_heals_nothing`; `test_a_delayed_mark_still_drains_and_survives_its_caster_going` (the caster freed first: no error); `test_reveal_calls_reveal_on_hidden_nodes_in_range_only`; `test_reveal_with_nothing_hidden_does_nothing`; `test_a_bridge_lays_a_one_way_platform_ahead_and_it_goes` (a body dropped on it rests on it; gone after `seconds`; a second cast replaces the first); `test_a_bridge_with_no_floor_does_nothing_odd`; `test_validate_knows_drain_reveal_and_bridge` (`drain` on a `zone` is refused). Python: `test_every_kind_in_the_table_has_a_glyph` already covers the new glyphs once rows use them.
- [ ] **Step 2: Run** `tools/run_tests.sh test_verb_extras`. Expected: FAIL.
- [ ] **Step 3: Implement** the key (healing in `_hit` through the caster's `health`), the two kinds, the node, the glyphs; move the slime arena test's snapshot and cleanup into `VerbArena` and have `test_verb_essence` call it.
- [ ] **Step 4: Run** `tools/run_tests.sh test_verb_extras`, `test_verb_essence`, `test_verb_kinds`, `test_verb_fields`, `test_verb_movers`, `test_slime_verbs`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: drain, reveal and bridge verbs, and a shared arena for the verb tests"`.

### Task 2: The wolf's and the undead's verbs

**Files:**
- Modify: `tools/form_verbs.json` (50 rows), generated `data/skills/verb_*.tres`, `data/forms/*.tres`, icons
- Create: `tests/test_species_verbs.gd`, Python tests in `tools/test_build_form_verbs.py`
- Test: `tests/test_species_verbs.gd`

- [ ] **Step 1: Write failing tests:** `test_every_wolf_and_undead_form_has_a_verb_row` (all but `wolf` and the skeleton, by form id from the generated forms); `test_each_of_their_verbs_does_something_in_a_fresh_arena` (through `VerbArena`, one fresh Player per row: damage, a root or stun, a spawned field, ally, vine, husk or platform, a mark, a stat window, a ward, a glide, essence, healing, a drain); `test_the_data_validates_with_the_new_verbs` (`DefValidator`, `FormValidator` with the verb ids); `test_a_verb_that_hurts_lists_a_value` (a row with a striking kind has `value > 0`); Python: `test_every_form_of_these_species_has_a_row`, `test_fidelity_and_notes_agree` (a `full` row has no note, an `approx` or `needs` row has one).
- [ ] **Step 2: Run** the suites. Expected: FAIL.
- [ ] **Step 3: Implement** the rows (one `form`, `name`, `mp`, `value`, `fidelity`, `note`, `text` and `spec` each, from the design doc's Verb and Gives-up columns), then `uv run --with Pillow python tools/build_form_verbs.py && python3 tools/build_species_forms.py`, import twice.
- [ ] **Step 4: Run** `tools/run_tests.sh test_species_verbs`, `test_form`, `test_content`, `test_art_assets`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: a verb for every wolf and undead form"`.

### Task 3: The spider's and the goblin's verbs

**Files:**
- Modify: `tools/form_verbs.json` (49 rows), generated data and icons
- Test: `tests/test_species_verbs.gd`, `tools/test_build_form_verbs.py`

- [ ] **Step 1: Write failing tests:** the Task 2 tests extended to the spider and the goblin, and `test_every_form_but_the_four_bases_has_a_verb` (all 99 non-slime forms and the slime's 17, none on the 24 built slime forms or on Quicksilver).
- [ ] **Step 2: Run** the suites. Expected: FAIL.
- [ ] **Step 3: Implement** the rows and regenerate as in Task 2.
- [ ] **Step 4: Run** the suites above, then the whole suite `TEST_TIMEOUT=1700 tools/run_tests.sh` and the Python tests. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: a verb for every spider and goblin form"`.
