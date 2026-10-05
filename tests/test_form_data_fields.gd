extends GutTest
## What a form carries beyond its stats: the essences it reads, where it is found, and the words about what it does.

func _skill_ids() -> Array:
	var out: Array = []
	for d in DefLoader.load_dir("res://data/skills"):
		if d.source != "enemy_only":
			out.append(d.id)
	return out

func _errors(forms: Dictionary) -> PackedStringArray:
	return FormValidator.validate(forms, _skill_ids())

func _wolf(id: String, fields := {}) -> FormDef:
	var f := FormDef.new()
	f.id = id
	f.display_name = id
	f.species = "wolf"
	f.stage = 2
	f.lineage = "moonbound"
	f.parents = ["wolf"]
	for k in fields:
		f.set(k, fields[k])
	return f

func test_the_new_fields_default_to_empty() -> void:
	var f := FormDef.new()
	assert_eq(f.reads, [])
	assert_eq(f.host, [])
	for s in [f.source, f.verb_text, f.gives_up, f.opened_by]:
		assert_eq(s, "")

func test_every_slime_form_still_loads_and_validates() -> void:
	assert_eq(Array(_errors(FormLoader.load_species())), [])

func test_a_form_may_read_a_later_element() -> void:
	var f := _wolf("w", {"reads": ["dark", "blood"], "host": ["forest"]})
	assert_eq(Array(_errors({"w": f})), [])

func test_an_unknown_element_in_reads_is_reported() -> void:
	var f := _wolf("w", {"reads": ["ether"]})
	assert_eq(Array(_errors({"w": f})), ["w: reads unknown essence 'ether'"])

func test_an_unknown_area_in_host_is_reported() -> void:
	var f := _wolf("w", {"host": ["moon"]})
	assert_eq(Array(_errors({"w": f})), ["w: host names unknown area 'moon'"])

func test_load_species_filters() -> void:
	assert_eq(FormLoader.load_species("wolf").size(), 21, "the wolf's forms are in the data since A3")
	assert_eq(FormLoader.load_species().size(), 24)
