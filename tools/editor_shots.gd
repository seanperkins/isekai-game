extends SceneTree
## Real-renderer shots of the room editor and of a room played from it. Run from the project root (windowed, unsandboxed):
##   env HOME="$PWD/.tmp/editor-home" godot --path . -s res://tools/editor_shots.gd
## Writes .tmp/editor/*.png: C1 fitted, C2 edited (a solid, a toad) at 1:1, a Solid drag in progress with its live label, the
## Creature palette, the Validate list, a placed tablet with its inspector, the problems list with findings, G1's pool with the
## kit checklist, the World overview, and C6 played from the editor with Wall Cling granted and every shortcut open.

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
		30:
			# a real click on the first palette entry (a FOCUS_NONE ItemList must still select): the log line below says if it did
			for pressed in [true, false]:
				var b := InputEventMouseButton.new()
				b.button_index = MOUSE_BUTTON_LEFT
				b.pressed = pressed
				b.position = Vector2(20, 62)
				root.push_input(b, true)
		32:
			print("PALETTE_CLICK creature_id=", ed.view.creature_id)
		34:
			_shot("editor_palette")
			ed.panels.press("Validate")
		40:
			_shot("editor_validate")
			ed.panels.press("Select")
			ed.panels.press("Fit room")  # the real path: fits beside the slot column
		46:
			_shot("editor_c2_fit")
			ed.panels.press("Validate")  # close the list
			ed.panels.press("Feature")
			ed.model.add_feature("C2", "tablet", Vector2(300, 100))
			var sel: Dictionary = ed.model.selection
			ed.model.set_field(sel, "title", "Moss tablet")
			ed.model.set_field(sel, "text", "Eat what hunts by sound in the dark.")
			ed.view.refresh()
		56:
			_shot("editor_feature_inspector")
			ed.model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
			ed.model.add_solid("C2", Vector2(100, 60), Vector2(160, 76))
			ed.view.refresh()
			ed.panels.press("Select")
			ed.panels.press("Validate")
		66:
			_shot("editor_problems")
			ed.panels.press("Validate")  # close it
			ed.open_room("G1")
			for i in ed.model.rooms["G1"].features.size():
				if ed.model.rooms["G1"].features[i]["kind"] == "rebirth_pool":
					ed.model.select({"room": "G1", "kind": "feature", "index": i})
			ed.view.refresh()
		76:
			_shot("editor_pool_kit")
			ed.panels.press("World")
		80:
			_shot("editor_world")
			ed.panels.press("World")  # close it
			ed.open_room("C6")
			ed.model.add_solid("C6", Vector2(200, 200), Vector2(280, 216))
			ed.view.refresh()
			ed.panels.press("Wall Cling")
			ed.panels.press("Open shortcuts")
		90:
			_shot("editor_c6_toggles")
			ed.get_script().set("sandbox_root", OS.get_user_data_dir())  # naming RoomEditor here would compile it before the autoloads exist
			ed.play(Vector2(120, 250))
			ed.queue_free()
		190:
			_shot("play_c6_cling")
			quit()
	return false
