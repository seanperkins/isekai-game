# Soul Layer 1: The Pure Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the soul layer's testable core: species and their unlock rules, soul points, banking, perks, the head start, the goddess's lines and her scene model, with the validator and the shipped data. Nothing here draws a screen or changes the death flow.

**Architecture:** New files under `scripts/soul/`, data under `data/species|perks|soul|goddess/`. Every model is a `RefCounted` or `Resource` tested without a scene. The only existing code touched is `SkillRulesEngine` (one new method) and the `Compendium` autoload (one new member).

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-04-soul-layer-design.md`. Execute in a worktree `.worktrees/soul-core` on branch `feat/soul-core`, cut from `docs/soul-layer-spec` (the spec and this plan are not on `main` yet).

## Global Constraints

- Starting values: `bank_rate` 10, `level_prices` `[2, 3, 4, 5]`, `power_price` 3, `many_deaths` 5. Perk `stats`: altar `C1`, +2 `max_hp` and +1 `max_mp` per purchase, `price_base` 5, `price_step` 3; the n-th purchase (counted from 0) costs `price_base + price_step * n`.
- Profile section `soul` = `{"points", "perks", "deaths"}`; `session_points` is never saved. Every `SoulProgress` change saves the Profile at once.
- `ESSENCE_SPENT` stays outside `Events.ALL` and `Events.INTERNAL`.
- Never edit `scripts/movement/`, `data/movement/`, the movement tests, `player.gd`, `room_lint.gd` or `world_validator.gd`.
- After creating a `.gd` with a `class_name`, run `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and commit its `.uid` with it (the repo tracks one per script). Run tests with `tools/run_tests.sh <substring>`; it fails on `SCRIPT ERROR`, `Parse Error` or an empty run.
- Commit messages carry no attribution lines. No time or effort estimates anywhere.

## Review Focus

- Banking an amount that is not a multiple of the rate, or more than is held, must spend nothing (Task 4).
- A `soul` section that is malformed, negative or names unknown perks loads as zero or is trimmed, never crashes (Task 3).
- `spend` takes session points first, and a short balance spends nothing (Task 3).
- A creature both defeated and eaten counts once toward an unlock (Task 2).
- `line_for` with `every` of 0, an empty `many_deaths` list, deaths of 0 or an unknown cause never divides by zero or indexes an empty list (Task 7).

### Task 1: `SkillRulesEngine.spend_essence`

**Files:**
- Modify: `scripts/skills/skill_rules_engine.gd` (add after `can_afford`; `evolve()` at the price loop)
- Test: `tests/test_spend_essence.gd`

**Interfaces:**
- Produces: `func spend_essence(element: String, units: int) -> bool` writes `units` entries of `ESSENCE_SPENT` tagged `{"essence": element}`; returns false and writes nothing when `not run_active`, `units <= 0` or `held(element) < units`.

- [ ] **Step 1: Write the failing tests.** Copy the `before_each` and `_absorb` helpers from `tests/test_evolution_price.gd`. Tests: `test_spend_lowers_held_by_exactly_the_units` (absorb water 7, `spend_essence("water", 3)` is true, `held("water")` is 4, `held("dark")` is 0); `test_spend_refuses_more_than_held_and_writes_nothing` (absorb 2, spend 3 is false, `held` still 2, `rules.count(SkillRulesEngine.ESSENCE_SPENT)` is 0); `test_spend_refuses_zero_negative_and_an_inactive_run` (units 0 and -1 are false; after `rules.reset_run()` a spend of 1 is false); `test_spending_makes_an_evolution_unaffordable` (absorb water 12, `can_afford("water_blade")` true, spend 10, then false, which proves the afford memo follows the ledger).
- [ ] **Step 2: Run** `tools/run_tests.sh spend_essence`. Expected: FAIL, `Parse Error` naming `spend_essence`.
- [ ] **Step 3: Implement** `spend_essence` as above, and make `evolve()` call it once per price element instead of its inner loop (`for e in price: spend_essence(e, int(price[e]))`). `can_afford` has already passed, so every call succeeds.
- [ ] **Step 4: Run** `tools/run_tests.sh spend_essence`, then `tools/run_tests.sh evolution`. Expected: PASS for both (the evolution suites are the regression gate for `evolve()`).
- [ ] **Step 5: Commit** `git add scripts/skills tests/test_spend_essence.gd tests/test_spend_essence.gd.uid && git commit -m "feat: SkillRulesEngine.spend_essence, used by evolve()"`.

### Task 2: Species, perk and rules data types

**Files:**
- Create: `scripts/soul/soul_rules.gd`, `scripts/soul/perk_def.gd`, `scripts/soul/species_def.gd`, `scripts/soul/species_unlocks.gd`, `scripts/soul/species_catalog.gd`
- Test: `tests/test_species_unlocks.gd`, `tests/test_perk_def.gd`

**Interfaces:**
- Produces: `SoulRules` (`Resource`): `@export var bank_rate: int = 10`, `level_prices: Array = [2, 3, 4, 5]`, `power_price: int = 3`, `many_deaths: int = 5`.
- Produces: `PerkDef` (`Resource`): `id`, `display_name`, `description: String`, `altar: String`, `price_base: int`, `price_step: int`, `effects: Array` (of `{"stat", "amount"}`); `func price_of(times_bought: int) -> int`.
- Produces: `SpeciesDef` (`Resource`): `id`, `display_name`, `movement_profile: String`, `unlock: Dictionary`.
- Produces: `SpeciesUnlocks.is_unlocked(def: SpeciesDef, records: Dictionary) -> bool` (static). `records` is `{creature_id: {"eaten": int, "defeated": int, ...}}`.
- Produces: `SpeciesCatalog.load_all(dir := "res://data/species") -> Dictionary` (id to `SpeciesDef`, via `DefLoader.load_dir(dir, "SpeciesDef")`) and `SpeciesCatalog.unlocked(catalog: Dictionary, records: Dictionary) -> Array` (the unlocked `SpeciesDef`s, `default`-kind first, then by id).

- [ ] **Step 1: Write the failing tests.** `test_species_unlocks.gd`, with a `_def(unlock)` helper building a `SpeciesDef`: `test_default_is_always_unlocked` (empty records); `test_count_reads_the_larger_of_eaten_and_defeated` (`{"kind":"count","creature":"bat","n":3}`: `{"bat":{"eaten":3,"defeated":3}}` is true; with `n` 5 it is false, since a sum of 6 would wrongly pass; `eaten` 2 and `defeated` 2 with `n` 3 is false); `test_count_edges` (exactly `n` true, one short false, missing record false); `test_defeat_needs_a_defeat_not_an_eat` (`defeated` 1 true; `eaten` 4 and `defeated` 0 false); `test_unknown_kind_is_locked`; `test_unlocked_lists_default_first_then_by_id` (a catalog of three defs, one locked). `test_perk_def.gd`: `test_price_rises_by_the_step` (base 5, step 3 gives 5, 8, 11 for 0, 1, 2).
- [ ] **Step 2: Run** `tools/run_tests.sh species_unlocks` and `perk_def`. Expected: FAIL, `Parse Error` for the missing classes.
- [ ] **Step 3: Implement** the five scripts as specified. `is_unlocked`: `default` true; `count` is `maxi(eaten, defeated) >= n` (the Bestiary raises `defeated` on a kill and `eaten` when its body is eaten, so a sum counts one creature twice); `defeat` is `defeated >= 1`; anything else false. Missing record and missing keys read as 0.
- [ ] **Step 4: Run** the same two commands. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/soul tests/test_species_unlocks.gd* tests/test_perk_def.gd* && git commit -m "feat: species, perk and soul rules definitions with the unlock rules"`.

### Task 3: `SoulProgress` and `Compendium.soul`

**Files:**
- Create: `scripts/soul/soul_progress.gd`
- Modify: `autoload/compendium.gd`
- Test: `tests/test_soul_progress.gd`

**Interfaces:**
- Consumes: `Profile.dict_section("soul")`, `set_section`, `save()`; `PerkDef.price_of` (Task 2).
- Produces: `SoulProgress` (`RefCounted`): `var points: int`, `perks: Dictionary`, `deaths: int`, `session_points: int`; `_init(p_profile = null, known_perks: Array = [])`; `total_points() -> int` (session plus saved); `add(n: int) -> void` (ignores `n <= 0`); `spend(n: int) -> bool` (negative or short is false and spends nothing; 0 is true; takes `session_points` first); `buy_perk(def: PerkDef) -> bool` (spends `def.price_of(perk_count(def.id))`, then raises the count); `perk_count(id: String) -> int`; `note_death() -> void`. Each of `add`, `spend`, `buy_perk`, `note_death` saves.
- Produces: `Compendium.soul: SoulProgress`, built with the profile and the ids of `DefLoader.load_dir("res://data/perks", "PerkDef")`.

- [ ] **Step 1: Write the failing tests.** Copy the temp-profile `before_each`, `after_each` and `_profile()` from `tests/test_world_progress.gd`; add `_perk()` (a `PerkDef` with id `stats`, base 5, step 3). Tests: `test_a_fresh_soul_is_empty`; `test_add_and_spend` (add 5, spend 3 true leaves 2, spend 3 false leaves 2; add 0 and -3 change nothing); `test_session_points_are_spent_first` (`session_points` 4, `points` 3, spend 5 is true, session 0, points 2); `test_buying_a_perk_follows_the_price_curve` (known `["stats"]`, add 20, buys cost 5 then 8, a third at 11 is false with 7 left, `perk_count("stats")` 2); `test_progress_survives_a_reload_but_session_points_do_not` (add, `note_death`, buy a perk, `session_points` 9, then a new `SoulProgress.new(_profile(), ["stats"])` shows the same points, deaths and perks and `session_points` 0); `test_a_malformed_section_loads_as_zero` (set `soul` to an array, to `{"points": -4, "deaths": "x"}`, and to `{"perks": {"gone": 2, "stats": 1, "bad": -1}}` with known `["stats"]`: zeros, then perks `{"stats": 1}`); `test_compendium_has_a_soul` (`Compendium.soul` is not null).
- [ ] **Step 2: Run** `tools/run_tests.sh soul_progress`. Expected: FAIL, `Parse Error` for `SoulProgress`.
- [ ] **Step 3: Implement** `SoulProgress`. Load: a number (int or float) of at least 0 becomes an int, anything else 0; `perks` keeps only known ids with a count above 0. `_save()` sets the `soul` section to `{"points", "perks", "deaths"}` (never `session_points`) and calls `profile.save()`, doing nothing when `profile` is null. Add `var soul: SoulProgress` to `autoload/compendium.gd` and build it in `_ready` after `progress`.
- [ ] **Step 4: Run** `tools/run_tests.sh soul_progress`, then `tools/run_tests.sh autoloads`. Expected: PASS for both.
- [ ] **Step 5: Commit** `git add scripts/soul autoload/compendium.gd tests/test_soul_progress.gd* && git commit -m "feat: SoulProgress, saved as the soul profile section, on the Compendium"`.

### Task 4: `Banking`

**Files:**
- Create: `scripts/soul/banking.gd`
- Test: `tests/test_banking.gd`

**Interfaces:**
- Consumes: `SkillRulesEngine.held`, `spend_essence` (Task 1); `SoulProgress.add` (Task 3); `SoulRules.bank_rate` (Task 2).
- Produces: `static func max_units(rules: SoulRules, engine: SkillRulesEngine, element: String) -> int` (`held` rounded down to a multiple of `bank_rate`, 0 when nothing is held); `static func bank(rules: SoulRules, engine: SkillRulesEngine, soul: SoulProgress, element: String, units: int) -> int` (the points added; 0 with nothing changed when `units <= 0`, not a multiple of `bank_rate`, or above `max_units`).

- [ ] **Step 1: Write the failing tests.** Build the engine as `tests/test_evolution_price.gd` does; `_rules()` is `SoulRules.new()`; `soul` is `SoulProgress.new()`. Tests: `test_max_units_rounds_down_to_the_rate` (held 27 gives 20; held 9 gives 0); `test_bank_converts_at_the_flat_rate` (absorb water 27, bank 20 returns 2, `soul.total_points()` 2, `held("water")` 7); `test_any_element_banks_at_the_same_rate` (dark 10 and earth 10 each give 1); `test_bank_refuses_what_it_cannot_do_and_spends_nothing` (held 27: units 15, 30, 0 and -10 each return 0, `held("water")` stays 27, points stay 0); `test_banking_changes_what_an_evolution_can_afford` (absorb water 12, `can_afford("water_blade")` true, bank 10, then false).
- [ ] **Step 2: Run** `tools/run_tests.sh banking`. Expected: FAIL, `Parse Error` for `Banking`.
- [ ] **Step 3: Implement** `Banking`. `bank` spends through `engine.spend_essence(element, units)` first and adds `units / rules.bank_rate` points only when that returned true.
- [ ] **Step 4: Run** `tools/run_tests.sh banking`. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/soul/banking.gd* tests/test_banking.gd* && git commit -m "feat: Banking turns held essence into soul points at a flat rate"`.

### Task 5: `SoulPerks`

**Files:**
- Create: `scripts/soul/soul_perks.gd`
- Test: `tests/test_soul_perks.gd`

**Interfaces:**
- Consumes: `PerkDef.effects`, `SoulProgress.perk_count`; `player.stats.add_level_bonus`, `player.refresh_stats()`, `player.fill_vitals()`.
- Produces: `static func apply(player: Player, soul: SoulProgress, perks: Array) -> void`: for each `PerkDef` bought at least once, adds `amount * times_bought` per effect through `player.stats.add_level_bonus`; when anything applied, calls `refresh_stats()` then `fill_vitals()`.

- [ ] **Step 1: Write the failing tests.** Build the player as `tests/test_rebirth_kit.gd`'s `before_each` does (rules, compendium, `Player.new()`, `setup`, `add_child_autofree`, `rules.start_run()`). `_stats_perk()` is a `PerkDef` with id `stats`, base 5, step 3, effects `[{"stat":"max_hp","amount":2},{"stat":"max_mp","amount":1}]`. Tests: `test_two_purchases_add_twice_the_effect_and_fill_vitals` (record `player.health.max_hp` and `player.mana.max_mp`, add 13 points, buy twice, wound the player with `player.health.take_hit(1, "physical")` and `player.mana.spend(1)`; after `apply`, `max_hp` is up 4, `max_mp` up 2, `health.hp` equals `max_hp` and `mana.mp` equals `max_mp`); `test_no_perk_bought_leaves_stats_and_vitals_alone` (wound first, `apply`, `health.hp` unchanged); `test_buying_after_apply_does_not_touch_the_live_player` (apply, then buy another, `health.max_hp` unchanged).
- [ ] **Step 2: Run** `tools/run_tests.sh soul_perks`. Expected: FAIL, `Parse Error` for `SoulPerks`.
- [ ] **Step 3: Implement** `SoulPerks.apply`.
- [ ] **Step 4: Run** `tools/run_tests.sh soul_perks`. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/soul/soul_perks.gd* tests/test_soul_perks.gd* && git commit -m "feat: SoulPerks applies bought perks at life start"`.

### Task 6: `HeadStart`

**Files:**
- Create: `scripts/soul/head_start.gd`
- Test: `tests/test_head_start.gd`

**Interfaces:**
- Consumes: `CompendiumModel.state`, `skill_name`, `State.OWNED_ONCE`; `SkillDef.source`, `starting`; `SoulRules` (Task 2); `RebirthKit.validate` in the test.
- Produces: `static func eligible_powers(compendium: CompendiumModel, skill_defs: Array) -> Array` (ids, sorted by `compendium.skill_name`; Owned-once only; never `evolution`, `enemy_only` or `starting`); `static func price(rules: SoulRules, cart: Dictionary) -> int` (the first `levels` entries of `level_prices`, `levels` clamped to `0..level_prices.size()`, plus `power_price` per power); `static func kit(cart: Dictionary) -> Dictionary` (`"skills"` only when powers are bought, `"level": 1 + levels` only when levels are bought, else `{}`); `static func cheapest(rules: SoulRules, power_count: int) -> int` (the cheaper of `level_prices[0]` and, when `power_count > 0`, `power_price`; -1 when nothing is for sale). The cart is `{"levels": int, "powers": Array}`.

- [ ] **Step 1: Write the failing tests.** Load `skills` and `creatures` with `DefLoader.load_dir`, `compendium = CompendiumModel.new(skills, creatures)`. Tests: `test_only_owned_once_base_powers_are_eligible` (raise `leap` to `OWNED_ONCE`, an evolution such as `water_blade` to `OWNED_ONCE` and `hydraulic_propulsion` to `NAMED`; the list holds `leap` only, and `appraisal`, the starting skill, is absent after `compendium.raise("appraisal", CompendiumModel.State.OWNED_ONCE)`); `test_price_sums_the_level_prices_and_powers` (levels 0 is 0, 1 is 2, 3 is 9, 9 clamps to 14; two powers add 6; levels 3 with two powers is 15); `test_kit_has_only_the_keys_in_use` (an empty cart is `{}`; levels 2 is `{"level": 3}`; one power is `{"skills": ["leap"]}`; both has both) and `RebirthKit.validate(kit)` is empty for each; `test_cheapest` (default rules with powers 0 is 2, `level_prices` set to `[]` with 1 power is 3, with 0 powers is -1).
- [ ] **Step 2: Run** `tools/run_tests.sh head_start`. Expected: FAIL, `Parse Error` for `HeadStart`.
- [ ] **Step 3: Implement** `HeadStart` as specified.
- [ ] **Step 4: Run** `tools/run_tests.sh head_start`. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/soul/head_start.gd* tests/test_head_start.gd* && git commit -m "feat: HeadStart prices levels and powers and builds the rebirth kit"`.

### Task 7: `GoddessLines`

**Files:**
- Create: `scripts/soul/goddess_lines.gd`
- Test: `tests/test_goddess_lines.gd`

**Interfaces:**
- Produces: `GoddessLines` (`Resource`): `@export var by_cause: Dictionary` (cause to an Array of Strings), `many_deaths: Array`, `fallback: String`; `func line_for(cause: String, deaths: int, every: int) -> String`. Rule order: (1) `every > 0`, `deaths > 0`, `deaths % every == 0` and a non-empty `many_deaths` give `many_deaths[(deaths / every - 1) % size]`; (2) a non-empty `by_cause[cause]` gives the entry at `posmod(deaths, size)`; (3) `fallback`.

- [ ] **Step 1: Write the failing tests.** `_lines()` builds `by_cause = {"bat": ["b0", "b1"]}`, `many_deaths = ["m0", "m1"]`, `fallback = "f"`. Tests: `test_a_known_cause_cycles_by_death_count` (`line_for("bat", d, 5)` for 1, 2, 3 is `b1`, `b0`, `b1`); `test_the_fifth_death_takes_a_many_deaths_line_even_with_a_cause_line` (5 is `m0`, 10 is `m1`, 15 wraps to `m0`); `test_an_unknown_or_empty_cause_takes_the_fallback` (`"blade"`, `""`); `test_degenerate_inputs_never_crash` (`every` 0 gives the cause line; an empty `many_deaths` on death 5 gives the cause line; deaths 0 gives `b0`; a cause with an empty list gives the fallback).
- [ ] **Step 2: Run** `tools/run_tests.sh goddess_lines`. Expected: FAIL, `Parse Error` for `GoddessLines`.
- [ ] **Step 3: Implement** `GoddessLines` as specified.
- [ ] **Step 4: Run** `tools/run_tests.sh goddess_lines`. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/soul/goddess_lines.gd* tests/test_goddess_lines.gd* && git commit -m "feat: GoddessLines picks her line from cause and death count"`.

### Task 8: `GoddessModel`

**Files:**
- Create: `scripts/soul/goddess_model.gd`
- Test: `tests/test_goddess_model.gd`

**Interfaces:**
- Consumes: `HeadStart.price`, `kit`, `cheapest` (Task 6); `SoulProgress.total_points` (Task 3); `SoulRules` (Task 2).
- Produces: `GoddessModel` (`RefCounted`): `enum Panel { WHERE, WHO, HEAD_START }`; `_init(places: Array, species: Array, powers: Array, soul: SoulProgress, rules: SoulRules, last := {})` where each of `places`, `species`, `powers` is `[{"id": String, "name": String}]` and `last` is `{"pool", "species"}`, which pre-selects the matching rows; `var panel: int`; `var cart := {"levels": 0, "powers": []}`; `switch_panel(step: int)` (wraps); `move(step: int)` (row within the panel, clamped); `row(p: int) -> int`; `rows(p: int) -> Array` (Head start is `[{"kind":"level","levels","max","next_price"}]` then one `{"kind":"power","id","name","taken","price"}` per power; `next_price` is -1 at the maximum); `adjust(step: int)` (Head start only: on the level row it adds or removes a level within `0..level_prices.size()`; on a power row a positive step takes it once and a negative step drops it); `selected_place() -> String`; `selected_species() -> String`; `cost() -> int`; `can_afford() -> bool`; `confirm() -> Dictionary` (`{}` when unaffordable or `places` or `species` is empty, else `{"altar", "species", "kit", "cost"}`; it does not spend); `need_menu() -> bool` (true when there is more than one place or species, or `HeadStart.cheapest(...)` is not -1 and `soul.total_points()` reaches it).

- [ ] **Step 1: Write the failing tests.** `_model(points, place_count := 2)` builds the first `place_count` of the places `C1` and `G1`, species `slime`, one power `leap`, a `SoulProgress` with `points` set, default `SoulRules`. Tests: `test_last_choice_preselects_its_rows` (`last` `{"pool":"G1","species":"slime"}` gives `selected_place()` `G1`); `test_panels_wrap_and_rows_clamp` (switch_panel -1 lands on `HEAD_START`; `move(-1)` at row 0 stays 0; each panel remembers its row); `test_levels_are_bought_up_to_the_cap` (in `HEAD_START`, `adjust(1)` twice gives levels 2 and cost 5; two more reach 4 and a fifth stays 4; `adjust(-1)` six times stops at 0); `test_a_power_is_taken_once_and_dropped` (move to row 1, `adjust(1)` twice leaves `cart["powers"]` as `["leap"]`, `adjust(-1)` empties it); `test_adjust_outside_head_start_does_nothing`; `test_confirm_needs_the_points_and_does_not_spend` (4 points, levels 2: `confirm()` is `{}`; 5 points: `{"altar": "C1", "species": "slime", "kit": {"level": 3}, "cost": 5}` and `soul.total_points()` still 5); `test_an_empty_cart_still_confirms` (0 points gives `kit` `{}`, `cost` 0); `test_need_menu` (`_model(1, 1)` with one species is false; `_model(2, 1)` is true, since 2 reaches the first level's price; `_model(0)` with two places is true).
- [ ] **Step 2: Run** `tools/run_tests.sh goddess_model`. Expected: FAIL, `Parse Error` for `GoddessModel`.
- [ ] **Step 3: Implement** `GoddessModel` as specified; the model builds `HeadStart` cart dictionaries and never mutates `SoulProgress`.
- [ ] **Step 4: Run** `tools/run_tests.sh goddess_model`. Expected: PASS.
- [ ] **Step 5: Commit** `git add scripts/soul/goddess_model.gd* tests/test_goddess_model.gd* && git commit -m "feat: GoddessModel, the pure state of the rebirth scene"`.

### Task 9: `SoulValidator`, the generator and the shipped data

**Files:**
- Create: `scripts/soul/soul_validator.gd`, `tools/build_soul.gd`, `data/species/slime.tres`, `data/perks/stats.tres`, `data/soul/soul_rules.tres`, `data/goddess/lines.tres`
- Test: `tests/test_soul_validator.gd`, `tests/test_soul_data.gd`

**Interfaces:**
- Produces: `SoulValidator.validate(species: Array, perks: Array, rules: SoulRules, lines: GoddessLines, creature_ids: Array, movement_dir := "res://data/movement") -> PackedStringArray` (static; empty means valid). Errors: a species with an unknown `unlock` kind, a `count` or `defeat` naming an unknown creature, a `count` with a missing or non-positive `n`, a duplicate species id, no `default` species, a non-empty `movement_profile` with no `<movement_dir>/<id>.tres`; a perk with a duplicate id, a `price_base` of 0 or less, a negative `price_step`, an effect whose stat is not a key of `Stats.DEFAULTS` or whose amount is 0; rules with `bank_rate`, `power_price` or any level price of 0 or less, empty `level_prices`, or `many_deaths` below 2; lines with a `by_cause` key that is not a creature id (other than `water_pool`) or `poison` or `spear`, an empty or blank entry, an empty `many_deaths` list or a blank `fallback`.

- [ ] **Step 1: Write the failing tests.** `test_soul_validator.gd` builds one valid fixture set in `_good()` and a test per error above (each mutates one field and asserts the message list is non-empty and mentions the field); `test_the_good_fixtures_validate_clean`. `test_soul_data.gd`: loads the shipped species, perks, rules and lines with `DefLoader.load_dir` (and `load` for the two single resources) and `creature_ids` from `DefLoader.load_dir("res://data/creatures")`; `test_the_shipped_data_validates_clean`; `test_slime_is_the_default_species_with_a_movement_profile` (`slime.unlock` is `{"kind": "default"}`, `FileAccess.file_exists("res://data/movement/slime.tres")`); `test_every_cause_has_a_line` (all 18 creature ids except `water_pool`, plus `poison` and `spear`, have a non-empty list in `by_cause`).
- [ ] **Step 2: Run** `tools/run_tests.sh soul_validator` and `soul_data`. Expected: FAIL, `Parse Error` for `SoulValidator`.
- [ ] **Step 3: Implement** `SoulValidator`, then `tools/build_soul.gd` in the style of `tools/build_forms.gd` (`extends SceneTree`, builds the four resources with `ResourceSaver.save`, `quit(1)` on a save error). Data: `slime` (display `Slime`, `movement_profile` `slime`, unlock `{"kind": "default"}`); `stats` (display `Stronger base stats`, description `+2 max HP and +1 max MP for every purchase, from your next life.`, altar `C1`, the Global Constraints numbers); the default `SoulRules`; and the lines: one entry per cause in `by_cause` (second person, her voice dry and kind rather than cruel, under 90 characters, naming the cause plainly, for example bat: `A bat. Of all the things.`), three `many_deaths` lines about how often this happens, and one `fallback`. Run it once: `env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_soul.gd`, then `godot --headless --import`.
- [ ] **Step 4: Run** `tools/run_tests.sh soul_validator`, `soul_data`, then the full suite once: `TEST_TIMEOUT=900 tools/run_tests.sh`. Expected: PASS everywhere, with no `SCRIPT ERROR`.
- [ ] **Step 5: Commit** `git add scripts/soul tools/build_soul.gd* data/species data/perks data/soul data/goddess tests/test_soul_validator.gd* tests/test_soul_data.gd* && git commit -m "feat: SoulValidator, the soul data generator and the shipped soul data"`.
