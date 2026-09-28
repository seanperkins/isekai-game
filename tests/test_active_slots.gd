extends GutTest

var s: ActiveSlots
var replaced: Array

func before_each() -> void:
	s = ActiveSlots.new()
	replaced = []
	s.slot_replaced.connect(func(n: String, o: String) -> void: replaced.append([n, o]))

func test_new_actives_fill_empty_slots_first() -> void:
	s.add("a")
	s.add("b")
	assert_eq(s.slots, ["a", "b"])
	assert_eq(replaced, [])

func test_third_active_replaces_least_recently_used() -> void:
	s.add("a")
	s.add("b")
	s.use(0)  # a is now more recent than b
	s.add("c")
	assert_eq(s.slots, ["a", "c"])
	assert_eq(replaced, [["c", "b"]])
	assert_eq(s.owned, ["a", "b", "c"])

func test_adding_an_owned_id_again_is_ignored() -> void:
	s.add("a")
	s.add("a")
	assert_eq(s.slots, ["a", ""])

func test_use_returns_id_and_sets_last_used() -> void:
	s.add("a")
	s.add("b")
	assert_eq(s.use(1), "b")
	assert_eq(s.last_used, 1)
	var empty := ActiveSlots.new()
	assert_eq(empty.use(0), "")

func test_cycle_rotates_last_used_slot_without_duplicates() -> void:
	for id in ["a", "b", "c"]:
		s.add(id)  # c replaces a (the LRU): slots [c, b]
	s.slots = ["a", "b"]  # arrange a known layout; owned is still [a, b, c]
	s.use(0)
	s.cycle()
	assert_eq(s.slots, ["c", "b"])
	s.cycle()
	assert_eq(s.slots, ["a", "b"])  # never puts b in both slots

func test_cycle_is_a_no_op_with_zero_or_one_owned() -> void:
	s.cycle()
	assert_eq(s.slots, ["", ""])
	s.add("a")
	s.cycle()
	assert_eq(s.slots, ["a", ""])

func test_cycle_brings_back_an_evicted_active() -> void:
	s.add("hydraulic_propulsion")
	s.add("poison_breath")
	s.use(1)
	s.add("water_blade")  # evicts hydraulic (LRU)
	assert_false(s.slots.has("hydraulic_propulsion"))
	s.use(0)
	s.cycle()
	assert_true(s.slots.has("hydraulic_propulsion"))

func test_reset_clears_everything() -> void:
	s.add("a")
	s.reset()
	assert_eq(s.slots, ["", ""])
	assert_eq(s.owned, [])
