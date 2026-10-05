extends GutTest
## Forms for more than one species: a form belongs to a species, each species has its own base, and the loader, the validator,
## the offers, the progress and the player take a species. The second species here is a fixture: the real wolf forms are later.

## A form with the five fields that matter to the tree.
static func make(id: String, species: String, stage: int, lineage: String, parents: Array) -> FormDef:
	var f := FormDef.new()
	f.id = id
	f.display_name = id
	f.species = species
	f.stage = stage
	f.lineage = lineage
	f.parents = parents
	return f

## One wolf line with two stage-3 children and a second wolf line.
static func wolf_forms() -> Dictionary:
	var out := {}
	for f in [
		make("wolf_moonbound", "wolf", 2, "moonbound", ["wolf"]),
		make("wolf_loup_garou", "wolf", 3, "moonbound", ["wolf_moonbound"]),
		make("wolf_ulfhedinn", "wolf", 3, "moonbound", ["wolf_moonbound"]),
		make("wolf_black_dog", "wolf", 2, "black_dog", ["wolf"]),
	]:
		out[f.id] = f
	return out

# --- Task 1: FormDef.species and a species-aware Form ---

func test_a_form_def_without_a_species_is_a_slime_form() -> void:
	assert_eq(FormDef.new().species, "slime")
	var forms := FormLoader.load_all()
	for id in forms:
		assert_eq((forms[id] as FormDef).species, "slime", id)

func test_is_base_knows_every_species_and_nothing_else() -> void:
	for s in Form.SPECIES:
		assert_true(Form.is_base(s), s)
	assert_false(Form.is_base("weaver"))
	assert_false(Form.is_base(""))

func test_a_wolf_body_starts_at_the_wolf_base() -> void:
	var f := Form.new("wolf")
	assert_eq(f.species, "wolf")
	assert_eq(f.form_id, "wolf")
	assert_eq(f.stage, 1)
	assert_eq(Form.new().form_id, "slime")

func test_a_wolf_body_advances_into_a_wolf_form_and_a_slime_body_does_not() -> void:
	var forms := wolf_forms()
	var wolf := Form.new("wolf")
	assert_true(wolf.advance("wolf_moonbound", forms))
	assert_eq(wolf.stage, 2)
	assert_eq(wolf.form_id, "wolf_moonbound")
	var slime := Form.new()
	assert_false(slime.advance("wolf_moonbound", forms))
	assert_eq(slime.stage, 1)
	assert_eq(slime.form_id, "slime")

func test_a_form_of_another_species_with_a_matching_parent_id_is_refused() -> void:
	var odd := make("odd", "wolf", 2, "x", ["slime"])
	assert_false(Form.new().advance("odd", {"odd": odd}), "the parent matches the slime base but the form is a wolf's")

func test_reset_returns_to_the_species_base() -> void:
	var f := Form.new("wolf")
	f.advance("wolf_moonbound", wolf_forms())
	f.reset()
	assert_eq(f.form_id, "wolf")
	assert_eq(f.stage, 1)

## The slime's 24 forms and the wolf fixture in one dictionary.
func _all() -> Dictionary:
	var out := FormLoader.load_all()
	out.merge(wolf_forms())
	return out

# --- Task 2: FormLoader species queries ---

func test_of_species_splits_a_mixed_dictionary() -> void:
	var all := _all()
	assert_eq(FormLoader.of_species(all, "wolf").size(), 4)
	assert_eq(FormLoader.of_species(all, "slime").size(), 24)
	assert_eq(FormLoader.of_species(all, "goblin").size(), 0)

func test_stage2_forms_default_to_the_slime() -> void:
	assert_eq(FormLoader.stage2_forms(_all()).size(), 6)

func test_stage2_forms_of_the_wolf_are_in_id_order() -> void:
	var ids: Array = FormLoader.stage2_forms(_all(), "wolf").map(func(f: FormDef) -> String: return f.id)
	assert_eq(ids, ["wolf_black_dog", "wolf_moonbound"])

func test_a_species_with_no_forms_has_no_stage2_forms() -> void:
	assert_eq(FormLoader.stage2_forms(_all(), "spider"), [])

# --- Task 3: FormValidator checks species, parentage and lineage ---

func _skill_ids() -> Array:
	var out: Array = []
	for d in DefLoader.load_dir("res://data/skills"):
		if d.source != "enemy_only":
			out.append(d.id)
	return out

func _errors(forms: Dictionary) -> PackedStringArray:
	return FormValidator.validate(forms, _skill_ids())

func test_the_fixture_species_passes_the_validator() -> void:
	assert_eq(_errors(wolf_forms()).size(), 0, str(_errors(wolf_forms())))

func test_the_slime_data_still_passes_beside_a_second_species() -> void:
	assert_eq(_errors(_all()).size(), 0, str(_errors(_all())))

func test_an_unknown_species_is_reported_once() -> void:
	var f := make("were", "werewolf", 2, "x", ["werewolf"])
	assert_eq(Array(_errors({"were": f})), ["were: unknown species 'werewolf'"])

func test_a_wolf_form_that_grows_from_the_slime_base_is_reported() -> void:
	var f := make("odd", "wolf", 2, "x", ["slime"])
	assert_eq(Array(_errors({"odd": f})), ["odd: parent 'slime' is another species' base"])

func test_a_wolf_form_that_grows_from_a_slime_form_is_reported() -> void:
	var all := FormLoader.load_all()
	all["odd3"] = make("odd3", "wolf", 3, "weaver", ["weaver"])
	assert_eq(Array(_errors(all)), ["odd3: parent 'weaver' is a slime form"])

func test_a_child_whose_lineage_differs_from_its_parents_is_reported() -> void:
	var all := wolf_forms()
	all["wolf_odd"] = make("wolf_odd", "wolf", 3, "x", ["wolf_moonbound"])
	assert_eq(Array(_errors(all)), ["wolf_odd: lineage 'x' differs from its parent's 'moonbound'"])

func test_a_wolf_form_with_no_lineage_is_reported() -> void:
	var f := make("wolf_blank", "wolf", 2, "", ["wolf"])
	assert_eq(Array(_errors({"wolf_blank": f})), ["wolf_blank: no lineage"])

func test_only_stage_two_forms_grow_from_a_wolf_base() -> void:
	var f := make("wolf_skip", "wolf", 3, "moonbound", ["wolf"])
	assert_string_contains("\n".join(_errors({"wolf_skip": f})), "only stage-2 forms grow from the base wolf")

# --- Task 4: FormOffers per species ---

## A stand-in for SkillRulesEngine: FormOffers only asks level_of.
class FakeRules:
	var levels := {}
	func level_of(id: String) -> int:
		return int(levels.get(id, 0))

func test_a_wolf_at_stage_one_is_offered_every_wolf_line() -> void:
	assert_eq(FormOffers.offers(_all(), Form.new("wolf"), FakeRules.new()), ["wolf_black_dog", "wolf_moonbound"])

func test_a_wolf_form_is_offered_its_children() -> void:
	var wolf := Form.new("wolf")
	wolf.advance("wolf_moonbound", _all())
	assert_eq(FormOffers.offers(_all(), wolf, FakeRules.new()), ["wolf_loup_garou", "wolf_ulfhedinn"])

func test_the_slime_offers_do_not_change_beside_a_wolf() -> void:
	assert_eq(FormOffers.offers(_all(), Form.new(), FakeRules.new()), ["greater_slime"])

func test_lineage_order_for_the_slime_is_the_six_lineages() -> void:
	assert_eq(FormOffers.lineage_order(_all()), ["weaver", "tide", "toxic", "bulwark", "echo", "greater"])

func test_lineage_order_for_the_wolf_follows_form_ids() -> void:
	assert_eq(FormOffers.lineage_order(_all(), "wolf"), ["black_dog", "moonbound"])

func test_a_species_with_no_forms_offers_nothing() -> void:
	assert_eq(FormOffers.offers({}, Form.new("spider"), FakeRules.new()), [])
	assert_eq(FormOffers.lineage_order({}, "spider"), [])
