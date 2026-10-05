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
## A pillar under a slab for the spider: one wall from the floor to the slab's top, the slab's underside to hang from.
const CRAWL_PILLAR := Rect2(760, -150, 30, 150)
const CRAWL_SLAB := Rect2(760, -180, 130, 30)
## Slick solids (the spider cannot grip, crawl on or hang from them): a tall block with a top, and a slab above it.
const SLICK_BLOCK := Rect2(300, -90, 60, 90)
const SLICK_CEILING := Rect2(300, -220, 60, 20)
## A thin one-way ledge (a floor on its top only) a spider can hop up through and walk off the end of.
const ONEWAY_LEDGE := Rect2(160, -50, 100, 6)
## A 16 px hard step at the left end for the wolf to vault, and a hostile dummy to pounce on (an Area2D floating 10 px above the
## floor: it marks contact, it does not block).
const STEP_LOW := Rect2(20, -16, 25, 16)
const DUMMY := Rect2(120, -50, 20, 40)
const START := Vector2(100, 0)
## The sprite's tint while a verb runs.
const VERB_TINT := Color(1.5, 1.3, 0.7)
## The stage-4 jump_height (185%) as a launch boost: rise scales with it squared.
const BOOST_JUMP_HEIGHT := 1.85
## How long the slime's landing frame shows (the player's LAND_SQUASH_SECONDS).
const LAND_SECONDS := 0.12
## How fast the ball's eyes roll around it (rad/s), and how fast the crawl wobble eases in and out.
const BALL_ROLL := 10.0
const CRAWL_EASE := 8.0
## The spider's sprite settles on a new surface in about 3 times this (the body changes surface in one tick), and a
## reversal pivots over PIVOT_SECONDS.
const THREAD_FADE := 0.15
const CORNER_EASE := 0.04
const PIVOT_SECONDS := 0.10
## The skid's dust puffs live this long (s); the wolf leans back this much (rad) in a skid, and its pose eases over LEAN_EASE;
## the leaping pose is stretched along the velocity.
const DUST_LIFE := 0.3
const SKID_LEAN := 0.25
const LEAN_EASE := 0.03
const POUNCE_STRETCH := Vector2(1.2, 0.85)
## The placeholder's alpha while the body is invulnerable (the roll and slide's first 0.2 s).
const INVULNERABLE_ALPHA := 0.6

## When set, replaces the keyboard and pad. `jump_pressed` is consumed (cleared) by the next physics frame, so a test
## sets it once; `jump_held` stays until the test clears it.
var scripted: MoveInput = null
var profile: MovementProfile
var state := MoveState.new()
## The movement logic, shared with the Player (built once the body exists).
var _sb: SpeciesBody
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
var _ball := false
var _ball_roll := 0.0
var _crawl_phase := 0.0
var _crawl_gain := 0.0
var _thread: Line2D
var _thread_anchor := Vector2.ZERO
var _thread_dir := Vector2.RIGHT
var _thread_alpha := 0.0
var _angle := 0.0
var _vis_off := Vector2.ZERO
var _stride := 0.0
var _prev_pos := Vector2.ZERO
var _sense := 1.0
var _pivot := 0.0
var _cam: Camera2D
var _dummy: Area2D
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
	_block(CRAWL_PILLAR)
	_block(CRAWL_SLAB)
	_oneway(ONEWAY_LEDGE)
	_slick(SLICK_BLOCK)
	_slick(SLICK_CEILING)
	_block(STEP_LOW)
	_hostile(DUMMY)
	body = CharacterBody2D.new()
	body.name = "Body"
	body.collision_mask = 7  # hard solids (layer 1), one-way ledges (layer 2) and slick solids (layer 3, value 4)
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	_box = RectangleShape2D.new()
	_box.size = BodyConfig.size()
	_shape.shape = _box
	body.add_child(_shape)
	body.position = START + Vector2(0, -BodyConfig.BOTTOM)
	add_child(body)
	_sb = SpeciesBody.new(body, _shape, _box)
	_sb.set_profile(profile)
	state = _sb.state
	_rect = ColorRect.new()
	_rect.size = BodyConfig.size()
	_rect.pivot_offset = Vector2(_rect.size.x / 2.0, _rect.size.y)
	_rect.color = Color(0.45, 0.85, 0.5)
	add_child(_rect)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	_thread = Line2D.new()
	_thread.name = "Thread"
	_thread.width = 1.5
	_thread.default_color = Color(0.92, 0.92, 0.97)
	_thread.visible = false
	add_child(_thread)
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
	if _sb != null:
		_sb.set_profile(p)  # no momentum or timers carry over a switch
		state = _sb.state
	else:
		state = MoveState.new()
	_ball = false
	_ball_roll = 0.0
	_landing = false
	_angle = 0.0
	_vis_off = Vector2.ZERO
	_stride = 0.0
	_pivot = 0.0
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
	_sprite.rotation = 0.0
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
	_sb.fill_input(i, func() -> bool: return _dummy.overlaps_body(body))
	_sb.think(i, delta, sqrt(BOOST_JUMP_HEIGHT) if boosted else 1.0)
	_update_thread(delta)
	if state.skidding:
		_puff_dust()
	if _sb.move(_before_move):
		_crawl(delta)
		return
	if _in_jump:
		_air_ticks += 1
		_top_y = minf(_top_y, body.global_position.y)
		if _air_ticks > 1 and body.is_on_floor():
			_in_jump = false
			_last = {"rise": _takeoff_y - _top_y, "airtime": _air_ticks * delta}
	_land_timer = maxf(0.0, _land_timer - delta)
	if not was_on_floor and body.is_on_floor():
		_landing = true  # judged next tick, once the step has said whether this landing bounced
		_landing_speed = _sb.fall_speed
	if absf(state.velocity.x) > 1.0:
		_facing = 1 if state.velocity.x > 0.0 else -1
	_spring.update(state.velocity.y, delta)
	_cam.position.x = clampf(body.position.x, 320.0, FLOOR.size.x - 320.0)
	_draw_body(delta)

## Just before the body moves: judge the landing the last move made, and note a take-off (its height is the position before this
## frame's move, as MovementSim measures it).
func _before_move(velocity: Vector2) -> Vector2:
	_judge_landing()
	if state.launched != "":
		_in_jump = true
		_takeoff_y = body.global_position.y
		_top_y = _takeoff_y
		_air_ticks = 0
	return velocity

## A bounce (timed rebound, hold bounce, wall bounce) is a ball, not a squash: it drops any squash a landing started and
## stays a ball, eyes rolling, until it stops being one: a landing that does not bounce again (which squashes and shows the
## landing frame, one tick after touching down), a Tackle, a wall grip or any other launch.
func _judge_landing() -> void:
	if state.launched == "rebound" or state.launched == "bounce" or state.wall_bounced:
		_ball = true
		_spring.calm()
		_land_timer = 0.0
		_landing = false
		return
	if _landing:
		_spring.land(_landing_speed)
		_land_timer = LAND_SECONDS
		_landing = false
		_ball = false
	if state.launched != "" or state.verb != "" or state.clinging:
		_ball = false

func _read_input() -> MoveInput:
	var i := MoveInput.new()
	if scripted != null:
		i.dir = scripted.dir
		i.jump_pressed = scripted.jump_pressed
		i.jump_held = scripted.jump_held
		i.down = scripted.down
		i.up = scripted.up
		i.aim = scripted.aim
		i.signature_pressed = scripted.signature_pressed
		scripted.jump_pressed = false
		scripted.signature_pressed = false
		return i
	i.dir = Input.get_axis("move_left", "move_right")
	i.jump_pressed = Input.is_action_just_pressed("jump")
	i.jump_held = Input.is_action_pressed("jump")
	i.down = Input.get_action_strength("aim_down")
	i.up = Input.get_action_strength("aim_up")
	var raw := Input.get_vector("move_left", "move_right", "aim_up", "aim_down", 0.0)
	i.aim = Vector2.from_angle(snappedf(raw.angle(), PI / 4.0)) if raw.length() >= 0.3 else Vector2.ZERO  # the cast aim, 8-way
	i.signature_pressed = Input.is_action_just_pressed("tackle")
	return i

## The collision box and the zip's cast live in SpeciesBody; the sandbox's tests reach them through these.
func _apply_box() -> void:
	_sb.apply_box()

func _cast(from: Vector2, to: Vector2, include_oneway: bool) -> Dictionary:
	return _sb._cast(from, to, include_oneway)

## The spider on a surface (SpeciesBody moved it): no landing, no jump measure, the camera and the drawing.
func _crawl(delta: float) -> void:
	_landing = false
	_land_timer = 0.0
	_in_jump = false
	_cam.position.x = clampf(body.position.x, 320.0, FLOOR.size.x - 320.0)
	_draw_body(delta)

## The thread from behind the spider to its anchor while it pulls or it slides down it, and for a moment after.
func _update_thread(delta: float) -> void:
	if state.zip_event == "start":
		_thread_anchor = body.global_position + state.zip_target
		_thread_dir = state.zip_dir
	if state.drop_event == "start":
		_thread_anchor = body.global_position + state.drop_target
		_thread_dir = Vector2.DOWN  # head down the thread: the rear, where the silk comes from, is up
	if state.zip_dir != Vector2.ZERO or state.drop_up > 0.0:
		_thread_alpha = 1.0
	else:
		_thread_alpha = maxf(0.0, _thread_alpha - delta / THREAD_FADE)
	_thread.visible = _thread_alpha > 0.0
	_thread.modulate.a = _thread_alpha
	_thread.points = PackedVector2Array([body.global_position - _thread_dir * 8.0, _thread_anchor])

## A puff of dust at the paws, drifting up and fading (the skid's).
func _puff_dust() -> void:
	var puff := ColorRect.new()
	puff.size = Vector2(4.0, 4.0)
	puff.color = Color(0.82, 0.76, 0.64, 0.8)
	puff.position = body.global_position + Vector2(signf(state.velocity.x) * 8.0 - 2.0, BodyConfig.BOTTOM - 4.0)
	puff.add_to_group("dust")
	add_child(puff)
	var tween := puff.create_tween().set_parallel(true)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(puff, "position:y", puff.position.y - 10.0, DUST_LIFE)
	tween.tween_property(puff, "modulate:a", 0.0, DUST_LIFE)
	tween.chain().tween_callback(puff.queue_free)

func _draw_body(delta: float) -> void:
	if _sheet != null and profile.id == "spider":
		_draw_spider(delta)
	elif _sheet != null:
		_clip = SpeciesLook.clip_for(profile.id, body.is_on_floor(), state.velocity.y, state.velocity.x, _land_timer, _look_verb(), VerbRunner.is_flat(state, profile), state.clinging, _ball)
		_animator.play(_clip)
		_animator.advance(delta)
		var frame := _animator.frame()
		var size := _sheet.frame_size(frame)
		if _clip == "ball":
			# the bouncing slime is a round ball whose eyes roll around it, drawn by SlimeBall (no frame for it yet)
			_ball_roll += BALL_ROLL * delta
			_sprite.texture = SlimeBall.texture(_ball_roll)
			size = Vector2(SlimeBall.SIZE, SlimeBall.SIZE)
		else:
			_ball_roll = 0.0
			_sprite.texture = _sheet.frame_texture(frame)
		_sprite.scale = _look_scale(delta)
		_sprite.rotation = _lean(delta)
		_sprite.flip_h = state.wall_side < 0 if _clip == "wall" else _facing < 0  # a wall on the left is gripped facing left
		_sprite.position = body.position + Vector2(0.0, BodyConfig.BOTTOM - size.y * _sprite.scale.y / 2.0)
	else:
		_rect.scale = Vector2(1.0, BodyConfig.spread_size().y / BodyConfig.size().y) if VerbRunner.is_flat(state, profile) else Vector2.ONE
		_rect.position = body.position + Vector2(-_rect.size.x / 2.0, BodyConfig.BOTTOM - _rect.size.y)
	var tint := VERB_TINT if state.verb != "" else Color.WHITE
	if state.invulnerable:
		tint.a = INVULNERABLE_ALPHA
	_sprite.modulate = tint
	_rect.modulate = tint
	var doing := state.verb if state.verb != "" else ("flat" if state.spread else ("wall" if state.clinging else ("crawl" if state.surface_n != Vector2.ZERO else "")))
	_label.text = "%s%s   speed %d   boost %s   verb: %s   last jump: rise %.1f px, air %.2f s\n1 biped   2 slime   3 wolf   4 spider   B boost   J tackle   S down (flatten, slide)   down on a one-way ledge drops through it   at a wall: press into it to stick, jump to kick off, hold jump to bounce   biped: J rolls (slides when running), a jump that nearly clears a ledge mantles it by itself, walls slide and kick off   wolf: J pounces along the arrows (forward if none; one air pounce per jump), a gallop hops low steps by itself, reversing at speed skids   spider: arrows crawl floors, walls and ceilings, jump hops off, J zips (aim with the arrows, a thread pulls you to the first solid within 160 px; jump cancels), S in the air or hanging from a ceiling drops on a thread (down reels, up climbs, jump lets go)" % [
		profile.id, " (placeholder, no art yet)" if _sheet == null else "", int(absf(body.velocity.x)), "on" if boosted else "off", doing, _last["rise"], _last["airtime"]]

## The verb the look shows: the running burst, else the biped's mantle pull ("" for none).
func _look_verb() -> String:
	if state.verb != "":
		return state.verb
	return "mantle" if state.mantle_left > 0.0 or state.mantle_event == "stand" else ""

## The spider, after how spiders move: the legs follow the distance travelled (so they freeze the instant it stops, on the
## frame they were on), the body is rigid (no bob, no squash), the sprite turns to the surface and eases through a corner (the
## body changes surface in one tick; the sprite starts where it was and catches up), the head points the way it goes and a
## reversal pivots (a quick squeeze). No silk: that waits for the zip and the silk drop.
func _draw_spider(delta: float) -> void:
	var attached := state.surface_n != Vector2.ZERO
	var corner := state.surface_event == "concave" or state.surface_event == "convex"
	if corner:
		_vis_off += _prev_pos - body.global_position
	_vis_off = _vis_off.lerp(Vector2.ZERO, 1.0 - exp(-delta / CORNER_EASE))
	var zipping := state.zip_dir != Vector2.ZERO
	var dropping := state.drop_up > 0.0
	var target := SpeciesLook.surface_angle(state.surface_n) if attached else 0.0
	if dropping:
		target = PI / 2.0 if _sense > 0.0 else -PI / 2.0  # head first down the thread (the sprite's right is its head)
	if zipping:
		if absf(state.zip_dir.x) > 0.01:
			_sense = signf(state.zip_dir.x)
		# head first along the thread: the sprite's right is its head, so a leftward zip is mirrored and turned the other way
		target = state.zip_dir.angle() if _sense > 0.0 else wrapf(state.zip_dir.angle() + PI, -PI, PI)
	_angle = lerp_angle(_angle, target, 1.0 - exp(-delta / CORNER_EASE))
	if (attached and not corner) or dropping:
		_stride = SpeciesLook.stride_advance(_stride, state.surface_shift.length())  # legs follow the distance, reeling too
	_clip = "crawl_%d" % (SpeciesLook.stride_frame(_stride) + 1) if (attached or dropping) and not zipping else "drop"
	var vx := state.drop_vx if dropping else state.velocity.x
	var sense := state.surface_sigma if attached else (signf(vx) if absf(vx) > 20.0 else _sense)
	if sense != _sense:
		_sense = sense
		_pivot = PIVOT_SECONDS
	_pivot = maxf(0.0, _pivot - delta)
	var squeeze := 1.0 - 0.55 * sin(PI * (1.0 - _pivot / PIVOT_SECONDS)) if _pivot > 0.0 else 1.0
	var size := _sheet.frame_size(_clip)
	_sprite.texture = _sheet.frame_texture(_clip)
	_sprite.rotation = _angle
	_sprite.flip_h = _sense < 0.0  # the sprite's right is the clockwise tangent: against it, mirror
	_sprite.scale = Vector2(squeeze, 1.0)
	_sprite.position = body.position + _vis_off + Vector2.UP.rotated(_angle) * (size.y / 2.0 - SurfaceStep.HN)
	_prev_pos = body.global_position

## The wolf's turn: nose along its velocity in a pounce (the sprite faces right; mirrored going left), leaning back in a skid, else
## upright. Eases, so it does not snap.
func _lean(delta: float) -> float:
	var target := 0.0
	var way := 1.0 if _facing > 0 else -1.0
	if profile.id == "wolf":
		if state.verb == "pounce":
			target = atan2(state.velocity.y, absf(state.velocity.x)) * way
		elif state.skidding:
			target = -SKID_LEAN * way
	_angle = lerp_angle(_angle, target, 1.0 - exp(-delta / LEAN_EASE))
	return _angle

## The sprite's scale: the slime's spring, wobbling while it crawls flat. The ball is never squashed, stretched or wobbled.
func _look_scale(delta: float) -> Vector2:
	if profile.id == "wolf" and state.verb == "pounce":
		return POUNCE_STRETCH  # the sprite is turned along the velocity, so this stretches along the leap
	if profile.id != "slime" or _clip == "ball":
		return Vector2.ONE
	var out := _spring.sprite_scale()
	var crawling := state.spread and state.verb == "" and absf(state.velocity.x) > SpeciesLook.MOVING_SPEED
	_crawl_phase = SpeciesLook.crawl_advance(_crawl_phase, state.velocity.x if crawling else 0.0, delta)
	_crawl_gain = move_toward(_crawl_gain, 1.0 if crawling else 0.0, delta * CRAWL_EASE)
	return out * Vector2.ONE.lerp(SpeciesLook.crawl_scale(_crawl_phase), _crawl_gain)

func _oneway(r: Rect2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 2
	b.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	shape.one_way_collision = true
	b.add_child(shape)
	var look := ColorRect.new()
	look.size = r.size
	look.position = -r.size / 2.0
	look.color = Color(0.55, 0.45, 0.25)
	b.add_child(look)
	add_child(b)

func _slick(r: Rect2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 4
	b.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	b.add_child(shape)
	var look := ColorRect.new()
	look.size = r.size
	look.position = -r.size / 2.0
	look.color = Color(0.6, 0.82, 0.95)
	b.add_child(look)
	add_child(b)

## A hostile that only marks contact (an Area2D the wolf's pounce reads), drawn as a red block.
func _hostile(r: Rect2) -> void:
	_dummy = Area2D.new()
	_dummy.name = "Dummy"
	_dummy.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	_dummy.add_child(shape)
	var look := ColorRect.new()
	look.size = r.size
	look.position = -r.size / 2.0
	look.color = Color(0.85, 0.25, 0.25, 0.7)
	_dummy.add_child(look)
	add_child(_dummy)

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
