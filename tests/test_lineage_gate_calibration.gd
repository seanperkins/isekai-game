extends GutTest
## The slime's lineage gates against the shipped world: which lineages a diet that eats every creature once has revealed and been
## offered at the end of each area, from each of the four starts (the Cave and the three rebirth altars). The numbers are the design
## doc's (section 8, "Opening thresholds"); a new creature or room moves them, and this test says so.

var forms := {}
var creatures := {}
var rooms := {}

func before_all() -> void:
	forms = FormLoader.load_species()
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var made := AreaWorlds.upto("DM")  # the hand-made rooms: the numbers are the design doc's, calibrated before creatures were placed in rooms
	for id in ShippedRooms.IDS:
		rooms[id] = made[id]

## [[area, revealed, offered], ...] at the end of each area, walking from `start_area` ("" is the Cave start).
func _walk(start_area: String) -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	rules.start_run()
	var order := CalibrationWalk.order(rooms, start_area)
	var out: Array = []
	for i in order.size():
		var room: RoomDef = rooms[order[i]]
		for s in room.spawns:
			var c: CreatureDef = creatures[s["id"]]
			if not c.untackleable:
				CalibrationWalk.eat(rules, c)
		var next_area: String = (rooms[order[i + 1]] as RoomDef).area if i + 1 < order.size() else ""
		if next_area != room.area:
			out.append([room.area, FormOffers.revealed_lineages(forms, rules), FormOffers.offered_lineages(forms, rules)])
	return out

func test_a_cave_start_reveals_three_in_the_cave_and_all_five_by_the_grotto() -> void:
	var w := _walk("")
	assert_eq(w[0][0], "cave")
	assert_eq(w[0][1], ["tide", "toxic", "echo"])
	assert_eq(w[1][1], ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_a_grotto_start_reveals_its_own_first() -> void:
	var w := _walk("grotto")
	assert_eq(w[0][0], "grotto")
	assert_eq(w[0][1], ["toxic", "bulwark", "echo"])

func test_a_flooded_start_reveals_tide_and_echo_first() -> void:
	var w := _walk("flooded")
	assert_eq(w[0][0], "flooded")
	assert_eq(w[0][1], ["tide", "echo"])

func test_a_deep_start_reveals_bulwark_and_echo_first_and_offers_nothing() -> void:
	var w := _walk("deep")
	assert_eq(w[0][0], "deep")
	assert_eq(w[0][1], ["bulwark", "echo"])
	assert_eq(w[0][2], [], "nothing is offered yet, so the Greater Slime fallback would show")

## [revealed, offered] the moment the walk's XP first reaches the first evolution's 270.
func _at_first_evolution(start_area: String) -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	rules.start_run()
	var xp := 0
	for id in CalibrationWalk.order(rooms, start_area):
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			if c.untackleable:
				continue
			CalibrationWalk.eat(rules, c)
			xp += c.xp
			if xp >= 270:
				return [FormOffers.revealed_lineages(forms, rules), FormOffers.offered_lineages(forms, rules)]
	return []

func test_at_the_first_evolution_a_cave_start_is_offered_all_five() -> void:
	assert_eq(_at_first_evolution("")[1], ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_at_the_first_evolution_every_other_start_is_offered_four_without_weaver() -> void:
	for start in ["grotto", "flooded", "deep"]:
		assert_eq(_at_first_evolution(start)[1], ["tide", "toxic", "bulwark", "echo"], start)
