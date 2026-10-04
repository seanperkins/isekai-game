extends GutTest
## The Tree tab's pure model: which powers, evolutions and forms show, in what state, joined by which edges, and where.

var skills: Array
var rules: SkillRulesEngine
var compendium: CompendiumModel
var by_id := {}

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	by_id = {}
	for d in skills:
		by_id[d.id] = d
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	rules.start_run()

func _build(forms := {}, reached: Array = [], current := "slime") -> Dictionary:
	return SkillTreeModel.build(rules, compendium, forms, reached, current)

func _discover_all() -> void:
	for id in compendium.states():
		compendium.raise(id, CompendiumModel.State.OWNED_ONCE)

func _player_skill_ids() -> Array:
	var out: Array = []
	for d in skills:
		if d.source != "enemy_only":
			out.append(d.id)
	out.sort()
	return out

## A base power with two evolutions, levelled until both are ready. Its price is water 2 and it holds water 1.
func _fixture_rules() -> SkillRulesEngine:
	var hydro := TestDefs.skill("hydraulic_propulsion", {"source": "essence",
		"unlock": [TestDefs.counter("absorbed", 1, {"essence": "water"})],
		"levels_on": {"event": "skill_used", "tags": {"id": "hydraulic_propulsion"}}, "level_curve": 2, "max_level": 8,
		"evolution_price": {"water": 2}})
	var evo := {"source": "evolution", "replaces": "hydraulic_propulsion", "unlock": [TestDefs.level("hydraulic_propulsion", 2)]}
	var defs := [hydro, TestDefs.skill("blade", evo.duplicate(true)), TestDefs.skill("dash", evo.duplicate(true))]
	var r: SkillRulesEngine = autofree(SkillRulesEngine.new())
	r.setup(defs)
	compendium = CompendiumModel.new(defs, [])
	CoreWiring.connect_core(r, compendium, AnnouncerQueue.new())
	r.start_run()
	for d in defs:
		compendium.raise(d.id, CompendiumModel.State.OWNED_ONCE)
	r.handle_event("absorbed", {"essence": "water"})
	for i in 2:
		r.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	return r

func _fixture_defs() -> Dictionary:
	var out := {}
	for id in ["hydraulic_propulsion", "blade", "dash"]:
		out[id] = rules.get_def(id)
	return out

# --- nodes, states and edges ---

func test_fully_discovered_every_player_skill_is_a_node_of_its_kind() -> void:
	_discover_all()
	var nodes: Dictionary = _build()["nodes"]
	var ids := nodes.keys()
	ids.sort()
	assert_eq(ids, _player_skill_ids())
	for id in nodes:
		assert_eq(nodes[id]["kind"], "evolution" if by_id[id].source == "evolution" else "power", id)
		assert_eq(nodes[id]["name"], by_id[id].display_name, id)

func test_every_evolution_has_exactly_one_parent_edge() -> void:
	_discover_all()
	var edges: Array = _build()["edges"]
	for d in skills:
		if d.source != "evolution":
			continue
		var into := edges.filter(func(e): return e["to"] == d.id)
		assert_eq(into.size(), 1, d.id)
		assert_eq(into[0]["from"], d.replaces, d.id)
		assert_eq(into[0]["kind"], "evolves", d.id)
		assert_true(into[0]["known"], d.id)

func test_a_new_soul_shows_only_its_starting_power() -> void:
	var m := _build()
	assert_eq(m["nodes"].keys(), ["appraisal"])
	assert_eq(m["nodes"]["appraisal"]["state"], SkillTreeModel.OWNED)
	assert_eq(m["edges"], [])

func test_an_unknown_evolution_of_an_owned_once_power_is_a_nameless_stub() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	var m := _build()
	for id in ["water_blade", "jet_dash"]:
		var n: Dictionary = m["nodes"][id]
		assert_eq(n["state"], SkillTreeModel.STUB, id)
		assert_eq(n.keys().filter(func(k): return k in ["name", "hint", "condition"]), [], "a stub carries no name and no ingredients")
	var edge: Array = m["edges"].filter(func(e): return e["to"] == "water_blade")
	assert_eq(edge.size(), 1)
	assert_false(edge[0]["known"], "an edge to a stub is drawn dim")

func test_a_merely_named_power_reveals_no_branches() -> void:
	compendium.raise("poison_breath", CompendiumModel.State.NAMED)
	var m := _build()
	assert_eq(m["nodes"]["poison_breath"]["state"], SkillTreeModel.NAMED)
	assert_false(m["nodes"]["poison_breath"].has("condition"))
	assert_false(m["nodes"].has("miasma"))
	assert_false(m["nodes"].has("venom_bolt"))
	assert_eq(m["edges"], [])

func test_an_edge_to_an_absent_parent_is_dropped() -> void:
	compendium.raise("miasma", CompendiumModel.State.NAMED)
	var m := _build()
	assert_eq(m["nodes"]["miasma"]["state"], SkillTreeModel.NAMED)
	assert_false(m["nodes"].has("poison_breath"))
	assert_eq(m["edges"], [], "never left dangling")

func test_only_owned_once_carries_the_condition() -> void:
	assert_ne(by_id["leap"].hint, "")
	compendium.raise("leap", CompendiumModel.State.HINTED)
	compendium.raise("wall_cling", CompendiumModel.State.OWNED_ONCE)
	var nodes: Dictionary = _build()["nodes"]
	assert_eq(nodes["leap"]["state"], SkillTreeModel.NAMED)
	assert_eq(nodes["leap"]["hint"], by_id["leap"].hint)
	assert_false(nodes["leap"].has("condition"))
	assert_eq(nodes["wall_cling"]["condition"], SkillScreenModel.condition_text(by_id["wall_cling"], by_id))
	assert_ne(nodes["wall_cling"]["condition"], "")

func test_a_secret_skill_leaves_no_trace_until_owned_once() -> void:
	assert_true(by_id["glutton"].secret)
	for st in [CompendiumModel.State.NAMED, CompendiumModel.State.HINTED]:
		compendium.raise("glutton", st)
		assert_false(_build()["nodes"].has("glutton"), str(st))
	compendium.raise("glutton", CompendiumModel.State.OWNED_ONCE)
	assert_true(_build()["nodes"].has("glutton"))

func test_every_edge_ends_on_a_visible_node_at_every_stage_of_discovery() -> void:
	var steps := [func(): pass,
		func(): compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE),
		func(): compendium.raise("miasma", CompendiumModel.State.NAMED),
		func(): _discover_all()]
	for step in steps:
		step.call()
		var m := _build()
		for e in m["edges"]:
			assert_true(m["nodes"].has(e["from"]) and m["nodes"].has(e["to"]), str(e))

func test_ready_retired_and_closed_come_from_the_engine() -> void:
	rules = _fixture_rules()
	var nodes: Dictionary = _build()["nodes"]
	assert_eq(nodes["hydraulic_propulsion"]["state"], SkillTreeModel.OWNED)
	assert_eq([nodes["blade"]["state"], nodes["dash"]["state"]], [SkillTreeModel.READY, SkillTreeModel.READY])
	rules.handle_event("absorbed", {"essence": "water"})  # the price is water 2
	assert_true(rules.evolve("blade"))
	nodes = _build()["nodes"]
	assert_eq(nodes["hydraulic_propulsion"]["state"], SkillTreeModel.RETIRED)
	assert_eq(nodes["blade"]["state"], SkillTreeModel.OWNED)
	assert_eq(nodes["dash"]["state"], SkillTreeModel.CLOSED)
