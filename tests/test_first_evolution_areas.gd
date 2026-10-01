extends GutTest
## The affinity that picks the first evolution divides by the supply of the areas a stage-1 life plays, so a later area
## (the Flooded) does not dilute it.

func _creatures() -> Dictionary:
	var out := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		out[c.id] = c
	return out

func _room(id: String, area: String, spawns: Array) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = area
	r.spawns = spawns
	return r

func test_supply_counts_only_the_listed_areas() -> void:
	var forms := FormLoader.load_all()
	var rooms := {
		"A": _room("A", "cave", [{"id": "toad", "pos": Vector2.ZERO}]),
		"B": _room("B", "flooded", [{"id": "drift_jelly", "pos": Vector2.ZERO}]),
	}
	var all := FormOffers.supply(rooms, _creatures(), forms)
	var scoped := FormOffers.supply(rooms, _creatures(), forms, ["cave"])
	assert_eq(all["tide"], 3, "toad water 1 + jelly water 2")
	assert_eq(scoped["tide"], 1, "only the cave's toad")

func test_the_default_supply_reads_only_the_first_evolution_areas() -> void:
	FormOffers._default_supply = {}
	var forms := FormLoader.load_all()
	var scoped := FormOffers.default_supply(forms)
	var rooms := World.load_rooms("res://data/rooms")
	var expected := FormOffers.supply(rooms, _creatures(), forms, FormOffers.FIRST_EVOLUTION_AREAS)
	assert_eq(scoped, expected)
	FormOffers._default_supply = {}

func test_the_first_evolution_areas_are_derived_not_trusted() -> void:
	# the Grotto's own rule, restated for the list: the ungated first-time XP of these areas reaches stage 1's cap, and
	# without the last area it does not
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
	for a in FormOffers.FIRST_EVOLUTION_AREAS:
		total += int(by_area.get(a, 0))
	assert_gte(total, Progression.stage_total(1), "cave plus grotto reach the cap")
	var without_last: int = total - int(by_area.get(FormOffers.FIRST_EVOLUTION_AREAS.back(), 0))
	assert_lt(without_last, Progression.stage_total(1), "the cap lands in the last of them")
