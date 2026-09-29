extends GutTest

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	return e

func test_stats_include_the_creatures_own_skills() -> void:
	var lizard := _enemy("lizard")
	assert_eq(lizard.stats.get_stat("def"), 3)  # 1 + Body Armor Lv2
	var bat := _enemy("bat")
	assert_true(bat.capabilities.has("flight"))
	assert_true(bat.capabilities.has("reveals_hidden"))
	assert_true(bat.is_in_group("actors") and bat.is_in_group("predatable") and bat.is_in_group("inspectable"))

func test_tackle_stuns_and_makes_it_predatable() -> void:
	var bat := _enemy("bat")
	assert_false(bat.can_be_predated())
	assert_true(bat.receive_tackle(1, false))
	assert_eq(bat.health.hp, 1)
	assert_eq(bat.status.state, EnemyStatus.STUNNED)
	assert_true(bat.can_be_predated())

func test_lethal_damage_downs_instead_of_removing() -> void:
	var bat := _enemy("bat")
	bat.receive_hit(9, "physical")
	assert_eq(bat.status.state, EnemyStatus.DYING)
	assert_false(bat.can_be_predated(), "not edible while the death effect plays")
	bat.finish_dying()
	assert_eq(bat.status.state, EnemyStatus.DOWNED)
	assert_true(bat.can_be_predated())
	assert_true(bat.receive_tackle(1, true) == false)  # downed: no further tackle effect

func test_tackle_that_downs_still_counts() -> void:
	var bat := _enemy("bat")
	bat.receive_hit(1, "physical")
	assert_true(bat.receive_tackle(1, false))
	assert_eq(bat.status.state, EnemyStatus.DYING)
	bat.finish_dying()
	assert_eq(bat.status.state, EnemyStatus.DOWNED)

func test_lizard_is_only_stunned_from_behind() -> void:
	var lizard := _enemy("lizard")
	assert_false(lizard.receive_tackle(1, false))
	assert_eq(lizard.status.state, EnemyStatus.ACTIVE)
	assert_true(lizard.receive_tackle(1, true))
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)

func test_serpent_cannot_be_stunned_or_eaten() -> void:
	var serpent := _enemy("serpent")
	assert_false(serpent.receive_tackle(1, true))
	assert_false(serpent.can_be_predated())

func test_thread_tier_two_stuns() -> void:
	var spider := _enemy("spider")
	spider.receive_thread(1)
	assert_eq(spider.status.state, EnemyStatus.ACTIVE)
	spider.receive_thread(2)
	assert_eq(spider.status.state, EnemyStatus.STUNNED)

func test_consume_returns_def_and_leaves() -> void:
	var toad := _enemy("toad")
	toad.receive_tackle(1, false)
	assert_eq(toad.consume(), creatures["toad"])
	assert_false(toad.can_be_predated())

func test_enemies_never_emit_gameplay_events() -> void:
	var seen: Array = []
	var recorder := func(n: String, t: Dictionary) -> void: seen.append(n)
	EventBus.game_event.connect(recorder)
	var toad := _enemy("toad")
	toad.receive_hit(1, "poison")
	toad.receive_tackle(1, false)
	toad.receive_hit(9, "physical")
	EventBus.game_event.disconnect(recorder)
	assert_eq(seen, [])

func test_water_pool_is_single_use() -> void:
	var pool := WaterPool.new()
	pool.setup(creatures["water_pool"])
	add_child_autofree(pool)
	assert_true(pool.can_be_predated())
	assert_eq(pool.consume(), creatures["water_pool"])
	assert_false(pool.can_be_predated())
