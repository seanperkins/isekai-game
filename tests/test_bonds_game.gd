extends GutTest
## In the game: a bonded creature belongs to the player's world, not to a room, so it goes where the player goes.

func _game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	return game

func _stunned_wolf_beside(game: Node) -> Enemy:
	var e: Enemy = game._spawn("gloom_wolf", Vector2.ZERO)
	game.world.room.add_child(e)
	e.global_position = game.player.global_position + Vector2(12, 0)
	e.status.stun(30.0)
	return e

func test_a_wolf_bonds_a_stunned_gloom_wolf_with_the_inspect_button() -> void:
	var game = await _game()
	game.player.set_species("wolf")
	var e: Enemy = _stunned_wolf_beside(game)
	game.player.do_inspect()
	assert_eq(game.player.companions.size(), 1)
	assert_true(e.is_queued_for_deletion())
	assert_eq(SkillRules.condition_value({"kind": "counter", "event": Deeds.BOND_FORMED, "tags": {"kind": "pack", "creature": "gloom_wolf"}, "n": 1}), 1)

func test_the_companion_is_not_a_child_of_the_room_so_a_room_change_cannot_free_it() -> void:
	var game = await _game()
	game.player.set_species("wolf")
	var e: Enemy = _stunned_wolf_beside(game)
	game.player.do_inspect()
	var pal: Companion = game.player.companions[0]
	assert_eq(pal.get_parent(), game.player.get_parent())
	assert_false(game.world.room.is_ancestor_of(pal))

func test_a_companion_follows_the_player_across_the_world() -> void:
	var game = await _game()
	game.player.set_species("wolf")
	var e: Enemy = _stunned_wolf_beside(game)
	game.player.do_inspect()
	var pal: Companion = game.player.companions[0]
	game.player.global_position += Vector2(1500, 0)
	await wait_physics_frames(3)
	assert_lt(pal.global_position.distance_to(game.player.global_position), Companion.TELEPORT_DISTANCE)

func test_the_player_dying_in_the_game_frees_the_companion() -> void:
	var game = await _game()
	game.player.set_species("wolf")
	var e: Enemy = _stunned_wolf_beside(game)
	game.player.do_inspect()
	var pal: Companion = game.player.companions[0]
	game.player.receive_hit(game.player.health.max_hp * 5, "fire")
	await wait_physics_frames(2)
	assert_false(is_instance_valid(pal))
