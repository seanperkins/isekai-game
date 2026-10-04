# Essence Overhaul, Part 3: Price, Held Essence and the End of EP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolving a power costs an authored price in the elements it runs on, paid from essence the player holds; Evolution Points are gone; the HUD says when an evolution is ready and affordable; the status screens show what is held.

**Architecture:** Spending is a ledger entry (`essence_spent`, one per unit, written directly with `_ledger.record`, deliberately outside `Events.ALL` and `Events.INTERNAL`), so `held = ABSORBED − essence_spent` is a projection of the one per-life log and `reset_run()` clears it with everything else. `evolution_price` lives once on each base power (four of them); its branches read it through `replaces`. `can_afford` is memoized on the ledger's size and cleared by `reset_run()`.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`), Python 3 for one data edit.

**Spec:** `docs/superpowers/specs/2026-10-03-essence-overhaul-design.md` (approved by Sean; the "Eaten and held", "Price", "Who pays", "EP", "Evolving" and "Display" rows and `Sequencing` step 3). Parts 1 and 2 must be merged first (this part uses `Essences.ALL`, the element thresholds, `TestDefs.satisfy`, and `FormOffers.offers(forms, form, rules)`).

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. A SCRIPT ERROR or Parse Error fails the whole run; a member read by another file must be removed in the same task as its readers. Content is generated: edit `tools/build_content.gd`, then run `env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd`. No new `class_name` script is added in this part.
- Prices (starting values, tuned by play), on the base power only: Hydraulic Propulsion `{"water": 6}` · Poison Breath `{"water": 6, "dark": 10}` · Spore Cloud `{"air": 6, "dark": 12}` · Sticky Thread `{"dark": 14}`. Every evolution branch reads its parent's price; no other skill carries one. Target: a Cave and Grotto full clear affords any one family's evolution but not all three dark evolutions (the review counted dark 29 against 10 + 12 + 14 = 36).
- `essence_spent` is a constant on `SkillRulesEngine` (`const ESSENCE_SPENT := "essence_spent"`). It is NOT added to `Events.ALL` (that would break `tests/test_constants.gd` and `tests/test_audio_catalog.gd` and let a skill count it) and NOT to `Events.INTERNAL` (`_drain` skips recording internal events). It is written with `_ledger.record`, never through `handle_event`, and never emitted on `EventBus`.
- `held(element) = count(ABSORBED, {essence}) − count(ESSENCE_SPENT, {essence})`. Recipes read eaten (`ABSORBED`), so spending never undoes an unlock.
- `evolution_ready` still fires once when the conditions are met; affordability is a separate question (`can_afford`) with no signal.
- EP is removed: `Progression.ep`, `spend_ep`, the kept-EP bookkeeping, the HUD's "EP n", the announcer's "— N EP in Skills", the Skills screen's EP wording, and the stale EP comments. Levels still raise stats and gate the body evolution at the cap.
- The Skills-tab evolve flow keeps its two presses (arm, then confirm). The in-world one-button prompt is a later follow-up, not part of this plan.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`; work on a branch cut from the merged part 2.
- Test commands: `tools/run_tests.sh <substring>`; `TEST_TIMEOUT=900 tools/run_tests.sh` for the whole suite. Success prints `PASS: N tests`.

## Review Focus

1. **A paid-for life ends and another begins at the same ledger size.** The memo is keyed on the ledger's size, which restarts at 0. Expect: an affordable answer from life 1 is not returned in life 2 (Task 1 test, `reset_run` clears the memo).
2. **An evolution that is ready but unaffordable.** Expect: `evolve` returns false and spends nothing, the row stays ready and says exactly what is short, and the HUD line stays off until it can be paid (Tasks 2 and 3).
3. **Two branches of one parent.** Expect: the HUD names the parent once, not each branch, and taking one branch pays once and closes the other (Task 3 test).
4. **A hand-built test def with no price.** `test_evolution_branches` builds its own parent and branches. Expect: they still evolve (an empty price is nothing to pay; no special-case branch exists) (Task 2).
5. **A skill carrying a price that is not a parent.** Expect: the validator names it, and a parent with no price, an unknown element and a non-positive amount are each named (Task 1 tests).

---

## File map

- Modify `scripts/skills/ledger.gd` — `size()`.
- Modify `scripts/skills/skill_def.gd` — `evolution_price`.
- Modify `scripts/skills/def_validator.gd` — `_check_prices`.
- Modify `scripts/skills/skill_rules_engine.gd` — `ESSENCE_SPENT`, `held`, `evolution_price`, `can_afford`, `evolve` pays, `evolution_cost` removed.
- Modify `tools/build_content.gd` (by script) and regenerate the four base-power `.tres` files.
- Modify `scripts/actors/progression.gd`, `scripts/player/player.gd`, `scripts/core/core_wiring.gd`, `scripts/ui/hud.gd`, `scripts/ui/skill_screen.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/status_text.gd`, `scripts/world/rebirth_kit.gd` (a comment).
- Create `tests/test_evolution_price.gd`, `tests/test_evolve_line.gd`.
- Modify tests: `test_def_validator`, `test_content`, `test_levels`, `test_evolution_screen`, `test_evolution_trees`, `test_progression_stages`, `test_aim_fixes`, `test_form_effects`, `test_form_tab`, `test_rebirth_kit`, `test_rebirth_flow`, `test_scripted_run`, `test_skill_rules_levels` (a comment), `test_status_text`, `test_skill_screen`.

---

### Task 1: The price on the four base powers, and `held` / `can_afford` (additive)

Nothing existing changes: `evolve()` still pays EP in the player and pays nothing in the engine until Task 2.

**Files:**
- Modify: `scripts/skills/ledger.gd`, `scripts/skills/skill_def.gd`, `scripts/skills/def_validator.gd`, `scripts/skills/skill_rules_engine.gd`
- Modify: `tools/build_content.gd` (by script); regenerate `data/skills/{hydraulic_propulsion,poison_breath,spore_cloud,sticky_thread}.tres`
- Test: `tests/test_evolution_price.gd` (create), `tests/test_def_validator.gd`, `tests/test_content.gd`

**Interfaces:**
- Consumes: `SkillRulesEngine._ledger` (`Ledger.counter(event, tags)`), `SkillRulesEngine._defs`, `Essences.ALL`, `SkillDef.replaces`.
- Produces: `Ledger.size() -> int`; `SkillDef.evolution_price: Dictionary`; `SkillRulesEngine.ESSENCE_SPENT: String`, `held(element: String) -> int`, `evolution_price(id: String) -> Dictionary` (the parent's price for an evolution, `{}` for anything else), `can_afford(id: String) -> bool` (memoized on `_ledger.size()`, cleared by `reset_run()`). Task 2 and Task 3 and the skill tree plan rely on these exact names.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_evolution_price.gd`:

```gdscript
extends GutTest
## The price of evolving a power, in held essence: what a price reads, what is held, what can be afforded.

var rules: SkillRulesEngine
var skills_by_id := {}

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	rules.start_run()

func _absorb(element: String, n: int) -> void:
	for i in n:
		rules.handle_event("absorbed", {"essence": element, "source": "test"})

func test_the_four_base_powers_carry_the_prices_the_spec_starts_with() -> void:
	assert_eq(skills_by_id["hydraulic_propulsion"].evolution_price, {"water": 6})
	assert_eq(skills_by_id["poison_breath"].evolution_price, {"water": 6, "dark": 10})
	assert_eq(skills_by_id["spore_cloud"].evolution_price, {"air": 6, "dark": 12})
	assert_eq(skills_by_id["sticky_thread"].evolution_price, {"dark": 14})

func test_branches_read_their_parents_price() -> void:
	assert_eq(rules.evolution_price("water_blade"), {"water": 6})
	assert_eq(rules.evolution_price("jet_dash"), {"water": 6})
	assert_eq(rules.evolution_price("miasma"), rules.evolution_price("venom_bolt"))
	assert_eq(rules.evolution_price("leap"), {}, "a skill with no parent has no price")
	assert_eq(rules.evolution_price("nope"), {})

func test_held_is_what_was_absorbed() -> void:
	_absorb("water", 9)
	assert_eq(rules.held("water"), 9)
	assert_eq(rules.held("dark"), 0)

func test_can_afford_turns_true_when_every_element_of_the_price_is_held() -> void:
	_absorb("water", 6)
	_absorb("dark", 9)
	assert_false(rules.can_afford("miasma"), "dark 9 of 10")
	_absorb("dark", 1)
	assert_true(rules.can_afford("miasma"))

func test_can_afford_does_not_survive_a_new_life_at_the_same_ledger_size() -> void:
	_absorb("water", 8)
	assert_true(rules.can_afford("water_blade"))
	rules.start_run()
	_absorb("earth", 8)  # the same ledger size, none of the essence
	assert_false(rules.can_afford("water_blade"))
```

Append to `tests/test_def_validator.gd` (a parent with one evolution is the smallest case the rule reads):

```gdscript
func _parent_and_branch(price: Dictionary) -> Array:
	var parent := TestDefs.skill("p", {"evolution_price": price})
	var branch := TestDefs.skill("e", {"source": "evolution", "replaces": "p", "unlock": [TestDefs.level("p", 1)]})
	return [parent, branch]

func test_a_power_with_evolutions_needs_a_price() -> void:
	var errs := DefValidator.validate(_parent_and_branch({}), TestDefs.all_creatures())
	assert_string_contains("\n".join(errs), "a power with evolutions needs an evolution_price")

func test_only_a_power_with_evolutions_carries_a_price() -> void:
	var s := [TestDefs.skill("lonely", {"evolution_price": {"water": 3}})]
	assert_string_contains("\n".join(DefValidator.validate(s, TestDefs.all_creatures())), "only a power with evolutions carries an evolution_price")

func test_a_price_names_known_elements_with_positive_units() -> void:
	var unknown := DefValidator.validate(_parent_and_branch({"poison": 3}), TestDefs.all_creatures())
	assert_string_contains("\n".join(unknown), "unknown essence 'poison'")
	var zero := DefValidator.validate(_parent_and_branch({"water": 0}), TestDefs.all_creatures())
	assert_string_contains("\n".join(zero), "must be positive")
```

In `tests/test_content.gd`, inside `test_all_content_validates` nothing changes (it must still pass). Add:

```gdscript
func test_the_four_parents_carry_a_price_and_nothing_else_does() -> void:
	var parents := {"sticky_thread": true, "hydraulic_propulsion": true, "poison_breath": true, "spore_cloud": true}
	for d in skills:
		assert_eq(not (d as SkillDef).evolution_price.is_empty(), parents.has(d.id), d.id)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `tools/run_tests.sh test_evolution_price`
Expected: `FAIL: engine error or empty run` (`evolution_price`, `held` and `can_afford` do not exist).

- [ ] **Step 3: Implement**

`scripts/skills/ledger.gd`, add after `clear()`:

```gdscript

## How many entries the log holds (a cheap fingerprint for memoizing answers that read the whole log).
func size() -> int:
	return _log.size()
```

`scripts/skills/skill_def.gd`, add after the `replaces` export:

```gdscript
## What evolving this power costs, in held essence: element -> units. Set once on the base power; its evolution branches share
## it (they read it through `replaces`). Empty on every other skill.
@export var evolution_price: Dictionary = {}
```

`scripts/skills/def_validator.gd`: in `validate()`, add `_check_prices(by_id, errors)` right after `_check_siblings(by_id, errors)`, and add this function after `_check_siblings`:

```gdscript
## A base power that has evolutions carries the price of evolving it (known elements, positive units); every other skill carries none.
static func _check_prices(by_id: Dictionary, errors: PackedStringArray) -> void:
	var parents := {}
	for d in by_id.values():
		if d.source == "evolution" and d.replaces != "":
			parents[d.replaces] = true
	for d in by_id.values():
		var w := _where(d)
		if parents.has(d.id):
			if d.evolution_price.is_empty():
				errors.append("%s: a power with evolutions needs an evolution_price" % w)
		elif not d.evolution_price.is_empty():
			errors.append("%s: only a power with evolutions carries an evolution_price" % w)
		for e in d.evolution_price:
			if not Essences.ALL.has(e):
				errors.append("%s: evolution_price names unknown essence '%s'" % [w, e])
			elif int(d.evolution_price[e]) <= 0:
				errors.append("%s: evolution_price of '%s' must be positive" % [w, e])
```

`scripts/skills/skill_rules_engine.gd`: add below `const BASE_STAGE_CAP := 5`:

```gdscript
## One ledger entry per spent unit of essence, tagged {"essence": element}. Written straight to the ledger by evolve(): it is
## deliberately not in Events.ALL (no skill may count it, and the audio and constants tests stay as they are) and not in
## Events.INTERNAL (_drain skips recording those).
const ESSENCE_SPENT := "essence_spent"
```

add below the `_children` declaration:

```gdscript
var _afford_memo := {}       # evolution id -> bool, valid while the ledger holds _afford_memo_size entries
var _afford_memo_size := -1
```

in `reset_run()` add, after `_granted.clear()`:

```gdscript
	_afford_memo.clear()
	_afford_memo_size = -1
```

and add these methods after `evolution_cost`:

```gdscript
## Essence of one element still held: what was absorbed this life minus what evolutions have spent. Recipes read what was
## absorbed, so spending never undoes an unlock.
func held(element: String) -> int:
	return _ledger.counter(Events.ABSORBED, {"essence": element}) - _ledger.counter(ESSENCE_SPENT, {"essence": element})

## The price of evolving into `id`: its parent's evolution_price (empty for a skill that is not an evolution).
func evolution_price(id: String) -> Dictionary:
	var d: SkillDef = _defs.get(id)
	if d == null or d.replaces == "":
		return {}
	var parent: SkillDef = _defs.get(d.replaces)
	return parent.evolution_price if parent != null else {}

## Every element of the price is held. Memoized on the ledger's size (the HUD asks every frame); reset_run() clears the memo
## because the ledger restarts at size 0.
func can_afford(id: String) -> bool:
	if _afford_memo_size != _ledger.size():
		_afford_memo.clear()
		_afford_memo_size = _ledger.size()
	if not _afford_memo.has(id):
		var ok := true
		var price := evolution_price(id)
		for e in price:
			if held(e) < int(price[e]):
				ok = false
				break
		_afford_memo[id] = ok
	return _afford_memo[id]
```

Write the prices into the generator and regenerate (the script inserts the field right after each base power's `id`; run from the repo root):

```bash
mkdir -p .tmp/price .tmp/gdhome
python3 - <<'PYEOF'
path = "tools/build_content.gd"
src = open(path).read()
prices = {
    "hydraulic_propulsion": '{"water": 6}',
    "poison_breath": '{"water": 6, "dark": 10}',
    "spore_cloud": '{"air": 6, "dark": 12}',
    "sticky_thread": '{"dark": 14}',
}
for sid, price in prices.items():
    old = '_s({"id": "%s", "display_name":' % sid
    assert src.count(old) == 1, sid
    src = src.replace(old, '_s({"id": "%s", "evolution_price": %s, "display_name":' % (sid, price))
open(path, "w").write(src)
print("prices written")
PYEOF
env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd
git diff --stat data/skills
```

Expected: `prices written`, then a diff touching exactly the four base-power files.

- [ ] **Step 4: Run the tests**

Run: `tools/run_tests.sh test_evolution_price`, `tools/run_tests.sh test_def_validator`, `tools/run_tests.sh test_content`
Expected: `PASS: <n> tests` for each.

- [ ] **Step 5: Commit**

```bash
git add scripts/skills tools/build_content.gd data/skills tests/test_evolution_price.gd tests/test_def_validator.gd tests/test_content.gd
git commit -m "feat: a power's evolution price, held essence and can_afford"
```

---

### Task 2: Evolving pays essence, and Evolution Points go (one atomic change)

`Player.try_evolve`, the Skills screen, the HUD, the announcer and a dozen tests read `ep` or `evolution_cost`; removing either in a separate task is a parse error, so they go together.

**Files:**
- Modify: `scripts/skills/skill_rules_engine.gd`, `scripts/actors/progression.gd`, `scripts/player/player.gd`, `scripts/core/core_wiring.gd`, `scripts/ui/hud.gd`, `scripts/ui/skill_screen.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/world/rebirth_kit.gd`
- Test: `tests/test_evolution_price.gd`, `tests/test_levels.gd`, `tests/test_evolution_screen.gd`, `tests/test_evolution_trees.gd`, `tests/test_progression_stages.gd`, `tests/test_aim_fixes.gd`, `tests/test_form_effects.gd`, `tests/test_form_tab.gd`, `tests/test_rebirth_kit.gd`, `tests/test_rebirth_flow.gd`, `tests/test_scripted_run.gd`, `tests/test_skill_rules_levels.gd`

**Interfaces:**
- Consumes: Task 1's `held`, `evolution_price`, `can_afford`, `ESSENCE_SPENT`; `Essences.ALL`.
- Produces: `SkillRulesEngine.evolve(id) -> bool` now checks `can_afford`, writes one `essence_spent` entry per unit of the price, then grants; `Player.try_evolve(id) -> bool` (no EP); `SkillScreenModel.price_text(price: Dictionary) -> String` (`"water 6, dark 10"` in `Essences.ALL` order) and `SkillScreenModel.shortfall_text(rules, price: Dictionary) -> String` (`"needs 2 more water, 6 more dark"`, empty when affordable); the ready row dict gains `"price"` and `"affordable"` in place of `"cost"`. `Progression` has no `ep` and no `spend_ep`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_evolution_price.gd`:

```gdscript
func _ready_poison_breath() -> void:
	TestDefs.satisfy(rules, "poison_breath")  # water 4, dark 4
	for i in 24:
		rules.handle_event("skill_used", {"id": "poison_breath"})  # Lv4: Miasma and Venom Bolt are ready together

func test_evolve_pays_exactly_the_price_and_leaves_the_recipe_counted() -> void:
	_ready_poison_breath()
	_absorb("water", 2)
	_absorb("dark", 6)
	var eaten_water := rules.count("absorbed", {"essence": "water"})
	assert_true(rules.can_afford("miasma"))
	assert_true(rules.evolve("miasma"))
	assert_eq(rules.held("water"), 0)
	assert_eq(rules.held("dark"), 0)
	assert_eq(rules.count("absorbed", {"essence": "water"}), eaten_water, "spending never undoes what was eaten")
	assert_gt(rules.level_of("poison_breath"), 0, "the parent keeps the level it reached")

func test_evolve_refuses_when_the_price_is_not_held_and_spends_nothing() -> void:
	_ready_poison_breath()
	assert_true(rules.is_evolution_ready("miasma"))
	assert_false(rules.can_afford("miasma"))
	assert_false(rules.evolve("miasma"))
	assert_eq(rules.held("water"), 4)
	assert_eq(rules.held("dark"), 4)
	assert_true(rules.is_evolution_ready("miasma"), "still ready, just not affordable")

func test_taking_one_branch_pays_once_and_closes_the_other() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # water 8
	for i in 12:
		rules.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_true(rules.evolve("water_blade"))
	assert_eq(rules.held("water"), 2, "8 absorbed, 6 paid")
	assert_false(rules.evolve("jet_dash"), "closed: its sibling was taken")
	assert_eq(rules.held("water"), 2, "a refused evolve spends nothing")

func test_a_new_life_holds_nothing() -> void:
	_absorb("water", 8)
	rules.start_run()
	assert_eq(rules.held("water"), 0)
```

Update the tests that read EP (each replaced function is given in full):

`tests/test_levels.gd`:

```gdscript
func test_progression_curve() -> void:
	var p := Progression.new()
	p.add_xp(9)
	assert_eq([p.level, p.xp], [1, 9])
	p.add_xp(1)
	assert_eq([p.level, p.xp], [2, 0])
	p.add_xp(40)  # 15 to reach Lv3, then 20 to reach Lv4
	assert_eq([p.level, p.xp], [4, 5])
	assert_eq(Progression.xp_to_next(1), 10)
	assert_eq(Progression.xp_to_next(3), 20)
```

(this replaces `test_progression_curve_and_ep`), and

```gdscript
func test_level_up_grants_stats() -> void:
	player.award_xp(10)
	assert_eq(player.progression.level, 2)
	assert_eq(player.health.max_hp, 32)
	assert_eq(player.mana.max_mp, 21)
	assert_eq(player.stats.level_bonus("max_hp"), 2)
	assert_eq(player.stats.skill_bonus("max_hp"), 0)
```

(replacing `test_level_up_grants_ep_and_stats`). Replace `test_evolution_waits_until_ep_is_spent` with:

```gdscript
func test_evolution_waits_until_it_is_paid_for() -> void:
	var ready: Array = []
	rules.evolution_ready.connect(func(id: String) -> void: ready.append(id))
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # water 8
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 12)  # Lv3: both branches open together
	assert_eq(rules.level_of("water_blade"), 0)
	assert_true(rules.is_evolution_ready("water_blade") and rules.is_evolution_ready("jet_dash"))
	assert_eq(ready.size(), 2)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 6)
	assert_eq(ready.size(), 2)  # announced once each
	assert_eq(rules.evolution_price("water_blade"), {"water": 6})
	assert_eq(rules.evolution_price("jet_dash"), {"water": 6})
	assert_true(rules.evolve("water_blade"))
	assert_eq(rules.held("water"), 2, "the price was paid in essence")
	assert_eq(rules.level_of("water_blade"), 1)
	assert_false(rules.evolve("water_blade"))
	assert_false(rules.evolve("jet_dash"))  # closed: its sibling was taken
	assert_true(rules.is_closed("jet_dash"))
```

Replace `test_player_evolves_only_with_enough_ep` with:

```gdscript
func test_player_evolves_only_when_the_price_is_held() -> void:
	TestDefs.satisfy(rules, "poison_breath")  # water 4, dark 4
	_emit("skill_used", {"id": "poison_breath"}, 24)  # Lv4: Miasma and Venom Bolt are ready
	assert_false(player.try_evolve("miasma"), "water 4 of 6, dark 4 of 10")
	_emit("absorbed", {"essence": "water"}, 2)
	_emit("absorbed", {"essence": "dark"}, 6)
	assert_true(player.try_evolve("miasma"))
	assert_eq(rules.level_of("miasma"), 1)
	assert_true(player.skillset.slots.slots.has("miasma"))
```

In `test_skill_screen_lists_ready_evolutions_and_evolves_on_accept` change the row expectation `assert_true(screen.row_texts().has("Water Blade  EVOLVE 1 EP"))` to `assert_true(screen.row_texts().has("Water Blade  EVOLVE"))`. In `test_hud_shows_level_xp_and_ep_and_enemies_award_xp_in_game` (rename it `test_hud_shows_level_and_xp_and_enemies_award_xp_in_game`) change the expectation to `"Lv 1/10  XP 0/10"`. Update the file's header comment lines 2-3 to `## Character levels: XP from downing and eating, level-ups grant stats, and evolutions wait for the player to pay their essence price.`

`tests/test_evolution_screen.gd`: replace `test_an_ep_short_press_never_evolves_and_the_card_says_how_to_earn_ep` with:

```gdscript
func test_a_short_press_never_evolves_and_the_card_says_what_is_short() -> void:
	TestDefs.satisfy(rules, "poison_breath")  # water 4, dark 4
	_emit("skill_used", {"id": "poison_breath"}, 24)  # Lv4: Miasma and Venom Bolt together
	var s := _screen()
	_select(s, "miasma")
	s.accept()
	s.accept()
	assert_eq(rules.level_of("miasma"), 0)
	var text := _detail(s)
	assert_string_contains(text, "needs 2 more water, 6 more dark")
	assert_false(text.contains("Press again to choose"))
	s.close()
```

`tests/test_evolution_trees.gd`: add a helper and call it before each `evolve`:

```gdscript
## Pays the parent's price: the essence is eaten first, as it would be in play.
func _fund(parent: String) -> void:
	var price: Dictionary = (skills_by_id[parent] as SkillDef).evolution_price
	for e in price:
		for i in int(price[e]):
			rules.handle_event("absorbed", {"essence": e, "source": "test"})
```

and in `test_each_tree_evolves_each_branch_in_a_fresh_run` insert `_fund(parent)` and `assert_true(rules.can_afford(chosen), chosen)` just before `assert_true(rules.evolve(chosen), chosen)`.

`tests/test_progression_stages.gd`: replace `test_evolving_resets_the_level_but_keeps_the_ep` and `test_leveling_gives_ep_only_below_the_cap` with:

```gdscript
func test_evolving_resets_the_level() -> void:
	var p := Progression.new()
	p.add_xp(Progression.stage_total(1))
	p.evolve_stage()
	assert_eq(p.stage, 2)
	assert_eq(p.level, 1)
	assert_eq(p.xp, 0)
	p.add_xp(Progression.stage_total(2))
	assert_eq(p.level, Progression.LEVEL_CAP, "stage 2 has its own, longer curve")

func test_xp_stops_at_the_cap() -> void:
	var p := Progression.new()
	p.add_xp(Progression.stage_total(1) + 200)
	assert_eq(p.level, Progression.LEVEL_CAP)
	assert_eq(p.xp, 0, "nothing banks past the cap")
```

`tests/test_aim_fixes.gd`: change the assertion in `test_levels_reset_when_a_run_restarts_in_place` to `assert_eq([player.progression.level, player.progression.xp], [1, 0])`.

`tests/test_form_effects.gd`: in `test_evolving_to_weaver_sets_the_stage_resets_the_level_and_raises_the_cap` delete the line `var ep := player.progression.ep` and the line `assert_eq(player.progression.ep, ep, "EP persists")`.

`tests/test_form_tab.gd`: in `test_the_hud_shows_the_cap_and_the_evolution_prompt` change `"Lv 1/10  XP 0/10  EP 0"` to `"Lv 1/10  XP 0/10"`.

`tests/test_rebirth_kit.gd`: rename `test_a_starting_level_gives_the_stat_bonuses_and_no_ep` to `test_a_starting_level_gives_the_stat_bonuses` and delete the line `assert_eq(player.progression.ep, 0, "EP is earned, not given")`; change the header comment to `## A rebirth pool's head start: granted skills that count as known but not discovered, and a starting level.`

`tests/test_rebirth_flow.gd`: change the message `"no EP from a starting level"` to `"a starting level banks no XP"`.

`tests/test_scripted_run.gd`: change the comment on `assert_true(rules.evolve("water_blade"))` to `# the price is held: four water pools gave water 8 against 6`. `tests/test_skill_rules_levels.gd`: change the comment `# Evolutions become ready rather than unlocking; the player spends EP to evolve.` to `# Evolutions become ready rather than unlocking; the player pays essence to evolve.`

- [ ] **Step 2: Run to verify they fail**

Run: `tools/run_tests.sh test_evolution_price`
Expected: FAIL (the new `evolve` tests fail: `evolve` pays nothing yet).

- [ ] **Step 3: Implement**

`scripts/skills/skill_rules_engine.gd`:
- change the doc comment on `evolution_ready` to `## An evolution's conditions are met; it unlocks only when the player pays its price (evolve()).`;
- delete the whole `evolution_cost` function and its doc comment (`## EP cost to evolve: ...` and its three-line body);
- replace `evolve` with:

```gdscript
## Pays a ready evolution's price in held essence (one ledger entry per unit), unlocks it and closes its siblings. False, and
## nothing is spent, when it is not ready or the price is not held. The parent retires as the evolution enters `_owned`, so the
## siblings' ready flags are erased here and _evaluate keeps them from coming back.
func evolve(id: String) -> bool:
	if not run_active or not _ready_evolutions.has(id) or _owned.has(id) or not can_afford(id):
		return false
	var price := evolution_price(id)
	for e in price:
		for i in int(price[e]):
			_ledger.record(ESSENCE_SPENT, {"essence": e})
	_ready_evolutions.erase(id)
	for sib in siblings_of(id):
		_ready_evolutions.erase(sib)
	_grant(_defs[id], true)
	if not _draining:
		_drain()
	return true
```

`scripts/actors/progression.gd`:
- replace the header comment (lines 3-5) with:

```gdscript
## Character level for the current run, in four stages. XP comes from downing and eating creatures;
## each level-up raises stats. A stage ends at LEVEL_CAP: extra XP is discarded until
## the body evolves (evolve_stage), which resets the level but keeps the level bonuses.
```

- delete `var ep := 0`; in `add_xp` delete the line `		ep += 1`;
- replace `start_at` (and its comment) with:

```gdscript
## A rebirth kit's starting level: the level bonuses (one leveled_up per level), no XP, stage 1.
func start_at(target: int) -> void:
	target = clampi(target, 1, LEVEL_CAP)
	while level < target:
		level += 1
		leveled_up.emit(level)
	xp = 0
```

- change the `evolve_stage` comment to `## Starts the next stage: level 1 again; the (stat) level bonuses are kept.`;
- delete the whole `spend_ep` function.

`scripts/player/player.gd`: replace `try_evolve` and its comment with:

```gdscript
## Pays the price in held essence and unlocks a ready evolution. False when it is not ready or the price is not held.
func try_evolve(id: String) -> bool:
	if not _rules.evolve(id):
		return false
	EventBus.world_event.emit("evolved", {"id": id})
	return true
```

and edit two comments: in the `advance_form` doc, `(keeping EP and the level bonuses)` becomes `(keeping the level bonuses)`; on `start_at_level` change `(bonuses, no EP, no fanfare)` to `(bonuses, no fanfare)`.

`scripts/core/core_wiring.gd`: replace the announcer line in the `evolution_ready` handler with:

```gdscript
		announcer.push_unlock(id, "Evolution available: [%s] (Skills tab)" % d.display_name))
```

`scripts/world/rebirth_kit.gd`: in the `apply` doc comment change `a starting level gives its bonuses but no EP.` to `a starting level gives its bonuses.`

`scripts/ui/hud.gd`: replace `level_text` with:

```gdscript
func level_text() -> String:
	var p := _player.progression
	if p.at_cap():
		return "Lv %d/%d  MAX" % [p.level, Progression.LEVEL_CAP]
	return "Lv %d/%d  XP %d/%d" % [p.level, Progression.LEVEL_CAP, p.xp, Progression.xp_to_next(p.level, p.stage)]
```

`scripts/ui/skill_screen_model.gd`: add these two functions after `capped_text()`:

```gdscript

## A price as text, in the canonical element order: "water 6, dark 10".
static func price_text(price: Dictionary) -> String:
	var parts: Array = []
	for e in Essences.ALL:
		if price.has(e):
			parts.append("%s %d" % [e, int(price[e])])
	return ", ".join(parts)

## What is short of a price: "needs 2 more water, 6 more dark"; empty when every element is held.
static func shortfall_text(rules, price: Dictionary) -> String:
	var parts: Array = []
	for e in Essences.ALL:
		if price.has(e):
			var short: int = int(price[e]) - rules.held(e)
			if short > 0:
				parts.append("%d more %s" % [short, e])
	return "needs " + ", ".join(parts) if not parts.is_empty() else ""
```

and change the ready row in `skill_rows` to:

```gdscript
					rows.append({"kind": "ready", "id": id, "name": d.display_name, "price": rules.evolution_price(id), "affordable": rules.can_afford(id)})
```

`scripts/ui/skill_screen.gd`:
- in the `accept()` doc comment replace `(spending\n## EP)` with `(paying its\n## essence price)`;
- in `accept()` replace `if _player.progression.ep >= _rules.evolution_cost(id):` with `if _rules.can_afford(id):`;
- in `row_texts()` replace `out.append("%s  EVOLVE %d EP" % [r["name"], r["cost"]])` with `out.append("%s  EVOLVE" % r["name"])`;
- in `_build_stats()` replace the `Lv %d    EP %d` label with `_label(_stats, "Lv %d" % p.level, Vector2(36, 92), Vector2(110, 12), FONT_MAIN, Color(1.0, 0.85, 0.45))`;
- in `_build_row`, replace the ready branch with:

```gdscript
	elif r["kind"] == "ready":
		_label(_list, "EVOLVE", Vector2(LIST_X + 170, y + 5), Vector2(70, 10), FONT_SMALL, Color(1.0, 0.85, 0.45) if r["affordable"] else COL_DIM)
```

- in `_build_detail`'s ready block replace `var cost: int = _rules.evolution_cost(id)` with `var price: Dictionary = _rules.evolution_price(id)`, and replace the six lines from `_label(_detail, "Costs %d EP ...` through `_label(_detail, action, ...)` (the Costs label, `var can`, `var action`, the `if can:` pair, and the action label) with:

```gdscript
		_label(_detail, "Costs " + SkillScreenModel.price_text(price), Vector2(DETAIL_X, 166), Vector2(190, 12), FONT_MAIN, COL_TITLE)
		var can := _rules.can_afford(id)
		var action := SkillScreenModel.shortfall_text(_rules, price)
		if can:
			action = "Press again to choose" if _armed == id else "[%s] Evolve" % ("A" if Controls.using_joypad else "Enter")
		_label(_detail, action, Vector2(DETAIL_X, 182), Vector2(190, 24), FONT_MAIN, Color.WHITE if can else COL_DIM, true)
```

(The last argument `true` wraps the line, as the neighbouring labels do, because a two-element shortfall is longer than one line.)

- [ ] **Step 4: Run the affected tests**

Run: `tools/run_tests.sh test_evolution`, `tools/run_tests.sh test_levels`, `tools/run_tests.sh test_progression`, `tools/run_tests.sh test_aim_fixes`, `tools/run_tests.sh test_form`, `tools/run_tests.sh test_rebirth`, `tools/run_tests.sh test_scripted_run`, `tools/run_tests.sh test_skill_rules`
Expected: `PASS: <n> tests` for each. Tests that evolve real defs after `TestDefs.satisfy(rules, "hydraulic_propulsion")` hold water 8 against a price of 6, so they evolve as before; `test_evolution_branches` builds its own defs with no price and still evolves (an empty price is nothing to pay).

- [ ] **Step 5: Closing grep and the full suite**

```bash
grep -rnE "progression\.ep|\.ep\b|spend_ep|evolution_cost|kept_ep|\bEP\b" scripts tools tests --include='*.gd'
```

Expected: no output. (The word "EP" may survive in a test's own comment; read any hit and fix it.)

Run: `TEST_TIMEOUT=900 tools/run_tests.sh`
Expected: `PASS: <n> tests` with no `SCRIPT ERROR`.

- [ ] **Step 6: Commit**

```bash
git add -A scripts tests
git commit -m "feat: evolving a power spends held essence, and Evolution Points go

evolve() writes one essence_spent ledger entry per unit of the parent's price
and refuses when it is not held; the Skills tab shows the price and what is
short; Progression, Player, the HUD and the announcer lose EP."
```

---

### Task 3: The HUD names a ready, affordable evolution; the screens show held essence

**Files:**
- Modify: `scripts/ui/hud.gd`, `scripts/ui/status_text.gd`, `scripts/ui/skill_screen.gd`
- Test: `tests/test_evolve_line.gd` (create), `tests/test_status_text.gd`, `tests/test_skill_screen.gd`

**Interfaces:**
- Consumes: `SkillRulesEngine.ready_evolutions() -> Array`, `can_afford(id)`, `held(element)`, `get_def(id).replaces`, `get_def(id).display_name`; `Hud._rules`, `Hud._player`.
- Produces: `Hud.evolve_text()` returns up to two lines: the existing body-evolution line, then `Evolve: <Parent power>  (Start|Esc, Skills tab)` for the first ready parent that is affordable (asked once per parent, not per branch); `StatusText.self_lines` and the Skills tab's stats column list `held` per element.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_evolve_line.gd`:

```gdscript
extends GutTest
## The HUD's second line: a power evolution that is ready and affordable, named once per parent.

var rules: SkillRulesEngine
var player: Player
var hud: Hud

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	hud = Hud.new()
	add_child_autofree(hud)
	hud.bind(player, rules, compendium, AnnouncerQueue.new())

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _ready_hydraulic() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # water 8
	for i in 12:
		rules.handle_event("skill_used", {"id": "hydraulic_propulsion"})  # Lv3: Water Blade and Jet Dash are ready

func test_there_is_no_line_before_anything_is_ready() -> void:
	assert_eq(hud.evolve_text(), "")

func test_a_ready_and_affordable_evolution_gets_a_line_naming_its_power() -> void:
	_ready_hydraulic()
	assert_string_contains(hud.evolve_text(), "Evolve: Hydraulic Propulsion")

func test_one_line_per_ready_parent_not_one_per_branch() -> void:
	_ready_hydraulic()
	assert_true(rules.is_evolution_ready("water_blade") and rules.is_evolution_ready("jet_dash"))
	assert_eq(hud.evolve_text().count("Evolve:"), 1)

func test_a_ready_but_unaffordable_evolution_has_no_line_until_it_can_be_paid() -> void:
	TestDefs.satisfy(rules, "poison_breath")  # water 4, dark 4
	for i in 24:
		rules.handle_event("skill_used", {"id": "poison_breath"})
	assert_true(rules.is_evolution_ready("miasma"))
	assert_eq(hud.evolve_text(), "")
	for i in 2:
		rules.handle_event("absorbed", {"essence": "water", "source": "test"})
	for i in 6:
		rules.handle_event("absorbed", {"essence": "dark", "source": "test"})
	assert_string_contains(hud.evolve_text(), "Evolve: Poison Breath")

func test_the_line_goes_once_the_evolution_is_taken() -> void:
	_ready_hydraulic()
	assert_true(rules.evolve("water_blade"))
	assert_eq(hud.evolve_text(), "")

func test_both_lines_show_together_at_the_level_cap() -> void:
	_ready_hydraulic()
	player.progression.add_xp(Progression.stage_total(1))
	var text := hud.evolve_text()
	assert_string_contains(text, "Your body can evolve")
	assert_string_contains(text, "Evolve: Hydraulic Propulsion")
	assert_eq(text.split("\n").size(), 2)
```

Append to `tests/test_status_text.gd`:

```gdscript
func test_the_essences_line_shows_what_is_held_after_paying_for_an_evolution() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # water 8
	for i in 12:
		rules.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	assert_true(rules.evolve("water_blade"))  # pays water 6
	var text := "\n".join(StatusText.self_lines(stats, health, rules, compendium, 1))
	assert_string_contains(text, "water 2")
```

Append to `tests/test_skill_screen.gd`:

```gdscript
func test_the_stats_column_lists_held_essence() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")  # water 8
	_screen()
	screen.open()
	var texts: Array = []
	for c in screen._stats.get_children():
		if c is Label:
			texts.append((c as Label).text)
	assert_true(texts.has("water  8"), str(texts))
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools/run_tests.sh test_evolve_line`
Expected: FAIL (`evolve_text` returns only the body line; the first test passes, the "Evolve:" ones fail).

- [ ] **Step 3: Implement**

`scripts/ui/hud.gd`: replace `evolve_text` with:

```gdscript
## The evolution prompts: "Your body can evolve" while the level cap is reached and there is a stage left, then one line for the
## first power evolution that is ready and affordable. `_evolve` is recomputed every frame, so affordability is polled.
func evolve_text() -> String:
	var key := "Start" if Controls.using_joypad else "Esc"
	var lines: Array = []
	if _player.progression.can_evolve():
		lines.append("Your body can evolve  (%s, Form tab)" % key)
	var parent := _first_affordable_parent()
	if parent != "":
		lines.append("Evolve: %s  (%s, Skills tab)" % [_rules.get_def(parent).display_name, key])
	return "\n".join(lines)

## The base power of the first ready evolution whose price is held, asked once per parent (its branches share a price).
func _first_affordable_parent() -> String:
	var asked := {}
	for id in _rules.ready_evolutions():
		var parent: String = _rules.get_def(id).replaces
		if asked.has(parent):
			continue
		asked[parent] = true
		if _rules.can_afford(id):
			return parent
	return ""
```

`scripts/ui/status_text.gd`: in `self_lines` change the essence loop to read held:

```gdscript
	for ess in Essences.ALL:
		var n: int = rules.held(ess)
		if n > 0:
			essences.append("%s %d" % [ess, n])
```

`scripts/ui/skill_screen.gd`: in `_build_stats` change `var n: int = _rules.count(Events.ABSORBED, {"essence": ess})` to `var n: int = _rules.held(ess)`.

- [ ] **Step 4: Run the tests**

Run: `tools/run_tests.sh test_evolve_line`, `tools/run_tests.sh test_status_text`, `tools/run_tests.sh test_skill_screen`, `tools/run_tests.sh test_form_tab`
Expected: `PASS: <n> tests` for each.

- [ ] **Step 5: Full suite and a look**

Run: `TEST_TIMEOUT=900 tools/run_tests.sh`
Expected: `PASS: <n> tests` with no `SCRIPT ERROR`.

Take a real-renderer screenshot to confirm the two HUD lines do not collide with the other top-left labels (the debug-input label shares the same corner but is hidden unless toggled). This tool needs a display, not `--headless`: `env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/evolution_shots.gd` writes `.tmp/evolution/hud_prompt.png` (the cap moment). Read that PNG and confirm the lines are legible and clear of the HP, MP and level labels.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui tests
git commit -m "feat: the HUD names a ready, affordable evolution; the screens show held essence"
```

---

## Self-Review

**Spec coverage** (essence overhaul spec; the rows part 3 owns):

| Spec requirement | Task |
|---|---|
| `evolution_price` once on the base power; validator presence, known elements, positive units; branches read the parent's | 1 |
| Starting prices and the "one family, not all three" target | 1 (data), Global Constraints |
| `held = ABSORBED − essence_spent`, spending recorded in the ledger directly, outside `Events.ALL` and `INTERNAL`, cleared by `reset_run()` | 1, 2 |
| `can_afford` memoized on ledger size, memo cleared on `reset_run()` | 1 |
| `evolve()` pays, refuses and spends nothing when short; recipes still count what was eaten | 2 |
| `evolution_cost()` and EP removed everywhere (HUD, announcer, Skills screen wording and affordability, Progression, Player, comments) | 2 |
| Skills tab keeps its two presses, now priced, with the shortfall text | 2 |
| HUD line for a ready, affordable evolution, once per parent, polled each frame | 3 |
| Status text and the stats column show `held` | 3 |

Not in this part: the in-world one-button prompt, the OR recipe group, banking and the death seed, stage 2 to 3 pairing by the evolved power.

**Placeholder scan:** none; every replaced function is given in full and every edited line names its exact old text.

**Type consistency:** `held(element: String) -> int`, `evolution_price(id: String) -> Dictionary`, `can_afford(id: String) -> bool` and `ESSENCE_SPENT` are defined in Task 1 and used in Tasks 2 and 3 (and by the skill tree plan); `SkillScreenModel.price_text(price)` and `shortfall_text(rules, price)` are defined and used in Task 2; the ready row keys `"price"` and `"affordable"` replace `"cost"` in the model and in `row_texts`, `_build_row` and `_build_detail`.
