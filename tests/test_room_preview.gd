extends GutTest
## RoomPreview: a schematic of a room or the world, drawn on the CPU (the headless renderer has no texture to read back) and a text
## map of the same. The room used here is synthetic so every pixel and character is known.

func _room() -> RoomDef:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "cave"
	r.size = Vector2i(1, 1)
	r.solids = [Rect2(200, 200, 80, 12)]
	r.water = [Rect2(400, 200, 64, 64)]
	r.spawns = [{"id": "toad", "pos": Vector2(100, 100)}]
	r.features = [{"kind": "glow_pool", "id": "t1_glow_pool_1", "pos": Vector2(300, 320)}]
	r.decor = [{"id": "rubble", "pos": Vector2(500, 320)}]
	r.exits = [{"edge": "right", "from": 100.0, "to": 180.0, "room": "T2"}]
	return r

func _px(img: Image, world: Vector2, scale := 0.5) -> Color:
	return img.get_pixelv(Vector2i(world * scale))

func _rows(text: String) -> Array:
	return Array(text.split("\n")).slice(1).map(func(l: String) -> String: return l.substr(3))

func test_the_image_is_one_pixel_per_two_world_pixels_and_each_thing_has_its_colour() -> void:
	var img := RoomPreview.image(_room(), 0.5)
	assert_eq(img.get_size(), Vector2i(320, 180))
	assert_eq(_px(img, Vector2(240, 206)), RoomPreview.C_SOLID)
	assert_eq(_px(img, Vector2(320, 100)), RoomPreview.C_AIR)
	assert_eq(_px(img, Vector2(432, 232)), RoomPreview.C_WATER)
	assert_eq(_px(img, Vector2(100, 100)), RoomPreview.C_SPAWN)
	assert_eq(_px(img, Vector2(630, 140)), RoomPreview.C_EXIT, "the exit's gap in the wall")
	assert_eq(_px(img, Vector2(630, 300)), RoomPreview.C_SOLID, "the wall elsewhere")

func test_exit_gaps_are_tinted_by_what_they_need() -> void:
	var r := _room()
	r.exits = [{"edge": "right", "from": 100.0, "to": 180.0, "room": "T2", "gate": "swim"},
		{"edge": "right", "from": 200.0, "to": 280.0, "room": "T3", "shortcut": "s1"}]
	var img := RoomPreview.image(r, 0.5)
	assert_eq(_px(img, Vector2(630, 140)), RoomPreview.C_GATE_SWIM)
	assert_eq(_px(img, Vector2(630, 240)), RoomPreview.C_SHORTCUT)

func test_the_start_and_hard_ledges_are_marked() -> void:
	var r := _room()
	r.start = Vector2(40, 300)
	r.hard_ledges = [r.solids[0]]
	var img := RoomPreview.image(r, 0.5)
	assert_eq(_px(img, Vector2(40, 300)), RoomPreview.C_START)
	assert_eq(_px(img, Vector2(240, 200)), RoomPreview.C_HARD, "a hard ledge is outlined")
	assert_eq(_px(img, Vector2(240, 206)), RoomPreview.C_SOLID)

func test_a_huge_room_is_clamped() -> void:
	var r := _room()
	r.size = Vector2i(6, 6)
	assert_lte(RoomPreview.clamp_scale(r, 1.0), 2000.0 / 3840.0 + 0.0001)
	var img := RoomPreview.image(r, 1.0)
	assert_lte(maxi(img.get_width(), img.get_height()), RoomPreview.MAX_SIDE)
	assert_eq(RoomPreview.clamp_scale(_room(), 0.01), 0.25)
	assert_eq(RoomPreview.clamp_scale(_room(), 1.0), 1.0)

func test_the_text_map() -> void:
	var text := RoomPreview.text_map(_room())
	var lines := text.split("\n")
	assert_eq(lines.size(), 10, "a ruler and nine rows")
	var rows := _rows(text)
	assert_eq(rows[5].substr(5, 2), "##", "the 80 px solid at x 200 to 280")
	assert_eq(rows[2][2], "S")
	assert_eq(rows[5][10], "~")
	assert_eq(rows[8], "#".repeat(16), "the floor")
	assert_eq(rows[3][15], "=", "the exit gap in the right wall at y 100 to 180")
	assert_eq(rows[7][7], "F", "the glow pool stands on the floor, in the cell above its base")
	assert_eq(rows[7][12], "d")

func test_a_wide_room_uses_bigger_cells() -> void:
	var r := _room()
	r.size = Vector2i(4, 1)
	var rows := _rows(RoomPreview.text_map(r))
	assert_eq(rows.size(), 5)
	assert_eq(rows[0].length(), 32)

func test_the_legend_lists_what_the_picture_cannot_label() -> void:
	var text := RoomPreview.legend(_room())
	assert_true(text.contains("[0] toad @ 100,100"), text)
	assert_true(text.contains("[0] glow_pool t1_glow_pool_1 @ 300,320"), text)
	assert_true(text.contains("[0] right 100-180 -> T2"), text)

func _world() -> Dictionary:
	var a := _room()
	a.id = "A1"
	var b := _room()
	b.id = "B1"
	b.cell = Vector2i(1, 0)
	return {"A1": a, "B1": b}

func test_the_world_grid_shows_the_covering_room_in_each_screen() -> void:
	assert_eq(RoomPreview.world_grid(_world()), "A1 B1")
	var wide := _world()
	wide["A1"].size = Vector2i(2, 1)
	wide["B1"].cell = Vector2i(2, 0)
	assert_eq(RoomPreview.world_grid(wide), "A1 A1 B1")

func test_a_dirty_room_is_outlined_in_the_world_image() -> void:
	var count := func(img: Image) -> int:
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y) == RoomPreview.C_DIRTY:
					n += 1
		return n
	assert_eq(count.call(RoomPreview.world_image(_world(), {}, 200)), 0)
	assert_gt(count.call(RoomPreview.world_image(_world(), {"A1": true}, 200)), 0)

func test_the_preview_tool() -> void:
	var session := RoomSession.new()
	var tools := RoomTools.new(session)
	var res := tools.call_tool("preview", {"room": "C1"})
	assert_false(res["isError"], str(res))
	assert_eq(res["content"][0]["type"], "image")
	assert_eq(res["content"][0]["mimeType"], "image/png")
	var img := Image.new()
	assert_eq(img.load_png_from_buffer(Marshalls.base64_to_raw(res["content"][0]["data"])), OK)
	var size: Vector2i = (session.model.rooms["C1"] as RoomDef).size
	assert_eq(img.get_size(), Vector2i(size.x * 320, size.y * 180))
	assert_eq(res["content"][1]["type"], "text")
	assert_true(res["content"][1]["text"].contains("exits"))
	var no_text := tools.call_tool("preview", {"room": "C1", "text": false})
	assert_eq(no_text["content"].size(), 1)
	var world := tools.call_tool("preview", {})
	assert_eq(world["content"][0]["type"], "image")
	assert_true(world["content"][1]["text"].contains("%d rooms" % ShippedRooms.IDS.size()))
	assert_eq(tools.call_tool("preview", {"room": "Z9"})["content"][0]["text"], "no room 'Z9'")
