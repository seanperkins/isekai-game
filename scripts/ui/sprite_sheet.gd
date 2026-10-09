class_name SpriteSheet
extends RefCounted
## A sheet of individually drawn frames assembled by tools/art/assemble_frames.py, with the hit
## shapes traced from each frame. Shapes are frame-local pixels, origin at the bottom centre.

const DIR := "res://assets/sheets/"
## Where sheets are read from; a test points it at tests/support/sheets.
static var dir := DIR

var texture: Texture2D
## The normal map laid out exactly as `texture` (tools/art/assemble_frames.py writes <set>_n.png beside the colour sheet), or null.
var normal_texture: Texture2D
var _frames := {}   # name -> {"rect": Rect2, "hurt": PackedVector2Array, "attack": PackedVector2Array, "hands": {"n": {"x", "y", "a"}, "f": {...}}}
var _atlas := {}    # name -> AtlasTexture
## Every load of a sheet shares its lit frames and its decoded images (a room of one form loads the sheet once per creature): keyed by the sheet's path, so each
## frame is cut once however many creatures wear it.
static var _lit_shared := {}     # "sheet path|name:mirrored" -> CanvasTexture
static var _images_shared := {}  # sheet path -> [colour Image, normal Image]

static func available(set_name: String) -> bool:
	return ResourceLoader.exists(dir + set_name + ".png") and FileAccess.file_exists(dir + set_name + ".json")

static func load_set(set_name: String) -> SpriteSheet:
	if not available(set_name):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(dir + set_name + ".json")) != OK:
		push_error("SpriteSheet: cannot read %s.json" % set_name)
		return null
	var sheet := SpriteSheet.new()
	sheet.texture = load(dir + str(json.data["image"]))
	if json.data.has("normal"):
		sheet.normal_texture = load(dir + str(json.data["normal"]))
	var frames: Dictionary = json.data["frames"]
	for name in frames:
		var f: Dictionary = frames[name]
		var r: Array = f["rect"]
		sheet._frames[name] = {
			"rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
			"hurt": _points(f["hurt"]),
			"attack": _points(f["attack"]),
			"hands": f.get("hands", {})}
	return sheet

static func _points(raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in raw:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out

func has_frame(name: String) -> bool:
	return _frames.has(name)

func frame_names() -> Array:
	return _frames.keys()

func frame_texture(name: String) -> Texture2D:
	if not _atlas.has(name):
		var t := AtlasTexture.new()
		t.atlas = texture
		t.region = _frames[name]["rect"]
		_atlas[name] = t
	return _atlas[name]

func frame_size(name: String) -> Vector2:
	return (_frames[name]["rect"] as Rect2).size

func hurt(name: String) -> PackedVector2Array:
	return _frames[name]["hurt"]

func attack(name: String) -> PackedVector2Array:
	return _frames[name]["attack"]

## Where each hand is in this frame and how far it is turned (degrees clockwise): {"n": {"x", "y", "a"}, "f": {...}} in the pixels of the hit shapes (origin at the
## bottom centre, y down), or {} for a frame that was exported without hands. The held-item layer puts what a goblin holds there.
func hands(name: String) -> Dictionary:
	return _frames[name]["hands"]

func has_normals() -> bool:
	return normal_texture != null

## The frame as the room's lights see it: its picture and its normal map, each cut from its sheet, as a CanvasTexture; null for a sheet with no
## normals. `mirrored` is for a creature facing left: the picture is flipped and so is the normal map, whose red channel (right) is inverted so a
## surface that faced right now faces left. Nearest filtering, as pixel art needs. Cut once.
func lit_texture(name: String, mirrored := false) -> Texture2D:
	if normal_texture == null:
		return null
	var key := "%s|%s:%d" % [texture.resource_path, name, 1 if mirrored else 0]
	if not _lit_shared.has(key):
		var rect := Rect2i(_frames[name]["rect"])
		var images := _sheet_images()
		var color: Image = (images[0] as Image).get_region(rect)
		var normal: Image = (images[1] as Image).get_region(rect)
		if mirrored:
			color.flip_x()
			normal.flip_x()
			for y in normal.get_height():
				for x in normal.get_width():
					var c := normal.get_pixel(x, y)
					if c.a > 0.0:
						normal.set_pixel(x, y, Color8(255 - c.r8, c.g8, c.b8, c.a8))  # whole numbers: no float rounding off a byte
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = ImageTexture.create_from_image(color)
		canvas.normal_texture = ImageTexture.create_from_image(normal)
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_lit_shared[key] = canvas
	return _lit_shared[key]

## The colour sheet's and the normal sheet's images, decoded once for every creature that wears the sheet.
func _sheet_images() -> Array:
	var path := texture.resource_path
	if not _images_shared.has(path):
		_images_shared[path] = [texture.get_image(), normal_texture.get_image()]
	return _images_shared[path]

## Draw a frame on a sprite, facing left or not. A sheet with normal maps is drawn lit by the room's lights, mirrored in the texture itself so its normals mirror
## with it (the sprite's flip_h stays false); a plain sheet is the frame, flipped.
func draw_on(sprite: Sprite2D, name: String, mirrored := false) -> void:
	sprite.texture = texture_of(name, mirrored)
	sprite.flip_h = mirrored and not has_normals()
	HeldItemLayer.follow_on(sprite, self, name, mirrored, has_normals())

## The texture `draw_on` puts on a sprite for this frame: the lit one for a sheet with normal maps (mirrored in the texture itself), else the plain frame
## (a sprite flips it).
func texture_of(name: String, mirrored := false) -> Texture2D:
	var lit := lit_texture(name, mirrored)
	return lit if lit != null else frame_texture(name)
