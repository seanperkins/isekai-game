class_name VerbField
extends Node2D
## A timed field a verb leaves (Maelstrom, Guardian, an Engulf's digest): it can follow a node, draw foes toward its centre and hurt
## the foes inside it once each whole second. It never touches its caster's team, ends on its own clock, and ends at once when its
## caster (or the node it follows) is gone. Group `verb_fields`.

const TICK_SECONDS := 1.0
const EPS := 1e-4  # a tick is due within this of its second, so N whole seconds tick N times whatever the float drift

var radius := 96.0
var _caster: Node2D
var _follow: Node2D
var _has_follow := false
var _pull := 0.0
var _damage := 0
var _type := "physical"
var _ignore_def := false
var _color := Color(1, 1, 1, 0.25)
var _seconds := 0.0
var _elapsed := 0.0
var _ticks := 0

## `opts`: `follow` (a node the field stays on), `pull` (px per second toward the centre), `damage` (per tick, 0 for none),
## `damage_type`, `ignore_def` (a hit on an Enemy skips its DEF) and `color`.
func launch(caster: Node2D, at: Vector2, p_radius: float, seconds: float, opts := {}) -> void:
	add_to_group("verb_fields")
	_caster = caster
	global_position = at
	radius = p_radius
	_seconds = seconds
	_follow = opts.get("follow")
	_has_follow = _follow != null
	_pull = float(opts.get("pull", 0.0))
	_damage = int(opts.get("damage", 0))
	_type = str(opts.get("damage_type", "physical"))
	_ignore_def = bool(opts.get("ignore_def", false))
	_color = opts.get("color", _color)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_caster) or (_has_follow and not is_instance_valid(_follow)):
		queue_free()
		return
	_elapsed += delta
	if _has_follow:
		global_position = _follow.global_position
	if _pull > 0.0:
		for n in _foes_inside():
			_draw_in(n, delta)
	while float(_ticks + 1) * TICK_SECONDS <= _elapsed + EPS and float(_ticks + 1) * TICK_SECONDS <= _seconds + EPS:
		_ticks += 1
		_pulse()
	queue_redraw()
	if _elapsed >= _seconds - EPS:
		queue_free()

func _pulse() -> void:
	if _damage <= 0:
		return
	for n in _foes_inside():
		if _ignore_def and n is Enemy:
			n.receive_hit(_damage, _type, global_position, "", true)
		else:
			n.receive_hit(_damage, _type, global_position, "")

func _draw_in(n: Node2D, delta: float) -> void:
	var to := global_position - n.global_position
	if to.length() < 2.0:
		return
	var step := to.normalized() * minf(_pull * delta, to.length())
	if n.has_method("move_and_collide"):
		n.move_and_collide(step)
	else:
		n.global_position += step

func _foes_inside() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("actors"):
		if n == _caster or not n.has_method("receive_hit") or n.get("team") == _caster.get("team"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		if n.global_position.distance_to(global_position) <= radius:
			out.append(n)
	return out

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, _color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(_color.r, _color.g, _color.b, 0.7), 1.0)
