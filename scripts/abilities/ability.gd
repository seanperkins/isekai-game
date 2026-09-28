class_name Ability
extends Node2D
## Base for active skills. The actor supplies facing, team and apply_impulse(); targets are
## other-team members of group "actors". Abilities never emit gameplay events themselves.

const COOLDOWN_SECONDS := 0.8

var actor: Node2D
var values: Array = []
var level := 1
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

## Other-team actors in front of the actor, nearest first.
func targets_in_front(range_px: float, half_height: float) -> Array:
	var out: Array = []
	for n in actor.get_tree().get_nodes_in_group("actors"):
		if n == actor or n.get("team") == actor.team or not n.has_method("receive_hit"):
			continue
		var dx: float = (n.global_position.x - actor.global_position.x) * actor.facing
		if dx >= -4.0 and dx <= range_px and absf(n.global_position.y - actor.global_position.y) <= half_height:
			out.append(n)
	out.sort_custom(func(a, b): return absf(a.global_position.x - actor.global_position.x) < absf(b.global_position.x - actor.global_position.x))
	return out

func _perform() -> void:
	pass
