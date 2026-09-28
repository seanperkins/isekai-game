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
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water"})
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
	assert_eq(screen.nav_step(0.8, 0.016), 1)
	assert_eq(screen.nav_step(0.9, 0.016), 0)
	assert_eq(screen.nav_step(0.9, 0.2), 0)
	assert_eq(screen.nav_step(0.9, 0.2), 1)  # held past the delay: repeat
	assert_eq(screen.nav_step(0.9, 0.05), 0)
	assert_eq(screen.nav_step(0.9, 0.1), 1)
	assert_eq(screen.nav_step(0.1, 0.016), 0)  # released
	assert_eq(screen.nav_step(-0.7, 0.016), -1)
