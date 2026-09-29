class_name VfxArt
extends RefCounted
## Procedural effect textures, white and tinted in the engine so any of them can be replaced without touching a caller.
## Built like terrain_motes.gd: an Image, then ImageTexture.create_from_image, cached. The soft spray texture is
## Art.light_texture() itself.

static var _silk: Texture2D
static var _crescent: Texture2D
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

## A 96x48 crescent from two circles with a soft alpha edge and a bright rim, open to the right.
static func crescent() -> Texture2D:
	if _crescent == null:
		var img := Image.create(96, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 96:
				var outer := Vector2(x - 36.0, y - 24.0).length()  # the big circle: its bulge leads, toward +x
				var inner := Vector2(x - 20.0, y - 24.0).length()  # bites the crescent out of its back; the horns trail behind
				var a := clampf((24.0 - outer) / 6.0, 0.0, 1.0) * clampf((inner - 20.0) / 6.0, 0.0, 1.0)
				if a > 0.0:
					var rim := clampf(1.0 - (24.0 - outer) / 10.0, 0.0, 1.0)
					img.set_pixel(x, y, Color(1, 1, 1, a * (0.55 + 0.45 * rim)))
		_crescent = ImageTexture.create_from_image(img)
	return _crescent

## The webs on a webbed creature, drawn over a frame of exactly `size` so one texel is one pixel of the creature. Not held:
## a few strands across it and a small fan in one corner. Held: a pale wrap over the whole body with dense strands and an
## outline over it. Seeded by the size, so a given frame always gets the same webs.
static func web_cover(size: Vector2i, held: bool) -> Texture2D:
	var key := "%dx%d%s" % [size.x, size.y, "h" if held else "s"]
	if not _cover.has(key):
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = size.x * 1000 + size.y + (7 if held else 0)
		if held:
			_wrap(img, size, rng)
		else:
			_strands(img, size, rng)
		_cover[key] = ImageTexture.create_from_image(img)
	return _cover[key]

const SILK := Color(0.95, 0.98, 1.0)

static func _strands(img: Image, size: Vector2i, rng: RandomNumberGenerator) -> void:
	var w := float(size.x - 1)
	var h := float(size.y - 1)
	_line(img, Vector2(rng.randf_range(0.15, 0.45) * w, 0), Vector2(rng.randf_range(0.5, 0.85) * w, h), 0.9)
	_line(img, Vector2(rng.randf_range(0.5, 0.85) * w, 0), Vector2(rng.randf_range(0.15, 0.5) * w, h), 0.9)
	_line(img, Vector2(0, rng.randf_range(0.2, 0.5) * h), Vector2(w, rng.randf_range(0.5, 0.8) * h), 0.9)
	# a small corner web: three spokes and a bridge across each gap
	var reach := minf(w, h) * 0.45
	var spokes := []
	for deg in [8.0, 45.0, 82.0]:
		var dir := Vector2.from_angle(deg_to_rad(deg))
		spokes.append(dir)
		_line(img, Vector2.ZERO, dir * reach, 0.9)
	for i in 2:
		_line(img, spokes[i] * reach * 0.5, spokes[i + 1] * reach * 0.5, 0.9)
		_line(img, spokes[i] * reach, spokes[i + 1] * reach, 0.9)

static func _wrap(img: Image, size: Vector2i, rng: RandomNumberGenerator) -> void:
	var c := Vector2(size.x - 1, size.y - 1) / 2.0
	for y in size.y:
		for x in size.x:
			var d := Vector2((x - c.x) / (size.x / 2.0), (y - c.y) / (size.y / 2.0)).length()
			if d <= 1.0:
				img.set_pixel(x, y, Color(SILK, 0.95 if d > 0.85 else 0.45))  # the wrap, with a firmer edge
	for i in 16:  # dense strands: chords between random points of the outline
		var a := Vector2.from_angle(rng.randf() * TAU)
		var b := Vector2.from_angle(rng.randf() * TAU)
		_line(img, c + a * c, c + b * c, 1.0)

static func _line(img: Image, from: Vector2, to: Vector2, alpha: float) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y))) + 1
	for i in steps + 1:
		var p := from.lerp(to, float(i) / float(steps))
		var x := roundi(p.x)
		var y := roundi(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, Color(SILK, alpha))
