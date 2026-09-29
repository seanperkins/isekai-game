extends GutTest
## Enemy behaviour with physics actually running (the unit tests elsewhere freeze it).

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

func test_lizard_does_not_turn_while_the_player_is_in_tackle_range() -> void:
	var lizard := _enemy("lizard", Vector2(0, 0))  # faces -1 (left)
	fake_player.global_position = Vector2(20, 0)          # right behind it
	await wait_physics_frames(5)
	assert_eq(lizard.facing, -1)

func test_lizard_turns_toward_a_player_outside_tackle_range() -> void:
	var lizard := _enemy("lizard", Vector2(0, 0))
	fake_player.global_position = Vector2(100, 0)
	await wait_physics_frames(3)
	assert_eq(lizard.facing, 1)

func test_active_enemy_deals_contact_damage() -> void:
	_enemy("bat", Vector2(0, 0))
	fake_player.global_position = Vector2(4, 0)
	await wait_physics_frames(2)
	assert_gt(fake_player.hits.size(), 0)
	assert_eq(fake_player.hits[0], [3, "physical"])

func test_downed_enemy_runs_no_ai_and_deals_no_contact_damage() -> void:
	var bat := _enemy("bat", Vector2(0, 0))
	bat.receive_hit(9, "physical")
	fake_player.global_position = Vector2(4, 0)
	await wait_physics_frames(5)
	assert_eq(fake_player.hits, [])
	assert_eq(bat.velocity.x, 0.0)

func test_toad_spits_poison_in_range_then_waits_for_cooldown() -> void:
	_enemy("toad", Vector2(0, 0))
	fake_player.global_position = Vector2(80, 0)
	await wait_seconds(1.5)  # wind-up, then the blob's flight
	assert_eq(fake_player.poisons, [[4, 1, 3.0]])
