extends GutTest
## The five new evolved abilities: Binding Web, Miasma, Venom Bolt, Healing Spores, Puffball.

class RopeActor extends Node2D:
	var team := "player"
	var facing := 1
	var ropes: Array = []
	var threads: Array = []
	var hits: Array = []
	var health := Health.new(10)
	func apply_impulse(_v: Vector2) -> void:
		pass
	func receive_hit(raw: int, type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, type])
	func receive_thread(tier: int) -> void:
		threads.append(tier)
	func attach_rope(anchor: Vector2, max_length: float, reel_speed: float, boost: float) -> void:
		ropes.append([anchor, max_length, reel_speed, boost])

var actor: RopeActor

func before_each() -> void:
	actor = RopeActor.new()
	add_child_autofree(actor)
	actor.add_to_group("actors")

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("vfx"):
		n.free()
	for n in get_tree().get_nodes_in_group("player_clouds"):
		n.free()

func _solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _enemy(pos: Vector2) -> RopeActor:
	var e := RopeActor.new()
	e.team = "enemy"
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = pos
	return e

func _cast(id: String, aim: Vector2, values: Array = [1]) -> Ability:
	var a: Ability = load("res://scenes/abilities/%s.tscn" % id).instantiate()
	add_child_autofree(a)
	a.setup(actor, values, 1)
	a.aim = aim
	await wait_physics_frames(2)
	a.activate()
	return a

func _patches() -> Array:
	return get_tree().get_nodes_in_group("player_clouds")

# --- Binding Web ---

func test_binding_web_holds_an_enemy_and_leaves_a_patch_at_it() -> void:
	var e := _enemy(Vector2(60, 0))
	await _cast("binding_web", Vector2(1, 0), [2])
	assert_eq(e.threads, [2], "held at once (tier 2)")
	assert_eq(actor.ropes, [])
	assert_eq(_patches().size(), 1)
	assert_almost_eq((_patches()[0] as Node2D).global_position.x, 60.0, 1.0)

func test_binding_web_never_ropes_and_webs_the_rock_it_meets() -> void:
	_solid(Rect2(80, -50, 20, 100))
	await _cast("binding_web", Vector2(1, 0), [2])
	assert_eq(actor.ropes, [], "no rope")
	assert_eq(_patches().size(), 1)
	assert_almost_eq((_patches()[0] as Node2D).global_position.x, 80.0, 2.0)

func test_binding_web_webs_full_range_in_open_air() -> void:
	await _cast("binding_web", Vector2(1, 0), [2])
	assert_eq(_patches().size(), 1)
	assert_almost_eq((_patches()[0] as Node2D).global_position.x, 120.0, 1.0)

func test_the_patch_does_no_damage_and_slows() -> void:
	await _cast("binding_web", Vector2(1, 0), [2])
	var z: SporeCloudArea = _patches()[0]
	assert_eq([z.damage, z.slow, z.radius], [0, true, 40.0])

func test_sticky_thread_still_ropes_and_leaves_no_patch() -> void:
	_solid(Rect2(-50, -110, 100, 10))
	await _cast("sticky_thread", Vector2(0, -1))
	assert_eq(actor.ropes.size(), 1)
	assert_eq(_patches().size(), 0)

func test_a_thread_form_discounts_binding_web() -> void:
	assert_eq(FormEffects.mp_cost({"trait_spinner": 1}, "binding_web", 4), 3)

# --- Poison Breath: Miasma and Venom Bolt ---

func test_venom_bolt_pierces_every_enemy_on_its_line_once() -> void:
	var a := _enemy(Vector2(60, 0))
	var b := _enemy(Vector2(200, 4))
	var off := _enemy(Vector2(120, 80))
	await _cast("venom_bolt", Vector2(1, 0), [9])
	assert_eq(a.hits, [[9, "poison"]])
	assert_eq(b.hits, [[9, "poison"]])
	assert_eq(off.hits, [])

func test_venom_bolt_stops_at_rock_and_at_260_px() -> void:
	var behind := _enemy(Vector2(120, 0))
	var far := _enemy(Vector2(270, 0))
	_solid(Rect2(90, -40, 10, 80))
	await _cast("venom_bolt", Vector2(1, 0), [9])
	assert_eq(behind.hits, [], "the rock ends the line")
	assert_eq(far.hits, [])

func test_venom_bolt_reaches_an_enemy_at_the_range_edge() -> void:
	var edge := _enemy(Vector2(255, 15))
	var past := _enemy(Vector2(275, 0))
	await _cast("venom_bolt", Vector2(1, 0), [9])
	assert_eq(edge.hits.size(), 1)
	assert_eq(past.hits.size(), 0)

func test_miasma_hits_the_cone_and_leaves_a_poisoning_non_slowing_cloud_at_its_end() -> void:
	var e := _enemy(Vector2(40, 0))
	await _cast("miasma", Vector2(1, 0), [9])
	assert_eq(e.hits, [[9, "poison"]])
	assert_eq(_patches().size(), 1)
	var z: SporeCloudArea = _patches()[0]
	assert_almost_eq(z.global_position.x, 56.0, 1.0)
	assert_false(z.slow)
	assert_eq([z.damage, z.radius], [1, 36.0])

func test_miasma_never_puts_its_cloud_behind_a_wall() -> void:
	_solid(Rect2(30, -50, 10, 100))
	await _cast("miasma", Vector2(1, 0), [9])
	assert_lt((_patches()[0] as Node2D).global_position.x, 32.0)

# --- Spore Cloud: Healing Spores and Puffball ---

func test_healing_spores_drops_a_healing_non_damaging_cloud_around_the_caster() -> void:
	await _cast("healing_spores", Vector2(1, 0), [40])
	var z: SporeCloudArea = _patches()[0]
	assert_eq([z.radius, z.damage, z.heals, z.slow], [40.0, 0, 1, true])
	assert_lt(actor.global_position.distance_to(z.global_position), z.radius, "the slime is inside at cast time")

func test_puffball_lands_on_the_floor_on_a_horizontal_aim() -> void:
	_solid(Rect2(-400, 12, 800, 20))  # the floor is 12 px below the caster
	await _cast("puffball", Vector2(1, 0), [64])
	var z: SporeCloudArea = _patches()[0]
	assert_eq([z.radius, z.damage, z.slow], [64.0, 1, true])
	assert_between((z as Node2D).global_position.x, 105.0, 135.0)
	assert_almost_eq(z.global_position.y, 12.0, 3.0)

func test_puffball_lands_on_a_45_degree_aim_on_flat_ground() -> void:
	_solid(Rect2(-400, 12, 800, 20))
	await _cast("puffball", Vector2(1, -1).normalized(), [64])
	var z: SporeCloudArea = _patches()[0]
	assert_almost_eq(z.global_position.y, 12.0, 3.0, "it came down to the floor, not to the arc cap")
	assert_between(z.global_position.x, 150.0, 190.0)

func test_puffball_straight_up_comes_back_down() -> void:
	_solid(Rect2(-400, 12, 800, 20))
	await _cast("puffball", Vector2(0, -1), [64])
	assert_almost_eq((_patches()[0] as Node2D).global_position.y, 12.0, 3.0)

func test_puffball_bursts_against_a_wall() -> void:
	_solid(Rect2(60, -100, 10, 200))
	await _cast("puffball", Vector2(1, 0), [64])
	assert_lt((_patches()[0] as Node2D).global_position.x, 62.0)

func test_puffball_over_a_pit_stops_at_the_cap() -> void:
	await _cast("puffball", Vector2(1, 0), [64])  # no floor at all
	assert_eq(_patches().size(), 1)
	# 40 steps of 1/30 s: x = 220 x 40/30, y = -150 x 40/30 + 300 x (40/30)^2 - a semi-step = the arc's own end
	var p := (_patches()[0] as Node2D).global_position
	assert_almost_eq(p.x, 293.33, 1.5)
	assert_almost_eq(p.y, 320.0, 1.5)

func test_a_ray_from_below_meets_the_underside_of_a_one_way_ledge() -> void:
	# Pins what the engine does today (the spec accepts either): the ray stops at the ledge's underside, so a Puffball
	# lobbed up under a thin ledge bursts beneath it. If a physics change lets rays pass, this test says so.
	var def := RoomDef.new()
	def.id = "T"
	def.area = "cave"
	def.size = Vector2i(1, 1)
	def.solids = [Rect2(-50, -40, 100, 12)]
	var room := RoomBuilder.build_room(def, {})
	add_child_autofree(room)
	room.position = Vector2.ZERO
	var a: Ability = load("res://scenes/abilities/puffball.tscn").instantiate()
	add_child_autofree(a)
	a.setup(actor, [64], 1)
	await wait_physics_frames(2)
	var hit = a.terrain_hit(Vector2(0, 0), Vector2(0, -100))
	assert_not_null(hit)
	assert_almost_eq(hit.y, -28.0, 1.0)
