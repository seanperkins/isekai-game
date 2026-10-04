class_name MovementSandbox
extends Node2D
## A room to feel the movement profiles in, on real collision: a floor, three ledges (a partial hop, a full base jump,
## and one that needs the boost) and a body driven by GroundAirStep. Keys 1 to 3 pick biped, slime or wolf; B toggles the
## stage-4 jump boost. Not the game: it does not use Player and touches nothing else. Run it with
##   godot --path . res://scenes/movement_sandbox.tscn

const LEDGES := [Rect2(400, -40, 80, 40), Rect2(520, -60, 80, 60), Rect2(640, -100, 80, 100)]
const FLOOR := Rect2(0, 0, 1400, 40)
## Walls at both ends, so holding a direction stops at the end of the floor instead of running off it.
const WALLS := [Rect2(-40, -400, 40, 440), Rect2(1400, -400, 40, 440)]
## A low tunnel: a 12 px gap above the floor, so only a flat slime fits.
const TUNNEL := Rect2(900, -52, 240, 40)
## A pillar 110 px from the right end wall: a shaft to climb by wall jumps.
const SHAFT_WALL := Rect2(1260, -300, 40, 300)
## How far from a wall (px) still counts as touching it for the wall verbs.
const WALL_RANGE := 6.0
const START := Vector2(100, 0)
## The sprite's tint while a verb runs.
const VERB_TINT := Color(1.5, 1.3, 0.7)
## The stage-4 jump_height (185%) as a launch boost: rise scales with it squared.
const BOOST_JUMP_HEIGHT := 1.85
## How long the slime's landing frame shows (the player's LAND_SQUASH_SECONDS).
const LAND_SECONDS := 0.12
## How long a bounce shows as a ball, how fast the stand-in ball turns (rad/s), and how fast the crawl wobble eases in and out.
const BALL_SECONDS := 0.3
const BALL_SPIN := 12.0
const CRAWL_EASE := 8.0

## When set, replaces the keyboard and pad. `jump_pressed` is consumed (cleared) by the next physics frame, so a test
## sets it once; `jump_held` stays until the test clears it.
var scripted: MoveInput = null
var profile: MovementProfile
var state := MoveState.new()
var body: CharacterBody2D
var boosted := false

var _spring := SquashSpring.new()
var _rect: ColorRect
var _shape: CollisionShape2D
var _box: RectangleShape2D
var _sprite: Sprite2D
var _sheet: SpriteSheet
var _animator: SlimeAnimator
var _clip := ""
var _facing := 1
var _land_timer := 0.0
var _landing := false
var _landing_speed := 0.0
var _ball_time := 0.0
var _crawl_phase := 0.0
var _crawl_gain := 0.0
var _cam: Camera2D
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
	for r in WALLS:
		_block(r)
	_block(TUNNEL)
	_block(SHAFT_WALL)
	body = CharacterBody2D.new()
	body.name = "Body"
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	_box = RectangleShape2D.new()
	_box.size = BodyConfig.size()
	_shape.shape = _box
	body.add_child(_shape)
	body.position = START + Vector2(0, -BodyConfig.BOTTOM)
	add_child(body)
	_rect = ColorRect.new()
	_rect.size = BodyConfig.size()
	_rect.pivot_offset = Vector2(_rect.size.x / 2.0, _rect.size.y)
	_rect.color = Color(0.45, 0.85, 0.5)
	add_child(_rect)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	_cam = Camera2D.new()
	_cam.name = "Camera"
	_cam.position = Vector2(START.x, -130)
	add_child(_cam)
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(8, 8)
	layer.add_child(_label)
	add_child(layer)
	_set_look(profile.id)

func set_profile(id: String) -> void:
	var p := MovementProfile.of(id)
	if p == null:
		return
	profile = p
	state = MoveState.new()  # no momentum or timers carry over a switch
	_ball_time = 0.0
	_landing = false
	if body != null:
		body.velocity = Vector2.ZERO
	if _sprite != null:
		_set_look(id)

## The species id while its sprite shows, "placeholder" while the colour rect stands in (no art, or its sheet is missing).
func look() -> String:
	return profile.id if _sheet != null else "placeholder"

## The clip playing, "" for the placeholder.
func clip() -> String:
	return _clip

## A fresh animator and sheet for `id`, or the colour rect when it has none.
func _set_look(id: String) -> void:
	_sheet = SpeciesLook.sheet_for(id)
	_animator = null
	_clip = ""
	if _sheet != null:
		_animator = SlimeAnimator.new(SpeciesLook.clips_for(id))
		_animator.play(SpeciesLook.clip_for(id, true, 0.0, 0.0, 0.0))
	_sprite.visible = _sheet != null
	_rect.visible = _sheet == null

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
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_profile(MovementProfile.IDS[key.keycode - KEY_1])
		KEY_B:
			set_boost(not boosted)

func _physics_process(delta: float) -> void:
	_dt = delta
	var i := _read_input()
	var was_on_floor := body.is_on_floor()
	i.on_floor = was_on_floor
	i.clearance_above = _clearance()
	i.wall_side = _wall_side(i.dir)
	VerbRunner.step(state, i, profile, delta, 1.0, sqrt(BOOST_JUMP_HEIGHT) if boosted else 1.0)
	_apply_box()
	_judge_landing()
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
	_land_timer = maxf(0.0, _land_timer - delta)
	if not was_on_floor and body.is_on_floor():
		_landing = true  # judged next tick, once the step has said whether this landing bounced
		_landing_speed = fall_speed
	if absf(state.velocity.x) > 1.0:
		_facing = 1 if state.velocity.x > 0.0 else -1
	_spring.update(state.velocity.y, delta)
	_cam.position.x = clampf(body.position.x, 320.0, FLOOR.size.x - 320.0)
	_draw_body(delta)

## A bounce (timed rebound, hold bounce, wall bounce) is a ball, not a squash: it drops any squash a landing started and
## shows the ball. Any other landing squashes and shows the landing frame, one tick after touching down.
func _judge_landing() -> void:
	if state.launched == "rebound" or state.launched == "bounce" or state.wall_bounced:
		_ball_time = BALL_SECONDS
		_spring.calm()
		_land_timer = 0.0
		_landing = false
	elif _landing:
		_spring.land(_landing_speed)
		_land_timer = LAND_SECONDS
		_ball_time = 0.0
		_landing = false
	_ball_time = maxf(0.0, _ball_time - _dt)

func _read_input() -> MoveInput:
	var i := MoveInput.new()
	if scripted != null:
		i.dir = scripted.dir
		i.jump_pressed = scripted.jump_pressed
		i.jump_held = scripted.jump_held
		i.down = scripted.down
		i.signature_pressed = scripted.signature_pressed
		scripted.jump_pressed = false
		scripted.signature_pressed = false
		return i
	i.dir = Input.get_axis("move_left", "move_right")
	i.jump_pressed = Input.is_action_just_pressed("jump")
	i.jump_held = Input.is_action_pressed("jump")
	i.down = Input.get_action_strength("aim_down")
	i.signature_pressed = Input.is_action_just_pressed("tackle")
	return i

## Which side a wall is on within WALL_RANGE (the side the input points to first), 0 for none or on the floor.
func _wall_side(dir: float) -> int:
	if body.is_on_floor():
		return 0
	var first := 1 if dir >= 0.0 else -1
	for side in [first, -first]:
		if body.test_move(body.global_transform, Vector2(side * WALL_RANGE, 0.0)):
			return side
	return 0

## Free px above the body: 0 when it could not rise STAND_RISE (a low ceiling), else plenty.
func _clearance() -> float:
	return 0.0 if body.test_move(body.global_transform, Vector2(0.0, -VerbRunner.STAND_RISE)) else 1000.0

## The collision box: flat while spread or sliding, its bottom always on the floor.
func _apply_box() -> void:
	var size := BodyConfig.spread_size() if VerbRunner.is_flat(state, profile) else BodyConfig.size()
	_box.size = size
	_shape.position.y = BodyConfig.BOTTOM - size.y / 2.0

func _draw_body(delta: float) -> void:
	if _sheet != null:
		_clip = SpeciesLook.clip_for(profile.id, body.is_on_floor(), state.velocity.y, state.velocity.x, _land_timer, state.verb, VerbRunner.is_flat(state, profile), state.clinging, _ball_time > 0.0)
		_animator.play(_clip)
		_animator.advance(delta)
		var frame := _animator.frame()
		_sprite.texture = _sheet.frame_texture(frame)
		_sprite.scale = _look_scale(frame, delta)
		_sprite.flip_h = state.wall_side < 0 if _clip == "wall" else _facing < 0  # a wall on the left is gripped facing left
		_sprite.position = body.position + Vector2(0.0, BodyConfig.BOTTOM - _sheet.frame_size(frame).y * _sprite.scale.y / 2.0)
	else:
		_rect.scale = Vector2.ONE
		_rect.position = body.position + Vector2(-_rect.size.x / 2.0, BodyConfig.BOTTOM - _rect.size.y)
	var tint := VERB_TINT if state.verb != "" else Color.WHITE
	_sprite.modulate = tint
	_rect.modulate = tint
	var doing := state.verb if state.verb != "" else ("flat" if state.spread else ("wall" if state.clinging else ""))
	_label.text = "%s%s   speed %d   boost %s   verb: %s   last jump: rise %.1f px, air %.2f s\n1 biped   2 slime   3 wolf   4 spider   B boost   J tackle   S down (flatten, slide)   at a wall: press into it to stick, jump to kick off, hold jump to bounce" % [
		profile.id, " (placeholder, no art yet)" if _sheet == null else "", int(absf(body.velocity.x)), "on" if boosted else "off", doing, _last["rise"], _last["airtime"]]

## The sprite's scale: the slime's spring, squared for the ball (which also turns), wobbling while it crawls flat.
func _look_scale(frame: String, delta: float) -> Vector2:
	if profile.id != "slime":
		return Vector2.ONE
	var out := _spring.sprite_scale()
	var crawling := state.spread and state.verb == "" and absf(state.velocity.x) > SpeciesLook.MOVING_SPEED
	_crawl_phase = SpeciesLook.crawl_advance(_crawl_phase, state.velocity.x if crawling else 0.0, delta)
	_crawl_gain = move_toward(_crawl_gain, 1.0 if crawling else 0.0, delta * CRAWL_EASE)
	out *= Vector2.ONE.lerp(SpeciesLook.crawl_scale(_crawl_phase), _crawl_gain)
	if _clip == "ball":
		out *= SpeciesLook.ball_scale(_sheet.frame_size(frame))
		_sprite.rotation += BALL_SPIN * _facing * delta
	else:
		_sprite.rotation = 0.0
	return out

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
