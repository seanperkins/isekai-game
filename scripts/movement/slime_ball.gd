class_name SlimeBall
extends RefCounted
## The slime as a bouncing ball: a round pixel-art body in the slime's own palette, with eyes that roll around it. Drawn
## here, a pure function of the roll, until the art has a real round frame (the sheet's frames are all dome or drop
## shaped). The body does not turn, only the eyes do. A circle, so a bounce never looks like a cone.

const SIZE := 40
const RADIUS := 20.0
const OUTLINE := Color8(8, 40, 130)
const RIM := Color8(110, 232, 255)
const EDGE := Color8(30, 190, 255)
const CORE := Color8(10, 118, 245)
const GLASS := Color8(205, 246, 255)
const EYE := Color8(7, 20, 66)
const GLINT := Color8(235, 250, 255)
## The two eyes' centres at roll 0 (px from the ball's centre, facing right) and an eye's half width and height.
const EYES: Array[Vector2] = [Vector2(7.5, 0.0), Vector2(14.0, 0.0)]
const EYE_HALF := Vector2(1.7, 3.2)

static var _body: Image

## The ball without eyes (shared: never draw on it).
static func body() -> Image:
	if _body == null:
		_body = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		var c := Vector2(SIZE, SIZE) / 2.0
		for y in SIZE:
			for x in SIZE:
				var p := Vector2(x + 0.5, y + 0.5) - c
				var d := p.length()
				if d > RADIUS:
					continue
				var col := OUTLINE
				if d <= RADIUS - 1.6:
					col = RIM
					if d <= RADIUS - 3.6:
						# a darker core, a little down and to the right, shading out to the lighter edge
						var q := (p - Vector2(2.0, 3.0)).length() / (RADIUS - 3.6)
						col = CORE.lerp(EDGE, clampf(q * q, 0.0, 1.0))
						if q > 0.55:
							col = col.lerp(RIM, (q - 0.55) * 0.9)
				_body.set_pixel(x, y, col)
		# the glassy highlight, high and to the left; it stays put while the eyes roll
		_paint(_body, c + Vector2(-8.0, -9.5), Vector2(3.4, 1.9), -0.6, GLASS)
		_paint(_body, c + Vector2(-12.5, -4.0), Vector2(1.1, 1.1), 0.0, GLASS)
	return _body

## The ball with its eyes rolled `roll` radians (clockwise on screen from facing right).
static func image(roll: float) -> Image:
	var img := body().duplicate() as Image
	var c := Vector2(SIZE, SIZE) / 2.0
	for eye in EYES:
		var centre := c + eye.rotated(roll)
		_paint(img, centre, EYE_HALF, roll, EYE)
		_paint(img, centre + Vector2(-0.4, -1.5).rotated(roll), Vector2(0.55, 0.55), 0.0, GLINT)  # a glint on the eye
	return img

static func texture(roll: float) -> ImageTexture:
	return ImageTexture.create_from_image(image(roll))

## Fills the ellipse of half sizes `half` (turned by `angle`) at `centre` with `col`, only where the ball already has a
## pixel, so nothing is ever painted outside its circle.
static func _paint(img: Image, centre: Vector2, half: Vector2, angle: float, col: Color) -> void:
	var reach := int(ceilf(maxf(half.x, half.y))) + 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var px := int(floorf(centre.x)) + dx
			var py := int(floorf(centre.y)) + dy
			if px < 0 or py < 0 or px >= SIZE or py >= SIZE or img.get_pixel(px, py).a <= 0.0:
				continue
			var local := (Vector2(px + 0.5, py + 0.5) - centre).rotated(-angle)
			if Vector2(local.x / half.x, local.y / half.y).length_squared() <= 1.0:
				img.set_pixel(px, py, col)
