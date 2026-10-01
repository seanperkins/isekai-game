extends GutTest
## The World view: a pure layout of every room at its world position, scaled to fit, and a click mapped back to a room.

func _rooms() -> Dictionary:
	return ShippedRooms.load_all()

func test_the_layout_has_one_rect_per_room_inside_the_panel() -> void:
	var panel := Rect2(20, 40, 600, 280)
	var layout := WorldView.layout(_rooms(), panel)
	assert_eq(layout.size(), 23)
	for item in layout:
		assert_true(panel.grow(0.01).encloses(item["rect"]), item["id"])

func test_the_layout_keeps_relative_positions_and_one_scale() -> void:
	var rooms := _rooms()
	var layout := WorldView.layout(rooms, Rect2(0, 0, 600, 300))
	var by_id := {}
	for item in layout:
		by_id[item["id"]] = item["rect"]
	var scale: float = (by_id["C1"] as Rect2).size.x / rooms["C1"].world_rect().size.x
	for id in rooms:
		assert_almost_eq((by_id[id] as Rect2).size.x, rooms[id].world_rect().size.x * scale, 0.01, id)
		assert_almost_eq((by_id[id] as Rect2).size.y, rooms[id].world_rect().size.y * scale, 0.01, id)
	assert_lt((by_id["C1"] as Rect2).position.x, (by_id["C2"] as Rect2).position.x, "C2 is east of C1")

func test_one_room_fills_the_panel() -> void:
	var r := RoomDef.new()
	r.id = "A"
	var layout := WorldView.layout({"A": r}, Rect2(0, 0, 600, 300))
	assert_eq(layout.size(), 1)
	assert_gt((layout[0]["rect"] as Rect2).size.x, 300.0)

func test_no_rooms_lay_out_to_nothing() -> void:
	assert_eq(WorldView.layout({}, Rect2(0, 0, 600, 300)), [])

func test_room_at_maps_a_point_to_a_room_or_nothing() -> void:
	var layout := WorldView.layout(_rooms(), Rect2(0, 0, 600, 300))
	var c1: Rect2 = layout.filter(func(i): return i["id"] == "C1")[0]["rect"]
	assert_eq(WorldView.room_at(layout, c1.get_center()), "C1")
	assert_eq(WorldView.room_at(layout, Vector2(-50, -50)), "")

func test_clicking_the_view_chooses_a_room() -> void:
	var v := WorldView.new()
	add_child_autofree(v)
	v.setup(_rooms(), "C1")
	var chosen := []
	v.room_chosen.connect(func(id: String) -> void: chosen.append(id))
	var c4: Rect2 = v.layout_items().filter(func(i): return i["id"] == "C4")[0]["rect"]
	v.click(c4.get_center())
	assert_eq(chosen, ["C4"])
	v.click(Vector2(-5, -5))
	assert_eq(chosen, ["C4"], "a click on nothing chooses nothing")

func test_a_left_click_event_reaches_click() -> void:
	var v := WorldView.new()
	add_child_autofree(v)
	v.setup(_rooms(), "C1")
	var chosen := []
	v.room_chosen.connect(func(id: String) -> void: chosen.append(id))
	var c2: Rect2 = v.layout_items().filter(func(i): return i["id"] == "C2")[0]["rect"]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = c2.get_center()
	v._gui_input(e)
	assert_eq(chosen, ["C2"])

func test_every_biome_has_a_colour_on_the_overview() -> void:
	for biome in TerrainArt.biomes():
		assert_true(WorldView.AREA_FILL.has(biome), "%s needs an AREA_FILL entry" % biome)
