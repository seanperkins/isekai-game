extends GutTest
## The editor's room view shows a room's water (it builds the room the way the game does) and Validate lists a trapped swimmer.

func test_the_room_view_shows_a_rooms_water() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var model := RoomEditModel.new(rooms, [])
	var view := RoomView.new()
	add_child_autofree(view)
	view.show_room(model, "F2")
	var found := 0
	for n in view.room_node().get_children():
		if n is DeepWater:
			found += 1
	assert_eq(found, 1, "the editor draws the F2 column")

func test_a_room_without_water_shows_none() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var model := RoomEditModel.new(rooms, [])
	var view := RoomView.new()
	add_child_autofree(view)
	view.show_room(model, "C1")
	for n in view.room_node().get_children():
		assert_false(n is DeepWater)

func test_validate_lists_a_trapped_swimmer() -> void:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "flooded"
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = [Rect2(200, 240, 160, 80)]  # no shore, no exit
	var model := RoomEditModel.new({"T1": r}, [])
	assert_true(model.problems().any(func(p): return str(p["text"]).find("cannot get out") >= 0), str(model.problems()))
