extends GutTest
## OpeningModel: prompt, the chosen line, the next truck, done. Pure state; the scene only draws it.

func _def() -> OpeningDef:
	var d := OpeningDef.new()
	d.choices = [{"id": "a", "label": "A"}, {"id": "b", "label": "B"}, {"id": "c", "label": "C"}]
	d.trucks = [
		{"prompt": "P0", "results": {"a": "r0a", "b": "r0b", "c": "r0c"}},
		{"prompt": "P1", "results": {"a": "r1a", "b": "r1b", "c": "r1c"}},
		{"prompt": "P2", "results": {"a": "r2a", "b": "r2b", "c": "r2c"}},
	]
	d.fallback = "fallback"
	d.goddess_line = "line"
	return d

func test_it_starts_on_the_first_trucks_prompt() -> void:
	var m := OpeningModel.new(_def())
	assert_eq(m.phase, OpeningModel.Phase.PROMPT)
	assert_eq([m.truck(), m.truck_count(), m.prompt()], [0, 3, "P0"])
	assert_eq(m.rows(), ["A", "B", "C"])
	assert_eq(m.row(), 0)
	assert_false(m.done())
	assert_eq(m.result_line(), "")

func test_move_clamps_at_both_ends_and_is_ignored_outside_a_prompt() -> void:
	var m := OpeningModel.new(_def())
	m.move(-1)
	assert_eq(m.row(), 0, "stops at the top")
	for i in 5:
		m.move(1)
	assert_eq(m.row(), 2, "stops at the bottom")
	m.move(-1)
	assert_eq(m.row(), 1)
	m.act()
	m.move(1)
	assert_eq(m.row(), 1, "a result is not a menu: moving does nothing")

func test_acting_takes_the_highlighted_choice_and_shows_its_line() -> void:
	var d := _def()
	for i in 3:
		var m := OpeningModel.new(d)
		m.move(i)
		assert_true(m.act())
		var id: String = d.choices[i]["id"]
		assert_eq(m.phase, OpeningModel.Phase.RESULT)
		assert_eq(m.chosen(), id)
		assert_eq(m.result_line(), d.result_for(0, id))
		assert_eq(m.prompt(), "P0", "the truck is still the same one")
		assert_eq(m.rows(), [], "no menu while the truck hits")

func test_the_next_truck_starts_with_the_row_reset() -> void:
	var m := OpeningModel.new(_def())
	m.move(2)
	m.act()
	assert_true(m.act())
	assert_eq(m.phase, OpeningModel.Phase.PROMPT)
	assert_eq([m.truck(), m.prompt(), m.row()], [1, "P1", 0])
	assert_eq(m.result_line(), "")

func test_the_third_result_ends_it() -> void:
	var m := OpeningModel.new(_def())
	for i in 3:
		m.act()
		m.act()
	assert_true(m.done())
	assert_eq(m.phase, OpeningModel.Phase.DONE)
	assert_eq([m.prompt(), m.rows(), m.result_line()], ["", [], ""])
	assert_false(m.act(), "nothing left to do")

func test_it_plays_all_three_trucks_with_different_choices() -> void:
	var d := _def()
	var m := OpeningModel.new(d)
	var seen: Array = []
	for pick in [0, 1, 2]:
		m.move(pick)
		m.act()
		seen.append([m.chosen(), m.result_line()])
		m.act()
	assert_eq(seen, [["a", "r0a"], ["b", "r1b"], ["c", "r2c"]])
	assert_true(m.done())

func test_an_empty_def_is_done_at_once() -> void:
	assert_true(OpeningModel.new(OpeningDef.new()).done())
	var no_trucks := _def()
	no_trucks.trucks = []
	assert_true(OpeningModel.new(no_trucks).done())
	var no_choices := _def()
	no_choices.choices = []
	assert_true(OpeningModel.new(no_choices).done())
