extends GutTest
## Ward-stones: planted where the caster stands, they slow enemies and mend the caster near them, link into a wider aura, protect an area, frighten, and hold
## holy ground that tethers its keeper.

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	_floor()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000
	lizard.global_position = Vector2(900, 0)
	player.global_position = Vector2(-300, 0)

func _floor() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("ward_stones"):
		n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _verb(spec: Dictionary) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [4], 1)
	return a

func _stones() -> Array:
	return get_tree().get_nodes_in_group("ward_stones")

func test_a_stone_is_planted_where_the_caster_stands_and_stays() -> void:
	_verb({"kind": "stone", "radius": 70.0}).activate()
	assert_eq(_stones().size(), 1)
	assert_eq((_stones()[0] as Node2D).global_position.x, player.global_position.x)
	await wait_seconds(1.0)
	assert_eq(_stones().size(), 1, "it is a stone, not a cloud")

func test_a_stone_slows_enemies_near_it_and_mends_the_caster() -> void:
	player.health.hp = 10
	_verb({"kind": "stone", "radius": 80.0, "slow": true, "heals": 2}).activate()
	lizard.global_position = Vector2(-280, 0)
	await wait_seconds(1.3)
	assert_gt(lizard._slow, 0.0, "slowed")
	assert_gt(player.health.hp, 10, "mended")

func test_only_so_many_stones_stand_and_a_new_one_takes_the_oldest_place() -> void:
	var a := _verb({"kind": "stone", "radius": 50.0, "max": 2})
	for i in 3:
		player.global_position = Vector2(-300.0 + i * 20.0, 0)
		a._cooldown = 0.0
		a.activate()
	assert_eq(_stones().size(), 2)

func test_stones_close_together_link_into_one_wider_aura() -> void:
	var a := _verb({"kind": "stone", "radius": 50.0, "max": 3, "link": 150.0})
	a.activate()
	var one: float = _stones()[0].effective_radius()
	player.global_position = Vector2(-240, 0)
	a._cooldown = 0.0
	a.activate()
	assert_gt(_stones()[0].effective_radius(), one, "linked")
	player.global_position = Vector2(300, 0)
	a._cooldown = 0.0
	a.activate()
	assert_eq(_stones()[2].effective_radius(), one, "a far one is alone")

func test_a_protecting_stone_nullifies_damage_to_whoever_stands_in_it() -> void:
	_verb({"kind": "stone", "radius": 80.0, "protect": true}).activate()
	await wait_physics_frames(5)
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_hit(5, "physical", Vector2.INF)
	assert_eq(player.health.hp, hp, "protected")
	player.global_position = Vector2(300, 0)
	await wait_seconds(0.4)
	player._invuln = 0.0
	player.receive_hit(5, "physical", Vector2.INF)
	assert_lt(player.health.hp, hp, "out of the area, it is not")

func test_a_fear_stone_frightens_enemies_and_the_callers_own_allies_flee_too() -> void:
	var ally_spec := {"kind": "summon", "count": 1, "seconds": 8.0}
	_verb(ally_spec).activate()
	var ally: VerbAlly = get_tree().get_nodes_in_group("verb_allies")[0]
	ally.global_position = player.global_position + Vector2(10, 0)
	_verb({"kind": "stone", "radius": 80.0, "status": {"flee": 2.0}, "afraid_allies": true}).activate()
	lizard.global_position = Vector2(-260, 0)
	await wait_seconds(1.3)
	assert_true(lizard.is_fleeing(), "the enemy is afraid")
	assert_true(ally.is_afraid(), "and so are the allies (the drawback)")

func test_holy_ground_wards_a_packmate_and_tethers_its_keeper() -> void:
	var pal := player.add_companion(DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == "gloom_wolf")[0], player.global_position, {"hp": 5})
	_verb({"kind": "stone", "radius": 80.0, "holy": true, "tether": 120.0}).activate()
	await wait_physics_frames(5)
	assert_true(pal.is_warded(), "the packmate is warded on holy ground")
	player.global_position = Vector2(-100, 0)  # 200 px from the stone
	await wait_physics_frames(3)
	assert_lte(absf(player.global_position.x - (-300.0)), 121.0, "tethered to the sacred spot")

func test_the_new_keys_validate() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "stone", "radius": 70, "max": 2, "slow": true, "heals": 2, "protect": true, "status": {"flee": 2}, "link": 150,
		"afraid_allies": true, "holy": true, "tether": 120, "seconds": 0})), [])
	assert_ne(Array(VerbKinds.validate({"kind": "stone", "protect": "yes"})), [])
