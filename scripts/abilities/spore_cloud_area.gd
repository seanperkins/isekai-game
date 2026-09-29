class_name SporeCloudArea
extends Node2D
## A lingering zone the player leaves behind: Spore Cloud, Binding Web's patch, Miasma, Healing Spores and Puffball.
## For `seconds` it slows every enemy inside it each physics frame (Enemy.slow_for is idempotent, so a fast enemy crossing
## between ticks is still slowed) and, once each whole second, hurts them (`damage`, poison; 0 means no hit at all) and heals
## its caster if the caster is inside (`heals`). Group `player_clouds`; it never hurts the caster or its team, and it is not a
## `hazards` node.

const TICK_SECONDS := 1.0
const EPS := 1e-4  # a tick is due within this of its second, so N whole seconds tick N times whatever the float drift

var radius := 24.0
var damage := 1
var slow := true
var heals := 0
var _seconds := 0.0
var _elapsed := 0.0
var _ticks := 0
var _actor: Node2D

## `opts` may hold `damage` (default 1), `slow` (default true), `heals` (default 0), `color` (the tint) and `look` ("web"
## draws Binding Web's web sprite where the flat square would be; any other value keeps the square).
func launch(at: Vector2, p_radius: float, seconds: float, actor: Node2D, opts := {}) -> void:
	global_position = at
	radius = p_radius
	_seconds = seconds
	_actor = actor
	damage = int(opts.get("damage", 1))
	slow = bool(opts.get("slow", true))
	heals = int(opts.get("heals", 0))
	add_to_group("player_clouds")
	for c in get_children():
		c.queue_free()
	if opts.get("look", "") == "web":
		var web := Sprite2D.new()
		web.texture = VfxArt.web(int(radius * 2.0))
		web.modulate = opts.get("color", Color(1, 1, 1, 0.9))
		add_child(web)
		return
	var haze := ColorRect.new()  # drawn at the real radius, so a higher level shows a bigger cloud
	haze.color = opts.get("color", Color(0.7, 0.95, 0.4, 0.3))
	haze.size = Vector2(radius * 2.0, radius * 2.0)
	haze.position = -haze.size / 2.0
	add_child(haze)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_actor):
		queue_free()
		return
	_elapsed += delta
	if slow:
		for n in _enemies_inside():
			if n.has_method("slow_for"):  # a cracked stone is an actor too, and it cannot be slowed
				n.slow_for(Enemy.SLOW_SECONDS)
	# A due tick is processed before expiry is checked, so a zone of N whole seconds ticks exactly N times.
	while float(_ticks + 1) * TICK_SECONDS <= _elapsed + EPS and float(_ticks + 1) * TICK_SECONDS <= _seconds + EPS:
		_ticks += 1
		_pulse()
	if _elapsed >= _seconds - EPS:
		queue_free()

func _pulse() -> void:
	if damage > 0:
		for n in _enemies_inside():
			n.receive_hit(damage, "poison", global_position, "poison")
	if heals > 0 and _actor.global_position.distance_to(global_position) <= radius:
		var h = _actor.get("health")
		if h != null:
			h.heal(heals)

func _enemies_inside() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("actors"):
		if n == _actor or not n.has_method("receive_hit") or n.get("team") == _actor.get("team"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		if n.global_position.distance_to(global_position) <= radius:
			out.append(n)
	return out
