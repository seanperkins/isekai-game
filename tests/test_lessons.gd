extends GutTest
## What a goblin has learned in a life: the first dealing with a creature type pays all its essence, a repeat pays a trickle.

func _def(id: String, essences: Dictionary) -> CreatureDef:
	return TestDefs.creature(id, {"essences": essences})

func test_the_first_dealing_pays_every_unit_in_canonical_order() -> void:
	var l := Lessons.new()
	var r := l.learn(_def("a", {"dark": 1, "earth": 2}))
	assert_true(r["first"])
	assert_eq(r["element"], "earth")
	assert_eq(r["essences"], ["earth", "earth", "dark"])

func test_a_repeat_pays_one_unit_of_the_largest_essence_and_is_not_first() -> void:
	var l := Lessons.new()
	var d := _def("a", {"dark": 1, "earth": 2})
	l.learn(d)
	var r := l.learn(d)
	assert_false(r["first"])
	assert_eq(r["element"], "earth")
	assert_eq(r["essences"], ["earth"])

func test_a_repeat_is_by_creature_id_not_by_def_object() -> void:
	var l := Lessons.new()
	l.learn(_def("a", {"water": 1}))
	assert_false(l.learn(_def("a", {"water": 1}))["first"])

func test_known_and_count_follow_the_types_met() -> void:
	var l := Lessons.new()
	assert_false(l.known("a"))
	assert_eq(l.count(), 0)
	l.learn(_def("a", {"water": 1}))
	l.learn(_def("a", {"water": 1}))
	l.learn(_def("b", {"earth": 1}))
	assert_true(l.known("a"))
	assert_true(l.known("b"))
	assert_eq(l.count(), 2)

func test_times_counts_every_dealing_with_a_type() -> void:
	var l := Lessons.new()
	assert_eq(l.times("a"), 0)
	l.learn(_def("a", {"water": 1}))
	assert_eq(l.times("a"), 1)
	l.learn(_def("a", {"water": 1}))
	l.learn(_def("b", {"water": 1}))
	assert_eq(l.times("a"), 2)
	assert_eq(l.times("b"), 1)
	l.reset()
	assert_eq(l.times("a"), 0)

func test_reset_forgets_everything() -> void:
	var l := Lessons.new()
	l.learn(_def("a", {"water": 1}))
	l.reset()
	assert_false(l.known("a"))
	assert_eq(l.count(), 0)
	assert_true(l.learn(_def("a", {"water": 1}))["first"])

func test_a_creature_with_no_essences_teaches_once_and_pays_nothing() -> void:
	var l := Lessons.new()
	var d := _def("blank", {})
	var first := l.learn(d)
	assert_true(first["first"])
	assert_eq(first["element"], "")
	assert_eq(first["essences"], [])
	var again := l.learn(d)
	assert_false(again["first"])
	assert_eq(again["essences"], [])

func test_a_tie_takes_the_earlier_element() -> void:
	assert_eq(Lessons.primary(_def("a", {"dark": 2, "water": 2})), "water")
	assert_eq(Lessons.primary(_def("a", {"light": 1, "air": 1})), "air")

func test_primary_of_no_essences_is_empty() -> void:
	assert_eq(Lessons.primary(_def("a", {})), "")
