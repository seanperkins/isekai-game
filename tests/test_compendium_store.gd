extends GutTest

const NAMES := ["unknown", "named", "hinted", "owned-once"]
var dir: String
var path: String
var warnings: Array

func before_each() -> void:
	dir = "user://gut_store_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)
	path = dir.path_join("compendium.json")
	warnings = []

func after_each() -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func _store() -> CompendiumStore:
	var s := CompendiumStore.new(path)
	s.warn = func(msg: String) -> void: warnings.append(msg)
	return s

func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _baks() -> Array:
	return Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".bak"))

func test_round_trip() -> void:
	assert_true(_store().save_states({"leap": 3, "glutton": 0}, NAMES))
	assert_eq(_store().load_states(NAMES), {"leap": 3, "glutton": 0})
	assert_false(FileAccess.file_exists(path + ".tmp"))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(int(parsed["version"]), 1)
	assert_eq(parsed["slots"]["leap"], "owned-once")

func test_missing_file_is_a_fresh_start() -> void:
	assert_eq(_store().load_states(NAMES), {})
	assert_eq(warnings, [])

func test_corrupt_file_is_backed_up_and_fresh() -> void:
	_write(path, "{not json")
	assert_eq(_store().load_states(NAMES), {})
	assert_eq(_baks().size(), 1)
	assert_false(FileAccess.file_exists(path))
	assert_eq(warnings.size(), 1)

func test_hand_edited_wrong_types_are_corrupt() -> void:
	# Review Focus 1
	for text in ['{"version": "1", "slots": {}}', '{"version": 1, "slots": []}',
			'{"version": 1, "slots": {"leap": "owned"}}', '[1, 2]', '{"version": 2, "slots": {}}']:
		_write(path, text)
		assert_eq(_store().load_states(NAMES), {}, text)
	assert_eq(_baks().size(), 5)

func test_valid_tmp_is_adopted_when_main_missing() -> void:
	_write(path + ".tmp", '{"version": 1, "slots": {"leap": "named"}}')
	assert_eq(_store().load_states(NAMES), {"leap": 1})
	assert_true(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + ".tmp"))

func test_valid_tmp_is_adopted_when_main_corrupt_and_main_is_backed_up() -> void:
	_write(path, "garbage")
	_write(path + ".tmp", '{"version": 1, "slots": {"leap": "hinted"}}')
	assert_eq(_store().load_states(NAMES), {"leap": 2})
	assert_eq(_baks().size(), 1)

func test_unwritable_location_returns_false_and_warns() -> void:
	# Review Focus 2: the parent "directory" is actually a file.
	_write(dir.path_join("blocker"), "x")
	var s := CompendiumStore.new(dir.path_join("blocker/compendium.json"))
	s.warn = func(msg: String) -> void: warnings.append(msg)
	assert_false(s.save_states({"leap": 1}, NAMES))
	assert_eq(warnings.size(), 1)

func test_save_creates_missing_directory() -> void:
	var nested := dir.path_join("a")
	var s := CompendiumStore.new(nested.path_join("compendium.json"))
	s.warn = func(msg: String) -> void: warnings.append(msg)
	assert_true(s.save_states({"leap": 3}, NAMES))
	assert_eq(s.load_states(NAMES), {"leap": 3})
	DirAccess.remove_absolute(nested.path_join("compendium.json"))
	DirAccess.remove_absolute(nested)
