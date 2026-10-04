extends GutTest
## OpeningValidator: every mistake in the opening's data is named, a wrong type never crashes, and the shipped copy is sound.

func _good() -> OpeningDef:
	var d := OpeningDef.new()
	d.choices = [{"id": "dodge", "label": "Dodge"}, {"id": "jump", "label": "Jump"}]
	d.trucks = [
		{"prompt": "A truck is coming.", "results": {"dodge": "You step aside. It follows.", "jump": "You jump. It is taller."}},
		{"prompt": "Another truck.", "results": {"dodge": "Again.", "jump": "Higher."}},
	]
	d.fallback = "The truck does not care."
	d.goddess_line = "I am so sorry."
	return d

func _errors(d: OpeningDef) -> String:
	return "\n".join(OpeningValidator.validate(d))

func test_a_good_def_validates_clean() -> void:
	assert_eq(_errors(_good()), "")

func test_a_null_def_is_an_error_not_a_crash() -> void:
	assert_string_contains("\n".join(OpeningValidator.validate(null)), "opening: no data")

func test_each_mistake_is_named() -> void:
	var d := _good()
	d.choices = []
	assert_string_contains(_errors(d), "opening: choices must be a non-empty list")
	d = _good()
	d.trucks = []
	assert_string_contains(_errors(d), "opening: trucks must be a non-empty list")
	d = _good()
	d.choices[0]["id"] = ""
	assert_string_contains(_errors(d), "opening: choice 0 needs a non-blank string id and label")
	d = _good()
	d.choices[1]["label"] = "  "
	assert_string_contains(_errors(d), "opening: choice 1 needs a non-blank string id and label")
	d = _good()
	d.choices[1]["id"] = "dodge"
	assert_string_contains(_errors(d), "opening: duplicate choice id 'dodge'")
	d = _good()
	d.choices[1]["label"] = "Dodge"
	assert_string_contains(_errors(d), "opening: duplicate choice label 'Dodge'")
	d = _good()
	d.trucks[1]["prompt"] = ""
	assert_string_contains(_errors(d), "opening: truck 1 needs a non-blank prompt")
	d = _good()
	d.trucks[0]["results"]["pray"] = "Nothing."
	assert_string_contains(_errors(d), "opening: truck 0 results name 'pray', which is not a choice")
	d = _good()
	d.trucks[0]["results"]["jump"] = ""
	assert_string_contains(_errors(d), "opening: truck 0 result 'jump' needs a non-blank string line")
	d = _good()
	d.fallback = ""
	assert_string_contains(_errors(d), "opening: fallback is blank")
	d = _good()
	d.goddess_line = "   "
	assert_string_contains(_errors(d), "opening: goddess_line is blank")

func test_wrong_types_are_named_not_crashed() -> void:
	var d := _good()
	d.choices = [5]
	assert_string_contains(_errors(d), "opening: choice 0 must be a Dictionary")
	d = _good()
	d.choices[0]["id"] = 7
	assert_string_contains(_errors(d), "opening: choice 0 needs a non-blank string id and label")
	d = _good()
	d.trucks = [3]
	assert_string_contains(_errors(d), "opening: truck 0 must be a Dictionary")
	d = _good()
	d.trucks[0]["results"] = "none"
	assert_string_contains(_errors(d), "opening: truck 0 results must be a Dictionary")
	d = _good()
	d.trucks[1]["results"]["dodge"] = 5
	assert_string_contains(_errors(d), "opening: truck 1 result 'dodge' needs a non-blank string line")
	d = _good()
	d.trucks[0].erase("prompt")
	d.trucks[0].erase("results")
	assert_string_contains(_errors(d), "opening: truck 0 needs a non-blank prompt")

func test_the_shipped_opening_pins_its_shape() -> void:
	var d := load("res://data/opening/opening.tres") as OpeningDef
	assert_not_null(d, "data/opening/opening.tres loads as an OpeningDef")
	assert_eq(_errors(d), "")
	assert_eq(d.trucks.size(), 3)
	assert_eq(d.choices.map(func(c: Dictionary) -> String: return c["id"]), ["dodge", "jump", "pray", "run"])
	assert_ne(d.goddess_line.strip_edges(), "")
	var lines := {}
	for truck in d.trucks:
		for id in truck["results"]:
			lines[truck["results"][id]] = true
	assert_eq(lines.size(), 12, "three trucks times four choices, every line different")
