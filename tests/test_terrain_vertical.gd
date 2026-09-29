extends GutTest
## Tall rooms: the backdrop layers move vertically too, each at its own factor, so a three-screen
## shaft has real depth. The layer art is extended (its middle band repeats) to cover the travel, with
## the ceiling fringe at the room's top and the floor formations at its bottom, and no camera
## position ever exposes a gap.

const VIEW := Vector2(640, 360)

func _src(biome: String = "cave", piece: String = "far_rock") -> Texture2D:
	return TerrainArt.layer(biome, piece)

func test_a_one_screen_room_uses_the_original_art_untouched() -> void:
	var src := _src()
	assert_same(TerrainLayers.tall_texture(src, 360), src)
	assert_same(TerrainLayers.tall_texture(src, 200), src, "never shrinks")

func test_a_taller_layer_keeps_the_ceiling_on_top_and_the_floor_on_the_bottom() -> void:
	var src := _src()
	var tall := TerrainLayers.tall_texture(src, 700)
	assert_eq(tall.get_height(), 700)
	assert_eq(tall.get_width(), src.get_width())
	var a := src.get_image()
	var b := tall.get_image()
	var band := int(TerrainLayers.KEEP_TOP)
	for x in range(0, a.get_width(), 37):
		for y in range(0, band, 7):
			assert_eq(b.get_pixel(x, y), a.get_pixel(x, y), "ceiling rows are the source's top rows")
		for y in range(1, int(TerrainLayers.KEEP_BOTTOM) + 1, 7):
			assert_eq(b.get_pixel(x, 700 - y), a.get_pixel(x, a.get_height() - y), "floor rows are the source's bottom rows")

func test_the_extended_middle_is_smooth_haze_not_a_mirrored_copy_of_the_art() -> void:
	var src := _src()
	var tall := TerrainLayers.tall_texture(src, 1000).get_image()
	var first := int(TerrainLayers.KEEP_TOP + TerrainLayers.FADE_ROWS)
	var last := 1000 - int(TerrainLayers.KEEP_BOTTOM + TerrainLayers.FADE_ROWS)
	assert_gt(last - first, 100, "the setup: there is a smear to test")
	for x in range(0, tall.get_width(), 23):
		var c := tall.get_pixel(x, first + 10)
		for y in range(first + 10, last - 10, 17):
			assert_eq(tall.get_pixel(x, y), c, "column %d is constant through the smear (no repeated rocks or arches)" % x)

func test_the_smear_joins_the_art_without_a_hard_edge() -> void:
	var src := _src()
	var tall := TerrainLayers.tall_texture(src, 800).get_image()
	var a := src.get_image()
	var top := int(TerrainLayers.KEEP_TOP)
	var bottom := int(TerrainLayers.KEEP_BOTTOM)
	var fade := int(TerrainLayers.FADE_ROWS)
	var worst_top := 0.0
	var worst_bottom := 0.0
	for x in range(0, tall.get_width(), 11):
		# the first faded row is nearly the source's row, the last is nearly the smear
		worst_top = maxf(worst_top, _dist(tall.get_pixel(x, top), a.get_pixel(x, top)))
		worst_bottom = maxf(worst_bottom, _dist(tall.get_pixel(x, 800 - bottom - 1), a.get_pixel(x, a.get_height() - bottom - 1)))
	assert_lt(worst_top, 0.35, "no jump from the ceiling art into the fade")
	assert_lt(worst_bottom, 0.35, "no jump from the fade into the floor art")
	assert_gt(fade, 10)

## Largest channel difference once each colour is premultiplied by its alpha (what is actually seen:
## the colour under a transparent pixel does not count).
func _dist(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r * a.a - b.r * b.a), absf(a.g * a.a - b.g * b.a)), maxf(absf(a.b * a.a - b.b * b.a), absf(a.a - b.a)))

func test_the_tall_texture_is_built_once() -> void:
	var src := _src()
	assert_same(TerrainLayers.tall_texture(src, 640), TerrainLayers.tall_texture(src, 640))

func test_the_layer_height_covers_the_camera_travel_for_its_factor() -> void:
	assert_eq(TerrainLayers.layer_height(0.25, 360.0), 360)
	assert_eq(TerrainLayers.layer_height(0.25, 1080.0), 540)   # 360 + 0.25 * 720
	assert_eq(TerrainLayers.layer_height(0.5, 720.0), 540)
	assert_eq(TerrainLayers.layer_height(0.0, 1080.0), 360, "the glued frame needs no extra")

func test_at_the_top_of_a_room_the_layer_top_meets_the_screen_top() -> void:
	var room_top := 1000.0
	var cam_center := Vector2(300, room_top + VIEW.y / 2.0)
	var o := TerrainParallax.layer_origin(cam_center, 0.5, 640.0, room_top, 1080.0)
	assert_almost_eq(o.y, room_top, 0.001)

func test_at_the_bottom_of_a_room_the_layer_bottom_meets_the_screen_bottom() -> void:
	var room_top := 1000.0
	var room_h := 1080.0
	var f := 0.5
	var cam_center := Vector2(300, room_top + room_h - VIEW.y / 2.0)
	var o := TerrainParallax.layer_origin(cam_center, f, 640.0, room_top, room_h)
	var h := float(TerrainLayers.layer_height(f, room_h))
	assert_almost_eq(o.y + h, room_top + room_h, 0.001)

func test_moving_the_camera_moves_a_layer_at_its_factor() -> void:
	var room_top := 0.0
	var room_h := 1080.0
	var a := TerrainParallax.layer_origin(Vector2(0, 180), 0.25, 640.0, room_top, room_h)
	var b := TerrainParallax.layer_origin(Vector2(0, 180 + 400), 0.25, 640.0, room_top, room_h)
	# the camera went down 400, so the world moved up 400 on screen; the layer moved up only 0.25 * 400
	var screen_a := a.y - (180.0 - VIEW.y / 2.0)
	var screen_b := b.y - (180.0 + 400.0 - VIEW.y / 2.0)
	assert_almost_eq(screen_b - screen_a, -100.0, 0.001)

func test_no_camera_position_ever_exposes_a_gap() -> void:
	var room_top := 500.0
	for room_h in [360.0, 720.0, 1080.0]:
		for f in [0.10, 0.25, 0.5]:
			var h := float(TerrainLayers.layer_height(f, room_h))
			# from a screen above the room to a screen below it (the camera slides during a transition)
			var cy := room_top - 300.0
			while cy < room_top + room_h + 300.0:
				var o := TerrainParallax.layer_origin(Vector2(0, cy), f, 640.0, room_top, room_h)
				var view_top := cy - VIEW.y / 2.0
				assert_lte(o.y, view_top + 0.001, "room_h %d f %.2f: a gap above at cam %d" % [room_h, f, cy])
				assert_gte(o.y + h, view_top + VIEW.y - 0.001, "room_h %d f %.2f: a gap below at cam %d" % [room_h, f, cy])
				cy += 41.0

func test_a_built_tall_room_has_extended_far_layers_and_a_one_screen_frame() -> void:
	var node := RoomBuilder.build_room(World.load_rooms("res://data/rooms")["C5"], {})  # 1x3 screens
	add_child_autofree(node)
	assert_eq(node.get_node("far_rock").texture.get_height(), TerrainLayers.layer_height(0.25, 1080.0))
	assert_eq(node.get_node("mid_rock").texture.get_height(), TerrainLayers.layer_height(0.5, 1080.0))
	assert_eq(node.get_node("foreground").texture.get_height(), 360, "the screen-glued frame stays one screen")

func test_a_built_one_screen_room_is_unchanged() -> void:
	var node := RoomBuilder.build_room(World.load_rooms("res://data/rooms")["C2"], {})
	add_child_autofree(node)
	assert_eq(node.get_node("far_rock").texture.get_height(), 360)
