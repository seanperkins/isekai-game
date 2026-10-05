class_name RoomSession
extends RefCounted
## The working set behind the room MCP: one RoomEditModel loaded from a directory of rooms, edited in memory, and what each room's file
## held when it was loaded or last written. Nothing reaches disk except through save, and a file that changed on disk
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

## Writes the rooms with unsaved edits (or just `ids` of them) into `dir`, through the model's own save. A room whose file no longer
## holds what the session loaded or last wrote is refused unless `force`: someone else wrote it. Returns {saved, removed, errors,
## problems}: `errors` is id -> reason (a room that was asked for but has no unsaved edits is named too), `problems` the current
## problems of the saved rooms (informational: they never block a save).
func save(ids: Array = [], force := false) -> Dictionary:
	var errors := {}
	var only: Array = []
	for id: String in (ids if not ids.is_empty() else model.dirty.keys()):
		if not model.rooms.has(id):
			errors[id] = "no room '%s'" % id
		elif not model.dirty.has(id):
			errors[id] = "no unsaved changes"
		elif not force and file_hash(id) != _hashes.get(id, ""):
			errors[id] = "changed on disk since loaded"
		else:
			only.append(id)
	var saved: Array = []
	var removed: Array = []
	if not only.is_empty():  # an empty `only` would mean every dirty room
		var written := model.save_dirty(dir, only)
		saved = written["saved"]
		removed = written["removed"]
		errors.merge(written["errors"])
	for id: String in saved:
		_hashes[id] = file_hash(id)
	for id: String in removed:
		_hashes.erase(id)
	var problems: Array = []
	for p: Dictionary in model.problems():
		if saved.has(p["room"]):
			problems.append(RoomSpec.plain(p))
	return {"saved": saved, "removed": removed, "errors": errors, "problems": problems}

## Drops every unsaved edit and the undo history and reads the disk again.
func revert() -> void:
	reload()

func state() -> Dictionary:
	var dirty := model.dirty.keys()
	dirty.sort()
	return {
		"rooms": model.rooms.size(), "dirty": dirty, "undo_depth": model.undo_depth(), "redo_depth": model.redo_depth(),
		"changed_on_disk": changed_on_disk(),
	}
