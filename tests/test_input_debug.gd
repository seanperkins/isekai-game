extends GutTest
## F1 / Back toggles an input debug overlay: raw stick, resolved aim, last cast direction.

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_overlay_toggles_and_reports_stick_aim_and_last_cast() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(1)
	assert_false(game.hud.input_debug_visible())
	game.hud.toggle_input_debug()
	assert_true(game.hud.input_debug_visible())
	var text: String = game.hud.input_debug_text()
	assert_string_contains(text, "stick")
	assert_string_contains(text, "aim")
	assert_string_contains(text, "last cast: —")
	game.player.last_cast = {"id": "water_blade", "aim": Vector2(0, -1)}
	assert_string_contains(game.hud.input_debug_text(), "last cast: water_blade (0, -1)")
	assert_true(InputMap.has_action("debug_input"))
