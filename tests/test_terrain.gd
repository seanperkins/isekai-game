extends GutTest
## Terrain art, the painter and the parallax stack.

## The full parallax stack is off in the shipped game for now (RoomBuilder.simple_layers); these tests keep it working.
func before_each() -> void:
	RoomBuilder.simple_layers = false

func after_each() -> void:
	RoomBuilder.simple_layers = true

const BIOMES := ["cave", "grotto", "flooded"]
const LAYERS := ["far_haze", "far_rock", "mid_rock", "foreground"]
const PIECES := ["fill_a", "backwall", "cap_top", "cap_bottom", "edge_left", "ledge_l", "ledge_m", "ledge_r"]

func test_every_biome_has_every_piece() -> void:
	for b in BIOMES:
		for p in PIECES:
			assert_not_null(TerrainArt.tile(b, p), "%s/%s" % [b, p])
		for l in LAYERS:
			assert_not_null(TerrainArt.layer(b, l), "%s/%s" % [b, l])

func test_stone_fill_repeats_every_four_tiles_and_layers_fill_the_screen() -> void:
	for b in BIOMES:
		assert_eq(TerrainArt.tile(b, "fill_a").get_size(), Vector2(128, 128))
		assert_eq(TerrainArt.tile(b, "backwall").get_size(), Vector2(128, 128))
		for l in LAYERS:
			var size := TerrainArt.layer(b, l).get_size()
			assert_eq(size.y, 360.0, l)
			assert_eq(fmod(size.x, 640.0), 0.0, "%s is a whole number of screens wide" % l)
		assert_eq(TerrainArt.layer(b, "foreground").get_size(), Vector2(640, 360))

func test_wrapping_pieces_have_no_visible_seam() -> void:
	for b in BIOMES:
		for l in ["far_haze", "far_rock", "mid_rock"]:  # the foreground is a frame, not a loop
			assert_true(_seam_ok(TerrainArt.layer(b, l).get_image(), true), l)
		for p in ["cap_top", "cap_bottom", "ledge_m"]:
			assert_true(_seam_ok(TerrainArt.tile(b, p).get_image(), true), p)
		assert_true(_seam_ok(TerrainArt.tile(b, "edge_left").get_image(), false), "edge_left")
		for p in ["fill_a", "backwall"]:
			var img := TerrainArt.tile(b, p).get_image()
			assert_true(_seam_ok(img, true), p)
			assert_true(_seam_ok(img, false), p)

func test_no_magenta_survives_in_terrain_art() -> void:
	for b in BIOMES:
		var images := {}
		for p in PIECES:
			images[p] = TerrainArt.tile(b, p).get_image()
		for l in LAYERS:
			images[l] = TerrainArt.layer(b, l).get_image()
		for piece in images:
			var img: Image = images[piece]
			var fringe := 0
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.0 and c.r > 0.92 and c.b > 0.92 and c.g < 0.2:  # pure background magenta; pink and violet art has more green
						fringe += 1
			assert_eq(fringe, 0, "%s/%s" % [b, piece])

func test_strips_report_where_their_surface_is() -> void:
	for p in ["cap_top", "cap_bottom", "edge_left", "ledge"]:
		var m := TerrainArt.meta("cave", p)
		assert_true(m.has("surface"), p)

func test_a_floor_shows_a_lip_on_top_and_none_on_the_room_boundary() -> void:
	var bounds := Rect2(0, 0, 640, 360)
	var floor_rect := Rect2(0, 320, 640, 40)
	var left_wall := Rect2(0, 0, 20, 360)
	var all := [floor_rect, left_wall]
	# The top of the floor is open air, except where the wall stands on it.
	assert_eq(TerrainPainter._open(floor_rect, "top", all, bounds), [Vector2(20, 640)])
	assert_eq(TerrainPainter._open(floor_rect, "bottom", all, bounds), [])
	assert_eq(TerrainPainter._open(floor_rect, "left", all, bounds), [])
	assert_eq(TerrainPainter._open(left_wall, "left", all, bounds), [])
	assert_eq(TerrainPainter._open(left_wall, "right", all, bounds), [Vector2(0, 320)])

func test_an_exit_gap_exposes_a_face() -> void:
	var bounds := Rect2(0, 0, 640, 360)
	var above := Rect2(0, 0, 20, 200)  # left wall above an exit that spans y 200..320
	var below := Rect2(0, 320, 20, 40)
	assert_eq(TerrainPainter._open(above, "bottom", [above, below], bounds), [Vector2(0, 20)])
	assert_eq(TerrainPainter._open(below, "top", [above, below], bounds), [Vector2(0, 20)])

func test_ledges_are_cut_from_three_pieces_and_gates_carry_their_art() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var c6: RoomDef = rooms["C6"]
	var closed := RoomBuilder.build_room(c6, {"progress": null})
	add_child_autofree(closed)
	var gates := closed.get_children().filter(func(n): return n.is_in_group("gate_c6_drop"))
	assert_eq(gates.size(), 1)
	assert_not_null(gates[0].get_node_or_null("Terrain"), "the gate paints itself, so opening it removes the art")
	var main_paint := closed.get_node("Terrain")
	assert_gt(main_paint.get_child_count(), 3)

func test_painted_rooms_have_a_full_depth_stack() -> void:
	var node := RoomBuilder.build_room(World.load_rooms("res://data/rooms")["C2"], {})
	add_child_autofree(node)
	for l in LAYERS:
		assert_true(node.get_node(l) is TerrainParallax, l)
	assert_lt(node.get_node("far_haze").factor, node.get_node("mid_rock").factor)
	assert_eq(node.get_node("foreground").factor, 0.0, "the foreground frame is glued to the screen")
	assert_lt(node.get_node("far_haze").z_index, node.get_node("BackWall").z_index)
	# The sprites draw at the layer's z: top-level nodes ignore the parent's.
	for l in LAYERS:
		assert_eq(node.get_node(l).get_child(0).z_index, node.get_node(l).z_index, l)
	assert_lt(node.get_node("foreground").z_index, 0, "the foreground frame is behind terrain, decor and actors (z 0 and up)")
	assert_gt(node.get_node("foreground").z_index, node.get_node("BackWall").z_index, "but in front of the back wall and the far layers")

func test_a_layer_always_covers_the_view_and_slides_at_its_factor() -> void:
	var width := 640.0
	for cx in [320.0, 1000.0, 5000.0, -700.0]:
		var origin := TerrainParallax.layer_origin(Vector2(cx, 400), 0.25, width)
		# The repeating region spans width + one screen from the origin, so it covers the view.
		assert_lte(origin.x, cx - 320.0, "left edge at %s" % cx)
		assert_gte(origin.x + width + 640.0, cx + 320.0, "right edge at %s" % cx)
		assert_eq(origin.y, 400.0 - 180.0, "screen-fixed vertically")
	# Moving the camera 100 px moves a 0.25 layer 25 px on screen: its origin trails by 75 px.
	var a := TerrainParallax.layer_origin(Vector2(1000, 0), 0.25, 640.0)
	var b := TerrainParallax.layer_origin(Vector2(1100, 0), 0.25, 640.0)
	assert_almost_eq((b.x - a.x), 75.0, 0.01)

func test_far_layers_ignore_point_lights() -> void:
	var node := RoomBuilder.build_room(World.load_rooms("res://data/rooms")["C1"], {})
	add_child_autofree(node)
	for l in ["far_haze", "far_rock", "mid_rock"]:
		assert_eq(node.get_node(l).light_mask, TerrainLayers.UNLIT_MASK)
	assert_ne(TerrainLayers.UNLIT_MASK & 1, 1, "PointLight2D defaults to cull mask bit 1")

## Every room decor id has a sprite, and nothing in the wilderness burns.
func test_room_decor_has_art_and_no_torch() -> void:
	for id in World.load_rooms("res://data/rooms"):
		var def: RoomDef = World.load_rooms("res://data/rooms")[id]
		for d in def.decor:
			assert_ne(d["id"], "torch", id)
			assert_not_null(Art.texture(d["id"]), "%s decor %s" % [id, d["id"]])

## The wrap seam differs no more than three times what neighbouring columns (or rows) differ on
## average across the whole image.
func _seam_ok(img: Image, horizontal: bool) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var lines := h if horizontal else w   # number of rows (or columns) compared
	var span := w if horizontal else h    # length along the wrap direction
	var seam := 0.0
	for i in lines:
		seam += _diff(_px(img, 0, i, horizontal), _px(img, span - 1, i, horizontal))
	var inner := 0.0
	var pairs := 0
	for k in range(0, span - 1, 3):
		for i in range(0, lines, 2):
			inner += _diff(_px(img, k, i, horizontal), _px(img, k + 1, i, horizontal))
			pairs += 1
	return seam / lines <= 3.0 * inner / pairs + 0.01

func _px(img: Image, along: int, line: int, horizontal: bool) -> Color:
	return img.get_pixel(along, line) if horizontal else img.get_pixel(line, along)

func _diff(a: Color, b: Color) -> float:
	if a.a < 0.5 and b.a < 0.5:
		return 0.0
	if (a.a < 0.5) != (b.a < 0.5):
		return 1.0
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0

func test_painted_rooms_drift_with_motes_and_plain_rooms_do_not() -> void:
	var def: RoomDef = World.load_rooms("res://data/rooms")["C1"]
	var node := RoomBuilder.build_room(def, {})
	add_child_autofree(node)
	var motes: CPUParticles2D = node.get_node("Motes")
	assert_gt(motes.amount, 8)
	assert_eq(motes.emission_rect_extents, def.pixel_size() / 2.0)
	var plain: RoomDef = def.duplicate()
	plain.area = "nowhere"
	var flat := RoomBuilder.build_room(plain, {})
	add_child_autofree(flat)
	assert_null(flat.get_node_or_null("Motes"))

func test_each_biome_sets_its_own_ambient_light() -> void:
	var fallback := Color(0.1, 0.2, 0.3)
	assert_gt(TerrainArt.ambient("cave", fallback).v, TerrainArt.ambient("deep", fallback).v, "the Cave is brighter than the deep")
	assert_gt(TerrainArt.ambient("cave", fallback).v, 0.85)
	assert_eq(TerrainArt.ambient("elsewhere", fallback), fallback)

## Platforms must not melt into the backdrop: the topmost pixel of every column is a dark outline.
func test_platform_edges_carry_a_dark_outline() -> void:
	for b in BIOMES:
		for piece in ["ledge_m", "cap_top"]:
			var img := TerrainArt.tile(b, piece).get_image()
			var dark := 0
			var columns := 0
			for x in img.get_width():
				for y in img.get_height():
					var c := img.get_pixel(x, y)
					if c.a > 0.5:
						columns += 1
						if c.get_luminance() < 0.2:
							dark += 1
						break
			assert_gt(columns, img.get_width() * 0.9, "%s/%s has a top edge" % [b, piece])
			assert_gt(float(dark) / float(columns), 0.9, "%s/%s top edge is outlined" % [b, piece])

func test_the_backdrop_is_dimmer_than_the_play_plane_and_the_frame_never_hides_a_ledge() -> void:
	var stack := TerrainLayers.STACK
	assert_lt(stack["mid_rock"][2].v, stack["far_rock"][2].v)
	assert_lt(stack["far_rock"][2].v, stack["far_haze"][2].v)
	assert_lt(stack["foreground"][2].a, 0.8, "the foreground frame is see-through")

func test_short_faces_get_a_clean_outline_and_tall_faces_the_stone_strip() -> void:
	var bounds := Rect2(0, 0, 640, 360)
	var step := Rect2(200, 100, 100, 32)      # a 32 px step: too short for the ragged strip
	var pillar := Rect2(400, 100, 40, 200)    # a tall face
	var root := TerrainPainter.paint(Node2D.new(), [{"rect": step, "kind": "ground"}, {"rect": pillar, "kind": "ground"}], bounds, "cave")
	add_child_autofree(root.get_parent())
	var lines := root.get_children().filter(func(n): return n is ColorRect)
	assert_eq(lines.size(), 2, "one outline per open side of the short step")
	for l in lines:
		assert_true(step.grow(1.0).encloses(Rect2(l.position, l.size)))
	var strips := root.get_children().filter(func(n): return n is Sprite2D and n.texture == TerrainArt.tile("cave", "edge_left"))
	assert_eq(strips.size(), 2, "the tall pillar keeps a ragged strip on each side")

## A strip laid over the fill must not end in a straight line of mismatched stone: below the shell,
## only moss may remain, so most of the strip's last row is empty.
func test_strips_are_shells_that_follow_the_silhouette() -> void:
	for piece in ["cap_top"]:
		var img := TerrainArt.tile("cave", piece).get_image()
		var last := img.get_height() - 1
		var solid := 0
		for x in img.get_width():
			if img.get_pixel(x, last).a > 0.5:
				solid += 1
		assert_lt(solid, img.get_width() * 0.35, "%s: the last row is mostly empty" % piece)

func test_each_biome_moves_its_air_differently() -> void:
	var cave := TerrainMotes.style("cave")
	var grotto := TerrainMotes.style("grotto")
	var flooded := TerrainMotes.style("flooded")
	assert_true(flooded["ring"], "the Flooded Tunnels have bubbles")
	assert_false(cave["ring"])
	assert_lt(flooded["dir"].y, 0.0, "bubbles rise")
	assert_gt(grotto["gravity"].y, 0.0, "spores sink")
	assert_gt(grotto["amount"], cave["amount"], "the Grotto is thick with spores")
	assert_ne(cave["colors"], grotto["colors"])
	assert_ne(grotto["colors"], flooded["colors"])

func test_biomes_whose_platforms_match_the_backdrop_hue_get_a_darker_backdrop() -> void:
	for biome in BIOMES:
		var dim := TerrainArt.backdrop_dim(biome)
		assert_between(dim, 0.4, 1.0, biome)
	assert_lt(TerrainArt.backdrop_dim("flooded"), TerrainArt.backdrop_dim("cave"), "teal platforms on teal water need contrast")
