extends GutTest
## Plan: boss arenas, Task 6. The glimpse: a creature's own sheet frame as a dark silhouette behind the room's solids, drifting slowly.

func _def(area: String, glimpse := {"creature": "taratect", "pos": Vector2(300, 150), "scale": 2.4}) -> RoomDef:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = area
	r.solids = [Rect2(100, 280, 200, 40)]
	r.glimpse = glimpse
	return r

func test_the_glimpse_is_the_creatures_own_frame_dark_and_scaled() -> void:
	var g := Glimpse.make({"creature": "taratect", "pos": Vector2(300, 150), "scale": 2.4})
	add_child_autofree(g)
	var sheet := SpriteSheet.load_set("taratect")
	assert_eq((g.texture as AtlasTexture).region, (sheet.frame_texture(sheet.frame_names()[0]) as AtlasTexture).region, "the sheet's first frame")
	assert_eq(g.scale, Vector2(2.4, 2.4))
	assert_eq(g.position, Vector2(300, 150))
	assert_almost_eq(g.modulate.a, 0.7, 0.001)
	assert_lt(g.modulate.r, 0.15, "near black")
	var named := Glimpse.make({"creature": "taratect", "pos": Vector2.ZERO, "scale": 1.0, "frame": "drop"})
	add_child_autofree(named)
	assert_eq((named.texture as AtlasTexture).region, (sheet.frame_texture("drop") as AtlasTexture).region, "a named frame")

func test_it_is_drawn_behind_the_rooms_solids_in_painted_and_unpainted_rooms() -> void:
	for area in ["plain", "deep"]:
		var node := RoomBuilder.build_room(_def(area), {})
		add_child_autofree(node)
		var kids := node.get_children()
		var glimpse_at := -1
		var first_solid := -1
		for k in kids.size():
			if kids[k] is Glimpse and glimpse_at < 0:
				glimpse_at = k
			if kids[k] is StaticBody2D and first_solid < 0:
				first_solid = k
		assert_gte(glimpse_at, 0, "%s: the room has its glimpse" % area)
		assert_lt(glimpse_at, first_solid, "%s: its child index is below the first solid's" % area)
	assert_true(TerrainArt.has_biome("deep"), "the painted case was really tested")

func test_it_drifts_but_stays_inside_the_room() -> void:
	var def := _def("plain")
	var g := Glimpse.make(def.glimpse)
	add_child_autofree(g)
	var base: Vector2 = g.position
	var moved := false
	var bounds := Rect2(Vector2.ZERO, def.pixel_size())
	for k in 400:
		g._process(0.1)  # 40 s
		moved = moved or g.position != base
		assert_true(bounds.has_point(g.position), "inside the room at step %d" % k)
	assert_true(moved)
	assert_lt((g.position - base).length(), Glimpse.DRIFT * 2.0, "a slow drift, not a wander")

func test_a_room_with_no_glimpse_has_none() -> void:
	var def := _def("plain", {})
	var node := RoomBuilder.build_room(def, {})
	add_child_autofree(node)
	assert_eq(node.get_children().filter(func(n: Node) -> bool: return n is Glimpse).size(), 0)
