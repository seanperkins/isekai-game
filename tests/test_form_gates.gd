extends GutTest
## A lineage form's reveal and offer thresholds: what it asks of the diet to show in the Tree tab and to be offered.

func _skill_ids() -> Array:
	var out: Array = []
	for d in DefLoader.load_dir("res://data/skills"):
		if d.source != "enemy_only":
			out.append(d.id)
	return out

## A slime stage-2 lineage form that is valid except for what a test sets.
func _lineage(fields := {}) -> FormDef:
	var f := FormDef.new()
	f.id = "x"
	f.display_name = "X"
	f.stage = 2
	f.lineage = "weaver"
	f.parents = ["slime"]
	f.powers = ["sticky_thread"]
	for k in fields:
		f.set(k, fields[k])
	return f

func _errors(f: FormDef) -> Array:
	return Array(FormValidator.validate({f.id: f}, _skill_ids()))

func test_the_fields_default_to_empty() -> void:
	assert_eq(FormDef.new().reveal, {})
	assert_eq(FormDef.new().offer, {})

func test_a_valid_gate_passes() -> void:
	assert_eq(_errors(_lineage({"reveal": {"dark": 24}, "offer": {"dark": 26}})), [])

func test_reveal_names_a_known_essence() -> void:
	assert_eq(_errors(_lineage({"reveal": {"ether": 5}, "offer": {"ether": 6}})),
		["x: reveal names unknown essence 'ether'", "x: offer names unknown essence 'ether'"])

func test_an_amount_must_be_positive() -> void:
	assert_eq(_errors(_lineage({"reveal": {"dark": 0}, "offer": {"dark": 4}})), ["x: reveal of 'dark' must be positive"])
	assert_eq(_errors(_lineage({"reveal": {"dark": 4}, "offer": {"dark": -1}})),
		["x: offer of 'dark' must be positive", "x: offer of 'dark' is below its reveal"])

func test_offer_names_the_same_elements_as_reveal() -> void:
	assert_eq(_errors(_lineage({"reveal": {"dark": 4}, "offer": {"water": 6}})), ["x: offer must name the same elements as its reveal"])

func test_an_offer_below_its_reveal_is_reported() -> void:
	assert_eq(_errors(_lineage({"reveal": {"dark": 24}, "offer": {"dark": 20}})), ["x: offer of 'dark' is below its reveal"])

func test_only_a_stage_two_lineage_form_carries_a_gate() -> void:
	var later := _lineage({"stage": 3, "parents": ["weaver"], "powers": [], "reveal": {"dark": 4}, "offer": {"dark": 5}})
	assert_string_contains("\n".join(FormValidator.validate({"weaver": FormLoader.load_species()["weaver"], "x": later}, _skill_ids())),
		"x: only a stage-2 lineage form carries a reveal and an offer")

func test_greater_slime_has_no_gate() -> void:
	var g := _lineage({"lineage": "greater", "powers": [], "reveal": {"dark": 4}, "offer": {"dark": 5}})
	assert_eq(_errors(g), ["x: only a stage-2 lineage form carries a reveal and an offer"])
