extends GutTest
## Game's opening decisions: when it is wanted, loading and validating its data, and refusing to start where it must not.

var game
var made: Array = []

func after_each() -> void:
	get_tree().paused = false
	for path in made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	made.clear()

func _unseen() -> SoulProgress:
	return SoulProgress.new()

func _seen() -> SoulProgress:
	var soul := SoulProgress.new()
	soul.opening_seen = true
	return soul

func _save(res: Resource) -> String:
	var path := "user://test_opening_%d.tres" % Time.get_ticks_usec()
	assert_eq(ResourceSaver.save(res, path), OK)
	made.append(path)
	return path

func test_wants_opening_follows_flags_and_the_saved_flag() -> void:
	assert_false(Game.wants_opening(_unseen(), [], false, true), "never in an editor Play")
	assert_false(Game.wants_opening(_unseen(), ["--skip-opening", "--opening"], false, false), "skip beats force")
	assert_true(Game.wants_opening(_seen(), ["--opening"], false, false), "--opening replays a seen profile")
	assert_false(Game.wants_opening(_seen(), ["--opening"], true, false), "--opening cannot start an opening nobody can advance")
	assert_false(Game.wants_opening(_seen(), ["--opening"], false, false, true), "--opening is honored once per process")
	assert_true(Game.wants_opening(_unseen(), ["--opening"], false, false, true), "after that, the saved flag decides")
	assert_false(Game.wants_opening(_unseen(), [], true, false), "a headless run never opens it")
	assert_true(Game.wants_opening(_unseen(), [], false, false), "a windowed launch of an unseen profile does")
	assert_false(Game.wants_opening(_seen(), [], false, false), "and not of a seen one")

func test_load_opening_returns_the_shipped_def() -> void:
	var def := Game.load_opening()
	assert_not_null(def)
	assert_true(def is OpeningDef)
	assert_eq(def.trucks.size(), 3)

func test_a_malformed_opening_is_refused_and_named() -> void:
	var bad := OpeningDef.new()
	bad.choices = [{"id": "a", "label": "A"}]
	bad.trucks = [{"prompt": "P", "results": "none"}]
	bad.fallback = "f"
	bad.goddess_line = "g"
	var bad_path := _save(bad)
	assert_null(Game.load_opening(bad_path))
	assert_push_error(bad_path.get_file())
	var other_path := _save(SoulRules.new())
	assert_null(Game.load_opening(other_path))
	assert_push_error(other_path.get_file())
	assert_null(Game.load_opening("user://no_such_opening.tres"))
	assert_push_error("no_such_opening")
	assert_false(get_tree().paused, "a refused opening never pauses the game")

func test_start_opening_refuses_over_a_pause() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	var before: bool = Compendium.soul.opening_seen
	get_tree().paused = true
	assert_false(game.start_opening(), "a menu is open: nothing starts")
	assert_true(get_tree().paused, "and the pause is not touched")
	get_tree().paused = false
	assert_eq(Compendium.soul.opening_seen, before)
	assert_false(game.opening.is_playing())
