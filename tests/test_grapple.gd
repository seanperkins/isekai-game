extends GutTest
## Sticky Thread / Swing Thread: the thread hits whatever it touches first. An enemy is
## slowed or held; terrain becomes a swing anchor.

class RopeActor extends Node2D:
	var team := "player"
	var facing := 1
	var ropes: Array = []
	var threads: Array = []
	func apply_impulse(_v: Vector2) -> void:
		pass
	func receive_hit(_raw: int, _type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass
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

func test_sticky_thread_anchors_to_a_ceiling_in_range() -> void:
	_solid(Rect2(-50, -110, 100, 10))  # underside at y = -100
	await _cast("sticky_thread", Vector2(0, -1))
	assert_eq(actor.ropes.size(), 1)
	var r: Array = actor.ropes[0]
	assert_almost_eq(r[0].y, -100.0, 0.5)
	assert_eq([r[1], r[2], r[3]], [120.0, 60.0, 1.0])

func test_sticky_thread_misses_terrain_beyond_its_range() -> void:
	_solid(Rect2(-50, -170, 100, 10))  # 160 px up
	await _cast("sticky_thread", Vector2(0, -1))
	assert_eq(actor.ropes, [])

func test_an_enemy_in_front_of_the_wall_takes_the_thread() -> void:
	_solid(Rect2(100, -50, 10, 100))
	var e := _enemy(Vector2(50, 0))
	await _cast("sticky_thread", Vector2(1, 0), [2])
	assert_eq(e.threads, [2])
	assert_eq(actor.ropes, [])

func test_a_wall_in_front_of_the_enemy_takes_the_thread() -> void:
	_solid(Rect2(40, -50, 10, 100))
	var e := _enemy(Vector2(90, 0))
	await _cast("sticky_thread", Vector2(1, 0))
	assert_eq(e.threads, [])
	assert_eq(actor.ropes.size(), 1)
	assert_almost_eq(actor.ropes[0][0].x, 40.0, 0.5)

func test_swing_thread_reaches_farther_and_launches_harder() -> void:
	_solid(Rect2(-50, -190, 100, 10))  # 180 px up: out of Sticky's reach
	await _cast("swing_thread", Vector2(0, -1), [2])
	assert_eq(actor.ropes.size(), 1)
	assert_eq([actor.ropes[0][1], actor.ropes[0][2], actor.ropes[0][3]], [200.0, 120.0, 1.4])

func test_swing_thread_still_holds_enemies() -> void:
	var e := _enemy(Vector2(60, 0))
	await _cast("swing_thread", Vector2(1, 0), [2])
	assert_eq(e.threads, [2])

func test_swing_thread_defaults_to_up_and_forward() -> void:
	_solid(Rect2(80, -90, 40, 10))
	await _cast("swing_thread", Vector2.ZERO, [2])
	assert_eq(actor.ropes.size(), 1)

func test_an_anchored_thread_is_drawn_to_the_anchor_by_the_player_not_as_a_flash() -> void:
	_solid(Rect2(-50, -110, 100, 10))
	await _cast("sticky_thread", Vector2(0, -1))
	assert_eq(get_tree().get_nodes_in_group("vfx").size(), 0)

func test_terrain_hit_belongs_to_every_ability() -> void:
	_solid(Rect2(40, -10, 10, 20))
	var a: Ability = load("res://scenes/abilities/water_blade.tscn").instantiate()
	add_child_autofree(a)
	a.setup(actor, [3], 1)
	await wait_physics_frames(2)
	var hit = a.terrain_hit(Vector2.ZERO, Vector2(100, 0))
	assert_not_null(hit)
	assert_almost_eq(hit.x, 40.0, 0.5)
