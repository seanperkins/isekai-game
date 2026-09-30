extends SceneTree
## Real-renderer shots of the room editor and of a room played from it. Run from the project root (windowed, unsandboxed):
##   env HOME="$PWD/.tmp/editor-home" godot --path . -s res://tools/editor_shots.gd
## Writes .tmp/editor/*.png: C1 fitted, C2 edited (a solid, a toad) at 1:1, a Solid drag in progress with its live label, the
## Creature palette, the Validate list, and C2 played from the editor with the edit in it.

const OUT := "res://.tmp/editor/"
var ed
var frame := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, n]))

func _mouse(button: bool, pressed: bool, room_pt: Vector2) -> void:
	var v = ed.view
	if button:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = v.to_screen(room_pt)
		v.handle_event(e)
	else:
		var m := InputEventMouseMotion.new()
		m.position = v.to_screen(room_pt)
		v.handle_event(m)

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		2:
			# built here, not in _initialize: the autoloads the editor names exist only once the tree is running
			ed = load("res://scenes/room_editor.tscn").instantiate()
			root.add_child(ed)
		10:
			_shot("editor_c1")
		12:
			ed.open_room("C2")
			ed.model.add_solid("C2", Vector2(400, 150), Vector2(520, 166))
			ed.model.add_spawn("C2", "toad", Vector2(600, 250))
			ed.model.add_spawn("C2", "bat", Vector2(300, 120))
			ed.view.refresh()
			ed.view.one_to_one()
			ed.view.pan(Vector2(-200, 0))
		20:
			_shot("editor_c2_edited")
			ed.panels.press("Solid")
			_mouse(true, true, Vector2(700, 200))
			_mouse(false, false, Vector2(820, 216))
		24:
			_shot("editor_solid_drag_ledge")
			_mouse(false, false, Vector2(820, 260))
		28:
			_shot("editor_solid_drag_rock")
			_mouse(true, false, Vector2(820, 260))
			ed.panels.press("Creature")
		34:
			_shot("editor_palette")
			ed.panels.press("Validate")
		40:
			_shot("editor_validate")
			ed.panels.press("Select")
			ed.view.fit()
		46:
			_shot("editor_c2_fit")
			ed.get_script().set("sandbox_root", OS.get_user_data_dir())  # naming RoomEditor here would compile it before the autoloads exist
			ed.play(Vector2(520, 100))
			ed.queue_free()
		120:
			_shot("play_c2")
			quit()
	return false
