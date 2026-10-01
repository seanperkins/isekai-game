class_name RoomEditor
extends Node
## The room editor scene root: a RoomView, the EditorPanels, the right-hand EditorSlot and the wiring between them and the
## RoomEditModel. Cmd/Ctrl+Z undoes, Shift+Cmd/Ctrl+Z redoes, Cmd/Ctrl+S saves (also while typing), F5 plays from the pointer (the
## Play button asks for a click), Tab hides every panel.

## What the Wall Cling toggle gives an editor Play: the slime starts with both movement skills, as after the first two caves.
const CAVE_MOVEMENT_KIT := {"skills": ["leap", "wall_cling"]}

## Tests inject a root; "" means HOME from the environment (the launcher sets it to .tmp/editor-home).
static var sandbox_root := ""

var model: RoomEditModel
var room_id := ""
var view_state := {}
var view: RoomView
var panels: EditorPanels
var slot: EditorSlot
var world: WorldView
## The two Play toggles; they ride in Game.editor_resume so a Play round trip keeps them.
var play_options := {"movement": false, "shortcuts": false}
var save_dir := "res://data/rooms"
var _choosing_spot := false
var _previous_room := ""  # the room you were in before the current one, for when the current one is undone away
var _slot_sel := {}       # the selection the inspector was built for: it is rebuilt when this changes, not on every edit

func _ready() -> void:
	var resume = Game.editor_resume
	Game.editor_resume = null
	if resume != null:
		model = resume["model"]
		room_id = resume["room"]
		view_state = resume["view"]
		play_options = resume.get("play_options", play_options)
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
	slot = EditorSlot.new()
	panels.add_slot(slot)
	world = WorldView.new()  # added after the slot, so it covers the palettes and the slot while it shows
	panels.add_slot(world)
	world.room_chosen.connect(func(id: String) -> void:
		world.visible = false
		open_room(id))
	panels.set_play_options(bool(play_options["movement"]), bool(play_options["shortcuts"]))
	view.changed.connect(_sync)
	view.selection_changed.connect(_sync)
	view.message.connect(panels.set_status)
	slot.problem_clicked.connect(land_on)
	slot.field_error.connect(panels.set_status)
	slot.field_changed.connect(view.refresh)
	panels.tool_chosen.connect(func(t: String) -> void: view.tool = t)
	panels.creature_chosen.connect(func(id: String) -> void: view.creature_id = id)
	panels.feature_chosen.connect(func(kind: String) -> void: view.feature_kind = kind)
	panels.decor_chosen.connect(func(id: String) -> void: view.decor_id = id)
	_refresh_decor_palette()
	panels.room_chosen.connect(open_room)
	panels.undo_pressed.connect(undo)
	panels.redo_pressed.connect(redo)
	panels.fit_pressed.connect(_refit)
	panels.one_to_one_pressed.connect(view.one_to_one)
	panels.validate_pressed.connect(_toggle_validation)
	panels.world_pressed.connect(_toggle_world)
	panels.grow_requested.connect(grow)
	panels.movement_toggled.connect(func(on: bool) -> void: _set_play_option("movement", on))
	panels.shortcuts_toggled.connect(func(on: bool) -> void: _set_play_option("shortcuts", on))
	panels.save_pressed.connect(save)
	panels.play_pressed.connect(_ask_for_spot)
	panels.new_room_requested.connect(new_room)
	if view_state.is_empty():
		_refit()
	_sync()
	panels.set_status("Cmd/Ctrl+Z undo, Cmd/Ctrl+S save, F5 play from the pointer, Tab hides the panels, Validate (N) lists the problems")

## A click in the room, a button or a shortcut is the end of any inspector edit: releasing focus commits a pending LineEdit first
## (before the room changes under it, or the model is saved, undone or played).
func _commit_pending() -> void:
	get_viewport().gui_release_focus()

## The screen area the panels leave open: below the toolbar, above the status bar, beside a palette when one shows, and always
## clear of the right-hand slot's column, so the room does not jump when a selection opens the slot over it. With the panels
## hidden (Tab) it is the whole window.
func _free_rect() -> Rect2:
	if not panels.panels_visible():
		return Rect2(0.0, 0.0, 640.0, 360.0)
	var left := 92.0 if panels.palette_visible() or panels.feature_palette_visible() or panels.decor_palette_visible() else 0.0
	return Rect2(left, 48.0, 640.0 - left - 168.0, 296.0)

func _refit() -> void:
	view.fit_in(_free_rect())

func _set_play_option(key: String, on: bool) -> void:
	_commit_pending()
	play_options[key] = on

func _toggle_world() -> void:
	_commit_pending()
	if world.visible:
		world.visible = false
	else:
		world.setup(model.rooms, room_id)
		world.visible = true

func _toggle_validation() -> void:
	_commit_pending()
	if slot.is_showing() == "problems":
		slot.hide_slot()
		_slot_sel = {}
		_sync_slot()
	else:
		slot.show_problems(model.problems())

func _sync() -> void:
	panels.set_rooms(model.rooms.keys(), model.dirty)
	panels.select_room(room_id)
	panels.set_problem_count(model.problems().size())
	_sync_slot()
	if world.visible:
		world.setup(model.rooms, room_id)
	get_window().title = "Room editor - %s%s" % [room_id, " *" if model.dirty.has(room_id) else ""]

## The slot shows the problems list while it is open (refreshed on every edit), else the inspector for an exit or a feature, else
## nothing. The inspector is rebuilt only when the selection changes, never under a field being typed in (an undo or redo clears
## the selection, so the inspector closes rather than showing stale values).
func _sync_slot() -> void:
	if slot.is_showing() == "problems":
		slot.show_problems(model.problems())
		return
	if _inspectable(model.selection):
		if slot.is_showing() != "inspector" or model.selection != _slot_sel:
			_slot_sel = model.selection.duplicate()
			slot.show_inspector(model, model.selection)
		else:
			slot.refresh_inspector()
	else:
		_slot_sel = {}
		slot.hide_slot()

func _inspectable(sel: Dictionary) -> bool:
	if sel.is_empty() or sel["room"] != room_id or not model.rooms.has(room_id):
		return false
	var r: RoomDef = model.rooms[room_id]
	match sel["kind"]:
		"exit":
			return sel["index"] < r.exits.size()
		"feature":
			return sel["index"] < r.features.size()
		"solid":
			return sel["index"] < r.solids.size()
	return false

## Opens the problem's room, selects the element it points at and centres the view on it.
func land_on(problem: Dictionary) -> void:
	_commit_pending()
	var room: String = problem["room"]
	if room != "" and model.rooms.has(room):
		open_room(room)
	var pick: Dictionary = problem["pick"]
	if pick.is_empty() or not model.rooms.has(pick["room"]):
		return
	model.select(pick)
	view.refresh()
	var rect := view.selection_rect()
	if rect.size != Vector2.ZERO:
		view.center_on(rect, _free_rect())

## Grows the current room by a screen on `side` ("left", "right" or "top"); a refusal goes to the status bar.
func grow(side: String) -> void:
	_commit_pending()
	var err := model.grow_room(room_id, side)
	if err != "":
		panels.set_status(err)
		return
	view.refresh()
	_refit()
	panels.set_status("grew %s by a screen on the %s" % [room_id, side])

func open_room(id: String) -> void:
	_commit_pending()
	if id != room_id:
		_previous_room = room_id
	room_id = id
	model.select({})
	view.show_room(model, id)
	_refresh_decor_palette()
	_refit()
	_sync()

## The Decor tool's palette is the current room's biome's decor.
func _refresh_decor_palette() -> void:
	panels.set_decor_ids(DecorLib.ids_for_biome(model.rooms[room_id].area))

func undo() -> void:
	_commit_pending()
	if model.undo():
		_after_history()

func redo() -> void:
	_commit_pending()
	if model.redo():
		_after_history()

## An undo or redo can remove the room being edited (undoing a new room): go back to where you came from.
func _after_history() -> void:
	if model.rooms.has(room_id):
		view.refresh()
		_sync()
		return
	var ids := model.rooms.keys()
	ids.sort()
	open_room(_previous_room if model.rooms.has(_previous_room) else ids[0])

## Creates a room beside the current one and opens it; a refusal goes to the status bar.
func new_room(edge: String, id: String, area: String, size: Vector2i) -> void:
	_commit_pending()
	var err := model.new_room_beside(room_id, edge, id, area, size)
	if err != "":
		panels.set_status(err)
		return
	open_room(id)
	panels.set_status("created %s beside %s" % [id, room_id])

func save() -> void:
	_commit_pending()
	var result := model.save_dirty(save_dir)
	var n: int = result["saved"].size()
	var text := "saved %d room%s" % [n, "" if n == 1 else "s"]
	for id in result["removed"]:
		text += "; removed the undone room %s" % id
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
	if _spot(pos) == null:
		return "click open floor: the slime needs somewhere to stand"
	return ""

## Where Play puts the slime for a click at `pos`: with Open shortcuts the closed gates are holes, not floor. Both play_error and
## play go through here, so they agree.
func _spot(pos: Vector2) -> Variant:
	return model.floor_spot(room_id, pos, not bool(play_options["shortcuts"]))

## Starts the real game in this room at the floor below `pos`, on the unsaved rooms; F5 or a death brings the editor back.
func play(pos: Vector2) -> void:
	_commit_pending()
	var err := play_error(pos)
	if err != "":
		panels.set_status(err)
		return
	Game.play_request = {"rooms": model.rooms, "room": room_id, "pos": _spot(pos),
		"kit": CAVE_MOVEMENT_KIT if play_options["movement"] else {}, "open_shortcuts": play_options["shortcuts"]}
	Game.editor_resume = {"model": model, "room": room_id, "view": view.state(), "play_options": play_options}
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _ask_for_spot() -> void:
	_commit_pending()
	_choosing_spot = true
	panels.set_status("click where the slime should start (F5 plays from the pointer)")

# --- input ---

func _unhandled_input(event: InputEvent) -> void:
	if _choosing_spot and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choosing_spot = false
		_commit_pending()
		play(view.to_room((event as InputEventMouseButton).position))
		get_viewport().set_input_as_handled()
		return
	if world.visible:
		return  # the overview covers the room: Delete, the wheel and F5 must not reach what it hides
	if view.handle_event(event):
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var cmd := key.ctrl_pressed or key.meta_pressed  # Cmd on a Mac, Ctrl elsewhere: either works
	if panels.typing() and not (cmd and key.keycode == KEY_S):
		return  # typing owns the keys, except that Cmd/Ctrl+S still saves
	if key.keycode == KEY_TAB:
		panels.toggle_panels()
	elif key.keycode == KEY_ESCAPE and world.visible:
		world.visible = false
	elif cmd and key.keycode == KEY_Z:
		if key.shift_pressed:
			redo()
		else:
			undo()
	elif cmd and key.keycode == KEY_S:
		save()
	elif key.keycode == KEY_F5 and not world.visible:
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
