class_name Ability
extends Node2D
## Base for active skills. The actor supplies facing, team and apply_impulse(); targets are
## other-team members of group "actors". Abilities never emit gameplay events themselves.

const COOLDOWN_SECONDS := 0.8

var actor: Node2D
var values: Array = []
var level := 1
## Cast direction (unit vector). Zero means "forward", i.e. the actor's facing.
var aim := Vector2.ZERO
var _cooldown := 0.0

func setup(p_actor: Node2D, p_values: Array, p_level: int) -> void:
	actor = p_actor
	values = p_values
	level = p_level

func activate() -> bool:
	if _cooldown > 0.0 or actor == null:
		return false
	_cooldown = COOLDOWN_SECONDS
	_perform()
	return true

## True when off cooldown, so the player can check before spending MP.
func ready() -> bool:
	return _cooldown <= 0.0 and actor != null

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

func value() -> int:
	if values.is_empty():
		return 0
	return int(values[clampi(level, 1, values.size()) - 1])

func aim_dir() -> Vector2:
	return aim.normalized() if aim != Vector2.ZERO else Vector2(actor.facing, 0.0)

## Other-team actors along the aim within `range_px`, at most `half_width` off the line,
## nearest first.
func targets_in_front(range_px: float, half_width: float) -> Array:
	var dir := aim_dir()
	var out: Array = []
	for n in actor.get_tree().get_nodes_in_group("actors"):
		if n == actor or n.get("team") == actor.team or not n.has_method("receive_hit"):
			continue
		var d: Vector2 = n.global_position - actor.global_position
		var along := d.dot(dir)
		if along >= -4.0 and along <= range_px and absf(d.cross(dir)) <= half_width:
			out.append(n)
	out.sort_custom(func(a, b): return (a.global_position - actor.global_position).dot(dir) < (b.global_position - actor.global_position).dot(dir))
	return out

func _perform() -> void:
	pass
