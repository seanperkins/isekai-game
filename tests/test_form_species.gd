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
