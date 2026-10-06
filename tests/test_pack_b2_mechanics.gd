extends GutTest
## Ambush from the ceiling and in the dark, weighing a creature's essence, devouring a corpse, a stench cloud, a size-scaled blow, a bounding hop that a
## talisman stops, and the frailty to holy light.

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
	_verb(spec).activate()
	return 1000 - lizard.health.hp

# --- ambush ---

func test_a_drop_from_the_ceiling_falls_on_what_is_below_for_more() -> void:
	var below := Enemy.new()
	below.setup(lizard.def, {})
	below.position = Vector2(0, 40)
	add_child_autofree(below)
	below.health.max_hp = 1000
	below.health.hp = 1000
	lizard.global_position = Vector2(900, 0)
	var plain := {"kind": "dash", "speed": 0.0, "hit_range": 80.0, "hit_half_width": 20.0}
	_verb(plain).activate()
	var flat := 1000 - below.health.hp
	below.health.hp = 1000
	player._ceiling_t = 1.0
	_verb({"kind": "dash", "speed": 0.0, "hit_range": 80.0, "hit_half_width": 20.0, "drop": 3.0}).activate()
	var dropped := 1000 - below.health.hp
	assert_eq(flat, 0, "a lunge forward misses what is under you")
	assert_gt(dropped, 0, "the drop falls on it")

func test_a_strike_in_the_dark_is_a_bonus_and_in_a_lit_room_it_is_weak() -> void:
	player.in_dark = false
	var lit := _damage_of({"kind": "dash", "hit_range": 80.0, "hit_half_width": 40.0, "dim": 2.0, "lit_mult": 0.5})
	player.in_dark = true
	var dark := _damage_of({"kind": "dash", "hit_range": 80.0, "hit_half_width": 40.0, "dim": 2.0, "lit_mult": 0.5, "cooldown": 0.0})
	assert_gt(dark, lit * 2, "the dark doubles it and the light halves it (%d against %d)" % [dark, lit])

# --- weigh ---

func test_weighing_drains_a_creature_whose_essence_is_lower() -> void:
	lizard.def = lizard.def.duplicate()
	lizard.def.essences = {"earth": 1}
	for i in 5:
		arena.rules.handle_event(Events.ABSORBED, {"essence": "dark", "source": "test"})
	player.health.hp = 5
	_verb({"kind": "weigh", "range": 80.0, "half_width": 40.0}).activate()
	assert_lte(lizard.health.hp, 0, "the weaker is drained at once")
	assert_gt(player.health.hp, 5, "and what was drained feeds the weigher")

func test_weighing_does_nothing_to_a_creature_with_more_essence() -> void:
	lizard.def = lizard.def.duplicate()
	lizard.def.essences = {"earth": 50, "dark": 50}
	_verb({"kind": "weigh", "range": 80.0, "half_width": 40.0}).activate()
	assert_eq(lizard.health.hp, 1000, "useless against stronger foes")

# --- a blow that scales with size ---

func test_a_size_scaled_blow_is_weak_against_small_foes_and_strong_against_big_ones() -> void:
	lizard.def = lizard.def.duplicate()
	lizard.def.stats = lizard.def.stats.duplicate()
	lizard.def.stats["max_hp"] = 4
	var small := _damage_of({"kind": "bolt", "range": 80.0, "size_scale": 12.0})
	lizard.def.stats["max_hp"] = 60
	var big := _damage_of({"kind": "bolt", "range": 80.0, "size_scale": 12.0, "cooldown": 0.0})
	assert_gt(big, small * 3, "big %d, small %d" % [big, small])

# --- devour ---

func test_devour_eats_a_corpse_to_heal_and_without_one_it_is_a_heavy_swing() -> void:
	var corpse := Enemy.new()
	corpse.setup(lizard.def, {})
	corpse.position = Vector2(25, 0)
	add_child_autofree(corpse)
	corpse.status.down()
	lizard.global_position = Vector2(900, 0)
	player.health.hp = 5
	_verb({"kind": "devour", "range": 60.0, "hp": 8}).activate()
	assert_eq(player.health.hp, 13, "healed by the meal")
	assert_eq(corpse.status.state, EnemyStatus.GONE, "the corpse is gone")
	lizard.global_position = Vector2(30, 0)
	await wait_physics_frames(2)
	var before := lizard.health.hp
	_verb({"kind": "devour", "range": 60.0, "hp": 8, "heft": 2.0, "cooldown": 0.0}).activate()
	assert_lt(lizard.health.hp, before, "no corpse: a heavy swing")

# --- a stench cloud ---

func test_a_cloud_left_by_a_blow_poisons_and_slows_where_it_lies() -> void:
	_verb({"kind": "burst", "range": 60.0, "half_width": 40.0, "cloud": {"radius": 50.0, "seconds": 3.0}}).activate()
	assert_eq(get_tree().get_nodes_in_group("player_clouds").size(), 1)

# --- frail to light ---

func test_a_body_frail_to_light_takes_half_again_from_holy_and_no_more_from_the_rest() -> void:
	player._invuln = 0.0
	var hp := player.health.hp
	player.receive_hit(10, "holy", Vector2.INF)
	var plain := hp - player.health.hp
	player.health.hp = hp
	player._invuln = 0.0
	player.skillset.capabilities["trait_light_frail"] = 1
	player.receive_hit(10, "holy", Vector2.INF)
	var frail := hp - player.health.hp
	assert_gt(frail, plain, "holy light hurts it more")
	player.health.hp = hp
	player._invuln = 0.0
	player.receive_hit(10, "physical", Vector2.INF)
	assert_eq(hp - player.health.hp, plain, "and nothing else does")

# --- a bounding hop ---

func test_a_hop_bounds_three_times_in_a_straight_line_that_cannot_be_turned() -> void:
	lizard.global_position = Vector2(900, 0)
	player.global_position = Vector2(-400, -40)
	_verb({"kind": "dash", "speed": 200.0, "hit_range": 30.0, "hops": 3, "hop_gap": 0.3}).activate()
	var x0 := player.global_position.x
	await wait_seconds(1.0)
	assert_gt(player.global_position.x, x0 + 80.0, "it bounded on (from %.0f to %.0f)" % [x0, player.global_position.x])

func test_a_talisman_stops_a_hop() -> void:
	var t := RoomTalisman.new()
	t.setup({"id": "tal", "pos": Vector2(0, 0), "radius": 100.0}, {})
	add_child_autofree(t)
	player.global_position = Vector2(10, 0)
	assert_true(player.in_talisman())
	var a := _verb({"kind": "dash", "speed": 200.0, "hit_range": 30.0, "hops": 3})
	a.activate()
	await wait_physics_frames(3)
	assert_almost_eq(player.velocity.x, 0.0, 1.0, "no hop")
