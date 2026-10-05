class_name AreaBuilder
extends RefCounted
## Builds the world's new areas in code. It loads the hand-authored rooms (every room that is not one a module makes), lets each module
## build and attach, and hands back the whole world to be checked and written. Generated rooms are made afresh on every run and the exits
## to them, and the features and spawns the modules attached (marked `by`), are stripped from the hand-authored rooms before the modules attach them again, so a run from what a run wrote gives the same world.

const ROOMS_DIR := "res://data/rooms"
## Godot picks a fresh random id for the script resource on every save; pinning it makes a save reproducible.
const SCRIPT_ID := "1_roomdef"
const DEFAULT_TMP_PATH := "user://area_builder_tmp.tres"

## Where serialize saves a room to read its text back (a test points it somewhere that cannot be written to).
static var tmp_path := DEFAULT_TMP_PATH

static func modules() -> Array:
	return AreaRegistry.modules()

static func build() -> Dictionary:
	return build_with(modules())

## `report`, when given, receives what the modules say they could not do (AreaModule.problems).
static func build_with(mods: Array, dir := ROOMS_DIR, report: Array = []) -> Dictionary:
	var prefixes: Array = []
	for m in mods:
		if m.prefix() != "":
			prefixes.append(m.prefix())
	var world := {}
	for id in World.load_rooms(dir):
		if not _generated(id, prefixes):
			world[id] = copy_room(World.load_rooms(dir)[id])
	for id in world:
		var r: RoomDef = world[id]
		r.exits = r.exits.filter(func(e: Dictionary) -> bool: return not _generated(str(e.get("room", "")), prefixes))
		r.features = r.features.filter(func(f: Dictionary) -> bool: return not prefixes.has(str(f.get("by", ""))))
		r.spawns = r.spawns.filter(func(sp: Dictionary) -> bool: return not prefixes.has(str(sp.get("by", ""))))
	for m in mods:
		m.build(world)
		report.append_array(m.problems())
	return world

## An id a module makes: its prefix and then digits only.
static func _generated(id: String, prefixes: Array) -> bool:
	for p in prefixes:
		if id.begins_with(p) and id.substr(p.length()).is_valid_int():
			return true
	return false

## A copy of a loaded room that can be changed without changing the cached resource other code holds.
static func copy_room(r: RoomDef) -> RoomDef:
	var c := RoomDef.new()
	for p in r.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or p["name"] == "script":
			continue
		var v = r.get(p["name"])
		c.set(p["name"], v.duplicate(true) if (v is Array or v is Dictionary) else v)
	return c

## Every WorldValidator error and RoomLint finding of a world, as text lines.
static func problems(world: Dictionary) -> PackedStringArray:
	var creature_ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c: CreatureDef) -> String: return c.id)
	var out := WorldValidator.validate(world, creature_ids, DefLoader.load_dir("res://data/perks", "PerkDef"))
	for id in world:
		if not RoomEditModel.valid_id(id):  # an id is a file name: it must not be able to name another place
			out.append("%s: not a plain room id" % id)
	for f in RoomLint.check(world):
		out.append("%s [%s] %s" % [f["room"], f["rule"], f["text"]])
	return out

## The .tres text of a room, as Godot writes it, with the script's resource id pinned; "" when it could not be saved.
static func serialize(r: RoomDef) -> String:
	if ResourceSaver.save(r, tmp_path) != OK:
		return ""
	var text := FileAccess.get_file_as_string(tmp_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	return pin_script_id(text)

static func pin_script_id(text: String) -> String:
	var re := RegEx.new()
	re.compile("1_[a-z0-9]{5}")
	var lines := text.split("\n")
	for i in lines.size():
		if lines[i].begins_with("[ext_resource") or lines[i].begins_with("script = ExtResource("):
			lines[i] = re.sub(lines[i], SCRIPT_ID, true)
	return "\n".join(lines)

## Whether two rooms hold the same content (every stored property equal). A file written by hand may order its properties differently from the
## one Godot writes; that is not a change.
static func same(a: RoomDef, b: RoomDef) -> bool:
	for p in a.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or p["name"] == "script":
			continue
		if a.get(p["name"]) != b.get(p["name"]):
			return false
	return true

## The rooms whose content differs from their file (or that have no file).
static func stale(world: Dictionary, dir := ROOMS_DIR) -> Array:
	var out: Array = []
	for id in world:
		var path := "%s/%s.tres" % [dir, id]
		if not FileAccess.file_exists(path) or not same(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE), world[id]):
			out.append(id)
	return out

## Writes the rooms `ids`; the errors, none when all were written. Every room is serialized and every id checked before any file is
## opened, so one that cannot be leaves every file as it was (a file is truncated on opening).
static func write(world: Dictionary, ids: Array, dir := ROOMS_DIR) -> PackedStringArray:
	var errors := PackedStringArray()
	var texts := {}
	for id in ids:
		if not RoomEditModel.valid_id(id):
			errors.append("%s: not a plain room id, not written" % id)
			continue
		texts[id] = serialize(world[id])
		if texts[id] == "":
			errors.append("%s: could not be serialized, nothing written" % id)
	if not errors.is_empty():
		return errors
	for id in ids:
		var f := FileAccess.open("%s/%s.tres" % [dir, id], FileAccess.WRITE)
		if f == null:
			errors.append("%s: could not be opened for writing" % id)
			continue
		f.store_string(texts[id])
		f.close()
	return errors

## The generated room files (an id a module's prefix makes) that no module builds any more.
static func orphans(world: Dictionary, mods: Array, dir := ROOMS_DIR) -> Array:
	var prefixes: Array = []
	for m in mods:
		if m.prefix() != "":
			prefixes.append(m.prefix())
	var out: Array = []
	for file in DirAccess.get_files_at(dir):
		var id: String = file.get_basename()
		if file.ends_with(".tres") and _generated(id, prefixes) and not world.has(id):
			out.append(id)
	out.sort()
	return out

static func remove(ids: Array, dir := ROOMS_DIR) -> void:
	for id in ids:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.tres" % [dir, id]))
