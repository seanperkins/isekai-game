extends GutTest
## The four non-slime species as goddess data, and starting a run as one.

func after_each() -> void:
	Game.launch_override = {}
	Compendium.progress.pending_start = {}
	SkillRules.reset_run()
	Announcer.queue.clear()

func _ids(defs: Array) -> Array:
	return defs.map(func(d: SpeciesDef) -> String: return d.id)

func _player() -> Player:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	return p

func test_every_species_of_the_form_tree_has_a_def_that_validates() -> void:
	var catalog := SpeciesCatalog.load_all()
	for id in Form.SPECIES:
		assert_true(catalog.has(id), id)
		assert_eq(catalog[id].movement_profile, MovementProfile.SPECIES_PROFILE[id], id)
	var perks := DefLoader.load_dir("res://data/perks", "PerkDef")
	var rules: SoulRules = load("res://data/soul/soul_rules.tres")
	var lines: GoddessLines = load("res://data/goddess/lines.tres")
	var creature_ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c: CreatureDef) -> String: return c.id)
	assert_eq(Array(SoulValidator.validate(catalog.values(), perks, rules, lines, creature_ids)), [])

func test_the_goddess_offers_only_what_is_unlocked() -> void:
	var catalog := SpeciesCatalog.load_all()
	assert_eq(_ids(SpeciesCatalog.unlocked(catalog, {})), ["slime"])
	assert_eq(_ids(SpeciesCatalog.unlocked(catalog, {"gloom_wolf": {"eaten": 0, "defeated": 1}})), ["slime", "wolf"])
	assert_eq(_ids(SpeciesCatalog.unlocked(catalog, {"spider": {"eaten": 5, "defeated": 0}})), ["slime", "spider"])
	assert_eq(_ids(SpeciesCatalog.unlocked(catalog, {"spider": {"eaten": 4, "defeated": 0}})), ["slime"], "one short")
	assert_eq(_ids(SpeciesCatalog.unlocked(catalog, {"armed_ant": {"eaten": 3, "defeated": 0}, "bog_lizardman": {"eaten": 0, "defeated": 3}})),
		["slime", "goblin", "undead"])

func test_species_arg_reads_a_known_species_and_nothing_else() -> void:
	assert_eq(Game.species_arg(["--species=wolf"]), "wolf")
	assert_eq(Game.species_arg(["--foo", "--species=undead"]), "undead")
	assert_eq(Game.species_arg(["--species=newt"]), "", "no such species: no override")
	assert_eq(Game.species_arg(["--species"]), "")
	assert_eq(Game.species_arg([]), "")

func test_set_species_turns_a_new_player_into_that_species() -> void:
	var p := _player()
	p.set_species("spider")
	assert_true(p.uses_species_body())
	assert_eq(p.species_body.profile.id, "spider")
	assert_eq(p.form.species, "spider")
	assert_eq(p.form.form_id, "spider")

func test_set_species_refuses_a_species_nobody_knows() -> void:
	var p := _player()
	p.set_species("newt")
	assert_false(p.uses_species_body())
	assert_eq(p.species, "slime")
	p.set_species("slime")
	assert_false(p.uses_species_body())

func test_the_game_starts_as_the_species_the_flag_names() -> void:
	Game.launch_override = {"headless": true, "args": ["--species=spider"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(game.player.species, "spider")
	assert_true(game.player.uses_species_body())
	assert_eq(game.player.form.species, "spider")

func test_a_goddess_pick_starts_that_species() -> void:
	Compendium.progress.pending_start = {"altar": "", "species": "wolf", "kit": {}}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(game.player.species, "wolf")
	assert_true(game.player.uses_species_body())

func test_a_malformed_pick_starts_a_slime() -> void:
	Compendium.progress.pending_start = {"altar": "", "species": "newt", "kit": {}}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(game.player.species, "slime")
	assert_false(game.player.uses_species_body())

# --- a species' own verb: the default goblin's weak blow ---

func test_the_two_legged_species_have_a_blow_of_their_own_and_the_others_have_their_moves() -> void:
	var catalog := SpeciesCatalog.load_all()
	assert_eq(catalog["goblin"].verb, "verb_goblin")
	assert_eq(catalog["undead"].verb, "verb_undead")
	for id in ["slime", "wolf", "spider"]:
		assert_eq(catalog[id].verb, "", id)
	assert_eq(SpeciesCatalog.verb_of("goblin"), "verb_goblin")
	assert_eq(SpeciesCatalog.verb_of("wolf"), "")
	assert_eq(SpeciesCatalog.verb_of("no_such_species"), "")

func test_a_goblin_starts_its_life_with_its_blow_in_its_first_slot_and_it_hits() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	p.set_species("goblin")
	rules.start_run()
	assert_true(rules.owned().has("verb_goblin"), "a goblin owns its blow from the start of a life")
	assert_eq(p.skillset.slots.use(0), "verb_goblin", "in the first slot")
	var other_rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	other_rules.setup(DefLoader.load_dir("res://data/skills"))
	var slime_p := Player.new()
	slime_p.setup(other_rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: other_rules.handle_event(n, t))
	add_child_autofree(slime_p)
	other_rules.start_run()
	assert_false(other_rules.owned().has("verb_goblin"), "a slime has no blow of the goblin's")

func test_evolving_into_a_form_with_a_verb_gives_it_the_blows_slot() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	p.set_species("goblin")
	rules.start_run()
	assert_true(p.become_form("goblin_giant_killer"))
	assert_eq(p.skillset.slots.use(0), "verb_goblin_giant_killer", "the form's verb takes the blow's slot")
