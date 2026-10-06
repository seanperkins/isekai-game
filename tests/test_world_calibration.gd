extends GutTest
## The world with its new areas and 169 placed creatures against the calibration of the hand-made world (docs/research/species-form-branches.md
## section 8). The four shipped areas are walked eating what a diet of creatures offers. The hand-made world's pins are the spec: on the diet of
## the common creatures (a stage-1 body's) the full world must reproduce them; a richer diet may reveal more, and sooner, never less.

var forms := {}
var creatures := {}
var skills: Array
var plan: Dictionary
var four := {}  # the checked-in rooms of the four shipped areas
var common := {}
var no_rares := {}
var everything := {}
var old_only := {}

func before_all() -> void:
	forms = FormLoader.load_species()
	skills = DefLoader.load_dir("res://data/skills")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	plan = JSON.parse_string(FileAccess.get_file_as_string("res://tools/creature_areas.json"))
	var all := World.load_rooms(AreaBuilder.ROOMS_DIR)
	for id in all:
		if CalibrationWalk.AREAS.has((all[id] as RoomDef).area):
			four[id] = all[id]
	old_only = CalibrationWalk.diet(four, plan, ["old"])
	common = CalibrationWalk.diet(four, plan, ["old", "common"])
	no_rares = CalibrationWalk.diet(four, plan, ["old", "common", "elite"])
	everything = CalibrationWalk.diet(four, plan, ["old", "common", "elite", "rare"])

## [[area, revealed, offered], ...] at the end of each area, walking from `start_area` ("" is the Cave start).
func _walk(rooms: Dictionary, start_area: String) -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
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

## [revealed, offered] the moment the walk's XP (a creature's xp once per eat) first reaches the first evolution's 270.
func _at_first_evolution(rooms: Dictionary, start_area: String) -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	rules.start_run()
	var xp := 0
	for id in CalibrationWalk.order(rooms, start_area):
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			if c.untackleable:
				continue
			CalibrationWalk.eat(rules, c)
			xp += c.xp
			if xp >= Progression.stage_total(1):
				return [FormOffers.revealed_lineages(forms, rules), FormOffers.offered_lineages(forms, rules)]
	fail_test("the %s start never reaches the first evolution's %d XP on this diet" % [start_area if start_area != "" else "cave", Progression.stage_total(1)])
	return [[], []]

## [[lineage, the eat at which what was absorbed first meets its reveal], ...] in the order they open on the walk from `start_area`: the design doc's
## numbers, which leave the +3 of an owned power out.
func _opening_order(rooms: Dictionary, start_area: String) -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	rules.start_run()
	var out: Array = []
	var seen := {}
	var eats := 0
	for id in CalibrationWalk.order(rooms, start_area):
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			if c.untackleable:
				continue
			CalibrationWalk.eat(rules, c)
			eats += 1
			for f: FormDef in FormLoader.stage2_forms(forms):
				if f.lineage == "greater" or seen.has(f.lineage):
					continue
				if f.reveal.keys().all(func(e: String) -> bool: return rules.absorbed(e) >= int(f.reveal[e])):  # the diet alone: no power bonus
					seen[f.lineage] = true
					out.append([f.lineage, eats])
	return out

# --- the diets ---

func test_the_old_diet_is_the_hand_made_world_and_the_common_diet_adds_creatures_to_it() -> void:
	var count := func(rooms: Dictionary) -> int:
		var n := 0
		for id in rooms:
			n += (rooms[id] as RoomDef).spawns.size()
		return n
	assert_eq(count.call(old_only), 98, "the shipped rooms' own creatures")
	assert_gt(count.call(common), count.call(old_only))
	assert_gt(count.call(no_rares), count.call(common))
	assert_gt(count.call(everything), count.call(no_rares))
	assert_eq(count.call(everything), count.call(four))

# --- the powers ---

## The Cave-start unlock of each power on the hand-made world (tests/test_content.gd's pins, with Spore Cloud's deliberate 16).
const HAND_MADE_CAVE := {"body_armor": 13, "echolocation": 3, "hardened_shell": 27, "hydraulic_propulsion": 7, "jolt": 57,
	"poison_breath": 7, "regeneration": 11, "sticky_thread": 14, "tremor": 73, "spore_cloud": 16}

func test_the_old_diet_unlocks_every_power_where_the_hand_made_world_did() -> void:
	var points := CalibrationWalk.unlock_points(skills, creatures, old_only, "")
	for id in HAND_MADE_CAVE:
		assert_eq(points.get(id, 0), HAND_MADE_CAVE[id], id)

func test_the_common_diet_unlocks_every_power_within_one_eat_of_it_and_jolt_within_ten() -> void:
	var points := CalibrationWalk.unlock_points(skills, creatures, common, "")
	for id in HAND_MADE_CAVE:
		var slack := 10.0 if id == "jolt" else 1.0  # Jolt waits for the Flooded's light: the Grotto's new commons come before it
		assert_almost_eq(float(points.get(id, 0)), float(HAND_MADE_CAVE[id]), slack, id)

func test_every_power_is_reachable_from_every_start_on_the_common_diet() -> void:
	for start in ["", "grotto", "flooded", "deep"]:
		var points := CalibrationWalk.unlock_points(skills, creatures, common, start)
		for d in skills:
			if d.source == "essence":
				assert_gt(int(points.get(d.id, 0)), 0, "%s from the %s start" % [d.id, start if start != "" else "cave"])

# --- the slime's lineages ---

func test_a_cave_start_on_the_common_diet_reveals_three_in_the_cave_and_all_five_by_the_grotto() -> void:
	var w := _walk(common, "")
	assert_eq(w[0][0], "cave")
	assert_eq(w[0][1], ["tide", "toxic", "echo"])
	assert_eq(w[0][2], ["toxic"], "and offers one")
	assert_eq(w[1][1], ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_the_other_starts_on_the_common_diet_reveal_what_they_did() -> void:
	assert_eq(_walk(common, "grotto")[0][1], ["toxic", "bulwark", "echo"])
	assert_eq(_walk(common, "grotto")[0][2], [])
	assert_eq(_walk(common, "flooded")[0][1], ["tide", "echo"])
	assert_eq(_walk(common, "deep")[0][1], ["bulwark", "echo"])
	assert_eq(_walk(common, "deep")[0][2], [], "nothing is offered yet, so the Greater Slime fallback would show")

func test_at_the_first_evolution_a_common_diet_cave_start_is_offered_all_five_and_the_other_starts_four() -> void:
	assert_eq(_at_first_evolution(common, "")[1], ["weaver", "tide", "toxic", "bulwark", "echo"])
	for start in ["grotto", "flooded", "deep"]:
		assert_eq(_at_first_evolution(common, start)[1], ["tide", "toxic", "bulwark", "echo"], start)

func test_a_richer_diet_reveals_and_offers_a_superset_at_the_end_of_every_area_on_every_start() -> void:
	for start in ["", "grotto", "flooded", "deep"]:
		var a := _walk(common, start)
		var b := _walk(no_rares, start)
		var c := _walk(everything, start)
		for i in a.size():
			for k in [1, 2]:
				for l in a[i][k]:
					assert_true(b[i][k].has(l), "%s start, %s: %s kept by the elites' diet" % [start, a[i][0], l])
				for l in b[i][k]:
					assert_true(c[i][k].has(l), "%s start, %s: %s kept by the full diet" % [start, a[i][0], l])

func test_the_full_diet_opens_bulwark_in_the_cave_which_the_common_diet_leaves_to_the_grotto() -> void:
	assert_false(_walk(common, "")[0][1].has("bulwark"))
	assert_true(_walk(everything, "")[0][1].has("bulwark"), "the cave's elites and rares carry earth: a bolder eater opens it sooner")

func test_the_lineages_open_in_the_design_docs_order_and_at_its_eats_on_the_old_diet() -> void:
	assert_eq(_opening_order(old_only, ""), [["toxic", 15], ["tide", 17], ["echo", 18], ["bulwark", 43], ["weaver", 45]], "Toxic 15, Tide 17, Echo 18 (Cave), Bulwark 43, Weaver 45 (Grotto)")

func test_the_common_diet_opens_them_in_the_same_order_and_the_cave_ones_within_two_eats() -> void:
	var order := _opening_order(common, "")
	assert_eq(order.map(func(p: Array) -> String: return p[0]), ["toxic", "tide", "echo", "bulwark", "weaver"])
	assert_eq(order.slice(0, 3), [["toxic", 15], ["tide", 19], ["echo", 20]], "within two eats of 15, 17 and 18: the Cave's new commons are met among the old creatures (the rooms were rebuilt for the rendered creatures' sizes: Toxic is now met at exactly 15)")
