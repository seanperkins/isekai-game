extends GutTest
## The last world and body verbs: drinking a lamp or a pool dry, a transmute with a chooser, a rig that crafts a throwable, a trap or smoke, a spin that turns two parts
## into a better one, a forge that needs a forge, a reveal of hidden walls, weak floors and traps, a copy of a creature's shape and move, a steal that leaves the
## creature alive, a shapeless reach, a contagion slow to build.

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
	player._invuln = 1000.0
	await wait_physics_frames(3)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for g in ["verb_traps", "verb_veils", "forges"]:
		for n in get_tree().get_nodes_in_group(g):
			n.free()
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
	return VerbAlly._creature(id)

# --- drink ---

func test_a_drink_needs_a_lamp_or_a_pool_and_darkens_the_lamp_and_heals() -> void:
	var a := _verb({"kind": "drink", "range": 60.0, "hp": 6, "mp": 4})
	assert_false(a.ready(), "no lamp or pool to eat")
	var lamp := RoomLamp.new()
	lamp.setup({"id": "L", "pos": Vector2(20, 16)}, {})
	add_child_autofree(lamp)
	player.health.hp = 5
	player.mana.mp = 1
	assert_true(a.ready())
	a.activate()
	assert_gt(player.health.hp, 5, "healed")
	assert_gt(player.mana.mp, 1)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(lamp._light), "the lamp is dark")

# --- transmute with a chooser ---

func test_a_transmute_makes_the_element_the_caster_aims_at_and_never_the_least_held_by_default() -> void:
	for i in 6:
		arena.rules.handle_event(Events.ABSORBED, {"essence": "earth", "source": "test"})
	var a := _verb({"kind": "transmute", "from_units": 3, "to_units": 2, "choose": true})
	a.aim = Vector2(0, -1)  # up: air
	a.activate()
	assert_eq(arena.rules.held("air"), 2, "the one aimed at, not the one held least")
	a._cooldown = 0.0
	a.aim = Vector2(-1, 0)  # left: dark
	a.activate()
	assert_eq(arena.rules.held("dark"), 2, "and it can make dark, which the old verb never did")

func test_a_transmute_with_no_aim_still_moves_to_the_least_held() -> void:
	for i in 6:
		arena.rules.handle_event(Events.ABSORBED, {"essence": "earth", "source": "test"})
	_verb({"kind": "transmute", "from_units": 3, "to_units": 2, "choose": true}).activate()
	assert_eq(arena.rules.held("earth"), 3)

# --- rig ---

func test_a_rig_crafts_by_the_way_you_aim() -> void:
	arena.foes[0].global_position = Vector2(60, 0)
	var a := _verb({"kind": "rig", "range": 200.0})
	player.collect_part("claw")
	var parts := player.parts_carried()
	a.aim = Vector2(1, 0)  # forward: a throwable
	a.activate()
	assert_eq(arena.foes[0].hits.size(), 1, "a crafted throwable")
	assert_eq(player.parts_carried(), parts - 1, "made from a part")
	a._cooldown = 0.0
	a.aim = Vector2(0, 1)  # down: a trap
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("verb_traps").size(), 1, "a rigged trap")
	a._cooldown = 0.0
	a.aim = Vector2(0, -1)  # up: smoke
	a.activate()
	assert_true(player.is_unseen() or get_tree().get_nodes_in_group("verb_veils").size() > 0, "a smoke bomb")

func test_a_rig_with_no_parts_makes_no_throwable() -> void:
	while player.parts_carried() > 0:
		player.inventory.take_carried()
	arena.foes[0].global_position = Vector2(60, 0)
	var a := _verb({"kind": "rig", "range": 200.0})
	a.aim = Vector2(1, 0)
	a.activate()
	assert_eq(arena.foes[0].hits.size(), 0)

# --- spin ---

func test_a_spin_turns_two_parts_into_one_better_one_and_loses_the_rest() -> void:
	while player.parts_carried() > 0:
		player.inventory.take_carried()
	player.collect_part("ribs")
	player.collect_part("ribs")
	_verb({"kind": "spin", "ladder": ["ribs", "claw", "weapon_arm"]}).activate()
	assert_eq(player.parts_carried(), 1, "two for one")
	assert_eq(player.inventory.carried_parts()[0], "claw", "a better part")

func test_a_spin_needs_two_parts() -> void:
	while player.parts_carried() > 0:
		player.inventory.take_carried()
	player.collect_part("ribs")
	var a := _verb({"kind": "spin", "ladder": ["ribs", "claw"]})
	assert_false(a.ready())

# --- forge ---

func test_a_forge_verb_that_needs_a_forge_works_only_beside_one_and_names_the_weapon() -> void:
	var spec := {"kind": "forge", "stat": "atk", "amount": 2, "parts": 2, "needs_forge": true, "named": true, "still": 1.5}
	var a := _verb(spec)
	assert_false(a.ready(), "needs a forge")
	var f := RoomForge.new()
	f.setup({"id": "F", "pos": Vector2(30, 16)}, {})
	add_child_autofree(f)
	assert_true(f.is_in_group("forges"))
	var atk := player.stats.get_stat("atk")
	assert_true(a.ready())
	a.activate()
	assert_eq(player.stats.get_stat("atk"), atk + 2)
	assert_eq(player.weapons.size(), 1, "a named weapon")
	assert_true(player.is_held_still(), "it takes time")

# --- reveal: weak floors and traps ---

func test_a_tap_shows_hidden_walls_weak_floors_and_traps() -> void:
	var wall := RoomHidden.new()
	wall.setup({"id": "H", "pos": Vector2(40, 60), "w": 24.0, "h": 60.0}, {})
	add_child_autofree(wall)
	var floor_ := RoomWeakFloor.new()
	floor_.setup({"id": "W", "pos": Vector2(80, 16), "width": 40.0}, {})
	add_child_autofree(floor_)
	var snare := RoomSnare.new()
	snare.setup({"id": "S", "pos": Vector2(120, 16)}, {})
	add_child_autofree(snare)
	assert_true(floor_.is_in_group("hidden") and snare.is_in_group("hidden"))
	_verb({"kind": "reveal", "radius": 700.0}).activate()
	assert_false(wall.is_in_group("hidden"))
	assert_true(floor_.is_revealed())
	assert_true(snare.is_revealed())

func test_an_unrevealed_snare_hurts_the_one_who_steps_on_it_and_a_revealed_one_does_not() -> void:
	var snare := RoomSnare.new()
	snare.setup({"id": "S", "pos": Vector2(0, 16)}, {})
	add_child_autofree(snare)
	player._invuln = 0.0
	var hp := player.health.hp
	await wait_physics_frames(4)
	assert_lt(player.health.hp, hp, "it sprang")
	var safe := RoomSnare.new()
	safe.setup({"id": "S2", "pos": Vector2(0, 16)}, {})
	add_child_autofree(safe)
	safe.reveal()
	player._invuln = 0.0
	hp = player.health.hp
	await wait_physics_frames(4)
	assert_eq(player.health.hp, hp, "a known trap is a harmless one")

func test_a_weak_floor_gives_way_under_whoever_stands_on_it_unless_it_was_found() -> void:
	var floor_ := RoomWeakFloor.new()
	floor_.setup({"id": "W", "pos": Vector2(0, 16), "width": 60.0}, {})
	add_child_autofree(floor_)
	await wait_seconds(1.0)
	assert_true(floor_.has_fallen(), "it gave way")
	var held := RoomWeakFloor.new()
	held.setup({"id": "W2", "pos": Vector2(300, 16), "width": 60.0}, {})
	add_child_autofree(held)
	held.reveal()
	player.global_position = Vector2(300, 0)
	await wait_seconds(1.0)
	assert_false(held.has_fallen(), "found, it holds")

# --- copy and steal ---

func test_a_copy_takes_the_look_and_stats_of_what_was_inspected_and_one_of_its_moves_and_fades() -> void:
	var def := _creature("twin_goblin_gremlin")
	player.last_inspected = def
	var atk := player.stats.get_stat("atk")
	var a := _verb({"kind": "copy", "seconds": 0.8})
	a.activate()
	assert_true(player.is_copying(), "wearing its shape")
	assert_not_null(player.get_node_or_null("CopyLook"))
	var alpha: float = (player.get_node("CopyLook") as Sprite2D).modulate.a
	await wait_seconds(0.5)
	assert_lt((player.get_node("CopyLook") as Sprite2D).modulate.a, alpha, "the copy fades")
	await wait_seconds(0.6)
	assert_false(player.is_copying())
	assert_null(player.get_node_or_null("CopyLook"))
	assert_eq(player.stats.get_stat("atk"), atk, "and the stats go with it")

func test_casting_a_copy_again_makes_the_creatures_move() -> void:
	var def := _creature("twin_wolf_black_dog")  # its verb is a veil
	player.last_inspected = def
	var a := _verb({"kind": "copy", "seconds": 5.0})
	a.activate()
	assert_false(player.is_unseen())
	a._cooldown = 0.0
	a.activate()
	assert_true(player.is_unseen(), "its move, borrowed")

func test_a_steal_takes_an_essence_and_a_power_from_a_living_creature_and_leaves_it_alive_once() -> void:
	var spider := Enemy.new()
	spider.setup(_creature("spider"), {})
	spider.position = Vector2(30, 0)
	add_child_autofree(spider)
	var hp := spider.health.hp
	var before := arena.rules.held("dark") + arena.rules.held("water")
	var a := _verb({"kind": "steal", "range": 60.0})
	a.activate()
	assert_gt(arena.rules.held("dark") + arena.rules.held("water"), before, "an essence")
	assert_true(arena.rules.owned().has("ceiling_walk") or arena.rules.owned().has("sticky_thread"), "a power")
	assert_eq(spider.health.hp, hp, "it is alive and unhurt")
	var now := arena.rules.held("dark") + arena.rules.held("water")
	a._cooldown = 0.0
	a.activate()
	assert_eq(arena.rules.held("dark") + arena.rules.held("water"), now, "a creature gives once")

# --- shapeless and slow to build ---

func test_a_shapeless_reach_is_never_quite_the_same() -> void:
	var reaches := {}
	VerbMind.rng.seed = 7
	var a := _verb({"kind": "bolt", "range": 150.0, "pierce": false, "jitter": 0.4})
	for i in 12:
		var spot := 60.0 + 12.0 * float(i)
		arena.foes[0].global_position = Vector2(spot, 0)
		arena.foes[0].hits.clear()
		a._cooldown = 0.0
		a.activate()
		reaches[spot] = arena.foes[0].hits.size()
	assert_true(reaches.values().has(0) and reaches.values().has(1), "sometimes it reaches that far and sometimes not")

func test_a_contagion_that_is_slow_to_build_jumps_late() -> void:
	arena.foes[0].global_position = Vector2(50, 0)
	arena.foes[1].global_position = Vector2(100, 0)
	arena.foes[2].global_position = Vector2(900, 0)
	lizard.global_position = Vector2(900, 0)
	_verb({"kind": "chain", "range": 160.0, "jump": 80.0, "hops": 2, "damage_type": "poison", "hop_delay": 0.4}).activate()
	assert_eq(arena.foes[0].hits.size(), 1)
	assert_eq(arena.foes[1].hits.size(), 0, "not yet")
	await wait_seconds(0.6)
	assert_eq(arena.foes[1].hits.size(), 1, "it spread")

func test_the_new_keys_validate() -> void:
	for spec in [{"kind": "drink", "range": 60, "hp": 6, "mp": 4}, {"kind": "transmute", "choose": true}, {"kind": "rig", "range": 200}, {"kind": "spin", "ladder": ["ribs", "claw"]},
			{"kind": "forge", "needs_forge": true, "named": true}, {"kind": "reveal", "radius": 700}, {"kind": "steal", "range": 60}, {"kind": "bolt", "jitter": 0.3},
			{"kind": "chain", "hop_delay": 0.4}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
