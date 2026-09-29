extends GutTest

func _no_duplicates(list: Array) -> bool:
	var seen := {}
	for item in list:
		if seen.has(item):
			return false
		seen[item] = true
	return true

func test_events_cover_the_spec_vocabulary() -> void:
	var expected := ["jumped", "wall_touched", "damaged", "hp_low_entered", "hp_low_exited",
		"stunned_enemy", "predated", "absorbed", "inspected", "skill_used", "mana_spent",
		"skill_unlocked", "skill_leveled"]
	assert_eq(Events.ALL.size(), expected.size())
	for e in expected:
		assert_has(Events.ALL, e)
	assert_true(_no_duplicates(Events.ALL))
	assert_eq(Events.INTERNAL, ["skill_unlocked", "skill_leveled"])

func test_sources_essences_and_stat_keys() -> void:
	assert_eq(Sources.ALL, ["bat", "toad", "lizard", "spider", "water_pool", "serpent", "spore_moth", "mushroom_crab", "vine_snake"])
	assert_eq(Essences.ALL, ["sound", "flight", "poison", "water", "armor", "earth", "thread", "spore", "shell"])
	assert_eq(StatKeys.ALL, ["max_hp", "atk", "def", "spd", "jump_height", "slide_speed",
		"predation_time", "regen_interval", "max_mp", "mp_regen"])
	assert_eq(StatKeys.INTEGER, ["max_hp", "atk", "def", "max_mp"])
	assert_eq(StatKeys.PERCENT, ["spd", "jump_height", "slide_speed", "predation_time", "mp_regen"])
	assert_true(_no_duplicates(StatKeys.ALL))
