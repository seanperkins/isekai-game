extends GutTest
## The conditions of an enemy's mind that verbs lay on it: frightened (it runs and does not attack), calm (it is not hostile), lured (it goes after a decoy,
## not the player), confused (it staggers), and a player it cannot see. A boss, which always hunts, is not moved by any of them.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	var unseen := false
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func is_unseen() -> bool:
		return unseen

var creatures := {}
var skills_by_id := {}
var player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func test_the_creature_the_tests_use_is_a_plain_walker() -> void:
	assert_eq(_enemy().kind, Enemy.Kind.WALKER, "a charger would wind up a charge, not walk, when the effect ends")

func before_each() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 16)
	add_child_autofree(ground)
	player = StubPlayer.new()
	add_child_autofree(player)
	player.add_to_group("player")
	player.add_to_group("actors")

func _enemy(id := "cave_rat", at := Vector2.ZERO) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = at
	add_child_autofree(e)
	return e

func test_a_frightened_enemy_runs_from_the_player_and_does_not_hurt_it() -> void:
	var e := _enemy()
	player.global_position = Vector2(10, 0)
	assert_true(e.flee_for(1.0))
	await wait_physics_frames(10)
	assert_true(e.is_fleeing())
	assert_lt(e.velocity.x, -10.0, "away from the player, who is to its right")
	assert_eq(player.hits.size(), 0, "a frightened creature does not attack, even touching")

func test_the_fright_wears_off_and_it_comes_back() -> void:
	var e := _enemy()
	player.global_position = Vector2(60, 0)
	e.flee_for(0.3)
	await wait_seconds(0.6)
	assert_false(e.is_fleeing())
	await wait_physics_frames(10)
	assert_gt(e.velocity.x, 10.0, "back after the player")

func test_a_calm_enemy_ignores_the_player_until_it_is_hurt() -> void:
	var e := _enemy()
	player.global_position = Vector2(30, 0)
	assert_true(e.calm_for(5.0))
	await wait_physics_frames(20)
	assert_false(e.is_alert(), "it does not notice the player")
	assert_eq(player.hits.size(), 0)
	assert_true(e.is_calm())
	e.receive_hit(1, "physical", player.global_position)
	assert_false(e.is_calm(), "a blow ends the calm")

func test_calm_wears_off_too() -> void:
	var e := _enemy()
	player.global_position = Vector2(60, 0)
	e.calm_for(0.3)
	await wait_seconds(0.6)
	assert_false(e.is_calm())
	await wait_physics_frames(6)
	assert_true(e.is_alert())

func test_a_boss_that_always_hunts_is_not_frightened_calmed_or_confused() -> void:
	var e := _enemy()
	e.hunting = true
	assert_false(e.flee_for(2.0))
	assert_false(e.calm_for(2.0))
	assert_false(e.confuse_for(2.0))
	assert_false(e.is_fleeing() or e.is_calm() or e.is_confused())

func test_a_lured_enemy_goes_after_the_lure_not_the_player() -> void:
	var e := _enemy()
	player.global_position = Vector2(60, 0)
	var lure := Node2D.new()
	add_child_autofree(lure)
	lure.global_position = Vector2(-120, 0)
	e.lure_to(lure, 3.0)
	await wait_physics_frames(15)
	assert_lt(e.velocity.x, -10.0, "toward the lure, behind it")
	lure.queue_free()
	await wait_physics_frames(4)
	assert_gt(e.velocity.x, 10.0, "a lure that is gone sends it back to the player")

func test_a_confused_enemy_staggers_first_one_way_and_then_the_other() -> void:
	var e := _enemy()
	player.global_position = Vector2(300, 0)
	e.confuse_for(2.0)
	var signs := {}
	for _i in 120:
		await wait_physics_frames(1)
		if absf(e.velocity.x) > 5.0:
			signs[signf(e.velocity.x)] = true
	assert_eq(signs.size(), 2, "it went both ways: %s" % [signs.keys()])

func test_a_player_that_cannot_be_seen_does_not_wake_an_enemy() -> void:
	var e := _enemy()
	player.global_position = Vector2(80, 0)
	player.unseen = true
	await wait_physics_frames(15)
	assert_false(e.is_alert())
	player.unseen = false
	await wait_physics_frames(6)
	assert_true(e.is_alert(), "seen again")

func test_a_hunting_boss_sees_through_a_veil() -> void:
	var e := _enemy()
	e.hunting = true
	player.global_position = Vector2(80, 0)
	player.unseen = true
	await wait_physics_frames(6)
	assert_true(e.is_alert(), "a boss in its arena always knows where you are")

# --- misled, woken, disarmed, and lured to ruin ---

func test_a_misled_enemy_walks_the_wrong_way_but_is_not_afraid() -> void:
	var e := _enemy()
	player.global_position = Vector2(100, 0)
	assert_true(e.reverse_for(1.0))
	await wait_physics_frames(10)
	assert_lt(e.velocity.x, -10.0, "away from the player, who is to its right")
	assert_false(e.is_fleeing(), "it is not frightened: touching it still hurts")

func test_a_wake_alerts_an_enemy_that_has_not_noticed_the_player_and_ends_a_calm() -> void:
	var e := _enemy()
	player.global_position = Vector2(400, 0)  # far beyond its sight
	await wait_physics_frames(3)
	assert_false(e.is_alert())
	e.calm_for(10.0)
	e.wake()
	assert_true(e.is_alert(), "a loud noise: it is up, and no longer calm")
	assert_false(e.is_calm())

func test_a_dormant_enemy_is_not_woken_by_a_wake() -> void:
	var e := _enemy()
	e.dormant = true
	e.wake()
	assert_false(e.is_alert())

func test_a_disarmed_enemy_does_not_cast_its_verb() -> void:
	var control := _enemy("twin_gleipnir")
	player.global_position = Vector2(60, 0)
	await wait_physics_frames(80)
	assert_gt(control.verb_casts, 0, "undisarmed it casts (else this test proves nothing)")
	control.queue_free()
	var e := _enemy("twin_gleipnir")
	e.disarm_for(3.0)
	await wait_physics_frames(80)
	assert_eq(e.verb_casts, 0)
	assert_true(e.is_disarmed())

func test_a_lured_enemy_walks_off_a_ledge_a_careful_one_would_stop_at_when_reckless() -> void:
	var e := _enemy("cave_rat", Vector2(0, 0))
	# the ground ends at x = 40: nothing beyond it
	for n in get_children():
		if n is StaticBody2D:
			n.queue_free()
	await wait_physics_frames(2)
	var ledge := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 20)
	shape.shape = rect
	ledge.add_child(shape)
	ledge.position = Vector2(0, 16)
	add_child_autofree(ledge)
	var lure := Node2D.new()
	add_child_autofree(lure)
	lure.global_position = Vector2(200, 0)
	player.global_position = Vector2(-300, 0)
	e.lure_to(lure, 5.0, false)
	await wait_seconds(1.5)
	assert_lt(e.global_position.x, 60.0, "a careful one stops at the edge (at %.0f)" % e.global_position.x)
	e.lure_to(lure, 5.0, true)
	await wait_seconds(1.5)
	assert_gt(e.global_position.x, 60.0, "a reckless one walks on over it (at %.0f)" % e.global_position.x)
