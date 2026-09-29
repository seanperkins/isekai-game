class_name WebCover
extends Sprite2D
## The webs on a webbed enemy, drawn over its sprite: a few strands while a thread slows it, a full cocoon while a thread
## holds it. Enemy decides when; this only fits the texture to the frame it sits over.

func _init() -> void:
	name = "WebCover"
	visible = false

func show_over(sprite: Sprite2D, held: bool) -> void:
	if sprite == null or sprite.texture == null:
		visible = false
		return
	texture = VfxArt.web_cover(Vector2i(sprite.texture.get_size()), held)
	position = sprite.position
	offset = sprite.offset
	flip_h = sprite.flip_h
	visible = true
