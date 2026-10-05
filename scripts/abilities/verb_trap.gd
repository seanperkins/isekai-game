class_name VerbTrap
extends Node2D
## A trap a verb rigs at the caster's feet (the Tinker's Rig). Once it is armed the first awake enemy in reach springs it: it takes the
## cast's damage and is stunned, the caster says `trap_sprung`, and the trap is gone. It goes quietly when its time is up. Group
## `verb_traps`; `caster` lets a fourth cast take the place of the oldest.

const ARM_SECONDS := 0.6
const REACH := Vector2(14.0, 24.0)

var caster: Node2D
var _power := 1
var _seconds := 0.0
var _stun := 0.0
var _age := 0.0

func launch(p_caster: Node2D, at: Vector2, power: int, seconds: float, stun: float) -> void:
	add_to_group("verb_traps")
	caster = p_caster
	global_position = at
	_power = power
	_seconds = seconds
	_stun = stun
	z_index = 1
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _seconds:
		queue_free()
		return
	if _age < ARM_SECONDS:
		return
	queue_redraw()
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Enemy) or n.dormant or n.status.state != EnemyStatus.ACTIVE:
			continue
		var d: Vector2 = n.global_position - global_position
		if absf(d.x) <= REACH.x and absf(d.y) <= REACH.y:
			_spring(n)
			return

func _spring(enemy: Enemy) -> void:
	enemy.receive_hit(_power, "physical", global_position, "")
	if _stun > 0.0 and enemy.def.predatable:
		enemy.status.stun(_stun)
	if is_instance_valid(caster) and caster.has_method("emit_deed"):
		caster.emit_deed(Deeds.TRAP_SPRUNG)
	queue_free()

func _draw() -> void:
	var color := Color(0.85, 0.8, 0.45) if _age >= ARM_SECONDS else Color(0.55, 0.52, 0.35)
	draw_line(Vector2(-8, 0), Vector2(-3, -5), color, 1.0)
	draw_line(Vector2(-3, -5), Vector2(0, 0), color, 1.0)
	draw_line(Vector2(0, 0), Vector2(3, -5), color, 1.0)
	draw_line(Vector2(3, -5), Vector2(8, 0), color, 1.0)
