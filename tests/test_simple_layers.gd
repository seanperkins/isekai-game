extends GutTest
## For now a painted room has two layers: a background (a per-biome dark base under the biome's back-wall
## tile) and the foreground (the painted terrain the player plays on). The parallax stack, the foreground
## frame, the motes and the set dressing stay in code behind RoomBuilder.simple_layers.

const BIOMES := ["cave", "grotto", "flooded"]
const STACK := ["far_haze", "far_rock", "mid_rock", "foreground", "Motes", "Dressing"]

func after_each() -> void:
	RoomBuilder.simple_layers = true

func _room(biome: String, size := Vector2i(2, 1)) -> Node2D:
	var def := RoomDef.new()
	def.id = "T"
	def.area = biome
	def.size = size
	def.solids = [Rect2(100, 200, 100, 12)]
	def.dressing = [{"piece": "stone_arch", "pos": Vector2(300, 330), "factor": 0.2}]
	var node := RoomBuilder.build_room(def, {})
	add_child_autofree(node)
	return node

func test_simple_layers_are_the_default() -> void:
	assert_true(RoomBuilder.simple_layers)

func test_a_painted_room_has_a_background_and_a_foreground_and_nothing_else() -> void:
	for b in BIOMES:
		var node := _room(b)
		for n in ["BackdropBase", "BackWall", "Terrain"]:
			assert_not_null(node.get_node_or_null(n), "%s has %s" % [b, n])
		for n in STACK:
			assert_null(node.get_node_or_null(n), "%s has no %s" % [b, n])

func test_the_background_covers_the_room_and_sits_behind_the_terrain() -> void:
	for b in BIOMES:
		var node := _room(b, Vector2i(2, 2))
		var base: ColorRect = node.get_node("BackdropBase")
		var wall: Sprite2D = node.get_node("BackWall")
		assert_eq(base.size, Vector2(1280, 720), b)
		assert_eq(wall.region_rect.size, Vector2(1280, 720), b)
		assert_lt(base.z_index, wall.z_index, "%s: the base is behind the wall tile" % b)
		assert_lt(wall.z_index, 0, "%s: both are behind the play plane" % b)
		assert_eq(wall.texture, TerrainArt.tile(b, "backwall"), "%s uses its own back-wall tile" % b)

func test_each_biome_has_its_own_dark_background() -> void:
	var seen := []
	for b in BIOMES:
		var c := TerrainArt.background_color(b)
		assert_lt(c.v, 0.3, "%s: dark, so the platforms read against it" % b)
		assert_false(seen.has(c), "%s: not the same colour as another biome" % b)
		seen.append(c)
		assert_eq((_room(b).get_node("BackdropBase") as ColorRect).color, c, b)

func test_the_full_stack_still_builds_behind_the_flag() -> void:
	RoomBuilder.simple_layers = false
	var node := _room("cave")
	for n in ["far_haze", "far_rock", "mid_rock", "foreground", "Motes", "Dressing", "BackWall"]:
		assert_not_null(node.get_node_or_null(n), n)
	assert_null(node.get_node_or_null("BackdropBase"), "the flat base belongs to the simple look")

func test_an_unpainted_area_keeps_its_flat_backdrop() -> void:
	var node := _room("nowhere")
	assert_null(node.get_node_or_null("BackdropBase"))
	assert_null(node.get_node_or_null("Terrain"))
