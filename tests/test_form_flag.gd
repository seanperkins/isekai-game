extends GutTest
## `--form=<id>`: start the run as any form, its whole line evolved to it, so a reviewer sees every evolution without a grind.

func after_each() -> void:
	Game.launch_override = {}
	Compendium.progress.pending_start = {}
	SkillRules.reset_run()
	Announcer.queue.clear()

func _player() -> Player:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	return p

func test_form_arg_reads_the_flag_and_nothing_else() -> void:
	assert_eq(Game.form_arg(["--form=wolf_fenrir"]), "wolf_fenrir")
	assert_eq(Game.form_arg(["--foo", "--form=gleipnir"]), "gleipnir")
	assert_eq(Game.form_arg(["--form"]), "")
	assert_eq(Game.form_arg(["--form="]), "")
	assert_eq(Game.form_arg([]), "")

func test_become_form_reaches_exactly_that_form_for_every_form() -> void:
	var forms := FormLoader.load_all()
	for id in forms:
		var def: FormDef = forms[id]
		var p := _player()
		assert_true(p.become_form(id), id)
		assert_eq(p.form.form_id, id, id)
		assert_eq(p.form.stage, def.stage, id)
		assert_eq(p.species, def.species, id)
		assert_false(p.evolving(), "%s: the evolve moment is over" % id)
		if def.verb != "":
			assert_true(p.skillset.slots.slots.has(def.verb), "%s: its verb is in a slot" % id)
		p.free()

func test_become_form_with_an_unknown_id_changes_nothing() -> void:
	for id in ["no_such_form", "", "wolf", "slime"]:
		var p := _player()
		assert_false(p.become_form(id), id)
		assert_eq(p.form.stage, 1, id)
		assert_eq(p.species, "slime", id)
		p.free()

func test_the_game_starts_as_the_form_the_flag_names() -> void:
	Game.launch_override = {"headless": true, "args": ["--form=wolf_fenrir"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(game.player.form.form_id, "wolf_fenrir")
	assert_eq(game.player.form.stage, 4)
	assert_eq(game.player.species, "wolf")
	assert_true(game.player.uses_species_body())

func test_an_unknown_form_flag_starts_a_plain_slime() -> void:
	Game.launch_override = {"headless": true, "args": ["--form=nothing_like_it"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(game.player.form.form_id, "slime")
