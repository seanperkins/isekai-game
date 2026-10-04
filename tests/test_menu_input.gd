extends GutTest
## Menu controls: A/Enter accept, B backs out, the stick moves one row per push.

var rules: SkillRulesEngine
var player: Player
var screen: SkillScreen

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	screen = SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, skills)

func after_each() -> void:
	Controls.last_stick = Vector2.ZERO
	get_tree().paused = false

func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev

func test_menu_buttons_are_bound_for_keys_and_pad() -> void:
	var back := InputMap.action_get_events("menu_back")
	var accept := InputMap.action_get_events("menu_accept")
	assert_true(back.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B))
	assert_true(accept.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A))
	assert_true(accept.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_ENTER))

func test_b_closes_the_screen() -> void:
	screen.open()
	screen._unhandled_input(_pad(JOY_BUTTON_B))
	assert_false(screen.is_open())
	assert_false(get_tree().paused)

func test_stick_motion_events_do_not_move_the_selection() -> void:
	for i in 40:
		rules.handle_event("jumped", {})
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	screen.open()
	var before := screen.selected_id()
	screen.move(1)
	assert_ne(screen.selected_id(), before, "needs two rows to prove anything")
	screen.move(-1)
	for v in [0.6, 0.8, 1.0, 0.9]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXIS_LEFT_Y
		ev.axis_value = v
		screen._unhandled_input(ev)
	assert_eq(screen.selected_id(), before)

func test_one_stick_push_is_one_step_then_it_repeats_slowly() -> void:
	var down := Vector2(0.0, 0.9)
	assert_eq(screen.nav_step(Vector2(0.0, 0.8), 0.016), Vector2i.DOWN)
	assert_eq(screen.nav_step(down, 0.016), Vector2i.ZERO)
	assert_eq(screen.nav_step(down, 0.2), Vector2i.ZERO)
	assert_eq(screen.nav_step(down, 0.2), Vector2i.DOWN)  # held past the delay: repeat
	assert_eq(screen.nav_step(down, 0.05), Vector2i.ZERO)
	assert_eq(screen.nav_step(down, 0.1), Vector2i.DOWN)
	assert_eq(screen.nav_step(Vector2(0.0, 0.1), 0.016), Vector2i.ZERO)  # released
	assert_eq(screen.nav_step(Vector2(0.0, -0.7), 0.016), Vector2i.UP)

func test_the_step_is_the_dominant_axis_in_all_four_directions() -> void:
	var cases := {Vector2(0.9, 0.2): Vector2i.RIGHT, Vector2(-0.8, 0.3): Vector2i.LEFT,
		Vector2(0.1, -0.9): Vector2i.UP, Vector2(-0.2, 0.7): Vector2i.DOWN}
	for stick in cases:
		screen.nav_step(Vector2.ZERO, 0.016)  # release between pushes
		assert_eq(screen.nav_step(stick, 0.016), cases[stick], str(stick))
	screen.nav_step(Vector2.ZERO, 0.016)
	assert_eq(screen.nav_step(Vector2(0.3, 0.3), 0.016), Vector2i.ZERO, "inside the threshold on both axes")

func test_a_diagonal_push_still_moves_a_list_and_a_sideways_push_does_not() -> void:
	rules.grant("leap")  # with Appraisal: two selectable rows on the Skills tab
	screen.open()
	var first := screen.selected_id()
	Controls.last_stick = Vector2(0.9, 0.1)
	screen._process(0.016)
	assert_eq(screen.selected_id(), first, "the lists read only the vertical part")
	Controls.last_stick = Vector2.ZERO
	screen._process(0.016)
	Controls.last_stick = Vector2(0.8, 0.6)
	screen._process(0.016)
	assert_ne(screen.selected_id(), first, "a diagonal push moves the list down, as it did before")

func test_the_settings_action_has_a_key_and_a_stick_click() -> void:
	Controls.ensure_actions()
	var evs := InputMap.action_get_events("settings")
	assert_true(evs.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_TAB))
	assert_true(evs.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_RIGHT_STICK))
