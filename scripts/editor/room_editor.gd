class_name RoomEditor
extends Node
## The room editor scene root: a RoomView, the EditorPanels and the wiring between them and the RoomEditModel. Cmd/Ctrl+Z undoes,
## Shift+Cmd/Ctrl+Z redoes, Cmd/Ctrl+S saves, F5 plays from the pointer (the Play button asks for a click).

## Tests inject a root; "" means HOME from the environment (the launcher sets it to .tmp/editor-home).
static var sandbox_root := ""

var model: RoomEditModel
var room_id := ""
var view_state := {}
var view: RoomView
var panels: EditorPanels
var save_dir := "res://data/rooms"
var _choosing_spot := false

func _ready() -> void:
	var resume = Game.editor_resume
	Game.editor_resume = null
	if resume != null:
		model = resume["model"]
		room_id = resume["room"]
		view_state = resume["view"]
	else:
		var ids: Array = SkillRules.creature_defs.map(func(c: CreatureDef) -> String: return c.id)
		model = RoomEditModel.new(World.load_rooms(save_dir), ids)
		room_id = "C1"
	view = RoomView.new()
	add_child(view)
	view.show_room(model, room_id)
	if not view_state.is_empty():
		view.restore(view_state)
	panels = EditorPanels.new()
	add_child(panels)
	panels.setup(model)
	view.changed.connect(_sync)
	view.selection_changed.connect(_sync_status)
	view.message.connect(panels.set_status)
	panels.tool_chosen.connect(func(t: String) -> void: view.tool = t)
	panels.creature_chosen.connect(func(id: String) -> void: view.creature_id = id)
	panels.room_chosen.connect(open_room)
	panels.undo_pressed.connect(undo)
	panels.redo_pressed.connect(redo)
	panels.fit_pressed.connect(view.fit)
	panels.one_to_one_pressed.connect(view.one_to_one)
	panels.validate_pressed.connect(func() -> void: panels.show_validation(model.validate()))
	panels.save_pressed.connect(save)
	panels.play_pressed.connect(_ask_for_spot)
	panels.new_room_requested.connect(new_room)
	_sync()
	panels.set_status("Cmd/Ctrl+Z undo, Cmd/Ctrl+S save, F5 play from the pointer")

func _sync() -> void:
	panels.set_rooms(model.rooms.keys(), model.dirty)
	panels.select_room(room_id)
	get_window().title = "Room editor - %s%s" % [room_id, " *" if model.dirty.has(room_id) else ""]

func _sync_status() -> void:
	pass

func open_room(id: String) -> void:
	room_id = id
	model.select({})
	view.show_room(model, id)
	_sync()

func undo() -> void:
	if model.undo():
		view.refresh()
		_sync()

func redo() -> void:
	if model.redo():
		view.refresh()
		_sync()

## Creates a room beside the current one and opens it; a refusal goes to the status bar.
func new_room(edge: String, id: String, area: String, size: Vector2i) -> void:
	var err := model.new_room_beside(room_id, edge, id, area, size)
	if err != "":
		panels.set_status(err)
		return
	open_room(id)
	panels.set_status("created %s beside %s" % [id, room_id])

func save() -> void:
	var result := model.save_dirty(save_dir)
	var n: int = result["saved"].size()
	var text := "saved %d room%s" % [n, "" if n == 1 else "s"]
	for id in result["errors"]:
		text += "; %s: %s" % [id, result["errors"][id]]
	panels.set_status(text)
	_sync()

# --- Play ---

## "" when Play may start from room point `pos`, else the reason it may not.
func play_error(pos: Vector2) -> String:
	if not RoomEditor.sandbox_ok():
		return "launch the editor with tools/edit_rooms.sh so Play cannot touch your save"
	for id in model.rooms:
		for e in (model.rooms[id] as RoomDef).exits:
			if not model.rooms.has(e.get("room", "")):
				return "an exit in %s points at an unknown room: fix it (Validate lists it)" % id
	if model.floor_spot(room_id, pos) == null:
		return "click open floor: the slime needs somewhere to stand"
	return ""

## Starts the real game in this room at the floor below `pos`, on the unsaved rooms; F5 or a death brings the editor back.
func play(pos: Vector2) -> void:
	var err := play_error(pos)
	if err != "":
		panels.set_status(err)
		return
	Game.play_request = {"rooms": model.rooms, "room": room_id, "pos": model.floor_spot(room_id, pos)}
	Game.editor_resume = {"model": model, "room": room_id, "view": view.state()}
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _ask_for_spot() -> void:
	_choosing_spot = true
	panels.set_status("click where the slime should start (F5 plays from the pointer)")

# --- input ---

func _unhandled_input(event: InputEvent) -> void:
	if _choosing_spot and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choosing_spot = false
		play(view.to_room((event as InputEventMouseButton).position))
		get_viewport().set_input_as_handled()
		return
	if view.handle_event(event):
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or panels.typing():
		return
	var cmd := key.ctrl_pressed or key.meta_pressed  # Cmd on a Mac, Ctrl elsewhere: either works
	if cmd and key.keycode == KEY_Z:
		if key.shift_pressed:
			redo()
		else:
			undo()
	elif cmd and key.keycode == KEY_S:
		save()
	elif key.keycode == KEY_F5:
		var p := view.to_room(get_viewport().get_mouse_position())
		if not RoomEditModel.bounds(model.rooms[room_id]).has_point(p):
			p = view.to_room(Vector2(320, 180))
		play(p)
	else:
		return
	get_viewport().set_input_as_handled()

## Is `user_dir` (OS.get_user_data_dir()) inside `root`? A trailing-slash prefix test, so `editor-home2` is not inside
## `editor-home`.
static func in_sandbox(user_dir: String, root: String) -> bool:
	if root == "":
		return false
	var r := root.trim_suffix("/")
	var u := user_dir.trim_suffix("/")
	return u == r or u.begins_with(r + "/")

## True when the editor was launched through tools/edit_rooms.sh (its HOME is `.tmp/editor-home`), so user:// is a throwaway
## directory and Play cannot write the real profile. An injected `sandbox_root` is trusted (tests).
static func sandbox_ok() -> bool:
	if sandbox_root != "":
		return in_sandbox(OS.get_user_data_dir(), sandbox_root)
	var home := OS.get_environment("HOME")
	return home.ends_with("/.tmp/editor-home") and in_sandbox(OS.get_user_data_dir(), home)
