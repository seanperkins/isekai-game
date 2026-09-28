extends GutTest
## Four active-skill slots (LB, RB, LT, RT / U, O, H, L): fill empty, else least recently used.

var s: ActiveSlots
var replaced: Array

func before_each() -> void:
	s = ActiveSlots.new()
	replaced = []
	s.slot_replaced.connect(func(n: String, o: String) -> void: replaced.append([n, o]))

func test_four_slots_fill_in_order() -> void:
	for id in ["a", "b", "c", "d"]:
		s.add(id)
	assert_eq(s.slots, ["a", "b", "c", "d"])
	assert_eq(replaced, [])

func test_fifth_active_replaces_least_recently_used() -> void:
	for id in ["a", "b", "c", "d"]:
		s.add(id)
	s.use(0)
	s.add("e")  # b is now the least recently used
	assert_eq(s.slots, ["a", "e", "c", "d"])
	assert_eq(replaced, [["e", "b"]])

func test_adding_an_owned_id_again_is_ignored() -> void:
	s.add("a")
	s.add("a")
	assert_eq(s.slots, ["a", "", "", ""])

func test_use_returns_id_or_empty() -> void:
	s.add("a")
	assert_eq(s.use(0), "a")
	assert_eq(s.use(3), "")

func test_assign_swaps_when_already_slotted() -> void:
	for id in ["a", "b"]:
		s.add(id)
	s.assign(3, "a")
	assert_eq(s.slots, ["", "b", "", "a"])
	s.assign(1, "a")
	assert_eq(s.slots, ["", "a", "", "b"])
	s.assign(0, "nope")
	assert_eq(s.slots[0], "")

func test_next_slot_for_cycles_through_all_four() -> void:
	s.add("a")
	assert_eq(s.next_slot_for("a"), 1)
	s.assign(1, "a")
	assert_eq(s.next_slot_for("a"), 2)
	s.assign(3, "a")
	assert_eq(s.next_slot_for("a"), 0)

func test_reset_clears_everything() -> void:
	s.add("a")
	s.reset()
	assert_eq(s.slots, ["", "", "", ""])
	assert_eq(s.owned, [])

func test_replace_takes_over_the_old_skills_slot() -> void:
	for id in ["a", "b", "c"]:
		s.add(id)
	s.replace("b", "z")
	assert_eq(s.slots, ["a", "z", "c", ""])
	assert_eq(s.owned, ["a", "c", "z"])
	assert_eq(replaced, [])

func test_replace_without_the_old_skill_just_adds() -> void:
	s.add("a")
	s.replace("b", "z")
	assert_eq(s.slots, ["a", "z", "", ""])
