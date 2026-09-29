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

## Set by TerrainLayers.build: the room's pixel height, so a tall room's layers can move vertically too.
var room_height := VIEW.y

func setup(p_texture: Texture2D, p_factor: float, p_z: int, p_light_mask: int, p_tint := Color.WHITE, p_room_height := VIEW.y) -> void:
	texture = p_texture
	factor = p_factor
	room_height = p_room_height
	z_index = p_z
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.top_level = true  # placed in world coordinates, whatever the room's position
	_sprite.z_index = p_z     # a top-level node ignores its parent's z, so it is set here
	_sprite.region_enabled = true
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_rect = Rect2(0, 0, texture.get_width() + VIEW.x, texture.get_height())
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
	var room_top: float = (get_parent() as Node2D).global_position.y if get_parent() is Node2D else center.y - VIEW.y / 2.0
	_sprite.global_position = layer_origin(center, factor, texture.get_width(), room_top, room_height)

## The world position of the layer image's top-left corner. Its left edge starts at most one
## texture width left of the view, so the repeating region always covers the view.
## Vertically the layer moves at `p_factor` too: it sits `p_factor * (how far the camera has gone down
## the room)` above where a screen-glued layer would be. The layer art is TerrainLayers.layer_height tall,
## exactly the travel that needs, so its top meets the screen top at the room's top and its bottom
## meets the screen bottom at the room's bottom, and no camera position (even mid-transition, beyond
## the room) leaves a gap. `room_top` INF means a one-screen room: glued, as before.
static func layer_origin(center: Vector2, p_factor: float, width: float, room_top: float = INF, room_height: float = VIEW.y) -> Vector2:
	var left := center.x - VIEW.x / 2.0
	var view_top := center.y - VIEW.y / 2.0
	var y := view_top
	if room_top != INF:
		y = view_top - p_factor * clampf(view_top - room_top, 0.0, maxf(0.0, room_height - VIEW.y))
	return Vector2(left - fposmod(center.x * p_factor, width), y)
