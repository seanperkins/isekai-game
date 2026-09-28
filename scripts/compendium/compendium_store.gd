class_name CompendiumStore
extends RefCounted
## Safe JSON persistence for Compendium slot states and Bestiary records.
## Bestiary records ("creatures") are optional, so saves from before the Bestiary still load,
## and a malformed record is dropped on its own rather than costing the skill states.
## Save: write <path>.tmp, verify it parses, then rename over <path>.
## Load: parse only as JSON (never str_to_var), type-check everything, never overwrite a bad file.
## Windows' rename is remove-then-rename, so a missing main file with a valid .tmp is recovered.

const VERSION := 1

var path: String
var warn: Callable = func(msg: String) -> void: push_warning(msg)
var _bak_seq := 0

func _init(p_path: String) -> void:
	path = p_path

func load_states(state_names: Array) -> Dictionary:
	var tmp := path + ".tmp"
	var data = null
	if FileAccess.file_exists(path):
		data = _read_valid(path, state_names)
		if data == null:
			_backup(path)
	if data == null and FileAccess.file_exists(tmp):
		data = _read_valid(tmp, state_names)
		if data != null:
			DirAccess.rename_absolute(_abs(tmp), _abs(path))
	return data if data != null else {}

## Bestiary records from the save: id -> {seen, appraisal, eaten, defeated}. Bad entries are
## skipped. Call after load_states, which handles recovery and backups.
func load_creatures() -> Dictionary:
	var json := JSON.new()
	if not FileAccess.file_exists(path) or json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("creatures")) != TYPE_DICTIONARY:
		return {}
	var out := {}
	for id in data["creatures"]:
		var rec = data["creatures"][id]
		var clean := _clean_record(rec)
		if not clean.is_empty():
			out[str(id)] = clean
	return out

static func _clean_record(rec) -> Dictionary:
	if typeof(rec) != TYPE_DICTIONARY or typeof(rec.get("seen")) != TYPE_BOOL:
		return {}
	var out := {"seen": rec["seen"]}
	for key in ["appraisal", "eaten", "defeated"]:
		var v = rec.get(key)
		if not (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) or v < 0:
			return {}
		out[key] = int(v)
	return out

func save_states(states: Dictionary, state_names: Array, creatures: Dictionary = {}) -> bool:
	var slots := {}
	for id in states:
		slots[id] = state_names[int(states[id])]
	var body := {"version": VERSION, "slots": slots}
	if not creatures.is_empty():
		body["creatures"] = creatures
	var text := JSON.stringify(body, "\t", true)
	var tmp := path + ".tmp"
	DirAccess.make_dir_recursive_absolute(_abs(path.get_base_dir()))
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		warn.call("Compendium: cannot write %s (%s); keeping the previous save" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	if _read_valid(tmp, state_names) == null:
		warn.call("Compendium: verify failed for %s; keeping the previous save" % tmp)
		return false
	var err := DirAccess.rename_absolute(_abs(tmp), _abs(path))
	if err != OK:
		warn.call("Compendium: rename to %s failed (%s)" % [path, error_string(err)])
		return false
	return true

## Returns id -> state index, or null when the file is not a valid save.
func _read_valid(p: String, state_names: Array):
	# JSON.parse (not parse_string) reports bad input by return code without logging an
	# engine error. Like parse_string, it never constructs Objects from data.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(p)) != OK:
		return null
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var version = parsed.get("version")
	if not (typeof(version) == TYPE_INT or typeof(version) == TYPE_FLOAT) or int(version) != VERSION:
		return null
	var slots = parsed.get("slots")
	if typeof(slots) != TYPE_DICTIONARY:
		return null
	var out := {}
	for id in slots:
		var s = slots[id]
		if typeof(s) != TYPE_STRING or not state_names.has(s):
			return null
		out[str(id)] = state_names.find(s)
	return out

func _backup(p: String) -> void:
	_bak_seq += 1
	var bak := p.get_base_dir().path_join("compendium.%d-%d-%d.bak" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), _bak_seq])
	DirAccess.rename_absolute(_abs(p), _abs(bak))
	warn.call("Compendium: %s was not a valid save; moved it to %s and started fresh" % [p, bak])

static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)
