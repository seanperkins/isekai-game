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
