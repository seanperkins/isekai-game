extends GutTest
## The rest of what the stance and body verbs need: a stance that is toggled, a heavy swing, a knock-down of heavy targets, extra damage against what killed
## you, and the body traits (knockback-proof, hazard-proof, armour from what is carried, more graft slots, a stench, no bond).

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000

func after_each() -> void:
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _verb(spec: Dictionary) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [4], 1)
	return a

func _damage_of(spec: Dictionary) -> int:
	lizard.health.hp = 1000
	lizard._ward_t = 0.0
	var a := _verb(spec)
	a.activate()
	return 1000 - lizard.health.hp

# --- a stance is toggled ---

func test_a_stance_is_taken_on_the_first_cast_after_a_beat_and_dropped_on_the_second() -> void:
	var atk := player.stats.get_stat("atk")
	var a := _verb({"kind": "rage", "toggle": true, "beat": 0.3, "stats": {"atk": 2}, "lock_blow": true})
	player.rage_start(a.spec, "verb_up")
	assert_true(player.rage.active())
	assert_eq(player.stats.get_stat("atk"), atk + 2)
	assert_true(player.is_held_still(), "rising costs a beat")
	assert_true(player.is_blow_locked(), "no pounce while up")
	player.rage_start(a.spec, "verb_up")
	assert_false(player.rage.active(), "the second cast drops to four")
	assert_eq(player.stats.get_stat("atk"), atk)
	assert_false(player.is_blow_locked(), "free to pounce again")

func test_a_stance_has_no_clock() -> void:
	player.rage_start({"kind": "rage", "toggle": true, "stats": {"atk": 2}}, "verb_up")
	await wait_seconds(1.0)
	assert_true(player.rage.active())

# --- a window can be a shield ---

func test_a_shield_window_resists_every_damage_type() -> void:
	player.rage_start({"seconds": 2.0, "resist": {"*": 100}}, "verb_shield")
	assert_eq(player.rage.percent_off("fire"), 100)
	assert_eq(player.rage.percent_off("physical"), 100)

# --- a heavy swing ---

func test_a_heavy_swing_hits_harder_and_holds_the_swinger_still() -> void:
	var plain := _damage_of({"kind": "burst", "range": 80.0, "half_width": 40.0})
	player._still_t = 0.0
	var heavy := _damage_of({"kind": "burst", "range": 80.0, "half_width": 40.0, "heft": 2.0})
	assert_gte(heavy, plain * 2 - 1, "it hits twice as hard (%d against %d)" % [heavy, plain])
	assert_true(player.is_held_still(), "and it is slow")

# --- a knock-down ---

func test_a_knockdown_stuns_a_heavy_target_that_cannot_be_stunned() -> void:
	var heavy: Enemy = lizard
	heavy.def = heavy.def.duplicate()
	heavy.def.predatable = false
	heavy.def.stats = heavy.def.stats.duplicate()
	heavy.def.stats["max_hp"] = DeedTags.HEAVY_HP + 10
	_verb({"kind": "burst", "range": 80.0, "half_width": 40.0, "knockdown": 2.0}).activate()
	assert_eq(heavy.status.state, EnemyStatus.STUNNED, "knocked down")

func test_a_knockdown_leaves_a_small_one_to_the_ordinary_status() -> void:
	lizard.def = lizard.def.duplicate()
	lizard.def.predatable = false
	lizard.def.stats = lizard.def.stats.duplicate()
	lizard.def.stats["max_hp"] = 5
	_verb({"kind": "burst", "range": 80.0, "half_width": 40.0, "knockdown": 2.0}).activate()
	assert_eq(lizard.status.state, EnemyStatus.ACTIVE)

func test_a_knockdown_does_not_fell_a_hunting_boss() -> void:
	lizard.hunting = true
	lizard.def = lizard.def.duplicate()
	lizard.def.stats = lizard.def.stats.duplicate()
	lizard.def.stats["max_hp"] = 100
	_verb({"kind": "burst", "range": 80.0, "half_width": 40.0, "knockdown": 2.0}).activate()
	assert_eq(lizard.status.state, EnemyStatus.ACTIVE)

# --- vengeance ---

func test_a_vengeance_hits_harder_against_what_killed_the_last_life() -> void:
	var plain := _damage_of({"kind": "burst", "range": 80.0, "half_width": 40.0, "vs_killer": 3.0})
	player.avenge_target = lizard.def.id
	var avenged := _damage_of({"kind": "burst", "range": 80.0, "half_width": 40.0, "vs_killer": 3.0})
	assert_gte(avenged, plain * 3 - 2, "three times against it (%d against %d)" % [avenged, plain])

# --- the body traits ---

func test_knockback_proof_takes_the_shove_out_of_a_blow() -> void:
	player.skillset.capabilities["trait_knockback_proof"] = 1
	player._invuln = 0.0
	player.receive_hit(5, "physical", Vector2(-40, 0))
	assert_eq(player.velocity, Vector2.ZERO)
	assert_eq(player._dash, 0.0)

func test_hazard_proof_walks_through_a_poison_cloud_and_a_thrown_spear() -> void:
	player.skillset.capabilities["trait_hazard_proof"] = 1
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_poison(3, 1, 3.0)
	player.receive_hit(5, "physical", Vector2(40, 0), "spear")
	assert_eq(player.health.hp, hp)
	player.receive_hit(5, "physical", Vector2(40, 0), "lizard")
	assert_lt(player.health.hp, hp, "a bite still bites")

func test_hoard_armour_takes_a_point_off_for_each_part_carried_up_to_four() -> void:
	player.skillset.capabilities["trait_hoard_armour"] = 1
	assert_eq(player.skillset.incoming("physical", 20, 30, 0.0, 0)["flat_off"], 0)
	assert_eq(player.skillset.incoming("physical", 20, 30, 0.0, 2)["flat_off"], 2)
	assert_eq(player.skillset.incoming("physical", 20, 30, 0.0, 9)["flat_off"], 4)

func test_a_stitched_body_wears_two_more_grafts() -> void:
	assert_eq(player.inventory.graft_cap(), Inventory.GRAFT_CAP)
	player.skillset.capabilities["trait_extra_grafts"] = 1
	player.refresh_stats()
	assert_eq(player.inventory.graft_cap(), Inventory.GRAFT_CAP + 2)

func test_a_stench_slows_the_enemies_close_to_the_body() -> void:
	player.skillset.capabilities["trait_stench"] = 1
	lizard.global_position = Vector2(20, 0)
	await wait_physics_frames(25)
	assert_gt(lizard._slow, 0.0)

func test_no_bond_means_no_companion_at_all() -> void:
	assert_gt(player.companion_cap(), 0)
	player.skillset.capabilities["trait_no_bond"] = 1
	assert_eq(player.companion_cap(), 0)
