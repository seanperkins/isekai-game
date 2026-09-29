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

# --- weak points: an armored enemy hit from behind, or while stunned, loses its DEF and takes double ---

func test_a_front_tackle_on_an_armored_enemy_still_does_one() -> void:
	var crab := _enemy("mushroom_crab")  # HP 8, DEF 2
	crab.receive_tackle(1, false)
	assert_eq(crab.health.hp, 7, "ATK 1 - DEF 2 floors at 1 from the front")
	assert_eq(crab.status.state, EnemyStatus.ACTIVE, "an armored front is not stunned")

func test_a_tackle_from_behind_ignores_armor_and_does_double() -> void:
	var crab := _enemy("mushroom_crab")
	crab.receive_tackle(1, true)
	assert_eq(crab.health.hp, 6, "ATK 1 x2, DEF ignored")
	assert_eq(crab.status.state, EnemyStatus.STUNNED)
	var lizard := _enemy("lizard")  # HP 5, DEF 3
	lizard.receive_tackle(2, true)
	assert_eq(lizard.health.hp, 1, "ATK 2 x2 = 4 through DEF 3")

func test_a_stunned_enemy_takes_the_weak_point_hit_from_the_front() -> void:
	var crab := _enemy("mushroom_crab")
	crab.receive_tackle(1, true)  # stunned from behind: 8 -> 6
	crab.receive_tackle(1, false)  # a front tackle on a stunned crab
	assert_eq(crab.health.hp, 4)

func test_a_stunned_crab_falls_in_four_tackles_within_its_stun() -> void:
	var crab := _enemy("mushroom_crab")
	crab.receive_tackle(1, true)
	for i in 3:
		crab.receive_tackle(1, false)
	assert_eq(crab.status.state, EnemyStatus.DYING, "8 HP: 2 + 2 + 2 + 2")

func test_an_unarmored_enemy_has_no_weak_point() -> void:
	var bat := _enemy("bat")  # HP 2, DEF 0
	bat.receive_tackle(1, true)
	assert_eq(bat.health.hp, 1, "a backstab on a bat is still a plain hit: it is stunned for the eat, not killed")
	assert_eq(bat.status.state, EnemyStatus.STUNNED)
