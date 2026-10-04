extends GutTest
## Reached forms: the player says when a body evolution succeeds, and the game records it in the world's progress (the
## real profile, or an editor Play's own in-memory progress).

var game: Game
var _reached_before: Array = []

func before_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	_reached_before = Compendium.progress.forms_reached.duplicate()

func after_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	get_tree().paused = false
	SkillRules.reset_run()
	Announcer.queue.clear()
	Compendium.progress.forms_reached = _reached_before
	Compendium.progress._save()  # the suite's profile outlives the run: leave it as it was

func _player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var p := Player.new()
	p.setup(rules, CompendiumModel.new(skills, creature_list), creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	return p

func test_the_signal_fires_on_a_successful_evolution_and_not_on_a_refused_one() -> void:
	var p := _player()
	var got: Array = []
	p.form_advanced.connect(func(id: String) -> void: got.append(id))
	assert_false(p.advance_form("weaver"), "below the level cap")
	assert_false(p.advance_form("snare", true), "not a child of the slime")
	assert_eq(got, [])
	assert_true(p.advance_form("weaver", true))
	assert_eq(got, ["weaver"])

func test_the_game_records_a_reached_form_and_a_new_life_keeps_it() -> void:
	Compendium.progress.forms_reached.erase("weaver")
	var first: Game = load("res://scenes/main.tscn").instantiate()
	add_child(first)
	await wait_physics_frames(3)
	assert_true(first.player.advance_form("weaver", true))
	assert_true(Compendium.progress.is_form_reached("weaver"))
	first.queue_free()
	await wait_process_frames(2)
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_eq(game.player.form.stage, 1, "a new life starts as a slime")
	assert_true(game.world.ctx["progress"].is_form_reached("weaver"), "and the soul still has the form it reached")

func test_an_editor_play_records_it_in_its_own_progress_only() -> void:
	Compendium.progress.forms_reached.erase("tide")
	var real_before: Array = Compendium.progress.forms_reached.duplicate()
	Game.play_request = {"rooms": World.load_rooms("res://data/rooms"), "room": "C2", "pos": Vector2(200, 250)}
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_true(game.player.advance_form("tide", true))
	assert_true(game.world.ctx["progress"].is_form_reached("tide"))
	assert_eq(Compendium.progress.forms_reached, real_before, "an editor Play never reaches the real profile")
