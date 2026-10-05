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

# --- cocoons ---

func test_is_cocoon_reads_the_prefix() -> void:
	assert_true(Inventory.is_cocoon("cocoon:bat"))
	assert_false(Inventory.is_cocoon("claw"))
	assert_false(Inventory.is_cocoon("cocoon"))
	assert_false(Inventory.is_cocoon("cocoon:"), "a cocoon of no one")

func test_a_cocoon_is_carried_never_worn_even_by_a_body_that_can_graft() -> void:
	var inv := _inv()
	assert_true(inv.add_cocoon("bat"))
	assert_eq(inv.carried(), ["cocoon:bat"])
	assert_eq(inv.worn(), [])
	assert_eq(inv.stat_mods(), [])

func test_two_cocoons_fit_and_a_third_is_refused() -> void:
	var inv := _inv()
	assert_true(inv.add_cocoon("bat"))
	assert_true(inv.add_cocoon("toad"))
	assert_false(inv.add_cocoon("lizard"))
	assert_eq(inv.cocoons(), ["bat", "toad"])
	assert_eq(Inventory.COCOON_COUNT_MAX, 2)

func test_take_cocoon_gives_the_first_creature_and_leaves_the_rest() -> void:
	var inv := _inv()
	inv.add_cocoon("bat")
	inv.add_cocoon("toad")
	assert_eq(inv.take_cocoon(), "bat")
	assert_eq(inv.cocoons(), ["toad"])
	assert_eq(inv.take_cocoon(), "toad")
	assert_eq(inv.take_cocoon(), "", "none left")

func test_carried_parts_leaves_the_cocoons_out() -> void:
	var inv := _inv()
	inv.add("claw", false)
	inv.add_cocoon("bat")
	inv.add("skull", false)
	assert_eq(inv.carried_parts(), ["claw", "skull"])
	assert_eq(inv.carried(), ["claw", "cocoon:bat", "skull"])

func test_take_carried_never_takes_a_cocoon() -> void:
	var inv := _inv()
	inv.add_cocoon("bat")
	assert_eq(inv.take_carried(), "", "only a cocoon is carried")
	assert_eq(inv.cocoons(), ["bat"])
	inv.add("claw", false)
	assert_eq(inv.take_carried(), "claw")
	assert_eq(inv.cocoons(), ["bat"])

func test_add_with_a_cocoon_id_adds_a_cocoon_and_the_cap_still_holds() -> void:
	var inv := _inv()
	assert_eq(inv.add("cocoon:bat", true), {"ok": true, "worn": false})
	assert_eq(inv.add("cocoon:toad", true), {"ok": true, "worn": false})
	assert_eq(inv.add("cocoon:lizard", true), {"ok": false, "worn": false})
	assert_eq(inv.cocoons(), ["bat", "toad"])

func test_take_all_and_give_all_carry_cocoons_with_the_parts() -> void:
	var inv := _inv()
	inv.add("ribs", true)
	inv.add_cocoon("bat")
	inv.add("claw", true)
	var all := inv.take_all()
	assert_eq(all.size(), 3)
	assert_true(all.has("cocoon:bat"))
	assert_eq(inv.cocoons(), [])
	var again := _inv()
	again.give_all(all, true)
	assert_eq(again.cocoons(), ["bat"])
	assert_eq(again.worn(), ["ribs", "claw"], "both grafts are worn again")
	assert_eq(again.carried_parts(), [])
