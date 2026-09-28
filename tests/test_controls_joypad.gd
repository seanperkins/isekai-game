extends GutTest
## Gamepad bindings (Xbox layout names; PlayStation/Switch pads map to the same positions).

func after_each() -> void:
	_axis(JOY_AXIS_LEFT_X, 0.0)
	Controls.using_joypad = false

func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _has_button(action: String, button: JoyButton) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return true
	return false

func test_every_action_has_a_gamepad_binding() -> void:
	var expected := {"jump": JOY_BUTTON_A, "tackle": JOY_BUTTON_X, "predate": JOY_BUTTON_B,
		"inspect": JOY_BUTTON_Y, "active_1": JOY_BUTTON_LEFT_SHOULDER,
		"active_2": JOY_BUTTON_RIGHT_SHOULDER, "cycle": JOY_BUTTON_DPAD_UP,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT}
	for action in expected:
		assert_true(_has_button(action, expected[action]), action)

func test_left_stick_moves_with_a_deadzone() -> void:
	_axis(JOY_AXIS_LEFT_X, -0.8)
	assert_true(Input.is_action_pressed("move_left"))
	assert_false(Input.is_action_pressed("move_right"))
	assert_lt(Input.get_axis("move_left", "move_right"), -0.5)
	_axis(JOY_AXIS_LEFT_X, 0.15)  # inside the deadzone
	assert_eq(Input.get_axis("move_left", "move_right"), 0.0)

func test_binding_is_idempotent() -> void:
	var before := InputMap.action_get_events("jump").size()
	Controls.ensure_actions()
	assert_eq(InputMap.action_get_events("jump").size(), before)

func test_slot_labels_follow_the_last_device_used() -> void:
	assert_eq(Controls.slot_labels(), ["U", "O"])
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	Controls._input(pad)
	assert_eq(Controls.slot_labels(), ["LB", "RB"])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	Controls._input(key)
	assert_eq(Controls.slot_labels(), ["U", "O"])

func test_tiny_stick_drift_does_not_switch_to_gamepad_labels() -> void:
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.1
	Controls._input(drift)
	assert_false(Controls.using_joypad)

func test_slot_line_uses_the_given_labels() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup([])
	assert_eq(StatusText.slot_line(ActiveSlots.new(), rules, ["LB", "RB"]), "[LB] —   [RB] —")
