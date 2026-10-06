class_name VerbOmen
extends Node
## An omen laid on an enemy (Omen): it dies when the time is up unless it cleanses first (it stands in deep water, or is struck with holy light). A
## hunting boss is only wounded. One at a time per caster. Group `verb_omens`.

const BOSS_FRACTION := 0.25
const OVERKILL := 10

var caster: Node2D
var target: Enemy
var _left := 0.0
var _type := "dark"

func launch(p_caster: Node2D, p_target: Enemy, seconds: float, damage_type: String) -> void:
	add_to_group("verb_omens")
	caster = p_caster
	target = p_target
	_left = seconds
	_type = damage_type
	target.set_meta("verb_omen", true)

func cancel() -> void:
	if is_instance_valid(target):
		target.remove_meta("verb_omen")
		target.remove_meta("verb_omen_cleansed")
	remove_from_group("verb_omens")
	queue_free()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.status.state == EnemyStatus.GONE:
		cancel()
		return
	if target.has_meta("verb_omen_cleansed") or DeepWater.at(get_tree(), target.global_position) != null:
		cancel()
		return
	_left -= delta
	if _left > 0.0:
		return
	var from: Vector2 = caster.global_position if is_instance_valid(caster) else Vector2.INF
	var dealt: int = int(target.health.max_hp * BOSS_FRACTION) if target.hunting else target.health.hp + OVERKILL
	target.receive_hit(dealt, _type, from, "omen", true)
	cancel()
