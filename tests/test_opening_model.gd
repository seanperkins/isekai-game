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

# --- the first dodge is free, and the last round has a grandma ---

func _turn_def() -> OpeningDef:
	var d := OpeningDef.new()
	d.choices = [{"id": "fight", "label": "Fight"}, {"id": "dodge", "label": "Dodge"}, {"id": "jump", "label": "Jump"}]
	d.trucks = [
		{"prompt": "P0", "results": {"fight": "r0f", "dodge": "r0d", "jump": "r0j"}},
		{"prompt": "P1", "results": {"fight": "r1f", "dodge": "r1d", "jump": "r1j"}},
		{"prompt": "P2", "results": {"fight": "r2f", "dodge": "r2d", "jump": "r2j"}},
	]
	d.fallback = "fallback"
	d.goddess_line = "line"
	d.dodge_success = "you did it"
	d.second_truck = "two now"
	d.grandma = {"id": "grandma", "label": "Save Grandma", "prompt": "an old lady", "result": "you push her clear"}
	return d

func test_the_first_dodge_is_free_and_the_round_comes_back_with_two_trucks() -> void:
	var m := OpeningModel.new(_turn_def())
	assert_eq(m.trucks_on_screen(), 1)
	m.move(1)
	m.act()
	assert_true(m.free_dodge(), "this dodge cannot fail")
	assert_eq(m.result_line(), "you did it")
	assert_true(m.act())
	assert_eq(m.phase, OpeningModel.Phase.PROMPT)
	assert_eq(m.truck(), 0, "the dodge does not use the round up")
	assert_eq(m.trucks_on_screen(), 2)
	assert_eq(m.prompt(), "two now", "the round opens on the second truck's arrival")
	assert_eq(m.row(), 0)
	assert_false(m.free_dodge())

func test_only_the_first_dodge_is_free() -> void:
	var m := OpeningModel.new(_turn_def())
	m.move(1)
	m.act()
	m.act()
	m.move(1)
	m.act()
	assert_false(m.free_dodge(), "the second dodge is a plain command")
	assert_eq(m.result_line(), "r0d")
	m.act()
	assert_eq(m.truck(), 1, "it used the round up")
	assert_eq(m.prompt(), "P1", "the arrival line is gone after its round")
	assert_eq(m.trucks_on_screen(), 2, "and the two trucks stay")

func test_a_dodge_in_a_later_round_is_free_when_none_came_before() -> void:
	var m := OpeningModel.new(_turn_def())
	m.act()  # fight
	m.act()
	assert_eq(m.truck(), 1)
	assert_eq(m.trucks_on_screen(), 1, "fighting brings no second truck")
	m.move(1)
	m.act()
	assert_true(m.free_dodge())
	m.act()
	assert_eq([m.truck(), m.trucks_on_screen()], [1, 2])

func test_a_free_dodge_with_no_copy_uses_the_trucks_own_line() -> void:
	var d := _turn_def()
	d.dodge_success = ""
	d.second_truck = ""
	var m := OpeningModel.new(d)
	m.move(1)
	m.act()
	assert_true(m.free_dodge())
	assert_eq(m.result_line(), "r0d")
	m.act()
	assert_eq(m.prompt(), "P0", "no arrival line: the truck's own prompt")

func test_a_def_with_no_dodge_choice_never_has_a_free_dodge() -> void:
	var m := OpeningModel.new(_def())
	for i in 3:
		m.act()
		assert_false(m.free_dodge())
		m.act()
	assert_true(m.done())

func test_the_grandma_appears_on_the_last_round_only() -> void:
	var m := OpeningModel.new(_turn_def())
	for round_index in 2:
		assert_false(m.grandma_here(), "round %d" % round_index)
		assert_eq(m.rows(), ["Fight", "Dodge", "Jump"])
		for i in 3:
			assert_true(m.enabled(i), "every command works")
		m.act()
		m.act()
	assert_true(m.grandma_here())
	assert_eq(m.prompt(), "an old lady")
	assert_eq(m.rows(), ["Fight", "Dodge", "Jump", "Save Grandma"])

func test_with_the_grandma_there_only_saving_her_is_enabled_and_the_cursor_sits_on_it() -> void:
	var m := OpeningModel.new(_turn_def())
	for i in 2:
		m.act()
		m.act()
	for i in 3:
		assert_false(m.enabled(i), "the ordinary commands are grayed out")
	assert_true(m.enabled(3))
	assert_false(m.enabled(4), "no row past the end")
	assert_eq(m.row(), 3, "the cursor starts on the only thing you can do")
	m.move(-1)
	m.move(-1)
	assert_eq(m.row(), 3, "it cannot leave it")
	m.move(1)
	assert_eq(m.row(), 3)

func test_saving_the_grandma_shows_her_line_then_ends_it() -> void:
	var m := OpeningModel.new(_turn_def())
	for i in 2:
		m.act()
		m.act()
	assert_true(m.act())
	assert_eq(m.chosen(), "grandma")
	assert_false(m.free_dodge())
	assert_eq(m.result_line(), "you push her clear")
	assert_true(m.act())
	assert_true(m.done())

func test_a_def_with_no_grandma_plays_as_before() -> void:
	var d := _turn_def()
	d.grandma = {}
	var m := OpeningModel.new(d)
	for i in 2:
		m.act()
		m.act()
	assert_false(m.grandma_here())
	assert_eq(m.rows(), ["Fight", "Dodge", "Jump"])
	assert_eq(m.prompt(), "P2")
	assert_true(m.enabled(0))

func test_the_dodge_cannot_be_free_in_the_grandma_round() -> void:
	var m := OpeningModel.new(_turn_def())
	for i in 2:
		m.act()
		m.act()
	m.move(-3)  # try to reach Dodge
	m.act()
	assert_eq(m.chosen(), "grandma", "the grayed rows cannot be chosen")
	assert_false(m.free_dodge())

func test_the_model_says_when_the_old_lady_was_chosen_whatever_her_id() -> void:
	for id in ["grandma", "save_grandma"]:
		var d := _turn_def()
		d.grandma["id"] = id
		var m := OpeningModel.new(d)
		assert_false(m.grandma_chosen())
		m.act()
		assert_false(m.grandma_chosen(), "an ordinary command in an ordinary round")
		m.act()
		m.act()
		m.act()
		m.act()
		assert_eq(m.chosen(), id)
		assert_true(m.grandma_chosen(), id)
		m.act()
		assert_false(m.grandma_chosen(), "once it is over")
