extends GutTest
## A verb for every form of the four non-slime species, each cast for real in a fresh arena.

const DAMAGING := ["bolt", "burst", "ring", "dash", "mark", "chain", "dissolve", "engulf"]

func _rows() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tools/form_verbs.json"))

func _rows_of(species: Array) -> Array:
	return _rows().filter(func(r: Dictionary) -> bool: return ResourceLoader.exists("res://data/forms/%s.tres" % r["form"]) and species.has(load("res://data/forms/%s.tres" % r["form"]).species))

func _forms_of(species: Array) -> Array:
	return FormLoader.load_all().values().filter(func(f: FormDef) -> bool: return species.has(f.species))

func _check_species(species: Array, expected_forms: int) -> void:
	var forms := _forms_of(species)
	assert_eq(forms.size(), expected_forms)
	var rowed: Array = _rows_of(species).map(func(r: Dictionary) -> String: return r["form"])
	for f in forms:
		assert_true(rowed.has(f.id), "%s has a verb row" % f.id)
		assert_eq(f.verb, "verb_" + f.id, f.id)
		assert_true(f.grants.has(f.verb), f.id)
	assert_eq(rowed.size(), expected_forms, "no row for a form that is not there")

func _check_verbs_do_something(species: Array) -> void:
	var arena := VerbArena.new(self)
	for row in _rows_of(species):
		arena.fresh()
		var did: bool = await arena.changes_something(row["form"])
		assert_true(did, "%s (%s) did something" % [row["name"], row["form"]])
		arena.clean()

# --- wolf and undead ---

func test_every_wolf_and_undead_form_has_a_verb() -> void:
	_check_species(["wolf"], 21)
	_check_species(["undead"], 29)

func test_each_wolf_and_undead_verb_does_something_in_a_fresh_arena() -> void:
	await _check_verbs_do_something(["wolf", "undead"])

# --- spider and goblin ---

func test_every_spider_and_goblin_form_has_a_verb() -> void:
	_check_species(["spider"], 21)
	_check_species(["goblin"], 28)

func test_each_spider_and_goblin_verb_does_something_in_a_fresh_arena() -> void:
	await _check_verbs_do_something(["spider", "goblin"])

func test_every_form_but_the_built_slime_ones_has_a_verb_and_they_have_none() -> void:
	var with_verb := 0
	for f in FormLoader.load_all().values():
		if f.verb != "":
			with_verb += 1
		elif f.species != "slime" or f.id == "quicksilver_slime":
			assert_eq(f.species == "slime", true, "%s has no verb" % f.id)  # only Quicksilver and the 24 built slime forms are without
		else:
			assert_true(["weaver", "snare", "silkbound", "arachne", "tide", "brook", "tidal", "tempest", "toxic", "acid", "venom", "blight", "bulwark", "golem", "stone", "crystal", "echo", "phantom", "storm", "sky", "greater_slime", "vast", "prime", "radiant"].has(f.id), f.id)
	assert_eq(with_verb, 99 + 17, "99 for the other species and the slime's 17")

# --- every row ---

func test_every_row_names_a_form_that_exists() -> void:
	for row in _rows():
		assert_true(ResourceLoader.exists("res://data/forms/%s.tres" % row["form"]), "%s is a form" % row["form"])

func test_the_data_validates_with_every_verb() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var verb_ids: Array = skills.filter(func(d: SkillDef) -> bool: return d.source == "form_verb").map(func(d: SkillDef) -> String: return d.id)
	var skill_ids: Array = skills.map(func(d: SkillDef) -> String: return d.id)
	assert_eq(Array(FormValidator.validate(FormLoader.load_all(), skill_ids, true, verb_ids)), [])
	assert_eq(Array(DefValidator.validate(skills, DefLoader.load_dir("res://data/creatures"))), [])

func test_a_verb_that_hurts_lists_a_value_and_costs_a_sane_amount() -> void:
	for row in _rows():
		var spec: Dictionary = row["spec"]
		var hurts: bool = DAMAGING.has(spec["kind"]) or bool(spec.get("damage", false))
		if hurts and spec["kind"] != "engulf":
			assert_gt(int(row["value"]), 0, "%s hurts, so it has a damage value" % row["form"])
		assert_between(int(row["mp"]), 2, 9, row["form"])
		if spec.has("cooldown"):
			assert_between(float(spec["cooldown"]), 1.0, 25.0, row["form"])

func test_a_row_that_says_full_has_no_note_and_one_that_does_not_has_one() -> void:
	for row in _rows():
		assert_eq(str(row["note"]) == "", row["fidelity"] == "full", row["form"])
