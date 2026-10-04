extends GutTest
## Which bodies a slime is offered when it can evolve: every lineage whose power it has reached.

## A stand-in for SkillRulesEngine: FormOffers only asks level_of.
class FakeRules:
	var levels := {}
	func level_of(id: String) -> int:
		return int(levels.get(id, 0))

var forms := {}

func before_all() -> void:
	forms = FormLoader.load_all()

func _rules(levels: Dictionary) -> FakeRules:
	var r := FakeRules.new()
	r.levels = levels
	return r

func test_lineage_powers_are_read_from_the_stage_two_forms() -> void:
	var p := FormOffers.lineage_powers(forms)
	assert_eq(p["weaver"], ["sticky_thread"])
	assert_eq(p["toxic"], ["poison_breath", "spore_cloud"])
	assert_eq(p["bulwark"], ["body_armor", "hardened_shell", "tremor"])
	assert_false(p.has("greater"), "the Greater lineage opens on nothing")

func test_a_lineage_is_open_when_one_of_its_powers_has_been_reached() -> void:
	assert_eq(FormOffers.open_lineages(forms, _rules({})), [])
	assert_eq(FormOffers.open_lineages(forms, _rules({"sticky_thread": 1})), ["weaver"])
	assert_eq(FormOffers.open_lineages(forms, _rules({"spore_cloud": 2})), ["toxic"], "either of Toxic's powers opens it")

func test_a_power_that_evolved_away_still_opens_its_lineage() -> void:
	# level_of keeps answering the level a retired parent reached, so Poison Breath becoming Miasma does not close Toxic
	assert_eq(FormOffers.open_lineages(forms, _rules({"poison_breath": 4})), ["toxic"])

func test_open_lineages_come_back_in_lineage_order_whatever_was_reached_first() -> void:
	var r := _rules({"echolocation": 5, "tremor": 1, "hydraulic_propulsion": 3, "sticky_thread": 2})
	assert_eq(FormOffers.open_lineages(forms, r), ["weaver", "tide", "bulwark", "echo"])

func test_every_open_lineage_is_offered_with_no_cap_and_no_ranking() -> void:
	var all := _rules({"sticky_thread": 1, "hydraulic_propulsion": 1, "poison_breath": 1, "body_armor": 1, "echolocation": 1})
	assert_eq(FormOffers.offers(forms, Form.new(), all), ["weaver", "tide", "toxic", "bulwark", "echo"])

func test_nothing_reached_offers_only_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({})), ["greater_slime"])

func test_one_open_lineage_is_offered_with_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({"echolocation": 1})), ["echo", "greater_slime"])

func test_two_open_lineages_never_add_greater_slime() -> void:
	assert_eq(FormOffers.offers(forms, Form.new(), _rules({"echolocation": 1, "tremor": 1})), ["bulwark", "echo"])

func test_stage_two_offers_its_two_children_stage_three_its_sovereign_stage_four_nothing() -> void:
	var f := Form.new()
	var none := _rules({})
	f.advance("weaver", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["arachne", "snare"])
	f.advance("snare", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["silkbound"])
	f.advance("silkbound", forms)
	assert_eq(FormOffers.offers(forms, f, none), [])

func test_greater_slime_leads_to_vast_and_radiant_then_prime() -> void:
	var f := Form.new()
	var none := _rules({})
	f.advance("greater_slime", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["radiant", "vast"])
	f.advance("vast", forms)
	assert_eq(FormOffers.offers(forms, f, none), ["prime"])

func test_a_real_engine_opens_a_lineage_when_a_power_is_granted_quietly() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	rules.start_run()
	assert_eq(FormOffers.open_lineages(forms, rules), [], "a fresh life owns only Appraisal")
	rules.grant("hydraulic_propulsion", false)  # a rebirth kit's way of giving a skill
	assert_eq(FormOffers.open_lineages(forms, rules), ["tide"])
