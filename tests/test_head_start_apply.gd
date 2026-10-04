extends GutTest
## A head start: granted skills that count as known but not discovered, and a starting level.

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
	HeadStart.apply(player, rules, compendium, {"skills": ["leap"]})
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
	HeadStart.apply(player, rules, compendium, {"skills": ["leap", "sticky_thread"]})
	assert_true(rules.owned().has("leap"))
	assert_eq(compendium.state("leap"), CompendiumModel.State.NAMED, "known, not discovered")
	assert_true(player.skillset.slots.slots.has("sticky_thread"), "an active lands in a slot")
	HeadStart.apply(player, rules, compendium, {"skills": ["sticky_thread"]})
	assert_eq(player.skillset.slots.slots.count("sticky_thread"), 1, "never twice")

func test_a_granted_skills_modifiers_apply() -> void:
	var before := player.stats.get_stat("jump_height")
	HeadStart.apply(player, rules, compendium, {"skills": ["leap"]})
	assert_gt(player.stats.get_stat("jump_height"), before)

func test_a_starting_level_gives_the_stat_bonuses() -> void:
	var hp := player.stats.get_stat("max_hp")
	HeadStart.apply(player, rules, compendium, {"level": 3})
	assert_eq(player.progression.level, 3)
	assert_eq(player.progression.stage, 1)
	assert_eq(player.stats.get_stat("max_hp"), hp + 2 * Player.LEVEL_UP_BONUS["max_hp"])
	assert_eq(player.stats.get_stat("max_mp"), player.stats.base("max_mp") + 2 * Player.LEVEL_UP_BONUS["max_mp"])

func test_a_starting_level_never_passes_the_cap_or_falls_below_one() -> void:
	HeadStart.apply(player, rules, compendium, {"level": 99})
	assert_eq(player.progression.level, Progression.LEVEL_CAP)
	rules.start_run()
	HeadStart.apply(player, rules, compendium, {"level": -4})
	assert_eq(player.progression.level, 1)

func test_a_starting_level_plays_no_level_up_events() -> void:
	var seen: Array = []
	EventBus.world_event.connect(func(n: String, _t: Dictionary) -> void: seen.append(n))
	HeadStart.apply(player, rules, compendium, {"level": 4})
	assert_false(seen.has("leveled_up"), "no fanfare at the start of a life")

func test_applying_a_kit_after_a_second_run_start_does_not_stack() -> void:
	HeadStart.apply(player, rules, compendium, {"skills": ["leap"], "level": 3})
	rules.start_run()
	assert_eq(player.progression.level, 1)
	HeadStart.apply(player, rules, compendium, {"skills": ["leap"], "level": 3})
	assert_eq(player.progression.level, 3)
	assert_eq(player.stats.level_bonus("max_hp"), 2 * Player.LEVEL_UP_BONUS["max_hp"])

func test_a_granted_skills_dependants_stay_locked_until_earned() -> void:
	HeadStart.apply(player, rules, compendium, {"skills": ["wall_cling", "sticky_thread"]})
	assert_false(rules.owned().has("swing_thread"))
	assert_false(rules.is_evolution_ready("swing_thread"), "Swing Thread needs Sticky Thread 3")
	assert_eq(rules.level_of("wall_cling"), 1)

func test_an_empty_kit_changes_nothing() -> void:
	HeadStart.apply(player, rules, compendium, {})
	assert_eq(player.progression.level, 1)
	assert_eq(rules.owned(), ["appraisal"])

func _creatures() -> Dictionary:
	var out := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		out[c.id] = c
	return out

func test_a_starting_level_starts_at_full_health_and_mana() -> void:
	HeadStart.apply(player, rules, compendium, {"level": 3})
	assert_gt(player.stats.get_stat("max_hp"), 30, "the level raised the maximum")
	assert_eq(player.health.hp, player.health.max_hp, "a new life is not wounded")
	assert_eq(player.mana.mp, player.mana.max_mp)

## The dearest head start the menu can sell (every level price paid) still leaves its XP to the cap within what the first two
## evolution areas supply, so a life that takes it can reach the cap without leaving them.
func test_the_largest_head_start_still_leaves_xp_to_the_cap_in_the_first_evolution_areas() -> void:
	var rooms := ShippedRooms.load_all()
	var creatures := _creatures()
	var areas_total := 0
	for id in WorldValidator.reachable(rooms, true):
		var r: RoomDef = rooms[id]
		if FIRST_EVOLUTION_AREAS.has(r.area):
			areas_total += ShippedRooms.first_time(rooms, creatures, [id])
	var need := 0
	for l in range(1 + SoulRules.new().level_prices.size(), Progression.LEVEL_CAP):
		need += Progression.xp_to_next(l)
	assert_lte(need, areas_total, "the first-evolution areas supply the XP from the top head start level to the cap")
