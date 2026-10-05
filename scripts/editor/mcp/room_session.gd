class_name RoomSession
extends RefCounted
## The working set behind the room MCP: one RoomEditModel loaded from a directory of rooms, edited in memory, and what each room's file
## held when it was loaded or last written. Nothing reaches disk except through save (a later task), and a file that changed on disk
## behind the session's back is noticed by comparing hashes (a modified time has only one-second resolution).

const ROOMS_DIR := "res://data/rooms"

var model: RoomEditModel
var dir: String
var _hashes := {}  # id -> SHA-256 of the room's file when loaded or last written; "" when it had none

func _init(p_dir := ROOMS_DIR) -> void:
	dir = p_dir
	reload()

## Rebuilds the model from `dir`, dropping every unsaved edit and the undo history. The files are read afresh, never from the
## resource cache, because another process may have rewritten them.
func reload() -> void:
	var ignore_cache := func(p: String) -> Resource: return ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
	var source := {}
	for r: RoomDef in DefLoader.load_dir(dir, "RoomDef", [], ignore_cache):
		source[r.id] = r
	var creatures: Array = DefLoader.load_dir("res://data/creatures", "CreatureDef")
	model = RoomEditModel.new(source, creatures.map(func(c: CreatureDef) -> String: return c.id))
	_hashes.clear()
	for id in source:
		_hashes[id] = file_hash(id)

func path_of(id: String) -> String:
	return "%s/%s.tres" % [dir, id]

## The SHA-256 of room `id`'s file, "" when there is none.
func file_hash(id: String) -> String:
	return FileAccess.get_sha256(path_of(id))

## The ids whose file differs from what the session recorded: edited elsewhere, or (for a room made here) a file that has appeared.
func changed_on_disk() -> Array:
	var ids := {}
	for id in model.rooms:
		ids[id] = true
	for id in _hashes:
		ids[id] = true
	var out: Array = []
	for id in ids:
		if file_hash(id) != _hashes.get(id, ""):
			out.append(id)
	out.sort()
	return out

func state() -> Dictionary:
	var dirty := model.dirty.keys()
	dirty.sort()
	return {
		"rooms": model.rooms.size(), "dirty": dirty, "undo_depth": model.undo_depth(), "redo_depth": model.redo_depth(),
		"changed_on_disk": changed_on_disk(),
	}
