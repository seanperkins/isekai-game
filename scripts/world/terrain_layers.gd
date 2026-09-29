class_name TerrainLayers
extends RefCounted
## The depth stack behind and in front of a room, Hollow Knight style. Back to front: far haze,
## far rock, mid rock, the room's back wall, a foreground frame of hanging roots, then terrain and actors.
## The three far layers wrap in x; the frame is one 640x360 image.
## Layers scroll sideways only (see TerrainParallax).

## piece -> [parallax factor, z_index, tint]. Factor 1 moves with the world, 0 stays on
## screen. Nearer layers are dimmed so the platforms in the play plane stay easy to read, and the
## foreground is a frame of roots and stalactite tips glued to the screen edges. It sits behind the
## terrain, decor and actors, so it can never cover a creature or a ledge.
const STACK := {
	"far_haze": [0.10, -30, Color(1, 1, 1, 1)],
	"far_rock": [0.25, -28, Color(0.7, 0.7, 0.7, 1)],
	"mid_rock": [0.50, -26, Color(0.5, 0.5, 0.5, 1)],
	"foreground": [0.0, -5, Color(1, 1, 1, 0.6)],  # behind terrain, decor and actors (z 0 and up): scenery never covers what you play with
}

## Lights only reach items whose light_mask overlaps theirs. The far layers use bit 2, which no
## PointLight2D uses, so crystals and fungus do not wash them out.
const UNLIT_MASK := 2

## The frame is scenery over the top of the view. Below FADE_START (screen pixels, of 360) it fades out,
## and it is gone by FADE_END, so the ferns, crystals and mushrooms down its sides never draw over
## creatures or ledges in the play band.
const FADE_START := 70.0
const FADE_END := 130.0

static var _frames := {}

## The biome's foreground frame with the play band faded out, built once per biome. Null when the
## biome has no frame.
static func foreground_texture(biome: String) -> Texture2D:
	if _frames.has(biome):
		return _frames[biome]
	var src := TerrainArt.layer(biome, "foreground")
	if src == null:
		return null
	var img := src.get_image()
	for y in img.get_height():
		var keep := 1.0 - smoothstep(FADE_START, FADE_END, float(y))
		if keep >= 1.0:
			continue
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				c.a *= keep
				img.set_pixel(x, y, c)
	_frames[biome] = ImageTexture.create_from_image(img)
	return _frames[biome]

static func build(room: Node2D, biome: String) -> void:
	for piece in STACK:
		var tex := foreground_texture(biome) if piece == "foreground" else TerrainArt.layer(biome, piece)
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
