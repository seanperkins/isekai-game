extends GutTest

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_main_scene_boots_a_run_with_room_actors_and_hud() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_not_null(game.player)
	assert_true(SkillRules.run_active)
	assert_eq(SkillRules.level_of("appraisal"), 1)
	var enemies := get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy)
	assert_eq(enemies.size(), RoomLayout.TEST_ROOM["spawns"].filter(func(s): return s["id"] != "water_pool").size())
	assert_eq(get_tree().get_nodes_in_group("predatable").filter(func(n): return n is WaterPool).size(), 2)
	assert_eq(game.hud.hp_text(), "HP 30/30")

func test_hud_shows_unlock_popup_from_the_announcer() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	for i in 40:
		EventBus.game_event.emit("jumped", {"from": "ground"})
	await wait_process_frames(2)
	assert_string_contains(game.hud.popup_text(), "Leap")

func test_test_room_meets_the_food_minimums_for_the_slice() -> void:
	var counts := {}
	for s in RoomLayout.TEST_ROOM["spawns"]:
		counts[s["id"]] = int(counts.get(s["id"], 0)) + 1
	assert_eq(counts, {"bat": 3, "toad": 4, "lizard": 3, "spider": 3, "water_pool": 2})
