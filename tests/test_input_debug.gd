extends GutTest
## F3 / Back toggles an input debug overlay: raw stick, the owning pad's right stick, the mouse state, the aim a cast would use
## (the left stick and keys are 8-way; the right stick and the mouse are free), last cast direction.

func after_each() -> void:
	PadInput.reset()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _game():
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(1)
	return game

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
	assert_string_contains(text, "pads ")
	assert_string_contains(text, "raw up ")
	game.player.last_cast = {"id": "water_blade", "aim": Vector2(0, -1)}
	assert_string_contains(game.hud.input_debug_text(), "last cast: water_blade (0, -1)")
	assert_true(InputMap.has_action("debug_input"))

func test_the_aim_field_is_the_aim_a_cast_would_use_and_default_when_nothing_is_held() -> void:
	var game = await _game()
	assert_string_contains(game.hud.input_debug_text(), "aim default")
	PadInput.axis(JOY_AXIS_LEFT_Y, -1.0)
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	assert_string_contains(game.hud.input_debug_text(), "aim (1, 0)")

func test_the_first_line_shows_the_owning_pads_raw_right_stick_even_under_the_deadzone() -> void:
	var game = await _game()
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.3)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.1)
	var text: String = game.hud.input_debug_text()
	assert_string_contains(text, "rstick dev 0 (0.30, 0.10)")
	assert_string_contains(text, "aim default")

func test_the_overlay_shows_whether_the_mouse_is_aiming() -> void:
	var game = await _game()
	assert_string_contains(game.hud.input_debug_text(), "mouse off")
	PadInput.mouse_move(Vector2(10, 0))
	assert_string_contains(game.hud.input_debug_text(), "mouse on")
