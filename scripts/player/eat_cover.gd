class_name EatCover
extends Node2D
## Eating by covering. The slime's body does not move: this node sits on the prey, hides the prey's own
## sprite, draws a copy that shrinks as the eat bar fills, and lays a translucent cover frame over it.
## The cover frame follows the progress: lunge, drape, engulf (two pulsing frames), release. Finishing
## or cancelling shows the prey's sprite again.

const PREY_MIN_SCALE := 0.2
const BODY_ALPHA := 0.8
const ENGULF_SECONDS := 0.15
const RELEASE_FROM := 0.92

var cover := Sprite2D.new()
var prey_copy := Sprite2D.new()
## The two halves of a cut corpse (killed by a blade), shrunk instead of a whole-creature copy.
var prey_halves: Node2D
var _sheet: SpriteSheet
var _target: Node2D
var _prey_sprite: Sprite2D
var _prey_was_visible := true
var _look_tint := Color.WHITE
var _look_scale := 1.0
var _cut: Node2D
var _bottom := 0.0
var _tex_height := 0.0
var _time := 0.0

static func cover_frame(progress: float, t: float) -> String:
	if progress >= RELEASE_FROM:
		return "cover_5"
	if progress < 0.1:
		return "cover_1"
	if progress < 0.2:
		return "cover_2"
	return "cover_3" if int(t / ENGULF_SECONDS) % 2 == 0 else "cover_4"

func begin(target: Node2D, sheet: SpriteSheet, left: bool = false) -> void:
	_target = target
	_sheet = sheet
	top_level = true
	_prey_sprite = target.get_node_or_null("Sprite")
	if _prey_sprite != null:
		_prey_was_visible = _prey_sprite.visible
	if _prey_sprite != null and _prey_sprite.texture != null:
		_tex_height = float(_prey_sprite.texture.get_height())
		_bottom = _prey_sprite.position.y + _tex_height / 2.0
		prey_copy.texture = _prey_sprite.texture
		prey_copy.flip_h = _prey_sprite.flip_h
		prey_copy.flip_v = _prey_sprite.flip_v
		prey_copy.modulate = _prey_sprite.modulate
		_prey_sprite.visible = false
	global_position = target.global_position + Vector2(0.0, _bottom)
	prey_copy.z_index = 0
	prey_copy.position = Vector2(0.0, -_tex_height / 2.0)
	add_child(prey_copy)
	_cut = target.cut_corpse() if target.has_method("cut_corpse") else null
	if _cut != null:
		_cut.visible = false
		prey_copy.visible = false
		prey_halves = _cut.duplicate() as Node2D
		prey_halves.visible = true
		prey_halves.position = Vector2.ZERO  # the holder sits at the feet, so the halves shrink toward the floor
		for h in prey_halves.get_children():
			(h as Node2D).position.y -= _bottom
		add_child(prey_halves)
	cover.z_index = 1
	cover.modulate.a = BODY_ALPHA
	cover.flip_h = left
	add_child(cover)
	_show("cover_1")

func tick(delta: float, progress: float) -> void:
	_time += delta
	if is_instance_valid(_target):
		global_position = _target.global_position + Vector2(0.0, _bottom)
	var s := lerpf(1.0, PREY_MIN_SCALE, clampf(progress, 0.0, 1.0))
	prey_copy.scale = Vector2(s, s)
	prey_copy.position.y = -_tex_height * s / 2.0
	if prey_halves != null:
		prey_halves.scale = Vector2(s, s)
	_show(cover_frame(progress, _time))

func finish() -> void:
	if is_instance_valid(_cut):
		_cut.visible = true
	if is_instance_valid(_prey_sprite):
		_prey_sprite.visible = _prey_was_visible
	queue_free()

## The slime's body look while it eats: a tinted, scaled base sheet when the form has no art of its own.
func set_look(tint: Color, body_scale: float) -> void:
	_look_tint = tint
	_look_scale = body_scale
	cover.scale = Vector2.ONE * body_scale
	cover.modulate = Color(tint.r, tint.g, tint.b, BODY_ALPHA)

func _show(frame: String) -> void:
	cover.texture = _sheet.frame_texture(frame)
	cover.position.y = -_sheet.frame_size(frame).y * _look_scale / 2.0
