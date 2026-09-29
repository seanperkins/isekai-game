class_name TerrainMotes
extends RefCounted
## Drifting particles that make a room feel alive, one additive emitter per room, sized to the room.
## Each biome moves differently, so its air feels different: the Cave has prismatic pollen, the
## Grotto slow warm spores that sink and sway, the Flooded Tunnels bubbles that rise.

const PER_100K_PX := 9  # base motes per 100,000 px of room area

## amount: multiplier on the base count. dir/spread/speed: launch. gravity: constant pull (y up is
## negative). scale: min/max size. ring: a hollow bubble instead of a soft dot.
const STYLES := {
	"cave": {"colors": [Color(1.0, 0.6, 0.8), Color(1.0, 0.9, 0.5), Color(0.6, 1.0, 0.8), Color(0.5, 0.9, 1.0), Color(0.8, 0.65, 1.0)],
		"amount": 1.0, "dir": Vector2(0.3, -1.0), "spread": 40.0, "speed": Vector2(4, 12), "gravity": Vector2.ZERO,
		"scale": Vector2(1.0, 2.0), "lifetime": 9.0, "ring": false},
	"grotto": {"colors": [Color(1.0, 0.75, 0.3), Color(1.0, 0.5, 0.7), Color(1.0, 0.9, 0.6), Color(0.9, 0.6, 1.0)],
		"amount": 1.8, "dir": Vector2(1.0, 0.25), "spread": 70.0, "speed": Vector2(3, 9), "gravity": Vector2(0, 2.5),
		"scale": Vector2(1.4, 2.8), "lifetime": 12.0, "ring": false},
	"flooded": {"colors": [Color(0.8, 1.0, 1.0), Color(0.6, 0.95, 1.0), Color(1.0, 1.0, 1.0)],
		"amount": 1.2, "dir": Vector2(0.0, -1.0), "spread": 18.0, "speed": Vector2(14, 30), "gravity": Vector2(0, -3.0),
		"scale": Vector2(0.6, 1.1), "lifetime": 7.0, "ring": true},
}

static func style(biome: String) -> Dictionary:
	return STYLES.get(biome, STYLES["cave"])

static func build(room: Node2D, size: Vector2, biome := "cave") -> CPUParticles2D:
	var s := style(biome)
	var p := CPUParticles2D.new()
	p.name = "Motes"
	p.amount = maxi(8, int(size.x * size.y / 100000.0 * PER_100K_PX * float(s["amount"])))
	p.lifetime = s["lifetime"]
	p.preprocess = p.lifetime  # the room is already full of motes when you arrive
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size / 2.0
	p.position = size / 2.0
	p.direction = s["dir"]
	p.spread = s["spread"]
	p.initial_velocity_min = s["speed"].x
	p.initial_velocity_max = s["speed"].y
	p.gravity = s["gravity"]
	p.scale_amount_min = s["scale"].x
	p.scale_amount_max = s["scale"].y
	p.texture = _ring() if s["ring"] else _dot()
	p.color_ramp = _fade()
	p.color_initial_ramp = _palette(s["colors"])
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.z_index = 8  # over the terrain and actors, under the foreground frame
	room.add_child(p)
	return p

static func _fade() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	return g

static func _palette(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / float(maxi(1, colors.size() - 1)))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g

static var _dot_texture: Texture2D
static var _ring_texture: Texture2D

## A soft 5 px round dot.
static func _dot() -> Texture2D:
	if _dot_texture == null:
		var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
		for y in 5:
			for x in 5:
				var d := Vector2(x - 2, y - 2).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d / 2.6, 0.0, 1.0)))
		_dot_texture = ImageTexture.create_from_image(img)
	return _dot_texture

## A hollow, round 9 px bubble with a bright glint.
static func _ring() -> Texture2D:
	if _ring_texture == null:
		var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
		for y in 9:
			for x in 9:
				var d := Vector2(x - 4, y - 4).length()
				var a := 0.0
				if d >= 3.2 and d <= 4.3:
					a = 0.85
				elif d < 3.2:
					a = 0.10
				img.set_pixel(x, y, Color(1, 1, 1, a))
		for glint in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
			img.set_pixelv(glint, Color(1, 1, 1, 1.0))
		_ring_texture = ImageTexture.create_from_image(img)
	return _ring_texture
