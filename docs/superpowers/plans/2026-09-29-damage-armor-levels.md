# Damage, Armor and Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat DEF subtraction with a hyperbolic, hit-relative armor percentage (physical only), let poison ignore DEF and Poison Resistance reach ticks (fractionally, with a carry), scale the direct-damage skills with ATK, and derive the Grotto creatures' numbers from a level in the content generator.

**Architecture:** One pure `Damage.hit(power, damage_type, defense, resist_pct, flat_off)` replaces `direct_hit`; `Damage.tick_milli` replaces `tick` with a persistent carry on the `Player`; `Damage.skill_power` amplifies three abilities through `Ability.actor_atk()`; `tools/build_content.gd` gains `_at_level` for four creatures and regenerates the `.tres` files. No runtime level code.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-29-damage-armor-levels-design.md`

## Global Constraints

- Run tests with `tools/run_tests.sh [substr]` from `/Users/sean/sites/isekai-game/.worktrees/damage-levels`; a SCRIPT ERROR fails the run. After adding a `class_name` script, run `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1`.
- Regenerate content with `godot --headless -s tools/build_content.gd` (with `HOME="$PWD/.tmp/gdhome"`, as `tools/build_world.gd`'s header shows) and stage the resulting `data/` files.
- Constants from the spec, verbatim: `ARMOR_PER_HIT` 80, `RESIST_CAP` 95, `SKILL_ATK_PCT` 25, `MILLI` 1000, level power 8% per level with `+50` rounding, Grotto level 4.
- Find code by symbol; line numbers in the spec drift.
- A test that pauses nothing here; tests that need a fresh `Player` build one as `tests/test_player.gd` does.
- No attribution lines in commit messages. Stage directories (`git add scripts tests tools data docs`) so `.gd.uid` files the import wrote are included.
- Poison spits in a test are each applied after the previous poison has run out (`Enemy.SPIT_SECONDS`, three `tick(1.0)` calls), which also clears the 1 s invulnerability.

## Review Focus

1. A physical or poison hit on a slime with DEF 0 and no resistance changing at ATK 1 (the identity the spec promises for damage taken).
2. Healing Spores, Binding Web or any cloud gaining damage from ATK (clouds stay a fixed 1; only Poison Breath, Water Blade, Venom Bolt amplify; Miasma's cone exactly once).
3. The weak point (`ignore_def`) losing its DEF bypass, or the crab weak-point tests being weakened instead of re-derived.
4. The poison carry being reset by a new application, or a whole HP drawn at HP 1 not being consumed.
5. Regeneration changing a Cave creature or any file beyond the four Grotto creatures and the three edited skills.
6. The Skills tab amplifying radius, distance or hold lines, or `SkillScreen` not passing the player's ATK.

## File Map

- Modify: `scripts/stats/damage.gd`, `scripts/player/player.gd` (`receive_hit`, `tick`, a new `_poison_milli`), `scripts/enemies/enemy.gd` (`receive_hit`, a comment), `scripts/abilities/ability.gd` (`actor_atk`), `scripts/abilities/poison_breath.gd`, `water_blade.gd`, `venom_bolt.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/skill_screen.gd`, `tools/build_content.gd`, `data/creatures/{mushroom_crab,vine_snake,spore_moth,pale_moth}.tres`, `data/skills/{body_armor,poison_resistance,poison_spit}.tres`, `docs/playtest-checklist.md`.
- Tests: create `tests/test_damage.gd`, `tests/test_poison_carry.gd`; modify `tests/test_stats.gd`, `tests/test_enemy.gd`, `tests/test_grotto_data.gd`, `tests/test_pale_moth.gd`, `tests/test_skill_screen.gd`, and any pin the full suite turns red for a number the spec changes.

---

### Task 1: `Damage.hit`, armor and the physical/poison split

**Files:**
- Modify: `scripts/stats/damage.gd`, `scripts/player/player.gd` (`receive_hit`), `scripts/enemies/enemy.gd` (`receive_hit`), `tests/test_stats.gd`
- Create: `tests/test_damage.gd`

**Interfaces:**
- Produces: `Damage.ARMOR_PER_HIT := 80`, `Damage.RESIST_CAP := 95`, `Damage.armor_pct(defense: int, power: int) -> int`, `Damage.hit(power: int, damage_type: String, defense: int, resist_pct: int, flat_off: int) -> int`. `Damage.direct_hit` is deleted (`Damage.tick` stays until Task 2).

- [ ] **Step 1: Write the failing tests** (`tests/test_damage.gd`)

```gdscript
extends GutTest
## Damage.hit: DEF is a hyperbolic percent of the hit's size for physical hits only; resistance percent (clamped at 95)
## applies to any type; flat reductions subtract; minimum 1.

func test_a_hit_at_def_zero_and_no_resistance_is_the_power_itself() -> void:
	for p in [1, 2, 5, 9, 16]:
		assert_eq(Damage.hit(p, "physical", 0, 0, 0), p)
		assert_eq(Damage.hit(p, "poison", 0, 0, 0), p)

func test_armor_is_a_percent_relative_to_the_hit() -> void:
	assert_eq(Damage.armor_pct(4, 5), 50)
	assert_eq(Damage.armor_pct(1, 5), 20)
	assert_eq(Damage.armor_pct(2, 5), 33)
	assert_eq(Damage.armor_pct(0, 5), 0)
	assert_eq(Damage.armor_pct(3, 0), 0)
	assert_eq(Damage.hit(40, "physical", 30, 0, 0), 20)

func test_armor_never_reaches_a_hundred_percent() -> void:
	assert_lt(Damage.armor_pct(100000, 1), 100)

func test_hit_is_monotone_in_def_and_in_power() -> void:
	for power in range(1, 61):
		var last := 1000
		for def in range(0, 81):
			var h := Damage.hit(power, "physical", def, 0, 0)
			assert_lte(h, last, "power %d def %d" % [power, def])
			last = h
	for def in range(0, 41):
		var last := 0
		for power in range(1, 61):
			var h := Damage.hit(power, "physical", def, 0, 0)
			assert_gte(h, last, "power %d def %d" % [power, def])
			last = h

func test_poison_ignores_def() -> void:
	assert_eq(Damage.hit(4, "poison", 3, 0, 0), 4)
	assert_eq(Damage.hit(9, "poison", 50, 0, 0), 9)

func test_resistance_applies_to_any_type_and_is_clamped_at_95() -> void:
	assert_eq(Damage.hit(10, "poison", 0, 50, 0), 5)
	assert_eq(Damage.hit(100, "poison", 0, 113, 0), 5, "113% behaves as 95%; a clamp of 100 would give 1")
	assert_eq(Damage.hit(4, "physical", 0, 20, 0), 3)  # 3.2 -> 3

func test_flat_reductions_subtract_after_the_percents_with_a_minimum_of_one() -> void:
	assert_eq(Damage.hit(6, "physical", 0, 0, 1), 5)
	assert_eq(Damage.hit(3, "physical", 0, 0, 5), 1)
	assert_eq(Damage.hit(10, "physical", 0, 90, 0), 1)

## ATK 1..5 against DEF 0..3: the old flat model, as literal expected values.
func test_the_legacy_grid_matches_except_one_cell() -> void:
	var old := {  # atk -> [def 0, def 1, def 2, def 3]
		1: [1, 1, 1, 1], 2: [2, 1, 1, 1], 3: [3, 2, 1, 1], 4: [4, 3, 2, 1], 5: [5, 4, 3, 2]}
	for atk in old:
		for def in 4:
			var want: int = old[atk][def]
			if atk == 4 and def == 3:
				want = 2  # the one intended difference: 4 x 52 / 100
			assert_eq(Damage.hit(atk, "physical", def, 0, 0), want, "atk %d def %d" % [atk, def])

func test_the_accepted_physical_rows() -> void:
	assert_eq(Damage.hit(4, "physical", 3, 0, 0), 2, "spider vs DEF 3")
	for def in [4, 5, 6]:
		assert_eq(Damage.hit(5, "physical", def, 0, 0), 2, "lizard vs DEF %d" % def)
	assert_eq(Damage.hit(6, "physical", 1, 0, 0), 4, "serpent vs DEF 1")
	assert_eq(Damage.hit(1, "physical", 3, 0, 0), 1, "a plain tackle vs the lizard")
	assert_eq(Damage.hit(4, "physical", 3, 0, 0), 2, "tackle at ATK 4 vs the lizard")
```

In `tests/test_stats.gd` port the five `direct_hit` pins (leave the four `tick` pins for Task 2): replace `test_direct_hit_percent_then_flat_then_floor_min_one` with

```gdscript
func test_hit_percent_then_flat_then_floor_min_one() -> void:
	assert_eq(Damage.hit(4, "physical", 0, 20, 0), 3)    # 3.2 -> 3
	assert_eq(Damage.hit(4, "physical", 0, 80, 0), 1)    # 0.8 -> min 1
	assert_eq(Damage.hit(3, "physical", 0, 0, 5), 1)     # flat above the damage -> min 1
	assert_eq(Damage.hit(6, "physical", 0, 0, 1), 5)     # the flat argument, not DEF: DEF 1 would be the serpent row (4)
	assert_eq(Damage.hit(10, "physical", 0, 90, 0), 1)   # integer math, no 0.999 error
```

Add player and enemy rows to `tests/test_damage.gd` (build a `Player` and an `Enemy` the way `tests/test_player.gd` and `tests/test_enemy.gd` do):
- a real `Player` with DEF 3 (`player.stats.set_modifiers("t", [{"stat": "def", "op": "add", "value": 3}])`) takes 2 from `receive_hit(4, "physical")`, and takes 4 from `receive_poison(4, 1, 3.0)`'s application (the 1 s invulnerability aside, read the HP drop from the application alone); with DEF 0 both take exactly the raw amount;
- a real toad-spit application on a DEF-5 player with Poison Resistance L1 costs 3 (`receive_hit(4, "poison")` with the resistance modifier `{"stat": "damage_taken", ...}` as `tests/test_player_skill_set.gd` builds it; copy that test's setup);
- an `Enemy` lizard (DEF 3): `receive_hit(5, "poison")` deals 5 (poison ignores DEF), `receive_hit(4, "physical")` deals 2; `receive_hit(4, "physical", Vector2.INF, "", true)` (`ignore_def`) deals the full 4.

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_damage` then `tools/run_tests.sh test_stats`
Expected: FAIL (Parse Error: `Damage.hit` and `Damage.armor_pct` not found).

- [ ] **Step 3: Implement**

`scripts/stats/damage.gd`:

```gdscript
const ARMOR_PER_HIT := 80
const RESIST_CAP := 95

## DEF as a percent of the hit's size: never 100%, no plateau. Physical hits only (see hit()).
static func armor_pct(defense: int, power: int) -> int:
	if defense <= 0 or power <= 0:
		return 0
	return floori(10000.0 * defense / (100 * defense + ARMOR_PER_HIT * power))

## One resolution for every hit: armor (physical only) and resistance multiply, then the flat reductions subtract; at least 1.
static func hit(power: int, damage_type: String, defense: int, resist_pct: int, flat_off: int) -> int:
	var armor := armor_pct(defense, power) if damage_type == "physical" else 0
	var through := (100 - armor) * (100 - clampi(resist_pct, 0, RESIST_CAP))
	return maxi(1, floori(float(power * through) / 10000.0) - flat_off)
```

Delete `direct_hit`. In `Player.receive_hit`: `health.take_hit(Damage.hit(raw, damage_type, stats.get_stat("def"), m["percent_off"], m["flat_off"]), damage_type)`. In `Enemy.receive_hit`: `health.take_hit(Damage.hit(raw, damage_type, 0 if ignore_def else stats.get_stat("def"), 0, 0), damage_type)` and update the header comment (enemies do not read their own resistances yet).

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_damage`, `test_stats`, `test_player`, `test_enemy`, `test_tuning`, `test_player_skill_set`, `test_skill_effects`, `test_hit_fairness`.
Expected: all PASS (every existing hit is at DEF 0 or a listed accepted row; a failure is a finding, not a test to weaken).

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools data docs
git commit -m "feat: damage resolves through one hit function with hyperbolic physical armor and poison that ignores DEF"
```

---

### Task 2: Fractional poison ticks with a carry

**Files:**
- Modify: `scripts/stats/damage.gd`, `scripts/player/player.gd` (`tick`, `_poison_milli`), `tests/test_stats.gd`
- Create: `tests/test_poison_carry.gd`

**Interfaces:**
- Produces: `Damage.MILLI := 1000`, `Damage.tick_milli(raw: int, resist_pct: int) -> int` (thousandths of an HP per second); `Player._poison_milli` (initialised 0, separate from `_poison_acc`, never reset by `receive_poison`). `Damage.tick` is deleted.

- [ ] **Step 1: Write the failing tests**

Port the four `tick` pins in `tests/test_stats.gd` (rename the test, it no longer "may reach zero"):

```gdscript
func test_tick_milli_takes_percent_only_in_thousandths() -> void:
	assert_eq(Damage.tick_milli(2, 0), 2000)
	assert_eq(Damage.tick_milli(2, 35), 1300)
	assert_eq(Damage.tick_milli(2, 65), 700)   # not 0: the fraction is carried
	assert_eq(Damage.tick_milli(10, 90), 1000)
	assert_eq(Damage.tick_milli(1, 20), 800)
	assert_eq(Damage.tick_milli(1, 100), 50, "clamped at 95%; a clamp of 100 would give 0")
```

`tests/test_poison_carry.gd` (fixture as `tests/test_player.gd`: a real `Player`, `rules.start_run()`; a helper `_spit()` calls `player.receive_poison(4, 1, 3.0)` and a helper `_run_out()` calls `player.tick(1.0)` three times; a helper `_resist(pct)` gives the player that percent of poison damage reduction the way `tests/test_player_skill_set.gd` does, without levelling a real skill; each test asserts the player's Poison Resistance level did not change):

```gdscript
func test_a_toad_spit_at_no_resistance_costs_its_application_and_three_ticks() -> void:
	var hp := player.health.hp
	_spit()
	_run_out()
	assert_eq(hp - player.health.hp, 4 + 3)

func test_toad_spit_ticks_at_20_percent_cost_two_hp_from_a_fresh_player() -> void:
	_resist(20)
	_spit()
	var after_application := player.health.hp
	_run_out()
	assert_eq(after_application - player.health.hp, 2, "800, 1600 -> 1, 1400 -> 1")

func test_two_spits_at_67_percent_cost_one_hp_of_ticks_and_the_carry_survives() -> void:
	_resist(67)
	_spit()
	_run_out()
	_spit()
	var after_second_application := player.health.hp
	_run_out()
	# ticks: 330,660,990 (0 HP) then 1320 -> 1 (320), 650, 980 -> 1 HP in total
	assert_eq(player._poison_milli, 980)

func test_three_spits_at_67_percent_cost_two_hp_of_ticks_with_970_carried() -> void:
	_resist(67)
	var applications := 0
	var tick_hp := 0
	for i in 3:
		var before := player.health.hp
		_spit()
		applications += before - player.health.hp
		var after := player.health.hp
		_run_out()
		tick_hp += after - player.health.hp
	assert_eq(applications, 3, "each application is max(1, 4 x 33 / 100)")
	assert_eq(tick_hp, 2)
	assert_eq(player._poison_milli, 970)

func test_a_moth_puff_at_20_percent_costs_one_hp_of_ticks() -> void:
	_resist(20)
	player.receive_poison(1, 1, 2.0)
	var after := player.health.hp
	player.tick(1.0)
	player.tick(1.0)
	assert_eq(after - player.health.hp, 1, "800 then 1600 -> 1 HP, 600 carried")

func test_a_whole_hp_drawn_at_one_hp_is_consumed() -> void:
	_resist(0)
	player.health.hp = 1
	player.receive_poison(1, 1, 2.0)  # the application cannot go below 1 either
	player.tick(1.0)
	assert_eq(player.health.hp, 1, "ticks never kill")
	assert_eq(player._poison_milli, 0, "the whole HP was consumed, not banked")

func test_receive_poison_never_resets_the_carry_but_does_reset_the_tick_clock() -> void:
	_resist(67)
	_spit()
	player.tick(1.0)
	var carried := player._poison_milli
	player.tick(1.0)  # invulnerability over
	player.tick(1.0)
	assert_gt(carried, 0)
	_spit()
	assert_gte(player._poison_milli, carried, "a new application keeps the fraction")
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_poison_carry`
Expected: FAIL (Parse Error: `tick_milli`, `_poison_milli`).

- [ ] **Step 3: Implement**

`scripts/stats/damage.gd`: delete `tick` and add

```gdscript
const MILLI := 1000

## A poison tick in thousandths of an HP per second: Poison Resistance reaches 1-point ticks instead of deleting them.
static func tick_milli(raw: int, resist_pct: int) -> int:
	return floori(float(raw * (100 - clampi(resist_pct, 0, RESIST_CAP)) * MILLI) / 100.0)
```

`Player`: add `var _poison_milli := 0` beside `_poison_acc` (with a comment: carried across applications; a new life is a new `Player`), and in `tick` replace the `Damage.tick` line with:

```gdscript
			var m := skillset.incoming("poison", health.hp, health.max_hp)
			_poison_milli += Damage.tick_milli(_poison_tick, m["percent_off"])
			var whole := floori(float(_poison_milli) / float(Damage.MILLI))
			_poison_milli -= whole * Damage.MILLI
			health.take_tick(whole)
```

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_poison_carry`, `test_stats`, `test_player`, `test_tuning`, `test_enemy_traces`, `test_spore_moth`, `test_toad`.
Expected: all PASS (`test_poison_application_then_ticks_floor_at_one` still reads 26 then 20: 2000 a second).

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools data docs
git commit -m "feat: poison ticks are fractional with a carry, so Poison Resistance reaches 1-point ticks"
```

---

### Task 3: Skills scale with ATK

**Files:**
- Modify: `scripts/stats/damage.gd`, `scripts/abilities/ability.gd`, `scripts/abilities/poison_breath.gd`, `water_blade.gd`, `venom_bolt.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/skill_screen.gd`, `tests/test_damage.gd`, `tests/test_skill_screen.gd`

**Interfaces:**
- Produces: `Damage.SKILL_ATK_PCT := 25`, `Damage.skill_power(value: int, atk: int) -> int`, `Ability.actor_atk() -> int` (the actor's `stats` ATK read with `actor.get("stats")`, 1 for a stub), `SkillScreenModel.detail(rules, d, slots, atk := 1)` and `SkillScreenModel.effect_lines(d, level, atk := 1)` (amplifying only the line labelled "Damage").

- [ ] **Step 1: Write the failing tests**

In `tests/test_damage.gd`:

```gdscript
func test_skill_power_is_the_table_at_atk_1_and_grows_25_percent_per_point() -> void:
	for v in [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16]:  # every Poison Breath value, Water Blade's 3, Venom Bolt's 9
		assert_eq(Damage.skill_power(v, 1), v)
	assert_eq(Damage.skill_power(16, 8), 44)
	assert_eq(Damage.skill_power(16, 3), 24)
	assert_eq(Damage.skill_power(2, 3), 3)
	assert_eq(Damage.skill_power(9, 3), 13)
	assert_eq(Damage.skill_power(1, 5), 2, "why the clouds do not use it: the value 1 is all rounding cliff")
	assert_eq(Damage.skill_power(3, 0), 3, "ATK below 1 is treated as 1")
```

Ability tests (a new `tests/test_skill_atk.gd`; a stub actor as `tests/test_abilities.gd` builds one for the identity checks, and a real `Player` for the integration):

- identity: with a stub actor without `stats`, Poison Breath, Water Blade and Venom Bolt deal their table values (the existing `test_abilities.gd` / `test_evolution_abilities.gd` pins stay green);
- a stub actor whose `stats` exposes `get_stat("atk")` returning 3: Poison Breath L1 (`[2, ...]`) deals 3; Venom Bolt (9) deals 13; Water Blade (3) deals 4; **Miasma's cone deals 13 (9 at ATK 3), once, not 19**;
- at ATK 5, Spore Cloud, Miasma's cloud and Puffball still launch clouds with `damage` 1 (read the zone's damage as `tests/test_zone.gd` and `tests/test_spore_cloud.gd` do), and Healing Spores and Binding Web still 0;
- a real `Player` at ATK 3 (`player.stats.set_modifiers("t", [{"stat": "atk", "op": "add", "value": 2}])`) casting Poison Breath L1 at a real toad (HP 3, Poison Resistance not read): the toad takes 3.

Skills tab tests in `tests/test_skill_screen.gd`: `SkillScreenModel.effect_lines(d, level, atk)` for Poison Breath at ATK 5 shows "Damage 4" at level 1 (2 x 200 / 100), while Spore Cloud's "Radius" line and Hydraulic Propulsion's "Distance %" are unchanged at any ATK, and `effect_lines(d, level)` (two arguments) still works; a bound `SkillScreen` with the player's ATK raised shows the amplified "Damage" text (open the screen with Poison Breath owned and selected, as that file's other tests do, and read `screen.detail_texts()`).

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_damage`, `test_skill_atk`, `test_skill_screen`
Expected: FAIL (`skill_power`, `actor_atk`, the extra `effect_lines` argument not found).

- [ ] **Step 3: Implement**

`Damage`: `const SKILL_ATK_PCT := 25` and

```gdscript
## A direct-damage skill's table value amplified by the caster's ATK: ATK 1 is the table exactly.
static func skill_power(value: int, atk: int) -> int:
	return maxi(1, floori(float(value * (100 + SKILL_ATK_PCT * (maxi(atk, 1) - 1))) / 100.0))
```

`Ability`:

```gdscript
## The caster's ATK, 1 for an actor without stats (test stubs). Read with get() so a stub needs no property.
func actor_atk() -> int:
	var s = actor.get("stats")
	return int(s.get_stat("atk")) if s != null else 1
```

`poison_breath.gd`: `t.receive_hit(Damage.skill_power(value(), actor_atk()), "poison", actor.global_position, "poison")`. `water_blade.gd`: `targets[0].receive_hit(Damage.skill_power(value(), actor_atk()), "physical", actor.global_position, "blade")`. `venom_bolt.gd`: `t.receive_hit(Damage.skill_power(value(), actor_atk()), "poison", from, "poison")`. Do not touch `miasma.gd`, `spore_cloud.gd`, `puffball.gd`, `healing_spores.gd` or `binding_web.gd` (Miasma calls `super._perform()`, so its cone amplifies once; the clouds stay fixed).

`SkillScreenModel.effect_lines(d, level, atk := 1)`: when the active label is `"Damage"`, `v = Damage.skill_power(v, atk)`; `detail(rules, d, slots, atk := 1)` passes `atk` through. In `skill_screen.gd` where it calls `SkillScreenModel.detail(_rules, d, _player.skillset.slots)` pass `int(_player.stats.get_stat("atk"))`.

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_damage`, `test_skill_atk`, `test_skill_screen`, `test_hardened_shell`, `test_spore_cloud`, `test_abilities`, `test_evolution_abilities`, `test_zone`, `test_aiming`, `test_form_effects`.
Expected: all PASS.

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools data docs
git commit -m "feat: Poison Breath, Water Blade and Venom Bolt scale with ATK; the Skills tab shows it"
```

---

### Task 4: The Grotto at level 4, the skill descriptions, regeneration

**Files:**
- Modify: `tools/build_content.gd`, `data/creatures/{mushroom_crab,vine_snake,spore_moth,pale_moth}.tres`, `data/skills/{body_armor,poison_resistance,poison_spit}.tres` (regenerated), `scripts/enemies/enemy.gd` (one comment), `tests/test_grotto_data.gd`, `tests/test_pale_moth.gd`, `tests/test_enemy.gd`

**Interfaces:**
- Produces: `static func _at_level(level: int, stats: Dictionary) -> Dictionary` and `static func _scaled(base: int, level: int) -> int` in `tools/build_content.gd`.

- [ ] **Step 1: Write the failing tests** (RED = the pins for the new numbers, before regenerating)

`tests/test_grotto_data.gd` `want`: moth `[4, 1, 0, 90, 2, ...]`, crab `[10, 2, 2, 70, 4, ...]`, snake `[6, 4, 0, 150, 3, ...]`. `tests/test_pale_moth.gd:23` becomes `[7, 1, 0, 110, 8]`.

`tests/test_enemy.gd` crab weak-point tests, re-derived (do not weaken any; each number follows from HP 10, DEF 2):

```gdscript
func test_a_front_tackle_on_an_armored_enemy_still_does_one() -> void:
	var crab := _enemy("mushroom_crab")  # HP 10, DEF 2
	crab.receive_tackle(1, false)
	assert_eq(crab.health.hp, 9, "ATK 1 against DEF 2 is 29% of 1, floored, then the minimum of 1")
	assert_eq(crab.status.state, EnemyStatus.ACTIVE, "an armored front is not stunned")

func test_a_tackle_from_behind_ignores_armor_and_does_double() -> void:
	var crab := _enemy("mushroom_crab")
	crab.receive_tackle(1, true)
	assert_eq(crab.health.hp, 8, "ATK 1 x2, DEF ignored")
	...  # the lizard half is unchanged

func test_a_stunned_enemy_takes_the_weak_point_hit_from_the_front() -> void:
	var crab := _enemy("mushroom_crab")
	crab.receive_tackle(1, true)  # stunned from behind: 10 -> 8
	crab.receive_tackle(1, false)  # a front tackle on a stunned crab
	assert_eq(crab.health.hp, 6)

func test_a_stunned_crab_falls_in_five_tackles_within_its_stun() -> void:
	assert_lt(4.0 * Player.TACKLE_SECONDS, EnemyStatus.STUN_SECONDS)
	var crab := _enemy("mushroom_crab")
	crab.receive_tackle(1, true)
	for i in 4:
		assert_eq(crab.status.state, EnemyStatus.STUNNED, "still stunned before front tackle %d" % (i + 1))
		crab.status.update(Player.TACKLE_SECONDS)
		crab.receive_tackle(1, false)
	assert_eq(crab.status.state, EnemyStatus.DYING, "10 HP: 2 + 2 + 2 + 2 + 2")
```

Add a content-generation pin `tests/test_grotto_data.gd`: `_scaled` values via the `.tres` (`scaled(8,4)==10` etc. are the pins above) and that the Cave creature stats are unchanged (bat `[2,3,0,140]`, toad `[3,3,0,70]`, lizard `[5,5,1,80]`, spider `[3,4,0,110]`).

Skill description pins: the regenerated Poison Spit description reads "4 poison on hit, then 1 per second for 3 s." (add to the toad/spit test that pins descriptions, or a small new assertion in `tests/test_grotto_data.gd`'s neighbour); Body Armor contains "physical"; Poison Resistance contains "over time".

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_grotto_data`, `test_pale_moth`, `test_enemy`
Expected: FAIL (the data still has the level-1 numbers).

- [ ] **Step 3: Implement**

In `tools/build_content.gd` add:

```gdscript
## A creature's stats at a level: max_hp, atk and def (the keys present) scaled by 8% a level, rounded half up; SPD and the
## rest are untouched. Level 1 is the identity, and 0 stays 0.
static func _at_level(level: int, stats: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	for key in ["max_hp", "atk", "def"]:
		if out.has(key):
			out[key] = _scaled(int(out[key]), level)
	return out

static func _scaled(base: int, level: int) -> int:
	return floori(float(base * (100 + 8 * (maxi(level, 1) - 1)) + 50) / 100.0)
```

(`build_content.gd` extends `SceneTree`; if `static` helpers cannot be called from the instance method that builds the array in this repo's idiom, make them instance methods like `_cr`.) Wrap the `"stats"` dictionary of the four Grotto entries: `"stats": _at_level(4, {"max_hp": 8, "atk": 2, "def": 2, "spd": 70})` (crab), `_at_level(4, {"max_hp": 5, "atk": 3, "def": 0, "spd": 150})` (snake), `_at_level(4, {"max_hp": 3, "atk": 1, "def": 0, "spd": 90})` (spore moth), `_at_level(4, {"max_hp": 6, "atk": 1, "def": 0, "spd": 110})` (pale moth). Edit three skill descriptions: Body Armor `"Raise DEF against physical damage."`, Poison Resistance `"Take less poison damage, and less from poison over time."`, Poison Spit `"4 poison on hit, then 1 per second for 3 s."`. Update the stale comment in `Enemy` ("a Mushroom Crab would take eight" -> "ten"). Regenerate: `env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd`.

Proof of a clean regeneration: `git status --short data/` lists exactly the four Grotto creature files and the three skill files, and `git diff --stat data/creatures/bat.tres data/creatures/toad.tres data/creatures/lizard.tres data/creatures/spider.tres data/creatures/water_pool.tres data/creatures/serpent.tres` prints nothing. Regenerating twice gives no further change.

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_grotto_data`, `test_pale_moth`, `test_enemy`, `test_enemy_traces`, `test_compendium_model`, `test_status_text`, then the full suite `tools/run_tests.sh`. A red pin whose number is a Grotto creature's is re-derived from the spec's table (a failure for any other reason is a finding).
Expected: PASS.

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add scripts tests tools data docs
git commit -m "feat: the Grotto creatures are level 4, generated from their base numbers; skill descriptions say what DEF and poison do now"
```

---

### Task 5: Playtest checklist and the whole suite

**Files:** `docs/playtest-checklist.md`

- [ ] **Step 1:** Add checklist lines: DEF now helps against big hits by a percentage and never fully cancels one; poison ignores DEF; Poison Resistance reduces ticks; Poison Breath, Water Blade and Venom Bolt hit harder as ATK rises (the Skills tab shows the ATK-amplified "Damage"); Body Armor no longer protects against toad spit; a Grotto Mushroom Crab has 10 HP and falls to five weak-point tackles within its stun.
- [ ] **Step 2:** Run the full suite `tools/run_tests.sh`. Expected: PASS.
- [ ] **Step 3: Commit**

```bash
git add docs
git commit -m "docs: playtest lines for the damage and armor model"
```

---

## Final steps

Whole-branch review with an opus reviewer (`review-package` per the skill; give it the Review Focus above verbatim and the spec), one fix pass (each fix RED to GREEN, suite green), then `finishing-a-development-branch`: merge to `main`, run the full suite on the merged tree, push, relaunch the game.
