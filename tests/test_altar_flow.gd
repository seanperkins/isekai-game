extends GutTest
## An altar in the real scene, driven by real key presses: interact with the Cave mouth's altar, bank essence into soul points, buy
## its perk, close the menu, and the next life is stronger. Banking and buying save through the Profile, so everything the flow
## touches is snapshotted in before_each and written back in after_each (a failed assertion cleans up too).

var game
var saved := {}

func before_each() -> void:
	var soul: SoulProgress = Compendium.soul
	var progress: WorldProgress = Compendium.progress
	var profile: Profile = Compendium.profile
	saved = {
		"points": soul.points, "perks": soul.perks.duplicate(true), "deaths": soul.deaths, "session": soul.session_points,
		"soul_section": profile.dict_section("soul"),
		"visited": progress.visited.duplicate(), "rebirths": progress.rebirths.duplicate(),
		"map": profile.list_section("map"), "rebirths_section": profile.list_section("rebirths"),
		"choice_section": profile.dict_section("rebirth_choice"),
		"paused": get_tree().paused,
	}

func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await wait_process_frames(1)
	game = null
	get_tree().paused = saved["paused"]
	var soul: SoulProgress = Compendium.soul
	soul.points = saved["points"]
	soul.perks = saved["perks"]
	soul.deaths = saved["deaths"]
	soul.session_points = saved["session"]
	Compendium.progress.visited = saved["visited"]
	Compendium.progress.rebirths = saved["rebirths"]
	var profile: Profile = Compendium.profile
	profile.set_section("soul", saved["soul_section"])
	profile.set_section("map", saved["map"])
	profile.set_section("rebirths", saved["rebirths_section"])
	profile.set_section("rebirth_choice", saved["choice_section"])
	profile.save()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _push(code: Key, times := 1) -> void:
	for i in times:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code  # Controls binds the physical key
		ev.pressed = true
		get_viewport().push_input(ev)

## An engine of its own, started and with no CoreWiring: absorbed essence reaches only it, never the real Compendium.
func _isolated_engine() -> SkillRulesEngine:
	var engine := SkillRulesEngine.new()
	engine.setup(SkillRules.skill_defs)
	engine.start_run()
	return engine

func _altar(id: String) -> Altar:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Altar and n.id == id:
			return n
	return null

func test_banking_and_buying_at_the_cave_altar_gives_the_next_life_the_perk() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await wait_physics_frames(2)
	Compendium.soul.points = 0
	Compendium.soul.perks = {}
	Compendium.soul.session_points = 0
	game.begin_life({"default": true, "kit": {}, "species": "slime"})
	var base_hp: int = game.player.health.max_hp
	assert_eq(game.altar_menu.engine, SkillRules, "the game binds the production engine to the altar menu")
	var engine := _isolated_engine()
	for i in 27:
		engine.handle_event("absorbed", {"essence": "water", "source": "test"})
	for i in 30:
		engine.handle_event("absorbed", {"essence": "dark", "source": "test"})
	game.altar_menu.bind(game.goddess, engine, Compendium.progress, game.player)
	var altar := _altar("C1")
	assert_not_null(altar, "the Cave mouth's altar is in the world")
	altar.interact(game.player)
	assert_true(game.altar_menu.is_open())
	assert_true(get_tree().paused)

	_push(KEY_DOWN)  # the water row
	_push(KEY_RIGHT, 2)
	_push(KEY_ENTER)
	assert_eq(Compendium.soul.total_points(), 2, "20 water banked at 10 a point")
	assert_eq(engine.held("water"), 7)

	_push(KEY_DOWN, 4)  # the dark row
	_push(KEY_RIGHT, 3)
	_push(KEY_ENTER)
	assert_eq(Compendium.soul.total_points(), 5)
	assert_eq(engine.held("dark"), 0)

	_push(KEY_DOWN)  # the perk row
	_push(KEY_ENTER)
	assert_eq(Compendium.soul.perk_count("stats"), 1)
	assert_eq(Compendium.soul.total_points(), 0, "the first purchase costs 5")
	assert_string_contains(game.altar_menu.footer_text(), "next life")

	_push(KEY_BACKSPACE)
	assert_false(game.altar_menu.is_open())
	assert_false(get_tree().paused)

	game.begin_life({"default": true, "kit": {}, "species": "slime"})
	assert_eq(game.player.health.max_hp, base_hp + 2, "the stats perk's +2 max HP applies from the next life")
