class_name EditorReturn
extends Node
## F5 during an editor Play returns to the editor. It runs while the tree is paused (the skill screen pauses it), ignores key
## repeats, and does nothing under the death card (the run is already returning).

var game: Game

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F5 or game == null:
		return
	if game.run != null and game.run.death_card_visible():
		return
	get_viewport().set_input_as_handled()
	game.return_to_editor()
