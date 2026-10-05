# Review aids: start as any form, and the cards say what a form does Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A reviewer can see every evolution in the game without a grind: `--form=<id>` starts the run as that form (its species, its whole line evolved to it), and the Tree and Form cards name the form's verb with its cost and say what it gives up and how it is opened.

**Architecture:** `Game.form_arg(args)` reads the flag; after `begin_life`, `Game` asks `Player.become_form(id)`, which sets the species and evolves down the form's parent chain with `advance_form(id, true)`, then ends the evolve moment. `SkillScreenModel.form_card` gains `verb`, `gives_up` and `opened_by`; the Tree card shows them.

**Tech Stack:** Godot 4.7 GDScript, GUT.

**Spec:** `docs/research/species-form-branches.md` (the Verb, Gives up and Opened by columns); roadmap.

## Global Constraints

- Baseline 2865 tests on `main` (af1ee1a). `--form=` is a debug flag like `--evolve`: it grants nothing else and an unknown id does nothing. The README lists it.
- A card line is one short line each: `Verb: Bind, 8 MP, 8 s`, `Gives up: <text>`, `Opened by: <text>`, shown only when the form has them.

## Review Focus

- `--form=` for each of the 141 forms reaches exactly that form, at its stage, with its verb in a slot and no error. (Task 1)
- A form that is not a FormDef (a species base, a typo) leaves the run as it was. (Task 1)
- A form with no verb (a built slime form, Quicksilver) has no verb line and no empty line. (Task 2)

---

### Task 1: `--form=<id>`

**Files:**
- Modify: `scripts/player/player.gd` (`become_form`), `scripts/game.gd` (`form_arg`, the call), `README.md`
- Test: `tests/test_form_flag.gd` (new)

**Interfaces:**
- Produces: `Player.become_form(id: String) -> bool` (false for an unknown id; sets the species, evolves along the parent chain with force, ends the evolve moment); `Game.form_arg(args: Array) -> String` (`--form=wolf_fenrir` gives `wolf_fenrir`, a bare or absent flag gives `""`).

- [ ] **Step 1: Write failing tests:** `test_form_arg_reads_the_flag_and_nothing_else`; `test_become_form_reaches_exactly_that_form_for_every_form` (all 141 forms on fresh Players: `form.form_id`, `form.stage`, `species` match; for a form with a verb the verb is in a slot; the evolve moment is over); `test_become_form_with_an_unknown_id_changes_nothing` (a typo, a species base); `test_the_game_starts_as_the_form_the_flag_names` (a `Game` with `--form=wolf_fenrir` has a wolf Player at stage 4 in `wolf_fenrir`).
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_flag`. Expected: FAIL.
- [ ] **Step 3: Implement** both functions and the call in `Game._ready` after `begin_life`; the README line.
- [ ] **Step 4: Run** `tools/run_tests.sh test_form_flag`, `test_game`, `test_evolution_flow`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: start as any form with --form="`.

### Task 2: The cards say what a form does

**Files:**
- Modify: `scripts/ui/skill_screen_model.gd` (`form_card`, `_form_tree_card`)
- Test: `tests/test_form_tab.gd`

**Interfaces:**
- Produces: `form_card` keys `verb` (text or ""), `gives_up`, `opened_by`; the Tree card's lines in that order after the traits.

- [ ] **Step 1: Write failing tests:** `test_the_form_card_names_the_verb_its_cost_and_cooldown` (`gleipnir`: `"Bind, 8 MP, 8 s"`); `test_the_card_of_a_form_with_no_verb_has_none` (`weaver`); `test_the_tree_card_shows_verb_gives_up_and_opened_by` (the three lines, once, for `wolf_fenrir`); `test_a_card_never_shows_an_empty_line`.
- [ ] **Step 2: Run** `tools/run_tests.sh test_form_tab`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `tools/run_tests.sh test_form_tab`, `test_skill_tree_view`, then the whole suite `TEST_TIMEOUT=1700 tools/run_tests.sh`. Expected: PASS.
- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: the cards name a form's verb, what it gives up and how it is opened"`.
