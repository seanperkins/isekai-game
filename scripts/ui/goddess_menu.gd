class_name GoddessMenu
extends CanvasLayer
## The goddess's scene after death: her line on top, then three panels (where, who, head start) and a footer. It drives a
## GoddessModel from keys, the D-pad and the left stick (through NavStep) and emits the confirmed result. Layer 40: above the
## death card (30) and the skill screen (20). It takes input only while open. No mouse.

signal confirmed(result: Dictionary)

const P := GoddessModel.Pane
const PANE_NAMES := ["WHERE", "WHO", "HEAD START"]
const PANEL_X := [32.0, 232.0, 432.0]
const COL_TEXT := Color(0.75, 0.9, 1.0)
const COL_DIM := Color(0.5, 0.5, 0.6)
## A panel draws at most this many rows (they fit the 180 px column); a longer list scrolls to keep the selected row in view.
const MAX_ROWS := 10
const ROWS_ABOVE := 5  # the selected row sits this far down the window until the list's ends

var _model: GoddessModel
var _line := ""
var _open := false
var _nav := NavStep.new()
var _line_label := Label.new()
var _headers: Array = []
var _columns: Array = []
var _footer := Label.new()

func _init() -> void:
	layer = 40
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # the opening hands over with the tree still paused; a death leaves it unpaused, so nothing else changes

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.05, 0.9)
	shade.size = Vector2(640, 360)
	add_child(shade)
	_line_label.position = Vector2(40, 24)
	_line_label.size = Vector2(560, 40)
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(_line_label, COL_TEXT)
	add_child(_line_label)
	for pane in 3:
		var header := Label.new()
		header.position = Vector2(PANEL_X[pane], 84)
		header.size = Vector2(176, 16)
		add_child(header)
		_headers.append(header)
		var column := VBoxContainer.new()
		column.position = Vector2(PANEL_X[pane], 104)
		column.size = Vector2(176, 180)
		add_child(column)
		_columns.append(column)
	_footer.position = Vector2(40, 318)
	_footer.size = Vector2(560, 24)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_footer, COL_TEXT)
	add_child(_footer)

## Shows the scene for `model` with her `line` on top.
func open(model: GoddessModel, line: String) -> void:
	_model = model
	_line = line
	_open = true
	visible = true
	_nav.reset()
	_redraw()

func is_open() -> bool:
	return _open

func line_text() -> String:
	return _line

## The pane's title; the current pane is in square brackets.
func header(pane: int) -> String:
	var title: String = PANE_NAMES[pane]
	return "[%s]" % title if _model != null and _model.panel == pane else title

## The pane's rows as drawn: a highlighted row starts "> ", the others two spaces.
func panel_rows(pane: int) -> Array:
	var out: Array = []
	if _model == null:
		return out
	var rows := _model.rows(pane)
	for i in rows.size():
		var mark := "> " if i == _model.row(pane) else "  "
		var row: Dictionary = rows[i]
		if pane == P.HEAD_START and row.get("kind", "") == "level":
			var next_price := int(row["next_price"])
			out.append("%sLevel +%d  %s" % [mark, int(row["levels"]), "next %d" % next_price if next_price >= 0 else "max"])
		elif pane == P.HEAD_START:
			out.append("%s[%s] %s  %d" % [mark, "x" if row["taken"] else " ", row["name"], int(row["price"])])
		else:
			out.append(mark + str(row["name"]))
	return out

## The rows actually drawn: all of them when they fit, else a window of MAX_ROWS that follows the selected row (so a head start
## list of every owned power never runs off the screen, and the selected row is always visible).
func shown_rows(pane: int) -> Array:
	var rows := panel_rows(pane)
	if rows.size() <= MAX_ROWS:
		return rows
	var start := clampi(_model.row(pane) - ROWS_ABOVE, 0, rows.size() - MAX_ROWS)
	return rows.slice(start, start + MAX_ROWS)

func footer_text() -> String:
	if _model == null:
		return ""
	var tail := "Enter: be reborn" if _model.can_afford() else "Not enough soul points"
	return "Soul points %d    Cost %d    %s" % [_model.soul.total_points(), _model.cost(), tail]

func move(step: int) -> void:
	if _open:
		_model.move(step)
		_redraw()

func switch_panel(step: int) -> void:
	if _open:
		_model.switch_panel(step)
		_redraw()

func adjust(step: int) -> void:
	if _open:
		_model.adjust(step)
		_redraw()

## Be reborn: closes and emits the model's result. False, and the menu stays open, when the cart costs more than the points.
func confirm() -> bool:
	if not _open:
		return false
	var result := _model.confirm()
	if result.is_empty():
		_redraw()
		return false
	_open = false
	visible = false
	confirmed.emit(result)
	return true

func _process(delta: float) -> void:
	if not _open:
		_nav.reset()
		return
	var step := _nav.step(Controls.last_stick, delta)
	if step.y != 0:
		move(step.y)
	elif step.x != 0:
		adjust(step.x)

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()  # the stick is read in _process; marking it handled keeps later handlers off it
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		move(1)
	elif event.is_action_pressed("tab_prev"):
		switch_panel(-1)
	elif event.is_action_pressed("tab_next"):
		switch_panel(1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		adjust(1)
	elif event.is_action_pressed("menu_accept") or event.is_action_pressed("ui_accept"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()

func _redraw() -> void:
	if not is_node_ready() or _model == null:
		return
	_line_label.text = _line
	for pane in 3:
		var focused: bool = _model.panel == pane
		_headers[pane].text = header(pane)
		_style(_headers[pane], COL_TEXT if focused else COL_DIM)
		for child in _columns[pane].get_children():
			child.queue_free()
		for text in shown_rows(pane):
			var label := Label.new()
			label.text = text
			_style(label, COL_TEXT if focused else COL_DIM)
			_columns[pane].add_child(label)
	_footer.text = footer_text()

func _style(label: Label, color: Color) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
