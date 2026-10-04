extends GutTest
## The Deep's skill and creatures as data: the numbers the spec fixes, and the Tremor threshold that keeps the skill out of the Cave.

var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func test_the_new_ids_are_sources_and_have_defs() -> void:
	for id in ["gloom_wolf", "armed_ant", "stone_drake"]:
		assert_true(Sources.ALL.has(id), id)
		assert_true(creatures.has(id), id)

func test_creature_numbers_and_flags() -> void:
	var wolf: CreatureDef = creatures["gloom_wolf"]
	assert_eq(wolf.xp, 6)
	assert_eq(wolf.essences, {"air": 1, "earth": 1})
	assert_true(wolf.charges and wolf.pack)
	assert_false(wolf.armored_charger)
	assert_eq(wolf.stats["spd"], 100)
	var ant: CreatureDef = creatures["armed_ant"]
	assert_eq(ant.xp, 3)
	assert_eq(ant.essences, {"earth": 2})
	assert_true(ant.pack)
	assert_false(ant.charges or ant.stomper or ant.armored_charger)
	var drake: CreatureDef = creatures["stone_drake"]
	assert_eq(drake.xp, 12)
	assert_eq(drake.essences, {"earth": 4})
	assert_true(drake.armored_charger and drake.stomper)
	assert_false(drake.pack)
	assert_eq(drake.stats["spd"], 40)

func test_the_stats_are_scaled_at_level_10() -> void:
	# _scaled: +8% a level, rounded half up: x1.72 at level 10
	var want := {"gloom_wolf": [10, 5, 0], "armed_ant": [9, 3, 2], "stone_drake": [28, 7, 5]}
	for id in want:
		var c: CreatureDef = creatures[id]
		assert_eq([c.stats["max_hp"], c.stats["atk"], c.stats["def"]], want[id], id)

func test_only_the_deeps_creatures_carry_the_new_flags() -> void:
	for id in creatures:
		var c: CreatureDef = creatures[id]
		if not ["gloom_wolf", "armed_ant", "stone_drake", "taratect"].has(id):
			assert_false(c.pack or c.charges or c.stomper, id)

func test_tremor() -> void:
	var t: SkillDef = skills["tremor"]
	assert_eq(t.source, "essence")
	assert_eq(t.mp_cost, 5)
	assert_eq(t.unlock[0]["tags"], {"essence": "earth"})
	assert_eq(t.unlock[0]["n"], 59)
	assert_eq(t.max_level, 5)
	assert_eq(t.effects[0]["values"], [3, 4, 5, 6, 7])

## Earth is already in the Cave's lizards, the Grotto's crabs and the Flooded's lizardmen. The threshold must stay above what they hold,
## or a life that eats the Cave gets an armor-piercing skill at its start (a respawning room can be lapped, so this raises the cost).
func test_the_tremor_threshold_is_above_the_pre_deep_earth_supply() -> void:
	var rooms := ShippedRooms.load_all()
	var units := 0
	for id in rooms:
		var r: RoomDef = rooms[id]
		if r.area == "deep":
			continue
		for s in r.spawns:
			units += int((creatures[s["id"]] as CreatureDef).essences.get("earth", 0))
	assert_gt(int((skills["tremor"] as SkillDef).unlock[0]["n"]), units, "the pre-Deep rooms hold %d earth units (4 lizards, 12 crabs, 5 crayfish, 6 lizardmen)" % units)
