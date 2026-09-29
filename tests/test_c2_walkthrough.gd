extends GutTest
## C2's floor must be walkable from its west exit to its east exit with no skills: the room's arch is scenery to walk under,
## not a wall (its legs were solid and blocked the way).

func _walk(game, from_x: float, to_x: float, frames: int) -> float:
	var rect: Rect2 = game.world.current_rect()
	Input.action_press("move_right")
	var best := 0.0
	for i in frames:
		await get_tree().physics_frame
		var local: Vector2 = game.player.global_position - rect.position
		best = maxf(best, local.x)
		if local.x >= to_x:
			break
	Input.action_release("move_right")
	return best

func test_a_player_can_walk_under_c2s_arch() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.world.enter_at("C2", Vector2(300, 308))
	# remove its creatures: this is about the level geometry (a frozen body would block the way too)
	for n in get_tree().get_nodes_in_group("actors"):
		if n != game.player:
			n.free()
	var reached: float = await _walk(game, 300.0, 800.0, 600)
	assert_gte(reached, 800.0, "walked from x 300 to x 800 along the floor (reached %.0f)" % reached)
	SkillRules.reset_run()
	Announcer.queue.clear()
