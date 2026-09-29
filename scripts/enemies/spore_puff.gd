class_name SporePuff
extends Node2D
## A moth's spore puff: a short-lived cloud that poisons the player once. Group `hazards` (which hurts the
## player only, like the toad's glob); the player's own Spore Cloud is a different group.

const RADIUS := 20.0
const LIFETIME := 2.0
const POISON := 1
const TICK := 1
const SECONDS := 2.0

var _age := 0.0
var _hit := false

func launch(at: Vector2) -> void:
	global_position = at
	add_to_group("hazards")

func _ready() -> void:
	if get_child_count() == 0:
		var haze := ColorRect.new()
		haze.color = Color(0.85, 0.95, 0.35, 0.35)
		haze.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
		haze.position = -haze.size / 2.0
		add_child(haze)
		add_child(Art.light(Color(0.85, 0.95, 0.4), 0.5, 0.5))

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	if _hit:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and SporePuff.hits(player, global_position):
		_hit = true
		player.receive_poison(POISON, TICK, SECONDS)

## True when a puff centred on `point` overlaps `target`: its traced shape, or the centre distance for a
## target with no shape (test stubs).
static func hits(target: Node2D, point: Vector2) -> bool:
	if target.has_method("hurt_polygon"):
		return ShapeHit.point_near(target.hurt_polygon(), point, RADIUS)
	return target.global_position.distance_to(point) <= RADIUS
