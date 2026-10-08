extends GutTest
## HeldItemLayer: the two items a goblin holds, drawn on the hands of its body sprite from the `hands` its sheet carries.

const FORM := "goblin_smith"
const SHEET := "anim_goblin_smith"

var _sprite: Sprite2D
var _layer: HeldItemLayer
var _sheet: SpriteSheet

func before_each() -> void:
	_sprite = Sprite2D.new()
	add_child_autofree(_sprite)
	_layer = HeldItemLayer.attach(_sprite)
	_sheet = SpriteSheet.load_set(SHEET)

func _pivot(side: String) -> Node2D:
	return _sprite.get_node("HeldItem" + side.to_upper())

func _art(side: String) -> Sprite2D:
	return _pivot(side).get_child(0)

## A frame of the smith's sheet whose near hand is turned by at least `degrees`.
func _turned_frame(degrees: float) -> String:
	for n in _sheet.frame_names():
		if absf(float(_sheet.hands(n)["n"]["a"])) >= degrees:
			return n
	return ""

func test_attach_makes_one_layer_that_is_not_a_canvas_item_and_two_pivots_on_the_body_itself() -> void:
	assert_eq(HeldItemLayer.attach(_sprite), _layer, "the same layer the second time")
	var as_node: Node = _layer
	assert_false(as_node is CanvasItem, "a node between a canvas item and its canvas children would cut the transform chain")
	for side in ["n", "f"]:
		assert_eq(_pivot(side).get_parent(), _sprite)
	assert_false((_pivot("n") as Node2D).show_behind_parent)
	assert_true((_pivot("f") as Node2D).show_behind_parent, "the far hand's item is drawn behind the body")

func test_set_item_loads_clears_and_refuses_an_unknown_id() -> void:
	assert_true(_layer.set_item("n", "axe"))
	assert_eq(_layer.item("n"), "axe")
	assert_false(_layer.set_item("n", "nonesuch"))
	assert_eq(_layer.item("n"), "axe", "the hand is as it was")
	assert_true(_layer.set_item("n", ""))
	assert_eq(_layer.item("n"), "")

func test_every_held_piece_can_be_swapped_in() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/held_items.json"))
	for id in table["items"]:
		assert_true(_layer.set_item("n", id), id)

func test_follow_puts_the_grip_on_the_hand_using_the_frames_real_height() -> void:
	_layer.bind(FORM)
	_sheet.draw_on(_sprite, "idle_1", false)
	var hand: Dictionary = _sheet.hands("idle_1")["n"]
	var height := _sheet.frame_size("idle_1").y
	assert_gt(height, 20.0)
	assert_eq(_pivot("n").position, Vector2(float(hand["x"]), float(hand["y"]) + height / 2.0), "from the bottom centre to the sprite's centre")
	var item := HeldItems.item("hammer")
	var item_height := SpriteSheet.load_set(item["set"]).frame_size("item").y
	var grip: Vector2 = item["grip"]
	assert_eq(_art("n").offset, -Vector2(grip.x, grip.y + item_height / 2.0), "the grip, not the picture's centre, is on the hand")
	assert_true(_pivot("n").visible and _pivot("f").visible)

func test_facing_left_mirrors_art_normal_position_grip_and_turn() -> void:
	var frame := _turned_frame(3.0)
	assert_ne(frame, "", "a frame with the hand turned")
	_layer.set_item("n", "axe")
	_sheet.draw_on(_sprite, frame, false)
	var right_rot := _pivot("n").rotation
	var right_pos := _pivot("n").position
	var right_off := _art("n").offset
	_sheet.draw_on(_sprite, frame, true)
	assert_eq(_pivot("n").position, Vector2(-right_pos.x, right_pos.y))
	assert_almost_eq(_pivot("n").rotation, -right_rot, 0.0001)
	assert_ne(_pivot("n").rotation, 0.0)
	assert_eq(_art("n").offset, Vector2(-right_off.x, right_off.y), "the grip is mirrored with the picture")
	assert_gt(absf(right_off.x), 0.5, "a grip with a sideways part")
	var axe := SpriteSheet.load_set(HeldItems.item("axe")["set"])
	assert_eq(_art("n").texture, axe.texture_of("item", true), "the lit, mirrored frame: its normal map is mirrored with it")
	assert_ne(_art("n").texture, axe.texture_of("item", false))
	assert_false(_art("n").flip_h, "a sheet with normals is mirrored in the texture, as the body is")

func test_the_near_item_is_not_dimmed_and_the_far_item_is_dimmed_once() -> void:
	_layer.bind(FORM)
	_sheet.draw_on(_sprite, "idle_1", false)
	assert_eq(_art("n").modulate, Color(1, 1, 1))
	assert_eq(_art("f").modulate, Color(HeldItemLayer.FAR_DIM, HeldItemLayer.FAR_DIM, HeldItemLayer.FAR_DIM))
	assert_eq(HeldItemLayer.FAR_DIM, 0.8)

func test_a_frame_without_hands_hides_the_items() -> void:
	_layer.bind(FORM)
	_sheet.draw_on(_sprite, "idle_1", false)
	assert_true(_pivot("n").visible)
	var plain := SpriteSheet.load_set("slime")
	plain.draw_on(_sprite, plain.frame_names()[0], false)
	assert_false(_pivot("n").visible)
	assert_false(_pivot("f").visible)

func test_each_pivot_is_scaled_by_the_forms_scale_and_inherits_the_sprites() -> void:
	_layer.bind(FORM)
	_sprite.position = Vector2(100.0, 50.0)
	_sprite.scale = Vector2(2.0, 2.0)
	_sheet.draw_on(_sprite, "idle_1", false)
	var k := float(HeldItems.form(FORM)["scale"])
	assert_eq(_pivot("n").scale, Vector2(k, k))
	assert_eq(_pivot("n").global_scale, Vector2(2.0 * k, 2.0 * k))
	assert_eq(_pivot("n").global_position, Vector2(100.0, 50.0) + 2.0 * _pivot("n").position, "the pivot rides the sprite")

func test_a_flipped_sprite_flips_each_pivot() -> void:
	var frame := _turned_frame(3.0)
	_layer.bind(FORM)
	_sheet.draw_on(_sprite, frame, false)
	var up_pos := _pivot("n").position
	var up_rot := _pivot("n").rotation
	var k := _pivot("n").scale.x
	_sprite.flip_v = true
	_sheet.draw_on(_sprite, frame, false)
	assert_eq(_pivot("n").position, Vector2(up_pos.x, -up_pos.y))
	assert_almost_eq(_pivot("n").rotation, -up_rot, 0.0001)
	assert_eq(_pivot("n").scale, Vector2(k, -k))

func test_an_item_is_plain_when_its_body_is_drawn_plain_and_lit_when_it_is_lit() -> void:
	_layer.set_item("n", "axe")
	var axe := SpriteSheet.load_set(HeldItems.item("axe")["set"])
	HeldItemLayer.follow_on(_sprite, _sheet, "idle_1", true, false)
	var plain := _art("n").texture as AtlasTexture
	var want := axe.frame_texture("item") as AtlasTexture
	assert_false(_art("n").texture is CanvasTexture, "no normal map where the body has none")
	assert_eq(plain.atlas, want.atlas)
	assert_eq(plain.region, want.region)
	assert_true(_art("n").flip_h, "a plain frame is flipped by the sprite")
	HeldItemLayer.follow_on(_sprite, _sheet, "idle_1", true, true)
	assert_eq(_art("n").texture, axe.texture_of("item", true))
	assert_false(_art("n").flip_h)

func test_bind_gives_defaults_overrides_survive_a_bind_and_clearing_restores_the_defaults() -> void:
	_layer.bind(FORM)
	assert_eq(_layer.item("n"), "hammer")
	assert_eq(_layer.item("f"), "tongs")
	_layer.set_item("n", "axe")
	_layer.bind("goblin_paladin")
	assert_eq(_layer.item("n"), "axe", "a held item survives an evolution")
	assert_eq(_layer.item("f"), HeldItems.form("goblin_paladin")["f"])
	_layer.clear_overrides()
	assert_eq(_layer.item("n"), HeldItems.form("goblin_paladin")["n"])
	_layer.bind("")
	assert_eq(_layer.item("n"), "", "the empty id is the base goblin, which holds nothing")

func test_a_cleared_hand_stays_empty_across_a_bind_until_the_overrides_are_cleared() -> void:
	_layer.bind(FORM)
	_layer.set_item("n", "")
	_layer.bind(FORM)
	assert_eq(_layer.item("n"), "")
	_layer.clear_overrides()
	assert_eq(_layer.item("n"), "hammer")

func test_suspending_hides_the_items_and_keeps_the_overrides_until_the_next_bind() -> void:
	_layer.bind(FORM)
	_layer.set_item("n", "axe")
	_sheet.draw_on(_sprite, "idle_1", false)
	HeldItemLayer.suspend_on(_sprite)
	assert_false(_pivot("n").visible)
	_sheet.draw_on(_sprite, "idle_1", false)
	assert_false(_pivot("n").visible, "a suspended layer stays hidden through every draw")
	_layer.bind(FORM)
	_sheet.draw_on(_sprite, "idle_1", false)
	assert_true(_pivot("n").visible)
	assert_eq(_layer.item("n"), "axe")

func test_copy_onto_makes_a_layer_with_the_same_items_following_the_last_frame() -> void:
	_layer.bind(FORM)
	_layer.set_item("f", "lantern")
	_sheet.draw_on(_sprite, "idle_1", true)
	var other := Sprite2D.new()
	add_child_autofree(other)
	var copy := _layer.copy_onto(other)
	assert_eq(copy.item("n"), "hammer")
	assert_eq(copy.item("f"), "lantern")
	assert_eq(other.get_node("HeldItemN").position, _pivot("n").position)
	assert_true(other.get_node("HeldItemN").visible)

func test_freeing_the_layer_takes_its_pivots_with_it() -> void:
	_layer.free()
	await get_tree().process_frame
	assert_null(_sprite.get_node_or_null("HeldItemN"))
	assert_null(_sprite.get_node_or_null("HeldItemF"))

func test_follow_on_does_nothing_for_a_sprite_with_no_layer() -> void:
	var bare := Sprite2D.new()
	add_child_autofree(bare)
	HeldItemLayer.follow_on(bare, _sheet, "idle_1", false, true)
	assert_eq(bare.get_child_count(), 0)
