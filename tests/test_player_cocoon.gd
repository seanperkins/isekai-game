extends GutTest
## A spider webs a stunned creature into a cocoon, carries it, eats it later or lets it go.

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

func _make(species := "spider", catalog: Array = []) -> Player:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	events = []
	var p := Player.new()
	p.species = species
	p.use_sheet = false
	p.setup(rules, CompendiumModel.new(skills, []), catalog, func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	player = p
	return p

func _def(id := "t_prey", essences := {"earth": 1}) -> CreatureDef:
	var d := TestDefs.creature(id, {"essences": essences})
	d.stats = {"max_hp": 4, "atk": 2, "def": 0, "spd": 100}
	return d

func _creature(def: CreatureDef, offset := Vector2(10, 0), stunned := true) -> Enemy:
	var e := Enemy.new()
	e.setup(def, skills_by_id)
	e.position = player.position + offset
	add_child_autofree(e)
	if stunned:
		e.status.stun(30.0)
	return e

func _named(event: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == event).map(func(e: Array) -> Dictionary: return e[1])

# --- cocooning ---

func test_a_spider_webs_a_stunned_creature_into_a_cocoon() -> void:
	_make()
	var e := _creature(_def())
	assert_true(player.try_cocoon())
	assert_true(e.is_queued_for_deletion(), "it leaves the room")
	assert_eq(player.inventory.cocoons(), ["t_prey"])
	assert_eq(_named(Deeds.PREY_COCOONED), [{"creature": "t_prey"}])
	assert_eq(_named(Deeds.ITEM_CARRIED).size(), 1, "a cocoon is a carried item like any other")
	assert_eq(_named(Deeds.DEFEATED).size(), 0)
	assert_eq(_named(Events.PREDATED).size(), 0)

func test_an_active_a_downed_a_dormant_or_a_far_creature_is_not_cocooned() -> void:
	_make()
	var active := _creature(_def("t_a"), Vector2(10, 0), false)
	var downed := _creature(_def("t_b"))
	downed.status.state = EnemyStatus.ACTIVE
	downed.receive_hit(999, "physical", Vector2.INF)
	downed.finish_dying()
	var dormant := _creature(_def("t_c"))
	dormant.dormant = true
	var far := _creature(_def("t_d"), Vector2(Player.PREDATE_RANGE + 40.0, 0))
	assert_false(player.try_cocoon())
	assert_eq(player.inventory.cocoons(), [])
	assert_false(active.is_queued_for_deletion())
	assert_false(far.is_queued_for_deletion())

func test_a_creature_that_cannot_be_eaten_is_not_cocooned() -> void:
	_make()
	var d := _def("t_boss")
	d.predatable = false
	d.appraisal_target = false
	var e := _creature(d)
	assert_false(e.can_be_cocooned())
	assert_false(player.try_cocoon())

func test_a_third_cocoon_is_refused_and_the_creature_stays() -> void:
	_make()
	_creature(_def("t_a"))
	_creature(_def("t_b"), Vector2(40, 0))
	assert_true(player.try_cocoon())
	player.position = Vector2(40, 0)
	assert_true(player.try_cocoon())
	player.position = Vector2(80, 0)
	var third := _creature(_def("t_c"), Vector2(10, 0))
	assert_false(player.try_cocoon())
	assert_false(third.is_queued_for_deletion())
	assert_eq(player.inventory.cocoons(), ["t_a", "t_b"])

func test_only_a_spider_cocoons() -> void:
	for species in ["slime", "wolf", "goblin", "undead"]:
		_make(species)
		var e := _creature(_def())
		assert_false(player.try_cocoon(), species)
		assert_false(e.is_queued_for_deletion(), species)

func test_a_dead_spider_cocoons_nothing() -> void:
	_make()
	var e := _creature(_def())
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_false(player.try_cocoon())
	assert_false(e.is_queued_for_deletion())

func test_the_nearest_stunned_creature_is_the_one_webbed() -> void:
	_make()
	var near := _creature(_def("t_near"), Vector2(8, 0))
	var far := _creature(_def("t_far"), Vector2(24, 0))
	player.try_cocoon()
	assert_true(near.is_queued_for_deletion())
	assert_false(far.is_queued_for_deletion())

func test_inspect_cocoons_before_it_inspects() -> void:
	_make()
	_creature(_def())
	watch_signals(player)
	player.do_inspect()
	assert_eq(player.inventory.cocoons(), ["t_prey"])
	assert_signal_not_emitted(player, "inspect_report")

func test_inspect_inspects_when_there_is_nothing_to_web() -> void:
	_make()
	watch_signals(player)
	player.do_inspect()
	assert_signal_emitted(player, "inspect_report")

func test_enemy_can_be_cocooned_only_when_alive_awake_stunned_and_edible() -> void:
	_make()
	var e := _creature(_def(), Vector2(10, 0), false)
	assert_false(e.can_be_cocooned(), "active")
	e.status.stun(10.0)
	assert_true(e.can_be_cocooned())
	e.dormant = true
	assert_false(e.can_be_cocooned(), "dormant")

# --- eaten later ---

func test_eating_a_cocoon_is_eating_the_creature() -> void:
	var d := _def("t_prey", {"dark": 1, "earth": 2})
	d.species = "wolf"
	_make("spider", [d])
	player.collect_part("cocoon:t_prey")
	player.health.hp = 1
	assert_true(player.eat_cocoon())
	assert_eq(_named(Events.PREDATED), [{"source": "t_prey", "kind": "creature", "species": "wolf"}])
	assert_eq(_named(Events.ABSORBED).map(func(t: Dictionary) -> String: return t["essence"]), ["earth", "earth", "dark"])
	assert_gt(player.health.hp, 1, "an eat heals")
	assert_eq(player.inventory.cocoons(), [], "the cocoon is spent")

func test_eating_a_cocoon_pays_the_xp_and_the_mp_of_an_eat() -> void:
	var d := _def()
	d.xp = 7
	_make("spider", [d])
	player.collect_part("cocoon:t_prey")
	player.mana.mp = 0
	var xp := player.progression.xp
	player.eat_cocoon()
	assert_eq(player.progression.xp, xp + 7)
	assert_eq(player.mana.mp, Player.EAT_MP)

func test_every_third_eat_raises_max_mp_whether_a_cocoon_or_not() -> void:
	var d := _def()
	_make("spider", [d])
	var max_mp := player.stats.get_stat("max_mp")
	for i in 2:
		var e := _creature(d, Vector2(10, 0))
		player._complete_predation(e)
	player.collect_part("cocoon:t_prey")
	player.eat_cocoon()
	assert_eq(player.stats.get_stat("max_mp"), max_mp + Player.MAX_MP_PER_THREE_EATS)

func test_with_no_cocoon_nothing_is_eaten_and_nothing_is_said() -> void:
	_make("spider", [_def()])
	assert_false(player.eat_cocoon())
	assert_eq(events, [])

func test_a_cocoon_of_a_creature_the_player_does_not_know_is_kept() -> void:
	_make("spider", [])
	player.collect_part("cocoon:t_prey")
	assert_false(player.eat_cocoon())
	assert_eq(player.inventory.cocoons(), ["t_prey"])
	assert_eq(_named(Events.PREDATED).size(), 0)

func test_a_dead_spider_eats_nothing() -> void:
	_make("spider", [_def()])
	player.collect_part("cocoon:t_prey")
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_false(player.eat_cocoon())

func test_the_predate_button_eats_the_cocoon_when_nothing_is_in_reach() -> void:
	_make("spider", [_def()])
	player.collect_part("cocoon:t_prey")
	player.begin_predate()
	assert_eq(player.inventory.cocoons(), [])
	assert_eq(_named(Events.PREDATED).size(), 1)

func test_the_predate_button_eats_the_creature_in_reach_and_not_the_cocoon() -> void:
	var d := _def()
	_make("spider", [d])
	player.collect_part("cocoon:t_prey")
	var e := _creature(d)
	player.begin_predate()
	assert_true(player.predation.active(), "it starts eating the creature")
	assert_eq(player.inventory.cocoons(), ["t_prey"])
	player.cancel_predate()
	assert_false(e.is_queued_for_deletion())

func test_a_goblin_eating_a_creature_alive_is_unchanged_by_all_this() -> void:
	var d := _def("t_a", {"earth": 2})
	_make("goblin", [d])
	var e := _creature(d)
	player._complete_predation(e)
	assert_eq(_named(Events.ABSORBED).size(), 2, "the lesson's units, once")
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 1)

func test_a_goblin_that_somehow_carries_a_cocoon_eats_it_for_its_essence_and_learns_nothing() -> void:
	var d := _def("t_a", {"earth": 2})
	_make("goblin", [d])
	player.collect_part("cocoon:t_a")
	assert_true(player.eat_cocoon())
	assert_eq(_named(Events.ABSORBED).size(), 2)
	assert_eq(_named(Deeds.LESSON_LEARNED).size(), 0, "there is no creature in front of it to learn from")

# --- freed ---

func test_a_spider_with_a_cocoon_and_nothing_to_inspect_lets_the_prey_go() -> void:
	_make()
	player.collect_part("cocoon:t_prey")
	watch_signals(player)
	player.do_inspect()
	assert_eq(player.inventory.cocoons(), [])
	assert_eq(_named(Deeds.PREY_FREED), [{"creature": "t_prey"}])
	assert_signal_emitted(player, "prey_released")
	assert_signal_not_emitted(player, "inspect_report")
	var params = get_signal_parameters(player, "prey_released")
	assert_eq(params[0], "t_prey")
	assert_gt((params[1] as Vector2).x, player.global_position.x, "beside it, the way it faces")

func test_the_prey_is_let_out_on_the_side_the_spider_faces() -> void:
	_make()
	player.facing = -1
	player.collect_part("cocoon:t_prey")
	watch_signals(player)
	player.try_release_prey()
	assert_lt((get_signal_parameters(player, "prey_released")[1] as Vector2).x, player.global_position.x)

func test_a_creature_to_inspect_wins_over_freeing_and_the_cocoon_is_kept() -> void:
	_make()
	player.collect_part("cocoon:t_prey")
	_creature(_def("t_other"), Vector2(10, 0), false)  # awake: nothing to web, something to inspect
	watch_signals(player)
	player.do_inspect()
	assert_signal_emitted(player, "inspect_report")
	assert_eq(player.inventory.cocoons(), ["t_prey"])
	assert_eq(_named(Deeds.PREY_FREED).size(), 0)

func test_with_no_cocoon_nothing_is_freed() -> void:
	_make()
	assert_false(player.try_release_prey())
	assert_eq(events, [])

func test_only_a_spider_frees_prey() -> void:
	for species in ["slime", "wolf", "goblin", "undead"]:
		_make(species)
		player.collect_part("cocoon:t_prey")
		assert_false(player.try_release_prey(), species)
		assert_eq(player.inventory.cocoons(), ["t_prey"], species)

func test_a_dead_spider_frees_nothing() -> void:
	_make()
	player.collect_part("cocoon:t_prey")
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_false(player.try_release_prey())
