extends GutTest
## What a life carries and wears: a graft is worn when the body can graft and its slot has room, everything else is carried.

var parts := {}

func before_all() -> void:
	parts = PartLoader.load_all()

func _inv() -> Inventory:
	return Inventory.new(parts)

func test_a_graft_is_worn_when_the_body_can_graft() -> void:
	var inv := _inv()
	assert_eq(inv.add("ribs", true), {"ok": true, "worn": true})
	assert_eq(inv.worn(), ["ribs"])
	assert_eq(inv.carried(), [])

func test_a_body_that_cannot_graft_carries_it() -> void:
	var inv := _inv()
	assert_eq(inv.add("ribs", false), {"ok": true, "worn": false})
	assert_eq(inv.worn(), [])
	assert_eq(inv.carried(), ["ribs"])

func test_a_held_part_and_a_key_are_carried_even_by_a_body_that_can_graft() -> void:
	var inv := _inv()
	assert_eq(inv.add("phylactery_shard", true)["worn"], false)
	assert_eq(inv.add("moonstone", true)["worn"], false)
	assert_eq(inv.carried(), ["phylactery_shard", "moonstone"])

func test_two_claws_are_worn_and_a_third_is_carried() -> void:
	var inv := _inv()
	for i in 3:
		inv.add("claw", true)
	assert_eq(inv.worn(), ["claw", "claw"])
	assert_eq(inv.carried(), ["claw"])
	assert_eq(inv.count("claw"), 3)

func test_a_second_of_a_one_slot_part_is_carried() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	assert_eq(inv.add("ribs", true)["worn"], false)
	assert_eq(inv.worn(), ["ribs"])
	assert_eq(inv.carried(), ["ribs"])

func test_four_grafts_is_the_most_that_are_worn() -> void:
	var inv := _inv()
	for id in ["ribs", "flesh", "claw", "claw", "skull"]:
		inv.add(id, true)
	assert_eq(inv.worn().size(), Inventory.GRAFT_CAP)
	assert_eq(inv.worn(), ["ribs", "flesh", "claw", "claw"])
	assert_eq(inv.carried(), ["skull"])

func test_stat_mods_are_the_worn_passives_and_not_the_carried() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	inv.add("claw", true)
	inv.add("claw", true)
	inv.add("claw", true)
	inv.add("moonstone", true)
	var mods := inv.stat_mods()
	assert_eq(mods.size(), 3)
	assert_true(mods.has({"stat": "def", "op": "add", "value": 1}))
	assert_eq(mods.filter(func(m: Dictionary) -> bool: return m["stat"] == "atk").size(), 2)
	assert_eq(mods.filter(func(m: Dictionary) -> bool: return m["stat"] == "atk" and m["value"] == 1).size(), 2)

func test_a_worn_part_with_no_passive_adds_no_mod() -> void:
	var inv := _inv()
	inv.add("phylactery_shard", true)
	assert_eq(inv.stat_mods(), [])

func test_shed_one_removes_the_latest_worn_graft() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	inv.add("flesh", true)
	assert_eq(inv.shed_one(), "flesh")
	assert_eq(inv.worn(), ["ribs"])
	assert_eq(inv.count("flesh"), 0)
	assert_eq(inv.stat_mods(), [{"stat": "def", "op": "add", "value": 1}])

func test_shed_one_with_nothing_worn_sheds_nothing_and_keeps_the_carried() -> void:
	var inv := _inv()
	inv.add("moonstone", true)
	assert_eq(inv.shed_one(), "")
	assert_eq(inv.carried(), ["moonstone"])

func test_a_shed_frees_the_slot() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	inv.shed_one()
	assert_eq(inv.add("ribs", true)["worn"], true)

func test_take_carried_takes_the_first_carried_part_and_never_a_worn_one() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	inv.add("moonstone", true)
	inv.add("skull", false)
	assert_eq(inv.take_carried(), "moonstone")
	assert_eq(inv.carried(), ["skull"])
	assert_eq(inv.worn(), ["ribs"])
	assert_eq(inv.take_carried(), "skull")
	assert_eq(inv.take_carried(), "", "nothing carried: nothing taken, the worn graft stays")
	assert_eq(inv.worn(), ["ribs"])

func test_take_all_returns_everything_and_empties_it() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	inv.add("ribs", true)
	inv.add("moonstone", true)
	var all := inv.take_all()
	all.sort()
	assert_eq(all, ["moonstone", "ribs", "ribs"])
	assert_eq(inv.worn(), [])
	assert_eq(inv.carried(), [])
	assert_eq(inv.stat_mods(), [])
	assert_eq(inv.take_all(), [])

func test_give_all_attaches_by_the_same_rules() -> void:
	var inv := _inv()
	inv.give_all(["claw", "claw", "claw", "moonstone"], true)
	assert_eq(inv.worn(), ["claw", "claw"])
	assert_eq(inv.carried(), ["claw", "moonstone"])
	var plain := _inv()
	plain.give_all(["claw", "moonstone"], false)
	assert_eq(plain.worn(), [])
	assert_eq(plain.carried(), ["claw", "moonstone"])

func test_an_unknown_part_is_refused_and_changes_nothing() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	assert_eq(inv.add("no_such_part", true), {"ok": false, "worn": false})
	assert_eq(inv.worn(), ["ribs"])
	assert_eq(inv.carried(), [])
	assert_eq(inv.count("no_such_part"), 0)

func test_give_all_skips_an_unknown_part() -> void:
	var inv := _inv()
	inv.give_all(["no_such_part", "ribs"], true)
	assert_eq(inv.worn(), ["ribs"])
