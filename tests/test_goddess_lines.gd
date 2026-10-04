extends GutTest
## Her line when you die: a cause line that cycles, a many-deaths line every few deaths, a fallback for anything else.

func _lines() -> GoddessLines:
	var l := GoddessLines.new()
	l.by_cause = {"bat": ["b0", "b1"]}
	l.many_deaths = ["m0", "m1"]
	l.fallback = "f"
	return l

func test_a_known_cause_cycles_by_death_count() -> void:
	var lines := _lines()
	assert_eq(lines.line_for("bat", 1, 5), "b1")
	assert_eq(lines.line_for("bat", 2, 5), "b0")
	assert_eq(lines.line_for("bat", 3, 5), "b1")

func test_the_fifth_death_takes_a_many_deaths_line_even_with_a_cause_line() -> void:
	var lines := _lines()
	assert_eq(lines.line_for("bat", 5, 5), "m0")
	assert_eq(lines.line_for("bat", 10, 5), "m1")
	assert_eq(lines.line_for("bat", 15, 5), "m0", "the list wraps")
	assert_eq(lines.line_for("bat", 6, 5), "b0", "the next death is a cause line again")

func test_an_unknown_or_empty_cause_takes_the_fallback() -> void:
	var lines := _lines()
	assert_eq(lines.line_for("blade", 1, 5), "f")
	assert_eq(lines.line_for("", 1, 5), "f")

func test_degenerate_inputs_never_crash() -> void:
	var lines := _lines()
	assert_eq(lines.line_for("bat", 5, 0), "b1", "an every of 0 turns the many-deaths rule off")
	assert_eq(lines.line_for("bat", 0, 5), "b0", "death 0 is not a many-deaths death")
	lines.by_cause["toad"] = []
	assert_eq(lines.line_for("toad", 1, 5), "f", "a cause with no lines takes the fallback")
	lines.many_deaths = []
	assert_eq(lines.line_for("bat", 5, 5), "b1", "no many-deaths lines: the cause line stands")
