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
	assert_eq(get_tree().get_nodes_in_group("predatable").filter(func(n): return n is WaterPool).size(), RoomLayout.TEST_ROOM["spawns"].filter(func(s): return s["id"] == "water_pool").size())
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
	var minimums := {"bat": 3, "toad": 4, "lizard": 3, "spider": 3, "water_pool": 2}
	for id in minimums:
		assert_gte(int(counts.get(id, 0)), minimums[id], id)

func test_the_starting_cave_spans_several_screens_each_way() -> void:
	var size: Vector2 = RoomLayout.TEST_ROOM["size"]
	assert_gte(size.x, 640.0 * 5)
	assert_gte(size.y, 360.0 * 3)

func test_spawns_sit_inside_the_cave_and_outside_rock() -> void:
	var size: Vector2 = RoomLayout.TEST_ROOM["size"]
	var solids: Array = RoomLayout.TEST_ROOM["solids"]
	for s in RoomLayout.TEST_ROOM["spawns"] + [{"id": "player", "pos": RoomLayout.TEST_ROOM["player"]}]:
		var pos: Vector2 = s["pos"]
		assert_true(Rect2(Vector2.ZERO, size).has_point(pos), "%s at %s" % [s["id"], pos])
		for r in solids:
			assert_false(r.has_point(pos), "%s at %s is inside %s" % [s["id"], pos, r])

## Ledges the slime stands on: inner solids no taller than 24 px (not columns or anchor rocks).
func _ledges() -> Array:
	var size: Vector2 = RoomLayout.TEST_ROOM["size"]
	return RoomLayout.TEST_ROOM["solids"].filter(func(r): return r.position.x >= 0.0 \
			and r.position.y >= 0.0 and r.position.x < size.x and r.size.y <= 24.0 and r.size.x > 20.0)

func test_every_ledge_is_reachable_from_the_floor_by_base_jumps() -> void:
	# Base apex: v^2 / 2g = 330^2 / 1800 = 60.5 px; allow 55 px of rise and a 60 px gap per
	# jump, or an 80 px gap when hopping across or down. No skills needed, not even the thread.
	var size: Vector2 = RoomLayout.TEST_ROOM["size"]
	var floor_rect: Rect2 = RoomLayout.TEST_ROOM["solids"][0]
	assert_eq(floor_rect.end, size, "the first solid is the floor")
	var ledges := _ledges()
	var reached := [floor_rect]
	var frontier := [floor_rect]
	while not frontier.is_empty():
		var p: Rect2 = frontier.pop_back()
		for q in ledges:
			if reached.has(q):
				continue
			var rise: float = p.position.y - q.position.y
			var gap: float = maxf(0.0, maxf(p.position.x - q.end.x, q.position.x - p.end.x))
			if (rise > 0.0 and rise <= 55.0 and gap <= 60.0) or (rise <= 0.0 and gap <= 80.0):
				reached.append(q)
				frontier.append(q)
	for q in ledges:
		assert_true(reached.has(q), "ledge at %s" % q)
