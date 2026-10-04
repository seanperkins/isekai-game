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

# --- layout ---

func _rects(m: Dictionary) -> Dictionary:
	var out := {}
	for id in m["nodes"]:
		out[id] = Rect2(m["nodes"][id]["pos"], SkillTreeModel.NODE_SIZE)
	return out

func _assert_no_overlap(rects: Dictionary) -> void:
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			assert_false(rects[ids[i]].intersects(rects[ids[j]]), "%s overlaps %s" % [ids[i], ids[j]])

func test_the_layout_is_deterministic_and_no_two_nodes_overlap() -> void:
	_discover_all()
	var a := _build()
	var ra := _rects(a)
	assert_eq(ra, _rects(_build()))
	_assert_no_overlap(ra)
	for id in ra:
		assert_true(Rect2(Vector2.ZERO, a["size"]).encloses(ra[id]), id + " is inside the canvas")

func test_discovering_a_node_never_moves_another() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	compendium.raise("leap", CompendiumModel.State.NAMED)
	var before := _rects(_build())
	_discover_all()
	var after := _rects(_build())
	for id in before:
		assert_eq(after[id], before[id], id)

func test_a_revealed_secret_takes_a_trailing_grid_cell_and_moves_nothing() -> void:
	for id in compendium.states():
		if id != "glutton":
			compendium.raise(id, CompendiumModel.State.OWNED_ONCE)
	var before := _rects(_build())
	assert_false(before.has("glutton"))
	compendium.raise("glutton", CompendiumModel.State.OWNED_ONCE)
	var after := _rects(_build())
	for id in before:
		assert_eq(after[id], before[id], id)
	var lowest := 0.0
	for id in before:
		if before[id].position.x >= 2.0 * SkillTreeModel.COL_PITCH:
			lowest = maxf(lowest, before[id].position.y)
	assert_gte(after["glutton"].position.y, lowest, "after every other grid power")

func test_the_evolving_powers_are_drawn_as_three_node_trees() -> void:
	_discover_all()
	var nodes: Dictionary = _build()["nodes"]
	for d in skills:
		if d.source != "evolution":
			continue
		var base: Vector2 = nodes[d.replaces]["pos"]
		var evo: Vector2 = nodes[d.id]["pos"]
		assert_eq(evo.x, base.x + SkillTreeModel.COL_PITCH, d.id + " sits one column right of its base")
		assert_true(evo.y >= base.y and evo.y <= base.y + SkillTreeModel.ROW_PITCH, d.id + " is level with its base or one row down")

func test_every_label_fits_its_node() -> void:
	_discover_all()
	var nodes: Dictionary = _build()["nodes"]
	var room := SkillTreeModel.NODE_SIZE.x - 2.0 * SkillTreeModel.LABEL_INSET
	for id in nodes:
		var w := ThemeDB.fallback_font.get_string_size(nodes[id]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, SkillScreen.FONT_SMALL).x
		assert_lte(w, room, nodes[id]["name"])

# --- navigation ---

func _walk(m: Dictionary) -> Dictionary:
	var start := SkillTreeModel.root(m)
	var seen := {start: true}
	var todo: Array = [start]
	while not todo.is_empty():
		var id: String = todo.pop_back()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := SkillTreeModel.neighbor(m, id, dir)
			if not seen.has(next):
				seen[next] = true
				todo.append(next)
	return seen

func test_walking_neighbor_from_the_root_reaches_every_node() -> void:
	var steps := [func(): pass,
		func(): compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE),
		func(): _discover_all()]
	for step in steps:
		step.call()
		var m := _build()
		var seen := _walk(m)
		for id in m["nodes"]:
			assert_true(seen.has(id), "%s is reachable from %s" % [id, SkillTreeModel.root(m)])

func test_neighbor_prefers_an_edge_and_stays_put_at_the_border() -> void:
	_discover_all()
	var m := _build()
	var right := SkillTreeModel.neighbor(m, "hydraulic_propulsion", Vector2i.RIGHT)
	assert_true(["water_blade", "jet_dash"].has(right), "an evolution, joined by an edge, first: got " + right)
	var top_left := SkillTreeModel.root(m)
	assert_eq(SkillTreeModel.neighbor(m, top_left, Vector2i.UP), top_left, "nothing above the top row")
	assert_eq(SkillTreeModel.neighbor(m, top_left, Vector2i.LEFT), top_left, "nothing left of column 0")
	assert_eq(SkillTreeModel.neighbor(m, "no_such_node", Vector2i.DOWN), "no_such_node")

func test_root_is_the_top_left_node() -> void:
	_discover_all()
	var m := _build()
	var r := SkillTreeModel.root(m)
	var rp: Vector2 = m["nodes"][r]["pos"]
	for id in m["nodes"]:
		var p: Vector2 = m["nodes"][id]["pos"]
		assert_true(rp.y < p.y or (rp.y == p.y and rp.x <= p.x), id)
	assert_eq(SkillTreeModel.root({"nodes": {}, "edges": [], "size": Vector2.ZERO}), "")

# --- the price and the card ---

func test_a_ready_evolution_says_whether_it_is_affordable() -> void:
	rules = _fixture_rules()
	assert_false(_build()["nodes"]["blade"]["affordable"], "holds water 1, the price is water 2")
	rules.handle_event("absorbed", {"essence": "water"})
	assert_true(_build()["nodes"]["blade"]["affordable"])
	assert_false(_build()["nodes"]["hydraulic_propulsion"].has("affordable"), "only a ready evolution carries it")

func test_the_price_line_names_the_price_what_you_hold_and_what_is_short() -> void:
	rules = _fixture_rules()
	assert_eq(SkillScreenModel.price_line(rules, "blade"), "Evolve for water 2 — you hold 1 water")
	assert_eq(SkillScreenModel.short_line(rules, "blade"), "Needs 1 more water")
	rules.handle_event("absorbed", {"essence": "water"})
	assert_eq(SkillScreenModel.short_line(rules, "blade"), "Evolve in the Skills tab")

func test_the_card_for_a_held_power_reuses_the_skill_detail() -> void:
	var card := SkillScreenModel.tree_card(rules, _build()["nodes"]["appraisal"], by_id, {}, ActiveSlots.new())
	var d := SkillScreenModel.detail(rules, by_id["appraisal"], ActiveSlots.new())
	assert_eq(card["title"], "Appraisal")
	assert_eq(card["status"], "Owned  Lv %d / %d" % [d["level"], d["max_level"]])
	assert_true(card["lines"].has(d["description"]))

func test_the_card_for_a_stub_says_nothing_about_it() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	var card := SkillScreenModel.tree_card(rules, _build()["nodes"]["water_blade"], by_id, {}, ActiveSlots.new())
	assert_eq(card, {"title": "???", "status": "Undiscovered", "lines": []})

func test_a_named_card_shows_the_hint_and_only_owned_once_shows_how() -> void:
	compendium.raise("leap", CompendiumModel.State.HINTED)
	compendium.raise("wall_cling", CompendiumModel.State.OWNED_ONCE)
	var nodes: Dictionary = _build()["nodes"]
	var leap := SkillScreenModel.tree_card(rules, nodes["leap"], by_id, {}, ActiveSlots.new())
	assert_eq(leap["status"], "Not yet learned")
	assert_true(leap["lines"].has(by_id["leap"].hint))
	assert_false(leap["lines"].any(func(l): return String(l).begins_with("How: ")))
	var cling := SkillScreenModel.tree_card(rules, nodes["wall_cling"], by_id, {}, ActiveSlots.new())
	assert_true(cling["lines"].has("How: " + SkillScreenModel.condition_text(by_id["wall_cling"], by_id)))

func test_a_ready_card_names_the_price_what_is_short_and_its_base() -> void:
	rules = _fixture_rules()
	var card := SkillScreenModel.tree_card(rules, _build()["nodes"]["blade"], _fixture_defs(), {}, ActiveSlots.new())
	assert_eq(card["status"], "Ready to evolve")
	assert_true(card["lines"].has("Evolve for water 2 — you hold 1 water"))
	assert_true(card["lines"].has("Needs 1 more water"))
	assert_true(card["lines"].has("Evolves from Hydraulic Propulsion"))

func test_a_power_with_no_unlock_condition_has_no_how_line() -> void:
	var node: Dictionary = _build()["nodes"]["appraisal"]
	var card := SkillScreenModel.tree_card(rules, node, by_id, {}, ActiveSlots.new())
	assert_false(card["lines"].any(func(l): return String(l).begins_with("How:")), "the starting power has nothing to do to earn it: %s" % str(card["lines"]))
