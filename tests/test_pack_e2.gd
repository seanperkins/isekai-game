extends GutTest
## A flood that is real water, a vine that grows slowly and can be climbed, a trail laid and walked back along, a growth that creeps and shows the way, a nail that
## drains its keeper, a body that holds its prey inside.

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000
	lizard.global_position = Vector2(900, 0)
	player._invuln = 1000.0
	await wait_physics_frames(3)  # the player was touching the lizard: let it settle, or it rides the lizard's jump like a moving platform
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	Input.action_release("aim_up")
	for g in ["verb_floods", "verb_vines", "verb_trails", "verb_networks", "deep_water", "climbables", "verb_fields"]:
		for n in get_tree().get_nodes_in_group(g):
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

# --- a flood ---

func test_a_flood_is_real_water_round_the_caster_and_it_drains_away() -> void:
	player.global_position = Vector2(0, 0)
	_verb({"kind": "flood", "width": 300.0, "depth": 90.0, "seconds": 0.6}).activate()
	await wait_physics_frames(3)
	assert_not_null(DeepWater.at(get_tree(), Vector2(0, 0)), "the low ground is under water")
	assert_null(DeepWater.at(get_tree(), Vector2(0, -200)), "not above it")
	assert_null(DeepWater.at(get_tree(), Vector2(400, 0)), "not beyond it")
	await wait_seconds(0.9)
	assert_null(DeepWater.at(get_tree(), Vector2(0, 0)), "it drained")

func test_a_flood_slows_you_too_unless_you_swim_and_slows_what_cannot_swim() -> void:
	player.global_position = Vector2(0, 0)
	lizard.global_position = Vector2(60, 0)
	var spd := player.stats.get_stat("spd")
	_verb({"kind": "flood", "width": 300.0, "depth": 90.0, "seconds": 3.0}).activate()
	await wait_physics_frames(6)
	assert_lt(player.stats.get_stat("spd"), spd, "it slows you too")
	assert_gt(lizard._slow, 0.0, "and what cannot swim")
	player._slow = 0.0
	player.stats.set_timed_modifiers(Player.SLOW_SOURCE, [])
	player.skillset.capabilities["swim"] = 1
	await wait_physics_frames(6)
	assert_eq(player.stats.get_stat("spd"), spd, "unless you swim")

# --- a vine that grows and can be climbed ---

func test_a_vine_grows_slowly_one_at_a_time_and_can_be_climbed() -> void:
	player.global_position = Vector2(0, 0)
	var a := _verb({"kind": "vine", "height": 160.0, "seconds": 8.0, "grow": 80.0, "climb": true})
	a.activate()
	var vine: VerbVine = get_tree().get_nodes_in_group("verb_vines")[0]
	assert_lt(vine.grown(), 40.0, "it is not all there at once")
	await wait_seconds(0.5)
	assert_gt(vine.grown(), 30.0, "it grows")
	assert_lt(vine.grown(), 60.0)
	a._cooldown = 0.0
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("verb_vines").size(), 1, "one at a time")
	await wait_seconds(1.0)
	var y0 := player.global_position.y
	Input.action_press("aim_up")
	await wait_seconds(0.6)
	assert_lt(player.global_position.y, y0 - 20.0, "it climbed the vine")

# --- a trail ---

func test_the_first_cast_lays_a_trail_and_the_second_walks_back_along_it_to_its_start() -> void:
	player.global_position = Vector2(0, 0)
	var a := _verb({"kind": "trail", "seconds": 10.0})
	a.activate()
	for i in 10:
		player.global_position += Vector2(30, -4)
		await wait_seconds(0.12)
	var far := player.global_position
	assert_gt(far.x, 250.0)
	a._cooldown = 0.0
	a.activate()
	await wait_seconds(1.2)
	assert_lt(player.global_position.distance_to(Vector2(0, 0)), 20.0, "back at the start")
	assert_eq(get_tree().get_nodes_in_group("verb_trails").size(), 0, "the trail is spent")

func test_a_return_with_no_trail_lays_one() -> void:
	var a := _verb({"kind": "trail", "seconds": 10.0})
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("verb_trails").size(), 1, "the trail must be laid first")

# --- a growth that creeps and shows the way ---

func test_a_network_creeps_slows_and_shows_the_way_to_a_mark() -> void:
	player.global_position = Vector2(0, 0)
	var pool := GlowPool.new()
	pool.setup({"id": "p", "pos": Vector2(400, 20)}, {})
	add_child_autofree(pool)
	lizard.global_position = Vector2(90, 0)
	_verb({"kind": "network", "radius": 140.0, "seconds": 8.0, "grow": 60.0}).activate()
	var net: VerbNetwork = get_tree().get_nodes_in_group("verb_networks")[0]
	var r0 := net.current_radius()
	assert_lt(r0, 60.0, "it begins small")
	assert_eq(lizard._slow, 0.0, "not yet reached")
	await wait_seconds(1.5)
	assert_gt(net.current_radius(), r0 + 40.0, "it creeps")
	assert_gt(lizard._slow, 0.0, "and now it has reached the lizard")
	assert_eq(net.route_target(), pool, "it shows the way to a mark")

# --- a nail ---

func test_a_nail_on_the_back_drains_its_keeper_when_it_is_hit() -> void:
	_verb({"kind": "aura", "radius": 60.0, "seconds": 5.0, "nail": {"drain": 3, "seconds": 5.0}}).activate()
	player.facing = 1
	player._invuln = 0.0
	player.health.hp = player.health.max_hp
	player.receive_hit(1, "physical", Vector2(60, 0))  # from the front
	var front := player.health.max_hp - player.health.hp
	player.health.hp = player.health.max_hp
	player._invuln = 0.0
	player.receive_hit(1, "physical", Vector2(-60, 0))  # from behind, where the nail shows
	var back := player.health.max_hp - player.health.hp
	assert_gt(back, front + 1, "the nail was hit: it drains (%d against %d)" % [back, front])

# --- a body that holds its prey ---

func test_an_engulfed_creature_is_held_inside_the_body_and_a_big_one_is_not_swallowed() -> void:
	player.global_position = Vector2(0, 0)
	lizard.global_position = Vector2(30, 0)
	var big := Enemy.new()
	big.setup(lizard.def, {})
	big.def = big.def.duplicate()
	big.def.stats = big.def.stats.duplicate()
	big.def.stats["max_hp"] = 30
	big.position = Vector2(-30, 0)
	add_child_autofree(big)
	_verb({"kind": "engulf", "range": 80.0, "seconds": 2.0, "small": 12}).activate()
	await wait_physics_frames(6)
	assert_lt(lizard.global_position.distance_to(player.global_position), 6.0, "it is inside")
	assert_lt(lizard.modulate.a, 1.0, "seen through the body")
	assert_gt(big.global_position.distance_to(player.global_position), 20.0, "a big one is too big to swallow")
	await wait_seconds(2.2)
	assert_eq(lizard.modulate.a, 1.0, "let out again")

func test_the_new_keys_validate() -> void:
	for spec in [{"kind": "flood", "width": 300, "depth": 90, "seconds": 6}, {"kind": "vine", "height": 160, "seconds": 8, "grow": 60, "climb": true}, {"kind": "trail", "seconds": 10},
			{"kind": "network", "radius": 140, "seconds": 8, "grow": 20}, {"kind": "aura", "nail": {"drain": 3, "seconds": 5}}, {"kind": "engulf", "small": 12}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
