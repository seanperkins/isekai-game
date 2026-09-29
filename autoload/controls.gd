extends Node
## Registers input actions at startup so project.godot stays readable. Idempotent.
## Keyboard and gamepad (Xbox layout names; PlayStation/Switch pads map to the same
## positions) are bound side by side. The last device used is the scheme: it picks the HUD labels
## and decides whether the right stick aims (see using_joypad and right_stick()).

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
	"active_3": [KEY_H],
	"active_4": [KEY_L],
	"debug_input": [KEY_F3],
	"menu": [KEY_ESCAPE],
	"tab_prev": [KEY_Q],
	"tab_next": [KEY_E],
	"fullscreen": [KEY_F11],
	"menu_accept": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
	"menu_back": [KEY_BACKSPACE],
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
	"aim_up": [JOY_BUTTON_DPAD_UP],
	"aim_down": [JOY_BUTTON_DPAD_DOWN],
	"debug_input": [JOY_BUTTON_BACK],
	"menu": [JOY_BUTTON_START],
	"tab_prev": [JOY_BUTTON_LEFT_SHOULDER],
	"tab_next": [JOY_BUTTON_RIGHT_SHOULDER],
	"menu_accept": [JOY_BUTTON_A],
	"menu_back": [JOY_BUTTON_B],
}

## Left stick direction per action: [axis, sign].
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"aim_up": [JOY_AXIS_LEFT_Y, -1.0],
	"aim_down": [JOY_AXIS_LEFT_Y, 1.0],
	"active_3": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"active_4": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

## Triggers are analog too; half-pull counts as a press.
const TRIGGER_DEADZONE := 0.5
const TRIGGER_ACTIONS := ["active_3", "active_4"]

## Also the threshold a right-stick push must pass to make its pad the aiming pad (aim_device).
const STICK_DEADZONE := 0.25
## The right stick aims only past this length: a resting stick at (0.25, 0.25), the action deadzone on each axis, is 0.354.
const RIGHT_STICK_DEADZONE := 0.45
const KEY_SLOT_LABELS := ["U", "O", "H", "L"]
const PAD_SLOT_LABELS := ["LB", "RB", "LT", "RT"]

## True while the last input was the pad. It picks the HUD labels and hints, and it enables the right stick (right_stick()):
## a key press or a mouse click clears it, a pad button or a stick past STICK_DEADZONE sets it.
var using_joypad := false
## The pad whose right stick aims: the last to push it past STICK_DEADZONE (a quiet reading from another pad never
## takes it). -1 for none. The stick itself is polled in raw_right_stick(), never cached.
var aim_device := -1
## Last raw left-stick reading and controller name. last_stick also drives Player.raw_aim() (the left-stick aim, the puddle
## spread and the rope reel) and the skill screen's stick navigation; the pad name is for the input debug overlay.
var last_stick := Vector2.ZERO
var last_pad_name := ""
var last_device := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the skill screen pauses the tree; a paused Controls would miss every stick and key event
	ensure_actions()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		DisplayServer.window_set_mode(toggled_window_mode(DisplayServer.window_get_mode()))
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			last_stick.x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y:
			last_stick.y = event.axis_value
		elif (event.axis == JOY_AXIS_RIGHT_X or event.axis == JOY_AXIS_RIGHT_Y) and absf(event.axis_value) > STICK_DEADZONE:
			aim_device = event.device
		last_device = event.device
		last_pad_name = Input.get_joy_name(event.device)
	if event is InputEventJoypadButton and event.pressed:
		using_joypad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > STICK_DEADZONE:
		using_joypad = true
	elif (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		using_joypad = false

## The right stick of the pad that owns it, raw and ungated (the debug overlay shows it). ZERO with no owner.
func raw_right_stick() -> Vector2:
	if aim_device < 0:
		return Vector2.ZERO
	return Vector2(Input.get_joy_axis(aim_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(aim_device, JOY_AXIS_RIGHT_Y))

## The right stick as an aim: ZERO unless the last input was the pad and it is pushed past the deadzone. Polled, so a pause
## and two pads at once are the engine's own per-device state; the deadzone is what protects against drift.
func right_stick() -> Vector2:
	if not using_joypad or aim_device < 0:
		return Vector2.ZERO
	var v := raw_right_stick()
	return v if v.length() >= RIGHT_STICK_DEADZONE else Vector2.ZERO

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == aim_device:
		aim_device = -1

## F11: fullscreen goes back to a window; anything else goes fullscreen.
static func toggled_window_mode(mode: DisplayServer.WindowMode) -> DisplayServer.WindowMode:
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return DisplayServer.WINDOW_MODE_WINDOWED
	return DisplayServer.WINDOW_MODE_FULLSCREEN

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
			InputMap.action_set_deadzone(action, TRIGGER_DEADZONE if TRIGGER_ACTIONS.has(action) else STICK_DEADZONE)

func _add(action: String, ev: InputEvent) -> void:
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
