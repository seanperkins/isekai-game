class_name EditorSlot
extends Control
## The editor's right-hand slot: the inspector for the selection, or the problems list, or nothing. It only emits signals;
## RoomEditor decides what to show and what a click on a problem does.

signal problem_clicked(problem: Dictionary)
signal field_error(text: String)
signal field_changed

const FONT := 8

var _scroll := ScrollContainer.new()
var _inspector: InspectorPanel
var _list: ItemList
var _problems: Array = []
var _showing := ""

func _init() -> void:
	position = Vector2(472, 50)
	size = Vector2(168, 290)
	visible = false
	var back := ColorRect.new()
	back.color = Color(0.08, 0.08, 0.12, 0.92)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

func is_showing() -> String:
	return _showing

func show_inspector(model: RoomEditModel, sel: Dictionary) -> void:
	_clear()
	_inspector = InspectorPanel.new()
	_inspector.field_error.connect(func(t: String) -> void: field_error.emit(t))
	_inspector.field_changed.connect(func() -> void: field_changed.emit())
	_scroll.add_child(_inspector)
	_inspector.build(model, sel)
	_showing = "inspector"
	visible = true

func show_problems(problems: Array) -> void:
	_clear()
	_problems = problems
	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(160, 280)
	_list.add_theme_font_size_override("font_size", FONT)
	_list.auto_height = true
	if problems.is_empty():
		_list.add_item("No problems found.")
	for p in problems:
		var room: String = p["room"]
		var text: String = p["text"]
		_list.add_item(text if room == "" or text.begins_with(room) else "%s: %s" % [room, text])
	_list.item_clicked.connect(func(i: int, _at: Vector2, button: int) -> void:
		if button == MOUSE_BUTTON_LEFT:
			click_problem(i))
	_list.item_activated.connect(click_problem)
	_scroll.add_child(_list)
	_showing = "problems"
	visible = true

func click_problem(i: int) -> void:
	if i >= 0 and i < _problems.size():
		problem_clicked.emit(_problems[i])

func hide_slot() -> void:
	_clear()
	_showing = ""
	visible = false

func problem_lines() -> Array:
	var out: Array = []
	if _list != null:
		for i in _list.item_count:
			out.append(_list.get_item_text(i))
	return out

func find_field(key: String) -> Control:
	return _inspector.find_field(key) if _inspector != null else null

func skill_checkboxes() -> Array:
	return _inspector.skill_checkboxes() if _inspector != null else []

func _clear() -> void:
	for c in _scroll.get_children():
		_scroll.remove_child(c)
		c.queue_free()
	_inspector = null
	_list = null
	_problems = []
