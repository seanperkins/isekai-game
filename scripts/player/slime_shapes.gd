class_name SlimeShapes
extends Node2D
## Hurt and attack shapes that follow the slime's drawn frame (traced when the sheet was assembled).
## Inert for now (collision layers 0): the shapes follow the art, and the enemy plan switches the game's
## damage checks over to shapes on both sides. Positions are local: the origin is the body's bottom
## centre, and everything is mirrored when the slime faces left.

var hurt := Area2D.new()
var attack := Area2D.new()
var hurt_poly := CollisionPolygon2D.new()
var attack_poly := CollisionPolygon2D.new()

func _init() -> void:
	hurt.name = "Hurt"
	attack.name = "Attack"
	for a in [hurt, attack]:
		a.collision_layer = 0
		a.collision_mask = 0
	hurt.add_child(hurt_poly)
	attack.add_child(attack_poly)
	add_child(hurt)
	add_child(attack)
	attack_poly.disabled = true

func refresh(sheet: SpriteSheet, frame: String, left: bool) -> void:
	hurt_poly.polygon = _mirrored(sheet.hurt(frame), left)
	var front := sheet.attack(frame)
	attack_poly.polygon = _mirrored(front, left)
	attack_poly.disabled = front.size() < 3

static func _mirrored(points: PackedVector2Array, left: bool) -> PackedVector2Array:
	if not left:
		return points
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(-p.x, p.y))
	return out
