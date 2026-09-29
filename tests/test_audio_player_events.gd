extends GutTest
## The player's audio-only events: landings, run and wall-slide loops, and the moments Player emits directly.

var seen: Array = []
var rules: SkillRulesEngine
var compendium: CompendiumModel
var player: Player

func _record(n: String, t: Dictionary) -> void:
	seen.append([n, t])

func _names() -> Array:
	return seen.map(func(e): return e[0])

func before_each() -> void:
	seen = []
	EventBus.world_event.connect(_record)

func after_each() -> void:
	EventBus.world_event.disconnect(_record)

func _tracker() -> PlayerAudioEvents:
	var p := PlayerAudioEvents.new()
	p.emit_event = _record
	return p

func test_a_hard_landing_reports_its_speed() -> void:
	var p := _tracker()
	p.update(false, 500.0, 0.0, false, false)   # falling
	p.update(true, 500.0, 0.0, false, false)    # touches down at 500 px/s
	assert_eq(seen, [["landed", {"hard": true, "speed": 500.0}]])

func test_a_soft_landing_and_no_landing_from_a_tiny_drop() -> void:
	var p := _tracker()
	p.update(false, 200.0, 0.0, false, false)
	p.update(true, 200.0, 0.0, false, false)
	assert_eq(seen, [["landed", {"hard": false, "speed": 200.0}]])
	seen = []
	p.update(false, 30.0, 0.0, false, false)
	p.update(true, 30.0, 0.0, false, false)
	assert_eq(seen, [])

func test_standing_on_the_floor_never_lands_again() -> void:
	var p := _tracker()
	for i in 10:
		p.update(true, 0.0, 0.0, false, false)
	assert_eq(seen, [])

func test_running_starts_and_stops_once_per_run() -> void:
	var p := _tracker()
	p.update(true, 0.0, 140.0, false, false)
	p.update(true, 0.0, 140.0, false, false)
	p.update(true, 0.0, 0.0, false, false)
	assert_eq(_names(), ["run_started", "run_stopped"])

func test_running_stops_when_leaving_the_floor_or_spreading() -> void:
	var p := _tracker()
	p.update(true, 0.0, 140.0, false, false)
	p.update(false, 100.0, 140.0, false, false)
	assert_eq(_names(), ["run_started", "run_stopped"])
	seen = []
	p.update(true, 0.0, 140.0, false, false)
	p.update(true, 0.0, 140.0, true, false)
	assert_eq(_names(), ["run_started", "run_stopped"])

func test_wall_slide_starts_and_stops() -> void:
	var p := _tracker()
	p.update(false, 80.0, 0.0, false, true)
	p.update(false, 80.0, 0.0, false, true)
	p.update(false, 80.0, 0.0, false, false)
	assert_eq(_names(), ["wall_slide_started", "wall_slide_stopped"])

func test_reset_ends_a_run_loop_and_says_nothing_the_second_time() -> void:
	var p := _tracker()
	p.update(true, 0.0, 140.0, false, false)
	seen = []
	p.reset()
	p.reset()
	assert_eq(_names(), ["run_stopped"])

func test_reset_ends_a_wall_slide_loop() -> void:
	var p := _tracker()
	p.update(false, 80.0, 0.0, false, true)
	seen = []
	p.reset()
	assert_eq(_names(), ["wall_slide_stopped"])

# --- Player emits the rest -------------------------------------------------------

func _player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	return player

func test_tackle_spread_and_level_up_emit_world_events() -> void:
	_player()
	player.do_tackle()
	assert_has(_names(), "tackled")
	player.set_spread(true)
	assert_true(seen.any(func(e): return e[0] == "spread" and e[1]["on"] == true))
	player.set_spread(false)
	assert_true(seen.any(func(e): return e[0] == "spread" and e[1]["on"] == false))
	player.award_xp(1000)
	assert_has(_names(), "leveled_up")

func test_dying_says_so_and_ends_the_loops() -> void:
	_player()
	player.audio_events.emit_event = _record
	player.audio_events.update(true, 0.0, 140.0, false, false)
	seen = []
	player.receive_hit(999, "physical")
	assert_has(_names(), "player_died")
	assert_has(_names(), "run_stopped")

func test_setting_spread_to_the_same_state_is_silent() -> void:
	_player()
	seen = []
	player.set_spread(false)
	assert_eq(seen, [])
