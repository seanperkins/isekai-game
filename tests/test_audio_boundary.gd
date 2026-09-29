extends GutTest
## Gameplay says what happened; Audio decides the sound. These tests read the source to keep that true.

const ROOTS := ["res://scripts", "res://autoload"]
const AUDIO_OWNED := ["res://autoload/audio.gd"]

var catalog: CueCatalog

func before_all() -> void:
	catalog = CueCatalog.load_file("res://data/audio/cues.json")

func _gd_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out

func _gameplay_files() -> Array:
	var out: Array = []
	for root in ROOTS:
		for f in _gd_files(root):
			if not AUDIO_OWNED.has(f) and not f.begins_with("res://scripts/audio/"):
				out.append(f)
	return out

func test_gameplay_scripts_name_no_cue_and_never_call_audio_play() -> void:
	var play := RegEx.create_from_string("Audio\\.(play|play_cue|stop_loop)\\b")
	var files := _gameplay_files()
	assert_gt(files.size(), 50)
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		assert_null(play.search(text), "%s calls Audio.play*" % f)
		for id in catalog.cues:
			assert_false(text.contains('"%s"' % id), "%s names the cue %s" % [f, id])

func test_every_emitted_world_event_has_a_catalog_entry() -> void:
	var emitted := RegEx.create_from_string("(?:world_event\\.emit|_emit)\\(\"([a-z_]+)\"")
	var names := {}
	for f in _gameplay_files():
		for m in emitted.search_all(FileAccess.get_file_as_string(f)):
			names[m.get_string(1)] = f
	assert_gt(names.size(), 20)
	for n in names:
		assert_true(catalog.events.has(n), "%s (emitted in %s) has no entry in data/audio/cues.json" % [n, names[n]])

func test_every_event_entry_that_plays_is_reachable_or_reserved() -> void:
	# Events the catalog maps but no script emits yet; each is reserved on purpose.
	var reserved := ["water_entered", "water_exited"]
	var emitted := RegEx.create_from_string("(?:world_event\\.emit|_emit)\\(\"([a-z_]+)\"")
	var names := {}
	for f in _gameplay_files():
		for m in emitted.search_all(FileAccess.get_file_as_string(f)):
			names[m.get_string(1)] = true
	for n in catalog.events:
		if str(n).begins_with("_") or Events.ALL.has(n) or ["skill_unlocked", "skill_leveled", "evolution_ready"].has(n):
			continue
		assert_true(names.has(n) or reserved.has(n), "%s is in the catalog but nothing emits it" % n)

func test_the_preview_scene_builds_a_button_per_cue_and_biome() -> void:
	var preview = load("res://tools/audio/preview.tscn").instantiate()
	add_child_autofree(preview)
	var buttons: Array = preview.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), catalog.cues.size() + CueCatalog.BIOMES.size())
