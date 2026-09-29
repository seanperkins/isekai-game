class_name TerrainLayers
extends RefCounted
## The depth stack behind and in front of a room, Hollow Knight style. Back to front: far haze,
## far rock, mid rock, the room's back wall, (terrain and actors), then a dark foreground frame.
## The three far layers wrap in x; the frame is one 640x360 image.
## Layers scroll sideways only (see TerrainParallax).

## piece -> [parallax factor, z_index, tint]. Factor 1 moves with the world, 0 stays on
## screen. Nearer layers are dimmed so the platforms in the play plane stay easy to read, and the
## foreground is a frame of roots and stalactite tips glued to the screen edges, so it never
## covers the middle of the view.
const STACK := {
	"far_haze": [0.10, -30, Color(1, 1, 1, 1)],
	"far_rock": [0.25, -28, Color(0.7, 0.7, 0.7, 1)],
	"mid_rock": [0.50, -26, Color(0.5, 0.5, 0.5, 1)],
	"foreground": [0.0, 12, Color(1, 1, 1, 0.6)],  # see-through: it frames the view without hiding a ledge
}

## Lights only reach items whose light_mask overlaps theirs. The far layers use bit 2, which no
## PointLight2D uses, so crystals and fungus do not wash them out.
const UNLIT_MASK := 2

static func build(room: Node2D, biome: String) -> void:
	for piece in STACK:
		var tex := TerrainArt.layer(biome, piece)
		if tex == null:
			continue
		var layer := TerrainParallax.new()
		layer.name = piece
		var tint: Color = STACK[piece][2]
		if piece != "foreground":  # the frame keeps its colour; the backdrop dims per biome
			var dim := TerrainArt.backdrop_dim(biome)
			tint = Color(tint.r * dim, tint.g * dim, tint.b * dim, tint.a)
		layer.setup(tex, STACK[piece][0], STACK[piece][1], UNLIT_MASK, tint)
		room.add_child(layer)

## The back wall is dimmed and mostly transparent: the parallax layers behind it show through, and
## the platforms in front of it stay easy to read.
const BACK_WALL_TINT := Color(0.62, 0.56, 0.78, 0.25)

## The dark rock face the player is in front of, sampled in room coordinates.
static func back_wall(room: Node2D, biome: String, size: Vector2) -> bool:
	var tex := TerrainArt.tile(biome, "backwall")
	if tex == null:
		return false
	var s := Sprite2D.new()
	s.name = "BackWall"
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.z_index = -20
	s.modulate = BACK_WALL_TINT
	room.add_child(s)
	return true
