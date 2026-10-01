extends GutTest
## Skills are held back by the body's stage: 5, 8, 12, 15. Progress is kept while capped, and evolving
## re-checks every owned skill straight to its new cap.

var engine: SkillRulesEngine
var log: Array

func _make(defs: Array) -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.report_error = func(msg: String) -> void: fail_test("unexpected engine error: " + msg)
	engine.setup(defs)
	log = []
	engine.skill_leveled.connect(func(id: String, lv: int) -> void: log.append("level:%s:%d" % [id, lv]))
	engine.start_run()

func _big(id := "big", curve := 2, max_level := 15, event := "jumped") -> SkillDef:
	var d := TestDefs.skill(id, {"unlock": [TestDefs.counter(event, 1)],
		"levels_on": {"event": event, "tags": {}}, "level_curve": curve, "max_level": max_level})
	return d

func _fire(event: String, n: int) -> void:
	for i in n:
		engine.handle_event(event, {})

func test_a_skill_stops_levelling_at_the_stage_cap_but_keeps_counting() -> void:
	_make([_big()])
	assert_eq(engine.stage_cap, 5)
	_fire("jumped", 1 + 2 * 20)  # far more than 4 levels' worth
	assert_eq(engine.level_of("big"), 5)
	assert_true(engine.is_capped("big"))
	assert_eq(engine.level_progress("big")["current"], 2, "the stored progress reads as a full bar")

func test_raising_the_cap_and_rechecking_levels_the_skill_straight_to_the_new_cap() -> void:
	_make([_big()])
	_fire("jumped", 1 + 2 * 20)
	engine.set_stage_cap(8)
	engine.recheck_levels()
	assert_eq(engine.level_of("big"), 8, "the events earned while capped were kept")
	assert_false(engine.is_capped("big") and engine.level_of("big") < 8)
	assert_eq(log.filter(func(e): return e.begins_with("level:big")).size(), 7, "one skill_leveled per level: 1 to 8")

func test_a_skill_never_passes_its_own_max() -> void:
	_make([_big("small", 2, 6)])
	_fire("jumped", 1 + 2 * 20)
	engine.set_stage_cap(15)
	engine.recheck_levels()
	assert_eq(engine.level_of("small"), 6)
	assert_false(engine.is_capped("small"), "at its own max it is not stage-capped")

func test_recheck_with_every_levelling_skill_far_past_the_cap_drops_no_event() -> void:
	var defs: Array = []
	for i in 14:
		defs.append(_big("s%d" % i, 1, 15, "ev%d" % i))
	_make(defs)
	for i in 14:
		_fire("ev%d" % i, 100)
	for i in 14:
		assert_eq(engine.level_of("s%d" % i), 5)
	engine.set_stage_cap(15)
	engine.recheck_levels()  # a report_error from the 64-item queue limit would fail the test
	for i in 14:
		assert_eq(engine.level_of("s%d" % i), 15, "s%d" % i)

func test_the_recheck_flags_itself_and_reports_how_many_levels_were_gained() -> void:
	_make([_big()])
	_fire("jumped", 1 + 2 * 20)
	engine.set_stage_cap(8)
	var seen := {"during": false, "gained": -1}
	engine.skill_leveled.connect(func(_id: String, _lv: int) -> void:
		if engine.rechecking:
			seen["during"] = true)
	engine.rechecked.connect(func(n: int) -> void: seen["gained"] = n)
	engine.recheck_levels()
	assert_true(seen["during"])
	assert_eq(seen["gained"], 3)
	assert_false(engine.rechecking)

func test_during_a_recheck_the_ticker_gets_one_line_not_one_per_level() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup([_big()])
	var q := AnnouncerQueue.new()
	var comp := CompendiumModel.new([_big()], [])
	CoreWiring.connect_core(rules, comp, q)
	rules.start_run()
	for i in 1 + 2 * 20:
		rules.handle_event("jumped", {})
	while not q.pop_ticker().is_empty():
		pass
	rules.set_stage_cap(8)
	rules.recheck_levels()
	var lines: Array = []
	var t := q.pop_ticker()
	while not t.is_empty():
		lines.append(t)
		t = q.pop_ticker()
	assert_eq(lines.size(), 1, "one line: %s" % [lines])
	assert_eq(lines[0]["kind"], "note")
	assert_eq(lines[0]["text"], "Your skills grew.")

func test_a_recheck_that_gains_nothing_says_nothing() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup([_big()])
	var q := AnnouncerQueue.new()
	CoreWiring.connect_core(rules, CompendiumModel.new([_big()], []), q)
	rules.start_run()
	rules.set_stage_cap(8)
	rules.recheck_levels()
	assert_eq(q.pop_ticker(), {})

func test_a_new_run_resets_the_cap() -> void:
	_make([_big()])
	engine.set_stage_cap(12)
	engine.start_run()
	assert_eq(engine.stage_cap, 5)

# --- the real skills ---

func _defs() -> Dictionary:
	var out := {}
	for d in DefLoader.load_dir("res://data/skills"):
		out[d.id] = d
	return out

## skill id -> [new max, level curve] (the plan's table)
const TABLE := {
	"leap": [10, 20], "wall_cling": [8, 12], "poison_resistance": [12, 6], "pain_resistance": [6, 2],
	"toughness": [12, 20], "appraisal": [5, 2], "glutton": [8, 5], "mana_recovery": [8, 60],
	"echolocation": [8, 3], "poison_breath": [15, 8], "body_armor": [8, 10], "sticky_thread": [15, 8],
	"hydraulic_propulsion": [15, 6], "regeneration": [6, 8], "spore_cloud": [8, 8], "hardened_shell": [8, 10], "swim": [3, 40], "jolt": [5, 8]}

func test_every_levelling_skill_has_its_planned_maximum_and_curve() -> void:
	var defs := _defs()
	for id in TABLE:
		assert_eq((defs[id] as SkillDef).max_level, TABLE[id][0], "%s max" % id)
		assert_eq((defs[id] as SkillDef).level_curve, TABLE[id][1], "%s curve" % id)

func test_only_the_skills_that_level_changed_and_the_others_stay_at_one() -> void:
	for id in _defs():
		var d: SkillDef = _defs()[id]
		if d.levels_on.is_empty():
			assert_eq(d.max_level, 1, "%s does not level, so its max stays 1" % id)

func test_effect_values_match_each_skills_max_and_never_decrease_in_strength() -> void:
	for id in TABLE:
		var d: SkillDef = _defs()[id]
		for e in d.effects:
			if e.has("values"):
				var v: Array = e["values"]
				assert_eq(v.size(), d.max_level, "%s: values match the max" % id)
				var descending: bool = e.get("op", "") == "set" or (e.get("stat", "") == "slide_speed") or (e.get("stat", "") == "predation_time") or (e.get("stat", "") == "knockback_taken")
				for i in range(1, v.size()):
					if descending:
						assert_lte(v[i], v[i - 1], "%s values only get stronger" % id)
					else:
						assert_gte(v[i], v[i - 1], "%s values only get stronger" % id)

func test_the_top_level_is_reachable_in_a_run_but_not_trivially() -> void:
	# events needed after unlock: (max - 1) * curve. Bounds: worth working for, achievable across four stages.
	for id in TABLE:
		var need: int = (TABLE[id][0] - 1) * TABLE[id][1]
		assert_gte(need, 4, "%s: the top level is not trivial (%d events)" % [id, need])
		assert_lte(need, 900, "%s: the top level is reachable (%d events)" % [id, need])

func test_appraisal_reaches_five_with_eight_first_time_inspections() -> void:
	var d: SkillDef = _defs()["appraisal"]
	assert_eq(d.max_level, 5)
	assert_eq((d.max_level - 1) * d.level_curve, 8, "eight first-time inspections, fewer than the creature types by the Grotto")

func test_the_bundled_content_still_validates() -> void:
	var loaded := DefLoader.load_content("res://data/skills", "res://data/creatures")
	assert_eq(loaded["errors"].size(), 0, str(loaded["errors"]))

func test_the_top_levels_are_reachable_against_what_their_sources_supply() -> void:
	var rooms := ShippedRooms.load_all()
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	# events one full pass of the Cave offers, by source
	var sound := 0
	var inspectable := 0
	var seen := {}
	for id in rooms:
		if (rooms[id] as RoomDef).area != "cave":
			continue  # this is the Cave's supply; the Grotto adds creature types
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			sound += int(c.essences.get("sound", 0))
			if c.appraisal_target and not seen.has(c.id):
				seen[c.id] = true
				inspectable += 1
	var defs := _defs()
	# Echolocation levels on absorbed sound: rooms respawn, so laps of the Cave farm it, but not in a handful
	var echo_needed: int = (defs["echolocation"].max_level - 1) * defs["echolocation"].level_curve
	assert_lte(echo_needed, sound * 6, "Echolocation's top level (%d sound) is within six laps of the Cave (%d per lap)" % [echo_needed, sound])
	assert_gt(echo_needed, sound, "and is more than a single lap, so it is not trivial")
	# Appraisal levels on the first inspection of each creature type: the Cave has few, the Grotto adds the rest
	var appraisal_needed: int = (defs["appraisal"].max_level - 1) * defs["appraisal"].level_curve
	assert_gt(appraisal_needed, inspectable, "the Cave alone cannot max Appraisal (%d needed, %d types)" % [appraisal_needed, inspectable])
	assert_lte(appraisal_needed, inspectable * 3, "and the whole game has enough creature types for it")
