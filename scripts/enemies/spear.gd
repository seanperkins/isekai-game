class_name Spear
extends SpitBlob
## The Bog Lizardman's spear: a straight, flat, fast line at where the player stood, a physical hit for the creature's ATK,
## stopped by rock (the blob's own test).

const SPEED := 220.0

func launch(from: Vector2, to: Vector2, damage: int, tick: int, seconds: float) -> void:
	global_position = from
	velocity = (to - from).normalized() * SPEED
	gravity = 0.0
	_damage = damage
	_tick = tick
	_seconds = seconds
	rotation = velocity.angle()
	add_to_group("hazards")

func _hit(player: Node2D) -> void:
	player.receive_hit(_damage, "physical", global_position)

func _look() -> void:
	var shaft := ColorRect.new()
	shaft.color = Color(0.62, 0.45, 0.25)
	shaft.size = Vector2(10, 2)
	shaft.position = Vector2(-14, -1)  # the tip ends at the node's origin, which is the hit point
	add_child(shaft)
	var tip := ColorRect.new()
	tip.color = Color(0.85, 0.88, 0.9)
	tip.size = Vector2(4, 2)
	tip.position = Vector2(-4, -1)
	add_child(tip)
