extends GutTest
## hit_all: everything under a point in hit order; hit is its first element.

var model: RoomEditModel

func before_each() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c): return c.id)
	model = RoomEditModel.new(ShippedRooms.load_all(), ids)

## A lone room with a creature, a tablet and two nested solids stacked on one point.
func _stack() -> RoomDef:
	var r := RoomDef.new()
	r.id = "L1"
	r.area = "cave"
	r.cell = Vector2i(20, 20)
	r.solids = [Rect2(100, 100, 200, 60), Rect2(150, 120, 40, 20)]   # the small one sits inside the big one
	r.spawns = [{"id": "toad", "pos": Vector2(170, 130)}]
	r.features = [{"kind": "tablet", "id": "l1_tablet_1", "pos": Vector2(170, 140), "title": "T"}]
	return r

func test_candidates_come_in_hit_order() -> void:
	model.rooms["L1"] = _stack()
	var kinds := model.hit_all("L1", Vector2(170, 130), 4.0).map(func(s): return s["kind"])
	assert_eq(kinds, ["spawn", "feature", "solid", "solid"])

func test_solids_are_smallest_area_first_with_ties_by_index() -> void:
	model.rooms["L1"] = _stack()
	var solids := model.hit_all("L1", Vector2(170, 130), 0.0).filter(func(s): return s["kind"] == "solid")
	assert_eq(solids.map(func(s): return s["index"]), [1, 0], "the small solid (index 1) before the big one")

func test_hit_is_the_first_candidate_and_empty_space_is_empty() -> void:
	model.rooms["L1"] = _stack()
	assert_eq(model.hit("L1", Vector2(170, 130), 4.0), model.hit_all("L1", Vector2(170, 130), 4.0)[0])
	assert_eq(model.hit_all("L1", Vector2(500, 300), 4.0), [])
	assert_eq(model.hit("L1", Vector2(500, 300), 4.0), {})

func test_spawns_are_nearest_first_with_ties_by_index() -> void:
	var r := _stack()
	r.spawns = [{"id": "toad", "pos": Vector2(176, 130)}, {"id": "bat", "pos": Vector2(171, 130)}, {"id": "bat", "pos": Vector2(171, 130)}]
	model.rooms["L1"] = r
	var spawns := model.hit_all("L1", Vector2(170, 130), 8.0).filter(func(s): return s["kind"] == "spawn")
	assert_eq(spawns.map(func(s): return s["index"]), [1, 2, 0])
