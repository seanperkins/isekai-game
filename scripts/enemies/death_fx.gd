class_name DeathFx
extends Node2D
## How a creature dies, matched to the blow (spec 2.2). A child of the enemy, so freeing the enemy
## frees the effect. It owns the enemy's sprite while it plays and hands it back when it ends:
##   tackle  hops the body away from the tackler, spinning onto its back (the only effect that moves it)
##   poison  turns the body green and melts it toward the floor
##   blade   replaces the sprite with two halves cut along the blade, sliding apart and falling
##   other   holds a beat
## Every effect ends with `finished`; the enemy then lies downed and its eat window starts.

signal finished

const TACKLE_SECONDS := 0.6
const POISON_SECONDS := 1.0
const BLADE_SECONDS := 0.6
const OTHER_SECONDS := 0.3
## The tackle death moves the body at most this far, and leaves it within SETTLE_RANGE of the
## tackler (inside the 32 px eat range), never off a ledge.
const TACKLE_MAX_TRAVEL := 24.0
const SETTLE_RANGE := 28.0
const HOP_SPEED := 110.0
const GRAVITY := 900.0
const POISON_TINT := Color(0.45, 1.0, 0.3)
const POISON_FLATTEN := 0.15
const BLADE_SLIDE := 10.0
const BLADE_GRAVITY := 500.0
const CUT_SHADER := preload("res://scripts/enemies/blade_cut.gdshader")

var cause := "other"
var _enemy: Enemy
var _sprite: Sprite2D
var _t := 0.0
var _done := false
var _base_y := 0.0
var _spin_dir := 1.0
var _halves: Array[Sprite2D] = []
var _normal := Vector2.UP
var _slide_x := 1.0  # +1 or -1: which way the upper half slides off
var _fall: Array[float] = [0.0, 0.0]
var _fall_v: Array[float] = [0.0, 0.0]
var _fall_max: Array[float] = [0.0, 0.0]

static func duration(for_cause: String) -> float:
	match for_cause:
		"tackle":
			return TACKLE_SECONDS
		"poison":
			return POISON_SECONDS
		"blade":
			return BLADE_SECONDS
	return OTHER_SECONDS

func begin(enemy: Enemy, p_cause: String, from: Vector2) -> void:
	_enemy = enemy
	cause = p_cause
	_sprite = enemy.get_node_or_null("Sprite")
	if _sprite != null:
		_base_y = _sprite.position.y
	match cause:
		"tackle":
			_begin_tackle(from)
		"blade":
			_begin_blade(from)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if _done:
		return
	_t += delta
	var k := clampf(_t / duration(cause), 0.0, 1.0)
	match cause:
		"tackle":
			_step_tackle(k)
		"poison":
			_step_poison(k)
		"blade":
			_step_blade(delta, k)
	if _t >= duration(cause):
		_finish()

# --- tackle ---

func _begin_tackle(from: Vector2) -> void:
	var away := signf(_enemy.global_position.x - from.x) if from != Vector2.INF else float(-_enemy.facing)
	if away == 0.0:
		away = 1.0
	_spin_dir = away
	var dist := absf(_enemy.global_position.x - from.x) if from != Vector2.INF else 0.0
	var travel := clampf(SETTLE_RANGE - dist, 0.0, TACKLE_MAX_TRAVEL)
	travel = minf(travel, _ground_reach(away, travel))
	var air := 2.0 * HOP_SPEED / GRAVITY
	_enemy.velocity = Vector2(away * travel / air, -HOP_SPEED)

## How far (up to `want`) the ground continues under the body's leading edge in direction `dir`, so a
## knocked creature is never sent over a ledge.
func _ground_reach(dir: float, want: float) -> float:
	var space := _enemy.get_world_2d().direct_space_state
	var reach := want
	while reach > 0.0:
		var x := _enemy.global_position.x + dir * (reach + Enemy.BODY_SIZE.x / 2.0)
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, _enemy.global_position.y), \
			Vector2(x, _enemy.global_position.y + Enemy.BODY_BOTTOM + Enemy.LEDGE_DEPTH))
		q.exclude = [_enemy.get_rid()]
		if not space.intersect_ray(q).is_empty():
			return reach
		reach -= 4.0
	return 0.0

func _step_tackle(k: float) -> void:
	if _enemy.is_on_floor():
		_enemy.velocity.x = 0.0  # landed: no sliding
	if _sprite != null:
		_sprite.rotation = _spin_dir * PI * minf(1.0, k * 1.6)

# --- poison ---

func _step_poison(k: float) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var flat := lerpf(1.0, POISON_FLATTEN, k)
	_sprite.scale = Vector2(lerpf(1.0, 1.25, k), flat)
	_sprite.position.y = _base_y + _sprite.texture.get_height() * (1.0 - flat) / 2.0
	_sprite.modulate = Color.WHITE.lerp(POISON_TINT, minf(1.0, k * 2.0))

# --- blade ---

func _begin_blade(from: Vector2) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var dir := (_enemy.global_position - from).normalized() if from != Vector2.INF else Vector2(_enemy.facing, 0)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_normal = Vector2(-dir.y, dir.x)
	if _normal.y > 0.0:
		_normal = -_normal  # "side +1" is the upper half
	_sprite.visible = false
	var sep := _normal.x if absf(_normal.x) > 0.3 else dir.x
	_slide_x = 1.0 if sep >= 0.0 else -1.0
	# The half on the normal's side (the upper one) drops onto the floor; the other is already on it.
	_fall_max = [_sprite.texture.get_height() / 2.0 * absf(_normal.y), 0.0]
	for side in [1.0, -1.0]:
		var half := Sprite2D.new()
		half.texture = _sprite.texture
		half.flip_h = _sprite.flip_h
		half.position = _sprite.position
		var mat := ShaderMaterial.new()
		mat.shader = CUT_SHADER
		mat.set_shader_parameter("normal", _normal)
		mat.set_shader_parameter("side", side)
		half.material = mat
		add_child(half)
		_halves.append(half)

func _step_blade(delta: float, k: float) -> void:
	for i in _halves.size():
		var side := 1.0 if i == 0 else -1.0
		var h := _halves[i]
		_fall_v[i] += BLADE_GRAVITY * delta
		_fall[i] = minf(_fall_max[i], _fall[i] + _fall_v[i] * delta)
		h.position = Vector2(_sprite.position.x + side * _slide_x * BLADE_SLIDE * minf(1.0, k * 2.0), _base_y + _fall[i])
		h.rotation = side * 0.2 * minf(1.0, k * 2.0)

# --- ending ---

## A blade kill keeps its two halves where they came to rest as the corpse, under the enemy as
## "CutCorpse". Returns true when it did.
func _leave_the_halves() -> bool:
	if cause != "blade" or _halves.size() != 2 or not is_instance_valid(_enemy):
		return false
	var corpse := Node2D.new()
	corpse.name = "CutCorpse"
	_enemy.add_child(corpse)
	for h in _halves:
		h.reparent(corpse)
	return true

func _finish() -> void:
	_done = true
	var cut := _leave_the_halves()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE
		_sprite.modulate = Color.WHITE
		_sprite.visible = not cut  # a cut creature stays in two pieces: the whole sprite never comes back
		_sprite.position.y = _base_y
	if is_instance_valid(_enemy):
		_enemy.velocity.x = 0.0
	finished.emit()
	queue_free()
