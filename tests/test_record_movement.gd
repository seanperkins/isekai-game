extends GutTest
## A recorded run: the sandbox's own movement, tick by tick, as the 3D stage will replay it.

var rec: MovementRecorder

func before_each() -> void:
	rec = MovementRecorder.new()
	add_child_autofree(rec)

func test_a_goblin_hops_the_ledges_and_ends_standing() -> void:
	var r: Dictionary = await rec.record("goblin", "jump_ledges")
	var ticks: Array = r["ticks"]
	assert_almost_eq(float(ticks[0]["x"]), 376.0, 1.0, "it starts where the script puts it: on the floor between the slick block and the first ledge")
	assert_almost_eq(float(ticks[0]["y"]), 0.0, 1.0, "on the floor")
	assert_eq(r["start"], [ticks[0]["x"], ticks[0]["y"]], "the record says where it started")
	assert_almost_eq(float(ticks[1]["t"]) - float(ticks[0]["t"]), 1.0 / 60.0, 0.0002, "a tick is a sixtieth of a second")
	var highest := 0.0
	for t: Dictionary in ticks:
		highest = minf(highest, float(t["y"]))
		assert_between(float(t["x"]), -40.0, 1440.0, "inside the walls")
		assert_between(float(t["y"]), -400.0, 40.0, "inside the course")
	assert_lt(highest, -40.0, "it got more than 40 px above the floor")
	assert_true(ticks[-1]["on_floor"], "it ends standing")

func test_an_unknown_species_or_script_records_nothing() -> void:
	assert_eq(await rec.record("dragon", "jump_ledges"), {})
	assert_eq(await rec.record("goblin", "dance"), {})
	assert_eq(await rec.record("goblin", "crawl"), {}, "a goblin does not crawl")

func _surfaces(r: Dictionary) -> Array:
	var seen: Array = []
	for t: Dictionary in r["ticks"]:
		if not seen.has(t["surface"]):
			seen.append(t["surface"])
	return seen

func test_every_species_runs_every_script_it_is_given_and_stays_in_the_course() -> void:
	for species: String in MovementRecorder.SCRIPTS_FOR:
		for script_name: String in MovementRecorder.scripts_for(species):
			var r: Dictionary = await rec.record(species, script_name)
			assert_false(r.is_empty(), "%s %s" % [species, script_name])
			var ticks: Array = r["ticks"]
			assert_gt(ticks.size(), 60, "%s %s runs for a while" % [species, script_name])
			for k in ticks.size():
				assert_almost_eq(float(ticks[k]["t"]), float(k) / 60.0, 0.0002, "%s %s tick %d" % [species, script_name, k])
			var lowest := -INF
			for t: Dictionary in ticks:
				lowest = maxf(lowest, float(t["y"]))
				if float(t["x"]) < -40.0 or float(t["x"]) > 1440.0 or float(t["y"]) < -400.0 or float(t["y"]) > 40.0:
					fail_test("%s %s left the course at %s" % [species, script_name, str(t)])
					break
			assert_true(ticks[-1]["on_floor"] or ticks[-1]["surface"] != "air", "%s %s ends on something" % [species, script_name])

func test_a_goblin_mantles_the_first_ledge_it_cannot_jump_onto_and_the_record_says_so() -> void:
	assert_has(_surfaces(await rec.record("goblin", "jump_ledges")), "mantle")

func test_the_goblin_and_the_slime_climb_the_shaft_by_wall_jumps() -> void:
	for species in ["goblin", "slime"]:
		var r: Dictionary = await rec.record(species, "wall_shaft")
		var highest := 0.0
		for t: Dictionary in r["ticks"]:
			highest = minf(highest, float(t["y"]))
		assert_lt(highest, -250.0, "%s climbed the 300 px shaft" % species)
		assert_has(_surfaces(r), "wall")

func test_the_spider_crawls_up_a_wall_over_the_slab_and_hangs_under_it() -> void:
	var r: Dictionary = await rec.record("spider", "crawl")
	var seen := _surfaces(r)
	for s in ["floor", "wall", "ceiling"]:
		assert_has(seen, s)
	var normals: Array = []
	for t: Dictionary in r["ticks"]:
		if t["surface"] == "ceiling":
			normals.append(t["normal"])
	assert_eq(normals[0], [0.0, 1.0], "hanging under the slab, the surface faces down")

func test_the_wolf_pounces() -> void:
	var r: Dictionary = await rec.record("wolf", "pounce")
	var verbs: Array = r["ticks"].map(func(t: Dictionary) -> String: return t["verb"])
	assert_has(verbs, "pounce")

func test_a_record_leaves_no_sandbox_behind() -> void:
	await rec.record("goblin", "walk_run")
	assert_eq(rec.get_child_count(), 0)

func test_a_script_with_no_start_begins_at_the_sandboxs_start() -> void:
	var r: Dictionary = await rec.record("goblin", "walk_run")
	assert_almost_eq(float(r["ticks"][0]["x"]), MovementSandbox.START.x, 1.0)
	assert_almost_eq(float(r["ticks"][0]["y"]), MovementSandbox.START.y, 1.0)

func test_a_crawler_has_a_speed_though_its_velocity_is_zero() -> void:
	var r: Dictionary = await rec.record("spider", "walk_run")
	var fastest := 0.0
	for t: Dictionary in r["ticks"]:
		assert_true(t["crawl"], "the spider is on a surface it crawls, floor or not")
		assert_eq(t["vx"], 0.0, "it moves by shifting its body")
		fastest = maxf(fastest, float(t["speed"]))
	assert_gt(fastest, 60.0, "its speed is read from where the body was")

func test_a_walker_has_its_velocity_as_its_speed_and_does_not_crawl() -> void:
	var r: Dictionary = await rec.record("goblin", "walk_run")
	for t: Dictionary in r["ticks"]:
		assert_false(t["crawl"])
		assert_almost_eq(float(t["speed"]), absf(float(t["vx"])), 0.01)

func test_a_speed_does_not_spike_where_a_crawler_turns_a_corner() -> void:
	var r: Dictionary = await rec.record("spider", "crawl")
	var fastest := 0.0
	for t: Dictionary in r["ticks"]:
		fastest = maxf(fastest, float(t["speed"]))
	assert_lt(fastest, 160.0, "the body wraps round a corner in a tick: that is not a speed")
