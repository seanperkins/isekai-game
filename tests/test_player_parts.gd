extends GutTest
## The player carries every part it picks up; the undead wear the grafts for their passives and lose one to a hard hit.

var rules: SkillRulesEngine
var player: Player
var events: Array

func _make(species := "slime") -> Player:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	events = []
	var p := Player.new()
	p.species = species
	p.use_sheet = false
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	player = p
	return p

func _named(event: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == event)

func _quarter() -> int:
	return ceili(player.health.max_hp * Player.SHED_FRACTION)

# --- collecting ---

func test_the_undead_wear_a_rib_and_it_raises_def() -> void:
	_make("undead")
	var def := player.stats.get_stat("def")
	player.collect_part("ribs")
	assert_eq(player.inventory.worn(), ["ribs"])
	assert_eq(player.stats.get_stat("def"), def + 1)
	assert_eq(_named(Deeds.PART_HARVESTED).map(func(e: Array) -> Dictionary: return e[1]), [{"part": "ribs"}])
	assert_eq(_named(Deeds.ITEM_CARRIED).size(), 1)
	assert_eq(_named(Deeds.GRAFT_ATTACHED).map(func(e: Array) -> Dictionary: return e[1]), [{"part": "ribs"}])

func test_a_wolf_carries_a_rib_and_gains_nothing() -> void:
	_make("wolf")
	var def := player.stats.get_stat("def")
	player.collect_part("ribs")
	assert_eq(player.inventory.worn(), [])
	assert_eq(player.inventory.carried(), ["ribs"])
	assert_eq(player.stats.get_stat("def"), def)
	assert_eq(_named(Deeds.PART_HARVESTED).size(), 1)
	assert_eq(_named(Deeds.ITEM_CARRIED).size(), 1)
	assert_eq(_named(Deeds.GRAFT_ATTACHED).size(), 0)

func test_flesh_worn_raises_max_hp() -> void:
	_make("undead")
	var hp := player.health.max_hp
	player.collect_part("flesh")
	assert_eq(player.health.max_hp, hp + 4)

func test_a_fifth_graft_is_carried_and_changes_nothing_worn() -> void:
	_make("undead")
	for id in ["ribs", "flesh", "claw", "claw"]:
		player.collect_part(id)
	var mp := player.health.max_hp
	var mana := player.stats.get_stat("max_mp")
	player.collect_part("skull")
	assert_eq(player.inventory.worn().size(), Inventory.GRAFT_CAP)
	assert_eq(player.inventory.carried(), ["skull"])
	assert_eq(player.stats.get_stat("max_mp"), mana, "a carried skull adds no MP")
	assert_eq(player.health.max_hp, mp)
	assert_eq(_named(Deeds.GRAFT_ATTACHED).size(), 4)
	assert_eq(_named(Deeds.PART_HARVESTED).size(), 5)

func test_an_unknown_part_is_refused() -> void:
	_make("undead")
	player.collect_part("no_such_part")
	assert_eq(events.size(), 0)
	assert_eq(player.inventory.count("no_such_part"), 0)

func test_a_dead_body_takes_nothing() -> void:
	_make("undead")
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_true(player.health.is_dead())
	assert_false(player.can_collect_parts())
	player.collect_part("ribs")
	assert_eq(player.inventory.count("ribs"), 0)

func test_a_new_run_starts_with_nothing_carried_or_worn() -> void:
	_make("undead")
	var def := player.stats.get_stat("def")
	player.collect_part("ribs")
	player.collect_part("moonstone")
	rules.start_run()
	assert_eq(player.inventory.worn(), [])
	assert_eq(player.inventory.carried(), [])
	assert_eq(player.stats.get_stat("def"), def)

func test_releasing_the_parts_gives_up_all_of_them_and_the_passives() -> void:
	_make("undead")
	var def := player.stats.get_stat("def")
	player.collect_part("ribs")
	player.collect_part("moonstone")
	var ids := player.release_parts()
	ids.sort()
	assert_eq(ids, ["moonstone", "ribs"])
	assert_eq(player.inventory.count("ribs") + player.inventory.count("moonstone"), 0)
	assert_eq(player.stats.get_stat("def"), def)

# --- cocoons ---

func test_a_cocoon_is_carried_and_says_only_that_something_was_carried() -> void:
	_make("spider")
	player.collect_part("cocoon:bat")
	assert_eq(player.inventory.cocoons(), ["bat"])
	assert_eq(_named(Deeds.ITEM_CARRIED).size(), 1)
	assert_eq(_named(Deeds.PART_HARVESTED).size(), 0, "a cocoon is not a part")
	assert_eq(_named(Deeds.GRAFT_ATTACHED).size(), 0)

func test_a_third_cocoon_is_refused_and_says_nothing() -> void:
	_make("spider")
	player.collect_part("cocoon:bat")
	player.collect_part("cocoon:toad")
	events.clear()
	player.collect_part("cocoon:lizard")
	assert_eq(events, [])
	assert_eq(player.inventory.cocoons(), ["bat", "toad"])

func test_parts_carried_does_not_count_cocoons() -> void:
	_make("spider")
	player.collect_part("cocoon:bat")
	player.collect_part("claw")
	assert_eq(player.parts_carried(), 1)

func test_the_part_lines_show_a_cocoon_by_its_creature() -> void:
	_make("spider")
	player.collect_part("cocoon:gloom_wolf")
	player.collect_part("claw")
	assert_eq(player.part_lines(), ["Carrying: Cocoon (Gloom Wolf), Claw"])
	player.collect_part("cocoon:gloom_wolf")
	assert_eq(player.part_lines(), ["Carrying: Cocoon (Gloom Wolf) x2, Claw"])

# --- shedding ---

func test_a_hit_of_a_quarter_of_max_hp_sheds_the_latest_graft() -> void:
	_make("undead")
	player.collect_part("ribs")
	player.collect_part("claw")
	var atk := player.stats.get_stat("atk")
	watch_signals(player)
	player.receive_hit(_quarter(), "fire")
	assert_false(player.health.is_dead())
	assert_eq(player.inventory.worn(), ["ribs"])
	assert_eq(player.stats.get_stat("atk"), atk - 1, "the claw's passive goes with it")
	assert_eq(_named(Deeds.GRAFT_SHED).map(func(e: Array) -> Dictionary: return e[1]), [{"part": "claw"}])
	assert_signal_emitted(player, "part_dropped")
	assert_eq(get_signal_parameters(player, "part_dropped")[0], "claw")

func _shed_from(blow_x: float) -> Vector2:
	_make("undead")
	player.collect_part("claw")
	player.global_position = Vector2(100.0, 0.0)
	watch_signals(player)
	player.receive_hit(_quarter(), "fire", Vector2(blow_x, 0.0))
	return get_signal_parameters(player, "part_dropped")[1]

func test_a_graft_knocked_off_by_a_blow_from_the_left_falls_to_the_right() -> void:
	assert_gt(_shed_from(80.0).x, 100.0)

func test_a_graft_knocked_off_by_a_blow_from_the_right_falls_to_the_left() -> void:
	assert_lt(_shed_from(120.0).x, 100.0)

func _worn_body_with_max_hp(max_hp: int) -> void:
	_make("undead")
	player.collect_part("ribs")
	player.health.set_max_hp(max_hp)
	player.health.hp = max_hp

func test_a_hit_of_exactly_a_quarter_sheds() -> void:
	_worn_body_with_max_hp(8)
	player.receive_hit(2, "fire")
	assert_eq(player.inventory.worn(), [])
	assert_eq(_named(Deeds.GRAFT_SHED).size(), 1)

func test_a_hit_of_one_less_than_a_quarter_does_not() -> void:
	_worn_body_with_max_hp(8)
	player.receive_hit(1, "fire")
	assert_eq(player.inventory.worn(), ["ribs"])
	assert_eq(_named(Deeds.GRAFT_SHED).size(), 0)

func test_a_smaller_hit_sheds_nothing() -> void:
	_make("undead")
	player.collect_part("ribs")
	watch_signals(player)
	player.receive_hit(_quarter() - 1, "fire")
	assert_eq(player.inventory.worn(), ["ribs"])
	assert_eq(_named(Deeds.GRAFT_SHED).size(), 0)
	assert_signal_not_emitted(player, "part_dropped")

func test_a_hit_with_nothing_worn_sheds_nothing_and_keeps_the_carried() -> void:
	_make("undead")
	player.collect_part("moonstone")
	watch_signals(player)
	player.receive_hit(_quarter(), "fire")
	assert_eq(player.inventory.carried(), ["moonstone"])
	assert_eq(_named(Deeds.GRAFT_SHED).size(), 0)
	assert_signal_not_emitted(player, "part_dropped")

func test_a_killing_blow_does_not_also_shed() -> void:
	_make("undead")
	player.collect_part("ribs")
	player.receive_hit(player.health.max_hp * 5, "fire")
	assert_true(player.health.is_dead())
	assert_eq(_named(Deeds.GRAFT_SHED).size(), 0)

func test_a_blow_that_is_blocked_sheds_nothing() -> void:
	_make("undead")
	player.collect_part("ribs")
	player.receive_hit(1, "fire")  # starts the invulnerable second
	player.receive_hit(_quarter(), "fire")
	assert_eq(player.inventory.worn(), ["ribs"])
	assert_eq(_named(Deeds.GRAFT_SHED).size(), 0)

# --- what the Form tab says ---

func test_the_part_lines_name_what_is_worn_and_what_is_carried() -> void:
	_make("undead")
	assert_eq(player.part_lines(), [])
	for id in ["ribs", "claw", "claw", "claw", "moonstone"]:
		player.collect_part(id)
	assert_eq(player.part_lines(), ["Grafts: Ribs, Claw x2", "Carrying: Claw, Moonstone"])

func test_a_body_that_cannot_graft_has_only_a_carrying_line() -> void:
	_make("wolf")
	player.collect_part("ribs")
	assert_eq(player.part_lines(), ["Carrying: Ribs"])

func test_the_form_tab_shows_the_grafts_and_the_carried() -> void:
	_make("undead")
	var screen := SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, CompendiumModel.new([], []), [])
	player.progression.add_xp(Progression.stage_total(player.progression.stage))
	player.collect_part("ribs")
	player.collect_part("moonstone")
	screen.open()
	screen.switch_tab(5)
	assert_eq(screen.tab(), "form")
	var text := "\n".join(screen.list_texts())
	assert_string_contains(text, "Grafts: Ribs")
	assert_string_contains(text, "Carrying: Moonstone")
	get_tree().paused = false

# --- in the room ---

func test_a_shed_graft_falls_in_the_room_and_waits_before_it_can_be_taken_back() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.player.set_species("undead")
	game.player.collect_part("claw")
	game.player.receive_hit(ceili(game.player.health.max_hp * Player.SHED_FRACTION), "fire")
	await wait_physics_frames(1)
	var found := get_tree().get_nodes_in_group("pickups").filter(func(p: Node) -> bool: return p.part.id == "claw")
	assert_eq(found.size(), 1)
	assert_eq(found[0].get_parent(), game.world.room)
	assert_gt(found[0].delay, 0.0)
	assert_gt(found[0].global_position.distance_to(game.player.global_position), 0.0)
	# standing right on it does not take it back at once
	found[0].global_position = game.player.global_position
	found[0]._physics_process(0.016)
	assert_eq(game.player.inventory.count("claw"), 0)
