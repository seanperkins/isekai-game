extends GutTest
## Every player active shows a visible effect when cast.

class FakeActor extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	func apply_impulse(_v: Vector2) -> void:
		pass
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF) -> void:
		hits.append([raw, damage_type])
	func receive_thread(_tier: int) -> void:
		pass

var player: FakeActor

func before_each() -> void:
	player = FakeActor.new()
	add_child_autofree(player)
	player.add_to_group("actors")

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("vfx"):
		n.free()

func _enemy(x: float) -> FakeActor:
	var e := FakeActor.new()
	e.team = "enemy"
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = Vector2(x, 0)
	return e

func _cast(id: String, values: Array = [1, 1, 1, 1, 1]) -> void:
	var a: Ability = load("res://scenes/abilities/%s.tscn" % id).instantiate()
	add_child_autofree(a)
	a.setup(player, values, 1)
	a.activate()

func _vfx() -> Array:
	return get_tree().get_nodes_in_group("vfx")

func test_poison_breath_shows_a_green_cloud_in_front() -> void:
	_cast("poison_breath")
	var clouds := _vfx()
	assert_eq(clouds.size(), 1)
	var puffs: Array = clouds[0].get_children().filter(func(n): return n is Sprite2D)
	assert_gte(puffs.size(), 3)
	for p in puffs:
		assert_eq(p.texture, Art.texture("spit_glob"))
		assert_gt(p.global_position.x, player.global_position.x)

func test_water_blade_draws_a_streak_to_its_target() -> void:
	var e := _enemy(60)
	_cast("water_blade", [3])
	var lines := _vfx().filter(func(n): return n is Line2D)
	assert_eq(lines.size(), 1)
	assert_eq(lines[0].points[1], e.global_position)

func test_water_blade_without_a_target_streaks_to_full_range() -> void:
	_cast("water_blade", [3])
	var lines := _vfx().filter(func(n): return n is Line2D)
	assert_eq(lines[0].points[1], player.global_position + Vector2(160, 0))

func test_sticky_thread_draws_a_thread() -> void:
	_enemy(50)
	_cast("sticky_thread")
	assert_eq(_vfx().filter(func(n): return n is Line2D).size(), 1)

func test_movement_skills_leave_an_afterimage() -> void:
	for id in ["hydraulic_propulsion", "jet_dash", "swing_thread"]:
		_cast(id)
	assert_eq(_vfx().size(), 3)

func test_effects_fade_and_free_themselves() -> void:
	_cast("poison_breath")
	await wait_seconds(0.6)
	assert_eq(_vfx().size(), 0)
