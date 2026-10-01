extends GutTest
## RoomBuilder.build_decor: a hand-edited decor entry must never crash the builder.

func test_a_decor_entry_with_no_sprite_is_skipped_not_a_crash() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	RoomBuilder.build_decor(parent, {"decor": [
		{"id": "no_such_sprite", "pos": Vector2(10, 10), "anchor": "top"},
		{"id": "no_such_sprite", "pos": Vector2(20, 10)},
		{"id": "crystal_teal", "pos": Vector2(50, 50)}]})
	assert_eq(parent.get_child_count(), 1, "only the real sprite is built")
