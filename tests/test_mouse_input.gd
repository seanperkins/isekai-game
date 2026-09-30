extends GutTest
## The mouse is the second pointing device of the keyboard scheme: enough travel or a click makes it the aimer, a pad or a
## vertical aim key hands the aim back, the buttons and the left-hand keys are skill and action aliases.

func after_each() -> void:
	PadInput.reset()
	get_tree().paused = false

func test_the_helper_speaks_game_px() -> void:
	PadInput.mouse_move(Vector2(3, 0))
	assert_almost_eq(Controls._mouse_travel, 3.0, 0.01, "if this is red, the stretch scale is not being undone and the tests below are not measuring 3 px")

func test_small_moves_add_up_to_mouse_aim_and_clear_the_pad() -> void:
	Controls.using_joypad = true
	PadInput.mouse_move(Vector2(3, 0))
	assert_false(Controls.mouse_aim)
	PadInput.mouse_move(Vector2(0, 3))
	assert_true(Controls.mouse_aim)
	assert_false(Controls.using_joypad)

func test_a_jostle_under_the_threshold_does_nothing() -> void:
	Controls.using_joypad = true
	PadInput.mouse_move(Vector2(3, 0))
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)

func test_a_key_press_between_two_moves_resets_the_total() -> void:
	# a keyboard-only laptop player's stray trackpad brushes must not add up over a session into mouse aim
	PadInput.mouse_move(Vector2(3, 0))
	PadInput.key(KEY_J)  # tackle: any key press while the mouse is not aiming
	PadInput.mouse_move(Vector2(3, 0))
	assert_false(Controls.mouse_aim)

func test_a_key_press_does_not_drop_a_live_mouse_aim() -> void:
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.key(KEY_J)
	assert_true(Controls.mouse_aim)

func test_the_pad_disconnect_signal_is_wired_to_the_owner_reset() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	assert_eq(Controls.aim_device, 0)
	Input.joy_connection_changed.emit(0, false)
	assert_eq(Controls.aim_device, -1)

func test_a_pad_input_between_two_moves_resets_the_total() -> void:
	PadInput.mouse_move(Vector2(3, 0))
	PadInput.axis(JOY_AXIS_LEFT_X, 0.8)
	PadInput.mouse_move(Vector2(3, 0))
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)

func test_either_button_sets_it_and_a_release_changes_nothing() -> void:
	Controls.using_joypad = true
	PadInput.mouse_button(MOUSE_BUTTON_RIGHT)
	assert_true(Controls.mouse_aim)
	assert_false(Controls.using_joypad)
	PadInput.button(JOY_BUTTON_A)  # the pad takes over while the mouse button is still down
	PadInput.mouse_button(MOUSE_BUTTON_RIGHT, false)
	assert_true(Controls.using_joypad, "a release is not a use of the mouse")
	assert_false(Controls.mouse_aim)
	PadInput.mouse_button(MOUSE_BUTTON_LEFT)
	assert_true(Controls.mouse_aim)
	assert_false(Controls.using_joypad)

func test_the_wheel_is_not_aiming() -> void:
	Controls.using_joypad = true
	PadInput.mouse_button(MOUSE_BUTTON_WHEEL_UP)
	PadInput.mouse_button(MOUSE_BUTTON_WHEEL_UP, false)
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)

func test_a_pad_button_or_push_hands_the_aim_back() -> void:
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.button(JOY_BUTTON_A)
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.axis(JOY_AXIS_LEFT_X, 0.8)
	assert_false(Controls.mouse_aim)

func test_a_vertical_aim_key_hands_it_back_but_a_movement_key_does_not() -> void:
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.key(KEY_A)  # move_left
	assert_true(Controls.mouse_aim, "running does not drop the mouse aim")
	PadInput.key(KEY_W)  # aim_up
	assert_false(Controls.mouse_aim)
	PadInput.mouse_move(Vector2(10, 0))
	assert_true(Controls.mouse_aim, "and a move after it aims again")
	PadInput.key(KEY_S)  # aim_down
	assert_false(Controls.mouse_aim)

func test_an_aim_key_pressed_while_paused_does_not_hand_the_aim_back() -> void:
	PadInput.mouse_move(Vector2(10, 0))
	get_tree().paused = true  # the skill screen: W/S navigate it and aim nothing
	PadInput.key(KEY_S)
	assert_true(Controls.mouse_aim)
	get_tree().paused = false

func test_the_mouse_buttons_and_the_left_hand_keys_are_bound() -> void:
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_true(InputMap.event_is_action(left, "active_1"))
	assert_true(InputMap.event_is_action(right, "active_2"))
	assert_false(InputMap.event_is_action(left, "active_2"))
	for pair in [["tackle", KEY_SHIFT], ["predate", KEY_F], ["inspect", KEY_R], ["active_3", KEY_Q], ["active_4", KEY_E]]:
		var keys := InputMap.action_get_events(pair[0]).filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
		assert_true(keys.has(pair[1]), pair[0])

func test_a_click_reaches_the_action_state() -> void:
	PadInput.mouse_button(MOUSE_BUTTON_LEFT)
	assert_true(Input.is_action_pressed("active_1"))
	PadInput.mouse_button(MOUSE_BUTTON_LEFT, false)
	assert_false(Input.is_action_pressed("active_1"))

func test_labels_follow_the_scheme() -> void:
	assert_eq(Controls.slot_labels(), ["U", "O", "H", "L"])
	assert_eq([Controls.eat_label(), Controls.inspect_label()], ["K", "I"])
	PadInput.mouse_move(Vector2(10, 0))
	assert_eq(Controls.slot_labels(), ["LMB", "RMB", "Q", "E"])
	assert_eq([Controls.eat_label(), Controls.inspect_label()], ["F", "R"])
	PadInput.button(JOY_BUTTON_A)
	assert_eq(Controls.slot_labels(), ["LB", "RB", "LT", "RT"])
	assert_eq([Controls.eat_label(), Controls.inspect_label()], ["B", "Y"])

func test_scheme_changed_fires_once_per_change() -> void:
	var count := [0]
	var cb := func() -> void: count[0] += 1
	Controls.scheme_changed.connect(cb)
	PadInput.mouse_move(Vector2(10, 0))
	assert_eq(count[0], 1)
	PadInput.mouse_move(Vector2(10, 0))
	assert_eq(count[0], 1, "the labels did not change")
	PadInput.button(JOY_BUTTON_A)
	assert_eq(count[0], 2)
	Controls.scheme_changed.disconnect(cb)
