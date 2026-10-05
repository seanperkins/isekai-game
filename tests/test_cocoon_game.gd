extends GutTest
## In the game: a freed prey is a stunned creature in the room again, and can be webbed once more.

func _game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	for n in get_tree().get_nodes_in_group("inspectable"):  # nothing near the spider to inspect, or the button would inspect
		if n != game.player:
			n.free()
	return game

func _creatures_of(game: Node, id: String) -> Array:
	return game.world.room.get_children().filter(func(n: Node) -> bool: return n is Enemy and n.def.id == id)

func test_a_freed_prey_stands_stunned_beside_the_spider() -> void:
	var game = await _game()
	game.player.set_species("spider")
	game.player.collect_part("cocoon:bat")
	game.player.do_inspect()
	var found := _creatures_of(game, "bat")
	assert_eq(found.size(), 1)
	var bat: Enemy = found[0]
	assert_eq(bat.status.state, EnemyStatus.STUNNED)
	assert_lt(bat.global_position.distance_to(game.player.global_position), 40.0)
	assert_eq(SkillRules.condition_value({"kind": "counter", "event": Deeds.PREY_FREED, "tags": {"creature": "bat"}, "n": 1}), 1)

func test_the_freed_prey_can_be_webbed_again() -> void:
	var game = await _game()
	game.player.set_species("spider")
	game.player.collect_part("cocoon:bat")
	game.player.do_inspect()
	game.player.do_inspect()
	assert_eq(game.player.inventory.cocoons(), ["bat"])
	assert_eq(_creatures_of(game, "bat").filter(func(n: Enemy) -> bool: return not n.is_queued_for_deletion()).size(), 0)
