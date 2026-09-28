extends GutTest
## Bestiary: each creature is unknown until seen, then appraised (up to the best Appraisal
## level used on it), then eaten. Records persist in the Compendium save.

var model: CompendiumModel
var creatures: Array
var dir: String

func before_each() -> void:
	creatures = DefLoader.load_dir("res://data/creatures")
	model = CompendiumModel.new(DefLoader.load_dir("res://data/skills"), creatures)
	dir = "user://test_bestiary_%d" % Time.get_ticks_usec()

func after_each() -> void:
	for f in ["compendium.json", "compendium.json.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))

func test_a_new_bestiary_knows_nothing() -> void:
	assert_eq(model.creature_record("bat"), {"seen": false, "appraisal": 0, "eaten": 0, "defeated": 0})

func test_seeing_defeating_and_eating_are_recorded() -> void:
	model.on_creature_seen("bat")
	model.on_creature_defeated("bat")
	model.on_game_event(Events.PREDATED, {"source": "bat", "kind": "creature"})
	model.on_game_event(Events.PREDATED, {"source": "bat", "kind": "creature"})
	model.on_game_event(Events.PREDATED, {"source": "water_pool", "kind": "terrain"})
	assert_eq(model.creature_record("bat"), {"seen": true, "appraisal": 0, "eaten": 2, "defeated": 1})
	assert_eq(model.creature_record("water_pool")["eaten"], 0)

func test_appraisal_keeps_the_best_level_used() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup([])
	model.on_inspect_processed({"target": "toad", "appraisal_target": true}, 2, rules)
	model.on_inspect_processed({"target": "toad", "appraisal_target": true}, 1, rules)
	assert_eq(model.creature_record("toad")["appraisal"], 2)
	assert_true(model.creature_record("toad")["seen"])

func test_bestiary_lists_creatures_but_not_terrain() -> void:
	var ids := model.bestiary_ids()
	assert_true(ids.has("bat"))
	assert_false(ids.has("water_pool"))

func test_records_survive_a_reload_alongside_skill_states() -> void:
	var store := CompendiumStore.new(dir.path_join("compendium.json"))
	var m := CompendiumModel.new(DefLoader.load_dir("res://data/skills"), creatures, store)
	m.raise("leap", CompendiumModel.State.NAMED)
	m.on_creature_seen("lizard")
	m.on_game_event(Events.PREDATED, {"source": "lizard", "kind": "creature"})
	var again := CompendiumModel.new(DefLoader.load_dir("res://data/skills"), creatures, store)
	assert_eq(again.state("leap"), CompendiumModel.State.NAMED)
	assert_eq(again.creature_record("lizard"), {"seen": true, "appraisal": 0, "eaten": 1, "defeated": 0})

func test_a_bad_creature_entry_is_dropped_but_skills_load() -> void:
	var store := CompendiumStore.new(dir.path_join("compendium.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(dir.path_join("compendium.json"), FileAccess.WRITE)
	f.store_string('{"version": 1, "slots": {"leap": "named"}, "creatures": {"bat": {"eaten": "lots"}, "toad": {"seen": true, "appraisal": 1, "eaten": 0, "defeated": 3}}}')
	f.close()
	var m := CompendiumModel.new(DefLoader.load_dir("res://data/skills"), creatures, store)
	assert_eq(m.state("leap"), CompendiumModel.State.NAMED)
	assert_eq(m.creature_record("bat")["eaten"], 0)
	assert_eq(m.creature_record("toad"), {"seen": true, "appraisal": 1, "eaten": 0, "defeated": 3})

func test_rows_reveal_by_record() -> void:
	model.on_creature_seen("bat")
	model.on_game_event(Events.PREDATED, {"source": "bat", "kind": "creature"})
	model.on_creature_seen("lizard")
	var rows := SkillScreenModel.bestiary_rows(model)
	var by_id := {}
	assert_eq(rows[0]["kind"], "header")
	for r in rows.slice(1):
		by_id[r["id"]] = r
	assert_eq([by_id["bat"]["name"], by_id["bat"]["status"]], ["Cave Bat", "eaten ×1"])
	assert_eq([by_id["lizard"]["name"], by_id["lizard"]["status"]], ["Armored Lizard", "seen"])
	assert_eq([by_id["spider"]["name"], by_id["spider"]["status"]], ["???", ""])

func test_detail_grows_with_appraisal_and_eating() -> void:
	model.on_creature_seen("bat")
	var seen := SkillScreenModel.bestiary_detail(model, "bat")
	assert_eq(seen["name"], "Cave Bat")
	assert_false(seen.has("stats"))
	model.on_game_event(Events.PREDATED, {"source": "bat", "kind": "creature"})
	var eaten := SkillScreenModel.bestiary_detail(model, "bat")
	assert_true(eaten.has("essences"))
	assert_false(eaten.has("stats"))
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup([])
	model.on_inspect_processed({"target": "bat", "appraisal_target": true}, 3, rules)
	var full := SkillScreenModel.bestiary_detail(model, "bat")
	assert_true(full.has("stats"))
	assert_true(full.has("skills"))
	assert_eq(SkillScreenModel.bestiary_detail(model, "spider")["name"], "???")
