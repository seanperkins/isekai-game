class_name PadInput
extends RefCounted
## Pad, key and mouse input for tests. Every event goes through the engine's Input and nothing else: the engine delivers it
## to Controls._input itself (and updates get_joy_axis and the action state), so calling _input by hand too would deliver
## it twice. reset() puts all of it back.

static func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

static func axis(axis_index: int, value: float, device := 0) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis_index as JoyAxis
	ev.axis_value = value
	_send(ev)

static func key(keycode: int) -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.pressed = pressed
		k.keycode = keycode as Key
		k.physical_keycode = keycode as Key  # the InputMap's bindings are physical keys, so is_action_pressed matches
		_send(k)

static func button(index: int, device := 0) -> void:
	for pressed in [true, false]:
		var b := InputEventJoypadButton.new()
		b.device = device
		b.button_index = index as JoyButton
		b.pressed = pressed
		_send(b)

## `relative` in game px. The root viewport divides an event's relative by its stretch scale on the way to _input, so this
## applies that scale first (headless, the root is not 640x360).
static func mouse_move(relative: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = (Engine.get_main_loop() as SceneTree).root.get_final_transform().basis_xform(relative)
	_send(m)

static func mouse_button(index: int, pressed := true) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = index as MouseButton
	b.pressed = pressed
	_send(b)

static func reset() -> void:
	for dev in [0, 1]:
		for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			axis(a, 0.0, dev)
	mouse_button(MOUSE_BUTTON_LEFT, false)
	mouse_button(MOUSE_BUTTON_RIGHT, false)
	Controls.aim_device = -1
	Controls.last_device = -1
	Controls.last_stick = Vector2.ZERO
	Controls.using_joypad = false
	Controls.mouse_aim = false
	Controls._mouse_travel = 0.0
	for a in ["aim_up", "aim_down", "move_left", "move_right", "active_1", "active_2", "active_3", "active_4"]:
		Input.action_release(a)
