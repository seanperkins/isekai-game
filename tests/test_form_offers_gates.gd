extends GutTest
## A wolf, undead, spider or goblin is offered the forms whose gates its run has met, and the rest are locked with what is missing.

var forms: Dictionary
var engine: SkillRulesEngine

func before_all() -> void:
	forms = FormLoader.load_all()

func before_each() -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.setup(DefLoader.load_dir("res://data/skills"))
	engine.start_run()

func _absorb(element: String, n: int) -> void:
	for i in n:
		engine.handle_event("absorbed", {"essence": element, "source": "bat"})

func _kill(tags: Dictionary, n: int) -> void:
	for i in n:
		engine.handle_event("defeated", tags.duplicate())

func _ids(defs: Array) -> Array:
	var out := defs.map(func(f: FormDef) -> String: return f.id)
	out.sort()
	return out

func _wolf() -> Form:
	return Form.new("wolf")

func test_a_new_wolf_is_offered_nothing_and_every_stage_two_form_is_locked() -> void:
	assert_eq(FormOffers.offers(forms, _wolf(), engine), [])
	assert_eq(_ids(FormOffers.locked(forms, _wolf(), engine)), ["wolf_black_dog", "wolf_moonbound", "wolf_warg"])

func test_the_black_dog_opens_on_its_essence_and_its_kills_from_behind() -> void:
	_absorb("dark", 13)
	_absorb("air", 13)
	assert_eq(FormOffers.offers(forms, _wolf(), engine), [], "the kills from behind are missing")
	_kill({"behind": true, "source": "bat"}, 5)
	assert_eq(FormOffers.offers(forms, _wolf(), engine), ["wolf_black_dog"])
	assert_false(_ids(FormOffers.locked(forms, _wolf(), engine)).has("wolf_black_dog"))

func test_a_form_that_waits_on_a_later_piece_is_never_offered_but_never_errors() -> void:
	_absorb("earth", 99)  # the Warg's essence, in plenty; its bonded packmate does not exist yet
	assert_false(FormOffers.offers(forms, _wolf(), engine).has("wolf_warg"))
	assert_true(_ids(FormOffers.locked(forms, _wolf(), engine)).has("wolf_warg"))

func test_stage_three_offers_only_the_children_of_the_current_form_whose_gate_is_met() -> void:
	var f := Form.new("wolf")
	assert_true(f.advance("wolf_black_dog", forms))
	_absorb("dark", 60)
	_absorb("air", 60)
	var offered := FormOffers.offers(forms, f, engine)
	for id in offered:
		assert_true((forms[id] as FormDef).parents.has("wolf_black_dog"), id)
	assert_false(offered.has("wolf_barghest"), "its Slink uses are missing")
	for i in 6:
		engine.handle_event("skill_used", {"id": "verb_wolf_black_dog"})
	assert_true(FormOffers.offers(forms, f, engine).has("wolf_barghest"))
	assert_false(FormOffers.offers(forms, f, engine).has("wolf_loup_garou"), "another line's form is never offered")

func test_the_slime_is_unchanged() -> void:
	assert_eq(FormOffers.locked(forms, Form.new("slime"), engine), [])
	_absorb("dark", 26)
	assert_true(FormOffers.offers(forms, Form.new("slime"), engine).has("weaver"))

func test_every_species_has_an_opening_set_of_locked_forms() -> void:
	for species in ["wolf", "undead", "spider", "goblin"]:
		var locked := FormOffers.locked(forms, Form.new(species), engine)
		assert_gt(locked.size(), 1, species)
		for f: FormDef in locked:
			assert_eq(f.species, species)
			assert_eq(f.stage, 2)

func test_a_stage_four_form_has_nothing_locked_below_it() -> void:
	var f := Form.new("wolf")
	f.stage = 4
	f.form_id = "wolf_fenrir"
	assert_eq(FormOffers.locked(forms, f, engine), [])
	assert_eq(FormOffers.offers(forms, f, engine), [])

func test_the_card_says_how_far_the_gate_has_got() -> void:
	_absorb("dark", 10)
	_kill({"behind": true}, 2)
	var card := SkillScreenModel.form_card(forms["wolf_black_dog"], engine)
	assert_eq(card["opened_progress"], "dark essence 10/13, air essence 0/13, kills from behind 2/5")
	_absorb("dark", 3)
	_absorb("air", 13)
	_kill({"behind": true}, 3)
	assert_eq(SkillScreenModel.form_card(forms["wolf_black_dog"], engine)["opened_progress"], "ready")
	assert_eq(SkillScreenModel.form_card(forms["weaver"], engine)["opened_progress"], "", "the slime has none")

func test_the_tree_card_has_a_needs_line_for_a_gated_form() -> void:
	var node := {"id": "wolf_black_dog", "kind": "form", "state": "named", "name": "Black Dog"}
	var card := SkillScreenModel._form_tree_card(engine, node, forms)
	assert_true(card["lines"].any(func(l: String) -> bool: return l.begins_with("Needs: dark essence 0/13")), str(card["lines"]))
	var slime := SkillScreenModel._form_tree_card(engine, {"id": "weaver", "kind": "form", "state": "named", "name": "Weaver"}, forms)
	assert_false(slime["lines"].any(func(l: String) -> bool: return l.begins_with("Needs:")))
