class_name VfxArt
extends RefCounted
## Procedural effect textures, white and tinted in the engine so any of them can be replaced without touching a caller.
## Built like terrain_motes.gd: an Image, then ImageTexture.create_from_image, cached. The soft spray texture is
## Art.light_texture() itself.

static var _silk: Texture2D
static var _crescent: Texture2D
static var _web := {}

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

## A 96x48 crescent from two circles with a soft alpha edge and a bright rim, open to the right.
static func crescent() -> Texture2D:
	if _crescent == null:
		var img := Image.create(96, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 96:
				var outer := Vector2(x - 24.0, y - 24.0).length()  # the big circle
				var inner := Vector2(x - 40.0, y - 24.0).length()  # bites the crescent out of it
				var a := clampf((24.0 - outer) / 6.0, 0.0, 1.0) * clampf((inner - 20.0) / 6.0, 0.0, 1.0)
				if a > 0.0:
					var rim := clampf(1.0 - (24.0 - outer) / 10.0, 0.0, 1.0)
					img.set_pixel(x, y, Color(1, 1, 1, a * (0.55 + 0.45 * rim)))
		_crescent = ImageTexture.create_from_image(img)
	return _crescent
