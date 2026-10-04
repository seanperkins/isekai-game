extends GutTest
## The opening in the real scene, driven by real key presses: three trucks with a different choice each, then her menu with her first
## words, one confirm, and the first life begins (and a death afterwards is death 1). Also the launches that must not play it, which
## must still leave a fresh profile unseen. Everything the flow touches is snapshotted in before_each and written back in
## after_each (a failed assertion cleans up too), because loading the game saves to the Profile.

var game
var saved := {}

func before_each() -> void:
	var soul: SoulProgress = Compendium.soul
	var progress: WorldProgress = Compendium.progress
	var profile: Profile = Compendium.profile
	var last: Dictionary = progress.last_choice()
	saved = {
		"points": soul.points, "perks": soul.perks.duplicate(true), "deaths": soul.deaths, "session": soul.session_points,
		"seen": soul.opening_seen,
		"soul_section": profile.dict_section("soul"),
		"visited": progress.visited.duplicate(), "rebirths": progress.rebirths.duplicate(),
		"pending": progress.pending_start.duplicate(true), "pool": last["pool"], "species": last["species"],
		"map": profile.list_section("map"), "rebirths_section": profile.list_section("rebirths"),
		"choice_section": profile.dict_section("rebirth_choice"),
		"paused": get_tree().paused, "flag_used": Game.opening_flag_used,
	}
	Game.launch_override = {}

func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await wait_process_frames(1)
	game = null
	Game.launch_override = {}
	Game.opening_flag_used = saved["flag_used"]
	get_tree().paused = saved["paused"]
	var soul: SoulProgress = Compendium.soul
	soul.points = saved["points"]
	soul.perks = saved["perks"]
	soul.deaths = saved["deaths"]
	soul.session_points = saved["session"]
	soul.opening_seen = saved["seen"]
	var progress: WorldProgress = Compendium.progress
	progress.visited = saved["visited"]
	progress.rebirths = saved["rebirths"]
	progress.pending_start = saved["pending"]
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

## A profile that has not seen the opening, as far as memory goes, while the disk still says it has: only `_ready` writing the
## explicit false can make the disk agree.
func _unseen_in_memory_but_seen_on_disk() -> void:
	Compendium.soul.deaths = 0
	Compendium.soul.finish_opening()
	Compendium.soul.opening_seen = false
	Compendium.progress.set_last_choice("C1", "slime")
	Compendium.progress.pending_start = {}

func _load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await wait_physics_frames(2)

## What the Profile file holds, read fresh (as the next launch would).
func _disk() -> Profile:
	var p := Profile.new("user://profile.json")
	p.warn = func(_msg: String) -> void: pass
	p.reload()
	return p

## The real restart's cleanup (the unpause) without its scene reload, which would take the runner's scene with it; counts restarts.
func _count_restarts() -> Array:
	var restarts := [0]
	game.run.restart_requested.disconnect(game._restart)
	game.run.restart_requested.connect(func() -> void:
		restarts[0] += 1
		game._prepare_restart())
	return restarts

## Three trucks: Dodge, then Jump, then Pray, dismissing each result.
func _play_the_trucks(def: OpeningDef) -> void:
	_push(KEY_ENTER)
	assert_eq(game.opening.text_lines(), [def.result_for(0, "dodge")])
	_push(KEY_ENTER)
	_push(KEY_DOWN)
	_push(KEY_ENTER)
	assert_eq(game.opening.text_lines(), [def.result_for(1, "jump")])
	_push(KEY_ENTER)
	_push(KEY_DOWN, 2)
	_push(KEY_ENTER)
	assert_eq(game.opening.text_lines(), [def.result_for(2, "pray")])
	_push(KEY_ENTER)

func test_a_new_profile_plays_the_trucks_then_meets_her_and_begins_the_first_life() -> void:
	_unseen_in_memory_but_seen_on_disk()
	Game.launch_override = {"headless": false}
	await _load_game()
	var def := Game.load_opening()
	assert_true(game.opening.is_playing(), "an unseen profile in a windowed launch plays it")
	assert_true(get_tree().paused)
	var on_disk := _disk().dict_section("soul")
	assert_true(on_disk.has("opening_seen") and on_disk["opening_seen"] == false, "the unseen flag reached the disk before the map")
	var restarts := _count_restarts()
	var menu := InputEventAction.new()
	menu.action = "menu"
	menu.pressed = true
	get_viewport().push_input(menu)
	assert_false(game.skill_screen.visible, "the menu key does nothing while the trucks play")
	assert_true(game.opening.is_playing())
	assert_eq(game.opening.text_lines(), [def.trucks[0]["prompt"]])
	_play_the_trucks(def)
	assert_false(game.opening.visible, "the opening hides its layer for her menu")
	assert_false(game.opening.is_playing())
	assert_true(game.goddess_menu.is_open())
	assert_eq(game.goddess_menu.line_text(), def.goddess_line, "her first words")
	assert_true(get_tree().paused, "her menu works over the paused tree")
	assert_false(Compendium.soul.opening_seen, "not until she is accepted")
	_push(KEY_ENTER)
	assert_eq(restarts[0], 1)
	assert_eq(Compendium.progress.pending_start, {"altar": "C1", "species": "slime", "kit": {}})
	assert_true(Compendium.soul.opening_seen)
	assert_true(_disk().dict_section("soul")["opening_seen"], "the disk says seen too")
	assert_eq(Compendium.soul.deaths, 0, "the trucks are not a death")
	assert_false(get_tree().paused, "the restart's cleanup unpaused it")
	game.player.receive_hit(9999, "physical", Vector2.INF, "bat")
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.3)
	assert_eq(Compendium.soul.deaths, 1, "the first real death reads as death 1")

func test_a_forced_replay_of_a_seen_profile_keeps_it_seen() -> void:
	Compendium.soul.finish_opening()
	Compendium.progress.set_last_choice("C1", "slime")
	Compendium.progress.pending_start = {}
	Game.opening_flag_used = false
	Game.launch_override = {"headless": false, "args": ["--opening"]}
	await _load_game()
	assert_true(game.opening.is_playing(), "--opening replays a seen profile")
	assert_true(Game.opening_flag_used, "and is used up for this process")
	assert_true(_disk().dict_section("soul")["opening_seen"], "a replay never writes the profile back to unseen")
	var restarts := _count_restarts()
	_play_the_trucks(Game.load_opening())
	assert_true(game.goddess_menu.is_open())
	_push(KEY_ENTER)
	assert_eq(restarts[0], 1)
	assert_true(Compendium.soul.opening_seen)
	assert_true(_disk().dict_section("soul")["opening_seen"])

func test_a_headless_first_launch_leaves_a_fresh_profile_unseen() -> void:
	_unseen_in_memory_but_seen_on_disk()
	await _load_game()  # the runner is headless: the opening is not wanted
	assert_false(game.opening.is_playing())
	assert_false(get_tree().paused)
	var disk := _disk()
	assert_false(disk.list_section("map").is_empty(), "the first room has been entered and its map saved")
	var on_disk := disk.dict_section("soul")
	assert_true(on_disk.has("opening_seen") and on_disk["opening_seen"] == false, "an explicit unseen survives the map write")
	assert_false(SoulProgress.new(disk, []).opening_seen, "so the next launch, windowed, still plays it")

func test_a_skipped_first_launch_leaves_a_fresh_profile_unseen() -> void:
	_unseen_in_memory_but_seen_on_disk()
	Game.launch_override = {"headless": false, "args": ["--skip-opening"]}
	await _load_game()
	assert_false(game.opening.is_playing(), "--skip-opening skips it")
	assert_false(get_tree().paused)
	var on_disk := _disk().dict_section("soul")
	assert_true(on_disk.has("opening_seen") and on_disk["opening_seen"] == false)
