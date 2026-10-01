extends GutTest
## DecorLib: the decor sprites the editor can place.

## Every decor entry the shipped rooms carry, as {room, d}.
func _shipped_decor() -> Array:
	var out: Array = []
	var rooms := World.load_rooms("res://data/rooms")
	for id in rooms:
		for d in (rooms[id] as RoomDef).decor:
			out.append({"room": id, "d": d})
	return out

func test_the_39_shipped_decor_ids_are_pinned_to_the_catalog() -> void:
	var ids := {}
	for item in _shipped_decor():
		var d: Dictionary = item["d"]
		ids[d["id"]] = true
		assert_eq(DecorLib.entry(d["id"], d["pos"]), d, "%s in %s" % [d["id"], item["room"]])
	assert_eq(ids.size(), 39)

func test_every_row_has_a_sprite_a_valid_anchor_and_a_light_that_is_absent_or_a_color() -> void:
	assert_eq(DecorLib.CATALOG.size(), 46)
	for id in DecorLib.CATALOG:
		var row: Dictionary = DecorLib.CATALOG[id]
		assert_not_null(Art.texture(id), "%s has a sprite" % id)
		assert_true(["bottom", "top"].has(row["anchor"]), id)
		assert_true(not row.has("light") or row["light"] is Color, id)

func test_every_biome_prefixed_sprite_has_a_row() -> void:
	var dir := DirAccess.open("res://assets/sprites")
	for f in dir.get_files():
		if f.ends_with(".png"):
			var sprite := f.trim_suffix(".png")
			for b in TerrainArt.biomes():
				if b != "cave" and sprite.begins_with(b + "_"):
					assert_true(DecorLib.CATALOG.has(sprite), "%s needs a catalog row" % sprite)

func test_biome_of_agrees_with_the_prefab_generators_naming() -> void:
	for biome in TerrainArt.biomes():
		for base in ["glow_fungus", "stalagmite", "wall_crystal"]:
			assert_eq(DecorLib.biome_of(Prefabs.decor_id(base, biome)), biome)

func test_ids_for_biome_partitions_the_catalog() -> void:
	var seen := 0
	for biome in TerrainArt.biomes():
		var ids := DecorLib.ids_for_biome(biome)
		seen += ids.size()
		for id in ids:
			assert_eq(DecorLib.biome_of(id), biome)
	assert_eq(seen, 46)
	assert_true(DecorLib.ids_for_biome("deep").has("deep_bones"))
	assert_false(DecorLib.ids_for_biome("cave").has("deep_bones"))

func test_entry_has_anchor_only_when_top_and_light_only_when_it_has_one() -> void:
	assert_eq(DecorLib.entry("vine", Vector2(1, 2)), {"id": "vine", "pos": Vector2(1, 2), "anchor": "top"})
	assert_eq(DecorLib.entry("rubble", Vector2(1, 2)), {"id": "rubble", "pos": Vector2(1, 2)})
	assert_true(DecorLib.entry("crystal_teal", Vector2.ZERO).has("light"))

func test_texture_box_is_bottom_or_top_anchored_and_falls_back_for_an_unknown_id() -> void:
	var tex := Art.texture("crystal_teal")
	assert_eq(DecorLib.texture_box("crystal_teal"), Rect2(-tex.get_width() / 2.0, -tex.get_height(), tex.get_width(), tex.get_height()))
	var vine := Art.texture("vine")
	assert_eq(DecorLib.texture_box("vine"), Rect2(-vine.get_width() / 2.0, 0.0, vine.get_width(), vine.get_height()))
	assert_eq(DecorLib.texture_box("no_such_sprite"), DecorLib.UNKNOWN_BOX)

func test_texture_box_takes_the_anchor_a_piece_carries_over_the_catalogs() -> void:
	var u := DecorLib.UNKNOWN_BOX
	assert_eq(DecorLib.texture_box("no_such_sprite", "top"), Rect2(u.position.x, 0.0, u.size.x, u.size.y))
	var vine := Art.texture("vine")
	assert_eq(DecorLib.texture_box("vine", "bottom"), Rect2(-vine.get_width() / 2.0, -vine.get_height(), vine.get_width(), vine.get_height()))
	assert_eq(DecorLib.box_of({"id": "vine", "pos": Vector2.ZERO, "anchor": "top"}), DecorLib.texture_box("vine"))
	assert_eq(DecorLib.box_of({"id": "vine", "pos": Vector2.ZERO}), DecorLib.texture_box("vine", "bottom"))
