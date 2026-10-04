class_name MovementSandbox
extends Node2D
## A room to feel the movement profiles in, on real collision: a floor, three ledges (a partial hop, a full base jump,
## and one that needs the boost) and a body driven by GroundAirStep. Keys 1 to 3 pick biped, slime or wolf; B toggles the
## stage-4 jump boost. Not the game: it does not use Player and touches nothing else. Run it with
##   godot --path . res://scenes/movement_sandbox.tscn

const LEDGES := [Rect2(400, -40, 80, 40), Rect2(520, -60, 80, 60), Rect2(640, -100, 80, 100)]
const FLOOR := Rect2(0, 0, 1400, 40)
const START := Vector2(100, 0)
## The stage-4 jump_height (185%) as a launch boost: rise scales with it squared.
const BOOST_JUMP_HEIGHT := 1.85

## When set, replaces the keyboard and pad. `jump_pressed` is consumed (cleared) by the next physics frame, so a test
## sets it once; `jump_held` stays until the test clears it.
var scripted: MoveInput = null
var profile: MovementProfile
var state := MoveState.new()
var body: CharacterBody2D
var boosted := false

var _spring := SquashSpring.new()
var _rect: ColorRect
var _label: Label
var _last := {"rise": 0.0, "airtime": 0.0}
var _in_jump := false
var _takeoff_y := 0.0
var _top_y := 0.0
var _air_ticks := 0
var _dt := 1.0 / 60.0

func _ready() -> void:
	set_profile("slime")
	_block(FLOOR)
	for r in LEDGES:
		_block(r)
	body = CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = BodyConfig.size()
	shape.shape = box
	body.add_child(shape)
	body.position = START + Vector2(0, -BodyConfig.BOTTOM)
	add_child(body)
	_rect = ColorRect.new()
	_rect.size = BodyConfig.size()
	_rect.pivot_offset = Vector2(_rect.size.x / 2.0, _rect.size.y)
	_rect.color = Color(0.45, 0.85, 0.5)
	add_child(_rect)
	var cam := Camera2D.new()
	cam.position = Vector2(360, -130)
	add_child(cam)
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(8, 8)
	layer.add_child(_label)
	add_child(layer)

func set_profile(id: String) -> void:
	var p := MovementProfile.of(id)
	if p == null:
		return
	profile = p
	state = MoveState.new()  # no momentum or timers carry over a switch
	if body != null:
		body.velocity = Vector2.ZERO

func set_boost(on: bool) -> void:
	boosted = on

## The most recent completed jump: its rise (px above where it left the floor) and its airtime (s).
func last_jump() -> Dictionary:
	return _last

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			set_profile(MovementProfile.IDS[key.keycode - KEY_1])
		KEY_B:
			set_boost(not boosted)

func _physics_process(delta: float) -> void:
	_dt = delta
	var i := _read_input()
	var was_on_floor := body.is_on_floor()
	i.on_floor = was_on_floor
	GroundAirStep.step(state, i, profile, delta, 1.0, sqrt(BOOST_JUMP_HEIGHT) if boosted else 1.0)
	if state.launched != "":
		_in_jump = true  # the take-off height is the position before this frame's move, as MovementSim measures it
		_takeoff_y = body.global_position.y
		_top_y = _takeoff_y
		_air_ticks = 0
	var fall_speed := state.velocity.y
	body.velocity = state.velocity
	body.move_and_slide()
	state.velocity = body.velocity
	if _in_jump:
		_air_ticks += 1
		_top_y = minf(_top_y, body.global_position.y)
		if _air_ticks > 1 and body.is_on_floor():
			_in_jump = false
			_last = {"rise": _takeoff_y - _top_y, "airtime": _air_ticks * delta}
	if not was_on_floor and body.is_on_floor():
		_spring.land(fall_speed)
	_spring.update(state.velocity.y, delta)
	_draw_body()

func _read_input() -> MoveInput:
	var i := MoveInput.new()
	if scripted != null:
		i.dir = scripted.dir
		i.jump_pressed = scripted.jump_pressed
		i.jump_held = scripted.jump_held
		scripted.jump_pressed = false
		return i
	i.dir = Input.get_axis("move_left", "move_right")
	i.jump_pressed = Input.is_action_just_pressed("jump")
	i.jump_held = Input.is_action_pressed("jump")
	return i

func _draw_body() -> void:
	_rect.scale = _spring.sprite_scale()
	_rect.position = body.position + Vector2(-_rect.size.x / 2.0, BodyConfig.BOTTOM - _rect.size.y)
	_label.text = "%s   speed %d   boost %s   last jump: rise %.1f px, air %.2f s\n1 biped   2 slime   3 wolf   B boost" % [
		profile.id, int(absf(body.velocity.x)), "on" if boosted else "off", _last["rise"], _last["airtime"]]

func _block(r: Rect2) -> void:
	var b := StaticBody2D.new()
	b.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	b.add_child(shape)
	var look := ColorRect.new()
	look.size = r.size
	look.position = -r.size / 2.0
	look.color = Color(0.3, 0.3, 0.38)
	b.add_child(look)
	add_child(b)
