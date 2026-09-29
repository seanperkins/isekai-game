extends GutTest
## Thin platforms (ledges) can be jumped up through from below and stood on from above; thick masses and tall walls
## are solid from every side.

const LEDGE := Rect2(100, 200, 100, 12)
const MASS := Rect2(300, 200, 100, 32)
const WALL := Rect2(500, 100, 16, 180)

const HARD := Rect2(100, 100, 100, 12)  # thin like a ledge, but chosen to be rock from below

func _room(hard: Array = []) -> Node2D:
	var def := RoomDef.new()
	def.id = "T"
	def.area = "cave"
	def.size = Vector2i(1, 1)
	def.solids = [LEDGE, MASS, WALL] if hard.is_empty() else [LEDGE, MASS, WALL, HARD]
	def.hard_ledges = hard
	var node := RoomBuilder.build_room(def, {})
	add_child_autofree(node)
	return node

func _body(at: Vector2) -> CharacterBody2D:
	var b := CharacterBody2D.new()
	var s := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(28, 24)
	s.shape = box
	b.add_child(s)
	add_child_autofree(b)
	b.global_position = at
	return b

func test_the_classification() -> void:
	assert_true(RoomBuilder.is_one_way(LEDGE), "a 12 px shelf is one-way")
	assert_false(RoomBuilder.is_one_way(MASS), "a 32 px mass is solid")
	assert_false(RoomBuilder.is_one_way(WALL), "a tall thin wall is solid")
	assert_false(RoomBuilder.is_one_way(Rect2(0, 0, 20, 12)), "a stub as narrow as a wall is solid")
	assert_true(RoomBuilder.is_one_way(Rect2(0, 0, 90, 24)), "24 px thick is still a ledge")

func test_you_can_jump_up_through_a_ledge_from_below() -> void:
	_room()
	await wait_physics_frames(2)
	var b := _body(Vector2(150, 240))  # its top at 228 is below the ledge's bottom (212)
	assert_false(b.test_move(b.global_transform, Vector2(0, -60)), "up through the ledge is free")

func test_you_stand_on_a_ledge_from_above() -> void:
	_room()
	await wait_physics_frames(2)
	var b := _body(Vector2(150, 180))  # feet at 192, the ledge top is 200
	assert_true(b.test_move(b.global_transform, Vector2(0, 30)), "falling onto it stops")

func test_a_ledge_has_no_solid_side() -> void:
	_room()
	await wait_physics_frames(2)
	var b := _body(Vector2(70, 206))
	assert_false(b.test_move(b.global_transform, Vector2(60, 0)), "walking sideways through a ledge's edge is free")

func test_a_thick_mass_blocks_from_below() -> void:
	_room()
	await wait_physics_frames(2)
	var b := _body(Vector2(350, 260))  # top at 248, the mass's bottom is 232
	assert_true(b.test_move(b.global_transform, Vector2(0, -40)), "a mass is solid from underneath")

func test_a_tall_wall_blocks_from_the_side() -> void:
	_room()
	await wait_physics_frames(2)
	var b := _body(Vector2(470, 200))
	assert_true(b.test_move(b.global_transform, Vector2(40, 0)))

# --- the choice is the author's: a thin platform can be listed as solid from below ---

func test_a_listed_hard_ledge_is_not_one_way() -> void:
	assert_true(RoomBuilder.is_one_way(HARD), "thin, and not listed: one-way")
	assert_false(RoomBuilder.is_one_way(HARD, [HARD]), "listed as hard: solid")
	assert_true(RoomBuilder.is_one_way(LEDGE, [HARD]), "another ledge is unaffected")

func test_a_hard_ledge_blocks_from_below_but_you_still_stand_on_it() -> void:
	_room([HARD])
	await wait_physics_frames(2)
	var below := _body(Vector2(150, 140))  # top at 128, under HARD's bottom (112)
	assert_true(below.test_move(below.global_transform, Vector2(0, -40)), "a hard ledge is solid from underneath")
	var above := _body(Vector2(150, 80))  # feet at 92, HARD's top is 100
	assert_true(above.test_move(above.global_transform, Vector2(0, 30)), "and you stand on it")

func test_the_ledge_beside_a_hard_one_is_still_pass_through() -> void:
	_room([HARD])
	await wait_physics_frames(2)
	var b := _body(Vector2(150, 240))
	assert_false(b.test_move(b.global_transform, Vector2(0, -60)), "the listed ledge does not make its neighbour hard")

# --- you can see the choice: a hard ledge has a rock underside, a pass-through one is a clean shelf ---

## Rock sprites hanging from the bottom of `r` (masses and walls in the same room have their own).
func _undersides(root: Node2D, r: Rect2) -> Array:
	var under := TerrainArt.tile("cave", "cap_bottom")
	return root.get_children().filter(func(n): return n is Sprite2D and n.texture == under \
		and absf(n.position.x - r.position.x) < 0.5 and n.position.y <= r.end.y and n.position.y + under.get_height() > r.end.y)

func test_a_hard_ledge_is_painted_with_an_underside_and_a_plain_ledge_is_not() -> void:
	var bounds := Rect2(0, 0, 640, 360)
	var plain := TerrainPainter.paint(Node2D.new(), [{"rect": LEDGE, "kind": "ground"}], bounds, "cave")
	add_child_autofree(plain.get_parent())
	assert_eq(_undersides(plain, LEDGE).size(), 0, "a pass-through ledge is a clean shelf")
	var hard := TerrainPainter.paint(Node2D.new(), [{"rect": HARD, "kind": "ground", "hard": true}], bounds, "cave")
	add_child_autofree(hard.get_parent())
	var sprites := _undersides(hard, HARD)
	assert_eq(sprites.size(), 1, "a hard ledge shows rock underneath")
	assert_eq(sprites[0].region_rect.size.x, HARD.size.x, "and spans the whole ledge")

func test_build_room_paints_a_listed_ledge_hard_and_only_that_one() -> void:
	var node := _room([HARD])
	var terrain := node.get_node("Terrain")
	assert_eq(_undersides(terrain, HARD).size(), 1, "the listed ledge gets an underside")
	assert_eq(_undersides(terrain, LEDGE).size(), 0, "the plain ledge stays a clean shelf")
