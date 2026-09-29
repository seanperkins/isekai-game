extends GutTest
## The Grotto's data: essences, sources, creature numbers, the two skills and the knockback route.

var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func test_new_essences_and_sources_are_registered() -> void:
	assert_true(Essences.ALL.has("spore"))
	assert_true(Essences.ALL.has("shell"))
	for id in ["spore_moth", "mushroom_crab", "vine_snake"]:
		assert_true(Sources.ALL.has(id), id)
		assert_true(creatures.has(id), id)

func test_the_creatures_have_the_approved_numbers() -> void:
	var want := {"spore_moth": [3, 1, 0, 90, 2, {"spore": 1, "flight": 1}],
		"mushroom_crab": [8, 2, 2, 70, 4, {"shell": 2, "earth": 1}],
		"vine_snake": [5, 3, 0, 150, 3, {"poison": 1, "thread": 1}]}
	for id in want:
		var c: CreatureDef = creatures[id]
		var w: Array = want[id]
		assert_eq([c.stats["max_hp"], c.stats["atk"], c.stats["def"], c.stats["spd"], c.xp, c.essences], w, id)

func test_only_the_lizard_and_crab_are_armored_chargers_and_only_moths_drift() -> void:
	for id in creatures:
		var c: CreatureDef = creatures[id]
		assert_eq(c.armored_charger, id == "lizard" or id == "mushroom_crab", id)
		assert_eq(c.drifter, id == "spore_moth" or id == "pale_moth", id)

func test_the_two_skills_match_the_spec() -> void:
	var sc: SkillDef = skills["spore_cloud"]
	assert_eq([sc.source, sc.max_level, sc.level_curve, sc.mp_cost], ["essence", 8, 8, 4])
	assert_eq(sc.unlock[0]["tags"], {"essence": "spore"})
	assert_eq(sc.unlock[0]["n"], 4)
	var hs: SkillDef = skills["hardened_shell"]
	assert_eq([hs.source, hs.max_level, hs.level_curve], ["essence", 8, 10])
	assert_eq(hs.unlock[0]["tags"], {"essence": "shell"})
	assert_eq(hs.effects[0]["stat"], "knockback_taken")
	assert_eq(hs.effects[0]["values"], [-8, -16, -24, -32, -40, -48, -56, -64])

func test_knockback_factor_is_one_with_no_skill_and_floors_at_036() -> void:
	var hs: SkillDef = skills["hardened_shell"]
	assert_eq(SkillEffects.knockback_factor([]), 1.0, "no skill: full knockback, not the missing-key zero")
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 1]]), 0.92, 0.0001)
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 4]]), 0.68, 0.0001)
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 8]]), 0.36, 0.0001)
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 8], [hs, 8]]), 0.36, 0.0001, "the floor guards a second source")

func test_the_content_validates_and_both_skills_have_icons() -> void:
	var loaded := DefLoader.load_content("res://data/skills", "res://data/creatures")
	assert_eq(loaded["errors"].size(), 0, str(loaded["errors"]))
	assert_not_null(Art.texture("icon_spore_cloud"))
	assert_not_null(Art.texture("icon_hardened_shell"))
