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
var _list: VBoxContainer
var _problems: Array = []
var _showing := ""

func _init() -> void:
	position = Vector2(472, 50)
	size = Vector2(168, 290)
	visible = false
	var back := ColorRect.new()
	back.color = Color(0.3, 0.3, 0.36)  # opaque and light enough that an unticked checkbox shows against it
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
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(160, 0)
	if problems.is_empty():
		_list.add_child(_text("No problems found."))
	for i in problems.size():
		var room: String = problems[i]["room"]
		var text: String = problems[i]["text"]
		var b := Button.new()
		b.text = text if room == "" or text.begins_with(room) else "%s: %s" % [room, text]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a finding is a sentence: wrap it rather than cut it at the slot's edge
		b.custom_minimum_size = Vector2(160, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", FONT)
		b.pressed.connect(click_problem.bind(i))
		_list.add_child(b)
	_scroll.add_child(_list)
	_showing = "problems"
	visible = true

func _text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT)
	return l

func click_problem(i: int) -> void:
	if i >= 0 and i < _problems.size():
		problem_clicked.emit(_problems[i])

func hide_slot() -> void:
	_clear()
	_showing = ""
	visible = false

## Re-reads the inspector's controls (see InspectorPanel.refresh); a no-op when it is not showing.
func refresh_inspector() -> void:
	if _inspector != null:
		_inspector.refresh()

func problem_lines() -> Array:
	var out: Array = []
	if _list != null:
		for c in _list.get_children():
			out.append(c.text)
	return out

func find_field(key: String) -> Control:
	return _inspector.find_field(key) if _inspector != null else null

func _clear() -> void:
	for c in _scroll.get_children():
		_scroll.remove_child(c)
		c.queue_free()
	_inspector = null
	_list = null
	_problems = []
