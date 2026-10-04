class_name SettingsMenu
extends Control
## The Settings menu: opened from the pause screen (Tab / R3), drawn over the tabs, and closed back to the same tab (Esc,
## Backspace, B, Start, or the Settings button again). It holds the Sound sliders. Built in code for 640x360.

const BOX := Rect2(150, 70, 340, 200)
const ROW_TOP := 110.0
const ROW_PITCH := 30.0

var _rows: Array = []
var _sel := 0
var _open := false
var _body := Control.new()
var _hint := ""

func _ready() -> void:
	visible = false
	var shade := ColorRect.new()
	shade.color = SkillScreen.COL_DIM_BG
	shade.size = Vector2(640, 360)
	add_child(shade)  # stops clicks: nothing under the menu can be clicked while it is open
	add_child(_body)

func is_open() -> bool:
	return _open

func open() -> void:
	_open = true
	_sel = 0
	visible = true
	redraw()

func close() -> void:
	_open = false
	visible = false

func rows() -> Array:
	return _rows.duplicate(true)

func selected_id() -> String:
	return "" if _rows.is_empty() else str(_rows[_sel]["id"])

func hint_text() -> String:
	return _hint

func move(delta: int) -> void:
	if not _open or _rows.is_empty():
		return
	var before := _sel
	_sel = clampi(_sel + delta, 0, _rows.size() - 1)
	if _sel != before:
		EventBus.world_event.emit("menu_move", {})
	redraw()

## Changes the selected slider by one step (direction is -1 or +1).
func adjust(direction: int) -> void:
	if not _open or _rows.is_empty():
		return
	Audio.adjust_setting(selected_id(), direction)
	EventBus.world_event.emit("menu_move", {})
	redraw()

## The menu's share of input while it is open: true when it used the event.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("settings") or event.is_action_pressed("menu") or event.is_action_pressed("menu_back") \
			or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		move(1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		adjust(1)
	else:
		return false
	return true

## Rebuilds the menu from the current settings (and the scheme, for the hint line).
func redraw() -> void:
	_rows = SkillScreenModel.sound_rows(Audio.settings)
	_sel = clampi(_sel, 0, _rows.size() - 1)
	for c in _body.get_children():
		c.free()
	var x := BOX.position.x
	_panel(BOX.position, BOX.size, SkillScreen.COL_BG, 2)
	_text("SETTINGS", Vector2(x + 12, BOX.position.y + 8), Vector2(200, 16), SkillScreen.FONT_BIG, SkillScreen.COL_TITLE)
	_text("Sound", Vector2(x + 12, BOX.position.y + 26), Vector2(200, 12), SkillScreen.FONT_SMALL, SkillScreen.COL_DIM)
	var y := ROW_TOP
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if i == _sel:
			_panel(Vector2(x + 6, y - 5), Vector2(BOX.size.x - 12, 24), SkillScreen.COL_SELECTED, 1)
		_text(r["name"], Vector2(x + 14, y), Vector2(80, 14), SkillScreen.FONT_MAIN, Color.WHITE)
		_rect(Vector2(x + 100, y + 3), Vector2(170, 8), Color(0.1, 0.12, 0.2))
		_rect(Vector2(x + 100, y + 3), Vector2(170.0 * clampf(r["value"], 0.0, 1.0), 8), SkillScreen.COL_PIP_ON)
		_text("%d%%" % int(round(r["value"] * 100.0)), Vector2(x + 280, y), Vector2(50, 14), SkillScreen.FONT_MAIN, SkillScreen.COL_DIM)
		y += ROW_PITCH
	_hint = "Up/Down Choose    Left/Right Adjust    B Back" if Controls.using_joypad else "W/S Choose    A/D Adjust    Esc Back"
	var h := _text(_hint, Vector2(x, BOX.end.y - 18), Vector2(BOX.size.x, 12), SkillScreen.FONT_SMALL, SkillScreen.COL_DIM)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _panel(pos: Vector2, box_size: Vector2, color: Color, border: int) -> void:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = SkillScreen.COL_BORDER
	style.set_border_width_all(border)
	style.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", style)
	p.position = pos
	p.size = box_size
	_body.add_child(p)

func _rect(pos: Vector2, box_size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = box_size
	_body.add_child(r)

func _text(text: String, pos: Vector2, box_size: Vector2, font: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.clip_text = true
	_body.add_child(l)
	l.size = box_size
	return l
