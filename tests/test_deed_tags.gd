extends GutTest
## DeedTags.for_defeat: how a kill was made, from what the last blow and the player's surroundings say. Pure.

func _def(id := "bat", hp := 3, species := "") -> CreatureDef:
	var c := TestDefs.creature(id, {"species": species})
	c.stats = {"max_hp": hp, "atk": 1, "def": 0, "spd": 100}
	return c

func _tags(blow := {}, ctx := {}, def := _def()) -> Dictionary:
	return DeedTags.for_defeat(def, blow, ctx)

func test_a_kill_with_nothing_recorded_has_only_its_source() -> void:
	assert_eq(_tags(), {"source": "bat"})

func test_species_is_there_only_when_the_creature_has_one() -> void:
	assert_eq(_tags({}, {}, _def("twin_wolf_fenrir", 26, "wolf"))["species"], "wolf")
	assert_false(_tags().has("species"))

func test_a_tackle_from_behind() -> void:
	assert_eq(_tags({"from_behind": true})["behind"], true)
	assert_false(_tags({"from_behind": false}).has("behind"))

func test_a_blow_from_far_away_is_ranged_at_the_threshold() -> void:
	assert_false(_tags({"distance": DeedTags.RANGED_PX - 1.0}).has("ranged"))
	assert_true(_tags({"distance": DeedTags.RANGED_PX}).has("ranged"))

func test_poison() -> void:
	assert_true(_tags({"damage_type": "poison"}).has("poison"))
	assert_false(_tags({"damage_type": "physical"}).has("poison"))

func test_a_heavy_foe_has_hp_at_the_threshold() -> void:
	assert_false(_tags({}, {}, _def("x", DeedTags.HEAVY_HP - 1)).has("heavy"))
	assert_true(_tags({}, {}, _def("x", DeedTags.HEAVY_HP)).has("heavy"))

func test_marked() -> void:
	assert_true(_tags({"marked": true}).has("marked"))
	assert_false(_tags({"marked": false}).has("marked"))

func test_unseen_means_the_enemy_was_not_alert_and_needs_a_recorded_blow() -> void:
	assert_true(_tags({"alert": false}).has("unseen"))
	assert_false(_tags({"alert": true}).has("unseen"))
	assert_false(_tags().has("unseen"), "no blow data is not an unseen kill")

func test_fleeing() -> void:
	assert_true(_tags({"fleeing": true}).has("fleeing"))
	assert_false(_tags({"fleeing": false}).has("fleeing"))

func test_the_ceiling_and_the_dark_come_from_the_players_surroundings() -> void:
	var t := _tags({}, {"ceiling": true, "dark": true})
	assert_true(t.has("ceiling") and t.has("dark"))
	assert_false(_tags({}, {"ceiling": false, "dark": false}).has("ceiling"))

func test_false_flags_are_left_out_so_a_gate_can_ask_for_true() -> void:
	var t := _tags({"from_behind": false, "damage_type": "physical", "distance": 0.0, "marked": false, "alert": true, "fleeing": false})
	assert_eq(t, {"source": "bat"})

func test_every_tag_it_makes_is_one_a_gate_may_name() -> void:
	var all := _tags({"from_behind": true, "distance": 99.0, "damage_type": "poison", "marked": true, "alert": false, "fleeing": true},
		{"ceiling": true, "dark": true}, _def("x", 40, "goblin"))
	for key in all:
		assert_true((Deeds.TAGS[Deeds.DEFEATED] as Array).has(key), key)

func test_the_dark_areas() -> void:
	assert_true(DeedTags.is_dark_area("deep"))
	assert_false(DeedTags.is_dark_area("cave"))
