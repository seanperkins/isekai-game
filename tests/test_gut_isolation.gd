extends GutTest
## Every test script starts from the game's own input state (tests/support/gut_isolation.gd).

func test_fresh_forgets_the_pad_the_mouse_and_what_is_held() -> void:
	Controls.using_joypad = true
	Controls.mouse_aim = true
	Controls.last_stick = Vector2(0.5, 0.5)
	Input.action_press("active_1")
	GutIsolation.fresh()
	assert_false(Controls.using_joypad)
	assert_false(Controls.mouse_aim)
	assert_eq(Controls.last_stick, Vector2.ZERO)
	assert_false(Input.is_action_pressed("active_1"))

func test_the_runner_asks_for_it() -> void:
	var runner := FileAccess.get_file_as_string("res://tools/run_tests.sh")
	assert_string_contains(runner, "-gpre_run_script=res://tests/support/gut_isolation.gd")
