extends GutTest
## Dying and starting the next life: her line on the death card, a direct restart or her menu, and the run begins at the chosen
## altar with the bought kit applied after start_run().

class Mortal extends Node:
	signal died
	var last_hit_cause := ""

var skills: Array
var creatures: Array

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	creatures = DefLoader.load_dir("res://data/creatures")

func _pools() -> Array:
	return [{"id": "C1", "area": "cave", "room": "C1", "pos": Vector2(140, 320), "kit": {}, "name": "Cave mouth"},
		{"id": "G1", "area": "grotto", "room": "C3", "pos": Vector2(100, 300), "kit": {"skills": ["leap"], "level": 3}, "name": "Grotto rebirth pool"}]

func _goddess(points := 0) -> Goddess:
	var soul := SoulProgress.new()
	soul.points = points
	var slime := SpeciesDef.new()
	slime.id = "slime"
	slime.display_name = "Slime"
	slime.unlock = {"kind": "default"}
	var lines := GoddessLines.new()
	lines.by_cause = {"bat": ["b0", "b1"]}
	lines.many_deaths = ["m0"]
	lines.fallback = "f"
	return Goddess.new(soul, SoulRules.new(), lines, {"slime": slime}, [], CompendiumModel.new(skills, creatures), skills)

func _run(progress: WorldProgress, pools: Array, goddess: Goddess = null) -> Array:
	var run := Run.new()
	add_child_autofree(run)
	var body: Mortal = autofree(Mortal.new())
	var world := World.new()
	add_child_autofree(world)
	run.bind(body, world, progress, pools, goddess)
	return [run, body]

func _await_card() -> void:
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.3)

## Listens for the menu request and keeps what it was told.
func _watch(run: Run) -> Array:
	var seen := []
	run.goddess_needed.connect(func(model: GoddessModel, line: String) -> void: seen.append([model, line]))
	return seen

func _restarts(run: Run) -> Array:
	var count := [0]
	run.restart_requested.connect(func() -> void: count[0] += 1)
	return count

# --- the death flow ---

func test_with_nothing_to_choose_death_restarts_directly_and_records_the_start() -> void:
	var progress := WorldProgress.new()
	var pair := _run(progress, _pools(), _goddess())
	var restarts := _restarts(pair[0])
	var asked := _watch(pair[0])
	pair[1].died.emit()
	await _await_card()
	assert_eq(restarts[0], 1)
	assert_eq(asked.size(), 0, "nothing to choose, so no menu")
	assert_eq(progress.pending_start, {"altar": "C1", "species": "slime", "kit": {}})
	assert_eq(progress.last_choice()["pool"], "C1")

func test_the_card_shows_her_line_for_the_cause_and_counts_one_death() -> void:
	var goddess := _goddess()
	var pair := _run(WorldProgress.new(), _pools(), goddess)
	pair[1].last_hit_cause = "bat"
	pair[1].died.emit()
	pair[1].died.emit()
	assert_eq(pair[0].line_text(), "b1", "the first death is death 1, so the second bat line")
	assert_eq(goddess.soul.deaths, 1, "one death, however many times died fires")
	await _await_card()

func test_a_second_altar_asks_and_waits() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	progress.set_last_choice("G1")
	var pair := _run(progress, _pools(), _goddess())
	var asked := _watch(pair[0])
	var restarts := _restarts(pair[0])
	pair[1].died.emit()
	await _await_card()
	assert_eq(asked.size(), 1)
	assert_eq(restarts[0], 0, "no restart until the choice is made")
	var model: GoddessModel = asked[0][0]
	assert_eq(model.selected_place(), "G1", "the last choice is pre-selected")
	pair[0].accept(model.confirm())
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start["altar"], "G1")
	assert_eq(progress.last_choice()["pool"], "G1")

func test_points_to_spend_open_the_menu_even_with_one_altar() -> void:
	var pair := _run(WorldProgress.new(), _pools(), _goddess(5))
	var asked := _watch(pair[0])
	var restarts := _restarts(pair[0])
	pair[1].died.emit()
	await _await_card()
	assert_eq(asked.size(), 1)
	assert_eq(restarts[0], 0)

func test_accept_spends_the_cost_and_carries_the_kit() -> void:
	var goddess := _goddess(9)
	var progress := WorldProgress.new()
	var pair := _run(progress, _pools(), goddess)
	var asked := _watch(pair[0])
	pair[1].died.emit()
	await _await_card()
	var model: GoddessModel = asked[0][0]
	model.switch_panel(-1)
	for i in 3:
		model.adjust(1)
	pair[0].accept(model.confirm())
	assert_eq(goddess.soul.total_points(), 0, "2 + 3 + 4 spent")
	assert_eq(progress.pending_start["kit"], {"level": 4})

func test_accept_ignores_a_result_the_pending_model_did_not_produce() -> void:
	var goddess := _goddess(5)
	var progress := WorldProgress.new()
	var pair := _run(progress, _pools(), goddess)
	var asked := _watch(pair[0])
	var restarts := _restarts(pair[0])
	pair[1].died.emit()
	await _await_card()
	var model: GoddessModel = asked[0][0]
	model.switch_panel(-1)
	model.adjust(1)
	var own := model.confirm()
	assert_eq(own, {"altar": "C1", "species": "slime", "kit": {"level": 2}, "cost": 2})
	var free := own.duplicate(true)
	free["cost"] = 0
	var negative := own.duplicate(true)
	negative["cost"] = -1
	var grand := {"altar": "C1", "species": "slime", "kit": {"level": 9}, "cost": 99}
	var underpaid := {"altar": "C1", "species": "slime", "kit": {"level": 9}, "cost": 2}
	model.adjust(1)  # one more level: `own` is now stale
	for forged in [free, negative, grand, underpaid, own]:
		pair[0].accept(forged)
	assert_eq(restarts[0], 0)
	assert_eq(progress.pending_start, {})
	assert_eq(goddess.soul.total_points(), 5, "nothing was spent")
	pair[0].accept(model.confirm())
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start["kit"], {"level": 3})
	assert_eq(goddess.soul.total_points(), 0)

func test_a_choice_is_taken_once_and_nothing_pending_is_ignored() -> void:
	var pair := _run(WorldProgress.new(), _pools(), _goddess(5))
	var asked := _watch(pair[0])
	var restarts := _restarts(pair[0])
	pair[1].died.emit()
	await _await_card()
	var model: GoddessModel = asked[0][0]
	pair[0].accept({})
	assert_eq(restarts[0], 0, "an empty result is ignored")
	pair[0].accept(model.confirm())
	pair[0].accept(model.confirm())
	assert_eq(restarts[0], 1, "the first choice stands")
	var idle := _run(WorldProgress.new(), _pools(), _goddess())
	var idle_restarts := _restarts(idle[0])
	idle[0].accept({"altar": "C1", "species": "slime", "kit": {}, "cost": 0})
	assert_eq(idle_restarts[0], 0, "nothing was asked, so nothing can be accepted")

func test_a_second_death_during_the_choice_does_nothing() -> void:
	var pair := _run(WorldProgress.new(), _pools(), _goddess(5))
	var asked := _watch(pair[0])
	pair[1].died.emit()
	pair[1].died.emit()
	await _await_card()
	pair[1].died.emit()
	await _await_card()
	assert_eq(asked.size(), 1)

func test_with_no_menu_listening_the_default_is_taken() -> void:
	var goddess := _goddess(5)
	var progress := WorldProgress.new()
	assert_true(goddess.model(progress, _pools()).need_menu(), "5 points reach the first level's price of 2")
	var pair := _run(progress, _pools(), goddess)
	var restarts := _restarts(pair[0])
	pair[1].died.emit()
	await _await_card()
	assert_eq(restarts[0], 1, "the game never hangs")
	assert_eq(progress.pending_start["kit"], {})
	assert_eq(goddess.soul.total_points(), 5)

func test_without_a_goddess_the_last_attuned_choice_is_taken() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	progress.set_last_choice("G1")
	var pair := _run(progress, _pools())
	var restarts := _restarts(pair[0])
	pair[1].died.emit()
	await _await_card()
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start, {"altar": "G1", "species": "slime", "kit": {}})

func test_without_a_goddess_a_last_choice_that_is_not_attuned_falls_back_to_the_default() -> void:
	var progress := WorldProgress.new()
	progress.set_last_choice("G1")
	var pair := _run(progress, _pools())
	pair[1].died.emit()
	await _await_card()
	assert_eq(progress.pending_start["altar"], "C1")

func test_a_run_bound_without_progress_behaves_as_before() -> void:
	var run := Run.new()
	add_child_autofree(run)
	var body: Mortal = autofree(Mortal.new())
	var world := World.new()
	add_child_autofree(world)
	run.bind(body, world)
	var restarts := [0]
	run.restart_requested.connect(func() -> void: restarts[0] += 1)
	body.died.emit()
	await _await_card()
	assert_eq(restarts[0], 1)

# --- starting the next life ---

func test_the_default_pool_starts_at_the_start_room_with_no_kit() -> void:
	var attuned := func(id: String) -> bool: return id == "C1"
	assert_eq(Game.resolve_start(_pools(), {}, attuned), {"default": true, "kit": {}, "species": "slime"})
	assert_eq(Game.resolve_start(_pools(), {"altar": "C1", "species": "slime"}, attuned), {"default": true, "kit": {}, "species": "slime"})

func test_an_attuned_pool_starts_in_its_room_at_its_spot_with_the_kit_and_species_from_pending() -> void:
	var attuned := func(_id: String) -> bool: return true
	var pending := {"altar": "G1", "species": "slime", "kit": {"level": 2}}
	var s := Game.resolve_start(_pools(), pending, attuned)
	assert_false(s["default"])
	assert_eq(s["room"], "C3")
	assert_eq(s["pos"], Vector2(100, 300 - BodyConfig.BOTTOM), "standing on the pool, not inside it")
	assert_eq(s["kit"], {"level": 2}, "the bought kit, never the pool's own")
	assert_eq(s["species"], "slime")
	assert_eq(s["altar"], "G1")

func test_an_unattuned_or_unknown_pool_falls_back_to_the_default_place_and_keeps_the_kit() -> void:
	var only_default := func(id: String) -> bool: return id == "C1"
	var pending := {"altar": "G1", "kit": {"level": 2}}
	var s := Game.resolve_start(_pools(), pending, only_default)
	assert_true(s["default"], "not attuned")
	assert_eq(s["kit"], {"level": 2}, "what was paid for is still given")
	assert_true(Game.resolve_start(_pools(), {"altar": "GONE"}, func(_id: String) -> bool: return true)["default"], "no such pool")
	assert_true(Game.resolve_start(_pools(), {"altar": 7}, func(_id: String) -> bool: return true)["default"], "malformed")

func test_a_malformed_kit_or_species_in_pending_falls_back() -> void:
	var s := Game.resolve_start(_pools(), {"kit": "level 9", "species": 3}, func(_id: String) -> bool: return true)
	assert_eq(s["kit"], {})
	assert_eq(s["species"], "slime")

func test_the_world_can_start_at_a_pool() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	game.world.enter_at("C3", Vector2(100, 300))
	assert_eq(game.world.current_id, "C3")
	var rect: Rect2 = (game.world.rooms["C3"] as RoomDef).world_rect()
	assert_eq(game.player.global_position, rect.position + Vector2(100, 300))
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_the_game_consumes_the_pending_start_so_a_later_reload_does_not_replay_it() -> void:
	Compendium.progress.pending_start = {"altar": "C1", "species": "slime"}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	assert_eq(Compendium.progress.pending_start, {})
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_a_kit_applies_after_start_run_and_never_survives_into_the_next_life() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var comp := CompendiumModel.new([], [])
	var player := Player.new()
	player.setup(rules, comp, [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	HeadStart.apply(player, rules, comp, {"skills": ["leap"], "level": 3})
	assert_eq(player.progression.level, 3)
	rules.start_run()  # the next life begins: everything goes
	assert_eq(player.progression.level, 1)
	assert_eq(rules.level_of("leap"), 0)
	HeadStart.apply(player, rules, comp, {})
	assert_eq(player.progression.level, 1, "an empty kit gives an empty start")

func test_the_game_gives_a_kit_after_start_run_so_the_new_life_keeps_it() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	game.player.debug_grant_xp(30)  # some leftover state from the previous life
	game.begin_life({"default": false, "kit": {"skills": ["leap"], "level": 3}})
	assert_eq(game.player.progression.level, 3)
	assert_eq(game.player.progression.xp, 0, "a starting level banks no XP")
	assert_true(SkillRules.owned().has("leap"), "the granted skill survived start_run")
	assert_eq(SkillRules.level_of("leap"), 1)
	game.begin_life({"default": true, "kit": {}})
	assert_eq(game.player.progression.level, 1, "the next life clears the kit")
	assert_false(SkillRules.owned().has("leap"))
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_species_is_carried_on_the_pending_start() -> void:
	var progress := WorldProgress.new()
	progress.set_last_choice("C1", "slime")
	var pair := _run(progress, _pools())
	pair[1].died.emit()
	await _await_card()
	assert_eq(progress.pending_start["species"], "slime")
