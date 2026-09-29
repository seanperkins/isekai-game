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
	assert_false(rules.is_evolution_ready("swing_thread"), "Swing Thread needs Wall Cling 2 and Sticky Thread 3")
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
	var supply := FormOffers.default_supply(forms)
	assert_lt(RebirthKit.eligible_lineages({"thread": 5}, supply, forms), 2, "one lineage is not enough")
	assert_gte(RebirthKit.eligible_lineages({"thread": 7, "sound": 6, "flight": 8}, supply, forms), 2)

## The essences a life eats in the ungated Grotto (G1..G4), as units.
func _ungated_grotto_units(rooms: Dictionary, creatures: Dictionary) -> Dictionary:
	var out := {}
	for id in ["G1", "G2", "G3", "G4"]:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			for e in c.essences:
				out[e] = int(out.get(e, 0)) + int(c.essences[e])
	return out

func test_every_shipped_grotto_pool_leaves_two_lineages_eligible_and_its_seeds_matter() -> void:
	# a seeded start must not lock you out of lineages: the kit's seeds plus what a life eats in the ungated
	# Grotto, against the whole world's supply, leave at least two eligible, and more than without the seeds
	var forms := FormLoader.load_all()
	var rooms := World.load_rooms("res://data/rooms")
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var supply := FormOffers.supply(rooms, creatures, forms)
	var checked := 0
	for p in RebirthChoice.pools(rooms):
		if p["id"] == WorldProgress.DEFAULT_POOL or p["area"] != "grotto":
			continue
		checked += 1
		var seeds: Dictionary = (p["kit"] as Dictionary).get("affinity", {})
		var without := _ungated_grotto_units(rooms, creatures)
		var with_seeds := without.duplicate()
		for e in seeds:
			with_seeds[e] = int(with_seeds.get(e, 0)) + int(seeds[e])
		var n_with := RebirthKit.eligible_lineages(with_seeds, supply, forms)
		var n_without := RebirthKit.eligible_lineages(without, supply, forms)
		assert_gte(n_with, 2, "pool %s leaves two lineages eligible" % p["id"])
		assert_gt(n_with, n_without, "pool %s: the seeds are not decoration" % p["id"])
	assert_gte(checked, 1, "the Grotto ships a pool")

func test_the_grotto_pool_kit_is_valid_and_quietly_grants_leap_and_wall_cling() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var pool: Dictionary = {}
	for p in RebirthChoice.pools(rooms):
		if p["id"] == "G1":
			pool = p
	assert_eq(pool["room"], "G1")
	assert_eq(RebirthKit.validate(pool["kit"]).size(), 0)
	assert_eq(pool["kit"]["skills"], ["leap", "wall_cling"])
	assert_eq(pool["kit"]["level"], 3)

func test_a_starting_level_starts_at_full_health_and_mana() -> void:
	RebirthKit.apply(player, rules, compendium, {"level": 3})
	assert_gt(player.stats.get_stat("max_hp"), 30, "the level raised the maximum")
	assert_eq(player.health.hp, player.health.max_hp, "a new life is not wounded")
	assert_eq(player.mana.mp, player.mana.max_mp)
