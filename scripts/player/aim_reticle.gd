class_name AimReticle
extends Node2D
## Where the pointer (right stick or mouse) aims: a chevron and two dots along +X, turned to the aim each frame and drawn over
## the body. Shown only while a cast could fire; it says where the aim points, not whether a skill is ready. Fixed geometry,
## so nothing is redrawn per frame.

const COLOR := Color(0.85, 0.95, 1.0)
const CHEVRON := 28.0
const DOTS := [40.0, 52.0]

var _player: Player

func _init() -> void:
	name = "AimReticle"
	visible = false
	z_index = 7

func bind(player: Player) -> void:
	_player = player

func _process(_delta: float) -> void:
	if _player == null:
		return
	var aim := _player.free_aim()
	visible = aim != Vector2.ZERO and _player.can_cast()
	if visible:
		rotation = aim.angle()
		scale = Vector2.ONE * _player.form_size()

func _draw() -> void:
	draw_polyline(PackedVector2Array([Vector2(CHEVRON - 6.0, -6.0), Vector2(CHEVRON + 1.0, 0.0), Vector2(CHEVRON - 6.0, 6.0)]), Color(COLOR, 0.95), 3.0)
	draw_circle(Vector2(DOTS[0], 0.0), 3.0, Color(COLOR, 0.8))
	draw_circle(Vector2(DOTS[1], 0.0), 2.5, Color(COLOR, 0.55))
