extends GutTest
## The right stick is polled per device, owned by the last pad to push it past 0.25, ignored once a key was the last input,
## and still seen while the tree is paused.

func after_each() -> void:
	PadInput.reset()
	get_tree().paused = false

func test_controls_keeps_processing_while_the_tree_is_paused() -> void:
	get_tree().paused = true
	assert_true(Controls.can_process(), "the skill screen pauses the tree; a paused Controls would miss every stick event")
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.8)  # sent while paused: only an ALWAYS Controls sees it
	assert_eq(Controls.aim_device, 0)

func test_a_push_past_the_action_deadzone_makes_that_pad_the_owner_and_reads_back() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.8)
	PadInput.axis(JOY_AXIS_RIGHT_Y, -0.6)
	assert_eq(Controls.aim_device, 0)
	assert_true(Controls.right_stick().is_equal_approx(Vector2(0.8, -0.6)))

func test_nothing_pushed_reads_zero() -> void:
	assert_eq(Controls.right_stick(), Vector2.ZERO)

func test_a_pad_button_with_no_right_stick_push_reads_zero() -> void:
	PadInput.button(JOY_BUTTON_A)
	assert_true(Controls.using_joypad)
	assert_eq(Controls.aim_device, -1)
	assert_eq(Controls.right_stick(), Vector2.ZERO)

func test_a_resting_diagonal_under_the_right_stick_deadzone_reads_zero() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.3)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.3)  # length 0.424, under 0.45; each axis is past the 0.25 that makes it the owner
	assert_eq(Controls.aim_device, 0)
	assert_eq(Controls.right_stick(), Vector2.ZERO)
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.25)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.25)  # 0.354
	assert_eq(Controls.right_stick(), Vector2.ZERO)
	assert_true(Controls.raw_right_stick().is_equal_approx(Vector2(0.25, 0.25)), "the raw reading is ungated")

func test_a_quiet_reading_from_a_second_pad_does_not_take_the_stick() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.05, 1)
	assert_eq(Controls.aim_device, 0)
	assert_true(Controls.right_stick().is_equal_approx(Vector2(1.0, 0.0)))

func test_a_real_push_on_a_second_pad_takes_it_wholly() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.9, 1)
	assert_eq(Controls.aim_device, 1)
	assert_true(Controls.right_stick().is_equal_approx(Vector2(0.0, 0.9)), "pad 1's stick, not a mix with pad 0's")

func test_a_key_press_silences_it_and_a_later_push_engages_it_again() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	PadInput.key(KEY_A)
	assert_eq(Controls.right_stick(), Vector2.ZERO)
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.5)  # a pad that keeps emitting re-arms the gate itself: the documented limit
	assert_true(Controls.right_stick().is_equal_approx(Vector2(0.5, 0.0)))

func test_a_disconnect_resets_the_owner_even_with_the_stick_still_held() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	Controls._on_joy_connection_changed(1, false)
	assert_eq(Controls.aim_device, 0, "another pad leaving changes nothing")
	Controls._on_joy_connection_changed(0, true)
	assert_eq(Controls.aim_device, 0, "a connect changes nothing")
	Controls._on_joy_connection_changed(0, false)  # the engine's axis for device 0 is still 1.0
	assert_eq(Controls.aim_device, -1)
	assert_eq(Controls.right_stick(), Vector2.ZERO)
