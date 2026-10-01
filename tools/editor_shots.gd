extends SceneTree
## Real-renderer shots of the room editor and of a room played from it. Run from the project root (windowed, unsandboxed):
##   env HOME="$PWD/.tmp/editor-home" godot --path . -s res://tools/editor_shots.gd
## Writes .tmp/editor/*.png: C1 fitted, C2 edited (a solid, a toad) at 1:1, a Solid drag in progress with its live label, the
## Creature palette, the Validate list, a placed tablet with its inspector, the problems list with findings, G1's pool with the
## kit checklist, the World overview, a new `deep` room dressed with decor (the Decor tool, a ledge's panel) and a `flooded` one on the
## overview, and C6 played from the editor with Wall Cling granted and every shortcut open.

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
			# a new room in each new biome beside C6, dressed with that biome's decor
			ed.open_room("C6")
			ed.new_room("left", "DeepA", "deep", Vector2i(1, 1))
		86:
			ed.model.add_solid("DeepA", Vector2(240, 220), Vector2(360, 232))  # a ledge
			ed.model.add_decor("DeepA", "deep_glow_fungus", Vector2(200, 100))  # stands on the floor
			ed.model.add_decor("DeepA", "deep_bones", Vector2(450, 100))
			ed.model.add_decor("DeepA", "deep_lichen_hang", Vector2(300, 150))  # hangs from the ceiling
			ed.model.add_decor("DeepA", "deep_wall_crystal", Vector2(260, 100))  # stands on the ledge
			ed.view.refresh()
			ed.panels.press("Decor")
		92:
			_shot("editor_decor_deep")
			ed.panels.press("Select")
			ed.model.select({"room": "DeepA", "kind": "solid", "index": ed.model.rooms["DeepA"].solids.size() - 1})
			ed.view.refresh()
		98:
			_shot("editor_solid_panel")
			ed.new_room("left", "FloodA", "flooded", Vector2i(1, 1))
		104:
			ed.model.add_decor("FloodA", "flooded_crystal_gold", Vector2(300, 100))
			ed.model.add_decor("FloodA", "flooded_root_hang", Vector2(450, 150))
			ed.view.refresh()
			ed.panels.press("World")
		110:
			_shot("editor_world_new_biomes")
			ed.panels.press("World")
			ed.open_room("F2")  # the Flooded's rooms carry water: the room view draws it
		113:
			_shot("editor_water_f2")
			ed.open_room("F3")
		116:
			_shot("editor_water_f3")
			ed.open_room("F5")
			ed.model.select({"room": "F5", "kind": "water", "index": 0})  # the Water tool's inspector: its four numbers
			ed.view.refresh()
		118:
			_shot("editor_water_inspector")
			ed.open_room("C6")
			ed.model.add_solid("C6", Vector2(200, 200), Vector2(280, 216))
			ed.view.refresh()
			ed.panels.press("Wall Cling")
			ed.panels.press("Open shortcuts")
		120:
			_shot("editor_c6_toggles")
			ed.get_script().set("sandbox_root", OS.get_user_data_dir())  # naming RoomEditor here would compile it before the autoloads exist
			ed.play(Vector2(120, 250))
			ed.queue_free()
		220:
			_shot("play_c6_cling")
			quit()
	return false
