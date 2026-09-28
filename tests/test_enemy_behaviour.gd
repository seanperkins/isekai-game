extends GutTest
## Smarter enemies: they need line of sight, forget you a while after losing you, respect
## ledges and walls, and every attack is telegraphed and dodgeable.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	var poisons: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF) -> void:
		hits.append([raw, damage_type])
	func receive_poison(application: int, tick_amount: int, seconds: float) -> void:
		poisons.append([application, tick_amount, seconds])

var creatures := {}
var skills_by_id := {}
var fake_player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	fake_player = StubPlayer.new()
	add_child_autofree(fake_player)
	fake_player.add_to_group("player")

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func _solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

## A floor whose top is at y 6, where a 12 px tall enemy at y 0 stands.
func _floor() -> void:
	_solid(Rect2(-400, 6, 800, 20))

func _blobs() -> int:
	return get_tree().get_nodes_in_group("hazards").size()

func test_rock_blocks_sight() -> void:
	_floor()
	_solid(Rect2(40, -60, 20, 66))
	var lizard := _enemy("lizard", Vector2(0, 0))
	fake_player.global_position = Vector2(100, 0)
	await wait_physics_frames(10)
	assert_false(lizard.is_alert())
	assert_eq(lizard.facing, -1)

func test_awareness_fades_after_losing_sight() -> void:
	_floor()
	var lizard := _enemy("lizard", Vector2(0, 0))
	fake_player.global_position = Vector2(100, 0)
	await wait_physics_frames(3)
	assert_true(lizard.is_alert())
	fake_player.global_position = Vector2(100, -400)  # far out of range
	await wait_seconds(Enemy.ALERT_MEMORY - 0.5)
	assert_true(lizard.is_alert())
	await wait_seconds(0.8)
	assert_false(lizard.is_alert())

func test_walkers_turn_at_ledges() -> void:
	_solid(Rect2(-40, 6, 80, 20))
	var lizard := _enemy("lizard", Vector2(0, 0))
	fake_player.global_position = Vector2(0, -1000)  # nobody around: patrolling
	await wait_seconds(3.0)
	assert_between(lizard.global_position.x, -40.0, 40.0)
	assert_lt(lizard.global_position.y, 10.0)

func test_walkers_turn_at_walls() -> void:
	_floor()
	_solid(Rect2(-30, -40, 10, 46))
	var lizard := _enemy("lizard", Vector2(0, 0))
	fake_player.global_position = Vector2(0, -1000)
	await wait_seconds(1.5)
	assert_eq(lizard.facing, 1)

func test_a_chaser_stops_at_the_ledge_instead_of_falling() -> void:
	_solid(Rect2(-40, 6, 80, 20))
	var toad := _enemy("toad", Vector2(0, 0))
	fake_player.global_position = Vector2(-150, 0)  # visible, beyond the edge, out of spit range
	await wait_seconds(2.0)
	assert_true(toad.is_alert())
	assert_between(toad.global_position.x, -40.0, 40.0)

func test_toad_winds_up_then_lobs_a_blob_that_poisons_on_hit() -> void:
	_floor()
	_enemy("toad", Vector2(0, 0))
	fake_player.global_position = Vector2(80, 0)
	await wait_seconds(0.2)
	assert_eq(_blobs(), 0)  # still puffing up
	await wait_seconds(0.35)
	assert_eq(_blobs(), 1)
	assert_eq(fake_player.poisons, [])
	await wait_seconds(1.0)
	assert_eq(fake_player.poisons, [[4, 1, 3.0]])
	assert_eq(_blobs(), 0)

func test_a_wall_stops_a_blob() -> void:
	_solid(Rect2(40, -60, 10, 70))
	fake_player.global_position = Vector2(80, 0)
	var blob := SpitBlob.new()
	add_child_autofree(blob)
	blob.launch(Vector2(0, 0), Vector2(80, 0), 4, 1, 3.0)
	await wait_seconds(1.0)
	assert_eq(fake_player.poisons, [])
	assert_false(is_instance_valid(blob))

func test_launch_velocity_lands_on_the_target() -> void:
	var from := Vector2(0, 0)
	var to := Vector2(80, -20)
	var v := SpitBlob.launch_velocity(from, to)
	var t := SpitBlob.FLIGHT_SECONDS
	var landed := from + v * t + Vector2(0, 0.5 * SpitBlob.GRAVITY * t * t)
	assert_almost_eq(landed, to, Vector2(0.01, 0.01))

func test_lizard_telegraphs_then_charges_then_rests() -> void:
	_floor()
	var lizard := _enemy("lizard", Vector2(0, 0))  # faces left
	fake_player.global_position = Vector2(-100, 0)
	await wait_physics_frames(3)
	assert_eq(lizard.charge_state(), "windup")
	assert_eq(lizard.velocity.x, 0.0)
	await wait_seconds(Enemy.CHARGE_WINDUP + 0.05)
	assert_eq(lizard.charge_state(), "charge")
	assert_almost_eq(lizard.velocity.x, -Enemy.BASE_SPEED * 0.8 * Enemy.CHARGE_MULT, 0.01)
	await wait_seconds(Enemy.CHARGE_SECONDS + 0.05)
	assert_eq(lizard.charge_state(), "rest")
	assert_eq(lizard.velocity.x, 0.0)

func test_bat_hovers_warns_then_dives_at_where_you_were() -> void:
	var bat := _enemy("bat", Vector2(0, -80))
	fake_player.global_position = Vector2(0, 0)
	await wait_physics_frames(2)
	assert_eq(bat.swoop_state(), "hover")
	var saw_warn := false
	for i in 150:
		await wait_physics_frames(1)
		if bat.swoop_state() == "warn":
			saw_warn = true
		if bat.swoop_state() == "dive":
			break
	assert_true(saw_warn)
	assert_eq(bat.swoop_state(), "dive")
	await wait_physics_frames(1)  # the dive's velocity is set on its first frame
	var dir: Vector2 = bat.velocity.normalized()
	assert_ne(dir, Vector2.ZERO)
	fake_player.global_position = Vector2(200, 0)  # sidestep
	await wait_physics_frames(3)
	assert_almost_eq(bat.velocity.normalized(), dir, Vector2(0.01, 0.01))  # not homing
