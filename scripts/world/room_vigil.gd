class_name RoomVigil
extends RoomDeed
## A place to keep watch: standing within NEAR px for SECONDS without taking damage is `vigil_kept`, once per life per vigil. A hit, or walking
## away, starts the watch again.

const NEAR := 40.0
const SECONDS := 10.0

var _held := 0.0
var _hp := -1

func _ready() -> void:
	if get_child_count() == 0:
		var candle := ColorRect.new()
		candle.color = Color(0.9, 0.9, 0.8)
		candle.size = Vector2(3, 8)
		candle.position = Vector2(-1.5, -8)
		add_child(candle)
		add_child(Art.light(Color(1.0, 0.9, 0.6), 0.7, 1.0))

func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		step(p, delta)

## One look at the player (a test calls it with a double).
func step(p: Node2D, delta: float) -> void:
	if _done:
		return
	var hp: int = p.health.hp
	if _hp >= 0 and hp < _hp:
		_held = 0.0
	_hp = hp
	if p.global_position.distance_to(global_position + Vector2(0.0, -14.0)) <= NEAR:
		_held += delta
	else:
		_held = 0.0
	if _held >= SECONDS:
		report(Deeds.VIGIL_KEPT)
