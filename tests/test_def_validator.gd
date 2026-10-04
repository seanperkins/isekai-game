extends GutTest

func _valid_skills() -> Array:
	return [
		TestDefs.skill("leap", {"unlock": [TestDefs.counter("jumped", 40)],
			"levels_on": {"event": "jumped", "tags": {}}, "level_curve": 40, "max_level": 2,
			"effects": [{"kind": "modifier", "stat": "jump_height", "op": "add", "values": [10, 15]}]}),
		TestDefs.skill("appraisal", {"starting": true}),
		TestDefs.skill("flight", {"source": "enemy_only"}),
	]

func _errors_with(skills: Array, creatures: Array = TestDefs.all_creatures()) -> String:
	return "\n".join(DefValidator.validate(skills, creatures))

func test_valid_set_passes() -> void:
	assert_eq(DefValidator.validate(_valid_skills(), TestDefs.all_creatures()).size(), 0)

func test_empty_directory_fails() -> void:
	assert_string_contains(_errors_with([]), "no skill defs found")

func test_missing_field_fails() -> void:
	var s := _valid_skills()
	s[0].display_name = ""
	assert_string_contains(_errors_with(s), "missing display_name")

func test_non_starting_skill_needs_unlock() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("orphan"))
	assert_string_contains(_errors_with(s), "needs at least one unlock condition")

func test_unknown_event_fails() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("bad", {"unlock": [TestDefs.counter("jumpd", 3)]}))
	assert_string_contains(_errors_with(s), "unknown event 'jumpd'")

func test_internal_event_in_counter_fails() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("bad", {"unlock": [TestDefs.counter("skill_leveled", 1)]}))
	assert_string_contains(_errors_with(s), "must not count internal event")

func test_internal_event_in_levels_on_fails() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("bad", {"unlock": [TestDefs.counter("jumped", 1)],
		"levels_on": {"event": "skill_unlocked", "tags": {}}, "level_curve": 1, "max_level": 2,
		"effects": [{"kind": "capability", "flag": "x"}]}))
	assert_string_contains(_errors_with(s), "must not count internal event")

func test_unknown_tag_source_and_essence_fail() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("bad1", {"unlock": [TestDefs.counter("predated", 1, {"source": "dragon"})]}))
	s.append(TestDefs.skill("bad2", {"unlock": [TestDefs.counter("absorbed", 1, {"essence": "fire"})]}))
	var errors := _errors_with(s)
	assert_string_contains(errors, "unknown source 'dragon'")
	assert_string_contains(errors, "unknown essence 'fire'")

func test_skill_level_cycle_fails() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("a", {"source": "evolution", "unlock": [TestDefs.level("b", 1)]}))
	s.append(TestDefs.skill("b", {"source": "evolution", "unlock": [TestDefs.level("a", 1)]}))
	assert_string_contains(_errors_with(s), "dependency cycle")

func test_skill_level_to_unknown_or_enemy_only_fails() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("e1", {"source": "evolution", "unlock": [TestDefs.level("nope", 1)]}))
	s.append(TestDefs.skill("e2", {"source": "evolution", "unlock": [TestDefs.level("flight", 1)]}))
	var errors := _errors_with(s)
	assert_string_contains(errors, "references unknown skill 'nope'")
	assert_string_contains(errors, "references enemy_only skill 'flight'")

func test_levelled_skill_needs_levels_on_and_curve() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("lv", {"unlock": [TestDefs.counter("jumped", 1)], "max_level": 3}))
	assert_string_contains(_errors_with(s), "needs levels_on and a positive level_curve")

func test_evolution_without_max_level_one_but_no_levelling_fails() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("evo", {"source": "evolution", "unlock": [TestDefs.level("leap", 2)], "max_level": 2}))
	assert_string_contains(_errors_with(s), "needs levels_on and a positive level_curve")

func test_values_length_must_match_max_level() -> void:
	var s := _valid_skills()
	s[0].effects = [{"kind": "modifier", "stat": "jump_height", "op": "add", "values": [10, 15, 20]}]
	assert_string_contains(_errors_with(s), "values has 3 entries but max_level is 2")

func test_compound_effect_is_valid() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("wall_cling", {"unlock": [TestDefs.counter("wall_touched", 15)],
		"levels_on": {"event": "wall_touched", "tags": {}}, "level_curve": 20, "max_level": 3,
		"effects": [{"kind": "capability", "flag": "wall_cling"},
			{"kind": "modifier", "stat": "slide_speed", "op": "add", "values": [-30, -45, -60]}]}))
	assert_eq(_errors_with(s), "")

func test_modifier_target_must_be_a_stat_key() -> void:
	var s := _valid_skills()
	s[0].effects = [{"kind": "modifier", "stat": "mana", "op": "add", "values": [1, 2]}]
	assert_string_contains(_errors_with(s), "modifier target 'mana' is not in StatKeys")

func test_active_scene_must_exist() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("zap", {"unlock": [TestDefs.counter("jumped", 1)],
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/nope.tscn"}]}))
	assert_string_contains(_errors_with(s), "active scene 'res://scenes/abilities/nope.tscn' does not exist")

func test_enemy_only_rules() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("tail", {"source": "enemy_only", "unlock": [TestDefs.counter("jumped", 1)]}))
	s.append(TestDefs.skill("big", {"source": "enemy_only", "max_level": 2,
		"levels_on": {"event": "jumped", "tags": {}}, "level_curve": 1}))
	var errors := _errors_with(s)
	assert_string_contains(errors, "enemy_only skill must not have an unlock")
	assert_string_contains(errors, "enemy_only skill must have max_level 1")

func test_creature_problems_fail() -> void:
	var creatures := TestDefs.all_creatures()
	creatures[0].essences = {"fire": 1}
	creatures[1].skills = [{"id": "nope", "level": 1}]
	creatures[2].skills = [{"id": "leap", "level": 3}]
	creatures[3].eat_bonus = {"stat": "mana", "amount": 1, "per": 1}
	creatures[4].appraisal_target = false
	var errors := _errors_with(_valid_skills(), creatures)
	assert_string_contains(errors, "unknown essence 'fire'")
	assert_string_contains(errors, "unknown skill id 'nope'")
	assert_string_contains(errors, "skill 'leap' level 3 is outside 1..2")
	assert_string_contains(errors, "eat_bonus stat 'mana' is not in StatKeys")
	assert_string_contains(errors, "appraisal_target may be false only on non-predatable sources")

func test_missing_and_duplicate_creature_defs_fail() -> void:
	var creatures := TestDefs.all_creatures()
	creatures = creatures.filter(func(c: CreatureDef) -> bool: return c.id != "serpent")  # drop serpent
	creatures.append(TestDefs.creature("bat"))
	var errors := _errors_with(_valid_skills(), creatures)
	assert_string_contains(errors, "missing CreatureDef for source 'serpent'")
	assert_string_contains(errors, "duplicate CreatureDef for 'bat'")

func test_wrong_resource_type_is_an_error_not_a_crash() -> void:
	var s := _valid_skills()
	s.append(TestDefs.creature("bat"))
	var c := TestDefs.all_creatures()
	c.append(TestDefs.skill("oops"))
	var errors := _errors_with(s, c)
	assert_string_contains(errors, "<bat>: is not a SkillDef")
	assert_string_contains(errors, "<oops>: is not a CreatureDef")

func test_replaces_must_name_a_parent() -> void:
	var s := _valid_skills()
	s.append(TestDefs.skill("evo", {"source": "evolution", "unlock": [TestDefs.level("leap", 1)], "replaces": "appraisal"}))
	assert_string_contains(_errors_with(s), "replaces 'appraisal', which is not a parent")

# --- evolutions replace their parent, alone, single-level, never starting ---

func _with_parent() -> Array:
	var s := _valid_skills()
	s.append(TestDefs.skill("parent", {"source": "essence", "unlock": [TestDefs.counter("jumped", 1)],
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/water_blade.tscn"}], "mp_cost": 3}))
	return s

func _evo(id: String, extra := {}) -> SkillDef:
	var f := {"source": "evolution", "replaces": "parent", "unlock": [TestDefs.level("parent", 3)],
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/water_blade.tscn"}], "mp_cost": 4}
	f.merge(extra, true)
	return TestDefs.skill(id, f)

func test_a_well_formed_pair_of_evolutions_is_valid() -> void:
	var s := _with_parent()
	s.append(_evo("a"))
	s.append(_evo("b"))
	assert_eq(_errors_with(s), "")

func test_an_evolution_needs_replaces() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"replaces": ""}))
	assert_string_contains(_errors_with(s), "an evolution needs replaces")

func test_an_evolution_needs_an_active_scene() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"effects": [{"kind": "capability", "flag": "a"}], "mp_cost": 0}))
	assert_string_contains(_errors_with(s), "an evolution needs an active scene")

func test_an_evolution_must_not_be_starting() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"starting": true}))
	assert_string_contains(_errors_with(s), "must not be starting")

func test_an_evolution_unlock_is_exactly_one_skill_level_on_its_parent() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"unlock": [TestDefs.level("parent", 3), TestDefs.level("leap", 2)]}))
	assert_string_contains(_errors_with(s), "exactly one skill_level condition on its replaces")

func test_an_evolution_is_single_level() -> void:
	var s := _with_parent()
	s.append(_evo("a", {"max_level": 2, "levels_on": {"event": "jumped", "tags": {}}, "level_curve": 5,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/water_blade.tscn", "values": [1, 2]}]}))
	assert_string_contains(_errors_with(s), "an evolution is single-level")

func test_siblings_share_the_unlock_level() -> void:
	var s := _with_parent()
	s.append(_evo("a"))
	s.append(_evo("b", {"unlock": [TestDefs.level("parent", 4)]}))
	assert_string_contains(_errors_with(s), "must unlock at the same level")

func test_an_evolution_of_an_evolution_is_rejected() -> void:
	var s := _with_parent()
	s.append(_evo("a"))
	s.append(_evo("b", {"replaces": "a", "unlock": [TestDefs.level("a", 1)]}))
	assert_string_contains(_errors_with(s), "which is itself an evolution")

func test_a_creatures_contact_type_and_projectile_must_be_known() -> void:
	var creatures := TestDefs.all_creatures()
	creatures[0].contact_type = "acid"
	assert_string_contains(_errors_with(_valid_skills(), creatures), "contact_type 'acid'")
	creatures[0].contact_type = "shock"
	creatures[1].projectile = "rock"
	assert_string_contains(_errors_with(_valid_skills(), creatures), "projectile 'rock'")
	creatures[1].projectile = "spear"
	assert_eq(DefValidator.validate(_valid_skills(), creatures).size(), 0)

func test_an_unknown_source_in_an_unlock_is_rejected() -> void:
	var s := [TestDefs.skill("s", {"unlock": [TestDefs.counter("predated", 3, {"source": "spidr"})]})]
	var errs := DefValidator.validate(s, TestDefs.all_creatures())
	assert_string_contains("\n".join(errs), "unknown source 'spidr'")

func test_an_unknown_element_in_an_unlock_is_rejected() -> void:
	var s := [TestDefs.skill("s", {"unlock": [TestDefs.counter("absorbed", 3, {"essence": "poison"})]})]
	var errs := DefValidator.validate(s, TestDefs.all_creatures())
	assert_string_contains("\n".join(errs), "unknown essence 'poison'")
