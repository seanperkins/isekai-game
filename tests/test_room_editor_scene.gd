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
