extends GutTest

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_main_scene_boots_a_run_in_the_first_room() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_not_null(game.player)
	assert_true(SkillRules.run_active)
	assert_eq(SkillRules.level_of("appraisal"), 1)
	assert_eq(game.world.current_id, "C1")
	assert_eq(game.run.room_id, "C1")
	var c1: RoomDef = game.world.rooms["C1"]
	var enemies := get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy)
	assert_eq(enemies.size(), c1.spawns.filter(func(s): return s["id"] != "water_pool").size())
	assert_eq(get_tree().get_nodes_in_group("predatable").filter(func(n): return n is WaterPool).size(),
		c1.spawns.filter(func(s): return s["id"] == "water_pool").size())
	assert_eq(game.hud.hp_text(), "HP 30/30")
	assert_eq(get_viewport().get_camera_2d(), game.world.camera)

func test_hud_shows_unlock_popup_from_the_announcer() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	for i in 40:
		EventBus.game_event.emit("jumped", {"from": "ground"})
	await wait_process_frames(2)
	assert_string_contains(game.hud.popup_text(), "Leap")

func test_creatures_on_screen_at_the_start_enter_the_bestiary() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_true(Compendium.model.creature_record("bat")["seen"])

func test_eating_and_defeating_reach_the_bestiary() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	var before: Dictionary = Compendium.model.creature_record("toad")
	EventBus.game_event.emit(Events.PREDATED, {"source": "toad", "kind": "creature"})
	var toad: Enemy = get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy and n.def.id == "toad")[0]
	toad.downed.emit(toad.def)
	var after: Dictionary = Compendium.model.creature_record("toad")
	assert_eq(after["eaten"], before["eaten"] + 1)
	assert_eq(after["defeated"], before["defeated"] + 1)
