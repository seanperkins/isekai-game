extends GutTest
## What a creature leaves: its own drops and, for a large one, ribs and flesh. A roll is per entry, from the rng it is given.

var creatures := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _def(hp := 3, drops := [], predatable := true) -> CreatureDef:
	var c := TestDefs.creature("bat", {"drops": drops, "predatable": predatable, "appraisal_target": predatable})
	c.stats = {"max_hp": hp, "atk": 1, "def": 0, "spd": 100}
	return c

func _rng(seed := 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func test_a_certain_drop_is_always_left_and_an_impossible_one_never() -> void:
	var sure := _def(3, [{"part": "claw", "chance": 1.0}])
	var never := _def(3, [{"part": "claw", "chance": 0.0}])
	var rng := _rng()
	for i in 50:
		assert_eq(Drops.roll(sure, rng), ["claw"])
		assert_eq(Drops.roll(never, rng), [])

func test_every_entry_is_rolled_once() -> void:
	var d := _def(3, [{"part": "claw", "chance": 1.0}, {"part": "skull", "chance": 1.0}])
	assert_eq(Drops.roll(d, _rng()), ["claw", "skull"])

func test_a_roll_is_repeatable_from_a_seed() -> void:
	var d := _def(3, [{"part": "claw", "chance": 0.5}, {"part": "skull", "chance": 0.5}])
	var a := _rng(42)
	var b := _rng(42)
	for i in 40:
		assert_eq(Drops.roll(d, a), Drops.roll(d, b))

func test_a_chance_is_a_fraction_of_the_rolls() -> void:
	var d := _def(3, [{"part": "claw", "chance": 0.3}])
	var rng := _rng(3)
	var hits := 0
	for i in 2000:
		hits += Drops.roll(d, rng).size()
	assert_between(hits, 480, 720, "about 30% of 2000")

func test_a_large_creature_can_leave_ribs_or_flesh_and_a_small_one_cannot() -> void:
	var big := _def(DeedTags.HEAVY_HP)
	var small := _def(DeedTags.HEAVY_HP - 1)
	var rng := _rng(5)
	var seen := {}
	for i in 500:
		for p in Drops.roll(big, rng):
			seen[p] = true
		assert_eq(Drops.roll(small, rng), [])
	assert_eq(seen.keys().size(), 2)
	assert_true(seen.has("ribs") and seen.has("flesh"))

func test_a_large_creature_that_cannot_be_eaten_leaves_nothing_extra() -> void:
	assert_eq(Drops.for_def(_def(40, [], false)), [])

func test_a_large_creatures_own_ribs_are_not_doubled() -> void:
	var d := _def(40, [{"part": "ribs", "chance": 1.0}])
	var entries := Drops.for_def(d)
	assert_eq(entries.filter(func(e: Dictionary) -> bool: return e["part"] == "ribs").size(), 1)
	assert_eq(entries.filter(func(e: Dictionary) -> bool: return e["part"] == "flesh").size(), 1, "the other large-corpse part is still there")
	assert_eq(Drops.for_def(d)[0]["chance"], 1.0, "its own chance wins")

func test_the_shipped_creatures_leave_what_the_design_says() -> void:
	var want := {
		"gloom_wolf": ["claw"], "bog_lizardman": ["claw"], "skeleton": ["ribs", "skull"], "village_goblin": ["bow_arm"],
		"shield_guard": ["weapon_arm"], "goblin_shaman": ["focus"], "chapel_priest": ["focus"], "moon_hare": ["moonstone"],
		"twin_undead_zombie": ["flesh", "ribs"], "twin_undead_ghoul": ["claw", "flesh", "ribs"], "twin_undead_bone_warrior": ["weapon_arm"],
		"twin_undead_draugr": ["weapon_arm"], "twin_undead_skeletal_archer": ["bow_arm"], "twin_undead_mummy_priest": ["wrappings"],
		"twin_undead_lich": ["phylactery_shard"]}
	for id in want:
		var own: Array = (creatures[id] as CreatureDef).drops.map(func(e: Dictionary) -> String: return e["part"])
		own.sort()
		assert_eq(own, want[id], id)

func test_the_moonstone_and_the_shard_are_rare() -> void:
	assert_eq(creatures["moon_hare"].drops[0]["chance"], 0.15)
	assert_eq(creatures["twin_undead_lich"].drops[0]["chance"], 0.1)

func test_a_creature_with_no_design_drops_has_none_of_its_own() -> void:
	for id in ["bat", "toad", "lizard", "spider", "twin_wolf_fenrir"]:
		assert_eq(creatures[id].drops, [], id)

func test_the_validator_rejects_an_unknown_part_and_a_chance_outside_zero_to_one() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var good := _creatures_with("bat", [{"part": "claw", "chance": 0.5}])
	assert_false(_has_error(DefValidator.validate(skills, good), "drop"))
	assert_true(_has_error(DefValidator.validate(skills, _creatures_with("bat", [{"part": "nothing", "chance": 0.5}])), "unknown part 'nothing'"))
	assert_true(_has_error(DefValidator.validate(skills, _creatures_with("bat", [{"part": "claw", "chance": 1.5}])), "chance"))
	assert_true(_has_error(DefValidator.validate(skills, _creatures_with("bat", [{"part": "claw", "chance": 0.0}])), "chance"))
	assert_true(_has_error(DefValidator.validate(skills, _creatures_with("bat", [{"chance": 0.5}])), "part"))

func _creatures_with(id: String, drops: Array) -> Array:
	var out: Array = []
	for c in TestDefs.all_creatures():
		out.append(TestDefs.creature(id, {"drops": drops}) if c.id == id else c)
	return out

func _has_error(errors: PackedStringArray, part: String) -> bool:
	return Array(errors).any(func(e: String) -> bool: return e.contains(part))
