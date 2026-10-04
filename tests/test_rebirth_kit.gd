extends GutTest
## A rebirth pool's head start: granted skills that count as known but not discovered, and a starting level.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var announcer: AnnouncerQueue
var skills: Array
var player: Player

const FIRST_EVOLUTION_AREAS := ["cave", "grotto"]

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	var creatures := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creatures)
	announcer = AnnouncerQueue.new()
	CoreWiring.connect_core(rules, compendium, announcer)
	player = Player.new()
	player.setup(rules, compendium, creatures, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _tickers() -> Array:
	var out: Array = []
	var t := announcer.pop_ticker()
	while not t.is_empty():
		out.append(t)
		t = announcer.pop_ticker()
	return out

# --- the engine's grant and discovery ---

func test_an_unannounced_grant_owns_the_skill_at_level_one_without_unlocking_it() -> void:
	var unlocked: Array = []
	rules.skill_unlocked.connect(func(id: String) -> void: unlocked.append(id))
	assert_true(rules.grant("leap", false))
	assert_eq(rules.level_of("leap"), 1)
	assert_true(rules.is_granted("leap"))
	assert_eq(unlocked, [], "no skill_unlocked: that would reveal the Compendium and slot it")
	assert_false(rules.grant("leap", false), "granting twice changes nothing")

func test_an_announced_grant_is_not_marked_granted() -> void:
	rules.grant("leap")
	assert_false(rules.is_granted("leap"))

func test_earning_a_granted_skills_unlock_emits_skill_discovered_once() -> void:
	var found: Array = []
	rules.skill_discovered.connect(func(id: String) -> void: found.append(id))
	rules.grant("leap", false)
	for i in 39:
		rules.handle_event("jumped", {"from": "ground"})
	assert_eq(found, [], "40 jumps unlock Leap; 39 is not enough")
	rules.handle_event("jumped", {"from": "ground"})
	assert_eq(found, ["leap"])
	for i in 100:
		rules.handle_event("jumped", {"from": "ground"})
	assert_eq(found, ["leap"], "once")
	assert_false(rules.is_granted("leap"), "it is discovered now")

func test_a_granted_skills_counters_start_from_zero() -> void:
	for i in 30:
		rules.handle_event("jumped", {"from": "ground"})  # before the grant
	rules.grant("leap", false)
	assert_eq(rules.level_progress("leap")["current"], 0)

func test_discovery_raises_the_compendium_and_the_ticker_says_so() -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"]})
	_tickers()
	for i in 40:
		rules.handle_event("jumped", {"from": "ground"})
	assert_eq(compendium.state("leap"), CompendiumModel.State.OWNED_ONCE)
	var lines := _tickers().filter(func(t): return t["kind"] == "note")
	assert_eq(lines.size(), 1)
	assert_eq(lines[0]["text"], "You understand Leap.")

func test_a_new_run_forgets_what_was_granted() -> void:
	rules.grant("leap", false)
	rules.start_run()
	assert_eq(rules.level_of("leap"), 0)
	assert_false(rules.is_granted("leap"))

# --- the kit ---

func test_a_kit_makes_skills_known_not_discovered_and_slots_actives_once() -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap", "sticky_thread"]})
	assert_true(rules.owned().has("leap"))
	assert_eq(compendium.state("leap"), CompendiumModel.State.NAMED, "known, not discovered")
	assert_true(player.skillset.slots.slots.has("sticky_thread"), "an active lands in a slot")
	RebirthKit.apply(player, rules, compendium, {"skills": ["sticky_thread"]})
	assert_eq(player.skillset.slots.slots.count("sticky_thread"), 1, "never twice")

func test_a_granted_skills_modifiers_apply() -> void:
	var before := player.stats.get_stat("jump_height")
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"]})
	assert_gt(player.stats.get_stat("jump_height"), before)

func test_a_starting_level_gives_the_stat_bonuses() -> void:
	var hp := player.stats.get_stat("max_hp")
	RebirthKit.apply(player, rules, compendium, {"level": 3})
	assert_eq(player.progression.level, 3)
	assert_eq(player.progression.stage, 1)
	assert_eq(player.stats.get_stat("max_hp"), hp + 2 * Player.LEVEL_UP_BONUS["max_hp"])
	assert_eq(player.stats.get_stat("max_mp"), player.stats.base("max_mp") + 2 * Player.LEVEL_UP_BONUS["max_mp"])

func test_a_starting_level_never_passes_the_cap_or_falls_below_one() -> void:
	RebirthKit.apply(player, rules, compendium, {"level": 99})
	assert_eq(player.progression.level, Progression.LEVEL_CAP)
	rules.start_run()
	RebirthKit.apply(player, rules, compendium, {"level": -4})
	assert_eq(player.progression.level, 1)

func test_a_starting_level_plays_no_level_up_events() -> void:
	var seen: Array = []
	EventBus.world_event.connect(func(n: String, _t: Dictionary) -> void: seen.append(n))
	RebirthKit.apply(player, rules, compendium, {"level": 4})
	assert_false(seen.has("leveled_up"), "no fanfare at the start of a life")

func test_applying_a_kit_after_a_second_run_start_does_not_stack() -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"], "level": 3})
	rules.start_run()
	assert_eq(player.progression.level, 1)
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"], "level": 3})
	assert_eq(player.progression.level, 3)
	assert_eq(player.stats.level_bonus("max_hp"), 2 * Player.LEVEL_UP_BONUS["max_hp"])

func test_a_granted_skills_dependants_stay_locked_until_earned() -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": ["wall_cling", "sticky_thread"]})
	assert_false(rules.owned().has("swing_thread"))
	assert_false(rules.is_evolution_ready("swing_thread"), "Swing Thread needs Sticky Thread 3")
	assert_eq(rules.level_of("wall_cling"), 1)

func test_an_empty_kit_changes_nothing() -> void:
	RebirthKit.apply(player, rules, compendium, {})
	assert_eq(player.progression.level, 1)
	assert_eq(rules.owned(), ["appraisal"])

func test_kit_validation_accepts_good_kits_and_names_bad_ones() -> void:
	assert_eq(RebirthKit.validate({"skills": ["leap", "wall_cling"], "level": 3}).size(), 0)
	assert_gt(RebirthKit.validate({"skills": ["nope"]}).size(), 0)
	assert_gt(RebirthKit.validate({"level": 11}).size(), 0)
	assert_eq(RebirthKit.validate({"affinity": {"bogus": 1}}).size(), 0, "a leftover key is ignored, not an error")

## One row per area: its pool's room (the first of `rooms`), the rooms a life eats in before its first heavy, and what its kit grants.
const AREA_KITS := {
	"grotto": {"rooms": ["G1", "G2", "G3", "G4"], "skills": ["leap", "wall_cling"], "level": 3},
	"flooded": {"rooms": ["F1", "F2"], "skills": ["leap", "wall_cling", "swim"], "level": 4},
	"deep": {"rooms": ["D1", "D2"], "skills": ["leap", "wall_cling", "swim", "tremor"], "level": 5},
}

func _creatures() -> Dictionary:
	var out := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		out[c.id] = c
	return out

func test_every_pool_kit_is_valid_and_grants_what_its_row_says() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	for area in AREA_KITS:
		var row: Dictionary = AREA_KITS[area]
		var pool: Dictionary = {}
		for p in RebirthChoice.altars(rooms):
			if p["room"] == row["rooms"][0]:
				pool = p
		assert_false(pool.is_empty(), "%s: a pool in %s" % [area, row["rooms"][0]])
		assert_eq(pool["area"], area)
		assert_eq(RebirthKit.validate(pool["kit"]).size(), 0, area)
		assert_eq(pool["kit"]["skills"], row["skills"], area)
		assert_eq(pool["kit"]["level"], row["level"], area)

func test_every_kits_xp_to_the_cap_is_within_the_first_evolution_areas_total() -> void:
	var rooms := ShippedRooms.load_all()
	var creatures := _creatures()
	var areas_total := 0
	for id in WorldValidator.reachable(rooms, true):
		var r: RoomDef = rooms[id]
		if FIRST_EVOLUTION_AREAS.has(r.area):
			areas_total += ShippedRooms.first_time(rooms, creatures, [id])
	for p in RebirthChoice.altars(rooms):
		if p["id"] == WorldProgress.DEFAULT_ALTAR:
			continue
		var need := 0
		for l in range(int((p["kit"] as Dictionary).get("level", 1)), Progression.LEVEL_CAP):
			need += Progression.xp_to_next(l)
		assert_lte(need, areas_total, "pool %s: the first-evolution areas supply the XP to its cap" % p["id"])

func test_a_starting_level_starts_at_full_health_and_mana() -> void:
	RebirthKit.apply(player, rules, compendium, {"level": 3})
	assert_gt(player.stats.get_stat("max_hp"), 30, "the level raised the maximum")
	assert_eq(player.health.hp, player.health.max_hp, "a new life is not wounded")
	assert_eq(player.mana.mp, player.mana.max_mp)

func test_a_kit_may_not_name_an_evolution() -> void:
	assert_string_contains("\n".join(RebirthKit.validate({"skills": ["water_blade"]})), "kit names evolution 'water_blade'")
	assert_eq(RebirthKit.validate({"skills": ["hydraulic_propulsion"]}), PackedStringArray())

# an F1 life can also go forward into the Deep now (188 + D1 + D2 reaches 225); this pins only that the Flooded alone is not enough
func test_the_flooded_alone_does_not_fill_an_f1_lifes_first_stage() -> void:
	var rooms := ShippedRooms.load_all()
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var kit_level := 0
	for p in RebirthChoice.altars(rooms):
		if p["id"] == "F1":
			kit_level = int((p["kit"] as Dictionary).get("level", 1))
	var need := 0
	for l in range(kit_level, Progression.LEVEL_CAP):
		need += Progression.xp_to_next(l)
	assert_eq(kit_level, 4)
	assert_eq(need, 225, "25 + 30 + 35 + 40 + 45 + 50")
	var first_pass := ShippedRooms.first_time(rooms, creatures, ["F1", "F2", "F3", "F4", "F5"])
	assert_lt(first_pass, need, "the Flooded alone is not enough: the life climbs back to the Grotto or the Cave")
	var areas_total := 0
	for id in WorldValidator.reachable(rooms, true):
		if FIRST_EVOLUTION_AREAS.has((rooms[id] as RoomDef).area):
			areas_total += ShippedRooms.first_time(rooms, creatures, [id])
	assert_lte(need, areas_total, "the first-evolution areas supply it")

func test_no_shipped_pool_carries_a_seeded_affinity() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	for p in RebirthChoice.altars(rooms):
		assert_false((p["kit"] as Dictionary).has("affinity"), "pool %s" % p["id"])
