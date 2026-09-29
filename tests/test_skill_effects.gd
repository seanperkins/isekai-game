extends GutTest

var skills := {}

func before_all() -> void:
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func test_value_at_clamps_level_and_defaults_to_zero() -> void:
	var e := {"kind": "modifier", "stat": "def", "op": "add", "values": [1, 2, 3]}
	assert_eq(SkillEffects.value_at(e, 1), 1)
	assert_eq(SkillEffects.value_at(e, 3), 3)
	assert_eq(SkillEffects.value_at(e, 9), 3)
	assert_eq(SkillEffects.value_at({"kind": "active"}, 2), 0)

func test_stat_modifiers_skip_damage_taken() -> void:
	assert_eq(SkillEffects.stat_modifiers(skills["leap"], 2), [{"stat": "jump_height", "op": "add", "value": 15}])
	assert_eq(SkillEffects.stat_modifiers(skills["poison_resistance"], 1), [])
	assert_eq(SkillEffects.stat_modifiers(skills["regeneration"], 1), [{"stat": "regen_interval", "op": "set", "value": 8}])

func test_capabilities_include_compound_effects() -> void:
	assert_eq(SkillEffects.capabilities(skills["wall_cling"], 2), {"wall_cling": 2})
	assert_eq(SkillEffects.stat_modifiers(skills["wall_cling"], 2), [{"stat": "slide_speed", "op": "add", "value": -40}])
	var gated := TestDefs.skill("g", {"effects": [{"kind": "capability", "flag": "x", "min_level": 2}]})
	assert_eq(SkillEffects.capabilities(gated, 1), {})
	assert_eq(SkillEffects.capabilities(gated, 2), {"x": 2})

func test_damage_reduction_scope_and_condition() -> void:
	var pairs := [[skills["poison_resistance"], 2], [skills["pain_resistance"], 3]]
	assert_eq(SkillEffects.damage_reduction(pairs, "poison", 30, 30), {"percent_off": 32, "flat_off": 0})
	assert_eq(SkillEffects.damage_reduction(pairs, "physical", 30, 30), {"percent_off": 0, "flat_off": 0})
	assert_eq(SkillEffects.damage_reduction(pairs, "physical", 8, 30), {"percent_off": 0, "flat_off": 3})
	assert_eq(SkillEffects.damage_reduction(pairs, "physical", 9, 30), {"percent_off": 0, "flat_off": 0})

func test_active_scene_and_values() -> void:
	assert_eq(SkillEffects.active_scene(skills["poison_breath"]), "res://scenes/abilities/poison_breath.tscn")
	assert_eq(SkillEffects.active_values(skills["poison_breath"]), [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
	assert_eq(SkillEffects.active_scene(skills["leap"]), "")
