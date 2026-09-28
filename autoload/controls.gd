extends Node
## Registers input actions at startup so project.godot stays readable. Idempotent.
## Keyboard and gamepad (Xbox layout names; PlayStation/Switch pads map to the same
## positions) are bound side by side, and the last device used picks the HUD labels.

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"aim_up": [KEY_W, KEY_UP],
	"aim_down": [KEY_S, KEY_DOWN],
	"tackle": [KEY_J],
	"predate": [KEY_K],
	"inspect": [KEY_I],
	"active_1": [KEY_U],
	"active_2": [KEY_O],
	"cycle": [KEY_TAB],
	"menu": [KEY_ESCAPE],
	"tab_prev": [KEY_Q],
	"tab_next": [KEY_E],
}

const PAD_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A],
	"tackle": [JOY_BUTTON_X],
	"predate": [JOY_BUTTON_B],
	"inspect": [JOY_BUTTON_Y],
	"active_1": [JOY_BUTTON_LEFT_SHOULDER],
	"active_2": [JOY_BUTTON_RIGHT_SHOULDER],
	"cycle": [JOY_BUTTON_DPAD_UP],
	"menu": [JOY_BUTTON_START],
	"tab_prev": [JOY_BUTTON_LEFT_SHOULDER],
	"tab_next": [JOY_BUTTON_RIGHT_SHOULDER],
}

## Left stick direction per action: [axis, sign].
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"aim_up": [JOY_AXIS_LEFT_Y, -1.0],
	"aim_down": [JOY_AXIS_LEFT_Y, 1.0],
}

const STICK_DEADZONE := 0.25
const KEY_SLOT_LABELS := ["U", "O"]
const PAD_SLOT_LABELS := ["LB", "RB"]

var using_joypad := false

func _ready() -> void:
	ensure_actions()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		using_joypad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > STICK_DEADZONE:
		using_joypad = true
	elif (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		using_joypad = false

## Button names for the two active slots, matching the device the player last used.
func slot_labels() -> Array:
	return PAD_SLOT_LABELS if using_joypad else KEY_SLOT_LABELS

func ensure_actions() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			_add(action, ev)
		for button in PAD_BUTTONS.get(action, []):
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			pad.device = -1  # any controller
			_add(action, pad)
		if PAD_AXES.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = PAD_AXES[action][0]
			motion.axis_value = PAD_AXES[action][1]
			motion.device = -1
			_add(action, motion)
			InputMap.action_set_deadzone(action, STICK_DEADZONE)

func _add(action: String, ev: InputEvent) -> void:
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
