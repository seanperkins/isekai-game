extends GutTest
## The authored Cave dressing: valid, present in every room, and never leaving a screen-height band of a
## tall room bare.

var rooms := {}
var all_rooms := {}

## The full parallax stack is off in the shipped game for now (RoomBuilder.simple_layers); these tests keep it working.
func before_each() -> void:
	RoomBuilder.simple_layers = false

func after_each() -> void:
	RoomBuilder.simple_layers = true

func before_all() -> void:
	all_rooms = World.load_rooms("res://data/rooms")
	rooms = ShippedRooms.only(all_rooms)  # the dressing pins are about the shipped rooms; a new room has none

func test_every_cave_room_is_dressed_and_the_world_still_validates() -> void:
	assert_eq(WorldValidator.validate(all_rooms).size(), 0, str(WorldValidator.validate(all_rooms)))
	for id in rooms:
		var r: RoomDef = rooms[id]
		if r.area == "cave":
			assert_gte(r.dressing.size(), 6, "%s is dressed" % id)
			assert_lte(r.dressing.size(), SetDressing.MAX_PROPS, "%s is within the cap" % id)

func test_every_screen_height_band_of_a_tall_room_carries_dressing() -> void:
	for id in rooms:
		var r: RoomDef = rooms[id]
		if r.area != "cave" or r.size.y < 2:
			continue
		for band in r.size.y:
			var lo := float(band) * 360.0
			var n := 0
			for e in r.dressing:
				var y: float = (e["pos"] as Vector2).y
				var h := DressingLib.size(r.area, str(e["piece"])).y
				var top := y if DressingLib.anchor(r.area, str(e["piece"])) == "top" else (y - h if DressingLib.anchor(r.area, str(e["piece"])) == "bottom" else y - h / 2.0)
				var bottom := top + h
				if bottom > lo and top < lo + 360.0:
					n += 1
			assert_gte(n, 2, "%s: screen band %d of %d has %d props" % [id, band, r.size.y, n])

func test_depth_is_varied_in_every_room() -> void:
	for id in rooms:
		var r: RoomDef = rooms[id]
		if r.area != "cave":
			continue
		var lo := 1.0
		var hi := 0.0
		for e in r.dressing:
			lo = minf(lo, float(e["factor"]))
			hi = maxf(hi, float(e["factor"]))
		assert_lt(lo, 0.3, "%s has a far layer" % id)
		assert_gt(hi, 0.5, "%s has a nearer layer" % id)

func test_no_prop_of_one_piece_stacks_exactly_on_another() -> void:
	for id in rooms:
		var r: RoomDef = rooms[id]
		var seen := {}
		for e in r.dressing:
			var key := "%s@%s" % [e["piece"], e["pos"]]
			assert_false(seen.has(key), "%s: %s is listed twice" % [id, key])
			seen[key] = true

func test_a_built_dressed_room_has_a_prop_for_every_entry() -> void:
	for id in rooms:
		var r: RoomDef = rooms[id]
		if r.dressing.is_empty():
			continue
		var node := RoomBuilder.build_room(r, {})
		add_child_autofree(node)
		var d: Node = node.get_node_or_null("Dressing")
		assert_not_null(d, id)
		assert_eq(d.get_child_count(), r.dressing.size(), id)
