class_name OpeningScene
extends CanvasLayer
## The opening: a JRPG battle against trucks. A sunny street, the commuter on the right and the truck on the left, a message window
## along the top, a life bar for each truck under it, and the command and status windows along the bottom. It goes in turns: yours
## (an arrow bobs over him and the commands are up), then the trucks' (the arrow moves to the truck, which charges and leaves). Each
## round is one third of your HP: the trucks roll in (INTRO), you pick a command (COMMAND), your action plays with its result line
## (ACTION, then RESULT while you read it for a moment), the trucks take their turn (HIT), and after the last round you are knocked
## out (KO) and the screen fades to white. The first Dodge works: the truck misses, that round does not count, and a second truck
## rolls in and stays, so both hit in turn from then on. The umbrella angers the truck it hits for good (angry eyebrows, a road-rage
## charge) and does nothing to its life bar. In the last round an old lady is in the road: every command but saving her is grayed
## out, you shove her clear and the trucks run you over. It pauses the game (the live world underneath must not touch the player),
## drives an OpeningModel from keys, the D-pad and the left stick (through NavStep), and marks every key and pad event handled while
## it plays, so there is no skip of the scene itself. Enter during an animation finishes it, and Enter while you read a result lets
## the trucks go at once. When the last fade-to-white is full it hides the battle, emits `finished` (the goddess's menu opens
## beneath, with the tree still paused) and fades the white away over her menu. Layer 45, added last so it sees input first.

signal finished

enum Beat { NONE, INTRO, COMMAND, ACTION, RESULT, HIT, KO }

const MAX_HP := 30
## The trucks' life bars start full and nothing you do ever moves them.
const TRUCK_HP := 9999
const BACKDROP := "res://assets/opening/backdrop.png"
## The layout on the 640x360 screen: the street, the fighters standing on FLOOR_Y, the message window on top, the trucks' life bars
## under it, and the command and status windows along the bottom. The command window holds up to OpeningDef.MAX_ROWS rows; a test
## pins the arithmetic.
const FLOOR_Y := 262.0
const HERO_REST := Vector2(470.0, FLOOR_Y)
## Where the old lady stands in the road (you stand there once you have shoved her clear), where she walks in from, and where she
## lands out of the way.
const GRANDMA_X := 400.0
const GRANDMA_START_X := 700.0
const SAFE_X := 585.0
## One truck alone stands at TRUCK_REST_X. Once the second has come they stand side by side, a little smaller, the front one and the
## one behind it (and a touch higher).
const TRUCK_REST_X := 185.0
const TRUCK_SLOTS_TWO := [255.0, 105.0]
const TRUCK_SCALE_TWO := 0.8
const REAR_LIFT := 8.0
const TRUCK_HALF_WIDTH := 125.0  # the art's half width: a truck stops this far (times its scale) plus HIT_GAP short of its target
const HIT_GAP := 10.0
const FIGHT_GAP := 80.0  # how far in front of the front truck he stands to swing the umbrella
const TRUCK_CAB_OFFSET := 70.0  # the turn arrow floats over the cab, this far right of the truck's middle
const TRUCK_MARKER_HEIGHT := 150.0  # and this high (times its scale): above the tilted charging frames too
const TRUCK_OFF_LEFT := -190.0
const TRUCK_OFF_RIGHT := 820.0
const MESSAGE_RECT := Rect2(100.0, 10.0, 440.0, 40.0)
const ENEMY_RECT := Rect2(10.0, 58.0, 150.0, 58.0)
const COMMAND_RECT := Rect2(10.0, 264.0, 140.0, 92.0)
const STATUS_RECT := Rect2(390.0, 300.0, 240.0, 54.0)
const ROW_HEIGHT := 13.0
const FONT_MAIN := 10
const FONT_SMALL := 8
const COL_TEXT := Color(0.9, 0.96, 1.0)
const COL_DISABLED := Color(0.45, 0.52, 0.64)
const COL_NAME := Color(1.0, 0.85, 0.45)
const COL_ENEMY := Color(1.0, 0.7, 0.6)
const COL_ENEMY_BAR := Color(0.95, 0.5, 0.3)
const COL_HONK := Color(1.0, 0.35, 0.25)
const RAGE_TINT := Color(1.0, 0.5, 0.5)
const INTRO_SECONDS := 0.9
const INTRO_STAGGER := 0.35
const GRANDMA_SECONDS := 1.2
const RESULT_HOLD := 2.2  # how long your result line stays up before the trucks go by themselves
const CHARGE_SECONDS := 0.45
const RAGE_REV_SECONDS := 0.55
const RAGE_CHARGE_SECONDS := 0.28
const FLASH_SECONDS := 0.3
const FADE_SECONDS := 1.0
const TURN_TAGS := {"player": "YOUR TURN", "truck": "TRUCK'S TURN"}
const RAGE_LINE := "The truck is in a road rage!"
## The same truck in different tints, so each round's (and each of the two) can be told apart.
const TRUCK_TINTS := [Color(1, 1, 1), Color(1.0, 0.86, 0.78), Color(0.84, 1.0, 0.86)]
## Choice id -> the clip the commuter plays for it; an id with no clip just stands.
const ACTION_CLIPS := {"fight": "fight", "dodge": "dodge", "jump": "jump", "pray": "pray", "run": "run", "grandma": "save"}

## The shown HP, animated down when the truck hits (the real value is `_hp`).
var hp_display := float(MAX_HP):
	set(value):
		hp_display = value
		_update_status()

var _model: OpeningModel
var _playing := false
var _beat := Beat.NONE
var _turn := ""
var _turn_actor: OpeningActor
var _hp := MAX_HP
var _message := ""
var _hero_home := HERO_REST.x  # where he stands this round (the old lady's spot after he has saved her)
var _angry := [false, false]
var _rage_attacks := 0
var _pops: Array = []
var _nav := NavStep.new()
var _tween: Tween
var _fx: Tween
var _bounce: Tween
var _sky := ColorRect.new()
var _backdrop := Sprite2D.new()
var _stage := Node2D.new()
var _truck := OpeningActor.new()
var _truck2 := OpeningActor.new()
var _trucks: Array = []
var _grandma := OpeningActor.new()
var _hero := OpeningActor.new()
var _flash := ColorRect.new()
var _marker := Node2D.new()
var _bob := Node2D.new()
var _tag := Label.new()
var _message_window := PanelContainer.new()
var _message_label := Label.new()
var _enemy_window := PanelContainer.new()
var _enemy_names: Array = []
var _enemy_hp_labels: Array = []
var _enemy_rows: Array = []
var _enemy_backs: Array = []
var _enemy_fills: Array = []
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
	_trucks = [_truck, _truck2]

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
	_truck2.name = "Truck2"  # the one behind: drawn first
	_truck2.setup("truck")
	_truck2.visible = false
	_stage.add_child(_truck2)
	_truck.name = "Truck"
	_truck.setup("truck")
	_stage.add_child(_truck)
	_grandma.name = "Grandma"
	_grandma.setup("grandma")
	_grandma.flip = true  # the sheets face right; she faces the trucks, like him
	_grandma.visible = false
	_stage.add_child(_grandma)
	_hero.name = "Commuter"
	_hero.setup("commuter")
	_stage.add_child(_hero)
	_build_windows()
	_build_marker()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 1)
	_flash.size = Vector2(640, 360)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _window_style() -> StyleBoxFlat:
	# The game's window style (the voice's pop-ups): translucent blue with a glowing border.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.1, 0.28, 0.88)
	style.border_color = Color(0.45, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	return style

func _build_windows() -> void:
	var style := _window_style()
	for pair in [[_message_window, MESSAGE_RECT, "Message"], [_enemy_window, ENEMY_RECT, "Enemy"], [_command_window, COMMAND_RECT, "Commands"], [_status_window, STATUS_RECT, "Status"]]:
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
	_build_enemy_window()
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

## One row per truck: its name and HP, and a bar under them. The bars start full and stay full.
func _build_enemy_window() -> void:
	var box := VBoxContainer.new()
	box.name = "Rows"
	box.add_theme_constant_override("separation", 3)
	_enemy_window.add_child(box)
	var bar_width := ENEMY_RECT.size.x - 14.0
	for i in 2:
		var row := VBoxContainer.new()
		row.name = "Row%d" % i
		row.add_theme_constant_override("separation", 1)
		var top := HBoxContainer.new()
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style(name_label, COL_ENEMY, FONT_SMALL)
		var hp_label := Label.new()
		_style(hp_label, COL_TEXT, FONT_SMALL)
		top.add_child(name_label)
		top.add_child(hp_label)
		row.add_child(top)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 6)
		var back := ColorRect.new()
		back.color = Color(0.0, 0.03, 0.12, 0.9)
		back.size = Vector2(bar_width, 6)
		var fill := ColorRect.new()
		fill.color = COL_ENEMY_BAR
		fill.size = Vector2(bar_width, 6)
		bar.add_child(back)
		bar.add_child(fill)
		row.add_child(bar)
		box.add_child(row)
		_enemy_names.append(name_label)
		_enemy_hp_labels.append(hp_label)
		_enemy_rows.append(row)
		_enemy_backs.append(back)
		_enemy_fills.append(fill)

## The turn marker: a gold arrow that bobs over whoever's turn it is, with a tag saying whose. `Bob` moves, the marker is placed.
func _build_marker() -> void:
	_marker.name = "TurnMarker"
	_marker.visible = false
	_bob.name = "Bob"
	_marker.add_child(_bob)
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([Vector2(-10, -18), Vector2(10, -18), Vector2(0, 0)])
	outline.color = Color(0.1, 0.05, 0.0)
	_bob.add_child(outline)
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.polygon = PackedVector2Array([Vector2(-7, -15), Vector2(7, -15), Vector2(0, -4)])
	arrow.color = COL_NAME
	_bob.add_child(arrow)
	_tag.name = "Tag"
	_tag.position = Vector2(-50, -34)
	_tag.size = Vector2(100, 14)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_tag, COL_NAME, FONT_MAIN)
	_tag.add_theme_constant_override("outline_size", 3)
	_tag.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_bob.add_child(_tag)
	add_child(_marker)

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
	_angry = [false, false]
	_rage_attacks = 0
	_pops.clear()
	_clear_pops()
	_hero_home = HERO_REST.x
	_stage.position = Vector2.ZERO
	_grandma.visible = false
	_set_turn("")
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

## Whose turn is highlighted: "player" while the commands are up, "truck" while the trucks charge, "" otherwise.
func turn() -> String:
	return _turn

## The commuter's HP (the number, not the animated bar).
func hp() -> int:
	return _hp

func commuter() -> OpeningActor:
	return _hero

## The front truck (the first of the one or two).
func truck() -> OpeningActor:
	return _truck

func truck_at(i: int) -> OpeningActor:
	return _trucks[i]

func grandma() -> OpeningActor:
	return _grandma

func trucks_shown() -> int:
	return _trucks.filter(func(t: OpeningActor) -> bool: return t.visible).size()

func truck_angry(i: int) -> bool:
	return _angry[i]

## How many road-rage charges have started (an angry truck's every attack is one).
func rage_attacks() -> int:
	return _rage_attacks

## The numbers that have floated up over a truck, and other words that have popped over one ("0", "HONK!"), this battle.
func pops_shown() -> Array:
	return _pops

## The truck's HP as its life bar shows it.
func truck_hp_text(i: int) -> String:
	return (_enemy_hp_labels[i] as Label).text

## How full the truck's life bar is, 0 to 1.
func truck_bar_fraction(i: int) -> float:
	return (_enemy_fills[i] as ColorRect).size.x / (_enemy_backs[i] as ColorRect).size.x

## What the message window says: the round's prompt, then the result of the choice, then the damage taken.
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

## Whether row `i` can be taken (the old lady grays out all the others).
func row_enabled(i: int) -> bool:
	return _model != null and _beat == Beat.COMMAND and _model.enabled(i)

func move(step: int) -> void:
	if _playing and _beat == Beat.COMMAND:
		_model.move(step)
		_redraw()

## Enter. At the command window it takes the highlighted command; once you have read the result it sends the trucks now (they go by
## themselves after a moment anyway); during any animation it finishes that animation at once.
func act() -> void:
	if not _playing:
		return
	match _beat:
		Beat.COMMAND:
			_model.act()
			_start_action(_model.chosen())
		Beat.RESULT:
			_start_truck_turn()
		_:
			skip()

## Finishes whatever animation is playing, running its steps to the end.
func skip() -> void:
	for t in [_tween, _fx]:
		if t != null and t.is_valid() and t.is_running():
			t.custom_step(100.0)
	if _fx != null and _fx.is_valid() and _fx.is_running():
		_fx.custom_step(100.0)  # a step can start one (the umbrella's jolt): finish that too

# --- where things stand ---

func _slot_x(i: int, count: int) -> float:
	return TRUCK_REST_X if count == 1 else float(TRUCK_SLOTS_TWO[i])

func _scale_for(count: int) -> float:
	return 1.0 if count == 1 else TRUCK_SCALE_TWO

func _front_x(i: int) -> float:
	var count := _model.trucks_on_screen()
	return _slot_x(i, count) + TRUCK_HALF_WIDTH * _scale_for(count)

## Where truck `i` stops so that its front just touches him where he stands.
func _hit_x(i: int) -> float:
	return _hero_home - TRUCK_HALF_WIDTH * _scale_for(_model.trucks_on_screen()) - HIT_GAP

func _tint(i: int) -> Color:
	return TRUCK_TINTS[(_model.truck() + i) % TRUCK_TINTS.size()]

# --- the choreography ---

## The trucks roll in from the left (the second a moment behind the first), the old lady shuffles in from the right when she is
## due, and then it is your turn.
func _begin_intro() -> void:
	_beat = Beat.INTRO
	_set_turn("")
	var count := _model.trucks_on_screen()
	_show_trucks(count)
	_set_message(_model.prompt())
	var tw := _new_tween()
	for i in count:
		if i > 0:
			tw.parallel()
		var step := tw.tween_property(_trucks[i], "position:x", _slot_x(i, count), INTRO_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if i > 0:
			step.set_delay(INTRO_STAGGER)
	if _model.grandma_here():
		_grandma.visible = true
		_grandma.position = Vector2(GRANDMA_START_X, FLOOR_Y)
		_grandma.play("idle")
		tw.parallel().tween_property(_grandma, "position:x", GRANDMA_X, GRANDMA_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_enter_command)
	_redraw()

## Puts the trucks off the left of the screen at their size and tint (and angry or not), ready to roll in.
func _show_trucks(count: int) -> void:
	for i in 2:
		var t: OpeningActor = _trucks[i]
		t.visible = i < count
		t.scale = Vector2.ONE * _scale_for(count)
		t.position = Vector2(TRUCK_OFF_LEFT, FLOOR_Y - (REAR_LIFT if i == 1 else 0.0))
		t.modulate = _tint(i)
		t.play("idle_angry" if _angry[i] else "idle")
	_update_enemy(count)

func _enter_command() -> void:
	_beat = Beat.COMMAND
	_nav.reset()
	_set_turn("player", _hero)
	_redraw()

func _start_action(id: String) -> void:
	_beat = Beat.ACTION
	_set_turn("")
	_set_message(_model.result_line())
	_hero.play(ACTION_CLIPS.get(id, "idle"))
	var home := _hero_home
	var tw := _new_tween()
	match id:
		"fight":  # step up to the truck, swing (the truck takes it badly), step back
			tw.tween_property(_hero, "position:x", _front_x(0) + FIGHT_GAP, 0.25)
			tw.tween_callback(_umbrella_hit)
			tw.tween_interval(0.45)
			tw.tween_property(_hero, "position:x", home, 0.25)
		"dodge":  # a hop back out of the way
			tw.tween_property(_hero, "position:x", home + 34.0, 0.2)
			tw.tween_interval(0.4)
			tw.tween_property(_hero, "position:x", home, 0.2)
		"jump":  # up and down in an arc
			tw.tween_interval(0.15)
			tw.tween_property(_hero, "position:y", FLOOR_Y - 60.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_hero, "position:y", FLOOR_Y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"run":  # off toward the edge of the screen, then back
			_hero.flip = false
			tw.tween_property(_hero, "position:x", home + 90.0, 0.6)
			tw.tween_callback(func() -> void: _hero.flip = true)
			tw.tween_property(_hero, "position:x", home, 0.5)
		"grandma":  # dash to her, shove her clear, and stand where she stood
			tw.tween_property(_hero, "position:x", GRANDMA_X, 0.3)
			tw.tween_callback(_shove_grandma)
			tw.tween_interval(0.55)
		_:
			tw.tween_interval(1.0)
	tw.tween_callback(_action_done)
	_redraw()

## The umbrella lands: the front truck gets angry for the rest of the fight, a zero floats up, and its life bar does not move.
func _umbrella_hit() -> void:
	var truck: OpeningActor = _trucks[0]
	_angry[0] = true
	truck.play("idle_angry")
	_pop("0", Vector2(_front_x(0) - 30.0, FLOOR_Y - truck.height()), Color.WHITE, FONT_MAIN + 8)
	var fill: ColorRect = _enemy_fills[0]
	fill.color = Color.WHITE
	fill.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(fill, "color", COL_ENEMY_BAR, 0.4)
	_kill(_fx)
	var x := truck.position.x
	_fx = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fx.tween_property(truck, "position:x", x + 5.0, 0.05)
	_fx.tween_property(truck, "position:x", x, 0.08)

## She is thrown clear onto the pavement behind him, and he stands in the road where she stood.
func _shove_grandma() -> void:
	_hero_home = GRANDMA_X
	_grandma.play("safe")
	_kill(_fx)
	_fx = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_fx.tween_property(_grandma, "position:x", SAFE_X, 0.6).set_ease(Tween.EASE_OUT)
	_fx.tween_property(_grandma, "position:y", FLOOR_Y - 40.0, 0.25).set_ease(Tween.EASE_OUT)
	_fx.chain().tween_property(_grandma, "position:y", FLOOR_Y - 12.0, 0.3).set_ease(Tween.EASE_IN)

## Your result stays up for a moment (Enter sends the trucks at once), then the trucks' turn starts on its own.
func _action_done() -> void:
	_hero_reset()
	_beat = Beat.RESULT
	_redraw()
	var tw := _new_tween()
	tw.tween_interval(RESULT_HOLD)
	tw.tween_callback(_start_truck_turn)

## The trucks' turn: each one on the street charges, one after the other, and leaves off the right of the screen. Normally every
## charge hits (the round's damage shared between them); after the first Dodge the one truck misses instead and goes straight by.
func _start_truck_turn() -> void:
	_beat = Beat.HIT
	var count := _model.trucks_on_screen()
	var miss := _model.free_dodge()
	var last_round := _model.truck() + 1 >= _model.truck_count()
	var round_damage := ceili(float(MAX_HP) / float(_model.truck_count()))
	var per_hit := ceili(float(round_damage) / float(count))
	_set_turn("truck", _trucks[0])
	var tw := _new_tween()
	for i in count:
		if i > 0:
			tw.tween_callback(_recover)
		_queue_attack(tw, i, miss, last_round and i == count - 1, per_hit)
	tw.tween_callback(_after_hit)
	_redraw()

func _queue_attack(tw: Tween, i: int, miss: bool, last: bool, per_hit: int) -> void:
	var truck: OpeningActor = _trucks[i]
	var rage: bool = _angry[i] and not miss
	tw.tween_callback(_attack_begin.bind(i, rage))
	if rage:  # the rev: shaking on the spot, going red, before it goes
		tw.tween_method(_rev.bind(i), 0.0, 1.0, RAGE_REV_SECONDS)
	var charge := RAGE_CHARGE_SECONDS if rage else CHARGE_SECONDS
	tw.tween_property(truck, "position:x", _hit_x(i), charge).set_trans(Tween.TRANS_CUBIC if rage else Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if miss:  # he hops over it as it comes, and it keeps going
		tw.tween_callback(_hero_leap)
		tw.tween_property(truck, "position:x", TRUCK_OFF_RIGHT, 0.6)
	else:
		tw.tween_callback(_impact.bind(last, per_hit, rage))
		tw.tween_interval(0.55)
		tw.tween_property(truck, "position:x", TRUCK_OFF_RIGHT, 0.6)

func _attack_begin(i: int, rage: bool) -> void:
	_set_turn("truck", _trucks[i])
	var truck: OpeningActor = _trucks[i]
	truck.play("charge_angry" if rage else "charge")
	if rage:
		_rage_attacks += 1
		_set_message(RAGE_LINE)
		_pop("HONK!", Vector2(_front_x_of(i) + 30.0, FLOOR_Y - 80.0), COL_HONK, FONT_MAIN + 6)

func _front_x_of(i: int) -> float:
	return (_trucks[i] as OpeningActor).position.x + TRUCK_HALF_WIDTH * _scale_for(_model.trucks_on_screen())

func _rev(t: float, i: int) -> void:
	var truck: OpeningActor = _trucks[i]
	truck.position.x = _slot_x(i, _model.trucks_on_screen()) + sin(t * 70.0) * 3.0
	truck.modulate = _tint(i).lerp(RAGE_TINT, 0.5 + 0.5 * sin(t * 40.0))

func _hero_leap() -> void:
	_hero.play("dodge")
	_kill(_fx)
	_fx = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fx.tween_property(_hero, "position:y", FLOOR_Y - 60.0, 0.2).set_ease(Tween.EASE_OUT)
	_fx.tween_interval(0.2)
	_fx.tween_property(_hero, "position:y", FLOOR_Y, 0.2).set_ease(Tween.EASE_IN)

## Between two trucks of one turn: he gets back up where he stands.
func _recover() -> void:
	_kill(_fx)
	_flash.modulate.a = 0.0
	hp_display = float(_hp)
	_stage.position = Vector2.ZERO
	_hero_reset()

func _impact(last: bool, per_hit: int, rage: bool) -> void:
	EventBus.world_event.emit("opening_hit", {})
	var before := _hp
	_hp = 0 if last else maxi(0, _hp - per_hit)
	_set_message("You take %d damage!" % maxi(1, before - _hp))
	_hero.play("hurt")
	_kill(_fx)
	_fx = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_fx.tween_property(self, "hp_display", float(_hp), 0.5)
	_flash.modulate.a = 1.0 if rage else 0.9
	_fx.tween_property(_flash, "modulate:a", 0.0, FLASH_SECONDS)
	_fx.tween_property(_hero, "position:x", _hero_home + (90.0 if rage else 60.0), 0.35).set_ease(Tween.EASE_OUT)
	_fx.tween_property(_hero, "position:y", FLOOR_Y - (60.0 if rage else 44.0), 0.17).set_ease(Tween.EASE_OUT)
	_fx.chain().tween_property(_hero, "position:y", FLOOR_Y, 0.18).set_ease(Tween.EASE_IN)
	if rage:
		_fx.tween_method(_shake_stage, 0.0, 1.0, 0.4)

func _shake_stage(t: float) -> void:
	_stage.position = Vector2(sin(t * 90.0) * 5.0, cos(t * 70.0) * 3.0) * (1.0 - t)

func _after_hit() -> void:
	_kill(_fx)
	_flash.modulate.a = 0.0  # a skipped hit reaches here with the impact's flash still up and its fade killed
	_stage.position = Vector2.ZERO
	hp_display = float(_hp)
	_set_turn("")
	_model.act()
	if _model.done():
		_start_ko()
	else:
		_hero_reset()
		_begin_intro()

func _start_ko() -> void:
	_beat = Beat.KO
	_hero.flip = true
	_hero.position = Vector2(_hero_home + 60.0, FLOOR_Y)
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
	_set_turn("")
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
	for node in [_sky, _backdrop, _stage, _message_window, _enemy_window, _command_window, _status_window]:
		node.visible = shown

func _hero_reset() -> void:
	_hero.position = Vector2(_hero_home, FLOOR_Y)
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
	if _turn == "truck":
		_place_marker()  # the arrow rides along with the truck as it charges
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

## Highlights whose turn it is: the arrow bobs over `actor` and the tag says whose. "" puts it away.
func _set_turn(who: String, actor: OpeningActor = null) -> void:
	_turn = who
	_turn_actor = actor
	_marker.visible = who != "" and actor != null
	if not _marker.visible:
		_kill(_bounce)
		return
	_tag.text = TURN_TAGS.get(who, "")
	_place_marker()
	if _bounce == null or not _bounce.is_valid():
		_bounce = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_bounce.tween_property(_bob, "position:y", -5.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bounce.tween_property(_bob, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Over his head, or over the truck's cab.
func _place_marker() -> void:
	if _turn_actor == null:
		return
	if _turn == "truck":
		_marker.position = _turn_actor.position + Vector2(TRUCK_CAB_OFFSET, -TRUCK_MARKER_HEIGHT - 6.0) * _turn_actor.scale
	else:
		_marker.position = _turn_actor.position + Vector2(0.0, -_turn_actor.height() - 6.0)

## Something floats up from `at` and fades: a damage number, or the honk.
func _pop(text: String, at: Vector2, color: Color, size: int) -> void:
	_pops.append(text)
	var label := Label.new()
	label.name = "Pop"
	label.text = text
	label.z_index = 10
	label.size = Vector2(80, 20)
	label.position = at - Vector2(40.0, 14.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(label, color, size)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_stage.add_child(label)
	var tw := label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 24.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(label.queue_free)

func _clear_pops() -> void:
	for child in _stage.get_children():
		if child is Label:
			child.free()

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
		_command_column.remove_child(child)
		child.free()
	var texts := row_texts()
	for i in texts.size():
		var label := Label.new()
		label.text = texts[i]
		label.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		_style(label, COL_TEXT if _model.enabled(i) else COL_DISABLED, FONT_MAIN)
		_command_column.add_child(label)
	_update_status()

## One life bar per truck on the street, each full: nothing you do takes anything off.
func _update_enemy(count: int) -> void:
	var names := ["Truck"] if count == 1 else ["Truck A", "Truck B"]
	for i in 2:
		(_enemy_rows[i] as Control).visible = i < count
		if i < count:
			(_enemy_names[i] as Label).text = names[i]
			(_enemy_hp_labels[i] as Label).text = "HP %d/%d" % [TRUCK_HP, TRUCK_HP]
	var height := 2.0 * 7.0 + count * 17.0 + (count - 1) * 3.0
	_enemy_window.custom_minimum_size.y = height
	_enemy_window.size.y = height

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
