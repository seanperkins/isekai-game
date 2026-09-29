class_name SpriteSheet
extends RefCounted
## A sheet of individually drawn frames assembled by tools/art/assemble_frames.py, with the hit
## shapes traced from each frame. Shapes are frame-local pixels, origin at the bottom centre.

const DIR := "res://assets/sheets/"

var texture: Texture2D
var _frames := {}   # name -> {"rect": Rect2, "hurt": PackedVector2Array, "attack": PackedVector2Array}
var _atlas := {}    # name -> AtlasTexture

static func available(set_name: String) -> bool:
	return ResourceLoader.exists(DIR + set_name + ".png") and FileAccess.file_exists(DIR + set_name + ".json")

static func load_set(set_name: String) -> SpriteSheet:
	if not available(set_name):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(DIR + set_name + ".json")) != OK:
		push_error("SpriteSheet: cannot read %s.json" % set_name)
		return null
	var sheet := SpriteSheet.new()
	sheet.texture = load(DIR + str(json.data["image"]))
	var frames: Dictionary = json.data["frames"]
	for name in frames:
		var f: Dictionary = frames[name]
		var r: Array = f["rect"]
		sheet._frames[name] = {
			"rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
			"hurt": _points(f["hurt"]),
			"attack": _points(f["attack"])}
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
