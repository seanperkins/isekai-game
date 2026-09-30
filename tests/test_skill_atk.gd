extends GutTest
## Poison Breath, Water Blade and Venom Bolt scale with the caster's ATK (25% a point); Miasma's cone does too, once; the
## clouds, holds and heals do not. ATK 1 is the table exactly, and an actor without stats counts as ATK 1.

class Body extends Node2D:
	var team := "player"
	var facing := 1
	var stats: Stats = null
	var hits: Array = []
	var threads: Array = []
	func apply_impulse(_v: Vector2) -> void:
		pass
	func receive_hit(raw: int, type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, type])
	func receive_thread(tier: int) -> void:
		threads.append(tier)

var caster: Body

func before_each() -> void:
	caster = Body.new()
	add_child_autofree(caster)
	caster.add_to_group("actors")

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("vfx"):
		n.free()
	for n in get_tree().get_nodes_in_group("player_clouds"):
		n.free()

func _atk(value: int) -> void:
	caster.stats = Stats.new({"atk": value})

func _enemy(x: float) -> Body:
	var e := Body.new()
	e.team = "enemy"
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = Vector2(x, 0)
	return e

func _cast(id: String, values: Array, level := 1) -> Ability:
	var a: Ability = load("res://scenes/abilities/%s.tscn" % id).instantiate()
	add_child_autofree(a)
	a.setup(caster, values, level)
	a.aim = Vector2(1, 0)
	await wait_physics_frames(2)
	a.activate()
	return a

func _clouds() -> Array:
	return get_tree().get_nodes_in_group("player_clouds")

func test_an_actor_without_stats_deals_the_table_values() -> void:
	var e := _enemy(40)
	await _cast("poison_breath", [2, 3, 4, 5, 6], 3)
	await _cast("water_blade", [3])
	await _cast("venom_bolt", [9])
	assert_eq(e.hits, [[4, "poison"], [3, "physical"], [9, "poison"]])

func test_atk_1_is_the_table_exactly() -> void:
	_atk(1)
	var e := _enemy(40)
	await _cast("poison_breath", [2])
	await _cast("venom_bolt", [9])
	assert_eq(e.hits, [[2, "poison"], [9, "poison"]])

func test_atk_3_amplifies_poison_breath() -> void:
	_atk(3)
	var e := _enemy(40)
	await _cast("poison_breath", [2])
	assert_eq(e.hits, [[3, "poison"]], "2 x 150 / 100")

func test_atk_3_amplifies_venom_bolt() -> void:
	_atk(3)
	var e := _enemy(120)
	await _cast("venom_bolt", [9])
	assert_eq(e.hits, [[13, "poison"]], "9 x 150 / 100 = 13.5 -> 13")

func test_atk_3_amplifies_water_blade() -> void:
	_atk(3)
	var e := _enemy(60)
	await _cast("water_blade", [3])
	assert_eq(e.hits, [[4, "physical"]], "3 x 150 / 100 = 4.5 -> 4")

func test_miasma_amplifies_its_cone_once_and_leaves_its_cloud_at_1() -> void:
	_atk(3)
	var e := _enemy(40)
	await _cast("miasma", [9])
	assert_eq(e.hits, [[13, "poison"]], "once, at 9 x 150 / 100: not 19, not 9")
	assert_eq((_clouds()[0] as SporeCloudArea).damage, 1)

func test_the_clouds_holds_and_heals_stay_fixed_at_high_atk() -> void:
	_atk(5)
	await _cast("spore_cloud", [32], 3)
	await _cast("puffball", [64])
	await _cast("healing_spores", [40])
	var by_radius := {}
	for c in _clouds():
		by_radius[(c as SporeCloudArea).radius] = [(c as SporeCloudArea).damage, (c as SporeCloudArea).heals]
	assert_eq(by_radius[32.0], [1, 0], "Spore Cloud")
	assert_eq(by_radius[64.0], [1, 0], "Puffball")
	assert_eq(by_radius[40.0], [0, 1], "Healing Spores")
	var e := _enemy(50)
	await _cast("binding_web", [2])
	assert_eq(e.threads, [2], "a hold tier is not damage")

func test_a_real_player_at_atk_3_breathes_3_on_a_toad() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	var player := Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	player.stats.set_modifiers("t", [{"stat": "atk", "op": "add", "value": 2}])
	assert_eq(player.stats.get_stat("atk"), 3)
	var toad := Enemy.new()
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	toad.setup(creature_list.filter(func(c): return c.id == "toad")[0], by_id)
	add_child_autofree(toad)
	toad.set_physics_process(false)
	toad.health.hp = 50
	toad.health.max_hp = 50
	toad.global_position = Vector2(40, 0)
	var a: Ability = load("res://scenes/abilities/poison_breath.tscn").instantiate()
	add_child_autofree(a)
	a.setup(player, [2], 1)
	a.aim = Vector2(1, 0)
	a.activate()
	assert_eq(toad.health.hp, 47, "ATK 3 turns the level 1 Damage 2 into 3")
