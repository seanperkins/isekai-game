class_name SetDressing
extends Node2D
## A room's hand-placed scenery: props at different depths behind the terrain and creatures. Each entry
## is {"piece", "pos" (local room px), "factor", optional "flip"}. A prop sits exactly at `pos` when the
## camera is centred on it and drifts with its depth elsewhere, on both axes: factor 1 moves with the
## world, 0 stays glued to the screen. Farther props are hazier and brighter, nearer ones dimmer, so the
## play plane stays readable. This is Hollow Knight's authoring model (layers on a Z axis, composed per
## room) without a 3D scene.

const MAX_PROPS := 40
const FACTOR_MIN := 0.1
const FACTOR_MAX := 0.9
## Behind the terrain, decor and actors (z 0 and up), in front of the back wall and the far layers.
const Z_FAR := -25
const Z_NEAR := -6
## The bit the far layers use; no light has it, so crystals and fungus do not wash props out.
const UNLIT_MASK := 2
const HAZE := {"cave": Color(0.78, 0.72, 1.0)}
const HAZE_DEFAULT := Color(0.8, 0.8, 0.9)
## A prop this far outside the view is hidden (the renderer would cull it anyway).
const CULL_MARGIN := 240.0
const VIEW := Vector2(640, 360)

var _biome := ""

## Where a prop authored at `pos` is drawn for a camera centred on `camera`.
static func prop_position(pos: Vector2, camera: Vector2, factor: float) -> Vector2:
	return camera + factor * (pos - camera)

static func z_for(factor: float) -> int:
	var t := inverse_lerp(FACTOR_MIN, FACTOR_MAX, clampf(factor, FACTOR_MIN, FACTOR_MAX))
	return int(round(lerpf(float(Z_FAR), float(Z_NEAR), t)))

## Far props are thin and bright and take the biome's haze; near props are dim and solid.
static func tint(factor: float, haze: Color) -> Color:
	var far := 1.0 - inverse_lerp(FACTOR_MIN, FACTOR_MAX, clampf(factor, FACTOR_MIN, FACTOR_MAX))
	var b := lerpf(0.5, 0.78, far)
	var lit := Color(b, b, b).lerp(Color(b * haze.r, b * haze.g, b * haze.b), far * 0.7)
	lit.a = lerpf(0.95, 0.65, far)
	return lit

## Builds a `Dressing` node under `room` from the room's entries, or returns null when the biome has no
## piece library. Entries with an unknown piece or no valid factor are skipped; no more than MAX_PROPS.
static func build(room: Node2D, biome: String, dressing: Array) -> SetDressing:
	if not DressingLib.has_biome(biome):
		return null
	var node := SetDressing.new()
	node.name = "Dressing"
	node._biome = biome
	var haze: Color = HAZE.get(biome, HAZE_DEFAULT)
	var built := 0
	for e in dressing:
		if built >= MAX_PROPS:
			break
		if typeof(e) != TYPE_DICTIONARY or not e.has("piece") or not e.has("pos") or not e.has("factor"):
			continue
		var tex := DressingLib.texture(biome, str(e["piece"]))
		if tex == null:
			continue
		var f := float(e["factor"])
		var s := Sprite2D.new()
		s.texture = tex
		s.top_level = true  # placed in world coordinates, whatever the room's position
		s.z_index = z_for(f)
		s.light_mask = UNLIT_MASK
		s.modulate = tint(f, haze)
		s.flip_h = bool(e.get("flip", false))
		var h := float(tex.get_height())
		match DressingLib.anchor(biome, str(e["piece"])):
			"top":
				s.offset = Vector2(0.0, h / 2.0)
			"bottom":
				s.offset = Vector2(0.0, -h / 2.0)
		s.set_meta("pos", e["pos"] as Vector2)
		s.set_meta("factor", f)
		node.add_child(s)
		built += 1
	room.add_child(node)
	return node

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		follow(cam.get_screen_center_position())

## Places every prop for a camera centred on `camera` (world coordinates).
func follow(camera: Vector2) -> void:
	var origin := (get_parent() as Node2D).global_position if get_parent() is Node2D else Vector2.ZERO
	var view := Rect2(camera - VIEW / 2.0, VIEW).grow(CULL_MARGIN)
	for s in get_children():
		var sprite := s as Sprite2D
		var at := prop_position(origin + (sprite.get_meta("pos") as Vector2), camera, float(sprite.get_meta("factor")))
		sprite.global_position = at
		sprite.visible = view.has_point(at)
