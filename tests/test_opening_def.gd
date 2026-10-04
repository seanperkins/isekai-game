extends GutTest
## The opening's data: a truck's result line for a choice, else the fallback.

func _def() -> OpeningDef:
	var d := OpeningDef.new()
	d.choices = [{"id": "dodge", "label": "Dodge"}, {"id": "jump", "label": "Jump"}]
	d.trucks = [
		{"prompt": "A truck is coming.", "results": {"dodge": "You step aside. It follows.", "jump": "You jump. It is taller."}},
		{"prompt": "Another truck.", "results": {"dodge": "Again."}},
	]
	d.fallback = "The truck does not care."
	d.goddess_line = "I am so sorry."
	return d

func test_result_for_returns_the_trucks_line_else_the_fallback() -> void:
	var d := _def()
	assert_eq(d.result_for(0, "dodge"), "You step aside. It follows.")
	assert_eq(d.result_for(0, "jump"), "You jump. It is taller.")
	assert_eq(d.result_for(1, "dodge"), "Again.")
	assert_eq(d.result_for(1, "jump"), d.fallback, "a choice the truck has no line for")
	assert_eq(d.result_for(0, "pray"), d.fallback, "an id that is not a choice")
	assert_eq(d.result_for(-1, "dodge"), d.fallback, "a truck before the first")
	assert_eq(d.result_for(5, "dodge"), d.fallback, "a truck past the last")
