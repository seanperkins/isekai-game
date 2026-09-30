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
