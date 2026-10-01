extends GutTest
## A rebirth pool's head start: granted skills that count as known but not discovered, a starting level
## without EP, and seeded affinity that only ever counts toward the first evolution.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var announcer: AnnouncerQueue
var skills: Array
var player: Player

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
	FormOffers._default_supply = {}  # forget a supply a test pinned; the next reader recomputes it from disk

## Evolution offers read FormOffers.default_supply (every room on disk). A pin about what the shipped rooms feed pins that
## cache to the shipped rooms, so a room added later does not move it.
func _pin_supply_to_the_shipped_rooms() -> void:
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	FormOffers._default_supply = FormOffers.supply(ShippedRooms.load_all(), creatures, FormLoader.load_all(), FormOffers.FIRST_EVOLUTION_AREAS)

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

func test_a_starting_level_gives_the_stat_bonuses_and_no_ep() -> void:
	var hp := player.stats.get_stat("max_hp")
	RebirthKit.apply(player, rules, compendium, {"level": 3})
	assert_eq(player.progression.level, 3)
	assert_eq(player.progression.ep, 0, "EP is earned, not given")
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

func test_seeded_affinity_counts_toward_the_first_evolution_and_nothing_else() -> void:
	_pin_supply_to_the_shipped_rooms()
	RebirthKit.apply(player, rules, compendium, {"affinity": {"thread": 7}})
	assert_eq(player.progression.seeded["thread"], 7)
	assert_eq(rules.count("absorbed", {"essence": "thread"}), 0, "the ledger is untouched: no skill unlocks from seeds")
	assert_false(rules.owned().has("sticky_thread"))
	player.progression.add_xp(Progression.stage_total(1))
	var offers := player.form_offers()
	assert_eq((offers[0] as FormDef).id, "weaver", "7 of Weaver's 11 thread is enough")

func test_applying_a_kit_after_a_second_run_start_does_not_stack() -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"], "level": 3, "affinity": {"thread": 2}})
	rules.start_run()
	assert_eq(player.progression.level, 1)
	assert_true(player.progression.seeded.is_empty())
	RebirthKit.apply(player, rules, compendium, {"skills": ["leap"], "level": 3, "affinity": {"thread": 2}})
	assert_eq(player.progression.level, 3)
	assert_eq(player.progression.seeded["thread"], 2)
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
	assert_true(player.progression.seeded.is_empty())

func test_kit_validation_accepts_good_kits_and_names_bad_ones() -> void:
	assert_eq(RebirthKit.validate({"skills": ["leap", "wall_cling"], "level": 3, "affinity": {"thread": 1}}).size(), 0)
	assert_gt(RebirthKit.validate({"skills": ["nope"]}).size(), 0)
	assert_gt(RebirthKit.validate({"level": 11}).size(), 0)
	assert_gt(RebirthKit.validate({"affinity": {"bogus": 1}}).size(), 0)

func test_the_eligibility_check_bites_on_a_poorly_seeded_kit() -> void:
	var forms := FormLoader.load_all()
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var supply := FormOffers.supply(ShippedRooms.load_all(), creatures, forms, FormOffers.FIRST_EVOLUTION_AREAS)  # the shipped rooms, not whatever is on disk
	assert_lt(RebirthKit.eligible_lineages({"thread": 5}, supply, forms), 2, "one lineage is not enough")
	assert_gte(RebirthKit.eligible_lineages({"thread": 7, "sound": 8, "flight": 8}, supply, forms), 2)

## One row per area: its pool's room (the first of `rooms`), the rooms a life eats in before its first heavy, and what its kit grants.
const AREA_KITS := {
	"grotto": {"rooms": ["G1", "G2", "G3", "G4"], "skills": ["leap", "wall_cling"], "level": 3},
	"flooded": {"rooms": ["F1", "F2"], "skills": ["leap", "wall_cling", "swim"], "level": 4},
}

## The essences a life can eat in `ids`, as units: a creature that cannot be downed by tackle (the jelly) is not counted.
func _units(rooms: Dictionary, creatures: Dictionary, ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			if c.untackleable:
				continue
			for e in c.essences:
				out[e] = int(out.get(e, 0)) + int(c.essences[e])
	return out

func _creatures() -> Dictionary:
	var out := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		out[c.id] = c
	return out

func test_every_pool_leaves_two_lineages_eligible_and_its_seeds_matter() -> void:
	# a seeded start must not lock you out of lineages: the kit's seeds plus what a life eats before its first heavy, against the
	# first-evolution areas' supply, leave at least two eligible, and more than without the seeds
	var forms := FormLoader.load_all()
	var rooms := ShippedRooms.load_all()
	var creatures := _creatures()
	var supply := FormOffers.supply(rooms, creatures, forms, FormOffers.FIRST_EVOLUTION_AREAS)
	for area in AREA_KITS:
		var checked := 0
		for p in RebirthChoice.pools(rooms):
			if p["id"] == WorldProgress.DEFAULT_POOL or p["area"] != area:
				continue
			checked += 1
			var seeds: Dictionary = (p["kit"] as Dictionary).get("affinity", {})
			var without := _units(rooms, creatures, AREA_KITS[area]["rooms"])
			var with_seeds := without.duplicate()
			for e in seeds:
				with_seeds[e] = int(with_seeds.get(e, 0)) + int(seeds[e])
			var n_with := RebirthKit.eligible_lineages(with_seeds, supply, forms)
			var n_without := RebirthKit.eligible_lineages(without, supply, forms)
			assert_gte(n_with, 2, "%s pool %s leaves two lineages eligible" % [area, p["id"]])
			assert_gt(n_with, n_without, "%s pool %s: the seeds are not decoration" % [area, p["id"]])
		assert_eq(checked, 1, "the %s ships exactly one pool" % area)

func test_every_pool_kit_is_valid_and_grants_what_its_row_says() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	for area in AREA_KITS:
		var row: Dictionary = AREA_KITS[area]
		var pool: Dictionary = {}
		for p in RebirthChoice.pools(rooms):
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
		if FormOffers.FIRST_EVOLUTION_AREAS.has(r.area):
			areas_total += ShippedRooms.first_time(rooms, creatures, [id])
	for p in RebirthChoice.pools(rooms):
		if p["id"] == WorldProgress.DEFAULT_POOL:
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
	for p in RebirthChoice.pools(rooms):
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
		if FormOffers.FIRST_EVOLUTION_AREAS.has((rooms[id] as RoomDef).area):
			areas_total += ShippedRooms.first_time(rooms, creatures, [id])
	assert_lte(need, areas_total, "the first-evolution areas supply it")
