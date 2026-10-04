extends GutTest
## Fixes from the controller-v2 review: aim at partial tilt, stale second devices, upward
## casts while falling, ability defaults when nothing is held, per-run level reset, UI text.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	for dev in [0, 1]:
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			_axis(axis, 0.0, dev)
	Controls.using_joypad = false
	Controls.last_stick = Vector2.ZERO
	for n in get_tree().get_nodes_in_group("vfx"):
		n.free()

func _axis(axis: JoyAxis, value: float, device: int = 0) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	Controls._input(ev)

func test_a_partial_stick_tilt_still_aims() -> void:
	_axis(JOY_AXIS_LEFT_Y, -0.45)  # below the old ~51% threshold
	assert_true(player.aim_held())
	assert_eq(player.aim_vector(), Vector2(0, -1))

func test_a_stale_second_device_does_not_cancel_the_aim() -> void:
	_axis(JOY_AXIS_LEFT_Y, 1.0, 1)   # a ghost pad reports down once and goes quiet
	_axis(JOY_AXIS_LEFT_Y, -1.0, 0)  # the real pad pushes up
	assert_eq(player.aim_vector(), Vector2(0, -1))

func test_upward_cast_overrides_fall_speed() -> void:
	player.velocity = Vector2(0, 500)
	player.apply_impulse(Vector2(0, -380))
	assert_eq(player.velocity.y, -380.0)
	player.velocity = Vector2(0, 200)
	player.apply_impulse(Vector2(300, 0))  # a flat dash keeps the current vertical speed
	assert_eq(player.velocity, Vector2(300, 200))

func test_nothing_held_lets_abilities_use_their_default() -> void:
	assert_false(player.aim_held())
	player.skillset.slots.owned.append("swing_thread")
	player.skillset.slots.slots[0] = "swing_thread"
	player.use_active(0)
	var swing: Ability = player._abilities["swing_thread"]
	assert_eq(swing.aim, Vector2.ZERO)
	assert_eq(player.last_cast["aim"], Vector2(1, -1).normalized())  # recorded as the direction actually used

func test_levels_reset_when_a_run_restarts_in_place() -> void:
	player.award_xp(25)
	assert_eq(player.progression.level, 3)
	rules.start_run()
	assert_eq([player.progression.level, player.progression.xp], [1, 0])
	assert_eq(player.health.max_hp, 30)

func test_debug_toggle_is_f3_and_back() -> void:
	var keys := InputMap.action_get_events("debug_input").filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
	assert_eq(keys, [KEY_F3])
