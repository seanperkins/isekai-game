class_name OpeningScene
extends CanvasLayer
## The opening: a JRPG battle against a truck. A sunny street, the commuter on the right and the truck on the left, a message window
## along the top and the command and status windows along the bottom. Each of the three trucks is one round: it rolls in (INTRO),
## you pick a command (COMMAND), your action plays with its result line (ACTION, then RESULT while you read it), the truck charges
## and hits (HIT), and after the last one you are knocked out (KO) and the screen fades to white. It pauses the game (the live world
## underneath must not touch the player), drives an OpeningModel from keys, the D-pad and the left stick (through NavStep), and marks
## every key and pad event handled while it plays, so there is no skip of the scene itself. Enter during an animation finishes it.
## When the last fade-to-white is full it hides the battle, emits `finished` (the goddess's menu opens beneath, with the tree still
## paused) and fades the white away over her menu. Layer 45, added last so it sees input first.

signal finished

enum Beat { NONE, INTRO, COMMAND, ACTION, RESULT, HIT, KO }

const MAX_HP := 30
const BACKDROP := "res://assets/opening/backdrop.png"
## The layout on the 640x360 screen: the street, the fighters standing on FLOOR_Y, the message window on top, and the command and
## status windows along the bottom. The command window holds up to OpeningDef.MAX_CHOICES rows; a test pins the arithmetic.
const FLOOR_Y := 262.0
const HERO_REST := Vector2(470.0, FLOOR_Y)
const TRUCK_REST_X := 185.0
const TRUCK_OFF_LEFT := -190.0
const TRUCK_OFF_RIGHT := 820.0
const TRUCK_HIT_X := 335.0
const MESSAGE_RECT := Rect2(100.0, 10.0, 440.0, 40.0)
const COMMAND_RECT := Rect2(10.0, 270.0, 140.0, 84.0)
const STATUS_RECT := Rect2(390.0, 300.0, 240.0, 54.0)
const ROW_HEIGHT := 14.0
const FONT_MAIN := 10
const FONT_SMALL := 8
const COL_TEXT := Color(0.9, 0.96, 1.0)
const COL_NAME := Color(1.0, 0.85, 0.45)
const INTRO_SECONDS := 0.9
const CHARGE_SECONDS := 0.45
const FLASH_SECONDS := 0.3
const FADE_SECONDS := 1.0
## The same truck three times: a different tint tells them apart.
const TRUCK_TINTS := [Color(1, 1, 1), Color(1.0, 0.86, 0.78), Color(0.84, 1.0, 0.86)]
## Choice id -> the clip the commuter plays for it; an id with no clip just stands.
const ACTION_CLIPS := {"fight": "fight", "dodge": "dodge", "jump": "jump", "pray": "pray", "run": "run"}

## The shown HP, animated down when the truck hits (the real value is `_hp`).
var hp_display := float(MAX_HP):
	set(value):
		hp_display = value
		_update_status()

var _model: OpeningModel
var _playing := false
var _beat := Beat.NONE
var _hp := MAX_HP
var _message := ""
var _nav := NavStep.new()
var _tween: Tween
var _fx: Tween
var _sky := ColorRect.new()
var _backdrop := Sprite2D.new()
var _stage := Node2D.new()
var _truck := OpeningActor.new()
var _hero := OpeningActor.new()
var _flash := ColorRect.new()
var _message_window := PanelContainer.new()
var _message_label := Label.new()
var _command_window := PanelContainer.new()
var _command_column := VBoxContainer.new()
var _status_window := PanelContainer.new()
var _name_label := Label.new()
var _hp_label := Label.new()
var _hp_back := ColorRect.new()
var _hp_fill := ColorRect.new()

func _init() -> void:
	layer = 45
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # it runs while the tree it paused is paused

func _ready() -> void:
	_sky.name = "Sky"  # the sky colour, should the backdrop image be missing
	_sky.color = Color(0.55, 0.78, 0.95)
	_sky.size = Vector2(640, 360)
	add_child(_sky)
	_backdrop.name = "Backdrop"
	_backdrop.centered = false
	if ResourceLoader.exists(BACKDROP):
		_backdrop.texture = load(BACKDROP)
	add_child(_backdrop)
	_stage.name = "Stage"
	add_child(_stage)
	_truck.name = "Truck"
	_truck.setup("truck")
	_stage.add_child(_truck)
	_hero.name = "Commuter"
	_hero.setup("commuter")
	_stage.add_child(_hero)
	_build_windows()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 1)
	_flash.size = Vector2(640, 360)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _build_windows() -> void:
	# The game's window style (the voice's pop-ups): translucent blue with a glowing border.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.1, 0.28, 0.88)
	style.border_color = Color(0.45, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	for pair in [[_message_window, MESSAGE_RECT, "Message"], [_command_window, COMMAND_RECT, "Commands"], [_status_window, STATUS_RECT, "Status"]]:
		var window: PanelContainer = pair[0]
		window.name = pair[2]
		window.add_theme_stylebox_override("panel", style)
		window.position = (pair[1] as Rect2).position
		window.size = (pair[1] as Rect2).size
		window.custom_minimum_size = (pair[1] as Rect2).size
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(window)
	_message_label.name = "MessageText"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(_message_label, COL_TEXT, FONT_MAIN)
	_message_window.add_child(_message_label)
	_command_column.name = "Choices"
	_command_column.add_theme_constant_override("separation", 0)
	_command_window.add_child(_command_column)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	_name_label.text = "You"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(_name_label, COL_NAME, FONT_MAIN)
	_style(_hp_label, COL_TEXT, FONT_MAIN)
	top.add_child(_name_label)
	top.add_child(_hp_label)
	status.add_child(top)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 8)
	_hp_back.color = Color(0.0, 0.03, 0.12, 0.9)
	_hp_back.size = Vector2(226, 8)
	_hp_back.name = "HpBack"
	_hp_fill.name = "HpFill"
	_hp_fill.size = Vector2(226, 8)
	bar.add_child(_hp_back)
	bar.add_child(_hp_fill)
	status.add_child(bar)
	_status_window.add_child(status)
	_update_status()

## Starts the battle. False, and nothing starts, when the game is already paused (a menu is open), it is already playing, or the
## def has nothing to play.
func play(def: OpeningDef) -> bool:
	if _playing or get_tree().paused:
		return false
	var model := OpeningModel.new(def)
	if model.done():
		return false
	_model = model
	_playing = true
	_hp = MAX_HP
	hp_display = float(MAX_HP)
	_flash.modulate.a = 0.0
	_show_battle(true)
	_hero_reset()
	visible = true
	_nav.reset()
	get_tree().paused = true
	_begin_intro()
	return true

func is_playing() -> bool:
	return _playing

## The beat now playing: "intro", "command", "action", "result", "hit", "ko", or "" when it is not playing.
func beat() -> String:
	return Beat.keys()[_beat].to_lower() if _beat != Beat.NONE else ""

## The commuter's HP (the number, not the animated bar).
func hp() -> int:
	return _hp

func commuter() -> OpeningActor:
	return _hero

func truck() -> OpeningActor:
	return _truck

## What the message window says: the truck's prompt, then the result of the choice, then the damage taken.
func text_lines() -> Array:
	return [_message] if _message != "" else []

## The commands as drawn: the highlighted one starts "> ", the others two spaces. Only while the command window is up.
func row_texts() -> Array:
	var out: Array = []
	if _model == null or _beat != Beat.COMMAND:
		return out
	var rows := _model.rows()
	for i in rows.size():
		out.append(("> " if i == _model.row() else "  ") + str(rows[i]))
	return out

func move(step: int) -> void:
	if _playing and _beat == Beat.COMMAND:
		_model.move(step)
		_redraw()

## Enter. At the command window it takes the highlighted command; once you have read the result it lets the truck charge; during
## any animation it finishes that animation at once.
func act() -> void:
	if not _playing:
		return
	match _beat:
		Beat.COMMAND:
			_model.act()
			_start_action(_model.chosen())
		Beat.RESULT:
			_start_hit()
		_:
			skip()

## Finishes whatever animation is playing, running its steps to the end.
func skip() -> void:
	for t in [_tween, _fx]:
		if t != null and t.is_valid() and t.is_running():
			t.custom_step(100.0)

# --- the choreography ---

func _begin_intro() -> void:
	_beat = Beat.INTRO
	_truck.modulate = TRUCK_TINTS[mini(_model.truck(), TRUCK_TINTS.size() - 1)]
	_truck.position = Vector2(TRUCK_OFF_LEFT, FLOOR_Y)
	_truck.play("idle")
	_set_message(_model.prompt())
	var tw := _new_tween()
	tw.tween_property(_truck, "position:x", TRUCK_REST_X, INTRO_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_enter_command)
	_redraw()

func _enter_command() -> void:
	_beat = Beat.COMMAND
	_nav.reset()
	_redraw()

func _start_action(id: String) -> void:
	_beat = Beat.ACTION
	_set_message(_model.result_line())
	_hero.play(ACTION_CLIPS.get(id, "idle"))
	var rest := HERO_REST
	var tw := _new_tween()
	match id:
		"fight":  # step up to the truck, swing, step back
			tw.tween_property(_hero, "position:x", rest.x - 80.0, 0.25)
			tw.tween_interval(0.45)
			tw.tween_property(_hero, "position:x", rest.x, 0.25)
		"dodge":  # a hop back out of the way
			tw.tween_property(_hero, "position:x", rest.x + 34.0, 0.2)
			tw.tween_interval(0.4)
			tw.tween_property(_hero, "position:x", rest.x, 0.2)
		"jump":  # up and down in an arc
			tw.tween_interval(0.15)
			tw.tween_property(_hero, "position:y", rest.y - 60.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_hero, "position:y", rest.y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"run":  # off toward the edge of the screen, then back
			_hero.flip = false
			tw.tween_property(_hero, "position:x", rest.x + 90.0, 0.6)
			tw.tween_callback(func() -> void: _hero.flip = true)
			tw.tween_property(_hero, "position:x", rest.x, 0.5)
		_:
			tw.tween_interval(1.0)
	tw.tween_callback(_action_done)
	_redraw()

func _action_done() -> void:
	_hero_reset()
	_beat = Beat.RESULT
	_redraw()

func _start_hit() -> void:
	_beat = Beat.HIT
	var last := _model.truck() + 1 >= _model.truck_count()
	_truck.play("charge")
	var tw := _new_tween()
	tw.tween_property(_truck, "position:x", TRUCK_HIT_X, CHARGE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_impact.bind(last))
	tw.tween_interval(0.55)
	tw.tween_property(_truck, "position:x", TRUCK_OFF_RIGHT, 0.6)
	tw.tween_callback(_after_hit.bind(last))
	_redraw()

func _impact(last: bool) -> void:
	EventBus.world_event.emit("opening_hit", {})
	var damage := ceili(float(MAX_HP) / float(_model.truck_count()))
	_hp = 0 if last else maxi(0, _hp - damage)
	_set_message("You take %d damage!" % (damage if not last else maxi(1, int(round(hp_display)))))
	_hero.play("hurt")
	_kill(_fx)
	_fx = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_fx.tween_property(self, "hp_display", float(_hp), 0.5)
	_flash.modulate.a = 0.9
	_fx.tween_property(_flash, "modulate:a", 0.0, FLASH_SECONDS)
	_fx.tween_property(_hero, "position:x", HERO_REST.x + 60.0, 0.35).set_ease(Tween.EASE_OUT)
	_fx.tween_property(_hero, "position:y", FLOOR_Y - 44.0, 0.17).set_ease(Tween.EASE_OUT)
	_fx.chain().tween_property(_hero, "position:y", FLOOR_Y, 0.18).set_ease(Tween.EASE_IN)

func _after_hit(_last: bool) -> void:
	_kill(_fx)
	hp_display = float(_hp)
	_model.act()
	if _model.done():
		_start_ko()
	else:
		_hero_reset()
		_begin_intro()

func _start_ko() -> void:
	_beat = Beat.KO
	_hero.flip = true
	_hero.position = Vector2(HERO_REST.x + 60.0, FLOOR_Y)
	_hero.play("ko")
	_set_message("")
	var tw := _new_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_flash, "modulate:a", 1.0, FADE_SECONDS)
	tw.tween_callback(_finish)
	_redraw()

## The white is full: the battle goes, `finished` lets her menu open beneath the white, and the white fades away over it.
func _finish() -> void:
	_playing = false
	_beat = Beat.NONE
	_nav.reset()
	_show_battle(false)
	finished.emit()
	var tw := _new_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, FADE_SECONDS)
	tw.tween_callback(_end_fade)

func _end_fade() -> void:
	visible = false

## Whether the white is still fading away over her menu.
func is_fading() -> bool:
	return visible and not _playing

func _show_battle(shown: bool) -> void:
	for node in [_sky, _backdrop, _stage, _message_window, _command_window, _status_window]:
		node.visible = shown

func _hero_reset() -> void:
	_hero.position = HERO_REST
	_hero.flip = true  # the sheets face right; he faces the truck
	_hero.play("idle")

func _new_tween() -> Tween:
	_kill(_tween)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return _tween

func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()

func _process(delta: float) -> void:
	if not _playing:
		_nav.reset()
		return
	if _beat == Beat.COMMAND:
		var step := _nav.step(Controls.last_stick, delta)
		if step.y != 0:
			move(step.y)

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

# --- drawing ---

func _set_message(text: String) -> void:
	_message = text
	_message_label.text = text
	_message_window.visible = text != ""

func _redraw() -> void:
	if not is_node_ready() or _model == null:
		return
	_message_label.text = _message
	_message_window.visible = _message != ""
	_command_window.visible = _beat == Beat.COMMAND
	for child in _command_column.get_children():
		child.queue_free()
	for text in row_texts():
		var label := Label.new()
		label.text = text
		label.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		_style(label, COL_TEXT, FONT_MAIN)
		_command_column.add_child(label)
	_update_status()

func _update_status() -> void:
	if _hp_label.get_parent() == null:
		return  # the windows are not built yet
	var shown := clampi(int(ceil(hp_display)), 0, MAX_HP)
	_hp_label.text = "HP %d/%d" % [shown, MAX_HP]
	var fraction := clampf(hp_display / float(MAX_HP), 0.0, 1.0)
	_hp_fill.size.x = _hp_back.size.x * fraction
	_hp_fill.color = Color(0.35, 0.9, 0.45) if fraction > 0.5 else (Color(1.0, 0.85, 0.3) if fraction > 0.25 else Color(1.0, 0.35, 0.3))

func _style(label: Label, color: Color, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
