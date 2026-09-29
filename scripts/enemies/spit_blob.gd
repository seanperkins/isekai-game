class_name SpitBlob
extends Node2D
## A toad's poison glob. It flies in an arc to where the player stood when it was spat, so it
## can be dodged; rock stops it. Hitting the player applies the toad's poison.

const GRAVITY := 600.0
const FLIGHT_SECONDS := 0.6
const HIT_RADIUS := 10.0  # centre distance, for a target with no shape (test stubs)
## The glob's own size when tested against a traced shape.
const GLOB_RADIUS := 3.0
const LIFETIME := 2.5

var velocity := Vector2.ZERO
var _damage := 0
var _tick := 0
var _seconds := 0.0
var _age := 0.0

## The launch velocity that lands on `to` after FLIGHT_SECONDS under GRAVITY.
static func launch_velocity(from: Vector2, to: Vector2) -> Vector2:
	var t := FLIGHT_SECONDS
	return Vector2((to.x - from.x) / t, (to.y - from.y) / t - 0.5 * GRAVITY * t)

func launch(from: Vector2, to: Vector2, damage: int, tick: int, seconds: float) -> void:
	global_position = from
	velocity = launch_velocity(from, to)
	_damage = damage
	_tick = tick
	_seconds = seconds
	add_to_group("hazards")

func _ready() -> void:
	if get_child_count() == 0:
		var glob := ColorRect.new()
		glob.color = Color(0.55, 0.95, 0.3)
		glob.size = Vector2(5, 5)
		glob.position = Vector2(-2.5, -2.5)
		add_child(glob)
		add_child(Art.light(Color(0.5, 1.0, 0.3), 0.6, 0.4))

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	var next := global_position + velocity * delta
	if _hits_rock(global_position, next):
		queue_free()
		return
	global_position = next
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and SpitBlob.hits(player, global_position):
		player.receive_poison(_damage, _tick, _seconds)
		queue_free()

## True when a glob at `point` hits `target`: within its traced shape (plus the glob's size), or the
## old centre distance for a target with no shape.
static func hits(target: Node2D, point: Vector2) -> bool:
	if target.has_method("hurt_polygon"):
		return ShapeHit.point_near(target.hurt_polygon(), point, GLOB_RADIUS)
	return target.global_position.distance_to(point) <= HIT_RADIUS

func _hits_rock(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	var skip: Array[RID] = []
	for n in get_tree().get_nodes_in_group("actors"):
		if n is CollisionObject2D:
			skip.append(n.get_rid())
	for n in get_tree().get_nodes_in_group("player"):
		if n is CollisionObject2D:
			skip.append(n.get_rid())
	query.exclude = skip
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()
