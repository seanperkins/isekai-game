extends GutTest
## The verbs that bond, tame, grow, turn and ride: a lasting packmate, two fragile companions, a swarm that is one big companion, an offer to a weakened
## creature, a pup that grows, wild creatures that join briefly, and a ride that puts the companion in the way.

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	_floor()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000
	lizard.global_position = Vector2(900, 0)
	player.global_position = Vector2(-300, 0)

func _floor() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

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

func _creature(id: String) -> CreatureDef:
	return DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == id)[0]

func _enemy(id: String, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(_creature(id), {})
	e.position = at
	add_child_autofree(e)
	return e

# --- a lasting packmate ---

func test_a_companion_verb_bonds_a_packmate_that_lasts_and_only_one_at_the_cap() -> void:
	_verb({"kind": "companion", "creature": "gloom_wolf"}).activate()
	assert_eq(player.companions.size(), 1)
	_verb({"kind": "companion", "creature": "gloom_wolf", "cooldown": 0.0}).activate()
	assert_eq(player.companions.size(), 1, "one bonded packmate")
	await wait_seconds(1.0)
	assert_eq(player.companions.size(), 1, "and it lasts, it is not a timed summon")

func test_two_fragile_companions_at_once_for_the_capstone() -> void:
	player.form.form_id = "goblin_lord_of_beasts"
	_verb({"kind": "companion", "creature": "cave_rat", "count": 2, "hp": 2}).activate()
	assert_eq(player.companions.size(), 2)
	assert_eq(player.companions[0].hp, 2, "fragile")

func test_a_swarm_is_one_big_companion_that_strikes_everything_close() -> void:
	_verb({"kind": "companion", "creature": "cave_rat", "swarm": true, "hp": 12}).activate()
	assert_eq(player.companions.size(), 1)
	var pal: Companion = player.companions[0]
	var a := _enemy("lizard", Vector2(-290, 0))
	var b := _enemy("lizard", Vector2(-300, 8))
	a.health.max_hp = 100
	a.health.hp = 100
	b.health.max_hp = 100
	b.health.hp = 100
	pal.global_position = Vector2(-295, 0)
	await wait_physics_frames(10)
	assert_lt(a.health.hp, 100, "one foe struck")
	assert_lt(b.health.hp, 100, "and the other by the same swarm")

# --- an offer ---

func test_an_offer_tames_a_weakened_creature_with_a_part_and_not_a_healthy_one() -> void:
	var rat := _enemy("cave_rat", Vector2(-280, 0))
	player.collect_part("claw")
	var parts := player.parts_carried()
	assert_false(player.try_offer(60.0), "a healthy rat refuses")
	rat.health.hp = 1
	assert_true(player.try_offer(60.0), "a weakened one takes it")
	assert_eq(player.companions.size(), 1)
	assert_eq(player.parts_carried(), parts - 1, "the item is spent")

# --- a pup that grows ---

func test_suckle_heals_the_packmate_and_the_third_one_grows_a_pup_into_a_second() -> void:
	player.form.form_id = "wolf_lupa"
	var pal := player.add_companion(_creature("gloom_wolf"), player.global_position, {"hp": 10})
	assert_not_null(pal)
	pal.hp = 2
	var a := _verb({"kind": "suckle", "radius": 80.0, "hp": 3, "grow": 3})
	pal.global_position = player.global_position
	a.activate()
	assert_gt(pal.hp, 2, "healed")
	assert_eq(player.companions.size(), 1)
	for i in 2:
		a._cooldown = 0.0
		a.activate()
	assert_eq(player.companions.size(), 2, "the pup is a second packmate")

# --- turned creatures ---

func test_a_roar_turns_the_pack_creatures_in_the_room_for_a_while_and_they_fight_for_the_player() -> void:
	var wolf := _enemy("gloom_wolf", Vector2(-250, 0))
	var foe := _enemy("lizard", Vector2(-215, 0))
	foe.health.max_hp = 100
	foe.health.hp = 100
	_verb({"kind": "roar", "radius": 400.0, "seconds": 1.0}).activate()
	assert_true(wolf.is_turned())
	assert_false(foe.is_turned(), "a lizard is not a wolf")
	await wait_seconds(0.8)
	assert_lt(foe.health.hp, 100, "the wolf fought the lizard")
	await wait_seconds(1.0)
	assert_false(wolf.is_turned(), "briefly")

func test_a_turned_creature_does_not_hurt_the_player_and_the_player_does_not_hurt_it() -> void:
	var wolf := _enemy("gloom_wolf", Vector2(-290, 0))
	player._invuln = 0.0
	var hp := player.health.hp
	wolf.turn_for(2.0)
	await wait_physics_frames(30)
	assert_eq(player.health.hp, hp)
	_verb({"kind": "burst", "range": 60.0, "half_width": 60.0}).activate()
	assert_eq(wolf.health.hp, wolf.health.max_hp, "the player's blows pass it by")

func test_a_bosss_will_is_not_turned() -> void:
	var boss := _enemy("gloom_wolf", Vector2(-250, 0))
	boss.hunting = true
	assert_false(boss.turn_for(2.0))

func test_a_pipe_calls_followers_and_draws_the_vermin() -> void:
	var rat := _enemy("cave_rat", Vector2(-250, 0))
	var foe := _enemy("lizard", Vector2(-215, 0))
	_verb({"kind": "summon", "count": 3, "seconds": 5.0, "turn": {"ids": ["cave_rat"], "radius": 300.0, "seconds": 3.0}, "lock": 3.0}).activate()
	assert_eq(get_tree().get_nodes_in_group("verb_allies").size(), 3)
	assert_true(rat.is_turned(), "the vermin came")
	assert_false(foe.is_turned())
	assert_true(player.is_blow_locked(), "cannot throw while playing")

# --- a ride ---

func test_a_ride_needs_a_companion_and_puts_it_in_the_way_of_the_blows() -> void:
	var mount := _verb({"kind": "mount", "seconds": 6.0, "stats": {"spd": 40, "atk": 2}})
	mount.activate()
	assert_false(player.is_mounted(), "no companion, no ride")
	var pal := player.add_companion(_creature("gloom_wolf"), player.global_position, {"hp": 6})
	mount._cooldown = 0.0
	var atk := player.stats.get_stat("atk")
	mount.activate()
	assert_true(player.is_mounted())
	assert_gt(player.stats.get_stat("atk"), atk)
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_hit(4, "physical", Vector2.INF)
	assert_eq(player.health.hp, hp, "the mount took it")
	assert_lt(pal.hp, 6, "the companion is exposed")
	player._invuln = 0.0
	player.receive_hit(50, "physical", Vector2.INF)
	assert_false(player.is_mounted(), "the mount is gone")

func test_a_spear_charge_is_strong_mounted_and_weak_on_foot() -> void:
	lizard.global_position = Vector2(-270, 0)
	lizard.health.hp = 1000
	var spec := {"kind": "dash", "hit_range": 60.0, "hit_half_width": 40.0, "ride": {"mounted": 2.0, "foot": 0.4}}
	_verb(spec).activate()
	var foot := 1000 - lizard.health.hp
	lizard.health.hp = 1000
	lizard._ward_t = 0.0
	player.add_companion(_creature("gloom_wolf"), player.global_position, {})
	var a := _verb(spec)
	a.activate()
	var mounted := 1000 - lizard.health.hp
	assert_gt(mounted, foot * 3, "mounted %d, on foot %d" % [mounted, foot])

# --- a heavier pounce ---

func test_a_window_can_make_the_pounce_heavier_and_shove_what_it_hits() -> void:
	player.rage_start({"seconds": 5.0, "blow": {"mult": 2.0, "knockback": 200.0}}, "verb_test")
	assert_eq(player.rage.blow_mult(), 2.0)
	assert_eq(player.rage.blow_knockback(), 200.0)
	player.rage.stop()
	assert_eq(player.rage.blow_mult(), 1.0)

func test_the_new_keys_validate() -> void:
	for spec in [{"kind": "companion", "creature": "gloom_wolf", "count": 2, "hp": 3, "swarm": true}, {"kind": "offer", "range": 60, "weak": 0.5},
			{"kind": "suckle", "radius": 80, "hp": 3, "grow": 3}, {"kind": "roar", "radius": 400, "seconds": 8}, {"kind": "mount", "seconds": 10, "stats": {"spd": 30}},
			{"kind": "dash", "ride": {"mounted": 2.0, "foot": 0.5}}, {"kind": "summon", "turn": {"ids": ["cave_rat"], "radius": 200, "seconds": 3}}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
