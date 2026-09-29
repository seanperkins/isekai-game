extends GutTest
## The game wires the biome on room entry, and a scene reload does not restart the music or leave loops running.

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()
	Audio.reset()

func test_entering_a_room_sets_the_biome_of_its_area() -> void:
	Audio.director.current_area = ""
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(Audio.director.current_area, game.world.rooms[game.world.current_id].area)
	assert_eq(Audio.director.current_area, "cave")

func test_a_second_game_in_the_same_biome_does_not_restart_the_bed() -> void:
	var first = load("res://scenes/main.tscn").instantiate()
	add_child(first)
	await wait_physics_frames(5)
	var path: String = Audio.director.current_music
	first.queue_free()
	await wait_physics_frames(2)
	var second = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(second)
	await wait_physics_frames(5)
	assert_eq(Audio.director.current_music, path)
	assert_false(Audio.director.set_biome("cave"), "still cave: nothing to restart")

func test_dying_ends_the_loops() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	EventBus.world_event.emit("run_started", {})
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	assert_true(Audio.is_looping("slime_run"))
	game.player.receive_hit(9999, "physical")
	assert_false(Audio.is_looping("slime_run"), "the player's death ends the run loop")
	assert_false(Audio.is_looping("slime_heartbeat"), "the heartbeat stops on the death card")
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	SkillRules.run_started.emit()
	assert_false(Audio.is_looping("slime_heartbeat"), "a new run ends a heartbeat left over")
