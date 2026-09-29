class_name VfxArt
extends RefCounted
## Procedural effect textures, white and tinted in the engine so any of them can be replaced without touching a caller.
## Built like terrain_motes.gd: an Image, then ImageTexture.create_from_image, cached. The soft spray texture is
## Art.light_texture() itself.

static var _silk: Texture2D
static var _web := {}
static var _cover := {}

## A 32x4 tileable silk strand: two bright centre rows, faint outer rows, a brighter bead every 8 px.
static func silk() -> Texture2D:
	if _silk == null:
		var img := Image.create(32, 4, false, Image.FORMAT_RGBA8)
		for x in 32:
			var bead := x % 8 < 2
			img.set_pixel(x, 0, Color(1, 1, 1, 0.25))
			img.set_pixel(x, 1, Color(1, 1, 1, 1.0 if bead else 0.8))
			img.set_pixel(x, 2, Color(1, 1, 1, 1.0 if bead else 0.8))
			img.set_pixel(x, 3, Color(1, 1, 1, 0.25))
		_silk = ImageTexture.create_from_image(img)
	return _silk

## A web `px` across: 8 spokes and 3 rings. It is built from distances to the centre (absolute offsets), so it is exactly
## symmetric under a quarter turn.
static func web(px: int) -> Texture2D:
	if not _web.has(px):
		var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
		var c := (px - 1) / 2.0
		for y in px:
			for x in px:
				var dx := absf(x - c)
				var dy := absf(y - c)
				var r := sqrt(dx * dx + dy * dy)
				var ring := false
				for k in [0.35, 0.65, 0.95]:
					if absf(r - k * c) < 0.9:
						ring = true
				var spoke := dx < 0.9 or dy < 0.9 or absf(dx - dy) < 0.9
				if r <= c and (ring or spoke):
					img.set_pixel(x, y, Color(1, 1, 1, 0.9))
		_web[px] = ImageTexture.create_from_image(img)
	return _web[px]

## The Water Blade's slash: generated pixel art of a crescent of water (tools/art/vfx_frames.json, make_vfx.py), bulge to
## +x, so a sprite turned to the aim travels bulge first.
static func water_slash() -> Texture2D:
	return Art.texture("vfx_water_slash")

## How far past the frame a cover reaches: strands a little, a cocoon enough to wrap the whole body.
const STRANDS_FIT := Vector2(1.1, 1.1)
const COCOON_FIT := Vector2(1.25, 1.4)

## The webs on a webbed creature, fitted to a frame of `size` (a creature's frames differ in size, and the cover is fitted
## to whichever one is on screen). Not held: the generated strands sprite (two corner cobwebs, thick strands and silk
## clumps). Held: the generated cocoon, turned to lie down over a frame wider than it is tall. Built from the same art at
## every size, so the layout stays put from one animation frame to the next.
static func web_cover(size: Vector2i, held: bool) -> Texture2D:
	var key := "%dx%d%s" % [size.x, size.y, "h" if held else "s"]
	if not _cover.has(key):
		var img := Art.texture("vfx_web_cocoon" if held else "vfx_web_strands").get_image()
		img.convert(Image.FORMAT_RGBA8)
		var fit := COCOON_FIT if held else STRANDS_FIT
		var target := Vector2i(maxi(4, ceili(size.x * fit.x)), maxi(4, ceili(size.y * fit.y)))
		if held and size.x >= size.y:
			img.rotate_90(COUNTERCLOCKWISE)
		img.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		_cover[key] = ImageTexture.create_from_image(img)
	return _cover[key]
