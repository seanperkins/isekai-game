extends GutTest
## The shipped companion, summon and ward-stone verbs, cast for real as the skill files have them: what each does and what it costs.

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
	lizard.global_position = Vector2(900, 0)
	player.global_position = Vector2(-300, 0)
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("verb_allies"):
		n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _cast(form: String) -> VerbAbility:
	var a := arena.verb(form)
	assert_true(a.activate(), "%s cast" % form)
	return a

func _creature(id: String) -> CreatureDef:
	return DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == id)[0]

func _enemy(id: String, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(_creature(id), {})
	e.position = at
	add_child_autofree(e)
	return e

func _allies() -> Array:
	return get_tree().get_nodes_in_group("verb_allies")

func test_court_is_three_slimes_that_die_to_a_touch() -> void:
	_cast("king_slime")
	assert_eq(_allies().size(), 3)
	assert_true(_allies()[0].mortal, "the court dies in one hit")

func test_bond_is_a_lasting_packmate_and_a_heavier_pounce() -> void:
	_cast("wolf_warg")
	assert_eq(player.companions.size(), 1)
	assert_gt(player.rage.blow_mult(), 1.0)
	assert_gt(player.rage.blow_knockback(), 0.0, "knockback")
	assert_lte(player.companions.size(), 1, "one bonded packmate")

func test_suckle_mends_and_grows_a_pup() -> void:
	player.form.form_id = "wolf_lupa"
	var pal := player.add_companion(_creature("gloom_wolf"), player.global_position, {"hp": 10})
	pal.hp = 1
	var a := arena.verb("wolf_lupa")
	pal.global_position = player.global_position
	a.activate()
	assert_gt(pal.hp, 1)
	for i in 2:
		a._cooldown = 0.0
		a.activate()
	assert_eq(player.companions.size(), 2, "the pup is a second packmate")

func test_the_first_wolfs_roar_turns_the_wolves_not_a_boss() -> void:
	var wolf := _enemy("gloom_wolf", Vector2(-250, 0))
	var boss := _enemy("gloom_wolf", Vector2(-200, 0))
	boss.hunting = true
	_cast("wolf_lycaon")
	assert_true(wolf.is_turned())
	assert_false(boss.is_turned())

func test_the_spectral_pack_pounces_with_you_and_fades() -> void:
	lizard.global_position = Vector2(-260, 0)
	_cast("wolf_cwn_annwn")
	assert_eq(_allies().size(), 2)
	for a in _allies():
		a.global_position = Vector2(-300, 0)
	player.echo_pounce()
	await wait_physics_frames(3)
	assert_lt(lizard.health.hp, 1000, "the echoes pounced")
	assert_almost_eq(float(_allies()[0]._seconds), 8.0, 0.01, "and fade after eight seconds")

func test_guardian_wards_a_packmate_and_tethers_you_to_the_holy_ground() -> void:
	var pal := player.add_companion(_creature("gloom_wolf"), player.global_position, {"hp": 4})
	_cast("wolf_church_grim")
	await wait_physics_frames(5)
	assert_true(pal.is_warded())
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(3)
	assert_lte(absf(player.global_position.x - (-300.0)), 161.0, "tethered")

func test_offer_tames_a_weakened_creature() -> void:
	var rat := _enemy("cave_rat", Vector2(-280, 0))
	player.collect_part("claw")
	rat.health.hp = 1
	_cast("goblin_beastcaller")
	assert_eq(player.companions.size(), 1)

func test_the_pipe_draws_the_rats_and_you_cannot_throw() -> void:
	var rat := _enemy("cave_rat", Vector2(-250, 0))
	_cast("goblin_pied_piper")
	assert_eq(_allies().size(), 3)
	assert_true(rat.is_turned())
	assert_true(player.is_blow_locked())

func test_the_knot_is_one_big_companion() -> void:
	player.form.form_id = "goblin_rat_king"
	_cast("goblin_rat_king")
	assert_eq(player.companions.size(), 1)
	assert_true(player.companions[0].swarm)

func test_two_fragile_companions() -> void:
	player.form.form_id = "goblin_lord_of_beasts"
	_cast("goblin_lord_of_beasts")
	assert_eq(player.companions.size(), 2)
	assert_lte(player.companions[0].hp, 3, "fragile")

func test_mount_fuses_and_exposes_the_companion() -> void:
	var a := arena.verb("goblin_beast_rider")
	a.activate()
	assert_false(player.is_mounted(), "nothing to ride")
	var pal := player.add_companion(_creature("gloom_wolf"), player.global_position, {"hp": 4})
	a._cooldown = 0.0
	a.activate()
	assert_true(player.is_mounted())
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_hit(3, "physical", Vector2.INF)
	assert_eq(player.health.hp, hp)
	assert_lt(pal.hp, 4, "exposed")

func test_the_spear_charge_is_weak_on_foot() -> void:
	var spec: Dictionary = arena.verb("goblin_wolf_lord").spec
	assert_lt(float(spec["ride"]["foot"]), 1.0)
	assert_gt(float(spec["ride"]["mounted"]), 1.0)

func test_hearth_slows_and_mends_and_two_stones_stand() -> void:
	player.health.hp = 10
	var a := _cast("goblin_tomte")
	lizard.global_position = Vector2(-280, 0)
	await wait_seconds(1.3)
	assert_gt(lizard._slow, 0.0)
	assert_gt(player.health.hp, 10)
	for i in 2:
		player.global_position = Vector2(-200.0 + i * 100.0, 0)
		a._cooldown = 0.0
		a.activate()
	assert_eq(get_tree().get_nodes_in_group("ward_stones").size(), 2)

func test_lar_links_the_stones_and_holds_you_still() -> void:
	var a := _cast("goblin_hearth_god")
	assert_true(player.is_held_still(), "immobile when it counts")
	var one: float = get_tree().get_nodes_in_group("ward_stones")[0].effective_radius()
	player.global_position = Vector2(-220, 0)
	a._cooldown = 0.0
	a.activate()
	assert_gt(get_tree().get_nodes_in_group("ward_stones")[0].effective_radius(), one)

func test_ward_protects_an_area() -> void:
	_cast("goblin_hob")
	await wait_physics_frames(4)
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_hit(5, "physical", Vector2.INF)
	assert_eq(player.health.hp, hp)

func test_the_curse_stone_frightens_enemies_and_your_own_allies() -> void:
	var ally := VerbAlly.new()
	add_child_autofree(ally)
	ally.launch(player, player.global_position + Vector2(10, 0), 1, 10.0, Color.WHITE)
	lizard.global_position = Vector2(-260, 0)
	_cast("goblin_boggart")
	await wait_seconds(1.3)
	assert_true(lizard.is_fleeing())
	assert_true(ally.is_afraid(), "allies fear you too")

func test_the_horn_stuns_rallies_and_is_loud() -> void:
	var far := _enemy("lizard", Vector2(-100, 0))
	await wait_physics_frames(3)
	var pal := player.add_companion(_creature("gloom_wolf"), player.global_position, {})
	_cast("goblin_horn_bearer")
	assert_gt(pal._rally_t, 0.0, "rallied")
	assert_true(far.is_alert(), "loud: it woke what was near")

func test_shield_wall_blocks_thrusts_and_sows_two_soldiers_while_rooted() -> void:
	_cast("undead_spartoi_hoplite")
	assert_eq(_allies().size(), 2)
	assert_true(player.is_held_still(), "rooted while sowing")
	assert_eq(player.rage.percent_off("physical"), 70, "the block")

func test_the_squad_is_four_mortal_soldiers() -> void:
	_cast("undead_sower_of_teeth")
	assert_eq(_allies().size(), 4)

func test_the_dance_rises_only_near_bodies() -> void:
	_cast("undead_master_of_the_dance")
	assert_eq(_allies().size(), 0, "only works near bodies")
	var corpse := _enemy("lizard", Vector2(-280, 0))
	corpse.status.down()
	var a := arena.verb("undead_master_of_the_dance")
	a.activate()
	assert_eq(_allies().size(), 1)

func test_minions_are_one_more_with_a_focus() -> void:
	var a := arena.verb("undead_adept")
	a.activate()
	assert_eq(_allies().size(), 2)
	player.collect_part("focus")
	a._cooldown = 0.0
	a.activate()
	assert_eq(_allies().size(), 3, "a focus makes a third")

func test_sisters_are_seven_webbing_decoys() -> void:
	lizard.global_position = Vector2(-200, 0)
	_cast("spider_seven_spider_spirits")
	assert_eq(_allies().size(), 7)
	assert_true(_allies()[0].web)
	assert_true(lizard.is_lured(), "they draw the enemies")

func test_brood_needs_cocoons_and_the_young_carry() -> void:
	var a := arena.verb("spider_broodmother")
	a.activate()
	assert_eq(_allies().size(), 0)
	player.inventory.add_cocoon("lizard")
	a._cooldown = 0.0
	a.activate()
	assert_eq(_allies().size(), 2)
	assert_true(_allies()[0].carry)

func test_command_follows_your_lead() -> void:
	_cast("spider_brood_queen")
	assert_eq(_allies().size(), 4)
	assert_true(_allies()[0].command)

func test_hatch_takes_time_and_the_young_are_stronger() -> void:
	player.inventory.add_cocoon("lizard")
	_cast("spider_cocoon_mother")
	assert_eq(_allies().size(), 0, "takes time")
	await wait_seconds(3.0)
	assert_eq(_allies().size(), 2)

func test_consecrate_mends_summons_and_burns_the_living_and_the_body_does_not_drain() -> void:
	var f := load("res://data/forms/undead_hierophant.tres") as FormDef
	assert_true(f.traits.has("no_drain") and f.traits.has("dark_weak"))
	_cast("undead_hierophant")
	assert_eq(get_tree().get_nodes_in_group("player_clouds").size(), 1)

func test_decree_curses_the_room_and_raises_tomb_guards() -> void:
	lizard.global_position = Vector2(300, 0)  # across the room
	_cast("undead_pharaoh")
	assert_true(lizard.is_cursed())
	assert_eq(_allies().size(), 2)

func test_hidden_soul_cheats_a_death_once() -> void:
	_cast("undead_deathless")
	player._invuln = 0.0
	player.receive_hit(999, "physical", Vector2.INF)
	assert_false(player.health.is_dead())

func test_bone_beams_bounce_and_the_lich_blinks_back() -> void:
	lizard.global_position = Vector2(-260, 0)
	var x := player.global_position.x
	_cast("undead_lich")
	assert_lt(lizard.health.hp, 1000)
	assert_lt(player.global_position.x, x, "a blink back")
