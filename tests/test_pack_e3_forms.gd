extends GutTest
## The shipped verbs of Pack E3 and F, and the audited ones, cast for real.

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
	for g in ["forges", "verb_traps", "verb_veils"]:
		for n in get_tree().get_nodes_in_group(g):
			n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _form(id: String) -> FormDef:
	return load("res://data/forms/%s.tres" % id)

func test_drink_needs_something_to_drink_and_the_eater_is_frail_to_light() -> void:
	assert_false(arena.verb("spider_light_eater").ready())
	assert_true(_form("spider_light_eater").traits.has("light_frail"))

func test_the_philosophers_stone_chooses_and_digests_faster() -> void:
	assert_true(arena.verb("philosophers_stone").spec["choose"])
	assert_lt(int(_form("philosophers_stone").stats["predation_time"]), 0)

func test_a_rig_is_by_aim_and_the_tinker_is_weak_in_melee() -> void:
	assert_eq(arena.verb("goblin_tinker").spec["kind"], "rig")
	assert_lt(int(_form("goblin_tinker").stats.get("atk", 0)), 2)

func test_spin_is_two_for_one() -> void:
	var a := arena.verb("goblin_rumpelstiltskin")
	while player.parts_carried() > 0:
		player.inventory.take_carried()
	assert_false(a.ready())
	player.collect_part("ribs")
	player.collect_part("ribs")
	assert_true(a.ready())
	a.activate()
	assert_eq(player.parts_carried(), 1)

func test_the_smith_needs_a_forge_and_time() -> void:
	var a := arena.verb("goblin_smith")
	assert_false(a.ready(), "needs a forge")
	var f := RoomForge.new()
	f.setup({"id": "F", "pos": Vector2(20, 16)}, {})
	add_child_autofree(f)
	assert_true(a.ready())
	a.activate()
	assert_eq(player.weapons.size(), 1)
	assert_true(player.is_held_still())

func test_the_opener_and_the_tap_reveal_the_whole_room() -> void:
	var snare := RoomSnare.new()
	snare.setup({"id": "S", "pos": Vector2(500, 16)}, {})
	add_child_autofree(snare)
	arena.verb("wolf_wepwawet").activate()
	assert_true(snare.is_revealed(), "even across the room")
	var snare2 := RoomSnare.new()
	snare2.setup({"id": "S2", "pos": Vector2(400, 16)}, {})
	add_child_autofree(snare2)
	var a := arena.verb("goblin_knocker")
	a.activate()
	assert_true(snare2.is_revealed())

func test_copy_takes_the_shape_and_fades() -> void:
	player.last_inspected = VerbAlly._creature("twin_goblin_gremlin")
	arena.verb("mimic").activate()
	assert_true(player.is_copying())

func test_steal_takes_from_the_living_without_killing() -> void:
	var spider := Enemy.new()
	spider.setup(VerbAlly._creature("spider"), {})
	spider.position = Vector2(30, 0)
	add_child_autofree(spider)
	arena.verb("spider_anansi").activate()
	assert_true(spider.has_meta("verb_stolen"))
	assert_eq(spider.status.state, EnemyStatus.ACTIVE)

func test_the_pseudopod_is_shapeless() -> void:
	assert_gt(float(arena.verb("shoggoth").spec["jitter"]), 0.0)

func test_contagion_is_slow_to_build() -> void:
	assert_gt(float(arena.verb("pestilence").spec["hop_delay"]), 0.0)

func test_the_mummys_wrap_binds_then_gusts_and_fire_hurts() -> void:
	arena.foes[0].global_position = Vector2(60, 0)
	var a := arena.verb("undead_mummy_priest")
	a.activate()
	assert_true(_form("undead_mummy_priest").traits.has("fire_frail"))
	assert_eq(arena.verb("undead_mummy_priest").spec["alt"]["kind"], "burst")

func test_bind_roots_a_boss_too() -> void:
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	lizard.global_position = Vector2(60, 0)
	lizard.hunting = true
	arena.verb("gleipnir").activate()
	assert_true(lizard.is_rooted(), "even a boss is held")
