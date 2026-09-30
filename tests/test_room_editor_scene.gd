extends GutTest
## The room editor: the view (the game's own builder through a camera), the tools, the panels and the assembled scene.

var model: RoomEditModel
var view: RoomView

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)
	view = RoomView.new()
	add_child_autofree(view)
	view.show_room(model, "C1")
	await wait_process_frames(2)

# --- the view ---

func test_the_view_builds_the_room_the_way_the_game_does() -> void:
	var built := view.room_node()
	assert_not_null(built)
	assert_eq(built.name, "C1")
	assert_eq(built.position, Vector2.ZERO, "the room sits at the origin, not its world position")
	assert_eq(get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy).size(), 0, "no live enemies")

func test_no_control_in_the_built_room_swallows_the_mouse() -> void:
	var stoppers := []
	var stack: Array = [view.room_node()]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			stoppers.append(n.get_path())
		stack.append_array(n.get_children())
	assert_eq(stoppers, [], "clicks must reach the tools")

func test_the_gates_of_closed_shortcuts_draw_closed() -> void:
	var shortcuts: Array = model.rooms["C1"].exits.filter(func(e): return e.has("shortcut"))
	assert_gt(shortcuts.size(), 0)
	assert_eq(get_tree().get_nodes_in_group("gate_%s" % shortcuts[0]["shortcut"]).size(), 1)

func test_screen_and_room_points_map_both_ways() -> void:
	for p in [Vector2(10, 10), Vector2(320, 180), Vector2(600, 300)]:
		var screen := view.to_screen(p)
		assert_almost_eq(view.to_room(screen), p, Vector2(0.01, 0.01))

func test_fit_shows_the_whole_room_and_one_to_one_is_a_zoom_of_one() -> void:
	view.fit()
	var size: Vector2 = model.rooms["C1"].pixel_size()
	var tl := view.to_screen(Vector2.ZERO)
	var br := view.to_screen(size)
	assert_true(Rect2(Vector2.ZERO, Vector2(640, 360)).encloses(Rect2(tl, br - tl)), "the whole room is on screen")
	view.one_to_one()
	assert_almost_eq(view.to_screen(Vector2(100, 0)).x - view.to_screen(Vector2.ZERO).x, 100.0, 0.01)

func test_pan_moves_the_view_by_screen_pixels() -> void:
	var before := view.to_screen(Vector2(100, 100))
	view.pan(Vector2(30, -20))
	assert_almost_eq(view.to_screen(Vector2(100, 100)) - before, Vector2(30, -20), Vector2(0.01, 0.01))

func test_the_pick_radius_is_eight_screen_pixels() -> void:
	view.one_to_one()
	assert_almost_eq(view.pick_radius(), 8.0, 0.01)
	view.zoom_by(2.0, Vector2(320, 180))
	assert_almost_eq(view.pick_radius(), 4.0, 0.01)

func test_zoom_keeps_the_point_under_the_pointer_fixed() -> void:
	var p := Vector2(400, 120)
	var before := view.to_screen(p)
	view.zoom_by(1.5, before)
	assert_almost_eq(view.to_screen(p), before, Vector2(0.01, 0.01))

func test_state_round_trips() -> void:
	view.zoom_by(2.0, Vector2(320, 180))
	var s := view.state()
	var other := RoomView.new()
	add_child_autofree(other)
	other.show_room(model, "C1")
	other.restore(s)
	assert_almost_eq(other.to_screen(Vector2(200, 200)), view.to_screen(Vector2(200, 200)), Vector2(0.01, 0.01))

# --- tools and input (events are handed to the view with positions from view.to_screen) ---

func _press(p: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = view.to_screen(p)
	return e

func _release(p: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := _press(p, button)
	e.pressed = false
	return e

func _motion(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = view.to_screen(p)
	return e

func test_the_solid_tool_drags_a_rect_with_a_live_label_and_writes_it_on_release() -> void:
	view.tool = "solid"
	var built := view.room_node()
	view.handle_event(_press(Vector2(100, 100)))
	view.handle_event(_motion(Vector2(180, 116)))
	assert_eq(view.live_label(), "one-way ledge")
	view.handle_event(_motion(Vector2(180, 160)))
	assert_eq(view.live_label(), "rock")
	assert_eq(model.undo_depth(), 0, "nothing is written until release")
	view.handle_event(_release(Vector2(180, 160)))
	assert_true(model.rooms["C1"].solids.has(Rect2(100, 100, 80, 60)))
	assert_eq(model.undo_depth(), 1)
	await wait_process_frames(2)
	assert_ne(view.room_node(), built, "the room was rebuilt")
	assert_eq(view.live_label(), "")

func test_the_creature_tool_places_a_marker_and_refuses_rock_with_a_message() -> void:
	view.tool = "creature"
	view.creature_id = "toad"
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	var solid: Rect2 = model.rooms["C1"].solids[0]
	view.handle_event(_press(solid.get_center()))
	view.handle_event(_release(solid.get_center()))
	assert_eq(messages.size(), 1)
	assert_eq(model.undo_depth(), 0)
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	assert_eq(model.rooms["C1"].spawns.back()["id"], "toad")

func test_the_creature_tool_without_a_choice_says_so() -> void:
	view.tool = "creature"
	view.creature_id = ""
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	assert_eq(messages.size(), 1)
	assert_eq(model.undo_depth(), 0)

func test_select_picks_drags_and_deletes_with_the_keyboard() -> void:
	view.tool = "select"
	model.rooms["C1"].solids = [Rect2(100, 200, 60, 20)]
	view.handle_event(_press(Vector2(120, 210)))
	view.handle_event(_motion(Vector2(160, 210)))
	view.handle_event(_release(Vector2(160, 210)))
	assert_eq(model.rooms["C1"].solids[0], Rect2(140, 200, 60, 20))
	assert_eq(model.undo_depth(), 1)
	var del := InputEventKey.new()
	del.keycode = KEY_DELETE
	del.pressed = true
	view.handle_event(del)
	assert_eq(model.rooms["C1"].solids.size(), 0)

func test_a_click_on_nothing_clears_the_selection_and_pushes_nothing() -> void:
	view.tool = "select"
	model.select({"room": "C1", "kind": "solid", "index": 0})
	view.handle_event(_press(Vector2(5, 5)))
	view.handle_event(_release(Vector2(5, 5)))
	assert_eq(model.selection, {})
	assert_eq(model.undo_depth(), 0)

func test_a_click_on_a_solid_without_moving_pushes_nothing() -> void:
	view.tool = "select"
	var s: Rect2 = model.rooms["C1"].solids[0]
	view.handle_event(_press(s.get_center()))
	view.handle_event(_release(s.get_center()))
	assert_eq(model.selection["kind"], "solid")
	assert_eq(model.undo_depth(), 0)

func test_the_exit_tool_drags_along_the_nearest_edge_and_writes_the_pair() -> void:
	var idx := -1
	for i in model.rooms["C1"].exits.size():
		if model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	var pair := model.partner_of("C1", idx)
	model.rooms["C2"].exits.remove_at(pair["index"])
	model.rooms["C1"].exits.remove_at(idx)
	view.tool = "exit"
	var w: float = model.rooms["C1"].pixel_size().x
	view.handle_event(_press(Vector2(w - 3.0, 200)))
	view.handle_event(_motion(Vector2(w - 3.0, 320)))
	view.handle_event(_release(Vector2(w - 3.0, 320)))
	assert_eq(model.rooms["C1"].exits.filter(func(e): return e["room"] == "C2").size(), 1)
	assert_eq("\n".join(model.validate()), "")

func test_a_refused_exit_drag_sends_the_reason_and_changes_nothing() -> void:
	view.tool = "exit"
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	view.handle_event(_press(Vector2(3, 100)))  # C1's left edge has no room across it
	view.handle_event(_motion(Vector2(3, 220)))
	view.handle_event(_release(Vector2(3, 220)))
	assert_eq(messages.size(), 1)
	assert_eq(model.undo_depth(), 0)

func test_middle_drag_pans_and_the_wheel_with_control_zooms() -> void:
	var before := view.to_screen(Vector2(100, 100))
	view.handle_event(_press(Vector2(200, 200), MOUSE_BUTTON_MIDDLE))
	var m := _motion(Vector2(200, 200))
	m.relative = Vector2(20, 10)
	m.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	view.handle_event(m)
	assert_almost_eq(view.to_screen(Vector2(100, 100)) - before, Vector2(20, 10), Vector2(0.5, 0.5))
	view.handle_event(_release(Vector2(200, 200), MOUSE_BUTTON_MIDDLE))
	var zoom_before := view.camera.zoom.x
	var wheel := _press(Vector2(200, 200), MOUSE_BUTTON_WHEEL_UP)
	wheel.ctrl_pressed = true
	view.handle_event(wheel)
	assert_gt(view.camera.zoom.x, zoom_before)

func test_creature_markers_are_static_and_an_unknown_id_is_red() -> void:
	model.rooms["C1"].spawns.append({"id": "gorgon", "pos": Vector2(300, 100)})
	view.show_room(model, "C1")
	await wait_process_frames(1)
	var markers := view.markers()
	assert_eq(markers.size(), model.rooms["C1"].spawns.size(), "one marker per creature")
	assert_eq(get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy).size(), 0, "never a live Enemy")
	assert_true(markers.any(func(m): return m.get_meta("unknown", false)), "the unknown id is marked")
	assert_eq(markers.filter(func(m): return m.get_meta("unknown", false)).size(), 1)
	assert_true(markers.any(func(m): return m.get_node_or_null("Sprite") != null), "a known creature is its sprite")

# --- panels ---

func _panels() -> EditorPanels:
	var p := EditorPanels.new()
	add_child_autofree(p)
	p.setup(model)
	await wait_process_frames(1)
	return p

func test_the_panels_list_rooms_creatures_and_mark_dirty_rooms() -> void:
	var p := await _panels()
	model.dirty["C2"] = true
	p.set_rooms(model.rooms.keys(), model.dirty)
	assert_true(p.room_labels().has("C2 *"))
	assert_true(p.room_labels().has("C1"))
	assert_eq(p.palette_ids(), model.creature_ids)

func test_choosing_a_room_or_a_creature_emits_the_id() -> void:
	var p := await _panels()
	watch_signals(p)
	p.set_rooms(["C1", "C2"], {})
	p.choose_room("C2")
	assert_signal_emitted_with_parameters(p, "room_chosen", ["C2"])
	p.choose_creature("toad")
	assert_signal_emitted_with_parameters(p, "creature_chosen", ["toad"])

func test_pressing_the_buttons_emits_the_signals() -> void:
	var p := await _panels()
	watch_signals(p)
	for label in ["Undo", "Redo", "Fit room", "1:1", "Validate", "Save", "Play"]:
		p.press(label)
	for s in ["undo_pressed", "redo_pressed", "fit_pressed", "one_to_one_pressed", "validate_pressed", "save_pressed", "play_pressed"]:
		assert_signal_emitted(p, s)
	p.press("Solid")
	assert_signal_emitted_with_parameters(p, "tool_chosen", ["solid"])

func test_the_palette_shows_only_for_the_creature_tool() -> void:
	var p := await _panels()
	p.set_tool("select")
	assert_false(p.palette_visible())
	p.press("Creature")
	assert_true(p.palette_visible())

func test_the_validate_list_shows_the_validators_errors_and_says_so_when_clean() -> void:
	var p := await _panels()
	model.rooms["C1"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	p.show_validation(model.validate())
	assert_true(p.validation_lines().any(func(l): return l.contains("unknown room 'Z'")))
	p.show_validation(PackedStringArray())
	assert_eq(p.validation_lines(), ["No problems found."])

func test_the_new_room_dialog_refuses_a_taken_id_and_emits_a_valid_request() -> void:
	var p := await _panels()
	watch_signals(p)
	p.open_new_room("right")
	p.set_new_room_fields("c1", "cave", Vector2i(1, 1))
	assert_ne(p.new_room_error(), "", "c1 collides with C1")
	p.confirm_new_room()
	assert_signal_not_emitted(p, "new_room_requested")
	p.set_new_room_fields("Fresh", "cave", Vector2i(2, 1))
	assert_eq(p.new_room_error(), "")
	p.confirm_new_room()
	assert_signal_emitted_with_parameters(p, "new_room_requested", ["right", "Fresh", "cave", Vector2i(2, 1)])
	assert_false(p.new_room_visible(), "the dialog closes")

func test_the_new_room_dialog_warns_about_holes_on_a_vertical_edge() -> void:
	var p := await _panels()
	p.open_new_room("bottom")
	assert_string_contains(p.new_room_note(), "hole")
	p.open_new_room("right")
	assert_false(p.new_room_note().contains("hole"))

func test_the_status_bar_shows_the_sandbox_directory_and_the_message() -> void:
	var p := await _panels()
	p.set_status("saved 2 rooms")
	assert_string_contains(p.status_text(), "saved 2 rooms")
	assert_string_contains(p.status_text(), OS.get_user_data_dir())

# --- the assembled scene ---

## GUT's own on-screen runner (a Control that stops the mouse) covers the whole 640x360 viewport; events pushed through the
## viewport would land on it. The editor tests hide it and put it back.
func _gut_ui(visible: bool) -> void:
	var layer := get_tree().root.get_node_or_null("GutRunner/GutLayer")
	if layer != null:
		layer.visible = visible

func after_each() -> void:
	_gut_ui(true)
	Game.play_request = {}
	Game.editor_resume = null
	RoomEditor.sandbox_root = ""

func _editor() -> RoomEditor:
	_gut_ui(false)
	Game.editor_resume = null
	var ed: RoomEditor = load("res://scenes/room_editor.tscn").instantiate()
	add_child_autofree(ed)
	await wait_process_frames(3)
	return ed

func _button_at(screen: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = screen
	return e

func _motion_at(screen: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = screen
	return e

func after_all() -> void:
	RoomEditor.sandbox_root = ""

func test_the_scene_boots_on_c1_with_a_view_and_panels_and_draws_a_solid_from_events() -> void:
	var ed := await _editor()
	assert_eq(ed.room_id, "C1")
	assert_not_null(ed.view)
	assert_not_null(ed.panels)
	ed.panels.press("Solid")
	var a := ed.view.to_screen(Vector2(100, 100))
	var b := ed.view.to_screen(Vector2(200, 116))
	for ev in [_button_at(a, true), _motion_at(b), _button_at(b, false)]:
		get_viewport().push_input(ev, true)  # true: the positions are already viewport (640x360) coordinates
	await wait_process_frames(2)
	assert_true(ed.model.rooms["C1"].solids.has(Rect2(100, 100, 100, 16)), "the drag reached the model through the viewport")
	assert_eq(ed.view.room_node().name, "C1")
	assert_true(ed.panels.room_labels().has("C1 *"), "the dirty mark shows")

func test_a_toolbar_click_does_not_reach_the_room() -> void:
	var ed := await _editor()
	ed.panels.press("Solid")
	for ev in [_button_at(Vector2(300, 10), true), _motion_at(Vector2(320, 12)), _button_at(Vector2(320, 12), false)]:
		get_viewport().push_input(ev, true)
	await wait_process_frames(2)
	assert_eq(ed.model.undo_depth(), 0, "a click on the bar is not a drag in the room")

func test_the_keyboard_shortcuts_undo_and_redo_and_typing_an_id_does_not_undo() -> void:
	var ed := await _editor()
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	var z := InputEventKey.new()
	z.keycode = KEY_Z
	z.pressed = true
	z.ctrl_pressed = true
	get_viewport().push_input(z)
	await wait_process_frames(1)
	assert_eq(ed.model.undo_depth(), 0, "ctrl+z undoes")
	var redo := InputEventKey.new()
	redo.keycode = KEY_Z
	redo.pressed = true
	redo.ctrl_pressed = true
	redo.shift_pressed = true
	get_viewport().push_input(redo)
	await wait_process_frames(1)
	assert_eq(ed.model.undo_depth(), 1, "ctrl+shift+z redoes")
	ed.panels.focus_new_room_id()
	await wait_process_frames(1)
	var typed := InputEventKey.new()
	typed.keycode = KEY_Z
	typed.pressed = true
	typed.ctrl_pressed = true
	get_viewport().push_input(typed)
	await wait_process_frames(1)
	assert_eq(ed.model.undo_depth(), 1, "typing in the id field does not undo")

func test_play_refuses_in_rock_outside_the_sandbox_and_with_an_exit_to_a_missing_room() -> void:
	var ed := await _editor()
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	var solid: Rect2 = ed.model.rooms["C1"].solids[0]
	assert_string_contains(ed.play_error(solid.get_center()), "click open floor")
	assert_eq(ed.play_error(Vector2(300, 100)), "")
	RoomEditor.sandbox_root = "/nowhere/.tmp/editor-home"
	assert_string_contains(ed.play_error(Vector2(300, 100)), "tools/edit_rooms.sh")
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	ed.model.rooms["C1"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	assert_string_contains(ed.play_error(Vector2(300, 100)), "unknown room")

func test_a_refused_play_says_why_in_the_status_bar_and_does_not_leave_the_scene() -> void:
	var ed := await _editor()
	RoomEditor.sandbox_root = "/nowhere/.tmp/editor-home"
	ed.play(Vector2(300, 100))
	assert_string_contains(ed.panels.status_text(), "tools/edit_rooms.sh")
	assert_eq(Game.play_request, {})
	assert_null(Game.editor_resume)

func test_save_writes_the_edited_rooms_to_the_directory_it_is_given() -> void:
	var ed := await _editor()
	ed.save_dir = "res://.tmp/editor_scene_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ed.save_dir))
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	ed.save()
	assert_true(FileAccess.file_exists("%s/C1.tres" % ed.save_dir))
	assert_string_contains(ed.panels.status_text(), "saved 1 room")
	assert_false(ed.panels.room_labels().has("C1 *"), "saved rooms lose their dirty mark")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/C1.tres" % ed.save_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ed.save_dir))

func test_choosing_a_room_switches_the_view_and_a_new_room_opens() -> void:
	var ed := await _editor()
	ed.open_room("C2")
	assert_eq(ed.view.room_id(), "C2")
	ed.open_room("C6")
	ed.new_room("left", "Fresh", "cave", Vector2i(1, 1))
	assert_eq(ed.room_id, "Fresh")
	assert_eq(ed.view.room_id(), "Fresh")
	assert_true(ed.model.rooms.has("Fresh"))
	assert_true(ed.panels.room_labels().has("Fresh *"))
	ed.new_room("left", "c6", "cave", Vector2i(1, 1))
	assert_ne(ed.panels.status_text().find("already"), -1, "a bad id is explained")

func test_undo_from_the_button_rebuilds_the_room() -> void:
	var ed := await _editor()
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	ed.view.refresh()
	var before := ed.view.room_node()
	ed.panels.press("Undo")
	await wait_process_frames(2)
	assert_eq(ed.model.undo_depth(), 0)
	assert_ne(ed.view.room_node(), before)
