extends GutTest
## The window a verb opens on the player (Rage): a timed bonus that kills can feed, with the price each one has: a crash after it, a verb locked when it
## dries, actions it forbids, a meter that cannot be stopped when full, a bleeding bite, a curse that lasts, a body that swells.

var arena: VerbArena
var player: Player

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player

func after_each() -> void:
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _start(spec: Dictionary, id := "verb_test") -> void:
	player.rage_start(spec, id)

func _kill() -> void:
	player.rage.on_kill(arena.lizard)

# --- the window ---

func test_a_window_adds_its_stats_and_takes_them_back() -> void:
	var atk := player.stats.get_stat("atk")
	_start({"seconds": 0.3, "stats": {"atk": 3}})
	assert_true(player.rage.active())
	assert_eq(player.stats.get_stat("atk"), atk + 3)
	await wait_seconds(0.6)
	assert_false(player.rage.active())
	assert_eq(player.stats.get_stat("atk"), atk)

func test_each_kill_refills_the_window_up_to_its_cap() -> void:
	_start({"seconds": 1.0, "stats": {"atk": 1}, "kill_refill": 2.0, "max_seconds": 4.0})
	_kill()
	assert_almost_eq(player.rage.left, 3.0, 0.1)
	_kill()
	_kill()
	assert_almost_eq(player.rage.left, 4.0, 0.01, "capped")

func test_a_crash_follows_the_window() -> void:
	var atk := player.stats.get_stat("atk")
	_start({"seconds": 0.2, "stats": {"atk": 3}, "crash": {"stats": {"atk": -2}, "seconds": 0.4}})
	await wait_seconds(0.4)
	assert_eq(player.stats.get_stat("atk"), atk - 2, "the crash")
	await wait_seconds(0.6)
	assert_eq(player.stats.get_stat("atk"), atk, "recovered")

func test_a_window_that_dries_without_a_kill_locks_its_verb() -> void:
	player.skillset.slots.add("verb_goblin_redcap")
	var ability: Ability = player._ability("verb_goblin_redcap")
	_start({"seconds": 0.2, "dry_lock": 30.0}, "verb_goblin_redcap")
	await wait_seconds(0.5)
	assert_false(ability.ready(), "it dried: the cap is lost for a while")

func test_a_window_that_was_fed_does_not_lock_its_verb_when_it_ends() -> void:
	player.skillset.slots.add("verb_goblin_redcap")
	var ability: Ability = player._ability("verb_goblin_redcap")
	_start({"seconds": 0.3, "kill_refill": 0.0, "dry_lock": 30.0}, "verb_goblin_redcap")
	_kill()
	await wait_seconds(0.6)
	assert_true(ability.ready(), "a kill kept it from drying")

# --- what it forbids, resists and shrugs off ---

func test_a_window_forbids_the_kinds_and_the_items_it_names() -> void:
	player.skillset.slots.add("verb_wolf_barghest")
	_start({"seconds": 5.0, "forbids": ["ring"]})
	var mp := player.mana.mp
	player.use_active(0)
	assert_eq(player.mana.mp, mp, "a ring cannot be cast")
	_start({"seconds": 5.0, "forbids": ["items"]})
	assert_true(player.rage.forbids("items"))
	assert_false(player.try_pickpocket(), "no items while frenzied")

func test_a_window_resists_a_damage_type_and_shrugs_off_the_flinch() -> void:
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_hit(20, "physical", Vector2(-40, 0))
	var plain := hp - player.health.hp
	player.health.hp = hp
	player._invuln = 0.0
	player.velocity = Vector2.ZERO
	player._dash = 0.0
	_start({"seconds": 5.0, "resist": {"physical": 100}, "no_flinch": true})
	player.receive_hit(20, "physical", Vector2(-40, 0))
	assert_gt(plain, 1, "an ordinary blow hurts")
	assert_lte(hp - player.health.hp, 1, "iron does not bite: it does no more than the least a blow can")
	assert_eq(player.velocity, Vector2.ZERO, "and there is no knockback")
	assert_eq(player._dash, 0.0)

# --- bleeding bites ---

func test_a_bleeding_window_makes_the_players_blows_bleed() -> void:
	_start({"seconds": 5.0, "bleed": 2.0})
	var ring := arena.verb("wolf_barghest")
	ring.spec = {"kind": "burst", "range": 80.0, "half_width": 40.0}
	ring.activate()
	assert_true(arena.lizard.is_bleeding())
	var hp := arena.lizard.health.hp
	await wait_seconds(1.3)
	assert_lt(arena.lizard.health.hp, hp, "it bleeds")

# --- the meter ---

func test_a_meter_grows_with_kills_scales_the_bonus_and_cannot_be_stopped_when_full() -> void:
	_start({"meter": {"start": 25.0, "per_kill": 40.0, "decay": 0.0}, "stats": {"atk": 4}})
	var atk := player.stats.get_stat("atk")
	assert_eq(atk, arena.player.stats.get_stat("atk"))
	var low := player.rage.meter
	_kill()
	assert_gt(player.rage.meter, low)
	assert_false(player.rage.drives())
	_kill()
	assert_gte(player.rage.meter, 100.0)
	assert_true(player.rage.drives(), "at full you cannot stop")

func test_a_meter_drains_and_the_frenzy_ends_at_nothing() -> void:
	_start({"meter": {"start": 10.0, "per_kill": 10.0, "decay": 40.0}, "stats": {"atk": 4}})
	await wait_seconds(0.6)
	assert_false(player.rage.active())

# --- kills reset the zip, shadow hides ---

func test_a_kill_resets_the_named_cooldowns() -> void:
	player.set_species("spider")
	_start({"seconds": 5.0, "kill_resets": ["zip"]})
	player.species_body.state.zip_cooldown = 3.0
	_kill()
	assert_eq(player.species_body.state.zip_cooldown, 0.0)

func test_a_window_that_hides_in_shadow_hides_only_in_the_dark() -> void:
	_start({"seconds": 5.0, "unseen_in_dark": true})
	player.in_dark = true
	assert_true(player.is_unseen())
	player.in_dark = false
	assert_false(player.is_unseen(), "needs shadow")

# --- a lone hunter ---

func test_a_lone_hunters_bonus_is_only_for_one_with_no_packmate() -> void:
	var atk := player.stats.get_stat("atk")
	_start({"seconds": 5.0, "alone": {"stats": {"atk": 4}, "isolated": 2.0}})
	assert_eq(player.stats.get_stat("atk"), atk + 4)
	player.companions.append(Node2D.new())
	player.rage.update(0.1)
	assert_eq(player.stats.get_stat("atk"), atk, "a packmate takes it away")
	player.companions.clear()
	player.rage.update(0.1)
	assert_eq(player.stats.get_stat("atk"), atk + 4)

func test_a_lone_hunter_hits_isolated_prey_harder() -> void:
	_start({"seconds": 5.0, "alone": {"stats": {}, "isolated": 2.0}})
	assert_eq(player.rage.power_mult_vs(arena.lizard), 2.0 if _isolated(arena.lizard) else 1.0)
	var friend := Enemy.new()
	friend.setup(arena.lizard.def, {})
	friend.position = arena.lizard.global_position + Vector2(20, 0)
	add_child_autofree(friend)
	assert_eq(player.rage.power_mult_vs(arena.lizard), 1.0, "prey with company is not isolated")

func _isolated(e: Enemy) -> bool:
	for n in get_tree().get_nodes_in_group("actors"):
		if n is Enemy and n != e and n.global_position.distance_to(e.global_position) < Rage.ISOLATED_RANGE:
			return false
	return true

# --- a curse that lasts, a body that swells ---

func test_a_curse_that_lasts_is_paid_when_the_window_ends_and_stays_for_the_life() -> void:
	var hp := player.stats.get_stat("max_hp")
	_start({"seconds": 0.2, "lasting": {"max_hp": -2}})
	await wait_seconds(0.5)
	assert_eq(player.stats.get_stat("max_hp"), hp - 2)
	player.rage_start({"seconds": 0.2, "lasting": {"max_hp": -2}}, "verb_test")
	await wait_seconds(0.5)
	assert_eq(player.stats.get_stat("max_hp"), hp - 4, "it stacks")

func test_a_body_swells_with_each_kill_up_to_its_limit() -> void:
	var atk := player.stats.get_stat("atk")
	_start({"seconds": 5.0, "swell": {"stat": "atk", "per_kill": 1, "max": 2}})
	_kill()
	assert_eq(player.stats.get_stat("atk"), atk + 1)
	_kill()
	_kill()
	assert_eq(player.stats.get_stat("atk"), atk + 2, "capped")
	assert_gt(player.rage.swell_size(), 1.0, "and it is bigger")

func test_the_spec_validates() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "rage", "seconds": 5, "stats": {"atk": 2}, "crash": {"stats": {"atk": -1}, "seconds": 2}, "forbids": ["ward", "items"]})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "burst", "rage": {"seconds": 5, "stats": {"atk": 2}}})), [])
	assert_ne(Array(VerbKinds.validate({"kind": "rage", "seconds": "long"})), [])
