extends GutTest
## A goblin learns what it meets instead of devouring it: its first dealing with a type pays that essence once, a repeat a trickle,
## and eating only heals. Every other species eats as it always did.

var skills: Array
var skills_by_id := {}
var creatures := {}
var rules: SkillRulesEngine
var player: Player
var events: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _make(species: String) -> Player:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	events = []
	var p := Player.new()
	p.species = species
	p.use_sheet = false
	p.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	player = p
	return p

func _def(id: String, essences: Dictionary, species := "") -> CreatureDef:
	return TestDefs.creature(id, {"essences": essences, "species": species})

func _enemy(def: CreatureDef) -> Enemy:
	var e := Enemy.new()
	e.setup(def, skills_by_id)
	add_child_autofree(e)
	return e

func _named(event: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == event).map(func(e: Array) -> Dictionary: return e[1])

func _absorbed() -> Array:
	return _named(Events.ABSORBED).map(func(t: Dictionary) -> String: return t["essence"])

# --- learning ---

func test_a_goblins_first_dealing_says_the_lesson_and_pays_every_unit() -> void:
	_make("goblin")
	player.learn_from(_enemy(_def("t_a", {"dark": 1, "earth": 2}, "wolf")))
	assert_eq(_named(Deeds.LESSON_LEARNED), [{"creature": "t_a", "species": "wolf", "element": "earth"}])
	assert_eq(_absorbed(), ["earth", "earth", "dark"])
	assert_eq(_named(Events.ABSORBED)[0]["source"], "t_a")

func test_a_lesson_leaves_out_a_species_the_creature_has_not() -> void:
	_make("goblin")
	player.learn_from(_enemy(_def("t_a", {"earth": 1})))
	assert_eq(_named(Deeds.LESSON_LEARNED), [{"creature": "t_a", "element": "earth"}])

func test_a_creature_pays_once_however_often_it_is_dealt_with() -> void:
	_make("goblin")
	var e := _enemy(_def("t_a", {"earth": 2}))
	player.learn_from(e)
	player.learn_from(e)
	assert_eq(_absorbed(), ["earth", "earth"])
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 1)

func test_a_second_creature_of_a_known_type_pays_a_trickle_and_no_lesson() -> void:
	_make("goblin")
	player.learn_from(_enemy(_def("t_a", {"dark": 1, "earth": 2})))
	events.clear()
	player.learn_from(_enemy(_def("t_a", {"dark": 1, "earth": 2})))
	assert_eq(_absorbed(), ["earth"])
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 0)

func test_two_types_say_two_lessons() -> void:
	_make("goblin")
	player.learn_from(_enemy(_def("t_a", {"earth": 1})))
	player.learn_from(_enemy(_def("t_b", {"water": 1})))
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 2)

func test_a_creature_with_no_essences_teaches_and_pays_nothing() -> void:
	_make("goblin")
	player.learn_from(_enemy(_def("t_blank", {})))
	assert_eq(_named(Deeds.LESSON_LEARNED), [{"creature": "t_blank"}])
	assert_eq(_absorbed(), [])

func test_a_dead_goblin_learns_nothing() -> void:
	_make("goblin")
	player.receive_hit(player.health.max_hp * 5, "fire")
	events.clear()
	player.learn_from(_enemy(_def("t_a", {"earth": 1})))
	assert_eq(events, [])

func test_only_a_goblin_learns() -> void:
	for species in ["slime", "wolf", "undead", "spider"]:
		_make(species)
		player.learn_from(_enemy(_def("t_a", {"earth": 1})))
		assert_eq(events, [], species)

func test_a_new_run_forgets_the_lessons() -> void:
	_make("goblin")
	player.learn_from(_enemy(_def("t_a", {"earth": 1})))
	rules.start_run()
	events.clear()
	player.learn_from(_enemy(_def("t_a", {"earth": 1})))
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 1, "first again")

# --- eating ---

func test_a_goblin_eating_a_creature_alive_learns_it_and_heals() -> void:
	_make("goblin")
	player.health.hp = 1
	var e := _enemy(_def("t_a", {"dark": 1, "earth": 2}))
	e.status.stun(10.0)
	player._complete_predation(e)
	assert_eq(_absorbed(), ["earth", "earth", "dark"], "the lesson's units, not the lesson and the meal")
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 1)
	assert_eq(_named(Events.PREDATED).size(), 1)
	assert_gt(player.health.hp, 1)

func test_downing_then_eating_a_creature_pays_once() -> void:
	_make("goblin")
	var e := _enemy(_def("t_a", {"earth": 2}))
	player.learn_from(e)  # downed
	player._complete_predation(e)  # eaten
	assert_eq(_absorbed(), ["earth", "earth"])
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 1)

func test_a_goblin_drinking_a_pool_pays_the_water_as_before_and_learns_nothing() -> void:
	_make("goblin")
	var pool := WaterPool.new()
	pool.setup(creatures[Sources.WATER_POOL])
	add_child_autofree(pool)
	player._complete_predation(pool)
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 0)
	assert_gt(_absorbed().size(), 0, "terrain is not a creature to learn from")
	assert_eq(_absorbed().filter(func(e: String) -> bool: return e != "water").size(), 0)

func test_the_other_species_eat_as_they_always_did() -> void:
	for species in ["slime", "wolf", "undead", "spider"]:
		_make(species)
		var e := _enemy(_def("t_a", {"dark": 1, "earth": 2}))
		e.status.stun(10.0)
		player._complete_predation(e)
		assert_eq(_absorbed(), ["earth", "earth", "dark"], species)
		assert_eq(_named(Deeds.LESSON_LEARNED).size(), 0, species)

# --- in the room ---

func _game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	return game

func _lessons_from(id: String) -> int:
	return SkillRules.condition_value({"kind": "counter", "event": Deeds.LESSON_LEARNED, "tags": {"creature": id}, "n": 1})

func test_a_goblin_that_downs_a_creature_in_the_room_learns_it() -> void:
	var game = await _game()
	game.player.set_species("goblin")
	var e: Enemy = game._spawn("bat", game.player.global_position + Vector2(120, -40))
	game.world.room.add_child(e)
	e.receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(2)
	assert_eq(_lessons_from("bat"), 1)

func test_eating_what_it_downed_does_not_teach_it_twice() -> void:
	var game = await _game()
	game.player.set_species("goblin")
	var e: Enemy = game._spawn("bat", game.player.global_position + Vector2(120, -40))
	game.world.room.add_child(e)
	e.receive_hit(999, "physical", game.player.global_position)
	await wait_physics_frames(2)
	game.player._complete_predation(e)
	await wait_physics_frames(1)
	assert_eq(_lessons_from("bat"), 1)
