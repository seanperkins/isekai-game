extends GutTest
## Dying and starting the next life: a direct restart at the only unlocked pool, or a choice, and the run
## begins at the chosen pool with its kit applied after start_run().

class Mortal extends Node:
	signal died

func _pools() -> Array:
	return [{"id": "C1", "area": "cave", "room": "C1", "pos": Vector2(140, 320), "kit": {}, "name": "Cave mouth"},
		{"id": "G1", "area": "grotto", "room": "C3", "pos": Vector2(100, 300), "kit": {"skills": ["leap"], "level": 3}, "name": "Grotto rebirth pool"}]

func _run(progress: WorldProgress, pools: Array) -> Array:
	var run := Run.new()
	add_child_autofree(run)
	var body: Mortal = autofree(Mortal.new())
	var world := World.new()
	add_child_autofree(world)
	run.bind(body, world, progress, pools)
	return [run, body]

func _await_card() -> void:
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.3)

func test_with_only_the_default_pool_death_restarts_directly_and_records_the_start() -> void:
	var progress := WorldProgress.new()
	var pair := _run(progress, _pools())
	var restarts := [0]
	pair[0].restart_requested.connect(func() -> void: restarts[0] += 1)
	pair[1].died.emit()
	await _await_card()
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start, {"pool": "C1", "species": "slime"})
	assert_eq(progress.last_choice()["pool"], "C1")

func test_with_a_second_attuned_pool_death_asks_and_waits_for_the_choice() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	progress.set_last_choice("G1")
	var pair := _run(progress, _pools())
	var seen := []
	var restarts := [0]
	pair[0].choice_needed.connect(func(d: Dictionary) -> void: seen.append(d))
	pair[0].restart_requested.connect(func() -> void: restarts[0] += 1)
	pair[1].died.emit()
	await _await_card()
	assert_eq(seen.size(), 1)
	assert_eq(restarts[0], 0, "no restart until a pool is chosen")
	assert_eq(seen[0]["options"].map(func(o): return o["id"]), ["C1", "G1"])
	assert_eq(seen[0]["selected"], 1, "the last choice is pre-selected")
	pair[0].choose("G1")
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start["pool"], "G1")
	assert_eq(progress.last_choice()["pool"], "G1")

func test_a_second_death_during_the_choice_does_nothing() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	var pair := _run(progress, _pools())
	var seen := [0]
	pair[0].choice_needed.connect(func(_d: Dictionary) -> void: seen[0] += 1)
	pair[1].died.emit()
	pair[1].died.emit()
	await _await_card()
	pair[1].died.emit()
	await _await_card()
	assert_eq(seen[0], 1)

func test_choosing_a_locked_or_unknown_pool_is_ignored() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	var pair := _run(progress, _pools() + [{"id": "F1", "area": "flooded", "room": "C4", "pos": Vector2.ZERO, "kit": {}, "name": "F"}])
	var restarts := [0]
	pair[0].restart_requested.connect(func() -> void: restarts[0] += 1)
	pair[0].choice_needed.connect(func(_d: Dictionary) -> void: pass)
	pair[1].died.emit()
	await _await_card()
	pair[0].choose("F1")
	pair[0].choose("nowhere")
	pair[0].choose("")
	assert_eq(restarts[0], 0)
	assert_eq(progress.pending_start, {})

func test_a_choice_can_only_be_made_once_per_death() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	var pair := _run(progress, _pools())
	var restarts := [0]
	pair[0].restart_requested.connect(func() -> void: restarts[0] += 1)
	pair[0].choice_needed.connect(func(_d: Dictionary) -> void: pass)
	pair[1].died.emit()
	await _await_card()
	pair[0].choose("G1")
	pair[0].choose("C1")
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start["pool"], "G1", "the first choice stands")

func test_with_no_menu_yet_the_preselected_pool_is_taken_so_the_game_never_hangs() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	progress.set_last_choice("G1")
	var pair := _run(progress, _pools())
	var restarts := [0]
	pair[0].restart_requested.connect(func() -> void: restarts[0] += 1)
	pair[1].died.emit()
	await _await_card()
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start["pool"], "G1")

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
	assert_eq(Game.resolve_start(_pools(), {}, attuned), {"default": true, "kit": {}})
	assert_eq(Game.resolve_start(_pools(), {"pool": "C1", "species": "slime"}, attuned), {"default": true, "kit": {}})

func test_an_attuned_pool_starts_in_its_room_at_its_spot_with_its_kit() -> void:
	var attuned := func(id: String) -> bool: return true
	var s := Game.resolve_start(_pools(), {"pool": "G1", "species": "slime"}, attuned)
	assert_false(s["default"])
	assert_eq(s["room"], "C3")
	assert_eq(s["pos"], Vector2(100, 300 - BodyConfig.BOTTOM), "standing on the pool, not inside it")
	assert_eq(s["kit"], {"skills": ["leap"], "level": 3})

func test_an_unattuned_or_unknown_pool_falls_back_to_the_default() -> void:
	var only_default := func(id: String) -> bool: return id == "C1"
	assert_true(Game.resolve_start(_pools(), {"pool": "G1"}, only_default)["default"], "not attuned")
	assert_true(Game.resolve_start(_pools(), {"pool": "GONE"}, func(_id: String) -> bool: return true)["default"], "no such pool")
	assert_true(Game.resolve_start(_pools(), {"pool": 7}, func(_id: String) -> bool: return true)["default"], "malformed")

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
	Compendium.progress.pending_start = {"pool": "C1", "species": "slime"}
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
	RebirthKit.apply(player, rules, comp, {"skills": ["leap"], "level": 3, "affinity": {"thread": 2}})
	assert_eq(player.progression.level, 3)
	rules.start_run()  # the next life begins: everything goes
	assert_eq(player.progression.level, 1)
	assert_eq(rules.level_of("leap"), 0)
	assert_true(player.progression.seeded.is_empty())
	RebirthKit.apply(player, rules, comp, {})
	assert_eq(player.progression.level, 1, "an empty kit gives an empty start")

func test_species_is_carried_on_the_pending_start() -> void:
	var progress := WorldProgress.new()
	progress.set_last_choice("C1", "slime")
	var pair := _run(progress, _pools())
	pair[1].died.emit()
	await _await_card()
	assert_eq(progress.pending_start["species"], "slime")
