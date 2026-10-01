extends GutTest

func test_make_positions_the_node_and_joins_the_group() -> void:
	var w := DeepWater.make(Rect2(100, 200, 64, 48))
	add_child_autofree(w)
	assert_true(w.is_in_group("deep_water"))
	assert_eq(w.position, Vector2(100, 200))
	assert_eq(w.local_rect.size, Vector2(64, 48))

func test_at_finds_the_node_holding_a_world_point() -> void:
	var holder := Node2D.new()
	holder.position = Vector2(1000, 500)
	add_child_autofree(holder)
	var w := DeepWater.make(Rect2(100, 200, 64, 48))
	holder.add_child(w)
	assert_eq(w.world_rect(), Rect2(1100, 700, 64, 48), "a room node's position carries into the rect")
	assert_eq(DeepWater.at(get_tree(), Vector2(1120, 720)), w)
	assert_null(DeepWater.at(get_tree(), Vector2(1099, 720)), "just left of it")
	assert_null(DeepWater.at(get_tree(), Vector2(1120, 748)), "the bottom edge is outside")

func test_the_builder_adds_one_node_per_water_rect() -> void:
	var r := RoomDef.new()
	r.id = "W1"
	r.area = "flooded"
	r.cell = Vector2i(3, 2)
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = [Rect2(100, 200, 64, 48), Rect2(300, 220, 80, 60)]
	var node := RoomBuilder.build_room(r, {})
	add_child_autofree(node)
	var found: Array = node.get_children().filter(func(n): return n is DeepWater)
	assert_eq(found.size(), 2)
	assert_eq(found[0].world_rect(), Rect2(Vector2(3 * 640, 2 * 360) + Vector2(100, 200), Vector2(64, 48)))

func test_a_room_without_water_builds_none() -> void:
	var r: RoomDef = ShippedRooms.load_all()["C1"]
	var node := RoomBuilder.build_room(r, {})
	add_child_autofree(node)
	assert_eq(node.get_children().filter(func(n): return n is DeepWater).size(), 0)
