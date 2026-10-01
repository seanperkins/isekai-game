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
	"exit": [["shortcut", "Shortcut", "line"]],
	"tablet": [["title", "Title", "line"], ["text", "Text", "line"]],
	"switch": [["shortcut", "Shortcut", "line"]],
	"rebirth_pool": [["kit_level", "Level", "level"], ["kit_skills", "Skills", "skills"]],
	"glow_pool": [],
	"solid": [["x", "X", "number"], ["y", "Y", "number"], ["w", "Width", "number"], ["h", "Height", "number"], ["hard", "Rock from below", "check"]],
}

var _model: RoomEditModel
var _sel := {}
var _fields := {}    # key -> Control
var _checks: Array = []

func build(model: RoomEditModel, sel: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_fields.clear()
	_checks.clear()
	_model = model
	_sel = sel.duplicate()
	var kind := _kind()
	add_child(_label(_title(kind)))
	if not FIELDS.has(kind) or (FIELDS[kind] as Array).is_empty():
		add_child(_label("nothing to edit"))
		return
	for spec in FIELDS[kind]:
		add_child(_label(spec[1]))
		var control := _make(spec[0], spec[2])
		_fields[spec[0]] = control
		add_child(control)

func find_field(key: String) -> Control:
	return _fields.get(key)

func skill_checkboxes() -> Array:
	return _checks

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
		"level":
			return _level(key)
		"skills":
			return _skills(key)
		"number":
			return _number(key)
		"check":
			return _check(key)
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
	match key:
		"x":
			box.min_value = 0.0
			box.max_value = size.x - RoomEditModel.MIN_SOLID
		"y":
			box.min_value = 0.0
			box.max_value = size.y - RoomEditModel.MIN_SOLID
		"w":
			box.min_value = RoomEditModel.MIN_SOLID
			box.max_value = size.x
		"h":
			box.min_value = RoomEditModel.MIN_SOLID
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

func _level(key: String) -> OptionButton:
	var pick := OptionButton.new()
	pick.name = "field_" + key
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_font_size_override("font_size", FONT)
	pick.add_item("none")
	for lv in range(1, Progression.LEVEL_CAP + 1):
		pick.add_item(str(lv))
	pick.select(int(_model.get_field(_sel, key)))
	pick.item_selected.connect(func(i: int) -> void: _commit(key, i))
	return pick

func _skills(key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "field_" + key
	var have: Array = _model.get_field(_sel, key)
	for d in RebirthKit.skill_defs():
		if d.source == "enemy_only" or d.source == "evolution":
			continue  # RebirthKit.validate refuses both
		var check := CheckBox.new()
		check.text = d.id
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_size_override("font_size", FONT)
		check.set_meta("skill", d.id)
		check.button_pressed = have.has(d.id)
		check.toggled.connect(func(_on: bool) -> void: _commit(key, _ticked()))
		_checks.append(check)
		box.add_child(check)
	return box

func _ticked() -> Array:
	var ids: Array = []
	for c in _checks:
		if (c as CheckBox).button_pressed:
			ids.append(c.get_meta("skill"))
	return ids

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
		(control as OptionButton).select(int(stored))
	else:
		for c in _checks:
			(c as CheckBox).set_pressed_no_signal((stored as Array).has(c.get_meta("skill")))
