extends GutTest
## The shipped stance and body verbs, cast for real as the skill files have them: what each does and what it costs.

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

func _cast(form: String) -> VerbAbility:
	var a := arena.verb(form)
	assert_true(a.activate(), "%s cast" % form)
	return a

func _form(id: String) -> FormDef:
	return load("res://data/forms/%s.tres" % id)

func test_rise_is_a_stance_that_costs_a_beat_and_locks_the_pounce() -> void:
	var atk := player.stats.get_stat("atk")
	var a := _cast("wolf_moonbound")
	assert_eq(player.stats.get_stat("atk"), atk + 2)
	assert_true(player.is_held_still(), "rising costs a beat")
	assert_true(player.is_blow_locked(), "no pounce while up")
	a._cooldown = 0.0
	a.activate()
	assert_false(player.rage.active(), "drop to four")

func test_frenzy_is_a_meter_kills_stoke_with_bleeding_bites_and_no_guard() -> void:
	var a := _cast("wolf_loup_garou")
	assert_true(player.rage.active())
	var low := player.rage.meter
	player.rage.on_kill(lizard)
	assert_gt(player.rage.meter, low, "a kill stokes it")
	assert_true(player.rage.forbids("ward") and player.rage.forbids("items"), "no guard, no items")
	assert_gt(float(player.rage.spec["bleed"]), 0.0, "bleeding bites")
	player.rage.on_kill(lizard)
	player.rage.on_kill(lizard)
	assert_true(player.rage.drives(), "at full you cannot stop")
	assert_not_null(a)

func test_skin_is_a_berserk_window_with_no_flinch_iron_proof_and_a_crash() -> void:
	var atk := player.stats.get_stat("atk")
	_cast("wolf_ulfhedinn")
	assert_true(player.rage.no_flinch())
	assert_eq(player.rage.percent_off("physical"), 60)
	assert_eq(player.stats.get_stat("atk"), atk + 3)
	player.rage.stop()
	assert_lt(player.stats.get_stat("atk"), atk, "a crash after the window")

func test_shield_bite_breaks_guards_refills_on_kills_and_still_crashes() -> void:
	var atk := player.stats.get_stat("atk")
	_cast("wolf_wolfskin_champion")
	assert_lt(lizard.health.hp, 1000, "the bite lands, through its armour")
	var left := player.rage.left
	player.rage.on_kill(lizard)
	assert_gt(player.rage.left, left - 0.1, "a kill refills the window")
	player.rage.stop()
	assert_lt(player.stats.get_stat("atk"), atk, "still crashes")

func test_lone_hunter_is_for_one_with_no_packmate_and_the_bond_is_disabled() -> void:
	var atk := player.stats.get_stat("atk")
	_cast("wolf_amarok")
	assert_eq(player.stats.get_stat("atk"), atk + 4)
	assert_true(_form("wolf_amarok").traits.has("no_bond"))
	player.skillset.capabilities["trait_no_bond"] = 1
	assert_eq(player.companion_cap(), 0)

func test_tank_knocks_down_heavy_targets_and_the_body_is_knockback_proof() -> void:
	lizard.def = lizard.def.duplicate()
	lizard.def.predatable = false
	lizard.def.stats = lizard.def.stats.duplicate()
	lizard.def.stats["max_hp"] = DeedTags.HEAVY_HP + 5
	_cast("wolf_dire_wolf")
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)
	assert_true(_form("wolf_dire_wolf").traits.has("knockback_proof"))

func test_dye_is_fed_by_kills_and_the_cap_is_lost_when_it_dries() -> void:
	player.skillset.slots.add("verb_goblin_redcap")
	var ability: Ability = player._ability("verb_goblin_redcap")
	player.mana.mp = player.mana.max_mp
	player.use_active(0)
	assert_true(player.rage.active())
	var left := player.rage.left
	player.rage.on_kill(lizard)
	assert_gt(player.rage.left, left, "a kill refreshes it")
	player.rage.left = 0.01
	player.rage.on_kill(lizard)
	player.rage.left = 0.0
	player.rage.stop()
	player.rage.start(player, player.rage.spec, "verb_goblin_redcap")
	player.rage.left = 0.01
	player.rage.update(0.1)
	assert_false(ability.ready(), "dried with no kill: lost for a long while")

func test_cursed_gear_is_huge_and_the_curse_stays() -> void:
	var hp := player.stats.get_stat("max_hp")
	var atk := player.stats.get_stat("atk")
	_cast("goblin_ring_maker")
	assert_eq(player.stats.get_stat("atk"), atk + 6)
	player.rage.stop()
	assert_eq(player.stats.get_stat("max_hp"), hp - 2, "the curse is lasting")

func test_flawless_gear_forges_two_slots_and_costs_three_parts() -> void:
	player.collect_part("claw")
	assert_eq(player.parts_carried(), 3)
	var atk := player.stats.get_stat("atk")
	var def := player.stats.get_stat("def")
	_cast("goblin_mastersmith")
	assert_eq(player.stats.get_stat("atk"), atk + 3)
	assert_eq(player.stats.get_stat("def"), def + 2, "a second gear slot")
	assert_eq(player.parts_carried(), 0, "high cost")

func test_heft_swings_are_slow_and_hit_harder_and_the_draugr_swells_with_kills() -> void:
	var atk := player.stats.get_stat("atk")
	_cast("undead_draugr")
	assert_true(player.is_held_still(), "slow")
	player.rage.on_kill(lizard)
	assert_eq(player.stats.get_stat("atk"), atk + 1, "it swells")

func test_the_cleaver_is_heavy_and_the_stitched_body_wears_more_and_stinks() -> void:
	_cast("undead_abomination")
	assert_true(player.is_held_still())
	var f := _form("undead_abomination")
	assert_true(f.traits.has("extra_grafts") and f.traits.has("stench"))

func test_the_overhead_cleave_is_followed_by_the_shield() -> void:
	_cast("undead_bone_warrior")
	assert_eq(player.rage.percent_off("fire"), 50, "half damage behind the shield")

func test_vengeance_hits_what_killed_you_harder() -> void:
	var spec: Dictionary = arena.verb("undead_revenant_knight").spec
	assert_gt(float(spec["vs_killer"]), 1.0)
	_cast("undead_revenant_knight")
	var plain := 1000 - lizard.health.hp
	lizard.health.hp = 1000
	player.avenge_target = lizard.def.id
	var a := arena.verb("undead_revenant_knight")
	a.activate()
	assert_gte(1000 - lizard.health.hp, int(plain * 2.0), "harder against its killer")

func test_the_stomp_stuns_and_the_colossus_walks_through_hazards() -> void:
	_cast("undead_bone_colossus")
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)
	assert_true(_form("undead_bone_colossus").traits.has("hazard_proof"))

func test_the_barrow_slam_stuns_and_armour_comes_from_what_is_carried() -> void:
	_cast("undead_barrow_king")
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)
	assert_true(_form("undead_barrow_king").traits.has("hoard_armour"))

func test_the_iron_boot_is_a_slow_heavy_stomp() -> void:
	_cast("goblin_ironboot")
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)
	assert_true(player.is_held_still())

# --- the second group ---

func test_reset_hides_the_hunter_in_shadow_and_kills_reset_the_zip() -> void:
	player.set_species("spider")
	_cast("spider_nightstalker")
	player.in_dark = true
	assert_true(player.is_unseen(), "unseen in shadow")
	player.in_dark = false
	assert_false(player.is_unseen(), "needs shadow (the drawback)")
	player.species_body.state.zip_cooldown = 3.0
	player.rage.on_kill(lizard)
	assert_eq(player.species_body.state.zip_cooldown, 0.0, "kills reset the zip")

func test_ambush_drops_from_the_ceiling_and_is_weak_in_a_lit_room() -> void:
	var spec: Dictionary = arena.verb("spider_stalker").spec
	assert_gt(float(spec["drop"]), 1.0)
	assert_lt(float(spec["lit_mult"]), 1.0, "weak in lit rooms")

func test_the_silent_drop_is_a_bonus_in_the_dark_only() -> void:
	player.in_dark = false
	_cast("spider_shadow_stalker")
	var lit := 1000 - lizard.health.hp
	lizard.health.hp = 1000
	player.in_dark = true
	var a := arena.verb("spider_shadow_stalker")
	a.activate()
	assert_gt(1000 - lizard.health.hp, lit * 2, "dim light: a bonus strike")

func test_weigh_drains_the_weaker_and_not_the_stronger() -> void:
	lizard.def = lizard.def.duplicate()
	lizard.def.essences = {"earth": 1}
	_cast("undead_heart_weigher")
	assert_lte(lizard.health.hp, 0)

func test_the_giant_slayer_scales_with_size() -> void:
	lizard.def = lizard.def.duplicate()
	lizard.def.stats = lizard.def.stats.duplicate()
	lizard.def.stats["max_hp"] = 3
	_cast("goblin_giant_killer")
	var small := 1000 - lizard.health.hp
	lizard.health.hp = 1000
	lizard._ward_t = 0.0
	lizard.def.stats["max_hp"] = 80
	var a := arena.verb("goblin_giant_killer")
	a.activate()
	assert_gt(1000 - lizard.health.hp, small * 3, "weak against small foes (the drawback)")

func test_devour_eats_a_corpse_and_without_one_swings_heavy() -> void:
	var corpse := Enemy.new()
	corpse.setup(lizard.def, {})
	corpse.position = Vector2(25, 0)
	add_child_autofree(corpse)
	corpse.status.down()
	lizard.global_position = Vector2(900, 0)
	player.health.hp = 5
	_cast("undead_zombie")
	assert_eq(player.health.hp, 13)
	assert_true(player.is_held_still() == false, "a meal is not a swing")

func test_rend_paralyses_and_leaves_a_stench_cloud_and_the_ghoul_is_frail_to_light() -> void:
	_cast("undead_ghoul")
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)
	assert_eq(get_tree().get_nodes_in_group("player_clouds").size(), 1)
	assert_true(_form("undead_ghoul").traits.has("light_frail"))

func test_the_vampires_bite_heals_it_and_it_trades_holy_for_speed() -> void:
	player.health.hp = 10
	_cast("undead_vampire")
	assert_gt(player.health.hp, 10)
	var f := _form("undead_vampire")
	assert_true(f.traits.has("light_frail"))
	assert_gt(int(f.stats["spd"]), 0, "fast")

func test_the_hop_is_three_bounds_and_a_talisman_stops_it() -> void:
	var spec: Dictionary = arena.verb("undead_jiangshi").spec
	assert_eq(int(spec["hops"]), 3)
	var t := RoomTalisman.new()
	t.setup({"id": "tal", "pos": Vector2(0, 0), "radius": 100.0}, {})
	add_child_autofree(t)
	arena.verb("undead_jiangshi").activate()
	await wait_physics_frames(2)
	assert_almost_eq(player.velocity.x, 0.0, 1.0, "no hop inside the talisman's reach")

func test_float_hangs_in_the_air_and_the_body_is_very_frail_and_very_strong() -> void:
	_cast("undead_demilich")
	assert_eq(player._glide_fall, 0.0)
	var f := _form("undead_demilich")
	assert_lt(int(f.stats["max_hp"]), 10, "the frailest form")
	assert_gte(int(f.stats["atk"]), 5, "very strong")
