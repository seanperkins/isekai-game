extends GutTest
## The pointer (the right stick, or the mouse cursor) aims casts freely, snapped to an exact axis near horizontal and vertical
## so the two "flat aim" checks keep working. The left stick and keys stay 8-way, and no pointer reaches the spread or the reel.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	PadInput.reset()
	for n in get_tree().get_nodes_in_group("vfx"):
		n.free()

func _right(x: float, y: float, device := 0) -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, x, device)
	PadInput.axis(JOY_AXIS_RIGHT_Y, y, device)

func _left(x: float, y: float) -> void:
	PadInput.axis(JOY_AXIS_LEFT_X, x)
	PadInput.axis(JOY_AXIS_LEFT_Y, y)

func _mouse_at(point: Vector2) -> void:
	player.pointer_override = point
	PadInput.mouse_move(Vector2(10, 0))  # the mouse is the aimer now

func _hydraulic() -> void:
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})  # Hydraulic Propulsion in slot 0
	player.mana.mp = 20
	player.mana.max_mp = 20

func _swap_in(scene: String, values: Array) -> Ability:
	var a: Ability = load("res://scenes/abilities/%s.tscn" % scene).instantiate()
	player.add_child(a)
	a.setup(player, values, 1)
	player._abilities["hydraulic_propulsion"] = a
	return a

# --- the right stick ---

func test_thirty_degrees_up_from_right_is_that_exact_direction() -> void:
	var v := Vector2.from_angle(deg_to_rad(-30.0))
	_right(v.x, v.y)
	assert_true(player.free_aim().is_equal_approx(v))

func test_a_shallow_stick_snaps_to_the_exact_axis_on_all_four_sides() -> void:
	var axes := {0.0: Vector2(1, 0), 90.0: Vector2(0, 1), 180.0: Vector2(-1, 0), 270.0: Vector2(0, -1)}
	for base in axes:
		for off in [-5.0, 5.0]:
			var v := Vector2.from_angle(deg_to_rad(base + off))
			_right(v.x, v.y)
			assert_eq(player.free_aim(), axes[base], "%s degrees %s" % [base, off])

func test_the_snap_ends_between_9_9_and_10_1_degrees() -> void:
	var inside := Vector2.from_angle(deg_to_rad(9.9))
	_right(inside.x, inside.y)
	assert_eq(player.free_aim(), Vector2(1, 0))
	var outside := Vector2.from_angle(deg_to_rad(10.1))
	_right(outside.x, outside.y)
	assert_ne(player.free_aim().y, 0.0)
	assert_true(player.free_aim().is_equal_approx(outside))

func test_the_snap_compares_the_normalised_stick_not_the_raw_one() -> void:
	_right(0.55, 0.13)  # length 0.565 (engaged); raw |y| 0.13 is under 0.1736, but normalised it is 0.230: 13 degrees
	assert_ne(player.free_aim().y, 0.0)
	assert_true(player.free_aim().is_equal_approx(Vector2(0.55, 0.13).normalized()))

func test_cast_aim_falls_back_to_the_left_stick_then_to_nothing() -> void:
	assert_eq(player.cast_aim(), Vector2.ZERO)
	_right(0.3, 0.1)  # an owning push under the 0.45 deadzone aims nothing
	assert_eq(player.free_aim(), Vector2.ZERO)
	assert_eq(player.cast_aim(), Vector2.ZERO)
	_left(0.0, -1.0)
	assert_eq(player.cast_aim(), Vector2(0, -1))

func test_the_right_stick_beats_the_left_stick_for_the_cast() -> void:
	_left(0.0, -1.0)
	_right(1.0, 0.0)
	assert_eq(player.cast_aim(), Vector2(1, 0))
	assert_eq(player.aim_vector(), Vector2(0, -1), "the left stick's own aim is unchanged")

func test_the_right_stick_beats_a_key_held_before_it_was_pushed() -> void:
	Input.action_press("aim_down")  # held first: action_press sends no event, so nothing hands the aim to the key
	_right(1.0, 0.0)
	assert_eq(player.cast_aim(), Vector2(1, 0))

func test_a_key_press_gives_the_cast_back_to_the_left_stick_or_the_keys() -> void:
	_right(1.0, 0.0, 1)  # a second pad's right stick
	PadInput.key(KEY_W)   # the keyboard is the last input: the gate closes
	Input.action_press("aim_up")
	assert_eq(player.cast_aim(), Vector2(0, -1), "the keys")
	Controls.last_stick = Vector2(-1, 0)  # a left stick held from before the key press (a new event would re-arm the pad)
	assert_eq(player.cast_aim(), Vector2(-1, 0), "a held left stick comes first, as raw_aim() reads today")

func test_the_right_stick_never_reaches_spread_or_the_rope_reel() -> void:
	_right(0.0, 1.0)  # straight down, the puddle gesture, on the wrong stick
	assert_eq(player.raw_aim(), Vector2.ZERO)
	assert_false(Player.wants_spread(true, player.aim_vector(), player.raw_aim().y, false))

# --- the mouse ---

func test_the_cursor_is_ignored_until_the_mouse_moves() -> void:
	player.pointer_override = Vector2(100, 0)
	assert_eq(player.free_aim(), Vector2.ZERO)

func test_the_cursor_thirty_degrees_up_is_that_exact_direction() -> void:
	var v := Vector2.from_angle(deg_to_rad(-30.0))
	_mouse_at(v * 100.0)
	assert_true(player.free_aim().is_equal_approx(v))

func test_the_cursor_snaps_to_horizontal_within_ten_degrees() -> void:
	_mouse_at(Vector2.from_angle(deg_to_rad(5.0)) * 100.0)
	assert_eq(player.free_aim(), Vector2(1, 0))

func test_a_cursor_on_the_body_falls_back_to_the_keys() -> void:
	_mouse_at(Vector2(5, 5))  # 7 px from the origin, under the 12 px deadzone
	assert_eq(player.free_aim(), Vector2.ZERO)
	Input.action_press("aim_up")
	assert_eq(player.cast_aim(), Vector2(0, -1))

func test_a_pad_push_after_the_mouse_hands_the_aim_to_the_stick() -> void:
	_mouse_at(Vector2(0, -100))
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	assert_eq(player.free_aim(), Vector2(1, 0))
	assert_eq(player.mouse_direction(), Vector2.ZERO, "the two pointers never both apply")

func test_the_cursor_beats_a_stale_left_stick_and_a_key_held_before_the_mouse_moved() -> void:
	Input.action_press("aim_down")  # held first: action_press sends no event, so nothing hands the aim to the key
	Controls.last_stick = Vector2(0, -1)  # a stick held before the mouse moved sends no further events
	_mouse_at(Vector2(100, 0))
	assert_eq(player.cast_aim(), Vector2(1, 0))
	assert_eq(player.raw_aim(), Vector2(0, -1), "raw_aim is unchanged: spread and the reel still read the stick and keys")

func test_the_cursor_never_reaches_spread_or_the_rope_reel() -> void:
	_mouse_at(Vector2(0, 100))  # straight down, the puddle gesture, on the mouse
	assert_eq(player.raw_aim(), Vector2.ZERO)
	assert_false(Player.wants_spread(true, player.aim_vector(), player.raw_aim().y, false))

# --- can_cast ---

func test_can_cast_in_each_state() -> void:
	assert_true(player.can_cast())
	player._channel = autofree(Ability.new())
	assert_false(player.can_cast(), "a live channel")
	player._channel = null
	player._begin_evolve_moment(FormLoader.load_all()["tide"])
	assert_false(player.can_cast(), "the evolve moment")

func test_can_cast_is_false_when_dead() -> void:
	player.health.take_hit(player.health.hp, "physical")  # setting hp does not set the dead flag
	assert_false(player.can_cast())

func _start_eating() -> void:
	var target := Enemy.new()
	target.setup(DefLoader.load_dir("res://data/creatures").filter(func(c): return c.id == "bat")[0], {})
	add_child_autofree(target)
	target.global_position = player.global_position + Vector2(10, 0)
	target.set_physics_process(false)
	target.receive_tackle(1, false)
	player.begin_predate()

func test_can_cast_is_false_while_eating() -> void:
	_start_eating()
	assert_true(player.predation.active())
	assert_false(player.can_cast())

func test_use_active_does_nothing_when_dead_eating_or_channelling() -> void:
	_hydraulic()
	player.health.take_hit(player.health.hp, "physical")
	player.use_active(0)
	assert_true(player.last_cast.is_empty(), "dead")
	assert_eq(player.mana.mp, 20)

func test_use_active_does_nothing_while_eating() -> void:
	_hydraulic()
	_start_eating()
	player.use_active(0)
	assert_true(player.last_cast.is_empty())
	assert_eq(player.mana.mp, 20)

func test_use_active_does_nothing_with_a_live_channel() -> void:
	_hydraulic()
	player._channel = autofree(Ability.new())
	player.use_active(0)
	assert_true(player.last_cast.is_empty())
	assert_eq(player.mana.mp, 20)

# --- the two flat-aim sites, and casts ---

func test_hydraulic_keeps_its_lift_when_the_right_stick_is_a_few_degrees_off_horizontal() -> void:
	_hydraulic()
	var v := Vector2.from_angle(deg_to_rad(-3.0))
	_right(v.x, v.y)
	player.use_active(0)
	assert_eq(player.velocity.y, load("res://scripts/abilities/hydraulic_propulsion.gd").HORIZONTAL_LIFT)

func test_hydraulic_keeps_its_lift_when_the_cursor_is_a_few_degrees_off_horizontal() -> void:
	_hydraulic()
	_mouse_at(Vector2.from_angle(deg_to_rad(-3.0)) * 100.0)
	player.use_active(0)
	assert_eq(player.velocity.y, load("res://scripts/abilities/hydraulic_propulsion.gd").HORIZONTAL_LIFT)

func test_a_jet_dash_mid_jump_keeps_its_rise_with_the_right_stick_a_few_degrees_below_horizontal() -> void:
	_hydraulic()
	_swap_in("jet_dash", [100])
	player.velocity = Vector2(0, -330)
	var v := Vector2.from_angle(deg_to_rad(3.0))
	_right(v.x, v.y)
	player.use_active(0)
	assert_eq(player.velocity.y, -330.0)

func test_a_jet_dash_mid_jump_keeps_its_rise_with_the_cursor_a_few_degrees_below_horizontal() -> void:
	_hydraulic()
	_swap_in("jet_dash", [100])
	player.velocity = Vector2(0, -330)
	_mouse_at(Vector2.from_angle(deg_to_rad(3.0)) * 100.0)
	player.use_active(0)
	assert_eq(player.velocity.y, -330.0)

func test_the_pointer_moving_during_a_live_hydraulic_hold_does_not_change_its_direction() -> void:
	_hydraulic()
	_right(1.0, 0.0)
	Input.action_press("active_1")
	await wait_physics_frames(3)
	var hydro = player._abilities["hydraulic_propulsion"]
	assert_not_null(player._channel)
	var latched: Vector2 = hydro._dir
	assert_eq(latched, Vector2(1, 0))
	_right(-1.0, 0.0)
	await wait_physics_frames(3)
	assert_eq(hydro._dir, latched)
	Input.action_release("active_1")

func test_a_mouse_click_starts_a_channel_and_its_release_ends_it() -> void:
	_hydraulic()
	PadInput.mouse_button(MOUSE_BUTTON_LEFT)
	await wait_physics_frames(3)
	assert_not_null(player._channel)
	PadInput.mouse_button(MOUSE_BUTTON_LEFT, false)
	await wait_physics_frames(3)
	assert_null(player._channel)

func _slash() -> Sprite2D:
	return get_tree().get_nodes_in_group("vfx").filter(func(n): return n is Sprite2D and n.texture == VfxArt.water_slash())[0]

func test_a_water_blade_cast_with_the_right_stick_at_thirty_degrees_turns_the_slash_to_it() -> void:
	_hydraulic()
	_swap_in("water_blade", [3])
	var v := Vector2.from_angle(deg_to_rad(-30.0))
	_right(v.x, v.y)
	player.use_active(0)
	assert_true(player.last_cast["aim"].is_equal_approx(v))
	assert_almost_eq(_slash().rotation, deg_to_rad(-30.0), 0.01)

func test_a_water_blade_cast_at_the_cursor_turns_the_slash_to_it() -> void:
	_hydraulic()
	_swap_in("water_blade", [3])
	var v := Vector2.from_angle(deg_to_rad(-30.0))
	_mouse_at(v * 100.0)
	player.use_active(0)
	assert_true(player.last_cast["aim"].is_equal_approx(v))
	assert_almost_eq(_slash().rotation, deg_to_rad(-30.0), 0.01)
