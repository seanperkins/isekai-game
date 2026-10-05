class_name VerbAlly
extends Node2D
## A small slime a verb calls (Court). It walks to the nearest foe of the caster's other team and strikes it, or stays by its caster
## when there is none, and goes when its time is up or its caster is gone. Group `verb_allies`, deliberately not `actors`: foes do
## not see it, so it cannot be hurt and no ability can hit it.

const SPEED := 70.0
const FOLLOW_SPEED := 160.0
const FOLLOW_GAP := 24.0
const CHASE_RANGE := 200.0
const STRIKE_REACH := Vector2(14.0, 30.0)
const STRIKE_SECONDS := 0.8

var caster: Node2D
var _power := 1
var _seconds := 0.0
var _elapsed := 0.0
var _strike_in := 0.0

func launch(p_caster: Node2D, at: Vector2, power: int, seconds: float, tint: Color) -> void:
	add_to_group("verb_allies")
	caster = p_caster
	global_position = at
	_power = power
	_seconds = seconds
	var s := Sprite2D.new()
	s.texture = Art.texture("slime_idle")
	s.modulate = tint
	s.scale = Vector2.ONE * 0.7
	add_child(s)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(caster) or _elapsed >= _seconds:
		queue_free()
		return
	_strike_in = maxf(0.0, _strike_in - delta)
	var foe := _nearest_foe()
	if foe == null:
		if global_position.distance_to(caster.global_position) > FOLLOW_GAP:
			global_position = global_position.move_toward(caster.global_position, FOLLOW_SPEED * delta)
		return
	var d: Vector2 = foe.global_position - global_position
	if absf(d.x) <= STRIKE_REACH.x and absf(d.y) <= STRIKE_REACH.y:
		if _strike_in <= 0.0:
			foe.receive_hit(_power, "physical", global_position, "")
			_strike_in = STRIKE_SECONDS
	else:
		global_position.x = move_toward(global_position.x, foe.global_position.x, SPEED * delta)

func _nearest_foe() -> Node2D:
	var best: Node2D = null
	var best_d := CHASE_RANGE
	for n in get_tree().get_nodes_in_group("actors"):
		if n == caster or not n.has_method("receive_hit") or n.get("team") == caster.get("team"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		var d: float = n.global_position.distance_to(global_position)
		if d < best_d:
			best = n
			best_d = d
	return best
