extends GutTest
## The Grotto's behaviours: the moth drifts and drops puffs, the crab charges, the snake lunges on a tether.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	var poisons: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_poison(application: int, tick_amount: int, seconds: float) -> void:
		poisons.append([application, tick_amount, seconds])

var creatures := {}
var skills_by_id := {}
var fake_player: StubPlayer
var puff_events := 0

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	fake_player = StubPlayer.new()
	add_child_autofree(fake_player)
	fake_player.add_to_group("player")
	puff_events = 0
	EventBus.world_event.connect(_on_world_event)

func after_each() -> void:
	if EventBus.world_event.is_connected(_on_world_event):
		EventBus.world_event.disconnect(_on_world_event)

func _on_world_event(n: String, _t: Dictionary) -> void:
	if n == "spore_puff":
		puff_events += 1

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
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

func _puffs() -> int:
	return get_tree().get_nodes_in_group("hazards").filter(func(n: Node) -> bool: return n is SporePuff).size()

func test_a_moth_neither_falls_nor_dives() -> void:
	var m := _enemy("spore_moth", Vector2(0, -60))  # no floor: a faller would drop
	fake_player.global_position = Vector2(60, -60)  # in alert range and level: a bat would dive
	await wait_physics_frames(60)
	assert_almost_eq(m.global_position.y, -60.0, 16.0, "it holds its height")
	assert_ne(m.swoop_state(), "dive")

func test_a_moth_in_view_flashes_then_drops_a_puff_each_interval() -> void:
	var m := _enemy("spore_moth", Vector2(0, -60))
	fake_player.global_position = Vector2(100, -60)
	await wait_physics_frames(int((Enemy.PUFF_INTERVAL - Enemy.PUFF_WINDUP) * 60.0) - 10)
	assert_eq(puff_events, 0, "not yet")
	await wait_physics_frames(int(Enemy.PUFF_WINDUP * 30.0))
	assert_true(m.telegraphing(), "it flashes before it drops")
	await wait_physics_frames(int(Enemy.PUFF_WINDUP * 60.0) + 20)
	assert_eq(puff_events, 1, "one puff by the interval")
	assert_gte(_puffs(), 1)
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0))
	assert_eq(puff_events, 2, "and a second one an interval later")

func test_a_moth_far_from_the_player_drops_nothing() -> void:
	_enemy("spore_moth", Vector2(0, -60))
	fake_player.global_position = Vector2(2000, -60)
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0) * 2)
	assert_eq(puff_events, 0)

func test_a_stunned_moth_stays_aloft_and_a_downed_one_falls() -> void:
	_floor()
	var m := _enemy("spore_moth", Vector2(0, -60))
	await wait_physics_frames(5)
	m.status.stun()
	await wait_physics_frames(30)
	assert_almost_eq(m.global_position.y, -60.0, 16.0, "stunned: still aloft")
	m.status.down()
	await wait_physics_frames(90)
	assert_gt(m.global_position.y, -20.0, "downed: it fell to the floor so it can be eaten")

func test_a_puff_hurts_the_player_once_then_lingers_harmlessly() -> void:
	var puff := SporePuff.new()
	add_child_autofree(puff)
	puff.launch(Vector2(0, 0))
	fake_player.global_position = Vector2(4, 0)
	await wait_physics_frames(30)
	assert_eq(fake_player.poisons.size(), 1, "one hit per puff, however long it lingers on the player")
	assert_true(puff.is_in_group("hazards"))

func test_a_puff_expires_and_ignores_enemies() -> void:
	var puff := SporePuff.new()
	add_child_autofree(puff)
	puff.launch(Vector2(500, 0))
	var toad := _enemy("toad", Vector2(500, 0))
	await wait_physics_frames(int(SporePuff.LIFETIME * 60.0) + 15)
	assert_eq(toad.health.hp, toad.health.max_hp, "a puff hurts the player only")
	assert_false(is_instance_valid(puff) and puff.is_inside_tree(), "it expired")

func test_a_snake_lunges_when_you_pass_under_then_returns_to_its_anchor() -> void:
	var s := _enemy("vine_snake", Vector2(0, -100))
	var anchor := s.global_position
	fake_player.global_position = Vector2(20, 0)  # under it, within 110
	var seen := {}
	for i in 240:
		await wait_physics_frames(1)
		seen[s.charge_state()] = true
		assert_true(s._on_ceiling, "the tether never clears")
	assert_true(seen.has("windup") and seen.has("charge") and seen.has("rest"), str(seen.keys()))
	fake_player.global_position = Vector2(2000, 0)
	await wait_physics_frames(120)
	assert_lt(s.global_position.distance_to(anchor), 4.0, "back on its anchor")

func test_a_stunned_snake_holds_still_and_a_downed_one_falls() -> void:
	_floor()
	var s := _enemy("vine_snake", Vector2(0, -100))
	await wait_physics_frames(5)
	s.status.stun()
	await wait_physics_frames(30)
	assert_almost_eq(s.global_position.y, -100.0, 3.0, "stunned mid-air: it stays on its tether")
	s.status.down()
	await wait_physics_frames(120)
	assert_gt(s.global_position.y, -30.0)

func test_a_crab_winds_up_then_charges_like_the_lizard() -> void:
	_floor()
	var c := _enemy("mushroom_crab", Vector2(0, 0))
	c.facing = 1
	fake_player.global_position = Vector2(80, 0)
	var seen := {}
	for i in 90:
		await wait_physics_frames(1)
		seen[c.charge_state()] = true
	assert_true(seen.has("windup") and seen.has("charge"), str(seen.keys()))

func test_a_snake_stunned_away_from_its_anchor_returns_when_the_stun_ends() -> void:
	var s := _enemy("vine_snake", Vector2(0, -100))
	var anchor := s.global_position
	await wait_physics_frames(3)
	s.global_position = anchor + Vector2(30, 40)  # where a lunge or a retreat left it
	s._state = "charge"
	s.status.stun(1.0)
	fake_player.global_position = Vector2(2000, 0)
	await wait_physics_frames(int(60.0 * 1.0) + 5)
	assert_eq(s.status.state, EnemyStatus.ACTIVE, "the stun is over")
	await wait_physics_frames(150)
	assert_lt(s.global_position.distance_to(anchor), 4.0, "and it is back on its anchor")

func test_a_puff_sinks_onto_a_player_standing_below_the_moth() -> void:
	var m := _enemy("spore_moth", Vector2(0, -100))
	fake_player.global_position = Vector2(0, 0)  # 100 px below, inside the 320 px view range
	var follow := func(n: String, t: Dictionary) -> void:
		if n == "spore_puff":
			fake_player.global_position.x = t["pos"].x  # the player stands right under wherever the moth is
	EventBus.world_event.connect(follow)
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0) + 200)
	EventBus.world_event.disconnect(follow)
	assert_gte(fake_player.poisons.size(), 1, "the puff drifted down onto it")
	assert_true(is_instance_valid(m))

func test_a_moth_killed_mid_windup_stops_flashing_its_warning() -> void:
	var m := _enemy("spore_moth", Vector2(0, -100))
	m._state = "flash"
	m._state_t = 0.3
	assert_true(m.telegraphing())
	m.receive_hit(99, "physical", Vector2.INF, "tackle")
	await wait_physics_frames(3)
	assert_false(m.telegraphing(), "a corpse does not telegraph")

func test_a_moth_turns_back_at_a_wall() -> void:
	_solid(Rect2(60, -200, 20, 300))  # a wall just east of it
	var m := _enemy("spore_moth", Vector2(0, -100))
	m.facing = 1
	fake_player.global_position = Vector2(-2000, 0)
	await wait_physics_frames(120)
	assert_eq(m.facing, -1, "it turned round instead of rubbing the wall")
	assert_lt(m.global_position.x, 60.0)

func test_a_moth_behind_rock_does_not_puff() -> void:
	_solid(Rect2(40, -300, 20, 600))  # rock between the moth and the player
	_enemy("spore_moth", Vector2(0, -100))
	fake_player.global_position = Vector2(150, -100)
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0) * 2)
	assert_eq(puff_events, 0, "no line of sight, no puff")
