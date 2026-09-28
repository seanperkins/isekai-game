class_name Profile
extends RefCounted
## The one persistent save, user://profile.json: Compendium slots, Bestiary records, the map,
## opened shortcuts and read tablets. Every section is written together with a safe write:
## write <path>.tmp, verify that it parses, then rename it over <path>. A corrupt file is backed
## up and replaced with a fresh one. A malformed section is dropped on its own. On first
## load, it migrates a legacy compendium.json.
## It also speaks CompendiumStore's interface, so CompendiumModel can save through it.

const VERSION := 1

var path: String
var legacy_path: String
var warn: Callable = func(msg: String) -> void: push_warning(msg)
var _sections := {}
var _bak_seq := 0

func _init(p_path: String, p_legacy_path: String = "") -> void:
	path = p_path
	legacy_path = p_legacy_path

func reload() -> void:
	_sections = {}
	var tmp := path + ".tmp"
	# Only a first launch migrates: a profile that exists but is corrupt starts fresh instead
	# of resurrecting the stale pre-migration compendium.json.
	var had_profile := FileAccess.file_exists(path) or FileAccess.file_exists(tmp)
	var data = null
	if FileAccess.file_exists(path):
		data = _parse(path)
		if data == null:
			_backup(path)
	if data == null and FileAccess.file_exists(tmp):
		data = _parse(tmp)
		if data != null:
			DirAccess.rename_absolute(_abs(tmp), _abs(path))
	if data != null:
		for key in data:
			if key != "version":
				_sections[key] = data[key]
		return
	if not had_profile and legacy_path != "" and FileAccess.file_exists(legacy_path):
		_migrate()

func set_section(name: String, value) -> void:
	_sections[name] = value

## A list of strings. Anything else is malformed: warn, drop it and return [].
func list_section(name: String) -> Array:
	var v = _sections.get(name)
	if v == null:
		return []
	if typeof(v) != TYPE_ARRAY or v.any(func(x) -> bool: return typeof(x) != TYPE_STRING):
		warn.call("Profile: dropped malformed '%s' section" % name)
		_sections.erase(name)
		return []
	return v.duplicate()

func save() -> bool:
	var body := {"version": VERSION}
	body.merge(_sections)
	var text := JSON.stringify(body, "\t", true)
	var tmp := path + ".tmp"
	DirAccess.make_dir_recursive_absolute(_abs(path.get_base_dir()))
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		warn.call("Profile: cannot write %s (%s); keeping the previous save" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	if _parse(tmp) == null:
		warn.call("Profile: verify failed for %s; keeping the previous save" % tmp)
		return false
	var err := DirAccess.rename_absolute(_abs(tmp), _abs(path))
	if err != OK:
		warn.call("Profile: rename to %s failed (%s)" % [path, error_string(err)])
		return false
	return true

# --- CompendiumStore interface -------------------------------------------------

func load_states(state_names: Array) -> Dictionary:
	var v = _sections.get("compendium")
	if v == null:
		return {}
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for id in v:
			if typeof(v[id]) != TYPE_STRING or not state_names.has(v[id]):
				out = {}
				v = null
				break
			out[str(id)] = state_names.find(v[id])
	if v == null or typeof(v) != TYPE_DICTIONARY:
		warn.call("Profile: dropped malformed 'compendium' section")
		_sections.erase("compendium")
		return {}
	return out

func load_creatures() -> Dictionary:
	var v = _sections.get("bestiary")
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var out := {}
	for id in v:
		var clean := CompendiumStore._clean_record(v[id])
		if not clean.is_empty():
			out[str(id)] = clean
	return out

func save_states(states: Dictionary, state_names: Array, creatures: Dictionary = {}) -> bool:
	var slots := {}
	for id in states:
		slots[id] = state_names[int(states[id])]
	_sections["compendium"] = slots
	_sections["bestiary"] = creatures.duplicate(true)
	return save()

# --- internals ------------------------------------------------------------------

## The parsed save as a Dictionary, or null when the file is not a valid profile.
func _parse(p: String):
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(p)) != OK:
		return null
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var version = data.get("version")
	if not (typeof(version) == TYPE_INT or typeof(version) == TYPE_FLOAT) or int(version) != VERSION:
		return null
	return data

func _migrate() -> void:
	var old := CompendiumStore.new(legacy_path)
	old.warn = warn
	var states := old.load_states(CompendiumModel.STATE_NAMES)
	var slots := {}
	for id in states:
		slots[id] = CompendiumModel.STATE_NAMES[int(states[id])]
	_sections["compendium"] = slots
	_sections["bestiary"] = old.load_creatures()
	save()

func _backup(p: String) -> void:
	_bak_seq += 1
	var bak := p.get_base_dir().path_join("profile.%d-%d-%d.bak" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), _bak_seq])
	DirAccess.rename_absolute(_abs(p), _abs(bak))
	warn.call("Profile: %s was not a valid save; moved it to %s and started fresh" % [p, bak])

static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)
