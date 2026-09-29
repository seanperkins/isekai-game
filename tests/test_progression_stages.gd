extends GutTest
## Stages, the level cap, and first-time XP: the run's arc.

func test_the_stage_curves_and_totals_match_the_spec() -> void:
	var totals := []
	for stage in [1, 2, 3, 4]:
		totals.append(Progression.stage_total(stage))
	assert_eq(totals, [270, 403, 540, 673])
	var sum := 0
	for t in totals:
		sum += t
	assert_eq(sum, 1886)

func test_each_level_of_a_stage_is_floored_not_rounded() -> void:
	assert_eq(Progression.xp_to_next(1), 10)
	assert_eq(Progression.xp_to_next(2), 15)
	assert_eq(Progression.xp_to_next(1, 2), 15)
	assert_eq(Progression.xp_to_next(2, 2), 22, "22.5 rounds down")
	assert_eq(Progression.xp_to_next(3, 2), 30)
	assert_eq(Progression.xp_to_next(2, 4), 37, "37.5 rounds down")

func test_xp_stops_at_the_level_cap_and_the_excess_is_discarded() -> void:
	var p := Progression.new()
	p.add_xp(Progression.stage_total(1) + 500)
	assert_eq(p.level, Progression.LEVEL_CAP)
	assert_eq(p.xp, 0, "nothing left over to carry")
	assert_true(p.at_cap())
	p.add_xp(99)
	assert_eq(p.level, Progression.LEVEL_CAP)
	assert_eq(p.xp, 0)

func test_the_body_can_evolve_at_the_cap_until_the_last_stage() -> void:
	var p := Progression.new()
	assert_false(p.can_evolve())
	p.add_xp(Progression.stage_total(1))
	assert_true(p.can_evolve())
	p.stage = 4
	assert_false(p.can_evolve(), "stage 4 is the last")

func test_evolving_resets_the_level_but_keeps_the_ep() -> void:
	var p := Progression.new()
	p.add_xp(Progression.stage_total(1))
	var ep := p.ep
	assert_eq(ep, 9)
	p.evolve_stage()
	assert_eq(p.stage, 2)
	assert_eq(p.level, 1)
	assert_eq(p.xp, 0)
	assert_eq(p.ep, ep, "EP persists")
	p.add_xp(Progression.stage_total(2))
	assert_eq(p.level, Progression.LEVEL_CAP, "stage 2 has its own, longer curve")

func test_leveling_gives_ep_only_below_the_cap() -> void:
	var p := Progression.new()
	p.add_xp(Progression.stage_total(1) + 200)
	assert_eq(p.ep, 9, "nine level-ups, then nothing more")

func test_a_spawn_pays_in_full_once_for_the_down_and_once_for_the_eat_then_a_quarter() -> void:
	var p := Progression.new()
	assert_eq(p.award("C1:3", "down", 5), 5)
	assert_eq(p.award("C1:3", "eat", 5), 5, "the eat is its own first-time reward")
	assert_eq(p.award("C1:3", "down", 5), 1, "a repeat pays floor(5/4)")
	assert_eq(p.award("C1:3", "eat", 5), 1)
	assert_eq(p.award("C1:4", "down", 5), 5, "another spawn point is fresh")

func test_repeats_of_small_creatures_pay_nothing() -> void:
	var p := Progression.new()
	p.award("C1:0", "down", 2)
	assert_eq(p.award("C1:0", "down", 2), 0, "bats pay 0 on repeat")
	p.award("C1:1", "down", 3)
	assert_eq(p.award("C1:1", "down", 3), 0, "toads and spiders too")

func test_a_spawn_killed_at_the_cap_keeps_its_first_time_reward() -> void:
	var p := Progression.new()
	p.add_xp(Progression.stage_total(1))
	assert_true(p.at_cap())
	assert_eq(p.award("C1:7", "down", 5), 0, "no XP at the cap")
	p.evolve_stage()
	assert_eq(p.award("C1:7", "down", 5), 5, "still fresh after evolving")

func test_an_untracked_award_with_no_key_is_always_full() -> void:
	var p := Progression.new()
	assert_eq(p.award("", "down", 5), 5)
	assert_eq(p.award("", "down", 5), 5)

func test_a_full_first_pass_of_the_cave_stays_under_the_stage_one_cap() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var p := Progression.new()
	var paid := 0
	for id in rooms:
		var r: RoomDef = rooms[id]
		if r.area != "cave":
			continue  # the Cave alone: the Grotto's pacing is in test_grotto_rooms
		for i in r.spawns.size():
			var c: CreatureDef = creatures[r.spawns[i]["id"]]
			var key := "%s:%d" % [id, i]
			paid += p.award(key, "down", c.xp)
			if c.id != "water_pool":
				paid += p.award(key, "eat", c.xp)
	assert_lt(paid, Progression.stage_total(1), "one pass through the Cave cannot reach the cap (%d of %d)" % [paid, Progression.stage_total(1)])

func test_room_spawn_keys_are_room_and_index() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var seen: Array = []
	var def: RoomDef = rooms["C1"]
	var ctx := {"spawn": func(_id: String, _pos: Vector2) -> Node:
		var n := Node2D.new()
		n.set_script(_keyed())
		seen.append(n)
		return n}
	var node := RoomBuilder.build_room(def, ctx)
	add_child_autofree(node)
	assert_eq(seen.size(), def.spawns.size())
	for i in seen.size():
		assert_eq(seen[i].spawn_key, "C1:%d" % i)

func _keyed() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar spawn_key := ''\n"
	s.reload()
	return s

func test_the_player_pays_first_time_xp_through_the_downed_signal_and_the_eat() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var player := Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var lizard: CreatureDef
	for c in DefLoader.load_dir("res://data/creatures"):
		if c.id == "lizard":
			lizard = c
	player.on_enemy_downed(lizard, "C1:8")
	assert_eq(player.progression.xp, 5)
	player.on_enemy_downed(lizard, "C1:8")
	assert_eq(player.progression.xp, 6, "the repeat pays 1")
	player.on_enemy_downed(lizard)
	assert_eq(player.progression.level, 2, "5 + 1 + 5 = 11 XP crosses the level-2 threshold of 10")
	assert_eq(player.progression.xp, 1, "no key: paid in full")
