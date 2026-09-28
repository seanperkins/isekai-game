extends GutTest

class FakeActor extends Node2D:
	var team := "player"
	var facing := 1
	var impulses: Array = []
	var hits: Array = []
	var threads: Array = []
	func apply_impulse(v: Vector2) -> void:
		impulses.append(v)
	func receive_hit(raw: int, damage_type: String) -> void:
		hits.append([raw, damage_type])
	func receive_thread(tier: int) -> void:
		threads.append(tier)

var player: FakeActor

func before_each() -> void:
	player = FakeActor.new()
	add_child_autofree(player)
	player.add_to_group("actors")

func _enemy(x: float, y: float = 0.0) -> FakeActor:
	var e := FakeActor.new()
	e.team = "enemy"
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = Vector2(x, y)
	return e

func _ability(scene: String, values: Array, level: int = 1) -> Ability:
	var a: Ability = load(scene).instantiate()
	add_child_autofree(a)
	a.setup(player, values, level)
	return a

func test_cooldown_blocks_until_it_elapses() -> void:
	var a := _ability("res://scenes/abilities/jet_dash.tscn", [])
	assert_true(a.activate())
	assert_false(a.activate())
	a._process(0.8)
	assert_true(a.activate())

func test_poison_breath_hits_other_team_in_front_only() -> void:
	var front := _enemy(40)
	var behind := _enemy(-40)
	var far := _enemy(200)
	var ally := FakeActor.new()
	add_child_autofree(ally)
	ally.add_to_group("actors")
	ally.global_position = Vector2(20, 0)
	var a := _ability("res://scenes/abilities/poison_breath.tscn", [2, 3, 4, 5, 6], 3)
	a.activate()
	assert_eq(front.hits, [[4, "poison"]])
	assert_eq(behind.hits, [])
	assert_eq(far.hits, [])
	assert_eq(ally.hits, [])

func test_water_blade_hits_nearest_in_front() -> void:
	var near := _enemy(60)
	var farther := _enemy(120)
	_ability("res://scenes/abilities/water_blade.tscn", [3]).activate()
	assert_eq(near.hits, [[3, "physical"]])
	assert_eq(farther.hits, [])

func test_sticky_thread_passes_tier() -> void:
	var e := _enemy(50)
	_ability("res://scenes/abilities/sticky_thread.tscn", [1, 1, 2, 2, 2], 3).activate()
	assert_eq(e.threads, [2])

func test_movement_abilities_push_the_actor_in_facing_direction() -> void:
	player.facing = -1
	_ability("res://scenes/abilities/hydraulic_propulsion.tscn", [100, 120, 140, 160, 180], 2).activate()
	_ability("res://scenes/abilities/jet_dash.tscn", []).activate()
	_ability("res://scenes/abilities/swing_thread.tscn", []).activate()
	assert_eq(player.impulses.size(), 3)
	assert_eq(player.impulses[0], Vector2(-456.0, -140.0))
	for v in player.impulses:
		assert_lt(v.x, 0.0)
