extends GutTest
## The areas a stage-1 life plays before its first evolution reach stage 1's cap, and the cap lands in the last of them.

## The Cave and the Grotto. (This list lived on FormOffers while the affinity ratio divided by their supply.)
const FIRST_EVOLUTION_AREAS := ["cave", "grotto"]

func _creatures() -> Dictionary:
	var out := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		out[c.id] = c
	return out

func test_the_first_evolution_areas_are_derived_not_trusted() -> void:
	# the ungated first-time XP of these areas reaches stage 1's cap, and without the last area it does not
	var rooms := ShippedRooms.load_all()
	var creatures := _creatures()
	var reach := WorldValidator.reachable(rooms, true)
	var by_area := {}
	for id in reach:
		var r: RoomDef = rooms[id]
		for s in r.spawns:
			var c: CreatureDef = creatures[s["id"]]
			by_area[r.area] = int(by_area.get(r.area, 0)) + c.xp * (1 if c.id == "water_pool" else 2)
	var total := 0
	for a in FIRST_EVOLUTION_AREAS:
		total += int(by_area.get(a, 0))
	assert_gte(total, Progression.stage_total(1), "cave plus grotto reach the cap")
	var without_last: int = total - int(by_area.get(FIRST_EVOLUTION_AREAS.back(), 0))
	assert_lt(without_last, Progression.stage_total(1), "the cap lands in the last of them")
