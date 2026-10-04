class_name InspectorPanel
extends VBoxContainer
## The controls for the selected exit, feature or solid, from a per-kind field list. Every control is bound to the selection captured at
## build, so a late commit (focus loss after the selection moved) lands on the element it was typed for. The model decides what a
## value may be: a refusal is reported and the control shows the stored value again.

signal field_error(text: String)
signal field_changed

const FONT := 8
## kind -> [[key, label, control], ...]; the keys are RoomEditModel.get_field / set_field's.
const FIELDS := {
	"exit": [["shortcut", "Shortcut", "line"], ["gate", "Gate", "choice"]],
	"tablet": [["title", "Title", "line"], ["text", "Text", "line"], ["hint", "Hint", "choice"]],
	"switch": [["shortcut", "Shortcut", "line"]],
	"altar": [["perk", "Perk", "choice"]],
	"glow_pool": [],
	"solid": [["x", "X", "number"], ["y", "Y", "number"], ["w", "Width", "number"], ["h", "Height", "number"], ["hard", "Rock from below", "check"]],
	"water": [["x", "X", "number"], ["y", "Y", "number"], ["w", "Width", "number"], ["h", "Height", "number"]],
}

var _model: RoomEditModel
var _sel := {}
var _fields := {}    # key -> Control

func build(model: RoomEditModel, sel: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_fields.clear()
	_model = model
	_sel = sel.duplicate()
	var kind := _kind()
	add_child(_label(_title(kind)))
	if not FIELDS.has(kind) or (FIELDS[kind] as Array).is_empty():
		add_child(_label("nothing to edit"))
		return
	for spec in FIELDS[kind]:
		if spec[2] != "check":
			add_child(_label(spec[1]))  # a checkbox carries its own text
		var control := _make(spec[0], spec[2])
		_fields[spec[0]] = control
		add_child(control)

func find_field(key: String) -> Control:
	return _fields.get(key)

func _kind() -> String:
	if _sel.is_empty() or not _model.rooms.has(_sel["room"]):
		return ""
	if _sel["kind"] == "feature":
		var features: Array = _model.rooms[_sel["room"]].features
		return features[_sel["index"]].get("kind", "") if _sel["index"] < features.size() else ""
	return _sel["kind"]

func _title(kind: String) -> String:
	if kind == "solid":
		return "Solid %d" % _sel["index"]
	if kind == "water":
		return "Water %d" % _sel["index"]
	if kind == "exit":
		var e: Dictionary = _model.rooms[_sel["room"]].exits[_sel["index"]]
		return "Exit %s to %s" % [e["edge"], e["room"]]
	var f: Dictionary = _model.rooms[_sel["room"]].features[_sel["index"]] if kind != "" else {}
	return "%s %s" % [kind.capitalize().replace("_", " "), f.get("id", "")]

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make(key: String, control: String) -> Control:
	match control:
		"number":
			return _number(key)
		"check":
			return _check(key)
		"choice":
			return _choice(key)
	return _line(key)

func _line(key: String) -> LineEdit:
	var line := LineEdit.new()
	line.name = "field_" + key
	line.custom_minimum_size = Vector2(150, 0)
	line.add_theme_font_size_override("font_size", FONT)
	line.text = str(_model.get_field(_sel, key))
	line.text_submitted.connect(func(t: String) -> void: _commit(key, t))
	line.focus_exited.connect(func() -> void: _commit(key, line.text))
	return line

func _number(key: String) -> SpinBox:
	var box := SpinBox.new()
	box.name = "field_" + key
	box.custom_minimum_size = Vector2(150, 0)
	box.step = 1.0
	box.rounded = true
	_set_range(box, key)                                   # ranges first: a new SpinBox is 0..100 and would clamp the value
	box.value = float(_model.get_field(_sel, key))         # then the value
	box.value_changed.connect(func(v: float) -> void: _commit(key, v))  # then connect, so building never commits
	box.get_line_edit().add_theme_font_size_override("font_size", FONT)
	return box

## The SpinBox range for a solid's number from the room it is in (a Grow changes it under an open selection).
func _set_range(box: SpinBox, key: String) -> void:
	var size: Vector2 = _model.rooms[_sel["room"]].pixel_size()
	var least := RoomEditModel.MIN_WATER if _sel["kind"] == "water" else RoomEditModel.MIN_SOLID
	match key:
		"x":
			box.min_value = 0.0
			box.max_value = size.x - least
		"y":
			box.min_value = 0.0
			box.max_value = size.y - least
		"w":
			box.min_value = least
			box.max_value = size.x
		"h":
			box.min_value = least
			box.max_value = size.y

func _check(key: String) -> CheckBox:
	var box := CheckBox.new()
	box.name = "field_" + key
	box.text = "Rock from below"
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", FONT)
	box.button_pressed = bool(_model.get_field(_sel, key))
	box.visible = _thin_solid()
	box.toggled.connect(func(on: bool) -> void: _commit(key, on))
	return box

## Thin solids (a one-way ledge unless marked) are the only ones the mark means anything for.
func _thin_solid() -> bool:
	return float(_model.get_field(_sel, "h")) <= 24.0 and float(_model.get_field(_sel, "w")) > 24.0

## A string choice (gate, hint): "none" plus the legal values, selected by item text. A stored value outside the list (hand-edited
## data) appears as its own item, so the control never shows "none" for a value that is there.
func _choice(key: String) -> OptionButton:
	var pick := OptionButton.new()
	pick.name = "field_" + key
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_font_size_override("font_size", FONT)
	pick.set_meta("choice", true)  # selected by item text
	pick.add_item("none")
	for v in _choices(key):
		pick.add_item(str(v))
	_select_choice(pick, str(_model.get_field(_sel, key)))
	pick.item_selected.connect(func(i: int) -> void: _commit(key, "" if i == 0 else pick.get_item_text(i)))
	return pick

func _choices(key: String) -> Array:
	match key:
		"gate":
			return WorldValidator.GATES
		"perk":
			return RoomEditModel.perk_ids()
	return RoomLint.hintable_skill_ids()

func _select_choice(pick: OptionButton, stored: String) -> void:
	if stored == "":
		pick.select(0)
		return
	for i in pick.item_count:
		if pick.get_item_text(i) == stored:
			pick.select(i)
			return
	pick.add_item(stored)
	pick.select(pick.item_count - 1)

## Writes one field through the model. A value equal to the stored one, or one for an element that no longer exists (a late
## focus loss), does nothing; a refusal reports the reason and puts the stored value back.
func _commit(key: String, value) -> void:
	var stored = _model.get_field(_sel, key)
	if stored == null or stored == value:
		return
	var err := _model.set_field(_sel, key, value)
	if err != "":
		field_error.emit(err)
		_show_stored(key)
	else:
		field_changed.emit()

## Re-reads every control from the model (after a drag, a Grow or any other edit made outside the panel), skipping a control
## that has keyboard focus: the author may be typing in it. Writes use set_value_no_signal / set_pressed_no_signal, so a refresh
## can never commit.
func refresh() -> void:
	for key in _fields:
		if not _has_focus(_fields[key]):
			_show_stored(key)

func _has_focus(c: Control) -> bool:
	if c is SpinBox:
		return (c as SpinBox).get_line_edit().has_focus()
	return c.has_focus()

func _show_stored(key: String) -> void:
	var control: Control = _fields.get(key)
	var stored = _model.get_field(_sel, key)
	if stored == null:
		return
	if control is LineEdit:
		(control as LineEdit).text = str(stored)
	elif control is SpinBox:
		_set_range(control as SpinBox, key)
		(control as SpinBox).set_value_no_signal(float(stored))
	elif control is CheckBox:
		(control as CheckBox).set_pressed_no_signal(bool(stored))
		control.visible = _thin_solid()
	elif control is OptionButton:
		_select_choice(control as OptionButton, str(stored))
