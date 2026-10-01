extends GutTest
## Which bodies a slime is offered when it can evolve.

var forms := {}
var rooms := {}
var creatures := {}
var supply := {}

func before_all() -> void:
	forms = FormLoader.load_all()
	# These examples are the Cave's numbers (5 thread, and so on); the Grotto adds its own supply, tested below.
	var shipped := ShippedRooms.load_all()
	for id in shipped:
		var r: RoomDef = shipped[id]
		if r.area == "cave":
			rooms[id] = r
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	supply = FormOffers.supply(rooms, creatures, forms)

func _full_pass() -> Dictionary:
	var out := {}
	for id in rooms:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			for e in c.essences:
				out[e] = int(out.get(e, 0)) + int(c.essences[e])
	return out

func _only(creature_id: String) -> Dictionary:
	var out := {}
	for id in rooms:
		for s in (rooms[id] as RoomDef).spawns:
			if s["id"] != creature_id:
				continue
			var c: CreatureDef = creatures[s["id"]]
			for e in c.essences:
				out[e] = int(out.get(e, 0)) + int(c.essences[e])
	return out

func test_supply_counts_each_lineages_essences_across_every_spawn() -> void:
	# thread comes only from spiders, one each; the Cave has 5
	assert_eq(supply["weaver"], 5)
	assert_gt(supply["tide"], 0)
	assert_gt(supply["toxic"], 0)
	assert_gt(supply["bulwark"], 0)
	assert_gt(supply["echo"], 0)

func test_supply_grows_by_itself_when_a_spawn_is_added() -> void:
	var before: int = supply["weaver"]
	var extra := RoomDef.new()
	extra.id = "X1"
	extra.spawns = [{"id": "spider", "pos": Vector2.ZERO}]
	var more := rooms.duplicate()
	more["X1"] = extra
	assert_eq(FormOffers.supply(more, creatures, forms)["weaver"], before + 1)

func test_a_full_first_pass_gives_every_lineage_full_affinity() -> void:
	var a := FormOffers.affinity(_full_pass(), supply, forms)
	for l in FormOffers.LINEAGE_ORDER:
		assert_almost_eq(a[l], 1.0, 0.0001, l)

func test_a_full_pass_offers_weaver_tide_toxic_by_lineage_order() -> void:
	var f := Form.new()
	assert_eq(FormOffers.offers(forms, f, _full_pass(), supply), ["weaver", "tide", "toxic"])

func test_eating_only_bats_offers_echo_and_greater_slime() -> void:
	var f := Form.new()
	assert_eq(FormOffers.offers(forms, f, _only("bat"), supply), ["echo", "greater_slime"])

func test_nothing_eaten_offers_only_greater_slime() -> void:
	var f := Form.new()
	assert_eq(FormOffers.offers(forms, f, {}, supply), ["greater_slime"])

func test_one_eligible_lineage_is_offered_with_greater_slime() -> void:
	var f := Form.new()
	assert_eq(FormOffers.offers(forms, f, _only("spider"), supply), ["weaver", "greater_slime"], "5 thread of 5 is the whole lineage")

func test_two_or_more_eligible_never_add_greater_slime() -> void:
	var f := Form.new()
	var both := _only("bat")
	for e in _only("spider"):
		both[e] = int(both.get(e, 0)) + int(_only("spider")[e])
	var o := FormOffers.offers(forms, f, both, supply)
	assert_false(o.has("greater_slime"))
	assert_eq(o.size(), 2)

func test_a_lineage_needs_sixty_percent_to_be_eligible() -> void:
	var f := Form.new()
	var five: int = supply["weaver"]
	var three := {"thread": int(ceil(float(five) * 0.6))}
	assert_true(FormOffers.offers(forms, f, three, supply).has("weaver"))
	var two := {"thread": int(floor(float(five) * 0.6)) - 0}
	if float(two["thread"]) / float(five) < FormOffers.ELIGIBLE:
		assert_false(FormOffers.offers(forms, f, two, supply).has("weaver"))

func test_the_ratio_not_raw_units_decides_so_a_small_lineage_is_not_left_behind() -> void:
	var f := Form.new()
	# 5 thread (everything Weaver offers) beats 8 of Echo's larger supply
	var absorbed := {"thread": 5, "sound": 6}
	var o := FormOffers.offers(forms, f, absorbed, supply)
	assert_eq(o[0], "weaver")

func test_stage_two_offers_its_two_children_stage_three_its_sovereign_stage_four_nothing() -> void:
	var f := Form.new()
	f.advance("weaver", forms)
	assert_eq(FormOffers.offers(forms, f, {}, supply), ["arachne", "snare"])
	f.advance("snare", forms)
	assert_eq(FormOffers.offers(forms, f, {}, supply), ["silkbound"])
	f.advance("silkbound", forms)
	assert_eq(FormOffers.offers(forms, f, {}, supply), [])

func test_greater_slime_leads_to_vast_and_radiant_then_prime() -> void:
	var f := Form.new()
	f.advance("greater_slime", forms)
	assert_eq(FormOffers.offers(forms, f, {}, supply), ["radiant", "vast"])
	f.advance("vast", forms)
	assert_eq(FormOffers.offers(forms, f, {}, supply), ["prime"])

func test_absorbed_units_read_the_runs_ledger() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	rules.start_run()
	for i in 3:
		rules.handle_event("absorbed", {"essence": "sound", "source": "bat"})
	rules.handle_event("absorbed", {"essence": "thread", "source": "spider"})
	var u := FormOffers.absorbed_units(rules)
	assert_eq(u["sound"], 3)
	assert_eq(u["thread"], 1)
	assert_eq(u.get("water", 0), 0)

func test_the_first_evolution_areas_supply_includes_the_grotto() -> void:
	var all_rooms := ShippedRooms.load_all()
	var whole := FormOffers.supply(all_rooms, creatures, forms, FormOffers.FIRST_EVOLUTION_AREAS)
	assert_gt(whole["toxic"], supply["toxic"], "spore feeds Toxic")
	assert_gt(whole["bulwark"], supply["bulwark"], "shell feeds Bulwark")
	assert_gt(whole["weaver"], supply["weaver"], "the snake's thread feeds Weaver")

