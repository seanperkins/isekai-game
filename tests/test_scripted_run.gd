extends GutTest
## Feeds a synthetic event sequence through the real content, engine, compendium and
## announcer, wired exactly as the autoloads wire them.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var announcer: AnnouncerQueue
var store: CompendiumStore
var dir: String
var unlock_order: Array

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creatures := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	dir = "user://gut_run_%d" % randi()
	store = CompendiumStore.new(dir.path_join("compendium.json"))
	store.warn = func(msg: String) -> void: fail_test(msg)
	compendium = CompendiumModel.new(skills, creatures, store)
	announcer = AnnouncerQueue.new()
	CoreWiring.connect_core(rules, compendium, announcer)
	unlock_order = []
	rules.skill_unlocked.connect(func(id: String) -> void: unlock_order.append(id))

func after_each() -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func _emit(ev: String, tags: Dictionary = {}, times: int = 1) -> void:
	for i in times:
		rules.handle_event(ev, tags)

func _eat(source: String, essences: Dictionary, kind: String = "creature") -> void:
	_emit("predated", {"source": source, "kind": kind})
	for ess in essences:
		for i in essences[ess]:
			_emit("absorbed", {"essence": ess, "source": source})

func test_a_full_run_then_death_then_second_run() -> void:
	rules.start_run()
	assert_eq(compendium.state("appraisal"), CompendiumModel.State.OWNED_ONCE)

	_emit("jumped", {"from": "ground"}, 40)             # Leap
	_emit("wall_touched", {}, 15)                        # Wall Cling
	for i in 3:
		_eat("bat", {"air": 2})           # Echolocation (air 6) on the 3rd bat
	_emit("damaged", {"damage_type": "poison"}, 6)       # Poison Resistance; also resets Glutton streak
	for i in 4:
		_eat("water_pool", {"water": 2}, "terrain")      # Hydraulic Propulsion (8 water)
	_emit("skill_used", {"id": "hydraulic_propulsion"}, 12)  # Lv3 -> Water Blade and Jet Dash are ready
	assert_true(rules.is_evolution_ready("water_blade"))
	assert_true(rules.evolve("water_blade"))  # the player would spend 1 EP

	# Glutton: 4 creature eats, a hit breaks the streak, then 5 clean eats.
	for i in 4:
		_eat("toad", {"water": 2, "dark": 1})
	_emit("damaged", {"damage_type": "physical"})
	assert_eq(rules.level_of("glutton"), 0)
	for i in 5:
		_eat("spider", {"water": 1, "dark": 1})
	assert_eq(rules.level_of("glutton"), 1)

	for id in ["leap", "wall_cling", "echolocation", "poison_resistance",
			"hydraulic_propulsion", "water_blade", "glutton"]:
		assert_eq(rules.level_of(id) >= 1, true, id)
	assert_lt(unlock_order.find("hydraulic_propulsion"), unlock_order.find("water_blade"))
	var hidden_unlocks := unlock_order.filter(func(id): return rules.get_def(id).hidden)
	assert_gte(hidden_unlocks.size(), 3)
	assert_gte(unlock_order.size(), 6)

	# Death, then rebirth.
	var death_log := rules.unlock_log()
	rules.reset_run()
	announcer.clear()
	assert_eq(death_log.size(), unlock_order.size())
	rules.start_run()
	assert_eq(rules.level_of("appraisal"), 1)
	assert_eq(rules.level_of("leap"), 0)
	for id in unlock_order:
		assert_eq(compendium.state(id), CompendiumModel.State.OWNED_ONCE, id)

	# The Compendium survives a reload from disk.
	var reloaded := CompendiumModel.new(DefLoader.load_dir("res://data/skills"),
		DefLoader.load_dir("res://data/creatures"), store)
	assert_eq(reloaded.state("water_blade"), CompendiumModel.State.OWNED_ONCE)

func test_unlocks_reach_announcer_and_levels_reach_ticker() -> void:
	rules.start_run()
	_emit("jumped", {}, 80)
	assert_eq(announcer.current()["id"], "leap")
	assert_eq(announcer.pop_ticker(), {"kind": "level", "id": "leap", "level": 2})
