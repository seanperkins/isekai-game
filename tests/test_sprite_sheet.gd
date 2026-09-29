extends GutTest
## The generated sheet: every listed frame is there, at its width, on the floor line, in a consistent
## scale, with hit shapes that hug the drawn pixels.

const FRAMES := "res://tools/art/slime_frames.json"

var sheet: SpriteSheet
var listed: Array = []

func before_all() -> void:
	sheet = SpriteSheet.load_set("slime")
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(FRAMES))
	listed = json.data["frames"]

func test_the_sheet_loads_and_lists_every_frame() -> void:
	assert_true(SpriteSheet.available("slime"))
	assert_false(SpriteSheet.available("no_such_set"))
	assert_null(SpriteSheet.load_set("no_such_set"))
	assert_eq(sheet.frame_names().size(), listed.size())
	for f in listed:
		assert_true(sheet.has_frame(f["name"]), f["name"])

func test_frames_are_their_listed_width_and_inside_the_sheet() -> void:
	var whole := sheet.texture.get_size()
	for f in listed:
		var size := sheet.frame_size(f["name"])
		assert_eq(int(size.x), int(f["width"]), f["name"])
		var t := sheet.frame_texture(f["name"]) as AtlasTexture
		assert_true(Rect2(Vector2.ZERO, whole).encloses(t.region), f["name"])
		assert_eq(t.region.size, size)

func test_the_frame_texture_is_cached() -> void:
	assert_same(sheet.frame_texture("idle_1"), sheet.frame_texture("idle_1"))

func test_every_frame_touches_the_floor_line() -> void:
	for f in listed:
		var hurt := sheet.hurt(f["name"])
		var lowest := -INF
		for p in hurt:
			lowest = maxf(lowest, p.y)
		assert_almost_eq(lowest, 0.0, 0.01, "%s: the shape's lowest point is the frame's bottom" % f["name"])

func test_hurt_shapes_are_inside_the_frame_and_have_substance() -> void:
	for f in listed:
		var size := sheet.frame_size(f["name"])
		var hurt := sheet.hurt(f["name"])
		assert_gte(hurt.size(), 3, f["name"])
		for p in hurt:
			assert_between(p.x, -size.x / 2.0 - 0.01, size.x / 2.0 + 0.01, f["name"])
			assert_between(p.y, -size.y - 0.01, 0.01, f["name"])

func test_the_hurt_shape_hugs_the_drawn_pixels() -> void:
	var img := sheet.texture.get_image()
	for name in ["idle_1", "spread_2", "tackle", "cover_3"]:
		var t := sheet.frame_texture(name) as AtlasTexture
		var hurt := sheet.hurt(name)
		var inflated: PackedVector2Array = Geometry2D.offset_polygon(hurt, 0.6)[0]
		var opaque := 0
		var inside := 0
		for y in int(t.region.size.y):
			for x in int(t.region.size.x):
				if img.get_pixel(int(t.region.position.x) + x, int(t.region.position.y) + y).a < 0.5:
					continue
				opaque += 1
				var local := Vector2(x + 0.5 - t.region.size.x / 2.0, y + 0.5 - t.region.size.y)
				if Geometry2D.is_point_in_polygon(local, inflated):
					inside += 1
		assert_eq(inside, opaque, "%s: every drawn pixel is inside its hurt shape" % name)
		assert_lt(_area(hurt), opaque * 1.7, "%s: the shape does not balloon past the art" % name)

func test_only_the_tackle_has_an_attack_shape_and_it_is_in_front() -> void:
	for f in listed:
		var attack := sheet.attack(f["name"])
		if f.has("attack_from"):
			assert_gte(attack.size(), 3, f["name"])
			for p in attack:
				assert_gte(p.x, -sheet.frame_size(f["name"]).x / 2.0 + f["attack_from"] * sheet.frame_size(f["name"]).x - 0.01, f["name"])
		else:
			assert_eq(attack.size(), 0, f["name"])

func test_the_poses_have_the_proportions_their_names_promise() -> void:
	var idle := sheet.frame_size("idle_1")
	assert_eq(int(idle.x), 44)
	assert_gt(sheet.frame_size("rise").y, idle.y, "rising is taller than resting")
	assert_lt(sheet.frame_size("land").y, idle.y, "landing is flatter")
	assert_lt(sheet.frame_size("spread_2").y, idle.y * 0.6, "the puddle is flat")
	assert_gt(sheet.frame_size("spread_2").x, idle.x, "and wide")
	assert_gt(sheet.frame_size("tackle").x, idle.x, "the tackle is stretched")
	assert_gt(sheet.frame_size("rope").y, idle.y, "hanging on a thread is stretched tall")

func test_frames_stay_in_a_consistent_scale() -> void:
	var idle := sheet.frame_size("idle_1")
	for f in listed:
		var h := sheet.frame_size(f["name"]).y
		assert_between(h, idle.y * 0.25, idle.y * 1.8, "%s (%d px) drifted from the idle scale (%d px)" % [f["name"], h, idle.y])

func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5
