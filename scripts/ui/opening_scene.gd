class_name OpeningScene
extends CanvasLayer
## The opening's truck dodge: a black screen, a road, a truck sliding in, and a tiny JRPG menu that cannot save you. It pauses the
## game (the live world underneath must not touch the player), drives an OpeningModel from keys, the D-pad and the left stick
## (through NavStep), and marks every key and pad event handled while it plays, so there is no skip. When the last result is
## dismissed it hides and emits `finished` with the tree still paused: the goddess's menu takes over from there. Layer 45, above
## her menu (40), added last so it sees input first.

signal finished

const APPROACH_SECONDS := 1.0
const FLASH_SECONDS := 0.15
const COL_TEXT := Color(0.75, 0.9, 1.0)
const COL_DIM := Color(0.5, 0.5, 0.6)

var _model: OpeningModel
var _playing := false
var _nav := NavStep.new()
var _stage := OpeningStage.new()
var _text := Label.new()
var _column := VBoxContainer.new()
var _footer := Label.new()

func _init() -> void:
	layer = 45
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # it runs while the tree it paused is paused

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 1.0)
	shade.size = Vector2(640, 360)
	add_child(shade)
	_stage.name = "Stage"
	add_child(_stage)
	_text.position = Vector2(60, 268)
	_text.size = Vector2(520, 40)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(_text, COL_TEXT)
	add_child(_text)
	_column.position = Vector2(280, 306)
	_column.size = Vector2(120, 48)
	add_child(_column)
	_footer.position = Vector2(40, 338)
	_footer.size = Vector2(560, 18)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_footer, COL_DIM)
	add_child(_footer)

## Starts the dodge. False, and nothing starts, when the game is already paused (a menu is open), it is already playing, or the
## def has nothing to play.
func play(def: OpeningDef) -> bool:
	if _playing or get_tree().paused:
		return false
	var model := OpeningModel.new(def)
	if model.done():
		return false
	_model = model
	_playing = true
	visible = true
	_nav.reset()
	_reset_stage()
	get_tree().paused = true
	_redraw()
	return true

func is_playing() -> bool:
	return _playing

## What the text box says: the truck's prompt, then the result of the choice while it hits.
func text_lines() -> Array:
	if _model == null or _model.done():
		return []
	return [_model.result_line() if _model.phase == OpeningModel.Phase.RESULT else _model.prompt()]

## The choices as drawn: the highlighted one starts "> ", the others two spaces. None while a result shows.
func row_texts() -> Array:
	var out: Array = []
	if _model == null:
		return out
	var rows := _model.rows()
	for i in rows.size():
		out.append(("> " if i == _model.row() else "  ") + str(rows[i]))
	return out

func move(step: int) -> void:
	if _playing:
		_model.move(step)
		_redraw()

## Enter. A prompt takes the highlighted choice and the truck hits; a result moves on, and the last one ends the scene.
func act() -> void:
	if not _playing:
		return
	var was := _model.phase
	_model.act()
	if was == OpeningModel.Phase.PROMPT:
		_stage.hit = true
		_stage.flash = 1.0
		EventBus.world_event.emit("opening_hit", {})
	elif _model.done():
		_finish()
		return
	else:
		_reset_stage()
	_redraw()

func _finish() -> void:
	_playing = false
	visible = false
	_nav.reset()
	finished.emit()

func _reset_stage() -> void:
	_stage.approach = 0.0
	_stage.flash = 0.0
	_stage.hit = false
	_stage.queue_redraw()

func _process(delta: float) -> void:
	if not _playing:
		_nav.reset()
		return
	if _model.phase == OpeningModel.Phase.PROMPT:
		_stage.approach = minf(1.0, _stage.approach + delta / APPROACH_SECONDS)
		var step := _nav.step(Controls.last_stick, delta)
		if step.y != 0:
			move(step.y)
	elif _model.phase == OpeningModel.Phase.RESULT:
		_stage.flash = maxf(0.0, _stage.flash - delta / FLASH_SECONDS)
	_stage.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction:
		get_viewport().set_input_as_handled()  # no skip: the menu key, Escape and the pad's buttons all stop here
	if event is InputEventJoypadMotion:
		return  # the stick is read in _process
	if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		move(1)
	elif event.is_action_pressed("menu_accept") or event.is_action_pressed("ui_accept"):
		act()

func _redraw() -> void:
	if not is_node_ready() or _model == null:
		return
	var lines := text_lines()
	_text.text = str(lines[0]) if not lines.is_empty() else ""
	for child in _column.get_children():
		child.queue_free()
	var rows := row_texts()
	for i in rows.size():
		var label := Label.new()
		label.text = rows[i]
		_style(label, COL_TEXT)
		_column.add_child(label)
	_footer.text = "Enter: choose" if _model.phase == OpeningModel.Phase.PROMPT else "Enter: continue"

func _style(label: Label, color: Color) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
