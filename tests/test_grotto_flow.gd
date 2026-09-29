extends GutTest
## The real world: falling through a floor hole enters the room below, and the rooms are connected in the game.

func _game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	return game

func _cleanup() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_dropping_through_c5s_floor_enters_g1() -> void:
	var game = await _game()
	game.world.enter_at("C5", Vector2(300, 990))
	await wait_physics_frames(120)
	assert_eq(game.world.current_id, "G1", "the hole in C5's floor is open")
	_cleanup()

func test_dropping_through_g2s_floor_enters_g3() -> void:
	var game = await _game()
	game.world.enter_at("G2", Vector2(880, 600))
	await wait_physics_frames(120)
	assert_eq(game.world.current_id, "G3")
	_cleanup()

func test_walking_from_g1_into_g2_and_from_g3_into_g4() -> void:
	var game = await _game()
	game.world.enter_at("G1", Vector2(1272, 296))
	await wait_physics_frames(60)
	assert_eq(game.world.current_id, "G1", "standing next to the edge is not crossing it")
	game.player.global_position = game.world.current_rect().position + Vector2(1285, 296)
	await wait_physics_frames(3)
	assert_eq(game.world.current_id, "G2", "G1's east exit leads to G2's west walkway")
	_cleanup()

## Standing on a chain's top ledge must keep you in the lower room: a ledge whose standing centre is above the
## room's top edge would flip you back and forth between the two rooms every frame.
func test_standing_on_a_chains_top_ledge_stays_in_the_lower_room() -> void:
	var game = await _game()
	game.world.enter_at("G1", Vector2(260, -8))
	await wait_physics_frames(90)
	assert_eq(game.world.current_id, "G1", "G1's top ledge")
	assert_true(game.player.is_on_floor(), "and the player stands on it")
	game.world.enter_at("G3", Vector2(200, -8))
	await wait_physics_frames(90)
	assert_eq(game.world.current_id, "G3", "G3's top ledge")
	assert_true(game.player.is_on_floor())
	_cleanup()
