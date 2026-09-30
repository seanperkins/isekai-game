class_name EditorPanels
extends CanvasLayer
## The editor's controls, laid out in the 640x360 viewport: a toolbar across the top, the creature palette at the left (for the
## Creature tool), the Validate list at the right, a status bar at the bottom and the New room dialog. It only emits signals;
## RoomEditor does the work.

signal tool_chosen(tool_name: String)
signal creature_chosen(id: String)
signal room_chosen(id: String)
signal undo_pressed
signal redo_pressed
signal fit_pressed
signal one_to_one_pressed
signal validate_pressed
signal save_pressed
signal play_pressed
signal new_room_requested(edge: String, id: String, area: String, size: Vector2i)

const FONT := 8
const AREAS := ["cave", "grotto"]
const EDGES := ["left", "right", "top", "bottom"]
const TOOLS := ["Select", "Solid", "Creature", "Exit"]
const HOLE_NOTE := "A room above or below a neighbour cuts a hole in its ceiling or floor: it is connected but not walkable until you add ledges."

var _model: RoomEditModel
var _root := Control.new()
var _bar := HBoxContainer.new()
var _room_pick := OptionButton.new()
var _room_ids: Array = []
var _buttons := {}                  # label -> Button
var _palette := ItemList.new()
var _validation := ItemList.new()
var _status := Label.new()
var _status_message := ""
var _dialog := PanelContainer.new()
var _new_edge := OptionButton.new()
var _new_id := LineEdit.new()
var _new_area := OptionButton.new()
var _new_w := SpinBox.new()
var _new_h := SpinBox.new()
var _new_error := Label.new()
var _new_note := Label.new()

func _init() -> void:
	layer = 10

func setup(model: RoomEditModel) -> void:
	_model = model
	_root.size = Vector2(640, 360)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks outside the widgets reach the room
	add_child(_root)
	_build_bar()
	_build_palette()
	_build_validation()
	_build_status()
	_build_dialog()
	set_rooms(model.rooms.keys(), model.dirty)
	set_tool("select")
	set_status("")

func _small(c: Control) -> void:
	c.add_theme_font_size_override("font_size", FONT)

func _button(label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE  # so typing never lands on a button
	_small(b)
	b.pressed.connect(action)
	_bar.add_child(b)
	_buttons[label] = b
	return b

func _build_bar() -> void:
	var back := ColorRect.new()
	back.color = Color(0.08, 0.08, 0.12, 0.92)
	back.size = Vector2(640, 24)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(back)
	_bar.position = Vector2(2, 2)
	_bar.add_theme_constant_override("separation", 2)
	_root.add_child(_bar)
	_small(_room_pick)
	_room_pick.focus_mode = Control.FOCUS_NONE
	_room_pick.item_selected.connect(func(i: int) -> void: room_chosen.emit(_room_ids[i]))
	_bar.add_child(_room_pick)
	for t in TOOLS:
		var b := _button(t, func() -> void: set_tool(t.to_lower()); tool_chosen.emit(t.to_lower()))
		b.toggle_mode = true
	_button("Undo", func() -> void: undo_pressed.emit())
	_button("Redo", func() -> void: redo_pressed.emit())
	_button("Fit room", func() -> void: fit_pressed.emit())
	_button("1:1", func() -> void: one_to_one_pressed.emit())
	_button("Validate", func() -> void: validate_pressed.emit())
	_button("Save", func() -> void: save_pressed.emit())
	_button("Play", func() -> void: play_pressed.emit())
	_button("New room...", func() -> void: open_new_room("right"))

func _build_palette() -> void:
	_palette.position = Vector2(0, 26)
	_palette.size = Vector2(92, 300)
	_small(_palette)
	for id in _model.creature_ids:
		_palette.add_item(id)
	_palette.item_selected.connect(func(i: int) -> void: creature_chosen.emit(_palette.get_item_text(i)))
	_root.add_child(_palette)

func _build_validation() -> void:
	_validation.position = Vector2(400, 26)
	_validation.size = Vector2(240, 300)
	_validation.visible = false
	_small(_validation)
	_root.add_child(_validation)

func _build_status() -> void:
	var back := ColorRect.new()
	back.color = Color(0.08, 0.08, 0.12, 0.92)
	back.position = Vector2(0, 344)
	back.size = Vector2(640, 16)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	_status.position = Vector2(2, 345)
	_status.size = Vector2(636, 14)
	_status.clip_text = true
	_small(_status)
	_root.add_child(_status)

func _build_dialog() -> void:
	_dialog.position = Vector2(170, 90)
	_dialog.visible = false
	var box := VBoxContainer.new()
	_dialog.add_child(box)
	var title := Label.new()
	title.text = "New room beside the current room"
	_small(title)
	box.add_child(title)
	box.add_child(_row("Edge", _new_edge))
	for e in EDGES:
		_new_edge.add_item(e)
	_new_edge.item_selected.connect(func(_i: int) -> void: _refresh_dialog())
	box.add_child(_row("Id", _new_id))
	_new_id.custom_minimum_size = Vector2(120, 0)
	_new_id.text_changed.connect(func(_t: String) -> void: _refresh_dialog())
	box.add_child(_row("Area", _new_area))
	for a in AREAS:
		_new_area.add_item(a)
	_new_w.min_value = 1
	_new_w.max_value = RoomEditModel.MAX_SCREENS
	_new_w.value = 1
	_new_h.min_value = 1
	_new_h.max_value = RoomEditModel.MAX_SCREENS
	_new_h.value = 1
	box.add_child(_row("Screens wide", _new_w))
	box.add_child(_row("Screens high", _new_h))
	_new_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_note.custom_minimum_size = Vector2(230, 0)
	_small(_new_note)
	box.add_child(_new_note)
	_new_error.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	_small(_new_error)
	box.add_child(_new_error)
	var row := HBoxContainer.new()
	var create := Button.new()
	create.text = "Create"
	_small(create)
	create.pressed.connect(confirm_new_room)
	row.add_child(create)
	var cancel := Button.new()
	cancel.text = "Cancel"
	_small(cancel)
	cancel.pressed.connect(func() -> void: _dialog.visible = false)
	row.add_child(cancel)
	box.add_child(row)
	_buttons["Create"] = create
	_buttons["Cancel"] = cancel
	_root.add_child(_dialog)

func _row(label: String, field: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(76, 0)
	_small(l)
	row.add_child(l)
	_small(field)
	row.add_child(field)
	return row

# --- what RoomEditor drives ---

func set_rooms(ids: Array, dirty: Dictionary) -> void:
	var keep := ""
	if _room_pick.selected >= 0 and _room_pick.selected < _room_ids.size():
		keep = _room_ids[_room_pick.selected]
	_room_ids = ids.duplicate()
	_room_ids.sort()
	_room_pick.clear()
	for id in _room_ids:
		_room_pick.add_item("%s *" % id if dirty.has(id) else String(id))
	select_room(keep if keep != "" else (_room_ids[0] if not _room_ids.is_empty() else ""))

## Shows `id` as the current room without emitting room_chosen.
func select_room(id: String) -> void:
	var i := _room_ids.find(id)
	if i >= 0:
		_room_pick.select(i)

func set_tool(tool_name: String) -> void:
	for t in TOOLS:
		(_buttons[t] as Button).button_pressed = t.to_lower() == tool_name
	_palette.visible = tool_name == "creature"

func set_status(text: String) -> void:
	_status_message = text
	_status.text = "%s   [%s]" % [text, OS.get_user_data_dir()]

func show_validation(errors: PackedStringArray) -> void:
	_validation.clear()
	if errors.is_empty():
		_validation.add_item("No problems found.")
	for e in errors:
		_validation.add_item(e)
	_validation.visible = true

func open_new_room(edge: String) -> void:
	_new_edge.select(maxi(0, EDGES.find(edge)))
	_new_id.text = ""
	_new_w.value = 1
	_new_h.value = 1
	_dialog.visible = true
	_refresh_dialog()

func set_new_room_fields(id: String, area: String, size: Vector2i) -> void:
	_new_id.text = id
	_new_area.select(maxi(0, AREAS.find(area)))
	_new_w.value = size.x
	_new_h.value = size.y
	_refresh_dialog()

func new_room_error() -> String:
	return _model.id_error(_new_id.text)

func confirm_new_room() -> void:
	var err := new_room_error()
	if err != "":
		_new_error.text = err
		return
	_dialog.visible = false
	new_room_requested.emit(EDGES[_new_edge.selected], _new_id.text, AREAS[_new_area.selected],
		Vector2i(int(_new_w.value), int(_new_h.value)))

func _refresh_dialog() -> void:
	var edge: String = EDGES[_new_edge.selected]
	_new_note.text = HOLE_NOTE if edge == "top" or edge == "bottom" else ""
	_new_error.text = "" if _new_id.text == "" else new_room_error()

func focus_new_room_id() -> void:
	_dialog.visible = true
	_new_id.grab_focus()

# --- read back (tests and RoomEditor) ---

func press(label: String) -> void:
	(_buttons[label] as Button).pressed.emit()

func choose_room(id: String) -> void:
	var i := _room_ids.find(id)
	select_room(id)
	room_chosen.emit(_room_ids[i])

func choose_creature(id: String) -> void:
	for i in _palette.item_count:
		if _palette.get_item_text(i) == id:
			_palette.select(i)
	creature_chosen.emit(id)

func room_labels() -> Array:
	var out: Array = []
	for i in _room_pick.item_count:
		out.append(_room_pick.get_item_text(i))
	return out

func palette_ids() -> Array:
	var out: Array = []
	for i in _palette.item_count:
		out.append(_palette.get_item_text(i))
	return out

func palette_visible() -> bool:
	return _palette.visible

func validation_lines() -> Array:
	var out: Array = []
	for i in _validation.item_count:
		out.append(_validation.get_item_text(i))
	return out

func status_text() -> String:
	return _status.text

func new_room_visible() -> bool:
	return _dialog.visible

func new_room_note() -> String:
	return _new_note.text

## True when a text field of the panels has keyboard focus (RoomEditor leaves its shortcuts alone then).
func typing() -> bool:
	var f := _root.get_viewport().gui_get_focus_owner() if _root.is_inside_tree() else null
	return f is LineEdit or f is SpinBox
