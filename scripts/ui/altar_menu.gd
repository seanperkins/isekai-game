class_name AltarMenu
extends CanvasLayer
## An altar's menu, opened in the world: attune, bank essence into soul points per element, and buy the altar's perk. It pauses the
## game while open (as the skill screen does) and drives an AltarModel from keys, the D-pad and the left stick (through NavStep).
## Layer 25: above the HUD and the skill screen (20), below the death card (30).

const COL_TEXT := Color(0.75, 0.9, 1.0)
const COL_DIM := Color(0.5, 0.5, 0.6)
const HINT := "Enter: choose   Back: leave"

## The essence engine the rows read and bank from (the run's: SkillRules).
var engine: SkillRulesEngine

var _goddess: Goddess
var _progress: WorldProgress
var _player: Node
var _model: AltarModel
var _title := ""
var _open := false
var _nav := NavStep.new()
var _title_label := Label.new()
var _column := VBoxContainer.new()
var _footer := Label.new()

func _init() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # it runs while the tree it paused is paused

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.05, 0.85)
	shade.size = Vector2(640, 360)
	add_child(shade)
	_title_label.position = Vector2(80, 40)
	_title_label.size = Vector2(480, 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_title_label, COL_TEXT)
	add_child(_title_label)
	_column.position = Vector2(150, 90)
	_column.size = Vector2(340, 200)
	add_child(_column)
	_footer.position = Vector2(40, 318)
	_footer.size = Vector2(560, 24)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_footer, COL_TEXT)
	add_child(_footer)

func bind(goddess: Goddess, p_engine: SkillRulesEngine, progress: WorldProgress, player: Node) -> void:
	_goddess = goddess
	engine = p_engine
	_progress = progress
	_player = player

## Opens the menu for an altar. False, and nothing opens, when the game is already paused (the skill screen is open), the player
## is dead, or no goddess is bound (an editor Play).
func open_for(altar: Altar) -> bool:
	if _goddess == null or get_tree().paused or (_player != null and _player.health.is_dead()):
		return false
	var model := AltarModel.new(altar.id, _goddess.perk_for(altar.perk), _progress, _goddess.soul, _goddess.rules, engine,
		altar.announce_attuned)
	open_model(model, altar.title())
	return true

func open_model(model: AltarModel, title: String) -> void:
	_model = model
	_title = title
	_open = true
	visible = true
	_nav.reset()
	if _player != null and _player.has_method("end_channel"):
		_player.end_channel()  # the tree is about to pause: a held channel would freeze mid-hold
	get_tree().paused = true
	EventBus.world_event.emit("menu_opened", {})
	_redraw()

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	EventBus.world_event.emit("menu_closed", {})

func is_open() -> bool:
	return _open

func title_text() -> String:
	return _title

## The rows as drawn: a highlighted row starts "> ", the others two spaces.
func row_texts() -> Array:
	var out: Array = []
	if _model == null:
		return out
	var rows := _model.rows()
	for i in rows.size():
		var mark := "> " if i == _model.row() else "  "
		var row: Dictionary = rows[i]
		match row["kind"]:
			"attune":
				out.append(mark + ("Attuned" if row["done"] else "Attune"))
			"element":
				out.append("%s%s  held %d  bank %d = %d" % [mark, str(row["element"]).capitalize(), row["held"], row["units"], row["points"]])
			"perk":
				out.append("%s%s  x%d  next %d" % [mark, row["name"], row["times"], row["price"]])
	return out

func footer_text() -> String:
	if _model == null:
		return ""
	return "Soul points %d    %s" % [_model.points(), _model.message if _model.message != "" else HINT]

func move(step: int) -> void:
	if _open:
		_model.move(step)
		_redraw()

func adjust(step: int) -> void:
	if _open:
		_model.adjust(step)
		_redraw()

func act() -> void:
	if _open:
		_model.act()
		_redraw()

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
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		adjust(1)
	elif event.is_action_pressed("menu_accept") or event.is_action_pressed("ui_accept"):
		act()
	elif event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()

func _redraw() -> void:
	if not is_node_ready() or _model == null:
		return
	_title_label.text = _title
	for child in _column.get_children():
		child.queue_free()
	var attuned := _model.attuned()
	var texts := row_texts()
	for i in texts.size():
		var label := Label.new()
		label.text = texts[i]
		_style(label, COL_TEXT if attuned or i == 0 else COL_DIM)  # banking and buying wait for the attune row
		_column.add_child(label)
	_footer.text = footer_text()

func _style(label: Label, color: Color) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
