extends GutTest
## Which bodies a slime is offered when it can evolve: the lineages whose offer threshold its diet has met.

## A stand-in for SkillRulesEngine: FormOffers asks level_of (powers owned) and absorbed (the diet).
class FakeRules:
	var levels := {}
	var diet := {}
	func level_of(id: String) -> int:
		return int(levels.get(id, 0))
	func absorbed(element: String) -> int:
		return int(diet.get(element, 0))

var forms := {}

func before_all() -> void:
	forms = FormLoader.load_species()

func _rules(diet := {}, levels := {}) -> FakeRules:
	var r := FakeRules.new()
	r.levels = levels
	r.diet = diet
	return r

func test_lineage_powers_are_read_from_the_stage_two_forms() -> void:
	var p := FormOffers.lineage_powers(forms)
	assert_eq(p["weaver"], ["sticky_thread"])
	assert_eq(p["toxic"], ["poison_breath", "spore_cloud"])
	assert_eq(p["bulwark"], ["body_armor", "hardened_shell", "tremor"])
	assert_false(p.has("greater"), "the Greater lineage opens on nothing")

func test_the_gates_are_read_from_the_data() -> void:
	assert_eq(forms["echo"].reveal, {"air": 10})
	assert_eq(forms["echo"].offer, {"air": 34})
	assert_eq(forms["tide"].reveal, {"water": 16})
	assert_eq(forms["tide"].offer, {"water": 26})
	assert_eq(forms["toxic"].reveal, {"water": 10, "dark": 8})
	assert_eq(forms["toxic"].offer, {"water": 20, "dark": 14})
	assert_eq(forms["bulwark"].reveal, {"earth": 30})
	assert_eq(forms["bulwark"].offer, {"earth": 56})
	assert_eq(forms["weaver"].reveal, {"dark": 24})
	assert_eq(forms["weaver"].offer, {"dark": 26})
	assert_eq(forms["greater_slime"].reveal, {})

func test_a_lineage_is_revealed_at_its_threshold() -> void:
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"air": 9})), [])
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"air": 10})), ["echo"])

func test_toxic_needs_both_elements() -> void:
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"water": 10})), [], "water 10 is short of Tide's 16 and Toxic needs dark too")
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"water": 10, "dark": 8})), ["toxic"])

func test_a_power_helps_by_three_and_never_gates_alone() -> void:
	var thread := {"sticky_thread": 1}
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"dark": 21}, thread)), ["weaver"], "21 and a power's 3 make 24")
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"dark": 20}, thread)), [])
	var armour := {"body_armor": 1, "hardened_shell": 1, "tremor": 1}
	assert_eq(FormOffers.revealed_lineages(forms, _rules({}, armour)), [], "three powers are +9 against a threshold of 30: nothing alone")

func test_every_owned_power_of_a_lineage_adds_three() -> void:
	var both := {"poison_breath": 1, "spore_cloud": 1}
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"water": 4, "dark": 2}, both)), ["toxic"], "two powers are +6 on each element")
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"water": 4, "dark": 2}, {"poison_breath": 1})), [])

func test_an_evolved_power_still_counts_as_owned() -> void:
	# level_of keeps answering the level a retired parent reached, so Poison Breath becoming Miasma does not cost Toxic its bonus
	assert_eq(FormOffers.revealed_lineages(forms, _rules({"water": 7, "dark": 5}, {"poison_breath": 4})), ["toxic"])

func test_revealed_lineages_come_back_in_lineage_order() -> void:
	var diet := {"air": 12, "earth": 40, "water": 20, "dark": 30}
	assert_eq(FormOffers.revealed_lineages(forms, _rules(diet)), ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_offered_needs_the_higher_number() -> void:
	assert_eq(FormOffers.offered_lineages(forms, _rules({"air": 33})), [])
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({"air": 33})), ["greater_slime"])
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({"air": 34})), ["echo", "greater_slime"])

func test_a_fresh_life_offers_only_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules()), ["greater_slime"])

func test_two_offered_lineages_never_add_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({"air": 34, "earth": 56})), ["bulwark", "echo"])

func test_every_offered_lineage_is_offered_with_no_cap_and_no_ranking() -> void:
	var all := _rules({"air": 34, "earth": 56, "water": 26, "dark": 26})
	assert_eq(FormOffers.offers(forms, Form.new(), all), ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_stage_two_offers_its_two_children_stage_three_its_sovereign_stage_four_nothing() -> void:
	var f := Form.new()
	var none := _rules({})
	f.advance("weaver", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["arachne", "snare"])
	f.advance("snare", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["gleipnir", "silkbound"])
	f.advance("silkbound", forms)
	assert_eq(FormOffers.offers(forms, f, none), [])

func test_greater_slime_leads_to_vast_and_radiant_then_prime() -> void:
	var f := Form.new()
	var none := _rules({})
	f.advance("greater_slime", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["radiant", "vast"])
	f.advance("vast", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["prime", "shoggoth"])

func test_a_real_engine_reveals_a_lineage_from_absorbed_essence() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	rules.start_run()
	assert_eq(FormOffers.revealed_lineages(forms, rules), [], "a fresh life has absorbed nothing")
	for i in 16:
		rules.handle_event("absorbed", {"essence": "water", "source": "test"})
	assert_eq(FormOffers.revealed_lineages(forms, rules), ["tide"])
