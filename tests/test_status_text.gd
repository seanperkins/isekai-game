extends GutTest

var rules: SkillRulesEngine
var compendium: CompendiumModel
var stats: Stats
var health: Health

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, DefLoader.load_dir("res://data/creatures"))
	stats = Stats.new({"max_hp": 30, "atk": 1, "def": 0, "spd": 100})
	health = Health.new(30)
	rules.start_run()

func test_self_lines_show_stats_skills_essences_and_bands_without_numbers() -> void:
	stats.apply_eat(TestDefs.creature("lizard", {"eat_bonus": {"stat": "def", "amount": 1, "per": 1}}))
	stats.set_modifiers("body_armor", [{"stat": "def", "op": "add", "value": 2}])
	TestDefs.satisfy(rules, "echolocation")
	for i in 20:
		rules.handle_event("jumped", {"from": "ground"})
	var text := "\n".join(StatusText.self_lines(stats, health, rules, compendium, 2))
	assert_string_contains(text, "HP 30/30")
	assert_string_contains(text, "DEF 3 (+1 eat, +2 skill)")
	assert_string_contains(text, "Appraisal Lv1")
	assert_string_contains(text, "Echolocation Lv1")
	assert_string_contains(text, "air 6")
	assert_string_contains(text, "Leap — something stirs")
	assert_false(text.contains("20/40"))

func test_self_lines_add_hints_at_lv3() -> void:
	for i in 32:
		rules.handle_event("jumped", {"from": "ground"})
	var text := "\n".join(StatusText.self_lines(stats, health, rules, compendium, 3))
	assert_string_contains(text, "Leap — it's close (Your body remembers every leap.)")

func test_creature_lines_grow_with_report() -> void:
	var lv1 := "\n".join(StatusText.creature_lines({"id": "bat", "name": "Cave Bat", "hp": 2}))
	assert_eq(lv1, "Cave Bat\nHP 2")
	var lv3 := "\n".join(StatusText.creature_lines({"id": "toad", "name": "Poison Toad", "hp": 3,
		"stats": {"max_hp": 3, "atk": 3, "def": 0, "spd": 70}, "essences": {"water": 1, "dark": 1},
		"eat_bonus": {"stat": "max_hp", "amount": 1, "per": 1},
		"skills": [{"id": "poison_spit", "level": 1}, {"id": "poison_resistance", "level": 2}]}))
	assert_string_contains(lv3, "ATK 3  DEF 0  SPD 70")
	assert_string_contains(lv3, "Essences: water 1, dark 1")
	assert_string_contains(lv3, "Eat bonus: +1 max_hp")
	assert_string_contains(lv3, "Skills: poison_spit Lv1, poison_resistance Lv2")

func test_creature_lines_for_empty_report() -> void:
	assert_eq(StatusText.creature_lines({}), PackedStringArray(["Nothing to appraise."]))

func test_slot_and_ticker_text() -> void:
	var slots := ActiveSlots.new()
	assert_eq(StatusText.slot_line(slots, rules), "[U] —  [O] —  [H] —  [L] —")
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	slots.add("hydraulic_propulsion")
	assert_eq(StatusText.slot_line(slots, rules), "[U] Hydraulic Propulsion  [O] —  [H] —  [L] —")
	assert_eq(StatusText.ticker_text({"kind": "level", "id": "hydraulic_propulsion", "level": 2}, rules), "Hydraulic Propulsion Lv2")
	assert_eq(StatusText.ticker_text({"kind": "slot_replaced", "new_id": "water_blade", "old_id": "hydraulic_propulsion"}, rules),
		"Water Blade replaced Hydraulic Propulsion")
