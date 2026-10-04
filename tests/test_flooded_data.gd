extends GutTest
## The Flooded Tunnels' skills and creatures as data: the numbers the spec fixes.

var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func test_the_new_ids_are_sources_and_have_defs() -> void:
	for id in ["glass_eel", "cave_crayfish", "drift_jelly", "bog_lizardman"]:
		assert_true(Sources.ALL.has(id), id)
		assert_true(creatures.has(id), id)
	assert_true(Essences.ALL.has(Essences.LIGHT))

func test_creature_numbers_and_flags() -> void:
	var eel: CreatureDef = creatures["glass_eel"]
	assert_eq(eel.xp, 3)
	assert_eq(eel.essences, {"light": 1, "air": 1, "water": 1})
	assert_true(eel.swimmer)
	assert_eq(eel.contact_type, "shock")
	assert_eq(eel.stats["spd"], 140)
	var crayfish: CreatureDef = creatures["cave_crayfish"]
	assert_eq(crayfish.xp, 5)
	assert_true(crayfish.armored_charger)
	assert_eq(crayfish.contact_type, "physical")
	assert_eq(crayfish.essences, {"earth": 1, "water": 1})
	var jelly: CreatureDef = creatures["drift_jelly"]
	assert_eq(jelly.xp, 3)
	assert_true(jelly.drifter and jelly.swimmer and jelly.untackleable)
	assert_eq(jelly.contact_type, "shock")
	assert_eq(jelly.essences, {"light": 1, "air": 1, "water": 2})
	var lizardman: CreatureDef = creatures["bog_lizardman"]
	assert_eq(lizardman.xp, 5)
	assert_eq(lizardman.projectile, "spear")
	assert_eq(lizardman.skills, [], "no poison_spit: a spear is not poison")
	assert_eq(lizardman.essences, {"earth": 1, "water": 1})

func test_the_stats_are_scaled_like_the_grottos() -> void:
	var eel: CreatureDef = creatures["glass_eel"]
	assert_eq(eel.stats["max_hp"], floori(float(4 * (100 + 8 * 6) + 50) / 100.0), "level 7")
	assert_eq(eel.stats["max_hp"], 6)
	assert_eq(eel.stats["spd"], 140, "SPD is not scaled")

func test_only_the_moths_puff() -> void:
	assert_true((creatures["spore_moth"] as CreatureDef).puffs)
	assert_true((creatures["pale_moth"] as CreatureDef).puffs)
	for id in creatures:
		if id != "spore_moth" and id != "pale_moth":
			assert_false((creatures[id] as CreatureDef).puffs, id)

func test_swim_and_jolt() -> void:
	var swim: SkillDef = skills["swim"]
	assert_eq(swim.source, "proficiency")
	assert_eq(swim.unlock[0]["event"], "submerged")
	assert_eq(swim.unlock[0]["n"], 20)
	assert_eq(swim.max_level, 3)
	assert_eq(swim.level_curve, 40)
	assert_true(swim.effects.any(func(e): return e.get("flag", "") == "swim"))
	var speed: Dictionary = swim.effects.filter(func(e): return e.get("stat", "") == "swim_speed")[0]
	assert_eq(speed["values"], [0, 30, 60])
	var jolt: SkillDef = skills["jolt"]
	assert_eq(jolt.source, "essence")
	assert_eq(jolt.mp_cost, 5)
	assert_eq(jolt.unlock[0]["tags"], {"essence": "light"})
	assert_eq(jolt.unlock[1]["tags"], {"essence": "air"})
	assert_eq(jolt.max_level, 5)
	assert_eq(jolt.effects[0]["values"], [3, 4, 5, 6, 7])

func test_the_storm_eel_is_the_eels_behaviour_on_bigger_numbers() -> void:
	var storm: CreatureDef = creatures["storm_eel"]
	var eel: CreatureDef = creatures["glass_eel"]
	assert_true(Sources.ALL.has("storm_eel"))
	assert_true(storm.swimmer)
	assert_eq(storm.contact_type, "shock")
	assert_eq(storm.xp, 10)
	assert_eq(storm.essences, {"light": 3, "air": 3, "water": 2})
	assert_eq(storm.stats["spd"], 160)
	assert_gt(storm.stats["max_hp"], eel.stats["max_hp"])
	assert_gt(storm.stats["atk"], eel.stats["atk"])

func test_the_storm_eels_sheet_is_the_eels_frames_enlarged() -> void:
	var eel := SpriteSheet.load_set("glass_eel")
	var storm := SpriteSheet.load_set("storm_eel")
	assert_eq(storm.frame_names().size(), eel.frame_names().size())
	for n in eel.frame_names():
		assert_true(storm.has_frame(n), n)
		assert_gt(storm.frame_size(n).x, eel.frame_size(n).x, "%s is enlarged" % n)
