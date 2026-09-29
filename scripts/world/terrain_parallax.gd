class_name TerrainParallax
extends Node2D
## One wrapping background layer. It follows the camera, so it always fills the view, and slides
## sideways at `factor` times the camera's speed: below 1 it lags behind the world (far away),
## above 1 it races past (in front). It never moves vertically, so a tall shaft keeps its ceiling
## fringe at the top of the screen and its floor formations at the bottom.
##
## Godot's Parallax2D was tried first, but it anchors the layer to the world origin, and rooms sit
## far from it.

const VIEW := Vector2(640, 360)

var factor := 1.0
var texture: Texture2D
var _sprite := Sprite2D.new()

func setup(p_texture: Texture2D, p_factor: float, p_z: int, p_light_mask: int, p_tint := Color.WHITE) -> void:
	texture = p_texture
	factor = p_factor
	z_index = p_z
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.top_level = true  # placed in world coordinates, whatever the room's position
	_sprite.z_index = p_z     # a top-level node ignores its parent's z, so it is set here
	_sprite.region_enabled = true
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_rect = Rect2(0, 0, texture.get_width() + VIEW.x, VIEW.y)
	_sprite.light_mask = p_light_mask
	_sprite.modulate = p_tint
	light_mask = p_light_mask
	add_child(_sprite)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		follow(cam.get_screen_center_position())

## Places the layer for a camera centred on `center`.
func follow(center: Vector2) -> void:
	_sprite.global_position = layer_origin(center, factor, texture.get_width())

## The world position of the layer image's top-left corner. Its left edge starts at most one
## texture width left of the view, so the repeating region always covers the view.
static func layer_origin(center: Vector2, p_factor: float, width: float) -> Vector2:
	var left := center.x - VIEW.x / 2.0
	return Vector2(left - fposmod(center.x * p_factor, width), center.y - VIEW.y / 2.0)
