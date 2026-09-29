extends GutTest
## Hurt and attack shapes follow the drawn frame. Inert: nothing collides with them yet.

var sheet: SpriteSheet
var shapes: SlimeShapes

func before_each() -> void:
	sheet = SpriteSheet.load_set("slime")
	shapes = SlimeShapes.new()
	add_child_autofree(shapes)

func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

func test_the_hurt_shape_is_the_frames_traced_shape() -> void:
	shapes.refresh(sheet, "idle_1", false)
	assert_eq(shapes.hurt_poly.polygon, sheet.hurt("idle_1"))
	var b := _bounds(shapes.hurt_poly.polygon)
	assert_almost_eq(b.size.x, 44.0, 2.0)

func test_spread_is_flat_and_wide() -> void:
	shapes.refresh(sheet, "idle_1", false)
	var idle := _bounds(shapes.hurt_poly.polygon)
	shapes.refresh(sheet, "spread_2", false)
	var flat := _bounds(shapes.hurt_poly.polygon)
	assert_lt(flat.size.y, idle.size.y * 0.6)
	assert_gt(flat.size.x, idle.size.x)

func test_only_a_frame_with_an_attack_region_enables_the_attack_shape() -> void:
	shapes.refresh(sheet, "idle_1", false)
	assert_eq(shapes.attack_poly.polygon.size(), 0)
	assert_true(shapes.attack_poly.disabled)
	shapes.refresh(sheet, "tackle", false)
	assert_gte(shapes.attack_poly.polygon.size(), 3)
	assert_false(shapes.attack_poly.disabled)
	assert_gt(_bounds(shapes.attack_poly.polygon).get_center().x, 0.0, "the attack is at the front")

func test_facing_left_mirrors_both_shapes() -> void:
	shapes.refresh(sheet, "tackle", false)
	var hurt_right := _bounds(shapes.hurt_poly.polygon)
	var attack_right := _bounds(shapes.attack_poly.polygon)
	shapes.refresh(sheet, "tackle", true)
	assert_almost_eq(_bounds(shapes.hurt_poly.polygon).get_center().x, -hurt_right.get_center().x, 0.01)
	assert_almost_eq(_bounds(shapes.attack_poly.polygon).get_center().x, -attack_right.get_center().x, 0.01)

func test_the_areas_are_inert() -> void:
	for a in [shapes.hurt, shapes.attack]:
		assert_eq(a.collision_layer, 0)
		assert_eq(a.collision_mask, 0)

func test_refreshing_the_same_frame_and_facing_again_does_not_rebuild_the_shapes() -> void:
	shapes.refresh(sheet, "idle_1", false)
	var marker := PackedVector2Array([Vector2(1, 1), Vector2(2, 1), Vector2(2, 2)])
	shapes.hurt_poly.polygon = marker  # a stand-in for "not rebuilt"
	shapes.refresh(sheet, "idle_1", false)
	assert_eq(shapes.hurt_poly.polygon, marker, "unchanged frame and facing: nothing to redo")
	shapes.refresh(sheet, "idle_1", true)
	assert_ne(shapes.hurt_poly.polygon, marker, "a new facing rebuilds")
	shapes.hurt_poly.polygon = marker
	shapes.refresh(sheet, "idle_2", true)
	assert_ne(shapes.hurt_poly.polygon, marker, "a new frame rebuilds")
	shapes.hurt_poly.polygon = marker
	shapes.refresh(SpriteSheet.load_set("slime"), "idle_2", true)
	assert_ne(shapes.hurt_poly.polygon, marker, "a different sheet object rebuilds")
