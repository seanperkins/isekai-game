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
static var _tall := {}

## Rows kept from the top and bottom of a layer when it is extended for a tall room: the ceiling
## fringe and the floor formations. Between them the art's middle rows blend (over FADE_ROWS each) into
## a smeared band of haze, so a tall shaft has no repeated or mirrored rocks.
const KEEP_TOP := 130.0
const KEEP_BOTTOM := 130.0
const FADE_ROWS := 50.0

## How tall a parallax layer of `factor` must be for a room `room_height` px tall: the screen plus the
## distance the layer travels while the camera goes from the room's top to its bottom.
static func layer_height(factor: float, room_height: float) -> int:
	return int(ceil(360.0 + factor * maxf(0.0, room_height - 360.0)))

## `src` extended to `height` rows; `src` itself when it is tall enough. The top and bottom KEEP rows are
## the source's own. The rows between blend, over FADE_ROWS each, into one smeared row of haze (the
## average of the art's middle rows) that fills the extra height, so the shaft between the ceiling and
## the floor is featureless instead of repeating the art.
static func tall_texture(src: Texture2D, height: int) -> Texture2D:
	if height <= src.get_height():
		return src
	var key := "%d:%d" % [src.get_rid().get_id(), height]
	if _tall.has(key):
		return _tall[key]
	var a := src.get_image()
	a.convert(Image.FORMAT_RGBA8)
	var w := a.get_width()
	var sh := a.get_height()
	var top := int(KEEP_TOP)
	var bottom := int(KEEP_BOTTOM)
	var fade := int(FADE_ROWS)
	var out := Image.create(w, height, false, Image.FORMAT_RGBA8)
	out.blit_rect(a, Rect2i(0, 0, w, top), Vector2i(0, 0))
	out.blit_rect(a, Rect2i(0, sh - bottom, w, bottom), Vector2i(0, height - bottom))
	var smear := _haze_row(a, top, sh - bottom)
	for k in fade:
		var t := smoothstep(0.0, 1.0, float(k + 1) / float(fade + 1))
		for x in w:
			out.set_pixel(x, top + k, _mix(a.get_pixel(x, top + k), smear[x], t))
			out.set_pixel(x, height - bottom - 1 - k, _mix(a.get_pixel(x, sh - bottom - 1 - k), smear[x], t))
	var rows := height - top - bottom - 2 * fade
	if rows > 0:
		var strip := Image.create(w, 1, false, Image.FORMAT_RGBA8)
		for x in w:
			strip.set_pixel(x, 0, smear[x])
		strip.resize(w, rows, Image.INTERPOLATE_NEAREST)
		out.blit_rect(strip, Rect2i(0, 0, w, rows), Vector2i(0, top + fade))
	var tex := ImageTexture.create_from_image(out)
	_tall[key] = tex
	return tex

## Each column's average colour over the middle source rows [from, to), alpha-weighted so transparent
## pixels do not darken it.
static func _haze_row(a: Image, from: int, to: int) -> Array:
	var mid := (from + to) / 2
	var lo := maxi(from, mid - 6)
	var hi := mini(to, mid + 7)
	var row: Array = []
	for x in a.get_width():
		var r := 0.0
		var g := 0.0
		var b := 0.0
		var al := 0.0
		for y in range(lo, hi):
			var c := a.get_pixel(x, y)
			r += c.r * c.a
			g += c.g * c.a
			b += c.b * c.a
			al += c.a
		var n := float(hi - lo)
		row.append(Color(r / al, g / al, b / al, al / n) if al > 0.0 else Color(0, 0, 0, 0))
	return row

## `from` blended toward `to` by t, alpha-weighted.
static func _mix(from: Color, to: Color, t: float) -> Color:
	var af := from.a * (1.0 - t)
	var at := to.a * t
	var al := af + at
	if al <= 0.0:
		return Color(0, 0, 0, 0)
	return Color((from.r * af + to.r * at) / al, (from.g * af + to.g * at) / al, (from.b * af + to.b * at) / al, al)

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

static func build(room: Node2D, biome: String, size: Vector2 = Vector2(640, 360)) -> void:
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
		if piece != "foreground":
			tex = tall_texture(tex, layer_height(STACK[piece][0], size.y))
		layer.setup(tex, STACK[piece][0], STACK[piece][1], UNLIT_MASK, tint, size.y)
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
