extends GutTest

var rules: SkillRulesEngine
var stats: Stats
var set: PlayerSkillSet

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(DefLoader.load_dir("res://data/skills"))
	stats = Stats.new({"max_hp": 30, "atk": 1, "def": 0, "spd": 100})
	set = PlayerSkillSet.new(rules, stats)
	rules.skill_unlocked.connect(set.on_skill_unlocked)
	rules.skill_leveled.connect(func(_id: String, _lv: int) -> void: set.refresh())
	rules.start_run()

func _emit(ev: String, tags: Dictionary, times: int = 1) -> void:
	for i in times:
		rules.handle_event(ev, tags)

func test_passive_modifiers_follow_unlock_and_level() -> void:
	_emit("jumped", {"from": "ground"}, 40)
	assert_eq(stats.get_stat("jump_height"), 110)
	_emit("jumped", {"from": "ground"}, 40)
	assert_eq(stats.get_stat("jump_height"), 120, "Leap's curve is 20 now: 40 more jumps is two levels, Lv3 (+20)")

func test_capabilities_and_compound_modifier() -> void:
	_emit("wall_touched", {}, 15)
	assert_true(set.has("wall_cling"))
	assert_eq(set.level("wall_cling"), 1)
	assert_eq(stats.get_stat("slide_speed"), 70)

func test_toughness_raises_max_hp() -> void:
	_emit("damaged", {"damage_type": "physical"}, 20)
	assert_eq(stats.get_stat("max_hp"), 33)

func test_active_unlocks_fill_slots() -> void:
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	assert_eq(set.slots.slots, ["hydraulic_propulsion", "", "", ""])

func test_incoming_damage_mods() -> void:
	_emit("damaged", {"damage_type": "poison"}, 6)   # Poison Resistance Lv1
	assert_eq(set.incoming("poison", 30, 30), {"percent_off": 20, "flat_off": 0})
	_emit("hp_low_exited", {}, 2)                    # Pain Resistance Lv1
	assert_eq(set.incoming("physical", 8, 30), {"percent_off": 0, "flat_off": 1})
	assert_eq(set.incoming("physical", 20, 30), {"percent_off": 0, "flat_off": 0})

func test_glutton_trigger_heals_on_creature_eats_only() -> void:
	assert_eq(set.heal_on("predated", {"source": "bat", "kind": "creature"}), 0)
	_emit("predated", {"source": "bat", "kind": "creature"}, 5)
	assert_eq(set.heal_on("predated", {"source": "bat", "kind": "creature"}), 3)
	assert_eq(set.heal_on("predated", {"source": "water_pool", "kind": "terrain"}), 0)

func test_reset_clears_slots_flags_and_modifiers() -> void:
	_emit("wall_touched", {}, 15)
	TestDefs.satisfy(rules, "hydraulic_propulsion")
	rules.reset_run()
	set.reset()
	assert_false(set.has("wall_cling"))
	assert_eq(set.slots.slots, ["", "", "", ""])
	assert_eq(stats.get_stat("slide_speed"), 100)

func test_slot_replaced_is_forwarded() -> void:
	var seen: Array = []
	set.slot_replaced.connect(func(n: String, o: String) -> void: seen.append([n, o]))
	for id in ["a", "b", "c", "d", "e"]:
		set.slots.add(id)
	assert_eq(seen, [["e", "a"]])

func test_skill_set_is_freed_when_dropped() -> void:
	# A lambda capturing self in the slot_replaced forward made a RefCounted cycle that
	# leaked one skill set (and its slots and stats) per run.
	var s := PlayerSkillSet.new(rules, Stats.new())
	var ref: WeakRef = weakref(s)
	var slots_ref: WeakRef = weakref(s.slots)
	s = null
	assert_null(ref.get_ref())
	assert_null(slots_ref.get_ref())
