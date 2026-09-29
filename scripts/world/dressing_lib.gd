class_name DressingLib
extends RefCounted
## The set-dressing piece library for a biome: res://assets/dressing/<biome>/<piece>.png plus a
## pieces.json manifest (each piece's size and anchor), built by tools/art/assemble_pieces.py.
## A biome without a library answers "no pieces" everywhere, so its rooms simply have no dressing.

const DIR := "res://assets/dressing/%s/"

static var _manifests := {}
static var _textures := {}  # "biome/piece" -> Texture2D

static func _manifest(biome: String) -> Dictionary:
	if _manifests.has(biome):
		return _manifests[biome]
	var path := (DIR % biome) + "pieces.json"
	var data := {}
	if FileAccess.file_exists(path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and typeof(json.data) == TYPE_DICTIONARY:
			data = json.data
	_manifests[biome] = data
	return data

static func has_biome(biome: String) -> bool:
	return not _manifest(biome).get("pieces", {}).is_empty()

static func piece_names(biome: String) -> Array:
	return _manifest(biome).get("pieces", {}).keys()

static func has_piece(biome: String, piece: String) -> bool:
	return _manifest(biome).get("pieces", {}).has(piece)

static func size(biome: String, piece: String) -> Vector2:
	var p: Dictionary = _manifest(biome).get("pieces", {}).get(piece, {})
	if p.is_empty():
		return Vector2.ZERO
	return Vector2(float(p["size"][0]), float(p["size"][1]))

static func anchor(biome: String, piece: String) -> String:
	return str(_manifest(biome).get("pieces", {}).get(piece, {}).get("anchor", "center"))

## The piece's texture, or null when the biome has no such piece (or its image is missing).
static func texture(biome: String, piece: String) -> Texture2D:
	if not has_piece(biome, piece):
		return null
	var key := "%s/%s" % [biome, piece]
	if _textures.has(key):
		return _textures[key]
	var path := (DIR % biome) + piece + ".png"
	if not ResourceLoader.exists(path):
		return null
	_textures[key] = load(path)
	return _textures[key]
