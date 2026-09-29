class_name SporeCloudArea
extends Node2D
## The player's Spore Cloud: for `seconds`, each second it poisons (1) and slows every enemy inside it.
## Group `player_clouds`; it never touches the player and is not a `hazards` node.

const TICK_SECONDS := 1.0

var radius := 24.0
var _left := 0.0
var _tick := 0.0
var _actor: Node2D

func launch(at: Vector2, p_radius: float, seconds: float, actor: Node2D) -> void:
	global_position = at
	radius = p_radius
	_left = seconds
	_actor = actor
	add_to_group("player_clouds")

func _ready() -> void:
	if get_child_count() == 0:
		var haze := ColorRect.new()
		haze.color = Color(0.7, 0.95, 0.4, 0.3)
		haze.size = Vector2(radius * 2.0, radius * 2.0)
		haze.position = -haze.size / 2.0
		add_child(haze)

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	_tick += delta
	if _tick < TICK_SECONDS:
		return
	_tick -= TICK_SECONDS
	for n in get_tree().get_nodes_in_group("actors"):
		if n == _actor or not n.has_method("receive_hit") or n.get("team") == _actor.get("team"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		if n.global_position.distance_to(global_position) <= radius:
			n.receive_hit(1, "poison", global_position, "poison")
			if n.has_method("slow_for"):
				n.slow_for(Enemy.SLOW_SECONDS)
