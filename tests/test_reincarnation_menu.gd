extends GutTest
## The menu renders RebirthChoice's decision, moves, confirms only unlocked entries, and sits above the death card.

class Mortal extends Node:
	signal died

func _decision() -> Dictionary:
	return {"options": [{"id": "C1", "name": "Cave mouth", "locked": false},
		{"id": "G1", "name": "Grotto rebirth pool", "locked": false},
		{"id": "F1", "name": "???", "locked": true}], "selected": 1}

func _menu() -> ReincarnationMenu:
	var m := ReincarnationMenu.new()
	add_child_autofree(m)
	return m

func test_it_does_nothing_until_a_decision_is_pending() -> void:
	var m := _menu()
	assert_false(m.is_open())
	assert_false(m.confirm())
	m.move(1)
	assert_eq(m.selected(), 0)

func test_it_renders_in_order_with_the_last_choice_selected_and_locked_pools_as_question_marks() -> void:
	var m := _menu()
	m.show_decision(_decision())
	assert_true(m.is_open())
	assert_eq(m.labels(), ["Cave mouth", "Grotto rebirth pool", "???"])
	assert_eq(m.selected(), 1)

func test_up_and_down_move_and_clamp() -> void:
	var m := _menu()
	m.show_decision(_decision())
	m.move(-1)
	assert_eq(m.selected(), 0)
	m.move(-1)
	assert_eq(m.selected(), 0, "clamped at the top")
	m.move(1)
	m.move(1)
	m.move(1)
	assert_eq(m.selected(), 2, "clamped at the bottom")

func test_a_locked_entry_cannot_be_confirmed_and_an_unlocked_one_calls_choose() -> void:
	var chosen: Array = []
	var m := _menu()
	m.choose_callback = func(id: String) -> void: chosen.append(id)
	m.show_decision(_decision())
	m.move(1)
	assert_eq(m.selected(), 2)
	assert_false(m.confirm())
	assert_eq(chosen, [])
	m.move(-1)
	assert_true(m.confirm())
	assert_eq(chosen, ["G1"])
	assert_false(m.is_open(), "it closes once a choice is made")

func test_it_sits_above_the_death_card() -> void:
	var run := Run.new()
	add_child_autofree(run)
	var m := _menu()
	assert_gt(m.layer, run._card.layer)

func test_dying_with_two_pools_opens_the_menu_and_confirming_restarts_at_the_choice() -> void:
	var progress := WorldProgress.new()
	progress.attune("G1")
	var pools := [{"id": "C1", "area": "cave", "room": "C1", "pos": Vector2(140, 320), "kit": {}, "name": "Cave mouth"},
		{"id": "G1", "area": "grotto", "room": "G1", "pos": Vector2(560, 320), "kit": {}, "name": "Grotto rebirth pool"}]
	var run := Run.new()
	add_child_autofree(run)
	var body: Mortal = autofree(Mortal.new())
	var world := World.new()
	add_child_autofree(world)
	run.bind(body, world, progress, pools)
	var menu := _menu()
	menu.bind(run)
	var restarts := [0]
	run.restart_requested.connect(func() -> void: restarts[0] += 1)
	body.died.emit()
	await wait_seconds(Run.DEATH_CARD_SECONDS + 0.3)
	assert_true(menu.is_open(), "the decision is on screen")
	assert_eq(restarts[0], 0, "and the run waits for it: a bound menu means no auto-pick")
	assert_eq(menu.labels(), ["Cave mouth", "Grotto rebirth pool"])
	menu.move(1)
	assert_true(menu.confirm())
	assert_eq(restarts[0], 1)
	assert_eq(progress.pending_start["pool"], "G1")

func _pad_button(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e

func test_a_gamepad_can_move_and_confirm() -> void:
	Controls.ensure_actions()
	var chosen: Array = []
	var m := _menu()
	m.choose_callback = func(id: String) -> void: chosen.append(id)
	m.show_decision(_decision())
	m._unhandled_input(_pad_button(JOY_BUTTON_DPAD_UP))
	assert_eq(m.selected(), 0, "the D-pad moves it")
	m._unhandled_input(_pad_button(JOY_BUTTON_DPAD_DOWN))
	assert_eq(m.selected(), 1)
	m._unhandled_input(_pad_button(JOY_BUTTON_A))
	assert_eq(chosen, ["G1"], "A confirms")

func test_the_keyboard_still_moves_and_confirms() -> void:
	Controls.ensure_actions()
	var chosen: Array = []
	var m := _menu()
	m.choose_callback = func(id: String) -> void: chosen.append(id)
	m.show_decision(_decision())
	var down := InputEventKey.new()
	down.physical_keycode = KEY_S
	down.pressed = true
	m._unhandled_input(down)
	assert_eq(m.selected(), 2)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	up.pressed = true
	m._unhandled_input(up)
	assert_eq(m.selected(), 1)
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	m._unhandled_input(enter)
	assert_eq(chosen, ["G1"])
