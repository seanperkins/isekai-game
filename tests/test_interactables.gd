extends GutTest
## Things you Inspect in the world. Inspect checks interactables first, then creatures, then
## yourself. A Glow Pool refills HP and MP; a tablet shows lore and hints at a skill.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var player: Player
var progress: WorldProgress
var announced: Array = []
var reports: Array = []

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creatures := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creatures)
	player = Player.new()
	player.setup(rules, compendium, creatures, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	progress = WorldProgress.new()
	announced = []
	reports = []
	player.inspect_report.connect(func(lines: PackedStringArray) -> void: reports.append(lines))

func _ctx() -> Dictionary:
	return {"progress": progress, "compendium": compendium,
		"announce": func(id: String, text: String) -> void: announced.append([id, text])}

func _feature(f: Dictionary) -> Node2D:
	var n := RoomFeatures.make(f, _ctx())
	add_child_autofree(n)
	return n

func test_soaking_in_a_glow_pool_refills_hp_and_mp() -> void:
	_feature({"kind": "glow_pool", "id": "p1", "pos": player.global_position + Vector2(10, 0)})
	player.health.take_hit(12, "physical")
	player.mana.spend(15)
	player.do_inspect()
	assert_eq(player.health.hp, player.health.max_hp)
	assert_eq(player.mana.mp, player.mana.max_mp)
	assert_eq(announced, [["p1", "Your body settles."]])

func test_reading_a_tablet_shows_lore_hints_a_skill_and_is_remembered() -> void:
	_feature({"kind": "tablet", "id": "t1", "pos": player.global_position + Vector2(-10, 0),
		"title": "Worn tablet", "text": "Listen.", "hint": "echolocation"})
	player.do_inspect()
	assert_eq(reports, [PackedStringArray(["Worn tablet", "Listen."])])
	assert_eq(compendium.state("echolocation"), CompendiumModel.State.HINTED)
	assert_true(progress.is_read("t1"))

func test_interactables_win_over_creatures_and_self() -> void:
	var t := _feature({"kind": "tablet", "id": "t1", "pos": player.global_position + Vector2(12, 0),
		"title": "Worn tablet", "text": "Listen.", "hint": ""})
	player.do_inspect()
	assert_eq(reports.size(), 1)
	assert_eq(reports[0][0], "Worn tablet")
	t.global_position = player.global_position + Vector2(60, 0)  # out of reach
	player.do_inspect()
	assert_ne(reports[1][0], "Worn tablet")  # falls back to the self report

func test_the_prompt_names_the_action() -> void:
	_feature({"kind": "glow_pool", "id": "p1", "pos": player.global_position})
	player._update_prompt()
	assert_true(player.eat_prompt.visible)
	assert_eq(player.eat_prompt.text, "I: soak")

func test_unknown_features_are_skipped() -> void:
	assert_null(RoomFeatures.make({"kind": "banana", "pos": Vector2.ZERO}, {}))

func test_rooms_build_their_features() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var c4 := RoomBuilder.build_room(rooms["C4"], _ctx())
	add_child_autofree(c4)
	assert_eq(c4.get_children().filter(func(n: Node) -> bool: return n is GlowPool).size(), 1)
