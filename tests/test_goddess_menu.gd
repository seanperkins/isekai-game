extends GutTest
## The goddess's menu draws her line and three panels, drives the model from keys and the stick, and emits the confirmed result.

const P := GoddessModel.Pane

var menu: GoddessMenu
var confirmed: Array
var saved_pad: Array

func before_each() -> void:
	saved_pad = [Controls.last_stick, Controls.using_joypad, Controls.last_device, Controls.last_pad_name]
	menu = GoddessMenu.new()
	add_child_autofree(menu)
	confirmed = []
	menu.confirmed.connect(func(result: Dictionary) -> void: confirmed.append(result))

func after_each() -> void:
	Controls.last_stick = saved_pad[0]
	Controls.using_joypad = saved_pad[1]
	Controls.last_device = saved_pad[2]
	Controls.last_pad_name = saved_pad[3]

func _model(points := 12, place_count := 2) -> GoddessModel:
	var places: Array = [{"id": "C1", "name": "Cave mouth"}, {"id": "G1", "name": "Grotto"}, {"id": "F1", "name": "Flooded"}].slice(0, place_count)
	var soul := SoulProgress.new()
	soul.points = points
	return GoddessModel.new(places, [{"id": "slime", "name": "Slime"}], [{"id": "leap", "name": "Leap"}], soul, SoulRules.new())

func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code  # Controls binds the physical key
	ev.pressed = true
	menu._unhandled_input(ev)

func _stick_event(y: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_Y
	ev.axis_value = y
	return ev

func test_it_does_nothing_until_opened() -> void:
	assert_false(menu.is_open())
	assert_false(menu.visible)
	assert_false(menu.confirm())
	menu.move(1)
	menu.adjust(1)
	_press(KEY_DOWN)
	assert_true(confirmed.is_empty())

func test_open_shows_her_line_and_the_panels() -> void:
	menu.open(_model(), "A bat. Of all the things.")
	assert_true(menu.is_open())
	assert_true(menu.visible)
	assert_eq(menu.line_text(), "A bat. Of all the things.")
	assert_eq(menu.panel_rows(P.WHERE), ["> Cave mouth", "  Grotto"])
	assert_eq(menu.panel_rows(P.WHO), ["> Slime"])
	assert_eq(menu.panel_rows(P.HEAD_START), ["> Level +0  next 2", "  [ ] Leap  3"])
	assert_eq([menu.header(P.WHERE), menu.header(P.WHO), menu.header(P.HEAD_START)], ["[WHERE]", "WHO", "HEAD START"])
	assert_eq(menu.footer_text(), "Soul points 12    Cost 0    Enter: be reborn")

func test_keys_drive_the_model() -> void:
	menu.open(_model(), "line")
	_press(KEY_DOWN)
	assert_eq(menu.panel_rows(P.WHERE), ["  Cave mouth", "> Grotto"])
	_press(KEY_Q)
	assert_eq(menu.header(P.HEAD_START), "[HEAD START]", "Q wraps back from Where to Head start")
	_press(KEY_RIGHT)
	assert_eq(menu.panel_rows(P.HEAD_START)[0], "> Level +1  next 3")
	assert_eq(menu.footer_text(), "Soul points 12    Cost 2    Enter: be reborn")
	_press(KEY_LEFT)
	assert_eq(menu.panel_rows(P.HEAD_START)[0], "> Level +0  next 2")
	_press(KEY_E)
	assert_eq(menu.header(P.WHERE), "[WHERE]", "E moves on from Head start to Where")

func test_a_power_row_shows_what_is_taken() -> void:
	menu.open(_model(), "line")
	_press(KEY_Q)
	_press(KEY_DOWN)
	_press(KEY_RIGHT)
	assert_eq(menu.panel_rows(P.HEAD_START), ["  Level +0  next 2", "> [x] Leap  3"])

func test_a_purchase_beyond_the_points_is_refused() -> void:
	menu.open(_model(4), "line")
	_press(KEY_Q)
	for i in 3:
		_press(KEY_RIGHT)
	assert_false(menu.confirm())
	assert_true(menu.is_open(), "the menu stays open")
	assert_eq(menu.footer_text(), "Soul points 4    Cost 9    Not enough soul points")
	assert_true(confirmed.is_empty())

func test_confirm_closes_and_emits_the_result() -> void:
	menu.open(_model(), "line")
	assert_true(menu.confirm())
	assert_false(menu.is_open())
	assert_false(menu.visible)
	assert_eq(confirmed, [{"altar": "C1", "species": "slime", "kit": {}, "cost": 0}])

func test_enter_confirms() -> void:
	menu.open(_model(), "line")
	_press(KEY_ENTER)
	assert_eq(confirmed.size(), 1)

func test_the_stick_steps_once_per_push() -> void:
	menu.open(_model(12, 3), "line")
	Controls.last_stick = Vector2(0.0, 0.9)
	menu._process(0.016)
	assert_eq(menu.panel_rows(P.WHERE), ["  Cave mouth", "> Grotto", "  Flooded"])
	menu._process(0.016)
	assert_eq(menu.panel_rows(P.WHERE), ["  Cave mouth", "> Grotto", "  Flooded"], "a held push repeats only after the delay")
	Controls.last_stick = Vector2.ZERO
	menu._process(0.016)
	Controls.last_stick = Vector2(0.0, 0.9)
	menu._process(0.016)
	assert_eq(menu.panel_rows(P.WHERE), ["  Cave mouth", "  Grotto", "> Flooded"], "a fresh push steps again")

func test_a_long_head_start_list_scrolls_to_keep_the_selected_row_visible() -> void:
	var powers: Array = []
	for i in 18:
		powers.append({"id": "p%d" % i, "name": "Power %d" % i})
	var soul := SoulProgress.new()
	soul.points = 99
	var model := GoddessModel.new([{"id": "C1", "name": "Cave mouth"}], [{"id": "slime", "name": "Slime"}], powers, soul, SoulRules.new())
	menu.open(model, "line")
	_press(KEY_Q)  # to Head start: the level row and 18 powers, 19 rows
	assert_eq(menu.panel_rows(P.HEAD_START).size(), 19, "the model still holds every row")
	assert_eq(menu.shown_rows(P.HEAD_START).size(), GoddessMenu.MAX_ROWS, "a window of rows, not all 19")
	assert_true((menu.shown_rows(P.HEAD_START)[0] as String).begins_with("> "), "it starts at the top with the level row selected")
	for step in 19:
		var shown := menu.shown_rows(P.HEAD_START)
		assert_eq(shown.size(), GoddessMenu.MAX_ROWS)
		assert_eq(shown.filter(func(t: String) -> bool: return t.begins_with("> ")).size(), 1, "the selected row is on screen at step %d" % step)
		_press(KEY_DOWN)
	var last := menu.shown_rows(P.HEAD_START)
	assert_true((last[last.size() - 1] as String).contains("Power 17"), "the last power is the last row shown")
	assert_true((last[last.size() - 1] as String).begins_with("> "), "and it is the selected one")

func test_a_stick_push_navigates_through_process_and_the_event_alone_moves_nothing() -> void:
	menu.open(_model(12, 3), "line")
	Controls.last_stick = Vector2.ZERO
	menu._unhandled_input(_stick_event(0.9))
	assert_true(get_viewport().is_input_handled(), "the menu marks the motion handled so no later handler acts on it")
	assert_eq(menu.panel_rows(P.WHERE)[0], "> Cave mouth", "the event itself moves nothing")
	get_viewport().push_input(_stick_event(0.9))
	assert_almost_eq(Controls.last_stick.y, 0.9, 0.001, "Controls records the stick in its own _input, before the menu")
	menu._process(0.016)
	assert_eq(menu.panel_rows(P.WHERE)[1], "> Grotto", "the next _process moves one row")

func test_the_menu_works_over_a_paused_tree() -> void:
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	menu.open(_model(0, 1), "her first words")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	get_tree().paused = true  # the opening leaves the tree paused when it hands over
	get_viewport().push_input(ev)
	get_tree().paused = false
	assert_eq(confirmed.size(), 1, "Enter reached the menu through a paused tree")
