class_name Art
extends RefCounted
## Style D sprites cut by tools/art/slice_sheets.py into res://assets/sprites/.

const DIR := "res://assets/sprites/%s.png"

## Texture for a sprite name from tools/art/manifest.json, or null when it doesn't exist.
static func texture(sprite_name: String) -> Texture2D:
	var path := DIR % sprite_name
	if not ResourceLoader.exists(path):
		return null
	return load(path)

static var _light: Texture2D

## Soft radial falloff shared by every PointLight2D.
static func light_texture() -> Texture2D:
	if _light == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_light = t
	return _light

## A point light of the given color, for crystals, torches and the slime's glow.
static func light(color: Color, energy: float = 1.0, scale: float = 1.5) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	return l

## A Sprite2D named "Sprite" whose bottom edge sits `bottom` px below its parent origin.
static func sprite(sprite_name: String, bottom: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Sprite"
	set_frame(s, sprite_name, bottom)
	return s

static func set_frame(s: Sprite2D, sprite_name: String, bottom: float) -> void:
	var tex := texture(sprite_name)
	if tex == null or s.texture == tex:
		return
	s.texture = tex
	s.position.y = bottom - tex.get_height() / 2.0
