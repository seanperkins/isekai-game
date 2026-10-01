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

func test_the_feature_tool_places_a_feature_on_the_surface_and_refuses_with_a_message() -> void:
	view.tool = "feature"
	view.feature_kind = "tablet"
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	var t: Dictionary = model.rooms["C1"].features.back()
	assert_eq(t["kind"], "tablet")
	assert_eq(model.undo_depth(), 1)
	var solid: Rect2 = model.rooms["C1"].solids[0]
	view.handle_event(_press(solid.get_center()))
	view.handle_event(_release(solid.get_center()))
	assert_eq(messages.size(), 1)
	assert_eq(model.undo_depth(), 1)

func test_a_placed_feature_has_a_marker_and_an_outline_when_selected() -> void:
	view.tool = "feature"
	view.feature_kind = "glow_pool"
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	await wait_process_frames(1)
	assert_gt(view.markers().filter(func(m): return m.has_meta("feature")).size(), 0)
	assert_gt(view.overlay.get_children().filter(func(n): return n is Line2D).size(), 0, "the selection outline is drawn")

func test_select_picks_a_feature_by_clicking_its_body_and_drags_it() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	view.show_room(model, "C1")
	view.tool = "select"
	var base: Vector2 = model.rooms["C1"].features.back()["pos"]
	view.handle_event(_press(base + Vector2(0, -10)))
	view.handle_event(_motion(base + Vector2(60, -10)))
	view.handle_event(_release(base + Vector2(60, -10)))
	assert_eq(model.rooms["C1"].features.back()["pos"].x, base.x + 60.0)

func test_a_press_releases_gui_focus_first() -> void:
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	assert_true(edit.has_focus())
	view.tool = "select"
	view.handle_event(_press(Vector2(5, 5)))
	assert_false(edit.has_focus(), "a click in the room commits and releases a pending field")

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
	var markers := view.markers().filter(func(m): return m.has_meta("index"))  # creature markers; features have their own
	assert_eq(markers.size(), model.rooms["C1"].spawns.size(), "one marker per creature")
	assert_eq(get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy).size(), 0, "never a live Enemy")
	assert_true(markers.any(func(m): return m.get_meta("unknown", false)), "the unknown id is marked")
	assert_eq(markers.filter(func(m): return m.get_meta("unknown", false)).size(), 1)
	assert_true(markers.any(func(m): return m.get_node_or_null("Sprite") != null), "a known creature is its sprite")

# --- the inspector and the right-hand slot ---

func _slot() -> EditorSlot:
	var s := EditorSlot.new()
	add_child_autofree(s)
	await wait_process_frames(1)
	return s

func test_the_inspector_edits_a_tablet_through_the_model() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	var slot := await _slot()
	slot.show_inspector(model, model.selection)
	assert_eq(slot.is_showing(), "inspector")
	var title: LineEdit = slot.find_field("title")
	title.text = "Moss"
	title.text_submitted.emit("Moss")
	assert_eq(model.rooms["C1"].features.back()["title"], "Moss")
	assert_eq(model.undo_depth(), 2, "placement then the edit")
	title.text_submitted.emit("Moss")
	title.focus_exited.emit()
	assert_eq(model.undo_depth(), 2, "Enter then focus loss is one step")

func test_a_pending_edit_goes_to_the_element_it_was_typed_for() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	model.add_feature("C1", "tablet", Vector2(400, 100))
	var first := {"room": "C1", "kind": "feature", "index": model.rooms["C1"].features.size() - 2}
	var slot := await _slot()
	slot.show_inspector(model, first)
	var title: LineEdit = slot.find_field("title")
	title.text = "First one"
	model.select({"room": "C1", "kind": "feature", "index": model.rooms["C1"].features.size() - 1})
	title.focus_exited.emit()
	assert_eq(model.rooms["C1"].features[first["index"]]["title"], "First one")

func test_a_refused_edit_shows_the_stored_value_and_reports_the_reason() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	var slot := await _slot()
	var errors := []
	slot.field_error.connect(func(t: String) -> void: errors.append(t))
	slot.show_inspector(model, model.selection)
	var title: LineEdit = slot.find_field("title")
	title.text = ""
	title.text_submitted.emit("")
	assert_eq(errors.size(), 1)
	assert_eq(title.text, "Tablet")

func test_a_pending_edit_for_an_element_that_is_gone_is_dropped_quietly() -> void:
	model.add_feature("C1", "tablet", Vector2(300, 100))
	var slot := await _slot()
	var errors := []
	slot.field_error.connect(func(t: String) -> void: errors.append(t))
	slot.show_inspector(model, model.selection)
	var title: LineEdit = slot.find_field("title")
	title.text = "Late"
	model.delete_selection()
	title.focus_exited.emit()
	assert_eq(errors, [])
	assert_eq(model.undo_depth(), 2, "the placement and the delete; the late edit did nothing")

func test_the_exit_inspector_sets_the_shortcut_on_both_halves() -> void:
	var idx := -1
	for i in model.rooms["C1"].exits.size():
		if model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	var slot := await _slot()
	slot.show_inspector(model, {"room": "C1", "kind": "exit", "index": idx})
	var line: LineEdit = slot.find_field("shortcut")
	line.text = "front_door"
	line.text_submitted.emit("front_door")
	assert_eq(model.rooms["C1"].exits[idx]["shortcut"], "front_door")
	assert_eq(model.undo_depth(), 1)

func test_the_pool_inspector_offers_level_and_the_kit_legal_skills() -> void:
	var sel := {"room": "G1", "kind": "feature", "index": model.rooms["G1"].features.find_custom(func(f): return f["kind"] == "rebirth_pool")}
	var slot := await _slot()
	slot.show_inspector(model, sel)
	var checks := slot.skill_checkboxes()
	var legal := RebirthKit.skill_defs().filter(func(d): return d.source != "enemy_only" and d.source != "evolution")
	assert_eq(checks.size(), legal.size(), "every skill a kit may name, none other")
	assert_eq(checks.size(), 18, "31 skills less 5 enemy-only and 8 evolution")
	var ids := checks.map(func(c): return c.get_meta("skill"))
	assert_false(ids.has("flight"))
	assert_true(slot.find_field("kit_level") is OptionButton)
	for c in checks:
		assert_eq(c.focus_mode, Control.FOCUS_NONE)

func test_ticking_a_skill_and_choosing_a_level_write_the_kit_and_keep_the_affinity() -> void:
	var idx: int = model.rooms["G1"].features.find_custom(func(f): return f["kind"] == "rebirth_pool")
	var sel := {"room": "G1", "kind": "feature", "index": idx}
	var affinity: Dictionary = model.rooms["G1"].features[idx]["kit"]["affinity"].duplicate()
	var had: Array = model.get_field(sel, "kit_skills")
	assert_false(had.is_empty(), "G1 ships skills in its kit")
	var slot := await _slot()
	slot.show_inspector(model, sel)
	for c in slot.skill_checkboxes():
		assert_eq(c.button_pressed, had.has(c.get_meta("skill")), "a box is ticked for each skill the kit holds")
	var extra: CheckBox = slot.skill_checkboxes().filter(func(c): return not had.has(c.get_meta("skill")))[0]
	extra.button_pressed = true
	var now: Array = model.get_field(sel, "kit_skills")
	assert_eq(now.size(), had.size() + 1)
	assert_true(now.has(extra.get_meta("skill")))
	for id in had:
		assert_true(now.has(id), "the skills it had are kept")
	var level: OptionButton = slot.find_field("kit_level")
	level.item_selected.emit(4)
	assert_eq(model.get_field(sel, "kit_level"), 4)
	assert_eq(model.rooms["G1"].features[idx]["kit"].get("affinity", {}), affinity)
	extra.button_pressed = false
	assert_eq(model.get_field(sel, "kit_skills").size(), had.size())

func test_the_problems_list_lands_on_the_problem() -> void:
	model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	model.serial += 1
	var slot := await _slot()
	var clicked := []
	slot.problem_clicked.connect(func(p: Dictionary) -> void: clicked.append(p))
	slot.show_problems(model.problems())
	assert_eq(slot.is_showing(), "problems")
	slot.click_problem(0)
	assert_eq(clicked[0]["room"], "C2")
	assert_eq(clicked[0]["pick"]["kind"], "spawn")

func test_the_slot_hides_and_reports_what_it_shows() -> void:
	var slot := await _slot()
	assert_eq(slot.is_showing(), "")
	model.add_feature("C1", "glow_pool", Vector2(300, 100))
	slot.show_inspector(model, model.selection)
	assert_eq(slot.is_showing(), "inspector")
	slot.hide_slot()
	assert_eq(slot.is_showing(), "")
	assert_false(slot.visible)

func test_typing_means_a_line_edit_or_spin_box_has_focus() -> void:
	var p := await _panels()
	assert_false(p.typing())
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	assert_true(p.typing())
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	add_child_autofree(box)
	edit.release_focus()
	assert_false(p.typing(), "a checkbox never counts")

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

func test_the_problems_list_shows_lint_and_validator_text_and_says_so_when_clean() -> void:
	var slot := await _slot()
	model.rooms["C1"].exits.append({"edge": "top", "from": 100.0, "to": 200.0, "room": "Z"})
	model.serial += 1
	slot.show_problems(model.problems())
	assert_true(slot.problem_lines().any(func(l): return l.contains("unknown room 'Z'")))
	slot.show_problems([])
	assert_eq(slot.problem_lines(), ["No problems found."])

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

func test_undoing_the_new_room_you_are_standing_in_returns_to_the_room_you_came_from() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	ed.new_room("left", "Fresh", "cave", Vector2i(1, 1))
	assert_eq(ed.room_id, "Fresh")
	ed.undo()
	assert_eq(ed.room_id, "C6", "the room is gone: back where you came from, not a dangling id")
	assert_eq(ed.view.room_id(), "C6")
	assert_false(ed.model.rooms.has("Fresh"))
	ed.redo()
	assert_true(ed.model.rooms.has("Fresh"))
	assert_eq(ed.room_id, "C6", "redo brings the room back but does not move you")
	ed.open_room("Fresh")
	assert_eq(ed.view.room_id(), "Fresh")

func test_the_validate_list_toggles_and_an_open_list_refreshes_on_any_edit() -> void:
	var ed := await _editor()
	ed.panels.press("Validate")
	assert_eq(ed.slot.is_showing(), "problems")
	ed.panels.press("Validate")
	assert_eq(ed.slot.is_showing(), "", "pressing Validate again hides it")
	ed.panels.press("Validate")
	assert_eq(ed.slot.is_showing(), "problems")
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(200, 116))
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "problems", "an edit refreshes the list instead of closing it")
	ed.undo()
	assert_eq(ed.slot.is_showing(), "problems")

func test_a_drag_where_the_validate_list_was_reaches_the_room_after_it_is_closed() -> void:
	var ed := await _editor()
	ed.panels.press("Validate")
	ed.panels.press("Validate")
	ed.panels.press("Solid")
	var a := ed.view.to_screen(Vector2(960, 120))
	var b := ed.view.to_screen(Vector2(1120, 180))
	for ev in [_button_at(a, true), _motion_at(b), _button_at(b, false)]:
		get_viewport().push_input(ev, true)
	await wait_process_frames(2)
	assert_eq(ed.model.undo_depth(), 1)

# --- Task 12: toolbar, Validate count, Grow, toggles, pending text ---

func test_the_validate_button_carries_the_count_and_the_open_list_refreshes() -> void:
	var ed := await _editor()
	assert_eq(ed.panels.validate_label(), "Validate (0)")
	ed.model.rooms["C1"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	ed.model.add_solid("C1", Vector2(100, 100), Vector2(160, 116))
	ed.view.refresh()
	var n: int = ed.model.problems().size()
	assert_gt(n, 0)
	assert_eq(ed.panels.validate_label(), "Validate (%d)" % n)
	ed.panels.press("Validate")
	assert_eq(ed.slot.is_showing(), "problems")
	var before: int = ed.slot.problem_lines().size()
	ed.model.add_solid("C1", Vector2(300, 100), Vector2(360, 116))
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "problems", "an open list refreshes instead of closing")
	assert_gte(ed.slot.problem_lines().size(), before)

func test_clicking_a_problem_opens_its_room_selects_it_and_centres_it() -> void:
	var ed := await _editor()
	ed.model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	ed.model.add_solid("C2", Vector2(100, 100), Vector2(160, 116))
	ed.view.refresh()
	var at := ed.model.problems().find_custom(func(p): return p["pick"].get("kind", "") == "spawn")
	assert_gte(at, 0)
	ed.panels.press("Validate")
	ed.slot.click_problem(at)
	assert_eq(ed.room_id, "C2")
	assert_eq(ed.model.selection["kind"], "spawn")
	var free := ed._free_rect()
	assert_almost_eq(ed.view.to_screen(ed.view.selection_rect().get_center()), free.get_center(), Vector2(1, 1), "the problem is centred in the free area")

func test_the_toggles_reach_the_play_request() -> void:
	var ed := await _editor()
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	ed.panels.press("Wall Cling")
	ed.panels.press("Open shortcuts")
	assert_true(ed.play_options["movement"])
	assert_true(ed.play_options["shortcuts"])
	ed.play(Vector2(300, 100))
	assert_eq(Game.play_request["kit"], {"skills": ["leap", "wall_cling"]})
	assert_true(Game.play_request["open_shortcuts"])
	assert_eq(Game.editor_resume["play_options"], {"movement": true, "shortcuts": true})
	Game.play_request = {}
	Game.editor_resume = null

func test_the_movement_kit_is_a_kit_the_validator_accepts() -> void:
	assert_eq(RebirthKit.validate(RoomEditor.CAVE_MOVEMENT_KIT), PackedStringArray())

func test_play_options_survive_the_round_trip_and_set_the_buttons() -> void:
	Game.editor_resume = {"model": model, "room": "C1", "view": {}, "play_options": {"movement": true, "shortcuts": false}}
	_gut_ui(false)
	var ed: RoomEditor = load("res://scenes/room_editor.tscn").instantiate()
	add_child_autofree(ed)
	await wait_process_frames(3)
	assert_true(ed.play_options["movement"])
	assert_true(ed.panels.toggle_state("Wall Cling"))
	assert_false(ed.panels.toggle_state("Open shortcuts"))

func test_play_error_and_play_agree_on_the_spot_with_the_toggle_on_and_off() -> void:
	var ed := await _editor()
	RoomEditor.sandbox_root = OS.get_user_data_dir()
	ed.open_room("C6")
	var gate: Rect2 = RoomBuilder.gate_rect(ed.model.rooms["C6"].pixel_size(), ed.model.rooms["C6"].exits.filter(func(e): return e.has("shortcut"))[0])
	var over := Vector2(gate.get_center().x, 100)
	assert_eq(ed.play_error(over), "", "a closed gate is a surface")
	ed.panels.press("Open shortcuts")
	assert_ne(ed.play_error(over), "", "with shortcuts open it is a hole")
	assert_null(ed._spot(over))

func test_grow_from_the_menu_changes_the_room_and_refuses_an_overlap() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	var w: int = ed.model.rooms["C6"].size.x
	ed.grow("left")
	assert_eq(ed.model.rooms["C6"].size.x, w + 1)
	ed.open_room("C1")
	ed.grow("right")
	assert_string_contains(ed.panels.status_text(), "overlap")

func test_the_grow_menu_emits_the_side() -> void:
	var p := await _panels()
	watch_signals(p)
	p.choose_grow("top")
	assert_signal_emitted_with_parameters(p, "grow_requested", ["top"])

func test_pending_text_is_committed_before_save_undo_and_play() -> void:
	var ed := await _editor()
	ed.save_dir = "res://.tmp/editor_scene_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ed.save_dir))
	ed.model.add_feature("C1", "tablet", Vector2(300, 100))
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "inspector")
	var title: LineEdit = ed.slot.find_field("title")
	title.grab_focus()
	title.text = "Typed"
	ed.panels.press("Save")
	assert_eq(ed.model.rooms["C1"].features.back()["title"], "Typed", "Save committed the pending text first")
	var saved := ResourceLoader.load("%s/C1.tres" % ed.save_dir, "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_eq(saved.features.back()["title"], "Typed")
	title = ed.slot.find_field("title")
	title.grab_focus()
	title.text = "Typed again"
	ed.panels.press("Undo")
	assert_eq(ed.model.rooms["C1"].features.back()["title"], "Typed", "the text committed as an edit and Undo undid it")
	assert_eq(ed.slot.is_showing(), "", "undo clears the selection, so the inspector closes rather than show stale text")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/C1.tres" % ed.save_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ed.save_dir))

func test_cmd_s_saves_even_while_a_field_has_focus() -> void:
	var ed := await _editor()
	ed.save_dir = "res://.tmp/editor_scene_save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ed.save_dir))
	ed.model.add_feature("C1", "tablet", Vector2(300, 100))
	ed.view.refresh()
	var title: LineEdit = ed.slot.find_field("title")
	title.grab_focus()
	title.text = "Via shortcut"
	assert_true(ed.panels.typing())
	var s := InputEventKey.new()
	s.keycode = KEY_S
	s.pressed = true
	s.ctrl_pressed = true
	get_viewport().push_input(s)
	await wait_process_frames(1)
	var saved := ResourceLoader.load("%s/C1.tres" % ed.save_dir, "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_not_null(saved)
	assert_eq(saved.features.back()["title"], "Via shortcut")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/C1.tres" % ed.save_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ed.save_dir))

func test_selecting_a_feature_shows_its_inspector_and_a_creature_hides_it() -> void:
	var ed := await _editor()
	ed.model.add_feature("C1", "tablet", Vector2(300, 100))
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "inspector")
	ed.model.select({"room": "C1", "kind": "spawn", "index": 0})
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "", "a solid now has a panel (a number each); a creature still has none")

func test_delete_and_undo_still_work_after_ticking_a_kit_skill() -> void:
	var ed := await _editor()
	ed.open_room("G1")
	var idx: int = ed.model.rooms["G1"].features.find_custom(func(f): return f["kind"] == "rebirth_pool")
	ed.model.select({"room": "G1", "kind": "feature", "index": idx})
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "inspector")
	var had: Array = ed.model.get_field(ed.model.selection, "kit_skills")
	ed.slot.skill_checkboxes().filter(func(c): return not had.has(c.get_meta("skill")))[0].button_pressed = true
	var box: CheckBox = ed.slot.skill_checkboxes()[0]
	assert_eq(box.focus_mode, Control.FOCUS_NONE, "a click on the box cannot leave focus on it")
	assert_false(ed.panels.typing())
	var z := InputEventKey.new()
	z.keycode = KEY_Z
	z.pressed = true
	z.ctrl_pressed = true
	get_viewport().push_input(z)
	await wait_process_frames(1)
	assert_eq(ed.model.get_field({"room": "G1", "kind": "feature", "index": idx}, "kit_skills").size(), had.size())

func test_tab_hides_and_shows_every_panel() -> void:
	var ed := await _editor()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	await wait_process_frames(1)
	assert_false(ed.panels.panels_visible())
	get_viewport().push_input(tab)
	await wait_process_frames(1)
	assert_true(ed.panels.panels_visible())

func test_the_feature_palette_shows_for_the_feature_tool_and_chooses_the_kind() -> void:
	var ed := await _editor()
	ed.panels.press("Feature")
	assert_true(ed.panels.feature_palette_visible())
	assert_false(ed.panels.palette_visible())
	assert_eq(ed.view.tool, "feature")
	ed.panels.choose_feature("switch")
	assert_eq(ed.view.feature_kind, "switch")

func test_the_world_button_shows_the_overview_and_choosing_a_room_opens_it() -> void:
	var ed := await _editor()
	ed.panels.press("World")
	assert_true(ed.world.visible)
	var c2: Rect2 = ed.world.layout_items().filter(func(i): return i["id"] == "C2")[0]["rect"]
	ed.world.click(c2.get_center())
	assert_false(ed.world.visible, "choosing a room closes the overview")
	assert_eq(ed.room_id, "C2")
	assert_eq(ed.view.room_id(), "C2")

func test_pressing_world_again_or_escape_closes_it() -> void:
	var ed := await _editor()
	ed.panels.press("World")
	ed.panels.press("World")
	assert_false(ed.world.visible)
	ed.panels.press("World")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc)
	await wait_process_frames(1)
	assert_false(ed.world.visible)
	assert_eq(ed.room_id, "C1", "closing changes nothing")

func test_the_overview_follows_the_model_while_it_is_open() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	ed.panels.press("World")
	var c6w: int = ed.model.rooms["C6"].size.x
	var ratio := func() -> float:
		var items: Array = ed.world.layout_items()
		var c6: Rect2 = items.filter(func(i): return i["id"] == "C6")[0]["rect"]
		var c1: Rect2 = items.filter(func(i): return i["id"] == "C1")[0]["rect"]
		return c6.size.x / c1.size.x
	var before: float = ratio.call()
	ed.grow("left")
	assert_true(ed.world.visible)
	assert_almost_eq(float(ratio.call()), before * float(c6w + 1) / float(c6w), 0.001, "the overview was laid out again with the grown room")

# --- review fixes: real events where the plan's tests emitted signals by hand ---

func _key(code: Key, ctrl := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	k.ctrl_pressed = ctrl
	return k

func test_delete_and_backspace_inside_a_field_edit_the_text_and_never_delete_the_element() -> void:
	var ed := await _editor()
	ed.model.add_feature("C1", "tablet", Vector2(300, 100))
	ed.view.refresh()
	var n: int = ed.model.rooms["C1"].features.size()
	var title: LineEdit = ed.slot.find_field("title")
	title.grab_focus()
	assert_true(ed.panels.typing())
	get_viewport().push_input(_key(KEY_DELETE))
	get_viewport().push_input(_key(KEY_BACKSPACE))
	await wait_process_frames(1)
	assert_eq(ed.model.rooms["C1"].features.size(), n, "keys typed in a field never reach the room")

func test_delete_after_ticking_a_kit_skill_deletes_the_pool() -> void:
	var ed := await _editor()
	ed.open_room("G1")
	var idx: int = ed.model.rooms["G1"].features.find_custom(func(f): return f["kind"] == "rebirth_pool")
	ed.model.select({"room": "G1", "kind": "feature", "index": idx})
	ed.view.refresh()
	var had: Array = ed.model.get_field(ed.model.selection, "kit_skills")
	ed.slot.skill_checkboxes().filter(func(c): return not had.has(c.get_meta("skill")))[0].button_pressed = true
	var n: int = ed.model.rooms["G1"].features.size()
	get_viewport().push_input(_key(KEY_DELETE))
	await wait_process_frames(1)
	assert_eq(ed.model.rooms["G1"].features.size(), n - 1, "a ticked box left no focus behind to swallow Delete")

func test_a_real_click_on_another_feature_commits_the_typed_text_to_the_first() -> void:
	var ed := await _editor()
	ed.model.add_feature("C1", "tablet", Vector2(300, 100))
	ed.model.add_feature("C1", "tablet", Vector2(420, 100))
	ed.view.refresh()
	var features: Array = ed.model.rooms["C1"].features
	var first_idx := features.size() - 2
	ed.model.select({"room": "C1", "kind": "feature", "index": first_idx})
	ed.view.refresh()
	var title: LineEdit = ed.slot.find_field("title")
	title.grab_focus()
	title.text = "Typed for the first"
	var second: Vector2 = features[features.size() - 1]["pos"]
	var at := ed.view.to_screen(second + Vector2(0, -8))
	for ev in [_button_at(at, true), _button_at(at, false)]:
		get_viewport().push_input(ev, true)
	await wait_process_frames(2)
	assert_eq(features[first_idx]["title"], "Typed for the first", "the click committed the text before the selection moved")
	assert_eq(ed.model.selection["index"], features.size() - 1, "and selected the second tablet")

func test_clicking_a_problem_button_for_real_lands_without_a_crash() -> void:
	var ed := await _editor()
	ed.model.rooms["C2"].spawns.append({"id": "toad", "pos": Vector2(5, 100)})
	ed.model.add_solid("C2", Vector2(100, 100), Vector2(160, 116))
	ed.view.refresh()
	ed.panels.press("Validate")
	ed.slot._list.get_child(0).pressed.emit()  # the button frees itself while its signal runs
	await wait_process_frames(2)
	assert_eq(ed.slot.is_showing(), "problems")
	assert_true(ed.model.rooms.has(ed.room_id))

func test_with_the_world_view_open_delete_cannot_reach_the_hidden_room() -> void:
	var ed := await _editor()
	ed.model.add_feature("C1", "tablet", Vector2(300, 100))
	ed.view.refresh()
	var n: int = ed.model.rooms["C1"].features.size()
	ed.panels.press("World")
	get_viewport().push_input(_key(KEY_DELETE))
	await wait_process_frames(1)
	assert_eq(ed.model.rooms["C1"].features.size(), n, "Delete did nothing under the overview")
	ed.panels.press("World")
	get_viewport().push_input(_key(KEY_DELETE))
	await wait_process_frames(1)
	assert_eq(ed.model.rooms["C1"].features.size(), n - 1, "and works again once it is closed")

func test_the_palettes_never_take_keyboard_focus_so_tab_keeps_hiding_the_panels() -> void:
	var p := await _panels()
	assert_eq(p._palette.focus_mode, Control.FOCUS_NONE)
	assert_eq(p._feature_palette.focus_mode, Control.FOCUS_NONE)

# --- Alt-press selection and the drag threshold ---

func _alt_press(p: Vector2) -> InputEventMouseButton:
	var e := _press(p)
	e.alt_pressed = true
	return e

## Two nested solids in a far-away room, stacked on one point.
func _nested_room() -> void:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.solids = [Rect2(100, 100, 200, 60), Rect2(150, 120, 40, 20)]
	model.rooms["L1"] = r
	model._baseline["L1"] = RoomEditModel.copy_room(r)
	view.show_room(model, "L1")

func test_a_plain_press_takes_the_first_candidate_and_alt_presses_walk_the_rest() -> void:
	_nested_room()
	view.tool = "select"
	var at := Vector2(170, 130)
	view.handle_event(_press(at))
	view.handle_event(_release(at))
	assert_eq(model.selection["index"], 1, "plain press: the smaller solid, as P2")
	view.handle_event(_alt_press(at))
	view.handle_event(_release(at))
	assert_eq(model.selection["index"], 0, "Alt-press: the next candidate")
	view.handle_event(_alt_press(at))
	view.handle_event(_release(at))
	assert_eq(model.selection["index"], 1, "and it wraps")

func test_an_alt_drag_moves_what_it_selected() -> void:
	_nested_room()
	view.tool = "select"
	var at := Vector2(170, 130)
	view.handle_event(_press(at))
	view.handle_event(_release(at))
	view.handle_event(_alt_press(at))
	view.handle_event(_motion(at + Vector2(40, 0)))
	view.handle_event(_release(at + Vector2(40, 0)))
	assert_eq(model.rooms["L1"].solids[0], Rect2(140, 100, 200, 60), "the big solid moved")
	assert_eq(model.rooms["L1"].solids[1], Rect2(150, 120, 40, 20), "the small one did not")

func test_a_creature_beside_a_selected_ledge_is_selected_by_a_plain_press() -> void:
	_nested_room()
	model.rooms["L1"].spawns = [{"id": "toad", "pos": Vector2(250, 120)}]
	view.tool = "select"
	view.handle_event(_press(Vector2(170, 130)))
	view.handle_event(_release(Vector2(170, 130)))
	view.handle_event(_press(Vector2(250, 120)))
	view.handle_event(_release(Vector2(250, 120)))
	assert_eq(model.selection["kind"], "spawn", "a plain press never keeps the old selection")

func test_a_press_with_a_pixel_of_jitter_moves_nothing_even_in_a_huge_room() -> void:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.size = Vector2i(6, 6)
	r.solids = [Rect2(100, 100, 200, 12)]
	model.rooms["L1"] = r
	model._baseline["L1"] = RoomEditModel.copy_room(r)
	view.show_room(model, "L1")
	view.tool = "select"
	var at := Vector2(200, 106)
	var press := _press(at)
	view.handle_event(press)
	var jitter := InputEventMouseMotion.new()
	jitter.position = press.position + Vector2(2, 0)   # 2 screen px: about 12 room px at this zoom
	view.handle_event(jitter)
	view.handle_event(_release(at))
	assert_eq(model.rooms["L1"].solids[0], Rect2(100, 100, 200, 12))
	assert_eq(model.undo_depth(), 0)

func test_a_drag_starts_after_three_screen_pixels_and_applies_from_the_press() -> void:
	_nested_room()
	view.tool = "select"
	var at := Vector2(170, 130)
	var press := _press(at)
	view.handle_event(press)
	var far := InputEventMouseMotion.new()
	far.position = press.position + Vector2(20, 0)
	view.handle_event(far)
	view.handle_event(_release(view.to_room(far.position)))
	var moved: Rect2 = model.rooms["L1"].solids[1]
	assert_almost_eq(moved.position.x, 150.0 + view.to_room(far.position).x - at.x, 4.0, "the whole distance applied, no lag")

# --- a solid's panel ---

func test_a_selected_solid_shows_its_numbers() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	assert_eq(ed.slot.is_showing(), "inspector")
	var x: SpinBox = ed.slot.find_field("x")
	assert_eq([x.value, x.min_value, x.max_value], [420.0, 0.0, 1276.0], "a new SpinBox starts at 0..100: ranges first, then the value")
	assert_eq((ed.slot.find_field("y") as SpinBox).value, 214.0)
	assert_eq((ed.slot.find_field("w") as SpinBox).value, 100.0)
	assert_eq((ed.slot.find_field("h") as SpinBox).value, 12.0)

func test_typing_a_number_commits_it_once_and_never_while_building() -> void:
	var ed := await _editor()
	var depth_before: int = ed.model.undo_depth()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	assert_eq(ed.model.undo_depth(), depth_before, "building the panel commits nothing")
	var x: SpinBox = ed.slot.find_field("x")
	x.value = 440.0
	assert_eq(ed.model.rooms["C1"].solids[1].position.x, 440.0)
	assert_eq(ed.model.undo_depth(), depth_before + 1)

func test_a_refused_number_shows_the_stored_value_again() -> void:
	var ed := await _editor()
	var errors := []
	ed.slot.field_error.connect(func(t: String) -> void: errors.append(t))
	ed.model.rooms["C1"].solids.append(Rect2(500, 100, 120, 12))
	var i: int = ed.model.rooms["C1"].solids.size() - 1
	ed.model.select({"room": "C1", "kind": "solid", "index": i})
	ed.view.refresh()
	(ed.slot.find_field("x") as SpinBox).value = 260.0
	(ed.slot.find_field("y") as SpinBox).value = 266.0   # now identical to C1's first ledge
	assert_eq(errors.size(), 1)
	assert_eq((ed.slot.find_field("y") as SpinBox).value, 100.0, "back to the stored value")

func test_rock_from_below_is_a_checkbox_that_hides_for_a_thick_solid() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	var box: CheckBox = ed.slot.find_field("hard")
	assert_true(box.visible)
	box.button_pressed = true
	assert_true(ed.model.rooms["C1"].hard_ledges.has(Rect2(420, 214, 100, 12)))
	ed.model.select({"room": "C1", "kind": "solid", "index": 5})
	ed.view.refresh()
	assert_false((ed.slot.find_field("hard") as CheckBox).visible, "a thick solid is rock anyway")

func test_building_the_panel_for_a_solid_that_sticks_out_of_the_room_changes_nothing() -> void:
	var ed := await _editor()
	ed.model.rooms["C1"].solids.append(Rect2(100, 358, 8, 4))  # lint's solid_outside: y is past the control's maximum (356)
	var i: int = ed.model.rooms["C1"].solids.size() - 1
	var depth: int = ed.model.undo_depth()
	ed.model.select({"room": "C1", "kind": "solid", "index": i})
	ed.view.refresh()
	assert_eq(ed.model.rooms["C1"].solids[i], Rect2(100, 358, 8, 4), "the control clamps what it shows; building commits nothing")
	assert_eq(ed.model.undo_depth(), depth)

# --- the inspector never shows a stale number ---

func test_a_drag_updates_the_number_that_was_showing() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	assert_true(ed.model.begin_move(ed.model.selection))
	ed.model.move_to(Vector2(40, 0))
	ed.model.end_move()
	ed.view.refresh()
	assert_eq((ed.slot.find_field("x") as SpinBox).value, 460.0, "the field follows the drag")

func test_a_grow_moves_the_number_and_the_range_with_the_room() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	var solid: Rect2 = ed.model.rooms["C6"].solids[0]
	ed.model.select({"room": "C6", "kind": "solid", "index": 0})
	ed.view.refresh()
	var depth: int = ed.model.undo_depth()
	ed.grow("left")
	var x: SpinBox = ed.slot.find_field("x")
	assert_eq(ed.model.rooms["C6"].solids[0].position.x, solid.position.x + 640.0)
	assert_eq(x.value, solid.position.x + 640.0, "the shifted value is shown, not clamped to the old maximum")
	assert_eq(x.max_value, 1280.0 - 4.0)
	assert_eq(ed.model.undo_depth(), depth + 1, "a refresh never commits: only the grow is a step")

func test_a_refresh_leaves_a_focused_field_alone_and_updates_it_once_it_is_not() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	var x: SpinBox = ed.slot.find_field("x")
	x.get_line_edit().grab_focus()
	ed.model.rooms["C1"].solids[1].position.x = 500.0   # the model changed under the focused field
	ed.slot.refresh_inspector()
	assert_eq(x.value, 420.0, "the author is typing in it: not overwritten")
	x.get_line_edit().release_focus()
	ed.slot.refresh_inspector()
	assert_eq(x.value, 500.0, "and refreshed once it is not focused")

func test_the_rock_from_below_checkbox_follows_the_height() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	(ed.slot.find_field("h") as SpinBox).value = 30.0
	assert_false((ed.slot.find_field("hard") as CheckBox).visible, "typed thick: the checkbox hides")
	(ed.slot.find_field("h") as SpinBox).value = 12.0
	assert_true((ed.slot.find_field("hard") as CheckBox).visible, "typed thin again: it shows")

# --- the Decor tool ---

func test_the_decor_tool_places_a_piece_that_stands_on_the_surface() -> void:
	view.tool = "decor"
	view.decor_id = "crystal_teal"
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	var placed: Dictionary = model.rooms["C1"].decor.back()
	assert_eq(placed["id"], "crystal_teal")
	assert_eq(model.selection["kind"], "decor")
	assert_eq(model.undo_depth(), 1)

func test_the_decor_tool_without_a_choice_says_so_and_refuses_with_a_message() -> void:
	view.tool = "decor"
	view.decor_id = ""
	var messages := []
	view.message.connect(func(t: String) -> void: messages.append(t))
	view.handle_event(_press(Vector2(300, 100)))
	view.handle_event(_release(Vector2(300, 100)))
	assert_eq(messages.size(), 1)
	view.decor_id = "vine"
	var top: Dictionary = model.rooms["C1"].exits.filter(func(e): return e["edge"] == "top")[0]
	var mid := (float(top["from"]) + float(top["to"])) / 2.0
	view.handle_event(_press(Vector2(mid, 200)))
	view.handle_event(_release(Vector2(mid, 200)))
	assert_eq(messages.size(), 2, "a hanging piece under a top exit has nothing to hang from")
	assert_eq(model.undo_depth(), 0)

func test_the_selected_decor_outline_and_an_unknown_pieces_red_box() -> void:
	model.rooms["C1"].decor.append({"id": "no_such_sprite", "pos": Vector2(300, 300)})
	view.show_room(model, "C1")
	await wait_process_frames(1)
	var i: int = model.rooms["C1"].decor.size() - 1
	model.select({"room": "C1", "kind": "decor", "index": i})
	assert_eq(view.selection_rect(), Rect2(Vector2(300, 300) + DecorLib.UNKNOWN_BOX.position, DecorLib.UNKNOWN_BOX.size))
	model.select({})
	view.refresh()
	assert_gt(view.overlay.get_children().filter(func(n): return n is Line2D).size(), 0, "nothing is selected, so the lines are the unknown piece's red box")

func test_an_unknown_decor_piece_can_be_reached_from_the_problems_list_and_deleted() -> void:
	var ed := await _editor()
	ed.model.rooms["C1"].decor.append({"id": "no_such_sprite", "pos": Vector2(300, 300), "anchor": "top"})
	ed.model.serial += 1
	ed.view.refresh()
	ed.panels.press("Validate")
	var at := ed.model.problems().find_custom(func(p): return p["pick"].get("kind", "") == "decor")
	assert_gte(at, 0, "decor_unknown lists it")
	ed.slot.click_problem(at)
	assert_eq(ed.model.selection["kind"], "decor")
	assert_ne(ed.view.selection_rect().size, Vector2.ZERO, "it has a box to centre on")
	var n: int = ed.model.rooms["C1"].decor.size()
	assert_eq(ed.model.delete_selection(), "")
	assert_eq(ed.model.rooms["C1"].decor.size(), n - 1)

func test_the_decor_palette_shows_for_the_decor_tool_and_follows_the_rooms_area() -> void:
	var ed := await _editor()
	ed.panels.press("Decor")
	assert_true(ed.panels.decor_palette_visible())
	assert_false(ed.panels.palette_visible())
	assert_eq(ed.panels.decor_palette_ids(), DecorLib.ids_for_biome("cave"))
	ed.open_room("G1")
	assert_eq(ed.panels.decor_palette_ids(), DecorLib.ids_for_biome("grotto"), "rebuilt for the new room's area")
	ed.panels.choose_decor("grotto_flowers")
	assert_eq(ed.view.decor_id, "grotto_flowers")
	assert_eq(ed._free_rect().position.x, 92.0, "the palette is counted when fitting")

# --- gate and hint controls ---

func test_the_gate_dropdown_writes_both_halves_and_shows_a_stored_unknown_gate_as_its_own_item() -> void:
	var ed := await _editor()
	var idx := -1
	for i in ed.model.rooms["C1"].exits.size():
		if ed.model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	ed.model.select({"room": "C1", "kind": "exit", "index": idx})
	ed.view.refresh()
	var pick: OptionButton = ed.slot.find_field("gate")
	assert_eq(pick.get_item_text(pick.selected), "none")
	pick.item_selected.emit(1)   # wall_cling
	assert_eq(ed.model.rooms["C1"].exits[idx].get("gate", ""), "wall_cling")
	ed.model.rooms["C1"].exits[idx]["gate"] = "typo_gate"   # hand-edited data
	ed.slot.show_inspector(ed.model, ed.model.selection)
	var shown: OptionButton = ed.slot.find_field("gate")
	assert_eq(shown.get_item_text(shown.selected), "typo_gate", "the control never shows 'none' for a gate that is there")

func test_the_hint_dropdown_sets_and_clears_a_tablets_hint() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	var idx: int = ed.model.rooms["C6"].features.find_custom(func(f): return f["kind"] == "tablet")
	ed.model.select({"room": "C6", "kind": "feature", "index": idx})
	ed.view.refresh()
	var pick: OptionButton = ed.slot.find_field("hint")
	pick.item_selected.emit(0)   # none
	assert_false(ed.model.rooms["C6"].features[idx].has("hint"))

func test_a_refresh_selects_a_string_choice_by_its_text() -> void:
	var ed := await _editor()
	var idx := -1
	for i in ed.model.rooms["C1"].exits.size():
		if ed.model.rooms["C1"].exits[i]["room"] == "C2":
			idx = i
	ed.model.select({"room": "C1", "kind": "exit", "index": idx})
	ed.view.refresh()
	ed.model.rooms["C1"].exits[idx]["gate"] = "wall_cling"   # changed under the open panel
	ed.slot.refresh_inspector()
	var pick: OptionButton = ed.slot.find_field("gate")
	assert_eq(pick.get_item_text(pick.selected), "wall_cling", "by item text, not by an index parsed from a string")

func test_a_new_room_says_which_room_it_was_made_beside() -> void:
	var ed := await _editor()
	ed.open_room("C6")
	ed.new_room("left", "Fresh", "cave", Vector2i(1, 1))
	assert_string_contains(ed.panels.status_text(), "created Fresh beside C6")

func test_the_rock_from_below_checkbox_is_not_labelled_twice() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	var labels := 0
	var stack: Array = [ed.slot]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text == "Rock from below":
			labels += 1
		stack.append_array(n.get_children())
	assert_eq(labels, 0, "the checkbox carries its own text")

# --- review fixes ---

func test_a_decor_choice_that_the_new_rooms_palette_does_not_list_is_dropped() -> void:
	var ed := await _editor()
	ed.panels.press("Decor")
	ed.panels.choose_decor("crystal_teal")
	assert_eq(ed.view.decor_id, "crystal_teal")
	ed.open_room("G1")   # a grotto room: the palette lists grotto_* ids only
	assert_eq(ed.view.decor_id, "", "the old choice is not in the new palette, so it must not still be placed")
	var n: int = ed.model.rooms["G1"].decor.size()
	ed.view.handle_event(_button_at(ed.view.to_screen(Vector2(300, 100)), true))
	ed.view.handle_event(_button_at(ed.view.to_screen(Vector2(300, 100)), false))
	assert_eq(ed.model.rooms["G1"].decor.size(), n, "nothing was placed")

func test_a_decor_choice_that_the_new_rooms_palette_lists_is_kept() -> void:
	var ed := await _editor()
	ed.panels.press("Decor")
	ed.panels.choose_decor("crystal_teal")
	ed.open_room("C2")   # still a cave room
	assert_eq(ed.view.decor_id, "crystal_teal")
	assert_eq(ed.panels._decor_palette.get_selected_items().size(), 1, "and it is still highlighted")

func test_the_number_field_shows_the_new_text_after_a_refresh_not_only_the_new_value() -> void:
	var ed := await _editor()
	ed.model.select({"room": "C1", "kind": "solid", "index": 1})
	ed.view.refresh()
	ed.model.rooms["C1"].solids[1].position.x = 500.0
	ed.slot.refresh_inspector()
	await wait_process_frames(2)
	assert_eq((ed.slot.find_field("x") as SpinBox).get_line_edit().text, "500", "what the author sees, not only .value")

func test_the_decor_palette_never_takes_keyboard_focus() -> void:
	var p := await _panels()
	assert_eq(p._decor_palette.focus_mode, Control.FOCUS_NONE)
