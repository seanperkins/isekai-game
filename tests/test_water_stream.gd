extends GutTest
## Hold Hydraulic Propulsion for a water stream: an extended burst. A tap is today's cast; a hold keeps the burst going (thrust
## only while below the burst's own speed, 0.6 s at most) and never flies.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var events: Array
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	events = []
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})  # Hydraulic Propulsion, slot 0

func after_each() -> void:
	for a in ["active_1", "aim_up", "move_left", "move_right"]:
		Input.action_release(a)

func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Presses the slot for `hold_ticks` physics ticks, releases, waits for the burst to finish, and returns the displacement.
func _cast(hold_ticks: int, aim_up := false) -> Dictionary:
	var start := player.global_position
	var apex := start.y
	if aim_up:
		Input.action_press("aim_up")
	Input.action_press("active_1")
	for i in hold_ticks:
		await get_tree().physics_frame
		apex = minf(apex, player.global_position.y)
	Input.action_release("active_1")
	for i in 80:
		await get_tree().physics_frame
		apex = minf(apex, player.global_position.y)
	Input.action_release("aim_up")
	return {"dx": player.global_position.x - start.x, "rise": start.y - apex, "dy": player.global_position.y - start.y}

func test_a_tap_keeps_the_bursts_full_lock_and_travels_at_least_95_px() -> void:
	var r := await _cast(1)
	assert_gte(r["dx"], 95.0)

func test_a_six_tick_press_never_travels_less_than_a_tap() -> void:
	var tap := await _cast(1)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	await wait_seconds(0.9)  # the cooldown
	var six := await _cast(6)
	assert_gte(six["dx"], tap["dx"] - 1.0)

func test_a_full_horizontal_hold_stretches_the_burst_but_does_not_fly() -> void:
	var tap := await _cast(1)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	await wait_seconds(0.9)
	var full := await _cast(60)  # held well past the 0.6 s cap
	assert_lte(full["dx"], tap["dx"] * 3.5)
	assert_gt(full["dx"], tap["dx"] * 2.0, "the hold does extend it")
	assert_gt(full["dy"], 0.0, "gravity still applies: it falls")
	assert_null(player._channel, "the cap ended it")

func test_a_full_upward_hold_rises_at_most_1_6_times_a_taps_apex() -> void:
	var tap := await _cast(1, true)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	await wait_seconds(0.9)
	var full := await _cast(60, true)
	assert_gt(tap["rise"], 60.0)
	assert_lte(full["rise"], tap["rise"] * 1.6)

func test_the_direction_is_latched_at_the_press() -> void:
	player.facing = 1
	Input.action_press("active_1")
	await _ticks(3)
	Input.action_press("move_left")  # mid-hold: facing flips every tick; the stream must not follow it
	var lowest := INF
	for i in 25:
		await get_tree().physics_frame
		lowest = minf(lowest, player.velocity.x)
	assert_gte(lowest, 379.0, "the burst speed is held: nothing steered or braked the stream")

func test_the_hold_ends_at_0_6_seconds_even_at_maximum_regen() -> void:
	player.stats.set_modifiers("test_regen", [{"stat": "mp_regen", "op": "add", "value": 300}])
	Input.action_press("active_1")
	await wait_seconds(0.9)
	assert_null(player._channel)

func test_a_full_hold_costs_the_start_and_one_beat() -> void:
	Input.action_press("active_1")
	await wait_seconds(0.9)
	assert_eq(events.filter(func(e): return e[0] == "mana_spent").size(), 3 + 1)

func test_the_spray_is_a_child_of_the_ability_and_follows_the_channel() -> void:
	Input.action_press("active_1")
	await _ticks(3)
	var ability: Ability = player._abilities["hydraulic_propulsion"]
	var spray: CPUParticles2D = ability.get_children().filter(func(n): return n is CPUParticles2D)[0]
	assert_true(spray.emitting)
	assert_false(spray.is_in_group("vfx"))
	Input.action_release("active_1")
	await _ticks(3)
	assert_false(spray.emitting)
	assert_true(spray.visible, "a soft stop lets the last spray finish")

func test_a_hard_stop_hides_the_spray_at_once() -> void:
	Input.action_press("active_1")
	await _ticks(3)
	var ability: Ability = player._abilities["hydraulic_propulsion"]
	var spray: CPUParticles2D = ability.get_children().filter(func(n): return n is CPUParticles2D)[0]
	player.end_channel()
	assert_false(spray.visible)
	assert_false(spray.emitting)
