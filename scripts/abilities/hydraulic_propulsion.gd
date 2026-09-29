extends Ability
## Water-powered burst along the aim; values are percent of base distance. A horizontal burst also lifts a little so it
## clears small gaps. Held, it keeps going: an extended burst (a thrust along the latched aim while below the burst's own
## speed, 0.6 s at most) with a spray behind the slime. It stretches the burst; it does not fly.

const BASE_PUSH := 380.0
const HORIZONTAL_LIFT := -140.0
const THRUST := 300.0  # px/s squared along the latched aim, only while below the burst speed

var _dir := Vector2.RIGHT
var _spray: CPUParticles2D

func _init() -> void:
	max_channel = 0.6

func _ready() -> void:
	_spray = CPUParticles2D.new()
	_spray.emitting = false
	_spray.amount = 24
	_spray.lifetime = 0.35
	_spray.local_coords = false
	_spray.texture = Art.light_texture()
	_spray.scale_amount_min = 0.03
	_spray.scale_amount_max = 0.06
	_spray.color = Color(0.5, 0.85, 1.0, 0.8)
	_spray.spread = 25.0
	_spray.initial_velocity_min = 60.0
	_spray.initial_velocity_max = 110.0
	_spray.gravity = Vector2(0, 120)
	add_child(_spray)

func _perform() -> void:
	var dir := aim_dir()
	var push := dir * BASE_PUSH * value() / 100.0
	if is_zero_approx(dir.y):
		push.y += HORIZONTAL_LIFT
	actor.apply_impulse(push)
	Vfx.puffs(actor, Art.texture("slime_idle"), [actor.global_position], Color(0.5, 0.8, 1.0, 0.6), 0.25)  # afterimage

func can_channel() -> bool:
	return true

func begin_channel() -> void:
	_dir = aim_dir()  # latched: with nothing held aim_dir() would follow `facing` on every call
	_perform()
	_spray.visible = true
	_spray.emitting = true
	_aim_spray()

func channel_tick(delta: float) -> bool:
	var v: Vector2 = actor.velocity
	if v.dot(_dir) < BASE_PUSH * value() / 100.0:
		v += _dir * THRUST * delta
	actor.apply_impulse(v)  # keeps velocity.y when it is zero, and re-arms the burst's 0.25 s lock
	_aim_spray()
	return true

func end_channel(hard := false) -> void:
	_spray.emitting = false
	if hard:
		_spray.visible = false
	super.end_channel(hard)

func _aim_spray() -> void:
	_spray.global_position = actor.global_position - _dir * 10.0
	_spray.direction = -_dir
