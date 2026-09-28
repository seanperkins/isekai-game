extends Node
## Registers input actions at startup so project.godot stays readable. Idempotent.

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"tackle": [KEY_J],
	"predate": [KEY_K],
	"inspect": [KEY_I],
	"active_1": [KEY_U],
	"active_2": [KEY_O],
	"cycle": [KEY_TAB],
}

func _ready() -> void:
	ensure_actions()

func ensure_actions() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
